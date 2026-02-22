#!/usr/bin/env bash
# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
# Safe to re-run -- replaces existing file with latest version.
#
# Sources (in priority order):
#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
#   2. shared/claude-shared.md          (fallback template from ai-tooling repo)
#
# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
# machine's profile from profile.json. See reference/tool-install-sources.md.
#
# Overwrites: yes (sole owner of ~/.claude/CLAUDE.md)

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-user-claude"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

# Backup a file before overwriting. Keeps at most $max_backups copies.
backup_file() {
    local file="$1" max_backups=20
    [ -f "$file" ] || return 0
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    cp "$file" "${file}.bak.${ts}"
    # Prune oldest beyond limit
    ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1)) | xargs rm -f 2>/dev/null
    log "Backed up $(display_path "$file")"
}

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_PATH="${1:-$SCRIPT_DIR/../shared/claude-shared.md}"
CONFIG="$HOME/.aitools/config.json"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
SOURCE_PATH=""
SOURCE_LABEL=""

if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
    USER_REPO_PATH=$(node -e "
try {
    const cfg = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    if (cfg.userRepoPath) console.log(cfg.userRepoPath);
} catch {}
" "$CONFIG" 2>/dev/null)

    if [ -n "$USER_REPO_PATH" ] && [ -f "$USER_REPO_PATH/claude/CLAUDE.md" ]; then
        SOURCE_PATH="$USER_REPO_PATH/claude/CLAUDE.md"
        SOURCE_LABEL="user repo"
    fi
fi

if [ -z "$SOURCE_PATH" ]; then
    if [ -f "$SHARED_PATH" ]; then
        SOURCE_PATH="$SHARED_PATH"
        SOURCE_LABEL="shared template"
    else
        log_error "No template found. Checked user repo and $(display_path "$SHARED_PATH")"
        exit 1
    fi
fi

log "Template source: $(display_path "$SOURCE_PATH") ($SOURCE_LABEL)"

# --- Read template content ---
SHARED_CONTENT=$(cat "$SOURCE_PATH")

# --- Profile interpolation ---
# Read profile.json and replace {{PLACEHOLDER}} tokens.
# Reuses the same pattern as build-deploy.sh (lines 58-100).
PROFILE_NAME=""
PROFILE_COMPANY=""
IDENTITY_GIT_NAME=""
IDENTITY_GIT_EMAIL=""

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
    console.log('PROFILE_NAME=' + JSON.stringify(prof.name));
    console.log('PROFILE_COMPANY=' + JSON.stringify(prof.company));
    console.log('IDENTITY_GIT_NAME=' + JSON.stringify(ident.git.name));
    console.log('IDENTITY_GIT_EMAIL=' + JSON.stringify(ident.git.email));
} catch(e) { process.exit(1); }
" "$CONFIG" 2>/dev/null) && eval "$PROFILE_VALS"
fi

if [ -n "$PROFILE_NAME" ]; then
    SHARED_CONTENT="${SHARED_CONTENT//\{\{PROFILE_NAME\}\}/$PROFILE_NAME}"
    SHARED_CONTENT="${SHARED_CONTENT//\{\{PROFILE_COMPANY\}\}/$PROFILE_COMPANY}"
    SHARED_CONTENT="${SHARED_CONTENT//\{\{IDENTITY_GIT_NAME\}\}/$IDENTITY_GIT_NAME}"
    SHARED_CONTENT="${SHARED_CONTENT//\{\{IDENTITY_GIT_EMAIL\}\}/$IDENTITY_GIT_EMAIL}"
    log "Profile interpolation: name=$PROFILE_NAME company=$PROFILE_COMPANY"
else
    log_warn "Profile not available -- {{PLACEHOLDER}} tokens will not be resolved"
fi

# Backup and remove existing file so we always write the latest version
backup_file "$CLAUDE_MD"
if [ -f "$CLAUDE_MD" ]; then
    rm "$CLAUDE_MD"
    log "Removed existing $(display_path "$CLAUDE_MD")"
fi

# --- Write CLAUDE.md ---
cat > "$CLAUDE_MD" << EOF
${SHARED_CONTENT}

## Machine-Specific

- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname))
- Shell: $(basename "$SHELL")
EOF

# Post-write validation
if [ ! -s "$CLAUDE_MD" ]; then
    log_error "Validation failed: $CLAUDE_MD is empty or missing"
elif ! grep -q "## Machine-Specific" "$CLAUDE_MD"; then
    log_error "Validation failed: $CLAUDE_MD missing Machine-Specific section"
fi

log_ok "Wrote $(display_path "$CLAUDE_MD")"

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
