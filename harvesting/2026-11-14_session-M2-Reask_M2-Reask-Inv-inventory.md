# M2-Reask-Inv: interactive prompt inventory, v1.0

Author: M2-Reask-Inv (for M2-Reask). Date: 2026-11-13. Worktree:
`C:\Users\jdpal\repos\aitools\.claude\worktrees\menus-reask` (all paths below are
relative to it). Line numbers are from this worktree as read today. They are for
this one-time edit; they will drift.

Method: Grep over `scripts/` and `shared/` for `Read-ConsoleChoice`,
`read_tty_choice`, `[Console]::ReadLine`, `Read-Host`, `ReadKey`, `$Host.UI`,
`PromptForChoice`, `read` at the start of a statement, `read -p/-n/-s`, `select ... in`,
`/dev/tty`, `[y/N]`, `[Y/n]`, and Python `input(`. Every call site was then read.
`packaging/` was also grepped: it has no prompts. `deploy/` was excluded (it is frozen
and still has the old raw `[Console]::ReadLine()` menus, which is expected). No
`select` menus, no `ReadKey`, and no Python prompts exist in scope.

Definitions used below:
- **Empty**: what a typed bare Enter does today.
- **Unrec**: what an answer outside the listed options does today.
- **EOF**: what happens when input ends (read_tty_choice / Read-ConsoleChoice log
  `No input at prompt (EOF) -- defaulting to <desc>` at warn level and return "").
- **NI/force**: behaviour in a non-interactive run (no tty / redirected stdin) and
  with `--force` / `AITOOLS_FORCE=1`.

---

## 1. scripts/aitools-lib.sh / scripts/aitools-lib.ps1 (the library)

| # | Function (sh / ps1) | Line sh / ps1 | Prompt text | Accepted | Empty | Unrec | EOF | NI / force | Parity | Class |
|---|---|---|---|---|---|---|---|---|---|---|
| L1 | `prompt_diff_review` / `Prompt-DiffReview` | read 2013 / 1994 (menu 1998-2035 / 1979-2025) | menu lines, then `  choice [o/a/m/s/x]: ` (adopt offered) or `  choice [o/s/x]: ` | a, m (only when adopt offered), s, x; lowercased. **There is no explicit `o` branch: `o` reaches the default branch.** | overwrite | overwrite. **`a` or `m` when adopt is NOT offered also overwrite** (sh 2015-2027, ps1 1996-2011) | overwrite (desc "overwrite") | Early return "overwrite" before any menu (sh 1917-1927, ps1 1896-1906). PS1 also returns overwrite when LOCAL cannot be read (1909-1915) | Options, text and order match. Minor: the [REVIEW] header is coloured in bash only (M1 territory) | CHOICE |
| L2 | `_invoke_ai_merge` / `Invoke-AiMerge` (preview) | 1736 / 1695 | `  [y]es accept / [r]efine / [n]o reject: ` | y, r (lowercased) | reject -> back to the review menu ("menu") | reject -> back to the review menu | reject (desc "reject the merge (back to the review menu)") | Unreachable: only via `[m]` in L1 | Match | CHOICE (EOF default = n) |
| L3 | `_invoke_ai_merge` / `Invoke-AiMerge` (refine) | 1700-1701 / 1659-1660 | `  refinement feedback: ` | any text | empty feedback sent to the AI | n/a | empty feedback (desc "no feedback") | Unreachable (via `[r]`) | Match | FREE-TEXT |
| L4 | `prompt_json_field_review` / `Prompt-JsonFieldReview` | 3575 / 3597 (menu 3554-3597 / 3576-3621) | `[REVIEW] <leaf> differs from <source>.` + values, then `  choice [o/a/s/x]: ` (adopt allowed) / `  choice [o/s/x]: ` / `  choice [a/s/x]: ` (field only in LOCAL, `$7`/`-OverwriteAllowed` = 0) | a (only when adopt allowed), s, x; **no explicit `o` branch: `o` reaches the default** | default_choice: overwrite, or skip when overwrite is not allowed | same as empty. **`a` when adopt is NOT allowed overwrites** (or skips when overwrite is also not allowed) | default_choice (desc "overwriting from <src>" / "skipping (only in <local>)") | Early return default_choice (sh 3543-3552, ps1 3567-3574). Callers: `review_json_fields` (sh 2430/2437, ps1 2448/2455; local-only fields are not prompted without an adopt target or a terminal: "keep") and `sync_managed_json` (sh 3830, ps1 3834; a fresh HOME takes overwrite without a prompt) | Match on options and order. M1 owns the display (value lines, labels) | CHOICE |

