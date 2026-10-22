#!/usr/bin/env bash
# build-deploy.sh — Generates self-contained deploy/ scripts from scripts/ + shared/
#
# Output goes to deploy/ only. There is no separate build/ directory in this repo;
# CI and MDM both consume deploy/.
#
# Reads shared content files and embeds them into deploy versions of setup scripts.
# The deploy/ scripts have zero dependencies on the repo or Google Drive — they can
# be deployed to any endpoint via MDM (Jamf, Intune) or run manually.
#
# deploy/deploy-harness.sh/.ps1 (the MDM path of scripts/deploy-harness.*) embed a
# snapshot of every harness source file (~/.aitools); MDM runs it first, before
# setup-user-cursor, whose rules fan-out reads ~/.aitools/rules. Its config.json
# writer (setup-user-config + aitools-profile + aitools-json) is copied alongside.
#
# Relay → ~/.cursor/AGENTS.md: NOT embedded here. That step needs the live repo file
# `.aitools/channel/relay.md` and runs from `scripts/sync-relay-to-cursor-agents.py`
# during `aitools` / `aitools install` (see scripts/aitools deploy_configs).
#
# Usage: bash scripts/build-deploy.sh   (run from repo root)
#
# CROSS-PLATFORM NOTE: This script is intentionally bash-only (no .ps1 variant).
# It's a build step that produces platform-independent output (both .sh and .ps1
# deploy scripts). The result is committed to git, so both platforms get identical
# deploy/ contents. A parallel PS1 would double maintenance for no output difference.
# On Windows, aitools.ps1 invokes this via Git Bash (a prerequisite for Claude Code).
# See .claude/rules/cross-platform.md "Approved exceptions" for the exception record.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
DEPLOY_DIR="$REPO_ROOT/deploy"
SHARED_DIR="$REPO_ROOT/shared"

# Strawberry Perl text-mode fix: PERLIO=:perlio disables CRLF translation that
# causes double-CR (\r\r\n) in extract_between --crlf output. No-op for Git's
# bundled perl (already uses :unix:perlio). See reference/cross-platform-detail.md.
export PERLIO=:perlio

