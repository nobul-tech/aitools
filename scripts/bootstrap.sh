#!/usr/bin/env bash
# bootstrap.sh -- One-line remote bootstrap for aitools on macOS/Linux.
#
# Usage (fresh machine, nothing installed). Note the `-c "$(curl ...)"` form --
# it keeps your terminal on stdin so interactive prompts (Homebrew sudo, gh auth
# login, repos-path, user init) still work. A plain `curl ... | bash` would NOT.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nobul-tech/aitools/main/scripts/bootstrap.sh)"
#
# Installs only what the repo can't install itself -- a package manager + git --
# then clones nobul-tech/aitools and hands off to scripts/aitools-install.sh, which
# installs the full toolchain (Node, Claude Code, etc.) and deploys configs. Finally,
# when interactive, runs `aitools user init` to pull your dotprofile so personal
# CLAUDE.md placeholders, skills, and hooks resolve.
#
# Idempotent: if the clone already exists it pulls and reinstalls.
# Override the clone location with AITOOLS_DIR (default: ~/repos/aitools).

set -euo pipefail

REPO_URL="https://github.com/nobul-tech/aitools.git"
AITOOLS_DIR="${AITOOLS_DIR:-$HOME/repos/aitools}"

say() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m[bootstrap] error:\033[0m %s\n' "$1" >&2; exit 1; }

OS="$(uname -s)"

# --- 1. Package manager + git (the irreducible prerequisites) ---
case "$OS" in
    Darwin)
        if ! command -v brew >/dev/null 2>&1; then
            say "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        # Put brew on PATH for this session (Apple Silicon, then Intel).
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        command -v git >/dev/null 2>&1 || { say "Installing git via Homebrew..."; brew install git; }
        ;;
    Linux)
        if ! command -v git >/dev/null 2>&1; then
            if command -v apt-get >/dev/null 2>&1; then
                say "Installing git/curl via apt..."
                sudo apt-get update -y && sudo apt-get install -y git curl
            elif command -v dnf >/dev/null 2>&1; then
                say "Installing git/curl via dnf..."
                sudo dnf install -y git curl
            else
                die "No supported package manager (apt/dnf) found. Install git manually, then re-run."
            fi
        fi
        ;;
    *)
        die "Unsupported OS '$OS'. On Windows use bootstrap.ps1 (irm ... | iex)."
        ;;
esac

command -v git >/dev/null 2>&1 || die "git is still unavailable after setup -- restart your terminal and re-run."

# --- 2. Clone or update the repo ---
if [ -d "$AITOOLS_DIR/.git" ]; then
    say "Updating existing clone at $AITOOLS_DIR"
    git -C "$AITOOLS_DIR" pull --ff-only || say "pull failed -- continuing with local copy"
else
    say "Cloning $REPO_URL -> $AITOOLS_DIR"
    mkdir -p "$(dirname "$AITOOLS_DIR")"
    git clone "$REPO_URL" "$AITOOLS_DIR"
fi

# --- 3. Install toolchain + deploy configs (machine environment, "Tier 1") ---
say "Running installer..."
if bash "$AITOOLS_DIR/scripts/aitools-install.sh" "$@"; then
    say "Installer completed."
else
    say "Installer reported issues -- see the log above before continuing."
fi

# --- 4. Personalize: pull dotprofile so placeholders/skills/hooks resolve ("Tier 2") ---
# Interactive only: 'aitools user init' may create/clone your private user repo and
# expects a TTY. Skipped automatically in non-interactive/MDM runs.
if [ -t 0 ] && [ -x "$HOME/.local/bin/aitools" ]; then
    say "Personalizing: aitools user init"
    "$HOME/.local/bin/aitools" user init || \
        say "user init skipped/failed -- run it later with: aitools user init"
else
    say "Skipping 'aitools user init' (non-interactive). Run it later to load your dotprofile."
fi

say "Done. Open a new shell so PATH + aliases take effect."
