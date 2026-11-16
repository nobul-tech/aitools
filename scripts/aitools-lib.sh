# aitools-lib.sh -- shared helpers for all aitools bash scripts
# Sourced, not executed directly. No shebang, no set -euo pipefail (caller sets it).
#
# Provides: platform and environment detection (AITOOLS_PLATFORM, IS_MACOS,
# IS_WINDOWS, IS_LINUX, AITOOLS_ENVIRONMENT, is_claude_code_web,
# is_local_environment, write_environment_skip), display_path, read_config_key,
# resolve_user_repo_path, resolve_machine_profile, tool_exception_get,
# tool_exception_record,
# logging_init, log/log_ok/log_error/log_warn/log_detail,
# write_warn/write_action/write_error, error_reason, invoke_ai, write_summary,
# summary_begin/summary_end, show_summary, run_child_relayed, run_relay_sync,
# SORT_KEYS_JS, normalize_json.
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
#   logging_init "script-name"
#
# Logging, warnings and errors follow reference/logging.md section 8. No script
# overrides a logging function: one that needs other behaviour sets a library
# option after logging_init (see logging_init: AITLIB_OPT_JSONL,
# AITLIB_OPT_CONSOLE_STDERR, AITLIB_OPT_COLOR_AUTO).

# ---------------------------------------------------------------------------
# Platform and environment detection (.claude/rules/cross-platform.md
# "Environment branches"; reference/cross-platform-detail.md "Platform and
# environment API"). Resolved once, when this library is sourced.
#   AITOOLS_PLATFORM     macos | linux | windows | unknown       (uname -s)
#   AITOOLS_ENVIRONMENT  claude-code-web | local
#     override: AITOOLS_ENVIRONMENT=claude-code-web|local already set
#     detect:   CLAUDE_CODE_REMOTE=true -> claude-code-web, else local
#     rule:     claude-code-web exists only on linux
# The code between the BEGIN/END markers is the canonical block that hooks embed
# verbatim (hooks cannot source this library). Change it here and in every hook
# that embeds it. A check-pre-commit step comparing the copies is planned (rollout
# batch R4); no hook embeds the block yet.
# ---------------------------------------------------------------------------
_AITOOLS_ENVIRONMENT_REQUESTED="${AITOOLS_ENVIRONMENT:-}"
# --- BEGIN aitools environment block ---
case "$(uname -s)" in
    Darwin*)              AITOOLS_PLATFORM="macos" ;;
    Linux*)               AITOOLS_PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) AITOOLS_PLATFORM="windows" ;;
    *)                    AITOOLS_PLATFORM="unknown" ;;
esac
case "${AITOOLS_ENVIRONMENT:-}" in
    claude-code-web|local) ;;
    *)
        if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
            AITOOLS_ENVIRONMENT="claude-code-web"
        else
            AITOOLS_ENVIRONMENT="local"
        fi ;;
esac
if [ "$AITOOLS_PLATFORM" != "linux" ]; then
    AITOOLS_ENVIRONMENT="local"
fi
# --- END aitools environment block ---
IS_MACOS=false
IS_WINDOWS=false
IS_LINUX=false
case "$AITOOLS_PLATFORM" in
    macos)   IS_MACOS=true ;;
    windows) IS_WINDOWS=true ;;
    linux)   IS_LINUX=true ;;
esac

# Predicates for environment branches (below the OS guard only).
is_claude_code_web()   { [ "$AITOOLS_ENVIRONMENT" = "claude-code-web" ]; }
is_local_environment() { [ "$AITOOLS_ENVIRONMENT" = "local" ]; }

# ---------------------------------------------------------------------------
# Log directory -- unified cross-platform location (reference/logging.md §1):
# ~/.aitools/logs on macOS, Linux, and Windows. Honors an explicit
# AITOOLS_LOG_DIR override (e.g. for tests).
# ---------------------------------------------------------------------------
AITOOLS_LOG_DIR="${AITOOLS_LOG_DIR:-$HOME/.aitools/logs}"

# ---------------------------------------------------------------------------
# Module-level counters (safe for sourcing without logging_init under set -u)
# ---------------------------------------------------------------------------
ERRORS=0
WARNINGS=0

# Library options (documented at logging_init). Reset when the library is
# sourced, so a parent's value never reaches a child script.
AITLIB_OPT_JSONL=false
AITLIB_OPT_CONSOLE_STDERR=false
AITLIB_OPT_COLOR_AUTO=false
# summary_begin: true when this process created the run summary file
AITLIB_SUMMARY_OWNER=false

# ---------------------------------------------------------------------------
# Display-friendly path (native Windows on MSYS, no-op elsewhere)
# ---------------------------------------------------------------------------
display_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

# ---------------------------------------------------------------------------
# Config reader (pure bash, handles UTF-8 BOM)
# ---------------------------------------------------------------------------
# Read a top-level string value from a JSON config file.
# Handles UTF-8 BOM (PowerShell 5.x writes one) and JSON-escaped backslashes.
read_config_key() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    local val
    val=$(tr -d '\357\273\277' < "$file" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | sed -n '1p' \
        | cut -d'"' -f4)
    [ -n "$val" ] || return 1
    # Unescape JSON backslashes: \\ -> \
    printf '%b' "$val"
}

# ---------------------------------------------------------------------------
# Dotprofile, machine-profile and tool-exception resolution
# (reference/user-repo.md "Resolution"; tool exceptions:
# reference/tool-support-decision-tree.md section 8)
# Intent: give every bash consumer one answer to "where is the dotprofile" and
# "which profile is this machine", with the reason ("via") logged to deploy.log,
# and the tool-exception store's reader and writer. The logic lives in the
# native resolver aitools-profile.sh (aitools-profile.ps1 under Git Bash on
# Windows, where the .sh refuses to run). NOT a writer of config.json (only
# setup-user-config writes it). NOT a writer of profile.json beyond
# tool_exception_record (which delegates to the resolver). Consumed by:
# setup-user-*.sh, aitools, the tool setup scripts (tool exceptions) and the
# generated deploy/ scripts (they set AITOOLS_PROFILE_SH to their embedded copy).
# Return codes follow the decision tree's helper rule: none returns 2.
# Results are globals, never stdout (counters and globals must survive).
#
# Result-global contract (PR #80 review3 B1/M1): every result global carries the
# AITLIB_ prefix and every private helper the _aitlib_ prefix, so they cannot
# collide with a caller's own variables (USER_REPO_PATH, PROFILE_FILE, ...).
# They are assigned only inside these functions -- this section has no top-level
# assignment -- so read them only after the call (under set -u an unset one is an
# error). Callers copy what they need into their own variables right after the
# call, e.g.:  resolve_user_repo_path || rc=$?;  USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
# ACTION rows: the wrapper emits the one ACTION for its failure (once per run:
# _aitlib_action_once skips a row the run summary already holds); callers do not
# add their own ACTION for the same failure.
#
# Resolver exit codes -> wrapper return codes (re-key batch 3). The resolver
# (aitools-profile.sh --help) exits 0 ok, 1 nothing found, 2 error, 3 refused,
# 4 refused: alias used by another profile (register only). No wrapper returns
# 2 (D-TS13: a bare 2 means user abort), and no resolver code other than 1 is
# read as "nothing found":
#   resolver exit         0          1               2      3            4
#   resolve_user_repo_path 0 found   1 shared-only   3      3 (refused)  3 (unexpected)
#   resolve_machine_profile 0 match  1 shared-only   3      3 (refused)  3 (unexpected)
#   tool_exception_get     0         1 unavailable   1      1 (refused)  1 (unexpected)
#   tool_exception_record  0         1 failed        1      3 refused    1 (unexpected)
# Every 3 and 4 is logged with its code and meaning. An exit 0/1 without the
# resolver's result lines ("via" or "result"; a value for hostname and
# machine-id) is rewritten to 2 first (_aitlib_profile_run).
# ---------------------------------------------------------------------------

# _aitlib_rm_tmp FILE [WHO] -- remove a temp file of the lib (the runner's stderr
# capture, the relay's exit-code file); a failure is a detail line naming WHO
# (default "aitools-profile") -- never silent; not a warning: a leftover temp
# file is nothing the user must act on (reference/logging.md 8.3)
_aitlib_rm_tmp() {
    if [ -e "$1" ] && ! rm -f "$1"; then log_detail "${2:-aitools-profile}: could not remove temp file $1"; fi
    return 0
}

# _aitlib_profile_run ARGS... -- run the resolver; sets AITLIB_PROFILE_OUT
# (tagged lines, CR stripped) and AITLIB_PROFILE_RC. Returns 0 when it ran, 1
# when no resolver is available (AITLIB_PROFILE_RC is then 2 with an "error"
# line naming it; the caller logs it). The resolver's stderr (its own log
# lines) is copied to deploy.log as detail lines. Callers: the wrappers below
# and `aitools user init` (scripts/aitools ui_profile_run copies the results).
# The exit code is trusted only with the result lines. Accepted output:
#   hostname, machine-id   exit 0 with a non-empty value (a bare value, no tags)
#   every other command    exit 0 or 1 with a "via" or a "result" line
#                          (user-repo-path, resolve, exception-get and
#                          derive-config print "via"; register and migrate
#                          print "result"; exception-set prints both)
# Exit 0 or 1 without them (a crash, a parse failure, a policy refusal -- pwsh
# exits 0 or 1 for those) is rewritten to 2 with an "error" line, so no caller
# mistakes it for "found" or "shared-only". Exits 2, 3 and 4 are passed through
# with the resolver's own lines.
# Windows (Git Bash) branch: aitools-profile.ps1 through pwsh
# (-ExecutionPolicy Bypass, as the OS dispatch rule calls .ps1 files; a throw
# exits 2 with an "error" line, "aitools-profile CMD threw: MESSAGE"). Absolute
# path arguments (after --path, --profile, --out, --config) are passed in
# Windows form (cygpath -w; unchanged when cygpath fails), stdout is forced to
# UTF-8 and CRs are stripped. AITLIB_PROFILE_VIA_PWSH=1 forces this branch on
# any OS (tests; cygpath is then used only when present).
# UNVERIFIED on Windows (tested on macOS only, through the forced branch):
# cygpath conversion, MSYS argument and environment translation, and the
# UTF-8 decoding of non-ASCII values.
_aitlib_profile_run() {
    AITLIB_PROFILE_OUT=""; AITLIB_PROFILE_RC=0
    local d sh ps1 errf="" line ok=false
    d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sh="${AITOOLS_PROFILE_SH:-$d/aitools-profile.sh}"
    ps1="${AITOOLS_PROFILE_PS1:-$d/aitools-profile.ps1}"
    if ! errf="$(mktemp)"; then
        errf=""
        log_warn "aitools-profile: mktemp failed -- the resolver's own log lines are not captured"
    fi
    if [ "$AITOOLS_PLATFORM" = "windows" ] || [ "${AITLIB_PROFILE_VIA_PWSH:-}" = "1" ]; then
        if [ ! -f "$ps1" ] || ! command -v pwsh >/dev/null 2>&1; then
            if [ -n "$errf" ]; then _aitlib_rm_tmp "$errf"; fi
            AITLIB_PROFILE_RC=2
            AITLIB_PROFILE_OUT="error"$'\t'"resolver $(basename "$ps1") or pwsh not found ($(display_path "$(dirname "$ps1")"))"
            return 1
        fi
        local a w prev="" ps1_arg="$ps1" arglist=""
        if command -v cygpath >/dev/null 2>&1; then
            if w="$(cygpath -w "$ps1")"; then ps1_arg="$w"; else log_detail "aitools-profile: cygpath -w failed for $ps1 -- passed unchanged"; fi
        fi
        for a in "$@"; do
            case "$prev" in
                --path|--profile|--out|--config)
                    if command -v cygpath >/dev/null 2>&1; then
                        case "$a" in
                            /*) if w="$(cygpath -w "$a")"; then a="$w"; else log_detail "aitools-profile: cygpath -w failed for $a -- passed unchanged"; fi ;;
                        esac
                    fi ;;
            esac
            arglist="$arglist$a"$'\n'
            prev="$a"
        done
        # Arguments travel in an environment variable, one per line (resolver
        # values are one line by contract), so pwsh -Command can set UTF-8 output
        # before it runs the resolver. A throw prints an "error" line (stdout) as
        # well as the stderr line, as Invoke-AitLibProfile does.
        AITLIB_PROFILE_OUT=$(AITLIB_PS1="$ps1_arg" AITLIB_PS_ARGS="$arglist" AITLIB_PS_CMD="${1:-}" pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command 'try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $a = @(); if ($env:AITLIB_PS_ARGS) { $a = @($env:AITLIB_PS_ARGS.Substring(0, $env:AITLIB_PS_ARGS.Length - 1) -split "`n") }; $global:LASTEXITCODE = 0; & $env:AITLIB_PS1 @a; exit $LASTEXITCODE } catch { $m = "aitools-profile $($env:AITLIB_PS_CMD) threw: $($_.Exception.Message -replace "\s*\r?\n\s*", " ")"; [Console]::Error.WriteLine($m); [Console]::Out.WriteLine("error`t$m"); exit 2 }' 2>"${errf:-/dev/null}") || AITLIB_PROFILE_RC=$?
        AITLIB_PROFILE_OUT="${AITLIB_PROFILE_OUT//$'\r'/}"
    else
        if [ ! -f "$sh" ]; then
            if [ -n "$errf" ]; then _aitlib_rm_tmp "$errf"; fi
            AITLIB_PROFILE_RC=2
            AITLIB_PROFILE_OUT="error"$'\t'"resolver $(basename "$sh") not found ($(display_path "$(dirname "$sh")"))"
            return 1
        fi
        # The resolver runs under the caller's bash (macOS /bin/bash 3.2 stays 3.2)
        AITLIB_PROFILE_OUT=$("${BASH:-bash}" "$sh" "$@" 2>"${errf:-/dev/null}") || AITLIB_PROFILE_RC=$?
    fi
    if [ -n "$errf" ]; then
        while IFS= read -r line; do
            line="${line//$'\r'/}"
            if [ -n "$line" ]; then log_detail "aitools-profile $1: $line"; fi
        done < "$errf"
        _aitlib_rm_tmp "$errf"
    fi
    case "$AITLIB_PROFILE_RC" in
        0|1)
            case "${1:-}" in
                hostname|machine-id)
                    if [ "$AITLIB_PROFILE_RC" -eq 0 ] && [ -n "$AITLIB_PROFILE_OUT" ]; then ok=true; fi ;;
                *)
                    case $'\n'"$AITLIB_PROFILE_OUT" in
                        *$'\n'via$'\t'*|*$'\n'result$'\t'*) ok=true ;;
                    esac ;;
            esac
            if ! $ok; then
                log_detail "aitools-profile ${1:-}: exit $AITLIB_PROFILE_RC without result lines -- treated as a resolver error"
                AITLIB_PROFILE_OUT="${AITLIB_PROFILE_OUT}"$'\n'"error"$'\t'"resolver exited $AITLIB_PROFILE_RC without result lines (see deploy.log)"
                AITLIB_PROFILE_RC=2
            fi ;;
    esac
    return 0
}

# _aitlib_profile_tag KEY -- value of the first KEY<TAB> line in AITLIB_PROFILE_OUT (pure)
_aitlib_profile_tag() {
    local k v
    while IFS=$'\t' read -r k v; do
        if [ "$k" = "$1" ]; then printf '%s' "$v"; return 0; fi
    done <<< "$AITLIB_PROFILE_OUT"
    return 0
}

# _aitlib_profile_lines KIND -- every warn or error value in AITLIB_PROFILE_OUT, one per line (pure)
_aitlib_profile_lines() {
    local k v
    while IFS=$'\t' read -r k v; do
        if [ "$k" = "$1" ]; then printf '%s\n' "$v"; fi
    done <<< "$AITLIB_PROFILE_OUT"
    return 0
}

# _aitlib_bash_path P -- the Git Bash form of a Windows path; unchanged elsewhere
# or when cygpath fails (pure)
_aitlib_bash_path() {
    local p=""
    if [ -n "$1" ] && command -v cygpath >/dev/null 2>&1; then
        if p="$(cygpath -u "$1")"; then printf '%s' "$p"; return 0; fi
    fi
    printf '%s' "$1"
}

# _aitlib_exit_note RC -- "" for resolver exit 1 (nothing found) and 2 (the plain
# error); for any other exit, " (resolver exit N: meaning)", so a 3 or 4 is never
# logged as a plain error or a "not found" (pure)
_aitlib_exit_note() {
    case "$1" in
        1|2) ;;
        3) printf ' (resolver exit 3: refused)' ;;
        4) printf ' (resolver exit 4: alias used by another profile -- not a result of this command)' ;;
        *) printf ' (resolver exit %s)' "$1" ;;
    esac
}

# _aitlib_action_once TEXT -- write the ACTION record TEXT unless the run summary
# already holds it (several setup scripts in one run hit the same failure). The
# same de-duplication as write_action's ACTION (_aitlib_action_record).
_aitlib_action_once() {
    _aitlib_action_record "$1"
}

# _aitlib_resolver_error TOOL WHAT -- one error for a failed resolver call
# (reference/logging.md 8.2, 8.3): the first "error" line of AITLIB_PROFILE_OUT
# (with its exit note) is the REASON, the other error lines are detail lines;
# with none, the reason is "resolver failed (exit N)".
_aitlib_resolver_error() {
    local tool="$1" what="$2" note w first=""
    note=$(_aitlib_exit_note "$AITLIB_PROFILE_RC")
    while IFS= read -r w; do
        [ -n "$w" ] || continue
        if [ -z "$first" ]; then first="$w$note"; else log_detail "$tool: $w$note"; fi
    done <<< "$(_aitlib_profile_lines error)"
    if [ -z "$first" ]; then first="resolver failed${note:- (exit $AITLIB_PROFILE_RC)}"; fi
    write_error "$tool" "$what" "$first"
}

# resolve_user_repo_path -- sets AITLIB_USER_REPO_PATH (bash path form) and
# AITLIB_USER_REPO_VIA (env|argument|config|convention|scan|none). Returns 0
# found, 1 no dotprofile (shared-only mode; not an error), 3 resolver error or
# refusal (one write_error "dotprofile" with the resolver's first error line as
# the reason + one ACTION per run, "see deploy.log -- the dotprofile could not
# be resolved").
resolve_user_repo_path() {
    AITLIB_USER_REPO_PATH=""; AITLIB_USER_REPO_VIA="none"
    local w
    if ! _aitlib_profile_run user-repo-path; then
        _aitlib_resolver_error "dotprofile" "resolver missing"
        _aitlib_action_once "see deploy.log -- the dotprofile could not be resolved"
        return 3
    fi
    AITLIB_USER_REPO_VIA=$(_aitlib_profile_tag via)
    while IFS= read -r w; do if [ -n "$w" ]; then log_detail "dotprofile: $w"; fi; done <<< "$(_aitlib_profile_lines warn)"
    case "$AITLIB_PROFILE_RC" in
        0)
            AITLIB_USER_REPO_PATH=$(_aitlib_bash_path "$(_aitlib_profile_tag path)")
            log_detail "dotprofile=$AITLIB_USER_REPO_PATH via=$AITLIB_USER_REPO_VIA"
            return 0 ;;
        1)
            log_detail "dotprofile: none found (shared-only mode)"
            return 1 ;;
    esac
    _aitlib_resolver_error "dotprofile" "resolver failed"
    _aitlib_action_once "see deploy.log -- the dotprofile could not be resolved"
    return 3
}

# resolve_machine_profile -- sets AITLIB_MACHINE_ALIAS, AITLIB_MACHINE_VIA,
# AITLIB_PROFILE_FILE, AITLIB_PROFILE_NAME, AITLIB_PROFILE_COMPANY,
# AITLIB_IDENTITY_GIT_NAME, AITLIB_IDENTITY_GIT_EMAIL, AITLIB_IDENTITY_GITHUB,
# and (re-key batch 3, the resolver's id-key fields):
#   AITLIB_MACHINE_KEY      the profiles key that matched ("" when none)
#   AITLIB_MACHINE_OWNER    this|other|unregistered|unknown|absent ("absent" when none)
#   AITLIB_MACHINE_LEGACY   true when the matched profile is still keyed by alias, else false
#   AITLIB_MACHINE_HOSTNAME this machine's live short hostname ("" when unavailable)
# AITLIB_MACHINE_ALIAS is the profile's alias field (its key for a legacy profile).
# A resolver without the id-key fields (an older embedded copy) leaves the
# defaults. Return 0 means a profile matched, not that it is this machine's:
# a caller that writes per-machine data checks AITLIB_MACHINE_OWNER = this.
# Logs one detail line ("machine profile: alias=.. via=.. key=.. owner=..").
# Resolver warnings are detail lines here: setup-user-config, the first script
# of every run, reports them once (a successful step stays OK, D-TS12).
# Returns 0 resolved, 1 no dotprofile (shared-only), 3 no match or error (one
# write_error "machine profile", WHAT "no machine match", REASON the resolver's
# first error line; one ACTION per run; callers must not
# substitute another machine's values; the AITLIB_PROFILE_/AITLIB_IDENTITY_
# values then hold the identity-level, machine-independent values only).
resolve_machine_profile() {
    AITLIB_MACHINE_ALIAS=""; AITLIB_MACHINE_VIA="none"; AITLIB_PROFILE_FILE=""
    AITLIB_PROFILE_NAME=""; AITLIB_PROFILE_COMPANY=""
    AITLIB_IDENTITY_GIT_NAME=""; AITLIB_IDENTITY_GIT_EMAIL=""; AITLIB_IDENTITY_GITHUB=""
    AITLIB_MACHINE_KEY=""; AITLIB_MACHINE_OWNER="absent"; AITLIB_MACHINE_LEGACY=false; AITLIB_MACHINE_HOSTNAME=""
    local w v
    if ! _aitlib_profile_run resolve --environment "$AITOOLS_ENVIRONMENT"; then
        _aitlib_resolver_error "machine profile" "resolver missing"
        # Same text as resolve_user_repo_path's: one ACTION per run for a missing resolver
        _aitlib_action_once "see deploy.log -- the dotprofile could not be resolved"
        return 3
    fi
    AITLIB_MACHINE_ALIAS=$(_aitlib_profile_tag alias)
    AITLIB_MACHINE_VIA=$(_aitlib_profile_tag via)
    AITLIB_PROFILE_FILE=$(_aitlib_bash_path "$(_aitlib_profile_tag profileFile)")
    AITLIB_PROFILE_NAME=$(_aitlib_profile_tag name)
    AITLIB_PROFILE_COMPANY=$(_aitlib_profile_tag company)
    AITLIB_IDENTITY_GIT_NAME=$(_aitlib_profile_tag gitName)
    AITLIB_IDENTITY_GIT_EMAIL=$(_aitlib_profile_tag gitEmail)
    AITLIB_IDENTITY_GITHUB=$(_aitlib_profile_tag github)
    AITLIB_MACHINE_KEY=$(_aitlib_profile_tag key)
    v=$(_aitlib_profile_tag owner); AITLIB_MACHINE_OWNER="${v:-absent}"
    v=$(_aitlib_profile_tag legacy); if [ "$v" = "true" ]; then AITLIB_MACHINE_LEGACY=true; fi
    AITLIB_MACHINE_HOSTNAME=$(_aitlib_profile_tag hostname)
    while IFS= read -r w; do if [ -n "$w" ]; then log_detail "machine profile: $w"; fi; done <<< "$(_aitlib_profile_lines warn)"
    log_detail "machine profile: alias=${AITLIB_MACHINE_ALIAS:-none} via=${AITLIB_MACHINE_VIA:-none} key=${AITLIB_MACHINE_KEY:-none} owner=$AITLIB_MACHINE_OWNER legacy=$AITLIB_MACHINE_LEGACY company=$AITLIB_PROFILE_COMPANY host=$AITLIB_MACHINE_HOSTNAME id=$(_aitlib_profile_tag machineId)"
    case "$AITLIB_PROFILE_RC" in
        0) if [ -n "$AITLIB_MACHINE_ALIAS" ]; then return 0; fi ;;
        1) log_detail "machine profile: no dotprofile -- shared-only mode"; return 1 ;;
    esac
    _aitlib_resolver_error "machine profile" "no machine match"
    log "machine profile: unresolved -- no other machine's values are used"
    _aitlib_action_once "Run: aitools user init (pick or register this machine's profile)"
    return 3
}

# tool_exception_get SLUG -- this machine's recorded tool exception (tree section
# 8 Reader; call only at T5). Sets AITLIB_TOOL_EXC_FOUND (true/false),
# AITLIB_TOOL_EXC_PLATFORM, AITLIB_TOOL_EXC_METHOD, AITLIB_TOOL_EXC_PATH,
# AITLIB_TOOL_EXC_DECIDED_AT. Returns 0 looked up (found or not), 1 store
# unavailable (one log_warn, recorded under the calling script's name when the
# recording switch is on; treated as no exception). Resolver warnings are
# detail lines: a kept tool is fine, so they are no warning of the run.
tool_exception_get() {
    AITLIB_TOOL_EXC_FOUND=false; AITLIB_TOOL_EXC_PLATFORM=""; AITLIB_TOOL_EXC_METHOD=""
    AITLIB_TOOL_EXC_PATH=""; AITLIB_TOOL_EXC_DECIDED_AT=""
    local slug="$1" w reason
    if ! _aitlib_profile_run exception-get --slug "$slug" --environment "$AITOOLS_ENVIRONMENT"; then
        log_warn "tool exceptions unavailable (resolver missing)"
        return 1
    fi
    while IFS= read -r w; do if [ -n "$w" ]; then log_detail "tool exceptions: $w"; fi; done <<< "$(_aitlib_profile_lines warn)"
    if [ "$AITLIB_PROFILE_RC" -ne 0 ]; then
        reason=$(_aitlib_profile_lines error | perl -ne 'next if $done; if (/\S/) { print; $done = 1 }')
        if [ "$AITLIB_PROFILE_RC" -eq 1 ]; then reason="no dotprofile"; fi
        log_warn "tool exceptions unavailable (${reason:-resolver failed})$(_aitlib_exit_note "$AITLIB_PROFILE_RC")"
        return 1
    fi
    if [ "$(_aitlib_profile_tag found)" = "true" ]; then
        AITLIB_TOOL_EXC_FOUND=true
        AITLIB_TOOL_EXC_PLATFORM=$(_aitlib_profile_tag platform)
        AITLIB_TOOL_EXC_METHOD=$(_aitlib_profile_tag method)
        AITLIB_TOOL_EXC_PATH=$(_aitlib_profile_tag path)
        AITLIB_TOOL_EXC_DECIDED_AT=$(_aitlib_profile_tag decidedAt)
    fi
    log_detail "tool exceptions: $slug found=$AITLIB_TOOL_EXC_FOUND profile=$(_aitlib_profile_tag alias) via=$(_aitlib_profile_tag via)"
    return 0
}

# tool_exception_record SLUG METHOD PATH VERSION [REASON] -- record a [k]eep
# decision (tree section 8 Writer; only after [k]eep, never in dry run or
# non-interactive runs). decidedBy = the calling script's name (SCRIPT_NAME).
# The resolver writes profile.json and commits and pushes it (N-Q2).
# Sets AITLIB_TOOL_EXC_RESULT (created|updated|unchanged|dry-run|refused|failed;
# never empty after the call) and AITLIB_TOOL_EXC_PUSHED (true/false).
# Returns 0 written or nothing to write (created/updated: a failed commit or
# push is one write_action, ACTION "run git push in <dotprofile>",
# AITLIB_TOOL_EXC_PUSHED=false; unchanged and dry-run write nothing, so they
# need no push and get no warning), 1 failed, 3 refused (no dotprofile, or the
# machine profile matched by hostname only or not at all). 3 is write_action,
# ACTION "run aitools user init to remember tool choices"; 1 (resolver missing,
# usage error, crash) is write_action, ACTION "see deploy.log -- a tool choice
# (tool exception) was not saved". Each warning is recorded under the calling
# script's name (the slug is not a tool name). The tool itself is fine, so no
# error (D-TS12).
tool_exception_record() {
    AITLIB_TOOL_EXC_PUSHED=false; AITLIB_TOOL_EXC_RESULT=""
    local slug="$1" method="$2" path="$3" version="$4" reason="${5:-}" w msg
    local args=(exception-set --slug "$slug" --platform "$AITOOLS_PLATFORM" --method "$method" --path "$path"
        --version "$version" --by "${SCRIPT_NAME:-unknown}" --environment "$AITOOLS_ENVIRONMENT")
    if [ -n "$reason" ]; then args+=(--reason "$reason"); fi
    if ! _aitlib_profile_run "${args[@]}"; then
        AITLIB_TOOL_EXC_RESULT=failed
        write_action "" "tool exception for $slug not saved (resolver missing)" "see deploy.log -- a tool choice (tool exception) was not saved"
        return 1
    fi
    AITLIB_TOOL_EXC_RESULT=$(_aitlib_profile_tag result)
    while IFS= read -r w; do if [ -n "$w" ]; then log_detail "tool exceptions: $w"; fi; done <<< "$(_aitlib_profile_lines warn)"
    case "$AITLIB_PROFILE_RC" in
        0)
            if [ "$(_aitlib_profile_tag pushed)" = "true" ]; then
                AITLIB_TOOL_EXC_PUSHED=true
                log_detail "tool exceptions: $slug recorded in $(_aitlib_profile_tag profileFile) (committed and pushed)"
            else
                case "$AITLIB_TOOL_EXC_RESULT" in
                    unchanged|dry-run)
                        log_detail "tool exceptions: $slug $AITLIB_TOOL_EXC_RESULT -- nothing written, nothing to push" ;;
                    *)
                        msg=$(_aitlib_profile_lines warn | perl -ne 'next if $done; if (/commit|push|git repository/) { print; $done = 1 }')
                        w=$(_aitlib_profile_tag profileFile)
                        if [ -n "$w" ]; then w=$(dirname "$(_aitlib_bash_path "$w")"); else w="your dotprofile"; fi
                        write_action "" "tool exception for $slug saved but not pushed (${msg:-see deploy.log})" "run git push in $w" ;;
                esac
            fi
            return 0 ;;
        3)
            AITLIB_TOOL_EXC_RESULT=refused
            msg=$(_aitlib_profile_lines error | perl -ne 'next if $done; if (/\S/) { print; $done = 1 }')
            write_action "" "tool exception for $slug not saved (${msg:-refused})$(_aitlib_exit_note 3)" "run aitools user init to remember tool choices"
            return 3 ;;
    esac
    # 2 (error), 4 (not a result of exception-set) and any other code: failed
    AITLIB_TOOL_EXC_RESULT=failed
    msg=$(_aitlib_profile_lines error | perl -ne 'next if $done; if (/\S/) { print; $done = 1 }')
    write_action "" "tool exception for $slug not saved (${msg:-resolver failed})$(_aitlib_exit_note "$AITLIB_PROFILE_RC")" "see deploy.log -- a tool choice (tool exception) was not saved"
    return 1
}

# ---------------------------------------------------------------------------
# Child-script log relay to deploy.jsonl (moved from the installers' "install
# log helpers", PR #89, so installers and deploy-harness share one copy)
# A parent that runs a child setup script (one that logs through aitools-lib)
# shows the child's console lines, mirrors each structured line
# ("[ts] [script] [level] msg") to deploy.jsonl -- the child already wrote it to
# deploy.log, the lib's log() writes no JSONL -- and counts the child's warnings
# and errors.
#   jsonl_record TS SCRIPT LEVEL MSG   append one deploy.jsonl record
#   relay_child_log TEXT               relay captured child output (all lines)
#   run_child_relayed [OPTIONS] LABEL CMD ARGS
#                                      run CMD ARGS, relay each line as it comes
# The rules are reference/logging.md 8.3 ("Children"):
# - A child's warn and error lines are counted in AITLIB_CHILD_WARNINGS /
#   AITLIB_CHILD_ERRORS only; a child's warnings are never added to the
#   parent's WARNINGS (each script counts its own).
# - The child records its own warnings and errors (recorded at the source).
# - A failed child (non-zero exit, or its own error lines with exit 0) is one
#   error of the parent (ERRORS +1). The relay records it (write_error: name
#   = the summary tool, else the base name of the first argument ending in
#   .sh / .ps1, else LABEL; WHAT "<label> failed (exit N)"; REASON
#   error_reason over the child's last 20 stderr lines, else over its last
#   stdout line that is not a warning line, or its last warning line when it
#   printed nothing else) only when the child wrote no ERROR record while it ran;
#   otherwise the error is logged and counted, not recorded again.
# - A user abort (exit 2) is recorded once, by the innermost relay: only when
#   the child wrote no WARN or ERROR record while it ran. With --abort-warn it
#   is WARN|<name>|aborted by user and one parent warning (deploy-harness);
#   without, ERROR|<name>|<label> failed (exit 2)|aborted by user and one
#   parent error.
# Results (set by relay_child_log and run_child_relayed, read after the call):
#   AITLIB_CHILD_WARNINGS  the child's warn lines (the exit footer
#                          "COMPLETED with N warning(s)" is relayed, not counted)
#   AITLIB_CHILD_ERRORS    the child's own error lines ("FAILED with ..." not
#                          counted): lines whose [script] is the script of the
#                          child's last structured line. A middle script that
#                          relays a grandchild re-prints the grandchild's lines;
#                          those name the grandchild and are not the middle
#                          script's own, so a middle script that handled them
#                          and exited 0 is not "failed (exit 0)". (A middle
#                          script whose last structured line is a grandchild's
#                          -- it logs nothing after the relay -- is judged by
#                          the grandchild's lines.)
#   AITLIB_CHILD_RC        run_child_relayed only: the child's exit code
# Private caches (JSON-escaped): AITLIB_RUN_ID, AITLIB_JSONL_HOST, AITLIB_JSONL_OS.
# ---------------------------------------------------------------------------

# _aitlib_json_esc VAR S -- set VAR to S as a JSON string body: backslash, quote,
# tab and newline escaped, every other control character (CR, ESC colour codes,
# ...) dropped (no subshell). The record is one valid JSON line when S is valid
# UTF-8; bytes that are not (e.g. a cp1252 path) are written as they are, as the
# installers did. bash and PowerShell records are byte-identical for valid UTF-8
# without U+0085, U+2028 and U+2029 (PowerShell escapes those; bash drops U+0085
# or keeps it raw depending on the locale).
_aitlib_json_esc() {
    local m="$2"
    m="${m//\\/\\\\}"
    m="${m//\"/\\\"}"
    m="${m//$'\t'/\\t}"
    m="${m//$'\n'/\\n}"
    m="${m//[[:cntrl:]]/}"
    printf -v "$1" '%s' "$m"
}

# _aitlib_jsonl_init -- the host, os and run id fields, computed (and escaped)
# once per process
_aitlib_jsonl_init() {
    local h=""
    if [ -n "${AITLIB_RUN_ID:-}" ]; then return 0; fi
    # hostname -s is missing on some Linux images: the -z test falls back
    if h="$(hostname -s 2>/dev/null)"; then :; else h=""; fi
    if [ -z "$h" ]; then
        if h="$(hostname 2>/dev/null)"; then h="${h%%.*}"; else h=""; fi
    fi
    _aitlib_json_esc AITLIB_JSONL_HOST "${h:-unknown}"
    _aitlib_json_esc AITLIB_JSONL_OS "$(uname -s)"
    if [ -n "${AITOOLS_RUN_ID:-}" ]; then
        h="$AITOOLS_RUN_ID"
    else
        # 6 random bytes as hex, as the installers did; the -z test covers a failure
        h="$(od -An -N6 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')" || h=""
    fi
    _aitlib_json_esc AITLIB_RUN_ID "${h:-$$}"
}

# jsonl_record TS SCRIPT LEVEL MSG -- append one record to deploy.jsonl in the log
# directory (logging_init's LOG_DIR). Key order: ts, host, os, script, run_id,
# level, msg (the installers' order). run_id = AITOOLS_RUN_ID, else one random id
# per process. Logging must not break the run it records (logging.md section 5):
# the first failed write is one log_warn (audit A-16: the run goes on, and the
# warning says why its records are missing); later calls write nothing
# (AITLIB_JSONL_FAILED=true, set before the warning so a log() that calls
# jsonl_record (the jsonl option) does not recurse). Inside a relayed process
# (AITLIB_RELAYED=1, exported by every relay) it writes nothing: the outermost
# relay mirrors every structured line it prints, so each line is one record.
# Returns 0.
jsonl_record() {
    local f="${LOG_DIR:-$AITOOLS_LOG_DIR}/deploy.jsonl" ts sc lv msg
    if [ "${AITLIB_JSONL_FAILED:-false}" = "true" ]; then return 0; fi
    if [ "${AITLIB_RELAYED:-}" = "1" ]; then return 0; fi
    _aitlib_jsonl_init
    _aitlib_json_esc ts "$1"; _aitlib_json_esc sc "$2"; _aitlib_json_esc lv "$3"; _aitlib_json_esc msg "$4"
    # 2>/dev/null: the shell's own "cannot open" message; the failure is reported by
    # the log_warn below (the if is the result check)
    if ! printf '{"ts":"%s","host":"%s","os":"%s","script":"%s","run_id":"%s","level":"%s","msg":"%s"}\n' \
        "$ts" "$AITLIB_JSONL_HOST" "$AITLIB_JSONL_OS" "$sc" "$AITLIB_RUN_ID" "$lv" "$msg" 2>/dev/null >> "$f"; then
        AITLIB_JSONL_FAILED=true
        log_warn "deploy.jsonl: cannot write $(display_path "$f") -- structured log records are skipped for the rest of this run"
    fi
    return 0
}

# _aitlib_relay_reset QUIET MIRROR -- start relaying one child: zero the child
# counts and the relay state (_AITLIB_RELAY_*: the options, the last line, the
# script name of the last structured line, the script names of the error lines)
_aitlib_relay_reset() {
    AITLIB_CHILD_WARNINGS=0; AITLIB_CHILD_ERRORS=0
    _AITLIB_RELAY_QUIET="${1:-false}"; _AITLIB_RELAY_MIRROR="${2:-true}"
    _AITLIB_RELAY_LAST=""; _AITLIB_RELAY_LAST_SCRIPT=""; _AITLIB_RELAY_ERR_SCRIPTS=""
    _AITLIB_RELAY_LAST_OTHER=false
}

# _aitlib_relay_line LINE -- print one child console line (with --quiet only its
# warn and error lines), mirror it to deploy.jsonl when it is a structured log
# line (unless --no-mirror), count its warn/error level in the child counts
# (never in the parent's WARNINGS / ERRORS), and keep it as the child's last
# stdout line (not an exit footer, which only restates the counts: a failed
# child's reason comes from the line before it). A warning line is kept only
# while no other line has been: the kept line is a warning line only when the
# child printed nothing else (reference/logging.md 8.3, RFI 5899-31)
_aitlib_relay_line() {
    local line="$1" clean esc=$'\033' f_ts f_script f_level f_msg last
    local re='^\[([^]]+)\] \[([^]]+)\] \[([a-z]+)\] (.*)$'
    if [ -z "$line" ]; then return 0; fi
    clean="${line//$'\r'/}"
    last="$clean"
    clean="${clean//"${esc}[31m"/}"
    clean="${clean//"${esc}[33m"/}"
    clean="${clean//"${esc}[0m"/}"
    if [[ "$clean" =~ $re ]]; then
        f_ts="${BASH_REMATCH[1]}"; f_script="${BASH_REMATCH[2]}"; f_level="${BASH_REMATCH[3]}"; f_msg="${BASH_REMATCH[4]}"
        if [ "${_AITLIB_RELAY_QUIET:-false}" != "true" ] || [ "$f_level" = "warn" ] || [ "$f_level" = "error" ]; then
            printf '%s\n' "$line"
        fi
        if [ "${_AITLIB_RELAY_MIRROR:-true}" = "true" ]; then
            jsonl_record "$f_ts" "$f_script" "$f_level" "$f_msg"
        fi
        _AITLIB_RELAY_LAST_SCRIPT="$f_script"
        case "$f_msg" in
            "COMPLETED with "*|"FAILED with "*) return 0 ;;   # the exit footer restates the counts
        esac
        if [ "$f_level" != "warn" ]; then
            _AITLIB_RELAY_LAST="$last"; _AITLIB_RELAY_LAST_OTHER=true
        elif [ "${_AITLIB_RELAY_LAST_OTHER:-false}" != "true" ]; then
            _AITLIB_RELAY_LAST="$last"
        fi
        case "$f_level" in
            warn)  AITLIB_CHILD_WARNINGS=$((AITLIB_CHILD_WARNINGS + 1)) ;;
            error) _AITLIB_RELAY_ERR_SCRIPTS="${_AITLIB_RELAY_ERR_SCRIPTS}${f_script}"$'\n' ;;
        esac
        return 0
    fi
    case "$clean" in
        # a blank line is not kept (as Send-AitLibChildLine)
        *[![:space:]]*) _AITLIB_RELAY_LAST="$last"; _AITLIB_RELAY_LAST_OTHER=true ;;
    esac
    if [ "${_AITLIB_RELAY_QUIET:-false}" != "true" ]; then
        printf '%s\n' "$line"
    fi
    return 0
}

# _aitlib_relay_finish -- set AITLIB_CHILD_ERRORS to the child's own error lines:
# those whose [script] is the script of its last structured line (see the
# section comment)
_aitlib_relay_finish() {
    local s n=0
    while IFS= read -r s; do
        if [ -n "$s" ] && [ "$s" = "$_AITLIB_RELAY_LAST_SCRIPT" ]; then n=$((n + 1)); fi
    done <<< "$_AITLIB_RELAY_ERR_SCRIPTS"
    AITLIB_CHILD_ERRORS=$n
}

# relay_child_log TEXT -- relay the captured console output of a child script,
# line by line (see the section comment). Sets AITLIB_CHILD_WARNINGS and
# AITLIB_CHILD_ERRORS. No failure decision, no record: the caller decides.
# Returns 0.
relay_child_log() {
    local line
    _aitlib_relay_reset false true
    while IFS= read -r line || [ -n "$line" ]; do
        _aitlib_relay_line "$line"
    done <<< "$1"
    _aitlib_relay_finish
    return 0
}

# _aitlib_summary_count VAR KIND -- set VAR to the number of KIND records (WARN,
# ERROR, ...) in the run summary (AITOOLS_SUMMARY_FILE; 0 without one). An
# unreadable summary counts 0 and is a detail line. VAR must not be one of this
# function's locals (_aitlib_se_*): printf -v would set the local, not the
# caller's variable.
_aitlib_summary_count() {
    local _aitlib_se_n=0 _aitlib_se_l _aitlib_se_f="${AITOOLS_SUMMARY_FILE:-}" _aitlib_se_k="$2|"
    if [ -n "$_aitlib_se_f" ] && [ -f "$_aitlib_se_f" ]; then
        if [ -r "$_aitlib_se_f" ]; then
            while IFS= read -r _aitlib_se_l || [ -n "$_aitlib_se_l" ]; do
                case "$_aitlib_se_l" in "$_aitlib_se_k"*) _aitlib_se_n=$((_aitlib_se_n + 1)) ;; esac
            done < "$_aitlib_se_f"
        else
            log_detail "run summary unreadable ($_aitlib_se_f) -- its $2 records are not counted"
        fi
    fi
    printf -v "$1" '%s' "$_aitlib_se_n"
}

# _aitlib_error_norecord TEXT -- the library-internal non-recording error path
# (reference/logging.md 8.2): an error-level line, counted in ERRORS, no record.
# Used only by the relay (a failed child whose error the child already recorded,
# or an abort it recorded) and by _managed_abort.
_aitlib_error_norecord() {
    log "$1" "error"
    ERRORS=$((ERRORS + 1))
}

# _aitlib_warn_norecord TEXT -- the same for a warning: the relay's
# --abort-warn abort that the child already recorded (logged, counted, not
# recorded again). Used only by the relay.
_aitlib_warn_norecord() {
    log "$1" "warn"
    WARNINGS=$((WARNINGS + 1))
}

# _aitlib_relay_name TOOL LABEL [CMD ARGS...] -- the record name of a relayed
# child (reference/logging.md 8.3 "Its name"): TOOL; else the base name, without
# extension, of the first argument ending in .sh or .ps1; else LABEL (pure)
_aitlib_relay_name() {
    local tool="$1" label="$2" a b
    shift 2
    if [ -n "$tool" ]; then printf '%s' "$tool"; return 0; fi
    for a in "$@"; do
        case "$a" in
            *.sh|*.ps1)
                b="${a##*/}"; b="${b##*\\}"; b="${b%.*}"
                if [ -n "$b" ]; then printf '%s' "$b"; return 0; fi ;;
        esac
    done
    printf '%s' "$label"
}

