#!/usr/bin/env bash
# setup-user-shell.sh -- Owns the aitools managed PATH block in the login profile (macOS/Linux)
# Safe to re-run -- idempotent.
#
# The harness must resolve managed tools (uv python shims, cursor-agent, brew
# bash 5.x) deterministically. This script writes a marked block
#   # >>> aitools managed >>>  ...  # <<< aitools managed <<<
# at the END of the bash LOGIN profile (~/.bash_profile). Placed last, the block
# re-asserts PATH precedence: brew shellenv (homebrew) then prepend ~/.local/bin,
# so the managed copies win over any earlier installer prepends (grok, antigravity)
# without rewriting the user's own lines.
#
# Resulting precedence (decision #6):
#   ~/.local/bin -> /opt/homebrew/bin -> grok/antigravity -> system
#
# Block re-applied idempotently (replaced in place if markers already present).
# The interactive *.rc keeps the aliases source line (managed elsewhere).
#
# Testing: set AITOOLS_PROFILE_DIR to operate on profiles in a scratch dir
# instead of $HOME.
#
# See plans/tooling-resolution-and-artifact-registry.md (Workstream A) and
# reference/tool-registry.md for context.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-user-shell"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Target profile (overridable for testing) ---
PROFILE_DIR="${AITOOLS_PROFILE_DIR:-$HOME}"
PROFILE="$PROFILE_DIR/.bash_profile"

START_MARKER="# >>> aitools managed >>>"
END_MARKER="# <<< aitools managed <<<"

# --- Build the managed block in a temp file ---
# The block is identical across Macs (arch detected at runtime), so it is safe
# to ship verbatim into any login profile.
BLOCK_FILE=$(mktemp)
cleanup() { rm -f "$BLOCK_FILE"; }
trap cleanup EXIT

cat > "$BLOCK_FILE" <<'BLOCK'
# >>> aitools managed >>>
# Owned by aitools (scripts/setup-user-shell.sh). Placed last so it re-asserts
# PATH precedence for harness-managed tools. Edit via the script, not by hand.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$PATH:$HOME/.cargo/bin"
[ -d "$HOME/go/bin" ] && export PATH="$PATH:$HOME/go/bin"
# <<< aitools managed <<<
BLOCK

# --- Back up before writing (skips if profile does not exist yet) ---
backup_file "$PROFILE"

# --- Detect prior state for accurate three-outcome reporting ---
HAD_BLOCK=0
if [ -f "$PROFILE" ] && grep -qF "$START_MARKER" "$PROFILE"; then
    HAD_BLOCK=1
fi

# --- Splice the block in (replace in place if present, else append at EOF) ---
# Perl owns the string surgery (USO: perl for non-trivial string manipulation).
# Reads the profile and the block, replaces the marked region or appends.
SPLICE_RC=0
PROFILE="$PROFILE" BLOCK_FILE="$BLOCK_FILE" \
START_MARKER="$START_MARKER" END_MARKER="$END_MARKER" \
perl -e '
    my $prof  = $ENV{PROFILE};
    my $start = $ENV{START_MARKER};
    my $end   = $ENV{END_MARKER};
    local $/;
    open my $bf, "<", $ENV{BLOCK_FILE} or die "block: $!";
    my $block = <$bf>; close $bf;
    my $c = "";
    if (-f $prof) {
        open my $pf, "<", $prof or die "profile read: $!";
        $c = <$pf>; close $pf;
    }
    if ($c =~ /\Q$start\E.*?\Q$end\E\n?/s) {
        $c =~ s/\Q$start\E.*?\Q$end\E\n?/$block/s;
    } else {
        $c .= "\n" if (length($c) && $c !~ /\n\z/);
        $c .= $block;
    }
    open my $out, ">", $prof or die "profile write: $!";
    print $out $c; close $out;
' || SPLICE_RC=$?

if [ "$SPLICE_RC" -ne 0 ]; then
    log_error "Failed to write managed block to $(display_path "$PROFILE")"
    write_summary ERROR "shell" "managed block write failed"
    exit 1
fi

# --- Post-write validation: markers present and balanced ---
if ! grep -qF "$START_MARKER" "$PROFILE" || ! grep -qF "$END_MARKER" "$PROFILE"; then
    log_error "Managed block markers missing after write -- $(display_path "$PROFILE")"
    write_summary ERROR "shell" "managed block markers missing"
    exit 1
fi

if [ "$HAD_BLOCK" -eq 1 ]; then
    log_ok "Refreshed managed block in $(display_path "$PROFILE")"
    write_summary OK "shell" "managed block refreshed"
else
    log_ok "Added managed block to $(display_path "$PROFILE")"
    write_summary OK "shell" "managed block added"
fi

# --- Advisory: zsh-only constructs in a bash login profile error on every login ---
# (e.g. grok's installer copies `autoload -Uz compinit` -- a zsh builtin -- which
# bash cannot run.) Warn but do not auto-remove; line surgery on user content
# beyond the managed block is out of scope for this script.
if [ -f "$PROFILE" ] && grep -qE '(^|[[:space:]])(autoload|compinit)([[:space:]]|$)' "$PROFILE"; then
    log_warn "Found zsh-only constructs (autoload/compinit) in $(display_path "$PROFILE") -- these error under bash"
    write_summary WARN "shell" "zsh-only lines in bash profile"
    write_summary ACTION "" "Remove autoload/compinit from .bash_profile (zsh-only)"
fi

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
