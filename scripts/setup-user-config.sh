#!/usr/bin/env bash
# setup-user-config.sh -- the only writer of ~/.aitools/config.json (macOS/Linux)
#
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.sh (dotprofile path, GitHub user, machine alias and how it was
# chosen). NOT a writer of profile.json (machine registration is `aitools user
# init`). NOT an interactive prompt (callers prompt, then pass --machine-alias).
# NOT the settings.json sync (setup-user-settings). Consumed by: aitools-install.sh
# Step 5, `aitools user init`, and the `aitools` sync deploy list (first entry).
#
# Safe to re-run: unchanged inputs produce "verified" and no write.
# Platform: macOS/Linux. On Windows use setup-user-config.ps1.
# Reference: reference/user-repo.md "Config Schema" and "Resolution".
# Needs: perl (aitools-json.pl, aitools-profile.sh); no node (P-Q3).
#
# Managed fields: version, meta, reposPath, repoPath (from flags; kept when not passed),
#   googleDrives (from --drives-json when it is a non-empty array; else kept, or []),
#   githubUser, userRepoPath, machineAlias (derived; kept when
#   derivation is unavailable or fails)
# Preserved: all other keys, in place (key order kept)
# Write path: merge to temp -> validate -> backup_file -> mv.
#   A read, merge or validation failure leaves the existing file untouched.
#
# Usage: setup-user-config.sh [--repos-path P] [--repo-path P] [--drives-json JSON]
#          [--github-user U] [--user-repo-path P] [--machine-alias A] [--dry-run] [--help]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "setup-user-config"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use setup-user-config.ps1."
        exit 1 ;;
esac

usage() {
    cat <<'EOF'
setup-user-config.sh -- write ~/.aitools/config.json (the only writer)

Options:
  --repos-path P       Base directory for repos (bootstrap; installer Step 3)
  --repo-path P        Path to the aitools repo (bootstrap; installer)
  --drives-json JSON   Detected Google Drives, JSON array (installer Step 4)
  --github-user U      GitHub user; names the dotprofile aitools-<U> (user init)
  --user-repo-path P   Dotprofile path chosen by user init
  --machine-alias A    Profile alias chosen by user init (explicit choice)
  --dry-run            Show what would change; write nothing
  --help               This text

Without flags: re-derive userRepoPath / githubUser / machineAlias from profile.json.
EOF
}

REPOS_PATH_ARG=""; REPO_PATH_ARG=""; DRIVES_JSON="[]"; GH_USER_ARG=""; URP_ARG=""; ALIAS_ARG=""
DRY_RUN=false
if [ "${AITOOLS_DRY_RUN:-}" = "1" ]; then DRY_RUN=true; fi
bad_args() {
    log_error "$1 (see --help)"
    write_summary ERROR "aitools config" "bad arguments"
    exit 1
}
while [ $# -gt 0 ]; do
    case "$1" in
        --repos-path|--repo-path|--drives-json|--github-user|--user-repo-path|--machine-alias)
            if [ $# -lt 2 ]; then bad_args "$1 needs a value"; fi
            case "$1" in
                --repos-path)     REPOS_PATH_ARG="$2" ;;
                --repo-path)      REPO_PATH_ARG="$2" ;;
                --drives-json)    DRIVES_JSON="$2" ;;
                --github-user)    GH_USER_ARG="$2" ;;
                --user-repo-path) URP_ARG="$2" ;;
                --machine-alias)  ALIAS_ARG="$2" ;;
            esac
            shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --force)    shift ;;  # accepted for deploy-list parity; this script has no review menu
        --help|-h)  usage; exit 0 ;;
        *)          bad_args "Unknown option: $1" ;;
    esac
done
for v in "$REPOS_PATH_ARG" "$REPO_PATH_ARG" "$DRIVES_JSON" "$GH_USER_ARG" "$URP_ARG" "$ALIAS_ARG"; do
    case "$v" in *$'\t'*|*$'\n'*|*$'\r'*) bad_args "option values must be one line (no tab or newline)" ;; esac
done

