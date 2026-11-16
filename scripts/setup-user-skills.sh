#!/usr/bin/env bash
# setup-user-skills.sh — Deploys user-level skills for Claude Code and Cursor on macOS/Linux
# Safe to re-run — uses managed file deployment with diff review.
#
# Discovers skills dynamically from shared/skills/ (framework) and dotprofile
# repo claude/skills/ (personal). Dotprofile skills take priority over shared.
# Deploys to ~/.claude/skills/ and ~/.cursor/skills/.
# Reverse discovery: detects user-created skills in deploy target and offers
# to adopt them to the dotprofile repo. Never offered: aitool-ops and
# aitool-eval, aitools skills retired (PR 129) before the skills manifest.
#
# Fallback deployer (FD-9, plans/skills-and-rules-fanout.md FO-6): when
# ~/.aitools/skills exists (deploy-harness has run), the fan-out owns the skills
# -- setup-user-claude writes ~/.claude/skills (row "claude skills") and
# setup-user-cursor writes ~/.cursor/skills (row "cursor skills"). This script
# then deploys nothing, writes neither row, writes OK "skills" "n/a (fanned
# out)" and keeps reverse discovery, which treats every name in
# ~/.aitools/skills (a directory or a manifest line, any source) and every
# backup or hidden name as not user-created. Reverse discovery's own rows (a
# failed adopt, an unreadable directory) then use the tool "skills" too. A
# resolver error, or an unreadable ~/.aitools/skills, manifest or
# ~/.claude/skills, means reverse discovery does not run (its adopt target is
# the dotprofile): a resolver error is recorded once by the library (under
# "dotprofile") and only logged here; an unreadable directory or manifest is
# ERROR "skills" "no adopt: <what>" with its reason. Without
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
# SKILLS_ROW_TOOL: the summary tool for reverse discovery's rows ("skills" when
# fanned out: the two fan-out tool names belong to the fan-out scripts).
SKILLS_HARNESS_DIR="$HOME/.aitools/skills"
SKILLS_FANNED_OUT=false
SKILLS_ROW_TOOL="claude skills"
if [ -d "$SKILLS_HARNESS_DIR" ]; then
    SKILLS_FANNED_OUT=true
    SKILLS_ROW_TOOL="skills"
    log "Skills are fanned out from ~/.aitools/skills by setup-user-claude (claude skills) and setup-user-cursor (cursor skills): not deploying them here"
    write_summary OK "skills" "n/a (fanned out)"
fi

# --- BEGIN skill discovery (replaced by build-deploy) ---

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_DIR/shared/skills"

