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

# --- Build logging (timestamped) ---
SCRIPT_NAME="build-deploy"
blog() { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_ok() { blog "OK: $1"; }
blog_error() { blog "ERROR: $1" >&2; }

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
# Bash logging helpers (embedded into each bash deploy script)
# ============================================================
bash_logging_helpers() {
    local script_name="$1"
    cat <<'LOGGING_BASH'
# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
LOGGING_BASH
    echo "SCRIPT_NAME=\"$script_name\""
    cat <<'LOGGING_BASH'
ERRORS=0

mkdir -p "$LOG_DIR"

log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }
LOGGING_BASH
}

# PowerShell logging helpers
ps1_logging_helpers() {
    local script_name="$1"
    cat <<LOGGING_PS1
# --- Logging ---
\$logDir = Join-Path \$env:LOCALAPPDATA "aitools"
\$logFile = Join-Path \$logDir "deploy.log"
\$scriptName = "$script_name"
\$errors = 0

if (-not (Test-Path \$logDir)) { New-Item -ItemType Directory -Path \$logDir -Force | Out-Null }

function Log(\$msg) {
    \$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    \$line = "[\$ts] [\$scriptName] \$msg"
    Write-Host \$line
    Add-Content -Path \$logFile -Value \$line
}
function LogOk(\$msg)    { Log "OK: \$msg" }
function LogError(\$msg) { Log "ERROR: \$msg"; \$script:errors++ }
function LogWarn(\$msg)  { Log "WARN: \$msg" }
LOGGING_PS1
}

# Bash exit footer
bash_exit_footer() {
    cat <<'EXIT_BASH'

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
EXIT_BASH
}

# PowerShell exit footer
ps1_exit_footer() {
    cat <<'EXIT_PS1'

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
EXIT_PS1
}

# ============================================================
# Backup helpers (embedded into deploy scripts that overwrite files)
# ============================================================
bash_backup_helper() {
    cat <<'BACKUP_BASH'

# Backup a file before overwriting. Keeps at most $max_backups copies.
backup_file() {
    local file="$1" max_backups=20
    [ -f "$file" ] || return 0
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    cp "$file" "${file}.bak.${ts}"
    # Prune oldest beyond limit
    ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1)) | xargs rm -f 2>/dev/null
    log "Backed up $file"
}
BACKUP_BASH
}

ps1_backup_helper() {
    cat <<'BACKUP_PS1'

# Backup a file before overwriting. Keeps at most $MaxBackups copies.
function Backup-File {
    param([string]$FilePath, [int]$MaxBackups = 20)
    if (-not (Test-Path $FilePath)) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${FilePath}.bak.${ts}"
    Copy-Item -Path $FilePath -Destination $backupPath
    # Prune oldest beyond limit
    $backups = Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending
    if ($backups.Count -gt $MaxBackups) {
        $backups | Select-Object -Skip $MaxBackups | Remove-Item -Force
    }
    Log "Backed up $FilePath"
}
BACKUP_PS1
}

# ============================================================
# OS guard helpers (embedded into template-generated deploy scripts)
# ============================================================
bash_os_guard() {
    cat <<'OS_GUARD_BASH'

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use the .ps1 version."
        exit 1 ;;
esac
OS_GUARD_BASH
}

ps1_os_guard() {
    cat <<'OS_GUARD_PS1'

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}
OS_GUARD_PS1
}

ps1_version_guard() {
    cat <<'VERSION_GUARD_PS1'

# --- PS 7 version guard ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: This script requires PowerShell 7+. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "Install: winget install --id Microsoft.PowerShell --source winget" -ForegroundColor Yellow
    exit 1
}
VERSION_GUARD_PS1
}

# ============================================================
# PS 5.1 compatibility helper (ConvertPSObjectToHashtable)
# ============================================================
ps1_hashtable_helper() {
    cat <<'HASHTABLE_PS1'

# --- PS 5.1 compatibility helper ---
function ConvertPSObjectToHashtable($obj) {
    if ($null -eq $obj) { return @{} }
    $ht = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
            $ht[$prop.Name] = ConvertPSObjectToHashtable $prop.Value
        } else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}
HASHTABLE_PS1
}

