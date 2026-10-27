#!/usr/bin/env bash
# setup-user-skills.sh — Deploys user-level skills for Claude Code and Cursor on macOS/Linux
# Safe to re-run — uses managed file deployment with diff review.
#
# Discovers skills dynamically from shared/skills/ (framework) and dotprofile
# repo claude/skills/ (personal). Dotprofile skills take priority over shared.
# Deploys to ~/.claude/skills/ and ~/.cursor/skills/.
# Reverse discovery: detects user-created skills in deploy target and offers
# to adopt them to the dotprofile repo.
#
# Fallback deployer (FD-9, plans/skills-and-rules-fanout.md FO-6): when
# ~/.aitools/skills exists (deploy-harness has run), the fan-out owns the skills
# -- setup-user-claude writes ~/.claude/skills (row "claude skills") and
# setup-user-cursor writes ~/.cursor/skills (row "cursor skills"). This script
# then deploys nothing, writes neither row, writes OK "skills" "n/a (fanned out
# from ~/.aitools/skills)" and keeps reverse discovery, which treats every name
# in ~/.aitools/skills (a directory or a manifest line, any source) and every
# backup or hidden name as not user-created. A resolver error then skips reverse
# discovery (its adopt target is the dotprofile): ERROR "skills". Without
# ~/.aitools/skills it deploys as before (an MDM endpoint run before
# deploy-harness, or a machine where deploy-harness failed). The check sits in
# the extracted body, so the generated MDM script (build-deploy) carries it.
# Platform: macOS/Linux; Windows uses setup-user-skills.ps1 (same rows).
# Tool data: /tool-registry skill.

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

# --- Harness check (FD-9): one writer per skill file ---
# ~/.aitools/skills exists -> the setup-user-claude / setup-user-cursor fan-out
# deploys the skills, so this script does not (no second review menu, no second
# adopt target for one file). In the extracted body: the MDM script has it too.
SKILLS_HARNESS_DIR="$HOME/.aitools/skills"
SKILLS_FANNED_OUT=false
if [ -d "$SKILLS_HARNESS_DIR" ]; then
    SKILLS_FANNED_OUT=true
    log "Skills are fanned out from $(display_path "$SKILLS_HARNESS_DIR") by setup-user-claude (claude skills) and setup-user-cursor (cursor skills): not deploying them here"
    write_summary OK "skills" "n/a (fanned out from ~/.aitools/skills)"
fi

# --- BEGIN skill discovery (replaced by build-deploy) ---

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_DIR/shared/skills"

# User repo for dotprofile overrides and adopt target: the one dotprofile
# resolver (reference/user-repo.md "Resolution"; SD-7). The rc is captured, not
# suppressed: 0 found, 1 no dotprofile (shared-only mode, expected), 3 resolver
# error (the lib already logged it: log_error + ERROR row "dotprofile").
# On 1 USER_REPO_PATH is empty: shared skills only, no adopt offer. On 3 the
# deploy is skipped (S3-M3Lead decision): shared copies must never overwrite
# deployed dotprofile versions while the dotprofile cannot be read.
URP_RC=0
resolve_user_repo_path || URP_RC=$?
USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
SKILLS_BLOCKED=false
if [ "$URP_RC" -ne 0 ] && [ "$URP_RC" -ne 1 ]; then
    SKILLS_BLOCKED=true
    if [ "$SKILLS_FANNED_OUT" = "true" ]; then
        # The fan-out deploys; reverse discovery adopts into the dotprofile, so
        # it cannot run. Reported under "skills": the two fan-out rows are not ours.
        log_error "Dotprofile unresolved (resolver error above) -- reverse discovery skipped, so no skill can be adopted to the dotprofile"
        write_summary ERROR "skills" "reverse discovery skipped: dotprofile error"
    else
        log_error "Dotprofile unresolved (resolver error above) -- skills not deployed, so shared copies cannot replace dotprofile versions"
        write_summary ERROR "claude skills" "not deployed: dotprofile error"
        write_summary ERROR "cursor skills" "not deployed: dotprofile error"
    fi
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
if [ "$SKILLS_BLOCKED" = "true" ]; then
    :  # resolver error: nothing is discovered, deployed or offered for adoption