# _aitlib_relay_exec RCF ERRF CMD [ARGS...] -- the relay's child process (run in a
# process substitution, so in a subshell): CMD's stdout goes to this subshell's
# stdout (the relay reads it), its stderr is teed to ERRF while it still reaches
# the console, AITLIB_RELAYED=1 is exported to it (only the outermost relay
# mirrors to deploy.jsonl), and its exit code is written to RCF once CMD and the
# tee have both ended. stdin is the caller's. bash 3.2 safe: a pipeline, not a
# second process substitution, so the tee has finished when RCF is written.
_aitlib_relay_exec() {
    local rcf="$1" errf="$2" rc=0
    shift 2
    # the subshell's own errexit / pipefail must not end it before RCF is written
    set +e
    export AITLIB_RELAYED=1
    { "$@" 2>&1 1>&3 3>&- | tee "$errf" >&2 3>&-; rc=${PIPESTATUS[0]}; } 3>&1
    printf '%s\n' "$rc" > "$rcf"
}

# run_child_relayed [--summary-tool TOOL] [--abort-warn] [--no-mirror] [--quiet]
#                   LABEL CMD [ARGS...]
# Run a child script (e.g. run_child_relayed --summary-tool "aitools config"
# "Step 5: setup-user-config.sh" "${BASH:-bash}" "$writer" ...) and relay its
# stdout line by line as it arrives (not captured until the end). The rules are
# the section comment's (reference/logging.md 8.3). Options, in any order before
# LABEL:
#   --summary-tool TOOL  the record name of a failed or aborted child
#   --abort-warn         record a user abort (exit 2) as one warning,
#                        WARN|<name>|aborted by user, counted as one parent
#                        warning and no error (the runner's request for
#                        deploy-harness); without it an abort is a failed child
#   --no-mirror          do not mirror the child's structured lines to
#                        deploy.jsonl (the child writes its own records)
#   --quiet              print only the child's warn and error lines (every
#                        line is still parsed, mirrored and counted)
# The child's stderr is teed to a temp file while it still reaches the console
# (its last 20 lines give a failed child's reason); a child's stderr is
# therefore not a terminal (plan 5.5 limit 5). Prompts go to /dev/tty and are
# unaffected. A prompt the child writes to /dev/tty can still overtake its last
# few lines when it follows them with no work in between (review B n-1). Only
# complete lines are relayed: a child whose prompt goes to stdout without a
# newline (e.g. pwsh [Console]::Write under Git Bash) must not be relayed while
# it prompts. stdin is the caller's. CMD runs in a subshell: it must be a
# separate process (a script), not a function that changes the caller's
# variables. Every relay exports AITLIB_RELAYED=1 to its child: inside a relayed
# process the relays do not mirror and jsonl_record writes nothing, so the
# outermost relay mirrors each structured line once.
# Not run at all (no CMD, a temp file not created): one write_error <name>
# "<label> not run" <cause>, return 1.
# Sets AITLIB_CHILD_RC, AITLIB_CHILD_WARNINGS, AITLIB_CHILD_ERRORS. Returns 0
# when the child exited 0 with no error line of its own; 1 otherwise (a failed
# child, an abort -- also with --abort-warn: AITLIB_CHILD_RC=2 tells the runner
# to stop -- or not run). Call it as: run_child_relayed ... || rc=$?
# It returns when every process holding the child's stdout and stderr has
# closed them (a background grandchild keeps it waiting).
run_child_relayed() {
    local tool="" label line rcf="" errf="" rc="" name what reason tail_err="" err=""
    local abort_warn=false quiet=false mirror=true w0=0 e0=0 w1=0 e1=0
    AITLIB_CHILD_RC=0; AITLIB_CHILD_WARNINGS=0; AITLIB_CHILD_ERRORS=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --summary-tool)
                if [ "$#" -lt 2 ]; then
                    AITLIB_CHILD_RC=1
                    write_error "" "run_child_relayed not run" "--summary-tool needs a value (caller bug)"
                    return 1
                fi
                tool="$2"; shift 2 ;;
            --abort-warn) abort_warn=true; shift ;;
            --no-mirror)  mirror=false; shift ;;
            --quiet)      quiet=true; shift ;;
            *) break ;;
        esac
    done
    label="${1:-child script}"
    if [ "$#" -gt 0 ]; then shift; fi
    name=$(_aitlib_relay_name "$tool" "$label" "$@")
    if [ "$#" -eq 0 ]; then
        AITLIB_CHILD_RC=1
        write_error "$name" "$label not run" "no command given"
        return 1
    fi
    if ! err=$(mktemp 2>&1); then
        AITLIB_CHILD_RC=1
        write_error "$name" "$label not run" "mktemp failed${err:+: $err}"
        return 1
    fi
    rcf="$err"
    if ! err=$(mktemp 2>&1); then
        _aitlib_rm_tmp "$rcf" "$label"
        AITLIB_CHILD_RC=1
        write_error "$name" "$label not run" "mktemp failed${err:+: $err}"
        return 1
    fi
    errf="$err"
    # Inside a relayed process the relays do not mirror (only the outermost does)
    if [ "${AITLIB_RELAYED:-}" = "1" ]; then mirror=false; fi
    _aitlib_summary_count w0 WARN
    _aitlib_summary_count e0 ERROR
    _aitlib_relay_reset "$quiet" "$mirror"
    while IFS= read -r line || [ -n "$line" ]; do
        _aitlib_relay_line "$line"
    done < <(_aitlib_relay_exec "$rcf" "$errf" "$@")
    _aitlib_relay_finish
    # a failed read leaves rc empty: the case below counts it as a failure
    rc="$(cat "$rcf")" || rc=""
    _aitlib_rm_tmp "$rcf" "$label"
    case "$rc" in
        ''|*[!0-9]*) log_detail "$label: exit code not recorded -- counted as a failure"; rc=1 ;;
    esac
    AITLIB_CHILD_RC="$rc"
    if [ "$rc" -eq 0 ] && [ "$AITLIB_CHILD_ERRORS" -eq 0 ]; then
        _aitlib_rm_tmp "$errf" "$label"
        return 0
    fi
    # The child's last 20 stderr lines (stderr reached the console already)
    if [ -s "$errf" ]; then
        tail_err=$(tail -n 20 "$errf") || tail_err=""
    fi
    _aitlib_rm_tmp "$errf" "$label"
    _aitlib_summary_count w1 WARN
    _aitlib_summary_count e1 ERROR
    if [ "$rc" -eq 2 ]; then
        # A user abort (D-TS13): recorded once, by the innermost relay
        log_detail "$label: exited 2 (user abort)"
        if [ "$w1" -gt "$w0" ] || [ "$e1" -gt "$e0" ]; then
            if $abort_warn; then
                _aitlib_warn_norecord "$label aborted by user -- the child recorded it"
            else
                _aitlib_error_norecord "$label failed (exit 2): aborted by user -- the child recorded it"
            fi
        elif $abort_warn; then
            write_warn "$name" "aborted by user"
        else
            write_error "$name" "$label failed (exit 2)" "aborted by user"
        fi
        return 1
    fi
    what="$label failed (exit $rc)"
    case "$tail_err" in
        *[![:space:]]*) reason=$(error_reason "$tail_err" "$rc") ;;
        *) reason=$(error_reason "$_AITLIB_RELAY_LAST" "$rc") ;;
    esac
    if [ "$e1" -gt "$e0" ]; then
        _aitlib_error_norecord "$what: $reason -- the child recorded its error"
    else
        write_error "$name" "$what" "$reason"
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Logging init
# ---------------------------------------------------------------------------
# Sets SCRIPT_NAME, LOG_DIR, LOG_FILE; resets ERRORS, WARNINGS; creates log dir.
# The run summary file (AITOOLS_SUMMARY_FILE) is untouched (reference/logging.md
# 8.6).
# Usage: logging_init "setup-foo"
#
# Library options (reference/logging.md sections 3, 5, 7, 8.2). Every option is
# off when the library is sourced (a parent's value never reaches a child) and
# is set by the script once, after sourcing the library: after logging_init, or
# before it when logging_init's own environment warning must already follow it
# (the resolver's stderr console). No script overrides a logging function.
#   AITLIB_OPT_JSONL=true          log / log_ok / log_warn / log_error (and
#                                  write_warn / write_action / write_error) also
#                                  write one deploy.jsonl record per line
#                                  (jsonl_record; the installers). Inside a
#                                  relayed process it writes nothing: the
#                                  outermost relay mirrors the line.
#   AITLIB_OPT_CONSOLE_STDERR=true console lines go to stderr, so stdout carries
#                                  only data; and recording is off: the helpers
#                                  log and count but write no run summary record
#                                  (a library-style tool, logging.md section 7:
#                                  aitools-profile)
#   AITLIB_OPT_COLOR_AUTO=true     warn and error console lines are coloured only
#                                  when the console stream in use (stdout, or
#                                  stderr with the option above) is a terminal
#                                  (build-deploy)
# ---------------------------------------------------------------------------
# Log rotation (reference/logging.md §4): size-based, 5 MB x 5 backups.
# Fail-safe -- a broken rotate must never break the operation it records (§5).
# ---------------------------------------------------------------------------
_LOG_MAX_BYTES=5242880   # 5 MB
_LOG_BACKUP_COUNT=5
_rotate_log() {
    local f="$1"
    [ -f "$f" ] || return 0
    local size
    if [ "$(uname -s)" = "Darwin" ]; then
        size=$(stat -f %z "$f" 2>/dev/null || echo 0)
    else
        size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    fi
    [ "$size" -ge "$_LOG_MAX_BYTES" ] || return 0
    # Shift backups: <f>.4 -> <f>.5 ... <f>.1 -> <f>.2, then <f> -> <f>.1.
    # All mutations tolerate failure (fail-safe logging, logging.md §5).
    rm -f "$f.$_LOG_BACKUP_COUNT" 2>/dev/null || true
    local i=$_LOG_BACKUP_COUNT
    while [ "$i" -gt 1 ]; do
        local prev=$((i - 1))
        if [ -f "$f.$prev" ]; then
            mv -f "$f.$prev" "$f.$i" 2>/dev/null || true
        fi
        i=$prev
    done
    mv -f "$f" "$f.1" 2>/dev/null || true
}

logging_init() {
    SCRIPT_NAME="${1:?logging_init requires a script name}"
    LOG_DIR="$AITOOLS_LOG_DIR"
    LOG_FILE="$LOG_DIR/deploy.log"
    # Fail-safe (logging.md section 5): a log directory that cannot be created
    # leaves every log write failing, and each failed write is swallowed; the run
    # goes on with its console output
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    _rotate_log "$LOG_FILE"
    ERRORS=0
    WARNINGS=0
    _log_aitools_environment
}

# Record the resolved platform/environment (file-only detail line); warn when an
# AITOOLS_ENVIRONMENT override was invalid or not possible on this platform. The
# resolved value replaces an exported override, so child scripts do not warn again.
_log_aitools_environment() {
    log_detail "platform=$AITOOLS_PLATFORM environment=$AITOOLS_ENVIRONMENT (AITOOLS_ENVIRONMENT='$_AITOOLS_ENVIRONMENT_REQUESTED' CLAUDE_CODE_REMOTE='${CLAUDE_CODE_REMOTE:-}' type='${CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE:-}')"
    if [ -n "$_AITOOLS_ENVIRONMENT_REQUESTED" ] && [ "$_AITOOLS_ENVIRONMENT_REQUESTED" != "$AITOOLS_ENVIRONMENT" ]; then
        log_warn "AITOOLS_ENVIRONMENT='$_AITOOLS_ENVIRONMENT_REQUESTED' ignored (valid: local; claude-code-web on Linux only) -- environment is $AITOOLS_ENVIRONMENT"
    fi
}

# ---------------------------------------------------------------------------
# Standard logging (Pattern A: console + log file, with [level] tag)
# ---------------------------------------------------------------------------
# _aitlib_log_append LINE FILE -- append LINE to the log FILE. Fail-safe
# (reference/logging.md section 5: "A failed log write is swallowed (the only
# sanctioned silent-suppression in the harness), because a broken log must not
# break the operation it records"): an unwritable, locked or missing log, or one
# that is a directory, returns 0 with no message, so set -e never ends the run
# and the console line is still printed. Parity: Add-AitLibLogText.
_aitlib_log_append() {
    { printf '%s\n' "$1" >> "$2"; } 2>/dev/null || true
}

# _aitlib_console LEVEL LINE -- print one console line: stdout, or stderr with
# AITLIB_OPT_CONSOLE_STDERR; warn yellow, error red, unless AITLIB_OPT_COLOR_AUTO
# is set and that stream is not a terminal
_aitlib_console() {
    local fd=1 colour=""
    if [ "$AITLIB_OPT_CONSOLE_STDERR" = "true" ]; then fd=2; fi
    case "$1" in
        error) colour="31" ;;
        warn)  colour="33" ;;
    esac
    if [ -n "$colour" ] && [ "$AITLIB_OPT_COLOR_AUTO" = "true" ] && [ ! -t "$fd" ]; then colour=""; fi
    if [ "$fd" = "2" ]; then
        if [ -n "$colour" ]; then printf '\033[%sm%s\033[0m\n' "$colour" "$2" >&2; else printf '%s\n' "$2" >&2; fi
    else
        if [ -n "$colour" ]; then printf '\033[%sm%s\033[0m\n' "$colour" "$2"; else printf '%s\n' "$2"; fi
    fi
}

log() {
    local level="${2:-info}" ts line
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    line="[$ts] [${SCRIPT_NAME:-unknown}] [$level] $1"
    _aitlib_log_append "$line" "${LOG_FILE:-}"
    _aitlib_console "$level" "$line"
    if [ "$AITLIB_OPT_JSONL" = "true" ]; then jsonl_record "$ts" "${SCRIPT_NAME:-unknown}" "$level" "$1"; fi
}
log_ok()    { log "$1" "ok"; }
log_detail() {
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _aitlib_log_append "[$ts] [${SCRIPT_NAME:-unknown}] [detail] $1" "${LOG_FILE:-}"
}

# ---------------------------------------------------------------------------
# Warnings, errors and run summary records (reference/logging.md 8.2-8.4)
#   log_warn TEXT                   [warn] TEXT; WARNINGS +1; WARN|<script>|TEXT
#   log_error TEXT                  [error] TEXT; ERRORS +1; ERROR|<script>|TEXT|.
#                                   Only for an error whose TEXT states its cause
#   write_warn TOOL TEXT            [warn] TEXT; WARNINGS +1; WARN|TOOL|TEXT
#   write_action TOOL TEXT ACTION   write_warn TOOL TEXT, then ACTION||ACTION
#                                   (an identical ACTION already in the file is
#                                   a detail line, not written again)
#   write_error TOOL WHAT REASON    [error] WHAT: REASON (WHAT alone when REASON
#                                   is empty); ERRORS +1; ERROR|TOOL|WHAT|REASON
#   error_reason OUTPUT EXIT_CODE   prints one REASON (8.3); OUTPUT -> detail lines
#   write_summary OK|DETAIL|ACTION TOOL TEXT   the record as written (any other
#                                   category: no record, one log_warn; below)
# An empty TOOL is the logging script's name (SCRIPT_NAME). Every record goes
# through _aitlib_record: CR and LF become a space in every field, "|" becomes
# "/" in every field except an ACTION's instruction; nothing is written outside
# a run (no AITOOLS_SUMMARY_FILE) or with AITLIB_OPT_CONSOLE_STDERR; a record
# that cannot be written is ignored (8.3 Fail-safe).
# ---------------------------------------------------------------------------

# _aitlib_record KIND FIELD... -- append one record to the run summary file.
# KIND ACTION takes "" and the instruction: ACTION||<instruction>.
_aitlib_record() {
    local f="${AITOOLS_SUMMARY_FILE:-}" kind="${1:-}" rec v
    if [ -z "$f" ] || [ "$AITLIB_OPT_CONSOLE_STDERR" = "true" ]; then return 0; fi
    shift
    if [ "$kind" = "ACTION" ]; then
        v="${2:-}"
        v="${v//$'\r'/ }"; v="${v//$'\n'/ }"
        rec="ACTION||$v"
    else
        rec="$kind"
        for v in "$@"; do
            v="${v//$'\r'/ }"; v="${v//$'\n'/ }"; v="${v//|//}"
            rec="$rec|$v"
        done
    fi
    # Fail-safe (reference/logging.md 8.3): the shell's own message is dropped and
    # the failure ignored, as a failed log line is (section 5)
    { printf '%s\n' "$rec" >> "$f"; } 2>/dev/null || true
}

# _aitlib_action_record TEXT -- ACTION||TEXT unless the run summary already holds
# that exact record (CR and LF compared as written: a space)
_aitlib_action_record() {
    local f="${AITOOLS_SUMMARY_FILE:-}" t="${1:-}" rc=0
    t="${t//$'\r'/ }"; t="${t//$'\n'/ }"
    if [ -n "$f" ] && [ -f "$f" ]; then
        # 2>/dev/null: an unreadable file is grep exit 2, checked below
        grep -qxF -- "ACTION||$t" "$f" 2>/dev/null || rc=$?
        if [ "$rc" -eq 0 ]; then
            log_detail "ACTION already in the run summary: $t"
            return 0
        fi
        if [ "$rc" -gt 1 ]; then log_detail "run summary unreadable ($f) -- ACTION written without the duplicate check"; fi
    fi
    _aitlib_record ACTION "" "$t"
}

log_warn() {
    log "$1" "warn"
    WARNINGS=$((WARNINGS + 1))
    _aitlib_record WARN "${SCRIPT_NAME:-unknown}" "$1"
}
log_error() {
    log "$1" "error"
    ERRORS=$((ERRORS + 1))
    _aitlib_record ERROR "${SCRIPT_NAME:-unknown}" "$1" ""
}
write_warn() {
    local name="${1:-}"
    if [ -z "$name" ]; then name="${SCRIPT_NAME:-unknown}"; fi
    log "${2:-}" "warn"
    WARNINGS=$((WARNINGS + 1))
    _aitlib_record WARN "$name" "${2:-}"
}
write_action() {
    write_warn "${1:-}" "${2:-}"
    _aitlib_action_record "${3:-}"
}
write_error() {
    local name="${1:-}" what="${2:-}" reason="${3:-}"
    if [ -z "$name" ]; then name="${SCRIPT_NAME:-unknown}"; fi
    if [ -n "$reason" ]; then log "$what: $reason" "error"; else log "$what" "error"; fi
    ERRORS=$((ERRORS + 1))
    _aitlib_record ERROR "$name" "$what" "$reason"
}

# Build-failure signatures (reference/logging.md 8.3 rule 1; script-standards
# "Build prerequisite validation"): one table, the same in aitools-lib.ps1
# ($script:BuildFailureSignatures: same names, patterns and remedies, same
# order; the first match wins). Patterns are case-insensitive regular
# expressions valid in Perl and .NET. Entries are NAME<TAB>PATTERN<TAB>REMEDY.
# Add new entries here and in aitools-lib.ps1 when new build failures are
# discovered (remedies from official tool documentation: tool-lifecycle.md).
AITLIB_BUILD_SIGNATURES="NASM	NASM command not found	brew install nasm / apt-get install nasm / winget install NASM.NASM
Linker	linker.*not found|link\\.exe.*not found	Install Xcode CLI tools (macOS), build-essential (Linux) or MSVC Build Tools with C++ workload (Windows)
CMake	cmake.*not found|Could not find cmake	brew install cmake / uv tool install cmake (see cmake.org/download)
pkg-config	pkg-config.*not found	brew install pkg-config / apt-get install pkg-config
Python headers	Python\\.h.*not found|python[0-9.]*-dev(el)?\\b	Install python3-dev or python3-devel (Python development headers)
C compiler	C compiler.*not found|\\bcc\\b.*not found	Install a C compiler (MSVC/gcc/clang)
OpenSSL	openssl.*not found|OPENSSL_DIR	brew install openssl / apt-get install libssl-dev, or set OPENSSL_DIR"

# error_reason OUTPUT EXIT_CODE -- print the REASON for a failed external command
# (reference/logging.md 8.3 "Every error has a reason"), for write_error:
#   write_error "pandoc" "brew install failed" "$(error_reason "$out" "$rc")"
# The first that applies:
#   1. a known build-failure signature (AITLIB_BUILD_SIGNATURES), as
#      "<NAME>: <REMEDY>";
#   2. (PowerShell only: the exception message)
#   3. the first line that is not a warning line matching an error marker: a
#      word that ends in "error:", any case (letters, digits, - and _), at the
#      start of the line or after a space; "fatal:", any case, at the start or
#      after a space; "E: " at the start; "syntax error", any case, anywhere;
#   4. the last non-empty line that is not a warning line;
#   5. "exit <EXIT_CODE>" when the output has a warning line (every non-empty
#      line is one);
#   6. "no output (exit <EXIT_CODE>)".
# Before matching, CR, ANSI CSI sequences and a leading "[<time>] [<script>]
# [<level>] " (the level in any case) are removed from each line;
# whitespace-only lines are empty; the reason printed is that line with its
# leading and trailing blanks trimmed. A warning line is one whose prefix has
# the level warn ("[<time>] [<script>] [warn] "), decided after CR and ANSI are
# removed and before the prefix is removed (RFI 5899-31: rules 3 and 4 never
# take a warning line as the reason). OUTPUT is logged to deploy.log as detail
# lines ("output: <line>", CR and ANSI removed, the prefix kept, empty lines
# skipped; the same lines as Get-AitErrorReason), so a caller does not log it
# as well (8.2). One
# perl process; no grep -P, no early-exit pipeline (bash 3.2 safe). Without
# perl (setup-perl runs before perl exists), or when perl fails, the reason
# comes from _aitlib_error_reason_noperl: rules 3-6 in bash, no build-failure
# signatures (rule 1), and a detail line says so. Always prints one reason and
# returns 0.
error_reason() {
    local ts r rc=0
    if ! command -v perl >/dev/null 2>&1; then
        log_detail "error_reason: perl not found -- reason taken without the build-failure signatures"
        _aitlib_error_reason_noperl "${1:-}" "${2:-}" true
        return 0
    fi
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    r=$(printf '%s' "${1:-}" | AITLIB_ER_CODE="${2:-}" AITLIB_ER_SIGS="$AITLIB_BUILD_SIGNATURES" \
        AITLIB_ER_LOG="${LOG_FILE:-}" AITLIB_ER_PREFIX="[$ts] [${SCRIPT_NAME:-unknown}] [detail] output: " perl -e '
        my $in = do { local $/; <STDIN> };
        $in = "" unless defined $in;
        my (@raw, @clean, @warn);
        for my $l (split /\n/, $in, -1) {
            $l =~ s/\r//g;
            $l =~ s/\e\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]//g;
            push @raw, $l;
            push @warn, ($l =~ /^\[[^\]]*\] \[[^\]]*\] \[warn\] / ? 1 : 0);
            (my $c = $l) =~ s/^\[[^\]]*\] \[[^\]]*\] \[[A-Za-z]+\] //;
            push @clean, $c;
        }
        # The full output, as detail lines (fail-safe: a log that cannot be
        # opened is skipped, as the library skips a failed log write)
        if ($ENV{AITLIB_ER_LOG} ne "" && open(my $fh, ">>", $ENV{AITLIB_ER_LOG})) {
            print $fh $ENV{AITLIB_ER_PREFIX}, $_, "\n" for grep { /\S/ } @raw;
            close $fh;
        }
        sub trim { my $s = shift; $s =~ s/^\s+//; $s =~ s/\s+\z//; return $s }
        my $out;
        for my $sig (split /\n/, $ENV{AITLIB_ER_SIGS}) {
            my ($name, $pat, $remedy) = split /\t/, $sig, 3;
            next unless defined $remedy;
            if ($in =~ /$pat/i) { $out = "$name: $remedy"; last }
        }
        if (!defined $out) {
            for my $i (0 .. $#clean) {
                next if $warn[$i];
                my $c = $clean[$i];
                if ($c =~ /(?:^| )[A-Za-z0-9_-]*error:/i || $c =~ /(?:^| )fatal:/i
                    || $c =~ /^E: / || $c =~ /syntax error/i) { $out = trim($c); last }
            }
        }
        if (!defined $out) {
            for my $i (reverse 0 .. $#clean) {
                next if $warn[$i];
                if ($clean[$i] =~ /\S/) { $out = trim($clean[$i]); last }
            }
        }
        $out = "exit $ENV{AITLIB_ER_CODE}" if !defined $out && grep { $_ } @warn;
        $out = "no output (exit $ENV{AITLIB_ER_CODE})" unless defined $out;
        print $out, "\n";
    ') || rc=$?
    if [ "$rc" -ne 0 ] || [ -z "$r" ]; then
        # perl failed: its detail lines may be in the log already, so not again
        log_detail "error_reason: perl failed (exit $rc) -- reason taken without the build-failure signatures"
        _aitlib_error_reason_noperl "${1:-}" "${2:-}" false
        return 0
    fi
    printf '%s\n' "$r"
    return 0
}

