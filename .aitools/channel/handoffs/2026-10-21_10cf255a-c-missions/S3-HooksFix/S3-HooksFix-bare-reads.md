# S3-HooksFix: remaining bare /dev/tty reads (2026-10-21)

INCIDENT: EOF-unsafe bare `read -r <var> < /dev/tty` calls remain in reusable
scripts after #81 fixed setup-user-hooks. Under `set -e`, a bare read that hits
EOF (closed stdin under a pty) returns 1 and aborts the caller with no log line
and no summary row (the #81 / GitHub #29 failure mode; reproduced for
setup-user-hooks in `S3-Hooks/S3-Hooks-verification.md` section 3, row
B-control). Not changed here: the scripts are owned by other missions or out of
this mission's scope. For the session commander to triage.

- **Expected** (spec): the `S3-HooksFix-drafts/shared/rules/hook-lifecycle.md` draft "Prompts" and
  `.claude/rules/interactive-menus.md` "Non-interactive fallback": EOF at the
  prompt logs a warning and takes the default. Library helpers:
  `read_tty_choice <var> <default-desc>` (`scripts/aitools-lib.sh`, defined at
  line 787: logs `No input at prompt (EOF) -- defaulting to <desc>` via
  `log_warn` and returns 0 with an empty value) and `Read-ConsoleChoice
  <DefaultDesc>` (`scripts/aitools-lib.ps1`, line 777). Gate:
  `tty_interactive` / `Test-InteractiveConsole`.

## Bash: bare reads (grep, origin/main db4b3c5)

Command: `grep -rnE 'read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*[A-Za-z_]+[[:space:]]*<[[:space:]]*/dev/tty' scripts shared`
(lib lines 783 and 789 are the helper itself and are excluded).

| File:line | Current | EOF-safe replacement |
|-----------|---------|----------------------|
| scripts/setup-user-skills.sh:200 | `read -r choice < /dev/tty` | `read_tty_choice choice "<default>"` (diff/skill menu default) |
| scripts/relay-outbound-prompt.sh:77 | `read -r choice < /dev/tty` | `read_tty_choice choice "continue"` (menu default is `c`) |
| scripts/aitools:108 | `read -r answer < /dev/tty` | `read_tty_choice answer "no"` (`[y/N]` migrate prompt) |
| scripts/aitools:157 | `read -r machine_alias < /dev/tty` | `read_tty_choice machine_alias "<hostname default>"` |
| scripts/aitools:957 | `read -r gh_user < /dev/tty` | `read_tty_choice gh_user "<existing default>"` |
| scripts/aitools:1058 | `read -r machine_alias < /dev/tty` | `read_tty_choice machine_alias "<default>"` |
| scripts/aitools:1062 | `read -r prof_name < /dev/tty` | `read_tty_choice prof_name "<default>"` |
| scripts/aitools:1066 | `read -r prof_company < /dev/tty` | `read_tty_choice prof_company "<default>"` |
| scripts/aitools:1118 | `read -r prof_name < /dev/tty` | `read_tty_choice prof_name "<USER default>"` |
| scripts/aitools:1122 | `read -r prof_email < /dev/tty` | `read_tty_choice prof_email "empty"` |
| scripts/aitools:1125 | `read -r prof_company < /dev/tty` | `read_tty_choice prof_company "empty"` |
| scripts/aitools:1128 | `read -r machine_alias < /dev/tty` | `read_tty_choice machine_alias "<default>"` |
| scripts/aitools:1181 | `read -r create_gh < /dev/tty` | `read_tty_choice create_gh "no"` (`[y/N]`) |

The `<default>` descriptions must be taken from each call site's own default
handling; I did not read every site's default logic (unknown for the rows marked
`<...>`). `scripts/aitools` is an entry point: confirm it sources `aitools-lib.sh`
before the first of these reads (not verified here).

## PowerShell pairs (same grep idea; not EOF-tested)

`Read-Host` / bare `[Console]::ReadLine()` outside the lib:
scripts/aitools.ps1:119, 147, 883, 989, 994, 999, 1049, 1051, 1052, 1053, 1110;
scripts/setup-user-skills.ps1:188 (`[Console]::ReadLine()` -> `$null` at EOF, no log);
scripts/relay-outbound-prompt.ps1:65; shared/shell/aliases.ps1:10, 275.
Replacement: `Read-ConsoleChoice "<default>"` behind `Test-InteractiveConsole`.
`Read-Host` behavior at EOF / redirected stdin was not tested on this machine
(unknown); `interactive-menus.md` "Console I/O" already says PS1 must not use
`Read-Host`.

## Suggested resolution

One change per owning mission: setup-user-skills.* (S3-SourceTruth owns
setup-user-skills), scripts/aitools + aitools.ps1 and relay-outbound-prompt.*
(unowned this session; suggest a follow-up `fix/tty-reads` branch). Each change:
swap the read, `bash -n` + pwsh parser, and a pty-at-EOF run under an isolated
`HOME` (the S3-Hooks B / B-control pattern).
