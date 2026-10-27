#!/usr/bin/env bash
# test-hookin.sh -- tests for the deploy-harness hook-ins: aitools-install.sh Step 8b
# and the deploy_configs loop of scripts/aitools (macOS/Linux)
#
# Each case builds a fixture aitools repo (git) whose scripts/ holds copies of the
# real aitools-install.sh, aitools, aitools-lib.sh and deploy-harness.sh, plus stub
# setup scripts (they record that they ran) and a stub config writer (it records
# its arguments). Everything runs under an isolated HOME in a temp directory,
# removed on exit; `claude` and `node` are stubs on PATH so the installer installs
# and updates nothing. The real HOME and the real repos are never touched.
# Cases:
#   static   -- installer has no ~/.aitools/bin step; Step 8b sits between Step 8
#               (Node) and Step 9 on both platforms; the sync deploy lists start with
#               deploy-harness and no longer list setup-user-config
#   install  -- deploy-harness runs once, bin is deployed by it, one run id in
#               deploy.jsonl, the writer runs at Step 5 and once inside Step 8b
#   install exit 1 -- a duplicate rule: ERROR row, the install continues, exit 1
#   install abort  -- [x]abort at a review menu (pty): exit 2, Step 9 not reached
#   loop     -- deploy_configs (extracted from scripts/aitools): writer runs once,
#               deploy-harness relayed to deploy.jsonl, the other 7 scripts run
#   loop exit 1 / loop abort (pty) -- as for the installer
#   ps loop / ps step -- the same for Deploy-Configs (aitools.ps1) and
#               Invoke-HarnessStep (aitools-install.ps1) under pwsh, through
#               tests/hookin/hookin-driver.ps1 (skipped without pwsh)
# Interactive cases use tests/managed-files/pty-run.py (python3); skipped without it.
# Platform: macOS, Linux. Exit 1 if any case fails.
#
# Usage: bash tests/hookin/test-hookin.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'next if $. == 1; last unless /^#/; s/^# ?//; print' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
HAVE_PTY=true
command -v python3 >/dev/null 2>&1 || HAVE_PTY=false
[ -f "$PTY" ] || HAVE_PTY=false

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 30
        fi
    fi
}
skip() { printf 'SKIP %s\n' "$1"; SKIP=$((SKIP + 1)); }

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

DEPLOY_STUBS="setup-user-claude setup-user-cursor setup-user-mcp setup-user-skills setup-cursor-ide-mcp setup-user-settings setup-user-hooks"

