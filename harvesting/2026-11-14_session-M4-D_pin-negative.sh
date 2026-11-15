#!/usr/bin/env bash
# Negative tests for the pin embed in build-deploy.sh: extract the perl program
# verbatim from the script and run it against bad and good pin fixtures.
set -uo pipefail
WT=C:/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
S=$WT/.scratch/session-M4-D
F=$S/pin-fixtures
mkdir -p "$F"
export PERLIO=:perlio
perl -0777 -ne 'print $1 if /_pin_msg=\$\(perl -e \x27(.*?)\x27 "\$PYWINPTY_PIN"/s or die "program not found\n"' "$WT/scripts/build-deploy.sh" > "$F/embed.pl" || { echo "extract failed"; exit 1; }
echo "extracted program: $(wc -l < "$F/embed.pl") lines"
: > "$F/empty.txt"
printf '# comment only\n\n' > "$F/blank.txt"
printf '# no pin line\nrequests==1.0 \\\n    --hash=sha256:00\n' > "$F/noline.txt"
printf "pywinpty==3.1.2 \\\\\n    --hash=sha256:aa\n'@\n" > "$F/terminator.txt"
printf "pywinpty==3.1.2 \\\\\n    --hash=sha256:aa\n  '@ indented\n" > "$F/terminator-indented.txt"
printf 'pywinpty==3.1.2 \\\r\n    --hash=sha256:aa\r\n    --hash=sha256:bb' > "$F/crlf-nofinalnl.txt"
for c in missing.txt empty.txt blank.txt noline.txt terminator.txt terminator-indented.txt crlf-nofinalnl.txt; do
    rc=0
    msg=$(perl "$F/embed.pl" "$F/$c" "$F/$c.blk" 2>&1) || rc=$?
    echo "case $c: exit $rc: $msg"
done
echo "--- block for crlf-nofinalnl.txt (cat -v):"
cat -v "$F/crlf-nofinalnl.txt.blk"
rc=0
msg=$(perl "$F/embed.pl" "$WT/scripts/requirements-pywinpty.txt" "$F/real.blk" 2>&1) || rc=$?
echo "case real pin: exit $rc: $msg"
