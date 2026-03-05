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

# Backup a file before overwriting. Keeps at most $max_backups copies.
backup_file() {
    local file="$1" max_backups=20
    [ -f "$file" ] || return 0
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    cp "$file" "${file}.bak.${ts}"
    # Prune oldest beyond limit
    ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1)) | xargs rm -f 2>/dev/null
    log "Backed up $(display_path "$file")"
}

# --- BEGIN backup_dir (extracted by build-deploy) ---
# Backup a directory before modifying managed files. Keeps at most $max_backups copies.
backup_dir() {
    local dir="$1" max_backups=5
    [ -d "$dir" ] || return 0
    # Count managed files; skip backup if none exist yet
    local file_count
    file_count=$(find "$dir" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        return 0
    fi
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    if ! cp -R "$dir" "${dir}.bak.${ts}"; then
        log_warn "Could not back up $(display_path "$dir") -- proceeding without backup"
        return 0
    fi
    # Prune old backups beyond limit.
    # find lists backup dirs; sort -r puts newest first; tail skips the keepers.
    local old_backups
    old_backups=$(find "$(dirname "$dir")" -maxdepth 1 -name "$(basename "$dir").bak.*" -type d \
        | sort -r | tail -n +$((max_backups + 1)))
    if [ -n "$old_backups" ]; then
        printf '%s\n' "$old_backups" | while IFS= read -r old_dir; do
            rm -rf "$old_dir"
            log "Pruned old backup: $(display_path "$old_dir")"
        done
    fi
    log "Backed up $(display_path "$dir") ($file_count managed files)"
}
# --- END backup_dir (extracted by build-deploy) ---

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

if [ "$DRY_RUN" = "true" ]; then
    # Show what would happen without writing
    EXISTING_LINES=0
    [ -f "$CLAUDE_MD" ] && EXISTING_LINES=$(wc -l < "$CLAUDE_MD")
    NEW_CONTENT="${SHARED_CONTENT}

## Machine-Specific

- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname))
- Shell: $(basename "$SHELL")"
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
    # Backup and remove existing file so we always write the latest version
    backup_file "$CLAUDE_MD"
    # Capture existing content for post-write comparison
    OLD_CONTENT=""
    if [ -f "$CLAUDE_MD" ]; then
        OLD_CONTENT=$(cat "$CLAUDE_MD")
    fi
    if [ -f "$CLAUDE_MD" ]; then
        rm "$CLAUDE_MD"
        log "Removed existing $(display_path "$CLAUDE_MD")"
    fi

    # --- Write CLAUDE.md ---
    cat > "$CLAUDE_MD" << EOF
${SHARED_CONTENT}

## Machine-Specific

- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname))
- Shell: $(basename "$SHELL")
EOF

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

    log_ok "Wrote $(display_path "$CLAUDE_MD")"
    # Determine what changed for summary detail
    NEW_WRITTEN=$(cat "$CLAUDE_MD")
    if [ -z "$OLD_CONTENT" ]; then
        log "Content: new file"
        CLAUDE_MD_DETAIL="created"
    elif [ "$OLD_CONTENT" = "$NEW_WRITTEN" ]; then
        log "Content unchanged (no differences)"
        CLAUDE_MD_DETAIL="unchanged"
    else
        log "Content updated"
        CLAUDE_MD_DETAIL="updated"
        # Log unified diff to deploy log (not console)
        diff -u <(echo "$OLD_CONTENT") <(echo "$NEW_WRITTEN") \
            --label "previous/CLAUDE.md" --label "new/CLAUDE.md" \
            >> "$LOG_FILE" 2>&1 || true  # diff exits 1 on differences (expected)
    fi
    if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
        write_summary OK "claude.md" "$CLAUDE_MD_DETAIL"
    elif [ "$ERRORS" -gt 0 ]; then
        write_summary ERROR "claude.md" "validation failed"
    fi
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

        ADDED=0; UPDATED=0; UNCHANGED=0
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            if [ -f "$RULES_DEST/$rule_name" ]; then
                # diff -q: exits 0 if identical, 1 if different (expected behavior)
                if diff -q "$RULES_DEST/$rule_name" "$rule_file" >/dev/null 2>&1; then
                    log "Unchanged: $rule_name (no differences)"
                    UNCHANGED=$((UNCHANGED + 1))
                    continue
                fi
                # Log unified diff before overwriting. diff exits 1 on differences (expected).
                log "Updating: $rule_name"
                diff -u "$RULES_DEST/$rule_name" "$rule_file" \
                    --label "deployed/$rule_name" --label "source/$rule_name" \
                    >> "$LOG_FILE" 2>&1 || true  # diff exits 1 on differences; diff appended to deploy log
                UPDATED=$((UPDATED + 1))
                write_summary DETAIL "claude rules" "updated: $rule_name"
            else
                log "Adding: $rule_name (new)"
                ADDED=$((ADDED + 1))
                write_summary DETAIL "claude rules" "added: $rule_name"
            fi
            cp "$rule_file" "$RULES_DEST/$rule_name"
        done

        # Log preserved files (in target but not in source)
        PRESERVED=0
        if [ -d "$RULES_DEST" ]; then
            for existing in "$RULES_DEST"/*.md; do
                [ -f "$existing" ] || continue
                exist_name=$(basename "$existing")
                if [ ! -f "$RULES_SRC/$exist_name" ]; then
                    log "Preserved unmanaged rule: $exist_name"
                    PRESERVED=$((PRESERVED + 1))
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

        if [ "$ERRORS" -eq 0 ]; then
            log_ok "Rules: $ADDED added, $UPDATED updated, $UNCHANGED unchanged, $PRESERVED preserved in $(display_path "$RULES_DEST")"
            write_summary OK "claude rules" "$ADDED added, $UPDATED updated, $UNCHANGED unchanged"
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