# User repo for dotprofile overrides and adopt target: the one dotprofile
# resolver (reference/user-repo.md "Resolution"; SD-7). The rc is captured, not
# suppressed: 0 found, 1 no dotprofile (shared-only mode, expected), 3 resolver
# error (the library recorded it once: write_error "dotprofile", counted in
# this script's errors, so the exit status is 1).
# On 1 USER_REPO_PATH is empty: shared skills only, no adopt offer. On 3 the
# deploy is skipped (S3-M3Lead decision): shared copies must never overwrite
# deployed dotprofile versions while the dotprofile cannot be read. What is
# not run because of it is logged at info, not recorded again (one cause, one
# red line: reference/logging.md 8.3 "Recorded at the source").
URP_RC=0
resolve_user_repo_path || URP_RC=$?
USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
SKILLS_BLOCKED=false
if [ "$URP_RC" -ne 0 ] && [ "$URP_RC" -ne 1 ]; then
    SKILLS_BLOCKED=true
    if [ "$SKILLS_FANNED_OUT" = "true" ]; then
        # The fan-out deploys; reverse discovery adopts into the dotprofile, so
        # it cannot run.
        log "Dotprofile unresolved (resolver error above) -- reverse discovery not run, so no skill can be adopted to the dotprofile"
    else
        log "Dotprofile unresolved (resolver error above) -- skills not deployed, so shared copies cannot replace dotprofile versions"
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
    write_warn "claude skills" "no skills found in shared/skills/ or the dotprofile -- nothing deployed"
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
        write_error "$tool_name" "cannot deploy $skill_name" "SKILL.md not found in the dotprofile or shared/skills"
        deploy_tracker_record failed "$tool_name" "$skill_name"
        return
    fi

    local dest_dir="$dest_base/$skill_name"
    local dest="$dest_dir/SKILL.md"

    # Read the source first: an unreadable file is one error with cat's
    # message, not an empty deploy that fails later for another reason.
    # 2>&1: cat writes nothing to stderr when it succeeds.
    local src_content src_rc=0
    src_content=$(cat "$src" 2>&1) || src_rc=$?
    if [ "$src_rc" -ne 0 ]; then
        write_error "$tool_name" "cannot read the source of $skill_name" "$(error_reason "$src_content" "$src_rc")"
        deploy_tracker_record failed "$tool_name" "$skill_name"
        return
    fi

    # Adopt target: the file actually read (the dotprofile copy when that was
    # the source, else shared/skills in the aitools repo). The library writes it.
    deploy_managed_file "$src_content" "$dest" "$tool_name" "$skill_name" "$src"

    case "$MANAGED_FILE_RESULT" in
        "accept & adopt")
            # Copy the adopted content to the other deploy targets too, so their
            # deploy sees LOCAL == SOURCE instead of asking again.
            local _other_base _other _sync_out _sync_rc
            for _other_base in $ALL_SKILL_DESTS; do
                [ "$_other_base" = "$dest_base" ] && continue
                _other="$_other_base/$skill_name/SKILL.md"
                _sync_rc=0
                _sync_out=$(mkdir -p "$_other_base/$skill_name" 2>&1) || _sync_rc=$?
                if [ "$_sync_rc" -ne 0 ]; then
                    write_error "$tool_name" "sync failed: $skill_name" "$(error_reason "$_sync_out" "$_sync_rc")"
                    continue
                fi
                backup_file "$_other"
                _sync_out=$(cp "$dest" "$_other" 2>&1) || _sync_rc=$?
                if [ "$_sync_rc" -eq 0 ]; then
                    log "Synced adopted skill to $(display_path "$_other")"
                else
                    write_error "$tool_name" "sync failed: $skill_name" "$(error_reason "$_sync_out" "$_sync_rc")"
                fi
            done
            ;;
        created|updated|skipped|verified|failed)
            # The library recorded a failed or skipped file itself; the
            # tracker writes the DETAIL item and counts it.
            ;;
    esac
    deploy_tracker_record "$MANAGED_FILE_RESULT" "$tool_name" "$skill_name"
}

# --- Deploy to Claude Code ---
if [ -n "$SKILL_NAMES" ]; then
    # Each failed item is its own ERROR record (the library's or this
    # script's write_error); the tracker writes the OK status with its counts
    # ("N failed" among them) and the DETAIL items, so there is no aggregate
    # error record (reference/logging.md 8.3 "Managed files").
    log "Deploying skills to $(display_path "$SKILLS_DEST")..."
    deploy_tracker_init
    for skill_name in $SKILL_NAMES; do
        deploy_skill "$skill_name" "$SKILLS_DEST" "claude skills"
    done
    deploy_tracker_summary "claude skills"

    # --- Deploy to Cursor ---
    log "Deploying skills to $(display_path "$SKILLS_DEST_CURSOR")..."
    deploy_tracker_init
    for skill_name in $SKILL_NAMES; do
        deploy_skill "$skill_name" "$SKILLS_DEST_CURSOR" "cursor skills"
    done
    deploy_tracker_summary "cursor skills"
fi

# --- Reverse discovery ---
# Skills aitools retired before the skills manifest existed: PR 129 deleted
# aitool-ops and aitool-eval from shared/skills, the old setup-user-skills had
# deployed them to ~/.claude/skills, and no skills manifest lists them. A copy
# left there is an old aitools copy, not a user-created skill, so it is never
# offered for adoption, in either mode (S3-Merge2-Review125 N2). Lower-cased,
# one per line, each line ending in a newline (in_list). Parity:
# $retiredSkillNames (.ps1).
RETIRED_SKILL_NAMES="aitool-eval
aitool-ops
"

