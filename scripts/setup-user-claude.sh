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
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
if ! mkdir -p "$CLAUDE_DIR"; then
    log_error "Cannot create $(display_path "$CLAUDE_DIR")"
    write_summary ERROR "claude.md" "cannot create ~/.claude"
    exit 1
fi

# --- Dotprofile and this machine's profile: one resolver (reference/user-repo.md
# "Resolution"). This script reads only the wrapper results (PR #80 contract),
# never profile.json or config.json itself: no alias lookup, no hostname or
# first-profile fallback. A miss never takes another machine's values: on no
# match the profile/identity values are identity-level only. The wrappers write
# the ERROR row and ACTION for their own failures; this script adds none. ---
URP_RC=0
resolve_user_repo_path || URP_RC=$?    # 1 = shared-only (expected); 3 = logged error + ERROR row
USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
USER_REPO_VIA="$AITLIB_USER_REPO_VIA"
if [ "$URP_RC" -eq 3 ]; then
    # A dotprofile error is not "no dotprofile": deploying the shared template
    # would replace the personal CLAUDE.md and rules. The wrapper wrote the
    # ERROR "dotprofile" row; this is the claude.md outcome row (no ACTION).
    log_error "CLAUDE.md and rules not deployed: the dotprofile could not be resolved"
    write_summary ERROR "claude.md" "not deployed: dotprofile unresolved"
    exit 1
fi
PROFILE_RC=0
resolve_machine_profile || PROFILE_RC=$?   # 1 = shared-only; 3 = no match / error (logged + ERROR row + ACTION)
MACHINE_ALIAS="$AITLIB_MACHINE_ALIAS"
MACHINE_VIA="$AITLIB_MACHINE_VIA"
PROFILE_NAME="$AITLIB_PROFILE_NAME"
PROFILE_COMPANY="$AITLIB_PROFILE_COMPANY"
IDENTITY_GIT_NAME="$AITLIB_IDENTITY_GIT_NAME"
IDENTITY_GIT_EMAIL="$AITLIB_IDENTITY_GIT_EMAIL"
log_detail "setup-user-claude: dotprofile rc=$URP_RC via=$USER_REPO_VIA; machine profile rc=$PROFILE_RC"

# Footer hostname, same source and form as the resolver's detect_hostname (P-Q5:
# macOS `scutil --get LocalHostName` only, never the DNS-derived kernel name;
# elsewhere `uname -n`; short and lower-case). The PR #80 contract has no
# hostname result, so it is read here until the lib exposes one. On failure the
# footer shows "unknown" and the reason is a detail line.
_host_rc=0
if [ -x /usr/sbin/scutil ]; then
    MACHINE_HOST=$(/usr/sbin/scutil --get LocalHostName 2>&1) || _host_rc=$?
else
    MACHINE_HOST=$(uname -n 2>&1) || _host_rc=$?
fi
if [ "$_host_rc" -ne 0 ]; then
    log_detail "footer hostname unavailable (exit $_host_rc): $MACHINE_HOST"
    MACHINE_HOST=""
fi
MACHINE_HOST=$(printf '%s' "${MACHINE_HOST%%.*}" | perl -pe 's/^\s+|\s+$//g; tr/A-Z/a-z/')
if [ -z "$MACHINE_HOST" ]; then MACHINE_HOST="unknown"; fi
USER_REPO_DISPLAY=""
if [ -n "$USER_REPO_PATH" ]; then
    USER_REPO_DISPLAY=$(printf '%s' "$USER_REPO_PATH" | HOME_DIR="$HOME" perl -pe 's/^\Q$ENV{HOME_DIR}\E(?=\/|$)/~/')
fi

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
SOURCE_PATH=""
SOURCE_LABEL=""
if [ -n "$USER_REPO_PATH" ] && [ -f "$USER_REPO_PATH/claude/CLAUDE.md" ]; then
    SOURCE_PATH="$USER_REPO_PATH/claude/CLAUDE.md"
    SOURCE_LABEL="user repo"
fi

if [ -z "$SOURCE_PATH" ]; then
    if [ -f "$SHARED_PATH" ]; then
        SOURCE_PATH="$SHARED_PATH"
        SOURCE_LABEL="shared template"
    else
        log_error "No template found. Checked user repo and $(display_path "$SHARED_PATH")"
        write_summary ERROR "claude.md" "no template found"
        exit 1
    fi
fi

log "Template source: $(display_path "$SOURCE_PATH") ($SOURCE_LABEL)"

# --- Read template content ---
if ! SHARED_CONTENT=$(cat "$SOURCE_PATH"); then
    log_error "Cannot read template: $(display_path "$SOURCE_PATH")"
    write_summary ERROR "claude.md" "template unreadable"
    exit 1
