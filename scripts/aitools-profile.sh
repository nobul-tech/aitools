#!/usr/bin/env bash
# aitools-profile.sh -- the one resolver for "where is my dotprofile" and
# "which machine profile is this machine" (macOS/Linux; on Windows use
# aitools-profile.ps1, which implements the same commands, options and output).
#
# Intent: Resolve, deterministically and with a stated reason ("via"), the
# dotprofile repo path and this machine's profile in profile.json, and derive
# the config.json values that come from them. NOT a writer of config.json
# (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
# except the `register` subcommand, which writes to a temp file the caller
# validates, backs up and moves, and the `exception-set` subcommand, the only
# writer of toolExceptions, which writes in place (temp, validate, backup, move)
# and commits and pushes profile.json. NOT the settings.json sync
# (sync_managed_json). Consumed by: the bash shared-lib wrappers
# resolve_user_repo_path / resolve_machine_profile / tool_exception_get /
# tool_exception_record, setup-user-config.sh, build-deploy.sh (on macOS/Linux;
# under Git Bash on Windows it uses the AITOOLS_USER_REPO_PATH the entry point
# exports), aitools `user init`, and the generated deploy/setup-user-claude.sh
# (embedded copy).
#
# Usage: aitools-profile.sh <command> [options]   (--help for details)
# Writers: `migrate` also writes profile.json (re-keys profiles in place: temp,
#   validate, backup, move, commit, push). The intent statement above predates
#   it; its update awaits commander approval.
# Machine profiles (profile.json revision 2.2, re-key design): keyed by this
#   machine's raw id, lower-cased (`profiles.<machineId>`; `machine.id` repeats
#   the key), or `environment:<name>` for an environment without a stable id
#   (claude-code-web). The human-readable name is the profile's `alias` field.
#   Profiles keyed by alias (revision 2.1, "legacy") are still read; `migrate`
#   re-keys them. Key lookups ignore case; `alias` lookups do not.
# Exit codes: 0 resolved / ok; 1 nothing found (expected states, e.g. before
#   `aitools user init`); 2 error (bad input, unreadable or invalid JSON,
#   ambiguous match, machine id on two profiles); 3 refused (exception-set
#   without a profile registered to this machine; register without a machine
#   id; a write to an AITOOLS_PROFILE_FILE snapshot); 4 refused (register: the
#   alias is used by another profile; pass --allow-duplicate-alias only after an
#   interactive confirm). Callers must not pass 2 through as their own exit
#   code: exit 2 from a setup script means a user abort (D-TS13).
# Output: data on stdout only -- key<TAB>value lines (default) or one JSON
#   object (--json). Diagnostics go to deploy.log (detail lines) and stderr.
#   Logging contract (library-style tool): every warning and error is returned
#   as a `warn` / `error` line (and logged at detail); the caller logs each at
#   its level and owns the summary rows and counters.
# Machine fields in resolve / derive-config / exception-get output:
#   key (the profiles key that matched), alias (its alias field, else the key),
#   via (override|environment|id|config|alias|hostname|none), owner (this |
#   other | unregistered | unknown | absent: whose profile it is; unknown = it
#   has a machine.id but this machine's id cannot be detected), legacy (true
#   when the profile is still keyed by alias). exception-get returns only this
#   machine's decisions (owner this); another profile's are ignored with a warning.
# JSON engine: scripts/aitools-json.pl (core perl only, no modules).
#   It keeps key order and writes the node JSON.stringify(v, null, 2) layout, so
#   bash, PowerShell (ConvertTo-Json) and node writers produce the same bytes for
#   strings, integers, booleans and null (what profile.json holds). Other number
#   literals are kept verbatim here and re-formatted by PowerShell and node; a
#   lone UTF-16 surrogate escape is written differently by each engine.
# Safe to re-run: every command except `register`, `exception-set` and
#   `migrate` is read-only; `register` writes only the --out file;
#   `exception-set` rewrites one toolExceptions entry and reports "unchanged"
#   when it is identical; `migrate` reports "unchanged" once every profile is
#   keyed by id.
# Platform: macOS/Linux. Reference: reference/user-repo.md "Resolution".
# Decisions: P-Q2 (raw machine ids), P-Q3 (native bash + PowerShell, no node),
#   P-Q5 (macOS hostname = `scutil --get LocalHostName` only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/aitools-lib.sh"
# stdout carries data: console log lines go to stderr (deploy.log unchanged).
# Defined before logging_init, whose environment check may already log a warning.
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local line="[$ts] [$SCRIPT_NAME] [$level] $1"
    printf '%s\n' "$line" >> "$LOG_FILE"
    printf '%s\n' "$line" >&2
}
logging_init "aitools-profile"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use aitools-profile.ps1."
        exit 1 ;;
esac

usage() {
    cat <<'EOF'
aitools-profile.sh -- dotprofile and machine-profile resolver (macOS/Linux)

Commands:
  user-repo-path  Which dotprofile. Options: --config F, --github-user U,
                  --user-repo-path P, --repos-path P, --plain (path only)
  machine-id      Print this machine's stable id (macOS IOPlatformUUID,
                  Linux /etc/machine-id); stored raw in profile.json
  hostname        Print this machine's name (macOS: scutil --get LocalHostName;
                  Linux: uname -n, short form)
  resolve         Which profile this machine uses and why (key, alias, via,
                  owner, legacy). Options: --config F, --profile F,
                  --alias A (a profiles key, else an alias field), --environment E
  derive-config   The config.json values derived from profile.json
                  (derived.machineId, derived.machineAlias). Options: --config F,
                  --github-user U, --user-repo-path P, --repos-path P,
                  --alias A, --environment E
  snapshot        Compact JSON of version, identity, cursor, profiles from
                  --profile F (for embedding in generated deploy scripts)
  register        Write --profile F with this machine's profile,
                  profiles.<machine id> (claude-code-web: environment:<name>),
                  to --out TMP. Options: --alias A (default: short hostname),
                  --allow-duplicate-alias (after an interactive confirm only),
                  --claim KEY (move an alias-keyed profile without machine.id
                  under this machine's key; after an interactive choice only),
                  --name N, --company C, --shell S, --environment E,
                  --create (new profile.json; with --github-user U, --email E).
                  Exit 3 = no machine id; exit 4 = alias used by another profile
  migrate         Re-key alias-keyed profiles by machine.id (alias = old key):
                  --profile F (default: the dotprofile's), --dry-run. Writes
                  in place (temp, validate, backup, move), commits, pushes
  exception-get   This machine's recorded tool exception for --slug S (found
                  true/false and the stored fields). Options: --config F,
                  --profile F, --alias A, --environment E
  exception-set   Record a [k]eep decision for --slug S: --platform P, --method M,
                  --path PATH, --version V, --by SCRIPT [--reason R]
                  [--decided-at UTC]. Writes profile.json in place (temp,
                  validate, backup, move), then commits profile.json and pushes.
                  Exit 3 = refused (no dotprofile, or no profile registered to
                  this machine: matched by hostname, cache or another machine)

Output: key<TAB>value lines; --json prints one JSON object instead.
Environment: AITOOLS_USER_REPO_PATH, AITOOLS_MACHINE_ALIAS, AITOOLS_PROFILE_FILE,
  AITOOLS_ENVIRONMENT (see reference/user-repo.md "Resolution").
Test options: --machine-id-value ID, --hostname-value NAME (replace detection;
  --machine-id-value none = no detectable id).
Exit: 0 ok, 1 not found, 2 error, 3 refused, 4 refused (alias in use).
EOF
}

# ---------------------------------------------------------------------------
# JSON engine: scripts/aitools-json.pl (core perl; order-preserving, node layout).
# Exit codes per command are documented in that file.
# ---------------------------------------------------------------------------
AITOOLS_JSON_PL="$SCRIPT_DIR/aitools-json.pl"
if [ ! -f "$AITOOLS_JSON_PL" ]; then
    log_detail "JSON engine missing: $AITOOLS_JSON_PL"
    printf 'aitools-profile: JSON engine missing: %s\n' "$AITOOLS_JSON_PL" >&2
    exit 2
fi
if ! command -v perl >/dev/null 2>&1; then
    log_detail "perl not found -- aitools-profile cannot read JSON"
    printf 'aitools-profile: perl not found (the harness manages perl; run aitools install)\n' >&2
    exit 2
fi

pj() { perl "$AITOOLS_JSON_PL" "$@"; }

# die_internal MSG -- an engine failure on an already-validated file: logged at
# detail (deploy.log keeps it even when the caller drops stderr), then stderr, exit 2
die_internal() {
    log_detail "internal error: $1"
    printf 'aitools-profile: internal error %s\n' "$1" >&2
    exit 2
}

# jread VAR FILE SEG... -- VAR = the scalar at the path ("" when absent, null or
# not a scalar); JREAD_FOUND=true|false. FILE must already be validated (jcheck);
# any other engine failure is an internal error and exits 2 with a message.
JREAD_FOUND=false
jread() {
    local __var="$1"; shift
    local __v="" __rc=0
    __v=$(pj get "$@") || __rc=$?
    case "$__rc" in
        0) JREAD_FOUND=true ;;
        1|3) JREAD_FOUND=false; __v="" ;;
        *) die_internal "reading $1 (engine exit $__rc)" ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jlist VAR KIND FILE SEG... -- VAR = keys (KIND=keys) or array items (KIND=items),
# newline-separated; "" when absent or of another type.
jlist() {
    local __var="$1" __kind="$2"; shift 2
    local __v="" __rc=0
    __v=$(pj "$__kind" "$@") || __rc=$?
    case "$__rc" in
        0) : ;;
        1|3) __v="" ;;
        *) die_internal "listing $1 (engine exit $__rc)" ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jtype VAR FILE SEG... -- VAR = object|array|string|number|boolean, or "" when absent/null
jtype() {
    local __var="$1"; shift
    local __v="" __rc=0
    __v=$(pj type "$@") || __rc=$?
    case "$__rc" in
        0) : ;;
        1) __v="" ;;
        *) die_internal "typing $1 (engine exit $__rc)" ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jsub VAR FILE SEG... -- VAR = compact JSON of the value at the path, "" when absent
jsub() {
    local __var="$1"; shift
    local __v="" __rc=0
    __v=$(pj json "$@") || __rc=$?
    case "$__rc" in
        0) : ;;
        1) __v="" ;;
        *) die_internal "reading $1 (engine exit $__rc)" ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# utf16_bom FILE -- 0 when FILE starts with a UTF-16 byte order mark
utf16_bom() {
    perl -e 'open(my $f, "<:raw", $ARGV[0]) or exit 1; my $b = ""; read($f, $b, 2); exit(($b eq "\xff\xfe" || $b eq "\xfe\xff") ? 0 : 1)' "$1"
}