Notes for L4: the `[a/s/x]` prompt with adopt hidden (`overwrite_allowed=0` and
`adopt_allowed=0`) is unreachable today. The only `overwrite_allowed=0` caller (sh 2430 /
ps1 2448) passes adopt "1". After re-ask, VALID must be built from the same flags that
build the prompt line: `o` only when overwrite is allowed, and `a` only when adopt is allowed.

Library prompt helpers (M3 owns their bodies): `read_tty_choice` (sh 1640-1648) and
`Read-ConsoleChoice` (ps1 1602-1611). At EOF both print a newline, call
`log_warn`/`LogWarn` (which increments WARNINGS / `$script:warnings`) and return "".
The interactivity tests are `tty_interactive` (sh 1627-1632: `[ -t 0 ]` and /dev/tty
can be opened) and `Test-InteractiveConsole` (ps1 1598-1600: `UserInteractive -and -not
IsInputRedirected`).

**Overlap risk with M3:** M3 owns "the AI-merge spinner". `_start_spinner` /
`Start-AiSpinner` is called inside `_invoke_ai_merge` / `Invoke-AiMerge` (sh 1706, ps1
1665), which is the same function as L2 and L3. If M2 edits L2, coordinate the
change or put it in a separate batch.

## 2. scripts/aitools (bash entry point) / scripts/aitools.ps1 (user init and profile check)

All of these use `ui_can_ask` (sh 150-153: not --force, not AITOOLS_FORCE, and
`tty_interactive`) / `Test-UiCanAsk` (ps1 812-815) as the gate, except A1 (see its row).
Both scripts load aitools-lib (`aitools.ps1` from line 524), so a wrapper there is
available.

| # | Function (sh / ps1) | Line sh / ps1 | Prompt text | Accepted | Empty | Unrec | EOF | NI / force | Parity | Class |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | `check_profile` (migrate) / `Invoke-ProfileCheck` (migrate) | 108-109 / 120-121 | `Migrate profile.json to v2 now? [y/N]: ` | regex `^[Yy]`: any answer starting with y/Y is yes (e.g. "yes", "yep") | no | no | no (desc "no") | Not asked: sh gate is `mode=interactive && ui_can_ask` (106), ps1 is `Mode -eq interactive -and Test-UiCanAsk` (119). With no prompt, nothing is migrated | Match (ps1 also requires `profilePath`) | CHOICE (y/N; documented default N; empty is the safe answer) |
| A2 | `ui_choose` / `Read-UiChoose` | 395-396 / 1056-1059 | `Which profile is this machine?`, `  [N] <alias>` per unregistered profile, `  [-] ...` (not selectable), `  [n] new profile for this machine`, `  [s] skip`, `Choice: ` | 1..n (dynamic; n can be 0), n/N, s/S (no trim, no lowercasing) | **skip** (explicit: sh `[sS]\|"")`, ps1 `-not $choice`), log_warn, return 2 | log_warn `invalid choice '<x>' -- registration skipped`, return 2 | skip (desc "skip") | No terminal: log_error + ERROR row + ACTION, return 1 (sh 370-375, ps1 1033-1038) | Match | CHOICE (dynamic VALID; EOF default s) |
| A3 | `ui_choose` / `Read-UiChoose` (after `n`) | 402-403 / 1065-1066 | `New alias (e.g., laptop, workstation): ` | any text | registration skipped (log_warn, return 2) | n/a | skip | n/a | Match | FREE-TEXT (empty is a value: skip) |
| A4 | `ui_ask_name_company` / `Read-UiNameCompany` | 425-428 / 1087-1090 | `Display name for <alias> (Enter = identity name): `, `Company for <alias> (Enter = identity company): ` | any text | the identity's value | n/a | the identity's value | Not asked | Match | FREE-TEXT x2 |
| A5 | `ui_register` / `Invoke-UiRegister` (alias used by another machine) | 472-473 / 1128-1129 | `Alias "<v>" is used by another machine's profile (<key>). Use it for this machine too? [y/N]: ` | `[yY]*` / `^[yY]`: anything starting with y | no: log_warn, WARN row "skipped", return 2 | no (same) | no (desc "no") | No terminal: log_error + ERROR row + ACTION, return 1 (466-471 / 1122-1127) | Match | CHOICE (y/N; documented default N; empty is the safe answer, nothing written) |
| A6 | `ui_identity` / `Read-UiIdentity` | 586-591 / 1251-1259 | `Display name [<name>]: `, `Email [<email>]: `, `Company: ` | any text | keep the shown value (name, email); company empty | n/a | same | Not asked | Match | FREE-TEXT x3 |
| A7 | `ui_scaffold` / `Invoke-UiScaffold` | 604-605 / 1269-1270 | `Alias for this machine (Enter = hostname): ` | any text | the hostname | n/a | the hostname | Not asked (hostname) | Match | FREE-TEXT |
| A8 | `migrate_profile_v1_to_v2` / `Invoke-UiV1Migrate` | 762-763 / 1428-1429 | `Alias for this machine (Enter = hostname): ` | any text | the hostname | n/a | the hostname | Not asked | Match | FREE-TEXT |
| A9 | `ui_create_dotprofile` / `Invoke-UiCreateDotprofile` | 814-816 / 1483-1485 | `Create the private GitHub repo '<name>' and push? [Y/n]: ` | `[yY]*` / `^[yY]` | **yes** (explicit `ans="y"`) | **no**: anything not starting with y declines (WARN row "created, not pushed" + ACTION) | **yes** (desc "yes") | Not asked: `ans` stays "y", so the repo is created and pushed (with `GIT_TERMINAL_PROMPT=0` / BatchMode ssh) | Match | CHOICE (Y/n; documented default Y). **FLAG: the default is the acting answer, not the safe one** |
| A10 | `user_init` / `Invoke-UserInit` | 885-886 / 1563-1564 | `GitHub username: ` | any text | unknown: log_error + ERROR row + ACTION, return 1 | n/a | same (desc "none") | Not asked, same error | Match | FREE-TEXT (empty is a value: fail) |