fi
if [ -z "$SHARED_CONTENT" ]; then
    log_error "Template is empty: $(display_path "$SOURCE_PATH")"
    write_summary ERROR "claude.md" "template empty"
    exit 1
fi

# --- Profile interpolation ---
# Values come from resolve_machine_profile above. Substitution runs in perl with
# the values passed through the environment, so "&", "$", "@" and "/" in a value
# are literal (bash ${var//pat/rep} treats "&" as the match in bash 5.2). An
# empty value leaves its token in place (visible, not silently blank). One pass:
# a value that contains token text is not substituted again.
if ! SHARED_CONTENT=$(printf '%s' "$SHARED_CONTENT" | \
    T_PROFILE_NAME="$PROFILE_NAME" T_PROFILE_COMPANY="$PROFILE_COMPANY" \
    T_IDENTITY_GIT_NAME="$IDENTITY_GIT_NAME" T_IDENTITY_GIT_EMAIL="$IDENTITY_GIT_EMAIL" \
    T_USER_REPO_PATH="$USER_REPO_DISPLAY" \
    perl -0777 -pe 's/\{\{(PROFILE_NAME|PROFILE_COMPANY|IDENTITY_GIT_NAME|IDENTITY_GIT_EMAIL|USER_REPO_PATH)\}\}/my $v = $ENV{"T_$1"}; (defined $v && length $v) ? $v : $&/ge'); then
    log_error "Template interpolation failed (perl)"
    write_summary ERROR "claude.md" "interpolation failed"
    exit 1
fi

case "$PROFILE_RC" in
    0) log "Profile interpolation: alias=$MACHINE_ALIAS via=$MACHINE_VIA name=$PROFILE_NAME company=$PROFILE_COMPANY" ;;
    1) log_warn "No dotprofile -- {{PLACEHOLDER}} tokens will not be resolved"
       write_summary WARN "claude.md" "template tokens unresolved" ;;
    *) log "Profile interpolation: identity-level values only (no machine profile) -- machine-specific tokens may stay unresolved" ;;
esac

# Construct final content (used by both dry-run preview and actual write)
NEW_CONTENT="${SHARED_CONTENT}

## Machine-Specific

- Machine: $(uname -s) $(uname -m) (${MACHINE_HOST}; profile ${MACHINE_ALIAS:-unresolved})
- Shell: $(basename "$SHELL")"

