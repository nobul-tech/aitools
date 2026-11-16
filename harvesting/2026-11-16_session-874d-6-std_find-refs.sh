#!/usr/bin/env bash
# Find references to the running-estimate files RFC 0011 retires (read-only).
set -euo pipefail
cd /Users/new-jose/repos/aitools
git grep -nE 'running-estimate\.json|mission-running-estimate|get_running_estimate_path' -- . ':!harvesting' ':!.aitools/channel/handoffs' ':!deploy' || echo "(no matches)"
