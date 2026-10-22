#!/usr/bin/env bash
# setup-user-skills.sh — Deploys user-level skills for Claude Code and Cursor on macOS/Linux
# Safe to re-run — uses managed file deployment with diff review.
#
# Discovers skills dynamically from shared/skills/ (framework) and dotprofile
# repo claude/skills/ (personal). Dotprofile skills take priority over shared.
# Deploys to ~/.claude/skills/ and ~/.cursor/skills/.
# Reverse discovery: detects user-created skills in deploy target and offers
# to adopt them to the dotprofile repo.

# --- BEGIN skills body (extracted by build-deploy) ---
set -euo pipefail

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
logging_init "setup-user-skills"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

# --- BEGIN skill discovery (replaced by build-deploy) ---

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_DIR/shared/skills"

# User repo for dotprofile overrides and adopt target: the one dotprofile
# resolver (reference/user-repo.md "Resolution"; SD-7). The rc is captured, not
# suppressed: 0 found, 1 no dotprofile (shared-only mode, expected), 3 resolver
# error (the lib already logged it: log_error + ERROR row "dotprofile"). On 1
# and 3 USER_REPO_PATH is empty: shared skills only, no adopt offer.
URP_RC=0
resolve_user_repo_path || URP_RC=$?
USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
if [ "$URP_RC" -ne 0 ] && [ "$URP_RC" -ne 1 ]; then
    # Not counted again: the resolver error is already an error and an ERROR row.
    log "Dotprofile unresolved (resolver error above) -- deploying shared skills only"
fi
DOTPROFILE_SKILLS=""
if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH/claude/skills" ]; then
    DOTPROFILE_SKILLS="$USER_REPO_PATH/claude/skills"
fi

SKILLS_DEST="$HOME/.claude/skills"
SKILLS_DEST_CURSOR="$HOME/.cursor/skills"
ALL_SKILL_DESTS="$SKILLS_DEST $SKILLS_DEST_CURSOR"

# --- Discover skills from shared and dotprofile ---
SKILL_NAMES=""
if [ -d "$SKILLS_SRC" ]; then
    for skill_dir in "$SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [ -f "$skill_dir/SKILL.md" ] || continue
        SKILL_NAMES="$SKILL_NAMES $skill_name"
    done
fi
# Add dotprofile skills not already in shared
if [ -n "$DOTPROFILE_SKILLS" ]; then
    for skill_dir in "$DOTPROFILE_SKILLS"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [ -f "$skill_dir/SKILL.md" ] || continue
        case " $SKILL_NAMES " in
            *" $skill_name "*) ;; # already listed from shared
            *) SKILL_NAMES="$SKILL_NAMES $skill_name" ;;
        esac
    done
fi
SKILL_NAMES="${SKILL_NAMES# }"

if [ -z "$SKILL_NAMES" ]; then
    log_warn "No skills found in shared/skills/ or dotprofile"
    write_summary WARN "claude skills" "no skills found"
fi

# --- Deploy function ---
deploy_skill() {
    local skill_name="$1"
    local dest_base="$2"
    local tool_name="$3"

    # Determine source: dotprofile wins over shared
    local src=""
    if [ -n "$DOTPROFILE_SKILLS" ] && [ -f "$DOTPROFILE_SKILLS/$skill_name/SKILL.md" ]; then
        src="$DOTPROFILE_SKILLS/$skill_name/SKILL.md"
    elif [ -f "$SKILLS_SRC/$skill_name/SKILL.md" ]; then
        src="$SKILLS_SRC/$skill_name/SKILL.md"
    else
        log_error "Skill source not found: $skill_name"
        return
    fi

    local dest_dir="$dest_base/$skill_name"
    local dest="$dest_dir/SKILL.md"

    # Adopt target: the file actually read (the dotprofile copy when that was
    # the source, else shared/skills in the aitools repo). The library writes it.
    deploy_managed_file "$(cat "$src")" "$dest" "$tool_name" "$skill_name" "$src"

    case "$MANAGED_FILE_RESULT" in
        "accept & adopt")
            # Copy the adopted content to the other deploy targets too, so their
            # deploy sees LOCAL == SOURCE instead of asking again.
            local _other_base _other
            for _other_base in $ALL_SKILL_DESTS; do
                [ "$_other_base" = "$dest_base" ] && continue
                _other="$_other_base/$skill_name/SKILL.md"
                if ! mkdir -p "$_other_base/$skill_name"; then
                    log_error "Failed: $skill_name: cannot create $(display_path "$_other_base/$skill_name")"
                    write_summary ERROR "$tool_name" "sync failed: $skill_name"
                    continue
                fi
                backup_file "$_other"
                if cp "$dest" "$_other"; then
                    log "Synced adopted skill to $(display_path "$_other")"
                else
                    log_error "Failed: $skill_name: could not copy the adopted skill to $(display_path "$_other")"
                    write_summary ERROR "$tool_name" "sync failed: $skill_name"
                fi
            done
            ;;
        created|updated|skipped|verified|failed)
            # The tracker records the outcome (failed -> ERROR row).
            ;;
    esac
    deploy_tracker_record "$MANAGED_FILE_RESULT" "$tool_name" "$skill_name"
}