# _aitlib_strip_csi TEXT -- set _AITLIB_CSI_OUT to TEXT without its ANSI CSI
# sequences (ESC [, bytes 0x30-0x3f, bytes 0x20-0x2f, one byte 0x40-0x7e: the
# pattern error_reason's perl removes), found by byte value (printf -v, bash
# 3.1+), so no locale-dependent range is used. No subshell.
_AITLIB_CSI_OUT=""
_aitlib_strip_csi() {
    local s="${1:-}" out="" rest ch n i esc=$'\033'
    while :; do
        case "$s" in *"$esc["*) ;; *) break ;; esac
        out="$out${s%%"$esc["*}"
        rest="${s#*"$esc["}"
        i=0
        while [ "$i" -lt "${#rest}" ]; do
            ch="${rest:$i:1}"; printf -v n '%d' "'$ch"
            if [ "$n" -ge 48 ] && [ "$n" -le 63 ]; then i=$((i + 1)); else break; fi
        done
        while [ "$i" -lt "${#rest}" ]; do
            ch="${rest:$i:1}"; printf -v n '%d' "'$ch"
            if [ "$n" -ge 32 ] && [ "$n" -le 47 ]; then i=$((i + 1)); else break; fi
        done
        if [ "$i" -lt "${#rest}" ]; then
            ch="${rest:$i:1}"; printf -v n '%d' "'$ch"
            if [ "$n" -ge 64 ] && [ "$n" -le 126 ]; then
                s="${rest:$((i + 1))}"
                continue
            fi
        fi
        # not a complete CSI sequence: ESC [ is kept, the scan goes on after it
        out="$out$esc["
        s="$rest"
    done
    _AITLIB_CSI_OUT="$out$s"
}

# _aitlib_error_reason_noperl OUTPUT EXIT_CODE LOG -- error_reason without perl:
# rules 3-6 of error_reason (the first error-marker line and the last non-empty
# line, each not a warning line; "exit <N>"; "no output (exit <N>)"), with the
# same line cleaning (CR, ANSI CSI, the "[<time>] [<script>] [<level>] "
# prefix), in bash 3.2 (ERE through [[ =~ ]], no subprocess). Character classes
# are spelled out, never ranges (a range in [[ =~ ]] depends on the locale: bash
# 5 under UTF-8 rejects [ -/]), and a CSI sequence is found by byte value. The
# build-failure signatures (rule 1, Perl regular expressions) are not tried.
# LOG=true logs each non-empty line as a detail line, as the perl path does.
# Prints one reason; returns 0.
_aitlib_error_reason_noperl() {
    local in="${1:-}" code="${2:-}" dolog="${3:-true}" l c
    local lc='abcdefghijklmnopqrstuvwxyz' uc='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local wre='^\[[^]]*\] \[[^]]*\] \[warn\] '
    local pfx="^\\[[^]]*\\] \\[[^]]*\\] \\[[$uc$lc]+\\] (.*)\$"
    local mk1="(^| )[${uc}${lc}0123456789_-]*[Ee][Rr][Rr][Oo][Rr]:"
    local mk2='(^| )[Ff][Aa][Tt][Aa][Ll]:'
    local mk3='^E: '
    local mk4='[Ss][Yy][Nn][Tt][Aa][Xx] [Ee][Rr][Rr][Oo][Rr]'
    local marker="" last="" sawwarn=false iswarn
    while IFS= read -r l || [ -n "$l" ]; do
        l="${l//$'\r'/}"
        _aitlib_strip_csi "$l"; l="$_AITLIB_CSI_OUT"
        case "$l" in *[![:space:]]*) ;; *) continue ;; esac
        if [ "$dolog" = "true" ]; then log_detail "output: $l"; fi
        iswarn=false
        if [[ "$l" =~ $wre ]]; then iswarn=true; sawwarn=true; fi
        c="$l"
        if [[ "$l" =~ $pfx ]]; then c="${BASH_REMATCH[1]}"; fi
        if [ -z "$marker" ] && [ "$iswarn" = "false" ]; then
            if [[ "$c" =~ $mk1 ]] || [[ "$c" =~ $mk2 ]] || [[ "$c" =~ $mk3 ]] || [[ "$c" =~ $mk4 ]]; then
                marker="$c"
            fi
        fi
        c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}"
        if [ "$iswarn" = "false" ] && [ -n "$c" ]; then last="$c"; fi
    done <<< "$in"
    if [ -n "$marker" ]; then
        marker="${marker#"${marker%%[![:space:]]*}"}"; marker="${marker%"${marker##*[![:space:]]}"}"
        printf '%s\n' "$marker"
    elif [ -n "$last" ]; then printf '%s\n' "$last"
    elif [ "$sawwarn" = "true" ]; then printf 'exit %s\n' "$code"
    else printf 'no output (exit %s)\n' "$code"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Agentic AI invocation -- generalized wrapper for claude/agent CLI
# ---------------------------------------------------------------------------
# Purpose: Standardized AI CLI invocation with speed/permission tiers,
#   validation callbacks, automatic retry, and telemetry logging.
# Inputs: SPEED (fast/balanced/quality), PERMISSIONS (none/readonly/full/
#   dangerous), VALIDATE_FN (function name, receives output as $1),
#   MAX_RETRIES (retry count on validation failure). Prompt from stdin.
# Expected output: Raw AI-generated text on stdout.
# Validation: Caller-provided VALIDATE_FN must return 0 (pass) or 1 (fail)
#   and set AI_REJECT_REASON on failure.
# Known limitations: Agent CLI has no --model flag; speed is hint-only via
#   prompt prefix. Retry prepends rejection reason but may not fix structural
#   issues (e.g., model always wrapping in code fences).

# File-only AI telemetry logging (avoids stdout capture interference when
# invoke_ai output is captured via $()). Does not increment ERRORS/WARNINGS --
# callers decide whether to count invoke_ai failures.
_ai_log() {
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _aitlib_log_append "[$ts] [$SCRIPT_NAME] [${2:-info}] $1" "${LOG_FILE:-/dev/null}"
}

AI_REJECT_REASON=""

invoke_ai() {
    local speed="${1:-balanced}"
    local permissions="${2:-none}"
    local validate_fn="${3:-}"
    local max_retries="${4:-0}"

    AI_REJECT_REASON=""

    # Read prompt from stdin
    local prompt
    prompt=$(cat)

    # Detect backend
    # command -v exempt: existence check with explicit fallback chain
    local cli_cmd=""
    if command -v claude >/dev/null 2>&1; then
        cli_cmd="claude"
    elif $IS_WINDOWS; then
        # Windows Git Bash: agent may be on PowerShell PATH only
        local agent_path
        agent_path=$(pwsh -NoProfile -Command \
            'Get-Command agent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source' \
            2>/dev/null) || true  # pwsh may not be installed; fallback is no agent CLI
        if [ -n "$agent_path" ]; then cli_cmd="agent"; fi
    elif command -v agent >/dev/null 2>&1; then
        cli_cmd="agent"
    fi

    if [ -z "$cli_cmd" ]; then
        AI_REJECT_REASON="No AI CLI available (claude or agent)"
        _ai_log "AI invocation: no CLI available (claude or agent)" "error"
        return 1
    fi

    # Build CLI flags
    local -a flags=()

    if [ "$cli_cmd" = "claude" ]; then
        flags+=("-p" "--no-session-persistence")
        # Speed mapping (claude CLI: explicit model + effort)
        case "$speed" in
            fast)     flags+=("--model" "haiku" "--effort" "low") ;;
            balanced) flags+=("--model" "sonnet") ;;
            quality)  flags+=("--model" "opus" "--effort" "high") ;;
        esac
        # Permission mapping
        case "$permissions" in
            none)      flags+=("--allowedTools" "") ;;
            readonly)  flags+=("--allowedTools" "Read Glob Grep") ;;
            full)      ;; # default -- no restriction
            dangerous) flags+=("--dangerously-skip-permissions") ;;
        esac
        # System prompt hints for speed tiers
        case "$speed" in
            fast)    flags+=("--append-system-prompt" "Be concise and direct.") ;;
            quality) flags+=("--append-system-prompt" "Take your time. Be thorough.") ;;
        esac
    else
        # Agent CLI -- no --model flag; speed via prompt prefix only
        flags+=("-p" "--trust")
        # Permission mapping
        case "$permissions" in
            none)      flags+=("--mode" "ask") ;;
            readonly)  flags+=("--mode" "plan") ;;
            full)      ;; # default
            dangerous) flags+=("--force") ;;
        esac
    fi

    # Speed prefix for agent CLI (no model flag available)
    local speed_prefix=""
    if [ "$cli_cmd" = "agent" ]; then
        case "$speed" in
            fast)    speed_prefix="Be concise and direct. Prioritize speed.\n\n" ;;
            quality) speed_prefix="Take your time. Be thorough and precise.\n\n" ;;
        esac
    fi

    # Retry loop
    local attempt=0
    local current_prompt="$prompt"

    while [ "$attempt" -le "$max_retries" ]; do
        attempt=$((attempt + 1))

        _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt"

        local full_prompt
        full_prompt=$(printf '%b%s' "$speed_prefix" "$current_prompt")

        local output
        # Suppress set -e abort; CLI may exit non-zero on model errors
        output=$(printf '%s' "$full_prompt" | "$cli_cmd" "${flags[@]}" 2>&1) || true

        if [ -z "$output" ]; then
            AI_REJECT_REASON="Empty output from $cli_cmd"
            _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt result=empty" "warn"
            if [ "$attempt" -le "$max_retries" ]; then
                current_prompt=$(printf 'Your previous output was empty. Try again.\n\n%s' "$prompt")
                continue
            fi
            return 1
        fi

        # Validate if function provided
        if [ -n "$validate_fn" ]; then
            if ! "$validate_fn" "$output"; then
                [ -z "$AI_REJECT_REASON" ] && AI_REJECT_REASON="Validation failed"
                _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt result=rejected reason=$AI_REJECT_REASON" "warn"
                while IFS= read -r _rej_line; do
                    log_detail "ai-rejected: $_rej_line"
                done <<< "$output"
                if [ "$attempt" -le "$max_retries" ]; then
                    current_prompt=$(printf 'Your previous output was rejected: %s. Try again.\n\n%s' \
                        "$AI_REJECT_REASON" "$prompt")
                    continue
                fi
                _ai_log "AI invocation: speed=$speed backend=$cli_cmd exhausted after $attempt attempts" "warn"
                return 1
            fi
        fi

        # Success
        _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt result=accepted"
        printf '%s' "$output"
        return 0
    done

    return 1
}

# ---------------------------------------------------------------------------
# Summary writer: write_summary OK|DETAIL|ACTION TOOL TEXT (reference/logging.md
# 8.4). The record is written as given; the category is never changed (a
# warning or error never recolours a tool's OK record: 8.3). ACTION writes
# ACTION||TEXT (TOOL ignored), not de-duplicated (write_action and
# _aitlib_action_once de-duplicate). Any other category (the retired WARN and
# ERROR, a lower-case word, a typo) writes no record: a WARN or ERROR record
# comes only from the warning and error helpers (8.2: write_warn, write_action,
# log_warn, write_error, log_error). So that such a call never vanishes, it is
# one log_warn under the script name, quoting the call: "invalid summary
# category CAT -- not recorded: TOOL: TEXT" (something wrong in the calling
# script: 8.3 "What is a warning"). check-script-compliance steps 12 and 13
# fail on such a call in scripts/. Parity: Write-Summary.
# ---------------------------------------------------------------------------
write_summary() {
    local cat="${1:-}"
    case "$cat" in
        OK|DETAIL) _aitlib_record "$cat" "${2:-}" "${3:-}" ;;
        ACTION)    _aitlib_record ACTION "" "${3:-}" ;;
        *)         log_warn "invalid summary category $cat -- not recorded: ${2:-}: ${3:-}" ;;
    esac
}

# ---------------------------------------------------------------------------
# Run summary file lifecycle (reference/logging.md 8.4, 8.5), for the entry
# points:
#   summary_begin  AITOOLS_SUMMARY_FILE unset: create an empty temp file, export
#                  its path, AITLIB_SUMMARY_OWNER=true (this process draws the
#                  panel). Already set: nothing (not the owner; a parent draws it).
#                  A temp file that cannot be created is one log_warn, and the
#                  run goes on without a panel.
#   summary_end    when this process owns the file: show_summary (draw, keep
#                  last-summary.txt with AITOOLS_PRESERVE_SUMMARY=1, delete);
#                  else nothing. AITLIB_SUMMARY_OWNER becomes false and
#                  AITOOLS_SUMMARY_FILE is unset (nothing is recorded after the
#                  panel: a write would create the deleted file again).
# Parity: Start-AitSummary / Complete-AitSummary in aitools-lib.ps1.
# ---------------------------------------------------------------------------
summary_begin() {
    local f=""
    AITLIB_SUMMARY_OWNER=false
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then return 0; fi
    if ! f=$(mktemp "${TMPDIR:-/tmp}/aitools-summary.XXXXXX" 2>&1); then
        log_warn "run summary: cannot create a temp file ($f) -- no end-of-run panel this run"
        return 0
    fi
    AITOOLS_SUMMARY_FILE="$f"
    export AITOOLS_SUMMARY_FILE
    AITLIB_SUMMARY_OWNER=true
}
summary_end() {
    if [ "${AITLIB_SUMMARY_OWNER:-false}" != "true" ]; then return 0; fi
    AITLIB_SUMMARY_OWNER=false
    show_summary
    unset AITOOLS_SUMMARY_FILE
}

# ---------------------------------------------------------------------------
# run_relay_sync CMD ARGS... -- run the relay -> Cursor AGENTS.md sync (CMD ARGS =
# the python command, sync-relay-to-cursor-agents.py and its options; moved here
# from the installers, plan step I1, so the installers and the entry points share
# one copy). Its output (stdout and stderr) is captured and logged through the
# library: each non-empty line a detail line on success. A failure is one
# warning, write_warn "relay sync" "relay -> AGENTS.md sync failed (exit N,
# non-fatal): <reason>" (the reason from error_reason, which logs the output as
# detail lines); CMD not found is "relay -> AGENTS.md sync not run (non-fatal):
# CMD not found" (returns 127). The caller records nothing more for it. A
# deploy.log that cannot be written never skips the sync (fail-safe logging,
# logging.md section 5). Returns the sync's exit code. Parity: Invoke-RelaySync.
# ---------------------------------------------------------------------------
run_relay_sync() {
    local out="" rc=0 line
    # command -v exempt: an existence check; the branch is the fallback
    if ! command -v "${1:-}" >/dev/null 2>&1; then
        write_warn "relay sync" "relay -> AGENTS.md sync not run (non-fatal): ${1:-(no command)} not found"
        return 127
    fi
    out=$("$@" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        write_warn "relay sync" "relay -> AGENTS.md sync failed (exit $rc, non-fatal): $(error_reason "$out" "$rc")"
        return "$rc"
    fi
    while IFS= read -r line; do
        line="${line//$'\r'/}"
        if [ -n "$line" ]; then log_detail "relay sync: $line"; fi
    done <<< "$out"
    return 0
}

# ---------------------------------------------------------------------------
# Environment skip: a step that does not apply in this environment reports one
# OK row "n/a (<environment>)" plus the reason in the log (cross-platform.md
# "Environment branches"). Not WARN (nothing is wrong) and not "skipped" (a
# governed term for the user's deployment choice).
# Usage: write_environment_skip "google chrome" "managed only in Claude Code web (D-CHR1)"
# ---------------------------------------------------------------------------
write_environment_skip() {
    local tool="$1" reason="$2"
    log "n/a in the $AITOOLS_ENVIRONMENT environment: $reason"
    write_summary OK "$tool" "n/a ($AITOOLS_ENVIRONMENT)"
}

# ---------------------------------------------------------------------------
# Backup a file before overwriting. Keeps at most $max_backups copies.
# A failed copy is non-fatal here (warn, return 0) and sets BACKUP_FILE_OK=false;
# callers that must not write without a backup check it (_managed_write).
# ---------------------------------------------------------------------------
BACKUP_FILE_OK=true
backup_file() {
    local file="$1" max_backups=20
    BACKUP_FILE_OK=true
    [ -f "$file" ] || return 0
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    # A failed backup is non-fatal (config-file-safety.md "Backup before overwrite"):
    # warn and let the caller proceed.
    if ! cp "$file" "${file}.bak.${ts}"; then
        BACKUP_FILE_OK=false
        log_warn "Could not back up $(display_path "$file") -- proceeding without backup"
        return 0
    fi
    # Prune oldest beyond limit.
    # 2>/dev/null: ls errors only if no backup matches; the backup just written always does,
    # and an empty list is handled by the -n check below.
    local old_backups old
    old_backups=$(ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1))) || old_backups=""
    if [ -n "$old_backups" ]; then
        while IFS= read -r old; do
            if [ -n "$old" ] && ! rm -f "$old"; then
                log_warn "Could not prune old backup $(display_path "$old")"
            fi
        done <<< "$old_backups"
    fi
    log "Backed up $(display_path "$file")"
}

# ---------------------------------------------------------------------------
# Back up a directory before modifying managed files: copy DIR to
# DIR.bak.<UTC> (DIR.bak.<UTC>-<n> when that name is taken) and keep the
# newest $max_backups copies. Result variables (reset on every call):
#   BACKUP_DIR_OK      true only when the copy exists after cp; else false
#   BACKUP_DIR_PATH    the copy's path when BACKUP_DIR_OK is true, else ""
#   BACKUP_DIR_REASON  why not, when false: "no directory", "no top-level
#                      *.md", "cannot list", "copy failed"
# Skip rule (kept: its callers, the setup-user-claude and setup-user-cursor
# rules fan-outs, back up only a directory that holds a top-level *.md file):
# no top-level regular *.md file (the extension compared case-insensitively:
# X.MD counts) -> no copy, a detail log line, reason "no top-level *.md". A
# failed copy is non-fatal (warn, return 0; config-file-safety.md "Backup
# before overwrite"): callers that must not write without a backup check
# BACKUP_DIR_OK. A half-made copy is removed (or, when that fails, renamed to
# DIR.bak.incomplete.<UTC>, which the prune never matches). A symlink inside
# DIR is copied as a symlink (cp -R; the .ps1 copies its content, as
# Copy-Item did, needing no Windows symlink privilege). Old backups are matched by literal name
# (DIR's base name + ".bak." + the UTC stamp, optional "-<n>"), never a glob, so
# names with [ ] * ? work and another directory's backups are never pruned.
# Parity: Backup-Dir in aitools-lib.ps1.
# ---------------------------------------------------------------------------
BACKUP_DIR_OK=false
BACKUP_DIR_PATH=""
BACKUP_DIR_REASON=""

# _backup_dir_discard DEST DIR TS: remove a half-made backup copy DEST (made
# writable and searchable first: chmod -R u+rwX); when it cannot be removed,
# rename it to DIR.bak.incomplete.<TS>[-n], a name the prune never matches.
# Logged either way. Parity: Remove-IncompleteBackup in aitools-lib.ps1.
_backup_dir_discard() {
    local dest="$1" dir="$2" ts="$3" alt n=0
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        return 0
    fi
    if chmod -R u+rwX "$dest" && rm -rf "$dest" && [ ! -e "$dest" ]; then
        log "Removed the incomplete backup copy $(display_path "$dest")"
        return 0
    fi
    alt="${dir}.bak.incomplete.${ts}"
    while [ -e "$alt" ] || [ -L "$alt" ]; do
        n=$((n + 1))
        alt="${dir}.bak.incomplete.${ts}-$n"
    done
    if mv "$dest" "$alt"; then
        log_warn "Could not remove the incomplete backup copy -- renamed it to $(display_path "$alt")"
    else
        log_warn "Could not remove or rename the incomplete backup copy $(display_path "$dest")"
    fi
}

