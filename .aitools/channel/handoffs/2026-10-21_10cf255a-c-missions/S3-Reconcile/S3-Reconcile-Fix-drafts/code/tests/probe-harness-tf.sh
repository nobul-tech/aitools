#!/usr/bin/env bash
# probe-harness-tf.sh GEN_PS1 OUTDIR -- copy a generated deploy-harness.ps1, drop its
# Windows OS guard, inject an uncaught error right after the outer `try {` (the one
# closed by the final `} finally {`), run it under an isolated HOME with pwsh -File
# and print the exit code. Variants: throw (terminating), cmd (a cmdlet error
# with -ErrorAction Stop), nonterm (a non-terminating cmdlet error).
set -uo pipefail
src="$1"
out="$2"
outer_try=$(perl -ne 'print "$.\n" if /^try \{\r?$/' "$src" | sed -n '2p')
echo "outer try line: $outer_try"
if [ -z "$outer_try" ]; then echo "no outer try found"; exit 1; fi
for v in throw cmd nonterm bind; do
    case "$v" in
        bind) inj='$probeX = Join-Path $null "x"' ;;
        throw) inj='throw "probe-throw"' ;;
        cmd) inj='Get-Item -LiteralPath "/nonexistent/probe" -ErrorAction Stop' ;;
        nonterm) inj='Get-Item -LiteralPath "/nonexistent/probe"' ;;
    esac
    f="$out/dh-$v.ps1"
    INJ="$inj" LN="$outer_try" perl -ne '
        if (/This script is for Windows/) { $skip = 1 }
        print unless $skip && /^\s*(LogError|exit 1)/;
        $skip = 0 if $skip && /^\s*exit 1/;
        print "$ENV{INJ}\n" if $. == $ENV{LN};
    ' "$src" > "$f"
    mkdir -p "$out/home-$v"
    HOME="$out/home-$v" pwsh -NoProfile -File "$f" > "$out/dh-$v.out" 2>&1
    rc=$?
    echo "variant=$v rc=$rc"
    grep -m3 -i -e "probe" -e "COMPLETED" -e "FAILED" "$out/dh-$v.out"
done