# jcheck FILE -- sets JCHECK_STATE=valid|missing|invalid and JCHECK_MSG. A UTF-16
# file is invalid in both resolvers, with the same message (PowerShell's reader
# would otherwise decode it while perl cannot).
jcheck() {
    local rc=0
    JCHECK_MSG=$(pj check "$1" 2>&1) || rc=$?
    case "$rc" in
        0) JCHECK_STATE=valid ;;
        1) JCHECK_STATE=missing ;;
        *) JCHECK_STATE=invalid
           if utf16_bom "$1"; then JCHECK_MSG="$1 is UTF-16 encoded, not UTF-8 -- save it as UTF-8"
           elif [ -z "$JCHECK_MSG" ]; then JCHECK_MSG="$1 could not be read (engine exit $rc)"; fi ;;
    esac
}

# expand_home PATH -- a leading ~ (alone, or ~/...) becomes $HOME, as in a shell
expand_home() {
    case "$1" in
        "~")   printf '%s' "$HOME" ;;
        "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
        *)     printf '%s' "$1" ;;
    esac
}

# ---------------------------------------------------------------------------
# Output: key<TAB>value lines, warnings and errors last
# ---------------------------------------------------------------------------
OUT_LINES=""
WARN_LINES=""
ERR_LINES=""
one_line() { local v="${1-}"; v="${v//[$'\t\r\n']/ }"; printf '%s' "$v"; }
put() { OUT_LINES="${OUT_LINES}${1}"$'\t'"$(one_line "${2-}")"$'\n'; }
add_warn() { WARN_LINES="${WARN_LINES}$(one_line "$1")"$'\n'; }
add_err() { ERR_LINES="${ERR_LINES}$(one_line "$1")"$'\n'; }
finish() {
    local code="$1" all="$OUT_LINES" line
    while IFS= read -r line; do
        if [ -n "$line" ]; then all="${all}warn"$'\t'"${line}"$'\n'; log_detail "$CMD warning: $line"; fi
    done <<< "$WARN_LINES"
    while IFS= read -r line; do
        if [ -n "$line" ]; then all="${all}error"$'\t'"${line}"$'\n'; log_detail "$CMD error: $line"; fi
    done <<< "$ERR_LINES"
    log_detail "$CMD exit=$code"
    if $OPT_JSON; then
        printf '%s' "$all" | pj tagged2json
    else
        printf '%s' "$all"
    fi
    exit "$code"
}

usage_error() {
    log_detail "usage error: $1"
    printf 'aitools-profile: %s (see --help)\n' "$1" >&2
    exit 2
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
CMD="${1:-}"
if [ $# -gt 0 ]; then shift; fi
case "$CMD" in --help|-h) usage; exit 0 ;; esac
OPT_CONFIG=""; OPT_PROFILE=""; OPT_ALIAS=""; OPT_ENVIRONMENT=""; OPT_GITHUB_USER=""
OPT_USER_REPO_PATH=""; OPT_REPOS_PATH=""; OPT_NAME=""; OPT_COMPANY=""; OPT_SHELL=""
OPT_EMAIL=""; OPT_OUT=""; OPT_MACHINE_ID_VALUE=""; OPT_HOSTNAME_VALUE=""
OPT_SLUG=""; OPT_PLATFORM=""; OPT_METHOD=""; OPT_PATH=""; OPT_VERSION=""; OPT_BY=""
OPT_REASON=""; OPT_DECIDED_AT=""
OPT_CREATE=false; OPT_JSON=false; OPT_PLAIN=false; OPT_DRY_RUN=false; OPT_ALLOW_DUP=false; OPT_CLAIM=""
need_value() { if [ "$1" -lt 2 ]; then usage_error "$2 needs a value"; fi; }
while [ $# -gt 0 ]; do
    case "$1" in
        --config)          need_value $# "$1"; OPT_CONFIG="$2"; shift 2 ;;
        --profile)         need_value $# "$1"; OPT_PROFILE="$2"; shift 2 ;;
        --alias)           need_value $# "$1"; OPT_ALIAS="$2"; shift 2 ;;
        --environment)     need_value $# "$1"; OPT_ENVIRONMENT="$2"; shift 2 ;;
        --github-user)     need_value $# "$1"; OPT_GITHUB_USER="$2"; shift 2 ;;
        --user-repo-path)  need_value $# "$1"; OPT_USER_REPO_PATH="$2"; shift 2 ;;
        --repos-path)      need_value $# "$1"; OPT_REPOS_PATH="$2"; shift 2 ;;
        --name)            need_value $# "$1"; OPT_NAME="$2"; shift 2 ;;
        --company)         need_value $# "$1"; OPT_COMPANY="$2"; shift 2 ;;
        --shell)           need_value $# "$1"; OPT_SHELL="$2"; shift 2 ;;
        --email)           need_value $# "$1"; OPT_EMAIL="$2"; shift 2 ;;
        --out)             need_value $# "$1"; OPT_OUT="$2"; shift 2 ;;
        --machine-id-value) need_value $# "$1"; OPT_MACHINE_ID_VALUE="$2"; shift 2 ;;
        --hostname-value)  need_value $# "$1"; OPT_HOSTNAME_VALUE="$2"; shift 2 ;;
        --slug)            need_value $# "$1"; OPT_SLUG="$2"; shift 2 ;;
        --platform)        need_value $# "$1"; OPT_PLATFORM="$2"; shift 2 ;;
        --method)          need_value $# "$1"; OPT_METHOD="$2"; shift 2 ;;
        --path)            need_value $# "$1"; OPT_PATH="$2"; shift 2 ;;
        --version)         need_value $# "$1"; OPT_VERSION="$2"; shift 2 ;;
        --by)              need_value $# "$1"; OPT_BY="$2"; shift 2 ;;
        --reason)          need_value $# "$1"; OPT_REASON="$2"; shift 2 ;;
        --decided-at)      need_value $# "$1"; OPT_DECIDED_AT="$2"; shift 2 ;;
        --path-form)       need_value $# "$1"; shift 2 ;;  # PowerShell parity; paths are already native here
        --create)          OPT_CREATE=true; shift ;;
        --json)            OPT_JSON=true; shift ;;
        --plain)           OPT_PLAIN=true; shift ;;
        --dry-run)         OPT_DRY_RUN=true; shift ;;
        --allow-duplicate-alias) OPT_ALLOW_DUP=true; shift ;;
        --claim)           need_value $# "$1"; OPT_CLAIM="$2"; shift 2 ;;
        --help|-h)         usage; exit 0 ;;
        *)                 usage_error "unknown option: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# This machine: environment, stable id, hostname
# ---------------------------------------------------------------------------
# Environment: the shared lib resolved AITOOLS_ENVIRONMENT; --environment re-applies
# the same rule (claude-code-web exists only on linux).
THIS_ENV="$AITOOLS_ENVIRONMENT"
if [ -n "$OPT_ENVIRONMENT" ]; then
    case "$OPT_ENVIRONMENT" in
        claude-code-web|local) THIS_ENV="$OPT_ENVIRONMENT" ;;
        *) usage_error "--environment must be local or claude-code-web" ;;
    esac
    if [ "$AITOOLS_PLATFORM" != "linux" ]; then THIS_ENV="local"; fi
fi

# Stable machine id, stored raw in profile.json (P-Q2).
#   macOS: IOPlatformUUID (ioreg) -- hardware-bound, survives OS reinstall.
#   Linux: /etc/machine-id, then /var/lib/dbus/machine-id (duplicated on cloned images).
THIS_ID=""; THIS_ID_SOURCE=""; THIS_ID_ERROR=""
# Tests only: AITOOLS_PROFILE_TEST_MACHINE_ID / AITOOLS_PROFILE_TEST_HOSTNAME act as
# --machine-id-value / --hostname-value for callers that do not pass options
# (setup-user-config tests).
if [ -z "$OPT_MACHINE_ID_VALUE" ] && [ -n "${AITOOLS_PROFILE_TEST_MACHINE_ID:-}" ]; then OPT_MACHINE_ID_VALUE="$AITOOLS_PROFILE_TEST_MACHINE_ID"; fi
if [ -z "$OPT_HOSTNAME_VALUE" ] && [ -n "${AITOOLS_PROFILE_TEST_HOSTNAME:-}" ]; then OPT_HOSTNAME_VALUE="$AITOOLS_PROFILE_TEST_HOSTNAME"; fi
detect_machine_id() {
    # Tests: the value "none" stands for "this machine's id cannot be detected"
    if [ "$OPT_MACHINE_ID_VALUE" = "none" ]; then
        THIS_ID=""; THIS_ID_ERROR="no machine id (test value)"; return 0
    fi
    if [ -n "$OPT_MACHINE_ID_VALUE" ]; then
        THIS_ID="$OPT_MACHINE_ID_VALUE"; THIS_ID_SOURCE="argument"; return 0
    fi
    if [ -x /usr/sbin/ioreg ]; then
        local out rc=0
        out=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then THIS_ID_ERROR="ioreg failed (exit $rc)"; return 0; fi
        THIS_ID=$(printf '%s\n' "$out" | perl -ne 'print $1 if /"IOPlatformUUID"\s*=\s*"([^"]+)"/')
        THIS_ID_SOURCE="IOPlatformUUID"
        if [ -z "$THIS_ID" ]; then THIS_ID_ERROR="IOPlatformUUID not found in ioreg output"; fi
        return 0
    fi
    local f
    for f in /etc/machine-id /var/lib/dbus/machine-id; do
        if [ -r "$f" ]; then
            THIS_ID=$(tr -d '[:space:]' < "$f")
            if [ -n "$THIS_ID" ]; then THIS_ID_SOURCE="$f"; return 0; fi
        fi
    done
    THIS_ID_ERROR="no machine id source (ioreg, /etc/machine-id, /var/lib/dbus/machine-id)"
}

# Hostname: one source per platform (P-Q5). macOS: `scutil --get LocalHostName`
# (the Bonjour name; the kernel hostname is derived from DNS/DHCP and changes with
# the network, so it is never used). Linux: `uname -n`, short form.
THIS_HOST=""; THIS_HOST_ERROR=""
# short_host NAME -- text before the first dot, ends trimmed, ASCII lower-cased
# (the same rule as ConvertTo-ShortHost in aitools-profile.ps1)
short_host() { local h="${1%%.*}"; printf '%s' "$h" | perl -pe 's/^[ \t\r\n]+|[ \t\r\n]+$//g; tr/A-Z/a-z/'; }
detect_hostname() {
    local raw="" rc=0
    if [ -n "$OPT_HOSTNAME_VALUE" ]; then
        raw="$OPT_HOSTNAME_VALUE"
    elif [ -x /usr/sbin/scutil ]; then
        raw=$(/usr/sbin/scutil --get LocalHostName 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then THIS_HOST_ERROR="scutil --get LocalHostName failed: $raw"; raw=""; fi
    else
        raw=$(uname -n 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then THIS_HOST_ERROR="uname -n failed (exit $rc): $raw"; raw=""; fi
    fi
    THIS_HOST=$(short_host "$raw")
}

# lc TEXT -- ASCII lower case (the same rule as ConvertTo-AsciiLower in the .ps1)
lc() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# ---------------------------------------------------------------------------
# Config (read-only here)
# ---------------------------------------------------------------------------
CFG_FILE="${OPT_CONFIG:-$HOME/.aitools/config.json}"
CFG_OK=false
load_config() {
    jcheck "$CFG_FILE"
    case "$JCHECK_STATE" in
        valid) CFG_OK=true ;;
        missing) CFG_OK=false ;;
        *) CFG_OK=false; add_warn "$JCHECK_MSG -- resolving without it" ;;
    esac
}
# cfg VAR KEY -- top-level config.json string, "" when absent or config unusable
cfg() {
    printf -v "$1" '%s' ""
    if $CFG_OK; then jread "$1" "$CFG_FILE" "$2"; fi
}

