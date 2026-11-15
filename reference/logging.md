# Logging Standard (aitools)

**Intent**: **Purpose**: Single source of truth for the aitools logging
standard: where logs live, how they rotate, how paths are formed per
platform, the log-line format, which code may write logs, and how warnings
and errors are recorded across the scripts of one run and shown in the
end-of-run panel. **Scope**: The decided standard and its rationale,
including the run summary file format and the panel template (section 8),
and the effect each logging helper has on logs, counts and the run summary
file. NOT when a script should use which helper, or the script block order
(`@.claude/rules/script-standards.md` +
`@reference/script-standards-detail.md`, which point here for the helpers'
effects). NOT check-vs-setup semantics beyond noting they share the
directory. **Audience**: Every agent or script that emits logs, and anyone
changing the logging substrate (`aitools-lib.{sh,ps1}`, `harness-db.py`,
`ait-harvest.py`, hooks, check-lib).

v2.0 (2026-11-15): section 8 added: log entries, warnings and errors across
scripts.

v2.1 (2026-11-15): error markers extended; the non-recording path,
library-style tools, managed-file records, user-abort recording and skipped
records stated.

v2.2 (2026-11-15): a nested abort is recorded once; the relay's mirror and
quiet options; streamed output that fails is logged twice.

> Ratified 2026-06-14 as part of the harvest/archive/logging plan
> (`plans/harvest-archive-resilience.md` §14). This doc consolidates logging
> decisions previously scattered across `script-standards.md`,
> `script-standards-detail.md`, `cross-platform.md`, and `hook-rollout.md`.

## Decisions

### 1. Location — one cross-platform directory: `~/.aitools/logs/`

ALL aitools logging goes to **`~/.aitools/logs/`** on macOS, Windows, Linux
(and future platforms). This **overrides** the previous deliberate 3-way
native-directory split:

