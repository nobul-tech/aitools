#!/usr/bin/env bash
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: /tool-registry skill (registries/tool-registry.json)
#
# Does four things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#   4. Fans the user-level harness rules (~/.aitools/rules) out to Cursor's user
#      rule files (~/.cursor/rules/*.mdc), converting each Claude Code .md rule to .mdc
#
# cli-config.json:
#   Managed fields: version, editor, permissions, model, hasChangedDefaultModel
#   Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields
# ~/.cursor/rules/ (additive deploy, pruned against the rules manifest):
#   Managed: one <name>.mdc per ~/.aitools/rules/<name>.md whose source in
#            ~/.aitools/rules/.aitools-rules-manifest is shared or dotprofile
#            (user-level rules only; commander decision 2026-10-22). *.bak.*
#            backups, the manifest and non-.md files are not fanned out.
#   Removed (backup kept): <name>.mdc for a manifest name whose source is
#            aitools (project rules) or retired, only if the fan-out created it
#            (the aitools-fanout marker line, or, for files from before the
#            marker, the same content as the conversion of the harness copy or
#            of one of its *.bak.* backups); any other file of such a name is
#            kept with a warning and an ACTION row (Cursor still loads it)
#   Preserved: every other ~/.cursor/rules/ file
#   No manifest, or one with another first line: nothing fanned out, nothing
#   removed, WARN row + ACTION (run aitools)
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
    # Read cursor.cli preferences from <dotprofile>/profile.json. The dotprofile
    # comes from the one resolver (reference/user-repo.md "Resolution"; SD-7) and
    # reaches node as arguments (path, rc); node never reads config.json itself.
    # rc is captured, not suppressed: 0 found, 1 no dotprofile (shared-only
    # mode: default preferences), 3 resolver error (the lib already logged it:
    # log_error + ERROR row "dotprofile"). On 3 the node preferences
    # block skips the merge rather than write defaults over the user's choices.
    # The generated deploy/ copy replaces that block with build-time values, so
    # there the arguments are unused (build-deploy follow-up: B5).
    URP_RC=0
    resolve_user_repo_path || URP_RC=$?
    USER_REPO_PATH="$AITLIB_USER_REPO_PATH"

    merge_rc=0
    MERGE_RESULT=$(node -e "
$SORT_KEYS_JS
const fs = require('fs');
const path = require('path');
const f = process.argv[1];
const dryRun = process.argv[2] === 'true';
const force = process.argv[3] === 'true';

// --- BEGIN profile preferences (replaced by build-deploy) ---
// argv[4] = dotprofile path (resolve_user_repo_path), argv[5] = its rc.
let vimMode = false;
let modelId = 'auto';
const userRepoPath = process.argv[4] || '';
const urpRc = process.argv[5] || '0';
if (urpRc !== '0' && urpRc !== '1') {
    console.log('skipped-dotprofile');
    process.exit(0);
}
if (userRepoPath) {
    const pfPath = path.join(userRepoPath, 'profile.json');
    try {
        const pf = JSON.parse(fs.readFileSync(pfPath, 'utf8'));
        if (pf.cursor && pf.cursor.cli) {
            if (typeof pf.cursor.cli.vimMode === 'boolean') vimMode = pf.cursor.cli.vimMode;
            if (typeof pf.cursor.cli.model === 'string') modelId = pf.cursor.cli.model;
        }
    } catch (e) {
        if (e.code === 'ENOENT') console.log('DETAIL: no profile.json in ' + userRepoPath + ' -- default preferences');
        else console.log('WARN: could not read profile preferences from ' + pfPath + ': ' + e.message + ' -- default preferences');
    }
}
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
" "$CLI_CONFIG" "$DRY_RUN" "$FORCE" "$USER_REPO_PATH" "$URP_RC") || merge_rc=$?

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
        skipped-dotprofile)
            # Not counted again: the resolver error is already an error and the
            # ERROR row "dotprofile" (the lib wrote both).
            log "Skipped the $(display_path "$CLI_CONFIG") merge: dotprofile unresolved (resolver error above), so the profile preferences are unknown"
            STATUS_cliConfig="SKIPPED (dotprofile error)"
            write_summary ERROR "cursor cli" "skipped (dotprofile error)" ;;
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
# converted form of it. Cursor gets user-level rules only (commander decision
# 2026-10-22): the rules manifest deploy-harness writes (PR #100 contract)
# names each rule's source; shared and dotprofile rules are fanned out, and
# the .mdc of an aitools or retired rule is removed when the fan-out created
# it. Parity: step 4 in setup-user-cursor.ps1.

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
#     UTF-8 BOM is dropped.
#   - With a rule name $2, the line after the frontmatter is the aitools-fanout
#     marker (CURSOR_FANOUT_MARKER + name): it tells a file this fan-out created
#     from a user's own .mdc, so pruning never removes the user's file.
#     Parity: ConvertTo-CursorRule in setup-user-cursor.ps1.
CURSOR_FANOUT_MARKER="<!-- aitools-fanout: generated by setup-user-cursor from ~/.aitools/rules/"
cursor_rule_from_md() {
    perl -e '
        my $name = defined $ARGV[0] ? $ARGV[0] : "";
        my $mark = $name eq "" ? "" : "$ARGV[1]$name; edit that rule, not this file -->\n";
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
            print "---\n", join("\n", @out), "\n---\n", $mark, $body;
        } else {
            print "---\nalwaysApply: true\n---\n", $mark, $t;
        }
    ' "${2:-}" "$CURSOR_FANOUT_MARKER" < "$1"
}

