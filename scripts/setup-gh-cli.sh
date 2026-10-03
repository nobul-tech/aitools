#!/usr/bin/env bash
# setup-gh-cli.sh — Installs/updates GitHub CLI (gh)
# Safe to re-run — detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (brew install gh).
# Linux: Uses GitHub's official apt repository (cli.github.com) + keyring --
#        never the distro package. The repository is added whenever it is
#        missing, including when a distro gh is already installed. A gh that
#        apt does not own (tarball, Homebrew, environment-provided) is left
#        alone rather than shadowed by a second copy.
#        Errors on non-apt systems (dnf arrives with Linux support).
#
# Auth (gh auth login) is interactive — handled by aitools-install Step 2, not here.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-gh-cli"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

OS_NAME="$(uname -s)"

# First line of `gh --version`, or "version unknown" when the output is not a gh
# version banner (environment-provided gh wrappers can print other text).
gh_version_line() {
    local out first
    # || true: a broken gh must not abort the script; the banner check below is the result check
    out=$(gh --version 2>&1) || true
    first=${out%%$'\n'*}
    case "$first" in
        "gh version "*) printf '%s' "$first" ;;
        *) printf 'version unknown' ;;
    esac
}

# Add GitHub's apt repository + signing keyring (official instructions, cli.github.com).
# Returns non-zero if any step fails; output goes to the log.
add_github_cli_apt_repo() {
    { (type -p wget >/dev/null || sudo apt-get install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; } 2>&1 \
        | while IFS= read -r line; do log "$line"; done
}

# --- Install/update ---
case "$OS_NAME" in
    Darwin)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install gh manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install gh"
            exit 1
        fi

        if command -v gh &>/dev/null; then
            log "gh CLI already installed ($(gh --version | head -1))"
            log "Checking for updates via Homebrew..."
            UPGRADE_OUTPUT=$(brew upgrade gh 2>&1) || true
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
                log_ok "gh CLI already up to date"
                write_summary OK "gh cli" "$(gh --version | head -1)"
            else
                printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
                if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                    log_error "brew upgrade gh failed (see log above)"
                    write_summary ERROR "gh cli" "brew upgrade failed"
                else
                    log_ok "gh CLI $(gh --version | head -1)"
                    write_summary OK "gh cli" "$(gh --version | head -1)"
                fi
            fi
        else
            log "Installing gh CLI via Homebrew..."
            if ! brew install gh 2>&1 | while IFS= read -r line; do log "$line"; done; then
                log_error "brew install gh failed"
                write_summary ERROR "gh cli" "brew install failed"
            fi

            if command -v gh &>/dev/null; then
                log_ok "gh CLI installed ($(gh --version | head -1))"
                log_ok "Install path: $(command -v gh)"
                write_summary OK "gh cli" "$(gh --version | head -1)"
            else
                log_error "brew install completed but 'gh' not found in PATH"
                write_summary ERROR "gh cli" "installed but not on PATH"
            fi
        fi
        ;;

    *)
        # Linux: GitHub's official apt repository (cli.github.com), never the distro package
        if command -v apt-get &>/dev/null; then
            GH_APT_LIST="/etc/apt/sources.list.d/github-cli.list"
            GH_PATH=""
            GH_APT_OWNED=false
            if command -v gh &>/dev/null; then
                GH_PATH=$(command -v gh)
                # dpkg -S exits non-zero when no package owns the file -- that is the answer sought
                if dpkg -S "$GH_PATH" >/dev/null 2>&1; then
                    GH_APT_OWNED=true
                fi
            fi
            if [ -n "$GH_PATH" ] && ! $GH_APT_OWNED; then
                # Not owned by apt (tarball, Homebrew, environment-provided client): an apt
                # gh would be a second copy that shadows, or is shadowed by, this one.
                GH_VERSION=$(gh_version_line)
                log_warn "gh at $GH_PATH ($GH_VERSION) is not managed by apt -- leaving it as is"
                write_summary WARN "gh cli" "not apt-managed (kept)"
            else
                if [ ! -f "$GH_APT_LIST" ]; then
                    if [ -n "$GH_PATH" ]; then
                        log_warn "gh at $GH_PATH comes from the distro repository, not cli.github.com -- switching sources"
                    fi
                    log "Adding the GitHub CLI apt repository (cli.github.com)..."
                    if ! add_github_cli_apt_repo; then
                        log_error "Could not add the GitHub CLI apt repository"
                        write_summary ERROR "gh cli" "apt repo setup failed"
                    fi
                fi
                if [ -f "$GH_APT_LIST" ]; then
                    log "Installing/updating gh from cli.github.com via apt..."
                    if ! { sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
                        log_error "apt-get install gh failed"
                        write_summary ERROR "gh cli" "apt-get install failed"
                    fi
                    hash -r
                    if command -v gh &>/dev/null; then
                        GH_VERSION=$(gh_version_line)
                        log_ok "gh CLI $GH_VERSION ($(command -v gh))"
                        write_summary OK "gh cli" "$GH_VERSION"
                    else
                        log_error "apt-get completed but 'gh' not found in PATH"
                        write_summary ERROR "gh cli" "installed but not on PATH"
                    fi
                fi
            fi
        else
            log_error "No supported package manager found (apt). Install gh manually: https://cli.github.com"
            write_summary ERROR "gh cli" "no supported package manager"
        fi
        ;;
esac

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
