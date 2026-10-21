#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools

echo "=== main function definition + invocation (arg passing) ==="
grep -nE '^[a-zA-Z_]+\(\) *\{|^main |"\$@"' scripts/aitools | grep -iE 'main|"\$@"' | head -10

echo ""
echo "=== context around _ORIG_ARGS capture and the exec replay (same scope?) ==="
grep -n '_ORIG_ARGS' scripts/aitools

echo ""
echo "=== bash -n ==="
if bash -n scripts/aitools; then echo "OK parse"; else echo "FAIL parse"; fi

echo ""
echo "=== simulate: does _ORIG_ARGS survive the parse loop? (mini harness) ==="
bash -c '
set -uo pipefail
_run() {
  _ORIG_ARGS=("$@")
  do_install=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      install) do_install=true; shift ;;
      *) shift ;;
    esac
  done
  echo "after parse: \$#=$# do_install=$do_install"
  echo "replay args: ${_ORIG_ARGS[@]+${_ORIG_ARGS[@]}}"
}
_run install --skip-gh-auth
echo "---- empty case ----"
_run
'