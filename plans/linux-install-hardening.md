# Linux install hardening (PR A) — install safety & correctness, v0.73.2

> Status: **draft — awaiting commander review** (protected: `plans/*.md`).
> Parent plan: `/home/user/nobul-jose/plans/linux-install-plan.md` (Phase 2).
> Epic: nobul-tech/aitools#10. Fixes #11 #12 #13 #15 #16 #17 #18.
> Not in scope: #14 (Linux install paths per tool) and #19 (CI/registry) — PR B.

## Intent

**Purpose**: Make `aitools install` safe to run and re-run on a machine it does not yet
fully support (Linux without Homebrew): never corrupt user config, never delete a
working tool before its replacement is verified, never report success after failure.
**Scope**: Bug fixes in 10 existing files (8 bash, 2 PowerShell), the release entry,
one tool-name table row, and the Go registry rows. NOT new Linux install methods,
pkg-manager helpers, Homebrew-on-Linux, or CI (PR B, `plans/linux-support.md`).
**Audience**: The commander (review), the batch sub-agents (execution), and the
verifying main agent.

## Context

`aitools install` v0.73.1 on Claude Code web (Ubuntu 24.04, root, no Homebrew) logged
`FAILED with 6 error(s)` but exited 0. On re-run it corrupted `~/.aitools/config.json`,
and it deleted a working `/usr/local/go`. The RCA (one issue per root cause) lives in
the parent plan and in issues #11–#18.

## Foundational decisions

| # | Decision | Source |
|---|---|---|
| F1 | **Install first, clean up second.** A non-preferred install is removed only after the replacement binary is verified on disk. If no replacement is available, keep the existing tool and WARN. Never delete it. | #12, #18 RCA; amends `tool-lifecycle.md` "Install cleanup" in PR B |
| F2 | **Judge success by the binary, not by output text.** Use `[ -x "$(brew --prefix)/bin/<tool>" ]` / `command -v` after the install. Grepping for `error\|fatal` stays limited to `brew upgrade` (Standard 3). | #18 RCA |
| F3 | **A working tool kept as-is is WARN, not ERROR.** ERROR means the tool is not usable (the severity table in `script-standards-detail.md`). | script-standards |
| F4 | **`/usr/local/go` with no `pkgutil` is `upstream`.** That is go.dev's official tarball location and is never a cleanup target. Darwin keeps the pkg/manual distinction. | #12; go.dev/doc/install |
| F5 | **Feature-detect CLI flags** (`uv python install --help`). Do not hard-require a minimum version in PR A; record the minimum in the registry in PR B. | #16 |
| F6 | **The `aitools` entry points exit 1 when the installer or deploy failed** (install, gitpull, and sync paths). | #13; script-standards exit footer |
| F7 | **Prototype-validated edits.** Every edit below was applied to a copy of `origin/main` (`bc75d1a`) and exercised by behavior tests (65/65 pass, listed per batch). Sub-agents apply these exact diffs; they write nothing else. | plan-execution.md |

## Execution protocol

- Branch `claude/fable-status-q9ch93` in the worktree `/home/user/nobul-jose/worktrees/aitools`, based on `origin/main` `bc75d1a`.
- One fresh `general-purpose` sub-agent per batch. The prompt is the template in
  `reference/plan-execution-detail.md`, with the error-handling rules block injected verbatim and
  "Edits to apply" set to that batch's diffs (each hunk: `-` lines = old_string, `+` lines
  = new_string, context lines anchor the match).
- After each batch the main agent:
  1. diffs each worktree file against the approved prototype; it must be byte-identical
  2. runs `bash -n` (and `pwsh` ParseFile for `.ps1` where pwsh is available; otherwise CI covers it)
  3. runs the batch's behavior test
  4. greps the changed hunks for `2>/dev/null`, `|| true` and `SilentlyContinue`, and confirms each one has a comment and a result check
- Batches go in order A1→A6, then D (docs/registry/release), then R (build-deploy, checks, commit, push, PR).
- Prototype and tests: `/home/user/.scratch/session-3030c86a-9/` (`proto-scripts/`, `test-a*.sh`,
  `run-all-tests.sh`). Before execution, copy the tests to `.aitools/scratch/` so they
  survive a reclaim; the archive hook harvests them.

### Error-handling audit — how to read the tables

Each table lists every suppression or failure-path construct **added or modified** in the
batch, with the comment that justifies it and the check that consumes its result.
Pre-existing constructs in untouched hunks are out of scope and are listed under
"Pre-existing, not changed" when they sit next to edited code.

---

## Batch A1 — `config.json` read-then-merge (#11)

**Files**: `scripts/aitools-install.sh`

**Change**: delete `read_config_drives()`. Its sed range ran to EOF on an inline `[]` and
spliced garbage into the heredoc. Replace the Step 5 `cat > … << CONFIGEOF` overwrite with a
node read-then-merge: merge to a temp file → `validate_json_config` → `backup_file` → `mv`.
Corrupt-file recovery salvages `userRepoPath`/`machineAlias`. `--dry-run` is honored (it was
ignored before). On a fresh machine without node, only the managed fields are written via
`printf`. An existing file without node is left untouched (WARN). This mirrors the PS1 twin,
which already parses correctly.

