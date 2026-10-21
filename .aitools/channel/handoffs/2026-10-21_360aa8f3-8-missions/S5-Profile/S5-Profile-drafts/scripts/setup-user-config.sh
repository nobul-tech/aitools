#!/usr/bin/env bash
# setup-user-config.sh -- the only writer of ~/.aitools/config.json (macOS/Linux)
#
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.js (dotprofile path, GitHub user, machine alias and how it was
# chosen). NOT a writer of profile.json (machine registration is `aitools user
# init`). NOT an interactive prompt (callers prompt, then pass --machine-alias).
# NOT the settings.json sync (setup-user-settings). Consumed by: aitools-install.sh
# Step 5, `aitools user init`, and the `aitools` sync deploy list (first entry).
#
# Safe to re-run: unchanged inputs produce "verified" and no write.
# Platform: macOS/Linux. On Windows use setup-user-config.ps1.
# Reference: reference/user-repo.md "Config Schema" and "Resolution".
#
# Managed fields: version, meta, reposPath, repoPath (from flags; kept when not passed),
#   googleDrives (from --drives-json when it is a non-empty array; else kept, or []),
#   githubUser, userRepoPath, machineAlias (derived; kept when
#   derivation is unavailable or fails)
# Preserved: all other keys
# Write path: merge to temp -> validate_json_config -> backup_file -> mv.
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
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true
while [ $# -gt 0 ]; do
    case "$1" in
        --repos-path)     REPOS_PATH_ARG="${2:-}"; shift 2 ;;
        --repo-path)      REPO_PATH_ARG="${2:-}"; shift 2 ;;
        --drives-json)    DRIVES_JSON="${2:-[]}"; shift 2 ;;
        --github-user)    GH_USER_ARG="${2:-}"; shift 2 ;;
        --user-repo-path) URP_ARG="${2:-}"; shift 2 ;;
        --machine-alias)  ALIAS_ARG="${2:-}"; shift 2 ;;
        --dry-run)        DRY_RUN=true; shift ;;
        --force)          shift ;;  # accepted for deploy-list parity; no review menu here
        --help|-h)        usage; exit 0 ;;
        *) log_error "Unknown option: $1 (see --help)"; write_summary ERROR "aitools config" "bad arguments"; exit 1 ;;
    esac
done

CONFIG_DIR="$HOME/.aitools"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_TMP="${CONFIG_FILE}.tmp.$$"
mkdir -p "$CONFIG_DIR"

# --- 1. Derive values from profile.json (aitools-profile.js) ---
DERIVED_JSON="{}"
if command -v node >/dev/null 2>&1 && PROFILE_JS=$(_aitools_profile_js); then
    derive_args=(derive-config --config "$CONFIG_FILE" --environment "$AITOOLS_ENVIRONMENT")
    [ -n "$REPOS_PATH_ARG" ] && derive_args+=(--repos-path "$REPOS_PATH_ARG")
    [ -n "$GH_USER_ARG" ] && derive_args+=(--github-user "$GH_USER_ARG")
    [ -n "$URP_ARG" ] && derive_args+=(--user-repo-path "$URP_ARG")
    [ -n "$ALIAS_ARG" ] && derive_args+=(--alias "$ALIAS_ARG")
    DERIVE_RC=0
    # exit code is the result: 0 derived, 1 no dotprofile, 2 no match / error
    DERIVE_OUT=$(node "$PROFILE_JS" "${derive_args[@]}") || DERIVE_RC=$?
    if [ -z "$DERIVE_OUT" ]; then
        log_error "Failed: profile derivation produced no output (exit $DERIVE_RC)"
        write_summary ERROR "aitools config" "derivation failed"
        DERIVE_OUT='{"derived":{},"warnings":[],"errors":[]}'
        DERIVE_RC=2
    fi
    # Report warnings/errors and extract the derived object (one node call)
    REPORT=$(node -e '
        const o = JSON.parse(process.argv[1]);
        for (const w of o.warnings || []) console.log("warn\t" + w);
        for (const e of o.errors || []) console.log("error\t" + e);
        console.log("derived\t" + JSON.stringify(o.derived || {}));
        console.log("aliases\t" + (o.aliases || []).join(", "));
        const d = o.derived || {};
        console.log("summary\tdotprofile=" + (d.userRepoPath || "none") + " via=" + (o.userRepoVia || "none") +
            " machineAlias=" + (d.machineAlias || "none") + " via=" + (o.via || "none") +
            " company=" + (o.company || "") + " id=" + (o.machineId || "unavailable") + " hosts=" + (o.hostnames || []).join("/"));
    ' "$DERIVE_OUT") || { log_error "Failed: could not parse derivation output"; write_summary ERROR "aitools config" "derivation unreadable"; REPORT=""; DERIVE_RC=2; }
    ALIASES=""
    while IFS=$'\t' read -r k v; do
        case "$k" in
            warn)    log_warn "config: $v" ;;
            error)   log_error "config: $v" ;;
            derived) DERIVED_JSON="$v" ;;
            aliases) ALIASES="$v" ;;
            summary) log "config: $v" ;;
        esac
    done <<< "$REPORT"
    case "$DERIVE_RC" in
        0) : ;;
        1) log "config: no dotprofile yet -- writing bootstrap keys only (shared-only mode)" ;;
        *) write_summary ERROR "machine profile" "no machine match"
           write_summary ACTION "" "Run: aitools user init (profiles: ${ALIASES:-none})" ;;
    esac
