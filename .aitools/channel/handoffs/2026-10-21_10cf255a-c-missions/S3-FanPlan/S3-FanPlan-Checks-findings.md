# S3-FanPlan-Checks findings: check scripts, CI, tests, Cursor twins

Explorer S3-FanPlan-Checks (level 2, under S3-FanPlan), 2026-10-26. Read only.
Reading copy: `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/` at
480b901 (origin/main). All `file:line` below are in that copy unless a PR is named.

## 1. Summary (5 lines)

1. No check step blocks a rules fan-out by itself. The steps that will react are pre-commit 13 (WARN unless `build-deploy.sh` is staged with `setup-user-claude.*`), pre-commit 6 (exec bit on new `tests/rules-fanout/*.sh`), pre-commit 20 (any doc that cites `tests/rules-fanout/...` before it exists), and post-push 30/31 (a new tracker outcome such as `removed` must go into both libs, and `setup-user-claude.sh/.ps1` must mention every `MANAGED_FILE_RESULT` value).
2. Pre-push step 7 smoke-runs the generated `setup-user-claude.sh --dry-run` in a HOME that has no `~/.aitools/rules`, and once more as an endpoint (`config.json` = `{}`). The fan-out must exit 0 or 1 there and still print `Profile source: live` / `Profile source: embedded build-time snapshot`. Exit 2 or higher fails the push.
3. CI (`.github/workflows/check.yml`) runs only `tests/logging`, `tests/managed-files` and `tests/profile`. The tests already on main in `tests/rules-fanout-cursor/`, `tests/deploy-harness/` and `tests/deploy-harness-mdm/` are not in CI. A `tests/rules-fanout/` suite needs explicit steps in the macos and linux jobs, plus a `/bin/bash` 3.2 step on macos.
4. Open PR #112 adds `tests/claude-mdm/test-claude-mdm.sh` and a CI step for it. Its MDM case asserts `~/.claude/rules/r1.md` is deployed straight from the dotprofile. The fan-out breaks that assertion unless the fixture seeds `~/.aitools/rules`.
5. Two Cursor twins are stale against their `.claude` rules: `deploy-paths.mdc` and `managed-file-deployment.mdc`. Open PRs #99 and #101 rewrite them. The fan-out needs twin edits to the "Rules: additive deploy from `<userRepoPath>/claude/rules/`" bullet and the deploy-paths text, and those edits rebase on #99/#101. All of these files are protected, so drafts only.

## 2. Files read in full (path, lines)

Scripts (all read in full): `scripts/check-pre-commit.sh` (506), `check-pre-commit.ps1` (404), `check-pre-push.sh` (274), `check-pre-push.ps1` (323), `check-post-push.sh` (860), `check-post-push.ps1` (999), `check-script-compliance.sh` (351), `check-script-compliance.ps1` (315), `check-prereq-detection.sh` (189), `check-prereq-detection.ps1` (263), `check-lib.sh` (204), `check-lib.ps1` (200), `check-path-refs.py` (204), `check-path-refs-allow.txt` (41), `check-hook-parity.py` (112), `_validate-ps1.ps1` (8), `githooks/pre-commit` (19), `init-logging.sh` (8), `init-logging.ps1` (7), `scripts/README.md` (128).

CI: `.github/workflows/check.yml` (471).

