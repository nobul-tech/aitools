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
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
# Returns non-zero if any step fails. The output is captured in REPO_OUT (exit
# status in REPO_RC) so that a failure has a reason (reference/logging.md 8.3);
# on success it goes to the log.
add_github_cli_apt_repo() {
    REPO_RC=0
    REPO_OUT=$({ (type -p wget >/dev/null || sudo apt-get install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; } 2>&1) \
        || REPO_RC=$?
    if [ "$REPO_RC" -eq 0 ] && [ -n "$REPO_OUT" ]; then
        printf '%s\n' "$REPO_OUT" | while IFS= read -r line; do log "$line"; done
    fi
    return "$REPO_RC"
}

# --- Install/update ---
# The platform comes from the library (AITOOLS_PLATFORM: macos / linux),
# never from a direct uname read (.claude/rules/cross-platform.md).
case "$AITOOLS_PLATFORM" in
    macos)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            write_error "gh cli" "Homebrew not found" "brew is not on PATH"
            log "Install gh manually:"
            log "  1. Install Homebrew: https://brew.sh"
            log "  2. brew install gh"
            write_summary ACTION "" "Install Homebrew (https://brew.sh), then: brew install gh"
            exit 1
        fi

        if command -v gh &>/dev/null; then
            log "gh CLI already installed ($(gh_version_line))"
            log "Checking for updates via Homebrew..."
            upgrade_rc=0
            UPGRADE_OUTPUT=$(brew upgrade gh 2>&1) || upgrade_rc=$?
            if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
                log_ok "gh CLI already up to date"
                write_summary OK "gh cli" "$(gh_version_line)"
            else
                # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
                if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
                    # The installed gh still works: a warning, not an error (Standard 3).
                    # error_reason logs the output as detail lines.
                    write_warn "gh cli" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$upgrade_rc")"
                    write_summary OK "gh cli" "$(gh_version_line)"
                else
                    while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
                    log_ok "gh CLI $(gh_version_line)"
                    write_summary OK "gh cli" "$(gh_version_line)"
                fi
            fi
        else
            # The output is captured (not streamed) so that a failure has a reason
            log "Installing gh CLI via Homebrew..."
            INSTALL_RC=0
            INSTALL_OUT=$(brew install gh 2>&1) || INSTALL_RC=$?
            if [ "$INSTALL_RC" -ne 0 ]; then
                write_error "gh cli" "brew install failed" "$(error_reason "$INSTALL_OUT" "$INSTALL_RC")"
            else
                printf '%s\n' "$INSTALL_OUT" | while IFS= read -r line; do log "$line"; done
                if command -v gh &>/dev/null; then
                    log_ok "gh CLI installed ($(gh_version_line))"
                    log_ok "Install path: $(command -v gh)"
                    write_summary OK "gh cli" "$(gh_version_line)"
                else
                    write_error "gh cli" "installed but not on PATH" "gh not found after brew install"
                fi
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
                write_summary OK "gh cli" "$GH_VERSION"
                write_warn "gh cli" "gh at $GH_PATH is not managed by apt -- kept as is"
            else
                if [ ! -f "$GH_APT_LIST" ]; then
                    if [ -n "$GH_PATH" ]; then
                        write_warn "gh cli" "gh at $GH_PATH comes from the distro repository, not cli.github.com -- switching sources"
                    fi
                    log "Adding the GitHub CLI apt repository (cli.github.com)..."
                    if ! add_github_cli_apt_repo; then
                        write_error "gh cli" "apt repo setup failed" "$(error_reason "$REPO_OUT" "$REPO_RC")"
                    fi
                fi
                if [ -f "$GH_APT_LIST" ]; then
                    # The output is captured (not streamed) so that a failure has a reason
                    log "Installing/updating gh from cli.github.com via apt..."
                    APT_RC=0
                    APT_OUT=$({ sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1) || APT_RC=$?
                    if [ "$APT_RC" -ne 0 ]; then
                        write_error "gh cli" "apt-get install failed" "$(error_reason "$APT_OUT" "$APT_RC")"
                        # One failure, one red line: the install error above is it
                        log "gh not checked: apt-get install failed"
                    else
                        if [ -n "$APT_OUT" ]; then
                            printf '%s\n' "$APT_OUT" | while IFS= read -r line; do log "$line"; done
                        fi
                        hash -r
                        if command -v gh &>/dev/null; then
                            GH_VERSION=$(gh_version_line)
                            log_ok "gh CLI $GH_VERSION ($(command -v gh))"
                            write_summary OK "gh cli" "$GH_VERSION"
                        else
                            write_error "gh cli" "installed but not on PATH" "gh not found after apt-get install"
                        fi
                    fi
                fi
            fi
        else
            write_error "gh cli" "no supported package manager" "apt-get not found -- install gh manually: https://cli.github.com"
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
