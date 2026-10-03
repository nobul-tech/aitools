#!/usr/bin/env bash
# aitools-install.sh — Install aitools command + configure environment
# Run once for first-time setup, or re-run via `aitools` to stay current.
#
# Installs/updates gh CLI, configures repos directory, auto-detects Google
# Drive mounts, writes ~/.aitools/config.json, installs the
# aitools command to ~/.local/bin/, adds shell integration, and deploys
# all configuration scripts.

set -euo pipefail

# --- Shared library (first, so flag errors and Windows forwarding are logged) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "aitools-install"

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
            log_warn "Unknown option: $1"
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
  When stdin is a terminal, prompts for gh login, repos path, and file reviews.
  When piped or run non-interactively, uses defaults and flags.
  AITOOLS_FORCE=1 (aitools install --force): no prompts even in a terminal;
  managed files take the source version (backups kept).
  When config.json already exists, uses saved values without prompting.
USAGE
    exit 0
fi

# --- Windows forwarding (safety net for direct invocation) ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        ps1_installer="$SCRIPT_DIR/aitools-install.ps1"
        if [ ! -f "$ps1_installer" ]; then
            log_error "aitools-install.ps1 not found"
            write_summary ERROR "aitools install" "aitools-install.ps1 missing"
            exit 1
        fi
        ps_args=()
        if $SKIP_GH_AUTH; then ps_args+=("-SkipGhAuth"); fi
        if $SKIP_DRIVE_DETECTION; then ps_args+=("-SkipDriveDetection"); fi
        if $DRY_RUN; then ps_args+=("-DryRun"); fi
        if [ -n "$REPOS_PATH" ]; then
            ps_args+=("-ReposPath" "$(cygpath -w "$REPOS_PATH")")
        fi
        log "Windows detected -- forwarding to PowerShell installer..."
        # Bootstrap: if pwsh not installed, use powershell.exe to install it via winget
        if ! command -v pwsh &>/dev/null; then
            log "pwsh (PowerShell 7) not found -- installing via winget..."
            pwsh_install_rc=0
            pwsh_install_out=$(powershell.exe -NoProfile -Command 'winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements' 2>&1) || pwsh_install_rc=$?
            while IFS= read -r line; do
                if [ -n "$line" ]; then log_detail "winget-pwsh: $line"; fi
            done <<< "$pwsh_install_out"
            # Refresh PATH hash so pwsh is found
            hash -r
            if ! command -v pwsh &>/dev/null; then
                if [ "$pwsh_install_rc" -ne 0 ]; then
                    log_error "winget install of PowerShell 7 failed (exit $pwsh_install_rc) -- see $(display_path "$LOG_FILE")"
                    write_summary ERROR "pwsh" "winget install failed (exit $pwsh_install_rc)"
                else
                    log_error "pwsh install succeeded but not in PATH. Restart terminal and re-run."
                    write_summary ERROR "pwsh" "installed but not on PATH"
                fi
                exit 1
            fi
        fi
        pwsh -NoProfile -ExecutionPolicy Bypass \
            -File "$(cygpath -w "$ps1_installer")" "${ps_args[@]}"
        exit $?
        ;;
esac

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
# Validates bash syntax with bash -n before executing. A syntax error or a failed
# script logs an error and writes an ERROR summary row; the install continues.
validate_and_run() {
    local script="$1"
    local name; name=$(basename "$script")
    local syntax_out syntax_rc=0 syntax_line
    syntax_out=$(bash -n "$script" 2>&1) || syntax_rc=$?
    if [ "$syntax_rc" -ne 0 ]; then
        while IFS= read -r syntax_line; do
            if [ -n "$syntax_line" ]; then log_detail "$name syntax: $syntax_line"; fi
        done <<< "$syntax_out"
        log_error "$name has syntax errors -- skipped (see $(display_path "$LOG_FILE"))"
        write_summary ERROR "${name%.sh}" "syntax errors -- skipped"
        return 0
    fi
    local script_rc=0
    bash "$script" || script_rc=$?
    if [ "$script_rc" -ne 0 ]; then
        log_error "$name failed (exit $script_rc)"
        write_summary ERROR "${name%.sh}" "script failed (exit $script_rc)"
    fi
}

