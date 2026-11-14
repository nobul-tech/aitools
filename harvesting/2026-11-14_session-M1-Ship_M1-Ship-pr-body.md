## Summary

- JSON field reviews name the file: `[REVIEW] registries/incidents.json: incidents differs from source.` The Created / Updated / Accept & adopt / Skipped log lines name it too.
- An array field shows which elements differ, colour-coded (red `-` only in local, green `+` only in source, yellow `~` changed), at most 20 lines, each also logged to deploy.log.
- deploy-harness overwrites its read-only copies (`~/.aitools/reference/`, `~/.aitools/registries/`) with no review menu and no adopt (backup kept): `Deploy-ManagedFile -NoReview` / `MANAGED_NO_REVIEW=true`.
- `harvesting/harvest-manifest.json` is gitignored and untracked (machine-local).
- The dotprofile now gitignores `deploy/` (nobul-jose/aitools-nobul-jose `6a98d1b`, `fecff7e`); check-pre-push step 7 and the docs follow.

## Why

The commander (session 87795dc3, 2026-11-13) could not tell which file a JSON review was about, could not see which array elements differed (a whole `incidents` array was one opaque line), and was asked to review `reference/` and `registries/` copies nobody edits. The harvest manifest and the dotprofile `deploy/` showed as uncommitted changes after every run. Commander's words: "gitignore anything in the deploy/ directory and commit/push that gittignore file to avoid these issues moving forward, also gittinore the harvest manifest in aitools repo".

## Changes

| Area | Change |
|---|---|
| `scripts/aitools-lib.ps1` / `.sh` | `Review-JsonFields -ItemName` / `review_json_fields` `$4`; `Prompt-JsonFieldReview -FileLabel -Detail` / `prompt_json_field_review` `$8 $9`; new `Write-JsonFieldDetail` / `_json_field_detail`; node review script: `arrayDetail()` 6th plan column (identical text in both libs); `Deploy-ManagedFile -NoReview` / `MANAGED_NO_REVIEW`; label in the JSON review's Created/Updated/Accept & adopt/Skipped lines |
| `scripts/deploy-harness.ps1` / `.sh` | `reference/` and `registries/` deployed as read-only copies; header "Overwrites" updated. The two `build-deploy.sh` `replace_once` anchors are unchanged (each still occurs once) |
| `scripts/check-pre-push.ps1` / `.sh` | Step 7: when the dotprofile has no committed `deploy/`, skip the staleness compare (PASS detail `fresh build OK (dotprofile deploy/ untracked, not compared)`); the build and the dry runs still run. Without this, the dotprofile change broke step 7 for everyone: FAIL (`diff exit 2`, .sh) or a throw (`Cannot find path ...\committed\deploy`, .ps1). PS1 step 7 also extracts with Windows' `System32\tar.exe`: from a Git Bash parent, GNU tar read `C:\...` as a remote host |
| `tests/check-pre-push/test-pre-push-step7.sh` (new) + `.github/workflows/check.yml` | Runs check-pre-push (`.ps1` on Windows, `.sh` elsewhere) from a clone one commit ahead of a fake `origin/main`, temp HOME, fixture dotprofiles: untracked `deploy/` -> PASS, comparison skipped, fixture left clean; stale committed `deploy/` -> FAIL "stale". CI step added to the macOS, Linux and Windows jobs |
| `scripts/build-deploy.sh` | Comments only: deploy/ is gitignored build output |
| `.gitignore`, `harvesting/harvest-manifest.json` | manifest ignored and removed from the index (file stays on disk) |
| Tests | see Verification |
| Docs | rule, reference, skill, README updates listed under Review after |

## Verification

Windows 11 Pro, pwsh 7.6, Git Bash, run from the worktree.

**Every tracked `tests/**/test-*` suite: 33 suites, all exit 0, 0 failed** (plus the new `check-pre-push/test-pre-push-step7.sh`: 3 passed, 0 failed, run from Git Bash).