strip_slash() { local p="$1"; while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done; printf '%s' "$p"; }

# ---------------------------------------------------------------------------
# Which dotprofile (reference/user-repo.md "Which dotprofile"), first match wins:
#   1 AITOOLS_USER_REPO_PATH  2 --user-repo-path  3 config.json userRepoPath
#   4 <reposPath>/aitools-<githubUser>  5 the only aitools-* dir with profile.json
#   6 none (shared-only mode; not an error)
# Sets RUR_PATH, RUR_VIA, RUR_EXPECTED. Returns 0 found, 1 none, 2 error.
# ---------------------------------------------------------------------------
RUR_PATH=""; RUR_VIA="none"; RUR_EXPECTED=""
resolve_user_repo() {
    RUR_PATH=""; RUR_VIA="none"; RUR_EXPECTED=""
    local p="" base="" user="" d n found="" count=0
    if [ -n "${AITOOLS_USER_REPO_PATH:-}" ]; then
        if [ -d "$AITOOLS_USER_REPO_PATH" ]; then
            RUR_PATH=$(strip_slash "$AITOOLS_USER_REPO_PATH"); RUR_VIA="env"; return 0
        fi
        add_err "AITOOLS_USER_REPO_PATH does not exist: $AITOOLS_USER_REPO_PATH"; return 2
    fi
    if [ -n "$OPT_USER_REPO_PATH" ]; then
        if [ -d "$OPT_USER_REPO_PATH" ]; then
            RUR_PATH=$(strip_slash "$OPT_USER_REPO_PATH"); RUR_VIA="argument"; return 0
        fi
        add_err "--user-repo-path does not exist: $OPT_USER_REPO_PATH"; return 2
    fi
    cfg p userRepoPath
    p=$(expand_home "$p")
    if [ -n "$p" ]; then
        if [ -d "$p" ]; then RUR_PATH=$(strip_slash "$p"); RUR_VIA="config"; return 0; fi
        add_warn "config.json userRepoPath does not exist: $p"
    fi
    base="$OPT_REPOS_PATH"
    if [ -z "$base" ]; then cfg base reposPath; base=$(expand_home "$base"); fi
    if [ -z "$base" ]; then base="$HOME/repos"; fi
    base=$(strip_slash "$base")
    user="$OPT_GITHUB_USER"
    if [ -z "$user" ]; then cfg user githubUser; fi
    if [ -n "$user" ]; then
        p="$base/aitools-$user"
        if [ -d "$p" ]; then RUR_PATH="$p"; RUR_VIA="convention"; return 0; fi
        RUR_EXPECTED="$p"; return 1
    fi
    for d in "$base"/aitools-*; do
        [ -d "$d" ] || continue
        n="${d##*/}"
        [[ "$n" =~ ^aitools-[A-Za-z0-9-]+$ ]] || continue
        [ -f "$d/profile.json" ] || continue
        found="$d"; count=$((count + 1))
    done
    if [ "$count" -eq 1 ]; then
        add_warn "githubUser unknown -- used the only dotprofile under $base"
        RUR_PATH="$found"; RUR_VIA="scan"; return 0
    fi
    if [ "$count" -gt 1 ]; then
        add_warn "githubUser unknown and $count aitools-* repos with profile.json under $base"
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Which machine profile (reference/user-repo.md "Which machine profile"; re-key
# design section b), first decisive step wins:
#   1 override (--alias, AITOOLS_MACHINE_ALIAS): a profiles key (ignoring
#     case), else an alias field; one alias on two profiles = error  via=override
#   2 environment claude-code-web: key environment:claude-code-web
#     (legacy: the profile whose machine.environment matches)         via=environment
#   3 profiles[<this machine's id>] (legacy: the alias-keyed profile
#     whose machine.id equals it; warns: migrate)                     via=id
#   4 config.json machineId, only when this machine's id is unknown  via=config
#   4L config.json machineAlias naming an alias-keyed profile without
#     machine.id (legacy cache; skipped when config.json has machineId) via=alias
#   5 hostname (legacy; warns)                                        via=hostname
#   6 none: error; never another profile's values
# Sets RM_KEY, RM_ALIAS, RM_VIA, RM_OWNER, RM_LEGACY, RM_OVERRIDE_SOURCE and the
# RM_ profile values. Returns 0 resolved, 2 no match or error.
# ---------------------------------------------------------------------------
RM_KEY=""; RM_ALIAS=""; RM_VIA="none"; RM_OWNER="absent"; RM_LEGACY=false; RM_OVERRIDE_SOURCE=""; RM_KIND=""
RM_NAME=""; RM_COMPANY=""; RM_GIT_NAME=""; RM_GIT_EMAIL=""; RM_GITHUB=""

# Profile entries (objects only), in file order. E_KIND: id (key equals its
# machine.id, ignoring case), env (key environment:<name>), legacy (keyed by
# alias). E_ALIAS: the alias field, else the key.
E_N=0
E_KEY=(); E_KEYLC=(); E_ALIAS=(); E_ALIASLC=(); E_MID=(); E_MIDLC=(); E_ENV=(); E_KIND=(); E_HASALIAS=()

# looks_like_id TEXT -- 0 when TEXT has the shape of a machine id (a UUID, as
# IOPlatformUUID and MachineGuid, or 32 hex digits, as /etc/machine-id)
looks_like_id() {
    local s
    s=$(lc "$1")
    [[ "$s" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || [[ "$s" =~ ^[0-9a-f]{32}$ ]]
}

# load_entries PF -- fill the E_ arrays; warns about entries that are not objects
load_entries() {
    local pf="$1" all k t al mid menv kind ignored=false
    E_N=0; E_KEY=(); E_KEYLC=(); E_ALIAS=(); E_ALIASLC=(); E_MID=(); E_MIDLC=(); E_ENV=(); E_KIND=(); E_HASALIAS=()
    jlist all keys "$pf" profiles
    while IFS= read -r k; do
        [ -n "$k" ] || continue
        jtype t "$pf" profiles "$k"
        if [ "$t" != "object" ]; then ignored=true; continue; fi
        jread al "$pf" profiles "$k" alias
        jread mid "$pf" profiles "$k" machine id
        jread menv "$pf" profiles "$k" machine environment
        E_KEY[E_N]="$k"; E_KEYLC[E_N]=$(lc "$k"); E_MID[E_N]="$mid"; E_MIDLC[E_N]=$(lc "$mid"); E_ENV[E_N]="$menv"
        E_HASALIAS[E_N]=false
        if [ -n "$al" ]; then E_ALIAS[E_N]="$al"; E_HASALIAS[E_N]=true; else E_ALIAS[E_N]="$k"; fi
        E_ALIASLC[E_N]=$(lc "${E_ALIAS[E_N]}")
        kind=legacy
        case "${E_KEYLC[E_N]}" in environment:*) kind=env ;; esac
        if [ "$kind" = "legacy" ] && [ -n "$mid" ] && [ "${E_MIDLC[E_N]}" = "${E_KEYLC[E_N]}" ]; then kind=id; fi
        E_KIND[E_N]="$kind"
        E_N=$((E_N + 1))
    done <<< "$all"
    if $ignored; then add_warn "profile.json has profile entries that are not objects -- ignored"; fi
}

# keys_csv I... -- the keys of entries I, ", "-separated
keys_csv() {
    local i out=""
    for i in "$@"; do out="${out:+$out, }${E_KEY[i]}"; done
    printf '%s' "$out"
}
# alias_csv -- every entry's alias, ", "-separated (in file order)
alias_csv() {
    local i=0 out=""
    while [ "$i" -lt "$E_N" ]; do out="${out:+$out, }${E_ALIAS[i]}"; i=$((i + 1)); done
    printf '%s' "$out"
}

# entry_owner I VIA -- this | other | unregistered | unknown: whose profile entry I
# is (unknown: it has a machine.id, but this machine's id cannot be detected)
entry_owner() {
    local i="$1" via="$2"
    if [ "${E_KIND[i]}" = "env" ]; then
        if [ "${E_KEYLC[i]}" = "environment:$THIS_ENV" ]; then printf 'this'; else printf 'other'; fi
        return 0
    fi
    if [ "$via" = "environment" ]; then printf 'this'; return 0; fi
    if [ -z "${E_MID[i]}" ]; then
        if [ "${E_KIND[i]}" = "legacy" ] && [ -n "$THIS_ID" ] && [ "${E_KEYLC[i]}" = "$(lc "$THIS_ID")" ]; then printf 'this'
        else printf 'unregistered'; fi
        return 0
    fi
    if [ -z "$THIS_ID" ]; then
        # This machine's id is unknown: only the cached key (config.json machineId) vouches for it
        if [ "$via" = "config" ]; then printf 'this'; else printf 'unknown'; fi
        return 0
    fi
    if [ "${E_MIDLC[i]}" = "$(lc "$THIS_ID")" ]; then printf 'this'; else printf 'other'; fi
}

# identity_values PF -- RM_ values from identity only (machine-independent)
identity_values() {
    local pf="$1" v
    jread v "$pf" identity name
    if $JREAD_FOUND; then RM_NAME="$v"; else jread RM_NAME "$pf" identity git name; fi
    jread RM_COMPANY "$pf" identity company
    jread RM_GIT_NAME "$pf" identity git name
    jread RM_GIT_EMAIL "$pf" identity git email
    jread RM_GITHUB "$pf" identity github
}

# profile_values PF KEY -- effective values: the profile's name/company win over identity
profile_values() {
    local pf="$1" k="$2" v
    identity_values "$pf"
    jread v "$pf" profiles "$k" name
    if $JREAD_FOUND; then RM_NAME="$v"; fi
    jread v "$pf" profiles "$k" company
    if $JREAD_FOUND; then RM_COMPANY="$v"; fi
}

# machine_done PF I VIA -- entry I is this run's profile: values, owner, warnings
machine_done() {
    local pf="$1" i="$2" via="$3" a j dups="" ndup=0 h names="" hit=false stored="" first=""
    RM_KEY="${E_KEY[i]}"; RM_ALIAS="${E_ALIAS[i]}"; RM_VIA="$via"; RM_KIND="${E_KIND[i]}"
    RM_OWNER=$(entry_owner "$i" "$via")
    RM_LEGACY=false
    if [ "${E_KIND[i]}" = "legacy" ]; then RM_LEGACY=true; fi
    profile_values "$pf" "$RM_KEY"
    a="$RM_ALIAS"
    if [ "$via" != "id" ] && [ "$via" != "environment" ] && [ "${E_KIND[i]}" != "env" ]; then
        if [ "$RM_OWNER" = "other" ] && [ -n "$THIS_ID" ]; then
            add_warn "profile \"$a\" is registered to another machine (machine.id ${E_MID[i]}, this machine $THIS_ID)"
        fi
        if [ "$via" != "hostname" ] && [ -n "$THIS_ID" ] && [ -z "${E_MID[i]}" ]; then
            add_warn "profile \"$a\" has no machine.id -- run: aitools user init (registers this machine)"
        fi
    fi
    # A cloned machine shares its id: a differing stored hostname is the only signal
    if [ "$via" = "id" ] && [ -n "$THIS_HOST" ]; then
        jread stored "$pf" profiles "$RM_KEY" machine hostname
        jlist names items "$pf" profiles "$RM_KEY" machine hostnames
        names="${stored}"$'\n'"${names}"
        while IFS= read -r h; do
            if [ -z "$h" ]; then continue; fi
            if [ -z "$first" ]; then first="$h"; fi
            if [ "$(short_host "$h")" = "$THIS_HOST" ]; then hit=true; break; fi
        done <<< "$names"
        if [ -n "$first" ] && ! $hit; then
            add_warn "profile \"$a\" was registered with hostname \"$first\", this machine is \"$THIS_HOST\" -- renamed (run: aitools user init to update it), or a clone that shares machine id $THIS_ID"
        fi
    fi
    # An alias on two profiles (allowed after an interactive confirm) warns on every run
    j=0
    while [ "$j" -lt "$E_N" ]; do
        if [ "${E_ALIAS[j]}" = "$a" ]; then dups="${dups:+$dups, }${E_KEY[j]}"; ndup=$((ndup + 1)); fi
        j=$((j + 1))
    done
    if [ "$ndup" -gt 1 ]; then add_warn "alias \"$a\" is used by $ndup machines ($dups)"; fi
    return 0
}

resolve_machine() {
    local pf="$1" config_id="$2" config_alias="$3" v t i idl hits="" n=0 kh="" kn=0 lh="" ln=0 names h idx
    RM_KEY=""; RM_ALIAS=""; RM_VIA="none"; RM_OWNER="absent"; RM_LEGACY=false; RM_OVERRIDE_SOURCE=""; RM_KIND=""
    jread v "$pf" version
    jtype t "$pf" profiles
    # Two states, two messages (callers tell them apart; PR #98 review m1)
    if [ "$v" != "2" ]; then add_err "profile.json is not v2"; return 2; fi
    if [ "$t" != "object" ]; then add_err "profile.json has no profiles object"; return 2; fi
    load_entries "$pf"
    if [ "$E_N" -eq 0 ]; then add_err "profile.json has no machine profiles"; return 2; fi

    local override="$OPT_ALIAS"
    if [ -n "$override" ]; then RM_OVERRIDE_SOURCE="argument"
    elif [ -n "${AITOOLS_MACHINE_ALIAS:-}" ]; then override="$AITOOLS_MACHINE_ALIAS"; RM_OVERRIDE_SOURCE="env"; fi
    if [ -n "$override" ]; then
        idl=$(lc "$override"); i=0
        while [ "$i" -lt "$E_N" ]; do
            if [ "${E_KEYLC[i]}" = "$idl" ]; then kh="$kh $i"; kn=$((kn + 1)); fi
            if [ "${E_ALIAS[i]}" = "$override" ]; then lh="$lh $i"; ln=$((ln + 1)); fi
            i=$((i + 1))
        done
        if [ "$kn" -eq 1 ]; then machine_done "$pf" $kh "override"; return 0; fi
        if [ "$kn" -gt 1 ]; then
            # shellcheck disable=SC2086  # index lists are space-separated integers
            add_err "override \"$override\" matches more than one profile key: $(keys_csv $kh)"; return 2
        fi
        if [ "$ln" -eq 1 ]; then machine_done "$pf" $lh "override"; return 0; fi
        if [ "$ln" -gt 1 ]; then
            # shellcheck disable=SC2086
            add_err "alias \"$override\" is used by more than one profile: $(keys_csv $lh) -- select one by its key"; return 2
        fi
        add_err "override alias \"$override\" not in profiles ($(alias_csv))"; return 2
    fi

    if [ "$THIS_ENV" = "claude-code-web" ]; then
        i=0
        while [ "$i" -lt "$E_N" ]; do
            if [ "${E_KEYLC[i]}" = "environment:claude-code-web" ]; then kh="$kh $i"; kn=$((kn + 1))
            elif [ "${E_KIND[i]}" != "env" ] && [ "${E_ENV[i]}" = "claude-code-web" ]; then lh="$lh $i"; ln=$((ln + 1)); fi
            i=$((i + 1))
        done
        if [ "$kn" -eq 1 ]; then machine_done "$pf" $kh "environment"; return 0; fi
        if [ "$ln" -eq 1 ]; then
            # shellcheck disable=SC2086
            add_warn "profile \"$(keys_csv $lh)\" is keyed by alias -- run: aitools-profile migrate (re-keys profiles by machine id)"
            machine_done "$pf" $lh "environment"; return 0
        fi
        if [ "$ln" -gt 1 ]; then
            # shellcheck disable=SC2086
            add_err "more than one claude-code-web profile: $(keys_csv $lh)"; return 2
        fi
        add_warn "no profile has machine.environment \"claude-code-web\""
    elif [ -n "$THIS_ID" ]; then
        idl=$(lc "$THIS_ID"); i=0
        while [ "$i" -lt "$E_N" ]; do
            if [ "${E_KEYLC[i]}" = "$idl" ]; then hits="$hits $i"; n=$((n + 1)); kn=$((kn + 1))
            elif [ -n "${E_MID[i]}" ] && [ "${E_MIDLC[i]}" = "$idl" ]; then hits="$hits $i"; n=$((n + 1)); fi
            i=$((i + 1))
        done
        if [ "$n" -eq 1 ]; then
            idx=$hits
            idx="${idx# }"
            if [ "$kn" -eq 0 ]; then
                add_warn "profile \"${E_KEY[idx]}\" is keyed by alias -- run: aitools-profile migrate (re-keys profiles by machine id)"
            elif [ -n "${E_MID[idx]}" ] && [ "${E_MIDLC[idx]}" != "$idl" ]; then
                add_warn "profile key \"${E_KEY[idx]}\" disagrees with its machine.id \"${E_MID[idx]}\" -- fix profile.json by hand"
            fi
            if [ -n "$config_id" ] && [ "$(lc "$config_id")" != "${E_KEYLC[idx]}" ]; then
                add_warn "config.json machineId \"$config_id\" disagrees with machine.id match \"${E_KEY[idx]}\" -- machine.id wins"
            elif [ -z "$config_id" ] && [ -n "$config_alias" ] && [ "$config_alias" != "${E_ALIAS[idx]}" ] && [ "$config_alias" != "${E_KEY[idx]}" ]; then
                add_warn "config.json machineAlias \"$config_alias\" disagrees with machine.id match \"${E_ALIAS[idx]}\" -- machine.id wins"
            fi
            machine_done "$pf" "$idx" "id"; return 0
        fi
        if [ "$n" -gt 1 ]; then
            # shellcheck disable=SC2086
            add_err "machine.id $THIS_ID is registered on more than one profile: $(keys_csv $hits)"; return 2
        fi
    fi

    # 4: the cached key, only when this machine's id cannot be detected
    if [ "$THIS_ENV" != "claude-code-web" ] && [ -z "$THIS_ID" ] && [ -n "$config_id" ]; then
        idl=$(lc "$config_id"); i=0; hits=""; n=0
        while [ "$i" -lt "$E_N" ]; do
            if [ "${E_KEYLC[i]}" = "$idl" ]; then hits="$hits $i"; n=$((n + 1)); fi
            i=$((i + 1))
        done
        if [ "$n" -eq 1 ]; then machine_done "$pf" $hits "config"; return 0; fi
        add_warn "config.json machineId \"$config_id\" not in profiles -- ignored"
    fi

    # 4L: legacy cache (config.json machineAlias names an alias-keyed profile)
    if [ -z "$config_id" ] && [ -n "$config_alias" ]; then
        i=0; idx=""
        while [ "$i" -lt "$E_N" ]; do
            if [ "${E_KIND[i]}" = "legacy" ] && [ "${E_KEY[i]}" = "$config_alias" ]; then idx="$i"; break; fi
            i=$((i + 1))
        done
        if [ -n "$idx" ]; then
            if [ -n "${E_MID[idx]}" ] && [ -n "$THIS_ID" ] && [ "${E_MIDLC[idx]}" != "$(lc "$THIS_ID")" ]; then
                add_warn "config.json machineAlias \"$config_alias\" names a profile registered to another machine (machine.id ${E_MID[idx]}) -- ignored"
            else
                machine_done "$pf" "$idx" "alias"; return 0
            fi
        else
            add_warn "config.json machineAlias \"$config_alias\" not in profiles ($(alias_csv))"
        fi
    fi

    hits=""; n=0
    if [ -n "$THIS_HOST" ]; then
        i=0
        while [ "$i" -lt "$E_N" ]; do
            jread v "$pf" profiles "${E_KEY[i]}" machine hostname
            jlist names items "$pf" profiles "${E_KEY[i]}" machine hostnames
            names="${v}"$'\n'"${names}"
            while IFS= read -r h; do
                if [ -n "$h" ] && [ "$(short_host "$h")" = "$THIS_HOST" ]; then
                    hits="$hits $i"; n=$((n + 1)); break
                fi
            done <<< "$names"
            i=$((i + 1))
        done
    fi
    if [ "$n" -eq 1 ]; then
        add_warn "matched by hostname only (legacy) -- run: aitools user init (registers machine.id)"
        machine_done "$pf" $hits "hostname"; return 0
    fi
    if [ "$n" -gt 1 ]; then
        # shellcheck disable=SC2086
        add_err "hostname matches more than one profile: $(keys_csv $hits)"; return 2
    fi
    add_err "no profile matches this machine (machine.id ${THIS_ID:-unavailable}, hostname ${THIS_HOST:-unavailable}) -- run: aitools user init"
    return 2
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
cmd_user_repo_path() {
    load_config
    local rc=0
    resolve_user_repo || rc=$?
    if $OPT_PLAIN; then
        local line
        while IFS= read -r line; do if [ -n "$line" ]; then printf 'warning: %s\n' "$line" >&2; fi; done <<< "$WARN_LINES"
        while IFS= read -r line; do if [ -n "$line" ]; then printf '%s\n' "$line" >&2; fi; done <<< "$ERR_LINES"
        log_detail "user-repo-path path=$RUR_PATH via=$RUR_VIA exit=$rc"
        if [ "$rc" -eq 0 ]; then printf '%s\n' "$RUR_PATH"; fi
        exit "$rc"
    fi
    put path "$RUR_PATH"
    put via "$RUR_VIA"
    put expected "$RUR_EXPECTED"
    finish "$rc"
}

cmd_machine_id() {
    detect_machine_id
    if [ -n "$THIS_ID_ERROR" ] || [ -z "$THIS_ID" ]; then
        log_detail "machine-id error: ${THIS_ID_ERROR:-empty id}"
        printf 'aitools-profile: %s\n' "${THIS_ID_ERROR:-empty machine id}" >&2
        exit 2
    fi
    log_detail "machine-id source=$THIS_ID_SOURCE"
    printf '%s\n' "$THIS_ID"
    exit 0
}

cmd_hostname() {
    detect_hostname
    if [ -n "$THIS_HOST_ERROR" ] || [ -z "$THIS_HOST" ]; then
        log_detail "hostname error: ${THIS_HOST_ERROR:-empty hostname}"
        printf 'aitools-profile: %s\n' "${THIS_HOST_ERROR:-empty hostname}" >&2
        exit 2
    fi
    printf '%s\n' "$THIS_HOST"
    exit 0
}

# put_machine_lines -- the shared tail of resolve and derive-config
put_identity_lines() {
    put name "$RM_NAME"
    put company "$RM_COMPANY"
    put gitName "$RM_GIT_NAME"
    put gitEmail "$RM_GIT_EMAIL"
    put github "$RM_GITHUB"
}

# detect_this_machine -- machine id + hostname, unavailability reported as warnings
detect_this_machine() {
    detect_machine_id
    detect_hostname
    if [ -n "$THIS_ID_ERROR" ]; then add_warn "machine id unavailable: $THIS_ID_ERROR"; fi
    if [ -n "$THIS_HOST_ERROR" ]; then add_warn "hostname unavailable: $THIS_HOST_ERROR"; fi
}

# locate_profile -- PF = the profile.json to read: --profile, else AITOOLS_PROFILE_FILE,
# else <dotprofile>/profile.json. PF_FROM_ENV=true for AITOOLS_PROFILE_FILE (a
# read-only snapshot in generated deploy scripts). Returns 0 readable, 1 none
# (no dotprofile, or no profile.json in it: shared-only mode), 2 error.
PF=""; PF_FROM_ENV=false
locate_profile() {
    local repo_rc=0
    PF="${OPT_PROFILE:-${AITOOLS_PROFILE_FILE:-}}"; PF_FROM_ENV=false
    if [ -z "$OPT_PROFILE" ] && [ -n "${AITOOLS_PROFILE_FILE:-}" ]; then PF_FROM_ENV=true; fi
    if [ -n "$PF" ]; then
        if [ ! -f "$PF" ]; then
            if $PF_FROM_ENV; then add_err "profile file set but missing: $PF (AITOOLS_PROFILE_FILE)"
            else add_err "profile file set but missing: $PF"; fi
            return 2
        fi
    else
        resolve_user_repo || repo_rc=$?
        if [ "$repo_rc" -ne 0 ]; then return "$repo_rc"; fi
        PF="$RUR_PATH/profile.json"
    fi
    jcheck "$PF"
    case "$JCHECK_STATE" in
        missing) add_warn "profile.json not found: $PF"; return 1 ;;
        invalid) add_err "$JCHECK_MSG"; return 2 ;;
    esac
    return 0
}

# put_match -- the machine fields of a resolution (key, owner, legacy)
put_match() { put key "$RM_KEY"; put owner "$RM_OWNER"; put legacy "$RM_LEGACY"; }

# resolve_this PF -- resolve_machine with the config.json cache values
resolve_this() {
    local config_id="" config_alias=""
    cfg config_id machineId
    cfg config_alias machineAlias
    resolve_machine "$1" "$config_id" "$config_alias"
}

cmd_resolve() {
    load_config
    detect_this_machine
    local rc=0
    put_head() {
        put alias "$RM_ALIAS"; put via "$RM_VIA"; put_match; put environment "$THIS_ENV"
        put machineId "$THIS_ID"; put hostname "$THIS_HOST"; put profileFile "$PF"
        put userRepoPath "$RUR_PATH"; put userRepoVia "$RUR_VIA"
    }
    locate_profile || rc=$?
    if [ "$rc" -ne 0 ]; then put_head; put_identity_lines; finish "$rc"; fi
    resolve_this "$PF" || rc=$?
    # No machine match: report identity-level values only (never another profile's)
    if [ -z "$RM_KEY" ]; then identity_values "$PF"; fi
    put_head
    put_identity_lines
    finish "$rc"
}

# ---------------------------------------------------------------------------
# Tool exceptions (reference/tool-support-decision-tree.md section 8; storage
# shape in reference/user-repo.md "Profile Schema"). Location:
# profiles.<key>.toolExceptions.<slug>, <key> = this machine's resolved profile
# (its machine id; a legacy alias key until `migrate`).
# exception-get returns the stored entry; matching it against the detected
# install (platform, method, path unless versionedPath) is the caller's job,
# because it needs the registry.
# ---------------------------------------------------------------------------
check_slug() {
    if [ -z "$OPT_SLUG" ]; then usage_error "$CMD needs --slug"; fi
    if ! [[ "$OPT_SLUG" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then usage_error "invalid slug: $OPT_SLUG"; fi
}

cmd_exception_get() {
    check_slug
    load_config
    detect_this_machine
    local rc=0 t="" found=false decision=""
    local e_platform="" e_method="" e_path="" e_version="" e_at="" e_by="" e_reason=""
    put_exc() {
        put slug "$OPT_SLUG"; put alias "$RM_ALIAS"; put via "$RM_VIA"; put_match; put profileFile "$PF"
        put found "$found"; put platform "$e_platform"; put method "$e_method"; put path "$e_path"
        put version "$e_version"; put decidedAt "$e_at"; put decidedBy "$e_by"; put reason "$e_reason"
    }
    locate_profile || rc=$?
    if [ "$rc" -ne 0 ]; then put_exc; finish "$rc"; fi
    resolve_this "$PF" || rc=$?
    if [ "$rc" -ne 0 ]; then put_exc; finish "$rc"; fi
    local k="$RM_KEY"
    jtype t "$PF" profiles "$k" toolExceptions "$OPT_SLUG"
    # Never another machine's decision (R18): only this machine's profile counts
    if [ -n "$t" ] && [ "$RM_OWNER" != "this" ]; then
        add_warn "toolExceptions.$OPT_SLUG in profile \"$RM_ALIAS\" is not this machine's (owner $RM_OWNER) -- ignored"
        t=""
    fi
    if [ "$t" = "object" ]; then
        jread decision "$PF" profiles "$k" toolExceptions "$OPT_SLUG" decision
        if [ "$decision" = "keep" ]; then
            found=true
            jread e_platform "$PF" profiles "$k" toolExceptions "$OPT_SLUG" detected platform
            jread e_method "$PF" profiles "$k" toolExceptions "$OPT_SLUG" detected method
            jread e_path "$PF" profiles "$k" toolExceptions "$OPT_SLUG" detected path
            jread e_version "$PF" profiles "$k" toolExceptions "$OPT_SLUG" detected version
            jread e_at "$PF" profiles "$k" toolExceptions "$OPT_SLUG" decidedAt
            jread e_by "$PF" profiles "$k" toolExceptions "$OPT_SLUG" decidedBy
            jread e_reason "$PF" profiles "$k" toolExceptions "$OPT_SLUG" reason
        else
            add_warn "toolExceptions.$OPT_SLUG in profile \"$RM_ALIAS\" has decision \"$decision\" (only \"keep\" is defined) -- ignored"
        fi
    elif [ -n "$t" ]; then
        add_warn "toolExceptions.$OPT_SLUG in profile \"$RM_ALIAS\" is not an object -- ignored"
    fi
    put_exc
    finish 0
}

# commit_profile DIR MESSAGE -- commit only profile.json in the dotprofile and push
# (N-Q2: dotprofile writes auto-commit and push). Failures are warnings: the file
# is already written; the user can commit by hand. Sets COMMITTED / PUSHED.
COMMITTED=false; PUSHED=false
# profile_dirty_before DIR -- 0 when profile.json has uncommitted changes in git
# (checked BEFORE this command writes, so an unrelated hand edit is not committed
# under this command's message); 1 when clean, untracked or not a repository.
profile_dirty_before() {
    local dir="$1" rc=0
    command -v git >/dev/null 2>&1 || return 1
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1  # not a repo: handled by commit_profile
    git -C "$dir" ls-files --error-unmatch -- profile.json >/dev/null 2>&1 || return 1  # untracked: nothing to protect
    git -C "$dir" diff --quiet -- profile.json || rc=$?
    if [ "$rc" -eq 0 ]; then git -C "$dir" diff --cached --quiet -- profile.json || rc=$?; fi
    [ "$rc" -ne 0 ]
}
commit_profile() {
    local dir="$1" msg="$2" dirty="$3" out rc=0
    COMMITTED=false; PUSHED=false
    if ! command -v git >/dev/null 2>&1; then
        add_warn "git not found -- profile.json written but not committed"; return 0
    fi
    out=$(git -C "$dir" rev-parse --is-inside-work-tree 2>&1) || rc=$?
    if [ "$rc" -ne 0 ] || [ "$out" != "true" ]; then
        add_warn "$dir is not a git repository -- profile.json written but not committed"; return 0
    fi
    if $dirty; then
        add_warn "profile.json had uncommitted changes before this write -- not committed automatically; review and commit profile.json in $dir by hand"
        return 0
    fi
    # No git identity on this machine yet (fresh machine): commit as the profile's
    # identity.git, the person the dotprofile belongs to. Empty = git's own error.
    local who=() gname="" gmail="" cur_name="" cur_mail=""
    cur_name=$(git -C "$dir" config user.name) || cur_name=""  # unset = exit 1; handled by the -z test
    cur_mail=$(git -C "$dir" config user.email) || cur_mail=""  # unset = exit 1; handled by the -z test
    if [ -z "$cur_name" ] || [ -z "$cur_mail" ]; then
        jread gname "$PF" identity git name
        jread gmail "$PF" identity git email
        if [ -n "$gname" ] && [ -n "$gmail" ]; then who=(-c "user.name=$gname" -c "user.email=$gmail"); fi
    fi
    out=$(git -C "$dir" add -- profile.json 2>&1) || rc=$?
    if [ "$rc" -eq 0 ]; then out=$(git -C "$dir" ${who[@]+"${who[@]}"} commit -m "$msg" -- profile.json 2>&1) || rc=$?; fi
    if [ "$rc" -ne 0 ]; then
        log_detail "git commit in $dir: $out"
        add_warn "dotprofile commit failed (exit $rc) -- commit profile.json in $dir by hand"; return 0
    fi
    COMMITTED=true
    # No prompts: GIT_TERMINAL_PROMPT covers https; BatchMode covers ssh (unless the
    # user already set GIT_SSH_COMMAND)
    local ssh_cmd="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"
    out=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="$ssh_cmd" git -C "$dir" push 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        log_detail "git push in $dir: $out"
        case "$out" in
            *rejected*|*non-fast-forward*|*fetch\ first*)
                add_warn "dotprofile push rejected (exit $rc): the remote has newer commits -- run git pull --rebase, then git push in $dir" ;;
            *)
                add_warn "dotprofile push failed (exit $rc) -- run git push in $dir" ;;
        esac
        return 0
    fi
    PUSHED=true
}

# backup_pf -- backup_file "$PF"; a failed backup is returned as a warning (the
# write goes ahead, config-file-safety.md: backup failures are non-fatal)
backup_pf() {
    backup_file "$PF"
    if [ "$BACKUP_FILE_OK" != "true" ]; then add_warn "could not back up $PF -- written without a backup"; fi
    return 0
}

# remove_tmp FILE -- delete a temp file; a failure is a warning, never silent
remove_tmp() {
    if [ -e "$1" ] && ! rm -f "$1"; then add_warn "could not remove $1"; fi
    return 0
}

cmd_exception_set() {
    check_slug
    case "$OPT_PLATFORM" in
        macos|linux|windows) : ;;
        *) usage_error "--platform must be macos, linux or windows" ;;
    esac
    if [ -z "$OPT_METHOD" ] || [ -z "$OPT_PATH" ] || [ -z "$OPT_BY" ]; then
        usage_error "exception-set needs --slug, --platform, --method, --path and --by"
    fi
    local o
    for o in "$OPT_METHOD" "$OPT_PATH" "$OPT_VERSION" "$OPT_BY" "$OPT_REASON" "$OPT_DECIDED_AT"; do
        case "$o" in *$'\t'*|*$'\n'*|*$'\r'*) usage_error "exception-set values must be one line (no tab or newline)" ;; esac
    done
    local at="$OPT_DECIDED_AT"
    if [ -z "$at" ]; then at=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi
    load_config
    detect_this_machine
    local rc=0 t="" before="" after="" state="created" tmp msg
    put_set() {
        put result "$state"; put slug "$OPT_SLUG"; put alias "$RM_ALIAS"; put via "$RM_VIA"; put_match
        put profileFile "$PF"; put committed "$COMMITTED"; put pushed "$PUSHED"
    }
    locate_profile || rc=$?
    if [ "$rc" -eq 1 ]; then state="refused"; add_err "no dotprofile profile.json -- run: aitools user init to remember tool choices"; put_set; finish 3; fi
    if [ "$rc" -ne 0 ]; then state="failed"; put_set; finish 2; fi
    if $PF_FROM_ENV; then
        state="refused"; add_err "profile from AITOOLS_PROFILE_FILE is a read-only snapshot -- not written"; put_set; finish 3
    fi
    rc=0
    resolve_this "$PF" || rc=$?
    # Writes need THIS machine's profile: profiles[<this id>] (a legacy alias-keyed
    # profile whose machine.id is this id is accepted; resolve warned "migrate"),
    # the environment profile, or an override naming one of those. A hostname,
    # cache (machineId/machineAlias) or another machine's profile is refused, or
    # this machine's choice would be recorded in -- and honoured by -- another
    # machine's profile.
    if [ "$rc" -ne 0 ]; then
        state="refused"; add_err "tool choice not saved -- run: aitools user init to remember tool choices"; put_set; finish 3
    fi
    if [ "$RM_VIA" = "hostname" ]; then
        state="refused"
        add_err "machine profile \"$RM_ALIAS\" matched by hostname only -- run: aitools user init to remember tool choices"
        put_set; finish 3
    fi
    if [ "$RM_VIA" = "config" ]; then
        state="refused"
        add_err "machine profile \"$RM_ALIAS\" matched by config.json machineId only (machine id unavailable) -- tool choice not saved"
        put_set; finish 3
    fi
    if [ "$RM_OWNER" != "this" ] || [ "$RM_VIA" = "alias" ]; then
        state="refused"
        add_err "machine profile \"$RM_ALIAS\" is not registered to this machine -- run: aitools user init to remember tool choices"
        put_set; finish 3
    fi
    local old_at="" k="$RM_KEY"
    jtype t "$PF" profiles "$k" toolExceptions "$OPT_SLUG"
    if [ -n "$t" ]; then
        state="updated"
        jsub before "$PF" profiles "$k" toolExceptions "$OPT_SLUG"
        jread old_at "$PF" profiles "$k" toolExceptions "$OPT_SLUG" decidedAt
    fi
    # An identical decision keeps its original timestamp (no commit, no push):
    # unless --decided-at is given, the first comparison uses the stored decidedAt.
    if [ -z "$OPT_DECIDED_AT" ] && [ -n "$old_at" ]; then at="$old_at"; fi
    if [ "${AITOOLS_DRY_RUN:-}" = "1" ]; then
        state="dry-run"; log_detail "[DRY RUN] would record toolExceptions.$OPT_SLUG in $PF"; put_set; finish 0
    fi
    tmp="$PF.tmp.$$"
    # write_entry AT -- build the entry with decidedAt AT into $tmp, validate it
    write_entry() {
        EDIT_OPS=""
        jtype t "$PF" profiles "$k" toolExceptions
        if [ "$t" != "object" ]; then edit_set json '{}' profiles "$k" toolExceptions; fi
        edit_set json '{}' profiles "$k" toolExceptions "$OPT_SLUG"
        edit_set string keep profiles "$k" toolExceptions "$OPT_SLUG" decision
        edit_set string "$OPT_PLATFORM" profiles "$k" toolExceptions "$OPT_SLUG" detected platform
        edit_set string "$OPT_METHOD" profiles "$k" toolExceptions "$OPT_SLUG" detected method
        edit_set string "$OPT_PATH" profiles "$k" toolExceptions "$OPT_SLUG" detected path
        edit_set string "$OPT_VERSION" profiles "$k" toolExceptions "$OPT_SLUG" detected version
        edit_set string "$1" profiles "$k" toolExceptions "$OPT_SLUG" decidedAt
        edit_set string "$OPT_BY" profiles "$k" toolExceptions "$OPT_SLUG" decidedBy
        if [ -n "$OPT_REASON" ]; then edit_set string "$OPT_REASON" profiles "$k" toolExceptions "$OPT_SLUG" reason
        else edit_set null "" profiles "$k" toolExceptions "$OPT_SLUG" reason; fi
        # Write path: temp -> validate -> backup -> move (config-file-safety.md)
        local wrc=0
        msg=$(printf '%s' "$EDIT_OPS" | pj edit "$PF" "$tmp" 2>&1) || wrc=$?
        if [ "$wrc" -ne 0 ]; then
            remove_tmp "$tmp"; state="failed"; add_err "exception-set failed: $msg"; put_set; finish 2
        fi
        jtype t "$tmp" profiles "$k" toolExceptions "$OPT_SLUG"
        if [ "$t" != "object" ]; then
            remove_tmp "$tmp"; state="failed"; add_err "validation failed: toolExceptions.$OPT_SLUG missing after write"; put_set; finish 2
        fi
        jsub after "$tmp" profiles "$k" toolExceptions "$OPT_SLUG"
    }
    write_entry "$at"
    if [ "$state" = "updated" ] && [ "$before" = "$after" ]; then
        remove_tmp "$tmp"; state="unchanged"; put_set; finish 0
    fi
    # A changed decision gets a fresh timestamp
    if [ -z "$OPT_DECIDED_AT" ] && [ "$at" = "$old_at" ]; then
        at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        write_entry "$at"
    fi
    local dirty=false
    if profile_dirty_before "$(dirname "$PF")"; then dirty=true; fi
    backup_pf
    if ! mv "$tmp" "$PF"; then
        remove_tmp "$tmp"; state="failed"; add_err "could not replace $PF"; put_set; finish 2
    fi
    log_detail "exception-set: toolExceptions.$OPT_SLUG ($OPT_PLATFORM $OPT_METHOD $OPT_PATH) written to $PF (profile $k, alias $RM_ALIAS)"
    commit_profile "$(dirname "$PF")" "Record tool exception: keep $OPT_SLUG ($OPT_METHOD) on $RM_ALIAS" "$dirty"
    put_set
    finish 0
}

