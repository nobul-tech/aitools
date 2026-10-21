Closes nobul-tech/aitools#9.

## Summary

`build-deploy.sh` checked hook files against a hardcoded preflight list that had drifted from `shared/hooks/hooks-manifest.json` (`block-explore-agent.sh` was missing). It now reads the manifest, and the parity audit checks that the hardcoded list doesn't come back.

| Commit | Change |
|---|---|
| 303a7ec | Read the hook/helper preflight from `hooks-manifest.json` (`hooks[].file` + `deploy[]`, looked up in `shared/hooks/`, then `scripts/`). Remove the dead `HOOK_*` and `AITOOLS_LIB_*` variables. `check-hook-parity.py` takes an optional 4th argument, `build-deploy.sh`, and post-push step 32 (sh + ps1) passes it. |
| e3cab6e | When node is missing, warn and skip the build (exit 0), as origin/main already did, so `aitools` Step 2 doesn't stop before the installer installs node. A missing or unparseable manifest still exits 1. Both embed loops now exit 1 on a missing source instead of `continue`. |
| 4dd4af8 | Parity check: ignore full-line comments and match whole names only (`(?<![\w.-])NAME(?![\w.-])`). "Reads hooks-manifest.json" must appear outside comments. Add type hints and catch `TypeError`. |
| 3d8c455 | Fix check-post-push step 27: `paste -sd ', '` was missing its `-` operand, so BSD paste aborted the checklist before step 32. Correct the step 32 header comments (sh + ps1). |
| 946f733 | Document step 32 in `reference/post-push-checklist.md`. Fix `hooks-manifest.json` `meta.reference`, which pointed at a plan file that doesn't exist. |
| d993a0f | CI: run `check-hook-parity.py` with all four arguments in the Linux job. |

## Verification (macOS)

- Builds ran with an isolated HOME pointed at a copy of the dotprofile, never the real one. They exit 0 with `Preflight OK: 20 hook/helper file(s)`. Output is identical under bash 5 and `/bin/bash` 3.2.
- Compared with an origin/main build, `diff -r` shows a change only in the `# Hooks deployed:` header comment of `deploy/setup-user-hooks.{sh,ps1}`.
- pwsh ParseFile passes for `check-post-push.ps1` and for all 21 generated `deploy/*.ps1`.
- Parity, 4 args: `bash + ps1 + build-deploy generate hook lists from manifest (18 hooks)`. Against origin/main's `build-deploy.sh` it flags 19 hardcoded names: every hook except `block-explore-agent.sh`, which is the drift.
- Negative tests, 10/10 as expected:
  - renamed hook → exit 1
  - literal hook name in code → fail; in a comment → pass; `my-session-archive.sh` and other lookalikes → pass
  - manifest only named in a comment → fail
  - malformed manifest → clean error
  - no node → exit 0 with a warning
  - unparseable or missing manifest → exit 1
  - embed loop reached with a missing source → exit 1
- `check-post-push.sh` (extensive) now gets past step 27 and **step 32 passes**. Its remaining FAILs come from the isolated HOME (no MCP configs) and the branch not yet being on main.

Not run: the PS1 step 32 on Windows (parse-checked only), and CI (this PR is its first run).

## Follow-ups (not in this PR)

- The dotprofile `deploy/` needs a companion regeneration commit (comment-only change in `setup-user-hooks.{sh,ps1}`) for pre-push step 7.
- Release notes entry goes in the v0.74.0 release.
- Pre-existing: step 27's `paste -sd ', '` alternates delimiters (`a,b c`) when 3 or more prereqs are missing. If build-deploy fails after its `rm -rf`, the dotprofile `deploy/` stays half-built until the next good build.

(tested: macOS)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
