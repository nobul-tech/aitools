#!/usr/bin/env bash
# shell-unset-probe.sh -- does "$(basename "$SHELL")" survive set -u with SHELL unset?
# Mirrors setup-user-claude.sh:178 (footer). Touches no files.
set -euo pipefail
unset SHELL
footer="- Shell: $(basename "$SHELL")"
printf 'reached: %s\n' "$footer"