```diff
diff --git a/scripts/aitools-install.sh b/scripts/aitools-install.sh
index 0182736..77f2289 100755
--- a/scripts/aitools-install.sh
+++ b/scripts/aitools-install.sh
@@ -226,23 +226,6 @@ read_config_key() {
     printf '%b' "$val"
 }
 
-# Read the raw googleDrives JSON array from a config file.
-# Returns "[]" if not found or empty.
-read_config_drives() {
-    local file="$1"
-    [ -f "$file" ] || { echo "[]"; return; }
-    local result
-    result=$(tr -d '\357\273\277\r' < "$file" \
-        | sed -n '/"googleDrives"/,/^[[:space:]]*\]/p' \
-        | sed '1s/.*\[/[/' \
-        | sed '$s/],*/]/')
-    if [ -z "$result" ] || [ "$result" = "[]" ]; then
-        echo "[]"
-    else
-        printf '%s' "$result"
-    fi
-}
-
 # --- Config file setup ---
 CONFIG_DIR="$HOME/.aitools"
 CONFIG_FILE="$CONFIG_DIR/config.json"
@@ -390,48 +373,132 @@ else
     AITOOLS_NATIVE="$AITOOLS_REPO"
 fi
 
-# Escape backslashes for JSON
+# Escape backslashes for JSON (used only when writing a fresh file without node)
 REPOS_PATH_JSON=$(printf '%s' "$REPOS_PATH_NATIVE" | sed 's/\\/\\\\/g')
 AITOOLS_JSON=$(printf '%s' "$AITOOLS_NATIVE" | sed 's/\\/\\\\/g')
 
-# If config already exists, preserve fields we don't manage
-USER_REPO_LINE=""
-MACHINE_ALIAS_LINE=""
-if [ -f "$CONFIG_FILE" ]; then
-    # Preserve googleDrives if we didn't detect any
-    if [ "$DRIVES_JSON" = "[]" ]; then
-        EXISTING_DRIVES=$(read_config_drives "$CONFIG_FILE")
-        if [ "$EXISTING_DRIVES" != "[]" ]; then
-            DRIVES_JSON="$EXISTING_DRIVES"
-            log "Preserved existing Google Drive entries from config"
+# Managed fields: version, reposPath, repoPath; googleDrives only when drives were
+#   detected this run (otherwise the existing array is kept, or [] when absent)
+# Preserved: userRepoPath, machineAlias (set by 'aitools user init') and all other keys
+# Write path: merge to a temp file -> validate_json_config -> backup_file -> mv.
+#   A merge or validation failure leaves the existing file untouched.
+CONFIG_TMP="${CONFIG_FILE}.tmp.$$"
+# read -d '' returns 1 at end of input by design; the -n check below is the result check
+read -r -d '' CONFIG_MERGE_JS <<'CONFIGJS' || true
+const fs = require('fs');
+const [file, tmp, reposPath, repoPath, drivesJson] = process.argv.slice(1);
+let raw = null;
+try {
+    raw = fs.readFileSync(file, "utf8");
+    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);  // strip UTF-8 BOM (PowerShell 5.x writes one)
+} catch (e) {
+    if (e.code !== 'ENOENT') { console.log('ERROR:read ' + e.message); process.exit(2); }
+}
+let cfg = {};
+let state = 'created';
+if (raw !== null) {
+    try {
+        cfg = JSON.parse(raw);
+        if (cfg === null || typeof cfg !== 'object' || Array.isArray(cfg)) throw new Error('top level is not an object');
+        state = 'updated';
+    } catch (e) {
+        // Invalid JSON: rebuild from managed fields, salvaging the user-init keys by pattern
+        console.log('CORRUPT:' + e.message);
+        cfg = {};
+        for (const k of ['userRepoPath', 'machineAlias']) {
+            const m = raw.match(new RegExp('"' + k + '"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"'));
+            if (m) { cfg[k] = JSON.parse('"' + m[1] + '"'); console.log('RECOVERED:' + k); }
+        }
+        state = 'recovered';
+    }
+}
+let drives;
+try { drives = JSON.parse(drivesJson); } catch (e) { console.log('ERROR:drives ' + e.message); process.exit(3); }
+const next = Object.assign({}, cfg, { version: 2, reposPath: reposPath, repoPath: repoPath });
+if (Array.isArray(drives) && drives.length > 0) next.googleDrives = drives;
+else if (!Array.isArray(next.googleDrives)) next.googleDrives = [];
+for (const k of ['version', 'reposPath', 'repoPath', 'googleDrives']) {
+    const a = JSON.stringify(cfg[k]), b = JSON.stringify(next[k]);
+    if (a !== b) console.log('CHANGED:' + k + ': ' + (a === undefined ? '(unset)' : a) + ' -> ' + b);
+}
+if (state === 'updated' && JSON.stringify(next) === JSON.stringify(cfg)) { console.log('RESULT:unchanged'); process.exit(0); }
+fs.writeFileSync(tmp, JSON.stringify(next, null, 2) + '\n');
+const v = JSON.parse(fs.readFileSync(tmp, 'utf8'));
+const missing = ['version', 'reposPath', 'repoPath'].filter(k => !(k in v));
+if (missing.length) { console.log('ERROR:validation missing ' + missing.join(', ')); process.exit(4); }
+console.log('RESULT:' + state);
+CONFIGJS
+
+if $DRY_RUN; then
+    log "[DRY RUN] Would merge version/reposPath/repoPath/googleDrives into $(display_path "$CONFIG_FILE")"
+elif [ -z "$CONFIG_MERGE_JS" ]; then
+    log_error "Failed: $(display_path "$CONFIG_FILE"): internal error -- config merge program is empty"
+    write_summary ERROR "aitools config" "merge program missing"
+elif command -v node >/dev/null 2>&1; then
+    MERGE_EC=0
+    # || records node's exit status so set -e does not abort before it is reported below
+    MERGE_OUTPUT=$(node -e "$CONFIG_MERGE_JS" "$CONFIG_FILE" "$CONFIG_TMP" \
+        "$REPOS_PATH_NATIVE" "$AITOOLS_NATIVE" "$DRIVES_JSON" 2>&1) || MERGE_EC=$?
+    MERGE_RESULT=$(printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print $1 if /^RESULT:(\w+)/')
+    if [ "$MERGE_EC" -ne 0 ] || [ -z "$MERGE_RESULT" ]; then
+        rm -f "$CONFIG_TMP"
+        printf '%s\n' "$MERGE_OUTPUT" | while IFS= read -r line; do
+            if [ -n "$line" ]; then log_detail "$line"; fi
+        done
+        log_error "Failed: $(display_path "$CONFIG_FILE"): config merge failed (exit $MERGE_EC) -- existing file left untouched"
+        write_summary ERROR "aitools config" "merge failed"
+    elif [ "$MERGE_RESULT" = "unchanged" ]; then
+        log_ok "Unchanged: $(display_path "$CONFIG_FILE")"
+        write_summary OK "aitools config" "verified"
+    elif ! validate_json_config "$CONFIG_TMP" version reposPath repoPath; then
+        # validate_json_config already logged the specific error
+        rm -f "$CONFIG_TMP"
+        write_summary ERROR "aitools config" "validation failed"
+    else
+        backup_file "$CONFIG_FILE"
+        if ! mv "$CONFIG_TMP" "$CONFIG_FILE"; then
+            rm -f "$CONFIG_TMP"
+            log_error "Failed: $(display_path "$CONFIG_FILE"): could not replace the config file"
+            write_summary ERROR "aitools config" "write failed"
+        else
+            case "$MERGE_RESULT" in
+                recovered)
+                    CORRUPT_REASON=$(printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print $1 if /^CORRUPT:(.+)/')
+                    log_warn "$(display_path "$CONFIG_FILE") was not valid JSON ($CORRUPT_REASON) -- rebuilt; the invalid copy was backed up"
+                    write_summary WARN "aitools config" "rebuilt (was invalid)" ;;
+                created)
+                    log_ok "Created: $(display_path "$CONFIG_FILE")"
+                    write_summary OK "aitools config" "created" ;;
+                *)
+                    log_ok "Updated: $(display_path "$CONFIG_FILE")"
+                    write_summary OK "aitools config" "updated" ;;
+            esac
+            # Changed keys: full old -> new in the log, key names as DETAIL lines (after the parent entry)
+            printf '%s\n' "$MERGE_OUTPUT" | perl -ne 'print "$1\n" if /^CHANGED:(.+)/' | while IFS= read -r change; do
+                log "  $change"
+                write_summary DETAIL "aitools config" "${change%%:*} updated"
+            done
         fi
     fi
-    # Preserve userRepoPath (set by 'aitools user init')
-    # `|| true`: read_config_key returns nonzero when the key is absent (pre user-init);
-    # without the guard, set -e aborts the install on a fresh/unpersonalized machine.
-    EXISTING_USER_REPO=$(read_config_key "$CONFIG_FILE" "userRepoPath") || true
-    if [ -n "$EXISTING_USER_REPO" ]; then
-        # printf -v preserves trailing \n ($() command substitution strips it)
-        printf -v USER_REPO_LINE '  "userRepoPath": "%s",\n' "$EXISTING_USER_REPO"
-    fi
-    # Preserve machineAlias (set by 'aitools user init')
-    EXISTING_MACHINE_ALIAS=$(read_config_key "$CONFIG_FILE" "machineAlias") || true
-    if [ -n "$EXISTING_MACHINE_ALIAS" ]; then
-        printf -v MACHINE_ALIAS_LINE '  "machineAlias": "%s",\n' "$EXISTING_MACHINE_ALIAS"
+elif [ ! -f "$CONFIG_FILE" ]; then
+    # Fresh machine without node (node arrives in Step 8): nothing to preserve, so
+    # writing just the managed fields is safe.
+    if printf '{\n  "version": 2,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "googleDrives": %s\n}\n' \
+            "$REPOS_PATH_JSON" "$AITOOLS_JSON" "$DRIVES_JSON" > "$CONFIG_TMP" \
+        && validate_json_config "$CONFIG_TMP" version reposPath repoPath \
+        && mv "$CONFIG_TMP" "$CONFIG_FILE"; then
+        log_ok "Created: $(display_path "$CONFIG_FILE")"
+        write_summary OK "aitools config" "created"
+    else
+        rm -f "$CONFIG_TMP"
+        log_error "Failed: $(display_path "$CONFIG_FILE"): could not write the initial config"
+        write_summary ERROR "aitools config" "write failed"
     fi
+else
+    log_warn "node not found -- $(display_path "$CONFIG_FILE") left unchanged (read-then-merge needs node, installed in Step 8)"
+    write_summary WARN "aitools config" "not updated (no node)"
 fi
 
-cat > "$CONFIG_FILE" << CONFIGEOF
-{
-  "version": 2,
-  "reposPath": "$REPOS_PATH_JSON",
-  "repoPath": "$AITOOLS_JSON",
-${USER_REPO_LINE}${MACHINE_ALIAS_LINE}  "googleDrives": $DRIVES_JSON
-}
-CONFIGEOF
-
-log_ok "Config written to $(display_path "$CONFIG_FILE")"
-validate_json_config "$CONFIG_FILE" version reposPath repoPath || true
 
 # ============================================================
 # 6. Install aitools command
```