# --- Deploy to Claude Code ---
if [ -n "$SKILL_NAMES" ]; then
    log "Deploying skills to $(display_path "$SKILLS_DEST")..."
    ERRORS_BEFORE_CLAUDE=$ERRORS
    deploy_tracker_init
    for skill_name in $SKILL_NAMES; do
        deploy_skill "$skill_name" "$SKILLS_DEST" "claude skills"
    done
    if [ "$ERRORS" -eq "$ERRORS_BEFORE_CLAUDE" ]; then
        deploy_tracker_summary "claude skills"
    else
        write_summary ERROR "claude skills" "deploy failed"
    fi

    # --- Deploy to Cursor ---
    log "Deploying skills to $(display_path "$SKILLS_DEST_CURSOR")..."
    ERRORS_BEFORE_CURSOR=$ERRORS
    deploy_tracker_init
    for skill_name in $SKILL_NAMES; do
        deploy_skill "$skill_name" "$SKILLS_DEST_CURSOR" "cursor skills"
    done
    if [ "$ERRORS" -eq "$ERRORS_BEFORE_CURSOR" ]; then
        deploy_tracker_summary "cursor skills"
    else
        write_summary ERROR "cursor skills" "deploy failed"
    fi
fi

# --- Reverse discovery ---
# Scan deployed skills for user-created skills not in shared or dotprofile
reverse_discover_skills() {
    local dest_base="$1"
    [ -d "$dest_base" ] || return 0

    for skill_dir in "$dest_base"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        [ -f "$skill_dir/SKILL.md" ] || continue

        # Skip if in shared
        [ -d "$SKILLS_SRC/$skill_name" ] && continue
        # Skip if in dotprofile
        if [ -n "$DOTPROFILE_SKILLS" ] && [ -d "$DOTPROFILE_SKILLS/$skill_name" ]; then
            continue
        fi

        # Found a user-created skill not in any source
        if [ -n "$USER_REPO_PATH" ]; then
            log "Found user-created skill: $skill_name"
            if [ "$DRY_RUN" = "true" ]; then
                log "[DRY RUN] Would offer to adopt $skill_name to dotprofile"
            elif tty_interactive; then
                # tty_interactive + read_tty_choice (GitHub #29): EOF at the
                # prompt logs a warning and takes the default, [s]kip.
                printf '\n  User-created skill detected: %s\n' "$skill_name" > /dev/tty
                printf '  [a]dopt to dotprofile  [s]kip\n' > /dev/tty
                printf '  > ' > /dev/tty
                local choice=""
                read_tty_choice choice "skip"
                case "$choice" in
                    a|adopt)
                        local _errors_before=$ERRORS
                        if ! adopt_managed_file "$skill_dir/SKILL.md" "$USER_REPO_PATH/claude/skills/$skill_name/SKILL.md" || [ "$ERRORS" -gt "$_errors_before" ]; then
                            write_summary ERROR "claude skills" "adopt failed: $skill_name"
                        fi
                        ;;
                    *)
                        log "Skipped adoption of $skill_name"
                        ;;
                esac
            else
                log "Non-interactive: skipped adoption prompt for $skill_name"
            fi
        fi
    done
}

reverse_discover_skills "$SKILLS_DEST"

# --- END skill discovery (replaced by build-deploy) ---

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
