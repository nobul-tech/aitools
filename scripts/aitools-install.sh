#!/usr/bin/env bash
# aitools-install.sh — Install aitools command + configure environment
# Run once for first-time setup, or re-run via `aitools` to stay current.
#
# Installs/updates gh CLI, configures repos directory, auto-detects Google
# Drive mounts, writes ~/.aitools/config.json, installs the
# aitools command to ~/.local/bin/, adds shell integration, and deploys
# all configuration scripts.

set -euo pipefail

# --- Defaults ---
REPOS_PATH=""
SKIP_DRIVE_DETECTION=false
SKIP_GH_AUTH=false
DRY_RUN=false
SHOW_HELP=false

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repos-path)
            REPOS_PATH="$2"
            shift 2
            ;;
        --skip-drive-detection)
            SKIP_DRIVE_DETECTION=true
            shift
            ;;
        --skip-gh-auth)
            SKIP_GH_AUTH=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            SHOW_HELP=true
            shift
            ;;
    esac
done
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true

if $SHOW_HELP; then
    cat <<'USAGE'
aitools-install.sh — Install aitools command + configure environment

Usage: bash scripts/aitools-install.sh [OPTIONS]

Options:
  --repos-path PATH         Set repos directory without prompting (default: ~/repos)
  --skip-drive-detection    Skip Google Drive auto-detection
  --skip-gh-auth            Skip gh auth login
  --dry-run                 Preview mode -- show what would change without writing
  --help, -h                Show this help

Interactive behavior:
  When stdin is a terminal, prompts for repos path and drive confirmation.
  When piped or run non-interactively, uses defaults and flags.
  When config.json already exists, uses saved values without prompting.
USAGE
    exit 0
fi

# --- Windows forwarding (safety net for direct invocation) ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        ps1_installer="$(dirname "$0")/aitools-install.ps1"
        if [ ! -f "$ps1_installer" ]; then
            echo "error: aitools-install.ps1 not found" >&2
            exit 1
        fi
        ps_args=()
        if $SKIP_GH_AUTH; then ps_args+=("-SkipGhAuth"); fi
        if $SKIP_DRIVE_DETECTION; then ps_args+=("-SkipDriveDetection"); fi
        if $DRY_RUN; then ps_args+=("-DryRun"); fi
        if [ -n "$REPOS_PATH" ]; then
            ps_args+=("-ReposPath" "$(cygpath -w "$REPOS_PATH")")
        fi
        echo "Windows detected -- forwarding to PowerShell installer..."
        # Bootstrap: if pwsh not installed, use powershell.exe to install it via winget
        if ! command -v pwsh &>/dev/null; then
            echo "pwsh (PowerShell 7) not found -- installing via winget..."
            powershell.exe -NoProfile -Command 'winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements'
            # Refresh PATH hash so pwsh is found
            hash -r
            if ! command -v pwsh &>/dev/null; then
                echo "error: pwsh install succeeded but not in PATH. Restart terminal and re-run." >&2
                exit 1
            fi
        fi
        pwsh -NoProfile -ExecutionPolicy Bypass \
            -File "$(cygpath -w "$ps1_installer")" "${ps_args[@]}"
        exit $?
        ;;
esac

# --- Shared library ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "aitools-install"

# JSONL logging (extends standard pattern with structured JSON)
LOG_JSONL="$LOG_DIR/deploy.jsonl"
RUN_ID="${AITOOLS_RUN_ID:-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
HOST_NAME="$(hostname -s 2>/dev/null || hostname)"
OS_NAME="$(uname -s)"

if $DRY_RUN; then export AITOOLS_DRY_RUN=1; fi

# Override: JSONL dual-format (human-readable + structured JSON)
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] [%s] [%s] %s\n' "$ts" "$SCRIPT_NAME" "$level" "$1" | tee -a "$LOG_FILE"
    printf '{"ts":"%s","host":"%s","os":"%s","script":"%s","run_id":"%s","level":"%s","msg":"%s"}\n' \
        "$ts" "$HOST_NAME" "$OS_NAME" "$SCRIPT_NAME" "$RUN_ID" "$level" "$1" >> "$LOG_JSONL"
}
log_ok()    { log "$1" "ok"; }
log_error() { log "$1" "error"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "$1" "warn"; WARNINGS=$((WARNINGS + 1)); }

