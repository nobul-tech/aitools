#!/usr/bin/env bash
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: /tool-registry skill (registries/tool-registry.json)
#
# Does four things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#   4. Fans the harness rules (~/.aitools/rules) out to Cursor's user rule files
#      (~/.cursor/rules/*.mdc), converting each Claude Code .md rule to .mdc
#
# cli-config.json:
#   Managed fields: version, editor, permissions, model, hasChangedDefaultModel
#   Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields
# ~/.cursor/rules/ (additive deploy):
#   Managed: one <name>.mdc per ~/.aitools/rules/<name>.md (converted); *.bak.*
#            backups and non-.md files in ~/.aitools/rules are not fanned out
#   Preserved: ~/.cursor/rules/ files not produced from ~/.aitools/rules
#   Location and format: S3-H-Cursor-research.md (.aitools/channel/handoffs/
#   2026-10-21_10cf255a-c-missions/S3-H-Cursor/)

# --- BEGIN cursor body (extracted by build-deploy) ---
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
logging_init "setup-user-cursor"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

# Log captured command output to the log file as detail lines (blank lines skipped).
write_output_detail() {  # label, output
    local line
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "$1: $line"; fi
    done <<< "$2"
}

CURSOR_DIR="$HOME/.cursor"
CLI_CONFIG="$CURSOR_DIR/cli-config.json"

# Track status for summary (plain vars -- bash 3.2 compat, no associative arrays)
STATUS_ripgrep=""
STATUS_cursorCli=""
STATUS_cliConfig=""

# --- 1. ripgrep (rg) ---

log "Step 1: ripgrep (rg)"

if [ "$DRY_RUN" = "true" ]; then
    if command -v rg &>/dev/null; then
        RG_VERSION=$(rg --version | head -1)
        log "[DRY RUN] ripgrep already installed: $RG_VERSION"
        STATUS_ripgrep="already installed ($RG_VERSION)"
    else
        log "[DRY RUN] Would install ripgrep via brew"
        STATUS_ripgrep="would install"
    fi
else
    if command -v rg &>/dev/null; then
        RG_VERSION=$(rg --version | head -1)
        log_ok "Already installed: $RG_VERSION"
        STATUS_ripgrep="already installed ($RG_VERSION)"
    else
        if command -v brew &>/dev/null; then
            log "Installing ripgrep via brew..."
            # Exit code decides (C-F2); the full output goes to the log as detail.
            if rg_out=$(brew install ripgrep 2>&1); then rg_rc=0; else rg_rc=$?; fi
            write_output_detail "brew-install-ripgrep" "$rg_out"
            hash -r

            if [ "$rg_rc" -ne 0 ]; then
                log_error "brew install ripgrep failed (exit $rg_rc) -- see $(display_path "$LOG_FILE")"
                STATUS_ripgrep="FAILED (exit $rg_rc)"
                write_summary ERROR "cursor cli" "ripgrep install failed (exit $rg_rc)"
            elif command -v rg &>/dev/null; then
                RG_VERSION=$(rg --version | head -1)
                log_ok "Installed: $RG_VERSION"
                STATUS_ripgrep="installed ($RG_VERSION)"
            else
                log_warn "brew install completed but 'rg' not found in PATH. Restart terminal to verify."
                STATUS_ripgrep="installed (restart terminal to verify)"
                write_summary WARN "cursor cli" "ripgrep not on PATH (restart terminal)"
            fi
        else
            log_warn "Homebrew not found. Install ripgrep manually: brew install ripgrep"
            STATUS_ripgrep="SKIPPED (brew not found)"
            write_summary WARN "cursor cli" "ripgrep missing (Homebrew not found)"
        fi
    fi
fi

# --- 2. Cursor CLI (agent) ---

log "Step 2: Cursor CLI (agent)"

if [ "$DRY_RUN" = "true" ]; then
    if command -v agent &>/dev/null; then
        AGENT_VERSION=$(agent --version)
        log "[DRY RUN] Cursor CLI already installed: $AGENT_VERSION"
        STATUS_cursorCli="already installed ($AGENT_VERSION)"
    else
        log "[DRY RUN] Would install Cursor CLI"
        STATUS_cursorCli="would install"
    fi