cmd_derive_config() {
    load_config
    detect_machine_id
    detect_hostname
    if [ -n "$THIS_ID_ERROR" ]; then add_warn "machine id unavailable: $THIS_ID_ERROR"; fi
    if [ -n "$THIS_HOST_ERROR" ]; then add_warn "hostname unavailable: $THIS_HOST_ERROR"; fi
    local repo_rc=0 rc=0 d_gh="" d_urp="" d_id="" d_alias="" pf gh=""
    put_derived() {
        put derived.githubUser "$d_gh"; put derived.userRepoPath "$d_urp"; put derived.machineId "$d_id"
        put derived.machineAlias "$d_alias"
        put userRepoVia "$RUR_VIA"; put via "$RM_VIA"; put_match; put company "$RM_COMPANY"
        put machineId "$THIS_ID"; put hostname "$THIS_HOST"; put aliases "$(alias_csv)"
    }
    resolve_user_repo || repo_rc=$?
    if [ "$repo_rc" -eq 2 ]; then put_derived; finish 2; fi
    if [ "$repo_rc" -eq 1 ]; then
        add_warn "no dotprofile found -- only bootstrap keys written (shared-only mode)"
        d_gh="$OPT_GITHUB_USER"
        put_derived; finish 1
    fi
    # A value from an environment override is used for this run but not persisted:
    # config.json records the machine's own answer, not a test's or a caller's.
    if [ "$RUR_VIA" != "env" ]; then d_urp="$RUR_PATH"
    else add_warn "dotprofile from AITOOLS_USER_REPO_PATH -- not saved to config.json"; fi
    pf="$RUR_PATH/profile.json"
    jcheck "$pf"
    case "$JCHECK_STATE" in
        missing) add_warn "profile.json not found in $RUR_PATH"; d_gh="$OPT_GITHUB_USER"; put_derived; finish 1 ;;
        invalid) add_err "$JCHECK_MSG"; put_derived; finish 2 ;;
    esac
    gh="$OPT_GITHUB_USER"
    if [ -z "$gh" ]; then jread gh "$pf" identity github; fi
    if [ -z "$gh" ]; then cfg gh githubUser; fi
    d_gh="$gh"
    resolve_this "$pf" || rc=$?
    if [ -n "$RM_KEY" ]; then
        if [ "$RM_VIA" = "override" ] && [ "$RM_OVERRIDE_SOURCE" = "env" ]; then
            add_warn "machine alias from AITOOLS_MACHINE_ALIAS -- not saved to config.json"
        elif [ "$RM_VIA" = "hostname" ]; then
            # A hostname match is a legacy guess, not a registration: caching it would
            # turn it into via=alias on the next run (PR #76 review M1)
            add_warn "machine alias \"$RM_ALIAS\" matched by hostname only -- not saved to config.json"
        else
            # machineId: the matched key, only for this machine's id-keyed profile
            # (read back only when live id detection fails). machineAlias: display
            # value, and the legacy cache for an alias-keyed profile (step 4L).
            if [ "$RM_KIND" = "id" ] && [ "$RM_OWNER" = "this" ]; then d_id="$RM_KEY"; fi
            d_alias="$RM_ALIAS"
        fi
    else
        RM_COMPANY=""
    fi
    put_derived
    finish "$rc"
}