# setup_case NAME: fixture repo ($R), HOME ($H), stub bin ($B)
setup_case() {
    C="$TMP_ROOT/$1"; R="$C/repo"; H="$C/home"; B="$C/bin"
    mkdir -p "$R/scripts" "$R/reference" "$R/shared/hooks" "$R/shared/rules" "$R/.claude/rules" \
        "$H/.aitools" "$B" "$C/repos"
    cp "$ROOT/scripts/aitools-install.sh" "$ROOT/scripts/aitools" "$ROOT/scripts/aitools-lib.sh" \
        "$ROOT/scripts/deploy-harness.sh" "$R/scripts/"
    # Stub config writer: records its arguments (the installer passes flags at Step 5;
    # deploy-harness calls it bare)
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "called $*" >> "$HOME/writer-calls"\nexit 0\n' \
        > "$R/scripts/setup-user-config.sh"
    for s in $DEPLOY_STUBS; do
        printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" >> "$HOME/calls"\nexit 0\n' "$s" > "$R/scripts/$s.sh"
    done
    # PowerShell twins (tests/hookin/hookin-driver.ps1 runs them with pwsh): the lib,
    # deploy-harness.ps1 with its Windows guard disabled, and the same stubs
    cp "$ROOT/scripts/aitools-lib.ps1" "$R/scripts/"
    perl -pe 's/-ge 6 -and -not \$IsWindows\)/-ge 6 -and \$false)/' "$ROOT/scripts/deploy-harness.ps1" \
        > "$R/scripts/deploy-harness.ps1"
    printf 'param([switch]$DryRun)\nAdd-Content -Path (Join-Path $env:USERPROFILE "writer-calls") -Value ("called " + $(if ($DryRun) { "-DryRun" } else { "" }))\nexit 0\n' \
        > "$R/scripts/setup-user-config.ps1"
    for s in $DEPLOY_STUBS; do
        printf 'Add-Content -Path (Join-Path $env:USERPROFILE "calls") -Value "%s"\nexit 0\n' "$s" > "$R/scripts/$s.ps1"
    done
    for f in harness-db.py read-session.py read-session-full.py; do
        printf '#!/usr/bin/env python3\nprint("%s")\n' "$f" > "$R/scripts/$f"
        chmod +x "$R/scripts/$f"
    done
    printf '# Harness\n\nsource text\n' > "$R/reference/harness.md"
    printf '#!/usr/bin/env bash\necho hook\n' > "$R/shared/hooks/h1.sh"; chmod +x "$R/shared/hooks/h1.sh"
    printf 'shared rule\n' > "$R/shared/rules/r1.md"
    printf 'project rule\n' > "$R/.claude/rules/p1.md"
    git -C "$R" init -q
    gitc -C "$R" add -A
    gitc -C "$R" commit -q -m fixture
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s"\n}\n' "$C/repos" "$R" \
        > "$H/.aitools/config.json"
    printf '#!/usr/bin/env bash\ncase "$1" in\n  --version) echo "9.9.9 (stub)" ;;\n  update) echo "already up to date" ;;\nesac\nexit 0\n' > "$B/claude"
    printf '#!/usr/bin/env bash\necho v22.0.0\n' > "$B/node"
    chmod +x "$B/claude" "$B/node"
}

# add_duplicate_rule: the same rule name in shared/rules and .claude/rules -> deploy-harness exit 1
add_duplicate_rule() {
    printf 'dup a\n' > "$R/shared/rules/dup.md"
    printf 'dup b\n' > "$R/.claude/rules/dup.md"
    gitc -C "$R" add -A
    gitc -C "$R" commit -q -m dup
}

