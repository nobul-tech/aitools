#!/usr/bin/env bash
# smoke-sh.sh ROOT -- run deploy-harness.sh --skip-config then setup-user-cursor.sh
# under ROOT/home (isolated), stdin /dev/null, rg/agent stubbed. Prints summaries.
set -uo pipefail
ROOT="$1"; A="$ROOT/aitools"; H="$ROOT/home"; O="$ROOT/out-sh"
mkdir -p "$O/bin"
printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$O/bin/rg"
printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$O/bin/agent"
chmod +x "$O/bin/rg" "$O/bin/agent"
run() { # run NAME SCRIPT ARGS...
    local n="$1"; shift
    : > "$O/$n.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_LOG_DIR -u AITOOLS_USER_REPO_PATH \
        HOME="$H" USERPROFILE="$H" AITOOLS_SUMMARY_FILE="$O/$n.summary" PATH="$O/bin:$PATH" NO_COLOR=1 \
        bash "$@" < /dev/null > "$O/$n.out" 2>&1
    echo "== $n exit $?"
    cat "$O/$n.summary"
}
run harness "$A/scripts/deploy-harness.sh" --skip-config
run cursor "$A/scripts/setup-user-cursor.sh"
echo "== ~/.cursor tree"
(cd "$H/.cursor" && find rules skills -maxdepth 2 | sort)
