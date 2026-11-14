#!/usr/bin/env bash
# bash-facts.sh -- what Git Bash resolves for python3/python (the test suites call python3)
set -uo pipefail
echo "bash: $BASH $BASH_VERSION"
for n in python3 python py; do
  printf '%-8s -> ' "$n"
  type -a "$n" 2>&1 | head -3 | tr '\n' ' '
  echo
done
echo "--- python3 --version"
python3 --version 2>&1
echo "exit: $?"
echo "--- python3 sys.executable"
python3 -c 'import sys; print(sys.executable, sys.version.split()[0])' 2>&1
echo "exit: $?"
echo "--- python3 -c import winpty"
python3 -c 'import winpty' 2>&1
echo "exit: $?"
