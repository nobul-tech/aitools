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
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
# Rules come from ~/.aitools/rules only (deploy-harness fills it: run it first);
# the dotprofile's claude/rules reaches Claude Code through it.

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

# Footer hostname: the resolver's (P-Q5, one hostname source: macOS
# `scutil --get LocalHostName`, elsewhere `uname -n`; short, lower-case), read
# from resolve_machine_profile above. "unknown" when the resolver gave none
# (the resolver says why in a warning, logged as a detail line).
MACHINE_HOST="${AITLIB_MACHINE_HOSTNAME:-}"
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
    # An unreadable CLAUDE.md is a warning below, not a set -e abort here
    if [ -f "$CLAUDE_MD" ] && [ -r "$CLAUDE_MD" ]; then EXISTING_LINES=$(wc -l < "$CLAUDE_MD"); fi
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
        # Compared as deploy_managed_file compares (trailing newlines removed).
        # The explicit open dies on an unreadable file (perl -p only warns).
        if ! _dr_existing=$(perl -0777 -e 'open my $f, "<", $ARGV[0] or die "cannot read $ARGV[0]: $!\n"; my $t = <$f>; $t = "" unless defined $t; $t =~ s/[\r\n]+\z//; print $t' "$CLAUDE_MD"); then
            log_warn "Cannot read $(display_path "$CLAUDE_MD") for the dry-run comparison"
            _dr_existing=""
        fi
        _dr_new=$(printf '%s' "$NEW_CONTENT" | perl -0777 -pe 's/[\r\n]+\z//')
        if [ "$_dr_existing" = "$_dr_new" ]; then
            log "[DRY RUN] Content unchanged"
            write_summary OK "claude.md" "verified"
        else
            log "[DRY RUN] Content differs -- would overwrite"
            write_summary OK "claude.md" "dry-run: would update"
        fi
    else
        log "[DRY RUN] File does not exist -- would create"
        write_summary OK "claude.md" "dry-run: would create"
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
# Rules fan-out: ~/.aitools/rules -> ~/.claude/rules. deploy-harness fills
# ~/.aitools/rules from aitools shared/rules, aitools .claude/rules and the
# dotprofile's claude/rules (first source wins) and writes its rules manifest
# (PR #100 contract). Claude Code gets every rule there except the ones the
# manifest retires (commander decisions 2026-10-22): *.md only, *.bak.* and
# hidden files skipped, names compared case-insensitively. The dotprofile's
# claude/rules is not read here. Additive: managed files updated, unmanaged
# files preserved; the copy of a retired rule is backed up and removed when it
# matches a harness copy. Adopt target: the repo file the manifest names as the
# rule's source, when it is on this machine. Parity: setup-user-claude.ps1.
RULES_SRC="$HOME/.aitools/rules"
RULES_DEST="$CLAUDE_DIR/rules"
RULES_MANIFEST="$RULES_SRC/.aitools-rules-manifest"
# The aitools checkout this script runs from: adopt targets of shared and
# aitools rules. Only a git checkout counts: the generated deploy/ copy runs
# from the dotprofile's deploy/ directory, and a package payload (git archive,
# read-only) has no .git; adopt is then offered for dotprofile rules only.
RULES_AITOOLS_REPO=""
if [ -f "$SCRIPT_DIR/../scripts/aitools-lib.sh" ] && [ -f "$SCRIPT_DIR/../shared/claude-shared.md" ] && [ -e "$SCRIPT_DIR/../.git" ]; then
    if ! RULES_AITOOLS_REPO=$(cd "$SCRIPT_DIR/.." && pwd); then
        log_warn "Cannot resolve the aitools checkout from $(display_path "$SCRIPT_DIR") -- adopt not offered for shared and aitools rules"
        RULES_AITOOLS_REPO=""
    fi
fi

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
# rule_adopt_target NAME SOURCE: print the repo file that a rule from SOURCE (a
# rules manifest source) came from, or nothing when that file is not on this
# machine (adopt and merge are then not offered). A dotprofile adopt target is
# committed and pushed by the library (N-Q2); an aitools one is a working-tree
# change. Parity: Get-RuleAdoptTarget in setup-user-claude.ps1.
rule_adopt_target() {
    local name="$1" src="$2" target=""
    case "$src" in
        shared)     if [ -n "$RULES_AITOOLS_REPO" ]; then target="$RULES_AITOOLS_REPO/shared/rules/$name"; fi ;;
        aitools)    if [ -n "$RULES_AITOOLS_REPO" ]; then target="$RULES_AITOOLS_REPO/.claude/rules/$name"; fi ;;
        dotprofile) if [ -n "${USER_REPO_PATH:-}" ]; then target="$USER_REPO_PATH/claude/rules/$name"; fi ;;
    esac
    if [ -n "$target" ] && [ -f "$target" ]; then printf '%s\n' "$target"; fi
}

