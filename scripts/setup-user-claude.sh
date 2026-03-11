#!/usr/bin/env bash
# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
# Safe to re-run -- replaces existing file with latest version.
#
# Sources (in priority order):
#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
#   2. shared/claude-shared.md          (fallback template from aitools repo)
#
# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
# machine's profile from profile.json. See reference/user-repo.md.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/ (additive deploy)
# Preserved: ~/.claude/rules/ files not in user repo source

set -euo pipefail

# --- BEGIN preamble (extracted by build-deploy) ---

# --- Flag parsing ---
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
    esac
done
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-user-claude"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

# --- END preamble (extracted by build-deploy) ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# SharedPath can be passed as first non-flag arg; default to shared/claude-shared.md
SHARED_PATH="$SCRIPT_DIR/../shared/claude-shared.md"
for arg in "$@"; do
    case "$arg" in
        --dry-run|--force) ;; # skip flags
        *) SHARED_PATH="$arg"; break ;;
    esac
done
CONFIG="$HOME/.aitools/config.json"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
SOURCE_PATH=""
SOURCE_LABEL=""

if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
    USER_REPO_PATH=$(node -e "
try {
    const cfg = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    if (cfg.userRepoPath) console.log(cfg.userRepoPath);
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read config: ' + e.message); }
" "$CONFIG" 2>/dev/null)

    if [ -n "$USER_REPO_PATH" ] && [ -f "$USER_REPO_PATH/claude/CLAUDE.md" ]; then
        SOURCE_PATH="$USER_REPO_PATH/claude/CLAUDE.md"
        SOURCE_LABEL="user repo"
    fi
fi

if [ -z "$SOURCE_PATH" ]; then
    if [ -f "$SHARED_PATH" ]; then
        SOURCE_PATH="$SHARED_PATH"
        SOURCE_LABEL="shared template"
    else
        log_error "No template found. Checked user repo and $(display_path "$SHARED_PATH")"
        exit 1
    fi
fi

log "Template source: $(display_path "$SOURCE_PATH") ($SOURCE_LABEL)"

# --- Read template content ---
SHARED_CONTENT=$(cat "$SOURCE_PATH")

# --- Profile interpolation ---
# Read profile.json and replace {{PLACEHOLDER}} tokens.
# Reuses the same pattern as build-deploy.sh (lines 58-100).
PROFILE_NAME=""
PROFILE_COMPANY=""
IDENTITY_GIT_NAME=""
IDENTITY_GIT_EMAIL=""

if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
    PROFILE_VALS=$(node -e "
const fs = require('fs'), path = require('path'), os = require('os');
try {
    const cfg = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    const repo = cfg.userRepoPath;
    const alias = cfg.machineAlias || '';
    if (!repo) throw new Error('no userRepoPath');
    const pf = path.join(repo, 'profile.json');
    const p = JSON.parse(fs.readFileSync(pf, 'utf8'));
    let prof, ident;
    if (p.version === 2) {
        prof = p.profiles[alias]
            || Object.values(p.profiles).find(pr => pr.machine && pr.machine.hostname.split('.')[0] === os.hostname().split('.')[0])
            || Object.values(p.profiles)[0];
        ident = p.identity;
    } else {
        prof = { name: p.name, company: p.company || '' };
        ident = { git: { name: (p.git && p.git.name) || p.name, email: (p.git && p.git.email) || p.email } };
    }
    console.log('PROFILE_NAME=' + JSON.stringify(prof.name));
    console.log('PROFILE_COMPANY=' + JSON.stringify(prof.company));
    console.log('IDENTITY_GIT_NAME=' + JSON.stringify(ident.git.name));
    console.log('IDENTITY_GIT_EMAIL=' + JSON.stringify(ident.git.email));
} catch(e) { process.exit(1); }
" "$CONFIG" 2>/dev/null) && eval "$PROFILE_VALS"
fi

if [ -n "$PROFILE_NAME" ]; then
    SHARED_CONTENT="${SHARED_CONTENT//\{\{PROFILE_NAME\}\}/$PROFILE_NAME}"
    SHARED_CONTENT="${SHARED_CONTENT//\{\{PROFILE_COMPANY\}\}/$PROFILE_COMPANY}"
    SHARED_CONTENT="${SHARED_CONTENT//\{\{IDENTITY_GIT_NAME\}\}/$IDENTITY_GIT_NAME}"
    SHARED_CONTENT="${SHARED_CONTENT//\{\{IDENTITY_GIT_EMAIL\}\}/$IDENTITY_GIT_EMAIL}"
    log "Profile interpolation: name=$PROFILE_NAME company=$PROFILE_COMPANY"
else
    log_warn "Profile not available -- {{PLACEHOLDER}} tokens will not be resolved"
    write_summary WARN "claude.md" "template tokens unresolved"
fi

# Construct final content (used by both dry-run preview and actual write)
NEW_CONTENT="${SHARED_CONTENT}

## Machine-Specific

- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname))
- Shell: $(basename "$SHELL")"

# ---------------------------------------------------------------------------
# Adopt deployed CLAUDE.md back to profile template.
# Strips machine-specific footer and reverse-tokenizes profile values.
# ---------------------------------------------------------------------------
adopt_claude_md() {
    local deployed="$1"
    local dest="$2"

    # Read deployed content, strip ## Machine-Specific section to end
    local content
    content=$(perl -pe 'last if /^## Machine-Specific/' "$deployed")
    # Remove trailing blank lines
    content=$(printf '%s' "$content" | perl -0777 -pe 's/\n+$/\n/')

    # Reverse-substitute profile values back to {{PLACEHOLDER}} tokens
    if [ -n "${PROFILE_NAME:-}" ]; then
        content=$(printf '%s' "$content" | perl -pe "
            s/\\Q${PROFILE_NAME}\\E/{{PROFILE_NAME}}/g;
            s/\\Q${PROFILE_COMPANY}\\E/{{PROFILE_COMPANY}}/g;
            s/\\Q${IDENTITY_GIT_NAME}\\E/{{IDENTITY_GIT_NAME}}/g;
            s/\\Q${IDENTITY_GIT_EMAIL}\\E/{{IDENTITY_GIT_EMAIL}}/g;
        ")
    fi

    mkdir -p "$(dirname "$dest")"
    backup_file "$dest"
    printf '%s\n' "$content" > "$dest"
    log_ok "Adopted CLAUDE.md to profile: $(display_path "$dest")"
    if [ -c /dev/tty ]; then
        printf '  Review: cd %s && git diff\n' \
            "$(display_path "$(dirname "$dest")/..")" > /dev/tty
    fi
}

if [ "$DRY_RUN" = "true" ]; then
    # Show what would happen without writing
    EXISTING_LINES=0
    [ -f "$CLAUDE_MD" ] && EXISTING_LINES=$(wc -l < "$CLAUDE_MD")
    NEW_LINES=$(echo "$NEW_CONTENT" | wc -l)
    log "[DRY RUN] $(display_path "$CLAUDE_MD"): overwrite (sole owner)"
    log "  Template source: $(display_path "$SOURCE_PATH") ($SOURCE_LABEL)"
    if [ -n "$PROFILE_NAME" ]; then
        log "  Profile interpolation: name=$PROFILE_NAME company=$PROFILE_COMPANY"
    else
        log "  Profile interpolation: none (tokens unresolved)"
    fi
    log "  Existing: ${EXISTING_LINES} lines"
    log "  New: ${NEW_LINES} lines"
    if [ -f "$CLAUDE_MD" ]; then
        if [ "$(cat "$CLAUDE_MD")" = "$NEW_CONTENT" ]; then
            log "[DRY RUN] Content unchanged"
        else
            log "[DRY RUN] Content differs -- would overwrite"
        fi
    else
        log "[DRY RUN] File does not exist -- would create"
    fi
else
    # --- Deploy CLAUDE.md via managed-file flow ---
    _adopt_label=""
    if [ -n "${USER_REPO_PATH:-}" ]; then
        _adopt_label="profile"
    fi
    deploy_managed_file "$NEW_CONTENT" "$CLAUDE_MD" "claude.md" "CLAUDE.md" "$_adopt_label"

    case "$MANAGED_FILE_RESULT" in
        adopted)
            adopt_claude_md "$CLAUDE_MD" "$USER_REPO_PATH/claude/CLAUDE.md"
            write_summary OK "claude.md" "adopted to profile"
            ;;
        skipped)
            write_summary WARN "claude.md" "skipped (user review)"
            ;;
        created|updated)
            # --- BEGIN post-write validation (extracted by build-deploy) ---
            # Post-write validation: check structure AND content (not just a marker)
            if [ ! -s "$CLAUDE_MD" ]; then
                log_error "Validation failed: $CLAUDE_MD is empty or missing"
            elif ! grep -q "## Machine-Specific" "$CLAUDE_MD"; then
                log_error "Validation failed: $CLAUDE_MD missing Machine-Specific section"
            elif ! grep -qE "## (Coaching|Code Style|Tool)" "$CLAUDE_MD"; then
                # Template body must be present -- a file with only the footer is corrupt
                log_error "Validation failed: $CLAUDE_MD missing template body (only footer present?)"
            fi
            # --- END post-write validation (extracted by build-deploy) ---
            if [ "$ERRORS" -eq 0 ]; then
                write_summary OK "claude.md" "$MANAGED_FILE_RESULT"
            else
                write_summary ERROR "claude.md" "validation failed"
            fi
            ;;
        unchanged)
            log "CLAUDE.md unchanged (no differences)"
            write_summary OK "claude.md" "unchanged"
            ;;
    esac
