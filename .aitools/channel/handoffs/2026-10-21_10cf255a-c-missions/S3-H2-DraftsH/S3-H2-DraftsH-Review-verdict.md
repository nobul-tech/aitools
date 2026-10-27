NO BLOCKING FINDINGS

# S3-H2-DraftsH-Review: independent review of PR #99 (Write the approved HARNESS protected-file drafts)

Reviewer: S3-H2-DraftsH-Review (independent, read-only). Date: 2026-10-22.
Branch `docs/harness-approved-drafts` at 9e70ca6. Base: origin/main 8a9dcb5.
Method: mechanical comparison of each draft block with the PR files (Perl and Python scripts in the reviewer's scratch dir `.scratch/session-h2dhrv/`: `blocks-check.pl`, `mdc-check.pl`, `json-check.py`), plus spot checks against origin/main code.

## Verdict per item

| Item | Target | Result |
|---|---|---|
| a | `.claude/skills/tool-ops/SKILL.md` Intent Scope | Verbatim. The removed lines equal the draft's Old block, and the added lines equal its New block. |
| b1 | registries/tool-ops.json `tools.cursor` | The file parses. `tools.cursor == draft["cursor"]` is True. `claude-code` is unchanged. `meta` is unchanged except `lastUpdated` 2026-10-05 -> 2026-10-22 (the skill's "Adding a new tool" step 6). The `_draft` wrapper note is not written, which is correct. |
| b2 | `reference/tool-ops-cursor.md` | `diff` against the draft: the only difference is the removed 4-line `<!-- S3-H-Cursor DRAFT (not applied) ... -->` comment, which is an acceptable draft marker. |
| c1 | `.claude/rules/deploy-paths.md`, MDM draft | The MDM run order section (draft lines 15-29), the extract + embed paragraph (68-75) and the deploy-harness bullet (82-85) each occur verbatim, exactly once. The staleness note (87-89) is held, correctly (see N4). |
| c2 | `.claude/rules/deploy-paths.md`, row 14 / R20 | Edits 1, 2b and 3 (NEW blocks) each occur verbatim, exactly once. Edit 2 occurs verbatim in two parts: the list (edit lines 94-107) and the pre-push paragraph (109-111). Between them sits the MDM bullet, the merge the PR describes. Row 14's source is S3-M3-Docs's copy. Its text is identical to the approval page row 14 (`S3-M3-Docs-approval-page.md:1239-1380`), so the choice is correct. |
| c3 | `.cursor/rules/deploy-paths.mdc` | Every new or changed paragraph of the `.md` (unwrapped, `@shared/` -> `shared/`) is found verbatim in the `.mdc`, except the one condensed heading. Details are in N2. This item still needs the commander's confirmation, as the PR states. |
| d | `reference/managed-file-deployment.md` | Draft lines 11-29 (heading, paragraph, table) occur verbatim, at the anchor the draft names. The closing paragraph is held, correctly (see N4). |
| e | `.claude/rules/cross-platform.md` | One line changed: `C:\repos\` -> `%USERPROFILE%\repos\`. `.cursor/rules/cross-platform.mdc` has no repos line (`git grep -i repos` on origin/main finds nothing), so leaving it unchanged is correct. |

Scope: `git diff --stat origin/main docs/harness-approved-drafts` lists 9 files. They are the 7 targets above plus the author's 2 files under `S3-H2-DraftsH/S3-H2-DraftsH-drafts/`. No file outside the mission is touched.

Every removed line in `.claude/rules/deploy-paths.md` comes from a draft:
- The 2 duplication-table rows and the "Three script pairs" wording come from row 14, edit 1.
- "progress toward the I6 structural fix" comes from row 14, edit 1.
- The `@shared/claude-shared.md` and rules bullets come from row 14, edit 2.
- The "any of the 3 scripts" heading comes from row 14, edit 2b.

## Findings

No blocking findings.

### N1 (merge readiness): pre-commit step 20 goes from PASS to FAIL repo-wide

`bash scripts/check-pre-commit.sh`, run from the worktree, gives 6 PASS, 12 SKIP, 1 WARN, 2 FAIL. Step 6 is the known pre-existing failure. Step 20 reports:

```
.claude/rules/deploy-paths.md:114: scripts/aitools-json.pl/.ps1
.cursor/rules/deploy-paths.mdc:59: scripts/aitools-json.pl/.ps1
reference/managed-file-deployment.md:414: .claude/hooks/
```

None of these three strings exists on origin/main: the main `deploy-paths.md` has no `aitools-json.pl/.ps1`, and the subsection with `.claude/hooks/` is new. Step 20 scans the whole repo (`scripts/check-pre-commit.sh:485`, `check-path-refs.py --root "$REPO_ROOT"`). After this merges, every later commit's pre-commit therefore fails step 20 until the allowlist is updated.

The text itself is correct:
- `scripts/aitools-json.pl` and `.ps1` both exist; the checker misreads the pair notation.
- `.claude/hooks` is a real deploy-harness source (`scripts/deploy-harness.sh:257`). It is absent on main (`git ls-tree origin/main .claude/` lists only commands, rules and skills).

So this is not a fidelity defect. Suggested: land the PR's three proposed lines in `scripts/check-path-refs-allow.txt` (not a protected file) in this PR or in a follow-up merged right after it. The commander decides, because the mission scope says "NOT code".

### N2: the `.mdc` twin carries the approved text faithfully

`mdc-check.pl` finds all of these verbatim in the `.mdc`:
- the MDM run order section (2 paragraphs);
- the step 2 parenthetical;
- the hooks table row;
- the pure-extract paragraph and its 3 bullets;
- the resolver paragraph;
- the extract + embed paragraph;
- all 7 auto-embedded bullets;
- the pre-push step 7 paragraph.

Differences from the `.md`, all in the `.mdc`'s existing condensed style (main's `.mdc` already used it):
- The duplication intro drops "— it faithfully reproduces whatever is hardcoded in the template." (main's `.mdc` also lacked it).
- The closing heading and steps are one line.
- `@shared/` is written as `shared/`.

The sections no draft changed keep the `.mdc`'s own wording. Two of them are now out of step with the `.md`. Both were already like this before the PR, so they are follow-ups, not part of this PR:
- `.mdc` line 30, "3. Verify via pre-commit steps 3+10". The `.md` says those steps "no longer apply" to the frozen `aitools/deploy/`.
- The `.mdc` MDM path line, `deploy/setup-*.sh/.ps1`. The `.md` has `<userRepoPath>/deploy/...`.

### N3: Q5 wording and trailing backslash

`S3-Harness-handback.md:46` suggests "standardise on %USERPROFILE%\repos". The PR writes `%USERPROFILE%\repos\`, which keeps the trailing separator of the replaced `C:\repos\` and of `~/repos/` on the same line. Acceptable.

The claims behind Q5 check out:
- `scripts/aitools-install.ps1:324,333` use `Join-Path $env:USERPROFILE "repos"`.
- The remaining `C:\repos` mentions match the PR's follow-up list: `shared/cursor-rules/user-rules.md:28` (protected, not in scope) and `scripts/aitools.ps1:1994` (a comment).

### N4: both holds are correct against origin/main

**MDM staleness note.** The note says pre-push step 7 "does not yet trigger on them". Step 7's trigger is `scripts/check-pre-push.sh:123`, `grep -E '^(scripts/(setup-.*|build-deploy|aitools-lib|aitools-profile)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|shared/)'`. It matches `shared/hooks`, `shared/skills` and `shared/rules`. On a match, step 7 rebuilds into a temp dotprofile and diffs `deploy/` (lines 131-173). So the parenthetical is false for three of the listed directories.

The rest of the author's corrected list is true. The regex does not match `reference/`, `registries/`, `.claude/*`, `scripts/deploy-harness.*` or the `scripts/*.py` bin CLIs.

The hold drops the true first sentence along with the false parenthetical. That is consistent with the approval terms (hold, do not invent text).

**managed-file-deployment closing paragraph.** It says rules reach the tools "through the `setup-user-claude` / `setup-user-cursor` fan-out". On main:
- Only setup-user-cursor fans out `~/.aitools/rules`: `scripts/setup-user-cursor.sh:378,389` (`HARNESS_RULES_DIR="$HOME/.aitools/rules"`) and `.ps1:372,383`.
- setup-user-claude's managed scope is `<userRepoPath>/claude/rules/` (`scripts/setup-user-claude.sh:13`, `.ps1:12`). `git grep -E "aitools[/\\]rules"` finds no `~/.aitools/rules` in either setup-user-claude script.

So the paragraph is false for setup-user-claude. The corrected draft agrees with the applied deploy-paths text ("`setup-user-claude` once it fans out").

### N5: claim spot checks against origin/main (all hold)

- **Row 14 resolver sentence.** `setup-user-settings.sh:67` and `setup-user-cursor.sh:199` call only `resolve_user_repo_path`. `setup-user-claude.sh:72,84` also calls `resolve_machine_profile`.
- **MDM run order.**
  - `n/a (no harness rules)`: `setup-user-cursor.sh:478,514`.
  - `config.json not generated` ERROR rows: `deploy-harness.sh:101-102,112-113`.
- **Extract + embed.**
  - `extract_span()`: `build-deploy.sh:365`.
  - The `add_source` parser and its count check: `build-deploy.sh:1712-1729`.
  - The `for cli in` parser: `build-deploy.sh:1737`.
  - `AITOOLS_PROFILE_SH`: `build-deploy.sh:525`.
  - `AITOOLS_USER_REPO_PATH`: `build-deploy.sh:188`.
- **managed-file-deployment table and paragraph.**
  - Sources and order: `deploy-harness.sh:254-263`.
  - bin CLIs: line 266.
  - `TOOL="harness files"`: line 50.
  - `deploy_managed_file ... "$src"` (adopt target = source): line 309.
  - Duplicate `log_error`: line 238.
  - `setup-user-config.sh` writer: lines 99-113.
- **tool-ops-cursor.md "Harness deployment".**
  - `alwaysApply: true` added when there is no frontmatter: `setup-user-cursor.sh:393,451`.
  - `**/<pattern>` with `alwaysApply: false`: lines 413 and 448.
  - Warning on a misparse: line 637.
- **SKILL.md Intent.** The widened scope matches the existing section "Per-tool ops references (where to read them)" (`.claude/skills/tool-ops/SKILL.md:45-63`).

### N6: a stale paragraph left unchanged (follow-up, no draft)

The last paragraph of `.claude/rules/deploy-paths.md` (lines 136-138) is unchanged. It says the I6 structural fix is still to "refactor `build-deploy.sh` to extract setup logic". The new text above it says claude, cursor, mcp and settings are now pure extract. No draft touches the paragraph, so leaving it is correct. It needs its own draft.

## Not run

- `bash scripts/check-pre-push.sh`. The author reports 6 PASS, 1 SKIP, 3 WARN, 0 FAIL.
- Windows.
- The Cursor live canary (needs `agent login`).
- CI. At review time linux and macos were pending; windows, CodeQL and Analyze had passed (`gh pr checks 99`).