# display_path is provided by aitools-lib.sh

# Interactive mode (same rule as the lib's review prompts): a terminal on stdin and
# no --force / AITOOLS_FORCE. Otherwise every prompt takes its default.
INSTALL_INTERACTIVE=false
if [ "${AITOOLS_FORCE:-}" != "1" ] && tty_interactive; then
    INSTALL_INTERACTIVE=true
fi

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
# macOS/Linux: ensure Homebrew is on PATH so brew- and node-dependent steps work
# even when invoked non-interactively (no profile sourced). Mirrors bootstrap.sh.
if [ "$OS_NAME" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

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
elif $INSTALL_INTERACTIVE; then
    log "Not authenticated. Starting gh auth login..."
    # Interactive: gh talks to the terminal directly, so only the exit code is captured.
    gh_auth_rc=0
    gh auth login || gh_auth_rc=$?
    if [ "$gh_auth_rc" -ne 0 ]; then
        log_error "gh auth login failed (exit $gh_auth_rc)"
        write_summary ERROR "gh auth" "login failed (exit $gh_auth_rc)"
        write_summary ACTION "" "Run: gh auth login"
    fi
else
    log_warn "Not authenticated and not interactive — skipping gh auth (use --skip-gh-auth to suppress)"
    write_summary WARN "gh auth" "not authenticated"
    write_summary ACTION "" "Run: gh auth login"
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
    if $INSTALL_INTERACTIVE; then
        # Interactive — prompt (EOF-safe: read_tty_choice logs and returns empty)
        printf 'Where should new repos live? [~/repos]: '
        read_tty_choice user_path "~/repos"
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

# Escape backslashes for JSON (used only when writing a fresh file without node)
REPOS_PATH_JSON=$(printf '%s' "$REPOS_PATH_NATIVE" | sed 's/\\/\\\\/g')
AITOOLS_JSON=$(printf '%s' "$AITOOLS_NATIVE" | sed 's/\\/\\\\/g')

# Managed fields: version, reposPath, repoPath; googleDrives only when drives were
#   detected this run (otherwise the existing array is kept, or [] when absent)
# Preserved: userRepoPath, machineAlias (set by 'aitools user init') and all other keys
# Write path: merge to a temp file -> validate_json_config -> backup_file -> mv.
#   A merge or validation failure leaves the existing file untouched.
CONFIG_TMP="${CONFIG_FILE}.tmp.$$"
# read -d '' returns 1 at end of input by design; the -n check below is the result check
read -r -d '' CONFIG_MERGE_JS <<'CONFIGJS' || true
const fs = require('fs');
const [file, tmp, reposPath, repoPath, drivesJson] = process.argv.slice(1);
let raw = null;
try {
    raw = fs.readFileSync(file, "utf8");
    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);  // strip UTF-8 BOM (PowerShell 5.x writes one)
} catch (e) {
    if (e.code !== 'ENOENT') { console.log('ERROR:read ' + e.message); process.exit(2); }
}
let cfg = {};
let state = 'created';
if (raw !== null) {
    try {
        cfg = JSON.parse(raw);
        if (cfg === null || typeof cfg !== 'object' || Array.isArray(cfg)) throw new Error('top level is not an object');
        state = 'updated';
    } catch (e) {
        // Invalid JSON: rebuild from managed fields, salvaging the user-init keys by pattern
        console.log('CORRUPT:' + e.message);
        cfg = {};
        for (const k of ['userRepoPath', 'machineAlias']) {
            const m = raw.match(new RegExp('"' + k + '"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"'));
            if (m) { cfg[k] = JSON.parse('"' + m[1] + '"'); console.log('RECOVERED:' + k); }
        }
        state = 'recovered';
    }
}
let drives;
try { drives = JSON.parse(drivesJson); } catch (e) { console.log('ERROR:drives ' + e.message); process.exit(3); }
const next = Object.assign({}, cfg, { version: 2, reposPath: reposPath, repoPath: repoPath });
if (Array.isArray(drives) && drives.length > 0) next.googleDrives = drives;
else if (!Array.isArray(next.googleDrives)) next.googleDrives = [];
for (const k of ['version', 'reposPath', 'repoPath', 'googleDrives']) {
    const a = JSON.stringify(cfg[k]), b = JSON.stringify(next[k]);
    if (a !== b) console.log('CHANGED:' + k + ': ' + (a === undefined ? '(unset)' : a) + ' -> ' + b);
}
if (state === 'updated' && JSON.stringify(next) === JSON.stringify(cfg)) { console.log('RESULT:unchanged'); process.exit(0); }
fs.writeFileSync(tmp, JSON.stringify(next, null, 2) + '\n');
const v = JSON.parse(fs.readFileSync(tmp, 'utf8'));
const missing = ['version', 'reposPath', 'repoPath'].filter(k => !(k in v));
if (missing.length) { console.log('ERROR:validation missing ' + missing.join(', ')); process.exit(4); }
console.log('RESULT:' + state);
CONFIGJS