# ============================================================
# Flag parsing helpers (--dry-run / --force support in deploy scripts)
# ============================================================
bash_flag_helpers() {
    cat <<'FLAG_BASH'

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

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"
FLAG_BASH
}

ps1_param_block() {
    cat <<'PARAM_PS1'
param(
    [switch]$DryRun,
    [switch]$Force
)

PARAM_PS1
}

ps1_flag_helpers() {
    cat <<'FLAG_PS1'

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }
FLAG_PS1
}

# ============================================================
# 1. deploy/setup-user-claude.sh
# ============================================================
blog "Generating deploy/setup-user-claude.sh"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-claude.sh — Creates user-level ~/.claude/CLAUDE.md
# Self-contained: shared preferences are embedded below. No repo or Drive needed.
# Safe to re-run — replaces existing file with latest version.

set -euo pipefail

BLOCK
    bash_logging_helpers "setup-user-claude"
    bash_os_guard
    bash_backup_helper
    bash_flag_helpers
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

    log_ok "Wrote $CLAUDE_MD"
    log "Machine: $OS_NAME $ARCH ($HOSTNAME), Shell: $SHELL_NAME"

    # Post-write validation: check structure AND content (not just a marker)
    if [ ! -s "$CLAUDE_MD" ]; then
        log_error "Validation failed: $CLAUDE_MD is empty or missing"
    elif ! grep -q "## Machine-Specific" "$CLAUDE_MD"; then
        log_error "Validation failed: $CLAUDE_MD missing Machine-Specific section"
    elif ! grep -qE "## (Coaching|Code Style|Tool)" "$CLAUDE_MD"; then
        # Template body must be present -- a file with only the footer is corrupt
        log_error "Validation failed: $CLAUDE_MD missing template body (only footer present?)"
    fi
fi
BLOCK
    bash_exit_footer
} > "$DEPLOY_DIR/setup-user-claude.sh"

chmod +x "$DEPLOY_DIR/setup-user-claude.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 2. deploy/setup-user-claude.ps1
# ============================================================
blog "Generating deploy/setup-user-claude.ps1"

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-claude.ps1 — Creates user-level ~/.claude/CLAUDE.md on Windows
# Self-contained: shared preferences are embedded below. No repo or Drive needed.
# Safe to re-run — replaces existing file with latest version.

BLOCK
    ps1_param_block
    ps1_logging_helpers "setup-user-claude"
    ps1_os_guard
    ps1_version_guard
    ps1_backup_helper
    ps1_flag_helpers
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
    if (Test-Path $claudeMd) {
        Remove-Item $claudeMd
        Log "Removed existing $claudeMd"
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($claudeMd)
    [System.IO.File]::WriteAllText($resolvedPath, $content, [System.Text.UTF8Encoding]::new($false))

    # Post-write validation: check structure AND content (not just a marker)
    if (-not (Test-Path $claudeMd) -or (Get-Item $claudeMd).Length -eq 0) {
        LogError "Validation failed: $claudeMd is empty or missing"
    } else {
        $written = Get-Content $claudeMd -Raw
        if ($written -notmatch '## Machine-Specific') {
            LogError "Validation failed: $claudeMd missing Machine-Specific section"
        }
        # Template body must be present -- a file with only the footer is corrupt
        if ($written -notmatch '## Coaching|## Code Style|## Tool') {
            LogError "Validation failed: $claudeMd missing template body (only footer present?)"
        }
    }

    LogOk "Wrote $claudeMd"
    Log "Machine: $osInfo ($hostname)"
}
BLOCK
    ps1_exit_footer
} > "$DEPLOY_DIR/setup-user-claude.ps1"

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

set -euo pipefail

BLOCK
    bash_logging_helpers "setup-user-cursor"
    bash_backup_helper
    bash_os_guard
    bash_flag_helpers
    cat <<'BLOCK'

CURSOR_DIR="$HOME/.cursor"
CLI_CONFIG="$CURSOR_DIR/cli-config.json"

# --- 1. ripgrep (rg) ---
log "Step 1: ripgrep (rg)"

if [ "$DRY_RUN" = "true" ]; then
    if command -v rg &>/dev/null; then
        log "[DRY RUN] ripgrep already installed: $(rg --version | head -1)"
    else
        log "[DRY RUN] Would install ripgrep via brew"
    fi