else
    if command -v agent &>/dev/null; then
        AGENT_VERSION=$(agent --version)
        log_ok "Already installed: $AGENT_VERSION"
        STATUS_cursorCli="already installed ($AGENT_VERSION)"
    else
        log "Installing Cursor CLI..."
        # Exit code decides (pipefail: a curl failure fails the pipeline); output logged as detail.
        cursor_rc=0
        cursor_out=$({ curl https://cursor.com/install -fsS | bash; } 2>&1) || cursor_rc=$?
        write_output_detail "cursor-installer" "$cursor_out"
        hash -r

        if [ "$cursor_rc" -ne 0 ]; then
            log_error "Cursor CLI installer failed (exit $cursor_rc) -- see $(display_path "$LOG_FILE")"
            STATUS_cursorCli="FAILED (exit $cursor_rc)"
            write_summary ERROR "cursor cli" "installer failed (exit $cursor_rc)"
        elif command -v agent &>/dev/null; then
            AGENT_VERSION=$(agent --version)
            log_ok "Installed: $AGENT_VERSION"
            STATUS_cursorCli="installed ($AGENT_VERSION)"
        else
            log_warn "Cursor CLI install completed but 'agent' not found in PATH. Restart terminal to verify."
            STATUS_cursorCli="installed (restart terminal to verify)"
            write_summary WARN "cursor cli" "agent not on PATH (restart terminal)"
        fi
    fi
fi

# --- 2b. Manage the agent -> cursor-agent symlink (harness-owned) ---
# The Cursor installer provides `cursor-agent`; the harness owns the `agent`
# shim so `agent` deterministically means Cursor, never a stale grok symlink.
if [ "$DRY_RUN" != "true" ]; then
    LOCAL_BIN="$HOME/.local/bin"
    if [ -x "$LOCAL_BIN/cursor-agent" ]; then
        if [ ! -e "$LOCAL_BIN/agent" ] || [ "$(readlink "$LOCAL_BIN/agent" 2>/dev/null || true)" != "cursor-agent" ]; then
            ln -sfn cursor-agent "$LOCAL_BIN/agent"
            log_ok "Linked agent -> cursor-agent in $(display_path "$LOCAL_BIN")"
        fi
    fi
    # Detection: warn if `agent` still resolves to grok (PATH-order regression).
    RESOLVED_AGENT="$(command -v agent 2>/dev/null || true)"
    case "$RESOLVED_AGENT" in
        "$HOME/.grok/"*)
            log_warn "'agent' resolves to grok ($RESOLVED_AGENT), not Cursor -- ensure ~/.local/bin precedes ~/.grok/bin (run setup-user-shell.sh)"
            write_summary WARN "cursor cli" "agent shadowed by grok" ;;
    esac
fi

# --- 3. cli-config.json (merge, not overwrite) ---

log "Step 3: cli-config.json"

if [ "$DRY_RUN" != "true" ]; then
    backup_file "$CLI_CONFIG"
fi

mkdir -p "$CURSOR_DIR"

if ! command -v node &>/dev/null; then
    log_warn "node not found -- skipping cli-config.json merge"
    STATUS_cliConfig="SKIPPED (node not found)"
else
    # Read cursor.cli preferences from profile.json (via config.json -> userRepoPath).
    # Falls back to defaults if profile not found.

    merge_rc=0
    MERGE_RESULT=$(node -e "
$SORT_KEYS_JS
const fs = require('fs');
const path = require('path');
const f = process.argv[1];
const dryRun = process.argv[2] === 'true';
const force = process.argv[3] === 'true';

// --- BEGIN profile preferences (replaced by build-deploy) ---
let vimMode = false;
let modelId = 'auto';
try {
    const cfgPath = path.join(process.env.HOME || process.env.USERPROFILE, '.aitools', 'config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    if (cfg.userRepoPath) {
        const pf = JSON.parse(fs.readFileSync(path.join(cfg.userRepoPath, 'profile.json'), 'utf8'));
        if (pf.cursor && pf.cursor.cli) {
            if (typeof pf.cursor.cli.vimMode === 'boolean') vimMode = pf.cursor.cli.vimMode;
            if (typeof pf.cursor.cli.model === 'string') modelId = pf.cursor.cli.model;
        }
    }
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read profile preferences: ' + e.message); }
// --- END profile preferences (replaced by build-deploy) ---

// --- Read existing cli-config.json ---
let config = {};
let corrupt = false;
try {
    config = JSON.parse(fs.readFileSync(f, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        corrupt = true;
        console.log('WARN: ' + f + ' is invalid JSON');
    }
}
const beforeKeys = Object.keys(config);
const before = JSON.stringify(sortKeys(config));

// Snapshot managed keys before merge for CHANGED: tracking
const snapshotKeys = ['version', 'editor', 'permissions', 'model', 'hasChangedDefaultModel'];
const beforeManaged = {};
for (const k of snapshotKeys) beforeManaged[k] = JSON.stringify(sortKeys(config[k]));

// --- Merge managed fields ---
config.version = 1;
if (!config.editor) config.editor = {};
config.editor.vimMode = vimMode;
if (!config.permissions) config.permissions = {};
if (!Array.isArray(config.permissions.allow)) config.permissions.allow = [];
if (!Array.isArray(config.permissions.deny)) config.permissions.deny = [];

// Model: only set if profile specifies 'auto' (the only supported value for now)
if (modelId === 'auto') {
    config.model = {
        modelId: 'default',
        displayModelId: 'auto',
        displayName: 'Auto',
        displayNameShort: 'Auto',
        aliases: ['auto'],
        maxMode: false
    };
    config.hasChangedDefaultModel = true;
}

// --- Clobber detection ---
const managedKeys = ['version', 'editor', 'permissions', 'model', 'hasChangedDefaultModel'];
const afterKeys = Object.keys(config);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

const after = JSON.stringify(sortKeys(config));

// Diagnostics go to stdout with a prefix (MSG: info, WARN: warning, DETAIL: log only)
// so bash can log them; the first unprefixed line is the status.
if (dryRun) {
    console.log('MSG: [DRY RUN] ' + f + ': merge');
    console.log('MSG:   Managed fields: ' + managedKeys.join(', '));
    if (lostKeys.length > 0) console.log('WARN: [DRY RUN] CLOBBER: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.log('WARN: [DRY RUN] File is corrupt -- --force required');
    console.log(before === after && !corrupt ? 'unchanged' : 'would-merge');
} else if (corrupt && !force) {
    console.log('DETAIL: ' + f + ' is corrupt. Use --force to overwrite, or fix manually.');
    console.log('error-corrupt');
} else if (lostKeys.length > 0 && !force) {
    console.log('DETAIL: merge would lose fields: ' + lostKeys.join(', ') + '. Use --force to proceed.');
    console.log('error-clobber');
} else {
    if (before === after) {
        console.log('unchanged');
    } else {
        if (corrupt) console.log('WARN: proceeding with --force on corrupt file');
        if (lostKeys.length > 0) console.log('WARN: proceeding with --force, losing fields: ' + lostKeys.join(', '));
        fs.writeFileSync(f, JSON.stringify(config, null, 2) + '\n');

        // Post-write validation
        const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
        const _missing = ['version'].filter(k => !(k in _v));
        if (_missing.length) { console.log('DETAIL: validation failed: missing ' + _missing.join(', ')); process.exit(1); }

        const changed = [];
        for (const k of snapshotKeys) {
            const oldVal = beforeManaged[k];
            const newVal = JSON.stringify(sortKeys(config[k]));
            if (oldVal !== newVal) changed.push(k + ': ' + (oldVal || '(unset)') + ' -> ' + (newVal || '(removed)'));
        }
        console.log(before === '{}' ? 'created' : 'merged');
        changed.forEach(c => console.log('CHANGED: ' + c));
    }
}
" "$CLI_CONFIG" "$DRY_RUN" "$FORCE") || merge_rc=$?

    # Log node's prefixed diagnostics; the first unprefixed line is the status.
    MERGE_STATUS=""
    while IFS= read -r line; do
        case "$line" in
            "MSG: "*)    log "${line#MSG: }" ;;
            "WARN: "*)   log_warn "${line#WARN: }" ;;
            "DETAIL: "*) log_detail "cli-config: ${line#DETAIL: }" ;;
            "CHANGED: "*) ;;
            *) if [ -z "$MERGE_STATUS" ]; then MERGE_STATUS="$line"; fi ;;
        esac
    done <<< "$MERGE_RESULT"
    # A non-zero node exit (post-write validation, uncaught error) overrides the status.
    if [ "$merge_rc" -ne 0 ]; then MERGE_STATUS="error-exit"; fi
    case "$MERGE_STATUS" in
        unchanged)
            log_ok "Already up to date: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="already up to date"
            write_summary OK "cursor cli" "verified" ;;
        created)
            log_ok "Created: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="created"
            emit_merge_details "$MERGE_RESULT" "cursor cli"
            write_summary OK "cursor cli" "created" ;;
        merged)
            log_ok "Merged preferences into: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="merged"
            emit_merge_details "$MERGE_RESULT" "cursor cli"
            write_summary OK "cursor cli" "updated" ;;
        would-merge)
            log "[DRY RUN] Would write merged config"
            STATUS_cliConfig="would merge (dry-run)" ;;
        error-corrupt)
            log_error "$(display_path "$CLI_CONFIG") is corrupt. Use --force to overwrite."
            STATUS_cliConfig="ERROR (corrupt, needs --force)"
            write_summary ERROR "cursor cli" "config corrupt" ;;
        error-clobber)
            log_error "$(display_path "$CLI_CONFIG") merge would lose fields. Use --force to proceed."
            STATUS_cliConfig="ERROR (clobber, needs --force)"
            write_summary ERROR "cursor cli" "merge would lose fields" ;;
        error-exit)
            log_error "$(display_path "$CLI_CONFIG") merge failed (node exit $merge_rc) -- see $(display_path "$LOG_FILE")"
            STATUS_cliConfig="ERROR (merge failed)"
            write_summary ERROR "cursor cli" "config merge failed (exit $merge_rc)" ;;
        *)
            log_error "Unexpected merge result: $MERGE_STATUS"
            STATUS_cliConfig="ERROR"
            write_summary ERROR "cursor cli" "unexpected error" ;;
    esac