**Error-handling audit**

| Construct | Comment | Result check |
|---|---|---|
| `read -r -d '' CONFIG_MERGE_JS … \|\| true` | "read -d '' returns 1 at end of input by design" | `[ -z "$CONFIG_MERGE_JS" ]` → `log_error` + `write_summary ERROR` |
| `node … 2>&1) \|\| MERGE_EC=$?` | "records node's exit status…" | `[ "$MERGE_EC" -ne 0 ] \|\| [ -z "$MERGE_RESULT" ]` → `log_error` + ERROR, temp removed, original untouched |
| JS `catch` on read | — | ENOENT → fresh. Other errors → `ERROR:read`, exit 2 (never swallowed) |
| JS `catch` on parse | "Invalid JSON: rebuild…" | logs `CORRUPT:`, bash → `log_warn` + `write_summary WARN "rebuilt (was invalid)"`; the invalid copy is preserved by `backup_file` |
| `validate_json_config "$CONFIG_TMP"` (no `\|\| true`) | "already logged the specific error" | `elif !` branch → `write_summary ERROR "validation failed"` |
| `mv` | — | `if ! mv` → `log_error` + ERROR |
| no-node fresh write `printf … && validate && mv` | "nothing to preserve" | `else` → `log_error` + ERROR |
| `rm -f "$CONFIG_TMP"` | — | cleanup; rule 8 OK |

Summary detail strings (≤30 chars, governed): `verified`, `created`, `updated`,
`rebuilt (was invalid)`, `merge failed`, `validation failed`, `write failed`,
`merge program missing`, `not updated (no node)`. DETAIL lines (`<key> updated`) are written
after their parent entry. New tool name `aitools config` → batch D adds it to the tool-name table.

**Test**: `test-a1.sh` — 28/28. Covers fresh, unchanged re-run, inline `[]` (the #11 repro),
preserved keys, detected drives replacing existing ones, corrupt-file recovery, BOM, the dry-run
no-op, merge failure leaving the original untouched, and no-node fresh/existing.

---

## Batch A2 — entry points propagate failure (#13)

**Files**: `scripts/aitools`, `scripts/aitools.ps1`

**Change**: an `overall_rc`/`$overallRc` set to 1 in the install-failure branch and in both
"Completed with N error(s)" branches. Those branches change level from `warn` to `error`: an
error count is not a warning. `main` returns it; PS1 ends with `exit $overallRc`.

```diff
diff --git a/scripts/aitools b/scripts/aitools
index 6b9b8c8..1a2baa2 100755
--- a/scripts/aitools
+++ b/scripts/aitools
@@ -1522,6 +1522,9 @@ fi
 
 fi  # _prebuild_done
 
+# Overall exit status: any failed installer/deploy step makes `aitools` exit non-zero
+overall_rc=0
+
 if $do_install; then
     # --- install: pull + rebuild + run installer (includes deploy) ---
     log "Step 3/$STEPS: Running installer"
@@ -1562,6 +1565,7 @@ if $do_install; then
         check_profile interactive
     else
         log "Completed with errors (see $LOG_DISPLAY)" "error"
+        overall_rc=1
     fi
 
 elif $do_gitpull; then
@@ -1572,7 +1576,8 @@ elif $do_gitpull; then
     if [ $deploy_rc -eq 0 ]; then
         log_ok "Done"
     else
-        log "Completed with $deploy_rc error(s)" "warn"
+        log "Completed with $deploy_rc error(s)" "error"
+        overall_rc=1
     fi
 
     log "Step 4/$STEPS: Tagging version"
@@ -1628,7 +1633,8 @@ else
     if [ $deploy_rc -eq 0 ]; then
         log_ok "Done"
     else
-        log "Completed with $deploy_rc error(s)" "warn"
+        log "Completed with $deploy_rc error(s)" "error"
+        overall_rc=1
     fi
 
     log_ok "Configs deployed ($(repo_version "$repo_path"))"
@@ -1698,6 +1704,7 @@ unset AITOOLS_RUN_ID
 unset AITOOLS_SUMMARY_FILE
 unset AITOOLS_SUPPRESS_SUMMARY_DISPLAY
 
+return "$overall_rc"
 }
 
 main "$@"; exit
```

```diff
diff --git a/scripts/aitools.ps1 b/scripts/aitools.ps1
index ef8027e..d7f965d 100644
--- a/scripts/aitools.ps1
+++ b/scripts/aitools.ps1
@@ -1439,6 +1439,9 @@ if (Test-Path $repoAitools) {
 
 }  # _prebuildDone
 
+# Overall exit status: any failed installer/deploy step makes `aitools` exit non-zero
+$overallRc = 0
+
 if ($doInstall) {
     # --- install: pull + rebuild + run installer (includes deploy) ---
     Log "Step 3/$steps`: Running installer"
@@ -1459,6 +1462,7 @@ if ($doInstall) {
         Invoke-ProfileCheck -Mode "interactive"
     } else {
         Log "Completed with errors (see $logFile)" "error"
+        $overallRc = 1
     }
 
 } elseif ($doGitpull) {
@@ -1468,7 +1472,8 @@ if ($doInstall) {
     if ($deployRc -eq 0) {
         LogOk "Done"
     } else {
-        Log "Completed with $deployRc error(s)" "warn"
+        Log "Completed with $deployRc error(s)" "error"
+        $overallRc = 1
     }
 
     Log "Step 4/$steps`: Tagging version"
@@ -1533,7 +1538,8 @@ if ($doInstall) {
     if ($deployRc -eq 0) {
         LogOk "Done"
     } else {
-        Log "Completed with $deployRc error(s)" "warn"
+        Log "Completed with $deployRc error(s)" "error"
+        $overallRc = 1
     }
 
     LogOk "Configs deployed ($(Get-RepoVersion $repoPath))"
@@ -1598,3 +1604,5 @@ if (Test-Path $relayPrompt) {
 Remove-Item Env:\AITOOLS_RUN_ID -ErrorAction SilentlyContinue
 Remove-Item Env:\AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
 Remove-Item Env:\AITOOLS_SUPPRESS_SUMMARY_DISPLAY -ErrorAction SilentlyContinue
+
+exit $overallRc
```

**Error-handling audit**: no suppression constructs are added. The pre-existing
`Remove-Item … -ErrorAction SilentlyContinue` lines next to the new `exit` are env-var
cleanup in untouched code. `main "$@"; exit` already exits with main's status, so the
bash change is only `return "$overall_rc"`.

**Test**: not unit-testable without a full run. It is verified in batch R by `aitools install`
with an injected failure (`exit` code must be 1), and by a clean second run (`exit` 0).
PS1 parse is checked by Windows CI; no pwsh in this environment.

---

## Batch A3 — Go: Linux tarball is upstream; install-first cleanup (#12)

**Files**: `scripts/aitools-lib.sh` (`detect_go_provenance`), `scripts/setup-go.sh`

**Change**: with no `pkgutil` (Linux), `/usr/local/go` is classified `upstream`, kept, and
reported OK. On macOS, pkg-installer and manual installs become a `CLEANUP_TARGET` that is
removed only after `$(brew --prefix)/bin/go` is verified. With no Homebrew → ERROR, and nothing
is removed. The OK summary is written once, after the PATH check, so a tool never gets two rows.

```diff
diff --git a/scripts/aitools-lib.sh b/scripts/aitools-lib.sh
index 5b3e949..58a2771 100755
--- a/scripts/aitools-lib.sh
+++ b/scripts/aitools-lib.sh
@@ -1588,8 +1588,12 @@ detect_go_provenance() {
         /opt/homebrew/*/go|/usr/local/Cellar/*/go)
             echo "homebrew" ;;
         /usr/local/go/bin/go)
-            # Check if installed via macOS .pkg installer (pkgutil) or manual tarball
-            if pkgutil --pkg-info=org.golang.go >/dev/null 2>&1; then
+            # /usr/local/go is go.dev's official tarball location. Only macOS can tell a
+            # .pkg install from a manual tarball (pkgutil). Without pkgutil (Linux) the
+            # tarball is the upstream-preferred install -- never a cleanup target.
+            if ! command -v pkgutil >/dev/null 2>&1; then
+                echo "upstream"
+            elif pkgutil --pkg-info=org.golang.go >/dev/null 2>&1; then
                 echo "pkg-installer"
             else
                 echo "manual"
```

```diff
diff --git a/scripts/setup-go.sh b/scripts/setup-go.sh
index 29a9467..adeff93 100755
--- a/scripts/setup-go.sh
+++ b/scripts/setup-go.sh
@@ -1,9 +1,12 @@
 #!/usr/bin/env bash
-# setup-go.sh -- Installs/updates Go via Homebrew (macOS)
+# setup-go.sh -- Installs/updates Go via Homebrew (macOS); keeps go.dev installs (Linux)
 # Safe to re-run -- detects existing install and upgrades as needed.
 #
-# macOS: Uses Homebrew (preferred). Removes pkg-installer and manual
-#        /usr/local/go installs. Warns for goenv (user-managed).
+# macOS: Uses Homebrew (preferred). Replaces pkg-installer and manual
+#        /usr/local/go installs, removing them only after Homebrew Go is
+#        verified (install first, clean up second). Warns for goenv (user-managed).
+# Linux: Keeps the go.dev tarball at /usr/local/go (the official install).
+#        Other Linux install paths arrive with Linux support (nobul-tech/aitools#14).
 # Windows: Uses winget -- see setup-go.ps1.
 #
 # See reference/tool-registry.md for install source details.
@@ -25,25 +28,13 @@ esac
 PROVENANCE=$(detect_go_provenance)
 log "Go install provenance: $PROVENANCE"
 
-# --- Cleanup non-preferred installs ---
+# --- Non-preferred installs: replace first, clean up only after verification ---
+# A failed or unavailable replacement must never leave the machine without Go.
+CLEANUP_TARGET=""
 case "$PROVENANCE" in
-    pkg-installer)
-        log_warn "Go installed via macOS .pkg installer -- removing /usr/local/go/"
-        if sudo rm -rf /usr/local/go; then
-            log_ok "Removed /usr/local/go/"
-        else
-            log_warn "Failed to remove /usr/local/go/ (sudo required)"
-        fi
-        PROVENANCE="none"
-        ;;
-    manual)
-        log_warn "Go installed manually at /usr/local/go/ -- removing"
-        if sudo rm -rf /usr/local/go; then
-            log_ok "Removed /usr/local/go/"
-        else
-            log_warn "Failed to remove /usr/local/go/ (sudo required)"
-        fi
-        PROVENANCE="none"
+    pkg-installer|manual)
+        CLEANUP_TARGET="/usr/local/go"
+        log "Go at /usr/local/go/ ($PROVENANCE) will be replaced by Homebrew Go, then removed"
         ;;
     goenv)
         log_warn "Go managed by goenv -- skipping cleanup (user-managed)"