cmd_snapshot() {
    if [ -z "$OPT_PROFILE" ]; then usage_error "snapshot needs --profile"; fi
    jcheck "$OPT_PROFILE"
    case "$JCHECK_STATE" in
        missing) log_detail "snapshot: profile.json not found: $OPT_PROFILE"
                 printf 'aitools-profile: profile.json not found: %s\n' "$OPT_PROFILE" >&2; exit 1 ;;
        invalid) log_detail "snapshot: $JCHECK_MSG"
                 printf 'aitools-profile: %s\n' "$JCHECK_MSG" >&2; exit 2 ;;
    esac
    local out rc=0
    out=$(pj snapshot "$OPT_PROFILE") || rc=$?
    if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
        log_detail "snapshot failed (engine exit $rc)"
        printf 'aitools-profile: snapshot failed (engine exit %s)\n' "$rc" >&2; exit 2
    fi
    log_detail "snapshot of $OPT_PROFILE"
    printf '%s\n' "$out"
    exit 0
}

# edit_op LINE... -- append tab-separated edit operations (values must be one line)
EDIT_OPS=""
edit_set() {
    local type="$1" value="$2"; shift 2
    local segs="" s
    for s in "$@"; do segs="${segs}"$'\t'"${s}"; done
    EDIT_OPS="${EDIT_OPS}set"$'\t'"${type}"$'\t'"$(one_line "$value")${segs}"$'\n'
}