elif [ "$SKILLS_FANNED_OUT" = "true" ]; then
    :  # the fan-out deploys: nothing is discovered for deployment here
elif [ -d "$SKILLS_SRC" ]; then
    for skill_dir in "$SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [ -f "$skill_dir/SKILL.md" ] || continue
        SKILL_NAMES="$SKILL_NAMES $skill_name"
    done
fi
# Add dotprofile skills not already in shared
if [ -n "$DOTPROFILE_SKILLS" ] && [ "$SKILLS_FANNED_OUT" != "true" ]; then
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

if [ -z "$SKILL_NAMES" ] && [ "$SKILLS_BLOCKED" != "true" ] && [ "$SKILLS_FANNED_OUT" != "true" ]; then
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

        # Fan-out mode: the fan-out's own backup and hidden names, and every
        # harness skill (HARNESS_SKILL_NAMES), are not user-created
        if [ "$SKILLS_FANNED_OUT" = "true" ]; then
            [ "$(skill_name_kind "$skill_name")" = "skill" ] || continue
            in_list "$(lower_name "$skill_name")" "$HARNESS_SKILL_NAMES" && continue
        fi
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

# --- Harness skill names (fan-out mode only) ---
# Every name in ~/.aitools/skills, as an entry or as a manifest line (any
# source, retired included), is a harness skill: the fan-out put it in
# ~/.claude/skills, so it is never offered for adoption. Lower-cased (APFS and
# NTFS are case-insensitive), one per line, each line ending in a newline
# (in_list). Returns 1 after log_error + ERROR "skills" when ~/.aitools/skills
# or its manifest cannot be read: reverse discovery is then skipped, so a
# harness skill is never mistaken for a user-created one. A manifest with a bad
# header adds no names (the fan-out reports it); its directory names still count.
HARNESS_SKILL_NAMES=""
collect_harness_skill_names() {
    local dir="$SKILLS_HARNESS_DIR"
    local manifest="$SKILLS_HARNESS_DIR/.aitools-skills-manifest"
    local tab entry name out line rc=0
    tab=$(printf '\t')
    if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
        log_error "Cannot read $(display_path "$dir") -- reverse discovery skipped, so no harness skill is offered for adoption"
        write_summary ERROR "skills" "reverse discovery skipped: cannot read ~/.aitools/skills"
        return 1
    fi
    for entry in "$dir"/*; do
        # an empty directory leaves the pattern itself (no such entry)
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        name=$(basename "$entry")
        [ "$(skill_name_kind "$name")" = "skill" ] || continue
        HARNESS_SKILL_NAMES="$HARNESS_SKILL_NAMES$(lower_name "$name")
"
    done
    if [ -e "$manifest" ] || [ -L "$manifest" ]; then
        # rc captured: 1 = unreadable (message in out), 2 = caller bug
        out=$(read_harness_manifest "$manifest" skills 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then
            log_error "Cannot read the skills manifest $(display_path "$manifest") (exit $rc): $out -- reverse discovery skipped, so no harness skill is offered for adoption"
            write_summary ERROR "skills" "reverse discovery skipped: cannot read skills manifest"
            return 1
        fi
        if [ "$out" = "header-bad" ]; then
            log "Skills manifest header not recognised: harness skill names taken from $(display_path "$dir") only"
            return 0
        fi
        while IFS= read -r line; do
            case "$line" in
                "rule$tab"*)
                    name="${line#rule$tab}"
                    name="${name%%$tab*}"
                    HARNESS_SKILL_NAMES="$HARNESS_SKILL_NAMES$(lower_name "$name")
"
                    ;;
                "invalid$tab"*)
                    log_detail "skills manifest: ignored line ${line#invalid$tab}"
                    ;;
            esac
        done <<< "$out"
    fi
    return 0
}

if [ "$SKILLS_BLOCKED" = "true" ]; then
    :  # resolver error: no adopt target (logged and reported above)
elif [ "$SKILLS_FANNED_OUT" != "true" ]; then
    reverse_discover_skills "$SKILLS_DEST"
elif [ -n "$USER_REPO_PATH" ]; then
    # Without a dotprofile there is no adopt target and nothing to offer
    if collect_harness_skill_names; then
        reverse_discover_skills "$SKILLS_DEST"
    fi
fi

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
