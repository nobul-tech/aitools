# S3-MF-Fix3-Review: independent review of PR #114

**Intent**: **Purpose**: An independent verdict on whether PR #114 fixes what it claims (audit A-10, A-11; PR #98 review m1; PR #108 review n-2) and changes nothing else. **Scope**: The PR's own commit 93569b2 on `fix/mf-audit-config` (head 16c9d18 adds only `S3-MF-Fix3-report.md`). The `--no-ff` merges of #98 and #108 are context only. NOT fixing code. NOT approving or merging. **Audience**: S3-MF-Fix3 (author), S3-M3Finish, Jose.

Reviewer: S3-MF-Fix3-Review (wrote none of this code). Reviewed 2026-10-22 on macOS arm64. Diff: `git show 93569b2` (6 files: aitools-profile.sh/.ps1, setup-user-config.sh/.ps1, tests/profile/test-config.sh, test-profile.sh). `git show --stat 16c9d18`: one .md file, no code.

## Verdict

**Approve-worthy. 0 blocking, 4 non-blocking.** All four items are fixed in both languages, and I confirmed each one in the code, in the tests and with my own probes. The resolver's tags and exit codes are unchanged. The writer contract is intact. The only behaviour change beyond the messages is one more counted error on the two section-1 failure paths. Those paths already exited 1, and the PR body discloses it.

## Per-item checklist

