# --- DRAFT: insert into scripts/aitools-lib.sh directly after read_config_key() ---
# (Also add "resolve_user_repo_path, resolve_machine_profile" to the "Provides:" header.)

# ---------------------------------------------------------------------------
# Dotprofile and machine-profile resolution (reference/user-repo.md "Resolution")
# Intent: give every bash consumer one answer to "where is the dotprofile" and
# "which profile is this machine", with the reason ("via") logged to deploy.log.
# The logic lives in aitools-profile.js (one definition shared with the PS1 lib,
# build-deploy.sh and profile-check.js). NOT a writer of config.json (only
# setup-user-config.sh writes it). NOT a writer of profile.json. Consumed by:
# setup-user-*.sh, aitools, aitools-install.sh, setup-user-config.sh and the
# generated deploy/ scripts (this lib is inlined there; they set
# AITOOLS_PROFILE_JS to their embedded copy).
# ---------------------------------------------------------------------------
_aitools_profile_js() {
    if [ -n "${AITOOLS_PROFILE_JS:-}" ] && [ -f "$AITOOLS_PROFILE_JS" ]; then
        printf '%s' "$AITOOLS_PROFILE_JS"
        return 0
    fi
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$d/aitools-profile.js" ]; then
        printf '%s' "$d/aitools-profile.js"
        return 0
    fi
    return 1
}

# resolve_user_repo_path -- sets USER_REPO_PATH (bash path form) and USER_REPO_VIA
# (env|argument|config|convention|scan|config-nonode|none).
# Returns 0 found, 1 no dotprofile (shared-only mode; not an error), 2 error (logged).
resolve_user_repo_path() {
    USER_REPO_PATH=""
    USER_REPO_VIA="none"
    local cfg="$HOME/.aitools/config.json" js out rc=0 k v raw seen_via=false seen_err=false
    if command -v node >/dev/null 2>&1 && js=$(_aitools_profile_js); then
        # rc is checked below; the tagged output carries the reason. stderr is kept
        # in $out so a node crash (which also exits 1) is visible, not "not found".
        out=$(node "$js" user-repo-path --config "$cfg" --format tagged 2>&1) || rc=$?
        while IFS=$'\t' read -r k v; do
            case "$k" in
                path)  USER_REPO_PATH="$v" ;;
                via)   USER_REPO_VIA="$v"; seen_via=true ;;
                warn)  log_warn "dotprofile: $v" ;;
                error) log_error "dotprofile: $v"; seen_err=true ;;
            esac
        done <<< "$out"
        if [ "$rc" -eq 0 ] && [ -n "$USER_REPO_PATH" ]; then
            log_detail "dotprofile=$USER_REPO_PATH via=$USER_REPO_VIA"
            return 0
        fi
        # rc 1 is "not found" only when the resolver itself said so (via line present)
        if [ "$rc" -ge 2 ] || ! $seen_via; then
            if ! $seen_err; then log_error "dotprofile: resolver failed (exit $rc): $(printf '%s' "$out" | head -c 300)"; fi
            USER_REPO_PATH=""
            write_summary ERROR "dotprofile" "resolver failed"
            return 2
        fi
        log_detail "dotprofile: none found (shared-only mode)"
        return 1
    fi
    # Degraded path (node absent, e.g. installer before Step 8): the cached pointer only.
    if raw=$(read_config_key "$cfg" "userRepoPath"); then
        if command -v cygpath >/dev/null 2>&1; then raw=$(cygpath -u "$raw"); fi
        if [ -d "$raw" ]; then
            USER_REPO_PATH="$raw"
            USER_REPO_VIA="config-nonode"
            log_detail "dotprofile=$USER_REPO_PATH via=config-nonode (node not available)"
            return 0
        fi
    fi
    log_detail "dotprofile: none found (node not available; config.json has no valid userRepoPath)"
    return 1
}

# resolve_machine_profile -- sets MACHINE_ALIAS, MACHINE_VIA, PROFILE_FILE,
# PROFILE_NAME, PROFILE_COMPANY, IDENTITY_GIT_NAME, IDENTITY_GIT_EMAIL,
# IDENTITY_GITHUB. Always logs "machine profile: alias=.. via=..".
# Returns 0 resolved, 1 no dotprofile (shared-only), 2 no match or error
# (log_error + write_summary ERROR/ACTION already emitted -- callers must not
# substitute another machine's values). On 2, the PROFILE_/IDENTITY_ values hold
# identity-level (machine-independent) values only; empty when not set there.
resolve_machine_profile() {
    MACHINE_ALIAS=""; MACHINE_VIA="none"; PROFILE_FILE=""
    PROFILE_NAME=""; PROFILE_COMPANY=""; IDENTITY_GIT_NAME=""; IDENTITY_GIT_EMAIL=""; IDENTITY_GITHUB=""
    local cfg="$HOME/.aitools/config.json" js out rc=0 k v seen_via=false seen_err=false
    if ! command -v node >/dev/null 2>&1; then
        log_warn "machine profile: node not available -- profile values not resolved"
        write_summary WARN "machine profile" "node missing"
        return 1
    fi
    if ! js=$(_aitools_profile_js); then
        log_error "machine profile: aitools-profile.js not found next to aitools-lib.sh (and AITOOLS_PROFILE_JS unset)"
        write_summary ERROR "machine profile" "resolver missing"
        return 2
    fi
    # rc is checked below; tagged lines carry warnings and errors
    out=$(node "$js" resolve --config "$cfg" --environment "$AITOOLS_ENVIRONMENT" --format tagged 2>&1) || rc=$?
    local hosts="" mid=""
    while IFS=$'\t' read -r k v; do
        case "$k" in
            alias)       MACHINE_ALIAS="$v" ;;
            via)         MACHINE_VIA="$v"; seen_via=true ;;
            profileFile) PROFILE_FILE="$v" ;;
            name)        PROFILE_NAME="$v" ;;
            company)     PROFILE_COMPANY="$v" ;;
            gitName)     IDENTITY_GIT_NAME="$v" ;;
            gitEmail)    IDENTITY_GIT_EMAIL="$v" ;;
            github)      IDENTITY_GITHUB="$v" ;;
            hostnames)   hosts="$v" ;;
            machineId)   mid="$v" ;;
            warn)        log_warn "machine profile: $v" ;;
            error)       log_error "machine profile: $v"; seen_err=true ;;
        esac
    done <<< "$out"
    if [ "$rc" -eq 0 ] && [ -n "$MACHINE_ALIAS" ]; then
        log "machine profile: alias=$MACHINE_ALIAS via=$MACHINE_VIA company=$PROFILE_COMPANY hosts=$hosts id=$mid"
        return 0
    fi
    if ! $seen_via && ! $seen_err; then
        # No resolver output at all: node crashed (its own exit 1 is not "not found")
        log_error "machine profile: resolver failed (exit $rc): $(printf '%s' "$out" | head -c 300)"
    fi
    if [ "$rc" -eq 1 ] && $seen_via; then
        log "machine profile: no dotprofile -- shared-only mode"
        return 1
    fi
    log_error "machine profile: unresolved (via=none hosts=$hosts id=$mid) -- no other machine's values will be used"
    write_summary ERROR "machine profile" "no machine match"
    write_summary ACTION "" "Run: aitools user init (pick or register this machine's profile)"
    return 2
}