elif ! command -v node >/dev/null 2>&1; then
    log_warn "config: node not available -- profile derivation skipped (node arrives in installer Step 8)"
    write_summary WARN "aitools config" "derivation skipped (no node)"
else
    log_error "config: aitools-profile.js not found next to aitools-lib.sh"
    write_summary ERROR "aitools config" "resolver missing"
fi

# --- 2. Merge (read-then-merge; managed keys only) ---
# read -d '' returns 1 at end of input by design; the -n check below is the result check
read -r -d '' CONFIG_MERGE_JS <<'CONFIGJS' || true
const fs = require('fs');
const [file, tmp, reposPath, repoPath, drivesJson, derivedJson, intentJson] = process.argv.slice(1);
let raw = null;
try {
    raw = fs.readFileSync(file, 'utf8');
    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
} catch (e) {
    if (e.code !== 'ENOENT') { console.log('ERROR:read ' + e.message); process.exit(2); }
}
let cfg = {};
let state = 'created';
if (raw !== null) {
    try {
        cfg = JSON.parse(raw);
        if (cfg === null || typeof cfg !== 'object' || Array.isArray(cfg)) throw new Error('top level is not an object');
        state = 'updated';
    } catch (e) {
        console.log('CORRUPT:' + e.message);
        cfg = {};
        for (const k of ['userRepoPath', 'machineAlias', 'githubUser', 'reposPath', 'repoPath']) {
            const m = raw.match(new RegExp('"' + k + '"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"'));
            if (m) { cfg[k] = JSON.parse('"' + m[1] + '"'); console.log('RECOVERED:' + k); }
        }
        state = 'recovered';
    }
}
let drives, derived, intent;
try { drives = JSON.parse(drivesJson); derived = JSON.parse(derivedJson); intent = JSON.parse(intentJson); }
catch (e) { console.log('ERROR:input ' + e.message); process.exit(3); }
const next = Object.assign({}, cfg);
next.version = 3;
if (reposPath) next.reposPath = reposPath;
if (repoPath) next.repoPath = repoPath;
if (Array.isArray(drives) && drives.length > 0) next.googleDrives = drives;
else if (!Array.isArray(next.googleDrives)) next.googleDrives = [];
for (const k of ['githubUser', 'userRepoPath', 'machineAlias']) {
    if (typeof derived[k] === 'string' && derived[k]) next[k] = derived[k];
}
next.meta = { intent: intent, writer: 'setup-user-config', derivedFrom: next.userRepoPath ? 'profile.json' : 'bootstrap only' };
const managed = ['version', 'meta', 'reposPath', 'repoPath', 'googleDrives', 'githubUser', 'userRepoPath', 'machineAlias'];
for (const k of managed) {
    const a = JSON.stringify(cfg[k]), b = JSON.stringify(next[k]);
    if (a !== b && k !== 'meta') console.log('CHANGED:' + k + ': ' + (a === undefined ? '(unset)' : a) + ' -> ' + (b === undefined ? '(unset)' : b));
}
if (state === 'updated' && JSON.stringify(next) === JSON.stringify(cfg)) { console.log('RESULT:unchanged'); process.exit(0); }
const missing = ['reposPath', 'repoPath'].filter(k => !next[k]);
if (missing.length) { console.log('ERROR:missing bootstrap ' + missing.join(', ') + ' (run aitools install)'); process.exit(4); }
fs.writeFileSync(tmp, JSON.stringify(next, null, 2) + '\n');
const v = JSON.parse(fs.readFileSync(tmp, 'utf8'));
const vm = ['version', 'reposPath', 'repoPath'].filter(k => !(k in v));
if (vm.length) { console.log('ERROR:validation missing ' + vm.join(', ')); process.exit(4); }
console.log('RESULT:' + state);
CONFIGJS

CONFIG_INTENT_JSON='{"purpose":"Per-machine pointers that let aitools find its repos and this machine profile, built from profile.json","scope":"Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineAlias). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer","audience":"read_config_key/ReadConfigKey callers, resolve_user_repo_path/Resolve-UserRepoPath, ait-harvest.py, hh, check-lib; written by setup-user-config.sh/.ps1"}'

