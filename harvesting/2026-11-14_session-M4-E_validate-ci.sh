#!/usr/bin/env bash
# Validate check.yml: YAML parse (python yaml if available, else ruby/node), and run the
# "Every test suite is in CI" perl check against the working tree (incl. staged new suite).
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
cd "$WT"
if python -c "import yaml" 2>/dev/null; then
    python -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/check.yml',encoding='utf-8')); print('yaml ok (PyYAML):', {k: len(v['steps']) for k, v in d['jobs'].items()})"
else
    echo "PyYAML not available"
    node -e "try { require('yaml') ; console.log('node yaml present') } catch (e) { console.log('node yaml absent') }"
fi
echo "--- FO-0 check (perl block copied from check.yml)"
perl -0777 -ne 'print $1 if /git ls-files .tests\/\*\/test-\*\.sh. \| perl -e \x27(.*?)\n\s*\x27\n/s' .github/workflows/check.yml > "$WT/.scratch/session-M4-E/fo0.pl"
wc -l "$WT/.scratch/session-M4-E/fo0.pl"
git ls-files 'tests/*/test-*.sh' | perl "$WT/.scratch/session-M4-E/fo0.pl"
echo "fo0 rc=$?"
git ls-files 'tests/*/test-*.sh' | grep pywinpty