# Byte comparison of a retired rule's copy with its harness copies and
# backups: the lib's fanout_text_equal (0 equal apart from trailing CR/LF, 1
# differ, 2 unreadable; parity Test-FanoutTextEqual).

# rule_manifest_source NAME: the manifest source of NAME (names compared
# case-insensitively), or nothing
rule_manifest_source() {
    local lc line
    lc=$(lower_name "$1")
    while IFS= read -r line; do
        case "$line" in
            "$lc$TAB"*) printf '%s\n' "${line#*"$TAB"}"; return 0 ;;
        esac
    done <<< "$RULE_SOURCE_OF"
    return 0
}

TAB=$(printf '\t')
RULES_GO=false
if [ ! -d "$RULES_SRC" ]; then
    log "No harness rules at $(display_path "$RULES_SRC") (deploy-harness has not run) -- skipping"
    write_summary OK "claude rules" "n/a (no harness rules)"
elif [ ! -r "$RULES_SRC" ] || [ ! -x "$RULES_SRC" ]; then
    log_error "Cannot list $(display_path "$RULES_SRC") (permission denied)"
    write_summary ERROR "claude rules" "cannot read harness rules"
else
    RULES_GO=true
fi

# Rules manifest: each rule's source (adopt target) and the retired names.
# Without one (deploy-harness before PR #100) every rule is fanned out, none
# is retired and adopt is not offered.
MANIFEST_OK=false
MANIFEST_FAILED=false   # unreadable: counted as a failed item, so the final row is ERROR
RULE_SOURCE_OF=""   # "<lower-case name><TAB><source>" lines
RETIRED_NAMES=""    # names the manifest retires, one per line
RETIRED_LC=""       # the same, lower-cased
if [ "$RULES_GO" = "true" ]; then
    if [ ! -f "$RULES_MANIFEST" ]; then
        log "No rules manifest at $(display_path "$RULES_MANIFEST") -- every rule fanned out, none retired, adopt not offered"
    else
        manifest_out=""
        if ! manifest_out=$(read_rules_manifest "$RULES_MANIFEST" 2>&1); then
            log_error "Cannot read the rules manifest $(display_path "$RULES_MANIFEST"): $manifest_out -- every rule fanned out, none retired"
            write_summary ERROR "claude rules" "cannot read rules manifest"
            MANIFEST_FAILED=true
        elif [ "$manifest_out" = "header-bad" ]; then
            log_warn "Rules manifest $(display_path "$RULES_MANIFEST"): the first line is not \"$RULES_MANIFEST_HEADER\" -- every rule fanned out, none retired, adopt not offered"
            write_summary ACTION "" "Run aitools to rebuild ~/.aitools/rules and its manifest"
        else
            MANIFEST_OK=true
            while IFS= read -r m_line; do
                [ -n "$m_line" ] || continue
                case "$m_line" in
                    "invalid$TAB"*)
                        log_warn "Rules manifest $(display_path "$RULES_MANIFEST"): line ignored: ${m_line#invalid"$TAB"}" ;;
                    "rule$TAB"*)
                        m_rest="${m_line#rule"$TAB"}"
                        m_name="${m_rest%%"$TAB"*}"
                        m_src="${m_rest#*"$TAB"}"
                        if [ "$m_src" = "retired" ]; then
                            RETIRED_NAMES="${RETIRED_NAMES}${m_name}
"
                            RETIRED_LC="${RETIRED_LC}$(lower_name "$m_name")
"
                        else
                            RULE_SOURCE_OF="${RULE_SOURCE_OF}$(lower_name "$m_name")${TAB}${m_src}
"
                        fi ;;
                esac
            done <<< "$manifest_out"
        fi
    fi
fi