else
    if command -v rg &>/dev/null; then
        RG_VERSION=$(rg --version | head -1)
        log_ok "Already installed: $RG_VERSION"
    else
        if command -v brew &>/dev/null; then
            log "Installing ripgrep via brew..."
            brew install ripgrep
            if command -v rg &>/dev/null; then
                log_ok "Installed: $(rg --version | head -1)"
            else
                log_error "brew install completed but 'rg' not found in PATH"
            fi
        else
            log_error "Homebrew not found. Install ripgrep manually: brew install ripgrep"
        fi
    fi
fi

# --- 2. Cursor CLI (agent) ---
log "Step 2: Cursor CLI (agent)"

if [ "$DRY_RUN" = "true" ]; then
    if command -v agent &>/dev/null; then
        log "[DRY RUN] Cursor CLI already installed: $(agent --version)"
    else
        log "[DRY RUN] Would install Cursor CLI via curl"
    fi
else
    if command -v agent &>/dev/null; then
        AGENT_VERSION=$(agent --version)
        log_ok "Already installed: $AGENT_VERSION"
    else
        log "Installing Cursor CLI..."
        curl https://cursor.com/install -fsS | bash
        if command -v agent &>/dev/null; then
            log_ok "Installed: $(agent --version)"
        else
            log_error "Cursor CLI install completed but 'agent' not found in PATH (restart terminal)"
        fi
    fi
fi

# --- 3. cli-config.json (merge, not overwrite) ---
log "Step 3: cli-config.json"

mkdir -p "$CURSOR_DIR"

if ! command -v node &>/dev/null; then
    log_warn "node not found -- skipping cli-config.json merge"
else
BLOCK
    # Emit the node merge with embedded defaults from profile
    cat <<BLOCK_INTERP
    backup_file "\$CLI_CONFIG"
    MERGE_RESULT=\$(node -e "
const fs = require('fs');
const f = process.argv[1];
const dryRun = process.argv[2] === 'true';
const force = process.argv[3] === 'true';

// --- Embedded preferences (from profile.json at build time) ---
const vimMode = $CURSOR_CLI_VIMMODE;
const modelId = '$CURSOR_CLI_MODEL';

// --- Read existing cli-config.json ---
let config = {};
let corrupt = false;
try { config = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) {
    if (e.code !== 'ENOENT') {
        corrupt = true;
        console.error('Warning: ' + f + ' is invalid JSON');
    }
}
const beforeKeys = Object.keys(config);

// --- Merge managed fields ---
config.version = 1;
if (!config.editor) config.editor = {};
config.editor.vimMode = vimMode;
if (!config.permissions) config.permissions = {};
if (!Array.isArray(config.permissions.allow)) config.permissions.allow = [];
if (!Array.isArray(config.permissions.deny)) config.permissions.deny = [];

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

// Clobber detection
const afterKeys = Object.keys(config);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.log('would-merge');
    if (corrupt) console.error('[DRY RUN] File is corrupt -- --force required');
    if (lostKeys.length) console.error('[DRY RUN] CLOBBER: would lose: ' + lostKeys.join(', '));
} else if (corrupt && !force) {
    console.log('error-corrupt');
} else if (lostKeys.length && !force) {
    console.log('error-clobber');
    console.error('Would lose fields: ' + lostKeys.join(', '));
} else {
    const before = JSON.stringify(config);
    fs.writeFileSync(f, JSON.stringify(config, null, 2) + '\\\\n');

    // Post-write validation
    const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
    const _missing = ['version'].filter(k => !(k in _v));
    if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }

    console.log(beforeKeys.length === 0 ? 'created' : 'merged');
}
" "\$CLI_CONFIG" "\$DRY_RUN" "\$FORCE")

    case "\$MERGE_RESULT" in
        unchanged)     log_ok "Already up to date: \$CLI_CONFIG" ;;
        created)       log_ok "Created: \$CLI_CONFIG" ;;
        merged)        log_ok "Merged preferences into: \$CLI_CONFIG" ;;
        would-merge)   log "[DRY RUN] \$CLI_CONFIG: merge managed fields" ;;
        error-corrupt) log_error "\$CLI_CONFIG is corrupt. Use --force to overwrite, or fix manually." ;;
        error-clobber) log_error "\$CLI_CONFIG merge would lose fields. Use --force to proceed." ;;
        *)             log_error "Unexpected merge result: \$MERGE_RESULT" ;;
    esac