CONFIG_DIR="$HOME/.aitools"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_TMP="${CONFIG_FILE}.tmp.$$"
PROFILE_SH="$SCRIPT_DIR/aitools-profile.sh"
JSON_PL="$SCRIPT_DIR/aitools-json.pl"
WORK_DIR=$(mktemp -d)
cleanup() { rm -rf "$WORK_DIR"; rm -f "$CONFIG_TMP"; }
trap cleanup EXIT

if ! command -v perl >/dev/null 2>&1; then
    log_error "perl not found -- config.json cannot be written (the harness manages perl: run aitools install)"
    write_summary ERROR "aitools config" "perl not found"
    exit 1
fi
for f in "$PROFILE_SH" "$JSON_PL"; do
    if [ ! -f "$f" ]; then
        log_error "Failed: $(display_path "$f") not found next to setup-user-config.sh -- config.json not written"
        write_summary ERROR "aitools config" "resolver missing"
        exit 1
    fi
done
pj() { perl "$JSON_PL" "$@"; }
mkdir -p "$CONFIG_DIR"

# --- 1. Derive values from profile.json (aitools-profile.sh derive-config) ---
derive_args=(derive-config --config "$CONFIG_FILE")
if [ -n "$REPOS_PATH_ARG" ]; then derive_args+=(--repos-path "$REPOS_PATH_ARG"); fi
if [ -n "$GH_USER_ARG" ]; then derive_args+=(--github-user "$GH_USER_ARG"); fi
if [ -n "$URP_ARG" ]; then derive_args+=(--user-repo-path "$URP_ARG"); fi
if [ -n "$ALIAS_ARG" ]; then derive_args+=(--alias "$ALIAS_ARG"); fi
DERIVE_RC=0
# exit code is the result: 0 derived, 1 no dotprofile, 2 no match / error
DERIVE_OUT=$(bash "$PROFILE_SH" "${derive_args[@]}" 2>"$WORK_DIR/derive.err") || DERIVE_RC=$?
while IFS= read -r line; do
    if [ -n "$line" ]; then log_detail "derive-config stderr: $line"; fi
done < "$WORK_DIR/derive.err"
D_GH=""; D_URP=""; D_ALIAS=""; U_VIA="none"; M_VIA="none"; D_COMPANY=""; D_ID=""; D_HOST=""; ALIASES=""
SEEN=false
NEED_INIT=false
# derive_warn TEXT -- resolver warnings about the cached config.json (or the
# expected shared-only state) are corrected or recorded by this write: info, so a
# successful write stays OK (D-TS12). The rest are real warnings.
derive_warn() {
    case "$1" in
        config.json\ *|*"not saved to config.json"*|"no dotprofile found"*|"githubUser unknown"*)
            log "config: $1 (handled by this write)" ;;
        *)
            log_warn "config: $1"
            case "$1" in *"run: aitools user init"*) NEED_INIT=true ;; esac ;;
    esac
}
while IFS=$'\t' read -r k v; do
    case "$k" in
        derived.githubUser)   D_GH="$v"; SEEN=true ;;
        derived.userRepoPath) D_URP="$v" ;;
        derived.machineAlias) D_ALIAS="$v" ;;
        userRepoVia)          U_VIA="$v" ;;
        via)                  M_VIA="$v" ;;
        company)              D_COMPANY="$v" ;;
        machineId)            D_ID="$v" ;;
        hostname)             D_HOST="$v" ;;
        aliases)              ALIASES="$v" ;;
        warn)                 derive_warn "$v" ;;
        error)                log_error "config: $v" ;;
    esac
done <<< "$DERIVE_OUT"
if ! $SEEN || [ "$DERIVE_RC" -gt 2 ]; then
    log_error "Failed: profile derivation produced no result (exit $DERIVE_RC) -- see $(display_path "$LOG_FILE")"
    write_summary ERROR "aitools config" "derivation failed"
    D_GH=""; D_URP=""; D_ALIAS=""; DERIVE_RC=2