| Platform | OLD path (superseded) | NEW path |
|----------|----------------------|----------|
| macOS    | `~/Library/Logs/aitools/` | `~/.aitools/logs/` |
| Linux/Win (bash) | `${XDG_STATE_HOME:-~/.local/state}/aitools/` | `~/.aitools/logs/` |
| Windows (PS1) | `%LOCALAPPDATA%\aitools\` | `~/.aitools/logs/` |

**Rationale.** aitools logs are internal diagnostics shipped to Datadog (via
the harness DB, not log tails) — they are not consumed by OS-native log
tooling, so the native-dir convention buys nothing here. Uniformity and
discoverability win, and the move **dissolves a latent Windows bug**: bash
(`~/.local/state`) and PS1 (`%LOCALAPPDATA%`) previously disagreed, splitting
logs by writer. `~/.aitools/` is already the user-scoped namespace (config,
deploy-state, proposed telemetry — see `@.claude/rules/aitools-workspace.md`),
so `logs/` joins it naturally.

**Override**: `AITOOLS_LOG_DIR` replaces the directory for every lib-based
writer (bash and PowerShell). Tests and `check-pre-push` step 7 set it to a
temp dir; the package path's macOS postinstall (a stub today) is designed to set `/Library/Logs/aitools`
(BP-16, `@plans/build-package/design.md`) because it runs as root before any
user HOME exists.

### 2. Path separators — native per language

Form the path using each language's native idiom; never hardcode a separator:

- **bash**: `"$HOME/.aitools/logs"` — forward slashes are valid in Git Bash.
- **PowerShell**: `Join-Path $HOME ".aitools" "logs"` — yields backslashes on Windows.
- **Python**: `pathlib.Path.home() / ".aitools" / "logs"` — native per OS.

**Exception**: when a path is written **into a bash command string** (e.g. a
hook `command` in `settings.json`, `bash "<path>"`, which Claude Code hands to
`sh -c` on macOS and Linux and to Git Bash on Windows:
`reference/tool-ops-claude-code.md` item #8),
use forward slashes regardless of host OS.

### 3. Granularity — per-component log files

Each component writes its own file so "did hook X fire?" is answerable by
reading one file:

| File | Writer |
|------|--------|
| `deploy.log` | every script that section 8.1 brings under the library, through `aitools-lib` (`logging_init` / `Initialize-Logging`), including the entry points and `build-deploy.sh`; the PowerShell `[RELAY]` prompt under `hh.ps1` (script name `relay-outbound`: its menu answers) |
| `deploy.jsonl` | `jsonl_record` / `Write-JsonlRecord` in `aitools-lib`, called by the library's `log` / `Log` when the jsonl option is set (the installers set it) and by the child relay (`run_child_relayed` / `Invoke-ChildRelayed`); one JSON record per line, fields `ts, host, os, script, run_id, level, msg`; one `run_id` per installer run (`AITOOLS_RUN_ID`, inherited by relayed children); an unwritable file is one warning, then records are skipped |
| `ait-harvest.log` | `scripts/ait-harvest.py` |
| `session-archive.log` | `session-archive.sh` shim (bash-fallback branch only) |
| `session-catchup.log` | `session-catchup.sh` shim (bash-fallback branch only) |
| `harvest-session.log` | `harvest-session.sh` shim (bash-fallback branch only) |
| `harness-db.log` | `scripts/harness-db.py` (was `deploy.log`) |
| `checks.log` / `checks.jsonl` | check/audit scripts (via `check-lib`) |
| `standing-order-guard.log` (and `<hook-name>.log`) | PreToolUse hooks, observe-mode checks only (`@.claude/rules/hook-rollout.md`); absent while every check enforces |
| `clip2md.log` | `clip2md` in `shared/shell/aliases.sh` / `.ps1` |

Note: the SessionEnd/SessionStart shims pass raw stdin to the Python helper,
which logs to `ait-harvest.log`. The per-shim `*.log` files capture ONLY the
bash-fallback branches (no Python / no helper / non-zero exit) — see
plan §20.2 C3.

### 4. Rotation — size-based, 5 MB × 5 backups

No rotation existed before. Standard everywhere:

- **maxBytes = 5 MB**, **backupCount = 5** (`<name>.log` → `<name>.log.1` … `.5`).
- **Python**: `logging.handlers.RotatingFileHandler` (stdlib).
- **bash**: size check in `logging_init` (`stat` size via `uname -s` dispatch →
  `mv` chain). No perl.
- **PowerShell**: size check in `Initialize-Logging` (`.Length` → `Move-Item` chain).

Same maxBytes/backupCount in all three.

### 5. Format — unchanged

`[<utc-Z>] [<script>] [<level>] <msg>`

- Levels: `info | ok | warn | error | detail`.
- File output: plain text (no ANSI).
- Console output: ANSI color for `warn` (yellow) / `error` (red); plain otherwise.
- `detail` is file-only (never console).
- Timestamps: UTC with `Z` suffix.
- **Fail-safe**: logging must never crash the tool. A failed log write is
  swallowed (the only sanctioned silent-suppression in the harness) (section
  8.3 extends it to run summary records), because a
  broken log must not break the operation it records. In `aitools-lib` every
  `deploy.log` write (`log`, `log_detail`, `_ai_log` / `Log`, `LogDetail`,
  `Write-AiLog`) goes through `_aitlib_log_append` / `Add-AitLibLogText`: a
  locked, unwritable or missing log never ends the run (not under `set -e`, not
  under `$ErrorActionPreference = "Stop"`), the console line still prints and
  the counters still count; a log directory that cannot be created is the same
  case (v0.77.1). The installers' jsonl writing and the profile resolver's
  stderr console are library options, and check-lib's `checks.log` /
  `checks.jsonl` writes (`_aitlib_log_append` with the file as its argument;
  `Write-CheckLogText` in PowerShell) use the same helpers; check-lib's log
  directory is created fail-safe too. The `aitools` entry points and
  `build-deploy.sh` log through the library (section 8). Not fail-safe yet
  (open incident #178): the hook `tool-ops-session-audit.sh` (its result
  line), listed in section 8.1.
  `deploy.jsonl` differs: its first failed write is one warning (the table in
  section 3).

### 6. Setup-vs-check separation preserved

Setup scripts (OK/WARN/ERROR semantics, `deploy.log`) and check scripts
(PASS/FAIL/WARN/SKIP semantics, `checks.log`/`checks.jsonl`) keep distinct
files and distinct vocabularies — now in the **same** directory. See
`@reference/script-standards-detail.md` "Logging architecture: setup vs check"
for the bridge pattern (`check_log_init`/`CheckLogInit`).

### 7. Library-style tools return diagnostics; callers log them at level

A library-style tool is a script that other scripts call for data:
`scripts/aitools-profile.sh` / `.ps1` today. Its contract:

- **Data** goes to stdout only (`key<TAB>value` lines, or one JSON object with
  `--json`).
- **Diagnostics** are returned, not logged at level: every warning and error is an
  output line (`warn<TAB>...`, `error<TAB>...`) and is also written to `deploy.log` at
  `detail`. Its console log lines go to stderr (the library's stderr console
  option), so they never mix with data.
- **Summary rows, counters and the exit footer belong to the caller.** The tool writes
  no `write_summary` row and touches none of its caller's counters (its own counters,
  raised only by its OS guard and lib helpers such as `backup_file`, end with its
  process). It sets the library's stderr console option, which also turns recording
  off: its helpers log and count but write no record (its warnings and errors reach
  the run summary through its caller, below).
- **The caller** logs each returned line at its level -- `warn` with `write_warn
  <tool>` or `log_warn` (counted, recorded), `error` with `write_error <tool>
  <what> <the resolver's error line>` (counted, recorded) -- unless the caller documents why a
  class of warnings is handled another way. Documented exceptions today: the
  `aitools-lib` wrappers log resolver warnings at `detail`, because
  `setup-user-config`, the first script of every run, reports them once; and
  `setup-user-config` logs warnings that its own write corrects as `info`, and turns
  advice the user must act on into `write_action` (one warning that says what to
  do, and one ACTION).
