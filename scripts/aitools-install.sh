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
            write_error "aitools install" "cannot forward to PowerShell" "aitools-install.ps1 not found next to aitools-install.sh"
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
            # Refresh PATH hash so pwsh is found
            hash -r
            if ! command -v pwsh &>/dev/null; then
                if [ "$pwsh_install_rc" -ne 0 ]; then
                    # error_reason logs winget's output as detail lines
                    write_error "pwsh" "winget install of PowerShell 7 failed (exit $pwsh_install_rc)" "$(error_reason "$pwsh_install_out" "$pwsh_install_rc")"
                else
                    write_error "pwsh" "installed but not on PATH" "restart the terminal and re-run"
                fi
                exit 1
            fi
        fi
        pwsh -NoProfile -ExecutionPolicy Bypass \
            -File "$(cygpath -w "$ps1_installer")" "${ps_args[@]}"
        exit $?
        ;;
esac

if $DRY_RUN; then export AITOOLS_DRY_RUN=1; fi

# --- BEGIN install log helpers (tests/profile/test-config.sh extracts this block) ---
# deploy.jsonl records, the child relay and the relay sync come from aitools-lib
# (jsonl_record, run_child_relayed, run_relay_sync: one copy for the installers,
# user init and deploy-harness; audit A-1). A record that cannot be written is one
# warning and the run goes on (A-16). This block keeps only the installer's own
# Step 3 / Step 5 helpers.