else
    log "config: dotprofile=${D_URP:-none} via=$U_VIA machineAlias=${D_ALIAS:-none} via=$M_VIA company=$D_COMPANY id=${D_ID:-unavailable} host=${D_HOST:-unavailable}"
    case "$DERIVE_RC" in
        0) : ;;
        1) log "config: no dotprofile yet -- writing bootstrap keys only (shared-only mode)" ;;
        *) write_summary ERROR "machine profile" "no machine match"
           write_summary ACTION "" "Run: aitools user init (profiles: ${ALIASES:-none})" ;;
    esac
    if [ "$DERIVE_RC" -eq 0 ] && $NEED_INIT; then
        write_summary ACTION "" "Run: aitools user init (registers this machine)"
    fi
fi

# --- 2. Merge (read-then-merge; managed keys only) ---
CONFIG_INTENT_JSON='{"purpose":"Per-machine pointers that let aitools find its repos and this machine profile, built from profile.json","scope":"Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineAlias). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer","audience":"read_config_key/ReadConfigKey callers, resolve_user_repo_path/Resolve-UserRepoPath, ait-harvest.py, hh, check-lib; written by setup-user-config.sh/.ps1"}'

OPS=""
op_set() {  # op_set TYPE VALUE KEY...
    local type="$1" value="$2"; shift 2
    local segs="" s
    for s in "$@"; do segs="${segs}"$'\t'"${s}"; done
    OPS="${OPS}set"$'\t'"${type}"$'\t'"${value}${segs}"$'\n'
}
cfg_get() {  # cfg_get VAR KEY -- top-level string of the existing config ("" when absent)
    local __v="" __rc=0
    __v=$(pj get "$CONFIG_FILE" "$2") || __rc=$?
    if [ "$__rc" -ne 0 ]; then __v=""; fi
    printf -v "$1" '%s' "$__v"
}

CONFIG_STATE="updated"; CHECK_RC=0; IN="$CONFIG_FILE"; CORRUPT_REASON=""
CHECK_MSG=$(pj check "$CONFIG_FILE" 2>&1) || CHECK_RC=$?
case "$CHECK_RC" in
    0) CONFIG_STATE="updated" ;;
    1) CONFIG_STATE="created"; IN="-" ;;
    *)
        # Invalid JSON: rebuild from managed fields, salvaging known keys by pattern
        CONFIG_STATE="recovered"; IN="-"; CORRUPT_REASON="$CHECK_MSG"
        for k in reposPath repoPath githubUser userRepoPath machineAlias; do
            sv=$(perl -0777 -ne 'BEGIN { $k = shift @ARGV } if (/"\Q$k\E"\s*:\s*"((?:[^"\\\n]|\\.)*)"/) { $v = $1; $v =~ s/\\(["\\\/])/$1/g; print $v }' "$k" "$CONFIG_FILE") || sv=""  # unreadable = nothing salvaged
            if [ -n "$sv" ]; then op_set string "$sv" "$k"; log "Recovered $k from the invalid config"; fi
        done ;;
esac

EXISTING_URP=""
if [ "$IN" != "-" ]; then cfg_get EXISTING_URP userRepoPath; fi
op_set number 3 version
if [ -n "$REPOS_PATH_ARG" ]; then op_set string "$REPOS_PATH_ARG" reposPath; fi
if [ -n "$REPO_PATH_ARG" ]; then op_set string "$REPO_PATH_ARG" repoPath; fi
if printf '%s' "$DRIVES_JSON" | perl -0777 -ne 'exit(/\A\s*\[\s*[^\]\s]/ ? 0 : 1)'; then
    op_set json "$DRIVES_JSON" googleDrives
else
    DT=""
    if [ "$IN" != "-" ]; then DT=$(pj type "$CONFIG_FILE" googleDrives) || DT=""; fi  # absent = not an array
    if [ "$DT" != "array" ]; then op_set json '[]' googleDrives; fi