## 3. scripts/aitools-install.sh / scripts/aitools-install.ps1

| # | Section | Line sh / ps1 | Prompt text | Accepted | Empty | EOF | NI | Parity | Class |
|---|---|---|---|---|---|---|---|---|---|
| I1 | Step 3 "repos directory" (top level) | 463-469 / 374-380 | sh `Where should new repos live? [~/repos]: `; ps1 `Where should new repos live? [<USERPROFILE>\repos]: ` | a path | default path | default path | default (`$HOME/repos`) | Text differs: bash shows `~/repos`, PS1 the full path. **The bash prompt is printed to stdout, not `> /dev/tty`** (463) | FREE-TEXT |

## 4. scripts/setup-user-hooks.sh / .ps1 and scripts/setup-user-skills.sh / .ps1 (reverse discovery)

| # | Script : section | Line sh / ps1 | Prompt text | Accepted | Empty | Unrec | EOF | NI / force | Parity | Class |
|---|---|---|---|---|---|---|---|---|---|---|
| H1 | setup-user-hooks : "Reverse discovery" (top level, inside the section build-deploy replaces) | 224-242 / 185-208 | `\n  User-created hook detected: <name>`, `  [a]dopt to dotprofile  [s]kip`, `  > ` | `a` or `adopt` | skip (log `Skipped adoption of <name>`) | skip | skip (desc "skip") | NI: log `Non-interactive: skipped adoption prompt for <name>`. `--force` does not change this menu (hook-lifecycle.md "Prompts in the hook deploy") | **Case gap: bash `case` is case-sensitive (`A` skips); PS1 `-in` is case-insensitive (`A` adopts)** | CHOICE (EOF default s; no [x]abort) |
| H2 | setup-user-skills : sh `reverse_discover_skills` (function, from 240); ps1 top-level block `if ($destSkillDirs.Count -gt 0)` (302-355); both inside the section build-deploy replaces | 283-301 / 329-351 | `\n  User-created skill detected: <name>`, `  [a]dopt to dotprofile  [s]kip`, `  > ` | `a` or `adopt` | skip | skip | skip | NI: log line as H1; `--dry-run` logs "Would offer..." | Same case gap as H1 | CHOICE |