# Exit 0 when the .mdc $1 was created by this fan-out: the line right after its
# frontmatter starts with CURSOR_FANOUT_MARKER. Exit 1 when it was not, any
# other code when $1 cannot be read. Parity: Test-CursorFanoutRule in setup-user-cursor.ps1.
cursor_rule_is_fanout() {
    perl -e '
        my ($f, $mark) = @ARGV;
        open my $fh, "<:raw", $f or die "cannot read $f: $!\n";
        local $/; my $t = <$fh>; close $fh; $t = "" unless defined $t;
        $t =~ s/\A\xEF\xBB\xBF//; $t =~ s/\r\n/\n/g;
        # Frontmatter lines may not be "---": the marker must follow the FIRST closing ---
        exit(($t =~ /\A---[ \t]*\n(?:(?!---[ \t]*\n)[^\n]*\n)*---[ \t]*\n\Q$mark\E/) ? 0 : 1);
    ' "$1" "$CURSOR_FANOUT_MARKER"
}

# Print the rules manifest $1 (deploy-harness section 5b, PR #100 contract) as
# lines "rule<TAB><name><TAB><source>" and "invalid<TAB><line, tabs as <TAB>>",
# or the one line "header-bad" when its first line is not RULES_MANIFEST_HEADER.
# A valid line: a *.md name with no / or \ and no .bak., a source of shared,
# aitools, dotprofile or retired, and a name not already listed (compared
# case-insensitively). Exit non-zero (message on stderr) when $1 cannot be read.
# Parity: Read-RulesManifest in setup-user-cursor.ps1.
RULES_MANIFEST_HEADER="# aitools rules manifest v1"
read_rules_manifest() {
    perl -e '
        my ($f, $header) = @ARGV;
        open my $fh, "<:raw", $f or die "cannot read $f: $!\n";
        my $head = <$fh>; $head = "" unless defined $head;
        $head =~ s/\A\xEF\xBB\xBF//; $head =~ s/\r?\n\z//;
        if ($head ne $header) { print "header-bad\n"; exit 0 }
        my %seen;
        while (my $l = <$fh>) {
            $l =~ s/\r?\n\z//;
            next if $l eq "";
            my ($name, $src) = split /\t/, $l, 2;
            $src = "" unless defined $src;
            if ($name !~ /\A[^\/\\]+\.md\z/ || $name =~ /\.bak\./
                    || $src !~ /\A(?:shared|aitools|dotprofile|retired)\z/ || $seen{lc $name}++) {
                (my $show = $l) =~ s/\t/<TAB>/g;
                print "invalid\t$show\n";
                next;
            }
            print "rule\t$name\t$src\n";
        }
        close $fh;
    ' "$1" "$RULES_MANIFEST_HEADER"
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

# Exit 0 when the line $1 is in the newline-separated list $2 (bash 3.2: no
# associative arrays)
in_list() {
    case "
$2" in
        *"
$1
"*) return 0 ;;
    esac
    return 1
}

RULES_MANIFEST="$HARNESS_RULES_DIR/.aitools-rules-manifest"
TAB=$(printf '\t')
MANIFEST_OK=false
ENTITLED_NAMES=""   # manifest names Cursor gets (source shared or dotprofile)
ENTITLED_LC=""      # the same, lower-cased
REMOVE_RULES=""     # "<name><TAB><source>" for source aitools or retired
REMOVE_LC=""        # their names, lower-cased

if [ ! -d "$HARNESS_RULES_DIR" ]; then
    log "No harness rules at $(display_path "$HARNESS_RULES_DIR") (deploy-harness has not run) -- skipping"
    write_summary OK "cursor rules" "n/a (no harness rules)"
elif [ ! -r "$HARNESS_RULES_DIR" ] || [ ! -x "$HARNESS_RULES_DIR" ]; then
    log_error "Cannot list $(display_path "$HARNESS_RULES_DIR") (permission denied)"
    write_summary ERROR "cursor rules" "cannot read harness rules"
elif [ ! -e "$RULES_MANIFEST" ]; then
    # Safe behaviour: without the manifest the source of each rule is unknown,
    # so nothing is fanned out (a project rule would load in every chat) and
    # nothing is removed (a user-level rule could be taken for a project rule)
    log_warn "No rules manifest at $(display_path "$RULES_MANIFEST") -- Cursor rules left unchanged (nothing fanned out, nothing removed)"
    write_summary WARN "cursor rules" "no rules manifest"
    write_summary ACTION "" "Run aitools to rebuild ~/.aitools/rules and its manifest"
else
    manifest_out=""
    if ! manifest_out=$(read_rules_manifest "$RULES_MANIFEST" 2>&1); then
        log_error "Cannot read the rules manifest $(display_path "$RULES_MANIFEST"): $manifest_out"
        write_summary ERROR "cursor rules" "cannot read rules manifest"
    elif [ "$manifest_out" = "header-bad" ]; then
        log_warn "Rules manifest $(display_path "$RULES_MANIFEST"): the first line is not \"$RULES_MANIFEST_HEADER\" -- Cursor rules left unchanged (nothing fanned out, nothing removed)"
        write_summary WARN "cursor rules" "rules manifest not v1"
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
                    m_lc=$(lower_name "$m_name")
                    case "$m_src" in
                        shared|dotprofile)
                            ENTITLED_NAMES="${ENTITLED_NAMES}${m_name}
