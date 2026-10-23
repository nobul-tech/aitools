# S3-M3-JsonRename report: order-preserving `rename` in the JSON engines (re-key batch 1)

**Intent**: **Purpose**: Record what mission S3-M3-JsonRename shipped (design batch 1), how it was verified, and what is left open. **Scope**: scripts/aitools-json.pl, scripts/aitools-json.ps1, tests/profile/test-profile.sh on PR #86. NOT the resolver (S3-M3-Resolver). **Audience**: S3-M3Lead, S3-M3-Resolver, the reviewer, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/86 (`feature/m3-rekey`). It is stacked on #82 and opened against base `main`.
- Commit 7cf9b8b: "Add order-preserving rename to the JSON engines (re-key batch 1)".
- Source: commander decision 5, and the re-key design sections (a), (f) and (h) row 1.

## Op contract (for S3-M3-Resolver)

- **perl**: `printf 'rename\t<NEW>\t<SEG>...\n' | perl aitools-json.pl edit IN OUT`. The last SEG is the key to rename. It can be combined with `set` and `del` lines in one stream, and the ops are applied in order.
- **PowerShell**: `Rename-JKey $root <NEW> @(<SEG>...)`. It mutates the tree in place and throws on error. Write the tree with `ConvertTo-NodeJson` + "`n" as today.
- **Behaviour**: the key keeps its position and its value, and every other byte is kept.
- **Errors**: the message is identical in both engines. perl exits 2 and does not write OUT. PowerShell throws the same text.
  - `rename: no key given`
  - `rename: new key is empty`
  - `rename: '<seg>' not found` (a path segment or the key itself)
  - `rename: '<seg>' is not an object`
  - `rename: '<NEW>' already exists`: another key equals NEW ignoring case. This matches PowerShell's case-insensitive property names, so perl cannot write a file that PowerShell then refuses to read.
- **No-ops and case**: NEW equal to the key is a no-op. A case-only rename (`ABC` -> `abc`) is allowed. Path segments match case-sensitively in both engines. Note that `Get-JNode` in PowerShell is still case-insensitive; that is pre-existing and was not changed.
- **migrate pattern**: run `rename <id> profiles <alias>`, then `set string <alias> profiles <id> alias`. The `alias` field is appended at the end of the entry. Test `jr-then-set` covers this.

## Tests

The new section "JSON engines: rename" in tests/profile/test-profile.sh has 22 cases plus 1 check, 99 assertions in total. The first commit had 14 cases and 66 assertions; the rest were added after review. A pwsh driver is written to the test temp dir.

- **Positions**: first, middle, last and top-level keys.
- **Byte preservation**: in the middle case, only the key line changes (diff = 2 lines).
- **Behaviour**: rename followed by set; case-only rename; no-op.
- **Errors**: missing key; existing key; existing key with different case; old key in the wrong case; missing path; non-object path; no key given.
- **Nothing written**: checked for every error case.
- **Parity**: in every case, perl and pwsh write identical bytes and print identical messages.

## Verification (macOS, isolated HOME)

- `perl -c`, `bash -n` and the pwsh parser all pass.
- test-profile.sh: 418 passed, 0 failed (385 before the review fixes), under both /bin/bash 3.2 (`AITOOLS_TEST_BASH=/bin/bash`) and bash 5.
- test-config.sh: 89 passed. test-lib.sh: 40 passed.
- check-pre-commit has 2 FAILs:
  - step 6: known.
  - step 20: dead references to reference/tool-support-decision-tree.md and scripts/gen-tool-specs.py. They are already on the base branch, in aitools-lib.*, aitools-profile.* and tool-adopt SKILL.md, not in this PR's files.
- check-pre-push: step 7 FAIL (known).

## Not run

- Windows and Linux (CI covers Linux).
- No resolver change, and the live dotprofile was not touched.

## Review outcome

- **Reviewer**: S3-M3-JsonRename-Review, an independent level-3 delegate. It ran 25 extra probes on both engines.
- **Review**: https://github.com/nobul-tech/aitools/pull/86#pullrequestreview-5620827835
- **Verdict**: request changes (1 major, 1 minor, 3 nits). GitHub refused `--request-changes` on our own PR, so it was posted as a comment.
- **Fixed in the follow-up commit** (all of them):
  - **MAJOR**: an empty NEW was accepted by perl, while PowerShell threw a non-contract error after it had already removed the keys. Both engines now refuse it first with `rename: new key is empty`. As a second guard, `Rename-JKey` now restores the original keys and order if `Add-Member` fails part-way, then throws `rename: failed, '<key>' unchanged: <why>`. No test triggers that restore path.
  - **MINOR**: perl now folds case with Unicode rules (`utf8::decode` + `lc`), matching PowerShell's `-ieq`. Test `jr-unicode-exists` covers it.
  - **Nits**: the header alignment is fixed. New cases cover scalar, array, null, `[]` and single-item array values, paths two and three levels deep, non-ASCII keys, and an existing OUT left untouched on failure.
- After the fixes, test-profile.sh passes 418 of 418, under both /bin/bash 3.2 and bash 5.
- **Pre-existing, reported by the reviewer, not changed**:
  - The PowerShell writer turns `0.10` into `0.1`, while perl keeps the source text. Same input, different bytes from the two writers.
  - PowerShell `Read-JsonFile` refuses keys that differ only in case; perl accepts them.

## INCIDENT markers (not filed)

- `INCIDENT:` check-pre-commit step 20 fails on the #82 line. reference/tool-support-decision-tree.md and scripts/gen-tool-specs.py are referenced from scripts/aitools-lib.ps1:90, aitools-lib.sh:112, aitools-profile.ps1:527, aitools-profile.sh:674 and shared/skills/tool-adopt/SKILL.md (68, 72, 79, 88, 164, 190, 211), but neither file exists on the branch.

- `INCIDENT:` (pre-existing, from the reviewer) the engines write the same number differently: perl `numnorm` keeps the source text (`0.10`), while PowerShell ConvertTo-Json writes `0.1`. Bash and PowerShell writers of one shared file can therefore produce different bytes.

## Open questions

1. Should the PowerShell `Get-JNode` path lookup also become case-sensitive, to match perl `nav`? Suggested: yes, in batch 2. The resolver owns those call sites, and id keys are lower-cased on write, so the risk is low.

## WRITE_BLOCKED

None.
