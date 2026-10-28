VERDICT: APPROVE WITH CHANGES

Independent review of PR #125 (FO-6, head 72589f9) by S3-FanoutImpl-Review125, checked against plan `plans/skills-and-rules-fanout.md` v1.0 (FD-9, section 3.4, FO-6). Scope: `git diff 3178810...72589f9` (setup-user-skills.sh/.ps1, the setup-user-skills generator in build-deploy.sh, tests/skills-legacy, check.yml). I did not count the inherited reds (deploy-harness-mdm `size gate (forced)`, fanout-lib `bd-special` on Linux).

The code does what FD-9 asks. There is one harness check (`[ -d ~/.aitools/skills ]` / `Test-Path -PathType Container`) and it sits in the extracted body, so the MDM scripts carry it. Discovery and deploy are gated, the `OK skills n/a` row is written, and reverse discovery is kept and filtered by the harness names. The sh and ps rows match. Error handling passes the plan-execution-detail block: `rc` is captured with a comment, every catch logs, and every `log_error` is paired with an ERROR row. I found one blocking item, about merge order rather than code, and two non-blocking fixes.

## Findings

**B1 (blocking: merge order, not code). The branch lacks FO-4 (#124) and FO-5 (#123). On this head alone, no skills are deployed to either tool on any machine that has run deploy-harness.**
- Evidence: `grep -rn fanout_harness_skills scripts/` on 72589f9 finds nothing. The log shows the branch is FO-3 + FO-2 + this commit. `merge-base --is-ancestor` also shows FO-4 is not in FO-5.
- The effect: `setup-user-skills.sh:57-63` / `.ps1:51-57` stop deploying whenever `~/.aitools/skills` exists, and since #106 deploy-harness creates it on every run. Without FO-4/FO-5, nothing else writes `~/.claude/skills` or `~/.cursor/skills`.
- Plan section 5 says "FO-6 after FO-4" and "each later branch merges the previous FO head `--no-ff` before its PR is marked ready". The PR is not a draft.
- Fix: merge after #124 and #123, or merge their heads into this branch `--no-ff`, then rerun tests/skills-legacy and tests/skills-fanout. A local trial merge (FO-6 + FO-4 + FO-5, not pushed) had one conflict, in check.yml (adjacent added steps; keeping both sides resolves it). After it, skills-legacy passed 38/38 and skills-fanout 158 passed with 1 skipped.

**N1 (non-blocking, should fix). In fan-out mode, a failed adopt still writes a `claude skills` row.**
- Where: `setup-user-skills.sh:261` (`write_summary ERROR "claude skills" "adopt failed: $skill_name"`) and `setup-user-skills.ps1:303`.
- Why it matters: section 3.4 (last line) says setup-user-skills must not write the `claude skills` / `cursor skills` rows when `~/.aitools/skills` exists, and the PR body says it writes neither.
- Reproduced on a pty, answering `a` with the fixture dotprofile `claude/skills` set to mode 555. Both sh and ps gave `OK|skills|n/a (...)` plus `ERROR|claude skills|adopt failed: fail<lang>`, exit 1.
- With FO-4 merged, this row collides with the fan-out's `claude skills` row. The panel's dedup (`show_summary`: ERROR outranks OK) then hides the fan-out's result.
- Fix: when `SKILLS_FANNED_OUT` / `$skillsFannedOut` is set, use tool `skills`. Add a test case for it; the suite has no adopt-failure case today.

**N2 (non-blocking, a contract gap between PRs). In fallback mode, the `claude skills` and `cursor skills` rows are each written twice in one run once FO-4/FO-5 are in.**
- Probe: the local FO-4 + FO-5 merge, run in dev order (setup-user-claude, setup-user-skills, setup-user-cursor) under an isolated HOME with no `~/.aitools/skills`.
- The summary file had:
  - `OK|claude skills|n/a (no harness skills)` (the fan-out), then `OK|claude skills|16 added` (the fallback);
  - `OK|cursor skills|16 added`, then `OK|cursor skills|n/a (no harness skills)`.
- `show_summary` keeps the first row when severities are equal, so the panel showed `claude skills  n/a (no harness skills)` even though 16 skills were added to `~/.claude/skills`. Cursor showed `16 added` only because setup-user-cursor runs later.
- In fan-out mode (deploy-harness run first) the rows are right: `claude skills 32 added`, `skills n/a (fanned out from ~/.aitools/skills)`, `cursor skills 32 added`, one each.
- Options:
  - (a) A contract change to 3.4: the fan-out's no-harness case only logs and writes no row, so the fallback owns both rows when `~/.aitools/skills` is absent. This mirrors FD-9's "one writer" rule. It belongs to FO-4/FO-5's lib function, in this PR with a "Contract change" section or in their fix round.
  - (b) The fallback writes WARN rows, which outrank OK, e.g. "fallback deploy: N added (no ~/.aitools/skills)".
- Suggested: (a).

**N3 (non-blocking). Test gaps.** The suite has no pty adopt case in fan-out mode (I checked it by hand: `minesh` / `mineps` were written to the fixture dotprofile, sh and ps), no adopt-failure row case (N1) and no empty-harness case.

## Probes asked for, and my judgement

- **Harness present but empty.** sh and ps: `OK skills n/a` only, nothing deployed, and the user skill `mine` is still found. FO-4 also gates on the directory (`n/a (no harness skills)` only when it is absent), so with an empty harness neither script deploys anything. The two gates are consistent, so this is acceptable. In practice an empty harness means deploy-harness is broken, and it reports that itself. No finding.
- **Dotprofile has the same skill name as shared (fanned out).** That skill is never offered for adoption: the shared, dotprofile and harness-name checks all skip it. A behaviour note for FO-7's docs: the fallback deploys with dotprofile winning, while the fan-out deploys with shared winning (FD-4). Switching modes therefore changes which copy of a same-name skill is deployed. The review menu shows the change; it is not silent.
- **Retired name in the manifest.** It is not offered for adoption (the suite's `gone` case), which matches FO-6's "any name in the manifest". No finding.
- **Reverse discovery offered for a user skill.** Yes, and it adopts on a pty (above).
- **Resolver error with a harness present.** I accept the author's choice. The panel dedups `OK skills n/a` against `ERROR skills reverse discovery skipped: dotprofile error`, so only the ERROR shows, next to the lib's own ERROR `dotprofile` row. Exit 1 matches fallback mode, and the consequence is real: nothing can be adopted. Neither fan-out row is touched. No finding.
- **MDM generated scripts both ways.** The suite builds into a fixture dotprofile. The generated `.sh` passes `bash -n` and the generated `.ps1` passes the pwsh parser. Both deploy the embedded skills without `~/.aitools/skills` and write only the n/a row with it. Passes.
- **Duplicate rows with FO-4's fan-out.** Fan-out mode: one row per tool, except N1 when an adopt fails. Fallback mode: duplicated (N2).
- Extra: a dangling-symlink manifest gives `ERROR skills reverse discovery skipped: cannot read skills manifest` in both sh and ps (parity holds).

## What I ran (macOS, isolated HOMEs; nothing against the real HOME)

| Run | Result |
|---|---|
| tests/skills-legacy, bash 5.3.15 | 38/38 |
| tests/skills-legacy, /bin/bash 3.2.57 | 38/38 |
| tests/claude-mdm | 35/35 |
| tests/b8-consumers | 60/60 |
| Local merge FO-6+FO-4+FO-5: tests/skills-legacy | 38/38 |
| Local merge FO-6+FO-4+FO-5: tests/skills-fanout | 158 passed, 1 skipped |
| Probes (empty harness, pty adopt, adopt failure, dangling manifest), sh and ps | as above |
| Combined-run rows probe (deploy-harness, claude, skills, cursor) on the local merge | as in N2 |
| CRLF on setup-user-skills.ps1 | 328/328 lines CRLF |
| Modes | setup-user-skills.sh and test-skills-legacy.sh are 100755 |

Not run: Windows, and `check-pre-commit` / `check-pre-push` (reviewer, no commit). CI on 72589f9 when this was posted: windows and CodeQL passed; macos and linux were still running.
