#!/usr/bin/env bash
# build-deploy.sh — Generates self-contained deploy/ scripts from scripts/ + shared/
#
# Reads shared content files and embeds them into deploy versions of setup scripts.
# The deploy/ scripts have zero dependencies on the repo or Google Drive — they can
# be deployed to any endpoint via MDM (Jamf, Intune) or run manually.
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

# --- Build logging (standalone -- does not source aitools-lib.sh) ---
SCRIPT_NAME="build-deploy"
blog()       { printf '[%s] [%s] [info] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_ok()    { printf '[%s] [%s] [ok] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_error() { printf '\033[31m[%s] [%s] [error] %s\033[0m\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" >&2; }

# Shared content files
CLAUDE_SHARED="$SHARED_DIR/claude-shared.md"

# Verify shared files exist
if [ ! -f "$CLAUDE_SHARED" ]; then
    blog_error "Required shared file not found: $CLAUDE_SHARED"
    exit 1
fi
for skill_file in "$SHARED_DIR/skills/chrome-devtools/SKILL.md" "$SHARED_DIR/skills/a11y-debugging/SKILL.md"; do
    if [ ! -f "$skill_file" ]; then
        blog_error "Required skill file not found: $skill_file"
        exit 1
    fi
done
if [ ! -f "$SHARED_DIR/hooks/session-archive.sh" ]; then
    blog_error "Required hook file not found: $SHARED_DIR/hooks/session-archive.sh"
    exit 1
fi

# Read shared content
CLAUDE_SHARED_CONTENT=$(cat "$CLAUDE_SHARED")
HOOK_SESSION_ARCHIVE=$(cat "$SHARED_DIR/hooks/session-archive.sh")
HOOK_STANDING_ORDER_GUARD=$(cat "$SHARED_DIR/hooks/standing-order-guard.sh")

# Read shared library content for inlining into deploy scripts
AITOOLS_LIB_BASH=$(cat "$SCRIPTS_DIR/aitools-lib.sh")
AITOOLS_LIB_PS1=$(cat "$SCRIPTS_DIR/aitools-lib.ps1")

# inline_lib_bash: replaces `source.*aitools-lib.sh` line with lib content (stdin -> stdout)
inline_lib_bash() {
    local line
    while IFS= read -r line; do
        if echo "$line" | grep -q 'source.*aitools-lib\.sh'; then
            printf '%s\n' "$AITOOLS_LIB_BASH"
        else
            printf '%s\n' "$line"
        fi
    done
}

# inline_lib_ps1: replaces `. .*aitools-lib.ps1` line with lib content (stdin -> stdout)
inline_lib_ps1() {
    local line
    while IFS= read -r line; do
        if echo "$line" | grep -q 'aitools-lib\.ps1'; then
            printf '%s\n' "$AITOOLS_LIB_PS1"
        else
            printf '%s\n' "$line"
        fi
    done
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

# --- Profile interpolation ---
# Read profile from user repo, interpolate identity placeholders.
# Fallback: use defaults if profile not found (build never fails).
PROFILE_NAME="Jose"
PROFILE_COMPANY="Nobul"
IDENTITY_GIT_NAME="Jose"
IDENTITY_GIT_EMAIL="jose@nobul.tech"
CURSOR_CLI_VIMMODE=false
CURSOR_CLI_MODEL="auto"
CLAUDE_AUTO_MEMORY=true
CLAUDE_ALWAYS_THINKING=true

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
    // Claude preferences
    let claudePrefs = { autoMemory: true, alwaysThinking: true };
    if (p.claude) {
        if (typeof p.claude.autoMemory === 'boolean') claudePrefs.autoMemory = p.claude.autoMemory;
        if (typeof p.claude.alwaysThinking === 'boolean') claudePrefs.alwaysThinking = p.claude.alwaysThinking;
    }
    // Output as KEY=VALUE lines for bash eval
    console.log('PROFILE_NAME=' + JSON.stringify(prof.name));
    console.log('PROFILE_COMPANY=' + JSON.stringify(prof.company));
    console.log('IDENTITY_GIT_NAME=' + JSON.stringify(ident.git.name));
    console.log('IDENTITY_GIT_EMAIL=' + JSON.stringify(ident.git.email));
    console.log('CURSOR_CLI_VIMMODE=' + JSON.stringify(cursorCli.vimMode));
    console.log('CURSOR_CLI_MODEL=' + JSON.stringify(cursorCli.model));
    console.log('CLAUDE_AUTO_MEMORY=' + JSON.stringify(claudePrefs.autoMemory));
    console.log('CLAUDE_ALWAYS_THINKING=' + JSON.stringify(claudePrefs.alwaysThinking));
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
blog "Claude prefs: autoMemory=$CLAUDE_AUTO_MEMORY alwaysThinking=$CLAUDE_ALWAYS_THINKING"

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
        '^    # --- BEGIN post-write validation' '^    # --- END post-write validation'
    cat <<'BLOCK'

    log_ok "Wrote $(display_path "$CLAUDE_MD")"
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
        '^    # --- BEGIN post-write validation' '^    # --- END post-write validation' --crlf
    cat <<'BLOCK'

    LogOk "Wrote $claudeMd"
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
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)

BLOCK
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
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#
# Managed fields: version, editor.vimMode, permissions, model, hasChangedDefaultModel
# Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields

BLOCK
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
# 23-24. deploy/setup-user-mcp.sh and .ps1 (template with embedded skills)
# ============================================================
# The scripts/ versions read skills from shared/skills/ (repo-relative).
# The deploy/ versions must be self-contained, so we embed SKILL.md content
# inline using heredocs, replacing the file-copy deploy_skill() function.

# Read skill content
SKILL_CHROME_DEVTOOLS=$(cat "$SHARED_DIR/skills/chrome-devtools/SKILL.md")
SKILL_A11Y_DEBUGGING=$(cat "$SHARED_DIR/skills/a11y-debugging/SKILL.md")

blog "Generating deploy/setup-user-mcp.sh (with embedded skills)"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Extract everything from script body start to skills section
    extract_between "$SCRIPTS_DIR/setup-user-mcp.sh" \
        '^# --- BEGIN mcp body' '^# --- END mcp body'
    # Emit self-contained skills deployment using heredocs
    cat <<'SKILLS_HEADER'

# --- Deploy Chrome DevTools skills (embedded) ---
# Vendored from https://github.com/ChromeDevTools/chrome-devtools-mcp/tree/main/skills
# Content embedded at build time by build-deploy.sh for self-contained deployment.

SKILLS_DEST="$HOME/.claude/skills"
SKILLS_DEST_CURSOR="$HOME/.cursor/skills"

SKILLS_HEADER
    # Deploy to ~/.claude/skills/ (Claude Code)
    echo 'log "Deploying skills to $SKILLS_DEST..."'
    echo 'mkdir -p "$SKILLS_DEST/chrome-devtools"'
    echo 'cat > "$SKILLS_DEST/chrome-devtools/SKILL.md" <<'"'"'__SKILL_CHROME_DEVTOOLS__'"'"
    echo "$SKILL_CHROME_DEVTOOLS"
    echo '__SKILL_CHROME_DEVTOOLS__'
    echo 'log_ok "Deployed skill: chrome-devtools -> $SKILLS_DEST/chrome-devtools"'
    echo ''
    echo 'mkdir -p "$SKILLS_DEST/a11y-debugging"'
    echo 'cat > "$SKILLS_DEST/a11y-debugging/SKILL.md" <<'"'"'__SKILL_A11Y_DEBUGGING__'"'"
    echo "$SKILL_A11Y_DEBUGGING"
    echo '__SKILL_A11Y_DEBUGGING__'
    echo 'log_ok "Deployed skill: a11y-debugging -> $SKILLS_DEST/a11y-debugging"'
    echo 'write_summary OK "claude skills" "deployed"'
    echo ''
    # Deploy to ~/.cursor/skills/ (Cursor Agent CLI)
    echo 'log "Deploying skills to $SKILLS_DEST_CURSOR..."'
    echo 'mkdir -p "$SKILLS_DEST_CURSOR/chrome-devtools"'
    echo 'cat > "$SKILLS_DEST_CURSOR/chrome-devtools/SKILL.md" <<'"'"'__SKILL_CHROME_DEVTOOLS_CURSOR__'"'"
    echo "$SKILL_CHROME_DEVTOOLS"
    echo '__SKILL_CHROME_DEVTOOLS_CURSOR__'
    echo 'log_ok "Deployed skill: chrome-devtools -> $SKILLS_DEST_CURSOR/chrome-devtools"'
    echo ''
    echo 'mkdir -p "$SKILLS_DEST_CURSOR/a11y-debugging"'
    echo 'cat > "$SKILLS_DEST_CURSOR/a11y-debugging/SKILL.md" <<'"'"'__SKILL_A11Y_DEBUGGING_CURSOR__'"'"
    echo "$SKILL_A11Y_DEBUGGING"
    echo '__SKILL_A11Y_DEBUGGING_CURSOR__'
    echo 'log_ok "Deployed skill: a11y-debugging -> $SKILLS_DEST_CURSOR/a11y-debugging"'
    echo 'write_summary OK "cursor skills" "deployed"'
    echo ''
    # Emit exit footer from source
    extract_between "$SCRIPTS_DIR/setup-user-mcp.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-user-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-mcp.ps1 (with embedded skills)"
{
    echo "$HEADER_COMMENT_PS1"
    # Extract everything from script body start to skills section (CRLF for PS1)
    extract_between "$SCRIPTS_DIR/setup-user-mcp.ps1" \
        '^# --- BEGIN mcp body' '^# --- END mcp body' --crlf
    # Emit self-contained skills deployment using PS1 here-strings
    cat <<'SKILLS_PS1_HEADER'

# --- Deploy Chrome DevTools skills (embedded) ---
# Vendored from https://github.com/ChromeDevTools/chrome-devtools-mcp/tree/main/skills
# Content embedded at build time by build-deploy.sh for self-contained deployment.

$skillsDest = Join-Path (Join-Path $env:USERPROFILE ".claude") "skills"
$skillsDestCursor = Join-Path (Join-Path $env:USERPROFILE ".cursor") "skills"

SKILLS_PS1_HEADER
    # Deploy to ~/.claude/skills/ (Claude Code)
    echo 'Log "Deploying skills to $skillsDest..."'
    echo '$chromeDevtoolsDir = Join-Path $skillsDest "chrome-devtools"'
    echo 'if (-not (Test-Path $chromeDevtoolsDir)) { New-Item -ItemType Directory -Path $chromeDevtoolsDir -Force | Out-Null }'
    echo '$chromeDevtoolsSkill = @'"'"
    echo "$SKILL_CHROME_DEVTOOLS"
    echo "'"'@'
    echo '$chromeDevtoolsDest = Join-Path $chromeDevtoolsDir "SKILL.md"'
    echo '[System.IO.File]::WriteAllText($chromeDevtoolsDest, $chromeDevtoolsSkill, [System.Text.UTF8Encoding]::new($false))'
    echo 'LogOk "Deployed skill: chrome-devtools -> $chromeDevtoolsDest"'
    echo ''
    echo '$a11yDir = Join-Path $skillsDest "a11y-debugging"'
    echo 'if (-not (Test-Path $a11yDir)) { New-Item -ItemType Directory -Path $a11yDir -Force | Out-Null }'
    echo '$a11ySkill = @'"'"
    echo "$SKILL_A11Y_DEBUGGING"
    echo "'"'@'
    echo '$a11yDest = Join-Path $a11yDir "SKILL.md"'
    echo '[System.IO.File]::WriteAllText($a11yDest, $a11ySkill, [System.Text.UTF8Encoding]::new($false))'
    echo 'LogOk "Deployed skill: a11y-debugging -> $a11yDest"'
    echo 'Write-Summary "OK" "claude skills" "deployed"'
    echo ''
    # Deploy to ~/.cursor/skills/ (Cursor Agent CLI)
    echo 'Log "Deploying skills to $skillsDestCursor..."'
    echo '$chromeDevtoolsDirCursor = Join-Path $skillsDestCursor "chrome-devtools"'
    echo 'if (-not (Test-Path $chromeDevtoolsDirCursor)) { New-Item -ItemType Directory -Path $chromeDevtoolsDirCursor -Force | Out-Null }'
    echo '$chromeDevtoolsDestCursor = Join-Path $chromeDevtoolsDirCursor "SKILL.md"'
    echo '[System.IO.File]::WriteAllText($chromeDevtoolsDestCursor, $chromeDevtoolsSkill, [System.Text.UTF8Encoding]::new($false))'
    echo 'LogOk "Deployed skill: chrome-devtools -> $chromeDevtoolsDestCursor"'
    echo ''
    echo '$a11yDirCursor = Join-Path $skillsDestCursor "a11y-debugging"'
    echo 'if (-not (Test-Path $a11yDirCursor)) { New-Item -ItemType Directory -Path $a11yDirCursor -Force | Out-Null }'
    echo '$a11yDestCursor = Join-Path $a11yDirCursor "SKILL.md"'
    echo '[System.IO.File]::WriteAllText($a11yDestCursor, $a11ySkill, [System.Text.UTF8Encoding]::new($false))'
    echo 'LogOk "Deployed skill: a11y-debugging -> $a11yDestCursor"'
    echo 'Write-Summary "OK" "cursor skills" "deployed"'
    echo ''
    # Emit exit footer from source (CRLF for PS1)
    extract_between "$SCRIPTS_DIR/setup-user-mcp.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 15. deploy/setup-user-hooks.sh (extracted from scripts/ + embedded hooks)
# ============================================================
blog "Generating deploy/setup-user-hooks.sh (extracted + embedded hooks)"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-hooks.sh -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Self-contained: hook script and preferences are embedded below. No repo needed.
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.PreToolUse, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields
#
# Hooks deployed:
#   SessionEnd: session-archive.sh (archives transcripts to user repo)
#   PreToolUse[Bash]: standing-order-guard.sh (enforces standing orders on Bash commands)

BLOCK
    # Extract: set -euo pipefail, flag parsing, logging, OS guard, DRY_RUN, require node
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- BEGIN hooks body' '^# --- BEGIN hook deployment'

    # REPLACE: hook deployment (deploy embeds scripts via heredoc instead of cp from repo)
    cat <<'BLOCK'
# --- Deploy embedded hook scripts to ~/.claude/hooks/ ---
HOOK_DEST="$HOME/.claude/hooks/session-archive.sh"
GUARD_DEST="$HOME/.claude/hooks/standing-order-guard.sh"
mkdir -p "$HOME/.claude/hooks"

if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hooks to ~/.claude/hooks/"
else
BLOCK
    echo 'cat > "$HOOK_DEST" <<'"'"'__EMBEDDED_HOOK__'"'"
    echo "$HOOK_SESSION_ARCHIVE"
    echo '__EMBEDDED_HOOK__'
    echo 'cat > "$GUARD_DEST" <<'"'"'__EMBEDDED_GUARD__'"'"
    echo "$HOOK_STANDING_ORDER_GUARD"
    echo '__EMBEDDED_GUARD__'
    cat <<'BLOCK'

    chmod +x "$HOOK_DEST"
    log_ok "Deployed hook: $HOOK_DEST"
    chmod +x "$GUARD_DEST"
    log_ok "Deployed hook: $GUARD_DEST"
fi

BLOCK

    # Extract: merge setup (SETTINGS_FILE, mkdir, HOOK_CMD, GUARD_CMD, node block start)
    # up to the profile preference reading inside the node block
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- END hook deployment' '^// --- BEGIN claude preferences'

    # REPLACE: embedded preferences (from profile.json at build time)
    cat <<BLOCK_INTERP
// --- Embedded preferences (from profile.json at build time) ---
const autoMemory = $CLAUDE_AUTO_MEMORY;
const alwaysThinking = $CLAUDE_ALWAYS_THINKING;
BLOCK_INTERP

    # Extract: rest of node block (merge logic, clobber, validation) + case statement
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^// --- END claude preferences' '^# --- END hooks body'

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
# setup-user-hooks.ps1 -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Self-contained: hook scripts and preferences are embedded below. No repo needed.
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.PreToolUse, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields
#
# Hooks deployed:
#   SessionEnd: session-archive.sh (archives transcripts to user repo)
#   PreToolUse[Bash]: standing-order-guard.sh (enforces standing orders on Bash commands)
#
# Note: Hook scripts are bash-only (Claude Code hooks always run in bash on
# both platforms). This PS1 script only deploys the hook configuration.

BLOCK
    # Extract: param(), logging, OS guard, ConvertPSObjectToHashtable, DRY_RUN
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- BEGIN hooks body' '^# --- BEGIN hook deployment' --crlf

    # REPLACE: hook deployment (deploy embeds scripts via here-string instead of Copy-Item from repo)
    printf '# --- Deploy embedded hook scripts to ~/.claude/hooks/ ---\r\n'
    printf '$claudeDir = Join-Path $env:USERPROFILE ".claude"\r\n'
    printf '$hooksDir = Join-Path $claudeDir "hooks"\r\n'
    printf 'if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }\r\n'
    printf '\r\n'
    printf '$hookDest = Join-Path $hooksDir "session-archive.sh"\r\n'
    printf '$guardDest = Join-Path $hooksDir "standing-order-guard.sh"\r\n'
    printf '\r\n'
    # Embed hook content via PS here-strings
    printf '$hookContent = @'"'"'\r\n'
    echo "$HOOK_SESSION_ARCHIVE" | perl -pe 's/\r?\n$/\r\n/'
    printf ''"'"'@\r\n'
    printf '\r\n'
    printf '$guardContent = @'"'"'\r\n'
    echo "$HOOK_STANDING_ORDER_GUARD" | perl -pe 's/\r?\n$/\r\n/'
    printf ''"'"'@\r\n'
    printf '\r\n'
    printf 'if ($DryRun) {\r\n'
    printf '    Log "[DRY RUN] Would deploy hooks to ~/.claude/hooks/"\r\n'
    printf '} else {\r\n'
    printf '    $resolvedHook = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($hookDest)\r\n'
    printf '    [System.IO.File]::WriteAllText($resolvedHook, $hookContent, [System.Text.UTF8Encoding]::new($false))\r\n'
    printf '    LogOk "Deployed hook: $hookDest"\r\n'
    printf '    $resolvedGuard = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($guardDest)\r\n'
    printf '    [System.IO.File]::WriteAllText($resolvedGuard, $guardContent, [System.Text.UTF8Encoding]::new($false))\r\n'
    printf '    LogOk "Deployed hook: $guardDest"\r\n'
    printf '}\r\n'

    # REPLACE: embedded preferences (no extraction between — sentinels are adjacent in PS1)
    printf '\r\n'
    printf '# --- Embedded preferences (from profile.json at build time) ---\r\n'
    printf '$autoMemory = $%s\r\n' "$CLAUDE_AUTO_MEMORY"
    printf '$alwaysThinking = $%s\r\n' "$CLAUDE_ALWAYS_THINKING"

    # Extract: merge section (settings.json merge, MergeHookEntry, clobber, validation)
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- END claude preferences' '^# --- END hooks body' --crlf

    # Extract: exit footer
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-hooks.ps1"

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

blog_ok "Build complete: $GENERATED scripts generated in deploy/"
ls -la "$DEPLOY_DIR/"
blog "Scripts are self-contained and ready for MDM deployment"