- **Exit codes** are the tool's own (documented in its header and `--help`). A caller
  never passes them through as its own exit code (exit 2 from a setup script means a
  user abort, D-TS13).

### 8. Log entries, warnings and errors across scripts

#### 8.0 Terms

- **Entry point**: a script that starts a run: `aitools`, `aitools install`,
  `aitools user init`, `build-package.sh`.
- **Run**: one invocation of an entry point, together with every script it
  runs.
- **Child**: a script that an entry point (or another script) runs as a
  separate script.
- **Relay**: the library's child runners, which run a child and relay its
  output: `run_child_relayed` (bash), `Invoke-ChildRelayed` (an in-process
  PowerShell child) and `Invoke-NativeRelayed` (a native command from
  PowerShell). Also the captured-output relays `relay_child_log` and
  `Send-ChildLog`.
- **Record**: one line of the run summary file.
- **Panel line**: one line of the end-of-run panel.
- **Tool**: a name from the tool name table
  (`@reference/script-standards-detail.md` "Tool name table").
- **Script name**: the name a script passes to `logging_init` /
  `Initialize-Logging`; it is the `<script>` field of the script's log lines.

Tool names and script names share one namespace: a script whose name equals a
tool name is that tool.

#### 8.1 Writers

Every bash and PowerShell script under `scripts/` (the setup scripts, the
entry points, the installers, `build-deploy.sh`, `build-package.sh` and the
helper scripts, the extensionless ones included) writes log entries and run
summary records only through the `aitools-lib.sh` / `.ps1` helpers (8.2). It
defines no logging functions of its own, and appends to no log or run summary
file directly. The only exceptions are the writers below.