# --- Summary file init (if not already set by parent aitools invocation) ---
if [ -z "${AITOOLS_SUMMARY_FILE:-}" ]; then
    AITOOLS_SUMMARY_FILE="$HOME/.aitools/run-summary.txt"
    rm -f "$AITOOLS_SUMMARY_FILE"
    touch "$AITOOLS_SUMMARY_FILE"
    export AITOOLS_SUMMARY_FILE
fi

# --- Script validation helper ---
# Validates bash syntax with bash -n before executing. Skips with warning on errors.
validate_and_run() {
    local script="$1"
    local name; name=$(basename "$script")
    if ! bash -n "$script" 2>/dev/null; then
        log_warn "$name has syntax errors -- skipping"
        return 0
    fi
    bash "$script" || log_error "$name failed"
}

# display_path is provided by aitools-lib.sh

# --- Post-write JSON validation ---
# Validates a JSON config file after writing: checks non-empty, valid JSON,
# required keys present, and no double-slash paths (excluding protocol prefixes).
$DRY_RUN && log "[DRY RUN] Preview mode -- no files will be written"

validate_json_config() {
    local file="$1"; shift
    local required_keys=("$@")
    if [ ! -s "$file" ]; then
        log_error "Validation failed: $file is empty or missing"
        return 1
    fi
    local validator=""
    if command -v python3 &>/dev/null; then validator="python3"
    elif command -v node &>/dev/null; then validator="node"
    fi
    if [ -z "$validator" ]; then
        log_warn "Cannot validate JSON (no python3 or node)"
        return 0
    fi
    # Valid JSON check
    if [ "$validator" = "python3" ]; then
        if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" 2>/dev/null; then
            log_error "Validation failed: $file is not valid JSON"
            return 1
        fi
    else
        if ! node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$file" 2>/dev/null; then
            log_error "Validation failed: $file is not valid JSON"
            return 1
        fi
    fi
    # Required fields check
    for key in "${required_keys[@]}"; do
        if ! grep -q "\"$key\"" "$file"; then
            log_error "Validation failed: $file missing required field '$key'"
            return 1
        fi
    done
    # Double-slash path check (skip protocol prefixes like https://)
    if [ "$validator" = "python3" ]; then
        local ds_result
        ds_result=$(python3 -c "
import json,sys
def check(o,p=''):
    if isinstance(o,str):
        s=o.replace('https://','').replace('http://','')
        if '//' in s: print(f'double-slash at {p}: {o}',file=sys.stderr); sys.exit(1)
    elif isinstance(o,dict):
        for k,v in o.items(): check(v,f'{p}.{k}')
    elif isinstance(o,list):
        for i,v in enumerate(o): check(v,f'{p}[{i}]')
check(json.load(open(sys.argv[1])))
" "$file" 2>&1)
        if [ $? -ne 0 ]; then
            log_error "Validation failed: $file contains double-slash in path value"
            return 1
        fi
    fi
    return 0
}

# --- Config helpers (pure-bash, no python3 dependency) ---

# Read a top-level string value from a JSON config file.
# Handles UTF-8 BOM (PowerShell 5.x writes one) and JSON-escaped backslashes.
read_config_key() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    local val
    val=$(tr -d '\357\273\277' < "$file" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | cut -d'"' -f4 || true)
    [ -n "$val" ] || return 1
    # Unescape JSON backslashes: \\ -> \
    printf '%b' "$val"
}

