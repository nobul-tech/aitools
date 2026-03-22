# AAR: check-post-push.sh Bugs (3 bugs, 1 emergent failure)

**Date**: 2026-03-18
**Investigated by**: S2 (Intelligence)
**Script**: `scripts/check-post-push.sh`
**Severity**: High -- the check script cannot complete a clean run on macOS

---

## 1. Executive Summary

`scripts/check-post-push.sh` has three independent bugs that combine to produce the observed failure (all checks appear to PASS, but exit code is 1 with multiple stderr errors). The bugs are:

1. **Bash 3.2 process-substitution + heredoc incompatibility** (step 21): The `< <(python3 - <<'PYEOF' ...)` construct fails on macOS's bash 3.2.57, producing "ambiguous redirect" and corrupting the heredoc content so Python receives broken code. Step 21 silently passes with `0 OK, 0 skipped` instead of detecting actual version drift.

2. **macOS BSD `paste` incompatibility** (11 call sites across steps 27, 29, 30, 31): `paste -sd,` and `paste -sd ', '` require an explicit `-` argument for stdin on macOS BSD `paste`. Without it, `paste` prints a usage error and exits non-zero.

3. **`set -euo pipefail` propagates `paste` failure** (emergent from Bug 2): The `paste` exit code 1 propagates through `pipefail` into `set -e`, which aborts the script before the exit footer runs. The summary and exit logic on lines 814-820 are never reached. The script exits 1 from `set -e`, not from `FAIL_COUNT > 0`.

There is no standalone "exit code contradiction" bug -- the exit code 1 is explained by Bug 2 + Bug 3 working together.

---

## 2. Timeline

| Date | Commit | What happened |
|------|--------|---------------|
| 2026-03-02 | `34e316f7` | Step 21 introduced with `< <(python3 - <<'PYEOF' ...)` pattern. Bug 1 existed from day one but was silent -- step always reported 0 results. |
| 2026-03-12 | `7435fd8` | Step 27 introduced with `paste -sd ', '` (Bug 2 introduced). |
| 2026-03-12 | `9b2e83a` | Steps 29-31 introduced with `paste -sd,` (Bug 2 expanded to 10 more call sites). |
| 2026-03-13 | `696dad2` | Step 21 Python code refactored to add `plat_key` dict (platform detection). This added two single-line dict literals with braces, increasing the severity of Bug 1's Python errors from potentially working (if the original code's dicts were on separate lines) to guaranteed failure (dict literals on single lines trigger bash 3.2 brace confusion). |
| 2026-03-17 | (runtime) | v0.62.2 session: user runs `bash scripts/check-post-push.sh`, sees all visible checks PASS but exit code 1 with stderr errors. |

---

## 3. Bug 1: Process Substitution + Heredoc Incompatibility ("Ambiguous Redirect")

### Location

Line 466: `done < <(python3 - "$versions_json" <<'PYEOF'`
Error reported on line 533 (the closing `fi` of the enclosing `if` block).

### What it does

Step 21 ("Tool version freshness") feeds a Python script via heredoc to `python3 -`, captures stdout via process substitution `<(...)`, and feeds it to a `while ... done < ...` loop.

### Why it fails