backup_dir() {
    local dir="${1%/}" max_backups=5
    BACKUP_DIR_OK=false; BACKUP_DIR_PATH=""; BACKUP_DIR_REASON=""
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        BACKUP_DIR_REASON="no directory"
        log_detail "backup_dir: ${1:-}: not backed up (no directory)"
        return 0
    fi
    local file_count rc=0
    # stdout: the count; on exit 1, the reason (stderr captured too)
    file_count=$(perl -e '
        my $d = shift;
        opendir my $dh, $d or do { print "cannot list $d: $!"; exit 1 };
        my $n = grep { /\.md\z/i && ! -l "$d/$_" && -f "$d/$_" } readdir $dh;
        closedir $dh;
        print $n;
    ' "$dir" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        BACKUP_DIR_REASON="cannot list"
        log_warn "Could not back up $(display_path "$dir") -- $file_count"
        return 0
    fi
    if [ "$file_count" -eq 0 ]; then
        BACKUP_DIR_REASON="no top-level *.md"
        log_detail "backup_dir: $dir: not backed up (no top-level *.md file)"
        return 0
    fi
    local ts dest n=0
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    dest="${dir}.bak.${ts}"
    while [ -e "$dest" ] || [ -L "$dest" ]; do
        n=$((n + 1))
        dest="${dir}.bak.${ts}-$n"
    done
    # cp -R as before: a symlink inside DIR is copied as a symlink (BSD and GNU
    # cp -R do not follow links below the top level)
    if ! cp -R "$dir" "$dest" || [ ! -d "$dest" ]; then
        BACKUP_DIR_REASON="copy failed"
        log_warn "Could not back up $(display_path "$dir") -- proceeding without backup"
        _backup_dir_discard "$dest" "$dir" "$ts"
        return 0
    fi
    BACKUP_DIR_OK=true
    BACKUP_DIR_PATH="$dest"
    local parent base old_backups old_dir prc=0
    parent=$(dirname "$dir")
    base=$(basename "$dir")
    # Newest first by name (the UTC stamp sorts by time); print the ones past the limit
    old_backups=$(perl -e '
        my ($parent, $base, $keep) = @ARGV;
        opendir my $dh, $parent or do { print "cannot list $parent: $!"; exit 1 };
        my @b = sort { $b cmp $a } grep {
            /\A\Q$base\E\.bak\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z(?:-[0-9]+)?\z/
                && ! -l "$parent/$_" && -d "$parent/$_"
        } readdir $dh;
        closedir $dh;
        print "$parent/$_\n" for @b[$keep .. $#b];
    ' "$parent" "$base" "$max_backups" 2>&1) || prc=$?
    if [ "$prc" -ne 0 ]; then
        log_warn "Could not prune old backups of $(display_path "$dir") -- $old_backups"
    elif [ -n "$old_backups" ]; then
        while IFS= read -r old_dir; do
            [ -n "$old_dir" ] || continue
            if rm -rf "$old_dir" && [ ! -e "$old_dir" ]; then
                log "Pruned old backup: $(display_path "$old_dir")"
            else
                log_warn "Could not prune old backup $(display_path "$old_dir")"
            fi
        done <<< "$old_backups"
    fi
    log "Backed up $(display_path "$dir") ($file_count managed files)"
}

# ---------------------------------------------------------------------------
# Managed-file helpers for deploy_managed_file, review_json_fields and the
# review prompts below. SOURCE is the source of truth; there is no deploy
# state (see the "Review choices" block above prompt_diff_review).
# ---------------------------------------------------------------------------

# [x]abort: log, then exit 2 (a bare exit 2 means user abort; commander
# decision 2026-10-21, D-TS13 reversed: no marker file). One helper for every
# review prompt. The line is logged at error level and counted through the
# non-recording path (reference/logging.md 8.2): the relay that ran this script
# records the abort once (8.3 "A user abort"). Parity: Invoke-ManagedAbort.
_managed_abort() {
    _aitlib_error_norecord "Aborted by user"
    exit 2
}

# Deploy state (~/.aitools/deploy-state/) is no longer used. Files from older
# versions are left on disk; say so once per script run (detail level).
_MANAGED_STATE_NOTED=false
_managed_state_notice() {
    if [ "$_MANAGED_STATE_NOTED" = "true" ]; then return 0; fi
    _MANAGED_STATE_NOTED=true
    if [ -d "$HOME/.aitools/deploy-state" ]; then
        log_detail "deploy state is no longer used (SOURCE is the source of truth); $(display_path "$HOME/.aitools/deploy-state") left on disk"
    fi
}

# ---------------------------------------------------------------------------
# dotprofile_commit_push FILE MESSAGE -- commit FILE, and only FILE, in the
# dotprofile and push it (N-Q2: dotprofile writes are committed and pushed
# automatically). Parity: Invoke-DotprofileCommitPush in aitools-lib.ps1.
#   FILE     absolute path of a file this run wrote
#   MESSAGE  commit message
#   TOOL     optional: the record name of its warnings (the deploying tool);
#            default "dotprofile"
# "In the dotprofile" is decided by git, not by the path string: FILE's git top
# level equals the dotprofile's git top level. The dotprofile is
# AITLIB_USER_REPO_PATH when the caller already ran resolve_user_repo_path
# (set, even to ""); otherwise the resolver is asked here, quietly (no ERROR
# row: a resolver failure means "not the dotprofile"; it overwrites
# AITLIB_PROFILE_OUT / AITLIB_PROFILE_RC).
# Pathspec commit (git add -- FILE, then git commit -m MESSAGE -- FILE), so other
# staged or unstaged changes in the dotprofile are never included. The push
# never prompts (GIT_TERMINAL_PROMPT=0; ssh BatchMode unless GIT_SSH_COMMAND is
# set); credential helpers still work. git's output goes to deploy.log (detail).
# Sets AITLIB_DOTPROFILE_PUSH (never empty after the call):
#   committed-pushed  committed and pushed (log_ok)
#   unchanged         FILE matches HEAD: nothing committed, no push, no warning
#   commit-failed     write_action TOOL, ACTION "commit and push <file> in
#                     <dotprofile>" (git's output: detail lines)
#   push-failed       committed, not pushed: write_action TOOL, ACTION "git pull
#                     --rebase, then git push in <dotprofile>" (remote has newer
#                     commits) or "run git push in <dotprofile>" (any other
#                     failure)
#   not-dotprofile    FILE is not in the dotprofile, or there is none: nothing done
# A failed commit or push's warning text carries "(exit N: <reason>)", the reason
# from error_reason over git's output (reference/logging.md 8.3), as PowerShell.
# Always returns 0: a failed commit or push is a warning, the caller's own
# outcome (e.g. "accept & adopt") is unchanged and the run continues.
# ---------------------------------------------------------------------------
dotprofile_commit_push() {
    AITLIB_DOTPROFILE_PUSH="not-dotprofile"
    local file="$1" msg="$2" tool="${3:-}" dir base top dp="" dptop prefix rel d out rc=0 drc=0 why
    if [ -z "$tool" ]; then tool="dotprofile"; fi
    dir=$(dirname "$file"); base=$(basename "$file")
    if ! command -v git >/dev/null 2>&1; then
        log_detail "dotprofile commit: git not found -- $(display_path "$file") not committed"
        return 0
    fi
    if [ -n "${AITLIB_USER_REPO_PATH+set}" ]; then
        dp="$AITLIB_USER_REPO_PATH"
    elif _aitlib_profile_run user-repo-path && [ "$AITLIB_PROFILE_RC" -eq 0 ]; then
        dp=$(_aitlib_bash_path "$(_aitlib_profile_tag path)")
    fi
    if [ -z "$dp" ] || [ ! -d "$dp" ] || [ ! -d "$dir" ]; then
        log_detail "dotprofile commit: $(display_path "$file") -- no dotprofile resolved or no such directory; nothing committed"
        return 0
    fi
    # 2>/dev/null: outside a git repo rev-parse fails; the empty result is checked below.
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=""
    dptop=$(git -C "$dp" rev-parse --show-toplevel 2>/dev/null) || dptop=""  # same: empty checked below
    d=$(display_path "$dp")
    if [ -z "$dptop" ]; then
        case "$file" in
            "$dp"/*)
                AITLIB_DOTPROFILE_PUSH="commit-failed"
                write_action "$tool" "dotprofile $d is not a git repository -- $base written but not committed" "commit and push $base in $d" ;;
            *) log_detail "dotprofile commit: $d is not a git repository; $(display_path "$file") is outside it" ;;
        esac
        return 0
    fi
    if [ -z "$top" ] || [ "$top" != "$dptop" ]; then
        log_detail "dotprofile commit: $(display_path "$file") is not in the dotprofile ($d) -- not committed"
        return 0
    fi
    prefix=$(git -C "$dir" rev-parse --show-prefix 2>/dev/null) || prefix=""  # "" = file at the repo root (valid)
    rel="${prefix}${base}"
    out=$(git -C "$dir" add -- "$base" 2>&1) || rc=$?
    if [ "$rc" -eq 0 ]; then
        git -C "$dir" diff --cached --quiet -- "$base" || drc=$?
        if [ "$drc" -eq 0 ]; then
            AITLIB_DOTPROFILE_PUSH="unchanged"
            log_detail "dotprofile commit: $rel unchanged in $d -- nothing to commit or push"
            return 0
        fi
        # drc 1 = a staged change to commit; >1 = diff error: the commit reports a real problem
        out=$(git -C "$dir" commit -m "$msg" -- "$base" 2>&1) || rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        AITLIB_DOTPROFILE_PUSH="commit-failed"
        why=$(error_reason "$out" "$rc")
        write_action "$tool" "dotprofile commit failed (exit $rc: $why) -- commit and push $rel in $d by hand" "commit and push $rel in $d"
        return 0
    fi
    if [ -n "$out" ]; then log_detail "git commit in $d: $out"; fi
    out=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}" git -C "$dir" push 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        AITLIB_DOTPROFILE_PUSH="push-failed"
        why=$(error_reason "$out" "$rc")
        case "$out" in
            *rejected*|*non-fast-forward*|*"fetch first"*)
                write_action "$tool" "dotprofile push rejected (exit $rc: $why): the remote has newer commits -- run git pull --rebase, then git push in $d" "git pull --rebase, then git push in $d" ;;
            *)
                write_action "$tool" "dotprofile push failed (exit $rc: $why) -- run git push in $d" "run git push in $d" ;;
        esac
        return 0
    fi
    if [ -n "$out" ]; then log_detail "git push in $d: $out"; fi
    AITLIB_DOTPROFILE_PUSH="committed-pushed"
    log_ok "dotprofile: $rel committed and pushed ($msg)"
    return 0
}

# After adopt or merge: an adopt target in the dotprofile is committed and
# pushed (dotprofile_commit_push, N-Q2). Any other adopt target (the aitools
# repo) stays a working-tree change: say that its repo has an uncommitted
# change to review (it is reviewed at commit, D-DEL5).
# _managed_adopt_notice TARGET [TOOL] -- TOOL: the record name of a commit or
# push warning (dotprofile_commit_push; default "dotprofile").
_managed_adopt_notice() {
    local target="$1" tool="${2:-}" top
    dotprofile_commit_push "$target" "Adopt $(basename "$target") from the deployed copy" "$tool"
    if [ "$AITLIB_DOTPROFILE_PUSH" != "not-dotprofile" ]; then return 0; fi
    # 2>/dev/null: outside a git repo there is nothing to commit (empty result checked).
    top=$(git -C "$(dirname "$target")" rev-parse --show-toplevel 2>/dev/null) || top=""
    if [ -n "$top" ]; then
        log "Uncommitted change in $(display_path "$top"): $(basename "$target") -- review and commit it (cd $(display_path "$top") && git diff)"
    fi
}

# ---------------------------------------------------------------------------
# Write LOCAL and/or the adopt target as one step.
#   $1 = LOCAL path   ("" = LOCAL not written)    $2 = LOCAL content
#   $3 = adopt path   ("" = adopt target not written)  $4 = adopt content
# Content is written with exactly one trailing newline. Before anything is
# written, each existing file is snapshotted (for restore) and backed up
# (backup_file: rotated .bak.<ts>); a failed backup fails the step with
# nothing written. After writing, each file is validated: non-empty, and for
# a name ending in .json: valid JSON that has every top-level key listed in
# MANAGED_WRITE_REQUIRED_1 / _2 (JSON arrays for $1 / $3; unset = none; the
# caller sets them just before the call; they are cleared on return). On any
# failure every file this call touched is restored from its snapshot (a file
# that did not exist is removed), MANAGED_WRITE_ERROR is set, and 1 is
# returned. The caller records MANAGED_WRITE_ERROR as the reason of its
# write_error (a failed restore below is one more log_error: it states its cause).
# ---------------------------------------------------------------------------
MANAGED_WRITE_ERROR=""
# The "<script>: line N: " prefix bash puts before a failed redirection's error
_AITLIB_SHELL_ERR_RE='^[^:]+: line [0-9]+: (.*)$'
MANAGED_WRITE_REQUIRED_1=""
MANAGED_WRITE_REQUIRED_2=""
_managed_write() {
    local p1="$1" c1="$2" p2="$3" c2="$4"
    local req1="${MANAGED_WRITE_REQUIRED_1:-[]}" req2="${MANAGED_WRITE_REQUIRED_2:-[]}"
    MANAGED_WRITE_REQUIRED_1=""; MANAGED_WRITE_REQUIRED_2=""
    MANAGED_WRITE_ERROR=""
    local snapdir
    if ! snapdir=$(mktemp -d); then
        MANAGED_WRITE_ERROR="could not create a restore snapshot directory -- nothing written"
        return 1
    fi

    # Snapshot: s<N> holds the prior content; e<N> marks "did not exist".
    local i p c werr
    for i in 1 2; do
        if [ "$i" = "1" ]; then p="$p1"; else p="$p2"; fi
        [ -n "$p" ] || continue
        if [ -f "$p" ]; then
            if ! cp -p "$p" "$snapdir/s$i"; then
                MANAGED_WRITE_ERROR="could not snapshot $(display_path "$p") for restore -- nothing written"
                rm -rf "$snapdir"
                return 1
            fi
            backup_file "$p"
            if [ "$BACKUP_FILE_OK" != "true" ]; then
                MANAGED_WRITE_ERROR="backup of $(display_path "$p") failed -- nothing written"
                rm -rf "$snapdir"
                return 1
            fi
        elif ! : > "$snapdir/e$i"; then
            MANAGED_WRITE_ERROR="could not record restore state for $(display_path "$p") -- nothing written"
            rm -rf "$snapdir"
            return 1
        fi
    done

    local rc=0 req
    for i in 1 2; do
        if [ "$i" = "1" ]; then p="$p1"; c="$c1"; req="$req1"; else p="$p2"; c="$c2"; req="$req2"; fi
        [ -n "$p" ] || continue
        if ! werr=$(mkdir -p "$(dirname "$p")" 2>&1); then
            MANAGED_WRITE_ERROR="cannot create the directory for $(display_path "$p"): $werr"
            rc=1; break
        fi
        if ! werr=$( { printf '%s\n' "$c" > "$p"; } 2>&1 ); then
            # bash prefixes a failed redirection with "<script>: line N: ": the
            # reason is the rest (the path and the system error), as the
            # PowerShell twin's (Get-AitErrorReason -ErrorRecord)
            if [[ "$werr" =~ $_AITLIB_SHELL_ERR_RE ]]; then werr="${BASH_REMATCH[1]}"; fi
            MANAGED_WRITE_ERROR="write failed for $(display_path "$p"): $werr"
            rc=1; break
        fi
        if [ ! -s "$p" ]; then
            MANAGED_WRITE_ERROR="validation failed: $(display_path "$p") is empty after the write"
            rc=1; break
        fi
        case "$p" in
            *.json)
                if ! werr=$(node -e "
const fs = require('fs');
let v;
try { v = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); }
catch (e) { console.error('not valid JSON: ' + e.message); process.exit(1); }
const req = JSON.parse(process.argv[2]);
const isObj = v !== null && typeof v === 'object' && !Array.isArray(v);
const miss = isObj ? req.filter(k => !Object.prototype.hasOwnProperty.call(v, k)) : req;
if (miss.length) { console.error('missing required keys: ' + miss.join(', ')); process.exit(1); }
" "$p" "$req" 2>&1); then
                    MANAGED_WRITE_ERROR="validation failed: $(display_path "$p"): $werr"
                    rc=1; break
                fi ;;
        esac
    done

    if [ "$rc" -ne 0 ]; then
        for i in 1 2; do
            if [ "$i" = "1" ]; then p="$p1"; else p="$p2"; fi
            [ -n "$p" ] || continue
            if [ -f "$snapdir/s$i" ]; then
                # Restore only what changed (a write refused at open changed nothing).
                if ! cmp -s "$snapdir/s$i" "$p"; then
                    if cp -p "$snapdir/s$i" "$p"; then
                        log "Restored $(display_path "$p")"
                    else
                        log_error "Restore failed for $(display_path "$p") -- its backup is next to it (.bak.*)"
                    fi
                fi
            elif [ -f "$snapdir/e$i" ] && [ -e "$p" ]; then
                if rm -f "$p"; then
                    log "Removed partial $(display_path "$p")"
                else
                    log_error "Could not remove partial $(display_path "$p")"
                fi
            fi
        done
    fi
    rm -rf "$snapdir"
    return "$rc"
}

# ---------------------------------------------------------------------------
# Merge file description lookup
# ---------------------------------------------------------------------------
# Purpose: Returns a human-readable description of a managed file for AI merge
#   prompts, providing context about the file's role in the config system.
# Inputs: $1 = file path
# Expected output: Single-line description string on stdout.
_get_merge_file_description() {
    case "$(basename "$1")" in
        CLAUDE.md) printf 'User-scope CLAUDE.md -- personal preferences and instructions for Claude Code' ;;
        *.md)      printf 'Configuration rule: %s' "$(basename "$1")" ;;
        *.json)    printf 'JSON config: %s' "$(basename "$1")" ;;
        *)         printf 'Managed file: %s' "$(basename "$1")" ;;
    esac
}

# ---------------------------------------------------------------------------
# AI merge prompt builder (initial merge)
# ---------------------------------------------------------------------------
# Purpose: Builds a structured merge prompt following the Role/Context/Task/
#   Constraints/Format pattern for merging managed configuration files.
# Inputs: $1=file_path, $2=source_content, $3=local_content, $4=diff_output
# Expected output: Complete prompt string on stdout, suitable for invoke_ai.
# Validation: validate_ai_merge_output (5 checks: conversational, fences,
#   refusal, truncation, header preservation)
# Known limitations: Very large files may hit model context limits. Files with
#   no markdown headers rely on Check 4 (length) for rewrite detection.
_ai_prompt_merge() {
    local file_path="$1"
    local source_content="$2"
    local local_content="$3"
    local diff_output="$4"

    local file_desc
    file_desc=$(_get_merge_file_description "$file_path")

    printf '%s' "You are merging a managed configuration file during automated deployment.

## What you are merging
${file_desc}

## Where changes come from
SOURCE: The canonical template, synced across machines -- the updated version being deployed
LOCAL: The user's current file on this machine, with their customizations

## What is happening
Updated configuration is being deployed. Source has changed and needs to be
incorporated without losing local customizations.

## Differences (unified diff: local vs source)
${diff_output}

## Full local file (start from this)
<LOCAL>
${local_content}
</LOCAL>

## Rules
1. Start with LOCAL as your base -- preserve all user customizations
2. Apply ONLY the changes shown in the diff
3. If a change conflicts with a local customization (contradicts its intent), keep local
4. If a change adds new content not in LOCAL, add it in the appropriate location
5. If a change updates content the user hasn't customized, apply it
6. CRITICAL: Do NOT wrap your output in markdown code fences (\`\`\`). Output raw file content ONLY
7. No commentary, no explanation, no preamble -- just the merged file content"
}

# ---------------------------------------------------------------------------
# AI merge prompt builder (refinement)
# ---------------------------------------------------------------------------
# Purpose: Builds a refinement prompt for iterating on a previous merge result
#   based on user feedback.
# Inputs: $1=source_content, $2=local_content, $3=current_merge, $4=feedback
# Expected output: Complete prompt string on stdout, suitable for invoke_ai.
# Validation: Same as initial merge (validate_ai_merge_output).
_ai_prompt_merge_refine() {
    local source_content="$1"
    local local_content="$2"
    local current_merge="$3"
    local feedback="$4"

    printf '%s' "You are refining a merged configuration file based on user feedback.

## Context
A previous merge produced CURRENT_MERGE from SOURCE + LOCAL. The user wants changes.

## SOURCE (original template)
<SOURCE>
${source_content}
</SOURCE>

## LOCAL (original user file)
<LOCAL>
${local_content}
</LOCAL>

## CURRENT MERGE (previous result)
<CURRENT_MERGE>
${current_merge}
</CURRENT_MERGE>

## User Feedback
${feedback}

## Rules
- Apply the user's feedback to CURRENT_MERGE
- Keep all content from CURRENT_MERGE not affected by the feedback
- Output the revised merged file content ONLY -- no preamble, no explanation, no markdown fences"
}

# Merge validation wrapper for invoke_ai -- captures source/local context
# via module-level variables set by _invoke_ai_merge before calling invoke_ai.
_MERGE_VALIDATE_SOURCE=""
_MERGE_VALIDATE_LOCAL=""
_merge_validate() {
    # Return the validator's status: the assignment below would otherwise make
    # this function return 0 and accept every output (parity: _MergeValidateWrapper).
    local rc=0
    validate_ai_merge_output "$1" "$_MERGE_VALIDATE_SOURCE" "$_MERGE_VALIDATE_LOCAL" || rc=$?
    AI_REJECT_REASON="$MERGE_REJECT_REASON"
    return "$rc"
}

MERGE_REJECT_REASON=""

# ---------------------------------------------------------------------------
# Validate AI merge output before accepting it.
# Returns 0 if valid, 1 if invalid. Sets MERGE_REJECT_REASON on failure.
# ---------------------------------------------------------------------------
validate_ai_merge_output() {
    local output="$1"
    local source_content="$2"
    local local_content="$3"
    MERGE_REJECT_REASON=""

    # Check 1: conversational patterns (first non-empty line)
    local first_line
    first_line=$(printf '%s' "$output" | perl -ne 'next if $done; if (/\S/) { print; $done = 1 }')
    # perl -0777 reads the whole input before it decides; an empty first line
    # is not conversational (as Test-AiMergeOutput in aitools-lib.ps1)
    if printf '%s' "$first_line" | perl -0777 -ne 'exit(/^(I |Here|Sure|Certainly|Let me)/i ? 0 : 1)'; then
        MERGE_REJECT_REASON="AI responded conversationally instead of producing merged content"
        return 1
    fi

    # Check 2: markdown code fences. The status is decided in END, after the
    # last line: an exit in the loop would stop reading (the writer can then die
    # of SIGPIPE under pipefail), and an "exit 0" followed by END { exit 1 }
    # ends with status 1 (perl runs END after exit), which is why checks 2 and
    # 3 never rejected anything before this form.
    if printf '%s\n' "$output" | perl -ne '$f = 1 if /^```/; END { exit($f ? 0 : 1) }'; then
        MERGE_REJECT_REASON="AI wrapped output in code fences -- need raw content"
        return 1
    fi

    # Check 3: conversational refusal patterns (not bare keywords -- content may
    # legitimately contain "permission", "access", etc.)
    if printf '%s' "$output" | perl -ne '$f = 1 if /(?:I don.t have permission|I cannot access|I.m not authorized|I need (?:your )?approval|permission denied|access denied|I.m unable to|I can.t (?:read|write|access|open|modify))/i; END { exit($f ? 0 : 1) }'; then
        MERGE_REJECT_REASON="AI indicated it couldn't perform the merge"
        return 1
    fi

    # Check 4: minimum length (output >= 50% of shorter input when shorter > 40 chars)
    local out_len src_len local_len min_input_len threshold
    out_len=$(printf '%s' "$output" | wc -c | tr -d ' ')
    src_len=$(printf '%s' "$source_content" | wc -c | tr -d ' ')
    local_len=$(printf '%s' "$local_content" | wc -c | tr -d ' ')
    if [ "$src_len" -le "$local_len" ]; then min_input_len=$src_len; else min_input_len=$local_len; fi
    threshold=$((min_input_len / 2))
    if [ "$min_input_len" -gt 40 ] && [ "$out_len" -lt "$threshold" ]; then
        MERGE_REJECT_REASON="Output too short ($out_len chars, expected ${threshold}+) -- likely truncated"
        return 1
    fi

    # Check 5: header preservation — deduplicated headers from source+local must
    # be >=60% preserved in output. Files with 0 headers pass (Check 4 handles truncation).
    local combined_headers
    combined_headers=$(printf '%s\n%s' "$source_content" "$local_content" \
        | grep -E '^#{1,6} ' | sort -u)
    local total preserved=0
    total=$(printf '%s\n' "$combined_headers" | grep -c '^' || true)  # count lines; may be 0
    if [ "$total" -gt 0 ]; then
        while IFS= read -r header; do
            [ -z "$header" ] && continue
            printf '%s' "$output" | grep -F "$header" >/dev/null && preserved=$((preserved + 1))
        done <<< "$combined_headers"
        local threshold=$(( (total * 60 + 99) / 100 ))
        [ "$threshold" -lt 1 ] && threshold=1
        if [ "$preserved" -lt "$threshold" ]; then
            MERGE_REJECT_REASON="Rewrote too much ($preserved/$total section headers preserved, need 60%+)"
            return 1
        fi
    fi

    return 0
}

MERGED_CONTENT=""

# ---------------------------------------------------------------------------
# Spinner for AI operations (visual progress indicator)
# A background subshell draws "\r  <c> <msg>" on /dev/tty every 0.2 s until
# _stop_spinner kills it. A background job of a non-interactive shell ignores
# SIGINT, so Ctrl+C alone never stops it (it kept drawing after the script died,
# mission M3b). Two guards:
#   - It watches the shell that started it (the PID taken before the fork:
#     BASHPID, or $$ on bash 3.2, which has no BASHPID) and ends, clearing its
#     line, at the first tick after that shell is gone -- whatever ended it,
#     SIGKILL included, where no trap can run.
#   - While invoke_ai runs, _invoke_ai_merge stops it from INT, TERM and EXIT
#     traps (_spinner_traps_set / _spinner_traps_restore).
# Without a controlling terminal it draws nothing but keeps watching (each draw
# fails quietly: the spinner is cosmetic). Starting one stops a running one.
# Parity: Start-AiSpinner / Stop-AiSpinner in aitools-lib.ps1.
# ---------------------------------------------------------------------------
_AI_SPINNER_PID=""

_start_spinner() {
    local msg="${1:-working...}" owner="${BASHPID:-$$}"
    if [ -n "$_AI_SPINNER_PID" ]; then _stop_spinner; fi
    # 2>/dev/null on the subshell: a draw on a missing or closed terminal fails
    # with a shell message; there is nothing to draw, which is not an error
    (
        local chars='/-\|'
        local i=0
        while kill -0 "$owner" 2>/dev/null; do
            printf '\r  %s %s' "${chars:$((i % 4)):1}" "$msg" > /dev/tty || :  # no terminal: keep watching
            i=$((i + 1))
            sleep 0.2
        done
        printf '\r  \033[K' > /dev/tty || :  # the owner is gone: clear the line if there is one
    ) 2>/dev/null &
    _AI_SPINNER_PID=$!
}

_stop_spinner() {
    if [ -n "$_AI_SPINNER_PID" ] && kill -0 "$_AI_SPINNER_PID" 2>/dev/null; then
        # || true: the spinner may end on its own between the check and the kill;
        # either way it is gone, which is all this needs
        kill "$_AI_SPINNER_PID" 2>/dev/null || true
        wait "$_AI_SPINNER_PID" 2>/dev/null || true  # reap; exit code irrelevant for spinner
    fi
    _AI_SPINNER_PID=""
    # || true: no controlling terminal -- there is no spinner line to clear
    { printf '\r  \033[K' > /dev/tty; } 2>/dev/null || true
}

# Traps that stop the spinner while an AI call runs (_invoke_ai_merge).
# _spinner_traps_set saves the caller's INT, TERM and EXIT traps and sets its
# own; _spinner_traps_restore puts the caller's back (a no-op when none are
# saved, so it is safe to call twice). On INT or TERM the handler stops the
# spinner, restores the caller's traps and sends the same signal to this shell
# again, so the caller's own trap, or the default action (the script ends, its
# EXIT trap runs), follows. On EXIT it stops the spinner and runs the caller's
# EXIT command. bash runs a trap only after the foreground command ends: on
# Ctrl+C the AI CLI gets SIGINT too and ends, then the handler runs.
# trap -p goes through a temp file, not $(trap -p ...): whether a command
# substitution sees the caller's traps differs between bash versions (not
# verified for bash 3.2, macOS /bin/bash). No temp file: the traps are not set
# (a detail line); the spinner's owner watch still ends it.
_AITLIB_SPIN_TRAPS_SET=false
_AITLIB_SPIN_PREV_INT=""
_AITLIB_SPIN_PREV_TERM=""
_AITLIB_SPIN_PREV_EXIT=""
_AITLIB_SPIN_EXIT_CMD=""

# _aitlib_spin_trap_arg -- '...' SIG: called with the arguments of a saved
# "trap -- 'CMD' EXIT" line; keeps CMD
_aitlib_spin_trap_arg() { _AITLIB_SPIN_EXIT_CMD="${2:-}"; }

_spinner_traps_set() {
    local tf=""
    if [ "$_AITLIB_SPIN_TRAPS_SET" = "true" ]; then return 0; fi
    if ! tf="$(mktemp)"; then
        log_detail "AI spinner: mktemp failed -- no INT/TERM/EXIT traps (the owner watch still stops it)"
        return 0
    fi
    trap -p INT > "$tf";  _AITLIB_SPIN_PREV_INT="$(cat "$tf")"
    trap -p TERM > "$tf"; _AITLIB_SPIN_PREV_TERM="$(cat "$tf")"
    trap -p EXIT > "$tf"; _AITLIB_SPIN_PREV_EXIT="$(cat "$tf")"
    _aitlib_rm_tmp "$tf" "AI spinner"
    _AITLIB_SPIN_EXIT_CMD=""
    if [ -n "$_AITLIB_SPIN_PREV_EXIT" ]; then
        eval "_aitlib_spin_trap_arg ${_AITLIB_SPIN_PREV_EXIT#trap }"
    fi
    _AITLIB_SPIN_TRAPS_SET=true
    trap '_spinner_on_signal INT' INT
    trap '_spinner_on_signal TERM' TERM
    trap '_spinner_on_exit' EXIT
}

_spinner_traps_restore() {
    if [ "$_AITLIB_SPIN_TRAPS_SET" != "true" ]; then return 0; fi
    _AITLIB_SPIN_TRAPS_SET=false
    if [ -n "$_AITLIB_SPIN_PREV_INT" ]; then eval "$_AITLIB_SPIN_PREV_INT"; else trap - INT; fi
    if [ -n "$_AITLIB_SPIN_PREV_TERM" ]; then eval "$_AITLIB_SPIN_PREV_TERM"; else trap - TERM; fi
    if [ -n "$_AITLIB_SPIN_PREV_EXIT" ]; then eval "$_AITLIB_SPIN_PREV_EXIT"; else trap - EXIT; fi
}

_spinner_on_signal() {
    _stop_spinner
    log_detail "AI spinner stopped by $1"
    _spinner_traps_restore
    kill -s "$1" "${BASHPID:-$$}"
}

_spinner_on_exit() {
    _stop_spinner
    log_detail "AI spinner stopped at exit"
    _AITLIB_SPIN_TRAPS_SET=false
    if [ -n "$_AITLIB_SPIN_EXIT_CMD" ]; then eval "$_AITLIB_SPIN_EXIT_CMD"; fi
}

# ---------------------------------------------------------------------------
# Interactive = stdin is a terminal AND the controlling terminal can be opened.
# Spec (managed-file-deployment.md, interactive-menus.md): non-terminal stdin ->
# no prompt, source wins. Prompts still read /dev/tty so data piped on stdin is
# never consumed as an answer. Parity: Test-InteractiveConsole in aitools-lib.ps1.
# ---------------------------------------------------------------------------
tty_interactive() {
    [ -t 0 ] || return 1
    # 2>/dev/null: the open fails when there is no controlling terminal; that
    # failure is the answer (return 1), not an error to report.
    (printf '' > /dev/tty) 2>/dev/null
}

# ---------------------------------------------------------------------------
# EOF-safe prompt read. Usage: read_tty_choice <var> <what-the-default-does>
# Bare `read -r x < /dev/tty` returns 1 at EOF (closed stdin under a pty), which
# aborts the caller under set -e with no log line. This logs and returns 0 with
# <var> empty, and sets READ_TTY_EOF=1 (0 after any other read), so a typed
# empty line and EOF can be told apart: read_menu_choice takes its EOF default
# only at EOF and asks again otherwise.
# ---------------------------------------------------------------------------
read_tty_choice() {
    local __var="$1" __default_desc="$2" __line=""
    READ_TTY_EOF=0
    if ! IFS= read -r __line < /dev/tty; then
        READ_TTY_EOF=1
        printf '\n' > /dev/tty
        log_warn "No input at prompt (EOF) -- defaulting to $__default_desc"
        __line=""
    fi
    printf -v "$__var" '%s' "$__line"
}

# ---------------------------------------------------------------------------
# Choice-menu read. Usage:
#   read_menu_choice VAR "VALID" DEFAULT "DEFAULT_DESC" "CONTEXT" "PROMPT"
# VALID: the accepted answers, lowercase, space-separated ("o a m s x",
# "y yes n no"). DEFAULT: the answer taken only at EOF (one of VALID).
# DEFAULT_DESC: what the default does (read_tty_choice's EOF warning).
# CONTEXT: a short label for the log ("review CLAUDE.md"). PROMPT: printed as
# data before every read ("  choice [o/s/x]: "); the caller prints the menu.
# Reads through read_tty_choice, trims surrounding whitespace and lowercases.
# An offered answer sets VAR. Anything else -- an empty line, a word, a letter
# not offered -- prints "  please type one of a/b/c" and asks again (commander,
# 2026-11-13: "no default or other characters should re-ask"). EOF sets VAR to
# DEFAULT. Every answer is logged at detail (deploy.log only).
# EOF detection: read_tty_choice returns "" both at EOF and for a typed empty
# line. READ_TTY_EOF=1 after the read marks EOF (set by read_tty_choice); as a
# fallback for an older read_tty_choice, an empty answer with WARNINGS raised
# during the read is also EOF (its EOF branch calls log_warn). 50 unrecognised answers in a row are treated as EOF, so a
# closed input that is not detected cannot loop forever.
# Spec: .claude/rules/interactive-menus.md "Answers";
# reference/managed-file-deployment.md "Menus". Parity: Read-MenuChoice in
# aitools-lib.ps1.
# ---------------------------------------------------------------------------
READ_TTY_EOF=0
read_menu_choice() {
    local __mvar="$1" __valid="$2" __default="$3" __desc="$4" __ctx="$5" __prompt="$6"
    local __ans="" __raw="" __w0=0 __tries=0 __v="" __hint=""
    for __v in $__valid; do
        if [ -z "$__hint" ]; then __hint="$__v"; else __hint="$__hint/$__v"; fi
    done
    while true; do
        printf '%s' "$__prompt" > /dev/tty
        READ_TTY_EOF=0
        __w0="${WARNINGS:-0}"
        __raw=""
        read_tty_choice __raw "$__desc"
        if [ "${READ_TTY_EOF:-0}" = "1" ] || { [ -z "$__raw" ] && [ "${WARNINGS:-0}" -gt "$__w0" ]; }; then
            log_detail "menu answer ($__ctx): EOF -> $__default"
            printf -v "$__mvar" '%s' "$__default"
            return 0
        fi
        # Trim surrounding whitespace (a CR included), then lowercase
        __ans="${__raw#"${__raw%%[![:space:]]*}"}"
        __ans="${__ans%"${__ans##*[![:space:]]}"}"
        __ans=$(printf '%s' "$__ans" | tr '[:upper:]' '[:lower:]')
        for __v in $__valid; do
            if [ "$__ans" = "$__v" ]; then
                log_detail "menu answer ($__ctx): \"$__raw\" -> $__ans"
                printf -v "$__mvar" '%s' "$__ans"
                return 0
            fi
        done
        log_detail "menu answer ($__ctx): \"$__raw\" -> not one of $__hint, asked again"
        __tries=$((__tries + 1))
        if [ "$__tries" -ge 50 ]; then
            log_warn "No valid answer after 50 tries at $__ctx -- treating input as ended, defaulting to $__desc"
            printf -v "$__mvar" '%s' "$__default"
            return 0
        fi
        printf '  please type one of %s\n' "$__hint" > /dev/tty
    done
}

# ---------------------------------------------------------------------------
# Agentic merge via invoke_ai with refinement loop ([m]erge & adopt).
# Uses structured prompts from _ai_prompt_merge / _ai_prompt_merge_refine.
# Sets DIFF_REVIEW_RESULT to:
#   "merge"  -- [y]es: MERGED_CONTENT holds the accepted merge
#   "menu"   -- [n]o: the preview was rejected; prompt_diff_review shows its
#               menu again (nothing written)
#   "failed" -- the AI merge produced no valid output; MANAGED_MERGE_ERROR
#               holds the reason (deploy_managed_file logs it; nothing written)
# ---------------------------------------------------------------------------
MANAGED_MERGE_ERROR=""
_invoke_ai_merge() {
    local file_path="$1"
    local source_content="$2"
    local local_content="${3:-}"
    local diff_output="${4:-}"

    MANAGED_MERGE_ERROR=""

    # Read local from disk if not provided (backward compat)
    if [ -z "$local_content" ] && [ -f "$file_path" ]; then
        local_content=$(cat "$file_path")
    fi

    # Detect backend for transparency display
    local ai_backend="unknown"
    if command -v claude >/dev/null 2>&1; then
        ai_backend="claude"
    elif command -v agent >/dev/null 2>&1; then
        ai_backend="agent"
    fi
    local display_name
    display_name=$(basename "$file_path")
    printf '  >> AI merge: %s (balanced) -- merging %s...\n' "$ai_backend" "$display_name" > /dev/tty

    # Set validation context for _merge_validate wrapper
    _MERGE_VALIDATE_SOURCE="$source_content"
    _MERGE_VALIDATE_LOCAL="$local_content"

    local current_merge=""
    local iteration=0

    while true; do
        iteration=$((iteration + 1))
        local prompt_text

        if [ -z "$current_merge" ]; then
            prompt_text=$(_ai_prompt_merge "$file_path" "$source_content" "$local_content" "$diff_output")
        else
            local feedback
            printf '  refinement feedback: ' > /dev/tty
            read_tty_choice feedback "no feedback"
            prompt_text=$(_ai_prompt_merge_refine "$source_content" "$local_content" "$current_merge" "$feedback")
        fi

        local merged
        # The traps stop the spinner if Ctrl+C, TERM or an exit ends the run
        # during the AI call; the caller's traps are back right after it
        _spinner_traps_set
        _start_spinner "merging $display_name (attempt $iteration)..."
        # invoke_ai returns 1 on failure with no stdout; || true suppresses set -e abort
        # (the empty result is checked just below)
        merged=$(printf '%s' "$prompt_text" | invoke_ai balanced none _merge_validate 1) || true
        _stop_spinner
        _spinner_traps_restore

        # Defense-in-depth: strip leading/trailing code fences if AI ignored instructions
        if [ -n "$merged" ]; then
            merged=$(printf '%s' "$merged" | perl -0777 -pe 's/\A```[^\n]*\n//; s/\n```\s*\z//')
        fi

        if [ -z "$merged" ]; then
            MANAGED_MERGE_ERROR="AI merge failed (iteration $iteration): ${AI_REJECT_REASON:-unknown error}"
            printf '  >> %s -- nothing written\n' "$MANAGED_MERGE_ERROR" > /dev/tty
            DIFF_REVIEW_RESULT="failed"
            return 0
        fi

        # Show merge preview
        printf '\n  --- merged result preview (first 30 lines) ---\n' > /dev/tty
        printf '%s\n' "$merged" | sed -n '1,30p' | while IFS= read -r line; do
            printf '  | %s\n' "$line" > /dev/tty
        done
        local total_lines
        total_lines=$(printf '%s\n' "$merged" | wc -l | tr -d ' ')
        if [ "$total_lines" -gt 30 ]; then
            printf '  | ... (%d more lines)\n' "$((total_lines - 30))" > /dev/tty
        fi
        printf '\n' > /dev/tty
        local accept
        # Only y, r or n count; anything else asks again; EOF = n (reject)
        read_menu_choice accept "y r n" n "reject the merge (back to the review menu)" \
            "merge preview $display_name" "  [y]es accept / [r]efine / [n]o reject: "
        case "$accept" in
            y)
                MERGED_CONTENT="$merged"
                DIFF_REVIEW_RESULT="merge"
                printf '  >> merged: AI-merged content accepted (iteration %d)\n' "$iteration" > /dev/tty
                return 0
                ;;
            r)
                current_merge="$merged"
                printf '  >> refining merge (iteration %d)...\n' "$iteration" > /dev/tty
                continue
                ;;
            *)  # n (read_menu_choice returns only y, r or n)
                printf '  >> merge rejected -- back to the review menu\n' > /dev/tty
                DIFF_REVIEW_RESULT="menu"
                return 0
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Review choices -- what each one does. Applies to prompt_diff_review,
# deploy_managed_file and review_json_fields below (PS1 twins:
# Prompt-DiffReview, Deploy-ManagedFile, Review-JsonFields). Spec:
# reference/managed-file-deployment.md. Model and AI merge rules:
# .claude/rules/agentic-standards.md "Managed-file review choices and merge".
#
# Terms:
#   SOURCE       the content being deployed (repo or dotprofile); the source
#                of truth
#   LOCAL        the deployed file on disk
#   ADOPT TARGET the repo file SOURCE comes from (ADOPT_PATH). The caller
#                passes its path; this library writes it. "" = no adopt
#                target: adopt and merge are not offered.
# There is no ancestor and no deploy state: the only comparison is SOURCE
# against LOCAL (trailing newlines normalized).
#
# No menu is shown when:
#   LOCAL missing                       -> SOURCE written, "created"
#   LOCAL == SOURCE                     -> nothing written, "verified"
#   no terminal, EOF, or AITOOLS_FORCE  -> SOURCE written (backup), "updated"
#   a read-only copy (MANAGED_NO_REVIEW=true) -> SOURCE written (backup),
#                                          "updated"; JSON too (whole file,
#                                          no field review)
#
# Text files (DEST not ending in .json), one review per file:
#   [o]verwrite      -> SOURCE written to LOCAL (backup kept); "updated"
#   [a]ccept & adopt -> LOCAL kept; LOCAL copied to the adopt target now;
#                       "accept & adopt"
#   [m]erge & adopt  -> AI merge (_invoke_ai_merge: invoke_ai balanced/none,
#                       validated, previewed; [y]es / [r]efine / [n]o). [y]:
#                       the merge is written to LOCAL and to the adopt target
#                       now; "accept & adopt". [n]: back to this menu. No valid
#                       merge output: nothing written; "failed".
#   [s]kip           -> nothing written; "skipped"; reviewed again next run
#   [x]abort         -> error line (logged, counted, not recorded: the relay
#                       records the abort), exit 2: ends this script
# After adopt or merge, SOURCE, LOCAL and the adopt target agree, so the next
# run verifies the file and asks nothing. A caller whose adopt target is not a
# plain copy of LOCAL (CLAUDE.md: machine footer stripped, profile tokens
# restored) passes an adopt filter; the adopt target gets the filtered content.
#
# JSON files (DEST ending in .json; review_json_fields): node compares SOURCE
# and LOCAL field by field (key path; a whole array is one field). Each
# differing field is one prompt_json_field_review: [o]verwrite (SOURCE value
# to LOCAL), [a]dopt (LOCAL value to the adopt target), [s]kip, [x]abort. No
# merge. A field only in LOCAL stays in LOCAL: with an adopt target and a
# terminal it gets [a]dopt / [s]kip / [x]abort (no overwrite); otherwise it is
# kept without a prompt. Key order is preserved in both files. One result per
# file, by precedence: failed > accept & adopt > skipped > updated > verified.
#
# Failure: every file a step writes (LOCAL, and the adopt target for adopt or
# merge) is snapshotted and backed up first (a failed backup of an existing
# file fails the step: nothing written) and validated after (non-empty; JSON
# parses and keeps SOURCE's top-level keys, except keys the review chose to
# leave absent). If a write, the merge or a validation fails, the files are
# restored, the error is recorded once (write_error under the caller's tool,
# with the reason), the result is "failed" (the caller records the outcome with
# the deploy tracker, which writes OK status and DETAIL records only) and the
# run continues with the next file. After adopt or merge, an adopt target in the
# dotprofile is committed (that file only) and pushed (dotprofile_commit_push,
# N-Q2; a failed commit or push is one write_action, the result stays
# "accept & adopt"). Any other adopt target (the aitools repo) is not
# committed: the library logs that its repo has an uncommitted change to
# review and ship.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Review diff shown by prompt_diff_review: LOCAL -> SOURCE, unified format.
# "-" lines are only on this machine, "+" lines only in the repo, so the diff
# reads as what [o]verwrite changes here. The hunks come from
# `git diff --no-index` (the same engine and options as Get-ReviewDiff in
# aitools-lib.ps1, so bash and PS1 print identical hunks); its own headers are
# replaced by:
#   --- this machine  <LOCAL path>
#   +++ repo          <SOURCE path, or "source (embedded)" when there is none>
# Spec: reference/managed-file-deployment.md "Diff Mechanism Detail".
#
# Args: $1 = LOCAL content, $2 = SOURCE content, $3 = LOCAL path (header),
#       $4 = SOURCE path (header; "" -> "source (embedded)")
# Sets REVIEW_DIFF (plain text, no colour; "" when git reports no line
# difference). Returns 1 when the diff cannot be produced, with the reason in
# REVIEW_DIFF_ERROR; the caller logs it.
# ---------------------------------------------------------------------------
REVIEW_DIFF=""
REVIEW_DIFF_ERROR=""
_review_diff() {
    local cur_content="$1"
    local new_content="$2"
    local local_label="$3"
    local source_label="${4:-}"
    REVIEW_DIFF=""
    REVIEW_DIFF_ERROR=""
    if [ -z "$source_label" ]; then source_label="source (embedded)"; fi

    local tmp_dir
    if ! tmp_dir=$(mktemp -d); then
        REVIEW_DIFF_ERROR="could not create a temp directory"
        return 1
    fi
    if ! printf '%s\n' "$cur_content" > "$tmp_dir/local" \
        || ! printf '%s\n' "$new_content" > "$tmp_dir/source"; then
        rm -rf "$tmp_dir"
        REVIEW_DIFF_ERROR="could not write the temp files"
        return 1
    fi

    # git diff exits 1 when the files differ (expected) and >1 on error.
    local raw rc=0 err=""
    # Pinned so user git config cannot change the hunks (GIT_DIFF_OPTS would
    # override -U3); --text keeps content with a NUL byte a text diff.
    raw=$(env -u GIT_DIFF_OPTS git -c core.quotePath=false \
        -c diff.suppressBlankEmpty=false -c diff.interHunkContext=0 \
        diff --no-index --no-color --no-ext-diff --no-textconv --text \
        --diff-algorithm=myers --indent-heuristic -U3 \
        -- "$tmp_dir/local" "$tmp_dir/source" 2> "$tmp_dir/err") || rc=$?
    if [ -s "$tmp_dir/err" ]; then err=$(cat "$tmp_dir/err"); fi
    rm -rf "$tmp_dir"
    if [ "$rc" -gt 1 ]; then
        REVIEW_DIFF_ERROR="git diff failed (exit $rc): ${err:-no output}"
        return 1
    fi

    # Drop git's own header lines (everything before the first hunk).
    local hunks
    hunks=$(printf '%s\n' "$raw" | perl -ne 'print if $seen ||= /^@@ /')
    if [ -z "$hunks" ]; then return 0; fi
    REVIEW_DIFF=$(printf -- '--- this machine  %s\n+++ repo          %s\n%s' \
        "$local_label" "$source_label" "$hunks")
    return 0
}

# Colour for the review diff: on unless NO_COLOR is set or TERM is "dumb".
# Only called on an interactive terminal; the deploy log never gets colour.
_review_colour() {
    [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]
}

# ---------------------------------------------------------------------------
# Show SOURCE against LOCAL and ask what to do ("Review choices" above).
#
# Args:
#   $1 = DEST, the deployed file on disk (LOCAL)
#   $2 = NEW_CONTENT, the SOURCE content
#   $3 = ADOPT_OFFERED: 1 offers [a]ccept & adopt and [m]erge & adopt; 0 hides them
#   $4 = CUR_CONTENT, LOCAL content (optional; read from DEST when empty)
#
# Sets DIFF_REVIEW_RESULT to "overwrite", "adopt", "merge", "skip" or
# "failed"; "merge" also sets MERGED_CONTENT; "failed" (the AI merge produced
# no valid output) sets MANAGED_MERGE_ERROR. Exits 2 on [x]abort
# (_managed_abort).
# Non-interactive, EOF at the prompt, --force / AITOOLS_FORCE: "overwrite".
# ---------------------------------------------------------------------------
DIFF_REVIEW_RESULT=""
_PDR_ADOPT_TARGET=""   # set by deploy_managed_file; display only (+++ header, menu)
_PDR_TOOL=""           # set by deploy_managed_file: the record name of its warnings
prompt_diff_review() {
    local file_path="$1"
    local new_content="$2"
    local adopt_offered="${3:-0}"
    local cur_content="${4:-}"

    DIFF_REVIEW_RESULT="overwrite"
    MERGED_CONTENT=""

    # --force or AITOOLS_FORCE: auto-overwrite. The user asked for it in this
    # run and it completed as asked: info, not a warning (reference/logging.md
    # 8.3 "What is a warning")
    if [ "${AITOOLS_FORCE:-}" = "1" ] || [ "${FORCE:-}" = "true" ]; then
        log "Diff in $(display_path "$file_path") -- overwriting (--force)"
        return 0
    fi

    # Non-interactive: auto-overwrite. Local edits are overwritten without the
    # user's choice: a warning (8.3)
    if ! tty_interactive; then
        write_warn "$_PDR_TOOL" "Diff in $(display_path "$file_path") -- overwriting (non-interactive)"
        return 0
    fi

    # Read current file if not provided
    if [ -z "$cur_content" ] && [ -f "$file_path" ]; then
        cur_content=$(cat "$file_path")
    fi

    # Context header
    # (the diff headers below name both paths)
    printf '\n\033[33m[REVIEW]\033[0m %s differs from source.\n' \
        "$(display_path "$file_path")" > /dev/tty
    printf '\n' > /dev/tty

    # AI merge input ([m]erge & adopt): SOURCE -> LOCAL diff, unchanged from
    # before the display change; the display below does not use it.
    local diff_output
    # diff exits 1 on differences (expected), suppress set -e abort
    diff_output=$(diff -u <(printf '%s' "$new_content") <(printf '%s' "$cur_content") \
        --label "source (would deploy)" --label "local (on disk)" 2>&1) || true

    # Show the review diff: LOCAL -> SOURCE (_review_diff). Parity:
    # Prompt-DiffReview in aitools-lib.ps1 prints the same lines.
    local use_colour=0
    if _review_colour; then use_colour=1; fi
    local adopt_label="the repo"
    if [ -n "$_PDR_ADOPT_TARGET" ]; then adopt_label=$(display_path "$_PDR_ADOPT_TARGET"); fi
    local src_label=""
    if [ -n "$_PDR_ADOPT_TARGET" ]; then src_label="$adopt_label"; fi
    if [ "$use_colour" = "1" ]; then
        printf '  \033[31mred -\033[0m = only on this machine   \033[32mgreen +\033[0m = only in the repo\n\n' > /dev/tty
    else
        printf '  red - = only on this machine   green + = only in the repo\n\n' > /dev/tty
    fi
    local leaf
    leaf=$(basename "$file_path")
    if ! _review_diff "$cur_content" "$new_content" "$(display_path "$file_path")" "$src_label"; then
        write_warn "$_PDR_TOOL" "Review diff unavailable for $(display_path "$file_path"): $REVIEW_DIFF_ERROR"
        printf '  (diff unavailable -- see deploy log)\n' > /dev/tty
    elif [ -z "$REVIEW_DIFF" ]; then
        printf '  (whitespace-only differences)\n' > /dev/tty
    else
        local diff_lines shown
        diff_lines=$(printf '%s\n' "$REVIEW_DIFF" | wc -l | tr -d ' ')
        shown="$REVIEW_DIFF"
        if [ "$diff_lines" -gt 40 ]; then
            # perl reads all of its input: `head` would exit early and make
            # printf die of SIGPIPE under pipefail on a large diff (> pipe buffer).
            shown=$(printf '%s\n' "$REVIEW_DIFF" | perl -ne 'print if $. <= 30')
        fi
        if [ "$use_colour" = "1" ]; then
            printf '%s\n' "$shown" \
                | perl -pe 's/^(-.*)$/\e[31m$1\e[0m/; s/^(\+.*)$/\e[32m$1\e[0m/' > /dev/tty
        else
            printf '%s\n' "$shown" > /dev/tty
        fi
        if [ "$diff_lines" -gt 40 ]; then
            printf '  ... (%d more lines -- full diff in deploy log)\n' \
                "$((diff_lines - 30))" > /dev/tty
        fi
        # Full diff as structured [detail] records at every size, plain text
        # (raw appends broke the log format).
        local diff_line
        while IFS= read -r diff_line; do
            log_detail "diff ${leaf}: $diff_line"
        done <<< "$REVIEW_DIFF"
    fi

    # Menu (parity: Prompt-DiffReview in aitools-lib.ps1). Each line says what
    # the choice does to the lines shown. A rejected merge preview ("menu")
    # shows the menu again.
    local choice
    while true; do
        printf '\n' > /dev/tty
        printf '  [o]verwrite       : this machine gets the green + lines (backup kept)\n' > /dev/tty
        if [ "$adopt_offered" = "1" ]; then
            printf '  [a]ccept & adopt  : the repo gets the red - lines (your version) -> %s\n' "$adopt_label" > /dev/tty
            printf '  [m]erge & adopt   : AI combines both; written to this machine and %s\n' "$adopt_label" > /dev/tty
        fi
        printf '  [s]kip            : nothing written; asked again next run\n' > /dev/tty
        printf '  [x]abort          : stop this script (exit 2)\n' > /dev/tty

        # Only an offered letter counts; an empty line or anything else asks
        # again (read_menu_choice); EOF = o (overwrite)
        if [ "$adopt_offered" = "1" ]; then
            read_menu_choice choice "o a m s x" o "overwrite" "review $leaf" "  choice [o/a/m/s/x]: "
        else
            read_menu_choice choice "o s x" o "overwrite" "review $leaf" "  choice [o/s/x]: "
        fi
        case "$choice" in
            o)  printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                DIFF_REVIEW_RESULT="overwrite" ;;
            a)  printf '  >> accept & adopt: local kept, copied to the repo\n' > /dev/tty
                DIFF_REVIEW_RESULT="adopt" ;;
            m)  _invoke_ai_merge "$file_path" "$new_content" "$cur_content" "$diff_output" ;;
            s)  printf '  >> skipped: local file unchanged\n' > /dev/tty
                DIFF_REVIEW_RESULT="skip" ;;
            x)  _managed_abort ;;
            *)  # unreachable: read_menu_choice returns only an offered letter
                log_error "review $leaf: unexpected answer '$choice' -- asking again"
                DIFF_REVIEW_RESULT="menu" ;;
        esac
        if [ "$DIFF_REVIEW_RESULT" != "menu" ]; then break; fi
    done
    return 0
}

# ---------------------------------------------------------------------------
# Deploy one managed file. SOURCE is the source of truth ("Review choices"
# above prompt_diff_review). Parity: Deploy-ManagedFile in aitools-lib.ps1.
#
# Args:
#   $1 = SRC_CONTENT   content to deploy (SOURCE)
#   $2 = DEST          deployed path (LOCAL). A name ending in .json is
#                      reviewed field by field (review_json_fields).
#   $3 = TOOL_NAME     summary tool name (e.g. "claude rules")
#   $4 = ITEM_NAME     item name for log lines (e.g. "concurrent-agents.md")
#   $5 = ADOPT_PATH    absolute path of the repo file that is the source of
#                      truth; "" = adopt and merge are not offered
#   $6 = ADOPT_FILTER  optional, text files only: name of a function that
#                      reads LOCAL content on stdin and prints the content the
#                      adopt target gets (CLAUDE.md strips its machine footer
#                      and restores profile tokens). "" = plain copy.
# MANAGED_NO_REVIEW=true (set for the one call: MANAGED_NO_REVIEW=true
#   deploy_managed_file ...): LOCAL is a read-only copy (never edited there,
#   e.g. deploy-harness reference/ and registries/): when it differs, SOURCE is
#   written (backup kept) with no menu and no adopt; JSON is written whole, not
#   reviewed field by field. Parity: -NoReview in aitools-lib.ps1.
#
# Sets MANAGED_FILE_RESULT to "created", "updated", "verified",
# "accept & adopt", "skipped" or "failed". The library records each warning and
# error once, under TOOL_NAME (the script's name when TOOL_NAME is ""), at the
# source (reference/logging.md 8.3 "Managed files"):
#   failed   nothing is left half-written (snapshots restored); one write_error,
#            WHAT "Failed: <item>", REASON the write, read, AI merge, adopt
#            filter or validation error
#   skipped  one write_warn "Skipped: <item> (...)"
#   a non-interactive overwrite of a differing LOCAL: one write_warn; under
#            --force it is info (the user asked for it)
# The caller records the outcome with the deploy tracker (OK status and DETAIL
# records only) and writes no second WARN or ERROR record. Exits 2 on [x]abort.
# Honors DRY_RUN (reports, writes nothing).
# ---------------------------------------------------------------------------
MANAGED_FILE_RESULT=""
deploy_managed_file() {
    local src_content="$1"
    local dest="$2"
    local tool_name="$3"
    local item_name="$4"
    local adopt_path="${5:-}"
    local adopt_filter="${6:-}"
    local no_review="${MANAGED_NO_REVIEW:-false}"

    MANAGED_FILE_RESULT="verified"
    _managed_state_notice

    # Normalize trailing newlines for a stable comparison: command substitution
    # strips them, and every write adds exactly one back.
    src_content=$(printf '%s' "$src_content" | perl -0777 -pe 's/[\r\n]+$/\n/')

    # A dangling symlink at DEST: never write through it (the write would create
    # the link's target, wherever it points). A live symlink is read and written
    # through, as before (dotfile managers link deployed files). Parity:
    # Deploy-ManagedFile (same message, also in a dry run).
    if [ -L "$dest" ] && [ ! -e "$dest" ]; then
        write_error "$tool_name" "Failed: $item_name" "$(display_path "$dest") is a dangling symlink -- not written through it"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi

    # Dry run: report what would happen without writing
    if [ "${DRY_RUN:-}" = "true" ]; then
        if [ -f "$dest" ]; then
            local _dr_existing
            _dr_existing=$(cat "$dest")
            _dr_existing=$(printf '%s' "$_dr_existing" | perl -0777 -pe 's/[\r\n]+$/\n/')
            if [ "$_dr_existing" = "$src_content" ]; then
                log "[DRY RUN] Unchanged: $item_name"
            else
                log "[DRY RUN] Would update: $item_name -> $(display_path "$dest")"
            fi
        else
            log "[DRY RUN] Would create: $item_name -> $(display_path "$dest")"
        fi
        return 0
    fi

    # JSON: field-by-field review (a read-only copy is written whole, below)
    case "$dest" in
        *.json)
            if [ "$no_review" != "true" ]; then
                local _src_tmp _src_err
                if ! _src_tmp=$(mktemp 2>&1); then
                    write_error "$tool_name" "Failed: $item_name" "could not create a temp file for the JSON review: $_src_tmp"
                    MANAGED_FILE_RESULT="failed"
                    return 0
                fi
                if ! _src_err=$( { printf '%s\n' "$src_content" > "$_src_tmp"; } 2>&1 ); then
                    rm -f "$_src_tmp"
                    write_error "$tool_name" "Failed: $item_name" "could not write a temp file for the JSON review: ${_src_err:-write failed}"
                    MANAGED_FILE_RESULT="failed"
                    return 0
                fi
                review_json_fields "$_src_tmp" "$dest" "$adopt_path" "$item_name" "$tool_name"
                rm -f "$_src_tmp"
                return 0
            fi ;;
    esac

    # New file: create
    if [ ! -f "$dest" ]; then
        if _managed_write "$dest" "$src_content" "" ""; then
            log_ok "Created: $item_name -> $(display_path "$dest")"
            MANAGED_FILE_RESULT="created"
        else
            write_error "$tool_name" "Failed: $item_name" "$MANAGED_WRITE_ERROR"
            MANAGED_FILE_RESULT="failed"
        fi
        return 0
    fi

    local existing _read_err
    # 2>/dev/null: the failure is checked here and its reason recorded below
    if ! existing=$(cat "$dest" 2>/dev/null); then
        # Read again for the reason only (stdout discarded, stderr captured)
        _read_err=$(cat "$dest" 2>&1 >/dev/null) || :
        write_error "$tool_name" "Failed: $item_name" "cannot read $(display_path "$dest"): ${_read_err:-cat failed}"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    existing=$(printf '%s' "$existing" | perl -0777 -pe 's/[\r\n]+$/\n/')
    if [ "$existing" = "$src_content" ]; then
        MANAGED_FILE_RESULT="verified"
        return 0
    fi

    # A read-only copy: SOURCE wins, no menu, no adopt (backup kept by _managed_write)
    if [ "$no_review" = "true" ]; then
        if _managed_write "$dest" "$src_content" "" ""; then
            log_ok "Updated: $item_name -> $(display_path "$dest") (read-only copy: source wins, backup kept)"
            MANAGED_FILE_RESULT="updated"
        else
            write_error "$tool_name" "Failed: $item_name" "$MANAGED_WRITE_ERROR (files restored)"
            MANAGED_FILE_RESULT="failed"
        fi
        return 0
    fi

    # LOCAL differs from SOURCE: review (non-interactive / EOF / --force -> overwrite)
    local adopt_offered=0
    if [ -n "$adopt_path" ]; then adopt_offered=1; fi
    _PDR_ADOPT_TARGET="$adopt_path"
    _PDR_TOOL="$tool_name"
    prompt_diff_review "$dest" "$src_content" "$adopt_offered" "$existing"
    _PDR_ADOPT_TARGET=""
    _PDR_TOOL=""

    local p_local="$dest" local_out="$src_content" p_repo="" repo_content=""
    case "$DIFF_REVIEW_RESULT" in
        skip)
            write_warn "$tool_name" "Skipped: $item_name (local differs from source; reviewed again next run)"
            MANAGED_FILE_RESULT="skipped"
            return 0 ;;
        failed)
            write_error "$tool_name" "Failed: $item_name" "${MANAGED_MERGE_ERROR:-AI merge failed} -- nothing written"
            MANAGED_FILE_RESULT="failed"
            return 0 ;;
        adopt)
            p_local=""; local_out=""
            p_repo="$adopt_path"; repo_content="$existing" ;;
        merge)
            local_out=$(printf '%s' "$MERGED_CONTENT" | perl -0777 -pe 's/[\r\n]+$/\n/')
            p_repo="$adopt_path"; repo_content="$local_out" ;;
    esac

    # The adopt target gets LOCAL (or the merge), passed through the filter if any
    if [ -n "$p_repo" ] && [ -n "$adopt_filter" ]; then
        local filtered filter_rc=0
        filtered=$(printf '%s\n' "$repo_content" | "$adopt_filter") || filter_rc=$?
        if [ "$filter_rc" -ne 0 ] || [ -z "$filtered" ]; then
            if [ "$filter_rc" -ne 0 ]; then
                write_error "$tool_name" "Failed: $item_name" "adopt filter $adopt_filter failed (exit $filter_rc) -- nothing written"
            else
                write_error "$tool_name" "Failed: $item_name" "adopt filter $adopt_filter returned nothing -- nothing written"
            fi
            MANAGED_FILE_RESULT="failed"
            return 0
        fi
        repo_content="$filtered"
    fi

    if ! _managed_write "$p_local" "$local_out" "$p_repo" "$repo_content"; then
        write_error "$tool_name" "Failed: $item_name" "$MANAGED_WRITE_ERROR (files restored)"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi

    if [ -n "$p_repo" ]; then
        log_ok "Accept & adopt: $item_name -> $(display_path "$p_repo")"
        _managed_adopt_notice "$p_repo" "$tool_name"
        MANAGED_FILE_RESULT="accept & adopt"
    else
        log_ok "Updated: $item_name -> $(display_path "$dest")"
        MANAGED_FILE_RESULT="updated"
    fi
}

# ---------------------------------------------------------------------------
# Review a JSON managed file field by field ("Review choices" above).
# Parity: Review-JsonFields in aitools-lib.ps1 (same embedded node script).
#
# Args:
#   $1 = SRC_FILE    file holding the SOURCE JSON
#   $2 = DEST        deployed JSON file (LOCAL)
#   $3 = ADOPT_PATH  repo JSON file that is the source of truth; "" = no adopt
#   $4 = ITEM_NAME   the file as the review header names it (default: DEST's
#                    file name)
#   $5 = TOOL        optional: the record name of its warnings and errors
#                    (deploy_managed_file passes its TOOL_NAME); default the
#                    script's name
#
# Sets MANAGED_FILE_RESULT, one per file by precedence failed > accept & adopt
# > skipped > updated > verified: "created" (LOCAL was missing), "failed"
# (files restored; one write_error TOOL "Failed: <file>" with the reason),
# "accept & adopt" (a field was adopted into
# ADOPT_PATH; overwrites chosen in the same run are written too), "skipped"
# (a field was left differing; one write_warn TOOL), "updated" (fields
# overwritten from SOURCE), "verified" (nothing written). A field overwritten
# in a non-interactive run is one write_warn TOOL (prompt_json_field_review;
# info under --force). Requires node.
# Exits 2 on [x]abort.
# ---------------------------------------------------------------------------
review_json_fields() {
    local src_file="$1" dest="$2" adopt_path="${3:-}" file_label="${4:-}" tool="${5:-}"
    local item
    item=$(basename "$dest")
    # The review header names the file (the caller's item name, else the file name)
    if [ -z "$file_label" ]; then file_label="$item"; fi
    MANAGED_FILE_RESULT="verified"

    if ! command -v node >/dev/null 2>&1; then
        write_error "$tool" "Failed: $item" "node is required for the JSON field review"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi

    local work
    if ! work=$(mktemp -d 2>&1); then
        write_error "$tool" "Failed: $item" "could not create a work directory for the JSON review: $work"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    cat > "$work/review.js" <<'REVIEW_JSON_NODE_EOF'
// review_json_fields / Review-JsonFields: SOURCE against LOCAL, field by field.
// The same text is embedded in aitools-lib.sh and aitools-lib.ps1: keep them identical.
//   plan  SRC LOCAL OUT_PLAN
//     OUT_PLAN: one line per differing field: idx<TAB>kind<TAB>key<TAB>local<TAB>source<TAB>detail
//     kind: differ | source-only | local-only. A whole array is one field; its
//     detail lists the elements that differ (arrayDetail), "" for other fields.
//   apply SRC LOCAL ADOPT CHOICES OUT_LOCAL OUT_ADOPT OUT_RESULT OUT_REQ_LOCAL OUT_REQ_ADOPT
//     ADOPT: the adopt target, or "-" for none.
//     CHOICES: idx<TAB>overwrite|adopt|skip|keep per field (missing = skip).
//     OUT_LOCAL / OUT_ADOPT: new file content, or empty when that file is unchanged.
//     OUT_RESULT: "over=N adopt=N skip=N kept=N".
//     OUT_REQ_LOCAL / OUT_REQ_ADOPT: JSON array of SOURCE's top-level keys the
//     written file must keep (keys the review chose to leave absent excluded).
//   keys  SRC OUT_KEYS
//     OUT_KEYS: JSON array of SOURCE's top-level keys ([] when not an object).
// Key order is preserved: existing keys keep their position, new keys are appended.
// Exit 3 with the reason on stderr when a file cannot be read or parsed.
const fs = require('fs');
const mode = process.argv[2];
function readJson(p, label) {
    let text;
    try { text = fs.readFileSync(p, 'utf8'); }
    catch (e) {
        if (e.code === 'ENOENT') return undefined;
        throw new Error(label + ': cannot read ' + p + ': ' + e.message);
    }
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
    try { return JSON.parse(text); }
    catch (e) { throw new Error(label + ': ' + p + ' is not valid JSON: ' + e.message); }
}
function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
function canon(v) {
    if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
    if (isObj(v)) return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
    return JSON.stringify(v);
}
function fields(src, loc) {
    const out = [];
    if (!isObj(src) || !isObj(loc)) {
        if (canon(src) !== canon(loc)) out.push({ path: [], kind: 'differ', s: src, l: loc });
        return out;
    }
    (function walk(s, l, path) {
        const keys = Object.keys(s).concat(Object.keys(l).filter(k => !has(s, k)));
        for (const k of keys) {
            const p = path.concat([k]);
            const inS = has(s, k), inL = has(l, k);
            if (inS && inL) {
                if (isObj(s[k]) && isObj(l[k])) walk(s[k], l[k], p);
                else if (canon(s[k]) !== canon(l[k])) out.push({ path: p, kind: 'differ', s: s[k], l: l[k] });
            } else if (inS) {
                out.push({ path: p, kind: 'source-only', s: s[k] });
            } else {
                out.push({ path: p, kind: 'local-only', l: l[k] });
            }
        }
    })(src, loc, []);
    return out;
}
function disp(v) {
    if (v === undefined) return '(absent)';
    let t = JSON.stringify(v);
    if (t.length > 200) t = t.slice(0, 197) + '...';
    return t;
}
function clean(t) { return String(t).replace(/[\t\r\n\x1f]/g, ' '); }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }
function short(v, n) {
    const t = v === undefined ? '(absent)' : JSON.stringify(v);
    return t.length > n ? t.slice(0, n - 3) + '...' : t;
}
// identity(v): "id=172" for an object element with an id, name, key, file or
// slug (string or number), else undefined
function identity(v) {
    if (!isObj(v)) return undefined;
    for (const k of ['id', 'name', 'key', 'file', 'slug']) {
        if (has(v, k) && (typeof v[k] === 'string' || typeof v[k] === 'number')) return k + '=' + JSON.stringify(v[k]);
    }
    return undefined;
}
// arrayDetail(l, s): the plan's detail column for an array field ("" for
// anything else). Lines joined by \x1f: a count line, then "- [i] value" (only
// in LOCAL, its index there), "+ [j] value" (only in SOURCE, its index there)
// and "~ [j] id=..: key: local -> source" (an object element with the same
// identity in both, one line per changed key). Elements are matched by value,
// so a reorder alone is one "~ order differs" line. At most 20 element lines.
function arrayDetail(l, s) {
    if (!Array.isArray(l) || !Array.isArray(s)) return '';
    const left = new Map();
    l.forEach((v, i) => { const c = canon(v); if (!left.has(c)) left.set(c, []); left.get(c).push(i); });
    const added = [];
    s.forEach((v, j) => { const q = left.get(canon(v)); if (q && q.length) q.shift(); else added.push(j); });
    const removed = [];
    for (const q of left.values()) removed.push(...q);
    removed.sort((a, b) => a - b);
    const byId = new Map();
    for (const i of removed) { const id = identity(l[i]); if (id !== undefined && !byId.has(id)) byId.set(id, i); }
    const paired = new Set();
    const rows = [];
    for (const j of added) {
        const id = identity(s[j]);
        if (id !== undefined && byId.has(id) && !paired.has(byId.get(id))) {
            const i = byId.get(id), a = l[i], b = s[j];
            paired.add(i);
            const keys = Object.keys(a).concat(Object.keys(b).filter(k => !has(a, k)));
            const ls = keys.filter(k => canon(a[k]) !== canon(b[k]))
                .map(k => '~ [' + j + '] ' + id + ': ' + k + ': ' + short(a[k], 70) + ' -> ' + short(b[k], 70));
            rows.push([j, ls]);
        } else {
            rows.push([j, ['+ [' + j + '] ' + short(s[j], 160)]]);
        }
    }
    for (const i of removed) if (!paired.has(i)) rows.push([i, ['- [' + i + '] ' + short(l[i], 160)]]);
    rows.sort((x, y) => x[0] - y[0]);
    let out = [];
    for (const r of rows) out.push(...r[1]);
    if (out.length === 0) out.push('~ order differs (same elements)');
    if (out.length > 20) out = out.slice(0, 20).concat(['... ' + (out.length - 20) + ' more line(s)']);
    return [l.length + ' local, ' + s.length + ' source element(s)'].concat(out).map(clean).join('\x1f');
}
function setPath(obj, path, val) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) o[path[i]] = {};
        o = o[path[i]];
    }
    o[path[path.length - 1]] = val;
}
function delPath(obj, path) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) return;
        o = o[path[i]];
    }
    delete o[path[path.length - 1]];
}
function keptKeys(src, obj) {
    if (!isObj(src) || !isObj(obj)) return [];
    return Object.keys(src).filter(k => has(obj, k));
}
try {
    const src = readJson(process.argv[3], 'source');
    if (src === undefined) throw new Error('source: ' + process.argv[3] + ' not found');
    if (mode === 'keys') {
        fs.writeFileSync(process.argv[4], JSON.stringify(isObj(src) ? Object.keys(src) : []) + '\n');
        process.exit(0);
    }
    const loc = readJson(process.argv[4], 'local');
    if (loc === undefined) throw new Error('local: ' + process.argv[4] + ' not found');
    const list = fields(src, loc);
    if (mode === 'plan') {
        const lines = list.map((f, i) => [i, f.kind, f.path.length ? clean(f.path.join('.')) : '(document)',
            clean(disp(f.l)), clean(disp(f.s)), f.kind === 'differ' ? arrayDetail(f.l, f.s) : ''].join('\t'));
        fs.writeFileSync(process.argv[5], lines.length ? lines.join('\n') + '\n' : '');
    } else if (mode === 'apply') {
        const adoptPath = (process.argv[5] && process.argv[5] !== '-') ? process.argv[5] : '';
        const choices = {};
        for (const line of fs.readFileSync(process.argv[6], 'utf8').split(/\r?\n/)) {
            const m = /^(\d+)\t(\w+)$/.exec(line);
            if (m) choices[m[1]] = m[2];
        }
        let newLocal = clone(loc);
        let adoptObj;
        if (adoptPath) {
            adoptObj = readJson(adoptPath, 'adopt target');
            if (adoptObj === undefined) adoptObj = clone(src);
        }
        let over = 0, adopt = 0, skip = 0, kept = 0;
        list.forEach((f, i) => {
            const c = choices[String(i)] || 'skip';
            if (c === 'adopt' && adoptPath) {
                adopt++;
                if (f.path.length === 0) adoptObj = clone(f.l);
                else if (f.kind === 'source-only') delPath(adoptObj, f.path);
                else setPath(adoptObj, f.path, clone(f.l));
            } else if (c === 'overwrite' && f.kind !== 'local-only') {
                over++;
                if (f.path.length === 0) newLocal = clone(f.s);
                else setPath(newLocal, f.path, clone(f.s));
            } else if (f.kind === 'local-only' && c !== 'skip') {
                kept++;
            } else {
                skip++;
            }
        });
        fs.writeFileSync(process.argv[7], over ? JSON.stringify(newLocal, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[8], adopt ? JSON.stringify(adoptObj, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[9], 'over=' + over + ' adopt=' + adopt + ' skip=' + skip + ' kept=' + kept + '\n');
        fs.writeFileSync(process.argv[10], JSON.stringify(keptKeys(src, newLocal)) + '\n');
        fs.writeFileSync(process.argv[11], JSON.stringify(adoptPath ? keptKeys(src, adoptObj) : []) + '\n');
    } else {
        throw new Error('unknown mode: ' + mode);
    }
} catch (e) {
    process.stderr.write(String((e && e.message) || e) + '\n');
    process.exit(3);
}
REVIEW_JSON_NODE_EOF

    local rc=0
    if [ ! -f "$dest" ]; then
        local src_json
        node "$work/review.js" keys "$src_file" "$work/keys.json" 2> "$work/err" || rc=$?
        if [ "$rc" -ne 0 ] || ! src_json=$(cat "$src_file"); then
            # The reason is one line (error_reason: 8.3); node's whole stderr is
            # logged as detail lines
            write_error "$tool" "Failed: $item" "cannot read the source JSON (node exit $rc): $(error_reason "$(cat "$work/err")" "$rc")"
            rm -rf "$work"
            MANAGED_FILE_RESULT="failed"
            return 0
        fi
        MANAGED_WRITE_REQUIRED_1=$(cat "$work/keys.json")
        rm -rf "$work"
        if _managed_write "$dest" "$src_json" "" ""; then
            log_ok "Created: $file_label -> $(display_path "$dest")"
            MANAGED_FILE_RESULT="created"
        else
            write_error "$tool" "Failed: $item" "$MANAGED_WRITE_ERROR"
            MANAGED_FILE_RESULT="failed"
        fi
        return 0
    fi

    node "$work/review.js" plan "$src_file" "$dest" "$work/plan.tsv" 2> "$work/err" || rc=$?
    if [ "$rc" -ne 0 ]; then
        write_error "$tool" "Failed: $item" "field comparison failed (node exit $rc): $(error_reason "$(cat "$work/err")" "$rc")"
        rm -rf "$work"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    if [ ! -s "$work/plan.tsv" ]; then
        rm -rf "$work"
        MANAGED_FILE_RESULT="verified"
        return 0
    fi

    # One review per differing field. fd 3 carries the plan so stdin stays the
    # terminal (tty_interactive tests stdin).
    local adopt_ok=0 can_prompt=0
    if [ -n "$adopt_path" ]; then adopt_ok=1; fi
    if [ "${AITOOLS_FORCE:-}" != "1" ] && [ "${FORCE:-}" != "true" ] && tty_interactive; then can_prompt=1; fi
    : > "$work/choices.tsv"
    local idx kind key ldisp sdisp detail choice
    while IFS=$'\t' read -r idx kind key ldisp sdisp detail <&3; do
        [ -n "$idx" ] || continue
        if [ "$kind" = "local-only" ]; then
            # A field only in LOCAL: [a]dopt / [s]kip / [x]abort, no overwrite.
            # Without an adopt target or a terminal it is kept, no prompt.
            if [ "$adopt_ok" = "1" ] && [ "$can_prompt" = "1" ]; then
                prompt_json_field_review "$key" "$ldisp" "(not in source)" "source" "1" "local" "0" "$file_label" "" "$tool"
                choice="$JSON_FIELD_REVIEW_RESULT"
            else
                log_detail "$item: $key only in local -- kept"
                choice="keep"
            fi
        else
            prompt_json_field_review "$key" "$ldisp" "$sdisp" "source" "$adopt_ok" "local" "1" "$file_label" "$detail" "$tool"
            choice="$JSON_FIELD_REVIEW_RESULT"
        fi
        printf '%s\t%s\n' "$idx" "$choice" >> "$work/choices.tsv"
    done 3< "$work/plan.tsv"

    rc=0
    node "$work/review.js" apply "$src_file" "$dest" "${adopt_path:--}" "$work/choices.tsv" \
        "$work/local.out" "$work/adopt.out" "$work/result.txt" \
        "$work/req-local.json" "$work/req-adopt.json" 2> "$work/err" || rc=$?
    if [ "$rc" -ne 0 ]; then
        write_error "$tool" "Failed: $item" "applying the field choices failed (node exit $rc): $(error_reason "$(cat "$work/err")" "$rc")"
        rm -rf "$work"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    local counts n_over n_adopt n_skip
    counts=$(cat "$work/result.txt")
    n_over=$(printf '%s' "$counts" | perl -ne 'print $1 if /over=(\d+)/')
    n_adopt=$(printf '%s' "$counts" | perl -ne 'print $1 if /adopt=(\d+)/')
    n_skip=$(printf '%s' "$counts" | perl -ne 'print $1 if /skip=(\d+)/')
    log_detail "$item: field review $counts"

    local p_local="" c_local="" p_adopt="" c_adopt="" r_local r_adopt
    r_local=$(cat "$work/req-local.json")
    r_adopt=$(cat "$work/req-adopt.json")
    if [ -s "$work/local.out" ]; then p_local="$dest"; c_local=$(cat "$work/local.out"); fi
    if [ -s "$work/adopt.out" ]; then p_adopt="$adopt_path"; c_adopt=$(cat "$work/adopt.out"); fi
    rm -rf "$work"

    if [ -n "$p_local" ] || [ -n "$p_adopt" ]; then
        MANAGED_WRITE_REQUIRED_1="$r_local"
        MANAGED_WRITE_REQUIRED_2="$r_adopt"
        if ! _managed_write "$p_local" "$c_local" "$p_adopt" "$c_adopt"; then
            write_error "$tool" "Failed: $item" "$MANAGED_WRITE_ERROR (files restored)"
            MANAGED_FILE_RESULT="failed"
            return 0
        fi
    fi
    if [ "${n_over:-0}" -gt 0 ]; then
        log_ok "Updated: $file_label -> $(display_path "$dest") ($n_over field(s) from source)"
    fi
    if [ "${n_adopt:-0}" -gt 0 ]; then
        log_ok "Accept & adopt: $file_label -> $(display_path "$adopt_path") ($n_adopt field(s))"
        _managed_adopt_notice "$adopt_path" "$tool"
    fi
    if [ "${n_skip:-0}" -gt 0 ]; then
        write_warn "$tool" "Skipped: $file_label ($n_skip field(s) differ from source; reviewed again next run)"
    fi
    if [ "${n_adopt:-0}" -gt 0 ]; then
        MANAGED_FILE_RESULT="accept & adopt"
    elif [ "${n_skip:-0}" -gt 0 ]; then
        MANAGED_FILE_RESULT="skipped"
    elif [ "${n_over:-0}" -gt 0 ]; then
        MANAGED_FILE_RESULT="updated"
    else
        MANAGED_FILE_RESULT="verified"
    fi
}

# ---------------------------------------------------------------------------
# Write an adopted file back to its source-of-truth target(s).
#
# Companion to deploy_managed_file: when the diff review returns
# "accept & adopt", the local (deployed) file won and must propagate back to
# every canonical source it was deployed from -- e.g. the user's dotprofile AND
# the shared/ template. Centralizes the backup+rotate+copy+log that callers
# used to hand-roll, so all adopt paths behave identically.
#
# For each target: rotate a timestamped backup of the existing target (via
# backup_file -- keeps 20, prunes oldest), ensure its parent dir, then copy the
# adopted content over it. Empty target args are skipped, so callers may pass an
# optional path (e.g. "${VAR:+...}") without branching.
#
# Args:
#   --tool TOOL  optional, first: the record name of its errors (default the
#                script's name)
#   $1     = adopted source file to copy FROM (the deployed file on disk)
#   $2..$N = one or more target paths to write back to (empty entries skipped)
#
# Sets ADOPT_TARGETS_WRITTEN to the count written. Returns 0 if >=1 target was
# written, 1 otherwise (source missing or no non-empty targets). Each failure
# is one write_error TOOL with its reason.
# ---------------------------------------------------------------------------
ADOPT_TARGETS_WRITTEN=0
adopt_managed_file() {
    local tool="" src err
    if [ "${1:-}" = "--tool" ]; then tool="${2:-}"; shift 2; fi
    src="$1"; shift
    ADOPT_TARGETS_WRITTEN=0

    if [ ! -f "$src" ]; then
        write_error "$tool" "adopt failed" "adopted source not found: $(display_path "$src")"
        return 1
    fi

    local target
    for target in "$@"; do
        [ -n "$target" ] || continue
        backup_file "$target"                 # rotation; no-op if target absent
        if ! err=$(mkdir -p "$(dirname "$target")" 2>&1); then
            write_error "$tool" "adopt to $(display_path "$target") failed" "cannot create its directory: $err"
            continue
        fi
        if err=$(cp "$src" "$target" 2>&1); then
            log_ok "Adopted -> $(display_path "$target")"
            ADOPT_TARGETS_WRITTEN=$((ADOPT_TARGETS_WRITTEN + 1))
        else
            write_error "$tool" "adopt to $(display_path "$target") failed" "${err:-cp failed}"
        fi
    done

    [ "$ADOPT_TARGETS_WRITTEN" -gt 0 ] && return 0 || return 1
}

# ---------------------------------------------------------------------------
# Deploy tracker: centralizes outcome counting and summary writing for
# loops that deploy multiple managed files (rules, skills, hooks).
# ---------------------------------------------------------------------------

# Reset all deploy tracker counters. Call before a deploy loop.
_DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
_DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0; _DT_REMOVED=0
DEPLOY_TRACKER_TEXT=""

deploy_tracker_init() {
    _DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
    _DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0; _DT_REMOVED=0
    DEPLOY_TRACKER_TEXT=""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
# "removed": the caller backed up and deleted a deployed file (a fan-out
# consumer pruning a retired rule). An outcome the tracker does not know is a
# caller bug: it is logged and counted as failed, never dropped.
# Args: $1=outcome $2=tool_name $3=item_name
deploy_tracker_record() {
    local outcome="$1" tool_name="$2" item_name="$3"
    case "$outcome" in
        added|created) _DT_ADDED=$((_DT_ADDED + 1))
                   write_summary DETAIL "$tool_name" "added: $item_name" ;;
        updated)   _DT_UPDATED=$((_DT_UPDATED + 1))
                   write_summary DETAIL "$tool_name" "updated: $item_name" ;;
        "accept & adopt") _DT_ACCEPTED=$((_DT_ACCEPTED + 1))
                       write_summary DETAIL "$tool_name" "accept & adopt: $item_name" ;;
        skipped)   _DT_SKIPPED=$((_DT_SKIPPED + 1))
                   write_summary DETAIL "$tool_name" "skipped: $item_name" ;;
        failed)    _DT_FAILED=$((_DT_FAILED + 1))
                   write_summary DETAIL "$tool_name" "failed: $item_name" ;;
        removed)   _DT_REMOVED=$((_DT_REMOVED + 1))
                   write_summary DETAIL "$tool_name" "removed: $item_name" ;;
        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
        *)         log_error "deploy_tracker_record: unknown outcome \"$outcome\" for $item_name ($tool_name) -- counted as failed"
                   _DT_FAILED=$((_DT_FAILED + 1))
                   write_summary DETAIL "$tool_name" "failed: $item_name" ;;
    esac
}

# Write the tool's status for a deploy loop: one OK record with the non-zero
# counts (e.g. "1 updated, 5 verified, 1 skipped, 1 failed"); the DETAIL
# records were written by deploy_tracker_record. It writes no WARN or ERROR
# record: each skipped item's warning and each failed item's error was
# recorded once where it happened (deploy_managed_file, the fan-out:
# reference/logging.md 8.3 "Managed files"), and the panel shows a tool with a
# warning or an error in yellow or red, not this OK record.
# Sets DEPLOY_TRACKER_TEXT for use in log lines.
# Args: $1=tool_name
deploy_tracker_summary() {
    local tool_name="$1"
    local parts=""
    if [ "$_DT_ADDED" -gt 0 ];    then parts="$_DT_ADDED added"; fi
    if [ "$_DT_UPDATED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_UPDATED updated"; fi
    if [ "$_DT_ACCEPTED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_ACCEPTED accepted"; fi
    if [ "$_DT_REMOVED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_REMOVED removed"; fi
    if [ "$_DT_VERIFIED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_VERIFIED verified"; fi
    if [ "$_DT_SKIPPED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_SKIPPED skipped"; fi
    if [ "$_DT_FAILED" -gt 0 ];   then parts="${parts:+$parts, }$_DT_FAILED failed"; fi
    # Every count 0 (nothing recorded, or only preserved items): not
    # "verified", which would claim a check that never ran
    if [ -z "$parts" ]; then parts="n/a (nothing to deploy)"; fi
    DEPLOY_TRACKER_TEXT="$parts"
    write_summary OK "$tool_name" "$parts"
}

# ---------------------------------------------------------------------------
# Fan-out helpers, for the consumers of ~/.aitools/rules and ~/.aitools/skills
# (setup-user-claude, setup-user-cursor; setup-user-cursor still defines its own
# copies of lower_name, in_list and read_rules_manifest, which match these).
# deploy-harness writes one manifest per kind (rules: PR #100 contract; skills:
# plans/skills-and-rules-fanout.md section 3.2): first line RULES_MANIFEST_HEADER
# or SKILLS_MANIFEST_HEADER, then "<name><TAB><source>" lines, source shared |
# aitools | dotprofile | retired. Parity: Get-RuleNameKind, Get-SkillNameKind,
# Read-HarnessManifest, Read-RulesManifest, Test-FanoutTextEqual and
# Test-FanoutDirMatches in aitools-lib.ps1 (same results, same exit codes).
# ---------------------------------------------------------------------------
RULES_MANIFEST_HEADER="# aitools rules manifest v1"
SKILLS_MANIFEST_HEADER="# aitools skills manifest v1"

# Lower-case a name (APFS and NTFS are case-insensitive)
lower_name() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Exit 0 when the line $1 is in the newline-separated list $2 (bash 3.2: no
# associative arrays)
in_list() {
    case "
$2" in
        *"
$1
"*) return 0 ;;
    esac
    return 1
}

# Print the kind of a file name in ~/.aitools/rules, compared case-insensitively
# (commander decision 2026-10-22): "hidden" (a dot file, e.g. the rules
# manifest), "backup" (*.bak.*, the library's backup naming), "rule" (*.md) or
# "other". Parity: Get-RuleNameKind in aitools-lib.ps1.
rule_name_kind() {
    local lc
    lc=$(lower_name "$1")
    case "$lc" in
        .*)      printf 'hidden\n' ;;
        *.bak.*) printf 'backup\n' ;;
        *.md)    printf 'rule\n' ;;
        *)       printf 'other\n' ;;
    esac
}

# Print the kind of an entry name in ~/.aitools/skills, compared
# case-insensitively: "hidden" (a dot name, e.g. the skills manifest), "backup"
# (*.bak.*, a backed-up skill directory) or "skill" (anything else). The name
# only: the caller checks that a "skill" entry is a directory.
# Parity: Get-SkillNameKind in aitools-lib.ps1.
skill_name_kind() {
    local lc
    lc=$(lower_name "$1")
    case "$lc" in
        .*)      printf 'hidden\n' ;;
        *.bak.*) printf 'backup\n' ;;
        *)       printf 'skill\n' ;;
    esac
}

# read_harness_manifest FILE KIND: print the manifest FILE of KIND (rules or
# skills) as lines "rule<TAB><name><TAB><source>" (the same first word for both
# kinds) and "invalid<TAB><line, tabs as <TAB>>", or the one line "header-bad"
# when its first line (a UTF-8 BOM and a CR before the LF ignored) is not the
# kind's header. A valid line: a name with no / or \ and no .bak. (rules: a *.md
# name, any case; skills: not starting with a dot), a source of shared, aitools,
# dotprofile or retired, and a name not already listed (compared
# case-insensitively). Exit codes:
#   0  read (the output may be "header-bad")
#   1  FILE missing, unreadable or a directory ("cannot read FILE: <reason>"
#      on stderr)
#   2  unknown KIND, a caller bug (message on stderr)
# The caller captures 2>&1 and checks the exit. setup-user-cursor's own copy
# of read_rules_manifest exits with perl's errno for a read failure; the
# output and message are the same. Parity: Read-HarnessManifest in
# aitools-lib.ps1 (throws for both failures).
read_harness_manifest() {
    local header
    case "${2:-}" in
        rules)  header="$RULES_MANIFEST_HEADER" ;;
        skills) header="$SKILLS_MANIFEST_HEADER" ;;
        *)
            printf 'read_harness_manifest: unknown kind "%s" (rules or skills)\n' "${2:-}" >&2
            return 2 ;;
    esac
    perl -e '
        my ($f, $header, $kind) = @ARGV;
        if (-d $f) { print STDERR "cannot read $f: is a directory\n"; exit 1 }
        open my $fh, "<:raw", $f or do { print STDERR "cannot read $f: $!\n"; exit 1 };
        my $head = <$fh>; $head = "" unless defined $head;
        $head =~ s/\A\xEF\xBB\xBF//; $head =~ s/\r?\n\z//;
        if ($head ne $header) { print "header-bad\n"; exit 0 }
        my $name_re = $kind eq "rules" ? qr/\A[^\/\\]+\.[mM][dD]\z/ : qr/\A[^\/\\.][^\/\\]*\z/;
        my %seen;
        while (my $l = <$fh>) {
            $l =~ s/\r?\n\z//;
            next if $l eq "";
            my ($name, $src) = split /\t/, $l, 2;
            $src = "" unless defined $src;
            if ($name !~ $name_re || $name =~ /\.bak\./
                    || $src !~ /\A(?:shared|aitools|dotprofile|retired)\z/ || $seen{lc $name}++) {
                (my $show = $l) =~ s/\t/<TAB>/g;
                print "invalid\t$show\n";
                next;
            }
            print "rule\t$name\t$src\n";
        }
        close $fh;
    ' "$1" "$header" "$2"
}

# read_rules_manifest FILE: read_harness_manifest FILE rules (the output of
# setup-user-cursor's own read_rules_manifest, byte for byte).
# Parity: Read-RulesManifest in aitools-lib.ps1.
read_rules_manifest() {
    read_harness_manifest "$1" rules
}

# _fanout_log_detail_lines PREFIX TEXT: one detail log line "PREFIX: <line>"
# per non-empty line of TEXT, so a multi-line reason keeps the
# [timestamp] [script] [detail] format on every line
_fanout_log_detail_lines() {
    local prefix="$1" l
    while IFS= read -r l; do
        if [ -n "$l" ]; then
            log_detail "$prefix: $l"
        fi
    done <<< "${2:-}"
}

# fanout_text_equal A B: exit 0 when files A and B hold the same bytes apart
# from trailing CR/LF (deploy_managed_file normalizes trailing newlines), 1 when
# they differ, 2 when they cannot be compared: a file is missing, a directory
# or unreadable, or perl itself failed. Every exit 2 writes a detail log line
# "fanout_text_equal: cannot read <file>: <reason>" or "fanout_text_equal: perl
# failed (exit N): <message>". Parity: Test-FanoutTextEqual in aitools-lib.ps1.
fanout_text_equal() {
    local rc=0 why=""
    # perl writes only failure reasons (stderr, captured)
    why=$(perl -e '
        my @t;
        for my $f (@ARGV) {
            if (-d $f) { print STDERR "cannot read $f: is a directory\n"; exit 2 }
            open my $fh, "<:raw", $f or do { print STDERR "cannot read $f: $!\n"; exit 2 };
            local $/; my $c = <$fh>; close $fh;
            $c = "" unless defined $c; $c =~ s/[\r\n]+\z//; push @t, $c;
        }
        exit($t[0] eq $t[1] ? 0 : 1);
    ' "${1:-}" "${2:-}" 2>&1) || rc=$?
    if [ "$rc" -gt 2 ]; then
        why="perl failed (exit $rc)${why:+: $why}"
        rc=2
    elif [ "$rc" -eq 2 ] && [ -z "$why" ]; then
        why="perl failed (exit 2) with no message"
    fi
    if [ -n "$why" ]; then
        _fanout_log_detail_lines "fanout_text_equal" "$why"
    fi
    return "$rc"
}

# fanout_dir_matches TARGET CAND: exit 0 when TARGET is a real directory (not a
# symlink), every regular file under it (recursive; a file whose base name is
# *.bak.*, compared case-insensitively, is ignored) exists as a regular file
# (a symlink to one counts) at the same relative path under CAND and is equal
# to it as fanout_text_equal compares, and it holds at least one such file.
# Exit 1 otherwise: TARGET or CAND empty; TARGET missing, a file or a symlink;
# no such file; a file missing, different or not a regular file in CAND; any
# non-regular entry anywhere under TARGET -- a symlink (never followed: what
# the fan-out did not write is the user's), a FIFO, a socket, a block or
# character device. Exit 2 when an entry cannot be read: a directory that
# cannot be listed, an entry that cannot be lstat'ed (a directory without
# search permission), a file that cannot be read; or perl failed. 2 wins over 1
# (the whole tree is checked). Every reason for exit 2 is its own detail log
# line "fanout_dir_matches: cannot list <dir>: <reason>" / "fanout_dir_matches:
# cannot read <path>: <reason>". Used before pruning a retired skill directory.
# Parity: Test-FanoutDirMatches in aitools-lib.ps1.
fanout_dir_matches() {
    local rc=0 why=""
    if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
        return 1
    fi
    # perl writes only failure reasons (stderr, captured), one line each
    why=$(perl -e '
        my ($t, $c) = @ARGV;
        exit 1 if -l $t || ! -d $t;
        my ($n, $bad, $err) = (0, 0, 0);
        my $read = sub {   # (text, undef) or (undef, reason); trailing CR/LF dropped
            my $f = shift;
            return (undef, "is a directory") if -d $f;
            open my $fh, "<:raw", $f or return (undef, "$!");
            local $/; my $x = <$fh>; close $fh;
            $x = "" unless defined $x; $x =~ s/[\r\n]+\z//;
            return ($x, undef);
        };
        my @stack = ("");
        while (@stack) {
            my $rel = pop @stack;
            my $dir = $rel eq "" ? $t : "$t/$rel";
            my $dh;
            unless (opendir $dh, $dir) { print STDERR "cannot list $dir: $!\n"; $err = 1; next }
            my @names = grep { $_ ne "." && $_ ne ".." } readdir $dh;
            closedir $dh;
            for my $e (@names) {
                my $r = $rel eq "" ? $e : "$rel/$e";
                my $p = "$t/$r";
                unless (lstat $p) { print STDERR "cannot read $p: $!\n"; $err = 1; next }
                if (-l _) { $bad = 1; next }
                if (-d _) { push @stack, $r; next }
                if (! -f _) { $bad = 1; next }   # FIFO, socket, device
                next if lc($e) =~ /\.bak\./;
                $n++;
                my $cp = "$c/$r";
                if (! -f $cp) { $bad = 1; next }   # missing, a directory, a FIFO ...
                my ($x, $xwhy) = $read->($p);
                if (defined $xwhy) { print STDERR "cannot read $p: $xwhy\n"; $err = 1; next }
                my ($y, $ywhy) = $read->($cp);
                if (defined $ywhy) { print STDERR "cannot read $cp: $ywhy\n"; $err = 1; next }
                $bad = 1 if $x ne $y;
            }
        }
        exit 2 if $err;
        exit(($bad || $n == 0) ? 1 : 0);
    ' "$1" "$2" 2>&1) || rc=$?
    if [ "$rc" -gt 2 ]; then
        why="perl failed (exit $rc)${why:+: $why}"
        rc=2
    fi
    if [ -n "$why" ]; then
        _fanout_log_detail_lines "fanout_dir_matches" "$why"
    fi
    return "$rc"
}

# _fanout_list_dir DIR: the entry names of DIR, one per line, sorted in byte
# order (names holding a newline left out). Exit 1 with the reason on stdout
# when DIR cannot be listed. Used by fanout_harness_skills.
# Parity: Get-FanoutSortedNames in aitools-lib.ps1.
_fanout_list_dir() {
    perl -e '
        opendir my $d, $ARGV[0] or do { print "cannot list $ARGV[0]: $!\n"; exit 1 };
        print "$_\n" for sort grep { $_ ne "." && $_ ne ".." && !/\n/ } readdir $d;
    ' "$1"
}

# _fanout_is_binary FILE: exit 0 when FILE holds a NUL byte or is not valid
# UTF-8 (a shell variable cannot carry it: deploy_managed_file would corrupt
# it), 1 when it is text, 2 (reason on stdout) when it cannot be read.
# Parity: Test-FanoutBinary in aitools-lib.ps1.
_fanout_is_binary() {
    # Well-formed UTF-8 (RFC 3629), as .NET's throwing UTF8Encoding checks it:
    # a surrogate, a code point above U+10FFFF, an overlong or truncated
    # sequence and FE/FF bytes are not text; noncharacters (U+FFFE) are text.
    # (utf8::decode is lax; Encode's strict UTF-8 also rejects noncharacters.)
    # A \G loop walks the file one sequence per match: one anchored match with
    # (...)* hits perl's repeat limit on a large multi-byte file and fails
    # silently, which would call valid text binary (PR 124 review NB1).
    perl -e '
        open my $fh, "<:raw", $ARGV[0] or do { print "cannot read $ARGV[0]: $!\n"; exit 2 };
        local $/; my $c = <$fh>; close $fh;
        $c = "" unless defined $c;
        exit 0 if index($c, "\0") >= 0;
        pos($c) = 0;
        1 while $c =~ /\G(?:[\x00-\x7F]+|[\xC2-\xDF][\x80-\xBF]|\xE0[\xA0-\xBF][\x80-\xBF]|[\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}|\xED[\x80-\x9F][\x80-\xBF]|\xF0[\x90-\xBF][\x80-\xBF]{2}|[\xF1-\xF3][\x80-\xBF]{3}|\xF4[\x80-\x8F][\x80-\xBF]{2})/gc;
        my $end = pos($c);
        $end = 0 unless defined $end;
        exit($end == length($c) ? 1 : 0);
    ' "$1"
}

# _fanout_copy_binary SRC DEST ITEM [TOOL]: deploy a non-text file byte for byte
# (no review menu: a binary has no line diff; SOURCE wins, as on a
# non-interactive run). Equal bytes -> "verified". Otherwise an existing DEST is
# backed up (backup_file; no backup -> failed, nothing written), SRC is copied
# to a temp file beside DEST, compared, and moved over DEST. Sets
# MANAGED_FILE_RESULT to created / updated / verified / failed (failed: one
# write_error TOOL "Failed: <item>" with the reason; TOOL default the script's
# name). Honors DRY_RUN. Parity: Copy-FanoutBinary in aitools-lib.ps1.
_fanout_copy_binary() {
    local src="$1" dest="$2" item="$3" tool="${4:-}" tmp err
    MANAGED_FILE_RESULT="failed"
    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        MANAGED_FILE_RESULT="verified"
        return 0
    fi
    if [ "${DRY_RUN:-}" = "true" ]; then
        if [ -f "$dest" ]; then log "[DRY RUN] Would update: $item (binary) -> $(display_path "$dest")"
        else log "[DRY RUN] Would create: $item (binary) -> $(display_path "$dest")"; fi
        MANAGED_FILE_RESULT="verified"
        return 0
    fi
    if ! err=$(mkdir -p "$(dirname "$dest")" 2>&1); then
        write_error "$tool" "Failed: $item" "cannot create the directory of $(display_path "$dest"): ${err:-mkdir failed}"
        return 0
    fi
    local existed=false
    if [ -f "$dest" ]; then
        existed=true
        backup_file "$dest"
        if [ "$BACKUP_FILE_OK" != "true" ]; then
            write_error "$tool" "Failed: $item" "backup of $(display_path "$dest") failed -- nothing written"
            return 0
        fi
    fi
    tmp="$dest.aitools-tmp.$$"
    err=""
    if ! err=$(cp "$src" "$tmp" 2>&1) || ! cmp -s "$src" "$tmp"; then
        rm -f "$tmp"
        write_error "$tool" "Failed: $item" "cannot copy $(display_path "$src") (binary): ${err:-the copy differs}"
        return 0
    fi
    if ! err=$(mv -f "$tmp" "$dest" 2>&1) || ! cmp -s "$src" "$dest"; then
        rm -f "$tmp"
        write_error "$tool" "Failed: $item" "cannot write $(display_path "$dest") (binary): ${err:-the written file differs}"
        return 0
    fi
    if $existed; then
        log_ok "Updated: $item (binary, no review: source wins; backup kept) -> $(display_path "$dest")"
        MANAGED_FILE_RESULT="updated"
    else
        log_ok "Created: $item (binary) -> $(display_path "$dest")"
        MANAGED_FILE_RESULT="created"
    fi
}

# _fanout_skill_reserved NAME: exit 0 when NAME is a skills directory name
# Claude Code owns (synced, anthropic-skills*; compared case-insensitively):
# the fan-out never writes or removes it. Parity: Test-FanoutSkillReserved.
_fanout_skill_reserved() {
    case "$(lower_name "$1")" in
        synced|anthropic-skills*) return 0 ;;
    esac
    return 1
}

# _fanout_matches_ignoring_junk TARGET CAND: fanout_dir_matches on a temp copy
# of TARGET without OS junk files (.DS_Store, Thumbs.db, desktop.ini, any
# depth, case-insensitive), so a Finder or Explorer file never blocks a
# retired prune. Same exit codes; 2 also when the temp copy fails (detail log).
# Parity: Test-FanoutDirMatchesIgnoringJunk in aitools-lib.ps1.
_fanout_matches_ignoring_junk() {
    local t="$1" c="$2" tmpd rc=0 why=""
    if ! tmpd=$(mktemp -d); then
        log_detail "fanout: cannot create a temp directory to compare $(display_path "$t")"
        return 2
    fi
    if ! why=$(cp -R "$t" "$tmpd/t" 2>&1); then
        log_detail "fanout: cannot copy $(display_path "$t") to compare it: $why"
        _fanout_rm_tmp "$tmpd"
        return 2
    fi
    if ! why=$(perl -MFile::Find -e '
        find({ no_chdir => 1, wanted => sub {
            return if -l $_ || ! -f _;
            my ($b) = m{([^/]+)\z};
            if (lc($b) =~ /\A(?:\.ds_store|thumbs\.db|desktop\.ini)\z/) { unlink $_ or die "cannot remove $_: $!\n" }
        } }, $ARGV[0]);
    ' "$tmpd/t" 2>&1); then
        log_detail "fanout: cannot drop OS junk files from the copy of $(display_path "$t"): $why"
        _fanout_rm_tmp "$tmpd"
        return 2
    fi
    fanout_dir_matches "$tmpd/t" "$c" || rc=$?
    _fanout_rm_tmp "$tmpd"
    return "$rc"
}

# _fanout_rm_tmp DIR: remove a temp copy, read-only subdirectories included
# (cp -R keeps a 0555 directory 0555); a failure is a detail log line.
_fanout_rm_tmp() {
    local why=""
    if ! why=$( { chmod -R u+rwx "$1" && rm -rf "$1"; } 2>&1 ) || [ -e "$1" ]; then
        log_detail "fanout: cannot remove the temp copy $(display_path "$1"): ${why:-still present}"
    fi
}

# _fanout_prune_dest_backups DEST KEEP: remove all but the newest KEEP
# DEST.bak.<UTC>[-n] directories beside DEST (literal name match, never a glob;
# the same pattern backup_dir prunes). Failures are warnings.
_fanout_prune_dest_backups() {
    local dest="${1%/}" keep="$2" parent base old prc=0 list
    parent=$(dirname "$dest"); base=$(basename "$dest")
    list=$(perl -e '
        my ($parent, $base, $keep) = @ARGV;
        opendir my $dh, $parent or do { print "cannot list $parent: $!"; exit 1 };
        my @b = sort { $b cmp $a } grep {
            /\A\Q$base\E\.bak\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z(?:-[0-9]+)?\z/
                && ! -l "$parent/$_" && -d "$parent/$_"
        } readdir $dh;
        closedir $dh;
        print "$parent/$_\n" for @b[$keep .. $#b];
    ' "$parent" "$base" "$keep" 2>&1) || prc=$?
    if [ "$prc" -ne 0 ]; then
        log_warn "Could not prune old backups of $(display_path "$dest") -- $list"
        return 0
    fi
    while IFS= read -r old; do
        [ -n "$old" ] || continue
        if rm -rf "$old" && [ ! -e "$old" ]; then
            log "Pruned old backup: $(display_path "$old")"
        else
            log_warn "Could not prune old backup $(display_path "$old")"
        fi
    done <<< "$list"
}

# ---------------------------------------------------------------------------
# fanout_harness_skills TOOL DEST AITOOLS_REPO DOTPROFILE
# Skills fan-out (plans/skills-and-rules-fanout.md section 3.4): every skill
# directory in ~/.aitools/skills (deploy-harness fills it, first source wins,
# and writes the skills manifest) except the ones the manifest retires ->
# DEST/<name>/** through deploy_managed_file, one item per file
# ("<name>/<rel>"). Callers: setup-user-claude ("claude skills",
# ~/.claude/skills) and setup-user-cursor ("cursor skills", ~/.cursor/skills).
#   TOOL          summary tool name
#   DEST          the tool's skills directory (created when missing)
#   AITOOLS_REPO  the aitools git checkout (adopt targets of shared and aitools
#                 skills); "" = none (deploy/ copy, package payload, Cursor)
#   DOTPROFILE    the dotprofile (adopt target of dotprofile skills); "" = none
# Behaviour: names compared case-insensitively; hidden and *.bak.* entries
# skipped (also *.bak.* file names inside a skill); a top-level file ignored
# with a log line; a dangling symlink, a case-only duplicate name and an
# unexpected deploy result are failed items; the executable bit follows the
# harness copy. DEST/<name> that is a symlink or a file is never written
# (preserved, a warning, one ACTION), nor is any directory in DEST the fan-out
# did not deploy this run (third-party skills, the firecrawl symlinks). The
# copy of a retired skill is removed only when fanout_dir_matches says it holds
# the harness copy's files (~/.aitools/skills/<name> or a <name>.bak.* backup
# there), after a verified backup to DEST.bak.<UTC>/<name>/ beside DEST (not in
# DEST, where the tool would still load it as a skill); else kept, a warning
# and one ACTION; OS junk files (.DS_Store, Thumbs.db, desktop.ini) in the
# copy do not block it; the newest 5 DEST.bak.<UTC> directories are kept. A
# file with a NUL byte or invalid UTF-8 is copied byte for byte (no review
# menu, backup kept). The names synced and anthropic-skills* belong to Claude
# Code: a harness skill of that name is a failed item, never written, and is
# never removed from DEST. No ~/.aitools/skills: info log only, no row
# (setup-user-skills, the fallback, owns the TOOL rows then). DRY_RUN=true
# writes nothing. Records (reference/logging.md 8.3): each warning is one
# write_warn TOOL and each failed item one write_error TOOL with its reason, at
# the source; the tool's status is the tracker's OK record (counts, also of
# failed and skipped items); an ACTION is written once (_aitlib_action_once).
# Returns 0 (failures are counted in ERRORS for the caller's exit footer);
# [x]abort at a review exits 2 from the library.
# Parity: Invoke-HarnessSkillsFanout in aitools-lib.ps1.
# ---------------------------------------------------------------------------
fanout_harness_skills() {
    local _fs_tool="${1:-}" _fs_dest="${2:-}" _fs_repo="${3:-}" _fs_dp="${4:-}"
    local _fs_src="$HOME/.aitools/skills"
    local _fs_manifest="$_fs_src/.aitools-skills-manifest"
    local _fs_tab _fs_who _fs_shown _fs_err="" _fs_unlisted=false
    _fs_tab=$(printf '\t')
    if [ -z "$_fs_tool" ] || [ -z "$_fs_dest" ]; then
        write_error "${_fs_tool:-skills}" "fan-out not run" "fanout_harness_skills: TOOL and DEST are required (caller bug)"
        return 0
    fi
    _fs_dest="${_fs_dest%/}"
    case "$_fs_tool" in
        "claude skills") _fs_who="Claude Code" ;;
        "cursor skills") _fs_who="Cursor" ;;
        *)               _fs_who="$_fs_tool" ;;
    esac
    # DEST as the ACTION rows show it: ~/... under HOME, forward slashes
    _fs_shown="$_fs_dest"
    case "$_fs_dest" in "$HOME"/*) _fs_shown="~/${_fs_dest#"$HOME"/}" ;; esac

    if [ ! -d "$_fs_src" ]; then
        # No row: setup-user-skills (the fallback deployer, FO-6) owns this
        # tool's rows when ~/.aitools/skills does not exist (PR #125 review N2)
        log "No harness skills at $(display_path "$_fs_src") (deploy-harness has not run) -- skipping; setup-user-skills deploys skills"
        return 0
    fi
    local _fs_entries="" _fs_lrc=0
    if [ -r "$_fs_src" ] && [ -x "$_fs_src" ]; then
        _fs_entries=$(_fanout_list_dir "$_fs_src" 2>&1) || _fs_lrc=$?
    else
        _fs_lrc=1; _fs_entries="permission denied"
    fi
    if [ "$_fs_lrc" -ne 0 ]; then
        write_error "$_fs_tool" "cannot read harness skills" "cannot list $(display_path "$_fs_src"): $_fs_entries"
        return 0
    fi

    # Skills manifest: each skill's source (adopt target) and the retired names.
    # Without one every skill is fanned out, none is retired, adopt not offered.
    local _fs_m_ok=false _fs_m_failed=false _fs_m_out="" _fs_m_line _fs_m_rest _fs_m_name _fs_m_src
    local _fs_source_of="" _fs_retired="" _fs_retired_lc=""
    if [ ! -e "$_fs_manifest" ] && [ ! -L "$_fs_manifest" ]; then
        log "No skills manifest at $(display_path "$_fs_manifest") -- every skill fanned out, none retired, adopt not offered"
    elif ! _fs_m_out=$(read_harness_manifest "$_fs_manifest" skills 2>&1); then
        write_error "$_fs_tool" "cannot read skills manifest" "$(display_path "$_fs_manifest"): $_fs_m_out -- every skill fanned out, none retired"
        _fs_m_failed=true
    elif [ "$_fs_m_out" = "header-bad" ]; then
        write_action "$_fs_tool" "Skills manifest $(display_path "$_fs_manifest"): the first line is not \"$SKILLS_MANIFEST_HEADER\" -- every skill fanned out, none retired, adopt not offered -- Run aitools to rebuild ~/.aitools/skills and its manifest" "Run aitools to rebuild ~/.aitools/skills and its manifest"
    else
        local _fs_m_invalid=false
        _fs_m_ok=true
        while IFS= read -r _fs_m_line; do
            [ -n "$_fs_m_line" ] || continue
            case "$_fs_m_line" in
                "invalid$_fs_tab"*)
                    _fs_m_invalid=true
                    write_action "$_fs_tool" "Skills manifest $(display_path "$_fs_manifest"): line ignored: ${_fs_m_line#invalid"$_fs_tab"} -- Run aitools to rebuild ~/.aitools/skills and its manifest" "Run aitools to rebuild ~/.aitools/skills and its manifest" ;;
                "rule$_fs_tab"*)
                    _fs_m_rest="${_fs_m_line#rule"$_fs_tab"}"
                    _fs_m_name="${_fs_m_rest%%"$_fs_tab"*}"
                    _fs_m_src="${_fs_m_rest#*"$_fs_tab"}"
                    if [ "$_fs_m_src" = "retired" ]; then
                        _fs_retired="${_fs_retired}${_fs_m_name}
"
                        _fs_retired_lc="${_fs_retired_lc}$(lower_name "$_fs_m_name")
"
                    else
                        _fs_source_of="${_fs_source_of}$(lower_name "$_fs_m_name")${_fs_tab}${_fs_m_src}
"
                    fi ;;
            esac
        done <<< "$_fs_m_out"
    fi

    # Skill directories: every entry whose kind is "skill", not retired
    local _fs_ent _fs_skills="" _fs_broken=""
    while IFS= read -r _fs_ent; do
        [ -n "$_fs_ent" ] || continue
        case "$(skill_name_kind "$_fs_ent")" in
            skill) ;;
            *) continue ;;   # hidden (the manifest) and *.bak.* (deploy-harness backups)
        esac
        if in_list "$(lower_name "$_fs_ent")" "$_fs_retired_lc"; then
            log "Not fanned out: $_fs_ent (retired in the skills manifest)"
            continue
        fi
        if [ -L "$_fs_src/$_fs_ent" ] && [ ! -e "$_fs_src/$_fs_ent" ]; then
            _fs_broken="${_fs_broken}${_fs_ent}
"
            continue
        fi
        if [ ! -d "$_fs_src/$_fs_ent" ]; then
            log "Ignoring non-skill file in harness skills: $_fs_ent (only skill directories are fanned out)"
            continue
        fi
        _fs_skills="${_fs_skills}${_fs_ent}
"
    done <<< "$_fs_entries"

    if [ -z "$_fs_skills" ] && [ -z "$_fs_broken" ] && [ -z "$_fs_retired" ]; then
        log "No skills in $(display_path "$_fs_src") -- skipping"
        # An unreadable manifest already recorded this tool's error
        if [ "$_fs_m_failed" != "true" ]; then
            write_summary OK "$_fs_tool" "n/a (no harness skills)"
        fi
        return 0
    fi
    if [ "${DRY_RUN:-}" = "true" ]; then
        # The dry run predicts the real run's outcome for a DEST that is not a directory
        if [ -e "$_fs_dest" ] && [ ! -d "$_fs_dest" ]; then
            write_error "$_fs_tool" "cannot create skills dir" "$(display_path "$_fs_dest") (a file is in the way) [DRY RUN]"
            return 0
        fi
    else
        backup_dir "$_fs_dest"
        if ! _fs_err=$(mkdir -p "$_fs_dest" 2>&1) || [ ! -d "$_fs_dest" ]; then
            write_error "$_fs_tool" "cannot create skills dir" "$(display_path "$_fs_dest"): ${_fs_err:-not a directory}"
            return 0
        fi
    fi

    deploy_tracker_init
    local _fs_errs_before=$ERRORS
    if [ "$_fs_m_failed" = "true" ]; then
        deploy_tracker_record "failed" "$_fs_tool" ".aitools-skills-manifest"
    fi
    while IFS= read -r _fs_ent; do
        [ -n "$_fs_ent" ] || continue
        write_error "$_fs_tool" "Failed: $_fs_ent" "dangling symlink in $(display_path "$_fs_src")"
        deploy_tracker_record "failed" "$_fs_tool" "$_fs_ent"
    done <<< "$_fs_broken"

    # Per skill: claim the name, check DEST/<name>, list its files. The deploy
    # list holds "<name><TAB><rel>" lines.
    local _fs_owned_lc="" _fs_kept="" _fs_list="" _fs_lc _fs_files _fs_f _fs_rel
    while IFS= read -r _fs_ent; do
        [ -n "$_fs_ent" ] || continue
        _fs_lc=$(lower_name "$_fs_ent")
        # A name Claude Code owns in its skills directory: never written
        if _fanout_skill_reserved "$_fs_ent"; then
            write_error "$_fs_tool" "Not fanned out: $_fs_ent" "a reserved skills directory name (synced and anthropic-skills* belong to Claude Code) -- rename the harness skill"
            deploy_tracker_record "failed" "$_fs_tool" "$_fs_ent"
            continue
        fi
        # Two harness skills whose names differ only in case (possible on a
        # case-sensitive file system) map to one directory here: the first wins
        if in_list "$_fs_lc" "$_fs_owned_lc"; then
            write_error "$_fs_tool" "Skipped duplicate: $_fs_ent" "a harness skill whose name differs only in case was already fanned out"
            deploy_tracker_record "failed" "$_fs_tool" "$_fs_ent"
            continue
        fi
        _fs_owned_lc="${_fs_owned_lc}${_fs_lc}
"
        if [ -L "$_fs_dest/$_fs_ent" ] || { [ -e "$_fs_dest/$_fs_ent" ] && [ ! -d "$_fs_dest/$_fs_ent" ]; }; then
            write_warn "$_fs_tool" "Kept $_fs_ent: not a directory this fan-out owns ($(display_path "$_fs_dest/$_fs_ent") is a symlink or a file) -- the harness copy is not deployed; move it aside to get the aitools copy"
            deploy_tracker_record "preserved" "$_fs_tool" "$_fs_ent"
            _fs_kept="${_fs_kept:+$_fs_kept, }$_fs_ent"
            continue
        fi
        # Files under the skill: real directories walked (symlinked ones not
        # followed), regular files (or symlinks to one) listed, *.bak.* base
        # names skipped; "f<TAB>rel" or "x<TAB>rel" (not a file: ignored)
        _fs_lrc=0
        _fs_files=$(perl -e '
            my $root = shift;
            my (@out, @stack) = ();
            @stack = ("");
            while (@stack) {
                my $rel = pop @stack;
                my $dir = $rel eq "" ? $root : "$root/$rel";
                opendir my $dh, $dir or do { print "cannot list $dir: $!\n"; exit 1 };
                my @names = grep { $_ ne "." && $_ ne ".." } readdir $dh;
                closedir $dh;
                for my $e (@names) {
                    next if $e =~ /\n/;
                    my $r = $rel eq "" ? $e : "$rel/$e";
                    my $p = "$root/$r";
                    if (! -l $p && -d _) { push @stack, $r; next }
                    next if lc($e) =~ /\.bak\./;
                    push @out, (-f $p ? "f" : "x") . "\t$r";
                }
            }
            print "$_\n" for sort { substr($a, 2) cmp substr($b, 2) } @out;
        ' "$_fs_src/$_fs_ent" 2>&1) || _fs_lrc=$?
        if [ "$_fs_lrc" -ne 0 ]; then
            write_error "$_fs_tool" "Failed: $_fs_ent" "$_fs_files"
            deploy_tracker_record "failed" "$_fs_tool" "$_fs_ent"
            continue
        fi
        while IFS= read -r _fs_f; do
            [ -n "$_fs_f" ] || continue
            _fs_rel="${_fs_f#?"$_fs_tab"}"
            case "$_fs_f" in
                "f$_fs_tab"*) _fs_list="${_fs_list}${_fs_ent}${_fs_tab}${_fs_rel}
" ;;
                *) log "Ignoring non-file in harness skills: $_fs_ent/$_fs_rel" ;;
            esac
        done <<< "$_fs_files"
    done <<< "$_fs_skills"

    # Deploy loop. The list is read on fd 3: stdin stays the terminal, so the
    # review menu can prompt (a loop fed on stdin never prompts). [x]abort exits
    # 2 from the library here: no TOOL row is written.
    local _fs_line _fs_name _fs_item _fs_dfile _fs_sfile _fs_msrc _fs_abase _fs_adopt _fs_content _fs_res
    local _fs_deployed=""   # deployed file paths, one per line (validation)
    while IFS= read -r _fs_line <&3; do
        [ -n "$_fs_line" ] || continue
        _fs_name="${_fs_line%%"$_fs_tab"*}"
        _fs_rel="${_fs_line#*"$_fs_tab"}"
        _fs_item="$_fs_name/$_fs_rel"
        _fs_sfile="$_fs_src/$_fs_name/$_fs_rel"
        _fs_dfile="$_fs_dest/$_fs_name/$_fs_rel"
        _fs_msrc=""
        _fs_adopt=""
        if [ "$_fs_m_ok" = "true" ]; then
            _fs_lc=$(lower_name "$_fs_name")
            while IFS= read -r _fs_m_line; do
                case "$_fs_m_line" in
                    "$_fs_lc$_fs_tab"*) _fs_msrc="${_fs_m_line#*"$_fs_tab"}"; break ;;
                esac
            done <<< "$_fs_source_of"
            _fs_abase=""
            case "$_fs_msrc" in
                shared)     if [ -n "$_fs_repo" ]; then _fs_abase="$_fs_repo/shared/skills"; fi ;;
                aitools)    if [ -n "$_fs_repo" ]; then _fs_abase="$_fs_repo/.claude/skills"; fi ;;
                dotprofile) if [ -n "$_fs_dp" ]; then _fs_abase="$_fs_dp/claude/skills"; fi ;;
            esac
            if [ -n "$_fs_abase" ] && [ -f "$_fs_abase/$_fs_name/$_fs_rel" ]; then
                _fs_adopt="$_fs_abase/$_fs_name/$_fs_rel"
            fi
        fi
        log_detail "$_fs_tool: $_fs_item source=${_fs_msrc:-unknown} adopt=${_fs_adopt:-none}"
        # A file with a NUL byte or invalid UTF-8 is copied byte for byte (a
        # shell variable would corrupt it); text goes through the review menu
        _fs_lrc=0
        _fs_content=$(_fanout_is_binary "$_fs_sfile") || _fs_lrc=$?
        if [ "$_fs_lrc" -ne 0 ] && [ "$_fs_lrc" -ne 1 ]; then
            write_error "$_fs_tool" "Cannot read harness skill file $(display_path "$_fs_sfile")" "${_fs_content:-perl failed (exit $_fs_lrc)}"
            deploy_tracker_record "failed" "$_fs_tool" "$_fs_item"
            continue
        fi
        if [ "$_fs_lrc" -eq 0 ]; then
            _fanout_copy_binary "$_fs_sfile" "$_fs_dfile" "$_fs_item" "$_fs_tool"
        else
            _fs_content=""
            # 2>/dev/null: the failure is checked here and its reason logged below
            # (not left as a raw console line)
            if ! _fs_content=$(cat "$_fs_sfile" 2>/dev/null); then
                # Read again for the reason only (stdout discarded, stderr
                # captured); "|| :" because it fails by definition here -- the
                # empty case falls back to "cat failed" below
                _fs_err=$(cat "$_fs_sfile" 2>&1 >/dev/null) || :
                write_error "$_fs_tool" "Cannot read harness skill file $(display_path "$_fs_sfile")" "${_fs_err:-cat failed}"
                deploy_tracker_record "failed" "$_fs_tool" "$_fs_item"
                continue
            fi
            deploy_managed_file "$_fs_content" "$_fs_dfile" "$_fs_tool" "$_fs_item" "$_fs_adopt"
        fi
        _fs_res="$MANAGED_FILE_RESULT"
        case "$_fs_res" in
            created|updated|verified|"accept & adopt"|skipped|failed) ;;
            *)
                write_error "$_fs_tool" "Unexpected deploy result for $_fs_item" "$_fs_res"
                _fs_res="failed" ;;
        esac
        # The executable bit follows the harness copy (a skill may ship scripts)
        if [ "${DRY_RUN:-}" != "true" ] && [ -f "$_fs_dfile" ]; then
            case "$_fs_res" in
                created|updated|verified|"accept & adopt")
                    if [ -x "$_fs_sfile" ] && [ ! -x "$_fs_dfile" ]; then
                        if ! _fs_err=$(chmod +x "$_fs_dfile" 2>&1); then
                            write_error "$_fs_tool" "Failed: $_fs_item" "cannot set the executable bit on $(display_path "$_fs_dfile"): ${_fs_err:-chmod failed}"
                            _fs_res="failed"
                        fi
                    elif [ ! -x "$_fs_sfile" ] && [ -x "$_fs_dfile" ]; then
                        if ! _fs_err=$(chmod a-x "$_fs_dfile" 2>&1); then
                            write_error "$_fs_tool" "Failed: $_fs_item" "cannot clear the executable bit on $(display_path "$_fs_dfile"): ${_fs_err:-chmod failed}"
                            _fs_res="failed"
                        fi
                    fi ;;
            esac
        fi
        _fs_deployed="${_fs_deployed}${_fs_dfile}
"
        deploy_tracker_record "$_fs_res" "$_fs_tool" "$_fs_item"
    done 3<<< "$_fs_list"
    if [ -n "$_fs_kept" ]; then
        _aitlib_action_once "$_fs_who skills in $_fs_shown not updated (a symlink or a file, not a directory the fan-out owns): $_fs_kept -- move them aside to get the aitools copy"
    fi

    # Retired skills: the copy in DEST is backed up and removed when it holds
    # this fan-out's files -- those of the harness copy or of a backup
    # deploy-harness made when it retired the skill. Any other directory of that
    # name may be the user's own: kept, with a warning.
    local _fs_rm _fs_rm_lc _fs_rm_path _fs_rm_dir _fs_rm_why _fs_cand _fs_rc _fs_rm_kept=""
    local _fs_bak_root="" _fs_ts _fs_n _fs_dlist="" _fs_rm_seen_lc=""
    if [ -n "$_fs_retired" ] && [ -d "$_fs_dest" ]; then
        if ! _fs_dlist=$(_fanout_list_dir "$_fs_dest" 2>&1); then
            write_warn "$_fs_tool" "Cannot list $(display_path "$_fs_dest") for the retired skills -- $_fs_dlist -- check its permissions"
            _fs_dlist=""
            _fs_unlisted=true
        fi
    fi
    while IFS= read -r _fs_rm; do
        [ -n "$_fs_rm" ] || continue
        _fs_rm_lc=$(lower_name "$_fs_rm")
        # Deployed this run under a name that differs only in case
        if in_list "$_fs_rm_lc" "$_fs_owned_lc"; then continue; fi
        # A name Claude Code owns is never removed
        if _fanout_skill_reserved "$_fs_rm"; then continue; fi
        # The copy in DEST, found case-insensitively; a real directory only
        _fs_rm_path=""
        while IFS= read -r _fs_ent; do
            [ -n "$_fs_ent" ] || continue
            if [ "$(lower_name "$_fs_ent")" = "$_fs_rm_lc" ] && [ ! -L "$_fs_dest/$_fs_ent" ] && [ -d "$_fs_dest/$_fs_ent" ]; then
                _fs_rm_path="$_fs_dest/$_fs_ent"
                break
            fi
        done <<< "$_fs_dlist"
        [ -n "$_fs_rm_path" ] || continue
        _fs_rm_dir=$(basename "$_fs_rm_path")
        # Reported here (kept, failed or removed): not counted again as preserved
        _fs_rm_seen_lc="${_fs_rm_seen_lc}$(lower_name "$_fs_rm_dir")
"
        _fs_rm_why=""
        # "$_fs_src/$_fs_rm".bak.*: the quoted part is literal ([ ] * ? work)
        for _fs_cand in "$_fs_src/$_fs_rm" "$_fs_src/$_fs_rm".bak.*; do
            [ -d "$_fs_cand" ] || continue
            _fs_rc=0
            # OS junk files (.DS_Store, Thumbs.db, desktop.ini) in the copy do not count
            _fanout_matches_ignoring_junk "$_fs_rm_path" "$_fs_cand" || _fs_rc=$?
            if [ "$_fs_rc" -eq 0 ]; then
                _fs_rm_why="same files as $(basename "$_fs_cand")"
                break
            fi
            if [ "$_fs_rc" -ne 1 ]; then
                write_warn "$_fs_tool" "Cannot compare $(display_path "$_fs_rm_path") with $(display_path "$_fs_cand")"
            fi
        done
        if [ -z "$_fs_rm_why" ]; then
            write_warn "$_fs_tool" "Kept $_fs_rm_dir: the skills manifest retires $_fs_rm, but this directory matches no harness copy (it may be your own) -- $_fs_who still loads it; delete it if it is an old fan-out copy"
            _fs_rm_kept="${_fs_rm_kept:+$_fs_rm_kept, }$_fs_rm_dir"
            continue
        fi
        if [ "${DRY_RUN:-}" = "true" ]; then
            log "[DRY RUN] Would back up and remove $_fs_rm_dir (retired skill; $_fs_rm_why)"
            continue
        fi
        # Backup beside DEST (DEST.bak.<UTC>/<name>), one directory per run
        if [ -z "$_fs_bak_root" ]; then
            _fs_ts=$(date -u +%Y-%m-%dT%H%M%SZ)
            _fs_bak_root="${_fs_dest}.bak.${_fs_ts}"
            _fs_n=0
            while [ -e "$_fs_bak_root" ] || [ -L "$_fs_bak_root" ]; do
                _fs_n=$((_fs_n + 1))
                _fs_bak_root="${_fs_dest}.bak.${_fs_ts}-$_fs_n"
            done
            if ! _fs_err=$(mkdir -p "$_fs_bak_root" 2>&1); then
                write_warn "$_fs_tool" "Cannot create the backup directory $(display_path "$_fs_bak_root"): ${_fs_err:-mkdir failed}"
            else
                # Keep the newest 5 DEST.bak.<UTC> directories (this one included)
                _fanout_prune_dest_backups "$_fs_dest" 5
            fi
        fi
        _fs_rc=1
        _fs_err="no backup directory"
        if [ -d "$_fs_bak_root" ] && [ ! -e "$_fs_bak_root/$_fs_rm_dir" ]; then
            if _fs_err=$(cp -R "$_fs_rm_path" "$_fs_bak_root/$_fs_rm_dir" 2>&1); then
                _fs_rc=0
                _fs_err="the copy differs"
                fanout_dir_matches "$_fs_rm_path" "$_fs_bak_root/$_fs_rm_dir" || _fs_rc=$?
            fi
        fi
        if [ "$_fs_rc" -ne 0 ]; then
            write_error "$_fs_tool" "Not removed: $_fs_rm_dir (retired skill)" "backup to $(display_path "$_fs_bak_root") failed: ${_fs_err:-cp failed}"
            deploy_tracker_record "failed" "$_fs_tool" "$_fs_rm_dir"
            continue
        fi
        _fs_err=""
        if ! _fs_err=$(rm -rf "$_fs_rm_path" 2>&1) || [ -e "$_fs_rm_path" ] || [ -L "$_fs_rm_path" ]; then
            write_error "$_fs_tool" "Cannot remove $(display_path "$_fs_rm_path") (retired skill; it may be partly removed; backup in $(display_path "$_fs_bak_root/$_fs_rm_dir"))" "$(printf '%s' "${_fs_err:-still present}" | perl -0777 -pe 's/\s*\n\s*/; /g')"
            deploy_tracker_record "failed" "$_fs_tool" "$_fs_rm_dir"
            continue
        fi
        log "Removed $_fs_rm_dir (retired skill; $_fs_rm_why; backup in $(display_path "$_fs_bak_root"))"
        deploy_tracker_record "removed" "$_fs_tool" "$_fs_rm_dir"
    done <<< "$_fs_retired"
    if [ -n "$_fs_rm_kept" ]; then
        _aitlib_action_once "$_fs_who still loads retired skills in $_fs_shown: $_fs_rm_kept -- delete them unless you wrote them"
    fi

    if [ "${DRY_RUN:-}" = "true" ]; then
        if [ "$_fs_unlisted" = "true" ]; then
            _aitlib_action_once "$_fs_who skills in $_fs_shown cannot be listed: retired skills not checked -- check its permissions"
        fi
        # Each failed item was recorded where it failed: the status only
        if [ "$_DT_FAILED" -gt 0 ]; then
            write_summary OK "$_fs_tool" "dry run (no files written), $_DT_FAILED failed"
        else
            write_summary OK "$_fs_tool" "dry run (no files written)"
        fi
        return 0
    fi

    # Preserved: skills in DEST this fan-out did not deploy this run
    # (directories and symlinks; never touched)
    if ! _fs_dlist=$(_fanout_list_dir "$_fs_dest" 2>&1); then
        write_warn "$_fs_tool" "Cannot list $(display_path "$_fs_dest") for the preserved report -- $_fs_dlist -- check its permissions"
        _fs_dlist=""
        _fs_unlisted=true
    fi
    if [ "$_fs_unlisted" = "true" ]; then
        _aitlib_action_once "$_fs_who skills in $_fs_shown cannot be listed: retired skills not checked and other skills not counted -- check its permissions"
    fi
    while IFS= read -r _fs_ent; do
        [ -n "$_fs_ent" ] || continue
        case "$(skill_name_kind "$_fs_ent")" in skill) ;; *) continue ;; esac
        if [ ! -d "$_fs_dest/$_fs_ent" ] && [ ! -L "$_fs_dest/$_fs_ent" ]; then continue; fi
        if in_list "$(lower_name "$_fs_ent")" "$_fs_rm_seen_lc"; then continue; fi
        if ! in_list "$(lower_name "$_fs_ent")" "$_fs_owned_lc"; then
            log "Preserved unmanaged skill: $_fs_ent"
            deploy_tracker_record "preserved" "$_fs_tool" "$_fs_ent"
        fi
    done <<< "$_fs_dlist"

    # Post-write validation: each deployed file is non-empty (a file whose
    # deploy failed is already reported; the library left it as it was)
    while IFS= read -r _fs_f; do
        [ -n "$_fs_f" ] || continue
        if [ -f "$_fs_f" ] && [ ! -s "$_fs_f" ]; then
            write_error "$_fs_tool" "Validation failed" "$(display_path "$_fs_f") is empty after deploy"
        fi
    done <<< "$_fs_deployed"

    # The tool's status (OK record); every failed item and failed validation
    # was recorded as its own error above, so the panel shows the tool in red
    local _fs_pres="$_DT_PRESERVED preserved"
    if [ "$_fs_unlisted" = "true" ]; then _fs_pres="preserved count unknown (cannot list)"; fi
    deploy_tracker_summary "$_fs_tool"
    if [ "$_DT_FAILED" -eq 0 ] && [ "$ERRORS" -eq "$_fs_errs_before" ]; then
        log_ok "Skills ($_fs_tool): $DEPLOY_TRACKER_TEXT, $_fs_pres in $(display_path "$_fs_dest")"
    else
        log "Skills ($_fs_tool): $DEPLOY_TRACKER_TEXT, $_fs_pres in $(display_path "$_fs_dest")"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# _json_field_detail WHAT DETAIL LOCAL_LABEL SOURCE_LABEL: the element lines of
# an array field under its review header (DETAIL: lines joined by \x1f), one
# per line, colour-coded when _review_colour (red "-" only in LOCAL, green "+"
# only in SOURCE, yellow "~" changed), after a legend. Each line also goes to
# deploy.log (detail). Parity: Write-JsonFieldDetail in aitools-lib.ps1.
# ---------------------------------------------------------------------------
_json_field_detail() {
    local what="$1" rest="$2" llabel="$3" slabel="$4" dl colour=0 us=$'\x1f'
    if _review_colour; then colour=1; fi
    if [ "$colour" = "1" ]; then
        printf '  \033[31mred -\033[0m = only in %s   \033[32mgreen +\033[0m = only in %s   \033[33myellow ~\033[0m = changed\n' "$llabel" "$slabel" > /dev/tty
    else
        printf '  red - = only in %s   green + = only in %s   yellow ~ = changed\n' "$llabel" "$slabel" > /dev/tty
    fi
    while :; do
        dl="${rest%%"$us"*}"
        log_detail "review $what: $dl"
        case "$colour$dl" in
            1-*) printf '  \033[31m%s\033[0m\n' "$dl" ;;
            1+*) printf '  \033[32m%s\033[0m\n' "$dl" ;;
            1~*) printf '  \033[33m%s\033[0m\n' "$dl" ;;
            *)   printf '  %s\n' "$dl" ;;
        esac > /dev/tty
        if [ "$rest" = "$dl" ]; then break; fi
        rest="${rest#*"$us"}"
    done
}