cmd_register() {
    if [ -z "$OPT_PROFILE" ] || [ -z "$OPT_OUT" ]; then
        usage_error "register needs --profile and --out"
    fi
    if [ -n "$OPT_ALIAS" ] && ! [[ "$OPT_ALIAS" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then usage_error "invalid alias: $OPT_ALIAS"; fi
    if [ -n "$OPT_ALIAS" ] && looks_like_id "$OPT_ALIAS"; then usage_error "invalid alias: $OPT_ALIAS (looks like a machine id)"; fi
    local o
    for o in "$OPT_NAME" "$OPT_COMPANY" "$OPT_SHELL" "$OPT_EMAIL" "$OPT_GITHUB_USER" "$OPT_CLAIM"; do
        case "$o" in *$'\t'*|*$'\n'*|*$'\r'*) usage_error "register values must be one line (no tab or newline)" ;; esac
    done
    local in="$OPT_PROFILE" state="created" before="" after="" v t ver os arch rc=0 msg mid=""
    local key="" src="" claimed="" alias="" owner="" owner_key="" i j idl
    put_reg() {
        put result "$state"; put key "$key"; put alias "$alias"; put owner "$owner"; put ownerKey "$owner_key"
        put claimed "$claimed"; put machineId "$THIS_ID"; put hostname "$THIS_HOST"
    }
    jcheck "$OPT_PROFILE"
    case "$JCHECK_STATE" in
        invalid) state="failed"; add_err "$JCHECK_MSG"; put_reg; finish 2 ;;
        missing)
            if ! $OPT_CREATE; then state="failed"; add_err "profile.json not found (use --create): $OPT_PROFILE"; put_reg; finish 1; fi
            in="-"
            edit_set number 2 version
            edit_set string "2.2" meta schemaRevision
            edit_set string "$OPT_GITHUB_USER" identity github
            edit_set string "$OPT_EMAIL" identity email
            if [ -n "$OPT_NAME" ]; then edit_set string "$OPT_NAME" identity name; fi
            if [ -n "$OPT_COMPANY" ]; then edit_set string "$OPT_COMPANY" identity company; fi
            edit_set string "$OPT_NAME" identity git name
            edit_set string "$OPT_EMAIL" identity git email
            edit_set json '{}' profiles ;;
    esac
    if [ "$in" != "-" ]; then
        jread ver "$in" version
        if [ "$ver" != "2" ]; then state="failed"; add_err "profile.json is not v2 -- migrate first"; put_reg; finish 2; fi
        jtype t "$in" profiles
        if [ "$t" != "object" ]; then edit_set json '{}' profiles; fi
    fi
    detect_hostname
    # The one key this command writes: this machine's id, lower-cased, or the
    # environment profile on claude-code-web (no stable id there)
    if [ "$THIS_ENV" = "claude-code-web" ]; then
        key="environment:claude-code-web"
    else
        detect_machine_id
        if [ -z "$THIS_ID" ]; then
            state="refused"
            add_err "no machine id: ${THIS_ID_ERROR:-empty machine id} -- a machine profile is keyed by this machine's id"
            put_reg; finish 3
        fi
        key=$(lc "$THIS_ID")
    fi
    E_N=0
    if [ "$in" != "-" ]; then load_entries "$in"; fi
    # This machine's entry: profiles[<key>] (any case), or a legacy alias-keyed entry
    # whose machine.id (machine.environment on claude-code-web) is this machine's
    local own="" leg="" nleg=0
    i=0
    while [ "$i" -lt "$E_N" ]; do
        if [ "${E_KEYLC[i]}" = "$key" ]; then
            if [ -n "$own" ]; then state="failed"; add_err "profiles has two keys for $key (${E_KEY[own]}, ${E_KEY[i]})"; put_reg; finish 2; fi
            own="$i"
        elif [ "${E_KIND[i]}" = "legacy" ]; then
            if { [ "$THIS_ENV" = "claude-code-web" ] && [ "${E_ENV[i]}" = "claude-code-web" ]; } \
                || { [ "$THIS_ENV" != "claude-code-web" ] && [ -n "${E_MID[i]}" ] && [ "${E_MIDLC[i]}" = "$key" ]; }; then
                leg="${leg:-$i}"; nleg=$((nleg + 1))
            fi
        fi
        i=$((i + 1))
    done
    local who="machine.id $THIS_ID"
    if [ "$THIS_ENV" = "claude-code-web" ]; then who="machine.environment claude-code-web"; fi
    if [ -n "$own" ] && [ "$nleg" -gt 0 ]; then
        state="failed"; add_err "$who is already registered on profile \"${E_KEY[leg]}\" -- run: aitools-profile migrate after removing the duplicate"; put_reg; finish 2
    fi
    if [ "$nleg" -gt 1 ]; then
        state="failed"; add_err "$who is already registered on profile \"${E_KEY[leg]}\" and another profile"; put_reg; finish 2
    fi
    if [ -n "$own" ]; then src="$own"
    elif [ -n "$leg" ]; then src="$leg"; claimed="${E_KEY[leg]}"; fi
    # --claim KEY (passed by user init only after the user picked KEY at a terminal):
    # move an alias-keyed profile that belongs to no machine under this machine's key
    if [ -n "$OPT_CLAIM" ]; then
        local c=""
        j=0
        while [ "$j" -lt "$E_N" ]; do
            if [ "${E_KEY[j]}" = "$OPT_CLAIM" ]; then c="$j"; break; fi
            j=$((j + 1))
        done
        if [ -z "$c" ]; then state="failed"; add_err "--claim: no profile \"$OPT_CLAIM\""; put_reg; finish 2; fi
        if [ -n "$src" ] && [ "$src" != "$c" ]; then
            state="failed"; add_err "--claim: this machine already has profile \"${E_KEY[src]}\""; put_reg; finish 2
        fi
        if [ "$src" != "$c" ]; then
            if [ "${E_KIND[c]}" != "legacy" ] || [ -n "${E_MID[c]}" ] || [ -n "${E_ENV[c]}" ]; then
                state="refused"; owner=$(entry_owner "$c" ""); owner_key="${E_KEY[c]}"
                add_err "--claim: profile \"$OPT_CLAIM\" is registered to another machine -- not claimed"
                put_reg; finish 4
            fi
            src="$c"; claimed="${E_KEY[c]}"
        fi
    fi
    # The alias: --alias, else this entry's alias, else the short hostname
    alias="$OPT_ALIAS"
    if [ -z "$alias" ] && [ -n "$src" ]; then alias="${E_ALIAS[src]}"; fi
    if [ -z "$alias" ]; then alias="$THIS_HOST"; fi
    if [ -z "$alias" ]; then state="failed"; add_err "no alias: pass --alias (hostname unavailable: ${THIS_HOST_ERROR:-empty})"; put_reg; finish 2; fi
    if ! [[ "$alias" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || looks_like_id "$alias"; then
        state="failed"; add_err "invalid alias: $alias (pass --alias)"; put_reg; finish 2
    fi
    # Another profile already answers to this alias (its alias field or its key,
    # ignoring case: laptop and Laptop are the same name to a person)
    local conf="" nconf=0
    idl=$(lc "$alias"); j=0
    while [ "$j" -lt "$E_N" ]; do
        if [ "$j" != "$src" ] && { [ "${E_ALIASLC[j]}" = "$idl" ] || [ "${E_KEYLC[j]}" = "$idl" ]; }; then
            conf="${conf:+$conf }$j"; nconf=$((nconf + 1))
        fi
        j=$((j + 1))
    done
    if [ "$nconf" -gt 0 ]; then
        j="${conf%% *}"
        owner_key="${E_KEY[j]}"
        owner=$(entry_owner "$j" "")
        # An alias this profile already has (a duplicate confirmed earlier) is not a new conflict
        if ! $OPT_ALLOW_DUP && ! { [ -n "$src" ] && [ "$alias" = "${E_ALIAS[src]}" ]; }; then
            state="refused"
            if [ "$owner" = "unregistered" ]; then
                add_err "alias \"$alias\" is used by profile $owner_key, which is not registered to any machine -- claim it (--claim $owner_key) or choose another alias"
            else
                add_err "alias \"$alias\" is used by another machine's profile ($owner_key) -- choose another alias, or confirm interactively (--allow-duplicate-alias)"
            fi
            put_reg; finish 4
        fi
        local keys_all
        # shellcheck disable=SC2086  # index list of integers
        keys_all=$(keys_csv $conf)
        add_warn "alias \"$alias\" is used by $((nconf + 1)) machines ($keys_all, $key)"
        owner=""; owner_key=""
    fi
    if [ -n "$src" ]; then
        state="updated"
        jsub before "$in" profiles "${E_KEY[src]}"
        # Re-key a claimed or differently-cased entry under this machine's key (position kept)
        if [ "${E_KEY[src]}" != "$key" ]; then
            EDIT_OPS="${EDIT_OPS}rename"$'\t'"${key}"$'\t'"profiles"$'\t'"${E_KEY[src]}"$'\n'
        fi
        if [ "$alias" != "${E_ALIAS[src]}" ] || { ! ${E_HASALIAS[src]} && [ -n "$claimed" ]; }; then
            if [ "$(lc "$alias")" != "$key" ]; then edit_set string "$alias" profiles "$key" alias; fi
        fi
    else
        edit_set string "$alias" profiles "$key" alias
    fi
    # Per-profile name/company only when neither the profile nor identity has one
    local has_prof has_ident
    if [ -n "$OPT_NAME" ]; then
        has_prof=false; has_ident=true
        if [ -n "$src" ]; then jread v "$in" profiles "${E_KEY[src]}" name; has_prof=$JREAD_FOUND; fi
        if [ "$in" != "-" ]; then jread v "$in" identity name; has_ident=$JREAD_FOUND; fi
        if ! $has_prof && ! $has_ident; then edit_set string "$OPT_NAME" profiles "$key" name; fi
    fi
    if [ -n "$OPT_COMPANY" ]; then
        has_prof=false; has_ident=true
        if [ -n "$src" ]; then jread v "$in" profiles "${E_KEY[src]}" company; has_prof=$JREAD_FOUND; fi
        if [ "$in" != "-" ]; then jread v "$in" identity company; has_ident=$JREAD_FOUND; fi
        if ! $has_prof && ! $has_ident; then edit_set string "$OPT_COMPANY" profiles "$key" company; fi
    fi
    if [ "$THIS_ENV" = "claude-code-web" ]; then
        edit_set string "claude-code-web" profiles "$key" machine environment
    else
        # machine.id repeats the key; an existing value differing only in case is kept
        if [ -n "$src" ]; then mid="${E_MID[src]}"; fi
        if [ -z "$mid" ] || [ "$(lc "$mid")" != "$key" ]; then edit_set string "$key" profiles "$key" machine id; fi
    fi
    # machine.hostname follows the live name unless it (or machine.hostnames) already
    # matches: a renamed machine clears the clone warning on its next registration
    local hnames="" hh hmatch=false
    if [ -n "$src" ]; then
        jread v "$in" profiles "${E_KEY[src]}" machine hostname
        jlist hnames items "$in" profiles "${E_KEY[src]}" machine hostnames
        hnames="${v}"$'\n'"${hnames}"
    fi
    while IFS= read -r hh; do
        if [ -n "$hh" ] && [ "$(short_host "$hh")" = "$THIS_HOST" ]; then hmatch=true; break; fi
    done <<< "$hnames"
    if ! $hmatch && [ -n "$THIS_HOST" ]; then edit_set string "$THIS_HOST" profiles "$key" machine hostname; fi
    case "$(uname -s)" in
        Darwin*) os="darwin" ;;
        Linux*)  os="linux" ;;
        *)       os=$(lc "$(uname -s)") ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             arch=$(uname -m) ;;
    esac
    edit_set string "$os" profiles "$key" machine os
    edit_set string "$arch" profiles "$key" machine arch
    if [ -n "$OPT_SHELL" ]; then edit_set string "$OPT_SHELL" profiles "$key" machine shell; fi
    msg=$(printf '%s' "$EDIT_OPS" | pj edit "$in" "$OPT_OUT" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then state="failed"; add_err "register failed: $msg"; put_reg; finish 2; fi
    jtype t "$OPT_OUT" profiles "$key"
    if [ "$t" != "object" ]; then state="failed"; add_err "validation failed: profile $key missing after write"; put_reg; finish 2; fi
    if [ "$THIS_ENV" != "claude-code-web" ]; then
        jread v "$OPT_OUT" profiles "$key" machine id
        if [ "$(lc "$v")" != "$key" ]; then state="failed"; add_err "validation failed: profiles.$key machine.id is \"$v\""; put_reg; finish 2; fi
    fi
    jsub after "$OPT_OUT" profiles "$key"
    if [ "$state" = "updated" ] && [ -z "$claimed" ] && [ "${E_KEY[src]}" = "$key" ] && [ "$before" = "$after" ]; then state="unchanged"; fi
    owner="this"
    put_reg
    finish 0
}