| Suite | Result |
|---|---|
| managed-files/test-managed-files.sh | 36 passed, 0 failed, 3 skipped (was 17 passed) |
| managed-files/test-managed-files.ps1 | 21 passed, 0 failed, 1 skipped (was 14 passed) |
| managed-files/test-adopt-push.sh / .ps1 | 18 / 14 passed, 1 / 1 skipped |
| deploy-harness/test-deploy-harness.sh | 89 passed, 3 skipped |
| deploy-harness-mdm/test-deploy-harness-mdm.sh | 54 passed, 1 skipped |
| build-deploy/test-build-deploy-backup.sh | 24 passed |
| b8-consumers, build-package/test-cli, claude-mdm | 31 / 36 / 32 passed (claude-mdm 2 skipped) |
| fanout-lib, rules-fanout, rules-fanout-cursor, skills-fanout, skills-legacy | 90 / 57 / 142 / 102 / 30 passed (20 / 4 / 7 / 8 / 2 skipped) |
| hookin, hooks (delegation-duty-guard, glossary-skill-guard, hooks-smoke, sessionstart-harness-db, sh-file-fixup, workflow-delegation-guard) | 25 / 44 / 12 / 44 / 50 / 41 / 74 passed |
| logging .sh / .ps1, os-guards, setup-user-shell.ps1 | 24 / 20 / 33 / 10 passed |
| profile (config, install, lib, profile, user-init) | 247 / 19 / 201 / 716 / 136 passed |
| harness-db/test-delegation-score.py, harvest/test-ait-harvest.py | OK / OK |

New tests in this PR (managed-files, both twins where both apply):
- node review script: identical text in `aitools-lib.sh` and `aitools-lib.ps1` (runs on every platform; no pty needed)
- `arrayDetail` edge cases: scalars, duplicate elements, mixed types (`1` vs `"1"`, `null`, objects without identity), empty SOURCE / LOCAL array, nested arrays, same identity with a changed and an absent key, key order inside an element (no difference), reorder only, >20 lines truncated with a count, tab and U+001F inside a value stay escaped (6 plan columns), scalar / non-array / source-only fields have no detail
- item label in the Created / Divergence / Updated log lines (non-interactive) and in every review header including the LOCAL-only field, plus Accept & adopt / Skipped log lines (pty)
- `-NoReview` / `MANAGED_NO_REVIEW`: new JSON file created; dry run writes nothing
- `Write-JsonFieldDetail`: plain (TERM=dumb) and colour output, every element line logged

Other checks:
- `bash -n` / pwsh parser on every touched script: OK
- `build-deploy.sh` under an isolated HOME into a clone of the dotprofile: exit 0, 0 errors; 24 generated `.sh` pass `bash -n`, 25 `.ps1` parse; both deploy-harness anchors present once; the clone's `git status` stays clean (deploy/ ignored). WARNs: the known Intune size warnings and "uncommitted changes" in the harness snapshot (the build ran before the commit)
- `check-pre-commit.ps1`: 10 PASS, 4 SKIP, 4 WARN, 1 FAIL -- step 20 dead path refs, pre-existing and not in files this PR touches: `CLAUDE.md:100 .claude/rules/relay-outbound.md`, `reference/tool-registry.md:341` and `shared/claude-shared.md:95 .claude/settings.local.json`
- `check-pre-push.ps1`: 7 PASS, 3 WARN, 0 FAIL; step 7 PASS `fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean` against the real dotprofile (read-only `git archive` copy)
- `check-post-push.ps1`: 25 PASS, 3 SKIP, 4 WARN, 1 FAIL (step 1 `HEAD != origin/main`: expected before merge)
- Interactive array display verified earlier on a real Windows console (ConPTY harness)

## Not run

- pty (interactive) test cases on Windows: pywinpty is not installed on this machine (SKIPs above); CI on Linux/macOS runs them, including the new `json-label-pty` cases
- macOS and Linux suites (CI)
- `check-pre-commit.sh` / `check-pre-push.sh` / `check-post-push.sh`: their OS guard refuses Git Bash; the `.ps1` twins ran. The `check-pre-push.sh` step-7 change is covered by `bash -n` here and by the new suite on macOS/Linux CI

## Review after

Every document and rule change, old -> new (D-DEL5):

