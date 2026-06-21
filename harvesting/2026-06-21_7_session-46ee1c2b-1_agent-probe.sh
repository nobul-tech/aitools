#!/usr/bin/env bash
# Probe: untangle agent / cursor-agent / grok resolution (read-only)
set -uo pipefail

echo "=== readlink targets in ~/.local/bin ==="
for c in agent cursor-agent grok; do
  p="$HOME/.local/bin/$c"
  if [ -L "$p" ]; then
    printf '%s -> %s\n' "$c" "$(readlink "$p")"
  elif [ -e "$p" ]; then
    printf '%s (regular file)\n' "$c"
  else
    printf '%s (absent)\n' "$c"
  fi
done

echo
echo "=== what each resolves to on PATH (interactive zsh) ==="
zsh -ilc 'for c in agent cursor-agent grok; do printf "%s -> " $c; command -v $c || echo "(none)"; done' 2>/dev/null

echo
echo "=== versions ==="
echo "-- ~/.grok/bin/agent --version"
"$HOME/.grok/bin/agent" --version 2>&1 | head -3 || true
echo "-- cursor-agent --version"
"$HOME/.local/bin/cursor-agent" --version 2>&1 | head -3 || true

echo
echo "=== contents of ~/.grok/bin ==="
ls -la "$HOME/.grok/bin" 2>&1 || true

echo
echo "=== does cursor's install dir provide an 'agent' entrypoint? ==="
ls -la "$HOME/.local/share/cursor-agent/versions/" 2>&1 | head -20 || true