# run_config_writer WRITER ARGS... -- Step 5: run setup-user-config.sh through the
# lib relay. The writer logs and records its own warnings and errors; the relay
# shows and mirrors its lines to deploy.jsonl, counts a failed writer as one error
# of the installer and records "ERROR|aitools config|Step 5: setup-user-config.sh
# failed (exit N)|<reason>" when the writer recorded no error of its own
# (reference/logging.md 8.3; A-1, A-18). Returns 0 (the relay counted a failure).
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
# a run from / (like GetFullPath in the .ps1). Returns 1 when it cannot be entered
# (cd's message on stderr). The config writer accepts absolute paths only.
absolute_repos_path() {
    case "$1" in
        /*) printf '%s' "$1" ;;
        *)  (CDPATH='' cd -- "$1" && pwd) ;;
    esac
}

# resolve_repos_dir PATH -- Step 3: create PATH and make it absolute (relative to
# the current directory). Sets REPOS_PATH. Returns 1 after one error (write_error
# "aitools config", the reason mkdir's or cd's message) when PATH cannot be created
# or resolved; the caller then skips Step 5, whose writer accepts absolute paths
# only (audit A-17).
resolve_repos_dir() {
    local p="$1" abs="" mkerr="" mkrc=0
    REPOS_PATH="$p"
    mkerr=$(mkdir -p "$p" 2>&1) || mkrc=$?
    if [ "$mkrc" -ne 0 ]; then
        write_error "aitools config" "repos directory '$p' not created -- config.json will not be written" "$(error_reason "$mkerr" "$mkrc")"
        return 1
    fi
    case "$p" in
        /*) ;;
        *)
            # 2>&1: cd's message is the reason when the path cannot be entered
            if abs=$(absolute_repos_path "$p" 2>&1) && [ -n "$abs" ]; then
                log "Repos path '$p' is relative -- using $abs (relative to the current directory)"
                REPOS_PATH="$abs"
            else
                write_error "aitools config" "repos path '$p' not resolved -- config.json will not be written" "$(error_reason "$abs" 1)"
                return 1
            fi ;;
    esac
    return 0
}

# prompt_repos_path -- Step 3, interactive run: ask where new repos live. The
# prompt goes to the terminal (/dev/tty), never stdout, like every other prompt
# (interactive-menus.md "Console I/O"); the answer is read with read_tty_choice
# (EOF-safe: it logs a warning and returns empty). Sets REPOS_PATH to the answer
# with a leading ~ expanded, or to $HOME/repos for an empty answer or EOF.
# Parity: the Step 3 prompt in aitools-install.ps1 ([Console]::Write +
# Read-ConsoleChoice).
prompt_repos_path() {
    local user_path=""
    printf 'Where should new repos live? [~/repos]: ' > /dev/tty
    read_tty_choice user_path "~/repos"
    if [ -n "$user_path" ]; then
        REPOS_PATH="${user_path/#\~/$HOME}"
    else
        REPOS_PATH="$HOME/repos"
    fi
}
# --- END install log helpers ---

# --- BEGIN install log options (tests/profile/test-install.sh extracts this block) ---
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
# The library's jsonl option (reference/logging.md sections 3 and 8.2): every log
# line of the installer is also one deploy.jsonl record (jsonl_record: escaped, the
# run id above; an unwritable deploy.jsonl is one warning, A-16). Inside a relay
# (aitools runs this installer relayed) it writes nothing: the outer relay mirrors
# the line (8.3).
AITLIB_OPT_JSONL=true
# --- END install log options ---

# --- Run summary file (reference/logging.md 8.4, 8.5): created here only when no
# caller set one (aitools runs this installer with its own); drawn at the end only
# when this installer created it (summary_end) ---
summary_begin

# install_tool SCRIPT -- the tool name a setup script records under (the tool
# name table, reference/script-standards-detail.md), passed to the relay as
# --summary-tool so a failed child is recorded under that name. A script that
# records under several tools gets the first (A6 Q7).
install_tool() {
    case "${1%.sh}" in
        setup-gh-cli)          printf 'gh cli' ;;
        setup-user-shell)      printf 'shell' ;;
        setup-vercelcli)       printf 'vercel cli' ;;
        setup-pandoc)          printf 'pandoc' ;;
        setup-rust)            printf 'rust/cargo' ;;
        setup-typst)           printf 'typst' ;;
        setup-uv)              printf 'uv' ;;
        setup-python)          printf 'python' ;;
        setup-pywinpty)        printf 'pywinpty' ;;
        setup-modal)           printf 'modal cli' ;;
        setup-go)              printf 'go' ;;
        setup-datadog)         printf 'datadog cli' ;;
        setup-perl)            printf 'perl' ;;
        setup-bash)            printf 'bash' ;;
        setup-google-chrome)   printf 'google chrome' ;;
        setup-user-claude)     printf 'claude.md' ;;
        setup-user-cursor)     printf 'cursor cli' ;;
        setup-user-mcp)        printf 'claude mcp' ;;
        setup-user-skills)     printf 'skills' ;;
        setup-cursor-ide-mcp)  printf 'cursor ide mcp' ;;
        setup-user-settings)   printf 'claude settings' ;;
        setup-user-hooks)      printf 'claude hooks' ;;
        deploy-harness)        printf 'harness files' ;;
        *)                     printf '%s' "${1%.sh}" ;;
    esac
}

# --- Script validation helper ---
# validate_and_run STEP SCRIPT -- run setup SCRIPT as installer step STEP ("Step
# 11"). bash -n first (a syntax error would exit 2, which reads as an abort): a
# syntax error is one error under the script's tool and the script is skipped.
# Then the script runs relayed (run_child_relayed --summary-tool <tool>, label
# "<STEP>: <script>"): its lines reach the console and deploy.jsonl, and a failed
# child is one error of the installer, recorded by the relay only when the child
# recorded none (reference/logging.md 8.3). The install continues either way.
validate_and_run() {
    local step="$1" script="$2" name tool syntax_out syntax_rc=0
    name=$(basename "$script")
    tool=$(install_tool "$name")
    syntax_out=$(bash -n "$script" 2>&1) || syntax_rc=$?
    if [ "$syntax_rc" -ne 0 ]; then
        write_error "$tool" "$name syntax check failed -- skipped" "$(error_reason "$syntax_out" "$syntax_rc")"
        return 0
    fi
    if ! run_child_relayed --summary-tool "$tool" "$step: $name" "${BASH:-bash}" "$script"; then
        log_detail "$step: $name failed (exit $AITLIB_CHILD_RC; logged and counted by the relay)"
    fi
    return 0
}

# run_harness_step SCRIPT [ARGS...] -- Step 8b: run deploy-harness.sh (SCRIPT) with
# ARGS (the caller passes --skip-config when Step 5 ran the config writer) relayed
# (aitools-lib run_child_relayed --summary-tool "harness files" --abort-warn: its
# stdout goes to the console and deploy.jsonl; stdin stays the terminal, the review
# menu reads /dev/tty). Checked with bash -n first: bash exits 2 on a syntax error,
# which would read as an abort. Returns 2 when deploy-harness exited 2 (the user
# chose [x]abort, D-TS13: the relay recorded one warning, "harness files" "aborted
# by user"; the caller stops the install), else 0. A failure is counted and, when
# deploy-harness recorded none, recorded by the relay; the install continues.
# Parity: Invoke-HarnessStep in aitools-install.ps1.
run_harness_step() {
    local harness="$1"
    shift
    local syntax_out syntax_rc=0
    if [ ! -f "$harness" ]; then
        write_warn "harness files" "deploy-harness.sh not found -- skipped (MDM deploy)"
        return 0
    fi
    syntax_out=$(bash -n "$harness" 2>&1) || syntax_rc=$?
    if [ "$syntax_rc" -ne 0 ]; then
        write_error "harness files" "deploy-harness.sh syntax check failed -- skipped" "$(error_reason "$syntax_out" "$syntax_rc")"
        return 0
    fi
    if run_child_relayed --summary-tool "harness files" --abort-warn "Step 8b: deploy-harness.sh" "${BASH:-bash}" "$harness" "$@"; then
        return 0
    fi
    if [ "$AITLIB_CHILD_RC" -eq 2 ]; then
        log "Step 8b: aborted by user at a review menu -- install stopped (exit 2)"
        return 2
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
# cites it as the reference example for validate_json_config. Each failure is one
# error (write_error, empty TOOL = this script's name: WHAT "<file> validation
# failed", REASON what is wrong, with the parser's message; reference/logging.md
# 8.2, 8.3).
validate_json_config() {
    local file="$1"; shift
    local required_keys=("$@")
    local out="" rc=0
    if [ ! -s "$file" ]; then
        write_error "" "$file validation failed" "the file is empty or missing"
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
    # Valid JSON check (the parser's message is the reason)
    if [ "$validator" = "python3" ]; then
        out=$(python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" 2>&1) || rc=$?
    else
        out=$(node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$file" 2>&1) || rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        write_error "" "$file validation failed" "not valid JSON: $(error_reason "$out" "$rc")"
        return 1
    fi
    # Required fields check
    for key in "${required_keys[@]}"; do
        if ! grep -q "\"$key\"" "$file"; then
            write_error "" "$file validation failed" "missing required field '$key'"
            return 1
        fi
    done
    # Double-slash path check (skip protocol prefixes like https://)
    if [ "$validator" = "python3" ]; then
        rc=0
        out=$(python3 -c "
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
" "$file" 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then
            write_error "" "$file validation failed" "a path value has a double slash: $(error_reason "$out" "$rc")"
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
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed -n '1p' | cut -d'"' -f4 || true)
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
if $IS_MACOS && ! command -v brew >/dev/null 2>&1; then
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
    validate_and_run "Step 1" "$gh_script"
else
    write_warn "gh cli" "setup-gh-cli.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 2. Authenticate gh
# ============================================================
log "Step 2: gh authentication"

if $SKIP_GH_AUTH; then
    log "Skipping gh auth (--skip-gh-auth)"
elif ! command -v gh &>/dev/null; then
    write_warn "gh auth" "gh not installed -- authentication skipped"
elif gh auth status &>/dev/null; then
    log_ok "gh already authenticated"
elif $INSTALL_INTERACTIVE; then
    log "Not authenticated. Starting gh auth login..."
    # Interactive: gh talks to the terminal directly, so only the exit code is
    # captured. Its stdin, stdout and stderr are the terminal itself: under a relay
    # (aitools runs this installer relayed) stdout and stderr are pipes, and gh
    # prompts only on a terminal.
    gh_auth_rc=0
    gh auth login </dev/tty >/dev/tty 2>&1 || gh_auth_rc=$?
    if [ "$gh_auth_rc" -ne 0 ]; then
        # The output went to the terminal: the reason is the exit code
        write_error "gh auth" "gh auth login failed (exit $gh_auth_rc)" "$(error_reason "" "$gh_auth_rc")"
        write_summary ACTION "" "Run: gh auth login"
    fi
else
    write_action "gh auth" "not authenticated (non-interactive run) -- run: gh auth login" "Run: gh auth login"
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
        # Interactive -- prompt on the terminal (EOF-safe; see prompt_repos_path)
        prompt_repos_path
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

    if $IS_MACOS; then
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
        # Linux: Google Drive for Desktop has no Linux client (Windows is
        # aitools-install.ps1's)
        log "Linux: Google Drive auto-detection is not supported"
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

REPOS_PATH_NATIVE="$REPOS_PATH"
AITOOLS_NATIVE="$AITOOLS_REPO"

# config.json has one writer: setup-user-config.sh (bootstrap keys from this
# installer + values derived from profile.json; no node needed, P-Q3).
CONFIG_WRITER="$SCRIPT_DIR/setup-user-config.sh"
CONFIG_WRITER_RAN=false   # true: Step 8b passes --skip-config (the writer runs once)
if ! $REPOS_OK; then
    log "Step 5: skipped -- the repos path is unusable (see the error above); config.json not written"
elif [ ! -f "$CONFIG_WRITER" ]; then
    write_error "aitools config" "config.json not written" "setup-user-config.sh not found next to the installer"
else
    writer_args=(--repos-path "$REPOS_PATH_NATIVE" --repo-path "$AITOOLS_NATIVE" --drives-json "$DRIVES_JSON")
    if $DRY_RUN; then writer_args+=(--dry-run); fi
    run_config_writer "$CONFIG_WRITER" "${writer_args[@]}"
    CONFIG_WRITER_RAN=true
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
    write_warn "aitools install" "aitools source not found at $(display_path "$AITOOLS_SRC") -- skipped (MDM deploy)"
fi

# Honest harness (hh): status + aitools
HH_SRC="$SCRIPT_DIR/hh.sh"
HH_DST="$HOME/.local/bin/hh"
if [ -f "$HH_SRC" ]; then
    cp "$HH_SRC" "$HH_DST"
    chmod +x "$HH_DST"
    log_ok "Installed hh to $(display_path "$HH_DST")"
else
    write_warn "aitools install" "hh.sh not found -- skipped (MDM deploy)"
fi

# The harness Python CLIs (~/.aitools/bin) are deployed by deploy-harness (Step 8b).

# ============================================================
# 7. Shell integration
# ============================================================
log "Step 7: Shell integration"

# setup-user-shell.sh is the single owner of the shell files (incident #173 parity):
# the PATH block in the login profile -- must run so the harness resolves managed
# tools (uv python, cursor-agent, brew bash) deterministically -- and the aliases
# source line in ~/.bashrc / ~/.zshrc.
shell_script="$SCRIPT_DIR/setup-user-shell.sh"
if [ -f "$shell_script" ]; then
    validate_and_run "Step 7" "$shell_script"
else
    write_warn "shell" "setup-user-shell.sh not found -- the login-profile PATH block and shell integration skipped (MDM deploy)"
fi

# ============================================================
# 8. Node.js
# ============================================================
log "Step 8: Node.js"

if command -v node &>/dev/null; then
    log_ok "Node.js already installed ($(node --version))"
    write_summary OK "node.js" "$(node --version)"
else
    case "$AITOOLS_PLATFORM" in
        macos)
            if command -v brew &>/dev/null; then
                log "Installing Node.js via Homebrew..."
                # Streamed to the console as it arrives and teed to a temp file, so a
                # failure has its output for the reason (logging.md 8.2: streamed
                # output that fails is logged twice). No temp file: streamed only,
                # and a failure's reason is the exit code.
                node_rc=0
                if ! node_tmp=$(mktemp 2>&1); then
                    log_detail "Step 8: no temp file for brew's output ($node_tmp) -- a failure's reason is its exit code"
                    node_tmp="/dev/null"
                fi
                if brew install node@22 2>&1 | tee "$node_tmp" | while IFS= read -r line; do log "$line"; done; then
                    node_rc=0
                else
                    node_rc=${PIPESTATUS[0]}
                fi
                node_out=""
                if [ "$node_tmp" != "/dev/null" ]; then
                    node_out=$(cat "$node_tmp") || node_out=""
                    if ! rm -f "$node_tmp"; then log_detail "Step 8: could not remove $node_tmp"; fi
                fi
                if [ "$node_rc" -ne 0 ]; then
                    write_error "node.js" "brew install node@22 failed (exit $node_rc)" "$(error_reason "$node_out" "$node_rc")"
                fi
                if command -v node &>/dev/null; then
                    log_ok "Node.js installed ($(node --version))"
                    write_summary OK "node.js" "$(node --version)"
                elif [ "$node_rc" -ne 0 ]; then
                    # The failed install is the error (one cause, one red line)
                    log "Step 8: 'node' not found in PATH after the failed brew install"
                else
                    write_error "node.js" "installed but not on PATH" "restart the terminal and re-run"
                fi
            else
                write_error "node.js" "Node.js not installed" "Homebrew not found -- install Node.js: https://nodejs.org"
            fi
            ;;
        *)
            write_action "node.js" "Node.js not installed -- install it: https://nodejs.org" "Install Node.js: https://nodejs.org"
            ;;
    esac
fi

# ============================================================
# 8b. Deployed harness (~/.aitools) -- deploy-harness.sh
# ============================================================
# After Node (Step 8). deploy-harness fills ~/.aitools/{reference,registries,hooks,
# rules,skills,bin} (bin was this installer's own step before). When Step 5 ran the
# config writer, deploy-harness gets --skip-config, so the writer runs once per
# install (OK "config.json" "n/a (written by installer)"). When Step 5 skipped it
# (repos path unusable, writer missing), deploy-harness runs the writer itself.
log "Step 8b: Deployed harness"

harness_rc=0
if $CONFIG_WRITER_RAN; then
    run_harness_step "$SCRIPT_DIR/deploy-harness.sh" --skip-config || harness_rc=$?
else
    run_harness_step "$SCRIPT_DIR/deploy-harness.sh" || harness_rc=$?
fi
if [ "$harness_rc" -eq 2 ]; then
    summary_end
    exit 2
fi

# ============================================================
# 9. Claude Code CLI
# ============================================================
# Source: https://code.claude.com/docs/en/setup
log "Step 9: Claude Code CLI"

if command -v claude &>/dev/null; then
    log_ok "Claude Code already installed ($(claude --version 2>/dev/null | sed -n '1p'))"
    write_summary OK "claude code" "$(claude --version 2>/dev/null | sed -n '1p')"
    log "Running claude update..."
    # Exit code decides (C-F2). Success: every output line is logged; a failure is
    # one warning (the tool still works) whose reason error_reason takes from the
    # output, which it logs as detail lines.
    update_rc=0
    UPDATE_OUTPUT=$(claude update 2>&1) || update_rc=$?
    if [ "$update_rc" -ne 0 ]; then
        write_warn "claude code" "claude update failed (exit $update_rc): $(error_reason "$UPDATE_OUTPUT" "$update_rc")"
    else
        while IFS= read -r line; do
            if [ -n "$line" ]; then log "$line"; fi
        done <<< "$UPDATE_OUTPUT"
        if printf '%s\n' "$UPDATE_OUTPUT" | grep -i 'already.*up.to.date\|no update' >/dev/null; then
            log_ok "Already up to date"
        else
            log_ok "claude update finished"
        fi
    fi
else
    log "Installing Claude Code CLI..."
    # Windows never reaches here: it is forwarded to aitools-install.ps1 at the top.
    # Streamed as it arrives and teed to a temp file for a failure's reason (as
    # Step 8). The exit code is the first non-zero of curl and the install script.
    claude_rc=0
    if ! claude_tmp=$(mktemp 2>&1); then
        log_detail "Step 9: no temp file for the install output ($claude_tmp) -- a failure's reason is its exit code"
        claude_tmp="/dev/null"
    fi
    if curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tee "$claude_tmp" | while IFS= read -r line; do log "$line"; done; then
        claude_rc=0
    else
        claude_ps=("${PIPESTATUS[@]}")
        claude_rc=${claude_ps[0]}
        if [ "$claude_rc" -eq 0 ]; then claude_rc=${claude_ps[1]}; fi
    fi
    claude_out=""
    if [ "$claude_tmp" != "/dev/null" ]; then
        claude_out=$(cat "$claude_tmp") || claude_out=""
        if ! rm -f "$claude_tmp"; then log_detail "Step 9: could not remove $claude_tmp"; fi
    fi
    if [ "$claude_rc" -ne 0 ]; then
        write_error "claude code" "Claude Code install script failed (exit $claude_rc)" "$(error_reason "$claude_out" "$claude_rc")"
    fi
    if command -v claude &>/dev/null; then
        log_ok "Claude Code installed ($(claude --version 2>/dev/null | sed -n '1p'))"
        write_summary OK "claude code" "$(claude --version 2>/dev/null | sed -n '1p')"
    elif [ "$claude_rc" -ne 0 ]; then
        # The failed install is the error (one cause, one red line)
        log "Step 9: 'claude' not found in PATH after the failed install"
    else
        write_error "claude code" "installed but not on PATH" "restart the terminal and re-run"
    fi
fi

# ============================================================
# 10. Vercel CLI
# ============================================================
log "Step 10: Vercel CLI"

vercel_script="$SCRIPT_DIR/setup-vercelcli.sh"
if [ -f "$vercel_script" ]; then
    validate_and_run "Step 10" "$vercel_script"
else
    write_warn "vercel cli" "setup-vercelcli.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 11. Pandoc
# ============================================================
log "Step 11: Pandoc"

pandoc_script="$SCRIPT_DIR/setup-pandoc.sh"
if [ -f "$pandoc_script" ]; then
    validate_and_run "Step 11" "$pandoc_script"
else
    write_warn "pandoc" "setup-pandoc.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 12. Rust (cargo)
# ============================================================
log "Step 12: Rust (cargo)"

rust_script="$SCRIPT_DIR/setup-rust.sh"
if [ -f "$rust_script" ]; then
    validate_and_run "Step 12" "$rust_script"
else
    write_warn "rust/cargo" "setup-rust.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 13. Typst
# ============================================================
log "Step 13: Typst"

typst_script="$SCRIPT_DIR/setup-typst.sh"
if [ -f "$typst_script" ]; then
    validate_and_run "Step 13" "$typst_script"
else
    write_warn "typst" "setup-typst.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 14. uv  (MUST precede Python -- uv is the Python manager)
# ============================================================
log "Step 14: uv"

uv_script="$SCRIPT_DIR/setup-uv.sh"
if [ -f "$uv_script" ]; then
    validate_and_run "Step 14" "$uv_script"
else
    write_warn "uv" "setup-uv.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 15. Python  (via uv -- requires Step 14)
# ============================================================
log "Step 15: Python"

python_script="$SCRIPT_DIR/setup-python.sh"
if [ -f "$python_script" ]; then
    validate_and_run "Step 15" "$python_script"
else
    write_warn "python" "setup-python.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 15b. pywinpty (Windows test library; macOS/Linux report n/a -- requires Step 15)
# ============================================================
# Parity with aitools-install.ps1, which installs it: here the script reports
# "n/a (<platform>)" and changes nothing.
log "Step 15b: pywinpty"

pywinpty_script="$SCRIPT_DIR/setup-pywinpty.sh"
if [ -f "$pywinpty_script" ]; then
    validate_and_run "Step 15b" "$pywinpty_script"
else
    write_warn "pywinpty" "setup-pywinpty.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 16. Modal CLI
# ============================================================
log "Step 16: Modal CLI"

modal_script="$SCRIPT_DIR/setup-modal.sh"
if [ -f "$modal_script" ]; then
    validate_and_run "Step 16" "$modal_script"
else
    write_warn "modal cli" "setup-modal.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 17. Go
# ============================================================
log "Step 17: Go"

go_script="$SCRIPT_DIR/setup-go.sh"
if [ -f "$go_script" ]; then
    validate_and_run "Step 17" "$go_script"
else
    write_warn "go" "setup-go.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 18. Datadog CLI
# ============================================================
log "Step 18: Datadog CLI"

datadog_script="$SCRIPT_DIR/setup-datadog.sh"
if [ -f "$datadog_script" ]; then
    validate_and_run "Step 18" "$datadog_script"
else
    write_warn "datadog cli" "setup-datadog.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 19. Perl
# ============================================================
log "Step 19: Perl"

perl_script="$SCRIPT_DIR/setup-perl.sh"
if [ -f "$perl_script" ]; then
    validate_and_run "Step 19" "$perl_script"
else
    write_warn "perl" "setup-perl.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 20. Bash
# ============================================================
log "Step 20: Bash"

bash_script="$SCRIPT_DIR/setup-bash.sh"
if [ -f "$bash_script" ]; then
    validate_and_run "Step 20" "$bash_script"
else
    write_warn "bash" "setup-bash.sh not found -- skipped (MDM deploy)"
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
    validate_and_run "Step 20b" "$chrome_script"
else
    write_warn "google chrome" "setup-google-chrome.sh not found -- skipped (MDM deploy)"
fi

# ============================================================
# 21. Deploy configurations
# ============================================================
log "Step 21: Deploy configurations"

DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh setup-user-mcp.sh setup-user-skills.sh setup-cursor-ide-mcp.sh setup-user-settings.sh setup-user-hooks.sh"

for script in $DEPLOY_SCRIPTS; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        validate_and_run "Step 21" "$script_path"
    else
        write_warn "$(install_tool "$script")" "$script not found -- skipped (MDM deploy)"
    fi
done

# ============================================================
# 22. Relay → Cursor AGENTS.md (mirror; same as aitools deploy)
# ============================================================
log "Step 22: Relay → Cursor AGENTS.md mirror"

# run_relay_sync (aitools-lib) logs the sync's output as detail lines and records
# a failure as one warning, "relay sync" (with its reason); nothing more here
sync_py="$SCRIPT_DIR/sync-relay-to-cursor-agents.py"
if [ -f "$sync_py" ]; then
    sync_args=()
    if $DRY_RUN; then sync_args+=(--dry-run); fi
    if ! $DRY_RUN; then export AITOOLS_SYNC_DEPLOY_LOG=1; fi
    if command -v python3 >/dev/null 2>&1; then
        if run_relay_sync python3 "$sync_py" ${sync_args[@]+"${sync_args[@]}"}; then
            if $DRY_RUN; then log_ok "relay -> AGENTS.md sync (dry-run)"; fi
        fi
    elif command -v py >/dev/null 2>&1; then
        if run_relay_sync py -3 "$sync_py" ${sync_args[@]+"${sync_args[@]}"}; then
            if $DRY_RUN; then log_ok "relay -> AGENTS.md sync (dry-run)"; fi
        fi
    else
        write_warn "relay sync" "Python not found -- relay -> AGENTS.md sync skipped"
    fi
    unset AITOOLS_SYNC_DEPLOY_LOG
fi

# The panel, only when this installer created the run summary file (summary_begin)
summary_end

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