@@ -77,20 +68,52 @@ elif [ "$PROVENANCE" = "goenv" ]; then
     GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
     log_ok "Go via goenv: $GO_VERSION"
     write_summary WARN "go" "$GO_VERSION (goenv -- not Homebrew)"
+elif [ "$PROVENANCE" = "upstream" ]; then
+    # go.dev tarball at /usr/local/go (Linux): the official install -- keep it.
+    # 2>/dev/null: version probe only; falls back to a placeholder string
+    GO_VERSION=$(/usr/local/go/bin/go version 2>/dev/null || echo "version unknown")
+    log_ok "Go via go.dev tarball at /usr/local/go ($GO_VERSION)"
+    write_summary OK "go" "$GO_VERSION"
+elif ! command -v brew >/dev/null 2>&1; then
+    log_error "Homebrew not found -- cannot install Go via Homebrew (existing installs left untouched)"
+    write_summary ERROR "go" "Homebrew not found"
 else
     log "Installing Go via Homebrew..."
-    if ! brew install go 2>&1 | while IFS= read -r line; do log "$line"; done; then
-        log_error "brew install go failed"
+    BREW_RC=0
+    # || records the pipeline status (pipefail) so set -e does not abort before it is reported
+    brew install go 2>&1 | while IFS= read -r line; do log "$line"; done || BREW_RC=$?
+    # Verify the formula's own prefix (opt/Cellar), not the shared bin dir: on Intel Macs
+    # $(brew --prefix)/bin is /usr/local/bin, where a symlink into /usr/local/go could
+    # pass for Homebrew Go and get its target deleted below.
+    # 2>/dev/null: stderr warnings must not leak into the path; || clears it on failure.
+    # The -z/-x checks below are the result check.
+    BREW_GO_PREFIX=$(brew --prefix go 2>/dev/null) || BREW_GO_PREFIX=""
+    BREW_GO="${BREW_GO_PREFIX:+$BREW_GO_PREFIX/bin/go}"
+    if [ "$BREW_RC" -ne 0 ] || [ -z "$BREW_GO" ] || [ ! -x "$BREW_GO" ]; then
+        log_error "brew install go failed (exit $BREW_RC) -- Homebrew Go not available"
         write_summary ERROR "go" "brew install failed"
-    fi
-    # Re-check after install
-    if command -v go >/dev/null 2>&1; then
-        GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
-        log_ok "Go installed ($GO_VERSION)"
-        write_summary OK "go" "$GO_VERSION"
+        if [ -n "$CLEANUP_TARGET" ]; then
+            log_warn "Kept existing Go at $CLEANUP_TARGET/ (replacement not verified)"
+        fi
     else
-        log_error "brew install completed but 'go' not found in PATH"
-        write_summary ERROR "go" "installed but not on PATH"
+        # 2>/dev/null: version probe only; falls back to a placeholder string
+        GO_VERSION=$("$BREW_GO" version 2>/dev/null || echo "version unknown")
+        log_ok "Go installed via Homebrew ($GO_VERSION)"
+        if [ -n "$CLEANUP_TARGET" ]; then
+            log_warn "Removing non-preferred Go at $CLEANUP_TARGET/ ($PROVENANCE) -- Homebrew Go verified"
+            if sudo rm -rf "$CLEANUP_TARGET"; then
+                log_ok "Removed $CLEANUP_TARGET/"
+            else
+                log_warn "Failed to remove $CLEANUP_TARGET/ (sudo required) -- it may shadow Homebrew Go on PATH"
+            fi
+        fi
+        hash -r
+        if command -v go >/dev/null 2>&1; then
+            write_summary OK "go" "$GO_VERSION"
+        else
+            log_error "Go installed but 'go' not found in PATH"
+            write_summary ERROR "go" "installed but not on PATH"
+        fi
     fi
 fi
 
```

**Error-handling audit**

| Construct | Comment | Result check |
|---|---|---|
| `command -v pkgutil` | command-existence exemption | if/elif fallback |
| `pkgutil --pkg-info … >/dev/null 2>&1` | pre-existing; output-only redirect inside `if` | the `if` is the check |
| `go version 2>/dev/null \|\| echo "version unknown"` (×2) | "version probe only; falls back…" | default-value fallback (exemption pattern) |
| `brew install go … \| while … \|\| BREW_RC=$?` | "records the pipeline status (pipefail)…" | `[ "$BREW_RC" -ne 0 ] \|\| [ ! -x "$BREW_GO" ]` → `log_error` + ERROR |
| `sudo rm -rf "$CLEANUP_TARGET"` | — | `if` → `log_ok` / `log_warn` (Homebrew Go already works → WARN per F3) |
| `command -v go` after `hash -r` | — | else → `log_error` + ERROR "installed but not on PATH" |

**Execution-time amendment (2026-10-03)**: the batch sub-agent found that verifying
`$(brew --prefix)/bin/go` is unsafe on Intel Macs. There that path is `/usr/local/bin/go`,
which can be a symlink into `/usr/local/go`, so the check would pass against the install about
to be deleted. Verification now uses the formula prefix (`brew --prefix go` → opt/Cellar); the
diff above includes it. Covered by `test-a3b.sh`.

**Test**: `test-a3.sh`, 4/4. A stub go.dev `/usr/local/go` on Linux with no brew → provenance `upstream`, directory kept, exit 0, `OK|go|<version>`.
`test-a3b.sh`, 7/7. Stub pkgutil/brew/sudo with a "manual" `/usr/local/go`:
- (a) brew exits 0 but the formula is missing while `<prefix>/bin/go` symlinks into `/usr/local/go` → directory kept, ERROR, exit 1, one summary row.
- (b) formula present → directory removed after verification, Homebrew version reported.

---

## Batch A4 — gh: official repo only, never shadow a foreign gh (#15)

**Files**: `scripts/setup-gh-cli.sh`

**Change**:
- **gh not owned by apt** (`dpkg -S` fails: tarball, Homebrew, or environment-provided): kept as-is, WARN.
- **apt-owned or absent**: the cli.github.com repo and keyring are added whenever `github-cli.list` is missing. The old code added it only on a first install, so a distro gh (2.45) was "updated" from the distro archive. Then `apt-get install gh` runs.
- **Version line**: validated as a `gh version …` banner, so a non-gh wrapper's output reads `version unknown` instead of polluting the summary.

```diff
diff --git a/scripts/setup-gh-cli.sh b/scripts/setup-gh-cli.sh
index c8cc876..3abd3ef 100755
--- a/scripts/setup-gh-cli.sh
+++ b/scripts/setup-gh-cli.sh
@@ -3,8 +3,12 @@
 # Safe to re-run — detects existing install and upgrades as needed.
 #
 # macOS: Uses Homebrew (brew install gh).