"
                            ENTITLED_LC="${ENTITLED_LC}${m_lc}
" ;;
                        *)
                            REMOVE_RULES="${REMOVE_RULES}${m_name}${TAB}${m_src}
"
                            REMOVE_LC="${REMOVE_LC}${m_lc}
" ;;
                    esac ;;
            esac
        done <<< "$manifest_out"
    fi
fi

if [ "$MANIFEST_OK" = "true" ]; then
    # Source files: every regular, non-hidden file, flat (the deploy-harness
    # contract), that the manifest lists as a user-level rule
    RULE_SOURCES=""
    RULE_BROKEN=""   # dangling symlinks: reported as failed in the deploy loop
    FOUND_LC=""      # entitled names found in the directory, lower-cased
    for rule_src in "$HARNESS_RULES_DIR"/*; do
        if [ ! -e "$rule_src" ] && [ ! -L "$rule_src" ]; then
            continue   # the unexpanded glob of an empty directory
        fi
        rule_base=$(basename "$rule_src")
        # Contract (S3-Harness correction): only *.md rules; *.bak.* are the
        # backups deploy_managed_file leaves next to updated harness files.
        # The glob skips hidden files, so the manifest itself is never listed.
        case "$rule_base" in
            *.bak.*) continue ;;
            *.md) ;;
            *) log "Ignoring non-rule file in harness rules: $rule_base (only *.md is fanned out)"
               continue ;;
        esac
        # Cursor gets user-level rules only (commander decision 2026-10-22)
        rule_lc=$(lower_name "$rule_base")
        if ! in_list "$rule_lc" "$ENTITLED_LC"; then
            if in_list "$rule_lc" "$REMOVE_LC"; then
                log_detail "Not fanned out: $rule_base (a project or retired rule in the rules manifest)"
            else
                log "Not fanned out: $rule_base (not in the rules manifest)"
            fi
            continue
        fi
        FOUND_LC="${FOUND_LC}${rule_lc}
"
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

    # A user-level name in the manifest with no file: nothing to fan out
    while IFS= read -r m_name; do
        [ -n "$m_name" ] || continue
        if ! in_list "$(lower_name "$m_name")" "$FOUND_LC"; then
            log_warn "Not fanned out: $m_name is in the rules manifest but not in $(display_path "$HARNESS_RULES_DIR") (run aitools to rebuild it)"
        fi
    done <<< "$ENTITLED_NAMES"

    if [ -z "$RULE_SOURCES" ] && [ -z "$RULE_BROKEN" ] && [ -z "$REMOVE_RULES" ]; then
        log "No user-level rules in $(display_path "$HARNESS_RULES_DIR") -- skipping"
        write_summary OK "cursor rules" "n/a (no user-level rules)"
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
            if ! rule_content=$(cursor_rule_from_md "$rule_src" "$rule_base"); then
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

        # Prune: a project (aitools) or retired rule must not stay loaded in
        # Cursor. Its .mdc is removed (backup kept) only when this fan-out created
        # it: the aitools-fanout marker, or, for a file deployed before the marker
        # existed (PR #87), the same content as the conversion of the harness copy.
        # Any other file of that name is the user's and is preserved.
        N_REMOVED=0
        RM_KEPT=""   # project/retired names kept because the fan-out did not create them
        while IFS= read -r rm_line; do
            [ -n "$rm_line" ] || continue
            rm_name="${rm_line%%"$TAB"*}"
            rm_src="${rm_line#*"$TAB"}"
            rm_dest="${rm_name%.md}.mdc"
            # Deployed this run from a user-level rule whose name differs only in case
            if in_list "$(lower_name "$rm_dest")" "$RULE_DESTS_LC"; then continue; fi
            rm_path="$CURSOR_RULES_DIR/$rm_dest"
            [ -f "$rm_path" ] || continue
            rm_why=""
            if cursor_rule_is_fanout "$rm_path"; then
                rm_why="aitools-fanout marker"
            else
                rm_rc=$?
                if [ "$rm_rc" -ne 1 ]; then
                    log_error "Cannot read $(display_path "$rm_path") -- not removed"
                    deploy_tracker_record "failed" "cursor rules" "$rm_dest"
                    continue
                fi
                # No marker (a PR #87 file): compare with the conversion of the
                # harness copy and of each backup deploy-harness left beside it
                # (it backs a rule up when it updates or retires it), so a rule
                # edited or retired since the #87 run is still recognised
                rm_current=""
                if ! rm_current=$(cat "$rm_path"); then
                    log_error "Cannot read $(display_path "$rm_path") -- not removed"
                    deploy_tracker_record "failed" "cursor rules" "$rm_dest"
                    continue
                fi
                for rm_cand in "$HARNESS_RULES_DIR/$rm_name" "$HARNESS_RULES_DIR/$rm_name".bak.*; do
                    [ -f "$rm_cand" ] || continue
                    rm_legacy=""
                    if rm_legacy=$(cursor_rule_from_md "$rm_cand") \
                        && [ -n "$rm_legacy" ] && [ "$rm_legacy" = "$rm_current" ]; then
                        rm_why="same content as the conversion of $(basename "$rm_cand")"
                        break
                    fi
                done
            fi
            if [ -z "$rm_why" ]; then
                # Kept (it may be the user's own file), but Cursor still loads it
                log_warn "Kept $rm_dest: the rules manifest lists $rm_name as $rm_src (Cursor gets user-level rules only), but this file was not created by the fan-out (no aitools-fanout marker, no matching harness copy) -- Cursor still loads it; remove it if it is an old fan-out copy"
                RM_KEPT="${RM_KEPT:+$RM_KEPT, }$rm_dest"
                continue
            fi
            if [ "$DRY_RUN" = "true" ]; then
                log "[DRY RUN] Would back up and remove $rm_dest ($rm_src rule; $rm_why)"
                continue
            fi
            backup_file "$rm_path"
            if ! $BACKUP_FILE_OK; then
                log_error "Not removed: $rm_dest ($rm_src rule): backup failed"
                deploy_tracker_record "failed" "cursor rules" "$rm_dest"
                continue
            fi
            if ! rm -f "$rm_path" || [ -e "$rm_path" ]; then
                log_error "Cannot remove $(display_path "$rm_path") ($rm_src rule)"
                deploy_tracker_record "failed" "cursor rules" "$rm_dest"
                continue
            fi
            N_REMOVED=$((N_REMOVED + 1))
            log "Removed $rm_dest ($rm_src rule: Cursor gets user-level rules only; $rm_why; backup kept)"
            write_summary DETAIL "cursor rules" "removed: $rm_dest"
        done <<< "$REMOVE_RULES"
        if [ -n "$RM_KEPT" ]; then
            write_summary ACTION "" "Cursor still loads project/retired rules in ~/.cursor/rules: $RM_KEPT -- delete them unless you wrote them"
        fi

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
                log "Cursor rules: $DEPLOY_TRACKER_TEXT, $N_REMOVED removed, $_DT_PRESERVED preserved in $(display_path "$CURSOR_RULES_DIR")"
            elif [ "$ERRORS" -eq "$ERRORS_BEFORE_CURSOR_RULES" ]; then
                if [ -z "$RULE_DESTS" ]; then
                    # Nothing fanned out: the row reports the pruning alone
                    if [ "$N_REMOVED" -gt 0 ]; then
                        write_summary OK "cursor rules" "$N_REMOVED removed"
                    else
                        write_summary OK "cursor rules" "n/a (no user-level rules)"
                    fi
                    log_ok "Cursor rules: no user-level rules, $N_REMOVED removed, $_DT_PRESERVED preserved in $(display_path "$CURSOR_RULES_DIR")"
                else
                    deploy_tracker_summary "cursor rules"
                    log_ok "Cursor rules: $DEPLOY_TRACKER_TEXT, $N_REMOVED removed, $_DT_PRESERVED preserved in $(display_path "$CURSOR_RULES_DIR")"
                fi
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