These writers keep their own logging until the unified-logging roadmap item
(GitHub issue #187) is implemented:
- the hooks (their own log files, section 3, and their `events.jsonl`
  records);
- the Python tools (their component logs, section 3);
- the Perl helpers (they write no log file: diagnostics on stderr only);
- `shared/shell/aliases.*` (`clip2md.log`);
- the check library and the check scripts that log through it (`checks.log` /
  `checks.jsonl`, section 6);
- the package launcher stubs under `packaging/`;
- the files and code paths that execute without the library. They write to
  the console only and record nothing, except the truncation guard below:
  - `bootstrap.sh` and `bootstrap.ps1`, which execute before the aitools
    repository is cloned (`bootstrap.sh`: its OS-guard line and its `say` /
    `die` messages);
  - `hh.sh`, which is installed alone in `~/.local/bin` (its OS-guard line and its
    `hh:` messages), and `hh.ps1`;
  - `relay-outbound-prompt.sh`, sourced into its caller: its OS-guard line
    and its `[RELAY]` lines; its menu answers are not logged.
    `relay-outbound-prompt.ps1` loads the library for its menu read and logs
    the answers through it; without the library it writes no log line;
  - the entry points `aitools` and `aitools.ps1` until they have loaded the
    library (it is found through `repoPath`): warnings found before are
    logged right after the load; an error that ends the run before it goes to
    stderr;
  - the PowerShell 7 version check of `aitools-profile.ps1`, before the
    library loads;
  - in the scripts `build-deploy.sh` generates: the truncation guard of
    `deploy-harness.sh`, which writes its log line to stderr and one ERROR
    record by hand, in the 8.4 format, before the library loads, and the embedded profile
    resolver of `setup-user-claude`, `-cursor` and `-settings`, which reports
    a failure to write its files on stderr before logging starts.

#### 8.2 Helpers

| Helper (bash / PowerShell) | deploy.log | Count | Run summary file |
|---|---|---|---|
| `log`, `log_ok`, `log_detail` / `Log`, `LogOk`, `LogDetail` | the line | none | none |
| `log_warn TEXT` / `LogWarn` | `[warn]` TEXT | warnings +1 | one WARN record, name = the script |
| `write_warn TOOL TEXT` / `Write-AitWarn` | `[warn]` TEXT | warnings +1 | one WARN record, name = TOOL |
| `write_action TOOL TEXT ACTION` / `Write-AitAction` | `[warn]` TEXT | warnings +1 | one WARN record (name = TOOL, text = TEXT) and one ACTION record (instruction = ACTION) |
| `log_error TEXT` / `LogError` | `[error]` TEXT | errors +1 | one ERROR record, name = the script, empty reason |
| `write_error TOOL WHAT REASON` / `Write-AitError` | `[error]` WHAT: REASON (WHAT alone when REASON is empty) | errors +1 | one ERROR record, name = TOOL |
| `error_reason OUTPUT EXIT_CODE` / `Get-AitErrorReason -Output -ExitCode [-ErrorRecord]` | OUTPUT as detail lines | none | none; returns one reason (8.3) |
| `write_summary OK\|DETAIL\|ACTION` / `Write-Summary` | none | none | the record |

The PowerShell helpers take the same arguments as their bash twins, in the
same order. "The script" is the logging script's script name (8.0). A helper
given an empty TOOL uses the logging script's name.

The library's abort path (`_managed_abort` / `Invoke-ManagedAbort`) and the
relay (for a failed child that 8.3 says it does not record) log their own
error line at error level and count it without recording it; no other code
may use that path.

A caller does not log the output it passes to `error_reason` /
`Get-AitErrorReason`; the helper logs it as detail lines. The one exception
is a command whose output the caller streams to the console as it arrives
(logged line by line at info) and captures at the same time: when it fails,
its output appears in deploy.log twice, once as it streamed and once as
detail.

A library-style tool (section 7) sets the library's stderr console option,
which also turns recording off: its helpers log and count but write no
record, and its warnings and errors reach the run summary through its caller
(section 7).

#### 8.3 Rules

- **Recorded at the source.** Each warning and error is recorded once, by
  the script that logs it. Every script of a run inherits the run summary
  file, so a parent and its children follow the same rule.
  - **Managed files.** A managed file deployed through
    `deploy_managed_file` / `Deploy-ManagedFile` is recorded by the library
    at the source: a skipped review is one warning and a failed deploy one
    error (its reason the write, AI merge, adopt-filter or validation
    error), each under the tool name the caller passes. The caller adds no
    record of its own for them, and the deploy tracker
    (`deploy_tracker_record` / `Record-DeployOutcome`) writes the tool's OK
    status record and DETAIL records only.
- **A WARN or ERROR record is one warning or one error**, never a tool's
  status. A tool's status is its OK record, and it is never recoloured.
- **Children.**
  - **Relayed lines.** The relay prints a child's lines. It mirrors the
    structured lines (`[<time>] [<script>] [<level>] <message>`) to
    deploy.jsonl. A runner may ask it not to mirror them (a child that writes
    its own deploy.jsonl records) or to print only the `warn` and `error`
    lines (a child whose other output is not shown). It counts the `warn` and `error` lines, but not the exit
    footer (`COMPLETED with ...`, `FAILED with ...`), in the child counts.
    A child's warnings are not added to the parent's warning count.
  - **A failed child** (non-zero exit, a throw, or error lines with exit 0)
    is one error of the parent, counted in its error count.
  - **Recording that error.** The relay records it only when the child
    recorded no ERROR record while it was executing. Otherwise it is logged at error
    level and counted, but not recorded again.
  - **Its name** is the summary tool given to the relay. Without one, it is
    the base name, without extension, of the first argument ending in `.sh`
    or `.ps1`, else the relay's label.
  - **Its WHAT** is `<label> failed (exit <N>)`, or `<label> failed
    (exception)` when an in-process PowerShell child threw.
  - **Its REASON**, the first that applies:
    - the exception message (a throw);
    - `error_reason` over the child's last 20 stderr lines (bash and native
      children: the relay tees stderr, which still reaches the console), or
      over the error records it wrote (in-process PowerShell children);
    - `error_reason` over its last stdout line.
  - **A user abort (exit 2)** keeps its outcome. The relay records it, as
    one record, only when the child recorded no WARN or ERROR record while
    it was executing (so an abort inside a relayed child that runs its own
    relay is recorded once, by the innermost relay); the runner never writes
    a second one.
    - A runner may ask the relay to record a child's abort as a warning
      instead of an error. `deploy-harness` aborted: one WARN record
      (`harness files`, `aborted by user`), counted as one warning of the
      parent, not an error; the run stops with exit 2.
    - Any other child aborted: one ERROR record (`<label> failed (exit 2)`,
      `aborted by user`), counted as one error of the parent; the run
      continues.

    The child's own abort line is logged and counted, not recorded.
