#!/usr/bin/env bash
# AI Tooling shell aliases — source from ~/.bashrc or ~/.zshrc
# Usage: source "/path/to/ai-tooling/shared/shell/aliases.sh"

# Claude Code launcher with CLAUDE.md check
cc() {
  if [ ! -f "CLAUDE.md" ] && [ ! -f "CLAUDE.local.md" ]; then
    echo "No CLAUDE.md found in $(pwd)."
    read -rp "Create one with 'claude /init'? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      claude /init
    fi
  fi
  claude "$@"
}

# Quick resume last session
alias ccr='claude -c'

# Interactive session picker
alias ccs='claude --resume'

# Clipboard HTML → Markdown (requires pandoc)
clip2md() {
  if ! command -v pandoc &>/dev/null; then
    echo "clip2md: pandoc not found. Run 'aitools install' or 'brew install pandoc' (macOS)" >&2
    return 1
  fi
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "clip2md: clipboard HTML extraction requires macOS (uses osascript)" >&2
    echo "clip2md: on Windows, use the PowerShell version instead" >&2
    return 1
  fi
  local html
  html=$(osascript -e 'the clipboard as «class HTML»' 2>/dev/null | \
    perl -ne 'print chr foreach unpack("C*",pack("H*",substr($_,11,-3)))')
  if [ -z "$html" ]; then
    echo "clip2md: no HTML content on clipboard" >&2
    return 1
  fi
  # Strip style/class/target attrs and bare div/span wrappers (Gmail noise)
  html=$(echo "$html" | perl -pe 's/\s*(style|class|target|saferedirecturl)="[^"]*"//gi; s/<\/?(div|span)[^>]*>//gi')
  if [ -n "$1" ]; then
    echo "$html" | pandoc -f html -t markdown | perl -pe 's/\{=""\}//g' > "$1"
    echo "Saved to $1"
  else
    echo "$html" | pandoc -f html -t markdown | perl -pe 's/\{=""\}//g'
  fi
}
