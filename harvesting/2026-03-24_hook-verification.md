# Hook Verification Report

**Date**: 2026-03-23
**Verifier**: Claude Opus 4.6 (agent)
**Files under review**:
- `shared/hooks/harvest-session.sh` (278 lines)
- `shared/hooks/scratch-init.sh` (87 lines)

**Issues addressed**: #53 (handoff lifecycle), #54 (harvest silent skip)

---

## Issue #54 Fixes

### F1: Warn (stderr) when non-ephemeral files exist but no harvesting/ dir

**PASS** — Lines 129-145 of `harvest-session.sh`. When `HAS_HARVESTING` is false and a non-ephemeral file is encountered, the script auto-creates `harvesting/` and emits a `printf ... >&2` warning at line 144.

However, **NEEDS AMENDMENT**: The original requirement says "MUST warn when non-ephemeral files exist but no harvesting/ dir." The current implementation does not merely warn -- it auto-creates the dir (which is F2). There is no separate warning-only path for when creation might fail. The combined behavior satisfies the spirit of F1 + F2 together, but note that if `mkdir -p` fails silently (e.g., read-only filesystem), the `HAS_HARVESTING=true` at line 131 would be set despite no directory existing, and the subsequent `cp` at line 166 would fail. The `mkdir -p` at line 131 does not have error checking.

**Severity**: Low. In practice, hook environments have write access to the repo. But strictly, `mkdir -p` success should be verified before setting `HAS_HARVESTING=true`.

### F2: Auto-create harvesting/ + harvest-manifest.json on first harvest

**PASS** — Lines 129-145 of `harvest-session.sh`.
- `mkdir -p "$HARVESTING_DIR"` at line 131 creates the directory.
- Lines 134-142 create `harvest-manifest.json` via `node -e` with proper schema (`schemaVersion: '1.0'`, `lastAudit: null`, `artifacts: {}`).
- The `node -e` script correctly checks `!fs.existsSync(f)` before writing (line 139), preventing overwrites.
- Falls back gracefully: `2>/dev/null || true` on the node invocation (line 142), and `command -v node` guard at line 134.

### F4: Report harvest results (count of harvested + skipped)

**PASS** — Lines 213-217 of `harvest-session.sh`. Reports via stderr:
```
[harvest] Session XXXX: N artifacts harvested, M ephemeral skipped
```
Correctly uses `printf` (not `echo`) and `>&2`. Only prints when there is at least one harvested or deleted item (line 214 condition).

---

## Issue #53 Requirements

### R1: Harvested filenames MUST include session ID (pattern: YYYY-MM-DD_session-XXXX_filename)

**PASS** — Lines 149-153 of `harvest-session.sh`. When `SESSION_PREFIX` is non-empty, the filename becomes `${TODAY}_session-${SESSION_PREFIX}_${filename}`. Pattern matches the requirement: `YYYY-MM-DD_session-XXXX_filename`.

When `SESSION_PREFIX` is empty (defensive fallback), the filename degrades to `${TODAY}_${filename}` (no session tag). This is acceptable defensive behavior.

### R2: Handoff files (name starts with "handoff") MUST be routed to .aitools/channel/handoffs/

**PASS** — Lines 116-127 of `harvest-session.sh`.
- Pattern match: `case "$filename" in handoff*) is_handoff=true ;;` (line 118) -- only filenames starting with "handoff".
- Destination: `$HANDOFFS_DIR` = `$PROJECT_ROOT/.aitools/channel/handoffs` (line 65).
- Filename includes session ID: `${TODAY}_session-${SESSION_PREFIX}_${filename}` (line 123).
- After copying to handoffs dir, increments `HARVESTED` and `continue`s (skips the harvesting/ path).

**NEEDS AMENDMENT**: Line 121 checks `[ -d "$HANDOFFS_DIR" ]` but does NOT auto-create the directory if it does not exist. If `.aitools/channel/handoffs/` has not been created yet (e.g., first session on a fresh clone), handoff files will fall through to the regular harvesting path instead of being routed to handoffs. Compare with how `harvesting/` is auto-created at line 131.