# ---------------------------------------------------------------------------
# Granular per-leaf review prompt for JSON settings sync (sync_managed_json)
# and the JSON field review (review_json_fields).
# One prompt per divergent setting/rule. overwrite/adopt/skip are per-leaf;
# abort (x) is global and exits the run (code 2).
#
# Args:
#   $1 = leaf display name (e.g. "theme" or "permissions.deny MCP(vercel)")
#   $2 = current value display (the local file's side)
#   $3 = proposed value display (the source side)
#   $4 = source label (e.g. "profile.json")
#   $5 = adopt-allowed flag ("1" to offer adopt, else hidden)
#   $6 = local label (default "settings.json")
#   $7 = overwrite-allowed flag (default "1"; "0" for a field only in the
#        local file: no [o]verwrite, and the default answer is skip)
#   $8 = file label: names the file in the header ("" = the leaf alone)
#   $9 = detail: element lines for an array field, joined by \x1f (the
#        plan's detail column, review_json_fields); shown colour-coded instead
#        of the two value lines ("" = show the two value lines)
#   $10 = TOOL, optional: the record name of its warning (the caller's tool:
#        review_json_fields, sync_managed_json); default the script's name
#
# Sets JSON_FIELD_REVIEW_RESULT to "overwrite", "adopt", or "skip".
# --force / AITOOLS_FORCE / non-interactive -> "overwrite" (source wins), or
# "skip" when overwrite is not allowed. A non-interactive overwrite replaces
# the local value without the user's choice: one write_warn TOOL per field
# ("Divergence in <field> -- overwriting from <source> (non-interactive)",
# reference/logging.md 8.3 "What is a warning"), as prompt_diff_review does for
# a text file. Under --force it is info (the user asked for it); a field only in
# the local file is kept (skip) and logged at info.
# ---------------------------------------------------------------------------
JSON_FIELD_REVIEW_RESULT=""
prompt_json_field_review() {
    local leaf="$1" current="$2" proposed="$3" source_label="${4:-profile.json}" adopt_allowed="${5:-1}"
    local local_label="${6:-settings.json}" overwrite_allowed="${7:-1}" file_label="${8:-}" detail="${9:-}"
    local tool="${10:-}"
    local default_choice="overwrite" default_desc="overwriting from $source_label" what="$leaf"
    if [ "$overwrite_allowed" != "1" ]; then
        default_choice="skip"; default_desc="skipping (only in $local_label)"
    fi
    if [ -n "$file_label" ]; then what="$file_label: $leaf"; fi

    JSON_FIELD_REVIEW_RESULT="$default_choice"

    # --force / AITOOLS_FORCE: source wins
    if [ "${AITOOLS_FORCE:-}" = "1" ] || [ "${FORCE:-}" = "true" ]; then
        log "Divergence in $what -- $default_desc (--force)"
        return 0
    fi
    # Non-interactive: source wins. Overwriting the local value without the
    # user's choice is a warning (8.3); keeping a local-only field is not.
    if ! tty_interactive; then
        if [ "$default_choice" = "overwrite" ]; then
            write_warn "$tool" "Divergence in $what -- $default_desc (non-interactive)"
        else
            log "Divergence in $what -- $default_desc (non-interactive)"
        fi
        return 0
    fi

    printf '\n\033[33m[REVIEW]\033[0m %s differs from %s.\n' "$what" "$source_label" > /dev/tty
    if [ -n "$detail" ]; then
        _json_field_detail "$what" "$detail" "$local_label" "$source_label"
    else
        printf '  %s : %s\n' "$local_label" "$current" > /dev/tty
        printf '  %s : %s\n' "$source_label" "$proposed" > /dev/tty
    fi
    printf '\n' > /dev/tty
    if [ "$overwrite_allowed" = "1" ]; then
        printf '  [o]verwrite : %s value -> %s\n' "$source_label" "$local_label" > /dev/tty
    fi
    if [ "$adopt_allowed" = "1" ]; then
        printf '  [a]dopt     : keep %s value -> write to %s\n' "$local_label" "$source_label" > /dev/tty
    fi
    printf '  [s]kip      : leave this setting unchanged\n' > /dev/tty
    printf '  [x]abort    : stop the run\n' > /dev/tty

    # The offered letters, from the same flags as the menu lines. Only an
    # offered letter counts; an empty line or anything else asks again
    # (read_menu_choice); EOF = the default (o, or s without overwrite).
    local valid="" default_letter="o" choice=""
    if [ "$overwrite_allowed" = "1" ]; then valid="o "; else default_letter="s"; fi
    if [ "$adopt_allowed" = "1" ]; then valid="${valid}a "; fi
    valid="${valid}s x"
    read_menu_choice choice "$valid" "$default_letter" "$default_desc" "json $what" \
        "  choice [$(printf '%s' "$valid" | tr ' ' '/')]: "
    case "$choice" in
        o)  printf '  >> overwritten from %s\n' "$source_label" > /dev/tty
            JSON_FIELD_REVIEW_RESULT="overwrite" ;;
        a)  printf '  >> adopted: %s value kept -> %s\n' "$local_label" "$source_label" > /dev/tty
            JSON_FIELD_REVIEW_RESULT="adopt" ;;
        x)  _managed_abort ;;
        *)  # s (read_menu_choice returns only an offered letter)
            printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
            JSON_FIELD_REVIEW_RESULT="skip" ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# Generic settings.json <-> profile.json sync engine.