if $DRY_RUN; then
    log "[DRY RUN] Would merge version/reposPath/repoPath/googleDrives into $(display_path "$CONFIG_FILE")"
elif [ -z "$CONFIG_MERGE_JS" ]; then
    log_error "Failed: $(display_path "$CONFIG_FILE"): internal error -- config merge program is empty"
    write_summary ERROR "aitools config" "merge program missing"
elif command -v node >/dev/null 2>&1; then
    MERGE_EC=0
    # || records node's exit status so set -e does not abort before it is reported below
    MERGE_OUTPUT=$(node -e "$CONFIG_MERGE_JS" "$CONFIG_FILE" "$CONFIG_TMP" \
        "$REPOS_PATH_NATIVE" "$AITOOLS_NATIVE" "$DRIVES_JSON" 2>&1) || MERGE_EC=$?
    MERGE_RESULT=$(printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print $1 if /^RESULT:(\w+)/')
    if [ "$MERGE_EC" -ne 0 ] || [ -z "$MERGE_RESULT" ]; then
        rm -f "$CONFIG_TMP"
        printf '%s\n' "$MERGE_OUTPUT" | while IFS= read -r line; do
            if [ -n "$line" ]; then log_detail "$line"; fi
        done
        log_error "Failed: $(display_path "$CONFIG_FILE"): config merge failed (exit $MERGE_EC) -- existing file left untouched"
        write_summary ERROR "aitools config" "merge failed"
    elif [ "$MERGE_RESULT" = "unchanged" ]; then
        log_ok "Unchanged: $(display_path "$CONFIG_FILE")"
        write_summary OK "aitools config" "verified"
    elif ! validate_json_config "$CONFIG_TMP" version reposPath repoPath; then
        # validate_json_config already logged the specific error
        rm -f "$CONFIG_TMP"
        write_summary ERROR "aitools config" "validation failed"
    else
        backup_file "$CONFIG_FILE"
        if ! mv "$CONFIG_TMP" "$CONFIG_FILE"; then
            rm -f "$CONFIG_TMP"
            log_error "Failed: $(display_path "$CONFIG_FILE"): could not replace the config file"
            write_summary ERROR "aitools config" "write failed"
        else
            case "$MERGE_RESULT" in
                recovered)
                    CORRUPT_REASON=$(printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print $1 if /^CORRUPT:(.+)/')
                    log_warn "$(display_path "$CONFIG_FILE") was not valid JSON ($CORRUPT_REASON) -- rebuilt; the invalid copy was backed up"
                    write_summary WARN "aitools config" "rebuilt (was invalid)" ;;
                created)
                    log_ok "Created: $(display_path "$CONFIG_FILE")"
                    write_summary OK "aitools config" "created" ;;
                *)
                    log_ok "Updated: $(display_path "$CONFIG_FILE")"
                    write_summary OK "aitools config" "updated" ;;
            esac
            # Changed keys: full old -> new in the log, key names as DETAIL lines (after the parent entry)
            printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print "$1\n" if /^CHANGED:(.+)/' | while IFS= read -r change; do
                log "  $change"
                write_summary DETAIL "aitools config" "${change%%:*} updated"
            done
        fi
    fi
