# M6-A report (v1.0)

Delegate M6-A of mission M6-Polish (session 87795dc3), item a (issue #29). M6-A returned this report in its hand-back but did not write the file before it was told to hand back. M6-Polish committed the text here unchanged in substance.

## Summary

1. Ten EOF regression cases for issue #29, with the same names in `tests/menus/test-menu-choice.sh` and its twin `.ps1`. They cover the JSON field prompt (through `deploy_managed_file`, including a field only in LOCAL), the settings sync, the AI-merge preview and the `[r]efine` feedback read. Tests only; the library is unchanged.
2. Checked on origin/main 846ab24 first: none of these cases existed, and no test called `sync_managed_json` / `Sync-ManagedJson`. The library behaves as documented at every prompt.
3. Mutation proof: 10 library mutants (5 per language), each breaking the EOF handling at one call site. Every mutant was killed, every new case fails under at least one mutant, and no older case failed under any of them.
4. All local suites pass on Windows. Pre-commit and pre-push report 0 FAIL.
5. PR #155 (branch `test/m6-eof`, head 0e94f5e at hand-back).

## New tests (same names in both twins)

1. EOF at a JSON field: overwrite (o), the repo unchanged
2. EOF at a JSON field: warning and 'EOF -> o' logged, no hint
3. EOF at a JSON field only in LOCAL: skip (s), LOCAL and the repo unchanged
4. EOF at a JSON field only in LOCAL: [a/s/x] asked, warning and 'EOF -> s' logged
5. EOF at the settings sync: overwrite (o) from profile.json, profile.json unchanged
6. EOF at the settings sync: warning and 'EOF -> o' logged, no hint
7. EOF at the merge preview: rejected (n), back to the review menu
8. EOF at the merge preview, then at the review menu: overwrite, the merge not written
9. EOF at the refine feedback: warning logged, the refine prompt has empty feedback
10. EOF at the refine feedback: the merge refined (AI called twice), then EOF rejects it and EOF overwrites

How EOF reaches each suite:
- `.sh`: one Ctrl-D (`\x04`) through `tests/managed-files/pty-run.py` for each read that must see EOF.
- `.ps1`: an exhausted `[Console]::SetIn` reader.

The stub AI CLI appends each prompt it gets to `bin/calls.txt`, followed by a `==CALL==` line.

## Mutation table

| Mutant (call site) | bash pass/fail | PowerShell pass/fail | New cases that fail |
|---|---|---|---|
| JSON field EOF default `o` -> `s` | 84/4 | 93/4 | 1, 2, 5, 6 |
| Field only in LOCAL: EOF default `s` -> `a` | 86/2 | 95/2 | 3, 4 |
| Merge preview EOF default `n` -> `y` | 85/3 | 94/3 | 7, 8, 10 |
| Feedback EOF -> reject the merge (`menu`) | 86/2 | 95/2 | 9, 10 |
| Feedback EOF -> feedback text `(eof)` | 87/1 | 96/1 | 9 |

## Local counts (Windows 11, Git Bash 5.3 with pywinpty ConPTY, pwsh 7)

| Suite or check | Result |
|---|---|
| menus `.sh` | 88/0/0 (was 78) |
| menus `.ps1` | 97/0/0 (was 87) |
| managed-files `.sh` | 79/0, 3 skipped |
| managed-files `.ps1` | 56/0 |
| adopt-push `.sh` / `.ps1` | 28/0 / 22/0 |
| os-guards | 34/0 |
| logging `.sh` / `.ps1` | 36/0 / 26/0 |
| menu-parity | 24/0 |
| `check-pre-commit.ps1` | 0 FAIL; WARN 5 (platform note), 9 (release notes), 11 (dotprofile changes, not M6-A's) |
| `check-pre-push.ps1` | 7 PASS, 3 advisory WARN, 0 FAIL |

## Not run

- The macOS and Linux halves locally; CI runs them.
- Nothing ran against the real HOME.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: the auto-mode note (Bash allowed for file edits) vs USO "Dedicated tools for file ops". Resolved by tier 1, the commander's words: the dedicated tools were used.
- INCIDENT: none (code and docs agree at every prompt).

## Operational learning

- With ConPTY under Git Bash, and with Linux n_tty (the linux CI job passed), several Ctrl-D sent in one write each end their own read. A terminal read blocks again after an EOF, so every read that must see EOF needs its own `\x04`.
- Mutation testing without touching the lib: copy the lib, the suite, `pty-run.py` and `relay-outbound-prompt.ps1` into a scratch tree with the same layout. The suites find the lib relative to their own path, so they load the mutant.
- A stub AI CLI that records its stdin lets a test count AI calls and inspect the prompts it received.
- Write the report before arming a long CI watch: the hand-back can be forced before CI finishes.