# Read the raw googleDrives JSON array from a config file.
# Returns "[]" if not found or empty.
read_config_drives() {
    local file="$1"
    [ -f "$file" ] || { echo "[]"; return; }
    local result
    result=$(tr -d '\357\273\277\r' < "$file" \
        | sed -n '/"googleDrives"/,/^[[:space:]]*\]/p' \
        | sed '1s/.*\[/[/' \
        | sed '$s/],*/]/')
    if [ -z "$result" ] || [ "$result" = "[]" ]; then
        echo "[]"
    else
        printf '%s' "$result"
    fi
}

# --- Config file setup ---
CONFIG_DIR="$HOME/.aitools"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

# Auto-detect aitools repo path from this script's location
# SCRIPT_DIR is set at top (lib sourcing)
AITOOLS_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================
# 0. System prerequisites
# ============================================================
# Windows long path check is in aitools-install.ps1 (Step 0).
# macOS/Linux have no path length limit -- nothing to do here.

# ============================================================
# 1. Install/update gh CLI
# ============================================================
log "Step 1: gh CLI"

gh_script="$SCRIPT_DIR/setup-gh-cli.sh"
if [ -f "$gh_script" ]; then
    validate_and_run "$gh_script"
else
    log_warn "setup-gh-cli.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 2. Authenticate gh
# ============================================================
log "Step 2: gh authentication"

if $SKIP_GH_AUTH; then
    log "Skipping gh auth (--skip-gh-auth)"
elif ! command -v gh &>/dev/null; then
    log_warn "gh not installed, skipping auth"
elif gh auth status &>/dev/null; then
    log_ok "gh already authenticated"
elif [ -t 0 ]; then
    log "Not authenticated. Starting gh auth login..."
    gh auth login || log_error "gh auth login failed"
else
    log_warn "Not authenticated and not interactive — skipping gh auth (use --skip-gh-auth to suppress)"
fi

# ============================================================
# 3. Configure repos directory
# ============================================================
log "Step 3: repos directory"

if [ -n "$REPOS_PATH" ]; then
    # Flag provided — use it
    REPOS_PATH="${REPOS_PATH/#\~/$HOME}"
    log "Using repos path from flag: $REPOS_PATH"
elif REPOS_PATH=$(read_config_key "$CONFIG_FILE" "reposPath"); then
    log "Using repos path from config: $REPOS_PATH"
fi
if [ -z "$REPOS_PATH" ]; then
    if [ -t 0 ]; then
        # Interactive — prompt
        printf 'Where should new repos live? [~/repos]: '
        read -r user_path
        if [ -n "$user_path" ]; then
            REPOS_PATH="${user_path/#\~/$HOME}"
        else
            REPOS_PATH="$HOME/repos"
        fi
    else
        # Non-interactive — use default
        REPOS_PATH="$HOME/repos"
    fi
fi

mkdir -p "$REPOS_PATH"
log_ok "Repos directory: $REPOS_PATH"

# ============================================================
# 4. Detect Google Drive mounts
# ============================================================
log "Step 4: Google Drive detection"

DRIVES_JSON="[]"

if $SKIP_DRIVE_DETECTION; then
    log "Skipping drive detection (--skip-drive-detection)"
else
    DRIVE_LIST=""

    if [ "$OS_NAME" = "Darwin" ]; then
        # macOS: scan ~/Library/CloudStorage/GoogleDrive-*/
        for dir in "$HOME/Library/CloudStorage"/GoogleDrive-*/; do
            [ -d "$dir" ] || continue
            account=$(basename "$dir" | sed 's/^GoogleDrive-//')
            my_drive="${dir%/}/My Drive"
            if [ -d "$my_drive" ]; then
                DRIVE_LIST="${DRIVE_LIST}${account}|${my_drive}\n"
                log_ok "Detected Google Drive: $account → $my_drive"
            fi
        done
    else
        # Linux/WSL: check if any Google Drive mounts exist via known paths
        # (Google Drive for Desktop on Linux is rare — mostly a no-op)
        log "Non-macOS detected — Google Drive auto-detection not supported on this platform via bash"
        log "Use aitools-install.ps1 on Windows for drive detection"
    fi

    # Build JSON array
    if [ -n "$DRIVE_LIST" ]; then
        DRIVES_JSON="["
        first=true
        while IFS='|' read -r account path; do
            [ -z "$account" ] && continue
            if $first; then
                first=false
            else
                DRIVES_JSON="${DRIVES_JSON},"
            fi
            # Escape backslashes for JSON
            escaped_path=$(printf '%s' "$path" | sed 's/\\/\\\\/g')
            DRIVES_JSON="${DRIVES_JSON}{\"path\":\"${escaped_path}\",\"account\":\"${account}\",\"label\":\"\"}"
        done < <(printf "$DRIVE_LIST")
        DRIVES_JSON="${DRIVES_JSON}]"
    fi