elif [ ! -f "$CONFIG_FILE" ]; then
    # Fresh machine without node (node arrives in Step 8): nothing to preserve, so
    # writing just the managed fields is safe.
    if printf '{\n  "version": 2,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "googleDrives": %s\n}\n' \
            "$REPOS_PATH_JSON" "$AITOOLS_JSON" "$DRIVES_JSON" > "$CONFIG_TMP" \
        && validate_json_config "$CONFIG_TMP" version reposPath repoPath \
        && mv "$CONFIG_TMP" "$CONFIG_FILE"; then
        log_ok "Created: $(display_path "$CONFIG_FILE")"
        write_summary OK "aitools config" "created"
    else
        rm -f "$CONFIG_TMP"
        log_error "Failed: $(display_path "$CONFIG_FILE"): could not write the initial config"
        write_summary ERROR "aitools config" "write failed"
    fi
else
    log_warn "node not found -- $(display_path "$CONFIG_FILE") left unchanged (read-then-merge needs node, installed in Step 8)"
    write_summary WARN "aitools config" "not updated (no node)"
fi


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

# Honest harness (hh): status + aitools
HH_SRC="$SCRIPT_DIR/hh.sh"
HH_DST="$HOME/.local/bin/hh"
if [ -f "$HH_SRC" ]; then
    cp "$HH_SRC" "$HH_DST"
    chmod +x "$HH_DST"
    log_ok "Installed hh to $(display_path "$HH_DST")"
else
    log_warn "hh.sh not found — skipping"
fi

# Harness Python CLIs -> ~/.aitools/bin (deployed copy, called by hooks via
# absolute path so every project's hooks resolve them — not run from the repo).
# These are sole-owned generated artifacts (the user never edits the deployed
# copy), so per config-file-safety.md we back up + diff-log + overwrite, with
# NO interactive review. deploy_managed_file's prompt is for user-customizable
# files only.
AITOOLS_BIN="$HOME/.aitools/bin"
mkdir -p "$AITOOLS_BIN"
_hbin_deployed=0
for _hcli in harness-db.py read-session.py read-session-full.py; do
    _src="$SCRIPT_DIR/$_hcli"
    _dst="$AITOOLS_BIN/$_hcli"
    if [ ! -f "$_src" ]; then
        log_warn "$_hcli not found at $(display_path "$_src") (MDM deploy — skipping)"
        continue
    fi
    if [ -f "$_dst" ] && diff -q "$_src" "$_dst" >/dev/null 2>&1; then
        continue  # identical — nothing to deploy
    fi
    if [ -f "$_dst" ]; then
        backup_file "$_dst"                                  # backup + rotate (aitools-lib)
        diff -u "$_dst" "$_src" >> "$LOG_FILE" 2>/dev/null || true  # log diff before overwrite
    fi
    cp "$_src" "$_dst"
    log_ok "Deployed $_hcli -> $(display_path "$_dst")"
    _hbin_deployed=$((_hbin_deployed + 1))
done
write_summary OK "harness bin" "$_hbin_deployed deployed to ~/.aitools/bin"

# ============================================================
# 7. Shell integration
# ============================================================
log "Step 7: Shell integration"

# Login-profile PATH ownership (managed marked block) -- must run so the harness
# resolves managed tools (uv python, cursor-agent, brew bash) deterministically.
shell_script="$SCRIPT_DIR/setup-user-shell.sh"
if [ -f "$shell_script" ]; then
    validate_and_run "$shell_script"
else
    log_warn "setup-user-shell.sh not found — skipping login-profile PATH block (MDM deploy)"
