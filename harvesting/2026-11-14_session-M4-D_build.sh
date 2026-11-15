#!/usr/bin/env bash
# Isolated MDM build: copy the dotprofile into scratch, run build-deploy.sh with HOME
# and AITOOLS_USER_REPO_PATH pointing into scratch. Never touches the real dotprofile.
set -uo pipefail
WT=C:/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
S=$WT/.scratch/session-M4-D
SRC=C:/Users/jdpal/repos/aitools-nobul-jose
COPY=$S/dotprofile
if [ ! -d "$COPY" ]; then
    cp -R "$SRC" "$COPY" || { echo "copy failed"; exit 1; }
    echo "copied $SRC -> $COPY"
fi
mkdir -p "$S/home"
export HOME="$S/home"
export USERPROFILE="$S/home"
export AITOOLS_USER_REPO_PATH="$COPY"
export AITOOLS_LOG_DIR="$S/home/logs"
unset AITOOLS_SUMMARY_FILE
rc=0
bash "$WT/scripts/build-deploy.sh" > "$S/build.log" 2>&1 || rc=$?
echo "build-deploy exit: $rc"
grep -n -e pywinpty -e "Build complete" -e "\[error\]" -e "PS1 files passed" "$S/build.log"
ls -la "$COPY/deploy/setup-pywinpty.ps1" "$COPY/deploy/setup-pywinpty.sh"
if bash -n "$COPY/deploy/setup-pywinpty.sh"; then echo "bash -n OK: deploy/setup-pywinpty.sh"; else echo "bash -n FAIL deploy/setup-pywinpty.sh"; fi
pwsh -NoProfile -File "$S/parse.ps1" "$COPY/deploy/setup-pywinpty.ps1"
echo "parse exit: $?"
echo "--- here-string and pin lines in deploy/setup-pywinpty.ps1 ---"
grep -n -e "AitoolsEmbeddedPywinptyPin" -e "^'@" -e "Embedded by scripts/build-deploy.sh" -e "pywinpty==" "$COPY/deploy/setup-pywinpty.ps1"
echo "hash lines: $(grep -c -e '--hash=sha256:' "$COPY/deploy/setup-pywinpty.ps1")"
for h in 197cb43a5a1c6ed5836907fdcb3f008883386bcdaa05ae0cfdf4848b3624e237 a58997fa8519694725dca4a297aa7bebada3675263742cfb12fbc5eb09d466e7 220e30a8cccd7f0be3356d4e3e56fdcda2ae45edc1de526b440c4031fe9308da d968dc4300b497f048318387781ed9931dc0038815f25b4f642a1749448769cb 980af688956fe78c87882682732e6eea45aa0b8d10a9628812e95878264d5204 fe0abcffd095642c78ba7c6abf4cc8129dce9568e97a1c9194eea23383d0de29 b8c47556fbf19595898dd75f45763072ff1160b080eefabeae8cc43c5acbd720 ed5c5ca288001590fbf1d5a52c6389f0f6ae7e4751bdc8b2f8f9c7249f266f9b; do
    if grep -q "sha256:$h" "$COPY/deploy/setup-pywinpty.ps1"; then echo "hash present: ${h:0:12}"; else echo "HASH MISSING: $h"; fi
done
echo "CRLF lines: $(grep -c $'\r$' "$COPY/deploy/setup-pywinpty.ps1") of $(wc -l < "$COPY/deploy/setup-pywinpty.ps1")"