fi
BLOCK_INTERP
    bash_exit_footer
} > "$DEPLOY_DIR/setup-user-cursor.sh"

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
    ps1_param_block
    ps1_logging_helpers "setup-user-cursor"
    ps1_backup_helper
    ps1_os_guard
    ps1_version_guard
    ps1_hashtable_helper
    ps1_flag_helpers
    cat <<'BLOCK'

# Helper: refresh PATH from registry (picks up winget installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

$cursorDir = Join-Path $env:USERPROFILE ".cursor"
$cliConfig = Join-Path $cursorDir "cli-config.json"

# --- 1. ripgrep (rg) ---
Log "Step 1: ripgrep (rg)"

if ($DryRun) {
    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        Log "[DRY RUN] ripgrep already installed: $(rg --version | Select-Object -First 1)"
    } else {
        Log "[DRY RUN] Would install ripgrep via winget"
    }
} else {
    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        LogOk "Already installed: $rgVersion"
    } else {
        Log "Installing ripgrep via winget..."
        winget install BurntSushi.ripgrep.MSVC --accept-package-agreements --accept-source-agreements
        Refresh-Path
        $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
        if ($rgCmd) {
            LogOk "Installed: $(rg --version | Select-Object -First 1)"
        } else {
            LogError "winget install completed but 'rg' not found in PATH (restart terminal)"
        }
    }
}

# --- 2. Cursor CLI (agent) ---
Log "Step 2: Cursor CLI (agent)"

if ($DryRun) {
    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        Log "[DRY RUN] Cursor CLI already installed: $(agent --version)"
    } else {
        Log "[DRY RUN] Would install Cursor CLI"
    }
} else {
    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        LogOk "Already installed: $agentVersion"
    } else {
        Log "Installing Cursor CLI..."
        Invoke-Expression (Invoke-RestMethod 'https://cursor.com/install?win32=true')
        $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
        if ($agentCmd) {
            LogOk "Installed: $(agent --version)"
        } else {
            LogError "Cursor CLI install completed but 'agent' not found in PATH (restart terminal)"
        }
    }
}

# --- 3. cli-config.json (merge, not overwrite) ---
Log "Step 3: cli-config.json"

