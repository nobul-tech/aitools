#!/usr/bin/env bash
# Rough per-suite count of process launches that dominate test cost:
# pwsh invocations, setup/deploy script runs, git init, pty runs.
set -euo pipefail
cd /Users/new-jose/repos/aitools
printf '%-50s %6s %6s %6s %6s %7s\n' suite pwsh pty gitinit bash lines
for f in tests/*/test-*.sh tests/*/test-*.ps1; do
    [ -f "$f" ] || continue
    pw=$(grep -cE '\bpwsh\b|\$pwshExe|PWSH' "$f" || true)
    pt=$(grep -cE 'pty-run|\$PTY|\$pty' "$f" || true)
    gi=$(grep -cE 'git (-C [^ ]+ )?init' "$f" || true)
    bs=$(grep -cE '\bbash "?\$' "$f" || true)
    ln=$(wc -l < "$f" | tr -d ' ')
    printf '%-50s %6s %6s %6s %6s %7s\n' "$f" "$pw" "$pt" "$gi" "$bs" "$ln"
done