**Severity**: Medium. The handoff routing silently degrades to harvesting/ instead of its dedicated location. Either auto-create `$HANDOFFS_DIR` or warn on stderr that handoffs cannot be routed.

### R3: SessionStart hook MUST discover handoffs at .aitools/channel/handoffs/ and announce them

**PASS** — Lines 69-83 of `scratch-init.sh`.
- Checks `[ -d "$HANDOFFS_DIR" ]` at line 71.
- Iterates `.md` files in the directory (line 74).
- Announces via stdout (which CC injects as session context): `Handoff available: <filename> (N total in <path>)` (line 80-81).

**NEEDS AMENDMENT (minor)**: The handoff discovery only looks for `*.md` files (line 74: `for hf in "$HANDOFFS_DIR"/*.md`). But `harvest-session.sh` routes any file named `handoff*` regardless of extension -- a `handoff-briefing.json` would be routed to handoffs/ but never discovered/announced by `scratch-init.sh`. The glob should match all files, not just `.md`.

**Severity**: Medium. JSON handoff files (e.g., `handoff-briefing.json`) would be silently missed.

---

## Technical Criteria

### 1. Bash syntax valid

**PASS** — Both files pass `bash -n` with exit code 0. No unclosed quotes, missing `fi`/`done`/`esac`, or other syntax errors.

### 2. set -euo pipefail present

**PASS** — `harvest-session.sh` line 13, `scratch-init.sh` line 13. Both have `set -euo pipefail`.

### 3. No stat -f || stat -c fallback chain

**PASS** — Neither file uses `stat` at all. No fallback chain pattern present.

### 4. No grep -P (BSD portability)

**PASS** — Neither file uses `grep -P`. Both use `grep -o` with POSIX bracket expressions (`[[:space:]]`), which is portable across BSD and GNU grep.

### 5. json_field() function present and correct for stdin parsing

**PASS** — Both files define `json_field()` (harvest-session.sh lines 19-28, scratch-init.sh lines 16-25). The function:
- Takes two args: json string and key name
- Uses `printf '%s'` (not echo) to pipe JSON to grep
- Uses `grep -o` with a pattern that matches `"key" : "value"` including optional whitespace
- Uses `head -1` to take only the first match
- Uses two `sed` commands to strip the key prefix and trailing quote
- Returns value via `printf '%s'` (no trailing newline)

**Note**: The function only handles string values (quoted). It will not extract numeric, boolean, or null values. For the hook's purposes (extracting `session_id` and `cwd`), string extraction is sufficient.

### 6. Session ID extraction from hook input JSON works correctly

**PASS** — Both files read stdin via `INPUT=$(cat)` then call `json_field "$INPUT" "session_id"`. The `SESSION_PREFIX` is extracted as the first 10 characters via `cut -c1-10` (harvest-session.sh line 36, scratch-init.sh line 59). This matches the scratch dir naming pattern `session-XXXXXXXXXX`.

### 7. Session dir lookup: tries session_id-based path first, falls back to .current-session

**PASS** — `harvest-session.sh` lines 44-50:
1. First tries `$SCRATCH_DIR/session-$SESSION_PREFIX` if prefix is non-empty and dir exists (line 46)
2. Falls back to reading `$SCRATCH_DIR/.current-session` (line 48-49)
3. Graceful exit if neither works (lines 52-55)

`scratch-init.sh` creates the session dir (lines 57-64) and writes `.current-session` (line 67), maintaining backward compatibility.

### 8. Auto-create harvesting/ only when there are actual non-ephemeral files to harvest

**PASS** — The auto-create block (lines 129-145) is inside the `for file` loop and only reached when `is_ephemeral` is false (past the `continue` at line 111) and after the handoff routing check. So `harvesting/` is only created when there is a concrete non-ephemeral, non-handoff file to harvest.

### 9. Handoff routing: only files named handoff* go to handoffs dir