-# Linux: Uses apt + GitHub CLI keyring (added on first install only).
-#        Falls back with warning on non-apt systems.
+# Linux: Uses GitHub's official apt repository (cli.github.com) + keyring --
+#        never the distro package. The repository is added whenever it is
+#        missing, including when a distro gh is already installed. A gh that
+#        apt does not own (tarball, Homebrew, environment-provided) is left
+#        alone rather than shadowed by a second copy.
+#        Errors on non-apt systems (dnf arrives with Linux support).
 #
 # Auth (gh auth login) is interactive — handled by aitools-install Step 2, not here.
 #
@@ -25,6 +29,30 @@ esac
 
 OS_NAME="$(uname -s)"
 
+# First line of `gh --version`, or "version unknown" when the output is not a gh
+# version banner (environment-provided gh wrappers can print other text).
+gh_version_line() {
+    local out first
+    # || true: a broken gh must not abort the script; the banner check below is the result check
+    out=$(gh --version 2>&1) || true
+    first=${out%%$'\n'*}
+    case "$first" in
+        "gh version "*) printf '%s' "$first" ;;
+        *) printf 'version unknown' ;;
+    esac
+}
+
+# Add GitHub's apt repository + signing keyring (official instructions, cli.github.com).
+# Returns non-zero if any step fails; output goes to the log.
+add_github_cli_apt_repo() {
+    { (type -p wget >/dev/null || sudo apt-get install -y wget) \
+        && sudo mkdir -p -m 755 /etc/apt/keyrings \
+        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
+        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
+        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; } 2>&1 \
+        | while IFS= read -r line; do log "$line"; done
+}
+
 # --- Install/update ---
 case "$OS_NAME" in
     Darwin)
@@ -72,41 +100,50 @@ case "$OS_NAME" in
         ;;
 
     *)
-        # Linux: apt is the preferred method
+        # Linux: GitHub's official apt repository (cli.github.com), never the distro package
         if command -v apt-get &>/dev/null; then
+            GH_APT_LIST="/etc/apt/sources.list.d/github-cli.list"
+            GH_PATH=""
+            GH_APT_OWNED=false
             if command -v gh &>/dev/null; then