if (-not (Test-Path $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    Log "Created $cursorDir"
}

BLOCK
    # Emit native PS merge with embedded build-time preferences
    cat <<BLOCK_INTERP
# --- Embedded preferences (from profile.json at build time) ---
\$vimMode = \$$CURSOR_CLI_VIMMODE
\$modelId = "$CURSOR_CLI_MODEL"

# --- Read existing cli-config.json ---
\$config = @{}
\$corrupt = \$false
if (Test-Path \$cliConfig) {
    try {
        \$config = ConvertPSObjectToHashtable (Get-Content \$cliConfig -Raw | ConvertFrom-Json)
    } catch {
        \$corrupt = \$true
        LogWarn "\$cliConfig could not be parsed (\$_)"
    }
}
\$beforeKeys = @(\$config.Keys)

# --- Merge managed fields ---
\$config["version"] = 1
if (-not \$config.ContainsKey("editor")) { \$config["editor"] = @{} }
\$config["editor"]["vimMode"] = \$vimMode
if (-not \$config.ContainsKey("permissions")) { \$config["permissions"] = @{} }
if (-not \$config["permissions"].ContainsKey("allow")) { \$config["permissions"]["allow"] = @() }
if (-not \$config["permissions"].ContainsKey("deny")) { \$config["permissions"]["deny"] = @() }

if (\$modelId -eq "auto") {
    \$config["model"] = @{
        modelId = "default"
        displayModelId = "auto"
        displayName = "Auto"
        displayNameShort = "Auto"
        aliases = @("auto")
        maxMode = \$false
    }
    \$config["hasChangedDefaultModel"] = \$true
}

# Clobber detection
\$lostKeys = @(\$beforeKeys | Where-Object { \$_ -notin \$config.Keys })

if (\$DryRun) {
    Log "[DRY RUN] \$cliConfig\`: merge managed fields"
    Log "  Managed: version, editor.vimMode, permissions, model, hasChangedDefaultModel"
    if (\$lostKeys.Count -gt 0) {
        LogWarn "[DRY RUN] CLOBBER: would lose: \$(\$lostKeys -join ', ')"
    }
    if (\$corrupt) {
        LogWarn "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
} elseif (\$corrupt -and -not \$Force) {
    LogError "\$cliConfig is corrupt. Use -Force to overwrite, or fix manually."
} elseif (\$lostKeys.Count -gt 0 -and -not \$Force) {
    LogError "\$cliConfig merge would lose fields: \$(\$lostKeys -join ', '). Use -Force to proceed."
} else {
    if (\$corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
    if (\$lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: \$(\$lostKeys -join ', ')" }

    Backup-File -FilePath \$cliConfig
    \$json = \$config | ConvertTo-Json -Depth 10
    \$resolvedPath = \$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(\$cliConfig)
    [System.IO.File]::WriteAllText(\$resolvedPath, \$json, [System.Text.UTF8Encoding]::new(\$false))

    # Post-write validation
    try {
        \$vContent = [System.IO.File]::ReadAllText(\$resolvedPath)
        \$vParsed = \$vContent | ConvertFrom-Json
        if (-not (\$vParsed.PSObject.Properties.Name -contains "version")) {
            LogError "Validation failed: \$cliConfig missing required field 'version'"
        }
    } catch {
        LogError "Validation failed: \$cliConfig is not valid JSON -- \$_"
    }

    if (\$beforeKeys.Count -eq 0) {
        LogOk "Created: \$cliConfig"
    } else {
        LogOk "Merged preferences into: \$cliConfig"
    }
}
BLOCK_INTERP
    ps1_exit_footer
} > "$DEPLOY_DIR/setup-user-cursor.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# 5-6. deploy/setup-cursor-mcp.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-cursor-mcp.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Strip the shebang from source and append the rest
    tail -n +2 "$SCRIPTS_DIR/setup-cursor-mcp.sh"
} > "$DEPLOY_DIR/setup-cursor-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-cursor-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-cursor-mcp.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-cursor-mcp.ps1"
} > "$DEPLOY_DIR/setup-cursor-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 7-8. deploy/setup-vercelcli.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-vercelcli.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Strip the shebang from source and append the rest
    tail -n +2 "$SCRIPTS_DIR/setup-vercelcli.sh"
} > "$DEPLOY_DIR/setup-vercelcli.sh"
chmod +x "$DEPLOY_DIR/setup-vercelcli.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-vercelcli.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-vercelcli.ps1"
} > "$DEPLOY_DIR/setup-vercelcli.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 9-10. deploy/setup-pandoc.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-pandoc.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Strip the shebang from source and append the rest
    tail -n +2 "$SCRIPTS_DIR/setup-pandoc.sh"
} > "$DEPLOY_DIR/setup-pandoc.sh"
chmod +x "$DEPLOY_DIR/setup-pandoc.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-pandoc.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-pandoc.ps1"
} > "$DEPLOY_DIR/setup-pandoc.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 11-12. deploy/setup-rust.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-rust.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Strip the shebang from source and append the rest
    tail -n +2 "$SCRIPTS_DIR/setup-rust.sh"
} > "$DEPLOY_DIR/setup-rust.sh"
chmod +x "$DEPLOY_DIR/setup-rust.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-rust.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-rust.ps1"
} > "$DEPLOY_DIR/setup-rust.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 13-14. deploy/setup-user-mcp.sh and .ps1 (template with embedded skills)
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
    # Take everything from source up to (but not including) the skills section
    sed -n '2,/^# --- Deploy Chrome DevTools skills ---$/{ /^# --- Deploy Chrome DevTools skills ---$/!p; }' \
        "$SCRIPTS_DIR/setup-user-mcp.sh"
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
    echo ''
    # Emit exit footer from source
    sed -n '/^# --- Exit ---$/,$ p' "$SCRIPTS_DIR/setup-user-mcp.sh"
} > "$DEPLOY_DIR/setup-user-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-user-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-mcp.ps1 (with embedded skills)"
{
    echo "$HEADER_COMMENT_PS1"
    # Take everything from source up to (but not including) the skills section
    # PS1 files have CRLF -- strip \r for sed matching, then re-add for PS1 output
    tr -d '\r' < "$SCRIPTS_DIR/setup-user-mcp.ps1" | \
        sed -n '1,/^# --- Deploy Chrome DevTools skills ---$/{ /^# --- Deploy Chrome DevTools skills ---$/!p; }' | \
        sed 's/$/'$'\r''/'
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
    echo ''
    # Emit exit footer from source (strip \r for matching, re-add for PS1)
    tr -d '\r' < "$SCRIPTS_DIR/setup-user-mcp.ps1" | \
        sed -n '/^# --- Exit ---$/,$ p' | \
        sed 's/$/'$'\r''/'
} > "$DEPLOY_DIR/setup-user-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 13. deploy/setup-user-hooks.sh (template with embedded hook + prefs)
# ============================================================
blog "Generating deploy/setup-user-hooks.sh (with embedded hook + prefs)"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-hooks.sh -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Self-contained: hook script and preferences are embedded below. No repo needed.
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields

