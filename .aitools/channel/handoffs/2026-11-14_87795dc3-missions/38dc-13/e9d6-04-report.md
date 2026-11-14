# e9d6-04-port-rules-cursor: report (v1.0)

Version 1.0, 2026-11-14. Author: e9d6-04-port-rules-cursor (delegated by 38dc-13).

**Intent**: **Purpose**: report the port of tests/rules-fanout-cursor to a native
PowerShell Windows harness and the macOS/Linux-only .sh harness, with the
verification evidence. **Scope**: the three suite files, local Windows runs,
mutation proof, guard, syntax. NOT golden files, tests/lib, product scripts,
CI workflow or docs. **Audience**: 38dc-13 (verifies, commits, ships).

## Summary

1. New `tests/rules-fanout-cursor/test-rules-fanout-cursor.ps1` (Windows, native pwsh): every case the .sh ran on Windows, same 151 check lines in the same order.
2. Local run: 145 passed, 0 failed, 6 skipped -- identical PASS/SKIP lines to the .sh harness's Windows CI run on main (145/0/6).
3. `.sh` harness: the contract guard (BASH_VERSINFO[5] form, per 38dc-13's correction) and every ps1/Windows branch removed; macOS/Linux behaviour unchanged.
4. Mutation proof: 5 of 6 mutations fail the suite with exit 1 (golden line, expected row, AITOOLS_DRY_RUN env, converter marker, glob-port anchor); 1 survives as an equivalent mutation for this suite's inputs (glob `**/` matching zero directories, untested by the .sh suite too).
5. No product bug found; no golden or tests/lib file touched.

## What Windows-reached code the suite tests

- `scripts/setup-user-cursor.ps1`, whole script (steps 1-4; step 4 is the rules fan-out under test), run as a child `pwsh -NoProfile -NonInteractive -File` under a temp HOME/USERPROFILE with stub `rg.cmd` / `agent.cmd` first on PATH, through `Invoke-TestScript`.
- `scripts/aitools-lib.ps1` (dot-sourced by setup-user-cursor.ps1: Deploy-ManagedFile, Backup-File, the deploy tracker, the rules-manifest reader).
- `ConvertTo-CursorRule` and `$cursorFanoutMarker` from setup-user-cursor.ps1, through `tests/rules-fanout-cursor/convert-rule.ps1` (loaded from the script's AST; the script body never runs), run as a child pwsh.
- The review menu on a ConPTY: `tests/managed-files/pty-run.py` (pywinpty) running the whole setup-user-cursor.ps1 interactively.

## Class

Class c: a .ps1 equivalent was written. No case needed Git Bash: the suite tests
no cross-platform bash code on Windows (the bash converter and setup-user-cursor.sh
are POSIX-only), so `Resolve-TestGitBash` is not used.

Ported, not run through Git Bash:
- `glob_match` (a perl model of Cursor's glob matcher) is ported to PowerShell
  (`GlobMatch`: the same token rules, quotemeta -> [regex]::Escape, \A...\z, perl
  split's trailing-empty-field rule), because perl is on a native pwsh PATH only
  when Git's usr\bin is (locally yes, by accident of PATH; not guaranteed).
- `tree_sig` (perl File::Find + md5) -> `TreeSig` (Get-ChildItem -Recurse -File
  -Force, MD5.HashData, the same .bak.TS normalization, ordinal sort).
- The frontmatter glob scan (RESOLVE_BAD / RESOLVE_COUNT) -> a PowerShell loop
  with the same per-file line-1 rule.
- grep patterns: each BRE pattern was translated by hand (BRE `(`, `)` are
  literal, escaped for .NET; `\|` alternation -> `|`); `-x` / `-F` forms became
  exact-line / Contains helpers. ANSI codes and CRs are removed from the console
  output and summary before matching (as the .sh's strip_cr did); the .mdc files
  are compared raw (no CR removal), which is stricter than Git Bash's grep, and
  passes.

## CI count vs local count

- CI (main, `ci-windows-main.log`, "Run bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh"): 145 passed, 0 failed, 6 skipped, 151 check lines.
- Local (`pwsh -NoProfile -File tests/rules-fanout-cursor/test-rules-fanout-cursor.ps1`, Windows 11, pwsh 7, exit 0): 145 passed, 0 failed, 6 skipped (windows: ps1 scripts), 151 check lines.
- Compared by `.scratch/session-e9d6-04/compare.py`: IDENTICAL, same check lines in the same order (including `resolve: the repo's path-scoped rules produce globs (count 58)` and `force: overwrite (-Force)`). The run log has no other line than the checks and the final count.
- Differing lines: none. The final line adds `(windows: ps1 scripts)`, as the exemplar does.

The 6 SKIP lines are kept with the CI text, on purpose:
- `dupcase` -- a real probe (NTFS holds one file for Foo.md/foo.md), as in the .sh.
- `broken`, `drydup`, `dangtarget` (dangling symlinks) and `unreadable`, `unreadsrc` (chmod 000) -- not ported: printed unconditionally with the CI text, with a comment. Reason: a dangling native symlink needs administrator rights or Developer Mode (locally `New-Item -ItemType SymbolicLink` fails: "Administrator privilege required for this operation."), so these cases could never be run here; on the CI runner (admin) they would run for the first time against setup-user-cursor.ps1, unverified. chmod 000 has no NTFS effect; a deny-ACL port was not attempted. Both are the existing follow-up "Windows symlink / chmod / read-only coverage" of plans/ci-platform-targeting.md.

## Mutation results

Script: `.scratch/session-e9d6-04/mutate.ps1` (edits one suite file, runs the
harness, restores the exact bytes in `finally`; each file verified byte-identical
after restore).

| Mutation | File | Result |
|---|---|---|
| a: golden line changed (`... 1 verified` -> `2 verified`) | golden/users.result | exit 1; FAIL `parity: users: ...` (144/1/6) |
| b: expected row changed (`2 added` -> `3 added`) | test-rules-fanout-cursor.ps1 | exit 1; FAIL `first: OK row 2 added` (144/1/6) |
| c: env variable: `AITOOLS_DRY_RUN = "1"` in Run-Script | test-rules-fanout-cursor.ps1 | exit 1; 60 FAILs (85/60/6), e.g. `first: plain.md -> plain.mdc`, `force: overwrite (-Force)` |
| d: converter marker argument dropped in Conv | test-rules-fanout-cursor.ps1 | exit 1; 15 FAILs, e.g. `convert: marker after frontmatter`, `parity: users`, `parity: aitools`, `parity: bracket` |
| e: glob model `(?:.*/)?` -> `(?:.*/)` | test-rules-fanout-cursor.ps1 | SURVIVED (exit 0, 145/0/6): equivalent for this suite: no case has `**/` matching zero directories; the .sh suite's perl model has the same inputs and the same blind spot |
| f: glob port anchor `\A` removed | test-rules-fanout-cursor.ps1 | exit 1; FAIL `resolve: un-anchored scripts/** does not (the defect)` (144/1/6) |

After the mutations: `git status --short tests/rules-fanout-cursor` shows only
` M convert-rule.ps1`, ` M test-rules-fanout-cursor.sh`, `?? test-rules-fanout-cursor.ps1`;
`git diff --stat -- tests/rules-fanout-cursor/golden` is empty. A final clean run
after the mutations: 145 passed, 0 failed, 6 skipped, exit 0, again IDENTICAL to
the CI check lines.

## Syntax and guard

- `bash -n tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`: no output, exit 0.
- PowerShell parser (`.scratch/session-e9d6-04/parse-check.ps1`, `Parser]::ParseFile`) on test-rules-fanout-cursor.ps1: parse ok.
- Guard: `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` in Git Bash: exit 1, stderr `This script is for macOS/Linux. On Windows, run tests/rules-fanout-cursor/test-rules-fanout-cursor.ps1 with pwsh.`; the guard runs before `mktemp`, so nothing is written. This is the only .sh run.
- `tests/os-guards/classify-guards.pl` on the suite files: `posix tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`, `win tests/rules-fanout-cursor/test-rules-fanout-cursor.ps1` (the .sh passes the BASH_VERSINFO[5] test-suite check). convert-rule.ps1 is not classified (not a test-*.ps1 entry point).

## Files changed

- `tests/rules-fanout-cursor/test-rules-fanout-cursor.ps1` (new, LF): the Windows harness.
- `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` (edit): header platform paragraph and `--bash-only` line updated (header length unchanged, so `--help` still prints lines 2-33); the guard as the first statement after `set -uo pipefail`; removed LANG_RUN, SCRIPT_PS1, HELPER_PS1, the pwsh-on-PATH check, the .cmd stubs, run_script's ps1 branch, strip_cr, force_note (check name kept as the literal `force: overwrite (--force)`, what it printed on macOS/Linux), conv's ps1 branch, the winpty probe and run_pty's ps1 branch; comments that named Git Bash or Windows runs updated. Check names and output on macOS/Linux are unchanged; the pty SKIP text `(python3 not found; on Windows also pywinpty)` is kept verbatim so the output stays identical.
- `tests/rules-fanout-cursor/convert-rule.ps1` (edit, comment only): its header said it is used by the .sh on Windows "called from Git Bash"; now it names the .ps1 harness and the child-pwsh call. No code change.

## Deviations from the .sh, each deliberate

- Run-Script and Run-Pty remove `AITOOLS_FORCE` and `AITOOLS_DRY_RUN` from the child's environment (the .sh's run_script inherited them; its run_pty removed them). A value in the runner's environment would otherwise change every case; neither is set in CI, so the CI result is unchanged.
- `upper: Up.MD -> Up.mdc` checks the listed name `Up.mdc` with an ordinal comparison, because NTFS `Test-Path` would also accept a wrong-case `up.mdc`; on Linux the .sh's `[ -f ]` is case-sensitive anyway.
- The converter's empty rule-name argument is not passed (convert-rule.ps1 defaults it to ""), to avoid relying on native empty-argument passing.
- Check takes a scriptblock and requires exactly one [bool]; an exception or extra output is a FAIL with the reason (the exemplar's stray-output lesson, made structural).

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none (no product deviation found; every case matched its golden result).
- CONFLICT: prompt contract item 5 (second guard case on `${OSTYPE:-}`) vs 38dc-13's CONTRACT CORRECTION message (second case on `${BASH_VERSINFO[5]:-}`, with evidence that an exported OSTYPE overrides bash's value) -- resolved by tier 2 (the delegating agent's newer amendment to its own prompt; no commander words on this point): used the BASH_VERSINFO[5] block verbatim.
- WRITE_BLOCKED: none.

## Contract change requests

None. Two notes for tests/lib owners (not requests): `Invoke-TestScript` worked
unchanged for the python3/pywinpty child; a shared `TreeSig`/md5 helper may be
worth having if other suites port perl `tree_sig` too.

## Open questions

1. Should the dangling-symlink cases (broken, drydup, dangtarget) run on the Windows CI runner, where the runner is an administrator and `New-Item -ItemType SymbolicLink` would work? Suggested answer: yes, in a follow-up that can watch one CI run: replace the three unconditional SKIPs with a probe (create a dangling link; SKIP when it fails), and treat any FAIL as a product parity finding (dangtarget has golden files ready).
2. Should `unreadable` / `unreadsrc` get a deny-ACL port? Suggested answer: yes, in the same follow-up (icacls deny read for the current user, removed in `finally`), verified locally first since ACLs need no admin.
3. Mutation e shows no case tests `**/` matching zero directories (e.g. `**/CLAUDE.md` vs `CLAUDE.md`). Suggested answer: add one resolve case to both harnesses in a separate change (needs no golden file).

## Operational learning (new)

- PowerShell command precedence is Alias > Function: helper functions named `ls`, `md` or `cat` are shadowed by the built-in aliases on Windows. Name them otherwise (ListNames, MkDirs, CatText).
- A function that returns `, @(...)` (unary comma) hands its caller one array object; `@(f)` then has Count 1. Return lists unrolled and wrap at the call site with `@()`.
- The Edit tool's `replace_all` dropped a trailing space of `new_string` here (`(Ls ` -> `(ListNames` with no space): end replacement strings on a non-space character.
- Native pwsh child runs of setup-user-cursor.ps1 match the goldens without any MSYS variable (TERM, MSYSTEM, Git usr\bin on PATH); nothing in this suite depended on the Git Bash environment.
- Timing (not measured precisely): a full local harness run goes past the foreground Bash limit (about 180 s), so run it in the background; it starts about 40 child pwsh processes for the converter plus about 35 script runs.
- In a `-File` script, `$args` inside a `Where-Object { }` block is that block's own (empty) `$args`: copy the script's `$args` to a variable first (my mutation selector silently selected nothing until I did).
