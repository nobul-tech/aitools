# S3-CursorVerify report v1.0 -- Cursor rules and skills fan-out, verified end to end

Version 1.0, 2026-10-29, by S3-CursorVerify (level-1 orchestrator, Session
Commander 10cf255a-c). Mission CURSOR-VERIFY (commander, 2026-10-28:
"setup-user-cursor, verify").

## Summary

1. On origin/main 207f1a6 (the PR 123 merge), deploy-harness then setup-user-cursor were run under an isolated HOME on bash 5, /bin/bash 3.2 and pwsh 7 (macOS). Rules from all three sources reach `~/.cursor/rules/*.mdc` with the marker, and all skills reach `~/.cursor/skills`. Both paths pass first source wins with one ERROR row per duplicate, the user's own files left alone, a clean re-run, dry runs that write nothing, per-file backups, retirement with backup, and the pty review prompt with skip and abort.
2. Parity: the bash and pwsh trees and rows are identical, except for the upper-case `.MD` rule and the exec bit (the exec bit only differs when pwsh runs on macOS). The pre-run on the PR 123 head 9c2d025 and the rerun on main are byte-identical on both paths.
3. Gap fixed: `X.MD` rules. bash drops them; pwsh deploys them, but its manifest reader rejects them, so pwsh gives a permanent WARN plus a "Run aitools" ACTION and can never retire the rule. Fix PR: https://github.com/nobul-tech/aitools/pull/137 (`fix/cursor-fanout-md-case`, head 193f51c). CI was pending at hand-back and no independent review has run yet.
4. Open question for the commander: a retired rule's `.mdc` that the user edited is removed on the marker alone (backup kept, no WARN). The plan pins this behaviour (section 3.1), while the skills prune checks content.
5. Small follow-ups: cli-config.json is backed up on every run, the manifests get a new mtime every run, `~/.cursor/{rules,skills}` never get a directory backup, and `[REVIEW]` ignores NO_COLOR.

## Verification matrix (main 207f1a6; pre-run 9c2d025 identical)

| Check | bash | pwsh | Evidence |
|---|---|---|---|
| Rules from shared, aitools and dotprofile all reach `.mdc` with the marker | pass | pass | S3-CursorVerify-Bash/out-main/P1, S3-CursorVerify-Pwsh/out-main/P1 |
| `FX-Upper.MD` | FAIL (dropped, log_detail only) | FAIL (deployed, manifest line invalid, WARN + ACTION on every run, never retired) | Bash-handback G1; Pwsh-handback G2, PX-upper |
| Skills from shared, .claude and dotprofile reach `~/.cursor/skills/<name>/` | pass | pass | out-main/P1 tree.txt |
| Exec bit on a skill script | pass (0755) | 0644 (pwsh on macOS only; not applicable on Windows) | P1 tree diff |
| First source wins, one ERROR row per skipped duplicate (5) | pass | pass | P1 rows.txt |
| Bracket names `fx-[br].md`, `fx-[br]ack` | pass | pass (deploy, update, retire, restore) | Pwsh PX-br* |
| User's own `.mdc` and skill untouched (content, mode, mtime) | pass | pass | P0-P4 snapshots |
| Re-run verifies, nothing changes | pass, except: manifests get a new mtime; bash writes a new cli-config.json.bak | pass, except the manifest mtime | P2 |
| Dry run writes nothing | pass | pass | P3 |
| Per-file backups on update | pass | pass | P3b |
| Directory backup of `~/.cursor/rules` and `~/.cursor/skills` | not made (`backup_dir` needs a top-level *.md) | not made | P3b deploy.log |
| Retired rule and skill backed up, then removed (tracker `removed`) | pass | pass | P4 |
| Retired rule whose `.mdc` the user edited | removed with backup, no WARN (marker alone) | same | setup-user-cursor.sh:790-794, .ps1:770-771 |
| Review menu prompts under a pty (rule and skill); `s` keeps the edits | pass | pass | P5 transcripts |
| `x` exits 2, nothing written after it | pass | pass | P5x / P5-x |
| /bin/bash 3.2 P1 matches bash 5 | pass | n/a | out-main/P1-bash32 |
| Parity of trees and rows, bash vs pwsh | identical except the FX-Upper and exec-bit rows | | orchestrator diff of out-main/P1 and P4 |