# ---------------------------------------------------------------------------
# migrate (re-key design section f): every alias-keyed profile with machine.id is
# renamed to that id, lower-cased (with machine.environment: environment:<name>),
# keeping its position; `alias` is set to the old key when the profile has none.
# Profiles with neither stay as they are (unclaimed; registration claims them).
# Two profiles with one id = error, nothing written. Write path: temp -> validate
# (every re-keyed profile's key = its machine.id) -> backup -> move, then commit
# only profile.json and push (N-Q2). The one command that changes profiles other
# than this machine's: a mechanical rename of keys, never of their contents.
# ---------------------------------------------------------------------------
cmd_migrate() {
    load_config
    local rc=0 state="unchanged" renamed="" unclaimed="" tmp msg i j t target v
    put_mig() {
        put result "$state"; put profileFile "$PF"; put renamed "$renamed"; put unclaimed "$unclaimed"
        put committed "$COMMITTED"; put pushed "$PUSHED"
    }
    locate_profile || rc=$?
    if [ "$rc" -eq 1 ]; then state="failed"; put_mig; finish 1; fi
    if [ "$rc" -ne 0 ]; then state="failed"; put_mig; finish 2; fi
    if $PF_FROM_ENV; then
        state="refused"; add_err "profile from AITOOLS_PROFILE_FILE is a read-only snapshot -- not written"; put_mig; finish 3
    fi
    jread v "$PF" version
    jtype t "$PF" profiles
    if [ "$v" != "2" ]; then state="failed"; add_err "profile.json is not v2"; put_mig; finish 2; fi
    if [ "$t" != "object" ]; then state="failed"; add_err "profile.json has no profiles object"; put_mig; finish 2; fi
    load_entries "$PF"
    # T_[i]: the key entry i ends up with
    local T_=()
    i=0
    while [ "$i" -lt "$E_N" ]; do
        target="${E_KEY[i]}"
        case "${E_KIND[i]}" in
            id|env) target="${E_KEYLC[i]}" ;;
            legacy)
                if [ -n "${E_MID[i]}" ] && looks_like_id "${E_KEY[i]}"; then
                    # A key that is itself an id but disagrees with machine.id: a hand
                    # edit; re-keying it could move this machine's key onto another id
                    state="failed"
                    add_err "profile key \"${E_KEY[i]}\" disagrees with its machine.id \"${E_MID[i]}\" -- fix profile.json by hand; nothing written"
                    put_mig; finish 2
                elif [ -n "${E_MID[i]}" ]; then target="${E_MIDLC[i]}"
                elif [ -n "${E_ENV[i]}" ]; then target="environment:$(lc "${E_ENV[i]}")"
                else
                    unclaimed="${unclaimed:+$unclaimed, }${E_KEY[i]}"
                    add_warn "profile \"${E_KEY[i]}\" has no machine.id -- left as is (aitools user init claims it)"
                fi ;;
        esac
        T_[i]="$target"
        i=$((i + 1))
    done
    # Two profiles that would share a key: nothing is written
    i=0
    while [ "$i" -lt "$E_N" ]; do
        j=$((i + 1))
        while [ "$j" -lt "$E_N" ]; do
            if [ "$(lc "${T_[i]}")" = "$(lc "${T_[j]}")" ]; then
                state="failed"
                add_err "profiles \"${E_KEY[i]}\" and \"${E_KEY[j]}\" would both be keyed \"${T_[i]}\" (one machine id on two profiles) -- nothing written"
                put_mig; finish 2
            fi
            j=$((j + 1))
        done
        i=$((i + 1))
    done
    EDIT_OPS=""
    i=0
    while [ "$i" -lt "$E_N" ]; do
        if [ "${T_[i]}" != "${E_KEY[i]}" ]; then
            renamed="${renamed:+$renamed, }${E_KEY[i]} -> ${T_[i]}"
            EDIT_OPS="${EDIT_OPS}rename"$'\t'"${T_[i]}"$'\t'"profiles"$'\t'"${E_KEY[i]}"$'\n'
            if [ "${E_KIND[i]}" = "legacy" ] && ! ${E_HASALIAS[i]}; then edit_set string "${E_KEY[i]}" profiles "${T_[i]}" alias; fi
        fi
        i=$((i + 1))
    done
    if [ -z "$renamed" ]; then put_mig; finish 0; fi
    if $OPT_DRY_RUN || [ "${AITOOLS_DRY_RUN:-}" = "1" ]; then
        state="dry-run"; log_detail "[DRY RUN] would re-key in $PF: $renamed"; put_mig; finish 0
    fi
    tmp="$PF.tmp.$$"
    rc=0
    msg=$(printf '%s' "$EDIT_OPS" | pj edit "$PF" "$tmp" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then remove_tmp "$tmp"; state="failed"; add_err "migrate failed: $msg"; put_mig; finish 2; fi
    jcheck "$tmp"
    if [ "$JCHECK_STATE" != "valid" ]; then remove_tmp "$tmp"; state="failed"; add_err "validation failed: $JCHECK_MSG"; put_mig; finish 2; fi
    i=0
    while [ "$i" -lt "$E_N" ]; do
        if [ "${T_[i]}" != "${E_KEY[i]}" ] && [ "${E_KIND[i]}" != "env" ]; then
            jtype t "$tmp" profiles "${T_[i]}"
            v=""
            case "${T_[i]}" in
                environment:*) jread v "$tmp" profiles "${T_[i]}" machine environment; v="environment:$(lc "$v")" ;;
                *) jread v "$tmp" profiles "${T_[i]}" machine id; v=$(lc "$v") ;;
            esac
            if [ "$t" != "object" ] || [ "$v" != "${T_[i]}" ]; then
                remove_tmp "$tmp"; state="failed"
                add_err "validation failed: profile \"${T_[i]}\" does not match its machine.id after the re-key"
                put_mig; finish 2
            fi
        fi
        i=$((i + 1))
    done
    local dirty=false
    if profile_dirty_before "$(dirname "$PF")"; then dirty=true; fi
    backup_pf
    if ! mv "$tmp" "$PF"; then
        remove_tmp "$tmp"; state="failed"; add_err "could not replace $PF"; put_mig; finish 2
    fi
    state="migrated"
    log_detail "migrate: re-keyed $renamed in $PF"
    commit_profile "$(dirname "$PF")" "Migrate machine profiles to id keys" "$dirty"
    put_mig
    finish 0
}

case "$CMD" in
    user-repo-path) cmd_user_repo_path ;;
    machine-id)     cmd_machine_id ;;
    hostname)       cmd_hostname ;;
    resolve)        cmd_resolve ;;
    derive-config)  cmd_derive_config ;;
    snapshot)       cmd_snapshot ;;
    register)       cmd_register ;;
    migrate)        cmd_migrate ;;
    exception-get)  cmd_exception_get ;;
    exception-set)  cmd_exception_set ;;
    "")             usage; exit 2 ;;
    *)              usage_error "unknown command: $CMD" ;;
esac