fi

# ============================================================
# 5. Write config file
# ============================================================
log "Step 5: Writing config"

# Convert MSYS paths to native Windows paths for config.json
if command -v cygpath &>/dev/null; then
    REPOS_PATH_NATIVE=$(cygpath -w "$REPOS_PATH")
    AITOOLS_NATIVE=$(cygpath -w "$AITOOLS_REPO")
else
    REPOS_PATH_NATIVE="$REPOS_PATH"
    AITOOLS_NATIVE="$AITOOLS_REPO"
fi

# Escape backslashes for JSON
REPOS_PATH_JSON=$(printf '%s' "$REPOS_PATH_NATIVE" | sed 's/\\/\\\\/g')
AITOOLS_JSON=$(printf '%s' "$AITOOLS_NATIVE" | sed 's/\\/\\\\/g')

# If config already exists, preserve fields we don't manage
USER_REPO_LINE=""
MACHINE_ALIAS_LINE=""
if [ -f "$CONFIG_FILE" ]; then
    # Preserve googleDrives if we didn't detect any
    if [ "$DRIVES_JSON" = "[]" ]; then
        EXISTING_DRIVES=$(read_config_drives "$CONFIG_FILE")
        if [ "$EXISTING_DRIVES" != "[]" ]; then
            DRIVES_JSON="$EXISTING_DRIVES"
            log "Preserved existing Google Drive entries from config"
        fi
    fi
    # Preserve userRepoPath (set by 'aitools user init')
    EXISTING_USER_REPO=$(read_config_key "$CONFIG_FILE" "userRepoPath")
    if [ -n "$EXISTING_USER_REPO" ]; then
        # printf -v preserves trailing \n ($() command substitution strips it)
        printf -v USER_REPO_LINE '  "userRepoPath": "%s",\n' "$EXISTING_USER_REPO"
    fi
    # Preserve machineAlias (set by 'aitools user init')
    EXISTING_MACHINE_ALIAS=$(read_config_key "$CONFIG_FILE" "machineAlias")
    if [ -n "$EXISTING_MACHINE_ALIAS" ]; then
        printf -v MACHINE_ALIAS_LINE '  "machineAlias": "%s",\n' "$EXISTING_MACHINE_ALIAS"
    fi
fi

cat > "$CONFIG_FILE" << CONFIGEOF
{
  "version": 2,
  "reposPath": "$REPOS_PATH_JSON",
  "repoPath": "$AITOOLS_JSON",
${USER_REPO_LINE}${MACHINE_ALIAS_LINE}  "googleDrives": $DRIVES_JSON
}
CONFIGEOF

log_ok "Config written to $(display_path "$CONFIG_FILE")"
validate_json_config "$CONFIG_FILE" version reposPath repoPath || true

# ============================================================
# 6. Install aitools command
# ============================================================
log "Step 6: Install aitools command"

AITOOLS_SRC="$SCRIPT_DIR/aitools"
AITOOLS_DST="$HOME/.local/bin/aitools"
mkdir -p "$HOME/.local/bin"
if [ -f "$AITOOLS_SRC" ]; then
    cp "$AITOOLS_SRC" "$AITOOLS_DST"
    chmod +x "$AITOOLS_DST"
    log_ok "Installed aitools to $(display_path "$AITOOLS_DST")"
