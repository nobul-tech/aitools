#!/usr/bin/env bash
# Reproduce check-pre-push step 3 and print each hit with its file (values masked
# after 12 chars so a real secret is not echoed in full).
set -euo pipefail
cd /Users/new-jose/repos/aitools
git diff origin/main..HEAD | perl -ne '
  if (/^\+\+\+ b\/(.*)/) { $f = $1; next }
  next unless /^\+/;
  # Same semantics as the ERE in check-pre-push.sh step 3: [\s] there is a
  # bracket of backslash and "s" (incident #134), so match [\\s]* here.
  if (/(password|secret|api_key|api-key|apikey|token|bearer|private_key|AWS_ACCESS|ANTHROPIC_API)[\\s]*[=:]/i) {
    my $line = substr($_, 0, 160); chomp $line;
    print "$f\n    $line\n";
  }
'