fi

# --- 4. User rules fan-out: ~/.aitools/rules -> ~/.cursor/rules ---
# Cursor (IDE and CLI) loads <dir>/.cursor/rules/**/*.mdc for the workspace and
# every ancestor directory, so ~/.cursor/rules reaches every workspace under
# $HOME. Plain .md files are ignored there, and a .mdc needs a leading ---
# frontmatter block, so each Claude Code .md rule is converted
# (cursor_rule_from_md). Adopt is not offered (ADOPT_PATH ""): ~/.aitools/rules
# is the harness copy, not the repo source, and the deployed file is a
# converted form of it. Parity: step 4 in setup-user-cursor.ps1.

log "Step 4: Cursor user rules"

HARNESS_RULES_DIR="$HOME/.aitools/rules"
CURSOR_RULES_DIR="$CURSOR_DIR/rules"

# Print the Cursor .mdc form of the Claude Code rule file $1 on stdout.
#   - No frontmatter: "alwaysApply: true" is added (always loaded, as in Claude Code).
#   - A top-level "paths:" key (Claude Code path scoping: a block list, a list at
#     column 0, one value, or a [a, b] flow list) becomes a "globs:" block list,
#     one "  - " item per pattern (Cursor splits an inline value on commas and
#     reads only indented items). Each relative pattern is anchored as
#     "**/<pattern>": Cursor matches a user rule's glob against the file path
#     relative to the directory that owns .cursor/rules ($HOME), and Claude Code
#     paths are project-relative. Absolute and "**/" patterns are kept.
#     "alwaysApply: false" is added unless the frontmatter sets alwaysApply.
#   - Every other frontmatter line and the body are kept; CRLF becomes LF and a
#     UTF-8 BOM is dropped. Parity: ConvertTo-CursorRule in setup-user-cursor.ps1.
cursor_rule_from_md() {
    perl -e '
        sub anchor {
            my $g = shift;
            $g =~ s/\A\s+//; $g =~ s/\s+\z//;
            if ($g =~ /\A"(.*)"\z/) { $g = $1 } elsif ($g =~ /\A\x27(.*)\x27\z/) { $g = $1 }
            return "" if $g eq "";
            return $g if $g eq "**" || $g =~ m{\A(?:/|\*\*/|[A-Za-z]:[\\/]|\\\\)};
            $g =~ s{\A\./}{};
            return "**/$g";
        }
        sub flow_items {
            my ($v, $depth, $cur, @items) = (shift, 0, "");
            for my $c (split //, $v) {
                if ($c eq "{") { $depth++ } elsif ($c eq "}" && $depth > 0) { $depth-- }
                if ($c eq "," && $depth == 0) { push @items, $cur; $cur = ""; next }
                $cur .= $c;
            }
            push @items, $cur;
            return @items;
        }
        local $/; my $t = <STDIN>; $t = "" unless defined $t;
        $t =~ s/\A\xEF\xBB\xBF//; $t =~ s/\r\n/\n/g;
        if ($t =~ /\A---[ \t]*\n(?:(.*?)\n)?---[ \t]*(?:\n|\z)(.*)\z/s) {
            my ($fm, $body) = (defined $1 ? $1 : "", $2);
            my (@out, $always, $globs, $in_paths);
            for my $line (split /\n/, $fm, -1) {
                if ($line =~ /^paths:[ \t]*(.*?)[ \t]*$/) {
                    my $v = $1; my @items;
                    if ($v =~ /\A\[(.*)\]\z/) { @items = flow_items($1) } elsif ($v ne "") { @items = ($v) }
                    push @out, "globs:"; $in_paths = 1;
                    for my $i (@items) { my $g = anchor($i); if ($g ne "") { push @out, "  - $g"; $globs = 1 } }
                    next;
                }
                next if $in_paths && $line =~ /^\s*#/;   # YAML comment inside the list
                if ($in_paths && $line =~ /^\s*-\s+(.*)$/) {
                    my $g = anchor($1); if ($g ne "") { push @out, "  - $g"; $globs = 1 }
                    next;
                }
                $in_paths = 0;
                $always = 1 if $line =~ /^alwaysApply:/;
                $globs = 1 if $line =~ /^globs:/;
                push @out, $line;
            }
            push @out, ($globs ? "alwaysApply: false" : "alwaysApply: true") unless $always;
            print "---\n", join("\n", @out), "\n---\n", $body;
        } else {
            print "---\nalwaysApply: true\n---\n", $t;
        }
    ' < "$1"
}

