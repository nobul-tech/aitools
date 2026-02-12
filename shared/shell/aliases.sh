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