# Native path forms for storage (installer convention: cygpath -w on Windows is the
# .ps1 writer's job; on macOS/Linux paths are already native).
if $DRY_RUN; then
    log "[DRY RUN] Would merge config into $(display_path "$CONFIG_FILE") (derived: $DERIVED_JSON)"
    write_summary OK "aitools config" "dry run"
elif [ -z "$CONFIG_MERGE_JS" ]; then
    log_error "Failed: $(display_path "$CONFIG_FILE"): internal error -- config merge program is empty"
    write_summary ERROR "aitools config" "merge program missing"
elif command -v node >/dev/null 2>&1; then
    MERGE_EC=0
    # || records node's exit status so set -e does not abort before it is reported below
    MERGE_OUTPUT=$(node -e "$CONFIG_MERGE_JS" "$CONFIG_FILE" "$CONFIG_TMP" \
        "$REPOS_PATH_ARG" "$REPO_PATH_ARG" "$DRIVES_JSON" "$DERIVED_JSON" "$CONFIG_INTENT_JSON" 2>&1) || MERGE_EC=$?
    MERGE_RESULT=$(printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print $1 if /^RESULT:(\w+)/')
    if [ "$MERGE_EC" -ne 0 ] || [ -z "$MERGE_RESULT" ]; then
        rm -f "$CONFIG_TMP"
        printf '%s\n' "$MERGE_OUTPUT" | while IFS= read -r line; do
            if [ -n "$line" ]; then log_detail "$line"; fi
        done
        log_error "Failed: $(display_path "$CONFIG_FILE"): config merge failed (exit $MERGE_EC) -- existing file left untouched"
        write_summary ERROR "aitools config" "merge failed"
    elif [ "$MERGE_RESULT" = "unchanged" ]; then
        log_ok "Verified: $(display_path "$CONFIG_FILE") (unchanged)"
        write_summary OK "aitools config" "verified"
    elif ! validate_json_config "$CONFIG_TMP" version reposPath repoPath; then
        rm -f "$CONFIG_TMP"
        write_summary ERROR "aitools config" "validation failed"
    else
        backup_file "$CONFIG_FILE"
        if ! mv "$CONFIG_TMP" "$CONFIG_FILE"; then
            rm -f "$CONFIG_TMP"
            log_error "Failed: $(display_path "$CONFIG_FILE"): could not replace the config file"
            write_summary ERROR "aitools config" "write failed"
        else
            case "$MERGE_RESULT" in
                recovered)
                    CORRUPT_REASON=$(printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print $1 if /^CORRUPT:(.+)/')
                    log_warn "$(display_path "$CONFIG_FILE") was not valid JSON ($CORRUPT_REASON) -- rebuilt; the invalid copy was backed up"
                    write_summary WARN "aitools config" "rebuilt (was invalid)" ;;
                created)
                    log_ok "Created: $(display_path "$CONFIG_FILE")"
                    write_summary OK "aitools config" "created" ;;
                *)
                    log_ok "Updated: $(display_path "$CONFIG_FILE")"
                    write_summary OK "aitools config" "updated" ;;
            esac
            printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print "$1\n" if /^CHANGED:(.+)/' | while IFS= read -r change; do
                log "  $change"
                write_summary DETAIL "aitools config" "${change%%:*} updated"
            done
        fi
    fi
elif [ ! -f "$CONFIG_FILE" ]; then
    # Fresh machine without node: nothing to preserve; write bootstrap keys only.
    if [ -z "$REPOS_PATH_ARG" ] || [ -z "$REPO_PATH_ARG" ]; then
        log_error "Failed: $(display_path "$CONFIG_FILE"): no node and no --repos-path/--repo-path -- nothing to write"
        write_summary ERROR "aitools config" "missing bootstrap values"
    else
        RP_JSON=$(printf '%s' "$REPOS_PATH_ARG" | perl -pe 's/\\/\\\\/g; s/"/\\"/g')
        AP_JSON=$(printf '%s' "$REPO_PATH_ARG" | perl -pe 's/\\/\\\\/g; s/"/\\"/g')
        if printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "googleDrives": %s\n}\n' \
                "$RP_JSON" "$AP_JSON" "$DRIVES_JSON" > "$CONFIG_TMP" \
            && validate_json_config "$CONFIG_TMP" version reposPath repoPath \
            && mv "$CONFIG_TMP" "$CONFIG_FILE"; then
            log_ok "Created: $(display_path "$CONFIG_FILE") (bootstrap keys; derivation runs once node is installed)"
            write_summary OK "aitools config" "created"
        else
            rm -f "$CONFIG_TMP"
            log_error "Failed: $(display_path "$CONFIG_FILE"): could not write the initial config"
            write_summary ERROR "aitools config" "write failed"
        fi
    fi
else
    log_warn "node not found -- $(display_path "$CONFIG_FILE") left unchanged (read-then-merge needs node)"
    write_summary WARN "aitools config" "not updated (no node)"
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