# Check a converted .mdc ($1) the way Cursor parses it: Cursor splits the whole
# file on "---" and takes the first non-empty piece as the frontmatter, so a
# "---" inside a frontmatter value moves the rest of it into the body. The
# converter always writes alwaysApply, so a parsed frontmatter without it means
# Cursor would misread the rule. Prints a reason, or nothing when the file is fine.
# Parity: Test-CursorRuleParse in setup-user-cursor.ps1.
cursor_rule_check() {
    perl -e '
        local $/; my $t = <STDIN>; $t = "" unless defined $t;
        $t =~ s/\A\s+//;
        exit 0 unless $t =~ /\A---/;   # no frontmatter: already an error in the caller
        my @p = grep { length } split /---/, $t, -1;
        my $fm = @p ? $p[0] : "";
        print "Cursor would not see alwaysApply in its frontmatter (a --- inside a frontmatter value?)" unless $fm =~ /^alwaysApply:/m;
    ' < "$1"
}

# Lower-case a name (duplicate detection: APFS and NTFS are case-insensitive)
lower_name() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

if [ ! -d "$HARNESS_RULES_DIR" ]; then
    log "No harness rules at $(display_path "$HARNESS_RULES_DIR") (deploy-harness has not run) -- skipping"
    write_summary OK "cursor rules" "n/a (no harness rules)"
