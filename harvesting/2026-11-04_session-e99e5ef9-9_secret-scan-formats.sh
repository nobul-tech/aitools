#!/usr/bin/env bash
# Independent scan of origin/main..HEAD added lines for real credential formats
# (prints file + masked match only).
set -euo pipefail
cd /Users/new-jose/repos/aitools
git diff origin/main..HEAD | perl -ne '
  if (/^\+\+\+ b\/(.*)/) { $f = $1; next }
  next unless /^\+/;
  while (/(sk-ant-[A-Za-z0-9_-]{10,}|sk-[A-Za-z0-9]{32,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[abpr]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AIza[0-9A-Za-z_-]{35}|(?:dd|DD)_(?:API|APP)_KEY\s*[=:]\s*["\x27]?[0-9a-f]{32}|Authorization:\s*Bearer\s+[A-Za-z0-9._-]{20,}|(?:password|passwd|secret|api[_-]?key|token)\s*[=:]\s*["\x27][^"\x27\s]{16,}["\x27])/g) {
    my $m = $1; $m = substr($m, 0, 14) . "...(" . length($m) . " chars)";
    print "$f: $m\n";
  }
'
echo "scan done"
