## Observation

`shared/hooks/hooks-manifest.json` declares itself the single source of truth for hook registration, and names `build-deploy.sh (required-file check + embed list)` as a consumer. The embed list is manifest-driven, but the **required-file preflight check is a hardcoded list** (`scripts/build-deploy.sh:66`) — and it has already drifted:

- `block-explore-agent.sh` is registered in the manifest (PreToolUse, matcher `Agent`) but **missing from the preflight list**.
- If that file went missing, preflight would pass and the embed loop's `blog_error "Hook source not found for embed"` path does `continue`, not `exit` — the build would complete with the hook silently absent from the deploy artifact.

Two more hardcoded hook lists exist in the same file:

- `scripts/build-deploy.sh:88-106` — `HOOK_*=$(cat …)` variables for all 18+1 hook files. **Dead code**: assigned, never referenced (embed loops read files directly from the manifest). A third copy of the hook list to keep in sync.
- `scripts/build-deploy.sh:72-77` — a separate hardcoded existence check for `ait-harvest.py`, which the manifest already lists under `deploy`.

(Also dead, non-hook: `AITOOLS_LIB_BASH`/`AITOOLS_LIB_PS1` at lines 109-110 — `inline_lib_bash`/`inline_lib_ps1` read the lib files directly.)

## Expected

`shared/hooks/hooks-manifest.json` `meta.purpose`: "Single source of truth for Claude Code hook registration. Consumed by … build-deploy.sh (required-file check + embed list) …". The required-file check should be **derived** from the manifest, not hand-maintained. This is the same drift class that `scripts/check-hook-parity.py` was written to prevent for the setup-user-hooks pair (RCA 2026-06-20) — but that audit does not cover build-deploy.sh, which is why this went undetected.

## Impact

Adding a hook to the manifest without also editing the hardcoded preflight list means the new hook is never preflight-verified; a missing/renamed hook file produces a non-fatal error and a deploy artifact with the hook unregistered — silent wrong behavior on every MDM/endpoint deploy from the dotprofile repo.

## Fix

1. **build-deploy.sh**: replace the hardcoded preflight loop (line 66) and the separate `ait-harvest.py` check with a single loop over `hooks[].file` + `deploy[]` from the manifest, resolving each file against `shared/hooks/` then `scripts/` (same resolution as the embed loops). Fail the build (`exit 1`) on any missing file. Add an explicit `node` requirement with a clear error — the embed loops already hard-depend on node, but today a missing node yields empty process substitutions and a broken artifact instead of an error.
2. **Remove dead code**: `HOOK_*` variables (88-106) and `AITOOLS_LIB_*` (109-110).
3. **Detection layer**: extend `scripts/check-hook-parity.py` (and its check-post-push step 32 call sites, bash + ps1) to also verify build-deploy.sh reads the manifest and contains no resurfaced hardcoded hook-file list.

## Discovery context

Found 2026-07-06 while loading `build-deploy.sh` and `hooks-manifest.json` into session context (session ba4c0c12-7); confirmed by grep sweep of `scripts/` + `shared/` for hook filename references. `setup-user-hooks.sh`/`.ps1` verified clean (fully manifest-driven).
