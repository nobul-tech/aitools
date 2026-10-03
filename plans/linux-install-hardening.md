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
   it duplicates the registry (incident #21, not GitHub #21). The exact old→new text is drafted at execution time from a
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

## PR C: logging conformance (epic #21, issues #22–#30, plus #31)

> **Status: PR C1 (batches C1, C2, C3a, C4a) shipped in v0.73.3 (2026-10-03).
> PR C2 (batches C3b, C4b, T1, D-C2) shipped 2026-10-03 (#37).
> PR C3 (batch C5, D-C3) approved for execution 2026-10-03.**
> Verbatim edits, the error-handling audits and the prototype test evidence are in
> the "PR C1/C2/C3 — verbatim edits" sections below; the logging audit plan is in the
> PR C2 section. Batches C6–C15 remain scoped only: each needs its own verbatim-edit
> revision of this section, presented for approval, before code is written.

### Origin

PR A's end-to-end Linux run (two installs from branch clones under an isolated HOME) surfaced
three defects:
- `setup-rust` logged a 3-line backtrace tail under "see log above".
- `setup-user-settings` died at a prompt with no `[error]` line or summary row.
- `setup-cursor-ide-mcp` logged a false "likely not configured".

A follow-up sub-agent audit then covered:
- every `setup-*.sh/.ps1`, both installers and both entry points, read in full or by pattern
- the four `*-lib` files, read in full by the main agent

It checked them against `script-standards.md`, `script-standards-detail.md` and `logging.md`.
The main agent spot-checked the audit's findings: `aitools:345` "exit 0", `aitools:1405` override clobber, `setup-user-cursor.sh:70`.

### Issues

| Issue | Root cause | Main files |
|---|---|---|
| #22 | Output truncated before logging | `setup-rust.sh/.ps1`, `aitools`, `aitools.ps1` |
| #23 | Output discarded or never logged (32 sites) | most `setup-*`, `aitools-install.*`, `aitools*` |
| #24 | `[ -n ] && log` piped loops abort under `set -e` | `setup-rust.sh`, `aitools-lib.sh` |
| #25 | Console output bypassing the logging framework | node merge blocks in `setup-user-cursor/hooks`, `setup-cursor-ide-mcp`; `setup-user-claude.sh`; `ReadConfigKey`; `aitools*` |
| #26 | Failure paths without `write_summary ERROR`; PS1 OK-after-LogError | most `setup-user-*`, `setup-cursor-ide-mcp.*`, installers, entry points |
| #27 | Output-grep success checks; misleading pointers (`exit $?` always 0) | `setup-rust`, `setup-modal`, `setup-vercelcli`, `aitools-install.sh`, `aitools-lib.sh`, `aitools`, `setup-cursor-ide-mcp` |
| #28 | Entry-point log override clobbered | `aitools`, `aitools.ps1` |
| #29 | Prompts die silently on EOF; inconsistent non-interactive detection | `aitools-lib.sh/.ps1` |
| #30 | Malformed or misattributed records; unguarded backup; silent manifest wipe | `aitools-lib.sh/.ps1`, `check-lib.ps1` |
| #31 | Fresh install: settings synced before `settings.json` exists | `aitools-lib.sh/.ps1` (`sync_managed_json`), deploy order |
| -- | `aitools install --force` / `-Force` never reached the installer (found during C1 review; fixed directly, no issue filed, per commander) | `aitools`, `aitools.ps1` |

### Foundational decisions

| # | Decision | Status |
|---|---|---|
| C-F1 | **Lib first.** Fix the shared helpers (#29 EOF-safe `read_tty_choice`/`Read-ConsoleChoice`, #30 guarded `backup_file`, checked deploy-state writes, `log_detail` diffs) before the scripts, so per-script fixes can call them. | Approved 2026-10-03 |
| C-F2 | **Exit code decides; output is logged in full.** Every install/update/uninstall: capture `2>&1`, `\|\| RC=$?`, log every line (verbose output via `log_detail`), decide on `RC` plus a binary check. Output grep stays only where Standard 3 allows it (`brew upgrade`). | Approved 2026-10-03 |
| C-F3 | **Every exit path writes a summary row.** `write_summary ERROR` before each `exit 1`. PS1 validation blocks compare error counts before and after and write ERROR instead of OK. Orchestrators add `ERROR "<script>" "script failed (exit N)"` when a child dies. | Approved 2026-10-03 |
| C-F4 | **Bash/PS1 parity is part of each fix.** Every row in the audit's parity table is closed in the same batch as its counterpart. | Approved 2026-10-03 |
| C-F5 | **#31: create from profile when `settings.json` is absent** (option 2 in the issue). `sync_managed_json` writes the profile mirror without prompting; deploy order is unchanged. | Approved 2026-10-03 |
| C-F6 | **Spec questions go through `/incident`, not code:** Standard 3 WARN-vs-ERROR for `brew upgrade` (#27c), and the `aitools` logging-overrides table (#28) if console output becomes the intent. | Standard 3: proposed (C5+). #28: resolved by C-F9 2026-10-03 |
| C-F7 | **One interactivity rule, both commands, every platform.** `aitools` and `aitools install` each run interactive or non-interactive, decided by the caller: interactive iff stdin is a terminal and neither `--force`/`-Force` nor `AITOOLS_FORCE=1` is set. Applies to the review prompts and to the installers' own prompts (gh login, repos path). Non-interactive: source wins (backup kept, WARN), installer prompts take their defaults. EOF at a prompt: WARN, then the same default. The `< /dev/null` on the bash install path is removed (it made macOS/Linux install non-interactive while Windows install was interactive). | Approved 2026-10-03 |
| C-F8 | **C1 (lib rule) and C3a (entry-point redirect) ship in the same PR.** C1 alone would make macOS/Linux `aitools install` non-interactive. | Approved 2026-10-03 |
| C-F9 | **Entry points load aitools-lib as early as they can and define no logging of their own (#28).** `scripts/aitools` / `aitools.ps1` source the lib as soon as `repoPath` is read; only `--help`, `--version` and the missing-repo clone run before it, and warnings found before it are logged right after it loads. The `scripts/aitools` row leaves the logging-overrides table. `aitools-install` keeps its JSONL override until JSONL moves into the lib (follow-up). | Approved 2026-10-03 |

### Batches

PR C1 (this revision; ≤3 code files per batch; `aitools-lib.*` changes ⇒ fresh sub-agent per batch):

| Batch | Files | Issues |
|---|---|---|
| C1 | `aitools-lib.sh` | #29, #30, #24 (`repair_uv_tool_env`), #27a (repair exit code), #31, C-F7 (`tty_interactive`) |
| C2 | `aitools-lib.ps1`, `check-lib.ps1`, `check-lib.sh` | #29, #30, #25 (`ReadConfigKey`), #31, C-F7 (`Test-InteractiveConsole`); audit: silent catches in `Get-DeployShadow`/`Try-AutoMerge`, uncommented suppressions in `check-lib.sh` |
| C3a | `aitools`, `aitools.ps1` | C-F7 (install no longer forced non-interactive), `--force` reaches install |
| C4a | `aitools-install.sh`, `aitools-install.ps1` | C-F7 (installer prompts), #29 (Step 3 read EOF-safe), stale "non-interactive install wrapper" comment |
| D-C1 | protected docs (approved 2026-10-03) | `interactive-menus.md` non-interactive fallback; `script-standards-detail.md` exemptions table rows; RELEASE_NOTES |

PR C2 (approved 2026-10-03; verbatim edits in "PR C2 — verbatim edits"):

| Batch | Files | Issues |
|---|---|---|
| C3b | `aitools`, `aitools.ps1` | #22, #23, #25, #26e, #27b, #28 (C-F9) |
| C4b | `aitools-install.sh`, `aitools-install.ps1` | #23, #25, #26b (Step 5 PS1 row), #26e (`$LASTEXITCODE`), #27a (`claude update`); remove dead Windows branches |
| T1 | `tests/logging/test-logging.sh`, `tests/logging/test-logging.ps1` (new), `.github/workflows/check.yml` | Logging unit tests (audit checks U1, U2), run on all three CI runners |
| D-C2 | protected docs (approved 2026-10-03) | `script-standards-detail.md` logging overrides (`scripts/aitools` row removed, entry-point text); `CLAUDE.md` `tests/` line; this plan. RELEASE_NOTES deferred |

PR C3 (approved 2026-10-03; verbatim edits in "PR C3 — verbatim edits"):

| Batch | Files | Issues |
|---|---|---|
| C5 | `setup-rust.sh`, `setup-rust.ps1`, `setup-typst.sh` | #22, #23, #24, #27 |
| D-C3 | protected docs (approved 2026-10-03) | exemptions table: `setup-rust.sh` and `setup-typst.sh` rows removed; this plan. RELEASE_NOTES deferred |

Later PRs (scoped, not approved):

| Batch | Files | Issues |
|---|---|---|
| C6 | `setup-typst.ps1`, `setup-pandoc.sh`, `setup-pandoc.ps1` | #23, #26a |
| C7 | `setup-modal.sh`, `setup-modal.ps1`, `setup-go.ps1` | #23, #26d, #27a |
| C8 | `setup-vercelcli.sh`, `setup-vercelcli.ps1`, `setup-gh-cli.ps1` | #23, #26a, #27a, auth WARN row |
| C9 | `setup-user-cursor.sh`, `setup-user-cursor.ps1` | #23, #25, #26b–d |
| C10 | `setup-user-hooks.sh`, `setup-user-hooks.ps1` | #25, #26a–c, #26f, #27b |
| C11 | `setup-user-settings.sh`, `setup-user-settings.ps1`, `setup-gh-cli.sh` | #26a–c; remove the "No settings.json yet" early exit (#31 caller half) |
| C12 | `setup-cursor-ide-mcp.sh`, `setup-cursor-ide-mcp.ps1` | #25, #26a–c, #27b (Cursor `mcp` verbs, re-verified via `/tool-eval` first) |
| C13 | `setup-user-mcp.sh`, `setup-user-mcp.ps1`, `setup-datadog.ps1` | #23, #26a |
| C14 | `setup-user-claude.sh`, `setup-user-claude.ps1` | #23, #25, #26a |
| C15 | `check-pre-commit.sh`, `check-pre-commit.ps1` (+ allowlist) | Logging audit checks A1-A11 as pre-commit steps, observe/WARN first, FAIL per check once its count is zero (see "Logging audit plan") |
| D-C | protected docs (batch-presented) | Exemptions table: remove the typst/pandoc/vercel/rust entries once those discards are fixed. Standard 3 outcome via `/incident`. RELEASE_NOTES. |

`setup-user-claude`, `setup-user-cursor` and `setup-user-hooks` have logic duplicated in
`build-deploy.sh` (`deploy-paths.md`). Batches C9, C10 and C14 must port each fix there and
confirm the regenerated dotprofile `deploy/` contains it (pre-commit step 13).

### Verification (each batch)

- `bash -n` and `pwsh` ParseFile (pwsh is now installable here from packages.microsoft.com).
- A stub-driven behavior test per fixed failure path. For example, a pty prompt with `/dev/null` input must log a line and default to overwrite (#29). An empty rustup output must not abort (#24).
- Grep the changed files for the old patterns: `tail -3`, `head -3`, `&& log "$line"; done`, `exit $?` inside `if !`.
- Any batch touching `aitools-lib.*` or a setup script: run `bash scripts/build-deploy.sh` and commit the regenerated `deploy/` in the dotprofile repo (`deploy-paths.md`).
- A final end-to-end install ×2 (same harness as PR A). Both runs must:
  - write a summary row for every script that ran
  - have zero raw lines in `deploy.log`
  - pass the second run with no prompts on a fresh HOME (#31)

### Detection (prevent recurrence)

Add check-pre-commit steps, starting in observe/WARN mode per `hook-rollout.md` practice:
- piped `[ … ] && log` loops
- `tail -N`/`head -N` piped into `log`
- `exit $?` inside an `if !` branch
- `exit 1` without a `write_summary` in the preceding 3 lines
- a `while read … done < file` loop whose body calls a review prompt (stdin is no longer the terminal; found in C1, `sync_managed_json`)

## PR C1 — verbatim edits (batches C1, C2, C3a, C4a)

Base: `main` @ 19a744e. Each diff below is the exact edit for its batch, prototyped on a
copy of the base and tested there (scratch: `.scratch/session-3030c86a-9/proto-c/`).


### Tests (stub-driven, isolated HOME per case)

| Suite | Prototype | `main` (same tests) |
|---|---|---|
| `test-c1.sh` (bash lib) | 24/24 pass | prompt cases die silently at the prompt, corrupt manifest kills the script with no output, uv repair reports false success |
| `test-c2.sh` (PS1 libs) | 26/26 pass | redirected stdin crashes `Prompt-DiffReview`, failed backup/state write throws, `"os":"Windows"` on Linux |
| `build-proto.sh` (gap 3) | `build-deploy.sh` exit 0, 40 scripts, all PS1 parse, all 20 `.sh` pass `bash -n`, every deploy script carries the new helpers | -- |

### Revision 3 (interactive/non-interactive mode, C1/C3 approved 2026-10-03)

Requirement: `aitools` and `aitools install` must each run interactive and non-interactive.

| Run as | Mode | Review prompts | Installer prompts (gh login, repos path) |
|---|---|---|---|
| From a terminal | interactive | shown; EOF -> source wins, backup, WARN | shown; EOF -> default |
| No terminal (piped, CI, agent, MDM) | non-interactive | source wins, backup, WARN | skipped (defaults) |
| `--force` / `AITOOLS_FORCE=1` | non-interactive | source wins, backup, WARN | skipped (defaults) |

| File | Change |
|---|---|
| `aitools-lib.sh` | `tty_interactive` (stdin is a terminal AND `/dev/tty` opens) used by both review prompts; `sync_managed_json` reads its decision list on fd 3 so the prompt still sees the caller's stdin (found by the e2e matrix: the old loop fed the TSV on stdin) |
| `aitools` (C3) | `< /dev/null` removed from the install path; `--force` now exported as `AITOOLS_FORCE` for install (bug: install ignored `--force`); usage text |
| `aitools.ps1` (C3) | `-Force` now exported as `AITOOLS_FORCE` for install (same bug); usage text |
| `aitools-install.sh` (C4) | `INSTALL_INTERACTIVE` = terminal and not forced, for Steps 2-3; Step 3 read is EOF-safe (`read_tty_choice`); help text; stale "non-interactive install wrapper" comment |
| `aitools-install.ps1` (C4) | `$installInteractive` = `Test-InteractiveConsole` and not forced (was `UserInteractive`, which is true with piped stdin); Step 3 `Read-Host` -> `Read-ConsoleChoice`; help text; same comment |

Tests (Linux):

| Suite | Prototype | `main` |
|---|---|---|
| `test-mode.sh` (lib prompts under a real pty: typed answers, EOF, forced, redirected stdin, no tty) | 15/15 | -- |
| `test-mode-e2e.sh` (real `aitools` + installer, stubbed tools; install x4 modes, sync x3) | 18/18 | 11/18: install never interactive, EOF kills the run, `--force` still shows REVIEW |
| `parse-entry.sh` (`bash -n` / pwsh ParseFile on all 4 entry points + installers) | pass | -- |

Not testable here: PS1 entry point and installer behaviour (OS guard: Windows only) -- parse-checked only; needs a Windows run. macOS run needed for the bash path. Commits carry `(tested: Linux)`.

Ordering: C1 (lib) and C3 (entry points) ship in one PR -- C1 alone would make macOS/Linux `aitools install` non-interactive.

Pending protected edit (drafted for review with the plan section): `interactive-menus.md` "Non-interactive fallback" -- name `--force` and the installer prompts.

### Revision 2 (gaps 1-4, approved 2026-10-03)

| Gap | Change |
|---|---|
| 1 | `Get-DeployShadow` and `Try-AutoMerge` catches now `LogWarn` (were silent `return $null`); test `shadow-fail` added |
| 2 | `check-lib.sh` added to C2: comments on `resolve_config` and `get_mtime` suppressions (callers verified: `check-post-push.sh` newest-transcript scan and plan-age check) |
| 3 | C1/C2 verification adds: run `bash scripts/build-deploy.sh`, commit regenerated `deploy/` in aitools-nobul-jose (`deploy-paths.md`) |
| 4 | Exemptions table in `reference/script-standards-detail.md` (protected) -- draft below |

#### Gap 4 draft: `reference/script-standards-detail.md` "Exemptions table"

Every row re-checked against current code. Line numbers for `check-lib.ps1` assume C2 is applied.

```diff
 | Script | Line(s) | Pattern | Reason |
 |--------|---------|---------|--------|
 | `setup-vercelcli.sh` | 69 | `2>/dev/null \|\| true` | Cleanup: npm uninstall may fail if not installed; brew install follows |
-| `setup-pandoc.sh` | 68, 73, 77 | `2>/dev/null \|\| true` | Cleanup: non-preferred package managers may not be installed |
-| `setup-rust.sh` | 44 | `2>/dev/null \|\| log_warn` | Cleanup: brew formula may not be fully installed; warned on failure |
-| `aitools-install.sh` | 273 | `2>/dev/null \|\| true` | Update: apt-get may need sudo; gh already works at current version |
-| `check-lib.ps1` | 110 | `2>$null` (InvokeGit) | Git stderr triggers PS ErrorActionPreference=Stop; caller checks result |
-| `check-lib.ps1` | 79-81 | `try/catch` (ReadConfigKey) | Config parse: catch logs warning; callers handle null return via ResolveConfig |
-| `setup-typst.sh` | 38, 43 | `2>/dev/null \|\| true` | Cleanup: cargo/npm may not have typst installed; Homebrew install follows |
-| `setup-typst.ps1` | 45, 53 | `2>$null` | Cleanup: cargo/npm stderr noise; non-blocking, winget install follows |
+| `setup-pandoc.sh` | 68, 73, 78 | `2>/dev/null \|\| true` | Cleanup: non-preferred package managers may not be installed |
+| `setup-rust.sh` | 32 | `2>/dev/null \|\| log_warn` | Cleanup: brew formula may not be fully installed; warned on failure |
+| `check-lib.ps1` | 177 | `2>$null` (InvokeGit) | Git stderr triggers PS ErrorActionPreference=Stop; caller checks result |
+| `setup-typst.sh` | 26, 31 | `>/dev/null 2>&1 \|\| true` | Cleanup: cargo/npm may not have typst installed; Homebrew install follows |
+| `setup-typst.ps1` | 25, 33 | `2>$null \| Out-Null` | Cleanup: cargo/npm stderr noise; non-blocking, winget install follows |
```

- Removed `aitools-install.sh:273`: the apt-get gh update moved to `setup-gh-cli.sh` in v0.73.2 (#33); the line no longer exists.
- Removed `check-lib.ps1:79-81` (ReadConfigKey): the function lives in `aitools-lib.ps1`, and after C2 its catch logs via `LogWarn`, so it is compliant and needs no exemption.
- Later batches (#23) capture the cleanup output in typst/pandoc/vercel/rust; those rows are removed by the batch that fixes each script.

PS1 EOF note: a pty cannot deliver EOF to pwsh (`[Console]::ReadLine` switches the terminal to raw
mode and hangs). The PS1 EOF cases use stdin at EOF with `Test-InteractiveConsole` stubbed true,
which drives the same `ReadLine()` -> `$null` path.

### Error-handling audit (`plan-execution-detail.md` §audit)

| # | Site | Before | After | Issue |
|---|---|---|---|---|
| 1 | `backup_file` cp | unguarded; set -e abort, no log | `if ! cp` -> `log_warn`, proceed | #30 |
| 2 | `backup_file` prune | `ls … 2>/dev/null \| xargs rm -f 2>/dev/null`, no check | commented `2>/dev/null` (empty list handled), per-file `rm` checked -> `log_warn` | #30 |
| 3 | `initialize_deploy_state` | corrupt manifest read raw; later node calls fail | validated once; corrupt -> `log_warn`, moved to `.corrupt`, fresh start; `mv` checked | #30 |
| 4 | `get_deploy_state_hash` node | `2>/dev/null`, unchecked | stderr visible; returns node's rc; caller (`deploy_managed_file`) logs `log_warn`; init hoisted out of `$(...)` so warnings are counted | #30 |
| 5 | `update_deploy_state` node | `2>/dev/null`; failure wrote an **empty manifest** | rc + empty-output checked -> `log_warn`, previous manifest kept | #30 |
| 6 | 6 × `read -r … < /dev/tty` | EOF -> rc 1 -> silent set -e abort | `read_tty_choice`: `log_warn` "No input at prompt (EOF) -- defaulting to …", caller default applies | #29 |
| 7 | `prompt_diff_review` log | raw diff appended to log only when > 40 lines (broke log format) | every diff line as `[detail] diff <file>: …`, all sizes | #30 |
| 8 | `sync_managed_json`, live file absent | prompted every profile key; died at EOF | creates from profile without prompts (logged), `mkdir -p` parent | #31 |
| 9 | `repair_uv_tool_env` output loop | piped `[ -n ] && log` (set -e hazard) | here-string + `if … fi` | #24 |
| 10 | `repair_uv_tool_env` result | grep `error.*failed` (missed real failures) | exit code decides; logged with rc | #27a |
| 11 | `repair_uv_tool_env` `uv python find` | `2>/dev/null \|\| true` uncommented | comment added; result already checked by `-n/-x` | audit |
| 12 | `ReadConfigKey` (PS1) | `Write-Host` console bypass | `LogWarn` when logging is initialized, else `Write-Warning` | #25 |
| 13 | `Backup-File` (PS1) | unguarded `Copy-Item`/`Remove-Item` | try/catch -> `LogWarn`, proceed | #30 |
| 14 | `Initialize-DeployState` (PS1) | corrupt manifest silently overwritten | moved to `.corrupt` (checked), same message as bash | #30 |
| 15 | `Update-DeployState` (PS1) | write failure threw (fatal under Stop) | try/catch -> `LogWarn` | #30 |
| 16 | 6 × `[Console]::ReadLine()` (PS1) | `$null.ToLower()` threw at EOF | `Read-ConsoleChoice` (same log line as bash) | #29 |
| 17 | non-interactive test (PS1) | `UserInteractive` in one prompt, `IsInputRedirected` in the other | `Test-InteractiveConsole` (both) used by both prompts | #29 |
| 18 | `Prompt-DiffReview` log (PS1) | console said "see deploy log"; nothing was logged | every diff line as `[detail]` | #30 |
| 19 | `Sync-ManagedJson`, live file absent (PS1) | prompted | same as #8 | #31 |
| 20 | `CheckLogInit` (PS1) | `"os":"Windows"` hardcoded | `Windows`/`macOS`/`Linux` from `$Is*` | #30 |

Behavior changes to note:
- EOF at any prompt now continues with the default (overwrite) **plus a WARN**, instead of killing
  the run. The summary row turns WARN via auto-promotion.
- PS1 `Prompt-DiffReview` with redirected stdin (e.g. run from an agent) now auto-overwrites with
  a WARN, matching `Prompt-JsonFieldReview` and bash. Previously it prompted and crashed.
- Fresh HOME: profile settings land on the **first** run (#31, lib half). Removing the
  `setup-user-settings.sh` "No settings.json yet" short-circuit is batch C11.

Not in C1/C2 (later batches): `x)abort` paths lack `write_summary ERROR` (#26, per-script batches);
`backup_dir` prune loop is piped but has no `&&` hazard (left as is).


### Batch C1 — aitools-lib.sh

#### `scripts/aitools-lib.sh`

```diff
diff --git ascripts/aitools-lib.sh bscripts/aitools-lib.sh
index 58a2771..308f445 100755
--- ascripts/aitools-lib.sh
+++ bscripts/aitools-lib.sh
@@ -309,9 +309,24 @@ backup_file() {
     [ -f "$file" ] || return 0
     local ts
     ts=$(date -u +%Y-%m-%dT%H%M%SZ)
-    cp "$file" "${file}.bak.${ts}"
-    # Prune oldest beyond limit
-    ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1)) | xargs rm -f 2>/dev/null
+    # A failed backup is non-fatal (config-file-safety.md "Backup before overwrite"):
+    # warn and let the caller proceed.
+    if ! cp "$file" "${file}.bak.${ts}"; then
+        log_warn "Could not back up $(display_path "$file") -- proceeding without backup"
+        return 0
+    fi
+    # Prune oldest beyond limit.
+    # 2>/dev/null: ls errors only if no backup matches; the backup just written always does,
+    # and an empty list is handled by the -n check below.
+    local old_backups old
+    old_backups=$(ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1))) || old_backups=""
+    if [ -n "$old_backups" ]; then
+        while IFS= read -r old; do
+            if [ -n "$old" ] && ! rm -f "$old"; then
+                log_warn "Could not prune old backup $(display_path "$old")"
+            fi
+        done <<< "$old_backups"
+    fi
     log "Backed up $(display_path "$file")"
 }
 
@@ -363,10 +378,16 @@ _deploy_state_key() {
 
 initialize_deploy_state() {
     local manifest_path="$_DEPLOY_STATE_DIR/manifest.json"
-    if [ -f "$manifest_path" ]; then
+    _DEPLOY_MANIFEST='{"version":1,"files":{}}'
+    [ -f "$manifest_path" ] || return 0
+    # Validate once here so the per-file node calls below only fail if node itself fails.
+    if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$manifest_path"; then
         _DEPLOY_MANIFEST=$(cat "$manifest_path")
     else
-        _DEPLOY_MANIFEST='{"version":1,"files":{}}'
+        log_warn "Deploy-state manifest unreadable -- starting fresh (old copy kept as .corrupt)"
+        if ! mv "$manifest_path" "${manifest_path}.corrupt"; then
+            log_warn "Could not move aside $(display_path "$manifest_path")"
+        fi
     fi
 }
 
@@ -375,13 +396,16 @@ get_deploy_state_hash() {
     if [ -z "$_DEPLOY_MANIFEST" ]; then initialize_deploy_state; fi
     local key
     key=$(_deploy_state_key "$file_path")
-    # node is already a dependency (used by read_config_key)
+    # node is already a dependency (used by read_config_key). Empty output = no record.
+    # Called via $(...): it must not log (stdout is the hash). Returns node's exit code;
+    # the caller logs. The manifest was validated in initialize_deploy_state, so a
+    # failure here is node itself.
     printf '%s' "$_DEPLOY_MANIFEST" | node -e "
         const m = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
         const f = m.files || {};
         const e = f[process.argv[1]];
         if (e && e.hash) process.stdout.write(e.hash);
-    " "$key" 2>/dev/null
+    " "$key"
 }
 
 update_deploy_state() {
@@ -395,13 +419,18 @@ update_deploy_state() {
 
     mkdir -p "$_DEPLOY_STATE_DIR"
 
-    # Update manifest via node
-    _DEPLOY_MANIFEST=$(printf '%s' "$_DEPLOY_MANIFEST" | node -e "
+    # Update manifest via node; on failure keep the previous manifest rather than writing an empty one.
+    local updated
+    if ! updated=$(printf '%s' "$_DEPLOY_MANIFEST" | node -e "
         const m = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
         if (!m.files) m.files = {};
         m.files[process.argv[1]] = { hash: process.argv[2], deployedAt: process.argv[3] };
         process.stdout.write(JSON.stringify(m, null, 2));
-    " "$key" "$hash" "$ts" 2>/dev/null)
+    " "$key" "$hash" "$ts") || [ -z "$updated" ]; then
+        log_warn "Could not update deploy state for $key -- next run may re-prompt"
+        return 0
+    fi
+    _DEPLOY_MANIFEST=$updated
 
     printf '%s\n' "$_DEPLOY_MANIFEST" > "$_DEPLOY_STATE_DIR/manifest.json"
 
@@ -672,6 +701,35 @@ _stop_spinner() {
     printf '\r  \033[K' > /dev/tty  # clear spinner line
 }
 
+# ---------------------------------------------------------------------------
+# Interactive = stdin is a terminal AND the controlling terminal can be opened.
+# Spec (managed-file-deployment.md, interactive-menus.md): non-terminal stdin ->
+# no prompt, source wins. Prompts still read /dev/tty so data piped on stdin is
+# never consumed as an answer. Parity: Test-InteractiveConsole in aitools-lib.ps1.
+# ---------------------------------------------------------------------------
+tty_interactive() {
+    [ -t 0 ] || return 1
+    # 2>/dev/null: the open fails when there is no controlling terminal; that
+    # failure is the answer (return 1), not an error to report.
+    (printf '' > /dev/tty) 2>/dev/null
+}
+
+# ---------------------------------------------------------------------------
+# EOF-safe prompt read. Usage: read_tty_choice <var> <what-the-default-does>
+# Bare `read -r x < /dev/tty` returns 1 at EOF (closed stdin under a pty), which
+# aborts the caller under set -e with no log line. This logs and returns 0 with
+# <var> empty, so each caller's `*)` default branch applies.
+# ---------------------------------------------------------------------------
+read_tty_choice() {
+    local __var="$1" __default_desc="$2" __line=""
+    if ! IFS= read -r __line < /dev/tty; then
+        printf '\n' > /dev/tty
+        log_warn "No input at prompt (EOF) -- defaulting to $__default_desc"
+        __line=""
+    fi
+    printf -v "$__var" '%s' "$__line"
+}
+
 # ---------------------------------------------------------------------------
 # Agentic merge via invoke_ai with refinement loop.
 # Uses structured prompts from _ai_prompt_merge / _ai_prompt_merge_refine.
@@ -715,7 +773,7 @@ _invoke_ai_merge() {
         else
             local feedback
             printf '  refinement feedback: ' > /dev/tty
-            IFS= read -r feedback < /dev/tty
+            read_tty_choice feedback "no feedback"
             prompt_text=$(_ai_prompt_merge_refine "$source_content" "$local_content" "$current_merge" "$feedback")
         fi
 
@@ -735,7 +793,7 @@ _invoke_ai_merge() {
             log_error "AI merge failed (iteration $iteration): ${AI_REJECT_REASON:-unknown error}"
             printf '  fallback [o]verwrite / [s]kip: ' > /dev/tty
             local fb
-            read -r fb < /dev/tty
+            read_tty_choice fb "overwrite"
             case "$(printf '%s' "$fb" | tr '[:upper:]' '[:lower:]')" in
                 s) DIFF_REVIEW_RESULT="skip" ;;
                 *) DIFF_REVIEW_RESULT="overwrite" ;;
@@ -755,7 +813,7 @@ _invoke_ai_merge() {
         fi
         printf '\n  [y]es accept / [r]efine / [n]o reject: ' > /dev/tty
         local accept
-        read -r accept < /dev/tty
+        read_tty_choice accept "reject merge (overwrite)"
         case "$(printf '%s' "$accept" | tr '[:upper:]' '[:lower:]')" in
             y)
                 MERGED_CONTENT="$merged"
@@ -811,7 +869,7 @@ prompt_diff_review() {
     fi
 
     # Non-interactive: auto-overwrite
-    if ! (printf '' > /dev/tty) 2>/dev/null; then
+    if ! tty_interactive; then
         log_warn "Diff in $(display_path "$file_path") -- overwriting (non-interactive)"
         return 0
     fi
@@ -840,8 +898,12 @@ prompt_diff_review() {
         printf '%s\n' "$diff_output" | head -30 > /dev/tty
         printf '  ... (%d more lines -- full diff in deploy log)\n' \
             "$((diff_lines - 30))" > /dev/tty
-        printf '%s\n' "$diff_output" >> "${LOG_FILE:-/dev/null}"
     fi
+    # Full diff as structured [detail] records at every size (raw appends broke the log format).
+    local diff_line
+    while IFS= read -r diff_line; do
+        log_detail "diff $(basename "$file_path"): $diff_line"
+    done <<< "$diff_output"
 
     # Attempt automatic merge if ancestor available
     if [ -n "$ancestor_content" ]; then
@@ -870,7 +932,7 @@ prompt_diff_review() {
             printf '  [x]abort\n' > /dev/tty
             printf '  choice [a/o/s/x]: ' > /dev/tty
             local merge_choice
-            read -r merge_choice < /dev/tty
+            read_tty_choice merge_choice "overwrite"
             case "$(printf '%s' "$merge_choice" | tr '[:upper:]' '[:lower:]')" in
                 a)  MERGED_CONTENT="$AUTO_MERGED_CONTENT"
                     if [ -n "$adopt_label" ]; then
@@ -913,7 +975,7 @@ prompt_diff_review() {
     fi
 
     local choice
-    read -r choice < /dev/tty
+    read_tty_choice choice "overwrite"
     case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
         a)  if [ -n "$adopt_label" ]; then
                 printf '  >> adopted: local version copied back to %s\n' "$adopt_label" > /dev/tty
@@ -996,7 +1058,13 @@ deploy_managed_file() {
 
         # Content differs — check deploy state for auto-deploy eligibility
         local state_hash existing_hash
-        state_hash=$(get_deploy_state_hash "$dest")
+        # Initialize in this shell (not inside the $(...) below) so its warnings are
+        # counted and the parsed manifest is cached for later calls.
+        if [ -z "$_DEPLOY_MANIFEST" ]; then initialize_deploy_state; fi
+        if ! state_hash=$(get_deploy_state_hash "$dest"); then
+            log_warn "Could not read deploy state for $item_name -- treating as not deployed"
+            state_hash=""
+        fi
         if [ -n "$state_hash" ]; then
             existing_hash=$(get_content_hash "$existing")
             if [ "$existing_hash" = "$state_hash" ]; then
@@ -1184,7 +1252,7 @@ prompt_json_field_review() {
         return 0
     fi
     # Non-interactive: source wins
-    if ! (printf '' > /dev/tty) 2>/dev/null; then
+    if ! tty_interactive; then
         log "Divergence in $leaf -- overwriting from $source_label (non-interactive)"
         return 0
     fi
@@ -1206,7 +1274,7 @@ prompt_json_field_review() {
     fi
 
     local choice
-    read -r choice < /dev/tty
+    read_tty_choice choice "overwrite from $source_label"
     case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
         a)  if [ "$adopt_allowed" = "1" ]; then
                 printf '  >> adopted: settings.json value kept -> %s\n' "$source_label" > /dev/tty
@@ -1441,11 +1509,23 @@ SYNC_NODE_EOF
     : > "$choices_tsv"
     if [ "$decision_count" -gt 0 ]; then
         local id kind cur prop adoptf
-        while IFS=$'\t' read -r id kind cur prop adoptf; do
+        if [ "$live_existed" = "false" ]; then
+            # No live file yet (fresh HOME): nothing local to protect, so every leaf is
+            # created from the profile without prompting (#31).
+            log "No $(display_path "$live_file") yet -- creating from profile ($decision_count setting(s))"
+            mkdir -p "$(dirname "$live_file")"
+        fi
+        # Read decisions on fd 3, not stdin: the prompt's interactivity test
+        # (tty_interactive) checks stdin, which must stay the caller's terminal.
+        while IFS=$'\t' read -r -u 3 id kind cur prop adoptf; do
             [ -n "$id" ] || continue
-            prompt_json_field_review "$id" "$cur" "$prop" "profile.json" "$adoptf"
+            if [ "$live_existed" = "false" ]; then
+                JSON_FIELD_REVIEW_RESULT="overwrite"
+            else
+                prompt_json_field_review "$id" "$cur" "$prop" "profile.json" "$adoptf"
+            fi
             printf '%s\t%s\n' "$id" "$JSON_FIELD_REVIEW_RESULT" >> "$choices_tsv"
-        done < "$decisions_tsv"
+        done 3< "$decisions_tsv"
     fi
 
     # --- Backup before apply ---
@@ -1503,6 +1583,8 @@ repair_uv_tool_env() {
     # Find a working Python -- uv's own Pythons first, then system
     local working_python=""
     local uv_python
+    # 2>/dev/null + || true: "no Python found" is an expected outcome here; the -n/-x
+    # check below handles it and falls through to system Python.
     uv_python=$(uv python find 2>/dev/null) || true
     if [ -n "$uv_python" ] && [ -x "$uv_python" ]; then
         working_python="$uv_python"
@@ -1519,13 +1601,16 @@ repair_uv_tool_env() {
 
     log "Repairing with: uv tool install --force --python $working_python $tool_name"
     local repair_output
-    repair_output=$(uv tool install --force --python "$working_python" "$tool_name" 2>&1) || true
-    printf '%s\n' "$repair_output" | while IFS= read -r line; do
-        [ -n "$line" ] && log "$line"
-    done
-
-    if printf '%s\n' "$repair_output" | grep -qi 'error.*failed'; then
-        log_error "$tool_name environment repair failed"
+    # Capture the exit code instead of aborting under set -e; it decides success below.
+    local repair_rc=0
+    repair_output=$(uv tool install --force --python "$working_python" "$tool_name" 2>&1) || repair_rc=$?
+    local line
+    while IFS= read -r line; do
+        if [ -n "$line" ]; then log "$line"; fi
+    done <<< "$repair_output"
+
+    if [ "$repair_rc" -ne 0 ]; then
+        log_error "$tool_name environment repair failed (uv exit $repair_rc)"
         return 1
     fi
 
```

### Batch C2 — aitools-lib.ps1, check-lib.ps1, check-lib.sh

#### `scripts/aitools-lib.ps1`

```diff
diff --git ascripts/aitools-lib.ps1 bscripts/aitools-lib.ps1
index 756f363..afd6b46 100644
--- ascripts/aitools-lib.ps1
+++ bscripts/aitools-lib.ps1
@@ -27,8 +27,10 @@ function ReadConfigKey {
         if ($val) { return $val }
     } catch {
         # File exists but is invalid JSON -- warn so callers know the null
-        # return means "corrupt", not "missing key"
-        Write-Host "      WARN: could not parse $File" -ForegroundColor Yellow
+        # return means "corrupt", not "missing key". Callers may run before
+        # Initialize-Logging; without a log file, fall back to the warning stream.
+        if ($script:logFile) { LogWarn "Could not parse $File" }
+        else { Write-Warning "Could not parse $File" }
     }
     return $null
 }
@@ -261,11 +263,21 @@ function Backup-File {
     if (-not (Test-Path $FilePath)) { return }
     $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
     $backupPath = "${FilePath}.bak.${ts}"
-    Copy-Item -Path $FilePath -Destination $backupPath
+    # A failed backup is non-fatal (config-file-safety.md "Backup before overwrite"):
+    # warn and let the caller proceed.
+    try {
+        Copy-Item -Path $FilePath -Destination $backupPath -ErrorAction Stop
+    } catch {
+        LogWarn "Could not back up $FilePath -- proceeding without backup: $_"
+        return
+    }
     # Prune oldest beyond limit
-    $backups = Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending
+    $backups = @(Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending)
     if ($backups.Count -gt $MaxBackups) {
-        $backups | Select-Object -Skip $MaxBackups | Remove-Item -Force
+        foreach ($old in ($backups | Select-Object -Skip $MaxBackups)) {
+            try { Remove-Item $old.FullName -Force -ErrorAction Stop }
+            catch { LogWarn "Could not prune old backup $($old.FullName)" }
+        }
     }
     Log "Backed up $FilePath"
 }
@@ -330,7 +342,9 @@ function Initialize-DeployState {
                 $script:DeployManifest | Add-Member -NotePropertyName files -NotePropertyValue @{} -Force
             }
         } catch {
-            LogWarn "Corrupt deploy manifest, resetting: $_"
+            LogWarn "Deploy-state manifest unreadable -- starting fresh (old copy kept as .corrupt): $_"
+            try { Move-Item $manifestPath "$manifestPath.corrupt" -Force -ErrorAction Stop }
+            catch { LogWarn "Could not move aside ${manifestPath}: $_" }
             $script:DeployManifest = [PSCustomObject]@{ version = 1; files = @{} }
         }
     } else {
@@ -381,21 +395,27 @@ function Update-DeployState {
     }
 
     $manifestDir = $script:DeployStateDir
-    if (-not (Test-Path $manifestDir)) {
-        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
-    }
     $manifestPath = Join-Path $manifestDir "manifest.json"
     $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($manifestPath)
-    $json = $script:DeployManifest | ConvertTo-Json -Depth 5
-    [System.IO.File]::WriteAllText($resolved, $json, [System.Text.UTF8Encoding]::new($false))
+    # A failed state write is non-fatal (parity with update_deploy_state): the
+    # file itself is deployed; the next run just may re-prompt.
+    try {
+        if (-not (Test-Path $manifestDir)) {
+            New-Item -ItemType Directory -Path $manifestDir -Force -ErrorAction Stop | Out-Null
+        }
+        $json = $script:DeployManifest | ConvertTo-Json -Depth 5
+        [System.IO.File]::WriteAllText($resolved, $json, [System.Text.UTF8Encoding]::new($false))
 
-    $shadowPath = Join-Path $manifestDir "shadows" $key
-    $shadowDir = Split-Path $shadowPath -Parent
-    if (-not (Test-Path $shadowDir)) {
-        New-Item -ItemType Directory -Path $shadowDir -Force | Out-Null
+        $shadowPath = Join-Path $manifestDir "shadows" $key
+        $shadowDir = Split-Path $shadowPath -Parent
+        if (-not (Test-Path $shadowDir)) {
+            New-Item -ItemType Directory -Path $shadowDir -Force -ErrorAction Stop | Out-Null
+        }
+        $resolvedShadow = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($shadowPath)
+        [System.IO.File]::WriteAllText($resolvedShadow, $Content, [System.Text.UTF8Encoding]::new($false))
+    } catch {
+        LogWarn "Could not update deploy state for $key -- next run may re-prompt: $_"
     }
-    $resolvedShadow = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($shadowPath)
-    [System.IO.File]::WriteAllText($resolvedShadow, $Content, [System.Text.UTF8Encoding]::new($false))
 }
 
 function Get-DeployShadow {
@@ -406,6 +426,8 @@ function Get-DeployShadow {
         try {
             return Get-Content $shadowPath -Raw -ErrorAction Stop
         } catch {
+            # Caller treats $null as "no ancestor" and bootstraps from the deployed file.
+            LogWarn "Could not read deploy shadow for $FilePath -- no merge ancestor: $_"
             return $null
         }
     }
@@ -440,6 +462,8 @@ function Try-AutoMerge {
         }
         return $null
     } catch {
+        # Caller treats $null as "no clean merge" and falls back to the manual menu.
+        LogWarn "Auto-merge failed -- falling back to manual review: $_"
         return $null
     } finally {
         Remove-Item $tmpLocal, $tmpAncestor, $tmpSource -ErrorAction SilentlyContinue
@@ -669,6 +693,29 @@ function Stop-AiSpinner {
     }
 }
 
+# ---------------------------------------------------------------------------
+# Prompt helpers (parity with aitools-lib.sh read_tty_choice / the /dev/tty check).
+# Test-InteractiveConsole: one non-interactive test for every prompt -- a
+# redirected stdin or a non-interactive session never prompts.
+# Read-ConsoleChoice: [Console]::ReadLine() returns $null at EOF, and the
+# callers' .ToLower() then threw. This logs and returns "" so each caller's
+# default branch applies.
+# ---------------------------------------------------------------------------
+function Test-InteractiveConsole {
+    return ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)
+}
+
+function Read-ConsoleChoice {
+    param([string]$DefaultDesc)
+    $line = [Console]::ReadLine()
+    if ($null -eq $line) {
+        [Console]::WriteLine("")
+        LogWarn "No input at prompt (EOF) -- defaulting to $DefaultDesc"
+        return ""
+    }
+    return $line
+}
+
 # ---------------------------------------------------------------------------
 # Agentic merge via Invoke-AI with refinement loop.
 # Uses structured prompts from Get-AiMergePrompt / Get-AiMergeRefinePrompt.
@@ -708,7 +755,7 @@ function Invoke-AiMerge {
                 -LocalContent $LocalContent -DiffOutput $DiffOutput
         } else {
             [Console]::Write("  refinement feedback: ")
-            $feedback = [Console]::ReadLine()
+            $feedback = Read-ConsoleChoice "no feedback"
             $promptText = Get-AiMergeRefinePrompt -SourceContent $SourceContent `
                 -LocalContent $LocalContent -CurrentMerge $currentMerge -Feedback $feedback
         }
@@ -728,7 +775,7 @@ function Invoke-AiMerge {
             [Console]::WriteLine("  >> AI merge failed (iteration $iteration): $reason")
             LogError "AI merge failed (iteration $iteration): $reason"
             [Console]::Write("  fallback [o]verwrite / [s]kip: ")
-            $fb = [Console]::ReadLine()
+            $fb = Read-ConsoleChoice "overwrite"
             if ($fb.ToLower() -eq "s") { return "skip" }
             return "overwrite"
         }
@@ -746,7 +793,7 @@ function Invoke-AiMerge {
         }
         [Console]::WriteLine("")
         [Console]::Write("  [y]es accept / [r]efine / [n]o reject: ")
-        $accept = [Console]::ReadLine()
+        $accept = Read-ConsoleChoice "reject merge (overwrite)"
         switch ($accept.ToLower()) {
             "y" {
                 $script:MergedContent = $merged
@@ -794,7 +841,7 @@ function Prompt-DiffReview {
     }
 
     # Non-interactive: auto-overwrite
-    if (-not [Environment]::UserInteractive) {
+    if (-not (Test-InteractiveConsole)) {
         LogWarn "Diff in $FilePath -- overwriting (non-interactive)"
         return "overwrite"
     }
@@ -831,6 +878,9 @@ function Prompt-DiffReview {
             $diffLines += "${prefix}$($d.InputObject)"
         }
         $diffOutput = $diffLines -join "`n"
+        # Full diff as [detail] records at every size (the console truncates at 30).
+        $leafName = Split-Path -Leaf $FilePath
+        foreach ($dl in $diffLines) { LogDetail "diff ${leafName}: $dl" }
     }
 
     if ($diffCount -eq 0) {
@@ -879,7 +929,7 @@ function Prompt-DiffReview {
             [Console]::WriteLine("  [s]kip")
             [Console]::WriteLine("  [x]abort")
             [Console]::Write("  choice [a/o/s/x]: ")
-            $choice = [Console]::ReadLine()
+            $choice = Read-ConsoleChoice "overwrite"
             switch ($choice.ToLower()) {
                 "a" {
                     $script:MergedContent = $autoMerged
@@ -926,7 +976,7 @@ function Prompt-DiffReview {
         [Console]::Write("  choice [o/m/s/x]: ")
     }
 
-    $choice = [Console]::ReadLine()
+    $choice = Read-ConsoleChoice "overwrite"
     switch ($choice.ToLower()) {
         "a" {
             if ($AdoptLabel) {
@@ -1189,7 +1239,7 @@ function Prompt-JsonFieldReview {
         Log "Divergence in $Leaf -- overwriting from $SourceLabel (--force)"
         return "overwrite"
     }
-    if ([Console]::IsInputRedirected) {
+    if (-not (Test-InteractiveConsole)) {
         Log "Divergence in $Leaf -- overwriting from $SourceLabel (non-interactive)"
         return "overwrite"
     }
@@ -1211,8 +1261,7 @@ function Prompt-JsonFieldReview {
         [Console]::Write("  choice [o/s/x]: ")
     }
 
-    $choice = [Console]::ReadLine()
-    if ($null -eq $choice) { return "overwrite" }
+    $choice = Read-ConsoleChoice "overwrite from $SourceLabel"
     switch ($choice.ToLower()) {
         "a" {
             if ($AdoptAllowed -eq "1") {
@@ -1427,10 +1476,21 @@ if (mode === 'plan') {
 
     # --- Prompt loop (granular, per leaf) ---
     $choiceLines = @()
+    if (-not $liveExisted -and $decisions.Count -gt 0) {
+        # No live file yet (fresh HOME): nothing local to protect, so every leaf is
+        # created from the profile without prompting (#31).
+        Log "No $LiveFile yet -- creating from profile ($($decisions.Count) setting(s))"
+        $liveDir = Split-Path $LiveFile -Parent
+        if (-not (Test-Path $liveDir)) { New-Item -ItemType Directory -Path $liveDir -Force | Out-Null }
+    }
     foreach ($line in $decisions) {
         $cols = $line -split "`t"
         $id = $cols[0]; $cur = $cols[2]; $prop = $cols[3]; $adoptf = $cols[4]
-        $action = Prompt-JsonFieldReview -Leaf $id -Current $cur -Proposed $prop -SourceLabel "profile.json" -AdoptAllowed $adoptf
+        if ($liveExisted) {
+            $action = Prompt-JsonFieldReview -Leaf $id -Current $cur -Proposed $prop -SourceLabel "profile.json" -AdoptAllowed $adoptf
+        } else {
+            $action = "overwrite"
+        }
         $choiceLines += "$id`t$action"
     }
     [System.IO.File]::WriteAllText($choicesTsv, (($choiceLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
```

#### `scripts/check-lib.ps1`

```diff
diff --git ascripts/check-lib.ps1 bscripts/check-lib.ps1
index 9134bed..873aac2 100644
--- ascripts/check-lib.ps1
+++ bscripts/check-lib.ps1
@@ -48,8 +48,10 @@ function CheckLogInit {
     $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
     $hostName = $env:COMPUTERNAME
     if (-not $hostName) { $hostName = hostname }
+    # Record the real platform (pwsh also runs these checks on macOS and Linux).
+    $osName = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } elseif ($IsLinux) { "Linux" } else { "unknown" }
     Add-Content -Path $script:CheckLog -Value "[$ts] [$Name] === RUN START ==="
-    Add-Content -Path $script:CheckJsonl -Value "{`"ts`":`"$ts`",`"check`":`"$Name`",`"event`":`"run_start`",`"host`":`"$hostName`",`"os`":`"Windows`"}"
+    Add-Content -Path $script:CheckJsonl -Value "{`"ts`":`"$ts`",`"check`":`"$Name`",`"event`":`"run_start`",`"host`":`"$hostName`",`"os`":`"$osName`"}"
 
     # Bridge: initialize aitools-lib logging vars so lib functions
     # (Log, Ensure-ToolOnPath, Deploy-ManagedFile, etc.) work in check context.
```

#### `scripts/check-lib.sh`

```diff
diff --git ascripts/check-lib.sh bscripts/check-lib.sh
index 2cfa5b4..908fd17 100755
--- ascripts/check-lib.sh
+++ bscripts/check-lib.sh
@@ -152,6 +152,8 @@ resolve_config() {
     CONFIG_FILE="$HOME/.aitools/config.json"
     USER_REPO_PATH=""
     if [ -f "$CONFIG_FILE" ]; then
+        # read_config_key returns 1 when the key is absent (before 'aitools user init');
+        # USER_REPO_PATH stays empty and callers test it with [ -n ] before use.
         USER_REPO_PATH=$(read_config_key "$CONFIG_FILE" "userRepoPath" 2>/dev/null || true)
     fi
 }
@@ -163,6 +165,8 @@ resolve_config() {
 # ---------------------------------------------------------------------------
 get_mtime() {
     local file="$1"
+    # stat fails only if the file vanished; 0 (epoch) makes it read as oldest, so
+    # check-post-push never picks it as "newest" and flags it stale (conservative).
     if $IS_MACOS; then
         stat -f %m "$file" 2>/dev/null || echo 0
     else
```

### Batch C3a — aitools, aitools.ps1

#### `scripts/aitools`

```diff
diff --git ascripts/aitools bscripts/aitools
index 1a2baa2..36b72f2 100755
--- ascripts/aitools
+++ bscripts/aitools
@@ -506,7 +506,8 @@ Commands:
 Options:
   --addmcp <name...>   Enable MCP server(s) for current project (vercel, webflow)
   --dry-run            Preview what would change without writing any files
-  --force              Overwrite all files without prompting for review
+  --force              No prompts: managed files take the source version (backups
+                       kept); with install, also skips gh login and path prompts
   --version, -v        Show installed and repo version
   --help, -h           Show this help
 
@@ -1528,6 +1529,10 @@ overall_rc=0
 if $do_install; then
     # --- install: pull + rebuild + run installer (includes deploy) ---
     log "Step 3/$STEPS: Running installer"
+    # Interactive iff run from a terminal: the installer and its setup scripts
+    # inherit this stdin and decide for themselves. --force makes every review
+    # prompt take the source version (backup kept), terminal or not.
+    if $force; then export AITOOLS_FORCE=1; fi
     case "$(uname -s)" in
         MINGW*|MSYS*|CYGWIN*)
             # Windows: forward to PowerShell installer with translated flags
@@ -1551,10 +1556,11 @@ if $do_install; then
                 "${ps_args[@]}"
             ;;
         *)
-            bash "$repo_path/scripts/aitools-install.sh" "${passthrough[@]}" < /dev/null
+            bash "$repo_path/scripts/aitools-install.sh" "${passthrough[@]}"
             ;;
     esac
     installer_rc=$?
+    unset AITOOLS_FORCE
     echo ""
     if [ $installer_rc -eq 0 ]; then
         log_ok "All up to date ($(repo_version "$repo_path"))"
```

#### `scripts/aitools.ps1`

```diff
diff --git ascripts/aitools.ps1 bscripts/aitools.ps1
index d302a59..869e42d 100644
--- ascripts/aitools.ps1
+++ bscripts/aitools.ps1
@@ -493,7 +493,8 @@ Commands:
 Options:
   --addmcp <name...>   Enable MCP server(s) for current project (vercel, webflow)
   --dry-run            Preview what would change without writing any files
-  --force              Overwrite all files without prompting for review
+  --force              No prompts: managed files take the source version (backups
+                       kept); with install, also skips gh login and path prompts
   --version, -v        Show installed and repo version
   --help, -h           Show this help
 
@@ -1449,8 +1450,13 @@ if ($doInstall) {
     if ($SkipGhAuth) { $installerArgs += "-SkipGhAuth" }
     if ($SkipDriveDetection) { $installerArgs += "-SkipDriveDetection" }
     if ($ReposPath) { $installerArgs += "-ReposPath"; $installerArgs += $ReposPath }
+    # Interactive iff run from a console: the installer and its setup scripts decide
+    # for themselves. -Force makes every review prompt take the source version
+    # (backup kept), console or not.
+    if ($Force) { $env:AITOOLS_FORCE = "1" }
     & "$repoPath\scripts\aitools-install.ps1" @installerArgs
     $installerRc = $LASTEXITCODE
+    if (Test-Path Env:\AITOOLS_FORCE) { Remove-Item Env:\AITOOLS_FORCE }
     Write-Host ""
     if ($installerRc -eq 0) {
         LogOk "All up to date ($(Get-RepoVersion $repoPath))"
```

### Batch C4a — aitools-install.sh, aitools-install.ps1

#### `scripts/aitools-install.sh`

```diff
diff --git ascripts/aitools-install.sh bscripts/aitools-install.sh
index 77f2289..37799ba 100755
--- ascripts/aitools-install.sh
+++ bscripts/aitools-install.sh
@@ -62,8 +62,10 @@ Options:
   --help, -h                Show this help
 
 Interactive behavior:
-  When stdin is a terminal, prompts for repos path and drive confirmation.
+  When stdin is a terminal, prompts for gh login, repos path, and file reviews.
   When piped or run non-interactively, uses defaults and flags.
+  AITOOLS_FORCE=1 (aitools install --force): no prompts even in a terminal;
+  managed files take the source version (backups kept).
   When config.json already exists, uses saved values without prompting.
 USAGE
     exit 0
@@ -149,6 +151,13 @@ validate_and_run() {
 
 # display_path is provided by aitools-lib.sh
 
+# Interactive mode (same rule as the lib's review prompts): a terminal on stdin and
+# no --force / AITOOLS_FORCE. Otherwise every prompt takes its default.
+INSTALL_INTERACTIVE=false
+if [ "${AITOOLS_FORCE:-}" != "1" ] && tty_interactive; then
+    INSTALL_INTERACTIVE=true
+fi
+
 # --- Post-write JSON validation ---
 # Validates a JSON config file after writing: checks non-empty, valid JSON,
 # required keys present, and no double-slash paths (excluding protocol prefixes).
@@ -272,7 +281,7 @@ elif ! command -v gh &>/dev/null; then
     log_warn "gh not installed, skipping auth"
 elif gh auth status &>/dev/null; then
     log_ok "gh already authenticated"
-elif [ -t 0 ]; then
+elif $INSTALL_INTERACTIVE; then
     log "Not authenticated. Starting gh auth login..."
     gh auth login || log_error "gh auth login failed"
 else
@@ -292,10 +301,10 @@ elif REPOS_PATH=$(read_config_key "$CONFIG_FILE" "reposPath"); then
     log "Using repos path from config: $REPOS_PATH"
 fi
 if [ -z "$REPOS_PATH" ]; then
-    if [ -t 0 ]; then
-        # Interactive — prompt
+    if $INSTALL_INTERACTIVE; then
+        # Interactive — prompt (EOF-safe: read_tty_choice logs and returns empty)
         printf 'Where should new repos live? [~/repos]: '
-        read -r user_path
+        read_tty_choice user_path "~/repos"
         if [ -n "$user_path" ]; then
             REPOS_PATH="${user_path/#\~/$HOME}"
         else
@@ -532,7 +541,7 @@ fi
 # These are sole-owned generated artifacts (the user never edits the deployed
 # copy), so per config-file-safety.md we back up + diff-log + overwrite, with
 # NO interactive review. deploy_managed_file's prompt is for user-customizable
-# files; under the non-interactive install wrapper its tty read aborts the run.
+# files only.
 AITOOLS_BIN="$HOME/.aitools/bin"
 mkdir -p "$AITOOLS_BIN"
 _hbin_deployed=0
```

#### `scripts/aitools-install.ps1`

```diff
diff --git ascripts/aitools-install.ps1 bscripts/aitools-install.ps1
index ead8c86..2b2e6db 100644
--- ascripts/aitools-install.ps1
+++ bscripts/aitools-install.ps1
@@ -28,8 +28,10 @@ Options:
   -Help                     Show this help
 
 Interactive behavior:
-  When stdin is a terminal, prompts for repos path and drive confirmation.
+  When stdin is a terminal, prompts for gh login, repos path, and file reviews.
   When piped or run non-interactively, uses defaults and flags.
+  AITOOLS_FORCE=1 (aitools install --force): no prompts even in a terminal;
+  managed files take the source version (backups kept).
   When config.json already exists, uses saved values without prompting.
 "@
     exit 0
@@ -80,6 +82,10 @@ if (-not $env:AITOOLS_SUMMARY_FILE) {
     New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force | Out-Null
 }
 
+# Interactive mode (same rule as the lib's review prompts): a console on stdin and
+# no -Force / AITOOLS_FORCE. Otherwise every prompt takes its default.
+$installInteractive = ($env:AITOOLS_FORCE -ne "1") -and (Test-InteractiveConsole)
+
 # --- Script validation helper ---
 # Validates PS1 syntax with ParseFile before executing. Skips with warning on parse errors.
 function Invoke-ValidatedScript {
@@ -192,7 +198,7 @@ if ($SkipGhAuth) {
     $authStatus = gh auth status 2>&1
     if ($LASTEXITCODE -eq 0) {
         LogOk "gh already authenticated"
-    } elseif ([Environment]::UserInteractive) {
+    } elseif ($installInteractive) {
         Log "Not authenticated. Starting gh auth login..."
         gh auth login
         if ($LASTEXITCODE -ne 0) {
@@ -225,9 +231,10 @@ if ($ReposPath) {
     }
 }
 if (-not $resolvedReposPath) {
-    if ([Environment]::UserInteractive) {
+    if ($installInteractive) {
         $defaultPath = Join-Path $env:USERPROFILE "repos"
-        $userInput = Read-Host "Where should new repos live? [$defaultPath]"
+        [Console]::Write("Where should new repos live? [$defaultPath]: ")
+        $userInput = Read-ConsoleChoice $defaultPath
         if ($userInput) {
             $resolvedReposPath = $userInput -replace '^~', $env:USERPROFILE
         } else {
@@ -364,7 +371,7 @@ if (Test-Path $hhPs1Src) {
 # These are sole-owned generated artifacts (the user never edits the deployed
 # copy), so per config-file-safety.md we back up + overwrite, with NO
 # interactive review. Deploy-ManagedFile's prompt is for user-customizable
-# files; under the non-interactive install wrapper its tty read aborts the run.
+# files only.
 $aitoolsBin = Join-Path $env:USERPROFILE ".aitools\bin"
 if (-not (Test-Path $aitoolsBin)) { New-Item -ItemType Directory -Path $aitoolsBin -Force | Out-Null }
 $hbinDeployed = 0
```

## PR C2 — verbatim edits (batches C3b, C4b, T1)

Base: `main` @ 5a010c2 (v0.73.3 + #36). Prototyped on a copy of the base
(scratch: `.scratch/session-3030c86a-9/proto-c2/`); each diff below is the exact edit.
No `aitools-lib.*` change, so no `deploy/` rebuild: `build-deploy.sh` does not embed the
entry points or the installers.

### Decisions applied

- **C-F2** (exit code decides, output logged in full) and **C-F3** (summary row on every
  failure path; orchestrators add `ERROR "<script>" "script failed (exit N)"`): approved
  2026-10-03.
- **C-F9 (#28): the entry points load aitools-lib as early as they can and define no
  logging of their own** (commander, 2026-10-03). `scripts/aitools` / `aitools.ps1`
  dot-source the lib as soon as `repoPath` is read from `config.json`. Only `--help`,
  `--version` and the missing-repo clone run before it; warnings found before it are
  queued and logged right after it loads. The entry points' own `log*` / `Log*`
  functions, their log-dir setup and the duplicate `display_path` are removed. Missing
  lib: one stderr line naming the path, exit 1 (`--version` still answers). The
  logging-overrides table loses its `scripts/aitools` row (D-C2).
- **Unit tests for logging** (commander, 2026-10-03): `tests/logging/` (bash + PS1), run
  on all three CI runners (batch T1).

### What changes

| Batch | File | Issue | Change |
|---|---|---|---|
| C3b | `aitools`, `aitools.ps1` | #28, C-F9 | Lib loaded right after `repoPath` resolution; own logging functions, log-dir setup and duplicate `display_path` removed; pre-lib warnings (old config dir, config-key migration, repo cloned fresh) queued and logged after the lib loads; unknown-argument checks moved after the lib load; missing lib -> stderr line + exit 1; missing-repo clone moved ahead of the lib load |
| C3b | `aitools` | #26e, #27b | `deploy_configs`: exit code captured before the `if` (the log said "exit 0" for every failure); `ERROR "<script>" "script failed (exit N)"` row per failed child |
| C3b | `aitools` | #23, C-F3 | Child syntax check: `bash -n` / PS1 parse messages logged as `[detail]` (were discarded); a skipped script is `log_error` + ERROR row (was `log_warn`, but already counted as a failure) |
| C3b | `aitools` | #22, #23 | `git pull` failure: every output line logged as `[detail] git-pull:`; console keeps its 3-line preview (`gitpull`: full output on stderr) |
| C3b | `aitools` | #23 | Self-update syntax checks (bash and PS1 copies, deploy-list reload): messages logged as detail |
| C3b | `aitools` | #23, #25 | Profile migration: `echo` lines -> `log_warn` / `log_ok`; commit and push output logged, exit codes checked |
| C3b | `aitools.ps1` | same | Parity: `Deploy-Configs` ERROR rows + detail parse errors; pull output as detail; migration via `LogWarn`/`LogOk` with checked git exit codes; parse errors logged on both self-update paths |
| C4b | `aitools-install.sh` | #25 | Lib sourced before flag parsing: unknown option, Windows forwarding and the pwsh bootstrap now log (were bare `echo`) |
| C4b | `aitools-install.sh` | #23 | pwsh bootstrap: winget output captured and logged, exit code checked, ERROR row |
| C4b | `aitools-install.sh` | #26e, C-F3 | `validate_and_run`: syntax messages as detail, ERROR row on syntax error or failed child (exit code in log and row) |
| C4b | `aitools-install.sh` | #26e | gh auth login failure: ERROR + ACTION rows. Not authenticated without a terminal: WARN + ACTION rows (`script-standards.md` post-install auth check) |
| C4b | `aitools-install.sh` | #27a | `claude update`: exit code decides; output logged line by line (was: grep for "error"/"fatal") |
| C4b | `aitools-install.sh` | dead code | Windows branches in Step 8 (node) and Step 9 (Claude) removed: Windows is forwarded to the PS1 installer at the top (`cross-platform.md` "Dead code from platform guards") |
| C4b | `aitools-install.ps1` | #26e | `Invoke-ValidatedScript`: `$LASTEXITCODE` checked after the child (was only `catch`); ERROR rows for exit code, exception and parse errors; parse lines via the lib's `LogDetail` (file-only; the installer's own `Log` prints every level, found in the C4b batch audit) |
| C4b | `aitools-install.ps1` | #23 | `git config --global core.longpaths`: output and exit code checked (was an unconditional `LogOk`) |
| C4b | `aitools-install.ps1` | #26e | gh auth rows (parity with bash) |
| C4b | `aitools-install.ps1` | #26b | Step 5: `Backup-File` before the write (bash parity, `config-file-safety.md`); write in try/catch; `aitools config` row on every path (created / updated / validation failed / write failed) |
| C4b | `aitools-install.ps1` | #27a, #23 | `claude update`: exit code captured before logging; Claude installer output captured (`*>&1`) and logged |
| T1 | `tests/logging/test-logging.sh` (new) | U1, U2 | 24 cases: lib format, levels, ANSI on console only, `log_detail` file-only, counters, `logging_init` reset, `write_summary` (no-op, row, OK->WARN), 5 MB rotation; entry point defines no log functions, unknown argument in lib format and in `deploy.log`, pre-lib warning logged, missing lib, `--version` without repo |
| T1 | `tests/logging/test-logging.ps1` (new) | U1, U2 | PS1 twin: 15 lib cases + AST check that `aitools.ps1` defines no `Log*`; 3 entry-point run cases on Windows (SKIP elsewhere: OS guard) |
| T1 | `.github/workflows/check.yml` | U1, U2 | "Logging unit tests (bash)" and "(PowerShell)" steps on macOS, Linux and Windows |

### Error-handling audit

| Pattern added | Where | Check |
|---|---|---|
| `x=$(cmd 2>&1) \|\| rc=$?` | every captured command above | `rc` tested on the next statement; output logged before the decision |
| `cmd \|\| rc=$?` (no capture) | `bash "$script"`, `pwsh -File`, `gh auth login` | interactive or self-logging children; `rc` tested immediately |
| `2>&1 \| Out-String` + `$LASTEXITCODE` | PS1 git, claude update, longpaths | exit code saved to a variable on the next line, before any other native call |
| `try/catch` | PS1 `Invoke-ValidatedScript`, Step 5 write | catch logs `LogError` and writes an ERROR row |
| `2>/dev/null` removed | `bash -n`, PS1 parse checks, migration push | now captured |
| pre-lib console output | `aitools` missing lib / failed clone | one line to stderr (no logger exists yet), exit 1; the clone itself is recorded as a warning once the lib loads |
| tests | `tests/logging/*` | no suppressions; temp dirs removed on exit (`trap` / `finally`); env vars reset by assignment |

Not changed (outside the issue list, noted as follow-ups): `git checkout HEAD -- deploy/ 2>/dev/null || true`
before each pull; the `profile:` lines printed with raw `printf`/`Write-Host` in the profile
check; `Read-Host` for the machine alias in `aitools.ps1` migration; the `aitools-lib.sh`
header comment still says both entry points override the log functions (fix with the
JSONL follow-up below, which changes the lib anyway); `aitools-install`'s JSONL override
(move JSONL into the lib so no script overrides logging).

### Tests (Linux)

| Suite | Prototype | `main` |
|---|---|---|
| `tests/logging/test-logging.sh` (T1, in repo) | 24/24 | 19/24: entry point defines its own log functions, unknown argument printed as bare `error:`, pre-lib warning lost, missing lib not detected, `--version` fails without the repo |
| `tests/logging/test-logging.ps1` (T1, in repo) | 15/15 + 3 SKIP; the 3 Windows cases pass (6/6 entry cases) on a guard-stripped copy | -- |
| `test-c2b.sh` (scratch): real `aitools` + installer, stubbed setup scripts; child exit 3, child syntax error, installer child exit 4, git pull failure, `claude update` exit 2, `claude update` exit 0 printing "error", unknown installer option, gh not authenticated | 17/17 | 4/17 |
| `test-c2b-ps1.ps1` (scratch): `Invoke-ValidatedScript` and `Deploy-Configs` extracted from the AST | 9/9 | 1/9 |
| `test-mode-e2e.sh` (PR C1 mode matrix, regression) | 18/18 | -- |
| `bash -n` / pwsh ParseFile, all changed files | pass | -- |

Not testable here: the PS1 entry point and installer run only on Windows (OS guard), so
their top-level blocks (Step 5, longpaths, claude update/install, pull) are parse-checked
only; the T1 Windows cases first run for real in CI. macOS run needed for the bash paths.
Commits carry `(tested: Linux)`.

### Logging audit plan (epic #21)

**Purpose.** Measure logging conformance across every reusable script, drive each
batch's files to zero on the checks it owns, and keep them there.

**Scope.** `scripts/aitools`, `aitools.ps1`, `aitools-install.*`, `setup-*.sh/.ps1`,
`aitools-lib.*` and `check-lib.*` (the libs through the unit tests). Hooks and
`build-deploy.sh` keep their own logging (logging-overrides table); only A4 applies to them.

**Checks and baseline.** Static counts are leads, not verdicts: every hit is fixed or
classified "allowed" with a reason (CLI output and usage text are allowed for A3; A4
hits are allowed only if listed in the exemptions table).

| Id | Check | Rule | Method | `main` @ 5a010c2 | After PR C2 | Owner |
|---|---|---|---|---|---|---|
| A1 | Script sources the lib + `logging_init` / `Initialize-Logging` | `script-standards.md` block order | static | 0 | 0 | -- |
| A2 | Script defines its own `log*` / `Log*` | `script-standards.md` "Do not define inline copies"; overrides table | static | 16 in 4 files | 8 in 2 (installer JSONL override, allowed until the JSONL follow-up) | JSONL follow-up |
| A3 | Bare `echo` / `printf` / `Write-Host` | `script-standards.md` "Logging framework is required" (#25) | static + manual classification | 198 in 18 | 193 in 18 | C5-C14 |
| A4 | `2>/dev/null`, `\|\| true`, `SilentlyContinue`, `Out-Null` | error-handling table, exemptions table | static + manual against exemptions | 356 in 41 | 344 in 41 | C5-C14, D-C |
| A5 | `exit 1` with no summary row in the 3 lines before (OS guards and exit footers excluded) | C-F3, #26a | static | 24 in 14 | 24 in 14 (all in setup scripts) | C5-C14 |
| A6 | Output truncated (`tail`/`head -N`, `Select-Object -First/-Last N`) before logging | #22 | static | 3 in 3 | 3 in 3 (setup scripts) | C5 |
| A7 | `$?` read inside an `if !` branch | #27b | static | 2 in 1 | 0 | done |
| A8 | Success decided by grepping output for "error"/"fatal" | #27a, Standard 3 | static | 11 in 10 | 10 in 9 (7 are `brew upgrade`, pending the Standard 3 `/incident`) | C5-C8, C-F6 |
| A9 | `[ ... ] && log` inside a loop body (aborts under `set -e`) | #24 | static | 9 in 8 | 9 in 8 | C5-C14 |
| A10 | `while read ... done < file` loop whose body calls a review prompt | C1 finding | manual (static step to add) | 0 known | 0 | -- |
| A11 | Exit footer checks `ERRORS` | `script-standards.md` exit footer | static | 0 | 0 | -- |
| U1 | Lib logging contract: format, levels, console colours, file without ANSI, `log_detail` file-only, counters, init reset, summary rows, rotation | `script-standards.md`, `logging.md` | unit (`tests/logging`), CI on 3 runners | -- | 24 + 15 cases | T1 |
| U2 | Entry points use the lib: no own log functions, lib-format errors, pre-lib warnings logged, missing-lib error, `--version` without repo | C-F9 | unit (`tests/logging`), CI | -- | in U1 counts | T1 |
| E1 | Install x2 on a fresh HOME: a summary row for every script, zero lines in `deploy.log` outside the `[ts] [script] [level]` format, no prompts on the second run | PR C verification | end-to-end harness (scratch today) | -- | -- | final PR C batch |

**Process.**
1. Each PR records the table above (scanner: `.scratch/session-3030c86a-9/audit-logging-baseline.sh`
   for now).
2. Each batch re-runs the scan. For the checks it owns, its files reach zero or each
   remaining hit is classified "allowed" in the plan with a reason. No count may rise
   anywhere else (ratchet).
3. New batch **C15**: turn the scanner into `check-pre-commit` steps (bash + PS1) in
   observe/WARN mode, per `hook-rollout.md`; promote a check to FAIL once its count is
   zero. Classified A3 hits get an allowlist; A4 classifications go to the exemptions
   table (protected). The existing "Detection" list above becomes these steps.
4. Promote the end-to-end harness (E1) to `tests/` once it no longer depends on scratch
   paths, and run it in CI on Linux.

**Exit criteria for epic #21.** A1, A5-A11 at zero; A2 at zero once the JSONL override
moves into the lib; every remaining A3/A4 hit classified; U1/U2 green on macOS, Linux and
Windows; E1 passes on all three.

### D-C2: protected doc edits (approved 2026-10-03)

- `reference/script-standards-detail.md`: the "Entry points" example now says entry
  points load the lib as early as they can (C-F9) and shows the `aitools-install` JSONL
  override as the only remaining one; the `scripts/aitools` row leaves the
  logging-overrides table.
- `CLAUDE.md` "How the harness is organized": `tests/` line.
- This plan: status, C-F2/C-F3 approved, C-F6 note, C-F9, batch tables, this section.
- RELEASE_NOTES: deferred by the commander.

### Verbatim diffs

#### Batch C3b

```diff
diff --git a/scripts/aitools b/scripts/aitools
index 36b72f2..b6b3ef5 100755
--- a/scripts/aitools
+++ b/scripts/aitools
@@ -26,7 +26,10 @@ if [ "$(uname -s)" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
 fi
 
 # ---------------------------------------------------------------------------
-# Helpers
+# Bootstrap helpers -- needed to find aitools-lib.sh (repoPath in config.json).
+# Everything else (logging, display_path, write_summary, ...) comes from the lib,
+# which is sourced as soon as repoPath is known (see "Load aitools-lib" below).
+# The lib defines an identical read_config_key, which replaces this one.
 # ---------------------------------------------------------------------------
 
 # Read a top-level string value from a JSON config file.
@@ -53,35 +56,6 @@ to_native_path() {
     fi
 }
 
-# Display-friendly path for user-facing messages (native Windows on MSYS).
-display_path() {
-    if command -v cygpath &>/dev/null; then
-        cygpath -w "$1"
-    else
-        printf '%s' "$1"
-    fi
-}
-
-# ---------------------------------------------------------------------------
-# Logging
-# ---------------------------------------------------------------------------
-
-# Unified log dir (reference/logging.md §1): ~/.aitools/logs on all platforms.
-LOG_DIR="${AITOOLS_LOG_DIR:-$HOME/.aitools/logs}"
-LOG_FILE="$LOG_DIR/deploy.log"
-mkdir -p "$LOG_DIR"
-LOG_DISPLAY=$(display_path "$LOG_FILE")
-ERRORS=0
-WARNINGS=0
-
-log() {
-    local level="${2:-info}"
-    printf '[%s] [aitools] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$1" >> "$LOG_FILE"
-}
-log_ok()    { log "$1" "ok"; }
-log_error() { log "$1" "error"; printf 'error: %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }
-log_warn()  { log "$1" "warn"; printf 'warning: %s\n' "$1" >&2; WARNINGS=$((WARNINGS + 1)); }
-
 # Check profile.json for issues and optionally prompt for fixes.
 # Usage: check_profile <warn|interactive>
 # Requires: node, $repo_path, $config
@@ -183,7 +157,7 @@ migrate_profile_v1_to_v2() {
     read -r machine_alias < /dev/tty
 
     if [ -z "$machine_alias" ]; then
-        echo "Migration cancelled (alias required)."
+        log_warn "profile migration cancelled (alias required)"
         return 1
     fi
 
@@ -277,10 +251,24 @@ fs.writeFileSync(f, JSON.stringify(cfg, null, 2) + '\n');
                 git -C "$user_repo_dir" config user.name "$git_name"
                 git -C "$user_repo_dir" config user.email "$git_email"
             fi
-            git -C "$user_repo_dir" add -A
-            git -C "$user_repo_dir" commit -m "Migrate profile.json from v1 to v2"
-            git -C "$user_repo_dir" push 2>/dev/null || echo "  (push failed -- run 'git push' manually in $(display_path "$user_repo_dir"))"
-            echo "Profile migrated and committed."
+            local git_out git_rc=0 git_line
+            git_out=$( { git -C "$user_repo_dir" add -A && git -C "$user_repo_dir" commit -m "Migrate profile.json from v1 to v2"; } 2>&1) || git_rc=$?
+            while IFS= read -r git_line; do
+                if [ -n "$git_line" ]; then log_detail "profile-migrate commit: $git_line"; fi
+            done <<< "$git_out"
+            if [ "$git_rc" -ne 0 ]; then
+                log_warn "profile migration commit failed (exit $git_rc) -- commit manually in $(display_path "$user_repo_dir")"
+                return 0
+            fi
+            git_rc=0
+            git_out=$(git -C "$user_repo_dir" push 2>&1) || git_rc=$?
+            while IFS= read -r git_line; do
+                if [ -n "$git_line" ]; then log_detail "profile-migrate push: $git_line"; fi
+            done <<< "$git_out"
+            if [ "$git_rc" -ne 0 ]; then
+                log_warn "profile migration push failed (exit $git_rc) -- run 'git push' manually in $(display_path "$user_repo_dir")"
+            fi
+            log_ok "Profile migrated and committed."
         fi
     fi
 }
@@ -327,22 +315,33 @@ deploy_configs() {
             for script in $deploy_scripts; do
                 local script_path="$script_dir/$script"
                 if [ -f "$script_path" ]; then
-                    # Validate PS1 syntax before executing
-                    if ! pwsh -NoProfile -Command "
+                    # Validate PS1 syntax before executing; each parse error is
+                    # printed by the check and logged as detail.
+                    local parse_out parse_rc=0 parse_line
+                    parse_out=$(pwsh -NoProfile -Command "
                         \$e = \$null
                         \$null = [System.Management.Automation.Language.Parser]::ParseFile('$(cygpath -w "$script_path")', [ref]\$null, [ref]\$e)
+                        foreach (\$x in \$e) { 'line ' + \$x.Extent.StartLineNumber + ': ' + \$x.Message }
                         if (\$e.Count -gt 0) { exit 1 }
-                    " 2>/dev/null; then
-                        log_warn "$script has parse errors -- skipping"
+                    " 2>&1) || parse_rc=$?
+                    if [ "$parse_rc" -ne 0 ]; then
+                        while IFS= read -r parse_line; do
+                            if [ -n "$parse_line" ]; then log_detail "$script parse: $parse_line"; fi
+                        done <<< "$parse_out"
+                        log_error "$script has parse errors -- skipped (see $LOG_DISPLAY)"
+                        write_summary ERROR "${script%.ps1}" "parse errors -- skipped"
                         errors=$((errors + 1))
                         continue
                     fi
                     # Run without output redirection -- child PS1 scripts log to
                     # deploy.log via [IO.File]::AppendAllText. PowerShell's 2>> holds
                     # an exclusive file lock that blocks the child's AppendAllText.
-                    if ! pwsh -NoProfile -ExecutionPolicy Bypass \
-                        -File "$(cygpath -w "$script_path")"; then
-                        log_error "$script failed (exit $?) -- see $LOG_DISPLAY"
+                    local script_rc=0
+                    pwsh -NoProfile -ExecutionPolicy Bypass \
+                        -File "$(cygpath -w "$script_path")" || script_rc=$?
+                    if [ "$script_rc" -ne 0 ]; then
+                        log_error "$script failed (exit $script_rc) -- see $LOG_DISPLAY"
+                        write_summary ERROR "${script%.ps1}" "script failed (exit $script_rc)"
                         errors=$((errors + 1))
                     fi
                 else
@@ -359,17 +358,27 @@ deploy_configs() {
             for script in $deploy_scripts; do
                 local script_path="$script_dir/$script"
                 if [ -f "$script_path" ]; then
-                    # Validate bash syntax before executing
-                    if ! bash -n "$script_path" 2>/dev/null; then
-                        log_warn "$script has syntax errors -- skipping"
+                    # Validate bash syntax before executing; bash -n's messages
+                    # are logged as detail.
+                    local syntax_out syntax_rc=0 syntax_line
+                    syntax_out=$(bash -n "$script_path" 2>&1) || syntax_rc=$?
+                    if [ "$syntax_rc" -ne 0 ]; then
+                        while IFS= read -r syntax_line; do
+                            if [ -n "$syntax_line" ]; then log_detail "$script syntax: $syntax_line"; fi
+                        done <<< "$syntax_out"
+                        log_error "$script has syntax errors -- skipped (see $LOG_DISPLAY)"
+                        write_summary ERROR "${script%.sh}" "syntax errors -- skipped"
                         errors=$((errors + 1))
                         continue
                     fi
                     # Run without output redirection -- child scripts log to
                     # deploy.log via >> append. Removing redirection ensures
                     # parity with the Windows fix and lets errors surface.
-                    if ! bash "$script_path"; then
-                        log_error "$script failed (exit $?) -- see $LOG_DISPLAY"
+                    local script_rc=0
+                    bash "$script_path" || script_rc=$?
+                    if [ "$script_rc" -ne 0 ]; then
+                        log_error "$script failed (exit $script_rc) -- see $LOG_DISPLAY"
+                        write_summary ERROR "${script%.sh}" "script failed (exit $script_rc)"
                         errors=$((errors + 1))
                     fi
                 else
@@ -597,24 +606,14 @@ while [[ $# -gt 0 ]]; do
     esac
 done
 
-# Reject unknown arguments when not installing (typos like "installs", "mcpp", etc.)
-if ! $do_install && [ ${#passthrough[@]} -gt 0 ]; then
-    log_error "unknown argument '${passthrough[0]}'"
-    echo "Run 'aitools --help' for usage."
-    return 1
-fi
-
-# Reject --addmcp with no server names
-if $addmcp_seen && [ ${#addmcp_servers[@]} -eq 0 ]; then
-    log_error "--addmcp requires at least one server name (vercel, webflow)"
-    return 1
-fi
-
 if $show_help; then
     usage
     return 0
 fi
 
+# Warnings found before the lib is loaded (it holds the logging); logged right after.
+_pre_lib_warnings=()
+
 # ---------------------------------------------------------------------------
 # Migrate config directory: ~/.config/ai-tooling/ -> ~/.aitools/
 # ---------------------------------------------------------------------------
@@ -625,7 +624,7 @@ new_config_dir="$HOME/.aitools"
 if [ -d "$old_config_dir" ] && [ ! -d "$new_config_dir" ]; then
     mv "$old_config_dir" "$new_config_dir"
 elif [ -d "$old_config_dir" ] && [ -d "$new_config_dir" ]; then
-    log_warn "both $old_config_dir and $new_config_dir exist -- using $new_config_dir"
+    _pre_lib_warnings+=("both $old_config_dir and $new_config_dir exist -- using $new_config_dir")
 fi
 
 # ---------------------------------------------------------------------------
@@ -658,7 +657,7 @@ try {
     console.error('config migration failed: ' + e.message);
     process.exit(1);
 }
-" "$config" 2>&1) || log_warn "config key migration failed: $migrate_out"
+" "$config" 2>&1) || _pre_lib_warnings+=("config key migration failed: $migrate_out")
         # Re-read repo_path after migration
         if raw=$(read_config_key "$config" "repoPath"); then
             repo_path=$(to_native_path "$raw")
@@ -666,6 +665,57 @@ try {
     fi
 fi
 
+# ---------------------------------------------------------------------------
+# Verify repo exists (clone fresh if missing). Runs before the lib is loaded --
+# the lib lives in the repo -- so status goes to the console directly and the
+# event is logged as a warning once the lib is up.
+# ---------------------------------------------------------------------------
+
+if [ ! -d "$repo_path/.git" ] && ! $show_version; then
+    printf 'aitools: repo not found at %s -- cloning fresh...\n' "$repo_path"
+    mkdir -p "$(dirname "$repo_path")"
+    if ! git clone https://github.com/nobul-tech/aitools.git "$repo_path"; then
+        printf 'error: failed to clone the aitools repo to %s\n' "$repo_path" >&2
+        return 1
+    fi
+    _pre_lib_warnings+=("Repo was not found at $repo_path -- cloned fresh")
+fi
+
+# ---------------------------------------------------------------------------
+# Load aitools-lib (logging, display_path, write_summary, ...) for every command.
+# Without the repo nothing below can run; --version still answers.
+# ---------------------------------------------------------------------------
+
+aitools_lib="$repo_path/scripts/aitools-lib.sh"
+if [ ! -f "$aitools_lib" ]; then
+    if $show_version; then
+        echo "aitools $AITOOLS_INSTALLED_VERSION"
+        echo "  repo: not found at $repo_path"
+        return 0
+    fi
+    printf 'error: aitools-lib.sh not found at %s -- check repoPath in %s\n' "$aitools_lib" "$config" >&2
+    return 1
+fi
+source "$aitools_lib"
+logging_init "aitools"
+LOG_DISPLAY=$(display_path "$LOG_FILE")
+for _w in ${_pre_lib_warnings[@]+"${_pre_lib_warnings[@]}"}; do
+    log_warn "$_w"
+done
+
+# Reject unknown arguments when not installing (typos like "installs", "mcpp", etc.)
+if ! $do_install && [ ${#passthrough[@]} -gt 0 ]; then
+    log_error "unknown argument '${passthrough[0]}'"
+    echo "Run 'aitools --help' for usage."
+    return 1
+fi
+
+# Reject --addmcp with no server names
+if $addmcp_seen && [ ${#addmcp_servers[@]} -eq 0 ]; then
+    log_error "--addmcp requires at least one server name (vercel, webflow)"
+    return 1
+fi
+
 # ---------------------------------------------------------------------------
 # --version
 # ---------------------------------------------------------------------------
@@ -1372,22 +1422,6 @@ if $do_sessions; then
     return 0
 fi
 
-# ---------------------------------------------------------------------------
-# Verify repo exists (clone fresh if missing)
-# ---------------------------------------------------------------------------
-
-if [ ! -d "$repo_path/.git" ]; then
-    log_warn "Repo not found at $(display_path "$repo_path") -- cloning fresh..."
-    repos_dir=$(dirname "$repo_path")
-    mkdir -p "$repos_dir"
-    if git clone https://github.com/nobul-tech/aitools.git "$repo_path"; then
-        log_ok "Clone successful"
-    else
-        log_error "Failed to clone repo to $(display_path "$repo_path")"
-        return 1
-    fi
-fi
-
 # ---------------------------------------------------------------------------
 # Run update (pull + rebuild + deploy/install)
 # ---------------------------------------------------------------------------
@@ -1402,10 +1436,6 @@ touch "$AITOOLS_SUMMARY_FILE"
 export AITOOLS_SUMMARY_FILE
 export AITOOLS_SUPPRESS_SUMMARY_DISPLAY=1
 
-# Source shared lib (provides write_summary, show_summary)
-source "$repo_path/scripts/aitools-lib.sh"
-logging_init "aitools"
-
 log "aitools $AITOOLS_INSTALLED_VERSION"
 
 if $do_install; then
@@ -1443,8 +1473,11 @@ if $do_gitpull; then
             log_ok "Updated"
         fi
     else
-        log_error "git pull failed"
-        echo "$pull_out" >&2
+        while IFS= read -r _pull_line; do
+            if [ -n "$_pull_line" ]; then log_detail "git-pull: $_pull_line"; fi
+        done <<< "$pull_out"
+        log_error "git pull failed (see $LOG_DISPLAY)"
+        printf '%s\n' "$pull_out" >&2
         return 1
     fi
 else
@@ -1461,11 +1494,15 @@ else
             log_ok "Updated"
         fi
     else
+        # Full output to the log first; the console keeps a 3-line preview.
+        while IFS= read -r _pull_line; do
+            if [ -n "$_pull_line" ]; then log_detail "git-pull: $_pull_line"; fi
+        done <<< "$pull_out"
         if echo "$pull_out" | grep -qiE "could not resolve|unable to access|connection refused|connection timed out|no route to host"; then
             log_warn "Could not reach remote — deploying from local checkout"
         else
-            log_warn "git pull failed -- deploying from local checkout"
-            echo "$pull_out" | head -3 | sed 's/^/    /' >&2
+            log_warn "git pull failed -- deploying from local checkout (see $LOG_DISPLAY)"
+            printf '%s\n' "$pull_out" | head -3 | sed 's/^/    /' >&2
         fi
         write_summary WARN "source" "stale local checkout (git pull failed)"
     fi
@@ -1506,7 +1543,9 @@ if [ -f "$repo_path/scripts/aitools" ]; then
     if [ -n "$_repo_list" ] && [ "$_repo_list" != "$_self_list" ]; then
         log "Deploy script list changed -- reloading entry point"
         _nv=$(repo_version "$repo_path")
-        if bash -n "$repo_path/scripts/aitools" 2>/dev/null; then
+        _syntax_rc=0
+        _syntax_out=$(bash -n "$repo_path/scripts/aitools" 2>&1) || _syntax_rc=$?
+        if [ "$_syntax_rc" -eq 0 ]; then
             sed "s/^AITOOLS_INSTALLED_VERSION=.*/AITOOLS_INSTALLED_VERSION=\"$_nv\"/" \
                 "$repo_path/scripts/aitools" > "$HOME/.local/bin/aitools"
             chmod +x "$HOME/.local/bin/aitools"
@@ -1516,7 +1555,10 @@ if [ -f "$repo_path/scripts/aitools" ]; then
             # otherwise `install` degrades to the sync path on reload.
             exec "$HOME/.local/bin/aitools" ${_ORIG_ARGS[@]+"${_ORIG_ARGS[@]}"}
         else
-            log_warn "Repo scripts/aitools has syntax errors -- continuing with current list"
+            while IFS= read -r _syntax_line; do
+                if [ -n "$_syntax_line" ]; then log_detail "aitools syntax: $_syntax_line"; fi
+            done <<< "$_syntax_out"
+            log_warn "Repo scripts/aitools has syntax errors -- continuing with current list (see $LOG_DISPLAY)"
         fi
     fi
 fi
@@ -1668,27 +1710,38 @@ if [ -f "$repo_path/scripts/aitools" ]; then
     new_version=$(repo_version "$repo_path")
 
     # Validate bash syntax before overwriting installed copy
-    if bash -n "$repo_path/scripts/aitools" 2>/dev/null; then
+    _syntax_rc=0
+    _syntax_out=$(bash -n "$repo_path/scripts/aitools" 2>&1) || _syntax_rc=$?
+    if [ "$_syntax_rc" -eq 0 ]; then
         sed "s/^AITOOLS_INSTALLED_VERSION=.*/AITOOLS_INSTALLED_VERSION=\"$new_version\"/" \
             "$repo_path/scripts/aitools" > "$HOME/.local/bin/aitools"
         chmod +x "$HOME/.local/bin/aitools"
     else
-        log_warn "skipping bash self-update (new aitools has syntax errors)"
+        while IFS= read -r _syntax_line; do
+            if [ -n "$_syntax_line" ]; then log_detail "aitools syntax: $_syntax_line"; fi
+        done <<< "$_syntax_out"
+        log_warn "skipping bash self-update (new aitools has syntax errors; see $LOG_DISPLAY)"
     fi
 
     # On Windows, also self-update aitools.ps1 (validate with current PS version first)
     case "$(uname -s)" in
         MINGW*|MSYS*|CYGWIN*)
             if [ -f "$repo_path/scripts/aitools.ps1" ]; then
-                if pwsh -NoProfile -Command "
+                _parse_rc=0
+                _parse_out=$(pwsh -NoProfile -Command "
                     \$e = \$null
-                    [System.Management.Automation.Language.Parser]::ParseFile('$(cygpath -w "$repo_path/scripts/aitools.ps1")', [ref]\$null, [ref]\$e)
+                    \$null = [System.Management.Automation.Language.Parser]::ParseFile('$(cygpath -w "$repo_path/scripts/aitools.ps1")', [ref]\$null, [ref]\$e)
+                    foreach (\$x in \$e) { 'line ' + \$x.Extent.StartLineNumber + ': ' + \$x.Message }
                     if (\$e.Count -gt 0) { exit 1 }
-                " 2>/dev/null; then
+                " 2>&1) || _parse_rc=$?
+                if [ "$_parse_rc" -eq 0 ]; then
                     sed 's/^\$AITOOLS_INSTALLED_VERSION = ".*"/$AITOOLS_INSTALLED_VERSION = "'"$new_version"'"/' \
                         "$repo_path/scripts/aitools.ps1" > "$HOME/.local/bin/aitools.ps1"
                 else
-                    log_warn "skipping PS1 self-update (parse errors on this PowerShell version)"
+                    while IFS= read -r _parse_line; do
+                        if [ -n "$_parse_line" ]; then log_detail "aitools.ps1 parse: $_parse_line"; fi
+                    done <<< "$_parse_out"
+                    log_warn "skipping PS1 self-update (parse errors on this PowerShell version; see $LOG_DISPLAY)"
                 fi
             fi
             ;;
diff --git a/scripts/aitools.ps1 b/scripts/aitools.ps1
index 869e42d..68016c4 100644
--- a/scripts/aitools.ps1
+++ b/scripts/aitools.ps1
@@ -59,7 +59,9 @@ if ($Remaining -and $Remaining -contains "--force") {
 }
 
 # ---------------------------------------------------------------------------
-# Helpers
+# Bootstrap helper -- needed to find aitools-lib.ps1 (repoPath in config.json).
+# Everything else (logging, Write-Summary, ...) comes from the lib, which is
+# dot-sourced as soon as repoPath is known (see "Load aitools-lib" below).
 # ---------------------------------------------------------------------------
 
 function Read-ConfigKey {
@@ -75,23 +77,6 @@ function Read-ConfigKey {
     return $null
 }
 
-# ---------------------------------------------------------------------------
-# Logging (bootstrap -- overridden after lib is sourced below)
-# ---------------------------------------------------------------------------
-
-$logDir = if ($env:AITOOLS_LOG_DIR) { $env:AITOOLS_LOG_DIR } else { Join-Path $HOME ".aitools" "logs" }
-$logFile = Join-Path $logDir "deploy.log"
-if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
-$script:errors = 0
-$script:warnings = 0
-
-function Log($msg, $level = "info") {
-    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
-    Add-Content -Path $logFile -Value "[$ts] [aitools] [$level] $msg"
-}
-function LogOk($msg)    { Log $msg "ok" }
-function LogError($msg) { Log $msg "error"; Write-Host "error: $msg" -ForegroundColor Red; $script:errors++ }
-function LogWarn($msg)  { Log $msg "warn"; Write-Host "warning: $msg" -ForegroundColor Yellow; $script:warnings++ }
 
 # Check profile.json for issues and optionally prompt for fixes.
 # Usage: Invoke-ProfileCheck -Mode "warn" or "interactive"
@@ -161,7 +146,7 @@ function Invoke-ProfileMigration {
     $userRepoDir = Split-Path $profilePath -Parent
     $machAlias = Read-Host "Machine alias for this machine (e.g., laptop, workstation)"
     if (-not $machAlias) {
-        Write-Host "Migration cancelled (alias required)."
+        LogWarn "profile migration cancelled (alias required)"
         return
     }
 
@@ -257,13 +242,28 @@ fs.writeFileSync(f, JSON.stringify(cfg, null, 2) + '\n');
                 git -C $userRepoDir config user.name $gitName
                 git -C $userRepoDir config user.email $gitEmail
             }
-            git -C $userRepoDir add -A
-            git -C $userRepoDir commit -m "Migrate profile.json from v1 to v2"
-            $pushResult = git -C $userRepoDir push 2>&1
-            if ($LASTEXITCODE -ne 0) {
-                Write-Host "  (push failed -- run 'git push' manually in $userRepoDir)"
+            $gitOut = git -C $userRepoDir add -A 2>&1 | Out-String
+            $gitRc = $LASTEXITCODE
+            if ($gitRc -eq 0) {
+                $gitOut += git -C $userRepoDir commit -m "Migrate profile.json from v1 to v2" 2>&1 | Out-String
+                $gitRc = $LASTEXITCODE
+            }
+            foreach ($gitLine in $gitOut.Split("`n")) {
+                if ($gitLine.Trim()) { LogDetail "profile-migrate commit: $($gitLine.TrimEnd())" }
+            }
+            if ($gitRc -ne 0) {
+                LogWarn "profile migration commit failed (exit $gitRc) -- commit manually in $userRepoDir"
+                return
+            }
+            $pushOut = git -C $userRepoDir push 2>&1 | Out-String
+            $pushRc = $LASTEXITCODE
+            foreach ($gitLine in $pushOut.Split("`n")) {
+                if ($gitLine.Trim()) { LogDetail "profile-migrate push: $($gitLine.TrimEnd())" }
+            }
+            if ($pushRc -ne 0) {
+                LogWarn "profile migration push failed (exit $pushRc) -- run 'git push' manually in $userRepoDir"
             }
-            Write-Host "Profile migrated and committed."
+            LogOk "Profile migrated and committed."
         }
     }
 }
@@ -308,7 +308,11 @@ function Deploy-Configs {
             $null = [System.Management.Automation.Language.Parser]::ParseFile(
                 $scriptPath, [ref]$null, [ref]$parseErrors)
             if ($parseErrors.Count -gt 0) {
-                LogWarn "$script has parse errors -- skipping"
+                foreach ($err in $parseErrors) {
+                    LogDetail "$script parse: line $($err.Extent.StartLineNumber): $($err.Message)"
+                }
+                LogError "$script has parse errors -- skipped (see $logFile)"
+                Write-Summary "ERROR" ($script -replace '\.ps1$', '') "parse errors -- skipped"
                 $errors++
                 continue
             }
@@ -321,11 +325,14 @@ function Deploy-Configs {
                 & $scriptPath
             } catch {
                 LogError "$script failed: $_"
+                Write-Summary "ERROR" ($script -replace '\.ps1$', '') "script failed (exception)"
                 $errors++
                 continue
             }
-            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
-                LogError "$script failed (exit code $LASTEXITCODE)"
+            $scriptRc = $LASTEXITCODE
+            if ($scriptRc -and $scriptRc -ne 0) {
+                LogError "$script failed (exit $scriptRc) -- see $logFile"
+                Write-Summary "ERROR" ($script -replace '\.ps1$', '') "script failed (exit $scriptRc)"
                 $errors++
             }
         } else {
@@ -540,19 +547,9 @@ if ($doUser -or $doSessions) {
     }
 }
 
-# Reject unknown commands (typos like "installs", "mcpp", etc.)
-$knownCommands = @("install", "gitpull", "mcp", "user", "sessions", "dashboard", "")
-if ($Command -and $Command -notin $knownCommands) {
-    LogError "unknown command '$Command'"
-    Write-Host "Run 'aitools --help' for usage."
-    exit 1
-}
-
-# Reject --addmcp with no server names
-if ($PSBoundParameters.ContainsKey('AddMcp') -and $AddMcp.Count -eq 0) {
-    LogError "--addmcp requires at least one server name (vercel, webflow)"
-    exit 1
-}
+# Warnings and notes found before the lib is loaded (it holds the logging); logged right after.
+$preLibWarnings = @()
+$preLibNotes = @()
 
 # ---------------------------------------------------------------------------
 # Migrate config directory: ~\.config\ai-tooling\ -> ~\.aitools\
@@ -564,7 +561,7 @@ $newConfigDir = Join-Path $env:USERPROFILE ".aitools"
 if ((Test-Path $oldConfigDir) -and -not (Test-Path $newConfigDir)) {
     Move-Item -Path $oldConfigDir -Destination $newConfigDir
 } elseif ((Test-Path $oldConfigDir) -and (Test-Path $newConfigDir)) {
-    LogWarn "both $oldConfigDir and $newConfigDir exist -- using $newConfigDir"
+    $preLibWarnings += "both $oldConfigDir and $newConfigDir exist -- using $newConfigDir"
 }
 
 # ---------------------------------------------------------------------------
@@ -592,15 +589,67 @@ if ($oldKey) {
         $json = $cfgObj | ConvertTo-Json -Depth 10
         $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($configFile)
         [System.IO.File]::WriteAllText($resolved, $json + "`n", [System.Text.UTF8Encoding]::new($false))
-        Log "Migrated config: aiToolingRepoPath -> repoPath"
+        $preLibNotes += "Migrated config: aiToolingRepoPath -> repoPath"
         # Re-read after migration
         $repoPath = Read-ConfigKey -File $configFile -Key "repoPath"
     } catch {
-        LogWarn "Config key migration failed: $_"
+        $preLibWarnings += "Config key migration failed: $_"
         # Non-fatal: continue with whatever repoPath was already resolved
     }
 }
 
+# ---------------------------------------------------------------------------
+# Verify repo exists (clone fresh if missing). Runs before the lib is loaded --
+# the lib lives in the repo -- so status goes to the console directly and the
+# event is logged as a warning once the lib is up.
+# ---------------------------------------------------------------------------
+
+if (-not (Test-Path (Join-Path $repoPath ".git")) -and -not $Version) {
+    Write-Host "aitools: repo not found at $repoPath -- cloning fresh..."
+    $reposDir = Split-Path $repoPath -Parent
+    if (-not (Test-Path $reposDir)) { New-Item -ItemType Directory -Path $reposDir -Force | Out-Null }
+    git clone https://github.com/nobul-tech/aitools.git $repoPath
+    if ($LASTEXITCODE -ne 0) {
+        [Console]::Error.WriteLine("error: failed to clone the aitools repo to $repoPath")
+        exit 1
+    }
+    $preLibWarnings += "Repo was not found at $repoPath -- cloned fresh"
+}
+
+# ---------------------------------------------------------------------------
+# Load aitools-lib (logging, Write-Summary, ...) for every command.
+# Without the repo nothing below can run; -Version still answers.
+# ---------------------------------------------------------------------------
+
+$aitoolsLib = Join-Path $repoPath "scripts" "aitools-lib.ps1"
+if (-not (Test-Path $aitoolsLib)) {
+    if ($Version) {
+        Write-Host "aitools $AITOOLS_INSTALLED_VERSION"
+        Write-Host "  repo: not found at $repoPath"
+        exit 0
+    }
+    [Console]::Error.WriteLine("error: aitools-lib.ps1 not found at $aitoolsLib -- check repoPath in $configFile")
+    exit 1
+}
+. $aitoolsLib
+Initialize-Logging "aitools"
+foreach ($note in $preLibNotes) { Log $note }
+foreach ($w in $preLibWarnings) { LogWarn $w }
+
+# Reject unknown commands (typos like "installs", "mcpp", etc.)
+$knownCommands = @("install", "gitpull", "mcp", "user", "sessions", "dashboard", "")
+if ($Command -and $Command -notin $knownCommands) {
+    LogError "unknown command '$Command'"
+    Write-Host "Run 'aitools --help' for usage."
+    exit 1
+}
+
+# Reject --addmcp with no server names
+if ($PSBoundParameters.ContainsKey('AddMcp') -and $AddMcp.Count -eq 0) {
+    LogError "--addmcp requires at least one server name (vercel, webflow)"
+    exit 1
+}
+
 # ---------------------------------------------------------------------------
 # --version
 # ---------------------------------------------------------------------------
@@ -1284,22 +1333,6 @@ if ($doSessions) {
     exit 0
 }
 
-# ---------------------------------------------------------------------------
-# Verify repo exists (clone fresh if missing)
-# ---------------------------------------------------------------------------
-
-if (-not (Test-Path (Join-Path $repoPath ".git"))) {
-    LogWarn "Repo not found at $repoPath -- cloning fresh..."
-    $reposDir = Split-Path $repoPath -Parent
-    if (-not (Test-Path $reposDir)) { New-Item -ItemType Directory -Path $reposDir -Force | Out-Null }
-    git clone https://github.com/nobul-tech/aitools.git $repoPath
-    if ($LASTEXITCODE -ne 0) {
-        LogError "Failed to clone repo to $repoPath"
-        exit 1
-    }
-    LogOk "Clone successful"
-}
-
 # ---------------------------------------------------------------------------
 # Run update (pull + rebuild + deploy/install)
 # ---------------------------------------------------------------------------
@@ -1313,9 +1346,6 @@ Remove-Item $env:AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
 New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force | Out-Null
 $env:AITOOLS_SUPPRESS_SUMMARY_DISPLAY = "1"
 
-# Source shared lib (provides Write-Summary, Show-Summary)
-. (Join-Path $repoPath "scripts" "aitools-lib.ps1")
-Initialize-Logging "aitools"
 
 Log "aitools $AITOOLS_INSTALLED_VERSION"
 
@@ -1353,15 +1383,19 @@ try {
         $pullOut = git pull origin main 2>&1 | Out-String
     }
     if ($LASTEXITCODE -ne 0) {
+        # Full output to the log first; the console keeps its preview.
+        foreach ($pullLine in $pullOut.Split("`n")) {
+            if ($pullLine.Trim()) { LogDetail "git-pull: $($pullLine.TrimEnd())" }
+        }
         if ($doGitpull) {
-            LogError "git pull failed"
+            LogError "git pull failed (see $logFile)"
             Write-Host $pullOut
             exit 1
         } else {
             if ($pullOut -match "(?i)(could not resolve|unable to access|connection refused|connection timed out|no route to host)") {
                 LogWarn "Could not reach remote - deploying from local checkout"
             } else {
-                LogWarn "git pull failed -- deploying from local checkout."
+                LogWarn "git pull failed -- deploying from local checkout (see $logFile)"
                 $pullOut.Trim().Split("`n") | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" }
             }
             Write-Summary "WARN" "source" "stale local checkout (git pull failed)"
@@ -1433,7 +1467,10 @@ if (Test-Path $repoAitools) {
             & $installedPath @PSBoundParameters
             exit $LASTEXITCODE
         } else {
-            LogWarn "Repo scripts/aitools.ps1 has parse errors -- continuing with current list"
+            foreach ($err in $parseErrors) {
+                LogDetail "aitools.ps1 parse: line $($err.Extent.StartLineNumber): $($err.Message)"
+            }
+            LogWarn "Repo scripts/aitools.ps1 has parse errors -- continuing with current list (see $logFile)"
         }
     }
 }
@@ -1581,7 +1618,10 @@ if (Test-Path $aitoolsSrc) {
     $parseErrors = $null
     $null = [System.Management.Automation.Language.Parser]::ParseFile($aitoolsSrc, [ref]$null, [ref]$parseErrors)
     if ($parseErrors.Count -gt 0) {
-        LogWarn "skipping PS1 self-update (new aitools.ps1 has parse errors on this PowerShell version)"
+        foreach ($err in $parseErrors) {
+            LogDetail "aitools.ps1 parse: line $($err.Extent.StartLineNumber): $($err.Message)"
+        }
+        LogWarn "skipping PS1 self-update (new aitools.ps1 has parse errors on this PowerShell version; see $logFile)"
     } else {
         $srcContent = Get-Content $aitoolsSrc -Raw
         $stampedContent = $srcContent -replace '^\$AITOOLS_INSTALLED_VERSION = ".*"', "`$AITOOLS_INSTALLED_VERSION = `"$newVersion`""
```

#### Batch C4b

```diff
diff --git a/scripts/aitools-install.sh b/scripts/aitools-install.sh
index 37799ba..652b02c 100755
--- a/scripts/aitools-install.sh
+++ b/scripts/aitools-install.sh
@@ -9,6 +9,11 @@
 
 set -euo pipefail
 
+# --- Shared library (first, so flag errors and Windows forwarding are logged) ---
+SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
+source "$SCRIPT_DIR/aitools-lib.sh"
+logging_init "aitools-install"
+
 # --- Defaults ---
 REPOS_PATH=""
 SKIP_DRIVE_DETECTION=false
@@ -40,7 +45,7 @@ while [[ $# -gt 0 ]]; do
             shift
             ;;
         *)
-            echo "Unknown option: $1" >&2
+            log_warn "Unknown option: $1"
             SHOW_HELP=true
             shift
             ;;
@@ -74,9 +79,10 @@ fi
 # --- Windows forwarding (safety net for direct invocation) ---
 case "$(uname -s)" in
     MINGW*|MSYS*|CYGWIN*)
-        ps1_installer="$(dirname "$0")/aitools-install.ps1"
+        ps1_installer="$SCRIPT_DIR/aitools-install.ps1"
         if [ ! -f "$ps1_installer" ]; then
-            echo "error: aitools-install.ps1 not found" >&2
+            log_error "aitools-install.ps1 not found"
+            write_summary ERROR "aitools install" "aitools-install.ps1 missing"
             exit 1
         fi
         ps_args=()
@@ -86,15 +92,25 @@ case "$(uname -s)" in
         if [ -n "$REPOS_PATH" ]; then
             ps_args+=("-ReposPath" "$(cygpath -w "$REPOS_PATH")")
         fi
-        echo "Windows detected -- forwarding to PowerShell installer..."
+        log "Windows detected -- forwarding to PowerShell installer..."
         # Bootstrap: if pwsh not installed, use powershell.exe to install it via winget
         if ! command -v pwsh &>/dev/null; then
-            echo "pwsh (PowerShell 7) not found -- installing via winget..."
-            powershell.exe -NoProfile -Command 'winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements'
+            log "pwsh (PowerShell 7) not found -- installing via winget..."
+            pwsh_install_rc=0
+            pwsh_install_out=$(powershell.exe -NoProfile -Command 'winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements' 2>&1) || pwsh_install_rc=$?
+            while IFS= read -r line; do
+                if [ -n "$line" ]; then log_detail "winget-pwsh: $line"; fi
+            done <<< "$pwsh_install_out"
             # Refresh PATH hash so pwsh is found
             hash -r
             if ! command -v pwsh &>/dev/null; then
-                echo "error: pwsh install succeeded but not in PATH. Restart terminal and re-run." >&2
+                if [ "$pwsh_install_rc" -ne 0 ]; then
+                    log_error "winget install of PowerShell 7 failed (exit $pwsh_install_rc) -- see $(display_path "$LOG_FILE")"
+                    write_summary ERROR "pwsh" "winget install failed (exit $pwsh_install_rc)"
+                else
+                    log_error "pwsh install succeeded but not in PATH. Restart terminal and re-run."
+                    write_summary ERROR "pwsh" "installed but not on PATH"
+                fi
                 exit 1
             fi
         fi
@@ -104,11 +120,6 @@ case "$(uname -s)" in
         ;;
 esac
 
-# --- Shared library ---
-SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
-source "$SCRIPT_DIR/aitools-lib.sh"
-logging_init "aitools-install"
-
 # JSONL logging (extends standard pattern with structured JSON)
 LOG_JSONL="$LOG_DIR/deploy.jsonl"
 RUN_ID="${AITOOLS_RUN_ID:-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
@@ -138,15 +149,27 @@ if [ -z "${AITOOLS_SUMMARY_FILE:-}" ]; then
 fi
 
 # --- Script validation helper ---
-# Validates bash syntax with bash -n before executing. Skips with warning on errors.
+# Validates bash syntax with bash -n before executing. A syntax error or a failed
+# script logs an error and writes an ERROR summary row; the install continues.
 validate_and_run() {
     local script="$1"
     local name; name=$(basename "$script")
-    if ! bash -n "$script" 2>/dev/null; then
-        log_warn "$name has syntax errors -- skipping"
+    local syntax_out syntax_rc=0 syntax_line
+    syntax_out=$(bash -n "$script" 2>&1) || syntax_rc=$?
+    if [ "$syntax_rc" -ne 0 ]; then
+        while IFS= read -r syntax_line; do
+            if [ -n "$syntax_line" ]; then log_detail "$name syntax: $syntax_line"; fi
+        done <<< "$syntax_out"
+        log_error "$name has syntax errors -- skipped (see $(display_path "$LOG_FILE"))"
+        write_summary ERROR "${name%.sh}" "syntax errors -- skipped"
         return 0
     fi
-    bash "$script" || log_error "$name failed"
+    local script_rc=0
+    bash "$script" || script_rc=$?
+    if [ "$script_rc" -ne 0 ]; then
+        log_error "$name failed (exit $script_rc)"
+        write_summary ERROR "${name%.sh}" "script failed (exit $script_rc)"
+    fi
 }
 
 # display_path is provided by aitools-lib.sh
@@ -283,9 +306,18 @@ elif gh auth status &>/dev/null; then
     log_ok "gh already authenticated"
 elif $INSTALL_INTERACTIVE; then
     log "Not authenticated. Starting gh auth login..."
-    gh auth login || log_error "gh auth login failed"
+    # Interactive: gh talks to the terminal directly, so only the exit code is captured.
+    gh_auth_rc=0
+    gh auth login || gh_auth_rc=$?
+    if [ "$gh_auth_rc" -ne 0 ]; then
+        log_error "gh auth login failed (exit $gh_auth_rc)"
+        write_summary ERROR "gh auth" "login failed (exit $gh_auth_rc)"
+        write_summary ACTION "" "Run: gh auth login"
+    fi
 else
     log_warn "Not authenticated and not interactive — skipping gh auth (use --skip-gh-auth to suppress)"
+    write_summary WARN "gh auth" "not authenticated"
+    write_summary ACTION "" "Run: gh auth login"
 fi
 
 # ============================================================
@@ -633,9 +665,6 @@ else
                 write_summary ERROR "node.js" "Homebrew not found"
             fi
             ;;
-        MINGW*|MSYS*)
-            log "Windows detected — install Node.js via winget (use aitools-install.ps1)"
-            ;;
         *)
             log_warn "Install Node.js manually: https://nodejs.org"
             write_summary WARN "node.js" "install manually (https://nodejs.org)"
@@ -653,49 +682,33 @@ if command -v claude &>/dev/null; then
     log_ok "Claude Code already installed ($(claude --version 2>/dev/null | head -1))"
     write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
     log "Running claude update..."
-    UPDATE_OUTPUT=$(claude update 2>&1) || true
-    if printf '%s\n' "$UPDATE_OUTPUT" | grep -qi 'already.*up.to.date\|no update'; then
+    # Exit code decides (C-F2); every output line is logged.
+    update_rc=0
+    UPDATE_OUTPUT=$(claude update 2>&1) || update_rc=$?
+    while IFS= read -r line; do
+        if [ -n "$line" ]; then log "$line"; fi
+    done <<< "$UPDATE_OUTPUT"
+    if [ "$update_rc" -ne 0 ]; then
+        log_warn "claude update failed (exit $update_rc) -- see $(display_path "$LOG_FILE")"
+    elif printf '%s\n' "$UPDATE_OUTPUT" | grep -qi 'already.*up.to.date\|no update'; then
         log_ok "Already up to date"
     else
-        printf '%s\n' "$UPDATE_OUTPUT" | while IFS= read -r line; do log "$line"; done
-        if printf '%s\n' "$UPDATE_OUTPUT" | grep -qi 'error\|fatal'; then
-            log_warn "claude update returned unexpected output (see log above)"
-        fi
+        log_ok "claude update finished"
     fi
 else
     log "Installing Claude Code CLI..."
-    case "$OS_NAME" in
-        MINGW*|MSYS*)
-            # WinGet works from Git Bash
-            if command -v winget &>/dev/null; then
-                # Suppress winget progress noise; install success checked via command -v below
-                winget install Anthropic.ClaudeCode --accept-package-agreements --accept-source-agreements 2>/dev/null
-                if command -v claude &>/dev/null; then
-                    log_ok "Claude Code installed ($(claude --version 2>/dev/null | head -1))"
-                    write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
-                else
-                    log_warn "Claude Code installed — restart terminal to use"
-                    write_summary WARN "claude code" "installed -- restart terminal to use"
-                fi
-            else
-                log "winget not available — install manually:"
-                log "  PowerShell: irm https://claude.ai/install.ps1 | iex"
-            fi
-            ;;
-        *)
-            if ! curl -fsSL https://claude.ai/install.sh | bash 2>&1 | while IFS= read -r line; do log "$line"; done; then
-                log_error "Claude Code install script failed"
-                write_summary ERROR "claude code" "install failed"
-            fi
-            if command -v claude &>/dev/null; then
-                log_ok "Claude Code installed ($(claude --version 2>/dev/null | head -1))"
-                write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
-            else
-                log_error "Claude Code install failed"
-                write_summary ERROR "claude code" "install failed"
-            fi
-            ;;
-    esac
+    # Windows never reaches here: it is forwarded to aitools-install.ps1 at the top.
+    if ! curl -fsSL https://claude.ai/install.sh | bash 2>&1 | while IFS= read -r line; do log "$line"; done; then
+        log_error "Claude Code install script failed"
+        write_summary ERROR "claude code" "install failed"
+    fi
+    if command -v claude &>/dev/null; then
+        log_ok "Claude Code installed ($(claude --version 2>/dev/null | head -1))"
+        write_summary OK "claude code" "$(claude --version 2>/dev/null | head -1)"
+    else
+        log_error "Claude Code install failed"
+        write_summary ERROR "claude code" "install failed"
+    fi
 fi
 
 # ============================================================
diff --git a/scripts/aitools-install.ps1 b/scripts/aitools-install.ps1
index 2b2e6db..cd5c462 100644
--- a/scripts/aitools-install.ps1
+++ b/scripts/aitools-install.ps1
@@ -87,7 +87,8 @@ if (-not $env:AITOOLS_SUMMARY_FILE) {
 $installInteractive = ($env:AITOOLS_FORCE -ne "1") -and (Test-InteractiveConsole)
 
 # --- Script validation helper ---
-# Validates PS1 syntax with ParseFile before executing. Skips with warning on parse errors.
+# Validates PS1 syntax with ParseFile before executing. A parse error or a failed
+# script logs an error and writes an ERROR summary row; the install continues.
 function Invoke-ValidatedScript {
     param([string]$ScriptPath)
     $name = Split-Path $ScriptPath -Leaf
@@ -95,13 +96,26 @@ function Invoke-ValidatedScript {
     $null = [System.Management.Automation.Language.Parser]::ParseFile(
         $ScriptPath, [ref]$null, [ref]$parseErrors)
     if ($parseErrors.Count -gt 0) {
-        LogWarn "$name has parse errors on this PowerShell version -- skipping"
         foreach ($err in $parseErrors) {
-            Log "  line $($err.Extent.StartLineNumber): $($err.Message)" "warn"
+            LogDetail "$name parse: line $($err.Extent.StartLineNumber): $($err.Message)"
         }
+        LogError "$name has parse errors on this PowerShell version -- skipped"
+        Write-Summary "ERROR" ($name -replace '\.ps1$', '') "parse errors -- skipped"
         return
     }
-    try { & $ScriptPath } catch { LogError "$name failed: $_" }
+    $global:LASTEXITCODE = 0
+    try {
+        & $ScriptPath
+    } catch {
+        LogError "$name failed: $_"
+        Write-Summary "ERROR" ($name -replace '\.ps1$', '') "script failed (exception)"
+        return
+    }
+    $scriptRc = $LASTEXITCODE
+    if ($scriptRc -and $scriptRc -ne 0) {
+        LogError "$name failed (exit $scriptRc)"
+        Write-Summary "ERROR" ($name -replace '\.ps1$', '') "script failed (exit $scriptRc)"
+    }
 }
 
 # --- Post-write JSON validation ---
@@ -167,8 +181,16 @@ if ($longPathsEnabled) {
 $gitLongPaths = git config --global core.longpaths 2>$null
 if ($gitLongPaths -ne "true") {
     Log "Setting git config --global core.longpaths true..."
-    git config --global core.longpaths true
-    LogOk "git core.longpaths enabled"
+    $longPathsOut = git config --global core.longpaths true 2>&1 | Out-String
+    $longPathsRc = $LASTEXITCODE
+    foreach ($lpLine in $longPathsOut.Split("`n")) {
+        if ($lpLine.Trim()) { LogDetail "git-longpaths: $($lpLine.TrimEnd())" }
+    }
+    if ($longPathsRc -eq 0) {
+        LogOk "git core.longpaths enabled"
+    } else {
+        LogWarn "git config --global core.longpaths true failed (exit $longPathsRc) -- deep paths may fail"
+    }
 } else {
     LogOk "git core.longpaths already enabled"
 }
@@ -200,12 +222,18 @@ if ($SkipGhAuth) {
         LogOk "gh already authenticated"
     } elseif ($installInteractive) {
         Log "Not authenticated. Starting gh auth login..."
+        # Interactive: gh talks to the console directly, so only the exit code is captured.
         gh auth login
-        if ($LASTEXITCODE -ne 0) {
-            LogError "gh auth login failed"
+        $ghAuthRc = $LASTEXITCODE
+        if ($ghAuthRc -ne 0) {
+            LogError "gh auth login failed (exit $ghAuthRc)"
+            Write-Summary "ERROR" "gh auth" "login failed (exit $ghAuthRc)"
+            Write-Summary "ACTION" "" "Run: gh auth login"
         }
     } else {
-        LogWarn "Not authenticated and not interactive -- skipping gh auth"
+        LogWarn "Not authenticated and not interactive -- skipping gh auth (use -SkipGhAuth to suppress)"
+        Write-Summary "WARN" "gh auth" "not authenticated"
+        Write-Summary "ACTION" "" "Run: gh auth login"
     }
 }
 
@@ -325,9 +353,28 @@ if ($existingUserRepoPath) { $config["userRepoPath"] = $existingUserRepoPath }
 if ($existingMachineAlias) { $config["machineAlias"] = $existingMachineAlias }
 
 $jsonContent = $config | ConvertTo-Json -Depth 10
-[System.IO.File]::WriteAllText($configFile, $jsonContent, [System.Text.UTF8Encoding]::new($false))
-LogOk "Config written to $configFile"
-ValidateJsonConfig -File $configFile -RequiredKeys @("version", "reposPath", "repoPath")
+$configExisted = Test-Path $configFile
+Backup-File $configFile
+$configWritten = $false
+try {
+    [System.IO.File]::WriteAllText($configFile, $jsonContent, [System.Text.UTF8Encoding]::new($false))
+    $configWritten = $true
+} catch {
+    LogError "Failed to write $configFile`: $_"
+    Write-Summary "ERROR" "aitools config" "write failed"
+}
+if ($configWritten) {
+    LogOk "Config written to $configFile"
+    $errorsBeforeValidation = $script:errors
+    ValidateJsonConfig -File $configFile -RequiredKeys @("version", "reposPath", "repoPath")
+    if ($script:errors -gt $errorsBeforeValidation) {
+        Write-Summary "ERROR" "aitools config" "validation failed"
+    } elseif ($configExisted) {
+        Write-Summary "OK" "aitools config" "updated"
+    } else {
+        Write-Summary "OK" "aitools config" "created"
+    }
+}
 
 # ============================================================
 # 6. Install aitools command
@@ -514,14 +561,25 @@ if (Get-Command claude -ErrorAction SilentlyContinue) {
     Write-Summary "OK" "claude code" "$(claude --version 2>$null | Select-Object -First 1)"
     Log "Running claude update..."
     $claudeOutput = claude update 2>&1 | Out-String
-    $claudeOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
-    if ($LASTEXITCODE -ne 0) {
-        LogWarn "claude update returned non-zero (exit $LASTEXITCODE)"
+    $updateRc = $LASTEXITCODE
+    foreach ($updateLine in $claudeOutput.Split("`n")) {
+        if ($updateLine.Trim()) { Log $updateLine.TrimEnd() }
+    }
+    if ($updateRc -ne 0) {
+        LogWarn "claude update failed (exit $updateRc) -- see $logFile"
+    } elseif ($claudeOutput -match '(?i)already.*up.to.date|no update') {
+        LogOk "Already up to date"
+    } else {
+        LogOk "claude update finished"
     }
 } else {
     Log "Installing Claude Code CLI..."
     try {
-        Invoke-Expression (Invoke-RestMethod 'https://claude.ai/install.ps1')
+        # Capture every stream of the official installer so its output reaches the log.
+        $installOut = Invoke-Expression (Invoke-RestMethod 'https://claude.ai/install.ps1') *>&1 | Out-String
+        foreach ($installLine in $installOut.Split("`n")) {
+            if ($installLine.Trim()) { Log $installLine.TrimEnd() }
+        }
         Refresh-Path
         if (Get-Command claude -ErrorAction SilentlyContinue) {
             LogOk "Claude Code installed ($(claude --version 2>$null | Select-Object -First 1))"
```

#### Batch T1

```diff
diff --git a/tests/logging/test-logging.sh b/tests/logging/test-logging.sh
new file mode 100755
index 0000000..979b132
--- /dev/null
+++ b/tests/logging/test-logging.sh
@@ -0,0 +1,142 @@
+#!/usr/bin/env bash
+# test-logging.sh -- unit tests for the shared logging framework (scripts/aitools-lib.sh)
+# and for the bash entry point's use of it (scripts/aitools).
+#
+# Safe to re-run: every case runs in its own temp HOME / log dir, removed on exit.
+# Platform: macOS, Linux, Windows (Git Bash). Exit 1 if any case fails.
+# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
+# end-of-run summary), reference/logging.md (location, rotation),
+# reference/script-standards-detail.md "Logging overrides".
+#
+# Usage: bash tests/logging/test-logging.sh [--help]
+
+set -uo pipefail
+
+if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
+    sed -n '2,12p' "$0"
+    exit 0
+fi
+
+ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
+LIB="$ROOT/scripts/aitools-lib.sh"
+ENTRY="$ROOT/scripts/aitools"
+TMP_ROOT="$(mktemp -d)"
+trap 'rm -rf "$TMP_ROOT"' EXIT
+
+PASS=0
+FAIL=0
+ESC=$(printf '\033')
+TS_RE='\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]'
+
+check() {  # name, condition (eval'd)
+    if eval "$2"; then
+        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
+    else
+        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
+    fi
+}
+
+# run_lib <case> <snippet>: source the lib in a fresh bash with an isolated log dir.
+# Console output -> $C/out, the log -> $C/logs/deploy.log, rc -> $C/rc.
+run_lib() {
+    C="$TMP_ROOT/$1"
+    mkdir -p "$C/home"
+    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="${SUMMARY:-}" \
+        bash -c "set -uo pipefail; source '$LIB'; logging_init t; $2" > "$C/out" 2>&1
+    echo $? > "$C/rc"
+    LOG="$C/logs/deploy.log"
+    [ -f "$LOG" ] || : > "$LOG"
+}
+
+# ---------------------------------------------------------------------------
+# aitools-lib.sh
+# ---------------------------------------------------------------------------
+
+run_lib format 'log "hello world"'
+check "lib: log line format [ts] [script] [level] message" \
+    "grep -Eq '^${TS_RE} \[t\] \[info\] hello world\$' '$LOG'"
+check "lib: log file is AITOOLS_LOG_DIR/deploy.log" "[ -s '$C/logs/deploy.log' ]"
+
+run_lib levels 'log_ok a; log_warn b; log_error c; log d info'
+check "lib: levels ok/warn/error/info recorded" \
+    "grep -q '\[ok\] a' '$LOG' && grep -q '\[warn\] b' '$LOG' && grep -q '\[error\] c' '$LOG' && grep -q '\[info\] d' '$LOG'"
+check "lib: log file has no ANSI codes" "! grep -q '$ESC' '$LOG'"
+check "lib: warn is yellow on the console" "grep -q '${ESC}\[33m.*\[warn\] b' '$C/out'"
+check "lib: error is red on the console" "grep -q '${ESC}\[31m.*\[error\] c' '$C/out'"
+check "lib: info is plain on the console" "grep -Eq '^${TS_RE} \[t\] \[info\] d\$' '$C/out'"
+
+run_lib detail 'log_detail "secret diff line"'
+check "lib: log_detail writes the log" "grep -q '\[detail\] secret diff line' '$LOG'"
+check "lib: log_detail stays off the console" "! grep -q 'secret diff line' '$C/out'"
+
+run_lib counters 'log_error x; log_error y; log_warn z; echo "COUNTS=$ERRORS/$WARNINGS"'
+check "lib: log_error/log_warn increment ERRORS/WARNINGS" "grep -q 'COUNTS=2/1' '$C/out'"
+
+run_lib reset 'log_error x; logging_init t2; echo "COUNTS=$ERRORS/$WARNINGS"'
+check "lib: logging_init resets the counters" "grep -q 'COUNTS=0/0' '$C/out'"
+
+SUMMARY="" run_lib nosummary 'write_summary ERROR tool detail; echo "RC=$?"'
+check "lib: write_summary is a no-op without AITOOLS_SUMMARY_FILE" "grep -q 'RC=0' '$C/out'"
+
+SUMMARY="$TMP_ROOT/summary.txt" run_lib summary 'write_summary ERROR tool "it failed"; write_summary OK tool2 v1'
+check "lib: write_summary writes CAT|tool|detail" "grep -qx 'ERROR|tool|it failed' '$TMP_ROOT/summary.txt'"
+check "lib: write_summary OK stays OK with no warnings" "grep -qx 'OK|tool2|v1' '$TMP_ROOT/summary.txt'"
+
+SUMMARY="$TMP_ROOT/summary2.txt" run_lib promote 'log_warn w; write_summary OK tool v1'
+check "lib: write_summary promotes OK to WARN after a warning" "grep -qx 'WARN|tool|v1' '$TMP_ROOT/summary2.txt'"
+
+C="$TMP_ROOT/rotate"; mkdir -p "$C/logs"
+head -c 5242880 /dev/zero | tr '\0' 'x' > "$C/logs/deploy.log"
+# Console output is irrelevant here; the check below inspects the rotated files.
+env HOME="$C" AITOOLS_LOG_DIR="$C/logs" bash -c "source '$LIB'; logging_init t; log after" > /dev/null 2>&1
+check "lib: logging_init rotates a 5 MB log to deploy.log.1" \
+    "[ -f '$C/logs/deploy.log.1' ] && grep -q '\[info\] after' '$C/logs/deploy.log' && [ \$(wc -c < '$C/logs/deploy.log') -lt 1000 ]"
+
+# ---------------------------------------------------------------------------
+# scripts/aitools (entry point) -- uses the lib's logging, defines none of its own
+# ---------------------------------------------------------------------------
+
+check "entry: defines no log functions (uses aitools-lib)" \
+    "! grep -Eq '^[[:space:]]*(log|log_ok|log_warn|log_error|log_detail)\(\)' '$ENTRY'"
+
+# fake_repo <case> [with-lib]: HOME with config.json -> a repo dir holding the lib.
+fake_repo() {
+    C="$TMP_ROOT/$1"
+    mkdir -p "$C/home/.aitools" "$C/repo/.git" "$C/repo/scripts"
+    if [ "${2:-}" = "with-lib" ]; then cp "$LIB" "$C/repo/scripts/"; fi
+    printf '{"version":2,"repoPath":"%s"}\n' "$C/repo" > "$C/home/.aitools/config.json"
+}
+run_entry() {  # args... (uses $C from fake_repo)
+    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" bash "$ENTRY" "$@" < /dev/null > "$C/out" 2> "$C/err"
+    echo $? > "$C/rc"
+    LOG="$C/logs/deploy.log"
+    [ -f "$LOG" ] || { mkdir -p "$C/logs"; : > "$LOG"; }
+}
+
+fake_repo unknown with-lib
+run_entry --bogus-flag
+check "entry: unknown argument exits 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
+check "entry: unknown argument written to deploy.log" \
+    "grep -Eq '^${TS_RE} \[aitools\] \[error\] unknown argument .--bogus-flag.' '$LOG'"
+check "entry: unknown argument shown in the lib's console format (not a bare 'error:')" \
+    "grep -Eq '${TS_RE} \[aitools\] \[error\] unknown argument' '$C/out' && ! grep -q '^error: unknown argument' '$C/err'"
+
+fake_repo prelib with-lib
+mkdir -p "$C/home/.config/ai-tooling"
+run_entry --bogus-flag
+check "entry: warnings found before the lib loads are logged after it loads" \
+    "grep -q '\[aitools\] \[warn\] both .*ai-tooling.* exist' '$LOG'"
+
+fake_repo nolib
+run_entry --bogus-flag
+check "entry: missing aitools-lib exits 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
+check "entry: missing aitools-lib names the path on stderr" "grep -q 'aitools-lib.sh not found at $C/repo/scripts' '$C/err'"
+
+fake_repo version
+rm -rf "$C/repo"
+run_entry --version
+check "entry: --version answers without the repo" \
+    "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q '^aitools ' '$C/out' && grep -q 'repo: not found' '$C/out'"
+
+printf -- '---- %d passed, %d failed\n' "$PASS" "$FAIL"
+[ "$FAIL" -eq 0 ]
diff --git a/tests/logging/test-logging.ps1 b/tests/logging/test-logging.ps1
new file mode 100644
index 0000000..5e2f928
--- /dev/null
+++ b/tests/logging/test-logging.ps1
@@ -0,0 +1,157 @@
+# test-logging.ps1 -- unit tests for the shared logging framework (scripts/aitools-lib.ps1)
+# and for the PowerShell entry point's use of it (scripts/aitools.ps1).
+#
+# Safe to re-run: every case uses its own temp log dir, removed on exit.
+# Platform: Windows, macOS, Linux (pwsh 7). Entry-point run cases need Windows
+# (aitools.ps1 has a Windows OS guard) and are reported as SKIP elsewhere.
+# Exit 1 if any case fails.
+# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
+# end-of-run summary), reference/logging.md, reference/script-standards-detail.md
+# "Logging overrides".
+#
+# Usage: pwsh -NoProfile -File tests/logging/test-logging.ps1 [-Help]
+
+param([switch]$Help)
+
+if ($Help) {
+    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 11
+    exit 0
+}
+
+$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
+$lib = Join-Path $root "scripts" "aitools-lib.ps1"
+$entry = Join-Path $root "scripts" "aitools.ps1"
+$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-logtest-" + [guid]::NewGuid())
+New-Item -ItemType Directory -Path $tmpRoot | Out-Null
+
+$script:pass = 0
+$script:fail = 0
+$script:skip = 0
+$tsRe = '\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\]'
+
+function Check([string]$Name, [bool]$Ok) {
+    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ } else { Write-Output "FAIL $Name"; $script:fail++ }
+}
+function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }
+
+# Run a snippet in a fresh pwsh with the lib dot-sourced and an isolated log dir.
+# Returns @{ Out = console text; Log = deploy.log text; Dir = case dir }.
+function Invoke-LibCase([string]$Case, [string]$Snippet, [string]$SummaryFile = "") {
+    $dir = Join-Path $tmpRoot $Case
+    New-Item -ItemType Directory -Path $dir -Force | Out-Null
+    $env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
+    $env:AITOOLS_SUMMARY_FILE = $SummaryFile
+    $code = ". '$lib'; Initialize-Logging 't'; $Snippet"
+    $out = & pwsh -NoProfile -Command $code *>&1 | Out-String
+    $logPath = Join-Path $env:AITOOLS_LOG_DIR "deploy.log"
+    $log = if (Test-Path $logPath) { [IO.File]::ReadAllText($logPath) } else { "" }
+    $env:AITOOLS_LOG_DIR = $null
+    $env:AITOOLS_SUMMARY_FILE = $null
+    return @{ Out = $out; Log = $log; Dir = $dir }
+}
+
+try {
+    # -----------------------------------------------------------------------
+    # aitools-lib.ps1
+    # -----------------------------------------------------------------------
+    $r = Invoke-LibCase "format" 'Log "hello world"'
+    Check "lib: log line format [ts] [script] [level] message" ($r.Log -match "(?m)^$tsRe \[t\] \[info\] hello world$")
+    Check "lib: log file is AITOOLS_LOG_DIR/deploy.log" (Test-Path (Join-Path $r.Dir "logs" "deploy.log"))
+
+    $r = Invoke-LibCase "levels" 'LogOk a; LogWarn b; LogError c; Log d'
+    Check "lib: levels ok/warn/error/info recorded" (($r.Log -match '\[ok\] a') -and ($r.Log -match '\[warn\] b') -and ($r.Log -match '\[error\] c') -and ($r.Log -match '\[info\] d'))
+    Check "lib: log file has no ANSI codes" (-not ($r.Log -match "`e\["))
+    Check "lib: console shows every level" (($r.Out -match '\[warn\] b') -and ($r.Out -match '\[error\] c') -and ($r.Out -match '\[info\] d'))
+
+    $r = Invoke-LibCase "detail" 'LogDetail "secret diff line"'
+    Check "lib: LogDetail writes the log" ($r.Log -match '\[detail\] secret diff line')
+    Check "lib: LogDetail stays off the console" (-not ($r.Out -match 'secret diff line'))
+
+    $r = Invoke-LibCase "counters" 'LogError x; LogError y; LogWarn z; Write-Output "COUNTS=$($script:errors)/$($script:warnings)"'
+    Check "lib: LogError/LogWarn increment the counters" ($r.Out -match 'COUNTS=2/1')
+
+    $r = Invoke-LibCase "reset" 'LogError x; Initialize-Logging "t2"; Write-Output "COUNTS=$($script:errors)/$($script:warnings)"'
+    Check "lib: Initialize-Logging resets the counters" ($r.Out -match 'COUNTS=0/0')
+
+    $r = Invoke-LibCase "nosummary" 'Write-Summary "ERROR" "tool" "detail"; Write-Output "DONE"'
+    Check "lib: Write-Summary is a no-op without AITOOLS_SUMMARY_FILE" ($r.Out -match 'DONE')
+
+    $sum = Join-Path $tmpRoot "summary.txt"
+    $r = Invoke-LibCase "summary" 'Write-Summary "ERROR" "tool" "it failed"; Write-Summary "OK" "tool2" "v1"' $sum
+    $rows = if (Test-Path $sum) { Get-Content $sum } else { @() }
+    Check "lib: Write-Summary writes CAT|tool|detail" ($rows -contains "ERROR|tool|it failed")
+    Check "lib: Write-Summary OK stays OK with no warnings" ($rows -contains "OK|tool2|v1")
+
+    $sum2 = Join-Path $tmpRoot "summary2.txt"
+    $r = Invoke-LibCase "promote" 'LogWarn w; Write-Summary "OK" "tool" "v1"' $sum2
+    $rows = if (Test-Path $sum2) { Get-Content $sum2 } else { @() }
+    Check "lib: Write-Summary promotes OK to WARN after a warning" ($rows -contains "WARN|tool|v1")
+
+    $rotDir = Join-Path $tmpRoot "rotate" "logs"
+    New-Item -ItemType Directory -Path $rotDir -Force | Out-Null
+    [IO.File]::WriteAllText((Join-Path $rotDir "deploy.log"), ("x" * 5242880))
+    $env:AITOOLS_LOG_DIR = $rotDir
+    # Console output is irrelevant here; the check below inspects the rotated files.
+    & pwsh -NoProfile -Command ". '$lib'; Initialize-Logging 't'; Log 'after'" *>&1 | Out-Null
+    $env:AITOOLS_LOG_DIR = $null
+    $rotated = Test-Path (Join-Path $rotDir "deploy.log.1")
+    $fresh = (Test-Path (Join-Path $rotDir "deploy.log")) -and ((Get-Item (Join-Path $rotDir "deploy.log")).Length -lt 1000)
+    Check "lib: Initialize-Logging rotates a 5 MB log to deploy.log.1" ($rotated -and $fresh)
+
+    # -----------------------------------------------------------------------
+    # scripts/aitools.ps1 (entry point) -- uses the lib's logging, defines none of its own
+    # -----------------------------------------------------------------------
+    $ast = [System.Management.Automation.Language.Parser]::ParseFile($entry, [ref]$null, [ref]$null)
+    $own = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -match '^(Log|LogOk|LogWarn|LogError|LogDetail)$' }, $true))
+    Check "entry: defines no log functions (uses aitools-lib)" ($own.Count -eq 0)
+
+    if ($IsWindows) {
+        # Fake USERPROFILE with config.json -> a repo dir holding the lib.
+        function New-FakeRepo([string]$Case, [bool]$WithLib) {
+            $d = Join-Path $tmpRoot $Case
+            New-Item -ItemType Directory -Path (Join-Path $d "home" ".aitools"), (Join-Path $d "repo" ".git"), (Join-Path $d "repo" "scripts") -Force | Out-Null
+            if ($WithLib) { Copy-Item $lib (Join-Path $d "repo" "scripts") }
+            $cfg = @{ version = 2; repoPath = (Join-Path $d "repo") } | ConvertTo-Json
+            [IO.File]::WriteAllText((Join-Path $d "home" ".aitools" "config.json"), $cfg)
+            return $d
+        }
+        function Invoke-Entry([string]$Dir, [string[]]$EntryArgs) {
+            $savedProfile = $env:USERPROFILE
+            $env:USERPROFILE = Join-Path $Dir "home"
+            $env:AITOOLS_LOG_DIR = Join-Path $Dir "logs"
+            $out = & pwsh -NoProfile -File $entry @EntryArgs *>&1 | Out-String
+            $rc = $LASTEXITCODE
+            $env:USERPROFILE = $savedProfile
+            $env:AITOOLS_LOG_DIR = $null
+            $logPath = Join-Path $Dir "logs" "deploy.log"
+            $log = if (Test-Path $logPath) { [IO.File]::ReadAllText($logPath) } else { "" }
+            return @{ Out = $out; Rc = $rc; Log = $log }
+        }
+        $d = New-FakeRepo "unknown" $true
+        $r = Invoke-Entry $d @("bogus-command")
+        Check "entry: unknown command exits 1" ($r.Rc -eq 1)
+        Check "entry: unknown command logged by the lib ([aitools] [error])" ($r.Log -match "$tsRe \[aitools\] \[error\] unknown command 'bogus-command'")
+
+        $d = New-FakeRepo "nolib" $false
+        $r = Invoke-Entry $d @("bogus-command")
+        Check "entry: missing aitools-lib exits 1" ($r.Rc -eq 1)
+        Check "entry: missing aitools-lib names the path" ($r.Out -match 'aitools-lib.ps1 not found at')
+
+        $d = New-FakeRepo "version" $false
+        Remove-Item -Recurse -Force (Join-Path $d "repo")
+        $r = Invoke-Entry $d @("-Version")
+        Check "entry: -Version answers without the repo" (($r.Rc -eq 0) -and ($r.Out -match 'repo: not found'))
+    } else {
+        foreach ($n in @("entry: unknown command exits 1", "entry: unknown command logged by the lib ([aitools] [error])",
+                         "entry: missing aitools-lib exits 1", "entry: missing aitools-lib names the path",
+                         "entry: -Version answers without the repo")) {
+            Skip $n "aitools.ps1 runs on Windows only"
+        }
+    }
+} finally {
+    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
+}
+
+Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
+if ($script:fail -gt 0) { exit 1 }
+exit 0
diff --git a/.github/workflows/check.yml b/.github/workflows/check.yml
index 6c5cfd7..4612585 100644
--- a/.github/workflows/check.yml
+++ b/.github/workflows/check.yml
@@ -1,5 +1,5 @@
 # .github/workflows/check.yml
-# CI pipeline for aitools: syntax validation, build, cross-platform checks
+# CI pipeline for aitools: syntax validation, logging unit tests, build, cross-platform checks
 # 3 runners: macOS (ARM), Linux (Ubuntu), Windows
 #
 # Bash management:
@@ -113,6 +113,12 @@ jobs:
           fi
           echo "All .py files passed syntax validation"
 
+      - name: Logging unit tests (bash)
+        run: bash tests/logging/test-logging.sh
+
+      - name: Logging unit tests (PowerShell)
+        run: pwsh -NoProfile -File tests/logging/test-logging.ps1
+
       - name: Build deploy scripts
         run: |
           echo "::group::Running build-deploy.sh"
@@ -237,6 +243,12 @@ jobs:
           fi
           echo "All .py files passed syntax validation"
 
+      - name: Logging unit tests (bash)
+        run: bash tests/logging/test-logging.sh
+
+      - name: Logging unit tests (PowerShell)
+        run: pwsh -NoProfile -File tests/logging/test-logging.ps1
+
       - name: Build deploy scripts
         run: bash scripts/build-deploy.sh
 
@@ -319,6 +331,14 @@ jobs:
           }
           Write-Host "All .ps1 files passed syntax validation"
 
+      - name: Logging unit tests (bash, via Git Bash)
+        shell: bash
+        run: bash tests/logging/test-logging.sh
+
+      - name: Logging unit tests (PowerShell, native)
+        shell: pwsh
+        run: pwsh -NoProfile -File tests/logging/test-logging.ps1
+
       - name: Build deploy scripts (via Git Bash)
         shell: bash
         run: bash scripts/build-deploy.sh
```

## PR C3 — verbatim edits (batch C5)

Base: `main` @ f6fe6cb (after PR C2). Prototyped on a copy of the base (scratch:
`.scratch/session-3030c86a-9/proto-c5/`); the diff below is the exact edit. Decisions
C-F2 (exit code decides, full output logged) and C-F3 (summary row on every failure path)
apply. `setup-typst.sh` stays Homebrew-only: its Linux install path is #14 (PR B); this
batch changes only its logging and checks.

### What changes

| File | Issue / check | Change |
|---|---|---|
| `setup-rust.sh` | #22, A6 | `rustup update`: every output line logged as `[detail] rustup-update:` (was `tail -3`) |
| `setup-rust.sh` | #24, A9 | The piped `[ -n ] && log` loop is gone (a blank last output line aborted the script under `set -e`; reproduced) |
| `setup-rust.sh` | #27a, #27b, A8 | Exit code decides (was a grep for "error"/"fatal"); ERROR row names the exit code; "see log above" replaced by the log path |
| `setup-rust.sh` | #23, A4 | Homebrew rust: detected with `brew list --versions rust`; `brew uninstall rust` output logged, failure warns with the exit code (was `2>/dev/null`) |
| `setup-rust.sh` | A4 | Version probes `2>&1` instead of `2>/dev/null`; `rustup --version` keeps only its `rustup ` line |
| `setup-rust.ps1` | #22, A6 | `rustup update` output logged in full as detail (was `Select-Object -Last 3`); exit code saved before logging |
| `setup-rust.ps1` | A4 | cargo/rustc version probes `2>&1`; the vswhere and nasm probes keep `2>$null` with a comment (stderr would fake a match / break the parse; both results are checked) |
| `setup-typst.sh` | #23, A4 | cargo `typst-cli` and npm `typst` are removed only when installed (`cargo install --list`, `npm ls -g`); removal output logged; a failed removal warns with the exit code (was `>/dev/null 2>&1 \|\| true`, unconditional) |
| `setup-typst.sh` | C-F2, A4 | `brew upgrade typst`: exit code captured (was `\|\| true`); non-zero exit is an ERROR even without "error" in the output; the Standard 3 output grep stays |

**Addendum (commander, 2026-10-03, found by pre-commit during execution):** pre-commit
step 14 flagged `setup-typst.sh` because its read-only `cargo install --list` matched the
literal `cargo install` grep for source builds. Step 14 in `check-pre-commit.sh` / `.ps1`
now matches `cargo install(?! --list)` (perl / .NET lookahead, no pipe). Verified: `--list`
alone not counted; `cargo install <pkg>` still counted; across all setup scripts only
`setup-datadog.sh/.ps1` are counted (as before), and they use the prereq framework.

Generated `deploy/` (dotprofile): `setup-rust.sh`, `setup-rust.ps1` and `setup-typst.sh`
change; the build gives 40 scripts and every generated script passes `bash -n` / ParseFile.

### Error-handling audit

| Pattern | Where | Check |
|---|---|---|
| `x=$(cmd 2>&1) \|\| rc=$?` | rustup update, brew uninstall, brew upgrade, cargo/npm removal, `cargo install --list` | `rc` tested on the next statement; output logged first |
| `if x=$(probe 2>&1); then` | `brew list --versions rust`, `npm ls -g typst` | the probe's exit code is the answer (installed or not); output kept for the log |
| `2>$null` kept, with comment | `setup-rust.ps1` vswhere, nasm | stderr would corrupt the parsed value; result checked on the next line |
| `Get-Command ... -ErrorAction SilentlyContinue` | `setup-rust.ps1` nasm (2) | command-existence check with explicit fallback (exempt) |

### Tests (Linux)

| Suite | Prototype | `main` |
|---|---|---|
| `test-c5.sh` (scratch): stubbed rustup/cargo/rustc/brew/npm/typst; rustup update failure, exit 0 with "error" text, blank trailing output, failed brew uninstall, brew rust absent; typst-cli present/absent, npm removal failure, up to date, `brew upgrade` exit 1 without "error" | 17/17 | 4/17: error line lost to `tail -3`, false ERROR on "error" text, `set -e` abort on a blank line, uninstall output discarded, unconditional uninstalls, quiet `brew upgrade` failure reported OK |
| `test-c5-ps1.sh` (scratch): `setup-rust.ps1` with the OS guard stripped, stub `rustup.exe` under a fake USERPROFILE | 4/4 | 2/4 |
| `bash -n` / ParseFile; `build-deploy.sh` into a dotprofile copy | pass; 40 scripts, 3 changed, all parse | -- |

Not testable here: the MSVC / NASM / persistent-PATH parts of `setup-rust.ps1` (Windows only;
unchanged except comments). macOS run needed for the Homebrew paths.

### Logging audit (after C5)

| Check | Before C5 | After C5 | C5 files |
|---|---|---|---|
| A3 | 193 in 18 | 191 in 16 | 0 |
| A4 | 344 in 41 | 328 in 39 | 4 in `setup-rust.ps1`, all allowed (2 command-existence checks, 2 commented and checked probes) |
| A6 | 3 in 3 | 1 in 1 | 0 |
| A8 | 10 in 9 | 9 in 8 | 1 in `setup-typst.sh`: the `brew upgrade` output grep, allowed by Standard 3 (WARN-vs-ERROR still pending, C-F6) |
| A9 | 9 in 8 | 8 in 7 | 0 |

### D-C3: protected doc edits

- `reference/script-standards-detail.md` exemptions table: remove the `setup-rust.sh` (line
  32) and `setup-typst.sh` (lines 26, 31) rows; those discards are fixed. The
  `setup-typst.ps1` row stays until C6.
- This plan: status line, batch table (C5 -> PR C3), this section.

### Verbatim diff

```diff
diff --git a/scripts/setup-rust.sh b/scripts/setup-rust.sh
index 5794bb4..db3e664 100755
--- a/scripts/setup-rust.sh
+++ b/scripts/setup-rust.sh
@@ -25,25 +25,37 @@ esac
 export PATH="$HOME/.cargo/bin:$PATH"
 
 # --- Cleanup non-preferred installs ---
-# Homebrew "rust" formula is a brew-managed toolchain that conflicts with rustup
-if command -v brew &>/dev/null && brew list rust &>/dev/null 2>&1; then
-    log_warn "Found Homebrew-managed rust (conflicts with rustup). Removing..."
-    # Cleanup: brew uninstall may fail if formula not fully installed; log warning only
-    brew uninstall rust 2>/dev/null || log_warn "Failed to uninstall brew rust"
+# Homebrew "rust" formula is a brew-managed toolchain that conflicts with rustup.
+# `brew list --versions rust` exits non-zero when the formula is not installed.
+if command -v brew &>/dev/null && brew_rust=$(brew list --versions rust 2>&1); then
+    log_warn "Found Homebrew-managed rust ($brew_rust; conflicts with rustup). Removing..."
+    uninstall_rc=0
+    uninstall_out=$(brew uninstall rust 2>&1) || uninstall_rc=$?
+    while IFS= read -r line; do
+        if [ -n "${line// /}" ]; then log_detail "brew-uninstall-rust: $line"; fi
+    done <<< "$uninstall_out"
+    if [ "$uninstall_rc" -ne 0 ]; then
+        # Non-blocking: rustup installs alongside; the brew copy may shadow it on PATH.
+        log_warn "brew uninstall rust failed (exit $uninstall_rc) -- see $(display_path "$LOG_FILE")"
+    fi
 fi
 
 # --- Install/update ---
 if command -v rustup &>/dev/null; then
     log "rustup found — updating toolchain..."
-    RUSTUP_OUTPUT=$(rustup update 2>&1) || true
-    printf '%s\n' "$RUSTUP_OUTPUT" | tail -3 | while IFS= read -r line; do [ -n "${line// /}" ] && log "$line"; done
-    if printf '%s\n' "$RUSTUP_OUTPUT" | grep -qi 'error\|fatal'; then
-        log_error "rustup update reported errors (see log above)"
-        write_summary ERROR "rust/cargo" "rustup update failed"
+    # Exit code decides (C-F2); the full output goes to the log as detail.
+    update_rc=0
+    RUSTUP_OUTPUT=$(rustup update 2>&1) || update_rc=$?
+    while IFS= read -r line; do
+        if [ -n "${line// /}" ]; then log_detail "rustup-update: $line"; fi
+    done <<< "$RUSTUP_OUTPUT"
+    if [ "$update_rc" -ne 0 ]; then
+        log_error "rustup update failed (exit $update_rc) -- see $(display_path "$LOG_FILE")"
+        write_summary ERROR "rust/cargo" "rustup update failed (exit $update_rc)"
     else
-        log_ok "cargo $(cargo --version 2>/dev/null)"
-        log_ok "rustc $(rustc --version 2>/dev/null)"
-        write_summary OK "rust/cargo" "$(cargo --version 2>/dev/null)"
+        log_ok "cargo $(cargo --version 2>&1)"
+        log_ok "rustc $(rustc --version 2>&1)"
+        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
     fi
 else
     log "Installing Rust toolchain via rustup..."
@@ -57,10 +69,11 @@ else
 
     if command -v cargo &>/dev/null; then
         log_ok "Rust toolchain installed"
-        log_ok "cargo $(cargo --version 2>/dev/null)"
-        log_ok "rustc $(rustc --version 2>/dev/null)"
-        log_ok "rustup $(rustup --version 2>/dev/null | head -1)"
-        write_summary OK "rust/cargo" "$(cargo --version 2>/dev/null)"
+        log_ok "cargo $(cargo --version 2>&1)"
+        log_ok "rustc $(rustc --version 2>&1)"
+        # rustup --version prints an "info:" line on stderr; keep only the version line.
+        log_ok "$(rustup --version 2>&1 | grep -m1 '^rustup ')"
+        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
     else
         log_error "rustup install completed but 'cargo' not found in PATH"
         log_error "Expected location: ~/.cargo/bin"
diff --git a/scripts/setup-rust.ps1 b/scripts/setup-rust.ps1
index a581213..d04ea49 100644
--- a/scripts/setup-rust.ps1
+++ b/scripts/setup-rust.ps1
@@ -23,14 +23,18 @@ if (Test-Path $cargoPath) {
     Log "rustup found -- updating toolchain..."
     $rustupExe = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
     $rustupOutput = & $rustupExe update 2>&1 | Out-String
-    $rustupOutput.Trim().Split("`n") | Select-Object -Last 3 | ForEach-Object { $l = $_.TrimEnd(); if ($l.Trim()) { Log $l } }
-    if ($LASTEXITCODE -ne 0) {
-        LogError "rustup update failed (exit code $LASTEXITCODE)"
-        Write-Summary "ERROR" "rust/cargo" "rustup update failed (exit $LASTEXITCODE)"
+    $updateRc = $LASTEXITCODE
+    # Full output to the log as detail (C-F2); the exit code decides.
+    foreach ($l in $rustupOutput.Split("`n")) {
+        if ($l.Trim()) { LogDetail "rustup-update: $($l.TrimEnd())" }
+    }
+    if ($updateRc -ne 0) {
+        LogError "rustup update failed (exit $updateRc) -- see $logFile"
+        Write-Summary "ERROR" "rust/cargo" "rustup update failed (exit $updateRc)"
     } else {
-        $cargoVersion = (& $cargoPath --version 2>$null)
+        $cargoVersion = (& $cargoPath --version 2>&1)
         $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
-        $rustcVersion = (& $rustcPath --version 2>$null)
+        $rustcVersion = (& $rustcPath --version 2>&1)
         LogOk "cargo $cargoVersion"
         LogOk "rustc $rustcVersion"
         Write-Summary "OK" "rust/cargo" "$cargoVersion"
@@ -46,9 +50,9 @@ if (Test-Path $cargoPath) {
     Refresh-Path
 
     if (Test-Path $cargoPath) {
-        $cargoVersion = (& $cargoPath --version 2>$null)
+        $cargoVersion = (& $cargoPath --version 2>&1)
         $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
-        $rustcVersion = (& $rustcPath --version 2>$null)
+        $rustcVersion = (& $rustcPath --version 2>&1)
         LogOk "Rust toolchain installed"
         LogOk "cargo $cargoVersion"
         LogOk "rustc $rustcVersion"
@@ -65,6 +69,8 @@ if (Test-Path $cargoPath) {
 $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
 $hasMSVC = $false
 if (Test-Path $vsWhere) {
+    # 2>$null: vswhere prints nothing on stdout when no install matches; stderr text
+    # would make $vsInstalls non-empty and fake a match. Checked on the next line.
     $vsInstalls = & $vsWhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
     if ($vsInstalls) { $hasMSVC = $true }
 }
@@ -101,6 +107,7 @@ if (-not $nasmCheck) {
     }
 }
 if ($nasmCheck) {
+    # 2>$null: the version is parsed from stdout only; an empty result is checked below.
     $nasmVer = (nasm --version 2>$null)
     if ($nasmVer) { $nasmVer = ($nasmVer -split '\s+' | Select-Object -Index 2) }
     LogOk "NASM found ($nasmVer)"
diff --git a/scripts/setup-typst.sh b/scripts/setup-typst.sh
index 8d9b181..b1d99a6 100755
--- a/scripts/setup-typst.sh
+++ b/scripts/setup-typst.sh
@@ -20,15 +20,36 @@ case "$(uname -s)" in
 esac
 
 # --- Cleanup non-preferred installs ---
+# Only packages that are actually installed are removed; a failed removal is a
+# warning (non-blocking -- the Homebrew install below proceeds), with the output logged.
+remove_package() {  # label, command...
+    local label="$1"; shift
+    local out rc=0 line
+    out=$("$@" 2>&1) || rc=$?
+    while IFS= read -r line; do
+        if [ -n "${line// /}" ]; then log_detail "$label: $line"; fi
+    done <<< "$out"
+    if [ "$rc" -eq 0 ]; then
+        log "Removed non-preferred install ($label)"
+    else
+        log_warn "$label failed (exit $rc) -- see $(display_path "$LOG_FILE")"
+    fi
+}
 # Cargo typst-cli conflicts with Homebrew typst (different binary paths)
 if command -v cargo &>/dev/null; then
-    # Cleanup: cargo package may not be installed; non-blocking -- Homebrew install follows
-    cargo uninstall typst-cli >/dev/null 2>&1 || true
+    cargo_list_rc=0
+    cargo_list=$(cargo install --list 2>&1) || cargo_list_rc=$?
+    if [ "$cargo_list_rc" -ne 0 ]; then
+        log_detail "cargo-install-list: $cargo_list"
+        log_warn "cargo install --list failed (exit $cargo_list_rc) -- skipping cargo typst-cli cleanup"
+    elif printf '%s\n' "$cargo_list" | grep -q '^typst-cli '; then
+        remove_package "cargo uninstall typst-cli" cargo uninstall typst-cli
+    fi
 fi
-# npm typst is a third-party wrapper, not official
-if command -v npm &>/dev/null; then
-    # Cleanup: npm package may not be installed; non-blocking -- Homebrew install follows
-    npm uninstall -g typst >/dev/null 2>&1 || true
+# npm typst is a third-party wrapper, not official. `npm ls` exits non-zero when absent.
+if command -v npm &>/dev/null && npm_typst=$(npm ls -g --depth=0 typst 2>&1); then
+    log_detail "npm-ls-typst: $npm_typst"
+    remove_package "npm uninstall -g typst" npm uninstall -g typst
 fi
 
 # --- Install/update ---
@@ -36,15 +57,17 @@ if command -v typst &>/dev/null; then
     typst_path=$(command -v typst)
     if [[ "$typst_path" == /opt/homebrew/* ]] || [[ "$typst_path" == /usr/local/* ]]; then
         log "Already installed via Homebrew -- upgrading..."
-        UPGRADE_OUTPUT=$(brew upgrade typst 2>&1) || true
-        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
+        upgrade_rc=0
+        UPGRADE_OUTPUT=$(brew upgrade typst 2>&1) || upgrade_rc=$?
+        if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
             log_ok "Typst already up to date"
             write_summary OK "typst" "$(typst --version)"
         else
-            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
-            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
-                log_error "brew upgrade typst failed (see log above)"
-                write_summary ERROR "typst" "brew upgrade failed"
+            while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
+            # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
+            if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
+                log_error "brew upgrade typst failed (exit $upgrade_rc) -- see $(display_path "$LOG_FILE")"
+                write_summary ERROR "typst" "brew upgrade failed (exit $upgrade_rc)"
             else
                 log_ok "$(typst --version)"
                 write_summary OK "typst" "$(typst --version)"
diff --git a/scripts/check-pre-commit.sh b/scripts/check-pre-commit.sh
index 23890a3..730c61c 100755
--- a/scripts/check-pre-commit.sh
+++ b/scripts/check-pre-commit.sh
@@ -284,10 +284,14 @@ fi
 # ---------------------------------------------------------------------------
 PREREQ_FAIL=false
 
-# Check: any script using 'cargo install' must call Check-BuildPrereqs or check_build_prereqs
+# Check: any script using 'cargo install' must call Check-BuildPrereqs or check_build_prereqs.
+# `cargo install --list` only lists installed packages (no build) and is not counted.
+uses_cargo_install() {
+    perl -ne '$f = 1 if /cargo install(?! --list)/; END { exit($f ? 0 : 1) }' "$1"
+}
 for script in "$REPO_ROOT"/scripts/setup-*.ps1; do
     [ -f "$script" ] || continue
-    if grep -q 'cargo install' "$script" 2>/dev/null; then
+    if uses_cargo_install "$script"; then
         if ! grep -q 'Check-BuildPrereqs\|Diagnose-BuildFailure' "$script" 2>/dev/null; then
             echo "      $(basename "$script") uses 'cargo install' without build prereq framework"
             PREREQ_FAIL=true
@@ -296,7 +300,7 @@ for script in "$REPO_ROOT"/scripts/setup-*.ps1; do
 done
 for script in "$REPO_ROOT"/scripts/setup-*.sh; do
     [ -f "$script" ] || continue
-    if grep -q 'cargo install' "$script" 2>/dev/null; then
+    if uses_cargo_install "$script"; then
         if ! grep -q 'check_build_prereqs\|diagnose_build_failure' "$script" 2>/dev/null; then
             echo "      $(basename "$script") uses 'cargo install' without build prereq framework"
             PREREQ_FAIL=true
diff --git a/scripts/check-pre-commit.ps1 b/scripts/check-pre-commit.ps1
index 61ad5a3..9544bbc 100644
--- a/scripts/check-pre-commit.ps1
+++ b/scripts/check-pre-commit.ps1
@@ -276,10 +276,11 @@ if ($hasSetupUser -and -not $hasBuildDeploy) {
 # ---------------------------------------------------------------------------
 $prereqFail = $false
 
-# Check: any script using 'cargo install' must call Check-BuildPrereqs or Diagnose-BuildFailure
+# Check: any script using 'cargo install' must call Check-BuildPrereqs or Diagnose-BuildFailure.
+# `cargo install --list` only lists installed packages (no build) and is not counted.
 foreach ($script in Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.ps1" -ErrorAction SilentlyContinue) {
     $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
-    if ($content -match 'cargo install') {
+    if ($content -match 'cargo install(?! --list)') {
         if ($content -notmatch 'Check-BuildPrereqs|Diagnose-BuildFailure') {
             Write-Host "      $($script.Name) uses 'cargo install' without build prereq framework"
             $prereqFail = $true
@@ -288,7 +289,7 @@ foreach ($script in Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter
 }
 foreach ($script in Get-ChildItem (Join-Path $script:RepoRoot "scripts") -Filter "setup-*.sh" -ErrorAction SilentlyContinue) {
     $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
-    if ($content -match 'cargo install') {
+    if ($content -match 'cargo install(?! --list)') {
         if ($content -notmatch 'check_build_prereqs|diagnose_build_failure') {
             Write-Host "      $($script.Name) uses 'cargo install' without build prereq framework"
             $prereqFail = $true
```

## Risks

| Risk | Mitigation |
|---|---|
| macOS behavior change in setup-go (cleanup now after install) | Same end state when brew works; strictly safer when it fails. Exercised in macOS CI only. **Untested locally.** |
| `aitools` now exits 1 where it used to exit 0; scripted callers may depend on 0 | That is the bug (#13). Called out in the release notes. |
| PS1 edits not executed here | Windows CI parse and run; the change is small and mirrors bash. |
| pup/uv non-Homebrew path on macOS with brew present but formula failing | Covered by the WARN-and-keep branch. Not exercised; brew isn't available here. |