- **Each script counts its own warnings.** Its exit footer reports its own
  warning count, and an error count that includes its failed children.
- **Every error has a reason.** An error states what failed (WHAT) and why
  (REASON). `error_reason` derives the reason, taking the first of these that
  applies:
  1. a known build-failure signature (`diagnose_build_failure` /
     `Diagnose-BuildFailure`), as `<NAME>: <REMEDY>`;
  2. the exception message, when an exception is given (PowerShell);
  3. the first line of the output that matches an error marker:
     - a word that ends in `error:`, in any case (for example `error:`,
       `Error:`, `ERROR:`, `SyntaxError:`, `Write-Error:`; the word may
       contain letters, digits, `-` and `_`), at the start of the line or
       after a space;
     - `fatal:`, in any case, at the start of the line or after a space;
     - `E: ` at the start of the line;
     - `syntax error`, in any case, anywhere in the line;
  4. the last non-empty line of the output;
  5. `no output (exit <N>)`.

  Before matching, CR, ANSI CSI sequences (`ESC [` ... final byte) and a
  leading `[<time>] [<script>] [<level>] ` prefix are removed from each
  line. The full output is logged as detail lines.
- **What is a warning.**
  - A warning reports something that is wrong, or that still needs the
    user. Examples: a tool not authenticated; a managed file left differing
    after a skipped review; local edits overwritten in a non-interactive run;
    a step under `--force` that loses data (a corrupt file rewritten, a merge
    that drops fields), which is still a warning.
  - A step the user explicitly asked for in the same run, and that completed
    as asked, is logged at info, not as a warning. Example: an overwrite
    under `--force`.
- **Outside a run** (no `AITOOLS_SUMMARY_FILE`), nothing is recorded.
- **Fail-safe.** A record that cannot be written is ignored, as a log line
  is (section 5). This extends section 5's one sanctioned silent failure to
  records.

#### 8.4 Run summary file format