-                log "gh CLI already installed ($(gh --version | head -1))"
-                log "Updating via apt..."
-                # apt handles idempotency; keyring was added on first install
-                if ! { sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
-                    log_error "apt-get install gh failed"
-                    write_summary ERROR "gh cli" "apt-get install failed"
-                fi
-                if command -v gh &>/dev/null; then
-                    log_ok "gh CLI updated/confirmed ($(gh --version | head -1))"
-                    write_summary OK "gh cli" "$(gh --version | head -1)"
-                else
-                    log_error "apt-get completed but 'gh' not found in PATH"
-                    write_summary ERROR "gh cli" "installed but not on PATH"
+                GH_PATH=$(command -v gh)
+                # dpkg -S exits non-zero when no package owns the file -- that is the answer sought
+                if dpkg -S "$GH_PATH" >/dev/null 2>&1; then
+                    GH_APT_OWNED=true
                 fi
+            fi
+            if [ -n "$GH_PATH" ] && ! $GH_APT_OWNED; then
+                # Not owned by apt (tarball, Homebrew, environment-provided client): an apt
+                # gh would be a second copy that shadows, or is shadowed by, this one.
+                GH_VERSION=$(gh_version_line)
+                log_warn "gh at $GH_PATH ($GH_VERSION) is not managed by apt -- leaving it as is"
+                write_summary WARN "gh cli" "not apt-managed (kept)"
             else
-                log "Installing gh CLI via apt + GitHub keyring..."
-                if ! { (type -p wget >/dev/null || sudo apt-get install -y wget) \
-                    && sudo mkdir -p -m 755 /etc/apt/keyrings \
-                    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
-                    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
-                    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
-                    && sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
-                    log_error "apt keyring + install failed for gh CLI"
-                    write_summary ERROR "gh cli" "apt install failed"
+                if [ ! -f "$GH_APT_LIST" ]; then
+                    if [ -n "$GH_PATH" ]; then
+                        log_warn "gh at $GH_PATH comes from the distro repository, not cli.github.com -- switching sources"
+                    fi
+                    log "Adding the GitHub CLI apt repository (cli.github.com)..."
+                    if ! add_github_cli_apt_repo; then
+                        log_error "Could not add the GitHub CLI apt repository"
+                        write_summary ERROR "gh cli" "apt repo setup failed"
+                    fi
                 fi
-
-                if command -v gh &>/dev/null; then
-                    log_ok "gh CLI installed ($(gh --version | head -1))"
-                    write_summary OK "gh cli" "$(gh --version | head -1)"
-                else
-                    log_error "Failed to install gh CLI via apt"
-                    write_summary ERROR "gh cli" "install failed"
+                if [ -f "$GH_APT_LIST" ]; then
+                    log "Installing/updating gh from cli.github.com via apt..."
+                    if ! { sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
+                        log_error "apt-get install gh failed"
+                        write_summary ERROR "gh cli" "apt-get install failed"
+                    fi
+                    hash -r
+                    if command -v gh &>/dev/null; then
+                        GH_VERSION=$(gh_version_line)
+                        log_ok "gh CLI $GH_VERSION ($(command -v gh))"
+                        write_summary OK "gh cli" "$GH_VERSION"
+                    else
+                        log_error "apt-get completed but 'gh' not found in PATH"
+                        write_summary ERROR "gh cli" "installed but not on PATH"
+                    fi
                 fi
             fi
         else
```

**Error-handling audit**

| Construct | Comment | Result check |
|---|---|---|
| `gh --version 2>&1) \|\| true` in `gh_version_line` | "a broken gh must not abort…; the banner check below is the result check" | `case "gh version "*` → else `version unknown` |
| `dpkg -S "$GH_PATH" >/dev/null 2>&1` | "exits non-zero when no package owns the file — that is the answer sought" | the `if` sets `GH_APT_OWNED` |
| `add_github_cli_apt_repo` pipeline | "Returns non-zero if any step fails" | `if ! add_github_cli_apt_repo` → `log_error` + ERROR "apt repo setup failed" |
| apt install pipeline | pre-existing pattern | `if !` → `log_error` + ERROR; then `command -v gh` → ERROR "installed but not on PATH" |
| `type -p wget >/dev/null` | command-existence exemption (moved verbatim from old code) | `\|\|` installs wget; failure fails the chain |

**Test**: `test-a4.sh`, 4/4. A non-apt stub gh → no sudo/apt invocation, `WARN|gh cli|not apt-managed (kept)`, version reads `version unknown`, exit 0.

---

## Batch A5 — uv & pup: no false success, fallback by binary (#17 #18)

**Files**: `scripts/setup-uv.sh`, `scripts/setup-datadog.sh`

**Change**:
- **uv, non-Homebrew and no brew**: WARN and keep it. This replaces the false `[ok] installed via Homebrew` that the re-check of the pre-existing uv produced.
- **uv, brew install fails**: WARN and keep the existing uv.
- **uv, no uv and no brew**: ERROR.
- **pup migration**: install first; remove the old binary only after `$(brew --prefix)/bin/pup` exists. With no brew, keep it and WARN.
- **pup fresh install**: brew if available, then cargo whenever `pup` is still missing. The cargo fallback previously never fired, because `brew: command not found` matches neither `error` nor `fatal`.
- **Loops**: three `while …; do [ -n ] && log; done` loops become `if … fi`. The `&&` form returns 1 on empty output and aborts under `set -e`.
- **Old-tap uninstall/untap**: the uncommented `|| true` pair gets an exit capture and an explicit WARN.

```diff
diff --git a/scripts/setup-uv.sh b/scripts/setup-uv.sh
index be89daf..3c8686e 100755
--- a/scripts/setup-uv.sh
+++ b/scripts/setup-uv.sh
@@ -2,7 +2,9 @@
 # setup-uv.sh -- Installs/updates uv (fast Python package installer)
 # Safe to re-run -- detects existing install and upgrades as needed.
 #
-# macOS: Uses Homebrew (preferred).
+# macOS: Uses Homebrew (preferred). An existing non-Homebrew uv is kept (WARN)
+#        when Homebrew is unavailable or its install fails -- the tool still works.
+# Linux: Homebrew-only until Linux support lands (nobul-tech/aitools#14).
 #
 # See reference/tool-registry.md for install source details.
 
@@ -41,21 +43,34 @@ if command -v uv >/dev/null 2>&1; then
             fi
         fi
     else
-        log_warn "uv installed via non-preferred method at $uv_path"
-        log "Installing via Homebrew (will take precedence on PATH)..."
-        if ! brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done; then
-            log_error "brew install uv failed"
-            write_summary ERROR "uv" "brew install failed"
-        fi
-        if command -v uv >/dev/null 2>&1; then
-            UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
-            log_ok "uv installed via Homebrew ($UV_VERSION)"
-            write_summary OK "uv" "$UV_VERSION"
+        # 2>/dev/null: version probe only; falls back to a placeholder string
+        UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
+        if ! command -v brew >/dev/null 2>&1; then
+            # The existing uv works; without Homebrew there is nothing to migrate to
+            log_warn "uv at $uv_path ($UV_VERSION) is not a Homebrew install and Homebrew is not available -- keeping it"
+            write_summary WARN "uv" "$UV_VERSION (not Homebrew)"
         else
-            log_error "brew install completed but 'uv' not found in PATH"
-            write_summary ERROR "uv" "installed but not on PATH"
+            log_warn "uv installed via non-preferred method at $uv_path"
+            log "Installing via Homebrew (will take precedence on PATH)..."
+            BREW_RC=0
+            # || records the pipeline status (pipefail) so set -e does not abort before it is reported
+            brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done || BREW_RC=$?
+            BREW_UV="$(brew --prefix)/bin/uv"
+            if [ "$BREW_RC" -eq 0 ] && [ -x "$BREW_UV" ]; then
+                # 2>/dev/null: version probe only; falls back to a placeholder string
+                UV_VERSION=$("$BREW_UV" --version 2>/dev/null || echo "version unknown")
+                log_ok "uv installed via Homebrew ($UV_VERSION)"
+                write_summary OK "uv" "$UV_VERSION"
+            else
+                # The pre-existing uv still works, so this is a warning, not a failure
+                log_warn "brew install uv failed (exit $BREW_RC) -- keeping existing uv at $uv_path ($UV_VERSION)"
+                write_summary WARN "uv" "$UV_VERSION (brew failed)"
+            fi
         fi
     fi
+elif ! command -v brew >/dev/null 2>&1; then
+    log_error "uv is not installed and Homebrew is not available -- cannot install uv"
+    write_summary ERROR "uv" "Homebrew not found"
 else
     log "Installing uv via Homebrew..."
     if ! brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done; then
```

```diff
diff --git a/scripts/setup-datadog.sh b/scripts/setup-datadog.sh
index d9c41a3..5ef8789 100755
--- a/scripts/setup-datadog.sh
+++ b/scripts/setup-datadog.sh
@@ -1,9 +1,12 @@
 #!/usr/bin/env bash
-# setup-datadog.sh -- Installs/updates Datadog CLI (pup) on macOS
+# setup-datadog.sh -- Installs/updates Datadog CLI (pup) on macOS/Linux
 # Safe to re-run -- detects existing install and upgrades as needed.
 #
 # macOS: Uses Homebrew tap datadog-labs/pack (preferred).
-#        Falls back to cargo install if Homebrew fails.
+#        Falls back to cargo install when Homebrew is unavailable or the tap
+#        install does not produce `pup` (judged by the binary, not by output text).
+#        A non-Homebrew pup is replaced only after the Homebrew copy is verified.
+# Linux: cargo fallback until Linux support lands (nobul-tech/aitools#14).
 # Windows: Uses cargo install -- see setup-datadog.ps1.
 #
 # See reference/tool-registry.md for install source details.
@@ -27,9 +30,19 @@ PUP_PATH=$(command -v pup 2>/dev/null) || PUP_PATH=""
 # --- Migrate old Homebrew tap (datadog/pack -> datadog-labs/pack) ---
 if [ -n "$PUP_PATH" ] && brew list datadog/pack/pup >/dev/null 2>&1; then
     log_warn "Pup installed from old tap (datadog/pack) -- migrating to datadog-labs/pack..."
-    UNINSTALL_OUTPUT=$(brew uninstall datadog/pack/pup 2>&1) || true
-    printf '%s\n' "$UNINSTALL_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
-    brew untap datadog/pack 2>/dev/null || true
+    UNINSTALL_EC=0
+    # || records brew's exit status; checked below
+    UNINSTALL_OUTPUT=$(brew uninstall datadog/pack/pup 2>&1) || UNINSTALL_EC=$?
+    printf '%s\n' "$UNINSTALL_OUTPUT" | while IFS= read -r line; do
+        if [ -n "$line" ]; then log "$line"; fi
+    done
+    if [ "$UNINSTALL_EC" -ne 0 ]; then
+        log_warn "brew uninstall datadog/pack/pup exited $UNINSTALL_EC -- reinstalling from the correct tap anyway"
+    fi
+    # A leftover tap entry is harmless (the formula is gone); report it, do not fail
+    if ! brew untap datadog/pack >/dev/null 2>&1; then
+        log_warn "Could not untap datadog/pack (left in place)"
+    fi
     log_ok "Old tap removed -- will reinstall from correct tap"
     PUP_PATH=""
 fi
@@ -57,36 +70,60 @@ if [ -n "$PUP_PATH" ]; then
             write_summary OK "datadog cli" "$PUP_VERSION"
         fi
     else
-        # Installed via go install or other method -- migrate to Homebrew
+        # Installed via go install or another method -- migrate to Homebrew.
+        # Install first; remove the old binary only after the Homebrew copy is verified.
+        # 2>/dev/null: version probe only; falls back to a placeholder string
         PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
-        log_warn "Pup found at $PUP_PATH ($PUP_VERSION) -- not via Homebrew, migrating..."
-        # Remove old binary (likely from go install)
-        if [ -f "$PUP_PATH" ]; then
-            rm -f "$PUP_PATH" 2>/dev/null || log_warn "Could not remove old binary at $PUP_PATH"
-        fi
-        INSTALL_EC=0
-        INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || INSTALL_EC=$?
-        printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
-        if [ "$INSTALL_EC" -ne 0 ] || printf '%s\n' "$INSTALL_OUTPUT" | grep -qi 'error\|fatal'; then
-            log_error "brew install datadog-labs/pack/pup failed during migration"
-            write_summary ERROR "datadog cli" "brew install failed (migration)"
+        if ! command -v brew >/dev/null 2>&1; then
+            log_warn "Pup found at $PUP_PATH ($PUP_VERSION) -- not via Homebrew, and Homebrew is not available; keeping it"
+            write_summary WARN "datadog cli" "$PUP_VERSION (not Homebrew)"
         else
-            PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
-            log_ok "Migrated to Homebrew ($PUP_VERSION)"
-        fi
-        if [ "$ERRORS" -eq 0 ]; then
-            PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
-            write_summary OK "datadog cli" "$PUP_VERSION"
+            log_warn "Pup found at $PUP_PATH ($PUP_VERSION) -- not via Homebrew, migrating..."
+            INSTALL_EC=0
+            # || records brew's exit status; the binary check below decides success
+            INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || INSTALL_EC=$?
+            printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
+                if [ -n "$line" ]; then log "$line"; fi
+            done
+            BREW_PUP="$(brew --prefix)/bin/pup"
+            if [ ! -x "$BREW_PUP" ]; then
+                # The old pup still works, so this is a warning, not a failure
+                log_warn "brew install datadog-labs/pack/pup did not produce $BREW_PUP (exit $INSTALL_EC) -- kept $PUP_PATH"
+                write_summary WARN "datadog cli" "$PUP_VERSION (migration failed)"
+            else
+                if [ "$PUP_PATH" != "$BREW_PUP" ] && [ -f "$PUP_PATH" ]; then
+                    if rm -f "$PUP_PATH"; then
+                        log "Removed old binary $PUP_PATH"
+                    else
+                        log_warn "Could not remove old binary at $PUP_PATH"
+                    fi
+                fi
+                # 2>/dev/null: version probe only; falls back to a placeholder string
+                PUP_VERSION=$("$BREW_PUP" version 2>/dev/null || echo "version unknown")
+                log_ok "Migrated to Homebrew ($PUP_VERSION)"
+                write_summary OK "datadog cli" "$PUP_VERSION"
+            fi
         fi
     fi
 else
-    # Fresh install
-    log "Installing Pup via Homebrew (datadog-labs/pack tap)..."
-    # brew install can exit non-zero for non-fatal warnings; check output for real errors
-    INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || true
-    printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
-    if printf '%s\n' "$INSTALL_OUTPUT" | grep -qi 'error\|fatal'; then
-        log_warn "brew install datadog-labs/pack/pup failed -- trying cargo install fallback..."
+    # Fresh install: Homebrew tap when available, else build from source with cargo.
+    # Success is judged by `pup` being on PATH afterwards -- not by grepping output
+    # (brew can exit non-zero on non-fatal warnings; a missing brew prints neither word).
+    if command -v brew >/dev/null 2>&1; then
+        log "Installing Pup via Homebrew (datadog-labs/pack tap)..."
+        INSTALL_EC=0
+        # || records brew's exit status; the binary check below decides success
+        INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || INSTALL_EC=$?
+        printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
+            if [ -n "$line" ]; then log "$line"; fi
+        done
+        log "brew install exit code: $INSTALL_EC"
+    else
+        log "Homebrew not found -- skipping the datadog-labs/pack tap"
+    fi
+    hash -r
+    if ! command -v pup >/dev/null 2>&1; then
+        log_warn "Pup not installed via Homebrew -- trying cargo install fallback..."
         if command -v cargo >/dev/null 2>&1; then
             # Pre-flight: check build prerequisites
             hash -r 2>/dev/null  # Refresh command cache -- picks up tools installed by earlier steps
@@ -98,7 +135,9 @@ else
             fi
             CARGO_EC=0
             CARGO_OUTPUT=$(cargo install --git https://github.com/datadog-labs/pup 2>&1) || CARGO_EC=$?
-            printf '%s\n' "$CARGO_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
+            printf '%s\n' "$CARGO_OUTPUT" | while IFS= read -r line; do
+                if [ -n "$line" ]; then log "$line"; fi
+            done
             if [ "$CARGO_EC" -ne 0 ]; then
                 # Diagnose: scan for known failure signatures
                 DIAGNOSIS=$(diagnose_build_failure "$CARGO_OUTPUT") || true
```

**Error-handling audit**

| Construct | Comment | Result check |
|---|---|---|
| `uv --version 2>/dev/null \|\| echo …` (×2) | "version probe only" | default-value fallback |
| `brew install uv … \| while … \|\| BREW_RC=$?` | "records the pipeline status (pipefail)…" | `[ "$BREW_RC" -eq 0 ] && [ -x "$BREW_UV" ]` → else `log_warn` + WARN "(brew failed)" (F3) |
| `brew uninstall … \|\| UNINSTALL_EC=$?` | "records brew's exit status; checked below" | `[ "$UNINSTALL_EC" -ne 0 ]` → `log_warn` |
| `brew untap … >/dev/null 2>&1` | "A leftover tap entry is harmless…; report it" | `if !` → `log_warn` |
| `brew install …pup … \|\| INSTALL_EC=$?` (×2) | "records brew's exit status; the binary check below decides success" | `[ ! -x "$BREW_PUP" ]` → WARN (migration) / `command -v pup` → cargo fallback (fresh) |
| `rm -f "$PUP_PATH"` | — | `if` → `log` / `log_warn` (was `2>/dev/null \|\| log_warn`) |
| `pup version 2>/dev/null \|\| echo …` (×2) | "version probe only" | default-value fallback |
| cargo block | unchanged except loop form | `CARGO_EC` + `diagnose_build_failure` → ERROR (pre-existing) |

**Pre-existing, not changed** (adjacent):
- `brew upgrade … 2>&1) || true` in both scripts' upgrade branches is consumed by the Standard 3 output grep.
- `hash -r 2>/dev/null` in the cargo block has a comment; `hash -r` cannot fail meaningfully.
- `PREREQ_MISSING=… || true` is consumed by the `-n` check.

**Test**: `test-a5.sh`, 15/15:
- uv kept with WARN and no false message
- no uv and no brew → ERROR, exit 1
- pup kept with WARN
- no pup and no brew → cargo fallback reached; summary carries the built version
- cargo silent failure → exit 1 with ERROR (no `set -e` abort)

---

## Batch A6 — Python: feature-detect `--upgrade` (#16)

**Files**: `scripts/setup-python.sh`, `scripts/setup-python.ps1`

**Change**: pass `--upgrade` only when `uv python install --help` lists it. Otherwise
WARN plus ACTION "Upgrade uv", and install without the flag. The install no longer fails
outright on older uv (0.8.17 on this host lacks the flag; verified). The bash loop moves to the `if … fi` form.

```diff
diff --git a/scripts/setup-python.sh b/scripts/setup-python.sh
index 96c9924..bbb5ea3 100755
--- a/scripts/setup-python.sh
+++ b/scripts/setup-python.sh
@@ -40,12 +40,24 @@ fi
 # --default: install unversioned python/python3 executables into uv's bin dir.
 # --preview-features python-install-default: silence the experimental warning and
 #   pin the behavior (the --default flag is gated behind this preview feature).
+# --upgrade: only on uv versions that support it (older uv rejects the flag and the
+#   whole install fails); without it an already-installed $TARGET_PY_VERSION is kept as is.
+UPGRADE_ARGS=()
+# || true: the help text is the result -- checked for the flag immediately below
+UV_INSTALL_HELP=$(uv python install --help 2>&1) || true
+if [[ "$UV_INSTALL_HELP" == *"--upgrade"* ]]; then
+    UPGRADE_ARGS=(--upgrade)
+else
+    log_warn "$(uv --version 2>&1 || echo "uv") does not support 'uv python install --upgrade' -- installing without it"
+    write_summary WARN "python" "uv too old for --upgrade"
+    write_summary ACTION "" "Upgrade uv, then re-run aitools install"
+fi
 log "Installing/updating uv-managed Python $TARGET_PY_VERSION as default..."
 INSTALL_RC=0
-INSTALL_OUTPUT=$(uv python install "$TARGET_PY_VERSION" --default --upgrade \
+INSTALL_OUTPUT=$(uv python install "$TARGET_PY_VERSION" --default ${UPGRADE_ARGS[@]+"${UPGRADE_ARGS[@]}"} \
     --preview-features python-install-default 2>&1) || INSTALL_RC=$?
 printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
-    [ -n "$line" ] && log "$line"
+    if [ -n "$line" ]; then log "$line"; fi
 done
 if [ "$INSTALL_RC" -ne 0 ]; then
     log_error "uv python install failed (see log above)"
```

```diff
diff --git a/scripts/setup-python.ps1 b/scripts/setup-python.ps1
index afac238..a6a44d8 100644
--- a/scripts/setup-python.ps1
+++ b/scripts/setup-python.ps1
@@ -43,8 +43,21 @@ if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
 # --default: install unversioned python/python3 executables into uv's bin dir.
 # --preview-features python-install-default: silence the experimental warning and
 #   pin the behavior (the --default flag is gated behind this preview feature).
+# --upgrade: only on uv versions that support it (older uv rejects the flag and the
+#   whole install fails); without it an already-installed $targetPyVersion is kept as is.
+$upgradeArgs = @()
+# The help text is the result -- checked for the flag immediately below
+$uvInstallHelp = uv python install --help 2>&1 | Out-String
+if ($uvInstallHelp -match '--upgrade') {
+    $upgradeArgs = @('--upgrade')
+} else {
+    $uvVersion = (uv --version 2>&1 | Out-String).Trim()
+    LogWarn "$uvVersion does not support 'uv python install --upgrade' -- installing without it"
+    Write-Summary "WARN" "python" "uv too old for --upgrade"
+    Write-Summary "ACTION" "" "Upgrade uv, then re-run aitools install"
+}
 Log "Installing/updating uv-managed Python $targetPyVersion as default..."
-$installOutput = uv python install $targetPyVersion --default --upgrade --preview-features python-install-default 2>&1 | Out-String
+$installOutput = uv python install $targetPyVersion --default @upgradeArgs --preview-features python-install-default 2>&1 | Out-String
 $installOutput.Trim().Split("`n") | ForEach-Object {
     $l = $_.TrimEnd()
     if ($l.Trim()) { Log $l }
```

**Error-handling audit**

| Construct | Comment | Result check |
|---|---|---|
| `UV_INSTALL_HELP=$(…2>&1) \|\| true` | "the help text is the result — checked for the flag immediately below" | `[[ … == *"--upgrade"* ]]` → else `log_warn` + WARN + ACTION |
| `$(uv --version 2>&1 \|\| echo "uv")` | inline in a log message | default fallback |
| `${UPGRADE_ARGS[@]+"${UPGRADE_ARGS[@]}"}` | bash 3.2 + `set -u` safe empty-array expansion | — |
| PS1 `$uvInstallHelp = uv … 2>&1 \| Out-String` | "The help text is the result…" | `-match '--upgrade'` → else `LogWarn` + WARN + ACTION |

**Test**: `test-a6.sh`, 7/7. Old uv: called without `--upgrade`, WARN and ACTION, exit 0. New uv: called with `--upgrade`, `OK|python|… (uv)`.

---

## Batch D — docs, registry, release (protected items presented with this plan)

Main agent, direct (no code). Every item below is part of **this review**:

1. **`reference/script-standards-detail.md`** tool-name table: add a row after `cursor cli`:
   ```
   | `aitools config` | aitools-install |
   ```
2. **Go registry entry via `/tool-registry`** (protected): the non-preferred "manual
   tarball" cleanup applies to **macOS only**, not macOS/Linux. Note the install-first/cleanup-after
   ordering. The hand-maintained `reference/tool-registry.md` Go section gets the same edit:
   it duplicates the registry, #21. The exact old→new text is drafted at execution time from a
   `/tool-registry` read and shown in the batch D checkpoint before writing.
3. **`RELEASE_NOTES.md`**: new entry above v0.73.1:

   ```
   ## v0.73.2 -- Fix: safe re-runs on Linux -- config merge, Go/pup cleanup order, exit status (2026-10-03)

   ### Bug fixes

   | # | Severity | Change |
   |---|----------|--------|
   | 1 | Critical | Re-running `aitools install` corrupted `~/.aitools/config.json`: the bash Step 5 `read_config_drives` sed range ran to EOF on an inline `"googleDrives": []` and spliced the rest of the file into a `cat >` heredoc. Step 5 is now a node read-then-merge (temp file → `validate_json_config` → `backup_file` → `mv`), preserves `userRepoPath`/`machineAlias`, rebuilds a corrupt file (WARN, invalid copy backed up), and honors `--dry-run`. (#11) |
   | 2 | Critical | `setup-go.sh` deleted `/usr/local/go` before checking for Homebrew, leaving Linux with no Go. On Linux the go.dev tarball is now classified `upstream` and kept; on macOS non-preferred installs are removed only after Homebrew Go is verified. (#12) |
   | 3 | High | `aitools` exited 0 when the installer or deploy reported errors. Both entry points now exit 1 (install, gitpull, sync). (#13) |
   | 4 | Medium | `setup-gh-cli.sh` "updated" an existing gh from the distro archive (2.45) and shadowed non-apt installs. It now adds the cli.github.com repo whenever missing and leaves non-apt gh untouched (WARN). (#15) |
   | 5 | Medium | `setup-python` failed outright on uv versions without `uv python install --upgrade`; the flag is now feature-detected (WARN + ACTION to upgrade uv). (#16) |
   | 6 | Low | `setup-uv.sh` reported `[ok] uv installed via Homebrew` when Homebrew had not run; a kept non-Homebrew uv is now WARN. (#17) |
   | 7 | Medium | `setup-datadog.sh` never reached the cargo fallback when Homebrew was absent, and deleted a non-Homebrew pup before the replacement installed. Fallback now keys on the binary; migration is install-first. (#18) |

   ### Documentation

   | # | Change |
   |---|--------|
   | 8 | `aitools config` added to the summary tool-name table; Go registry cleanup scoped to macOS. |

   **Verified on:** Linux (Ubuntu 24.04, Claude Code web, no Homebrew): `bash -n` clean on all edited `.sh`; 65/65 behavior checks across six sandboxed harnesses; `aitools install` run twice — exit status matches installer result, config valid on both runs, `/usr/local/go` intact. macOS/Windows: CI only (no local run) — `.ps1` edits (`aitools.ps1`, `setup-python.ps1`) not executed.
   ```

## Batch R — build, verify end-to-end, release

1. `bash scripts/build-deploy.sh`. This regenerates the **dotprofile** `deploy/` (`deploy-paths.md`); check that the counterparts of the 10 edited scripts contain the change. Commit it in `aitools-nobul-jose` on the same branch.
2. Restore Go from go.dev for an honest end-to-end test. Use the official tarball per go.dev/doc/install, verified against the published sha256, into `/usr/local/go`. The bug removed it.
3. Back up `~/.aitools/config.json`. Run the install twice under a pty (`aitools install --skip-gh-auth --repos-path /home/user/nobul-jose/repos --skip-drive-detection`) and redirect each run to a log (smoke-test pattern). Then assert:
   - wrapper exit = installer result
   - `node -e "require('/root/.aitools/config.json')"` passes after each run, and the second run logs `Unchanged`
   - `/usr/local/go/bin/go` still present
   - gh unchanged
   - no `[ok] … via Homebrew` lines
   - `~/.claude/CLAUDE.md` has no `{{` placeholders
4. Inject a failure: re-run with a stub failing setup script on PATH, or `chmod -x` a stub copy. Assert `aitools` exits 1, then revert.
5. `check-pre-commit.sh`, then commit with `Jose <jose@nobul.tech>`. The message ends `(tested: Linux)` with the trailers.
6. `check-pre-push.sh`, then push `-u origin claude/fable-status-q9ch93`. Open a PR in both repos (aitools PR links #10–#18), then run `check-post-push.sh`.
7. The tag/version bump is confirmed with the commander before tagging.
8. After merge, update via `/incident`: `correctiveAction` on each incident filed in nobul-tech/aitools#20 whose linked issue is one of #11–#18, plus the `/investigate` barrier analysis per issue before closing.

## Risks

| Risk | Mitigation |
|---|---|
| macOS behavior change in setup-go (cleanup now after install) | Same end state when brew works; strictly safer when it fails. Exercised in macOS CI only. **Untested locally.** |
| `aitools` now exits 1 where it used to exit 0; scripted callers may depend on 0 | That is the bug (#13). Called out in the release notes. |
| PS1 edits not executed here | Windows CI parse and run; the change is small and mirrors bash. |
| pup/uv non-Homebrew path on macOS with brew present but formula failing | Covered by the WARN-and-keep branch. Not exercised; brew isn't available here. |