**PASS** — Line 117-119: `case "$filename" in handoff*) is_handoff=true ;;`. Only filenames starting with the literal string "handoff" trigger the handoff route. All other non-ephemeral files go to `harvesting/`.

### 10. No rm -rf of session dirs

**PASS** — No `rm -rf` in executable code in either file. Both files have comments explicitly explaining why `rm -rf` was removed (harvest-session.sh lines 220-223, scratch-init.sh lines 44-45), referencing the 30-file loss incident. Only `rm -f "$SCRATCH_DIR/.current-session"` at line 224 (single file removal) is present.

### 11. All stderr output uses printf (not echo)

**PASS** — All stderr output in both files uses `printf`:
- `harvest-session.sh` line 144: `printf '[harvest] Created harvesting/...' >&2`
- `harvest-session.sh` lines 215-216: `printf '[harvest] Session %s: ...' >&2`
- `scratch-init.sh` line 49: `printf 'Stale scratch dirs: ...'` (stdout, not stderr -- this is session context, intentionally stdout)
- `scratch-init.sh` lines 80-81: `printf 'Handoff available: ...'` (stdout -- session context)
- `scratch-init.sh` line 86: `printf 'Session scratch directory: ...'` (stdout -- session context)

No `echo` used for any output.

### 12. Manifest update node script handles missing manifest file gracefully

**PASS** — Two node scripts handle the manifest:
- **Creation** (lines 136-142): Checks `!fs.existsSync(f)` before writing. Wrapped in `2>/dev/null || true`.
- **Update** (lines 178-206): Line 187: `try { manifest = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}` — if manifest doesn't exist or is invalid JSON, catches the error and starts with a fresh default manifest object (line 186). Wrapped in `2>/dev/null || true`.
- **Audit** (lines 230-273): Line 237: `try { manifest = JSON.parse(fs.readFileSync(f, 'utf8')); } catch { process.exit(0); }` — if manifest is missing/invalid, exits cleanly. Guard at line 229: `[ -f "$MANIFEST" ]`.

---

## Summary

| # | Criterion | Result |
|---|-----------|--------|
| F1 | Warn on no harvesting/ | PASS |
| F2 | Auto-create harvesting/ + manifest | PASS |
| F4 | Report harvest results | PASS |
| R1 | Session ID in filenames | PASS |
| R2 | Handoff routing to handoffs/ | PASS (see amendment) |
| R3 | Discover handoffs on SessionStart | PASS (see amendment) |
| T1 | Bash syntax valid | PASS |
| T2 | set -euo pipefail | PASS |
| T3 | No stat fallback chain | PASS |
| T4 | No grep -P | PASS |
| T5 | json_field() correct | PASS |
| T6 | Session ID extraction | PASS |
| T7 | Session dir lookup w/ fallback | PASS |
| T8 | Auto-create only on real files | PASS |
| T9 | Handoff routing correctness | PASS |
| T10 | No rm -rf of session dirs | PASS |
| T11 | printf for stderr | PASS |
| T12 | Manifest handles missing file | PASS |

### Amendments Needed

1. **MEDIUM — Handoffs dir not auto-created** (`harvest-session.sh` line 121): When `.aitools/channel/handoffs/` does not exist, handoff files silently fall through to `harvesting/` instead of their dedicated location. Add `mkdir -p "$HANDOFFS_DIR"` before the routing check, or at minimum warn on stderr.

2. **MEDIUM — Handoff discovery glob too narrow** (`scratch-init.sh` line 74): Only `*.md` files are discovered, but harvest routes any `handoff*` file regardless of extension. Change glob from `"$HANDOFFS_DIR"/*.md` to `"$HANDOFFS_DIR"/handoff*` or `"$HANDOFFS_DIR"/*` to match all routed handoff files.

3. **LOW — mkdir -p success not verified** (`harvest-session.sh` line 131): `HAS_HARVESTING=true` is set unconditionally after `mkdir -p`, even if it fails. On a read-only filesystem, subsequent `cp` would fail. Consider: `mkdir -p "$HARVESTING_DIR" && HAS_HARVESTING=true`.