1. `.claude/rules/agentic-standards.md` "Managed-file review choices and merge" -- new bullet (approved by the commander 2026-11-13, "4) approved."): "LOCAL differs, read-only copy (deploy-harness `reference/`, `registries/`; `MANAGED_NO_REVIEW=true` / `-NoReview`): SOURCE written to LOCAL, no menu, no adopt, in every run."
2. `.claude/rules/aitools-workspace.md` workspace table, `harvesting/` row: Tracked `tracked` -> `tracked, except the manifest`; Purpose "...manifest `harvest-manifest.json` (`ait-harvest.py`)" -> "...manifest `harvest-manifest.json` (`ait-harvest.py`) is gitignored, machine-local (commander, 2026-11-13)".
3. `.claude/rules/deploy-paths.md` MDM path: added "The dotprofile gitignores `deploy/` (commander, 2026-11-13): it is machine-local build output, not committed, so an endpoint gets it from a build, not from a pull."
4. `.cursor/rules/deploy-paths.mdc` MDM path: "...into the user's dotprofile repo." -> "...into the user's dotprofile repo, which gitignores it (machine-local build output, commander 2026-11-13)."
5. `.gitignore`: added `harvesting/harvest-manifest.json` with a comment.
6. `shared/skills/harvest/SKILL.md` "Where the files live": added "In aitools the manifest is gitignored: each machine keeps its own (commander, 2026-11-13)."; step 4 "Commit the artifact + manifest update" -> "Commit the artifact (and the manifest update, in a repo that tracks the manifest; aitools does not)".
7. `reference/artifact-harvesting.md` directory table: `harvesting/` `tracked` / "harvested artifacts plus the harvest manifest" -> `tracked, except the manifest` / "...In aitools the manifest (`harvest-manifest.json`) is gitignored and machine-local (commander, 2026-11-13)..."; section 6 "until someone commits them (`/harvest` skill, "Commit the artifact + manifest update")" -> "until someone commits the files (`/harvest` skill, "Commit the artifact"; in aitools the manifest is gitignored, so only the harvested files are committed)".
8. `reference/managed-file-deployment.md`: new paragraph "Read-only copies".
9. `reference/harness.md`: `reference/` and `registries/` are read-only copies (overwritten, backup kept, no menu, no adopt).
10. `reference/pre-push-checklist.md` step 7: compare only "when the dotprofile tracks `deploy/`"; a dotprofile that gitignores it skips the compare.
11. `reference/user-repo.md`: tree comment "shared by all this user's machines" -> "gitignored, machine-local (commander, 2026-11-13)"; "So one committed deploy/ is correct for every machine." -> "So one deploy/, built on any machine, is correct for every machine. (The dotprofile gitignores `deploy/` since 2026-11-13...)".
12. `README.md`: "then commit the regenerated deploy/ in your dotprofile repo" -> "the dotprofile deploy/ is build output: gitignored, not committed" (both platform blocks).
13. `scripts/build-deploy.sh` comments: "The result is committed to git" -> machine-local build output; "deploy/ is committed once" -> "may be built on one machine ... no longer committed"; "committed deploy/ in place" -> "previous deploy/ in place".
14. Code: `scripts/deploy-harness.*` header "Overwrites: no" -> "Overwrites: reference/ and registries/ only -- read-only copies".
15. Code: `scripts/check-pre-push.*` step 7 -- compare `deploy/` only when the dotprofile commits it; PASS detail "dotprofile deploy/ matches a fresh build" -> "fresh build OK (dotprofile deploy/ untracked, not compared)" in that case; PS1 `tar` -> `$env:SystemRoot\System32\tar.exe` (fallback `tar`).
16. `.github/workflows/check.yml`: new step "check-pre-push step 7 tests" in the macos, linux and windows jobs.

## Follow-ups

1. **Every aitools checkout, once, before pulling this merge:** `harvesting/harvest-manifest.json` is deleted upstream. A checkout where it is modified (this machine's main checkout shows ` M harvesting/harvest-manifest.json`) fails `git pull --ff-only` (local changes would be overwritten); a clean one has the file deleted from disk by the pull. To keep the local manifest: copy it aside, `git checkout -- harvesting/harvest-manifest.json`, pull, copy it back (it is now ignored). Without that, the harvester starts an empty manifest (entries lost, harvested files kept).
2. **Every other machine's dotprofile, once:** pulling `fecff7e` deletes `deploy/` from disk (tracked -> untracked); a dirty `deploy/` blocks the pull: `git checkout -- deploy` first. The next `aitools` run rebuilds it.
3. **MDM:** an endpoint that pulled `deploy/` from the dotprofile repo no longer gets it from git. It needs a build (`build-deploy.sh`) or another delivery path (the package path, `plans/build-package/`).
4. `check-post-push.ps1` run from a native PowerShell parent calls bare `bash`, which resolved to the WSL shim (no distribution) and failed steps 2 and 6 on every `.sh`; run from Git Bash it passes. Pre-existing, not changed here (the cross-platform rule says Git Bash, not WSL, is the managed bash).
5. RELEASE_NOTES.md not updated (pre-commit/pre-push step 5 WARN).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