- An entry point that finds `AITOOLS_SUMMARY_FILE` unset creates the file
  (empty) and exports its path. One that finds it set writes to that file
  and does not create it.
- The file is UTF-8, with one record per line and fields separated by `|`.
- A writer replaces CR and LF in any field with a space, and `|` with `/` in
  every field except an ACTION's `<instruction>`.

```
OK|<tool>|<status>
DETAIL|<tool>|<detail>
WARN|<name>|<text>
ERROR|<name>|<what>|<reason>
ACTION||<instruction>
```

| Field | Meaning |
|---|---|
| `<tool>` | A tool name (8.0) |
| `<name>` | `<tool>` when the writer names one; otherwise the logging script's name |
| `<status>` | The tool's state when it is fine: a version, `verified`, `n/a (<reason>)` |
| `<detail>` | One item of the tool's outcome (`added: <item>`) |
| `<text>` | What is wrong, or what to do |
| `<what>` | The step that failed |
| `<reason>` | Why it failed (8.3); empty only for an error recorded by `log_error` |
| `<instruction>` | The command or step the user must take |

**Reader rules**:
- For an ACTION record, everything after the second `|` is the instruction.
- For other kinds, a missing trailing field is empty (so a 3-field ERROR
  record has an empty reason), and extra fields are joined back with `/`.
- A record of an unknown kind, or any record other than ACTION with an empty
  name or tool, is skipped and logged at detail; the detail line quotes the
  skipped record verbatim.

#### 8.5 Panel format

**When it is drawn.** The entry point that created the file draws it once,
at the end of the run, and then deletes it. An entry point that found the
file already set draws nothing. (`AITOOLS_SUPPRESS_SUMMARY_DISPLAY` is how
the creator tells a nested installer so.) When `AITOOLS_PRESERVE_SUMMARY=1`,
a copy is kept as `last-summary.txt` in the log directory. Nothing is drawn
when the file is missing or empty.

**Notation.** `X*` means zero or more X; `X+` one or more; `[X]` optional;
`"..."` literal text; `<x:16>` the field padded with spaces to 16
characters, never cut; `<x:70>` the field cut to 70 characters (below).

```
panel         = blank rule green-block yellow-block red-block [action-block] rule
blank         = an empty line
rule          = bash: U+2500 x 56; PowerShell: "-" x 60
green-block   = (green-line detail-line*)*
yellow-block  = (yellow-line detail-line*)* [more-line]
red-block     = (red-line detail-line*)* [more-line]
action-block  = blank action-header action-line+
green-line    = "  [ok]  " <tool:16> " " <status>
yellow-line   = "  [!]   " <name:16> " " <text:70> [" (x" N ")"]
red-line      = "  [ERR] " <name:16> " " <what> [": " <reason>]   (cut below) [" (x" N ")"]
detail-line   = 26 spaces <detail>
more-line     = 8 spaces "+" N " more in deploy.log"
action-header = "  ACTION REQUIRED -- run before tools are ready:"
action-line   = "  >>  " <instruction>
```

**Rules.**
- **Green**: one line per tool that has an OK record and no WARN or ERROR
  record under its name. A tool's first OK record gives its position and
  its status.
- **Yellow and red**:
  - every WARN / ERROR record, in file order;
  - identical records (same name and text; for errors, same name, what and
    reason) collapse into the first, followed by `(xN)`;
  - after collapsing, at most 20 lines per section; the rest are counted in
    one `more-line`.
  - DETAIL lines do not count toward the 20.
- **DETAIL lines** follow their tool's first panel line, in its colour. A
  tool's DETAIL lines are not shown when that line is beyond the cap or does
  not exist.
- **ACTION lines** keep file order; identical ones are shown once.
- **Cutting.**
  - Lengths and padding count Unicode code points, in every locale.
  - `cut(s, n)`: `s` itself when it is at most `n` code points long;
    otherwise its first `n - 3` code points followed by `...`.
  - A yellow line's `<text>` is `cut(text, 70)`.
  - A red line, with `w` = the length of `<what>` and `r` = the length of
    `<reason>`:
    - with an empty reason, the line is `cut(what, 70)` with no `": "`;
    - otherwise, if `w + 2 + r <= 70`, both are shown whole;
    - otherwise `<what>` becomes `cut(what, max(20, 70 - 2 - r))`, and then
      `<reason>` becomes `cut(reason, 70 - 2 - w')`, where `w'` is the new
      length of `<what>`. The `": "` separator counts toward the 70.
  - Green status, DETAIL and ACTION lines are not cut.