Tests: `tests/profile/test-config.sh` (527), `test-user-init.sh` (498), `user-init-harness.ps1` (36), `test-lib.sh` (646), `test-profile.sh` (1198); `tests/logging/test-logging.sh` (142), `test-logging.ps1` (157). Outside the named slice, because they are the closest pattern: `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` (304), `convert-rule.ps1` (19), `tests/deploy-harness/test-deploy-harness.sh` (281), `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (297). Partly read: `tests/managed-files/test-managed-files.sh`, lines 1-80 and 300-349.

Cursor rules: all 18 `.mdc` files in full. The launch prompt said 19, but `find` lists 18: managed-file-deployment (68), config-file-safety (66), hook-rollout (32), deploy-paths (41), sources-of-truth (44), documentation-standards (46), cursor-rule-parity (9), tool-lifecycle (139), cross-platform (82), relay-outbound (19), git-safety (36), agentic-standards (158), script-standards (143), general (15), interactive-menus (30), web-sources (38), plan-execution (12), smoke-test-pattern (17).

Checklists: `reference/pre-commit-checklist.md` (83), `pre-push-checklist.md` (55), `post-push-checklist.md` (255).

Lib excerpts, for steps 29-31: `scripts/aitools-lib.sh` 2260-2339 (tracker) plus a grep of `MANAGED_FILE_RESULT=` and the menu `printf`s; `scripts/aitools-lib.ps1` 2255-2334 plus the matching grep.

Rules: the packet, the explorer brief, user CLAUDE.md, concurrent-agents.md, delegation.md, project CLAUDE.md, `.aitools/channel/CLAUDE.md`, and every `.claude/rules/*.md` named in the packet. Main-checkout copies, which were loaded into context.

**Not read (gap):** `plans/tool-support-and-machine-profile.md`, the prior handoff `2026-10-21_360aa8f3-8.md`, and the reference subset (script-standards-detail, cross-platform-detail, logging, managed-file-deployment, plan-execution-detail). None of the findings below depend on them, but the planner should not assume I checked them.

PR diffs read: the slice files of open PRs #99, #101, #110 (tests), #112 (CI + `tests/claude-mdm/`), #116 (CI). PR file list from `gh pr list -R nobul-tech/aitools --state open`.

## 3. Current behaviour, with verbatim code

### 3.1 Pre-commit

**Step 3, build freshness** (`check-pre-commit.sh:106-121`). With `--fix` it runs `build-deploy.sh` against the **real HOME**:
```bash
106	build_needed=false
107	if echo "$STAGED_FILES" | grep -E '^(scripts/|shared/)' | grep -qvE 'README\.md$'; then
108	    build_needed=true
109	fi
110	
111	if $build_needed; then
112	    if $FIX_MODE; then
113	        bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1
114	        git add deploy/ 2>/dev/null
```
PS1 twin: `check-pre-commit.ps1:103-123`, same behaviour.

**Step 6, exec bit** (`check-pre-commit.sh:162`). The pathspec `'*.sh'` matches every tracked `.sh` in every directory, so new `tests/rules-fanout/*.sh` files must be 100755:
```bash
162	non_exec=$(git ls-files -s '*.sh' 2>/dev/null | grep -v '^100755' || true)
```

**Step 8, config merge safety** (`check-pre-commit.sh:192-207`). WARN on an added line in a staged `scripts/setup-*` diff that matches:
```bash
199	    if echo "$diff_output" | grep -qE '^\+.*cat[[:space:]]*>|^\+.*WriteAllText.*ConvertTo-Json'; then
```

**Step 13, deploy template sync** (`check-pre-commit.sh:263-280`). The deploy-paths.md drift check:
```bash
263	HAS_SETUP_USER=false
264	HAS_BUILD_DEPLOY=false
265	for f in $STAGED_FILES; do
266	    case "$f" in
267	        scripts/setup-user-claude.*|scripts/setup-user-cursor.*|scripts/setup-user-mcp.*|scripts/setup-user-hooks.*)
268	            HAS_SETUP_USER=true ;;
269	        scripts/build-deploy.sh)
270	            HAS_BUILD_DEPLOY=true ;;
271	    esac
272	done
273	
274	if [ "$HAS_SETUP_USER" = true ] && [ "$HAS_BUILD_DEPLOY" = false ]; then
275	    step_warn "13" "Deploy template sync" "scripts/setup-user-* changed without build-deploy.sh -- verify deploy template is up to date"
```
PS1 twin (`check-pre-commit.ps1:261-272`):
```powershell
261	$hasSetupUser = $stagedFiles | Where-Object {
262	    $_ -match '^scripts/setup-user-(claude|cursor|mcp|hooks)\.'
263	}
264	$hasBuildDeploy = $stagedFiles -contains 'scripts/build-deploy.sh'
```
The step looks only at file names, per commit. It does not cover `scripts/deploy-harness.*` or `scripts/aitools-lib.*`.

**Step 15, deprecated summary terms** (`check-pre-commit.sh:321-322`). It FAILs on any `write_summary ... "unchanged"` in a non-check script:
```bash
321	hits=$(grep -rn 'write_summary.*"unchanged"' scripts/ --include='*.sh' | grep -v '^scripts/check-' || true)
322	hits_ps1=$(grep -rn 'Write-Summary.*"unchanged"' scripts/ --include='*.ps1' | grep -v '^scripts/check-' || true)
```

**Step 16, capability bypass** (`check-pre-commit.sh:343-345`). Scope is `.claude/rules/`, `.cursor/rules/` and `CLAUDE.md`, and table rows are exempt:
```bash
343	hits=$(grep -rnE '@?(reference|registries)/[a-z0-9-]*\.json' .claude/rules/ .cursor/rules/ CLAUDE.md \
344	    | perl -ne 'print if /glossary\.json|framework-registry\.json|incidents\.json|tool-registry\.json|tool-ops\.json/' \
345	    | grep -v '^.*:.*|.*|.*|.*|' || true)
```
PS1: `check-pre-commit.ps1:330-356`, same governed list.

**Step 20, path references** (`check-pre-commit.sh:474-495` and `check-path-refs.py`). Scan set (`check-path-refs.py:53-65`):
```python
53	SCAN = (
54	    (".claude/skills", "*.md", True),
55	    ("shared/skills", "*.md", True),
56	    (".claude/rules", "*.md", False),
57	    (".cursor/rules", "*.mdc", False),
58	    ("reference", "*.md", False),
59	    ("shared/hooks", "*.sh", False),
60	    ("scripts", "*.sh", False),
61	    ("scripts", "*.ps1", False),
62	    ("scripts", "*.py", False),
63	)
64	CODE_SUFFIXES = (".sh", ".ps1", ".py")
65	SCAN_FILES = ("CLAUDE.md", "shared/claude-shared.md", "shared/README.md")
```
- In markdown, backticked or `@` tokens starting with a top-level dir (`tests/` is one, `TOP_DIRS` line 47-50) must exist.
- In code files, only literal `registries/<x>.json` and `reference/<x>.(md|json)` tokens are checked (line 69).
- Skipped: `~/` paths, placeholders (`<>{}*?$| `), git-ignored paths.
- Exemptions: an allowlist line `file|path|reason`, or the marker `path-ref: ignore`.

**Step 2, syntax** (`check-pre-commit.sh:51-101`). Every staged `.sh` gets `bash -n` and every staged `.ps1` gets the pwsh parser, whatever its directory (so tests are included).

### 3.2 Pre-push

**Step 7** (`check-pre-push.sh:123-229`, PS1 `check-pre-push.ps1:126-277`).

Trigger regex (line 123):
```bash
123	deploy_sources=$(echo "$PUSH_FILES" | grep -E '^(scripts/(setup-.*|build-deploy|aitools-lib|aitools-profile)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|shared/)' || true)
```

Isolation. The build runs with the temp HOME and a temp dotprofile copy (lines 131-148):
```bash
147	        env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
148	            HOME="$d7_tmp/home" AITOOLS_USER_REPO_PATH="$d7_tmp/dot" bash "$REPO_ROOT/scripts/build-deploy.sh"
```

Smoke run of the generated scripts (lines 179-198). This is the part the fan-out must keep passing:
```bash
179	        for d7_s in setup-user-claude.sh setup-user-settings.sh setup-user-cursor.sh; do
...
183	            d7_s_out=$(env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
184	                HOME="$d7_tmp/home" AITOOLS_LOG_DIR="$d7_tmp/logs" AITOOLS_USER_REPO_PATH="$d7_tmp/dot" \
185	                AITOOLS_SUMMARY_FILE="$d7_sum" \
186	                bash "$d7_tmp/dot/deploy/$d7_s" --dry-run < /dev/null 2>&1) || d7_s_rc=$?
...
190	            if [ "$d7_s_rc" -gt 1 ]; then
191	                d7_smoke="$d7_smoke $d7_s(exit $d7_s_rc)"
192	            elif printf '%s\n' "$d7_s_out" | grep -q 'resolver missing' || grep -q 'resolver missing' "$d7_sum"; then
193	                d7_smoke="$d7_smoke $d7_s(resolver missing)"
194	            elif [ "$d7_s" = "setup-user-claude.sh" ] && [ -f "$d7_tmp/dot/profile.json" ] \
195	                && ! printf '%s\n' "$d7_s_out" | grep -q 'Profile source: live'; then
196	                d7_smoke="$d7_smoke $d7_s(live profile not used)"
```
Endpoint case (lines 202-217): `HOME=$d7_tmp/endpoint`, `config.json` = `{}`, no `AITOOLS_USER_REPO_PATH`. The output must contain `Profile source: embedded build-time snapshot`. In both runs `$d7_tmp/home` and the endpoint HOME have **no `~/.aitools/rules`**.

### 3.3 Post-push

**Step 7** (`check-post-push.sh:204-211`). It runs `build-deploy.sh` against the **real HOME** on every run, then diffs the frozen `aitools/deploy/`:
```bash
204	bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1
205	drift=$(git diff deploy/ 2>/dev/null || true)
```
`build-deploy.sh:218` is `DEPLOY_DIR="$_urp/deploy"` (the dotprofile), so this run rebuilds the real dotprofile `deploy/`. PS1 twin: `check-post-push.ps1:233-244`.

**Step 19, config merge audit** (`check-post-push.sh:421-431`). WARN when a `setup-*` contains `cat >` and its first 15 lines lack "sole owner". `setup-user-claude.sh:12` carries `# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)` and has no `cat >`. A header rewrite that pushes this line past line 15 matters only if a `cat >` is added.

**Step 23** runs `check-script-compliance.sh/.ps1`. See 3.4.

**Step 29, menu parity** (`check-post-push.sh:747-756`):
```bash
750	    ps1_auto=$(perl -ne 'print "$1\n" if /Console.*Write.*\[(\w)\]/' "$ps1_lib" | sort -u | paste -s -d , -)
751	    sh_auto=$(perl -ne 'print "$1\n" if /printf.*\[(\w)\]/' "$sh_lib" | sort -u | paste -s -d , -)
```
- It compares the sets of unique letters across all of `aitools-lib.sh` and `aitools-lib.ps1`. Today both are `a,m,n,o,r,s,x,y`, from `aitools-lib.sh:1464,1729-1735,2370-2376` and `aitools-lib.ps1:1400,1686-1692,2353-2359`.
- Menus in `setup-user-claude.*` are not scanned.
- A new letter in one lib fails the step. A new prompt that reuses existing letters is not detected.

**Step 30, return-value coverage.** Bash (`check-post-push.sh:766-789`):
```bash
766	    sh_returns=$(perl -ne 'print "$1\n" if /MANAGED_FILE_RESULT="(\w[\w-]*)"/' "$sh_lib" | sort -u | paste -s -d , -)
...
777	    for caller in "$REPO_ROOT/scripts/setup-user-claude.sh"; do
778	        cname=$(basename "$caller")
779	        for val in $(echo "$sh_returns" | tr ',' ' '); do
780	            if ! grep -q "$val" "$caller"; then
```
- The value set is scanned from the whole lib file, not just `deploy_managed_file`. Today it is `accept,created,failed,skipped,updated,verified`: the `\w[\w-]*` stops at the space in `accept & adopt`.
- Lines 768-772 compute `ps1_returns`, `sh_tracker` and `ps1_tracker` and never use them.
- PS1 (`check-post-push.ps1:904-922`) checks **both** `setup-user-claude.sh` and `.ps1`, with the bash value set. Bash checks only the `.sh`.
- The test is a substring grep anywhere in the file, comments included.

**Step 31, state machine sync** (`check-post-push.sh:799-803`):
```bash
799	    sh_results=$(perl -ne 'if (/^deploy_managed_file\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_managed_file/)) { print "$1\n" if /MANAGED_FILE_RESULT="(\w[\w-]*)"/ }' "$sh_lib" | sort -u | paste -s -d , -)
800	    ps1_results=$(perl -ne 'if (/^function Deploy-ManagedFile\b/ .. (/^function / && !/Deploy-ManagedFile/)) { print "$1\n" if /return\s+"([\w-]+)"/ }' "$ps1_lib" | sort -u | paste -s -d , -)
802	    sh_tracker=$(perl -ne 'if (/^deploy_tracker_record\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_tracker_record/)) { if (/^\s+([\w|.-]+)\)\s/) { for (split /\|/, $1) { print "$_\n" } } }' "$sh_lib" | sort -u | paste -s -d , -)
803	    ps1_tracker=$(perl -ne 'if (/^function Record-DeployOutcome\b/ .. (/^function / && !/Record-DeployOutcome/)) { while (/-eq\s+"([\w-]+)"|"([\w-]+)"\s*\{/g) { print(($1 // $2) . "\n") } }' "$ps1_lib" | sort -u | paste -s -d , -)
```
The tracker cases it compares today (`aitools-lib.sh:2283-2296`, `aitools-lib.ps1:2275-2283`):
```bash
2284	        added|created) _DT_ADDED=$((_DT_ADDED + 1))
2286	        updated)   _DT_UPDATED=$((_DT_UPDATED + 1))
2288	        "accept & adopt") _DT_ACCEPTED=$((_DT_ACCEPTED + 1))
2290	        skipped)   _DT_SKIPPED=$((_DT_SKIPPED + 1))
2292	        failed)    _DT_FAILED=$((_DT_FAILED + 1))
2294	        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
2295	        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
```
```powershell
2276	        { $_ -eq "added" -or $_ -eq "created" } { $script:dtAdded++;     Write-Summary "DETAIL" $ToolName "added: $ItemName" }
2277	        "updated"   { $script:dtUpdated++;   Write-Summary "DETAIL" $ToolName "updated: $ItemName" }
2278	        "accept & adopt" { $script:dtAccepted++;  Write-Summary "DETAIL" $ToolName "accept & adopt: $ItemName" }
2279	        "skipped"   { $script:dtSkipped++;   Write-Summary "DETAIL" $ToolName "skipped: $ItemName" }
2280	        "failed"    { $script:dtFailed++;    Write-Summary "DETAIL" $ToolName "failed: $ItemName" }
2281	        "verified"  { $script:dtVerified++ }
2282	        "preserved" { $script:dtPreserved++ }
```
Both sides extract `added,created,failed,preserved,skipped,updated,verified`. `accept & adopt` is invisible to both regexes. The summary writers (`deploy_tracker_summary`, `aitools-lib.sh:2303-2321`; `Write-DeployTrackerSummary`, `.ps1:2288-2306`) are not audited by any step.

**Step 32** (`check-hook-parity.py`) audits only hooks. It is not affected unless the fan-out touches hook names in `build-deploy.sh`.

### 3.4 Script compliance (post-push step 23) on `scripts/setup-*`

`check-script-compliance.sh`:
- Step 3 (lines 93-115): every `exit 1` needs `write_summary`, `ERRORS`, `log_error`, an OS-guard token or a forwarding token in the 10 lines before it. `exit 2` is not checked.
- Step 6 (lines 146-162): WARN on a raw `echo ` at line start, except `echo ""`.
- Step 7 (lines 169-190): WARN on a pipeline `grep` without `|| true` in a `set -euo pipefail` script.
- Step 11 (lines 259-292): FAIL on `ErrorAction SilentlyContinue` with no null check in the next 3 lines.
- Step 12 (lines 297-321): FAIL on a `write_summary` category outside OK/WARN/ERROR/ACTION/DETAIL.

`check-script-compliance.ps1` adds: step 3 on `^\s*exit 1` (lines 72-92), step 6 on raw `Write-Host` (WARN), step 12 on both shells.

### 3.5 CI (`.github/workflows/check.yml`)

- **Test steps in macos** (lines 116-150): logging .sh/.ps1, managed-files .sh/.ps1, and profile `test-profile` / `test-config` / `test-lib` / `test-user-init`, each also under `AITOOLS_TEST_BASH=/bin/bash /bin/bash ... --bash-only`.
- **Test steps in linux** (lines 287-309): the same tests, without the 3.2 runs.
- **Test steps in windows** (lines 393-407): logging and managed-files only (Git Bash and native pwsh). No profile tests.
- **Not in CI:** `tests/rules-fanout-cursor/`, `tests/deploy-harness/`, `tests/deploy-harness-mdm/` (all on main since dd562f6, 3e1a97d and eedefb8).
- **Syntax steps** cover `scripts/*.sh`, `scripts/githooks/pre-commit`, `deploy/*.sh`, `shared/hooks/*.sh` and `scripts/*.ps1`, `deploy/*.ps1` (lines 57, 77). `tests/` files are syntax-checked only by being run.
- **Deploy drift** (lines 165-170) excludes the profile-dependent scripts:
  ```yaml
  165	          drift=$(git diff -- deploy/ \
  166	            ':!deploy/setup-user-claude.sh' ':!deploy/setup-user-claude.ps1' \
  ```
  CI runs `bash scripts/build-deploy.sh` on the runner (lines 152-156, 311-312, 448-450).

### 3.6 Test HOME isolation patterns (question d)

**`tests/profile` pattern.**
- Setup: `WORK="$(mktemp -d)"` and `trap cleanup EXIT` (`test-config.sh:18-20`).
- Each run sets the environment on the call:
  ```bash
  90	        env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
  91	            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac $CASE_ENV \
  92	            "$BASH_BIN" "$SH" "$@" > "$WORK/out.txt" 2>&1 || RC=$?
  ```
- The pwsh twin adds `AITOOLS_PROFILE_TEST_ANY_OS=1` (line 96).
- `test-user-init.sh:135-139` also strips inherited overrides and pins git config:
  ```bash
  135	    local e=(env -u AITOOLS_SUMMARY_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_FORCE
  136	        HOME="$H" PATH="$WORK/bin:$PATH" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_PRESERVE_SUMMARY=1
  138	        GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_NOSYSTEM=1 ...
  ```
- `BASH_BIN="${AITOOLS_TEST_BASH:-bash}"` and `--bash-only` give the macOS 3.2 CI variant (`test-config.sh:21-23`).

**Fan-out patterns to copy for `tests/rules-fanout/`.**
- `test-rules-fanout-cursor.sh:45-75`: a `setup_case` per case with HOME and stub bin, then `run_script` with `env HOME=... AITOOLS_LOG_DIR=... AITOOLS_SUMMARY_FILE=... PATH=stub:$PATH bash "$SCRIPT" < /dev/null`, and `check name "cond"`.
- PR #110 adds the `manifest()` helper that writes `~/.aitools/rules/.aitools-rules-manifest`. Header `# aitools rules manifest v1`, then `<name>\t<source>` lines, with sources `shared|dotprofile|aitools|retired`. It also adds `step4-driver.ps1`, which runs one step of the `.ps1` past its Windows OS guard, and the `parity()` function (tree md5 + summary rows).
- PS1 OS guard: disable it in a temp copy with `perl -pe 's/-and -not \$IsWindows\)/-and \$false)/'`, as in `test-deploy-harness-mdm.sh:256,263` and PR #112 `test-claude-mdm.sh`.
- MDM side: `test-deploy-harness-mdm.sh:73-83` runs `build-deploy.sh` with `HOME=<temp>` whose `config.json` points `userRepoPath` at a fixture git dotprofile in the temp dir. It then runs the generated script from a copy under further temp HOMEs.

## 4. What must change or be checked, and why

| # | Item | Required? | Why / what |
|---|---|---|---|
| C1 | New `tests/rules-fanout/*.sh` mode 100755 | Required | Pre-commit 6 FAILs otherwise. On Windows use `git update-index --chmod=+x`. |
| C2 | `tests/rules-fanout/` steps in `check.yml` | Required for "regression test" to mean anything in CI | Add to the macos job after "User init tests", as `bash tests/rules-fanout/test-rules-fanout.sh` plus `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout/test-rules-fanout.sh --bash-only` (if the test supports it). Add the same `bash` step to the linux job. Optional for windows: a Git Bash step, as for managed-files. Suggested: also add the three existing un-CI'd fan-out/harness suites (INCIDENT I-2). |
| C3 | Pre-commit 13 | Check only | Stage `scripts/build-deploy.sh` in the same commit as `scripts/setup-user-claude.*` to get PASS. Otherwise WARN (non-blocking). |
| C4 | Pre-commit 20 | Check | Any `.claude/rules`, `.cursor/rules`, `reference/*.md`, skill or `CLAUDE.md` text that cites `tests/rules-fanout/...` or a new script path must land in the same commit as the file, or get an allowlist entry. `scripts/check-path-refs-allow.txt` is open in PR #99, so rebase on it. `~/.aitools/rules` citations are skipped (the `~` rule). |
| C5 | Pre-commit 15, compliance 12 | Check | Fan-out rows must use OK/WARN/ERROR/ACTION/DETAIL. Never `write_summary ... "unchanged"`; use `verified`. |
| C6 | Pre-commit 8 | Check | Do not add `cat >` or `WriteAllText ... ConvertTo-Json` lines to `setup-user-claude.*`. Use `deploy_managed_file`. |
| C7 | Post-push 30 | Required if the lib gains a value | Any new `MANAGED_FILE_RESULT="x"` anywhere in `aitools-lib.sh` (whole-file scan) forces the literal `x` into both `setup-user-claude.sh` and `.ps1` (PS1 step 30 checks both). If the rules loop moves into a lib function, the CLAUDE.md `case` keeps the strings, so it still passes. That is a weakness, not a guarantee. |
| C8 | Post-push 31 | Required if a tracker outcome is added | The known defect "tracker has no `removed`". Adding `removed)` to `deploy_tracker_record` requires `"removed" { ... }` (or `-eq "removed"`) in `Record-DeployOutcome`, else FAIL. Use a single-word outcome: one with a space (`"retired rule"`) is invisible to both regexes. `deploy_tracker_summary` / `Write-DeployTrackerSummary` must also print "N removed", which no step checks. |
| C9 | Post-push 29 | Check | A new prompt in a lib must appear in both libs. A new letter in one lib FAILs. A prompt inside `setup-user-claude.*` is not audited, so parity there needs a test. |
| C10 | Pre-push 7 smoke | Required | Generated `deploy/setup-user-claude.sh --dry-run` with no `~/.aitools/rules` must exit 0 or 1, never 2 or higher. Suggested: `OK|claude rules|n/a (no harness rules)` and exit 0, as Cursor does (`test-rules-fanout-cursor.sh:174`). It must keep the `Profile source:` lines. The PS1 variant (`check-pre-push.ps1:202-235`) needs the same. |
| C11 | `tests/managed-files/test-managed-files.sh:318-346` (in CI) | Check | Runs the real `scripts/setup-user-claude.sh` on a pty with input `a\n` for the CLAUDE.md review, in a HOME with no `~/.aitools/rules`. The fan-out must not prompt or consume stdin there. |
| C12 | PR #112 `tests/claude-mdm/test-claude-mdm.sh` (MDM sh run) | Required once #112 merges | The check `grep -qx 'rule one' '$TMP_ROOT/mdm-sh/.claude/rules/r1.md'` expects dotprofile rules deployed directly. After the fan-out, either seed `~/.aitools/rules/r1.md` (plus a manifest) in that HOME, or change the assertion to the n/a row. |
| C13 | `.cursor/rules/managed-file-deployment.mdc:32` | Twin edit (protected, draft) | The line reads `- **Rules**: additive deploy from \`<userRepoPath>/claude/rules/\` — managed files updated, unmanaged files in target preserved`. Same bullet in `.claude/rules/managed-file-deployment.md`. It must say Claude gets `~/.aitools/rules` minus retired. Also add the `deploy-harness` content-source row that the `.md` has and the `.mdc` lacks. Rebase on #101, which edits lines 30-31 and 59. |
| C14 | `.cursor/rules/deploy-paths.mdc` | Twin edit (protected, draft) | After #99: "(and `setup-user-claude` once it fans out)" becomes present tense. The auto-embedded bullet `<userRepoPath>/claude/rules/*.md → read at build time (the fallback rules)` and the claude "rules fallback" sentence must change to the MDM counterpart. Same in `.claude/rules/deploy-paths.md`. Write the edit on top of #99, not on main. |
| C15 | `.cursor/rules/config-file-safety.mdc` | Probably none | No rules-specific text (Directory deployment, lines 39-45, is generic). Only if the `.md` example "`# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/`" (config-file-safety.md "Directory deployment") is changed, and that example is not in the `.mdc`. |
| C16 | `.cursor/rules/interactive-menus.mdc:18-21` | Check | Says setup-user-claude deploys CLAUDE.md and rules at two call sites and must handle all values at each. Still true if the fan-out keeps `deploy_managed_file`. Edit only if the call-site structure changes. |
| C17 | `reference/post-push-checklist.md:189-195` (step 30 text) | Optional doc fix | Says the callers are `setup-user-claude`, `setup-user-mcp`, `setup-user-hooks`. The code audits only setup-user-claude. Update if step 30 changes. |
| C18 | Header lines `setup-user-claude.sh:13-14` / `.ps1:12-13` | Check | `# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/` must change. `build-deploy.sh:642-643,731-732` repeats this header for the generated scripts (Claude/Lib slice). Keep `sole owner` within the first 15 lines (post-push 19). |

## 5. Interactions with open PRs in this slice

- **#112** (`fix/mf-audit-claude-build`) adds `tests/claude-mdm/test-claude-mdm.sh` (334 lines) and CI steps "setup-user-claude dev + MDM tests" in macos (bash 5 + `/bin/bash` 3.2) and linux. Overlap: C12. Its fixture (`DP/claude/rules/r1.md`, `write_config` → `userRepoPath`) is the natural home for the fan-out's MDM cases. Suggested: extend `tests/claude-mdm/` for MDM parity, and keep `tests/rules-fanout/` for the dev-path fan-out matrix. Or put both in `tests/rules-fanout/` and update #112's r1.md check.
- **#103, #113, #115, #116** all add the same CI hunk at `check.yml` lines ~125-131 ("Dotprofile adopt commit+push tests"). #116 also adds "Installer Step 3/5 relay tests" after line 149, and #112 adds its step at the same anchor. A new `tests/rules-fanout/` step inserted after "User init tests" (line 150 macos, line 309 linux) conflicts textually with #112 and #116. Rebase after they merge.
- **#110** (Cursor fan-out, rules manifest) rewrites `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` and adds `step4-driver.ps1`. It defines the manifest contract the Claude fan-out must read: `~/.aitools/rules/.aitools-rules-manifest`, `# aitools rules manifest v1`, `<name>\t<source>`, sources `shared|dotprofile|aitools|retired`. It also changes the Cursor n/a row text to `n/a (no user-level rules)` for a manifest with no user rules. Copy its `manifest()` / `parity()` helpers. Do not edit its files.
- **#100** (`feature/harness-rules-manifest`) touches `tests/deploy-harness/test-deploy-harness.sh` only, in my slice. Whether #100 actually writes `retired` lines is in the Harness slice. I saw only the #110 test fixture, which uses `retired`.
- **#111** touches both deploy-harness tests. No direct overlap with a new `tests/rules-fanout/`.
- **#99** edits `.cursor/rules/deploy-paths.mdc` and `scripts/check-path-refs-allow.txt` (C4, C14).
- **#101** edits `.cursor/rules/managed-file-deployment.mdc` (C13).
- **#109** edits `scripts/check-lib.sh/.ps1` (B8 consumer rows). I did not read the diff. No expected overlap with fan-out steps.
- **#114, #108, #98** touch `tests/profile/*` only, which is the isolation pattern source. No overlap.

## 6. Error-handling, parity and script-standards issues in code the refactor touches

1. Post-push 30 parity gap. Bash audits only `setup-user-claude.sh` (`check-post-push.sh:777`). PS1 audits `.sh` and `.ps1` (`check-post-push.ps1:908-911`), but with the **bash** value set. Bash also computes three unused variables (`check-post-push.sh:768-772`).
2. Post-push 30 is a substring grep. `verified` in a comment satisfies it. It cannot prove a handler exists (`interactive-menus.md` "Known limitation").
3. Post-push 29 compares letter sets across whole libs, not menus or order, despite `interactive-menus.md` saying "identical options in identical order".
4. `check-post-push.ps1:709,734,741,748` uses `$repoRoot`, which is never set in that script (it sets `$script:RepoRoot` at line 8). PowerShell variable names are case-insensitive, so `$repoRoot` resolves to the same script-scope variable. Probably fine at runtime, but unverified: I did not run it.
5. Pre-commit 3 `--fix` (`check-pre-commit.sh:113`, `.ps1:112`) and post-push 7 (`check-post-push.sh:204`, `.ps1:234`) run `build-deploy.sh` against the real HOME, with `>/dev/null 2>&1` and no exit-code check. This is a silent failure and it mutates the real dotprofile `deploy/` (`build-deploy.sh:218`).
6. `scripts/githooks/pre-commit:13-16` runs `build-deploy.sh` against the real HOME whenever `shared/` or `build-deploy.sh` is staged. It is not active in this clone (`git config --get core.hooksPath` exit 1, unset). Unknown on the Windows machine.
7. `scripts/README.md:39-44` says pre-commit has 12 steps and post-push 26. The code has steps up to 20 and 32.

## 7. Risks, unknowns, open questions (with suggested answers)

- **Brief vs code on pre-push.** The brief and launch prompt say `check-pre-push.sh` runs `build-deploy.sh` against the real HOME. At 480b901 step 7 runs it under `HOME=$d7_tmp/home` with `AITOOLS_USER_REPO_PATH` set to a temp dotprofile copy (`check-pre-push.sh:131-148`). It only reads the real `~/.aitools/config.json`. The dangerous ones are **post-push 7** and **pre-commit 3 `--fix`**. I did not run any of them. Suggested answer: treat pre-push as safe to run from a worktree (the packet section 4 already tells shippers to run it), and treat post-push as never-run without an isolated HOME.
- **Q1: where do the MDM parity tests live, `tests/rules-fanout/` or #112's `tests/claude-mdm/`?** Suggested: `tests/rules-fanout/test-rules-fanout.sh` for the dev path plus PS1 parity (driver like #110's `step4-driver.ps1`), and extend `tests/claude-mdm/` for the generated MDM scripts once #112 merges. If #112 is not merged when FAN-IMPL starts, put both in `tests/rules-fanout/` and note C12.
- **Q2: does `tests/rules-fanout/` run under macOS `/bin/bash` 3.2 in CI?** Suggested: yes, because `setup-user-claude.sh` must be bash 3.2 compatible (packet section 5). Use the `AITOOLS_TEST_BASH` / `--bash-only` convention from `tests/profile`.
- **Q3: with no `~/.aitools/rules`, should the row be OK n/a or ERROR?** Suggested: `OK|claude rules|n/a (no harness rules)`, exit 0. This matches Cursor, and keeps pre-push 7 and test-managed-files green. ERROR would make every endpoint without deploy-harness exit 1 (still passes pre-push 7, but noisy).
- **Unknown:** whether `build-deploy.sh` still writes anything into `aitools/deploy/`. deploy-paths.md says it is frozen, but `build-deploy.sh:33` still sets `DEPLOY_DIR="$REPO_ROOT/deploy"` before line 218 reassigns it. That affects whether the CI and pre-commit 10 drift checks mean anything (Lib/Harness slice).
- **Unknown:** the exact `retired` semantics in #100. Not read; Harness slice.
- **Risk:** CI's Windows job runs no profile, fan-out or harness tests. PS1 fan-out parity is tested only through pwsh on macOS/Linux, and the native Windows OS-guard path never runs in CI.

## 8. INCIDENT markers (not filed)

- INCIDENT I-1 (high): post-push step 7 (`check-post-push.sh:204`, `.ps1:234`) and pre-commit step 3 `--fix` (`check-pre-commit.sh:113`, `.ps1:112`) run `build-deploy.sh` against the real HOME with output discarded and the exit code unchecked. That deletes and rebuilds the real dotprofile `deploy/` (`build-deploy.sh:218`), while the step compares only the frozen `aitools/deploy/`. Expected per script-standards.md "Error handling requirements" and #86 (isolated HOME). Pre-push 7 already shows the isolated pattern to copy.
- INCIDENT I-2 (medium): `tests/rules-fanout-cursor/`, `tests/deploy-harness/` and `tests/deploy-harness-mdm/` are on main and absent from `.github/workflows/check.yml`, so their regressions never fail CI.
- INCIDENT I-3 (medium): `.cursor/rules/deploy-paths.mdc` drifts from `.claude/rules/deploy-paths.md`. It says "Four script pairs" including setup-user-mcp, the MDM path is "`deploy/`" not the dotprofile, and "Verify via pre-commit steps 3+10", which the `.md` says no longer apply. `.cursor/rules/managed-file-deployment.mdc` lacks the `deploy-harness` content-source row (cursor-rule-parity.mdc). Partly addressed by open #99/#101.
- INCIDENT I-4 (medium): pre-push step 7's trigger (`check-pre-push.sh:123`, `.ps1:126`) omits `scripts/deploy-harness.(sh|ps1)`, `.claude/rules/`, `reference/`, `registries/`, `.claude/skills/` and the dotprofile `claude/rules/`. All of these are embedded into the generated `deploy/deploy-harness.*` (#99 deploy-paths text), so a push that changes them never checks that the dotprofile `deploy/` is stale.
- INCIDENT I-5 (low): post-push step 30 parity and coverage gaps (section 6 items 1-2). Post-push 29 checks letter sets, not identical order (item 3).
- INCIDENT I-6 (low): `scripts/README.md:39-44` step counts are stale. `reference/post-push-checklist.md:191-195` names step-30 callers (`setup-user-mcp`, `setup-user-hooks`) that the code no longer audits.

WRITE_BLOCKED: none.