#
# profile.json (under a sub-path, e.g. "claude.settings") is the source of
# truth for the live JSON file (settings.json), EXCLUDING harness-managed keys
# (e.g. "hooks"). For every managed leaf (arbitrary keys; permissions handled
# per-rule across allow/ask/deny):
#   - in live, not in profile  -> auto-adopt into profile (no prompt)
#   - equal                    -> no-op
#   - differ / live-missing    -> granular per-leaf prompt (prompt_json_field_review)
# Deprecated permission rules are stripped from live before the scan so they
# are never adopted. Writes preserve key order (no sort). Both files are backed
# up before write and validated after.
#
# Args:
#   $1 = live JSON file (e.g. ~/.claude/settings.json)
#   $2 = profile JSON file (dotprofile profile.json)
#   $3 = profile sub-path holding the mirror, dot form (e.g. "claude.settings")
#   $4 = exclude keys, comma-separated (default "hooks")
#   $5 = deprecated permission rules, comma-separated (default "")
#   $6 = TOOL, optional: the record name of its warnings and errors (e.g.
#        "claude settings"); default the script's name
#
# Sets SYNC_MANAGED_JSON_RESULT to "unchanged", "updated", or "created".
# A leaf the user skipped at its prompt is left differing: one write_warn TOOL
# per skipped leaf ("Skipped: <leaf> in <file> (differs from profile.json;
# reviewed again next run)"); a leaf of an existing live file overwritten in a
# non-interactive run is one write_warn TOOL (prompt_json_field_review; info
# under --force; no warning when the live file is created). A failure is one
# write_error TOOL "settings sync
# failed" with its reason ("plan pass: ...", "apply pass: ...", "<file> is not
# valid JSON after write -- ..."), and returns 1. Parity: Sync-ManagedJson.
# Requires node. Honors DRY_RUN (plan only, no writes). Exits 2 on user abort.
# ---------------------------------------------------------------------------
SYNC_MANAGED_JSON_RESULT=""
sync_managed_json() {
    local live_file="$1" profile_file="$2" subpath="$3"
    local exclude_keys="${4:-hooks}" deprecated_rules="${5:-}" tool="${6:-}"

    SYNC_MANAGED_JSON_RESULT="unchanged"

    if ! command -v node >/dev/null 2>&1; then
        write_error "$tool" "settings sync not run" "node is required for the JSON sync"
        return 1
    fi

    local nodescript="" plan_json="" decisions_tsv="" choices_tsv="" applyerr="" t
    for t in nodescript plan_json decisions_tsv choices_tsv applyerr; do
        if ! printf -v "$t" '%s' "$(mktemp 2>&1)" || [ ! -f "${!t}" ]; then
            write_error "$tool" "settings sync failed" "cannot create a temp file: ${!t}"
            rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr" 2>/dev/null || true  # best-effort cleanup: the failure is already recorded
            return 1
        fi
    done

    cat > "$nodescript" <<'SYNC_NODE_EOF'
const fs = require('fs');
const mode = process.argv[2];
const PERM_CATS = ['allow', 'ask', 'deny'];

function readJson(p) {
    try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
    catch (e) { if (e.code === 'ENOENT') return null; throw e; }
}
function jeq(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
function getSub(obj, parts) { let o = obj; for (const k of parts) { if (o == null || typeof o !== 'object') return undefined; o = o[k]; } return o; }
function ensureSub(obj, parts) { let o = obj; for (const k of parts) { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; o = o[k]; } return o; }
function setPath(obj, parts, val) { let o = obj; for (let i = 0; i < parts.length - 1; i++) { if (o[parts[i]] == null || typeof o[parts[i]] !== 'object') o[parts[i]] = {}; o = o[parts[i]]; } o[parts[parts.length - 1]] = val; }
function delPath(obj, parts) { let o = obj; for (let i = 0; i < parts.length - 1; i++) { if (o[parts[i]] == null) return; o = o[parts[i]]; } delete o[parts[parts.length - 1]]; }
function disp(v) { return v === undefined ? '(not in settings.json)' : JSON.stringify(v); }

function buildPlan(live, profile, subParts, excludeKeys, deprecated) {
    live = live || {};
    const mirror = getSub(profile, subParts) || {};
    const deprecatedRemoved = [];
    if (live.permissions) {
        for (const cat of PERM_CATS) {
            if (Array.isArray(live.permissions[cat])) {
                for (const r of live.permissions[cat]) if (deprecated.includes(r)) deprecatedRemoved.push({ cat, rule: r });
                live.permissions[cat] = live.permissions[cat].filter(r => !deprecated.includes(r));
            }
        }
    }
    const decisions = {}; const autoAdopts = [];
    const keys = new Set([...Object.keys(live), ...Object.keys(mirror)]);
    for (const k of excludeKeys) keys.delete(k);
    for (const k of keys) {
        if (k === 'permissions') {
            const lp = live.permissions || {}; const mp = mirror.permissions || {};
            const lHas = Object.prototype.hasOwnProperty.call(lp, 'defaultMode');
            const mHas = Object.prototype.hasOwnProperty.call(mp, 'defaultMode');
            if (lHas && !mHas) autoAdopts.push({ kind: 'scalar', path: ['permissions', 'defaultMode'], value: lp.defaultMode });
            else if (mHas && !lHas) decisions['permissions.defaultMode'] = { type: 'permScalar', path: ['permissions', 'defaultMode'], kind: 'live-missing', currentDisplay: disp(undefined), proposedDisplay: disp(mp.defaultMode), profileValue: mp.defaultMode };
            else if (lHas && mHas && !jeq(lp.defaultMode, mp.defaultMode)) decisions['permissions.defaultMode'] = { type: 'permScalar', path: ['permissions', 'defaultMode'], kind: 'differ', currentDisplay: disp(lp.defaultMode), proposedDisplay: disp(mp.defaultMode), liveValue: lp.defaultMode, profileValue: mp.defaultMode };
            for (const cat of PERM_CATS) {
                const lr = Array.isArray(lp[cat]) ? lp[cat] : [];
                const mr = Array.isArray(mp[cat]) ? mp[cat] : [];
                for (const rule of new Set([...lr, ...mr])) {
                    const inL = lr.includes(rule), inM = mr.includes(rule);
                    if (inL && !inM) autoAdopts.push({ kind: 'permRule', cat, rule });
                    else if (inM && !inL) decisions['permissions.' + cat + ' ' + rule] = { type: 'permRule', cat, rule, kind: 'live-missing', currentDisplay: '(not in settings.json)', proposedDisplay: 'rule present in profile.json' };
                }
            }
        } else {
            const lHas = Object.prototype.hasOwnProperty.call(live, k);
            const mHas = Object.prototype.hasOwnProperty.call(mirror, k);
            if (lHas && !mHas) autoAdopts.push({ kind: 'scalar', path: [k], value: live[k] });
            else if (mHas && !lHas) decisions[k] = { type: 'scalar', path: [k], kind: 'live-missing', currentDisplay: disp(undefined), proposedDisplay: disp(mirror[k]), profileValue: mirror[k] };
            else if (lHas && mHas && !jeq(live[k], mirror[k])) decisions[k] = { type: 'scalar', path: [k], kind: 'differ', currentDisplay: disp(live[k]), proposedDisplay: disp(mirror[k]), liveValue: live[k], profileValue: mirror[k] };
        }
    }
    return { decisions, autoAdopts, deprecatedRemoved };
}

const subParts = process.argv[5] ? process.argv[5].split('.') : [];
const excludeKeys = process.argv[6] ? process.argv[6].split(',').filter(Boolean) : [];
const deprecated = process.argv[7] ? process.argv[7].split(',').filter(Boolean) : [];

if (mode === 'plan') {
    const livePath = process.argv[3], profilePath = process.argv[4], planOut = process.argv[8];
    const live = readJson(livePath) || {};
    const profile = readJson(profilePath) || {};
    const plan = buildPlan(live, profile, subParts, excludeKeys, deprecated);
    fs.writeFileSync(planOut, JSON.stringify(plan));
    // TSV for the bash prompt loop: id \t kind \t currentDisplay \t proposedDisplay \t adoptAllowed
    const lines = [];
    for (const [id, d] of Object.entries(plan.decisions)) {
        lines.push([id, d.kind, d.currentDisplay, d.proposedDisplay, '1'].join('\t'));
    }
    // Trailing newline required: the bash `while read` loop drops a final line
    // that lacks one, silently losing the last decision.
    process.stdout.write(lines.length ? lines.join('\n') + '\n' : '');
    // counts to stderr for logging
    process.stderr.write('adopts=' + plan.autoAdopts.length + ' deprecated=' + plan.deprecatedRemoved.length + ' decisions=' + Object.keys(plan.decisions).length + '\n');
} else if (mode === 'apply') {
    const livePath = process.argv[3], profilePath = process.argv[4];
    const planPath = process.argv[8], choicesPath = process.argv[9];
    const plan = readJson(planPath);
    const live = readJson(livePath) || {};
    const profile = readJson(profilePath) || {};
    const mirror = ensureSub(profile, subParts);
    const origLive = JSON.stringify(live), origProfile = JSON.stringify(profile);

    // deprecated removals (already stripped in plan's view; re-apply to actual live)
    for (const d of plan.deprecatedRemoved) {
        if (live.permissions && Array.isArray(live.permissions[d.cat])) {
            live.permissions[d.cat] = live.permissions[d.cat].filter(r => r !== d.rule);
        }
    }
    // auto-adopts -> mirror
    for (const a of plan.autoAdopts) {
        if (a.kind === 'scalar') setPath(mirror, a.path, a.value);
        else if (a.kind === 'permRule') {
            if (!mirror.permissions || typeof mirror.permissions !== 'object') mirror.permissions = {};
            const arr = Array.isArray(mirror.permissions[a.cat]) ? mirror.permissions[a.cat] : [];
            if (!arr.includes(a.rule)) arr.push(a.rule);
            mirror.permissions[a.cat] = arr;
        }
    }
    // decisions
    const choices = {};
    try {
        const raw = fs.readFileSync(choicesPath, 'utf8');
        for (const ln of raw.split('\n')) { if (!ln) continue; const i = ln.indexOf('\t'); if (i < 0) continue; choices[ln.slice(0, i)] = ln.slice(i + 1); }
    } catch (e) { if (e.code !== 'ENOENT') throw e; }
    for (const [id, action] of Object.entries(choices)) {
        const d = plan.decisions[id]; if (!d || action === 'skip') continue;
        if (d.type === 'scalar' || d.type === 'permScalar') {
            if (action === 'overwrite') setPath(live, d.path, d.profileValue);
            else if (action === 'adopt') { if (d.kind === 'live-missing') delPath(mirror, d.path); else setPath(mirror, d.path, d.liveValue); }
        } else if (d.type === 'permRule') {
            if (action === 'overwrite') {
                if (!live.permissions || typeof live.permissions !== 'object') live.permissions = {};
                const arr = Array.isArray(live.permissions[d.cat]) ? live.permissions[d.cat] : [];
                if (!arr.includes(d.rule)) arr.push(d.rule);
                live.permissions[d.cat] = arr;
            } else if (action === 'adopt') {
                if (mirror.permissions && Array.isArray(mirror.permissions[d.cat])) mirror.permissions[d.cat] = mirror.permissions[d.cat].filter(r => r !== d.rule);
            }
        }
    }
    // drop empty permission arrays in live for cleanliness
    if (live.permissions && typeof live.permissions === 'object') {
        for (const cat of PERM_CATS) if (Array.isArray(live.permissions[cat]) && live.permissions[cat].length === 0) delete live.permissions[cat];
    }
    const liveChanged = JSON.stringify(live) !== origLive;
    const profileChanged = JSON.stringify(profile) !== origProfile;
    if (liveChanged) fs.writeFileSync(livePath, JSON.stringify(live, null, 2) + '\n');
    if (profileChanged) fs.writeFileSync(profilePath, JSON.stringify(profile, null, 2) + '\n');
    process.stdout.write((liveChanged ? 'live-changed' : 'live-unchanged') + ' ' + (profileChanged ? 'profile-changed' : 'profile-unchanged'));
}
SYNC_NODE_EOF

    local live_existed="false"
    [ -f "$live_file" ] && live_existed="true"

    # --- Plan pass ---
    local plan_stderr
    plan_stderr=$(node "$nodescript" plan "$live_file" "$profile_file" "$subpath" "$exclude_keys" "$deprecated_rules" "$plan_json" 2>&1 1>"$decisions_tsv") || {
        local plan_rc=$?
        # node's stderr is multi-line (a stack, a temp path): one reason line,
        # the whole of it logged as detail lines by error_reason (8.3)
        write_error "$tool" "settings sync failed" "plan pass: $(error_reason "$plan_stderr" "$plan_rc")"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr"
        return 1
    }
    log "Settings sync plan: $plan_stderr"

    # grep -c prints "0" and exits 1 on no matches; `|| true` avoids set -e abort
    # without the double-"0" that `|| echo 0` would append (-> "integer expected").
    local decision_count
    decision_count=$(grep -c . "$decisions_tsv" 2>/dev/null || true)
    [ -n "$decision_count" ] || decision_count=0

    if [ "${DRY_RUN:-}" = "true" ]; then
        log "[DRY RUN] settings sync: $plan_stderr (would prompt for $decision_count divergent leaf/leaves)"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr"
        SYNC_MANAGED_JSON_RESULT="unchanged"
        return 0
    fi

    # Nothing to adopt, purge, or decide -> no write, no backups (avoid churn).
    case "$plan_stderr" in
        "adopts=0 deprecated=0 decisions=0")
            log_ok "Settings unchanged: $(display_path "$live_file")"
            rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr"
            SYNC_MANAGED_JSON_RESULT="unchanged"
            return 0 ;;
    esac

    # --- Prompt loop (granular, per leaf) ---
    : > "$choices_tsv"
    if [ "$decision_count" -gt 0 ]; then
        local id kind cur prop adoptf
        if [ "$live_existed" = "false" ]; then
            # No live file yet (fresh HOME): nothing local to protect, so every leaf is
            # created from the profile without prompting (#31).
            log "No $(display_path "$live_file") yet -- creating from profile ($decision_count setting(s))"
            mkdir -p "$(dirname "$live_file")"
        fi
        # Read decisions on fd 3, not stdin: the prompt's interactivity test
        # (tty_interactive) checks stdin, which must stay the caller's terminal.
        while IFS=$'\t' read -r -u 3 id kind cur prop adoptf; do
            [ -n "$id" ] || continue
            if [ "$live_existed" = "false" ]; then
                JSON_FIELD_REVIEW_RESULT="overwrite"
            else
                prompt_json_field_review "$id" "$cur" "$prop" "profile.json" "$adoptf" "settings.json" "1" "" "" "$tool"
            fi
            # A skipped leaf is left differing: one warning per leaf
            # (reference/logging.md 8.3). Parity: Sync-ManagedJson.
            if [ "$JSON_FIELD_REVIEW_RESULT" = "skip" ]; then
                write_warn "$tool" "Skipped: $id in $(display_path "$live_file") (differs from profile.json; reviewed again next run)"
            fi
            printf '%s\t%s\n' "$id" "$JSON_FIELD_REVIEW_RESULT" >> "$choices_tsv"
        done 3< "$decisions_tsv"
    fi

    # --- Backup before apply ---
    backup_file "$live_file"
    [ -f "$profile_file" ] && backup_file "$profile_file"

    # --- Apply pass ---
    local apply_out apply_rc=0
    apply_out=$(node "$nodescript" apply "$live_file" "$profile_file" "$subpath" "$exclude_keys" "$deprecated_rules" "$plan_json" "$choices_tsv" 2>"$applyerr") || apply_rc=$?
    if [ "$apply_rc" -ne 0 ]; then
        write_error "$tool" "settings sync failed" "apply pass: $(error_reason "$apply_out"$'\n'"$(cat "$applyerr")" "$apply_rc")"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr"
        return 1
    fi

    # --- Post-write validation ---
    local verr=""
    if [ -f "$live_file" ] && ! verr=$(node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$live_file" 2>&1); then
        write_error "$tool" "settings sync failed" "$(display_path "$live_file") is not valid JSON after write -- $(error_reason "$verr" 1)"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr"
        return 1
    fi

    case "$apply_out" in
        live-changed*)
            log_ok "Settings synced: $(display_path "$live_file")"
            SYNC_MANAGED_JSON_RESULT=$([ "$live_existed" = "true" ] && echo "updated" || echo "created") ;;
        *)
            log_ok "Settings unchanged: $(display_path "$live_file")"
            SYNC_MANAGED_JSON_RESULT="unchanged" ;;
    esac
    case "$apply_out" in
        *profile-changed) log_ok "Profile updated: $(display_path "$profile_file")" ;;
    esac

    rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv" "$applyerr"
    return 0
}