set -euo pipefail

BLOCK
    bash_logging_helpers "setup-user-hooks"
    bash_os_guard
    bash_flag_helpers
    cat <<'BLOCK'

# --- Require node for JSON manipulation ---
if ! command -v node &>/dev/null; then
    log_error "node required for JSON manipulation"
    exit 1
fi

# --- Deploy embedded hook script to ~/.claude/hooks/ ---
HOOK_DEST="$HOME/.claude/hooks/session-archive.sh"
mkdir -p "$HOME/.claude/hooks"

BLOCK
    # Embed the hook script content via heredoc
    cat <<'BLOCK'
if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hook to $HOOK_DEST"
else
BLOCK
    echo 'cat > "$HOOK_DEST" <<'"'"'__EMBEDDED_HOOK__'"'"
    echo "$HOOK_SESSION_ARCHIVE"
    echo '__EMBEDDED_HOOK__'
    cat <<'BLOCK'

    chmod +x "$HOOK_DEST"
    log_ok "Deployed hook: $HOOK_DEST"
fi

# --- Merge hook + preferences into ~/.claude/settings.json ---
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

HOOK_CMD="bash \"$HOOK_DEST\""

BLOCK
    # Emit the node merge block with build-time embedded preference constants
    cat <<BLOCK_INTERP
MERGE_RESULT=\$(node -e "
const fs = require('fs');
const settingsFile = process.argv[1];
const hookCmd = process.argv[2];
const dryRun = process.argv[3] === 'true';
const force = process.argv[4] === 'true';

// --- Embedded preferences (from profile.json at build time) ---
const autoMemory = $CLAUDE_AUTO_MEMORY;
const alwaysThinking = $CLAUDE_ALWAYS_THINKING;

// --- Read existing settings.json ---
let settings = {};
let corrupt = false;
try { settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8')); } catch (e) {
    if (e.code !== 'ENOENT') {
        corrupt = true;
        console.error('Warning: ' + settingsFile + ' is invalid JSON');
    }
}
const beforeKeys = Object.keys(settings);

// --- Merge hook ---
if (!settings.hooks) settings.hooks = {};
if (!Array.isArray(settings.hooks.SessionEnd)) settings.hooks.SessionEnd = [];

const hookId = 'session-archive.sh';
const existing = settings.hooks.SessionEnd.find(rule =>
    rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId))
);

if (existing) {
    existing.hooks.forEach(h => {
        if (h.command && h.command.includes(hookId)) {
            h.command = hookCmd;
        }
    });
} else {
    settings.hooks.SessionEnd.push({
        matcher: '',
        hooks: [{
            type: 'command',
            command: hookCmd
        }]
    });
}

// --- Merge claude preferences ---
settings.autoMemoryEnabled = autoMemory;
settings.alwaysThinkingEnabled = alwaysThinking;