else
    log_warn "aitools source not found at $(display_path "$AITOOLS_SRC") (MDM deploy — skipping)"
fi

# ============================================================
# 7. Shell integration
# ============================================================
log "Step 7: Shell integration"

ALIASES_PATH="$SCRIPT_DIR/../shared/shell/aliases.sh"
if [ -f "$ALIASES_PATH" ]; then
    ALIASES_ABS=$(cd "$(dirname "$ALIASES_PATH")" && pwd)/$(basename "$ALIASES_PATH")
    OLD_MARKER="# ai-tooling shell integration"
    MARKER="# aitools shell integration"
    for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
        # Only add to files that exist OR create .bashrc as fallback
        if [ "$rcfile" = "$HOME/.bashrc" ] || [ -f "$rcfile" ]; then
            # Remove old marker block if present
            if grep -qF "$OLD_MARKER" "$rcfile" 2>/dev/null; then
                perl -i -0777 -pe 's/\n?# ai-tooling shell integration\nsource "[^\n]*"\n?//g' "$rcfile"
                log "Removed old shell integration marker from $(display_path "$rcfile")"
            fi
            if ! grep -qF "$MARKER" "$rcfile" 2>/dev/null; then
                printf '\n%s\nsource "%s"\n' "$MARKER" "$ALIASES_ABS" >> "$rcfile"
                log_ok "Added shell integration to $(display_path "$rcfile")"
            else
                log_ok "Shell integration already in $(display_path "$rcfile")"
            fi
        fi
    done
else
    log_warn "aliases.sh not found — skipping shell integration (MDM deploy)"
fi

# ============================================================
# 8. Node.js
# ============================================================
log "Step 8: Node.js"

if command -v node &>/dev/null; then
    log_ok "Node.js already installed ($(node --version))"
    write_summary OK "node.js" "$(node --version)"
else
    case "$OS_NAME" in
        Darwin)
            if command -v brew &>/dev/null; then
                log "Installing Node.js via Homebrew..."
                if ! brew install node@22 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "brew install node@22 failed"
                    write_summary ERROR "node.js" "brew install failed"
                fi
                if command -v node &>/dev/null; then
                    log_ok "Node.js installed ($(node --version))"
                    write_summary OK "node.js" "$(node --version)"
                else
                    log_error "brew install completed but 'node' not found in PATH"
                    write_summary ERROR "node.js" "installed but not on PATH"
                fi
            else
                log_error "Homebrew not found. Install Node.js manually: https://nodejs.org"
                write_summary ERROR "node.js" "Homebrew not found"
            fi
            ;;
        MINGW*|MSYS*)
            log "Windows detected — install Node.js via winget (use aitools-install.ps1)"
            ;;
        *)
            log_warn "Install Node.js manually: https://nodejs.org"
            write_summary WARN "node.js" "install manually (https://nodejs.org)"
            ;;
    esac
fi

# ============================================================
# 9. Claude Code CLI
# ============================================================
# Source: https://code.claude.com/docs/en/setup
log "Step 9: Claude Code CLI"

if command -v claude &>/dev/null; then
    log_ok "Claude Code already installed ($(claude --version 2>/dev/null | head -1))"
    write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
    log "Running claude update..."
    UPDATE_OUTPUT=$(claude update 2>&1) || true
    if printf '%s\n' "$UPDATE_OUTPUT" | grep -qi 'already.*up.to.date\|no update'; then
        log_ok "Already up to date"
    else
        printf '%s\n' "$UPDATE_OUTPUT" | while IFS= read -r line; do log "$line"; done
        if printf '%s\n' "$UPDATE_OUTPUT" | grep -qi 'error\|fatal'; then
            log_warn "claude update returned unexpected output (see log above)"
        fi
    fi