Both are absent from the MDM path: build-deploy.sh has no prompt code (grep for
read_tty_choice, /dev/tty, ReadLine, Read-Host and `[a]dopt` in `scripts/build-deploy.sh`:
no matches). The reverse-discovery blocks sit in the sections that build-deploy replaces.
H2's bash code is the function `reverse_discover_skills`, but its PS1 twin is top-level
code, not a function (a structural asymmetry, not a menu difference).

## 5. scripts/relay-outbound-prompt.sh / .ps1

| # | Function | Line sh / ps1 | Prompt text | Accepted | Empty | Unrec | EOF | NI | Class |
|---|---|---|---|---|---|---|---|---|---|
| R1 | `relay_outbound_prompt` / `Invoke-RelayOutboundPrompt` | 74-89 / 64-72 | `  [c]ontinue  [q]uit (exit 2)  [s]how git status`, `  choice [c/q/s] (default c): ` | **Prefix match**: anything starting with q quits (return 2); anything starting with s shows `git status -sb` and then **continues (returns 0, no re-ask)** | continue (documented "(default c)") | continue | sh: **a bare `read -r choice < /dev/tty`**. At EOF `read` returns 1. Errexit is off inside the function because both callers run it under `\|\|` (aitools 2362 `\|\| return $?`, hh.sh 113 `\|\| exit $?`), so it continues with no log line. ps1: `Read-Host` returns $null, which becomes '' and continues | Skip when `AITOOLS_SKIP_RELAY_PROMPT=1`. Hint only when `CI` is set (unless `RELAY_PROMPT_FORCE`). sh: hint when /dev/tty cannot be opened (**no `[ -t 0 ]` test**). ps1: hint when `-not [Environment]::UserInteractive` (**no IsInputRedirected test**, so piped stdin is consumed by Read-Host) | CHOICE (ambiguous: see below) |

Rule deviations (pre-existing): the ps1 uses `Read-Host` and `Write-Host`, which the
interactive-menus.md "Console I/O" rule forbids. The sh uses a bare `read`.
Neither file sources aitools-lib, and neither do its `hh.sh` / `hh.ps1` callers (grep:
no `aitools-lib` in hh.*). `scripts/aitools` and `aitools.ps1` do load the lib. A
`read_menu_choice` / `Read-MenuChoice` call here would therefore fail when the prompt
runs from `hh`. The rule that governed this prompt, `.claude/rules/relay-outbound.md`,
was deleted on 2026-11-13 (scripts/check-path-refs-allow.txt:14). The root `CLAUDE.md`
still cites it (a known pre-commit step 20 failure).

## 6. shared/shell/aliases.sh / aliases.ps1 (user shell functions)

| # | Function | Line sh / ps1 | Prompt text | Accepted | Empty | Unrec | EOF | Class |
|---|---|---|---|---|---|---|---|---|
| S1 | `cc` | 12-13 / 10 | `Create one with 'claude /init'? [y/N] ` | exactly `y`/`Y` (`^[Yy]$`) | no | no | sh: bare `read -r answer` from stdin (EOF leaves it empty, so no). ps1: `Read-Host` | CHOICE y/N, suggested OUT of M2 scope |
| S2 | `clip2md` (explicit-name mode) | 252-253 / 275 | `<name> exists. Overwrite? [y/N] ` | exactly `y`/`Y` | "Aborted." (no write) | aborted | aborted | CHOICE y/N, suggested OUT of M2 scope |

These are sourced into the user's interactive shell. They cannot source aitools-lib
(cross-platform.md exempts "Shell alias modules" from the OS guard). They read stdin
with a bare `read` / `Read-Host`, not /dev/tty / Read-ConsoleChoice. Empty is the safe
answer in both.

---

## CHOICE (in scope for re-ask)

