#!/bin/bash
# Read-only probes for S4-Review-B (no installs, no writes outside stdout)
set -u
echo "== /bin/bash"; /bin/bash --version | head -1
echo "== PATH bash"; command -v bash; bash --version | head -1
echo "== realpath/readlink"; command -v realpath; ls -l /bin/realpath 2>&1; readlink -f /opt/homebrew/bin/node 2>&1
echo "== perl"; command -v perl; /usr/bin/perl -v | head -2
/usr/bin/perl -MJSON::PP -e 'print "JSON::PP $JSON::PP::VERSION\n"' 2>&1
/usr/bin/perl -MCwd -e 'print "abs_path node: ", (Cwd::abs_path(q{/opt/homebrew/bin/node}) // "undef"), "\n"; print "abs_path missing: ", (Cwd::abs_path(q{/nonexistent/x}) // "undef"), "\n"'
echo "== node resolution"; command -v node; ls -l /opt/homebrew/bin/node 2>&1
echo "== brew"; command -v brew
if command -v brew >/dev/null 2>&1; then
  echo "prefix node: $(brew --prefix node 2>&1)"
  echo "list node: $(brew list --versions node 2>&1)"; echo "rc=$?"
  echo "list node@22: $(brew list --versions node@22 2>&1)"
  echo "prefix go: $(brew --prefix go 2>&1)"
  brew list --versions go >/dev/null 2>&1; echo "list go rc=$?"
  brew list --versions definitely-not-a-formula-xyz >/dev/null 2>&1; echo "list bogus rc=$?"
  /usr/bin/time -p brew list --versions node >/dev/null 2>/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-B-scratch/time.txt; cat /Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-B-scratch/time.txt
  /usr/bin/time -p brew --prefix node >/dev/null 2>/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-B-scratch/time.txt; cat /Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-B-scratch/time.txt
  rm -f /Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-B-scratch/time.txt
fi
echo "== go"; command -v go; ls -l "$(command -v go 2>/dev/null)" 2>&1
pkgutil --pkg-info=org.golang.go >/dev/null 2>&1; echo "pkgutil go rc=$?"
echo "== python3 stub"; command -v python3; ls -l /usr/bin/python3 2>&1
echo "== uv tool dir"; command -v uv && uv tool dir --bin 2>&1
echo "== npm prefix"; command -v npm && npm prefix -g 2>&1
echo "== case-sensitivity of /"; diskutil info / 2>/dev/null | grep -i "File System Personality"