macOS ships bash 3.2.57 (2007-era, frozen at GPLv2 due to Apple's GPLv3 policy). Bash 3.2 has a parsing bug where `< <(cmd <<'HEREDOC' ... HEREDOC)` -- combining input redirection from a process substitution with a heredoc redirected to the command inside the process substitution -- produces "ambiguous redirect." The `0` in `0: ambiguous redirect` refers to file descriptor 0 (stdin), which both the process substitution redirect `<` and the heredoc `<<` compete for.

Additionally, bash 3.2 appears to partially interpret curly-brace dict literals (`{'Darwin': 'macos', 'Windows': 'windows'}`) inside the heredoc despite the quoted delimiter `<<'PYEOF'`. The Python code received by `python3` has the braces stripped, producing:
```python
plat_key = 'Darwin': 'macos'.get(platform.system(), 'linux')
```
instead of:
```python
plat_key = {'Darwin': 'macos', 'Windows': 'windows'}.get(platform.system(), 'linux')
```

### Reproduction

```bash
#!/usr/bin/env bash
set -euo pipefail
while IFS= read -r line; do echo "$line"; done < <(python3 - <<'PYEOF'
d = {'a': 1, 'b': 2}
print(d)
PYEOF
)
```
This reliably produces `ambiguous redirect` on macOS bash 3.2.57 and Python SyntaxErrors on stderr. The while loop processes zero lines. Without `set -e`, the script continues past the failure.

### Impact

- Step 21 ALWAYS reports `0 OK, 0 skipped` on macOS -- it has NEVER produced correct results since its introduction on 2026-03-02.
- Tool version drift detection is completely non-functional.
- The "ambiguous redirect" error goes to stderr; the step reports [PASS], masking the failure.

### RCA (5 Whys)

1. **Why does step 21 fail?** The `< <(python3 - <<'PYEOF' ...)` construct is incompatible with bash 3.2.
2. **Why is this construct used?** Process substitution (`<(...)`) was chosen to avoid the subshell variable-scoping problem of `cmd | while read ...` (variables set inside the loop would be lost in the subshell). Combined with a heredoc to pass the Python script inline.
3. **Why wasn't it caught?** The failure is silent: the process substitution error goes to stderr, the while loop gets zero input, counters stay at initialized values, and `step_pass` is called with `0 OK, 0 skipped` -- which looks plausible.
4. **Why does bash 3.2 fail here?** It's a 2007-era parser with known limitations in heredoc handling within compound redirections. This specific combination (process substitution input + heredoc within the substituted command) is an edge case that newer bash versions handle correctly.
5. **Why is bash 3.2 in use?** Apple ships bash 3.2 as `/bin/bash` and has since macOS Catalina (2019) due to GPLv3 avoidance. The script's shebang is `#!/usr/bin/env bash` which resolves to `/bin/bash` unless the user has installed a newer bash.

---

## 4. Bug 2: macOS BSD `paste` Incompatibility

### Location

11 call sites total:
- **Line 702** (step 27): `paste -sd ', '` -- space in delimiter, no stdin file arg
- **Lines 745-746** (step 29): `paste -sd,` -- bundled flag, no stdin file arg
- **Lines 761, 763, 765, 767** (step 30): `paste -sd,`
- **Lines 792, 793, 795, 796** (step 31): `paste -sd,`

### What it does

`paste -sd,` (or `paste -sd ', '`) joins lines from stdin into a single comma-separated line. Used to format multi-line output into summary strings.

### Why it fails

macOS BSD `paste` requires an explicit file argument (or `-` for stdin) when using the `-s` flag. GNU `paste` (Linux) accepts implicit stdin. The BSD behavior:

```bash
echo "a" | paste -sd,      # FAILS: "usage: paste [-s] [-d delimiters] file ..."
echo "a" | paste -sd, -    # WORKS: "a"
echo "a" | paste -s -d , - # WORKS: "a"
```

Exit code on failure: 1.

### Impact

- **Step 27**: If `check_build_prereqs` finds missing prereqs (e.g., cmake), the `paste` on line 702 fails. Under `set -euo pipefail`, this aborts the script.
- **Steps 29-31**: Always reached (inside `$EXTENSIVE` which is always true). The first `paste -sd,` on line 745 aborts the script even if step 27 passed.
- Every `paste` call site is a potential script-abort point.

### RCA (5 Whys)

1. **Why does `paste` fail?** BSD `paste` (macOS) requires explicit file args for `-s` mode; GNU `paste` (Linux) accepts implicit stdin.
2. **Why is GNU syntax used?** The code was written/tested on a system with GNU `paste` (or never tested on macOS).
3. **Why wasn't this caught?** The check-post-push.sh script has an OS guard that prevents running on Windows, but both macOS and Linux are allowed. The script was tested on one but not verified on both.
4. **Why isn't there a cross-platform test for this?** The project's `check-script-compliance.sh` checks for `grep -P` (known BSD incompatibility) but not for `paste` BSD incompatibilities.
5. **Why use `paste` at all?** `paste -sd,` is a common idiom for joining lines. On macOS, `perl -pe 'chomp if eof'` or `tr '\n' ','` are portable alternatives.

---

## 5. Bug 3: Exit Code Contradiction (Emergent from Bug 2)

### Mechanism

This is not an independent bug but an emergent failure from Bug 2 interacting with `set -euo pipefail`:

1. `paste -sd,` (line 745 or similar) exits with code 1
2. `pipefail` propagates the non-zero exit through the pipeline: `perl ... | sort -u | paste -sd,`
3. The pipeline is inside a command substitution: `ps1_auto=$(... | paste -sd,)`
4. `set -e` detects the non-zero exit and aborts the script immediately
5. Lines 814-820 (summary + exit footer) are NEVER reached
6. The script exits with the pipeline's exit code (1), not from the `FAIL_COUNT` check

### Verification

The stdout output ends abruptly after whatever step contained the first failing `paste`. No summary line ("=== SUMMARY: ...") appears in stdout. The exit code 1 comes from `set -e` aborting at the `paste` failure point, not from the exit footer logic.

### Why "all 13 checks PASSED" was misleading

The "13 checks PASSED" in the user's report refers to the **inner** `check-script-compliance.sh` (step 23), which has 13 sub-checks and its own separate summary. The **outer** check-post-push.sh summary was never printed because the script was killed by `set -e` before reaching it.

---

## 6. Dependencies Between Bugs

### Bug 1 (process substitution + heredoc) is INDEPENDENT

- Exists since 2026-03-02
- Affects only step 21
- Silent failure (no script abort)
- Would exist even if Bugs 2-3 were fixed

### Bugs 2 and 3 are COUPLED

- Bug 2 (paste incompatibility) CAUSES Bug 3 (exit code contradiction)
- Fixing Bug 2 eliminates Bug 3 automatically
- They can be treated as a single fix

### Parallel fixability

All bugs can be fixed in parallel:
- Bug 1: Replace `< <(cmd <<'HEREDOC')` with a bash-3.2-compatible pattern
- Bug 2: Replace `paste` usage with a macOS-compatible alternative (add `-` for stdin, or use `perl`)

---

## 7. Verification Criteria

### Bug 1 fixed when:

- [ ] Step 21 produces non-zero OK/SKIP/WARN counts when tools are installed
- [ ] Running `bash scripts/check-post-push.sh 2>/tmp/stderr.txt` produces NO "ambiguous redirect" in `/tmp/stderr.txt`
- [ ] Running `bash scripts/check-post-push.sh 2>/tmp/stderr.txt` produces NO Python SyntaxErrors in `/tmp/stderr.txt`
- [ ] Step 21 output matches the output of running the Python code in isolation (i.e., actual tool version data)

### Bug 2 fixed when:

- [ ] Running `bash scripts/check-post-push.sh 2>/tmp/stderr.txt` produces NO "usage: paste" in `/tmp/stderr.txt`
- [ ] Steps 27, 29, 30, 31 all complete and report results
- [ ] The exit footer (summary line) always appears in stdout

### Bug 3 fixed when (automatic from Bug 2 fix):

- [ ] Exit code is 0 when FAIL_COUNT is 0
- [ ] Exit code is 1 only when FAIL_COUNT > 0
- [ ] The `=== SUMMARY: ...` line always appears before exit

### Cross-platform:

- [ ] All fixes verified on macOS bash 3.2.57 (`/bin/bash`)
- [ ] All fixes verified on Linux bash 5.x (if available)
- [ ] No regressions on either platform

---

## 8. Recommended Corrective Actions

### Bug 1: Process substitution + heredoc

**Direction**: Eliminate the `< <(cmd <<'HEREDOC')` compound redirect. Two viable approaches:

**Option A** (write-then-execute): Write the Python code to a temp file, execute from file instead of stdin heredoc.
```
tmpf=$(mktemp); cat > "$tmpf" <<'PYEOF' ... PYEOF; while ... done < <(python3 "$tmpf" "$versions_json"); rm "$tmpf"
```

**Option B** (pipe instead of process substitution): Use `cmd | while read ...` and accept the subshell variable scoping limitation. Since the counters need to survive the loop, use a temp output file instead.

Option A is cleaner and avoids both the bash 3.2 bug and the subshell scoping issue.

### Bug 2: macOS BSD `paste`

**Direction**: Replace all 11 `paste` call sites with macOS-compatible alternatives.

**Option A**: Add explicit `-` for stdin to all `paste` calls: `paste -s -d , -`
This is the minimal change but `paste -sd,` (bundled flags) may also be a portability concern on some BSD versions. Use separated flags: `paste -s -d , -`.

**Option B**: Replace `paste` with `perl -pe 'chomp if eof'` combined with `tr '\n' ','` or a perl one-liner: `perl -e 'chomp(@l=<STDIN>); print join(",", @l)'`. This eliminates the BSD/GNU divergence entirely.

**Option C**: Add a `join_lines` helper function to `check-lib.sh` that abstracts the platform difference, then replace all 11 call sites.

Option A is the simplest. Option C is the most maintainable for a script with 11 call sites.

### Detection improvement

Consider adding a compliance check for `paste` without stdin file arg, similar to the existing `grep -P` check (which catches another BSD/GNU incompatibility). This would go in `check-script-compliance.sh`.

### Process note

The project's `cross-platform.md` rule and `script-standards.md` rule already require cross-platform awareness. The `paste` BSD incompatibility is the same class of issue as the `grep -P` issue that was already caught and fixed in commit `ca3efc1` ("Fix grep -P on macOS in check scripts"). A check-script-compliance step for `paste` without explicit stdin would prevent recurrence.