fi


# --- BEGIN rules deployment (extracted by build-deploy) ---
# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
RULES_SRC=""
if [ -n "${USER_REPO_PATH:-}" ] && [ -d "$USER_REPO_PATH/claude/rules" ]; then
    RULES_SRC="$USER_REPO_PATH/claude/rules"
fi

RULES_DEST="$CLAUDE_DIR/rules"

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
if [ -n "$RULES_SRC" ]; then
    RULE_COUNT=$(find "$RULES_SRC" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    if [ "$RULE_COUNT" -eq 0 ]; then
        log "User repo claude/rules/ exists but has no .md files -- skipping"
    elif [ "$DRY_RUN" = "true" ]; then
        EXISTING_COUNT=0
        if [ -d "$RULES_DEST" ]; then
            EXISTING_COUNT=$(find "$RULES_DEST" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
        fi
        log "[DRY RUN] $(display_path "$RULES_DEST"): additive deploy"
        log "  Source: $(display_path "$RULES_SRC") ($RULE_COUNT rule files)"
        log "  Existing: $EXISTING_COUNT rule files"
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            if [ -f "$RULES_DEST/$rule_name" ]; then
                # diff -q: exits 0 if identical, 1 if different (expected, not an error)
                if diff -q "$RULES_DEST/$rule_name" "$rule_file" >/dev/null 2>&1; then
                    log "  Would skip (unchanged): $rule_name"
                else
                    log "  Would update (changed): $rule_name"
                fi
            else
                log "  Would add (new): $rule_name"
            fi
        done
        # Show files that would be preserved
        if [ -d "$RULES_DEST" ]; then
            for existing in "$RULES_DEST"/*.md; do
                [ -f "$existing" ] || continue
                exist_name=$(basename "$existing")
                if [ ! -f "$RULES_SRC/$exist_name" ]; then
                    log "  Would preserve (unmanaged): $exist_name"
                fi
            done
        fi
    else
        backup_dir "$RULES_DEST"
        mkdir -p "$RULES_DEST"

        deploy_tracker_init
        ERRORS_BEFORE_RULES=$ERRORS
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            _adopt_label=""
            if [ -n "${USER_REPO_PATH:-}" ]; then
                _adopt_label="profile"
            fi
            deploy_managed_file "$(cat "$rule_file")" "$RULES_DEST/$rule_name" "claude rules" "$rule_name" "$_adopt_label"

            case "$MANAGED_FILE_RESULT" in
                adopted)
                    mkdir -p "$USER_REPO_PATH/claude/rules"
                    cp "$RULES_DEST/$rule_name" "$USER_REPO_PATH/claude/rules/$rule_name"
                    log_ok "Adopted rule to profile: $rule_name"
                    ;;
            esac
            deploy_tracker_record "$MANAGED_FILE_RESULT" "claude rules" "$rule_name"
        done

        # Log preserved files (in target but not in source)
        if [ -d "$RULES_DEST" ]; then
            for existing in "$RULES_DEST"/*.md; do
                [ -f "$existing" ] || continue
                exist_name=$(basename "$existing")
                if [ ! -f "$RULES_SRC/$exist_name" ]; then
                    log "Preserved unmanaged rule: $exist_name"
                    deploy_tracker_record "preserved" "claude rules" "$exist_name"
                fi
            done
        fi

        # Post-write validation: each deployed file is non-empty
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            if [ ! -s "$RULES_DEST/$rule_name" ]; then
                log_error "Validation failed: $rule_name is empty after deploy"
            fi
        done

        if [ "$ERRORS" -eq "$ERRORS_BEFORE_RULES" ]; then
            deploy_tracker_summary "claude rules"
            log_ok "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
        else
            write_summary ERROR "claude rules" "validation failed"
        fi
    fi
else
    log "No user rules to deploy (no claude/rules/ in user repo)"
fi
# --- END rules deploy logic (extracted by build-deploy) ---
# --- END rules deployment (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
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
# --- END exit (extracted by build-deploy) ---