# --- Build logging (standalone -- does not source aitools-lib.sh) ---
SCRIPT_NAME="build-deploy"
blog()       { printf '[%s] [%s] [info] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_ok()    { printf '[%s] [%s] [ok] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_warn()  { printf '\033[33m[%s] [%s] [warn] %s\033[0m\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" >&2; }
blog_error() { printf '\033[31m[%s] [%s] [error] %s\033[0m\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" >&2; }

# Shared content files
CLAUDE_SHARED="$SHARED_DIR/claude-shared.md"

# Verify shared files exist
if [ ! -f "$CLAUDE_SHARED" ]; then
    blog_error "Required shared file not found: $CLAUDE_SHARED"
    exit 1
fi
# Verify at least one skill file exists in shared/skills/
_skill_count=0
for _skill_dir in "$SHARED_DIR/skills"/*/; do
    [ -d "$_skill_dir" ] || continue
    if [ -f "$_skill_dir/SKILL.md" ]; then
        _skill_count=$((_skill_count + 1))
    else
        blog_warn "Skill directory missing SKILL.md: $_skill_dir"
    fi
done
if [ "$_skill_count" -eq 0 ]; then
    blog_error "No skill files found in $SHARED_DIR/skills/"
    exit 1
fi
blog "Found $_skill_count skill(s) in shared/skills/"
# Hook + helper preflight: file list derived from hooks-manifest.json (single
# source of truth -- no hardcoded hook filenames in this script; see issue #9).
# Resolution mirrors the embed loops: shared/hooks/ first, then scripts/ (the
# manifest 'deploy' helpers may live in either).
HOOKS_MANIFEST="$SHARED_DIR/hooks/hooks-manifest.json"
if [ ! -f "$HOOKS_MANIFEST" ]; then
    blog_error "Required manifest not found: $HOOKS_MANIFEST"
    exit 1
fi
# node is required to build: manifest parsing here, the dotprofile lookup below,
# and the hook embed loops all shell out to node. A node-less machine has never
# been able to build (the dotprofile lookup needs node, so the build skipped);
# keep that a graceful skip (exit 0) so 'aitools' continues to the installer
# step that installs node. The silent-failure case this preflight closes is node
# PRESENT but the manifest unparseable -- that is handled (exit 1) just below.
if ! command -v node >/dev/null 2>&1; then
    blog_warn "node not found -- skipping deploy build (node is installed by 'aitools install')"
    exit 0
fi
_manifest_files=$(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log([...m.hooks.map(h=>h.file),...(m.deploy||[])].join("\n"))' "$HOOKS_MANIFEST") || {
    blog_error "Failed to parse $HOOKS_MANIFEST"
    exit 1
}
_hook_count=0
while IFS= read -r _hook_file; do
    [ -n "$_hook_file" ] || continue
    if [ ! -f "$SHARED_DIR/hooks/$_hook_file" ] && [ ! -f "$SCRIPTS_DIR/$_hook_file" ]; then
        blog_error "Manifest-listed hook file not found: $_hook_file (searched shared/hooks/ and scripts/)"
        exit 1
    fi
    _hook_count=$((_hook_count + 1))
done <<< "$_manifest_files"
blog "Preflight OK: $_hook_count hook/helper file(s) from hooks-manifest.json"

# Cursor AGENTS mirror (repo runtime — requires .aitools/channel/relay.md; not in deploy/)
if [ ! -f "$SCRIPTS_DIR/sync-relay-to-cursor-agents.py" ]; then
    blog_error "Required script not found: $SCRIPTS_DIR/sync-relay-to-cursor-agents.py"
    exit 1
fi
blog "Found sync-relay-to-cursor-agents.py (relay→AGENTS runs from aitools deploy, not from deploy/)"

# Read shared content
# (Hook contents are NOT read into variables here -- the embed loops read each
# file directly from the hooks-manifest.json list. Keeping per-hook variables
# was dead code and a hardcoded list that drifted; see issue #9.)
CLAUDE_SHARED_CONTENT=$(cat "$CLAUDE_SHARED")

# inline_lib_bash: replaces `source.*aitools-lib.sh` line with lib content (stdin -> stdout)
# Uses perl for performance (single process vs ~2 subprocesses per line with while-read)
inline_lib_bash() {
    perl -e '
        open my $lib, "<", $ARGV[0] or die "Cannot open lib: $!";
        my $content = do { local $/; <$lib> };
        close $lib;
        while (<STDIN>) {
            if (/source.*aitools-lib\.sh/) {
                print $content;
            } else {
                print;
            }
        }
    ' "$SCRIPTS_DIR/aitools-lib.sh"
}

# inline_lib_ps1: replaces `. .*aitools-lib.ps1` line with lib content (stdin -> stdout)
# Uses perl for performance (single process vs ~2 subprocesses per line with while-read)
inline_lib_ps1() {
    perl -e '
        open my $lib, "<", $ARGV[0] or die "Cannot open lib: $!";
        my $content = do { local $/; <$lib> };
        close $lib;
        while (<STDIN>) {
            if (/aitools-lib\.ps1/) {
                print $content;
            } else {
                print;
            }
        }
    ' "$SCRIPTS_DIR/aitools-lib.ps1"
}

# --- Read user rules for embedding ---
# User rules are embedded at build time into deploy scripts.
# At runtime, deploy scripts write embedded rules to a temp dir, then use the
# same additive deploy logic extracted from scripts/setup-user-claude.sh/.ps1.
USER_RULES_DIR=""
USER_RULE_COUNT=0
declare -a USER_RULE_NAMES=()
declare -a USER_RULE_CONTENTS=()

CONFIG="$HOME/.aitools/config.json"
if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
    _urp=$(node -e "
try {
    const cfg = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    if (cfg.userRepoPath) console.log(cfg.userRepoPath);
} catch(e) {}
" "$CONFIG" 2>/dev/null) || true  # node failure is non-fatal; _urp stays empty
    if [ -n "$_urp" ] && [ -d "$_urp/claude/rules" ]; then
        USER_RULES_DIR="$_urp/claude/rules"
        for rf in "$USER_RULES_DIR"/*.md; do
            [ -f "$rf" ] || continue
            USER_RULE_NAMES+=("$(basename "$rf")")
            USER_RULE_CONTENTS+=("$(tr -d '\r' < "$rf")")
            USER_RULE_COUNT=$((USER_RULE_COUNT + 1))
        done
    fi
fi

if [ "$USER_RULE_COUNT" -gt 0 ]; then
    blog "User rules: $USER_RULE_COUNT files from $USER_RULES_DIR"
else
    blog "WARN: No user rules found at build time -- deploy scripts will not manage ~/.claude/rules/"
fi

# --- Build target: the user's own dotprofile repo, not the shared aitools repo ---
# build-deploy produces a PERSONALIZED, self-contained (MDM-ready) artifact into the
# user's dotprofile repo (aitools-<ghuser>/deploy/). The shared aitools/deploy/ is left
# untouched. Every user has a dotprofile; 'aitools user init' creates one if missing.
# If no dotprofile is configured yet, skip gracefully -- the bootstrap flow runs
# build-deploy only AFTER user init, so userRepoPath is set by the time we build.
if [ -n "${_urp:-}" ] && [ -d "$_urp" ]; then
    DEPLOY_DIR="$_urp/deploy"
    blog "Build target: $DEPLOY_DIR (dotprofile repo)"
else
    blog_warn "No dotprofile configured (userRepoPath unset). Run 'aitools user init' first -- skipping deploy build."
    exit 0
fi

# --- Profile interpolation ---
# Read profile from user repo, interpolate identity placeholders.
# Fallback: use defaults if profile not found (build never fails).
PROFILE_NAME="Jose"
PROFILE_COMPANY="Nobul"
IDENTITY_GIT_NAME="Jose"
IDENTITY_GIT_EMAIL="jose@nobul.tech"
CURSOR_CLI_VIMMODE=false
CURSOR_CLI_MODEL="auto"
# Claude settings are not embedded: setup-user-settings syncs ~/.claude/settings.json
# from profile.json (claude.settings) at runtime, in dev and deploy alike.

CONFIG="$HOME/.aitools/config.json"
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
    // Cursor CLI preferences
    let cursorCli = { vimMode: false, model: 'auto' };
    if (p.cursor && p.cursor.cli) {
        if (typeof p.cursor.cli.vimMode === 'boolean') cursorCli.vimMode = p.cursor.cli.vimMode;
        if (typeof p.cursor.cli.model === 'string') cursorCli.model = p.cursor.cli.model;
    }
    // Output as KEY=VALUE lines for bash eval
    console.log('PROFILE_NAME=' + JSON.stringify(prof.name));
    console.log('PROFILE_COMPANY=' + JSON.stringify(prof.company));
    console.log('IDENTITY_GIT_NAME=' + JSON.stringify(ident.git.name));
    console.log('IDENTITY_GIT_EMAIL=' + JSON.stringify(ident.git.email));
    console.log('CURSOR_CLI_VIMMODE=' + JSON.stringify(cursorCli.vimMode));
    console.log('CURSOR_CLI_MODEL=' + JSON.stringify(cursorCli.model));
} catch(e) { process.exit(1); }
" "$CONFIG" 2>/dev/null) && eval "$PROFILE_VALS"
fi

# Interpolate placeholders
CLAUDE_SHARED_CONTENT="${CLAUDE_SHARED_CONTENT//\{\{PROFILE_NAME\}\}/$PROFILE_NAME}"
CLAUDE_SHARED_CONTENT="${CLAUDE_SHARED_CONTENT//\{\{PROFILE_COMPANY\}\}/$PROFILE_COMPANY}"
CLAUDE_SHARED_CONTENT="${CLAUDE_SHARED_CONTENT//\{\{IDENTITY_GIT_NAME\}\}/$IDENTITY_GIT_NAME}"
CLAUDE_SHARED_CONTENT="${CLAUDE_SHARED_CONTENT//\{\{IDENTITY_GIT_EMAIL\}\}/$IDENTITY_GIT_EMAIL}"

blog "Profile interpolation: name=$PROFILE_NAME company=$PROFILE_COMPANY"
blog "Cursor CLI prefs: vimMode=$CURSOR_CLI_VIMMODE model=$CURSOR_CLI_MODEL"

# Clean and recreate deploy/
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

GENERATED=0

# Header for generated files
HEADER_COMMENT_BASH="# Generated by scripts/build-deploy.sh — do not edit directly."
HEADER_COMMENT_PS1="# Generated by scripts/build-deploy.sh — do not edit directly."

# ============================================================
# Sentinel-based extraction helper (Perl)
# ============================================================
# Extracts lines between two sentinel markers (exclusive of markers themselves).
# Uses Perl flip-flop operator for clean range extraction.
# Usage: extract_between FILE START_REGEX END_REGEX [--crlf]
#   --crlf: convert LF output to CRLF (for PS1 deploy scripts)
extract_between() {
    local file="$1" start="$2" end="$3" crlf="${4:-}"
    local result
    # Use m!...! as Perl regex delimiter to avoid conflicts with / in sentinels
    if [ "$crlf" = "--crlf" ]; then
        result=$(perl -ne '
            s/\r\n?$/\n/;
            if (m!'"$start"'! .. m!'"$end"'!) {
                next if m!'"$start"'! || m!'"$end"'!;
                s/\n$/\r\n/; print;
            }' "$file")
    else
        result=$(perl -ne '
            if (m!'"$start"'! .. m!'"$end"'!) {
                print unless m!'"$start"'! || m!'"$end"'!;
            }' "$file")
    fi
    if [ -z "$result" ]; then
        blog_error "Extraction failed: sentinels not found in $(basename "$file") (start: $start, end: $end)"
        exit 1
    fi
    printf '%s\n' "$result"
}

# extract_span FILE START_REGEX END_REGEX [--crlf]
#   Prints the lines from the one matching START_REGEX (included) up to the one
#   matching END_REGEX (excluded); END_REGEX "EOF" means to the end of the file.
#   Each regex must match exactly one line, START before END, or the build fails.
#   Unlike extract_between, a missing end marker never runs on to EOF silently.
#   Used where the source has section headings but no BEGIN/END markers.
extract_span() {
    local file="$1" start="$2" end="$3" crlf="${4:-}"
    local errf
    errf=$(mktemp)
    if ! perl -e '
        my ($file, $start, $end, $crlf) = @ARGV;
        open my $fh, "<", $file or die "cannot read $file: $!\n";
        my @l = <$fh>;
        close $fh;
        s/\r?\n\z/\n/ for @l;   # CRLF sources (.ps1): match and print as LF lines
        my @s = grep { $l[$_] =~ /$start/ } 0 .. $#l;
        die "start /$start/ matches " . scalar(@s) . " lines (need exactly 1)\n" unless @s == 1;
        my $e = scalar @l;
        if ($end ne "EOF") {
            my @e = grep { $l[$_] =~ /$end/ } 0 .. $#l;
            die "end /$end/ matches " . scalar(@e) . " lines (need exactly 1)\n" unless @e == 1;
            $e = $e[0];
            die "end /$end/ comes before start /$start/\n" unless $e > $s[0];
        }
        for my $i ($s[0] .. $e - 1) {
            my $x = $l[$i];
            $x =~ s/\n\z/\r\n/ if $crlf eq "--crlf";
            print $x;
        }
    ' -- "$file" "$start" "$end" "$crlf" 2> "$errf"; then
        blog_error "Extraction failed in $(basename "$file"): $(cat "$errf")"
        rm -f "$errf"
        exit 1
    fi
    rm -f "$errf"
}

# replace_once OLD NEW -- stdin -> stdout with the literal text OLD replaced by
#   NEW. OLD must occur exactly once, or the build fails (a reworded source line
#   must not slip through unchanged).
replace_once() {
    if ! perl -e '
        my ($old, $new) = @ARGV;
        my $text = do { local $/; <STDIN> };
        my $n = () = $text =~ /\Q$old\E/g;
        die "expected 1 occurrence of [$old], found $n\n" unless $n == 1;
        $text =~ s/\Q$old\E/$new/;
        print $text;
    ' -- "$1" "$2"; then
        blog_error "replace_once failed (source line reworded?): $1"
        exit 1
    fi
}

# ============================================================
# 1. deploy/setup-user-claude.sh
# ============================================================
blog "Generating deploy/setup-user-claude.sh"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-claude.sh — Creates user-level ~/.claude/CLAUDE.md and deploys user rules
# Self-contained: shared preferences and user rules are embedded below. No repo needed.
# Safe to re-run — replaces existing file with latest version.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md (additive deploy from embedded rules)
# Preserved: ~/.claude/rules/ files not in embedded source

set -euo pipefail

BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN preamble' '^# --- END preamble'
    cat <<'BLOCK'

# --- Auto-detect machine info ---
OS_NAME=$(uname -s)
ARCH=$(uname -m)
HOSTNAME=$(hostname -s 2>/dev/null || hostname)
SHELL_NAME=$(basename "${SHELL:-/bin/bash}")

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

mkdir -p "$CLAUDE_DIR"
log "Ensuring $CLAUDE_DIR exists"

# --- Embedded shared preferences (from shared/claude-shared.md) ---
BLOCK
    echo 'read -r -d "" SHARED_CONTENT <<'"'"'__EMBEDDED_CLAUDE_SHARED__'"'"' || true'
    echo "$CLAUDE_SHARED_CONTENT"
    echo '__EMBEDDED_CLAUDE_SHARED__'
    cat <<'BLOCK'

# --- Build content ---
NEW_CONTENT="${SHARED_CONTENT}

## Machine-Specific

- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})
- Shell: ${SHELL_NAME}"

if [ "$DRY_RUN" = "true" ]; then
    EXISTING_LINES=0
    [ -f "$CLAUDE_MD" ] && EXISTING_LINES=$(wc -l < "$CLAUDE_MD")
    NEW_LINES=$(echo "$NEW_CONTENT" | wc -l)
    log "[DRY RUN] $CLAUDE_MD: overwrite (sole owner)"
    log "  Template source: embedded (build-time)"
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
    backup_file "$CLAUDE_MD"
    # Capture existing content for post-write comparison
    OLD_CONTENT=""
    if [ -f "$CLAUDE_MD" ]; then
        OLD_CONTENT=$(cat "$CLAUDE_MD")
    fi
    if [ -f "$CLAUDE_MD" ]; then
        rm "$CLAUDE_MD"
        log "Removed existing $CLAUDE_MD"
    fi

    # --- Write CLAUDE.md ---
    cat > "$CLAUDE_MD" << CLAUDE_EOF
${SHARED_CONTENT}

## Machine-Specific

- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})
- Shell: ${SHELL_NAME}
CLAUDE_EOF

BLOCK
    # Extract: post-write validation from scripts/ (single source of truth)
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^\s*# --- BEGIN post-write validation' '^\s*# --- END post-write validation'
    cat <<'BLOCK'

    log_ok "Wrote $(display_path "$CLAUDE_MD")"
    if [ "$ERRORS" -eq 0 ]; then
        write_summary OK "claude.md" "deployed"
    else
        write_summary ERROR "claude.md" "validation failed"
    fi
    log "Machine: $OS_NAME $ARCH ($HOSTNAME), Shell: $SHELL_NAME"
    # Log whether content actually changed
    if [ -z "$OLD_CONTENT" ]; then
        log "Content: new file"
    elif [ "$OLD_CONTENT" = "$NEW_CONTENT" ]; then
        log "Content unchanged (no differences)"
    else
        log "Content updated"
        # Log unified diff to deploy log (not console)
        diff -u <(echo "$OLD_CONTENT") <(echo "$NEW_CONTENT") \
            --label "previous/CLAUDE.md" --label "new/CLAUDE.md" \
            >> "$LOG_FILE" 2>&1 || true  # diff exits 1 on differences (expected)
    fi
fi

BLOCK
    # --- Embedded user rules deployment ---
    if [ "$USER_RULE_COUNT" -gt 0 ]; then
        # Set up embedded rules: write to temp dir, then use extracted deploy logic
        cat <<'BLOCK'
# --- Embedded user rules (from user repo at build time) ---
RULES_SRC=$(mktemp -d)
_cleanup_rules() { rm -rf "$RULES_SRC"; }
trap _cleanup_rules EXIT
BLOCK
        # Emit heredocs for each embedded rule file
        for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
            local_name="${USER_RULE_NAMES[$i]}"
            # Sanitize name for heredoc delimiter: replace - and . with _
            safe_name=$(echo "$local_name" | perl -pe 's/[^a-zA-Z0-9]/_/g')
            echo "cat > \"\$RULES_SRC/$local_name\" <<'__RULE_${safe_name}__'"
            echo "${USER_RULE_CONTENTS[$i]}"
            echo "__RULE_${safe_name}__"
        done
        cat <<'BLOCK'
RULES_DEST="$CLAUDE_DIR/rules"
BLOCK
        # Extract deploy logic from scripts/ (single source of truth)
        extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
            '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic'
        cat <<'BLOCK'

# Clean up temp source dir
rm -rf "$RULES_SRC"
trap - EXIT
BLOCK
    else
        cat <<'BLOCK'
log "No user rules embedded at build time -- ~/.claude/rules/ not managed by this script"
BLOCK
    fi
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-claude.sh"

chmod +x "$DEPLOY_DIR/setup-user-claude.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 2. deploy/setup-user-claude.ps1
# ============================================================
blog "Generating deploy/setup-user-claude.ps1"

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-claude.ps1 — Creates user-level ~/.claude/CLAUDE.md and deploys user rules
# Self-contained: shared preferences and user rules are embedded below. No repo needed.
# Safe to re-run — replaces existing file with latest version.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md (additive deploy from embedded rules)
# Preserved: ~/.claude/rules/ files not in embedded source

BLOCK
    cat <<'BLOCK'
param(
    [switch]$DryRun,
    [switch]$Force
)

BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN preamble' '^# --- END preamble' --crlf
    cat <<'BLOCK'

# --- Auto-detect machine info ---
$osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
$hostname = $env:COMPUTERNAME

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Log "Created $claudeDir"
    }
}

# --- Embedded shared preferences (from shared/claude-shared.md) ---
$sharedContent = @'
BLOCK
    echo "$CLAUDE_SHARED_CONTENT"
    cat <<'BLOCK'
'@

# --- Build content ---
$content = @"
$sharedContent

## Machine-Specific

- Machine: $osInfo ($hostname)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

if ($DryRun) {
    $existingLines = 0
    if (Test-Path $claudeMd) {
        $existingLines = (Get-Content $claudeMd).Count
    }
    $newLines = ($content -split "`n").Count
    Log "[DRY RUN] $claudeMd`: overwrite (sole owner)"
    Log "  Template source: embedded (build-time)"
    Log "  Existing: $existingLines lines"
    Log "  New: $newLines lines"
    if (Test-Path $claudeMd) {
        $existingContent = Get-Content $claudeMd -Raw
        if ($existingContent -eq $content) {
            Log "[DRY RUN] Content unchanged"
        } else {
            Log "[DRY RUN] Content differs -- would overwrite"
        }
    } else {
        Log "[DRY RUN] File does not exist -- would create"
    }
} else {
    Backup-File -FilePath $claudeMd
    # Capture existing content for post-write comparison
    $oldContent = ""
    if (Test-Path $claudeMd) {
        try {
            $oldContent = Get-Content $claudeMd -Raw -ErrorAction Stop
        } catch {
            LogWarn "Cannot read existing CLAUDE.md for comparison: $_"
        }
    }
    if (Test-Path $claudeMd) {
        Remove-Item $claudeMd
        Log "Removed existing $claudeMd"
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($claudeMd)
    [System.IO.File]::WriteAllText($resolvedPath, $content, [System.Text.UTF8Encoding]::new($false))

BLOCK
    # Extract: post-write validation from scripts/ (single source of truth)
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^\s*# --- BEGIN post-write validation' '^\s*# --- END post-write validation' --crlf
    cat <<'BLOCK'

    LogOk "Wrote $claudeMd"
    if ($errors -eq 0) {
        Write-Summary "OK" "claude.md" "deployed"
    } else {
        Write-Summary "ERROR" "claude.md" "validation failed"
    }
    Log "Machine: $osInfo ($hostname)"
    # Log whether content actually changed
    if (-not $oldContent) {
        Log "Content: new file"
    } elseif ($oldContent -eq $content) {
        Log "Content unchanged (no differences)"
    } else {
        Log "Content updated"
        # Log diff to deploy log (not console)
        $oldLines = @($oldContent -split "`n")
        $newLines = @($content -split "`n")
        $diffResult = Compare-Object $oldLines $newLines -PassThru
        if ($diffResult) {
            Add-Content -Path $logFile -Value "  --- previous/CLAUDE.md"
            Add-Content -Path $logFile -Value "  +++ new/CLAUDE.md"
            foreach ($line in $diffResult) {
                $side = if ($line.SideIndicator -eq '<=') { '-' } else { '+' }
                Add-Content -Path $logFile -Value "  $side $line"
            }
        }
    }
}

BLOCK
    # --- Embedded user rules deployment (PS1) ---
    if [ "$USER_RULE_COUNT" -gt 0 ]; then
        # Set up embedded rules: write to temp dir, then use extracted deploy logic
        printf '# --- Embedded user rules (from user repo at build time) ---\r\n'
        printf '$rulesSrc = Join-Path $env:TEMP "aitools-rules-$(Get-Random)"\r\n'
        printf 'New-Item -ItemType Directory -Path $rulesSrc -Force | Out-Null\r\n'
        # Emit here-strings for each embedded rule file
        for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
            local_name="${USER_RULE_NAMES[$i]}"
            safe_name=$(echo "$local_name" | perl -pe 's/[^a-zA-Z0-9]/_/g')
            printf '$_rule_%s = @'"'"'\r\n' "$safe_name"
            echo "${USER_RULE_CONTENTS[$i]}" | perl -pe 's/\r?\n$/\r\n/'
            printf ''"'"'@\r\n'
            printf '$_ruleDest_%s = Join-Path $rulesSrc "%s"\r\n' "$safe_name" "$local_name"
            printf '[System.IO.File]::WriteAllText($_ruleDest_%s, $_rule_%s, [System.Text.UTF8Encoding]::new($false))\r\n' "$safe_name" "$safe_name"
        done
        printf '$rulesDest = Join-Path $claudeDir "rules"\r\n'
        printf '\r\n'
        # Extract deploy logic from scripts/ (single source of truth)
        extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
            '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic' --crlf
        printf '\r\n'
        printf '# Clean up temp source dir\r\n'
        printf 'Remove-Item $rulesSrc -Recurse -Force -ErrorAction SilentlyContinue\r\n'
    else
        printf 'Log "No user rules embedded at build time -- ~/.claude/rules/ not managed by this script"\r\n'
    fi
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-claude.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# 3. deploy/setup-user-cursor.sh
# ============================================================
blog "Generating deploy/setup-user-cursor.sh"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Self-contained. No repo or Drive needed.
# Safe to re-run — checks each step and skips what's already done.
# Run deploy-harness.sh first: step 4 fans out ~/.aitools/rules, which it fills.
#
BLOCK
    # Header scope (steps, managed/preserved) from the source header, so it
    # cannot drift from the body below
    extract_span "$SCRIPTS_DIR/setup-user-cursor.sh" \
        '^# Does [a-z]+ things:' '^# --- BEGIN cursor body'
    # Extract body from scripts/ source up to profile preferences sentinel
    extract_between "$SCRIPTS_DIR/setup-user-cursor.sh" \
        '^# --- BEGIN cursor body' '^// --- BEGIN profile preferences'
    # Emit build-time embedded preferences (replacing runtime profile reading)
    cat <<BLOCK_INTERP
// --- Embedded preferences (from profile.json at build time) ---
const vimMode = $CURSOR_CLI_VIMMODE;
const modelId = '$CURSOR_CLI_MODEL';
BLOCK_INTERP
    # Extract from end of profile preferences to end of cursor body
    extract_between "$SCRIPTS_DIR/setup-user-cursor.sh" \
        '^// --- END profile preferences' '^# --- END cursor body'
    # Exit footer
    extract_between "$SCRIPTS_DIR/setup-user-cursor.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-cursor.sh"

chmod +x "$DEPLOY_DIR/setup-user-cursor.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 4. deploy/setup-user-cursor.ps1
# ============================================================
blog "Generating deploy/setup-user-cursor.ps1"

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-cursor.ps1 — Sets up Cursor CLI + dependencies on Windows
# Self-contained. No repo or Drive needed.
# Safe to re-run — checks each step and skips what's already done.
# Run deploy-harness.ps1 first: step 4 fans out .aitools\rules, which it fills.
#
BLOCK
    # Header scope (steps, managed/preserved) from the source header, so it
    # cannot drift from the body below
    extract_span "$SCRIPTS_DIR/setup-user-cursor.ps1" \
        '^# Does [a-z]+ things:' '^# --- BEGIN cursor body' --crlf
    # Extract body from scripts/ source up to profile preferences sentinel (CRLF for PS1)
    extract_between "$SCRIPTS_DIR/setup-user-cursor.ps1" \
        '^# --- BEGIN cursor body' '^# --- BEGIN profile preferences' --crlf
    # Emit build-time embedded preferences (replacing runtime profile reading)
    printf '# --- Embedded preferences (from profile.json at build time) ---\r\n'
    printf '$vimMode = $%s\r\n' "$CURSOR_CLI_VIMMODE"
    printf '$modelId = "%s"\r\n' "$CURSOR_CLI_MODEL"
    # Extract from end of profile preferences to end of cursor body (CRLF for PS1)
    extract_between "$SCRIPTS_DIR/setup-user-cursor.ps1" \
        '^# --- END profile preferences' '^# --- END cursor body' --crlf
    # Exit footer
    extract_between "$SCRIPTS_DIR/setup-user-cursor.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-cursor.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# 5-6. deploy/setup-cursor-ide-mcp.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-cursor-ide-mcp.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Strip the shebang from source and inline lib
    tail -n +2 "$SCRIPTS_DIR/setup-cursor-ide-mcp.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-cursor-ide-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-cursor-ide-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-cursor-ide-mcp.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-cursor-ide-mcp.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-cursor-ide-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 7-8. deploy/setup-vercelcli.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-vercelcli.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-vercelcli.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-vercelcli.sh"
chmod +x "$DEPLOY_DIR/setup-vercelcli.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-vercelcli.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-vercelcli.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-vercelcli.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 9-10. deploy/setup-pandoc.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-pandoc.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-pandoc.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-pandoc.sh"
chmod +x "$DEPLOY_DIR/setup-pandoc.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-pandoc.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-pandoc.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-pandoc.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 11-12. deploy/setup-rust.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-rust.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-rust.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-rust.sh"
chmod +x "$DEPLOY_DIR/setup-rust.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-rust.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-rust.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-rust.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 13-14. deploy/setup-typst.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-typst.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-typst.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-typst.sh"
chmod +x "$DEPLOY_DIR/setup-typst.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-typst.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-typst.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-typst.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 15-16. deploy/setup-gh-cli.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-gh-cli.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-gh-cli.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-gh-cli.sh"
chmod +x "$DEPLOY_DIR/setup-gh-cli.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-gh-cli.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-gh-cli.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-gh-cli.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 17-18. deploy/setup-python.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-python.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-python.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-python.sh"
chmod +x "$DEPLOY_DIR/setup-python.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-python.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-python.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-python.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 19-20. deploy/setup-uv.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-uv.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-uv.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-uv.sh"
chmod +x "$DEPLOY_DIR/setup-uv.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-uv.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-uv.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-uv.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 21-22. deploy/setup-modal.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-modal.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-modal.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-modal.sh"
chmod +x "$DEPLOY_DIR/setup-modal.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-modal.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-modal.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-modal.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 23-24. deploy/setup-go.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-go.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-go.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-go.sh"
chmod +x "$DEPLOY_DIR/setup-go.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-go.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-go.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-go.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 25-26. deploy/setup-datadog.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-datadog.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-datadog.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-datadog.sh"
chmod +x "$DEPLOY_DIR/setup-datadog.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-datadog.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-datadog.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-datadog.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 27-28. deploy/setup-perl.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-perl.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-perl.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-perl.sh"
chmod +x "$DEPLOY_DIR/setup-perl.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-perl.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-perl.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-perl.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 29-30. deploy/setup-bash.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-bash.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-bash.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-bash.sh"
chmod +x "$DEPLOY_DIR/setup-bash.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-bash.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-bash.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-bash.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-google-chrome.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-google-chrome.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-google-chrome.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-google-chrome.sh"
chmod +x "$DEPLOY_DIR/setup-google-chrome.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-google-chrome.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-google-chrome.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-google-chrome.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-user-shell.sh and .ps1 (copy as-is) -- login-profile PATH block
# ============================================================
blog "Copying deploy/setup-user-shell.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-user-shell.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-user-shell.sh"
chmod +x "$DEPLOY_DIR/setup-user-shell.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-user-shell.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-user-shell.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-user-shell.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 31-32. deploy/setup-user-mcp.sh and .ps1 (MCP only, skills moved to setup-user-skills)
# ============================================================

blog "Generating deploy/setup-user-mcp.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    extract_between "$SCRIPTS_DIR/setup-user-mcp.sh" \
        '^# --- BEGIN mcp body' '^# --- END mcp body'
    extract_between "$SCRIPTS_DIR/setup-user-mcp.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-user-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-mcp.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    extract_between "$SCRIPTS_DIR/setup-user-mcp.ps1" \
        '^# --- BEGIN mcp body' '^# --- END mcp body' --crlf
    extract_between "$SCRIPTS_DIR/setup-user-mcp.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-user-settings.sh and .ps1 (settings.json <-> profile.json sync)
# ============================================================
# Self-contained via inline_lib_* (sync_managed_json + prompt_json_field_review).
# Resolves profile.json at runtime via config.json userRepoPath -- no build-time
# value embedding needed (works identically in dev and MDM).
blog "Generating deploy/setup-user-settings.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    extract_between "$SCRIPTS_DIR/setup-user-settings.sh" \
        '^# --- BEGIN settings body' '^# --- END settings body'
    extract_between "$SCRIPTS_DIR/setup-user-settings.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-settings.sh"
chmod +x "$DEPLOY_DIR/setup-user-settings.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-settings.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    extract_between "$SCRIPTS_DIR/setup-user-settings.ps1" \
        '^# --- BEGIN settings body' '^# --- END settings body' --crlf
    extract_between "$SCRIPTS_DIR/setup-user-settings.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-settings.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 31-32. deploy/setup-user-skills.sh and .ps1 (with dynamically embedded skills)
# ============================================================
# The scripts/ versions discover skills from shared/skills/ at runtime.
# The deploy/ versions embed all SKILL.md content at build time for self-contained deployment.

blog "Generating deploy/setup-user-skills.sh (with embedded skills)"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Extract boilerplate (flag parsing, lib, OS guard, DRY_RUN)
    extract_between "$SCRIPTS_DIR/setup-user-skills.sh" \
        '^# --- BEGIN skills body' '^# --- BEGIN skill discovery'

    # Emit self-contained skills deployment using heredocs
    cat <<'SKILLS_HEADER'

# --- Deploy skills (embedded at build time) ---

SKILLS_DEST="$HOME/.claude/skills"
SKILLS_DEST_CURSOR="$HOME/.cursor/skills"
ALL_SKILL_DESTS="$SKILLS_DEST $SKILLS_DEST_CURSOR"

SKILLS_HEADER
    # Emit helper function for diff-reviewed embedded skill deployment.
    # Takes a content FILE path (not a string) to avoid bash 3.2
    # parsing issues with $(cat <<'EOF') command substitution.
    cat <<'DEPLOY_SKILL_FUNC'
deploy_embedded_skill() {
    local skill_name="$1"
    local dest_base="$2"
    local tool_name="$3"
    local content_file="$4"

    local dest_dir="$dest_base/$skill_name"
    local dest="$dest_dir/SKILL.md"

    # No adopt target: the file read here is the build-time embed, not a repo
    # file (contract default #9), so adopt and merge are not offered.
    deploy_managed_file "$(cat "$content_file")" "$dest" "$tool_name" "$skill_name" ""

    case "$MANAGED_FILE_RESULT" in
        created|updated|verified|skipped|failed|"accept & adopt")
            # The tracker records the outcome (failed -> ERROR row).
            ;;
    esac
    deploy_tracker_record "$MANAGED_FILE_RESULT" "$tool_name" "$skill_name"
}

DEPLOY_SKILL_FUNC

    # Dynamically discover and embed all skills from shared/skills/
    _embedded_skills=""
    echo '_skill_tmp=$(mktemp -d)'
    for _skill_dir in "$SHARED_DIR/skills"/*/; do
        [ -d "$_skill_dir" ] || continue
        _sname=$(basename "$_skill_dir")
        _sfile="$_skill_dir/SKILL.md"
        [ -f "$_sfile" ] || continue
        _heredoc_marker="__SKILL_$(echo "$_sname" | tr '[:lower:]-' '[:upper:]_')__"
        echo "cat > \"\$_skill_tmp/${_sname}.md\" <<'${_heredoc_marker}'"
        cat "$_sfile"
        echo "${_heredoc_marker}"
        echo ''
        _embedded_skills="$_embedded_skills $_sname"
    done
    _embedded_skills="${_embedded_skills# }"

    # Deploy to ~/.claude/skills/ (Claude Code)
    echo 'log "Deploying skills to $SKILLS_DEST..."'
    echo 'ERRORS_BEFORE_CLAUDE_SKILLS=$ERRORS'
    echo 'deploy_tracker_init'
    for _sname in $_embedded_skills; do
        echo "deploy_embedded_skill \"$_sname\" \"\$SKILLS_DEST\" \"claude skills\" \"\$_skill_tmp/${_sname}.md\""
    done
    echo 'if [ "$ERRORS" -eq "$ERRORS_BEFORE_CLAUDE_SKILLS" ]; then'
    echo '    deploy_tracker_summary "claude skills"'
    echo 'else'
    echo '    write_summary ERROR "claude skills" "deploy failed"'
    echo 'fi'
    echo ''

    # Deploy to ~/.cursor/skills/ (Cursor Agent CLI)
    echo 'log "Deploying skills to $SKILLS_DEST_CURSOR..."'
    echo 'ERRORS_BEFORE_CURSOR_SKILLS=$ERRORS'
    echo 'deploy_tracker_init'
    for _sname in $_embedded_skills; do
        echo "deploy_embedded_skill \"$_sname\" \"\$SKILLS_DEST_CURSOR\" \"cursor skills\" \"\$_skill_tmp/${_sname}.md\""
    done
    echo 'if [ "$ERRORS" -eq "$ERRORS_BEFORE_CURSOR_SKILLS" ]; then'
    echo '    deploy_tracker_summary "cursor skills"'
    echo 'else'
    echo '    write_summary ERROR "cursor skills" "deploy failed"'
    echo 'fi'
    echo ''
    echo 'rm -rf "$_skill_tmp"'
    echo ''

    # Emit exit footer from source
    extract_between "$SCRIPTS_DIR/setup-user-skills.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-skills.sh"
chmod +x "$DEPLOY_DIR/setup-user-skills.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-skills.ps1 (with embedded skills)"
{
    echo "$HEADER_COMMENT_PS1"
    # Extract boilerplate (param, lib, OS guard, DRY_RUN)
    extract_between "$SCRIPTS_DIR/setup-user-skills.ps1" \
        '^# --- BEGIN skills body' '^# --- BEGIN skill discovery' --crlf

    # Emit self-contained skills deployment using PS1 here-strings
    cat <<'SKILLS_PS1_HEADER'

# --- Deploy skills (embedded at build time) ---

$skillsDest = Join-Path (Join-Path $env:USERPROFILE ".claude") "skills"
$skillsDestCursor = Join-Path (Join-Path $env:USERPROFILE ".cursor") "skills"
$allSkillDests = @($skillsDest, $skillsDestCursor)

SKILLS_PS1_HEADER
    # Emit helper function for diff-reviewed embedded skill deployment
    cat <<'DEPLOY_SKILL_PS1_FUNC'
function Deploy-EmbeddedSkill {
    param([string]$SkillName, [string]$DestBase, [string]$ToolName, [string]$Content)

    $destDir = Join-Path $DestBase $SkillName
    $dest = Join-Path $destDir "SKILL.md"

    # No adopt target: the content here is the build-time embed, not a repo
    # file (contract default #9), so adopt and merge are not offered.
    $skillResult = Deploy-ManagedFile -Content $Content -DestPath $dest -ToolName $ToolName -ItemName $SkillName -AdoptPath ""

    if ($skillResult -in @("created", "updated", "verified", "skipped", "failed", "accept & adopt")) {
        # The tracker records the outcome (failed -> ERROR row).
    }
    Record-DeployOutcome -Outcome $skillResult -ToolName $ToolName -ItemName $SkillName
}

DEPLOY_SKILL_PS1_FUNC

    # Dynamically discover and embed all skills from shared/skills/
    _embedded_skills=""
    for _skill_dir in "$SHARED_DIR/skills"/*/; do
        [ -d "$_skill_dir" ] || continue
        _sname=$(basename "$_skill_dir")
        _sfile="$_skill_dir/SKILL.md"
        [ -f "$_sfile" ] || continue
        # PS1 variable name: convert dashes to underscores
        _varname=$(echo "$_sname" | tr '-' '_')
        echo "\$skill_${_varname} = @'"
        cat "$_sfile"
        echo "'@"
        echo ''
        _embedded_skills="$_embedded_skills ${_sname}|${_varname}"
    done
    _embedded_skills="${_embedded_skills# }"

    # Deploy to ~/.claude/skills/ (Claude Code)
    echo 'Log "Deploying skills to $skillsDest..."'
    echo '$errorsBeforeClaudeSkills = $errors'
    echo 'Initialize-DeployTracker'
    for _pair in $_embedded_skills; do
        _sname="${_pair%%|*}"
        _varname="${_pair##*|}"
        echo "Deploy-EmbeddedSkill \"$_sname\" \$skillsDest \"claude skills\" \$skill_${_varname}"
    done
    echo 'if ($errors -eq $errorsBeforeClaudeSkills) {'
    echo '    Write-DeployTrackerSummary -ToolName "claude skills"'
    echo '} else {'
    echo '    Write-Summary "ERROR" "claude skills" "deploy failed"'
    echo '}'
    echo ''

    # Deploy to ~/.cursor/skills/ (Cursor Agent CLI)
    echo 'Log "Deploying skills to $skillsDestCursor..."'
    echo '$errorsBeforeCursorSkills = $errors'
    echo 'Initialize-DeployTracker'
    for _pair in $_embedded_skills; do
        _sname="${_pair%%|*}"
        _varname="${_pair##*|}"
        echo "Deploy-EmbeddedSkill \"$_sname\" \$skillsDestCursor \"cursor skills\" \$skill_${_varname}"
    done
    echo 'if ($errors -eq $errorsBeforeCursorSkills) {'
    echo '    Write-DeployTrackerSummary -ToolName "cursor skills"'
    echo '} else {'
    echo '    Write-Summary "ERROR" "cursor skills" "deploy failed"'
    echo '}'
    echo ''

    # Emit exit footer from source (CRLF for PS1)
    extract_between "$SCRIPTS_DIR/setup-user-skills.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-skills.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 15. deploy/setup-user-hooks.sh (extracted from scripts/ + embedded hooks)
# ============================================================
blog "Generating deploy/setup-user-hooks.sh (extracted + embedded hooks)"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-hooks.sh -- Deploys Claude Code hooks to ~/.claude/settings.json
# Self-contained: hook scripts are embedded below. No repo needed.
# Safe to re-run -- merges the `hooks` key without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop
# Preserved: permissions, enabledPlugins, all other fields (prefs synced by setup-user-settings)
#
# Hooks deployed: every hook registered in shared/hooks/hooks-manifest.json
# at build time (embedded below), plus its deploy-only helper scripts.

BLOCK
    # Extract: set -euo pipefail, flag parsing, logging, OS guard, DRY_RUN, require node
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- BEGIN hooks body' '^# --- BEGIN hook deployment'

    # REPLACE: hook deployment (deploy embeds scripts via heredoc instead of cp from repo)
    cat <<'BLOCK'
# --- Deploy embedded hook scripts to ~/.claude/hooks/ (generated from manifest) ---
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hooks to $HOOKS_DIR"
else
BLOCK
    # Embed each hook + helper from the manifest (single source of truth).
    # Heredoc per file with a unique delimiter derived from the filename.
    _MANIFEST="$SHARED_DIR/hooks/hooks-manifest.json"
    while IFS= read -r _hookfile; do
        [ -n "$_hookfile" ] || continue
        if [ -f "$SHARED_DIR/hooks/$_hookfile" ]; then
            _src="$SHARED_DIR/hooks/$_hookfile"
        elif [ -f "$SCRIPTS_DIR/$_hookfile" ]; then
            _src="$SCRIPTS_DIR/$_hookfile"
        else
            # Unreachable after the manifest preflight; fail loudly (never skip)
            # so a future edit to one side cannot reintroduce a silent drop.
            # exit leaves the { } | inline_lib_bash subshell; pipefail + set -e
            # then abort the build.
            blog_error "Hook source not found for embed: $_hookfile"
            exit 1
        fi
        _delim="__EMB_$(echo "$_hookfile" | tr 'a-z.-' 'A-Z__')__"
        echo "cat > \"\$HOOKS_DIR/$_hookfile\" <<'${_delim}'"
        cat "$_src"
        # Guarantee the delimiter lands on its own line even when the source hook
        # lacks a trailing newline (POSIX-incomplete file) -- otherwise the heredoc
        # never closes and the generated script is unparseable.
        [ -n "$(tail -c1 "$_src")" ] && echo ""
        echo "$_delim"
    done < <(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log([...m.hooks.map(h=>h.file),...((m.deploy)||[])].join("\n"))' "$_MANIFEST")
    cat <<'BLOCK'

    for _hf in "$HOOKS_DIR"/*.sh; do
        [ -f "$_hf" ] || continue
        chmod +x "$_hf"
        log_ok "Deployed hook: $_hf"
    done
fi
BLOCK
    # Embed REGS_JSON (registration list) at build time from the manifest, so the
    # self-contained deploy script needs no manifest at runtime. The node merge
    # block reads it from argv -- identical to the dev path.
    _REGS=$(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log(JSON.stringify(m.hooks.map(h=>({event:h.event,file:h.file,matcher:h.matcher||""}))))' "$SHARED_DIR/hooks/hooks-manifest.json")
    echo ""
    echo "# Registration list embedded from hooks-manifest.json at build time."
    echo "REGS_JSON='$_REGS'"
    echo ""

    # Extract: merge section (settings.json hooks merge, mergeHookEntry, clobber,
    # validation) + case statement. Prefs are no longer handled here -- they are
    # profile-sourced and synced by setup-user-settings.
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- END hook deployment' '^# --- END hooks body'

    # Extract: exit footer
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-hooks.sh"

chmod +x "$DEPLOY_DIR/setup-user-hooks.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 16. deploy/setup-user-hooks.ps1 (extracted from scripts/ + embedded hooks)
# ============================================================
blog "Generating deploy/setup-user-hooks.ps1 (extracted + embedded hooks)"

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-hooks.ps1 -- Deploys Claude Code hooks to ~/.claude/settings.json
# Self-contained: hook scripts are embedded below. No repo needed.
# Safe to re-run -- merges the `hooks` key without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop
# Preserved: permissions, enabledPlugins, all other fields (prefs synced by setup-user-settings)
#
# Hooks deployed: every hook registered in shared/hooks/hooks-manifest.json
# at build time (embedded below), plus its deploy-only helper scripts.
#
# Note: Hook scripts are bash-only (Claude Code hooks always run in bash on
# both platforms). This PS1 script only deploys the hook configuration.

BLOCK
    # Extract: param(), logging, OS guard, ConvertPSObjectToHashtable, DRY_RUN
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- BEGIN hooks body' '^# --- BEGIN hook deployment' --crlf

    # REPLACE: hook deployment (deploy embeds scripts via here-string + manifest-driven $regs)
    printf '# --- Deploy embedded hook scripts to ~/.claude/hooks/ (generated from manifest) ---\r\n'
    printf '$claudeDir = Join-Path $env:USERPROFILE ".claude"\r\n'
    printf '$hooksDir = Join-Path $claudeDir "hooks"\r\n'
    printf 'if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }\r\n'
    printf '\r\n'
    printf '$hookFiles = @{}\r\n'
    # Embed each hook + helper from the manifest (single source of truth).
    _PS_MANIFEST="$SHARED_DIR/hooks/hooks-manifest.json"
    while IFS= read -r _hookfile; do
        [ -n "$_hookfile" ] || continue
        if [ -f "$SHARED_DIR/hooks/$_hookfile" ]; then
            _src="$SHARED_DIR/hooks/$_hookfile"
        elif [ -f "$SCRIPTS_DIR/$_hookfile" ]; then
            _src="$SCRIPTS_DIR/$_hookfile"
        else
            # Unreachable after the manifest preflight; fail loudly (never skip)
            # so a future edit to one side cannot reintroduce a silent drop.
            # exit leaves the { } pipeline subshell; pipefail + set -e then abort
            # the build.
            blog_error "Hook source not found for PS1 embed: $_hookfile"
            exit 1
        fi
        printf '$hookFiles["%s"] = @'"'"'\r\n' "$_hookfile"
        perl -pe 's/\r?\n$/\r\n/' "$_src"
        # Guarantee the here-string terminator ('@) lands on its own line even when
        # the source hook lacks a trailing newline.
        [ -n "$(tail -c1 "$_src")" ] && printf '\r\n'
        printf ''"'"'@\r\n'
        printf '\r\n'
    done < <(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log([...m.hooks.map(h=>h.file),...((m.deploy)||[])].join("\n"))' "$_PS_MANIFEST")
    printf 'if ($DryRun) {\r\n'
    printf '    Log "[DRY RUN] Would deploy hooks to ~/.claude/hooks/"\r\n'
    printf '} else {\r\n'
    printf '    foreach ($hName in $hookFiles.Keys) {\r\n'
    printf '        $hDest = Join-Path $hooksDir $hName\r\n'
    printf '        $hResolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($hDest)\r\n'
    printf '        [System.IO.File]::WriteAllText($hResolved, $hookFiles[$hName], [System.Text.UTF8Encoding]::new($false))\r\n'
    printf '        LogOk "Deployed hook: $hDest"\r\n'
    printf '    }\r\n'
    printf '}\r\n'
    printf '\r\n'
    # Embed $regs (registration list) at build time from the manifest, so the
    # self-contained deploy script needs no manifest at runtime.
    printf '# Registration list embedded from hooks-manifest.json at build time.\r\n'
    printf '$regs = @(\r\n'
    while IFS= read -r _line; do
        [ -n "$_line" ] || continue
        printf '%s\r\n' "$_line"
    done < <(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));for(const h of m.hooks){console.log("    [pscustomobject]@{ event = \""+h.event+"\"; file = \""+h.file+"\"; matcher = \""+(h.matcher||"")+"\" }")}' "$SHARED_DIR/hooks/hooks-manifest.json")
    printf ')\r\n'

    printf '\r\n'

    # Extract: merge section (settings.json hooks merge, MergeHookEntry, clobber,
    # validation). Prefs are no longer handled here -- they are profile-sourced
    # and synced by setup-user-settings.
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- END hook deployment' '^# --- END hooks body' --crlf

    # Extract: exit footer
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-hooks.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-user-config.* + aitools-profile.* + aitools-json.* (copy as-is)
# ============================================================
# The config.json writer deploy-harness calls (its section 1 runs
# "$SCRIPT_DIR/setup-user-config.sh" / ".ps1"), plus the two helpers the writer
# loads from its own directory. Copies with the library inlined: no logic here.
for _cw in setup-user-config aitools-profile; do
    blog "Copying deploy/$_cw.sh"
    {
        echo '#!/usr/bin/env bash'
        echo "$HEADER_COMMENT_BASH"
        tail -n +2 "$SCRIPTS_DIR/$_cw.sh" | inline_lib_bash
    } > "$DEPLOY_DIR/$_cw.sh"
    chmod +x "$DEPLOY_DIR/$_cw.sh"
    GENERATED=$((GENERATED + 1))

    blog "Copying deploy/$_cw.ps1"
    {
        echo "$HEADER_COMMENT_PS1"
        cat "$SCRIPTS_DIR/$_cw.ps1" | inline_lib_ps1
    } > "$DEPLOY_DIR/$_cw.ps1"
    GENERATED=$((GENERATED + 1))
done

blog "Copying deploy/aitools-json.pl"
{
    echo '#!/usr/bin/env perl'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/aitools-json.pl"
} > "$DEPLOY_DIR/aitools-json.pl"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/aitools-json.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/aitools-json.ps1"
} > "$DEPLOY_DIR/aitools-json.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/deploy-harness.sh and .ps1 (~/.aitools from a build-time snapshot)
# ============================================================
# scripts/deploy-harness.* list each source directory with git ls-files and read
# the files from the repos. An MDM endpoint has neither, so the snapshot is taken
# here: for every source directory the dev script names (parsed from its
# add_source calls -- not a second list), the `git ls-files -z` output and every
# listed file (contents + executable bit), plus the bin CLIs (parsed from its
# `for cli in` line). The generated script embeds them (base64), unpacks them to
# a temp directory laid out like the repos, and answers the plan's two git calls
# (rev-parse --is-inside-work-tree, ls-files -z) from the snapshot. Everything
# else is the dev script's own code, extracted between its section headings:
# preamble + flags + section 1 (config.json), then sections 3-7 (directories,
# plan and conflicts, deploy, preserved, summary + exit). By design:
#   - section 2 (dotprofile lookup) is replaced: dotprofile rules are the
#     build-time dotprofile's, as with setup-user-claude's embedded rules;
#   - the adopt target is "" (the source is the embed, not a repo file), as for
#     the embedded skills (contract default #9).
HARNESS_SH="$SCRIPTS_DIR/deploy-harness.sh"
HARNESS_PS1="$SCRIPTS_DIR/deploy-harness.ps1"
for _hf in "$HARNESS_SH" "$HARNESS_PS1"; do
    if [ ! -f "$_hf" ]; then
        blog_error "Required script not found: $_hf"
        exit 1
    fi
done

if ! MDM_TMP=$(mktemp -d); then
    blog_error "Could not create a temp directory for the harness snapshot"
    exit 1
fi
trap 'rm -rf "$MDM_TMP"' EXIT
MDM_MANIFEST="$MDM_TMP/manifest.tsv"   # stage path <TAB> source file <TAB> exec (0|1)
: > "$MDM_MANIFEST"

# Source directories: "<aitools|dotprofile><TAB><relative dir>" per add_source call
MDM_SOURCES=$(perl -ne '
    if (/^\s*add_source\s+\S+\s+"[^"]*"\s+"\$(REPO_DIR|DOTPROFILE)\/([^"]+)"/) {
        print(($1 eq "REPO_DIR" ? "aitools" : "dotprofile"), "\t$2\n");
    }' "$HARNESS_SH")
_mdm_calls=$(perl -ne '$n++ if /^\s*add_source\s/; END { print $n + 0 }' "$HARNESS_SH")
_mdm_parsed=$(printf '%s\n' "$MDM_SOURCES" | perl -ne '$n++ if /\S/; END { print $n + 0 }')
_mdm_ps1_calls=$(perl -ne '$n++ if /^\s*Add-Source\s+-Kind\s/; END { print $n + 0 }' "$HARNESS_PS1")
if [ "$_mdm_calls" -eq 0 ] || [ "$_mdm_calls" -ne "$_mdm_parsed" ]; then
    blog_error "deploy-harness.sh: parsed $_mdm_parsed of $_mdm_calls add_source calls -- update the parser in build-deploy.sh"
    exit 1
fi
if [ "$_mdm_ps1_calls" -ne "$_mdm_calls" ]; then
    blog_error "deploy-harness parity: $_mdm_calls add_source calls in .sh, $_mdm_ps1_calls Add-Source calls in .ps1"
    exit 1
fi
# bin CLIs: the dev script's `for cli in ...; do` list (and the .ps1 list must match)
if ! MDM_BIN=$(perl -ne 'if (/^for cli in ([^;]+); do/) { print join("\n", split(" ", $1)), "\n"; $n++ } END { exit($n == 1 ? 0 : 1) }' "$HARNESS_SH"); then
    blog_error "deploy-harness.sh: no single 'for cli in ...; do' bin list -- update the parser in build-deploy.sh"
    exit 1
fi
if ! MDM_BIN_PS1=$(perl -ne 'if (/^foreach \(\$cli in \@\(([^)]*)\)\)/) { my @a = $1 =~ /"([^"]+)"/g; print join("\n", @a), "\n"; $n++ } END { exit($n == 1 ? 0 : 1) }' "$HARNESS_PS1"); then
    blog_error "deploy-harness.ps1: no single 'foreach (\$cli in @(...))' bin list -- update the parser in build-deploy.sh"
    exit 1
fi
if [ "$MDM_BIN" != "$MDM_BIN_PS1" ]; then
    blog_error "deploy-harness parity: bin lists differ between .sh and .ps1"
    exit 1
fi

# mdm_snapshot_dir STAGE_REL ABS_DIR -- list ABS_DIR as the dev script does and
# add the listing and every listed file to the manifest.
MDM_DIRS=0
mdm_snapshot_dir() {
    local stage_rel="$1" dir="$2" lsf
    if [ ! -d "$dir" ]; then
        blog "Harness snapshot: $stage_rel not found -- not embedded (deploy-harness logs the missing source)"
        return 0
    fi
    MDM_DIRS=$((MDM_DIRS + 1))
    lsf="$MDM_TMP/ls.$MDM_DIRS"
    # 2>/dev/null: rev-parse fails outside a git work tree; that failure selects the fallback.
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if ! git -C "$dir" ls-files -z > "$lsf"; then
            blog_error "Harness snapshot: git ls-files failed in $dir"
            exit 1
        fi
    else
        # e.g. pre-push step 7 builds into a git-archive copy of the dotprofile
        blog_warn "Harness snapshot: $dir is not in a git work tree -- embedding every file on disk, listed as git would"
        if ! perl -MFile::Find -e '
            my $root = shift;
            my @f;
            find({ no_chdir => 1, wanted => sub {
                if (-d $_ && m{/\.git\z}) { $File::Find::prune = 1; return; }
                push @f, substr($_, length($root) + 1) if -f $_;
            } }, $root);
            print map { "$_\0" } sort @f;
        ' "$dir" > "$lsf"; then
            blog_error "Harness snapshot: cannot list $dir"
            exit 1
        fi
    fi
    printf '%s\t%s\t0\n' "$stage_rel/.aitools-mdm-ls-files" "$lsf" >> "$MDM_MANIFEST"
    # Listed but missing on disk: not embedded; deploy-harness WARNs at run time, as in dev.
    if ! perl -e '
        my ($lsf, $dir, $stage) = @ARGV;
        open my $h, "<:raw", $lsf or die "cannot read $lsf: $!\n";
        local $/ = "\0";
        while (my $rel = <$h>) {
            chomp $rel;
            next if $rel eq "";
            die "path with a tab or line break cannot be embedded: $dir/$rel\n" if $rel =~ /[\t\r\n]/;
            my $src = "$dir/$rel";
            next unless -f $src;
            print "$stage/$rel\t$src\t", (-x $src ? 1 : 0), "\n";
        }
    ' "$lsf" "$dir" "$stage_rel" >> "$MDM_MANIFEST"; then
        blog_error "Harness snapshot: cannot add the files of $dir"
        exit 1
    fi
}

while IFS=$'\t' read -r _mdm_base _mdm_rel; do
    [ -n "$_mdm_base" ] || continue
    if [ "$_mdm_base" = "aitools" ]; then
        mdm_snapshot_dir "aitools/$_mdm_rel" "$REPO_ROOT/$_mdm_rel"
    else
        mdm_snapshot_dir "dotprofile/$_mdm_rel" "$_urp/$_mdm_rel"
    fi
done <<< "$MDM_SOURCES"
while IFS= read -r _mdm_cli; do
    [ -n "$_mdm_cli" ] || continue
    if [ ! -f "$SCRIPTS_DIR/$_mdm_cli" ]; then
        blog_warn "Harness snapshot: bin $_mdm_cli not found -- not embedded (deploy-harness WARNs at run time)"
        continue
    fi
    _mdm_x=0
    if [ -x "$SCRIPTS_DIR/$_mdm_cli" ]; then _mdm_x=1; fi
    printf 'aitools/scripts/%s\t%s\t%s\n' "$_mdm_cli" "$SCRIPTS_DIR/$_mdm_cli" "$_mdm_x" >> "$MDM_MANIFEST"
done <<< "$MDM_BIN"
MDM_FILES=$(perl -ne '$n++ unless /\/\.aitools-mdm-ls-files\t/; END { print $n + 0 }' "$MDM_MANIFEST")
blog "Harness snapshot: $MDM_FILES files from $MDM_DIRS source directories (+ bin)"

# mdm_emit_payload MANIFEST sh|ps1 -- one unpack call per manifest line, the file
# as base64, preceded by a comment with its stage path, size and sha256 (so a
# deploy/ diff shows which harness file changed).
mdm_emit_payload() {
    if ! perl -MMIME::Base64 -MDigest::SHA=sha256_hex -e '
        my ($manifest, $mode) = @ARGV;
        open my $m, "<", $manifest or die "cannot read $manifest: $!\n";
        while (my $line = <$m>) {
            chomp $line;
            my ($rel, $src, $exec) = split /\t/, $line, 3;
            open my $fh, "<:raw", $src or die "cannot read $src: $!\n";
            my $data = do { local $/; <$fh> };
            close $fh;
            $data = "" unless defined $data;
            printf "# %s (%d bytes, sha256 %s)\n", $rel, length($data), sha256_hex($data);
            my $b64 = encode_base64($data);
            if ($mode eq "sh") {
                (my $q = $rel) =~ s/\x27/\x27\\\x27\x27/g;
                print "mdm_unpack \x27$q\x27 $exec <<\x27__AITOOLS_MDM_B64__\x27 || MDM_UNPACK_FAILED=\$((MDM_UNPACK_FAILED + 1))\n";
                print $b64, "__AITOOLS_MDM_B64__\n";
            } else {
                (my $q = $rel) =~ s/\x27/\x27\x27/g;
                print "Expand-MdmPayload \x27$q\x27 \@\x27\n", $b64, "\x27\@\n";
            }
        }
    ' "$1" "$2"; then
        blog_error "Harness snapshot: could not write the embedded payload ($2)"
        exit 1
    fi
}

blog "Generating deploy/deploy-harness.sh (extracted + embedded harness snapshot)"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# deploy-harness.sh -- populate ~/.aitools, the deployed harness, from a
# build-time snapshot (macOS/Linux; MDM path of scripts/deploy-harness.sh)
#
# Self-contained: every harness source file is embedded below (base64, one block
# per file, each with its size and sha256). No repo, dotprofile checkout or git
# is needed at run time. Safe to re-run: a file equal to its source is verified
# and not written. Platform: macOS/Linux. On Windows use deploy-harness.ps1.
#
# Run it FIRST in an MDM sequence: setup-user-cursor (and the other rules
# fan-out consumers) read ~/.aitools/rules, which this script fills.
#
# Same directories, plan, name conflicts (first source wins, ERROR row per
# duplicate), outcomes, summary rows ("harness files") and exit codes as
# scripts/deploy-harness.sh, whose code is extracted below at build time. MDM
# differences:
#   - sources are the snapshot taken when deploy/ was built (per source
#     directory: its git ls-files list, the listed files, their executable bit);
#   - dotprofile rules are those of the dotprofile deploy/ was built from;
#   - accept & adopt / merge & adopt are not offered (the source is the embed);
#   - config.json is generated by setup-user-config.sh in this directory.
#
# Usage: deploy-harness.sh [--dry-run] [--force] [--help]
#   --dry-run   report what would change; write nothing (also AITOOLS_DRY_RUN=1)
#   --force     no review menu: source wins (also AITOOLS_FORCE=1)
# Exit: 0 done (warnings possible), 1 errors (incl. duplicates, config.json
#   not generated), 2 aborted by the user at a review menu.

BLOCK
    extract_span "$HARNESS_SH" '^set -euo pipefail$' '^# 2\. Dotprofile'
} | inline_lib_bash > "$DEPLOY_DIR/deploy-harness.sh"
{
    cat <<'BLOCK'
# 2. (MDM) Embedded sources -- replaces the dev path's dotprofile lookup
# =========================================================================
# Each source directory of scripts/deploy-harness.sh was snapshotted when this
# deploy/ was built: its `git ls-files -z` output (.aitools-mdm-ls-files) and
# every listed file, plus the bin CLIs. They are unpacked into a temp directory
# laid out like the repos ($MDM_STAGE/aitools, $MDM_STAGE/dotprofile). The git
# function below answers the plan's two git calls for those directories from
# the snapshot and passes every other call to the real git, so sections 3-7 are
# the dev script's code, unchanged except the adopt target ("").
if ! command -v perl >/dev/null 2>&1; then
    log_error "perl not found -- the embedded harness files cannot be unpacked"
    write_summary ERROR "$TOOL" "perl not found"
    exit 1
fi
MDM_STAGE="$WORK/src"
MDM_UNPACK_FAILED=0

# mdm_unpack REL EXEC -- decode base64 on stdin into $MDM_STAGE/REL (EXEC 1: executable)
mdm_unpack() {
    local dest="$MDM_STAGE/$1"
    if ! mkdir -p "${dest%/*}"; then
        log_error "MDM: cannot create the directory for embedded $1"
        return 1
    fi
    if ! perl -MMIME::Base64 -0777 -ne 'print decode_base64($_)' > "$dest"; then
        log_error "MDM: cannot unpack embedded $1"
        return 1
    fi
    if [ "$2" = "1" ]; then
        if ! chmod +x "$dest"; then
            log_error "MDM: cannot set the executable bit on embedded $1"
            return 1
        fi
    fi
    return 0
}

# git -C DIR rev-parse --is-inside-work-tree / git -C DIR ls-files -z for a
# snapshot directory: answered from its .aitools-mdm-ls-files. Anything else:
# the real git (the library uses it for protected-file checks).
git() {
    if [ "$#" -eq 4 ] && [ "$1" = "-C" ] && [ -f "$2/.aitools-mdm-ls-files" ]; then
        case "$2" in
            "$MDM_STAGE"/*)
                case "$3 $4" in
                    "rev-parse --is-inside-work-tree") printf 'true\n'; return 0 ;;
                    "ls-files -z") cat "$2/.aitools-mdm-ls-files"; return $? ;;
                esac ;;
        esac
    fi
    command git "$@"
}

# --- Embedded harness snapshot (generated from the repos at build time) ---
BLOCK
    printf 'MDM_EMBEDDED_FILES=%s\n' "$MDM_FILES"
    mdm_emit_payload "$MDM_MANIFEST" sh
    cat <<'BLOCK'
# --- End of embedded harness snapshot ---

if [ "$MDM_UNPACK_FAILED" -gt 0 ]; then
    write_summary ERROR "$TOOL" "$(short "$MDM_UNPACK_FAILED embedded file(s) not unpacked")"
fi
log "MDM: sources are the build-time snapshot ($MDM_EMBEDDED_FILES files), unpacked in $(display_path "$MDM_STAGE")"
REPO_DIR="$MDM_STAGE/aitools"
SCRIPT_DIR="$REPO_DIR/scripts"        # section 4 reads the bin CLIs from "$SCRIPT_DIR/<cli>"
DOTPROFILE="$MDM_STAGE/dotprofile"    # section 4 reads "$DOTPROFILE/claude/rules"
if ! mkdir -p "$DOTPROFILE"; then
    log_error "MDM: cannot create $(display_path "$DOTPROFILE")"
    write_summary ERROR "$TOOL" "no work directory"
fi

# =========================================================================
BLOCK
    extract_span "$HARNESS_SH" '^# 3\. The six directories' EOF \
        | replace_once 'deploy_managed_file "$content" "$dest" "$TOOL" "$item" "$src"' \
                       'deploy_managed_file "$content" "$dest" "$TOOL" "$item" ""  # MDM: no adopt target (the source is the embed)'
} >> "$DEPLOY_DIR/deploy-harness.sh"
chmod +x "$DEPLOY_DIR/deploy-harness.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/deploy-harness.ps1 (extracted + embedded harness snapshot)"
{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# deploy-harness.ps1 -- populate %USERPROFILE%\.aitools, the deployed harness, from
# a build-time snapshot (Windows; MDM path of scripts/deploy-harness.ps1)
#
# Self-contained: every harness source file is embedded below (base64, one block
# per file, each with its size and sha256). No repo, dotprofile checkout or git
# is needed at run time. Safe to re-run: a file equal to its source is verified
# and not written. Platform: Windows. On macOS/Linux use deploy-harness.sh.
#
# Run it FIRST in an MDM sequence: setup-user-cursor (and the other rules
# fan-out consumers) read .aitools\rules, which this script fills.
#
# Same directories, plan, name conflicts (first source wins, ERROR row per
# duplicate), outcomes, summary rows ("harness files") and exit codes as
# scripts/deploy-harness.ps1, whose code is extracted below at build time. MDM
# differences:
#   - sources are the snapshot taken when deploy/ was built (per source
#     directory: its git ls-files list and the listed files);
#   - dotprofile rules are those of the dotprofile deploy/ was built from;
#   - accept & adopt / merge & adopt are not offered (the source is the embed);
#   - config.json is generated by setup-user-config.ps1 in this directory.
#
# Usage: deploy-harness.ps1 [-DryRun] [-Force] [-Help]
#   -DryRun   report what would change; write nothing (also AITOOLS_DRY_RUN=1)
#   -Force    no review menu: source wins (also AITOOLS_FORCE=1)
# Exit: 0 done (warnings possible), 1 errors (incl. duplicates, config.json
#   not generated), 2 aborted by the user at a review menu.

BLOCK
    extract_span "$HARNESS_PS1" '^param\($' '^# 2\. Dotprofile'
} | inline_lib_ps1 > "$DEPLOY_DIR/deploy-harness.ps1"
{
    cat <<'BLOCK'
# 2. (MDM) Embedded sources -- replaces the dev path's dotprofile lookup
# =========================================================================
# Each source directory of scripts/deploy-harness.ps1 was snapshotted when this
# deploy/ was built: its `git ls-files -z` output (.aitools-mdm-ls-files) and
# every listed file, plus the bin CLIs. They are unpacked into a temp directory
# laid out like the repos ($mdmStage\aitools, $mdmStage\dotprofile). The git
# function below answers the plan's two git calls for those directories from
# the snapshot and passes every other call to the real git, so sections 3-7 are
# the dev script's code, unchanged except the adopt target (""). The temp
# directory is removed in the finally block at the end (it runs on exit too).
$mdmStage = Join-Path ([IO.Path]::GetTempPath()) ("aitools-harness-" + [guid]::NewGuid().ToString("N"))
try {
$mdmUnpackFailed = 0

# Expand-MdmPayload REL BASE64 -- decode into $mdmStage\REL
function Expand-MdmPayload {
    param([string]$Rel, [string]$B64)
    $dest = Join-Path $mdmStage ($Rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    try {
        $dir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
        [IO.File]::WriteAllBytes($dest, [Convert]::FromBase64String($B64))
    } catch {
        LogError "MDM: cannot unpack embedded ${Rel}: $_"
        $script:mdmUnpackFailed++
    }
}

# git -C DIR rev-parse --is-inside-work-tree / git -C DIR ls-files -z for a
# snapshot directory: answered from its .aitools-mdm-ls-files. Anything else:
# the real git (the library uses it for protected-file checks).
function git {
    if ($args.Count -eq 4 -and $args[0] -eq '-C') {
        $lsFile = Join-Path ([string]$args[1]) ".aitools-mdm-ls-files"
        $inStage = ([IO.Path]::GetFullPath([string]$args[1])).StartsWith(
            [IO.Path]::GetFullPath($mdmStage) + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)
        if ($inStage -and (Test-Path -LiteralPath $lsFile -PathType Leaf)) {
            if ($args[2] -eq 'rev-parse' -and $args[3] -eq '--is-inside-work-tree') {
                $global:LASTEXITCODE = 0
                return "true"
            }
            if ($args[2] -eq 'ls-files' -and $args[3] -eq '-z') {
                $global:LASTEXITCODE = 0
                return [IO.File]::ReadAllText($lsFile, [System.Text.UTF8Encoding]::new($false))
            }
        }
    }
    $realGit = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $realGit) {
        $global:LASTEXITCODE = 127
        Write-Error "git not found"
        return
    }
    & $realGit @args
}

# --- Embedded harness snapshot (generated from the repos at build time) ---
BLOCK
    printf '$mdmEmbeddedFiles = %s\n' "$MDM_FILES"
    mdm_emit_payload "$MDM_MANIFEST" ps1
    cat <<'BLOCK'
# --- End of embedded harness snapshot ---

if ($mdmUnpackFailed -gt 0) {
    Write-Summary "ERROR" $tool (Get-ShortDetail "$mdmUnpackFailed embedded file(s) not unpacked")
}
Log "MDM: sources are the build-time snapshot ($mdmEmbeddedFiles files), unpacked in $mdmStage"
$repoDir = Join-Path $mdmStage "aitools"
$scriptDir = Join-Path $repoDir "scripts"        # section 4 reads the bin CLIs from $scriptDir\<cli>
$dotprofile = Join-Path $mdmStage "dotprofile"   # section 4 reads $dotprofile\claude\rules
try {
    New-Item -ItemType Directory -Path $dotprofile -Force -ErrorAction Stop | Out-Null
} catch {
    LogError "MDM: cannot create ${dotprofile}: $_"
    Write-Summary "ERROR" $tool "no work directory"
}

# =========================================================================
BLOCK
    extract_span "$HARNESS_PS1" '^# 3\. The six directories' EOF \
        | replace_once '-ItemName $p.Item -AdoptPath $p.Src' \
                       '-ItemName $p.Item -AdoptPath ""  # MDM: no adopt target (the source is the embed)'
    cat <<'BLOCK'
} finally {
    # ErrorAction: checked on the next line
    Remove-Item -LiteralPath $mdmStage -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $mdmStage) { LogWarn "MDM: could not remove the temp directory $mdmStage" }
}
BLOCK
} >> "$DEPLOY_DIR/deploy-harness.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# Summary
# ============================================================
# ============================================================
# Post-build: Validate PS1 syntax (Windows only)
# ============================================================
# On Windows (Git Bash), validate all generated .ps1 files with ParseFile.
# Catches encoding issues and syntax errors at build time rather than install time.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        blog "Validating generated PS1 scripts..."
        PS1_ERRORS=0
        for ps1_file in "$DEPLOY_DIR"/*.ps1; do
            [ -f "$ps1_file" ] || continue
            ps1_name=$(basename "$ps1_file")
            if ! pwsh -NoProfile -Command "
                \$e = \$null
                \$null = [System.Management.Automation.Language.Parser]::ParseFile('$(cygpath -w "$ps1_file")', [ref]\$null, [ref]\$e)
                if (\$e.Count -gt 0) {
                    foreach (\$err in \$e) { Write-Host \"  line \$(\$err.Extent.StartLineNumber): \$(\$err.Message)\" }
                    exit 1
                }
            " 2>/dev/null; then
                blog_error "$ps1_name has parse errors on this PowerShell version"
                PS1_ERRORS=$((PS1_ERRORS + 1))
            fi
        done
        if [ "$PS1_ERRORS" -gt 0 ]; then
            blog_error "$PS1_ERRORS PS1 file(s) failed validation"
            exit 1
        else
            blog_ok "All PS1 files passed validation"
        fi
        ;;
    *)
        # macOS/Linux: Validate PS1 via pwsh (managed tool)
        if command -v pwsh &>/dev/null; then
            blog "Validating generated PS1 scripts via pwsh..."
            PS1_ERRORS=0
            for ps1_file in "$DEPLOY_DIR"/*.ps1; do
                [ -f "$ps1_file" ] || continue
                ps1_name=$(basename "$ps1_file")
                errors_output=$(pwsh -NoProfile -Command "
                    \$e = \$null
                    \$null = [System.Management.Automation.Language.Parser]::ParseFile('$ps1_file', [ref]\$null, [ref]\$e)
                    if (\$e.Count -gt 0) {
                        foreach (\$err in \$e) { Write-Host \"  line \$(\$err.Extent.StartLineNumber): \$(\$err.Message)\" }
                        exit 1
                    }
                " 2>&1) || {
                    blog_error "$ps1_name has parse errors:"
                    echo "$errors_output"
                    PS1_ERRORS=$((PS1_ERRORS + 1))
                }
            done
            if [ "$PS1_ERRORS" -gt 0 ]; then
                blog_error "$PS1_ERRORS PS1 file(s) failed validation"
                exit 1
            else
                blog_ok "All PS1 files passed validation (pwsh)"
            fi
        else
            blog_warn "pwsh not found -- PS1 validation skipped (install: brew install powershell/tap/powershell)"
        fi
        ;;
esac

# ============================================================
# Post-build: Fix file permissions and line endings
# ============================================================
# 1. Ensure all .sh files are executable on disk (Write tool creates 100644)
chmod +x "$DEPLOY_DIR"/*.sh 2>/dev/null || true
blog_ok "Set +x on all .sh files in deploy/"

# 2. Convert deploy/*.ps1 to CRLF (.gitattributes requires eol=crlf)
#    build-deploy.sh writes LF; without this, git sees them as modified.
#    PERLIO=:perlio (set at top) prevents Strawberry Perl text-mode double-CR.
perl -pi -e 's/(?<!\r)\n/\r\n/' "$DEPLOY_DIR"/*.ps1
blog_ok "Converted deploy/*.ps1 to CRLF"

blog_ok "Build complete: $GENERATED scripts generated in deploy/"
ls -la "$DEPLOY_DIR/"
blog "Scripts are self-contained and ready for MDM deployment"