fi

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
    # Exit code decides (C-F2); every output line is logged.
    update_rc=0
    UPDATE_OUTPUT=$(claude update 2>&1) || update_rc=$?
    while IFS= read -r line; do
        if [ -n "$line" ]; then log "$line"; fi
    done <<< "$UPDATE_OUTPUT"
    if [ "$update_rc" -ne 0 ]; then
        log_warn "claude update failed (exit $update_rc) -- see $(display_path "$LOG_FILE")"
    elif printf '%s\n' "$UPDATE_OUTPUT" | grep -qi 'already.*up.to.date\|no update'; then
        log_ok "Already up to date"
    else
        log_ok "claude update finished"
    fi
else
    log "Installing Claude Code CLI..."
    # Windows never reaches here: it is forwarded to aitools-install.ps1 at the top.
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
# 14. uv  (MUST precede Python -- uv is the Python manager)
# ============================================================
log "Step 14: uv"

uv_script="$SCRIPT_DIR/setup-uv.sh"
if [ -f "$uv_script" ]; then
    validate_and_run "$uv_script"
else
    log_warn "setup-uv.sh not found — skipping (MDM deploy)"
fi

# ============================================================
# 15. Python  (via uv -- requires Step 14)
# ============================================================
log "Step 15: Python"

python_script="$SCRIPT_DIR/setup-python.sh"
if [ -f "$python_script" ]; then
    validate_and_run "$python_script"
else
    log_warn "setup-python.sh not found — skipping (MDM deploy)"
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
# 19. Perl
# ============================================================
log "Step 19: Perl"

perl_script="$SCRIPT_DIR/setup-perl.sh"
if [ -f "$perl_script" ]; then
    validate_and_run "$perl_script"
else
    log_warn "setup-perl.sh not found -- skipping (MDM deploy)"
fi

# ============================================================
# 20. Bash
# ============================================================
log "Step 20: Bash"

bash_script="$SCRIPT_DIR/setup-bash.sh"
if [ -f "$bash_script" ]; then
    validate_and_run "$bash_script"
else
    log_warn "setup-bash.sh not found -- skipping (MDM deploy)"
fi

# ============================================================
# 21. Deploy configurations
# ============================================================
log "Step 21: Deploy configurations"

DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh setup-user-mcp.sh setup-user-skills.sh setup-cursor-ide-mcp.sh setup-user-settings.sh setup-user-hooks.sh"

for script in $DEPLOY_SCRIPTS; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        validate_and_run "$script_path"
    else
        log_warn "$script not found — skipping"
    fi
done

# ============================================================
# 22. Relay → Cursor AGENTS.md (mirror; same as aitools deploy)
# ============================================================
log "Step 22: Relay → Cursor AGENTS.md mirror"

sync_py="$SCRIPT_DIR/sync-relay-to-cursor-agents.py"
if [ -f "$sync_py" ]; then
    sync_args=()
    if $DRY_RUN; then sync_args+=(--dry-run); fi
    if ! $DRY_RUN; then export AITOOLS_SYNC_DEPLOY_LOG=1; fi
    if command -v python3 >/dev/null 2>&1; then
        if python3 "$sync_py" ${sync_args[@]+"${sync_args[@]}"} >>"$LOG_FILE" 2>&1; then
            if $DRY_RUN; then log_ok "relay→AGENTS sync (dry-run)"; fi
        else
            log_warn "sync-relay-to-cursor-agents.py failed (non-fatal)"
        fi
    elif command -v py >/dev/null 2>&1; then
        if py -3 "$sync_py" ${sync_args[@]+"${sync_args[@]}"} >>"$LOG_FILE" 2>&1; then
            if $DRY_RUN; then log_ok "relay→AGENTS sync (dry-run)"; fi
        else
            log_warn "sync-relay-to-cursor-agents.py failed (non-fatal)"
        fi
    else
        log_warn "Python not found — skipping relay→AGENTS sync"
    fi
    unset AITOOLS_SYNC_DEPLOY_LOG 2>/dev/null || true
fi

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