# Scan deployed skills for user-created skills not in shared or dotprofile
reverse_discover_skills() {
    local dest_base="$1"
    [ -d "$dest_base" ] || return 0
    # No adopt target: nothing would be offered, so the scan is not needed
    [ -n "$USER_REPO_PATH" ] || return 0
    # An unreadable directory would leave the glob below empty: report it
    if [ ! -r "$dest_base" ] || [ ! -x "$dest_base" ]; then
        write_error "$SKILLS_ROW_TOOL" "no adopt: target unreadable" "~/.claude/skills is not readable -- reverse discovery not run"
        # return 0: the error is counted in ERRORS (the exit footer exits 1);
        # a non-zero return would end the script under set -e before the footer
        return 0
    fi

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
        # An aitools skill retired before the manifest existed (both modes)
        if in_list "$(lower_name "$skill_name")" "$RETIRED_SKILL_NAMES"; then
            log "Not offered for adoption: $skill_name (an aitools skill retired before the skills manifest existed; delete ~/.claude/skills/$skill_name if you no longer use it)"
            continue
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
                # tty_interactive + read_menu_choice (GitHub #29):
                # read_menu_choice prints the prompt, lowercases the answer (so
                # `A` adopts, as in the PS1 twin), logs it at detail, and
                # re-asks on an empty or unrecognised answer; only EOF takes
                # the default, [s]kip.
                printf '\n  User-created skill detected: %s\n' "$skill_name" > /dev/tty
                printf '  [a]dopt to dotprofile  [s]kip\n' > /dev/tty
                local choice=""
                read_menu_choice choice "a adopt s skip" "s" "skip" "adopt skill $skill_name" "  > "
                case "$choice" in
                    a|adopt)
                        # The library records a failure once (write_error
                        # under SKILLS_ROW_TOOL, with its reason); the if keeps
                        # set -e from ending the script on its return 1
                        if ! adopt_managed_file --tool "$SKILLS_ROW_TOOL" "$skill_dir/SKILL.md" "$USER_REPO_PATH/claude/skills/$skill_name/SKILL.md"; then
                            log "Adoption of $skill_name not completed (error above)"
                        fi
                        ;;
                    s|skip)
                        log "Skipped adoption of $skill_name"
                        ;;
                    *)
                        # Unreachable: read_menu_choice returns only a VALID
                        # answer. Skip (writes nothing) and say so.
                        write_warn "$SKILLS_ROW_TOOL" "unexpected answer \"$choice\" at adopt skill $skill_name -- adoption skipped"
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
# (in_list). Returns 1 after one write_error "skills" when ~/.aitools/skills
# or its manifest cannot be read: reverse discovery is then not run, so a
# harness skill is never mistaken for a user-created one. A manifest with a bad
# header adds no names (the fan-out reports it); its directory names still count.
HARNESS_SKILL_NAMES=""
collect_harness_skill_names() {
    local dir="$SKILLS_HARNESS_DIR"
    local manifest="$SKILLS_HARNESS_DIR/.aitools-skills-manifest"
    local tab entry name out line rc=0
    tab=$(printf '\t')
    if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
        write_error "skills" "no adopt: harness unreadable" "~/.aitools/skills is not readable -- reverse discovery not run"
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
            # out is "cannot read <file>: <reason>", which states the cause;
            # error_reason logs it as detail (reverse discovery is not run)
            write_error "skills" "no adopt: manifest unreadable" "$(error_reason "$out" "$rc")"
            return 1
        fi
        if [ "$out" = "header-bad" ]; then
            log "Skills manifest header not recognised: harness skill names taken from ~/.aitools/skills only"
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
    :  # resolver error: no adopt target (recorded by the library, logged above)
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