fi
if [ -n "$D_GH" ]; then op_set string "$D_GH" githubUser; fi
if [ -n "$D_URP" ]; then op_set string "$D_URP" userRepoPath; fi
if [ -n "$D_ALIAS" ]; then op_set string "$D_ALIAS" machineAlias; fi
DERIVED_FROM="bootstrap only"
if [ -n "$D_URP" ] || [ -n "$EXISTING_URP" ]; then DERIVED_FROM="profile.json"; fi
op_set json '{}' meta
op_set json "$CONFIG_INTENT_JSON" meta intent
op_set string "setup-user-config" meta writer
op_set string "$DERIVED_FROM" meta derivedFrom

MERGE_RC=0
MERGE_MSG=$(printf '%s' "$OPS" | pj edit "$IN" "$CONFIG_TMP" 2>&1) || MERGE_RC=$?
if [ "$MERGE_RC" -ne 0 ]; then
    log_detail "merge: $MERGE_MSG"
    log_error "Failed: $(display_path "$CONFIG_FILE"): config merge failed (exit $MERGE_RC) -- existing file left untouched"
    write_summary ERROR "aitools config" "merge failed"
else
    # Validation: valid object (checked by the engine on write) + bootstrap keys present
    MISSING=""
    for k in version reposPath repoPath; do
        KT=$(pj type "$CONFIG_TMP" "$k") || KT=""  # absent key = missing
        if [ -z "$KT" ]; then MISSING="${MISSING:+$MISSING, }$k"; fi
    done
    # Changed keys (meta excluded: it describes the file, not the machine)
    CHANGES=""
    for k in version reposPath repoPath googleDrives githubUser userRepoPath machineAlias; do
        a=""; b=""
        if [ "$IN" != "-" ]; then a=$(pj json "$CONFIG_FILE" "$k") || a=""; fi  # absent = (unset)
        b=$(pj json "$CONFIG_TMP" "$k") || b=""  # absent = (unset)
        if [ "$a" != "$b" ]; then CHANGES="${CHANGES}${k}: ${a:-(unset)} -> ${b:-(unset)}"$'\n'; fi
    done
    SAME=false
    if [ "$CONFIG_STATE" = "updated" ]; then
        A=$(pj json "$CONFIG_FILE") || A="a"
        B=$(pj json "$CONFIG_TMP") || B="b"
        if [ "$A" = "$B" ]; then SAME=true; fi
    fi
    if [ -n "$MISSING" ]; then
        log_error "Failed: $(display_path "$CONFIG_FILE"): missing bootstrap $MISSING (run aitools install) -- existing file left untouched"
        write_summary ERROR "aitools config" "missing bootstrap values"
    elif $SAME; then
        log_ok "Verified: $(display_path "$CONFIG_FILE") (unchanged)"
        write_summary OK "aitools config" "verified"
    elif $DRY_RUN; then
        log "[DRY RUN] Would write $(display_path "$CONFIG_FILE") ($CONFIG_STATE)"
        while IFS= read -r change; do
            if [ -n "$change" ]; then log "[DRY RUN]   $change"; fi
        done <<< "$CHANGES"
        write_summary OK "aitools config" "dry-run: would update"
    else
        backup_file "$CONFIG_FILE"
        if ! mv "$CONFIG_TMP" "$CONFIG_FILE"; then
            log_error "Failed: $(display_path "$CONFIG_FILE"): could not replace the config file"
            write_summary ERROR "aitools config" "write failed"
        else
            case "$CONFIG_STATE" in
                recovered)
                    log_warn "$(display_path "$CONFIG_FILE") was not valid JSON ($CORRUPT_REASON) -- rebuilt; the invalid copy was backed up"
                    write_summary WARN "aitools config" "rebuilt (was invalid)" ;;
                created)
                    log_ok "Created: $(display_path "$CONFIG_FILE")"
                    write_summary OK "aitools config" "created" ;;
                *)
                    log_ok "Updated: $(display_path "$CONFIG_FILE")"
                    write_summary OK "aitools config" "updated" ;;
            esac
            while IFS= read -r change; do
                if [ -n "$change" ]; then
                    log "  $change"
                    write_summary DETAIL "aitools config" "${change%%:*} updated"
                fi
            done <<< "$CHANGES"
        fi
    fi
fi

# --- Exit footer ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