// Clobber detection
const afterKeys = Object.keys(settings);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.log('dry-run');
    if (corrupt) console.error('[DRY RUN] File is corrupt -- --force required');
    if (lostKeys.length) console.error('[DRY RUN] CLOBBER: would lose: ' + lostKeys.join(', '));
} else if (corrupt && !force) {
    console.log('error-corrupt');
} else if (lostKeys.length && !force) {
    console.log('error-clobber');
    console.error('Would lose fields: ' + lostKeys.join(', '));
} else {
    fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');

    // Post-write validation
    const _v = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
    const _missing = ['hooks', 'autoMemoryEnabled', 'alwaysThinkingEnabled'].filter(k => !(k in _v));
    if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }

    console.log('ok');
}
" "\$SETTINGS_FILE" "\$HOOK_CMD" "\$DRY_RUN" "\$FORCE")

case "\$MERGE_RESULT" in
    ok)            log_ok "Settings deployed to \$SETTINGS_FILE" ;;
    dry-run)       log "[DRY RUN] \$SETTINGS_FILE: merge managed fields"
                   log "  Managed: hooks.SessionEnd, autoMemoryEnabled, alwaysThinkingEnabled" ;;
    error-corrupt) log_error "\$SETTINGS_FILE is corrupt. Use --force to overwrite, or fix manually." ;;
    error-clobber) log_error "\$SETTINGS_FILE merge would lose fields. Use --force to proceed." ;;
    *)             log_error "Unexpected merge result: \$MERGE_RESULT" ;;
esac
BLOCK_INTERP
    cat <<'BLOCK'

if [ "$DRY_RUN" != "true" ]; then
    log "  Hook: $HOOK_CMD"
    log "  autoMemoryEnabled: $(node -e "console.log(JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')).autoMemoryEnabled)")"
    log "  alwaysThinkingEnabled: $(node -e "console.log(JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')).alwaysThinkingEnabled)")"
fi
BLOCK
    bash_exit_footer
} > "$DEPLOY_DIR/setup-user-hooks.sh"

chmod +x "$DEPLOY_DIR/setup-user-hooks.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 14. deploy/setup-user-hooks.ps1 (template with embedded hook + prefs)
# ============================================================
blog "Generating deploy/setup-user-hooks.ps1 (with embedded hook + prefs)"

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-hooks.ps1 -- Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Self-contained: hook script and preferences are embedded below. No repo needed.
# Safe to re-run -- merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields
#
# Note: The hook script itself is bash-only (Claude Code hooks always run in
# bash on both platforms). This PS1 script only deploys the hook configuration.

BLOCK
    ps1_param_block
    ps1_logging_helpers "setup-user-hooks"
    ps1_os_guard
    ps1_version_guard
    ps1_hashtable_helper
    ps1_backup_helper
    ps1_flag_helpers
    cat <<'BLOCK'

# --- Deploy embedded hook script to ~/.claude/hooks/ ---
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"
if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }

$hookDest = Join-Path $hooksDir "session-archive.sh"

$hookContent = @'
BLOCK
    echo "$HOOK_SESSION_ARCHIVE"
    cat <<'BLOCK'
'@

if ($DryRun) {
    Log "[DRY RUN] Would deploy hook to $hookDest"
} else {
    $resolvedHook = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($hookDest)
    [System.IO.File]::WriteAllText($resolvedHook, $hookContent, [System.Text.UTF8Encoding]::new($false))
    LogOk "Deployed hook: $hookDest"
}

# --- Merge hook + preferences into ~/.claude/settings.json ---
$settingsFile = Join-Path $claudeDir "settings.json"
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }

# Hook command uses Unix-style path (hooks run in bash even on Windows)
$hookDestUnix = $hookDest -replace '\\', '/'
$hookCmd = "bash `"$hookDestUnix`""

BLOCK
    # Emit native PS merge with embedded build-time preferences
    cat <<BLOCK_INTERP
# --- Embedded preferences (from profile.json at build time) ---
\$autoMemory = \$$CLAUDE_AUTO_MEMORY
\$alwaysThinking = \$$CLAUDE_ALWAYS_THINKING

# --- Read existing settings.json ---
\$settings = @{}
\$corrupt = \$false
if (Test-Path \$settingsFile) {
    try {
        \$settings = ConvertPSObjectToHashtable (Get-Content \$settingsFile -Raw | ConvertFrom-Json)
    } catch {
        \$corrupt = \$true
        LogWarn "\$settingsFile could not be parsed (\$_)"
    }
}
\$beforeKeys = @(\$settings.Keys)

# --- Merge hook ---
if (-not \$settings.ContainsKey("hooks")) { \$settings["hooks"] = @{} }
if (-not \$settings["hooks"].ContainsKey("SessionEnd")) { \$settings["hooks"]["SessionEnd"] = @() }

\$sessionEndArr = @(\$settings["hooks"]["SessionEnd"])
\$hookId = "session-archive.sh"
\$foundHook = \$false
for (\$i = 0; \$i -lt \$sessionEndArr.Count; \$i++) {
    \$rule = \$sessionEndArr[\$i]
    if (\$rule -is [System.Collections.Hashtable] -and \$rule.ContainsKey("hooks")) {
        \$ruleHooks = @(\$rule["hooks"])
        for (\$j = 0; \$j -lt \$ruleHooks.Count; \$j++) {
            \$h = \$ruleHooks[\$j]
            if (\$h -is [System.Collections.Hashtable] -and \$h.ContainsKey("command") -and \$h["command"] -match \$hookId) {
                \$h["command"] = \$hookCmd
                \$foundHook = \$true
            }
        }
    }
}
if (-not \$foundHook) {
    \$newRule = @{
        matcher = ""
        hooks = @(
            @{ type = "command"; command = \$hookCmd }
        )
    }
    \$sessionEndArr += \$newRule
    \$settings["hooks"]["SessionEnd"] = \$sessionEndArr
}

# --- Merge preferences ---
\$settings["autoMemoryEnabled"] = \$autoMemory
\$settings["alwaysThinkingEnabled"] = \$alwaysThinking

# Clobber detection
\$lostKeys = @(\$beforeKeys | Where-Object { \$_ -notin \$settings.Keys })

if (\$DryRun) {
    Log "[DRY RUN] \$settingsFile\`: merge managed fields"
    Log "  Managed: hooks.SessionEnd, autoMemoryEnabled, alwaysThinkingEnabled"
    if (\$lostKeys.Count -gt 0) {
        LogWarn "[DRY RUN] CLOBBER: would lose: \$(\$lostKeys -join ', ')"
    }
    if (\$corrupt) {
        LogWarn "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
} elseif (\$corrupt -and -not \$Force) {
    LogError "\$settingsFile is corrupt. Use -Force to overwrite, or fix manually."
} elseif (\$lostKeys.Count -gt 0 -and -not \$Force) {
    LogError "\$settingsFile merge would lose fields: \$(\$lostKeys -join ', '). Use -Force to proceed."
} else {
    if (\$corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
    if (\$lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: \$(\$lostKeys -join ', ')" }

    Backup-File -FilePath \$settingsFile
    \$json = \$settings | ConvertTo-Json -Depth 10
    \$resolvedSettings = \$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(\$settingsFile)
    [System.IO.File]::WriteAllText(\$resolvedSettings, \$json, [System.Text.UTF8Encoding]::new(\$false))

    # Post-write validation
    try {
        \$vContent = [System.IO.File]::ReadAllText(\$resolvedSettings)
        \$vParsed = \$vContent | ConvertFrom-Json
        \$requiredKeys = @("hooks", "autoMemoryEnabled", "alwaysThinkingEnabled")
        foreach (\$k in \$requiredKeys) {
            if (-not (\$vParsed.PSObject.Properties.Name -contains \$k)) {
                LogError "Validation failed: \$settingsFile missing required field '\$k'"
            }
        }
    } catch {
        LogError "Validation failed: \$settingsFile is not valid JSON -- \$_"
    }

    LogOk "Settings deployed to \$settingsFile"
    Log "  Hook: \$hookCmd"
    Log "  autoMemoryEnabled: \$autoMemory"
    Log "  alwaysThinkingEnabled: \$alwaysThinking"
}
BLOCK_INTERP
    ps1_exit_footer
} > "$DEPLOY_DIR/setup-user-hooks.ps1"

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