# Source files: every *.md in ~/.aitools/rules (flat, the deploy-harness
# contract) that the manifest does not retire. The glob skips hidden files.
RULE_SOURCES=""   # paths, one per line
RULE_BROKEN=""    # dangling symlinks: failed in the deploy loop
if [ "$RULES_GO" = "true" ]; then
    for rule_src in "$RULES_SRC"/*; do
        if [ ! -e "$rule_src" ] && [ ! -L "$rule_src" ]; then
            continue   # the unexpanded glob of an empty directory
        fi
        rule_base=$(basename "$rule_src")
        case "$(rule_name_kind "$rule_base")" in
            rule) ;;
            backup|hidden) continue ;;
            *) log "Ignoring non-rule file in harness rules: $rule_base (only *.md is fanned out)"
               continue ;;
        esac
        if in_list "$(lower_name "$rule_base")" "$RETIRED_LC"; then
            log "Not fanned out: $rule_base (retired in the rules manifest)"
            continue
        fi
        if [ -L "$rule_src" ] && [ ! -e "$rule_src" ]; then
            RULE_BROKEN="${RULE_BROKEN}${rule_base}
"
            continue
        fi
        if [ ! -f "$rule_src" ]; then
            log "Ignoring non-file in harness rules: $rule_base"
            continue
        fi
        RULE_SOURCES="${RULE_SOURCES}${rule_src}
"
    done

    if [ -z "$RULE_SOURCES" ] && [ -z "$RULE_BROKEN" ] && [ -z "$RETIRED_NAMES" ]; then
        log "No rules in $(display_path "$RULES_SRC") -- skipping"
        # An unreadable manifest already wrote this tool's ERROR row
        if [ "$MANIFEST_FAILED" != "true" ]; then
            write_summary OK "claude rules" "n/a (no harness rules)"
        fi
        RULES_GO=false
    elif [ "$DRY_RUN" != "true" ]; then
        backup_dir "$RULES_DEST"
        if ! mkdir -p "$RULES_DEST"; then
            log_error "Cannot create $(display_path "$RULES_DEST")"
            write_summary ERROR "claude rules" "cannot create rules dir"
            RULES_GO=false
        fi
    fi
fi

if [ "$RULES_GO" = "true" ]; then
    deploy_tracker_init
    ERRORS_BEFORE_RULES=$ERRORS
    if [ "$MANIFEST_FAILED" = "true" ]; then
        deploy_tracker_record "failed" "claude rules" ".aitools-rules-manifest"
    fi
    while IFS= read -r broken_name; do
        [ -n "$broken_name" ] || continue
        log_error "Failed: $broken_name: dangling symlink in $(display_path "$RULES_SRC")"
        deploy_tracker_record "failed" "claude rules" "$broken_name"
    done <<< "$RULE_BROKEN"

    # Deploy loop. The list is read on fd 3: stdin stays the terminal, so the
    # review menu can prompt (a loop fed on stdin never prompts). [x]abort exits
    # 2 from the library here: no "claude rules" row is written, and the
    # calling installer or aitools loop records "script failed (exit 2)".
    RULE_DESTS=""      # deployed names, one per line
    RULE_DESTS_LC=""   # the same, lower-cased
    while IFS= read -r rule_src <&3; do
        [ -n "$rule_src" ] || continue
        rule_name=$(basename "$rule_src")
        rule_lc=$(lower_name "$rule_name")
        # Two harness rules whose names differ only in case (possible on a
        # case-sensitive file system) map to one file here: the first wins
        if in_list "$rule_lc" "$RULE_DESTS_LC"; then
            log_error "Skipped duplicate: $rule_name (a harness rule whose name differs only in case was already deployed)"
            deploy_tracker_record "failed" "claude rules" "$rule_name"
            continue
        fi
        RULE_DESTS="${RULE_DESTS}${rule_name}
"
        RULE_DESTS_LC="${RULE_DESTS_LC}${rule_lc}
"
        rule_source=""
        _rule_adopt_path=""
        if [ "$MANIFEST_OK" = "true" ]; then
            rule_source=$(rule_manifest_source "$rule_name")
            if [ -n "$rule_source" ]; then
                _rule_adopt_path=$(rule_adopt_target "$rule_name" "$rule_source")
            fi
        fi
        log_detail "claude rules: $rule_name source=${rule_source:-unknown} adopt=${_rule_adopt_path:-none}"
        _rule_content=""
        if ! _rule_content=$(cat "$rule_src"); then
            log_error "Cannot read harness rule $(display_path "$rule_src")"
            deploy_tracker_record "failed" "claude rules" "$rule_name"
            continue
        fi
        deploy_managed_file "$_rule_content" "$RULES_DEST/$rule_name" "claude rules" "$rule_name" "$_rule_adopt_path"
        case "$MANAGED_FILE_RESULT" in
            created|updated|verified|"accept & adopt"|skipped|failed)
                # The library wrote LOCAL and the adopt target itself (it commits
                # and pushes a dotprofile adopt target, N-Q2); the tracker records
                # every outcome (failed -> ERROR row, skipped -> WARN row).
                ;;
            *)
                log_error "Unexpected deploy result for ${rule_name}: $MANAGED_FILE_RESULT"
                MANAGED_FILE_RESULT="failed" ;;
        esac
        deploy_tracker_record "$MANAGED_FILE_RESULT" "claude rules" "$rule_name"
    done 3<<< "$RULE_SOURCES"

    # Retired rules: the copy in ~/.claude/rules is backed up and removed when
    # it is this fan-out's copy -- the same text as the harness copy or as a
    # backup deploy-harness made when it retired the rule. Any other file of
    # that name may be the user's own: kept, with a warning.
    RM_KEPT=""
    while IFS= read -r rm_name; do
        [ -n "$rm_name" ] || continue
        rm_lc=$(lower_name "$rm_name")
        # Deployed this run under a name that differs only in case
        if in_list "$rm_lc" "$RULE_DESTS_LC"; then continue; fi
        # The copy in ~/.claude/rules, found case-insensitively (a case-sensitive
        # file system may hold it as Gone.md for the manifest's gone.md)
        rm_path=""
        for rm_existing in "$RULES_DEST"/*; do
            [ -f "$rm_existing" ] || continue
            if [ "$(lower_name "$(basename "$rm_existing")")" = "$rm_lc" ]; then
                rm_path="$rm_existing"
                break
            fi
        done
        [ -n "$rm_path" ] || continue
        rm_file=$(basename "$rm_path")
        if [ ! -r "$rm_path" ]; then
            log_error "Cannot read $(display_path "$rm_path") -- retired rule not removed"
            deploy_tracker_record "failed" "claude rules" "$rm_file"
            continue
        fi
        rm_why=""
        for rm_cand in "$RULES_SRC/$rm_name" "$RULES_SRC/$rm_name".bak.*; do
            [ -f "$rm_cand" ] || continue
            rm_rc=0
            fanout_text_equal "$rm_path" "$rm_cand" || rm_rc=$?
            if [ "$rm_rc" -eq 0 ]; then
                rm_why="same text as $(basename "$rm_cand")"
                break
            fi
            if [ "$rm_rc" -ne 1 ]; then
                log_warn "Cannot compare $(display_path "$rm_path") with $(display_path "$rm_cand")"
            fi
        done
        if [ -z "$rm_why" ]; then
            log_warn "Kept $rm_file: the rules manifest retires $rm_name, but this file matches no harness copy (it may be your own) -- Claude Code still loads it; delete it if it is an old fan-out copy"
            RM_KEPT="${RM_KEPT:+$RM_KEPT, }$rm_file"
            continue
        fi
        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY RUN] Would back up and remove $rm_file (retired rule; $rm_why)"
            continue
        fi
        backup_file "$rm_path"
        # Belt and braces: remove only when a backup with the same text exists
        # beside it (a backup step that reports success without a copy must not
        # lose the file)
        rm_backed=false
        if [ "$BACKUP_FILE_OK" = "true" ]; then
            for rm_bak in "$rm_path".bak.*; do
                [ -f "$rm_bak" ] || continue
                if fanout_text_equal "$rm_path" "$rm_bak"; then rm_backed=true; break; fi
            done
        fi
        if [ "$rm_backed" != "true" ]; then
            log_error "Not removed: $rm_file (retired rule): backup failed"
            deploy_tracker_record "failed" "claude rules" "$rm_file"
            continue
        fi
        if ! rm -f "$rm_path" || [ -e "$rm_path" ]; then
            log_error "Cannot remove $(display_path "$rm_path") (retired rule)"
            deploy_tracker_record "failed" "claude rules" "$rm_file"
            continue
        fi
        log "Removed $rm_file (retired rule; $rm_why; backup kept)"
        deploy_tracker_record "removed" "claude rules" "$rm_file"
    done <<< "$RETIRED_NAMES"
    if [ -n "$RM_KEPT" ]; then
        write_summary ACTION "" "Claude Code still loads retired rules in ~/.claude/rules: $RM_KEPT -- delete them unless you wrote them"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        if [ "$_DT_FAILED" -gt 0 ]; then
            write_summary ERROR "claude rules" "$_DT_FAILED failed (dry run)"
        else
            write_summary OK "claude rules" "dry run (no files written)"
        fi
    else
        # Preserved: rules in ~/.claude/rules not fanned out this run
        for existing in "$RULES_DEST"/*; do
            [ -f "$existing" ] || continue
            exist_name=$(basename "$existing")
            case "$(rule_name_kind "$exist_name")" in
                rule) ;;
                *) continue ;;
            esac
            if ! in_list "$(lower_name "$exist_name")" "$RULE_DESTS_LC"; then
                log "Preserved unmanaged rule: $exist_name"
                deploy_tracker_record "preserved" "claude rules" "$exist_name"
            fi
        done

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        while IFS= read -r rule_name; do
            [ -n "$rule_name" ] || continue
            if [ -f "$RULES_DEST/$rule_name" ] && [ ! -s "$RULES_DEST/$rule_name" ]; then
                log_error "Validation failed: $rule_name is empty after deploy"
            fi
        done <<< "$RULE_DESTS"

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
