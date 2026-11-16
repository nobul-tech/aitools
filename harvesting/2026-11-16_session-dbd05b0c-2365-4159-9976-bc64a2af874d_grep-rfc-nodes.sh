#!/usr/bin/env bash
# List RFC 0011 lines that name brief nodes removed by D874d-70, or the L3401 typo.
set -euo pipefail
grep -n -E 'access|name_prefix|duties|return|ambiguities|L3401' /Users/new-jose/repos/aitools/rfcs/RFC-0011-structured-reports.md