- **Colours**:
  - bash: green 32, yellow 33, red 31, ACTION bold magenta 1;35 (ANSI);
  - PowerShell: `Green`, `Yellow`, `Red`, `Magenta`;
  - a `more-line` and DETAIL lines take their section's colour.

#### 8.6 State and events

| State | Owner | Changed by | Read by |
|---|---|---|---|
| `WARNINGS` / `$script:warnings` | each script process | `log_warn`, `write_warn`, `write_action`, the relay (a child's abort recorded as a warning) | exit footer; `read_menu_choice` end-of-input fallback |
| `ERRORS` / `$script:errors` | each script process | `log_error`, `write_error`, the relay (a failed child) | exit footer (exit 1); fan-out validation |
| `AITLIB_CHILD_WARNINGS` / `AITLIB_CHILD_ERRORS` (`$script:AitLibChildWarnings` / `$script:AitLibChildErrors`) | the parent, per relayed child | the relay | the relay's failure decision (the error count and the exit code) |
| Run summary file | the run | the helpers of 8.2; the writers of 8.1 | the panel; the relay (ERROR records written while a child was executing); ACTION de-duplication; checks that inspect it |
| `deploy.log`, `deploy.jsonl` | the log directory (`~/.aitools/logs/`, or `AITOOLS_LOG_DIR`) | the helpers of 8.2; the writers of 8.1 | people, telemetry |

| Event | Effect |
|---|---|
| An entry point starts | Creates and exports `AITOOLS_SUMMARY_FILE` unless it is already set |
| `logging_init` / `Initialize-Logging` | Counts reset to 0; the run summary file is untouched |
| A warning helper | Logged; warning count +1; one WARN record (plus an ACTION record for `write_action`) |
| An error helper | Logged, with its reason when it has one; error count +1; one ERROR record |
| `write_summary` | Its record is appended as written |
| The relay sees a child's line | Printed; a structured line mirrored to deploy.jsonl; a warn or error line (not the exit footer) adds 1 to the child count |
| A child fails | Parent error count +1; one ERROR record from the relay only if the child recorded none (8.3) |
| A child aborts (exit 2) | As 8.3, recorded once, by the relay: `deploy-harness` (recorded as a warning at the runner's request), one WARN record and parent warning count +1, and the run stops with exit 2; any other child, one ERROR record and parent error count +1, and the run continues |
| Exit footer | The script's counts; exit 1 when its error count is above 0 |
| The entry point that created the file ends | Panel drawn (8.5); file deleted; `last-summary.txt` kept when `AITOOLS_PRESERVE_SUMMARY=1` |

## Migration status

The location/rotation migration across `aitools-lib.{sh,ps1}`, `harness-db.py`,
hooks, `check-lib`, and `clip2md` is tracked in plan §14.3. After migration,
no log path uses the old literals (`.local/state`, `Library/Logs`,
`%LOCALAPPDATA%\aitools`) (§20.3 M4). The literals still appear legitimately
for install paths (`%LOCALAPPDATA%\bin\NASM`, `%LOCALAPPDATA%\Programs\...`)
and for the package path's root log directory (the `AITOOLS_LOG_DIR`
override above).

## Cross-references

- Per-script helper API + levels: `@.claude/rules/script-standards.md`
- Helper detail, check architecture, console colors: `@reference/script-standards-detail.md`
- When to use which helper, the tool name table and the severity guide: `@reference/script-standards-detail.md` "End-of-run summary"
- User-scoped namespace (`~/.aitools/`): `@.claude/rules/aitools-workspace.md`
- Hook observe-mode logs: `@.claude/rules/hook-rollout.md`
- Plan: `plans/harvest-archive-resilience.md` §14