# ---------------------------------------------------------------------------
# Repair broken uv tool environment (cross-platform)
# ---------------------------------------------------------------------------
# When `uv tool upgrade <tool>` fails with "missing a valid environment",
# find a working Python via `uv python find` (fallback: system python/python3)
# and reinstall with --force --python <path>.
# Usage: repair_uv_tool_env UV_TOOL UPGRADE_OUTPUT [TOOL]
#   UV_TOOL         the uv tool package name (e.g. "modal")
#   UPGRADE_OUTPUT  the failed upgrade's captured output
#   TOOL            optional: the record name of a failed repair (the tool name
#                   table's name, e.g. "modal cli"); default the script's name
# Returns (parity: Repair-UvToolEnv):
#   0  repaired (the broken environment is logged at info: it is fixed, nothing
#      is left for the user -- reference/logging.md 8.3 "What is a warning")
#   1  not applicable: the output does not show a broken environment (nothing
#      logged or recorded; the caller handles its own failure)
#   3  the repair failed and is recorded (one write_error TOOL with its reason):
#      the caller records nothing more for it
repair_uv_tool_env() {
    local tool_name="$1"
    local upgrade_output="${2:-}"
    local tool="${3:-}"

    if ! printf '%s\n' "$upgrade_output" | grep 'missing a valid environment' >/dev/null; then
        return 1
    fi

    log "$tool_name uv environment is broken (Python removed?) -- repairing..."

    # Find a working Python -- uv's own Pythons first, then system
    local working_python=""
    local uv_python
    # 2>/dev/null + || true: "no Python found" is an expected outcome here; the -n/-x
    # check below handles it and falls through to system Python.
    uv_python=$(uv python find 2>/dev/null) || true
    if [ -n "$uv_python" ] && [ -x "$uv_python" ]; then
        working_python="$uv_python"
    elif command -v python3 >/dev/null 2>&1; then
        working_python=$(command -v python3)
    elif command -v python >/dev/null 2>&1; then
        working_python=$(command -v python)
    fi

    if [ -z "$working_python" ]; then
        write_error "$tool" "$tool_name uv environment repair failed" "no working Python found (uv python find, python3, python)"
        return 3
    fi

    log "Repairing with: uv tool install --force --python $working_python $tool_name"
    local repair_output
    # Capture the exit code instead of aborting under set -e; it decides success below.
    local repair_rc=0
    repair_output=$(uv tool install --force --python "$working_python" "$tool_name" 2>&1) || repair_rc=$?

    if [ "$repair_rc" -ne 0 ]; then
        # error_reason logs the output as detail lines
        write_error "$tool" "$tool_name uv environment repair failed (uv exit $repair_rc)" "$(error_reason "$repair_output" "$repair_rc")"
        return 3
    fi
    local line
    while IFS= read -r line; do
        if [ -n "$line" ]; then log "$line"; fi
    done <<< "$repair_output"

    log_ok "Repaired $tool_name uv environment"
    return 0
}