# ---------------------------------------------------------------------------
# Adopt filter for CLAUDE.md (deploy_managed_file ADOPT_FILTER): LOCAL content
# on stdin -> the dotprofile template on stdout. Strips the machine-specific
# footer and reverse-tokenizes profile values, so the next run rebuilds the
# same CLAUDE.md from the template and verifies it. Empty profile values are
# never substituted (an empty pattern would match everywhere).
# ---------------------------------------------------------------------------
claude_md_adopt_filter() {
    local content
    # Everything before ## Machine-Specific; trailing blank lines removed
    content=$(perl -pe 'last if /^## Machine-Specific/')
    content=$(printf '%s' "$content" | perl -0777 -pe 's/\n+\z//')
    # One pass over all values, longest first: a value inside a longer one
    # (company "nobul.tech" in email "jose@nobul.tech") never breaks the longer
    # one's token. Equal text keeps the first token in this order, so
    # {{PROFILE_NAME}} wins over {{IDENTITY_GIT_NAME}} (P-Q13).
    content=$(printf '%s' "$content" | \
        AMF_USER_REPO_PATH="${USER_REPO_DISPLAY:-}" \
        AMF_PROFILE_NAME="${PROFILE_NAME:-}" AMF_PROFILE_COMPANY="${PROFILE_COMPANY:-}" \
        AMF_IDENTITY_GIT_NAME="${IDENTITY_GIT_NAME:-}" AMF_IDENTITY_GIT_EMAIL="${IDENTITY_GIT_EMAIL:-}" \
        perl -pe 'BEGIN {
            our (%tok, $re); my (@vals, $i);
            for my $k (qw(USER_REPO_PATH PROFILE_NAME PROFILE_COMPANY IDENTITY_GIT_NAME IDENTITY_GIT_EMAIL)) {
                my $v = $ENV{"AMF_$k"}; $i++;
                next unless defined $v && length $v;
                next if exists $tok{$v};
                $tok{$v} = $k; push @vals, [$v, $i];
            }
            @vals = sort { length($b->[0]) <=> length($a->[0]) || $a->[1] <=> $b->[1] } @vals;
            $re = @vals ? join("|", map { quotemeta($_->[0]) } @vals) : "";
        }
        our (%tok, $re);
        s/($re)/"{{" . $tok{$1} . "}}"/ge if length $re;')
    printf '%s\n' "$content"
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
    # Adopt target: the dotprofile template (the source of truth when a user
    # repo is configured). The library writes it, through claude_md_adopt_filter.
    _claude_adopt_path=""
    if [ -n "${USER_REPO_PATH:-}" ]; then
        _claude_adopt_path="$USER_REPO_PATH/claude/CLAUDE.md"
    fi
    deploy_managed_file "$NEW_CONTENT" "$CLAUDE_MD" "claude.md" "CLAUDE.md" "$_claude_adopt_path" "claude_md_adopt_filter"

    case "$MANAGED_FILE_RESULT" in
        created|updated|"accept & adopt")
            # Errors logged before this point (e.g. the machine-profile resolver)
            # are not validation failures
            _claude_errs_before=$ERRORS
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
            if [ "$ERRORS" -ne "$_claude_errs_before" ]; then
                write_summary ERROR "claude.md" "validation failed"
            elif [ "$MANAGED_FILE_RESULT" = "accept & adopt" ]; then
                write_summary OK "claude.md" "accepted to profile"
            else
                write_summary OK "claude.md" "$MANAGED_FILE_RESULT"
            fi
            ;;
        skipped)
            write_summary WARN "claude.md" "skipped (user review)"
            ;;
        verified)
            log "CLAUDE.md verified (no differences)"
            write_summary OK "claude.md" "verified"
            ;;
        failed)
            # The library restored the files and logged the reason (log_error).
            write_summary ERROR "claude.md" "deploy failed"
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
        if ! mkdir -p "$RULES_DEST"; then
            log_error "Cannot create $(display_path "$RULES_DEST")"
            write_summary ERROR "claude rules" "cannot create rules dir"
            exit 1
        fi

        deploy_tracker_init
        ERRORS_BEFORE_RULES=$ERRORS
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            # Adopt target: the dotprofile rule (the file deployed from). Empty
            # in the MDM deploy script (no user repo): adopt and merge not offered.
            _rule_adopt_path=""
            if [ -n "${USER_REPO_PATH:-}" ]; then
                _rule_adopt_path="$USER_REPO_PATH/claude/rules/$rule_name"
            fi
            if ! _rule_content=$(cat "$rule_file"); then
                log_error "Cannot read source rule $rule_name"
                deploy_tracker_record "failed" "claude rules" "$rule_name"
                continue
            fi
            deploy_managed_file "$_rule_content" "$RULES_DEST/$rule_name" "claude rules" "$rule_name" "$_rule_adopt_path"

            case "$MANAGED_FILE_RESULT" in
                created|updated|verified|"accept & adopt"|skipped|failed)
                    # The library wrote LOCAL and the adopt target itself; the
                    # tracker records every outcome (failed -> ERROR row).
                    ;;
            esac
            deploy_tracker_record "$MANAGED_FILE_RESULT" "claude rules" "$rule_name"
            # After a merge & adopt (the library already wrote the merge to the
            # dotprofile), auto commit+push to keep the dotprofile in sync.
            # Kept: commander confirmed 2026-10-21 (contract item #11).
            if [ "$MANAGED_FILE_RESULT" = "accept & adopt" ] && [ -n "${MERGED_CONTENT:-}" ] && [ -n "${USER_REPO_PATH:-}" ]; then
                # Suppress git stderr noise; failure handled by if/else branches
                if (cd "$USER_REPO_PATH" && \
                    git add "claude/rules/$rule_name" && \
                    git diff --cached --quiet "claude/rules/$rule_name") 2>/dev/null; then
                    # git diff --cached --quiet exits 0 = no staged changes
                    log "No diff to commit in user repo for $rule_name"
                else
                    # Suppress git stderr noise; failure handled by if/else branches
                    if (cd "$USER_REPO_PATH" && \
                        git add "claude/rules/$rule_name" && \
                        git commit -m "Sync merged $rule_name from deploy" && \
                        git push) 2>/dev/null; then
                        log_ok "Pushed merged $rule_name to user repo"
                    else
                        log_warn "Failed to push merged $rule_name to user repo"
                        write_summary WARN "claude rules" "$rule_name not pushed"
                    fi
                fi
            fi
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

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            if [ -f "$RULES_DEST/$rule_name" ] && [ ! -s "$RULES_DEST/$rule_name" ]; then
                log_error "Validation failed: $rule_name is empty after deploy"
            fi
        done

        if [ "$_DT_FAILED" -gt 0 ]; then
            # deploy_tracker_summary writes the ERROR row ("N failed")
            deploy_tracker_summary "claude rules"
            log "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
        elif [ "$ERRORS" -eq "$ERRORS_BEFORE_RULES" ]; then
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