## Gaps and fix PRs

- `.MD` case (fixed in PR 137, not merged). Plan `plans/rules-fanout-claude.md` already recorded this as R9 and follow-up F2 under D1 ("case-insensitive", commander answers 2026-10-22), but it was never implemented. PR 137 changes deploy-harness.sh/.ps1 and the rules-name check in both libs. It may conflict with PR 126, which touches both libs.
- Not fixed (reported only): cli-config.json backup on every run (setup-user-cursor.sh:197-199); manifest rewrite on every run (deploy-harness.sh:681-692); no directory backup (backup_dir precondition); `[REVIEW]` colour ignores NO_COLOR (aitools-lib.sh:1972); the review header says "repo source (embedded)" for the ~/.aitools source.

## Reviewer verdicts

- PR 137: none yet. The independent reviewer was not launched because this mission ended at the forced hand-back. It still needs a reviewer, who posts the verdict with `gh pr comment` on the final head.
- Verifier output was spot-checked by me: the G1 code at .ps1:770-771; my own trees diff (bash vs pwsh, P1 and P4; bash P4 at 9c2d025 vs main).

## CONFLICT / WRITE_BLOCKED

- CONFLICT: the prompt said to run the verification only after PR 123 merges, but PR 123 was closed by accident, so its merge time was unknown. Resolved by tier 2 (prompt intent): I ran a pre-run on head 9c2d025, then reran the same phases on main after the merge. The results are identical.
- CONFLICT: contract P4 (mine) expected a user-edited retired `.mdc` to be kept, while plan 3.1 pins #110's marker logic. Resolved by tier 2: the code follows the plan, so I raise it as an open question and do not fix it.
- WRITE_BLOCKED: none (the delegates hit read-only `cat` blocks from the guard and used Read).

## INCIDENT markers (not filed)

- INCIDENT: commit 2f7ccdb on main ("Land118 fixed #123") auto-closed PR 123 through a GitHub closing keyword.
- INCIDENT: the shared helper `.scratch/session-10cf255a-c/commit-onto-origin.sh` writes every blob at 100644. My commit ac2c189 put 19 .sh files at 100644 and broke check-pre-commit step 6; fixed in 1771636.
- INCIDENT: the `.MD` case mismatch between deploy-harness and the manifest readers, a bash/pwsh parity gap (PR 137).
- INCIDENT: a user-edited retired Cursor rule is removed on the marker alone, with no WARN or ACTION (spec ambiguity).
- INCIDENT: `backup_dir` never backs up `~/.cursor/rules` or `~/.cursor/skills` (config-file-safety "Directory deployment" step 2).
- INCIDENT: cli-config.json is backed up on every run, even when unchanged.

## Open questions (with suggested answers)

1. Should a retired rule's `.mdc` that the user edited (marker still present) be kept? Suggested: yes. Remove it only when its content equals the conversion of the harness copy or a backup; otherwise WARN and add it to the kept-files ACTION, as the skills prune does (FD-4). This is a .sh and .ps1 change for setup-user-cursor.
2. Should a no-change run write nothing (cli-config.json backup, manifest mtime)? Suggested: yes, with `cmp` guards.
3. PR 137 still needs CI green and an independent reviewer. Suggested: the Session Commander launches the reviewer (diff `origin/main...fix/cursor-fanout-md-case`), then it joins the merge train after PR 126.

## Not run

Windows (native pwsh, Git Bash), Linux, setup-user-cursor steps 1-3 (installers, cli-config) on the pwsh path, the real OS guards, MDM `deploy/`, `-Force`, the `o` answer under a pty, AI merge, loading the output in a real Cursor, a large multi-byte skill file (PR 124's `_fanout_is_binary` fix).

## Files

- Contract: S3-CursorVerify-contract.md; fixture and runners: scripts/
- Bash verifier: S3-CursorVerify-Bash/ (handback v1.0, rerun v1.0, out/, out-main/, scripts/)
- Pwsh verifier: S3-CursorVerify-Pwsh/ (handback v1.0, rerun v1.0, out/, out-main/, scripts/)
- Fixer: S3-CursorVerify-Fix/ (whatever it wrote before hand-back; its final report was not received)