1. aitools-lib.sh:`prompt_diff_review` / aitools-lib.ps1:`Prompt-DiffReview` (L1). VALID `o a m s x`, or `o s x` without an adopt target. EOF default `o` ("overwrite"). Add an explicit `o` branch; `a`/`m` must re-ask when they are not offered.
2. aitools-lib.sh:`prompt_json_field_review` / aitools-lib.ps1:`Prompt-JsonFieldReview` (L4). VALID built from the flags: `o` if overwrite is allowed, `a` if adopt is allowed, plus `s x`. EOF default is default_choice (`o`, or `s` when overwrite is not allowed). Add an explicit `o` branch.
3. aitools-lib.sh:`_invoke_ai_merge` / aitools-lib.ps1:`Invoke-AiMerge` preview (L2). VALID `y r n`. EOF default `n` ("reject the merge (back to the review menu)"). Coordinate with M3 (spinner in the same function).
4. scripts/aitools:`ui_choose` / aitools.ps1:`Read-UiChoose` (A2). VALID `1..n n s` (dynamic). EOF default `s`. Today empty = skip: this changes to re-ask.
5. scripts/aitools:`check_profile` (migrate) / aitools.ps1:`Invoke-ProfileCheck` (A1). `[y/N]`. VALID `y n`. EOF default `n`. Today empty = no (safe).
6. scripts/aitools:`ui_register` / aitools.ps1:`Invoke-UiRegister` duplicate-alias confirm (A5). `[y/N]`. VALID `y n`. EOF default `n`. Today empty = no (safe).
7. scripts/aitools:`ui_create_dotprofile` / aitools.ps1:`Invoke-UiCreateDotprofile` (A9). `[Y/n]`. VALID `y n`. EOF default `y` (today). **FLAG: the default acts (creates and pushes a GitHub repo).**
8. scripts/setup-user-hooks.sh / .ps1 reverse discovery (H1). VALID `a s` (today also the word `adopt`). EOF default `s`. Fix the case parity at the same time.
9. scripts/setup-user-skills.sh / .ps1 reverse discovery (H2). Same as 8.
10. scripts/relay-outbound-prompt.sh:`relay_outbound_prompt` / .ps1:`Invoke-RelayOutboundPrompt` (R1). Ambiguous: see below.
11. shared/shell/aliases.sh / .ps1 `cc` and `clip2md` (S1, S2). Choice-shaped, but suggested out of scope: see below.

## FREE-TEXT (out of scope)

1. aitools-lib.sh:`_invoke_ai_merge` / .ps1:`Invoke-AiMerge`: `refinement feedback:` (L3)
2. scripts/aitools:`ui_choose` / aitools.ps1:`Read-UiChoose`: `New alias (e.g., laptop, workstation):` (A3)
3. scripts/aitools:`ui_ask_name_company` / aitools.ps1:`Read-UiNameCompany`: display name, company (A4)
4. scripts/aitools:`ui_identity` / aitools.ps1:`Read-UiIdentity`: display name, email, company (A6)
5. scripts/aitools:`ui_scaffold` / aitools.ps1:`Invoke-UiScaffold`: `Alias for this machine (Enter = hostname):` (A7)
6. scripts/aitools:`migrate_profile_v1_to_v2` / aitools.ps1:`Invoke-UiV1Migrate`: the same alias prompt (A8)
7. scripts/aitools:`user_init` / aitools.ps1:`Invoke-UserInit`: `GitHub username:` (A10)
8. scripts/aitools-install.sh / .ps1 Step 3: `Where should new repos live?` (I1)

## Ambiguous, with suggested answers

- **y/N confirms (A1, A5)**: they are CHOICE under the commander's "no default or other
  characters should re-ask". Empty is the safe answer today. Suggest: re-ask on empty, and
  keep the `[y/N]` capital letter only as the EOF default. Alternatively, drop the capital
  (`[y/n]`) so the prompt does not promise an Enter default it no longer honours. Suggest
  dropping it, because the prompt text would otherwise mislead. Accept `y n`; decide whether
  `yes`/`no` are VALID words (today any `y*` is yes). Suggest `y yes n no`, so nothing a
  user types today as a deliberate yes stops working.
- **[Y/n] (A9)**: the same, but its default acts. Suggest re-ask on empty, `[y/n]` text,
  and keep EOF = `y` only because NI/force already create and push (no behaviour change
  outside a terminal). Alternatively, make EOF = `n`. That is a behaviour change, so ask the
  commander.