| # | item | status | evidence (93569b2) |
|---|---|---|---|
| 1 | A-10: every ACTION has a log line carrying its instruction | **fixed** | The audit scope (findings section 3, A-10) is the two section-1 ACTIONs. sh:289-303 / ps1:267-281: a shared `ADVICE` / `$rowAdvice` variable feeds both `log_error` / `LogError "config: <row> -- <advice>"` and the ACTION row, so their texts cannot drift. The level is error, the same as the ERROR row next to it, as the launch prompt said. The section-3 ACTION already had a same-text `log_warn` (sh:469-471 / ps1:439-441), unchanged. These are the only ACTION sites in either writer (`grep -n ACTION`). Tests: C16 (out_has + `log_has "[error] config: profile.json invalid -- ..."`), C23, C23e. Probe P6 (true no-match): both writers print `[error] config: machine profile: no machine match -- Run: aitools user init (profiles: other)`, with identical rows and `FAILED with 2 error(s)` in both. |
| 2 | A-11: bash temp/EXIT-trap removals checked; parity with Remove-ConfigTmp | **fixed** (n-1) | sh:151-155 `remove_config_tmp`: `[ -e ] && ! rm -f` gives a counted `log_warn "Could not remove temp file $CONFIG_TMP"`. It is called once at sh:456, after every section-2 branch. No `exit` sits between the merge (sh:376) and that call, so every non-move path reaches it. After a successful `mv` it does nothing. sh:158-165 `cleanup` checks both removals and logs at detail. The trap's return value does not change the script's exit status. PS removes the temp file in each branch (ps1:360, 388, 392, 396, 401, 410), also after the row, so the order of warning and row matches. Test C25 stubs `rm` (bash only): exit 1, a `[warn]` line, both detail lines. The PS text carries the exception message (`...: <reason>`) and bash's does not (n-1). |
| 3 | #98 m1: two states, two messages; the writer classifies both | **fixed** | sh:645-646 / ps1:514-515 (`resolve_machine` / `Resolve-Machine`) and sh:1469-1470 / ps1:1298-1299 (`migrate`): the version is checked first (`profile.json is not v2`), then the type (`profile.json has no profiles object`). Each check returns 2, or `put_mig` + `finish 2` / `& $putMig` + `Complete-Command 2`. `finish` and `Complete-Command` both exit (ps1:204), so only one error line is ever printed. Writer: sh:262 / ps1:237 add `has no profiles object` to the PROFILE_BAD classifier. With `--no-machine` this message is not one of the two prefixes the writer silences (sh:253 / ps1:228: `no profile matches this machine`, `profile.json has no machine profiles`), so it stays an invalid profile.json, as the PR says. Tests: test-profile rm-v1 (`^...is not v2$`, no "has no profiles object"), rm-v2-no-profiles, rm-v2-profiles-array, mig-v1, mig-no-profiles (file untouched); test-config C23, C23b, C23c, C23d. |
| 4 | #108 n-2: a case-twin merge failure names the key | **fixed** | sh:381-383 / ps1:353-358 parse the engine message `set: '<seg>' differs only in case from existing key '<key>'` (aitools-json.pl:192, aitools-json.ps1:141) and append ` -- key "<key>" differs only in case from the managed key "<seg>": rename or remove it`. The groups are the right way round: group 1 is the managed segment, group 2 the user's key. The row stays `ERROR\|aitools config\|merge failed`, with no ACTION. bash: perl prints nothing on no match and exits 0. The `\|\| MERGE_WHY=""` has its comment and falls back to the generic text. Test C24 (MachineId). Probes P1 (`Meta`), P2 (`GoogleDrives`), P5/P7 (`REPOSPATH` with `--repos-path` / `-ReposPath`): both writers print the same key text, config.json is untouched and no temp file is left. |
| 5a | Resolver output contract | **intact** | Only the two message texts change. Tag lines, `result failed` (migrate) and exit 2 are the same on both paths. The register message `profile.json is not v2 -- migrate first` (sh:1264 / ps1:1120) is unchanged. |
| 5b | Writer contract | **intact** | `--machine-id` / `-MachineId` and `--no-machine` / `-NoMachine` are untouched (the diff does not touch argument parsing). Exits stay 0/1: the new `log_error` lines fire only on paths that already had a counted error (the resolver's `config: <error>` line, sh:260 / ps1:235), so exit 1 there is unchanged. No path can exit 2. At most one ACTION: section 1 writes one only when DERIVE_RC is not 0 or 1, section 3 only when DERIVE_RC is 0, and the merge and case-twin paths write none (C23 to C23d `rows_n 1 ACTION`). |
| 6 | Parity, bash 3.2, silent failures, write_summary, config-file-safety | **ok** | Parity: the test-config pwsh halves (byte-identical config.json, identical rows) for C16, C23 to C24, plus my probes P1, P2, P6, P7. Wording differences that were already there (bash `(exit N)` and `display_path`, PS the full path) are unchanged. bash 3.2: `/bin/bash -n` is clean and every suite passes under 3.2. Silent failures: the one new suppression (sh:382) has its comment and a fallback. write_summary: no path loses a row. config-file-safety: read-then-merge, backup and validation are untouched. A refused merge leaves the file untouched (C24, P1). |
| 7 | Consumers of the old text | **none left** | `grep -rln "not v2"` (worktree, excluding .scratch, harvesting and .git) finds only the 4 touched scripts, the 2 tests and handoff .md files. `grep "has no profiles"` finds only the new text. No lib, user-init or check consumer parses the resolver's message (`grep` over scripts/). The live dotprofile `deploy/` does not contain the literal old text (`grep -rln "is not v2"`: no hits). Whether the embedded copy is encoded is unknown, but nothing in deploy/ parses it either way. It goes stale until the next build-deploy, as the PR says. |

## On the PR's Assumptions and Follow-ups

- **ACTION pairing at error level**: I agree, given the launch prompt and that I-2 (#147) is still open. A `log_warn` would auto-promote later OK rows. Side effect (n-2): one failure now counts as two errors.
- **No version value in "is not v2"**: I agree. A message that the two engines print differently would open a parity gap for no gain.
- **v2 without a profiles object stays invalid under `--no-machine`**: consistent with #98 and the launch prompt. The Follow-up (advise `aitools user init` only when `profiles` is absent) is a reasonable commander question.
- **No ACTION for a case twin**: correct. It keeps "at most one ACTION", and the log line now names the key.
- **Follow-up `"version": 2.0` parity**: I did not reproduce it (unknown). It is plausible from `Get-JText`, and out of scope.

## Blocking findings

None.

## Non-blocking findings

- **n-1 (A-11 parity, low)**: the bash warning says `Could not remove temp file <path>` with no reason. PowerShell says `Could not remove temp file <path>: <exception message>` (ps1:166). `rm`'s own diagnostic goes to the console unstructured and never reaches deploy.log. The PR says "the same text as PowerShell". It is the same prefix only. Suggested: `if [ -e "$CONFIG_TMP" ] && ! RM_ERR=$(rm -f "$CONFIG_TMP" 2>&1); then log_warn "Could not remove temp file $CONFIG_TMP: $RM_ERR"; fi`.
- **n-2 (error count, low; tied to I-2)**: on the two section-1 paths, one problem now counts as 2 errors: the resolver's `config: <error>` line plus the new ACTION line (P6: `FAILED with 2 error(s)`, both writers). The installer's PowerShell relay counts child error lines (audit A-1), so its own footer grows by one as well. That is acceptable now, and it is disclosed. Re-check when I-2 is decided (the PR's Follow-ups already list this).
- **n-3 (pre-existing parity gap, out of scope, low)**: probe P3, a config.json holding both `machineId` and `MachineId`. bash merges: exit 0, `OK|aitools config|updated`, and both keys are kept, so bash writes a file that PowerShell `ConvertFrom-Json` rejects. PS treats the file as invalid JSON ("contains keys with different casing") and rebuilds it: `WARN|aitools config|rebuilt (was invalid)`, `MachineId` dropped. The engines refuse to add a case twin only when the exact key is absent, so the n-2 path never sees this case. It is not introduced by this PR. It belongs to the #108 / I-5 follow-up (key-case spec).
- **n-4 (tests, low)**: C23e checks the no-match log line on the console only, not its level in deploy.log (C16 checks the level for the invalid-profile line). C25 has no PowerShell twin (disclosed).

## INCIDENT markers (not filed)

- `INCIDENT:` (I-2, existing #147, still undecided) the ACTION pairing level drives n-2. Nothing new.
- `INCIDENT:` (I-5 from the PR #108 review, extended) no spec covers a config.json or profile.json that already holds two keys differing only in case. The bash engine keeps both, the PowerShell reader rejects the file, and the writers then disagree on the outcome (probe P3: OK vs WARN rebuilt). The I-5 suggestion (one paragraph in reference/cross-platform-detail.md or reference/user-repo.md) should cover this case too.

## Tests run

macOS arm64, isolated HOME and AITOOLS_LOG_DIR under `.scratch/session-mf3rev/` (cwd `.scratch/session-mf3rev/cwd`), script `.scratch/session-mf3rev/run-tests.sh`. pwsh 7 parity halves ran in every suite.

| suite | GNU bash 5.3.15 | /bin/bash 3.2.57 (`AITOOLS_TEST_BASH=/bin/bash`) | PR body | baseline |
|---|---|---|---|---|
| test-config | 319 / 0 | 319 / 0 | 319 / 0 | 269 / 0 |
| test-profile | 763 / 0 | 763 / 0 | 763 / 0 | 744 / 0 |
| test-lib | 209 / 0 | 209 / 0 | 209 / 0 | 209 / 0 |
| test-user-init | 200 / 0 | 200 / 0 | 200 / 0 | 200 / 0 |

- `bash -n` and `/bin/bash -n` on setup-user-config.sh, aitools-profile.sh, test-config.sh and test-profile.sh: clean. pwsh `Parser::ParseFile` on setup-user-config.ps1 and aitools-profile.ps1: clean.
- Probes (`probe.sh`, `probe2.sh`, both writers): P1 `Meta` twin, P2 `GoogleDrives` twin, P3 `machineId` + `MachineId` (n-3), P5/P7 `REPOSPATH` twin with the repos-path argument, P6 true no-match (A-10 line and error count). A P4 fixture mistake (hostname matched) and a P5 PowerShell run with bash flags were discarded.
- Ownership: 93569b2 touches none of S3-MF-Runner's files (aitools-lib, scripts/aitools, aitools.ps1, test-lib, test-user-init).

## Not run

- Windows / Git Bash (PS only under pwsh 7 on macOS).
- check-pre-commit / check-pre-push (the author reports them).
- build-deploy.sh; anything against the real HOME.
- A real (not stubbed) `rm` failure; n-1 is from reading the code.
- The `"version": 2.0` parity Follow-up.
