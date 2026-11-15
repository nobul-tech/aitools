#!/usr/bin/env bash
# Time one isolated build-deploy.sh run (fixture dotprofile, stub pwsh, temp HOME).
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
S=$WT/.scratch/session-M4-E
T=$(mktemp -d)
mkdir -p "$T/home/.aitools" "$T/bin" "$T/dot"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/pwsh"
chmod +x "$T/bin/pwsh"
git -C "$T/dot" init -q
printf '.scratch/\n*.bak.*\n' > "$T/dot/.gitignore"
printf '# fixture\n' > "$T/dot/README.md"
git -C "$T/dot" add -A
git -C "$T/dot" -c user.email=t@e.invalid -c user.name=t commit -q -m fixture
start=$(date +%s)
env -u AITOOLS_SUMMARY_FILE HOME="$T/home" USERPROFILE="$(cygpath -m "$T/home")" AITOOLS_USER_REPO_PATH="$(cygpath -m "$T/dot")" PATH="$T/bin:$PATH" \
    bash "$WT/scripts/build-deploy.sh" < /dev/null > "$S/time-build.log" 2>&1
rc=$?
end=$(date +%s)
echo "stub-pwsh build: exit $rc, $((end - start)) s"
ls "$T/dot/deploy" | wc -l
ls -la "$T/dot/deploy/setup-pywinpty.ps1" "$T/dot/deploy/setup-pywinpty.sh"
start=$(date +%s)
env -u AITOOLS_SUMMARY_FILE HOME="$T/home" USERPROFILE="$(cygpath -m "$T/home")" AITOOLS_USER_REPO_PATH="$(cygpath -m "$T/dot")" \
    bash "$WT/scripts/build-deploy.sh" < /dev/null > "$S/time-build-realpwsh.log" 2>&1
rc=$?
end=$(date +%s)
echo "real-pwsh build: exit $rc, $((end - start)) s"
rm -rf "$T"