# ---------------------------------------------------------------------------
# Parse CHANGED: lines from a node merge result and emit DETAIL summary entries.
# Usage: emit_merge_details "$MERGE_RESULT" "tool_name"
# Only processes lines prefixed with "CHANGED: " -- ignores status and other output.
# ---------------------------------------------------------------------------
emit_merge_details() {
    local merge_result="$1" tool_name="$2"
    local changed_keys
    changed_keys=$(echo "$merge_result" | perl -ne 'print if s/^CHANGED: //')
    if [ -n "$changed_keys" ]; then
        while IFS= read -r key_change; do
            log "  $key_change"
            write_summary DETAIL "$tool_name" "$key_change"
        done <<< "$changed_keys"
    fi
}

# ---------------------------------------------------------------------------
# JSON normalization for comparison (sorted keys, deterministic output)
# ---------------------------------------------------------------------------
# JavaScript JSON.stringify preserves insertion order, which may differ
# between runs or between PS1/bash variants writing the same file. Sorting
# keys before comparison ensures identical content produces identical JSON.
#
# SORT_KEYS_JS: minified sortKeys function for embedding in node -e blocks.
#   Usage: node -e "$SORT_KEYS_JS; ..."
#
# normalize_json: pipe-based wrapper for standalone use.
#   Usage: NORMALIZED=$(echo "$json_string" | normalize_json)
SORT_KEYS_JS='function sortKeys(o){if(o===null||typeof o!=="object")return o;if(Array.isArray(o))return o.map(sortKeys);var s={};Object.keys(o).sort().forEach(function(k){s[k]=sortKeys(o[k])});return s}'

normalize_json() {
    node -e "
        var input = require('fs').readFileSync('/dev/stdin', 'utf8');
        $SORT_KEYS_JS
        try {
            console.log(JSON.stringify(sortKeys(JSON.parse(input)), null, 2));
        } catch(e) {
            process.stderr.write('normalize_json: ' + e.message + '\n');
            process.exit(1);
        }
    "
}

# ---------------------------------------------------------------------------
# Go install provenance detection (macOS)
# Returns: "homebrew", "pkg-installer", "goenv", "manual", "none", or "unknown"
# ---------------------------------------------------------------------------
detect_go_provenance() {
    local go_path
    go_path=$(command -v go 2>/dev/null) || { echo "none"; return; }
    case "$go_path" in
        /opt/homebrew/*/go|/usr/local/Cellar/*/go)
            echo "homebrew" ;;
        /usr/local/go/bin/go)
            # /usr/local/go is go.dev's official tarball location. Only macOS can tell a
            # .pkg install from a manual tarball (pkgutil). Without pkgutil (Linux) the
            # tarball is the upstream-preferred install -- never a cleanup target.
            if ! command -v pkgutil >/dev/null 2>&1; then
                echo "upstream"
            elif pkgutil --pkg-info=org.golang.go >/dev/null 2>&1; then
                echo "pkg-installer"
            else
                echo "manual"
            fi ;;
        */.goenv/*)
            echo "goenv" ;;
        *)
            echo "unknown" ;;
    esac
}

# ---------------------------------------------------------------------------
# Ensure GOPATH/bin is on PATH for current session
# Returns 0 if already on PATH, 1 if added for this session. Not a warning: new
# shells get Go's bin directory from the managed PATH block (setup-user-shell,
# issue #185), so the caller logs it at info.
# ---------------------------------------------------------------------------
ensure_gopath_bin_on_path() {
    local gopath_bin="${GOPATH:-$HOME/go}/bin"
    case ":$PATH:" in
        *":$gopath_bin:"*) return 0 ;;
    esac
    export PATH="$gopath_bin:$PATH"
    return 1
}

# ---------------------------------------------------------------------------
# Summary panel renderer (reference/logging.md 8.4 reader rules, 8.5 panel)
# ---------------------------------------------------------------------------
# show_summary [--keep] [FILE] -- draw the end-of-run panel from FILE (default
# AITOOLS_SUMMARY_FILE): green (one line per tool with an OK record and no WARN
# or ERROR record under its name; its first OK record's status), yellow (every
# WARN record, file order), red (every ERROR record), the ACTION block; a
# U+2500 rule above and below. Identical yellow / red records collapse into the
# first, followed by "(xN)"; at most 20 yellow and 20 red lines, then
# "+N more in deploy.log"; DETAIL lines follow their tool's first panel line in
# its colour (not shown when that line is beyond the cap or does not exist);
# identical ACTION lines are shown once. Yellow text is cut at 70 code points,
# red what/reason by the 8.5 algorithm; the name column is padded to 16 code
# points, never cut. Lengths count code points in every locale (perl -CSD).
# A record of an unknown kind, or one other than ACTION with an empty name, is
# skipped and logged at detail, quoted verbatim. Nothing is drawn when FILE is
# unset, missing or empty.
# Without --keep (the entry points' end of run, summary_end) it then keeps a
# copy as last-summary.txt in the log directory when AITOOLS_PRESERVE_SUMMARY=1
# and deletes FILE. With --keep FILE is left as it is.
# Parity: Show-Summary in aitools-lib.ps1 (rule "-" x 60; colours by name).
show_summary() {
    local keep=false sfile ts
    if [ "${1:-}" = "--keep" ]; then keep=true; shift; fi
    sfile="${1:-${AITOOLS_SUMMARY_FILE:-}}"
    [ -n "$sfile" ] || return 0
    [ -f "$sfile" ] || return 0
    if [ -s "$sfile" ]; then
        ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        if ! AITLIB_SS_LOG="${LOG_FILE:-}" AITLIB_SS_PREFIX="[$ts] [${SCRIPT_NAME:-unknown}] [detail] run summary: skipped record: " \
            perl -CSD -e '
            use strict; use warnings;
            my $file = shift;
            open(my $in, "<", $file) or die "cannot read $file: $!\n";
            my (@ok_order, %ok_status, %bad, @warn, @err, %det, @actions, %act_seen, @skipped);
            while (my $line = <$in>) {
                $line =~ s/\r?\n\z//;
                next if $line eq "";
                my ($kind) = $line =~ /\A([^|]*)/;
                if ($kind eq "ACTION") {
                    my ($instr) = $line =~ /\A[^|]*\|[^|]*\|(.*)\z/s;
                    if (!defined $instr || $instr eq "") { push @skipped, $line; next }
                    push @actions, $instr unless $act_seen{$instr}++;
                    next;
                }
                my @f = split /\|/, $line, -1;
                shift @f;
                my $nf = $kind eq "ERROR" ? 3 : 2;
                push @f, "" while @f < $nf;
                if (@f > $nf) { my @rest = splice(@f, $nf - 1); push @f, join("/", @rest) }
                if ($kind !~ /\A(?:OK|DETAIL|WARN|ERROR)\z/ || $f[0] eq "") { push @skipped, $line; next }
                my $name = $f[0];
                if ($kind eq "OK") {
                    next if exists $ok_status{$name};
                    $ok_status{$name} = $f[1];
                    push @ok_order, $name;
                } elsif ($kind eq "DETAIL") {
                    push @{ $det{$name} }, $f[1];
                } elsif ($kind eq "WARN") {
                    $bad{$name} = 1;
                    push @warn, [$name, $f[1]];
                } else {
                    $bad{$name} = 1;
                    push @err, [$name, $f[1], $f[2]];
                }
            }
            close $in;
            if (@skipped && $ENV{AITLIB_SS_LOG} ne "" && open(my $lf, ">>", $ENV{AITLIB_SS_LOG})) {
                print $lf $ENV{AITLIB_SS_PREFIX}, $_, "\n" for @skipped;
                close $lf;
            }
            sub cut { my ($s, $n) = @_; return length($s) <= $n ? $s : substr($s, 0, $n - 3) . "..." }
            sub pad { my ($s, $n) = @_; return length($s) >= $n ? $s : $s . (" " x ($n - length($s))) }
            sub collapse {
                my ($list, $keyf) = @_;
                my (@out, %at);
                for my $r (@$list) {
                    my $k = $keyf->($r);
                    if (exists $at{$k}) { $out[$at{$k}][1]++ }
                    else { $at{$k} = scalar @out; push @out, [$r, 1] }
                }
                return @out;
            }
            my @yl = collapse(\@warn, sub { join("\0", @{ $_[0] }) });
            my @rl = collapse(\@err,  sub { join("\0", @{ $_[0] }) });
            # The first panel line of a tool: its green line, else its first
            # yellow, else its first red line (index into the collapsed list)
            my (%first_y, %first_r);
            for my $i (0 .. $#yl) { my $n = $yl[$i][0][0]; $first_y{$n} = $i unless exists $first_y{$n} }
            for my $i (0 .. $#rl) { my $n = $rl[$i][0][0]; $first_r{$n} = $i unless exists $first_r{$n} }
            my %c = (green => "\e[32m", yellow => "\e[33m", red => "\e[31m", magenta => "\e[1;35m");
            my $rst = "\e[0m";
            my $cap = 20;
            my @out = ("", "\x{2500}" x 56);
            my $details = sub {
                my ($name, $col) = @_;
                push @out, $c{$col} . (" " x 26) . $_ . $rst for @{ $det{$name} || [] };
            };
            for my $n (@ok_order) {
                next if $bad{$n};
                push @out, $c{green} . "  [ok]  " . pad($n, 16) . " " . $ok_status{$n} . $rst;
                $details->($n, "green");
            }
            for my $i (0 .. $#yl) {
                last if $i >= $cap;
                my ($r, $cnt) = @{ $yl[$i] };
                my $t = cut($r->[1], 70) . ($cnt > 1 ? " (x$cnt)" : "");
                push @out, $c{yellow} . "  [!]   " . pad($r->[0], 16) . " " . $t . $rst;
                $details->($r->[0], "yellow") if $first_y{$r->[0]} == $i;
            }
            push @out, $c{yellow} . (" " x 8) . "+" . (@yl - $cap) . " more in deploy.log" . $rst if @yl > $cap;
            for my $i (0 .. $#rl) {
                last if $i >= $cap;
                my ($r, $cnt) = @{ $rl[$i] };
                my ($w, $why) = ($r->[1], $r->[2]);
                my $body;
                if ($why eq "") {
                    $body = cut($w, 70);
                } elsif (length($w) + 2 + length($why) <= 70) {
                    $body = "$w: $why";
                } else {
                    my $max = 70 - 2 - length($why);
                    $max = 20 if $max < 20;
                    my $w2 = cut($w, $max);
                    $body = $w2 . ": " . cut($why, 70 - 2 - length($w2));
                }
                $body .= " (x$cnt)" if $cnt > 1;
                push @out, $c{red} . "  [ERR] " . pad($r->[0], 16) . " " . $body . $rst;
                $details->($r->[0], "red") if !exists $first_y{$r->[0]} && $first_r{$r->[0]} == $i;
            }
            push @out, $c{red} . (" " x 8) . "+" . (@rl - $cap) . " more in deploy.log" . $rst if @rl > $cap;
            if (@actions) {
                push @out, "", $c{magenta} . "  ACTION REQUIRED -- run before tools are ready:" . $rst;
                push @out, $c{magenta} . "  >>  " . $_ . $rst for @actions;
            }
            push @out, "\x{2500}" x 56;
            print "$_\n" for @out;
        ' "$sfile"; then
            log_detail "run summary: the panel could not be drawn from $sfile"
        fi
    fi
    if $keep; then return 0; fi
    # Preserve summary for log compliance checks
    if [ "${AITOOLS_PRESERVE_SUMMARY:-}" = "1" ]; then
        # 2>/dev/null: the failure is the detail line below (the panel is already drawn)
        if ! cp "$sfile" "${LOG_DIR:-$AITOOLS_LOG_DIR}/last-summary.txt" 2>/dev/null; then
            log_detail "run summary: could not keep a copy as last-summary.txt in ${LOG_DIR:-$AITOOLS_LOG_DIR}"
        fi
    fi
    # The panel is drawn: the file is removed (rm -f ignores a missing file)
    rm -f "$sfile"
}

# ---------------------------------------------------------------------------
# Build prerequisite checking
# ---------------------------------------------------------------------------

# ensure_tool_on_path: Verify a tool is findable after installation.
# Tries: 1) command -v (current PATH), 2) hash -r (cache refresh),
# 3) known paths fallback (filesystem check + session PATH update).
# Usage: ensure_tool_on_path "nasm" "/usr/local/bin/nasm" "/opt/homebrew/bin/nasm"
# Returns 0 if tool is now on PATH, 1 otherwise.
ensure_tool_on_path() {
    local tool_name="$1"
    shift
    local known_paths=("$@")

    # Already on PATH?
    if command -v "$tool_name" >/dev/null 2>&1; then return 0; fi

    # Refresh command cache (picks up tools installed earlier in the same session)
    hash -r 2>/dev/null  # expected to succeed; some shells don't support it
    if command -v "$tool_name" >/dev/null 2>&1; then return 0; fi

    # Fallback: check known install locations on disk
    for kp in "${known_paths[@]}"; do
        if [ -x "$kp" ]; then
            local parent_dir
            parent_dir=$(dirname "$kp")
            export PATH="$parent_dir:$PATH"
            log "$tool_name found at $kp (added to session PATH)"
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Resolve the harness-managed Python interpreter deterministically.
# Prefers the uv shim (~/.local/bin/python3) so the harness uses the managed
# interpreter even in non-interactive contexts (cron/launchd/hooks) where the
# login-profile PATH order does not apply. Prints the resolved command or path
# on stdout; returns 1 if no interpreter is found.
# ---------------------------------------------------------------------------
harness_python() {
    local uv_shim="$HOME/.local/bin/python3"
    if [ -x "$uv_shim" ]; then
        printf '%s' "$uv_shim"
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi
    if command -v python >/dev/null 2>&1; then
        command -v python
        return 0
    fi
    return 1
}

# Check known build prerequisites for an ecosystem.
# Usage: check_build_prereqs "cargo"
#   Outputs missing prereq info to stdout (one per line: NAME|INSTALL_INSTRUCTION).
#   Returns 0 if all present, 1 if any missing.
check_build_prereqs() {
    local ecosystem="$1"
    local missing=0

    # Refresh shell command cache (picks up tools installed earlier in the same session)
    hash -r 2>/dev/null  # expected to succeed; some shells don't support it

    case "$ecosystem" in
        cargo)
            # NASM -- required by aws-lc-sys on x86_64
            if [ "$(uname -m)" = "x86_64" ] && ! command -v nasm >/dev/null 2>&1; then
                # Fallback: check known install locations
                if ensure_tool_on_path "nasm" /usr/local/bin/nasm /opt/homebrew/bin/nasm /usr/bin/nasm; then
                    : # Found via fallback -- ensure_tool_on_path already added to PATH
                else
                    echo "NASM|brew install nasm (macOS) or apt-get install nasm (Linux)"
                    missing=1
                fi
            fi
            # cmake -- required by some crates
            # Official: cmake.org/download lists pip, ZIP, MSI (not winget)
            # macOS: brew install cmake (user-level, no sudo)
            # Windows: uv tool install cmake (user-level, see reference/tool-evaluation-playbook.md)
            if ! command -v cmake >/dev/null 2>&1; then
                if ensure_tool_on_path "cmake" /usr/local/bin/cmake /opt/homebrew/bin/cmake /usr/bin/cmake /Applications/CMake.app/Contents/bin/cmake; then
                    : # Found via fallback
                else
                    echo "CMake|brew install cmake (macOS) / uv tool install cmake (Windows) -- see cmake.org/download"
                    missing=1
                fi
            fi
            ;;
        pip)
            # Add pip-specific prereqs here as discovered
            ;;
        go)
            # Add go-specific prereqs here as discovered
            ;;
    esac

    return $missing
}

# ---------------------------------------------------------------------------
# Build failure diagnosis
# ---------------------------------------------------------------------------

# Scan build output for known failure signatures (AITLIB_BUILD_SIGNATURES, the
# table error_reason uses; first match wins, case-insensitive).
# Usage: diagnose_build_failure "$output"
#   Prints "NAME|REMEDY" if a known signature is found (error_reason gives the
#   same match as "<NAME>: <REMEDY>").
#   Returns 0 if found, 1 if no match. Parity: Diagnose-BuildFailure.
diagnose_build_failure() {
    printf '%s' "${1:-}" | AITLIB_ER_SIGS="$AITLIB_BUILD_SIGNATURES" perl -e '
        my $in = do { local $/; <STDIN> };
        $in = "" unless defined $in;
        my $hit;
        for my $sig (split /\n/, $ENV{AITLIB_ER_SIGS}) {
            my ($name, $pat, $remedy) = split /\t/, $sig, 3;
            next unless defined $remedy;
            if ($in =~ /$pat/i) { $hit = "$name|$remedy"; last }
        }
        if (defined $hit) { print $hit, "\n"; exit 0 }
        exit 1;
    '
}