# run_env [input] -- CMD...: run CMD under the case HOME (stdin /dev/null, or a pty with input)
run_env() {
    local input="$1"; shift
    [ "${1:-}" = "--" ] && shift
    : > "$C/summary"
    : > "$H/calls"
    if [ -z "$input" ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_RUN_ID -u AITOOLS_SUPPRESS_SUMMARY_DISPLAY \
            HOME="$H" PATH="$B:$PATH" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
            "$@" < /dev/null > "$C/out" 2>&1
        echo $? > "$C/rc"
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_RUN_ID -u AITOOLS_SUPPRESS_SUMMARY_DISPLAY \
            HOME="$H" PATH="$B:$PATH" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
            python3 "$PTY" --input "$input" --log "$C/out" -- "$@"
        echo $? > "$C/rc"
    fi
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

run_install() {  # run_install [input]
    # SUPPRESS: as under `aitools install` -- show_summary would render and delete the file
    run_env "${1:-}" -- env AITOOLS_SUPPRESS_SUMMARY_DISPLAY=1 bash "$R/scripts/aitools-install.sh" --skip-gh-auth --skip-drive-detection --repos-path "$C/repos"
}

# The loop driver: deploy_abort + deploy_configs extracted from scripts/aitools
# (top-level functions inside main()), run with the lib loaded as aitools loads it.
LOOP_FUNCS="$TMP_ROOT/loop-funcs.sh"
perl -ne 'print if /^deploy_abort\(\) \{/ .. /^\}/; print if /^deploy_configs\(\) \{/ .. /^\}/' \
    "$ROOT/scripts/aitools" > "$LOOP_FUNCS"
LOOP_DRIVER="$TMP_ROOT/loop-driver.sh"
cat > "$LOOP_DRIVER" <<'EOF'
#!/usr/bin/env bash
# loop-driver.sh SCRIPTS_DIR FUNCS -- run deploy_configs SCRIPTS_DIR as scripts/aitools does
source "$1/aitools-lib.sh"
logging_init "aitools"
LOG_DISPLAY="$LOG_FILE"
dry_run=false
force=false
show_cloud_mcp() { :; }
source "$2"
deploy_configs "$1"
printf 'LOOP rc=%s aborted=%s\n' "$?" "$deploy_aborted"
EOF

run_loop() {  # run_loop [input]
    run_env "${1:-}" -- bash "$LOOP_DRIVER" "$R/scripts" "$LOOP_FUNCS"
}

rc() { cat "$C/rc"; }
row() { grep -qxF "$1" "$C/summary"; }
calls() { perl -pe 's/\n/ /' "$H/calls"; }
count() { grep -c -- "$1" "$2"; }   # count LINES-MATCHING FILE

ALL_STUBS="setup-user-claude setup-user-cursor setup-user-mcp setup-user-skills setup-cursor-ide-mcp setup-user-settings setup-user-hooks "
LOOP_STUBS="setup-user-claude setup-user-mcp setup-user-skills setup-cursor-ide-mcp setup-user-cursor setup-user-settings setup-user-hooks "

# ---------------------------------------------------------------------------
# Static checks (both platforms' files)
# ---------------------------------------------------------------------------
C=""
for f in aitools-install.sh aitools-install.ps1; do
    check "static: $f has no harness bin step" \
        "! grep -qE 'harness bin|_hbin_deployed|hbinDeployed' '$ROOT/scripts/$f'"
    check "static: $f Step 8b between Step 8 (Node) and Step 9" \
        "perl -ne '\$a=\$. if /Step 8: Node/; \$b=\$. if /Step 8b: Deployed harness\"/; \$c=\$. if /Step 9: Claude/; END { exit((\$a && \$b && \$c && \$a < \$b && \$b < \$c) ? 0 : 1) }' '$ROOT/scripts/$f'"
done
check "static: aitools deploy lists start with deploy-harness, no setup-user-config" \
    "[ \"\$(grep -cE '^ +local deploy_scripts=\"deploy-harness\.(sh|ps1) ' '$ROOT/scripts/aitools')\" = 2 ] && ! grep -qE '^ +local deploy_scripts=.*setup-user-config' '$ROOT/scripts/aitools'"
check "static: aitools.ps1 deploy list starts with deploy-harness, no setup-user-config" \
    "grep -qE '^ +\\\$deployScripts = @\\(\"deploy-harness\.ps1\", ' '$ROOT/scripts/aitools.ps1' && ! grep -qE '^ +\\\$deployScripts = .*setup-user-config' '$ROOT/scripts/aitools.ps1'"
check "static: loop functions extracted" "grep -q '^deploy_abort() {' '$LOOP_FUNCS' && grep -q '^deploy_configs() {' '$LOOP_FUNCS'"

# ---------------------------------------------------------------------------
# Installer
# ---------------------------------------------------------------------------
setup_case install
run_install
check "install: exit 0" "[ \"\$(rc)\" = 0 ]"
check "install: Step 8b runs once, after Step 8 and before Step 9" \
    "perl -ne '\$n++ if /\] Step 8b: Deployed harness\$/; \$a=\$. if /Step 8: Node/ && !\$a; \$b=\$. if /Step 8b: Deployed/ && !\$b; \$c=\$. if /Step 9: Claude/ && !\$c; END { exit((\$n == 1 && \$a < \$b && \$b < \$c) ? 0 : 1) }' '$C/out'"
check "install: deploy-harness ran once (one summary row)" "[ \"\$(count '|harness files|' '$C/summary')\" = 1 ] && row 'OK|harness files|7 added'"
check "install: bin deployed by deploy-harness, executable" \
    "[ -x '$H/.aitools/bin/harness-db.py' ] && [ -x '$H/.aitools/bin/read-session.py' ] && [ -x '$H/.aitools/bin/read-session-full.py' ]"
check "install: no harness bin row" "! grep -q 'harness bin' '$C/summary'"
check "install: writer at Step 5 (flags) and once bare inside Step 8b" \
    "[ \"\$(count '^called --repos-path' '$H/writer-calls')\" = 1 ] && [ \"\$(count '^called \$' '$H/writer-calls')\" = 1 ] && [ \"\$(wc -l < '$H/writer-calls' | tr -d ' ')\" = 2 ]"
check "install: deploy-harness lines relayed to deploy.jsonl" "grep -q '\"script\":\"deploy-harness\"' '$C/logs/deploy.jsonl'"
check "install: one run id in deploy.jsonl" \
    "perl -ne '\$r{\$1}=1 if /\"run_id\":\"([^\"]*)\"/; END { exit(keys(%r) == 1 ? 0 : 1) }' '$C/logs/deploy.jsonl'"
check "install: Step 21 scripts ran" "[ \"\$(calls)\" = '$ALL_STUBS' ]"
run_install
check "install rerun: verified" "[ \"\$(rc)\" = 0 ] && row 'OK|harness files|7 verified'"

setup_case install-err
add_duplicate_rule
run_install
check "install exit 1: ERROR row, install continued, exit 1" \
    "[ \"\$(rc)\" = 1 ] && row 'ERROR|harness files|script failed (exit 1)' && grep -q 'Step 9: Claude' '$C/out' && [ \"\$(calls)\" = '$ALL_STUBS' ]"

if $HAVE_PTY; then
    setup_case install-abort
    run_install
    printf 'local edit\n' > "$H/.aitools/hooks/h1.sh"
    run_install 'x\n'
    check "install abort: exit 2, Step 9 and Step 21 not run" \
        "[ \"\$(rc)\" = 2 ] && ! grep -q 'Step 9: Claude' '$C/out' && [ ! -s '$H/calls' ]"
    check "install abort: WARN row, file unchanged" \
        "row 'WARN|harness files|aborted by user' && grep -qx 'local edit' '$H/.aitools/hooks/h1.sh'"
else
    skip "install abort (no python3 / pty-run.py)"
fi

# ---------------------------------------------------------------------------
# deploy_configs (scripts/aitools sync loop)
# ---------------------------------------------------------------------------
setup_case loop
run_loop
check "loop: rc 0, not aborted" "grep -qx 'LOOP rc=0 aborted=false' '$C/out'"
check "loop: writer runs once (inside deploy-harness)" \
    "[ \"\$(wc -l < '$H/writer-calls' | tr -d ' ')\" = 1 ] && [ \"\$(count '^called \$' '$H/writer-calls')\" = 1 ]"
check "loop: deploy-harness first, then the 7 scripts" \
    "[ \"\$(calls)\" = '$LOOP_STUBS' ] && row 'OK|harness files|7 added'"
check "loop: deploy-harness lines relayed to deploy.jsonl" "grep -q '\"script\":\"deploy-harness\"' '$C/logs/deploy.jsonl'"

setup_case loop-err
add_duplicate_rule
run_loop
check "loop exit 1: one error counted, ERROR row, the 7 scripts ran" \
    "grep -qx 'LOOP rc=1 aborted=false' '$C/out' && row 'ERROR|harness files|script failed (exit 1)' && [ \"\$(calls)\" = '$LOOP_STUBS' ]"

if $HAVE_PTY; then
    setup_case loop-abort
    run_loop
    printf 'local edit\n' > "$H/.aitools/rules/p1.md"
    run_loop 'x\n'
    check "loop abort: aborted, no later script ran" \
        "grep -q 'LOOP rc=0 aborted=true' '$C/out' && [ ! -s '$H/calls' ] && row 'WARN|harness files|aborted by user'"
else
    skip "loop abort (no python3 / pty-run.py)"
fi

# ---------------------------------------------------------------------------
# PowerShell: Deploy-Configs (aitools.ps1) and Invoke-HarnessStep
# (aitools-install.ps1), loaded from the real files by hookin-driver.ps1
# ---------------------------------------------------------------------------
DRIVER="$ROOT/tests/hookin/hookin-driver.ps1"
run_ps() {  # run_ps MODE [input]
    run_env "${2:-}" -- env USERPROFILE="$H" pwsh -NoProfile -File "$DRIVER" -Mode "$1" -ScriptsDir "$R/scripts" -RepoRoot "$ROOT"
}
if command -v pwsh >/dev/null 2>&1; then
    check "ps: driver guard check (fixture deploy-harness.ps1 guard disabled)" \
        "grep -q -- '-ge 6 -and \\\$false)' '$TMP_ROOT/loop/repo/scripts/deploy-harness.ps1'"

    setup_case ps-loop
    run_ps loop
    check "ps loop: rc 0, not aborted" "grep -qx 'LOOP rc=0 aborted=False' '$C/out'"
    check "ps loop: writer runs once (inside deploy-harness)" \
        "[ \"\$(wc -l < '$H/writer-calls' | tr -d ' ')\" = 1 ] && [ \"\$(count '^called \$' '$H/writer-calls')\" = 1 ]"
    check "ps loop: deploy-harness first, then the 7 scripts" \
        "[ \"\$(calls)\" = '$LOOP_STUBS' ] && row 'OK|harness files|7 added'"
    check "ps loop: deploy-harness lines relayed to deploy.jsonl" "grep -q '\"script\":\"deploy-harness\"' '$C/logs/deploy.jsonl'"

    setup_case ps-loop-err
    add_duplicate_rule
    run_ps loop
    check "ps loop exit 1: one error counted, ERROR row, the 7 scripts ran" \
        "grep -qx 'LOOP rc=1 aborted=False' '$C/out' && row 'ERROR|harness files|script failed (exit 1)' && [ \"\$(calls)\" = '$LOOP_STUBS' ]"

    setup_case ps-step
    run_ps step
    check "ps step: returns 0, one OK row" "grep -qx 'STEP rc=0' '$C/out' && row 'OK|harness files|7 added' && [ \"\$(count '|harness files|' '$C/summary')\" = 1 ]"
    check "ps step: bin deployed" "[ -f '$H/.aitools/bin/harness-db.py' ]"

    setup_case ps-step-err
    add_duplicate_rule
    run_ps step
    check "ps step exit 1: returns 0 (install continues), ERROR row" \
        "grep -qx 'STEP rc=0' '$C/out' && row 'ERROR|harness files|script failed (exit 1)'"

    setup_case ps-step-missing
    rm -f "$R/scripts/deploy-harness.ps1"
    run_ps step
    check "ps step missing script: WARN row" "grep -qx 'STEP rc=0' '$C/out' && row 'WARN|harness files|deploy-harness.ps1 not found'"

    if $HAVE_PTY; then
        setup_case ps-loop-abort
        run_ps loop
        printf 'local edit\n' > "$H/.aitools/rules/p1.md"
        run_ps loop 'x\n'
        check "ps loop abort: aborted, no later script ran, WARN row" \
            "grep -q 'LOOP rc=0 aborted=True' '$C/out' && [ ! -s '$H/calls' ] && row 'WARN|harness files|aborted by user'"
        check "ps loop abort: abort line logged as [aitools]" \
            "grep -q '\[aitools\] \[info\] deploy-harness.ps1: aborted by user' '$LOG'"

        setup_case ps-step-abort
        run_ps step
        printf 'local edit\n' > "$H/.aitools/rules/p1.md"
        run_ps step 'x\n'
        check "ps step abort: returns 2, WARN row, file unchanged" \
            "grep -q 'STEP rc=2' '$C/out' && row 'WARN|harness files|aborted by user' && grep -qx 'local edit' '$H/.aitools/rules/p1.md'"
    else
        skip "ps abort cases (no python3 / pty-run.py)"
    fi
else
    skip "PowerShell cases (pwsh not found)"
fi

printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
