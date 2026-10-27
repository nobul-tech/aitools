#!/usr/bin/env bash
# aitools-install.sh — Install aitools command + configure environment
# Run once for first-time setup, or re-run via `aitools` to stay current.
#
# Installs/updates gh CLI, configures repos directory, auto-detects Google
# Drive mounts, writes ~/.aitools/config.json, installs the
# aitools command to ~/.local/bin/, adds shell integration, deploys the
# harness to ~/.aitools (deploy-harness.sh, Step 8b), and deploys
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

OS_NAME="$(uname -s)"

if $DRY_RUN; then export AITOOLS_DRY_RUN=1; fi

# --- BEGIN install log helpers (tests/profile/test-config.sh extracts this block) ---
# deploy.jsonl records and the child relay come from aitools-lib (jsonl_record,
# run_child_relayed: one copy for the installers, user init and deploy-harness;
# audit A-1). A record that cannot be written is one warning and the run goes on
# (A-16). This block keeps only the installer's own Step 3 / Step 5 helpers.

# jsonl_write TS SCRIPT LEVEL MSG -- the lib's jsonl_record under the installer's
# former name (tests/profile/test-config.sh calls it; no logic of its own)
jsonl_write() { jsonl_record "$@"; }

# run_config_writer WRITER ARGS... -- Step 5: run setup-user-config.sh through the
# lib relay. The writer logs and writes its own summary rows; the relay shows and
# mirrors its lines to deploy.jsonl, counts its warnings, logs one error for a
# failed writer and writes "ERROR|aitools config|script failed (exit N)" when the
# writer died before a row of its own (A-1, A-18). Returns 0 (the relay counted
# a failure).
run_config_writer() {
    local writer="$1"; shift
    if ! run_child_relayed --summary-tool "aitools config" "Step 5: setup-user-config.sh" "${BASH:-bash}" "$writer" "$@"; then
        log_detail "Step 5: config writer step failed (exit $AITLIB_CHILD_RC; logged and counted by the relay)"
    fi
    return 0
}