else
    log "Installing Claude Code CLI..."
    case "$OS_NAME" in
        MINGW*|MSYS*)
            # WinGet works from Git Bash
            if command -v winget &>/dev/null; then
                # Suppress winget progress noise; install success checked via command -v below
                winget install Anthropic.ClaudeCode --accept-package-agreements --accept-source-agreements 2>/dev/null
                if command -v claude &>/dev/null; then
                    log_ok "Claude Code installed ($(claude --version 2>/dev/null | head -1))"
                    write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
                else
                    log_warn "Claude Code installed — restart terminal to use"
                    write_summary WARN "claude code" "installed -- restart terminal to use"
                fi
            else
                log "winget not available — install manually:"
                log "  PowerShell: irm https://claude.ai/install.ps1 | iex"
            fi
            ;;
        *)
            if ! curl -fsSL https://claude.ai/install.sh | bash 2>&1 | while IFS= read -r line; do log "$line"; done; then
                log_error "Claude Code install script failed"
                write_summary ERROR "claude code" "install failed"
            fi
            if command -v claude &>/dev/null; then
                log_ok "Claude Code installed ($(claude --version 2>/dev/null | head -1))"
                write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
            else
                log_error "Claude Code install failed"
                write_summary ERROR "claude code" "install failed"
            fi
            ;;
    esac
fi

# ============================================================
# 10. Vercel CLI
# ============================================================
log "Step 10: Vercel CLI"

vercel_script="$SCRIPT_DIR/setup-vercelcli.sh"
if [ -f "$vercel_script" ]; then
    validate_and_run "$vercel_script"
else
    log_warn "setup-vercelcli.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 11. Pandoc
# ============================================================
log "Step 11: Pandoc"

pandoc_script="$SCRIPT_DIR/setup-pandoc.sh"
if [ -f "$pandoc_script" ]; then
    validate_and_run "$pandoc_script"
else
    log_warn "setup-pandoc.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 12. Rust (cargo)
# ============================================================
log "Step 12: Rust (cargo)"

rust_script="$SCRIPT_DIR/setup-rust.sh"
if [ -f "$rust_script" ]; then
    validate_and_run "$rust_script"
else
    log_warn "setup-rust.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 13. Typst
# ============================================================
log "Step 13: Typst"

typst_script="$SCRIPT_DIR/setup-typst.sh"
if [ -f "$typst_script" ]; then
    validate_and_run "$typst_script"
else
    log_warn "setup-typst.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 14. Python
# ============================================================
log "Step 14: Python"

python_script="$SCRIPT_DIR/setup-python.sh"
if [ -f "$python_script" ]; then
    validate_and_run "$python_script"
else
    log_warn "setup-python.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 15. uv
# ============================================================
log "Step 15: uv"

uv_script="$SCRIPT_DIR/setup-uv.sh"
if [ -f "$uv_script" ]; then
    validate_and_run "$uv_script"
else
    log_warn "setup-uv.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 16. Modal CLI
# ============================================================
log "Step 16: Modal CLI"

modal_script="$SCRIPT_DIR/setup-modal.sh"
if [ -f "$modal_script" ]; then
    validate_and_run "$modal_script"
else
    log_warn "setup-modal.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 17. Go
# ============================================================
log "Step 17: Go"

go_script="$SCRIPT_DIR/setup-go.sh"
if [ -f "$go_script" ]; then
    validate_and_run "$go_script"
else
    log_warn "setup-go.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 18. Datadog CLI
# ============================================================
log "Step 18: Datadog CLI"

datadog_script="$SCRIPT_DIR/setup-datadog.sh"
if [ -f "$datadog_script" ]; then
    validate_and_run "$datadog_script"
else
    log_warn "setup-datadog.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 19. Deploy configurations
# ============================================================
log "Step 19: Deploy configurations"

DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh setup-user-mcp.sh setup-cursor-ide-mcp.sh setup-user-hooks.sh"

for script in $DEPLOY_SCRIPTS; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        validate_and_run "$script_path"
    else
        log_warn "$script not found — skipping"
    fi
done

[ -z "${AITOOLS_SUPPRESS_SUMMARY_DISPLAY:-}" ] && show_summary

# --- Exit ---
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