- **ui_choose (A2)**: its default is explicit in code (`[sS]|""`). Suggest re-ask (the
  commander's words cover "default"), with VALID being the listed numbers plus `n s`. The
  golden menu filter (below) keeps passing as long as the re-ask hint does not start with
  `  [` and the prompt stays `Choice: `.
- **Relay prompt (R1)**: it is choice-shaped with a documented "(default c)". Suggest in
  scope, but as its own batch, because (a) neither the script nor hh.sh/hh.ps1 loads
  aitools-lib, so the wrapper is unavailable from `hh`; (b) the ps1 uses Read-Host and
  Write-Host. Options: source aitools-lib from relay-outbound-prompt.* (risky for hh.sh,
  which is sourced into the user's shell), or leave R1 out of M2 and file it. Suggest:
  leave it out of M2, report an `INCIDENT:` for its Console I/O and EOF deviations, and let
  the commander decide.
- **aliases cc/clip2md (S1, S2)**: suggest out of scope. They run in the user's own
  shell with no lib, empty is already the safe "no", and the rules exempt them as shell
  alias modules.
- **Reverse discovery word `adopt`**: suggest VALID `a adopt s skip`, so the existing
  `adopt` keeps working. The `please type one of` hint would then list four tokens. If that
  is unwanted, accept `adopt` as an alias of `a` outside VALID (needs a contract extension).

## Tests and golden files

Interactive tests drive prompts through `tests/managed-files/pty-run.py`. It sends one
input line each time the child goes quiet, and **never sends EOF when the input runs
out**: the child is killed at the 30 s timeout (exit 124). So any test that answers
with an empty or unrecognised line and then stops will time out after re-ask.

- `tests/managed-files/test-managed-files.ps1:185-187`, case "enter": input `"\n"`,
  asserts **"empty choice at the menu: overwrite"**. **This must change**: for example,
  input `"\ns\n"`, assert the re-ask hint and `skipped`, and assert the log line
  `menu answer (...): "" -> not one of o/a/m/s/x, asked again`. The bash suite has no such
  case; add one for parity.
- `tests/managed-files/test-managed-files.ps1:179-181`, case "eof": calls
  `Read-ConsoleChoice` directly with an empty `Console.In` (M3's body). Unchanged.
- `tests/managed-files/test-managed-files.sh:167-170`, case "eof": input `'\x04'`,
  asserts overwrite and the EOF warning. It stays valid if the wrapper maps EOF to the
  default.
- All other pty inputs found send only valid letters for the menu shown:
  test-managed-files.sh/.ps1 (`s a m y n x o` sequences, JSON `o\na\ns\na\n`),
  test-adopt-push.sh/.ps1 (`a`, `m\ny`), test-deploy-harness.sh:302-333 (`a` with an
  adopt target, `s`, `x`, and `a` under --force/AITOOLS_FORCE with no menu),
  test-rules-fanout.sh:437/443, test-skills-fanout.sh:575/581 (`a\na`, `x`),
  test-rules-fanout-cursor.sh:821/824 (`s`, `x`), test-skills-legacy.sh:440/449 (`a`),
  test-hookin.sh:272/308/375/384 (`x`), test-deploy-harness-mdm.sh:440/445 (`s`).
  I did not check that each `a` lands on a menu that offers `[a]`, except deploy-harness
  (an adopt target is passed: scripts/deploy-harness.sh:347).
- `tests/profile/test-user-init.sh:609-651` (drives both shells): pty-claim `1\n`,
  pty-hostname-other `s\n`, pty-dup-confirm `\n\ny\n`, pty-dup-decline `\n\nn\n` (the two
  empty lines answer the FREE-TEXT display name / company prompts A4, so they stay valid),
  pty-force `1\n` (no prompt). Line 636 asserts the exact confirm text
  `Use it for this machine too? [y/N]`. **If A5's text changes to `[y/n]`, update this
  assertion.**
- Golden: `tests/profile/golden/userinit-pty-claim-menu.txt` holds the menu lines picked
  by `perl -ne 'print if /^Which profile|^  \[|^Choice/'`, with `Choice: .*` normalised
  (test-user-init.sh:617). It is shared by sh and ps1. A re-ask hint such as
  `  please type one of 1/n/s` does not match the filter, so the golden is unaffected. A
  hint starting with `  [` would break it. The other `userinit-pty-*.txt` goldens hold the
  exit code, summary rows, profile.json and commits; they are unaffected while the answers
  stay the same.
- Grep for menu text across all `tests/**/golden/` found nothing else (`choice [`,
  `[o]verwrite`, `[s]kip`, `please type`, `No input at prompt`, `menu answer`: matches only
  in test-managed-files.sh/.ps1 and test-rules-fanout-cursor.sh, none in golden files).
- No test drives A1, A9, A10, H1/H2 interactively, R1, or S1/S2 (grep for their prompt
  texts in tests/: no matches). test-skills-legacy.sh covers reverse discovery only in
  `found ...` / non-interactive form, plus the pty `a\n` adopt at 440/449.

## check-post-push steps 29 / 30 (scripts/check-post-push.sh; twin check-post-push.ps1)

- Both run only with `--extensive` (`$EXTENSIVE` / `$Extensive`).
- **Step 29** "Deployment menu parity audit" (sh 744-757, ps1 881-896): scans
  **only** `scripts/aitools-lib.ps1` and `scripts/aitools-lib.sh`. PS1 lines matching
  `Console.*Write.*\[(\w)\]` and bash lines matching `printf.*\[(\w)\]` (perl: greedy, so
  the LAST single-letter bracket on a line; ps1 Select-String -AllMatches) are reduced to
  sorted unique letter sets, and the two sets are compared. Implications for M2:
  - Menu option lines must stay literal `[Console]::WriteLine("  [o]...")` / `printf '  [o]...'`
    in the library, or they drop out of the audit (a set comparison will still pass if both
    drop out, silently).
  - The prompt line `choice [o/a/m/s/x]` does not match (`\w` is one character), so passing
    it as a wrapper argument changes nothing. A re-ask hint without brackets is invisible
    to the audit.
  - Not covered: scripts/aitools, aitools.ps1, setup-user-hooks/skills, relay-outbound-prompt
    and aliases. Parity there is checked only by tests (golden menu for A2).
- **Step 30** "Return value coverage audit" (sh 759-790): compares the
  `MANAGED_FILE_RESULT="..."` values in aitools-lib.sh with mentions in
  `scripts/setup-user-claude.sh`. `sh_tracker`, `ps1_returns` and `ps1_tracker` are
  computed but **unused**. ps1_returns' regex `return\s+"([\w-]+)"` would pick up the
  menu returns ("overwrite", "adopt", "skip", "menu", "merge") but feeds nothing. Menu
  code is invisible to step 30.
- **Step 31** "Deployment state machine sync" (sh 795-816) uses flip-flop ranges that
  start at `^deploy_managed_file\b` / `^function Deploy-ManagedFile\b` and
  `^deploy_tracker_record\b` / `^function Record-DeployOutcome\b`. A wrapper placed
  right after `read_tty_choice` / `Read-ConsoleChoice` (sh ~1649, ps1 ~1612) is outside
  those ranges. Do not put a `return "<word>"` or `MANAGED_FILE_RESULT=` line inside them.

## Spec text that still says "unrecognised = overwrite" (for M2's spec batch)

- `reference/managed-file-deployment.md:165`: "An unrecognised answer selects
  `overwrite`, as today."
- Library comments: aitools-lib.sh 1637-1638 ("so each caller's `*)` default branch
  applies") and aitools-lib.ps1 1594-1596 ("so each caller's default branch applies").
  These sit in the read_tty_choice / Read-ConsoleChoice headers, so coordinate with M3.
- `.claude/rules/interactive-menus.md` "Non-interactive fallback" and
  `.claude/rules/agentic-standards.md` say nothing about an unrecognised answer (grep for
  "unrecogni", "Enter" and "empty" in .claude/rules: no menu matches). Add the re-ask rule
  there.
- `.claude/rules/hook-lifecycle.md` "Prompts in the hook deploy" defines only EOF and NI
  for reverse discovery. Add the re-ask rule if H1/H2 change.

## Not checked

- `deploy/` (frozen; old menus left as they are), `harvesting/`, `.scratch/`.
- Prompts run by external programs (`gh auth login`, git credential prompts): they are
  not ours.
- `reference/user-repo.md` "Registration" was not read in depth for menu wording (grep for
  the menu strings there: no matches).
- I did not run any test or script. This is static reading only. I did not create the
  `.scratch/session-M2-Inv/` scratch directory, because I needed no helper script.