# absolute_repos_path PATH -- print PATH as an absolute path. A relative PATH must
# already exist (Step 3 creates it first, relative to the current directory, as the
# pre-#79 installer did); it is resolved with cd + pwd, which normalises ./, ../ and
# a run from / (like GetFullPath in the .ps1). Returns 1 when it cannot be entered.
# The config writer accepts absolute paths only.
absolute_repos_path() {
    case "$1" in
        /*) printf '%s' "$1" ;;
        *)  (CDPATH='' cd -- "$1" && pwd) ;;
    esac
}

# resolve_repos_dir PATH -- Step 3: create PATH and make it absolute (relative to
# the current directory). Sets REPOS_PATH. Returns 1 after log_error and one ERROR
# row "aitools config" when PATH cannot be created or resolved; the caller then
# skips Step 5, whose writer accepts absolute paths only (audit A-17).
resolve_repos_dir() {
    local p="$1" abs="" mkerr=""
    REPOS_PATH="$p"
    if ! mkerr=$(mkdir -p "$p" 2>&1); then
        log_detail "Repos directory '$p': ${mkerr:-mkdir failed}"
        log_error "Repos directory '$p' could not be created -- config.json will not be written"
        write_summary ERROR "aitools config" "repos dir not created"
        return 1
    fi
    case "$p" in
        /*) ;;
        *)
            if abs=$(absolute_repos_path "$p") && [ -n "$abs" ]; then
                log "Repos path '$p' is relative -- using $abs (relative to the current directory)"
                REPOS_PATH="$abs"
            else
                log_error "Repos path '$p' is relative and could not be resolved -- config.json will not be written"
                write_summary ERROR "aitools config" "repos path not absolute"
                return 1
            fi ;;
    esac
    return 0
}
# --- END install log helpers ---

# --- BEGIN install log override (tests/profile/test-install.sh extracts this block) ---
# One run id for this installer's deploy.jsonl records and every relayed child's
# (the lib's jsonl_record reads AITOOLS_RUN_ID; a child that relays its own children
# passes it on). 6 random bytes as hex, the lib's form; when that fails it stays
# unset and the lib picks one id for this process. Exported to children only (a
# bash process cannot change its caller's environment).
if [ -z "${AITOOLS_RUN_ID:-}" ]; then
    if _run_id="$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')" && [ -n "$_run_id" ]; then
        export AITOOLS_RUN_ID="$_run_id"
    else
        log_detail "deploy.jsonl: no random run id (od failed) -- the lib picks one for this process"
    fi
fi

# Override: JSONL dual-format (human-readable + structured JSON). The record goes
# through the lib's jsonl_record: escaped, one run_id for the installer's own
# lines and its relayed children's, and an unwritable deploy.jsonl is one warning,
# not the end of the installer under set -e (A-16).
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] [%s] [%s] %s\n' "$ts" "$SCRIPT_NAME" "$level" "$1" | tee -a "$LOG_FILE"
    jsonl_record "$ts" "$SCRIPT_NAME" "$level" "$1"
}
log_ok()    { log "$1" "ok"; }
log_error() { log "$1" "error"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "$1" "warn"; WARNINGS=$((WARNINGS + 1)); }
# --- END install log override ---

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

# run_harness_step SCRIPT -- Step 8b: run deploy-harness.sh (SCRIPT) relayed
# (aitools-lib run_child_relayed: its stdout goes to the console and deploy.jsonl;
# stdin stays the terminal, the review menu reads /dev/tty). Checked with bash -n
# first: bash exits 2 on a syntax error, which would read as an abort. Returns 2 when
# deploy-harness exited 2 (the user chose [x]abort, D-TS13; the caller stops the
# install), else 0. Exit 1 (errors): the lib logged the error; this adds the ERROR
# row and the install continues. Parity: Invoke-HarnessStep in aitools-install.ps1.
run_harness_step() {
    local harness="$1"
    local syntax_out syntax_rc=0 syntax_line
    if [ ! -f "$harness" ]; then
        log_warn "deploy-harness.sh not found -- skipping (MDM deploy)"
        write_summary WARN "harness files" "deploy-harness.sh not found"
        return 0
    fi
    syntax_out=$(bash -n "$harness" 2>&1) || syntax_rc=$?
    if [ "$syntax_rc" -ne 0 ]; then
        while IFS= read -r syntax_line; do
            if [ -n "$syntax_line" ]; then log_detail "deploy-harness.sh syntax: $syntax_line"; fi
        done <<< "$syntax_out"
        log_error "deploy-harness.sh has syntax errors -- skipped (see $(display_path "$LOG_FILE"))"
        write_summary ERROR "harness files" "syntax errors -- skipped"
        return 0
    fi
    if run_child_relayed "Step 8b: deploy-harness.sh" "${BASH:-bash}" "$harness"; then
        return 0
    fi
    if [ "$AITLIB_CHILD_RC" -eq 2 ]; then
        log "Step 8b: aborted by user at a review menu -- install stopped (exit 2)"
        write_summary WARN "harness files" "aborted by user"
        return 2
    fi
    # Exit 0 with error lines: the lib logged them and returned 1
    if [ "$AITLIB_CHILD_RC" -eq 0 ]; then
        write_summary ERROR "harness files" "errors logged (exit 0)"
    else
        write_summary ERROR "harness files" "script failed (exit $AITLIB_CHILD_RC)"
    fi
    return 0
}

# display_path is provided by aitools-lib.sh

# Interactive mode (same rule as the lib's review prompts): a terminal on stdin and
# no --force / AITOOLS_FORCE. Otherwise every prompt takes its default.
INSTALL_INTERACTIVE=false
if [ "${AITOOLS_FORCE:-}" != "1" ] && tty_interactive; then
    INSTALL_INTERACTIVE=true
fi

$DRY_RUN && log "[DRY RUN] Preview mode -- no files will be written"

# --- Post-write JSON validation ---
# Validates a JSON config file after writing: checks non-empty, valid JSON,
# required keys present, and no double-slash paths (excluding protocol prefixes).
# No caller here since config.json moved to setup-user-config.sh (M3 B3b). It stays
# in this installer (M3 B2 kept it out of aitools-lib) because config-file-safety.md
# cites it as the reference example for validate_json_config.
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

REPOS_OK=true
if resolve_repos_dir "$REPOS_PATH"; then
    log_ok "Repos directory: $REPOS_PATH"
else
    REPOS_OK=false   # logged with its ERROR row; Step 5 is skipped
fi

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

# config.json has one writer: setup-user-config.sh (bootstrap keys from this
# installer + values derived from profile.json; no node needed, P-Q3).
CONFIG_WRITER="$SCRIPT_DIR/setup-user-config.sh"
if ! $REPOS_OK; then
    log "Step 5: skipped -- the repos path is unusable (see the error above); config.json not written"
elif [ ! -f "$CONFIG_WRITER" ]; then
    log_error "Failed: setup-user-config.sh not found next to the installer -- config.json not written"
    write_summary ERROR "aitools config" "writer missing"
else
    writer_args=(--repos-path "$REPOS_PATH_NATIVE" --repo-path "$AITOOLS_NATIVE" --drives-json "$DRIVES_JSON")
    if $DRY_RUN; then writer_args+=(--dry-run); fi
    run_config_writer "$CONFIG_WRITER" "${writer_args[@]}"
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

# The harness Python CLIs (~/.aitools/bin) are deployed by deploy-harness (Step 8b).

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
# 8b. Deployed harness (~/.aitools) -- deploy-harness.sh
# ============================================================
# After Node (Step 8). deploy-harness fills ~/.aitools/{reference,registries,hooks,
# rules,skills,bin} (bin was this installer's own step before) and re-derives
# config.json through setup-user-config.sh (Step 5 wrote the bootstrap keys it needs).
log "Step 8b: Deployed harness"

harness_rc=0
run_harness_step "$SCRIPT_DIR/deploy-harness.sh" || harness_rc=$?
if [ "$harness_rc" -eq 2 ]; then
    if [ -z "${AITOOLS_SUPPRESS_SUMMARY_DISPLAY:-}" ]; then show_summary; fi
    exit 2
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
# 20b. Google Chrome (managed in the Claude Code web environment only, D-CHR1)
# ============================================================
# Before Step 21 so setup-user-mcp writes the chrome-devtools args for a browser that
# exists. The script decides by environment and reports "n/a (<environment>)" elsewhere
# (D-ENV8), so this step has no environment branch.
log "Step 20b: Google Chrome"

chrome_script="$SCRIPT_DIR/setup-google-chrome.sh"
if [ -f "$chrome_script" ]; then
    validate_and_run "$chrome_script"
else
    log_warn "setup-google-chrome.sh not found -- skipping (MDM deploy)"
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