elif [ ! -r "$HARNESS_RULES_DIR" ] || [ ! -x "$HARNESS_RULES_DIR" ]; then
    log_error "Cannot list $(display_path "$HARNESS_RULES_DIR") (permission denied)"
    write_summary ERROR "cursor rules" "cannot read harness rules"
else
    # Source files: every regular, non-hidden file, flat (the deploy-harness contract)
    RULE_SOURCES=""
    RULE_BROKEN=""   # dangling symlinks: reported as failed in the deploy loop
    for rule_src in "$HARNESS_RULES_DIR"/*; do
        if [ ! -e "$rule_src" ] && [ ! -L "$rule_src" ]; then
            continue   # the unexpanded glob of an empty directory
        fi
        rule_base=$(basename "$rule_src")
        # Contract (S3-Harness correction): only *.md rules; *.bak.* are the
        # backups deploy_managed_file leaves next to updated harness files
        case "$rule_base" in
            *.bak.*) continue ;;
            *.md) ;;
            *) log "Ignoring non-rule file in harness rules: $rule_base (only *.md is fanned out)"
               continue ;;
        esac
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

    if [ -z "$RULE_SOURCES" ] && [ -z "$RULE_BROKEN" ]; then
        log "Harness rules directory $(display_path "$HARNESS_RULES_DIR") is empty -- skipping"
        write_summary OK "cursor rules" "n/a (no harness rules)"
    else
        if [ "$DRY_RUN" != "true" ]; then
            backup_dir "$CURSOR_RULES_DIR"
            if ! mkdir -p "$CURSOR_RULES_DIR"; then
                log_error "Cannot create $(display_path "$CURSOR_RULES_DIR")"
            fi
        fi

        deploy_tracker_init
        ERRORS_BEFORE_CURSOR_RULES=$ERRORS
        while IFS= read -r broken_name; do
            [ -n "$broken_name" ] || continue
            log_error "Failed: $broken_name: dangling symlink in $(display_path "$HARNESS_RULES_DIR")"
            deploy_tracker_record "failed" "cursor rules" "$broken_name"
        done <<< "$RULE_BROKEN"

        # Newline-separated name lists (bash 3.2: no associative arrays)
        RULE_DESTS=""       # deployed names
        RULE_DESTS_LC=""    # the same, lower-cased (duplicate and preserved checks)
        while IFS= read -r rule_src; do
            [ -n "$rule_src" ] || continue
            rule_base=$(basename "$rule_src")
            dest_name="${rule_base%.md}.mdc"

            # Two sources mapping to one target (names that differ only in case,
            # possible on a case-sensitive file system): the first wins
            dest_lc=$(lower_name "$dest_name")
            case "
$RULE_DESTS_LC" in
                *"
$dest_lc
"*)
                    log_error "Skipped duplicate: $rule_base -> $dest_name (already deployed from another harness rule)"
                    deploy_tracker_record "failed" "cursor rules" "$rule_base"
                    continue ;;
            esac
            RULE_DESTS="${RULE_DESTS}${dest_name}
"
            RULE_DESTS_LC="${RULE_DESTS_LC}${dest_lc}
"

            rule_content=""
            if ! rule_content=$(cursor_rule_from_md "$rule_src"); then
                log_error "Failed: $rule_base: conversion to .mdc failed"
                deploy_tracker_record "failed" "cursor rules" "$dest_name"
                continue
            fi
            if [ -z "$rule_content" ]; then
                log_error "Failed: $rule_base: empty after conversion -- nothing written"
                deploy_tracker_record "failed" "cursor rules" "$dest_name"
                continue
            fi

            deploy_managed_file "$rule_content" "$CURSOR_RULES_DIR/$dest_name" "cursor rules" "$dest_name" ""
            case "$MANAGED_FILE_RESULT" in
                created|updated|verified|skipped|failed)
                    # The library wrote (or left) LOCAL; the tracker records every
                    # outcome (failed -> ERROR row, skipped -> WARN row).
                    ;;
                "accept & adopt")
                    # Not reachable: adopt is not offered without an adopt target
                    log_error "Unexpected accept & adopt for $dest_name (no adopt target)" ;;
                *)
                    log_error "Unexpected deploy result for ${dest_name}: $MANAGED_FILE_RESULT"
                    MANAGED_FILE_RESULT="failed" ;;
            esac
            deploy_tracker_record "$MANAGED_FILE_RESULT" "cursor rules" "$dest_name"
        done <<< "$RULE_SOURCES"

        if [ "$DRY_RUN" = "true" ]; then
            if [ "$_DT_FAILED" -gt 0 ]; then
                write_summary ERROR "cursor rules" "$_DT_FAILED failed (dry run)"
            else
                write_summary OK "cursor rules" "dry run (no files written)"
            fi
        else
            # Preserved: files in ~/.cursor/rules not produced from ~/.aitools/rules
            for existing in "$CURSOR_RULES_DIR"/*; do
                [ -f "$existing" ] || continue
                exist_name=$(basename "$existing")
                case "$exist_name" in *.bak.*) continue ;; esac
                exist_lc=$(lower_name "$exist_name")
                case "
$RULE_DESTS_LC" in
                    *"
$exist_lc
"*) ;;
                    *)  log "Preserved unmanaged rule: $exist_name"
                        deploy_tracker_record "preserved" "cursor rules" "$exist_name" ;;
                esac
            done

            # Post-write validation: non-empty, and a .mdc starts with frontmatter
            while IFS= read -r dest_name; do
                [ -n "$dest_name" ] || continue
                dest_path="$CURSOR_RULES_DIR/$dest_name"
                [ -f "$dest_path" ] || continue
                if [ ! -s "$dest_path" ]; then
                    log_error "Validation failed: $dest_name is empty after deploy"
                    continue
                fi
                case "$dest_name" in
                    *.mdc)
                        first_line=""
                        # read fails on a last line without a newline; first_line is still set and checked below
                        IFS= read -r first_line < "$dest_path" || true
                        case "$first_line" in
                            ---*) ;;
                            *) log_error "Validation failed: $dest_name has no frontmatter (Cursor skips it)" ;;
                        esac ;;
                esac
            done <<< "$RULE_DESTS"

            # Check each deployed rule as Cursor parses it (warn: the rule is
            # deployed but Cursor would misread its frontmatter)
            while IFS= read -r dest_name; do
                [ -n "$dest_name" ] || continue
                dest_path="$CURSOR_RULES_DIR/$dest_name"
                [ -s "$dest_path" ] || continue
                if ! parse_problem=$(cursor_rule_check "$dest_path"); then
                    log_error "Validation failed: cannot check $dest_name"
                elif [ -n "$parse_problem" ]; then
                    log_warn "$dest_name: $parse_problem -- fix the source rule in ~/.aitools/rules"
                fi
            done <<< "$RULE_DESTS"

            if [ "$_DT_FAILED" -gt 0 ]; then
                # deploy_tracker_summary writes the ERROR row ("N failed")
                deploy_tracker_summary "cursor rules"
                log "Cursor rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$CURSOR_RULES_DIR")"
            elif [ "$ERRORS" -eq "$ERRORS_BEFORE_CURSOR_RULES" ]; then
                deploy_tracker_summary "cursor rules"
                log_ok "Cursor rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$CURSOR_RULES_DIR")"
            else
                write_summary ERROR "cursor rules" "validation failed"
            fi
        fi
    fi
fi

# --- END cursor body (extracted by build-deploy) ---

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
