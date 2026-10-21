# S5-Tools report: governed tool-support framework (mission M2)

**Intent**: **Purpose**: Hand Session Commander 360aa8f3-8 the review-ready
draft batch for the tool support framework, the gap table for every setup
script, and the findings, so the commander can approve the batch in one round.
**Scope**: Summary, decision tree, draft file inventory, open questions with
recommendations, gap table and migration batching, INCIDENT findings,
adversarial review disposition. NOT the drafts' content (in `S5-Tools-drafts/`).
NOT node specifics (M4) or the profile schema (M3). **Audience**: Session
Commander 360aa8f3-8, then Jose.

## Summary

1. One decision tree (T0-T7 + replace guard RP, 16 leaves plus 2 removal notes, each with log line, summary row, ACTION, exit code; dry run as an overlay) defines "a supported tool"; it lives in a new protected reference `reference/tool-support-decision-tree.md` (also the single authority for schema 1.1 field rules, helper contract, removal guards, M3 exception contract, conformance check, test matrix). The rewritten `tool-lifecycle.md` (121 lines, was 134) carries six directives, the update policy, and the `/tool-adopt` trigger.
2. New project skill `/tool-adopt` (after `/tool-eval`, invokes it when no preferred method exists, owns the single onboarding checklist, maintains registry + rule); `/tool-eval` and `/tool-registry` edited; glossary adds "tool adoption", "tool exception", "update channel".
3. Registry schema 1.1: `updateChannel`; typed `kind`/`package`/`family`/`environments`/`detection`/`removal`/`versionedPath` per method; `nonPreferredMethods` folded into `install[]`; `knownPaths` gains a verified shape; enums tightened. Scripts read it via generated specs in `generated/tool-specs/` (MDM self-containment; no JSON parser on minimal Linux; no evaluation of registry text).
4. No setup script conforms: 7 remove a tool before its replacement is verified (F1), setup-datadog.sh deletes unknown-source binaries, tool scripts ignore dry run, shadow checks are WARN or absent, and node / claude-code / cursor-agent / pwsh have no setup script. Verified on this Mac: preferred `node@22` is installed, keg-only, off PATH; `node` resolves to Homebrew `node` 26.3.1.
5. 26 INCIDENT findings (4 high), 12 open questions with recommended answers. An adversarial reviewer (S5-Tools-A) raised 55 findings including 4 blockers; all 4 blockers and most majors are fixed in revision 2 (section 7).

## 1. Decision tree

Authoritative copy: `S5-Tools-drafts/reference/tool-support-decision-tree.md`
sections 2-3 (mermaid diagram, node rules, leaf table). Condensed:

| Node | Test | Outcome |
|------|------|---------|
| T0 | Status for platform+environment (non-local environment status overrides platform status) | `n/a` → **NA** (OK `n/a (<env or platform>)`); `evaluating` → **EVALUATING** (WARN + ACTION, proposed D-TS12) |
| T1 | One preferred method for platform + environment (+ Linux family); most specific match wins | none or tie → **NO-METHOD** (ERROR + ACTION `run /tool-eval <slug> -- no <platform> method`) |
| T2 | `tool_detect_method`: resolve command; typed probes, preferred first, then package-database probes, then path-only | none / preferred / non-preferred / unknown |
| T3 (none) | Preferred copy at a verified known path but off PATH? installable kind, manager + build prereqs present? | off PATH → T7; else **PREREQ** (ERROR + ACTION) or install, verify by binary → T7 / **INSTALL-FAIL** |
| T4 (preferred) | Update per `updateChannel` | → T7 (a failed update only warns; T7's row is promoted to WARN, or reports the broken state) |
| T5 (non-preferred / unknown) | Matching tool exception (same method and path)? | yes → **EXCEPTION** (info log "known exception", OK row, no prompt) |
| T6 | Interactive (tty, not `AITOOLS_FORCE`, not dry run)? | no → **HOLD** (WARN log + WARN row + ACTION, nothing changed) |
| Menu | non-preferred: `[r]eplace / [k]eep / [x]abort`; unknown: `[i]nstall alongside / [k]eep / [x]abort` | EOF/other → HOLD; k → **KEEP** (exception written); x → **ABORT** (exit 2, installer stops) |
| Replace | install/update preferred FIRST → verify binary → **RP**: preferred dir on PATH and a different file → guarded removal recipe | fail → **REPLACE-FAIL**; RP fails → **REPLACE-BLOCKED** (both: old copy untouched); no recipe / refused or failed removal → note + ACTION, then T7 |
| Unknown | `[i]nstall alongside`; never removed | → T7 (SHADOWED names the unknown path in ACTION) |
| T7 | Resolves to the preferred binary (tool-ops `resolution` when it exists); Windows persistent PATH; version probe prints a version ≥ minVersion, not blocked | **OK** / **SHADOWED** / **NOT-ON-PATH** / **VERSION-UNKNOWN** / **BELOW-MIN** (non-OK are ERROR + ACTION) |
| Kept / held | EXCEPTION, KEEP, HOLD still run the version half of T7 | below min / blocked → **BELOW-MIN** |
| overlay | `AITOOLS_DRY_RUN=1` | read-only nodes run, acting nodes log `[DRY RUN] would …`, the leaf it would reach is reported with `dry-run:` detail |

Update channels: `latest-stable` (default), `lts`, `pinned-major`, `pinned-minor` (`pin` + `reason`), `vendor-auto`. Every run moves a preferred install to its channel's latest and verifies it (D-TS5).

Key design choices (each traceable in the reference):
- **Typed probes and builders, no shell executed from the registry** — detection, install, update, removal are built by the library from typed fields (`update` strings become display-only); the generator shell-quotes values.
- **Generated tool specs** (`generated/tool-specs/<slug>.sh/.ps1`) instead of runtime JSON parsing — reasons in reference 7.1; the exception store may use a parser because it can degrade to "no exception". See Q1.
- **RP guard** (added after verifying node on this Mac): replace never removes the only copy that resolves.
- **Removal guards** (reference 7.3): `path:` removal refused for empty tokens, root/home/prefix dirs, symlinks, dirs not containing the binary or not named for the tool.
- **Exception match** by platform + method + PATH-resolved path (not realpath; case-insensitive on macOS/Windows), method-only for `versionedPath` methods; fallback profiles are never written.
- **"Install class"** instead of "provenance" (a governed term for an aitools component).
- **Exit 2 = abort** for the tool menu, with an installer contract to stop the run — which also fixes the managed-file abort (INCIDENT I-02).

## 2. Draft files

All under `/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Tools/S5-Tools-drafts/`. Every one targets a protected file (rules, references, skills under the proposed table row, registries, intent statements).

| Draft (mirrors repo path) | Protected? | New / edit | Intent status | Diff |
|---|---|---|---|---|
| `reference/tool-support-decision-tree.md` | yes (proposed new row) | new | new intent, DRAFT | -- |
| `.claude/rules/tool-lifecycle.md` | yes | edit (rewrite; onboarding checklist, rebuild steps, and "Dotprofile priority" moved into `/tool-adopt` step 5; nothing dropped) | modified intent, DRAFT | `.diff` |
| `reference/framework-tool-lifecycle.md` | yes | edit (desired-state section, artifacts) | modified intent, DRAFT | `.diff` |
| `.claude/skills/tool-adopt/SKILL.md` | yes (proposed skills row) | new | new intent, DRAFT | -- |
| `.claude/skills/tool-eval/SKILL.md` | yes (intent) | edit (load list, recommend step 7, hand-off, maintain rule) | modified intent, DRAFT | `.diff` |
| `.claude/skills/tool-registry/SKILL.md` | yes (intent) | edit (schema 1.1 rows, required fields, validation step) | modified intent, DRAFT | `.diff` |
| `.claude/rules/interactive-menus.md` | yes | edit (tool menu section; "managed-file menu functions") | **new** intent (file had none), DRAFT | `.diff` |
| `.claude/rules/sources-of-truth.md` | yes | edit (registry row; rows for the reference and the three tool skills; generated-file note) | **new** intent (file had none), DRAFT | `.diff` |
| `.claude/rules/glossary.md` | yes | edit (3 term lines) | unchanged | `.diff` |
| `registries/glossary.terms-draft.json` | yes (`registries/glossary.json`) | 3 terms added, `managed tool` modified | n/a (JSON entries) | -- |
| `registries/tool-registry.schema-1.1-draft.json` | yes (`registries/tool-registry.json`) | schema 1.1 + node (illustrative, M4; includes a linux status change for M4/commander) + go entries | modified `meta.intent`, DRAFT | -- |
| `registries/framework-registry.tool-lifecycle-entry-draft.json` | yes | edit (stale entry: concepts, artifacts; write only once paths exist) | n/a | -- |

Lib-helper spec, removal guards, menu text, installer/entry-point contract, pre-commit conformance check, planned detection hook, profile `toolExceptions` contract for M3, and test matrix are sections 7-10 of the reference draft (single authoritative location).

**Companion edits required in the same batch, not drafted** (protected; small; listed so nothing drifts):
- `.cursor/rules/tool-lifecycle.mdc` and `interactive-menus.mdc` — mirror the `.md` changes (mirrors already drift, I-23).
- `.claude/rules/git-safety.md` — name `generated/` as a fully generated, tracked directory (regenerated, never edited), like `deploy/` (review A-08).
- `reference/script-standards-detail.md` — severity guide line for SHADOWED (D-TS11/Q10); governed outcome `n/a (<platform>)` and helper `write_platform_skip` (Q12); summary rows `<ver> (kept)`, `under evaluation`.
- `shared/skills/aitool-eval/SKILL.md` — refresh the derived reference card from the new `/tool-eval` (review B-04).
- `.claude/rules/managed-file-deployment.md` — fix the cross-reference to the missing "Deployment pattern updates" section (I-14).

Contract for M3 in one paragraph (reference section 8): `profiles.<alias>.toolExceptions.<slug> = {decision:"keep", method, path, platform, environment, decided (UTC Z), by, note}`; `path` is the PATH-resolved command path; match = same platform + method + path (case-insensitive on macOS/Windows), or method only when the registry marks the method `versionedPath`; written only by `tool_exception_record` / `Set-ToolException` after `[k]eep` (read-then-merge, backup, validate; never dry run or non-interactive; refused when the profile came from the hostname/first-profile fallback); read at T5 every run; logged as "known exception" at info level; distinct from top-level `overrides`; a write adds ACTION `commit profile.json`; the engine must work at installer Step 1 (no node/uv python), and a missing engine degrades to "no exception" with a warning.

## 3. Open questions (each with a recommended answer)

| # | Question | Recommendation |
|---|----------|----------------|
| Q1 | How do setup scripts get registry data: (A) generated specs committed in `generated/tool-specs/` and embedded by build-deploy, (B) parse the JSON at run time (perl `JSON::PP` / `ConvertFrom-Json`), (C) keep hard-coded values and let the pre-commit check compare them? | **A.** One source; MDM deploy scripts stay self-contained; no evaluation of registry text; B fails on minimal Linux (`JSON::PP` is in `perl-modules`, not `perl-base`) and the registry cannot degrade. C as a stopgap for batches before the generator. Needs the git-safety.md companion edit |
| Q2 | Summary severity for a kept (exception) install: OK or WARN? (proposed D-TS10) | **OK `<ver> (kept)`** — the user decided; a permanent WARN trains people to ignore WARN. This departs from F3 ("kept as-is is WARN") for recorded exceptions only; unrecorded holds stay WARN |
| Q3 | `[x]abort` scope: stop the whole run (exit 2) or only this tool? | **Stop the run (exit 2)**, matching the governed managed-file abort, and fix the installers to honour exit 2 (I-02) |
| Q4 | Keep automatic fallback methods (modal pip / `python -m pip`, datadog cargo on macOS)? | **Remove them.** A missing manager is PREREQ (ERROR + ACTION naming the prerequisite's setup script). Fallbacks install non-preferred methods without a decision, against tool-evaluation.md's governing principle. Keep cargo only where it is the registry's preferred method (datadog Windows) |
| Q5 | Below `minVersion` (bash < 5.0, perl < 5.010): ERROR or WARN? | **ERROR + ACTION** — the harness cannot run on it; today's WARN hides a broken environment |
| Q6 | Must verification query upstream for "the channel's latest" version number? | **No** — the update command is the mechanism; querying differs per manager and is unreliable. Revisit if health flags need it |
| Q7 | Resolve the `reference/tool-registry.md` duplication how? | **JSON canonical; md generated.** Phase 1: banner "superseded — registries/tool-registry.json is canonical; do not edit" + move prose-only facts (PATH issues, notes) into JSON fields that already exist; Phase 2: generator writes the md (like `deploy/`), and check-post-push steps 9, 10, 25 read the JSON (S3-Nine's files — follow-up after #9). Nothing deleted. Same for `registries/tool-versions.json` vs registry `versions` (I-11) |
| Q8 | Protect all project skills in sources-of-truth (`.claude/skills/*/SKILL.md`)? The draft adds only the three tool skills | **Yes, as a separate decision** — the brief already treats skills as protected and their intents are protected; the table does not say so (I-15). Not bundled into this batch because no D-TS decision covers it |
| Q9 | Where is the tool registry schema documented: the rule (three-layer convention), the skill (today), or the reference? | **Reference section 6 only**; the skill and registry `meta` point to it; the rule's cross-reference names it. Amend `framework-three-layer-governance.md` "Schema" to "documented in the rule or a reference it names" (separate approval) |
| Q10 | SHADOWED = ERROR although another copy runs (proposed D-TS11)? | **Yes** — "supported" means resolving to the managed copy (tooling-resolution plan decision 10); add the severity-guide line (companion edit). Today's WARN is how the python shadow went unnoticed |
| Q11 | A platform still `evaluating`: WARN or ERROR (proposed D-TS12)? | **WARN `under evaluation` + ACTION** — nothing is broken that the user caused; ERROR would fire on every Linux run for node |
| Q12 | Platform-level n/a row: new governed outcome `n/a (<platform>)` + `write_platform_skip` / `Write-PlatformSkip`, or reuse the environment helper? | **New platform variant** — `write_environment_skip` prints the environment name, which is wrong for "typst on Linux"; add the governed row (companion edit) |

## 4. Gap table

Legend: **C** compliant, **D** deviates, **M** missing, **n/a** not applicable. Columns are decision-tree requirements:
L0 preferred method from registry (D-TS1) · L1 NO-METHOD = ERROR + ACTION `/tool-eval` (D-TS2) · L2 detection by registry signatures (T2) · L3 fresh install verified by binary (F2) · L4 update per channel, failure = WARN when tool works · L5 non-preferred: non-interactive WARN + ACTION / interactive menu (D-TS3) · L6 unknown never removed, reported · L7 install first, remove after verify (F1) · L8 keep exception (D-TS4) · L9 post-check SHADOWED/NOT-ON-PATH = ERROR (Standard 4) · L10 summary coverage, detail ≤30.

Evidence cites the script block (header comment of the block) or lib function.
Cross-cutting gap not in a column: every tool setup script except
setup-google-chrome ignores `AITOOLS_DRY_RUN`, which the installer exports
(I-22); the tree's dry-run overlay fixes it per migrated script.

| Script | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | L8 | L9 | L10 | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| setup-go.sh | D | M | D | C | D | D | D | C | M | D | D | Commands hard-coded; Linux keeps `/usr/local/go` as OK although registry `install.linux` is `[]` ("upstream" branch). `detect_go_provenance` (lib) uses fixed path patterns, not registry. `brew upgrade go … || true` + grep → ERROR on failure. pkg/manual replaced with no menu; goenv = `log_warn` + WARN row, no ACTION. Unknown → brew Go installed alongside, no WARN. Removal only after `BREW_GO` verified (C). Post-check is `command -v go` only; failed `sudo rm -rf` is a warn "may shadow". Summary detail = full `go version` line (~32 chars) |
| setup-go.ps1 | D | n/a | D | C | D | D | D | **D** | M | D | D | "Cleanup non-preferred installs": `choco uninstall golang` BEFORE winget install. Scoop WARN, no ACTION. `Get-GoProvenance` (lib) path + `winget list`. Unknown/msi → winget install without WARN. Post-check `Get-Command` only; no persistent PATH test |
| setup-gh-cli.sh | D | D | D | C | D | D | D | n/a | M | D | C | macOS: no detection — a non-brew gh hits `brew upgrade gh` → ERROR. Linux: `dpkg -S` ownership (matches the `dpkg:` probe design); non-apt gh kept with WARN "not apt-managed (kept)" but no ACTION, no menu; distro gh switched to cli.github.com automatically; non-apt Linux → ERROR "no supported package manager" (no `/tool-eval` ACTION) |
| setup-gh-cli.ps1 | D | n/a | M | C | D | M | M | n/a | M | D | D | No detection: winget upgrade non-zero → WARN "may be installed via another method". Persistent PATH check only on fresh install. "<ver> (upgrade check failed, exit N)" > 30 chars |
| setup-uv.sh | D | M | D | C | D | D | D | C | M | M | C | Registry `install.linux` = `[]` but script tries Homebrew → ERROR "Homebrew not found" (should be NO-METHOD). "Homebrew" = path prefix `/opt/homebrew/*` or `/usr/local/*`. Non-brew uv → brew uv installed alongside automatically; OK row written with brew version even if the old uv still resolves first (no post-check) |
| setup-uv.ps1 | D | n/a | M | C | **D** | M | M | n/a | M | D | D | `winget upgrade` output matching `No installed package` is treated as "already up to date" → a non-winget uv reports OK silently. "version check failed after upgrade" = 34 chars |
| setup-typst.sh | D | M | D | D | D | D | D | **D** | M | D | C | "Cleanup non-preferred installs" runs `cargo uninstall typst-cli` / `npm uninstall -g typst` BEFORE the Homebrew install. No Homebrew presence check (fails as "brew install typst failed"). Linux `[]` not gated. Prefix-based brew detection |
| setup-typst.ps1 | D | n/a | M | C | D | D | D | **D** | M | D | D | `Remove-NonPreferred` (cargo, npm) before winget install. Non-winget typst → `winget upgrade` non-zero → ERROR |
| setup-datadog.sh | D | M | D | C | D | D | **D** | **D** | M | D | C | Old tap: `brew uninstall datadog/pack/pup` BEFORE reinstall. Any non-Homebrew pup (including unknown sources) is `rm -f`'d after brew install — violates "unknown never removed". cargo fallback on macOS is not a registry macOS method; header says Linux = cargo while registry Linux preferred = homebrew |
| setup-datadog.ps1 | D | n/a | M | C | C | M | M | n/a | M | D | D | Detection absent (any pup → `cargo install --git` rebuild). Post-check `Get-Command` only. "missing build prereqs: …" > 30 chars |
| setup-pandoc.sh | D | n/a | D | C | D | D | D | **D** | M | D | C | macOS: conda / MacPorts / cabal removed BEFORE `brew install pandoc`; `/usr/local/*` counted as Homebrew though the registry lists "/usr/local/bin/pandoc not from Homebrew" as non-preferred. Linux: any pandoc = OK (no detection, no update; registry `update` has no apt key) |
| setup-pandoc.ps1 | D | n/a | D | C | D | D | M | n/a | M | D | D | Detection = winget upgrade exit code; Chocolatey → WARN only, no ACTION, no menu. "<ver> (upgrade check failed)" > 30 |
| setup-rust.sh | D | n/a | D | C | C | D | M | **D** | M | M | C | "Cleanup non-preferred installs": `brew uninstall rust` BEFORE rustup install. apt rustc (registry non-preferred) not detected. PATH only prepended for the session; no post-check |
| setup-rust.ps1 | D | n/a | D | C | C | M | M | n/a | M | D | D | Detection = `~/.cargo/bin/cargo.exe` exists. Persistent PATH ERROR + ACTION present (closest to T7), no shadow test. MSVC WARN detail ~70 chars |
| setup-vercelcli.sh | D | n/a | D | C | D | D | D | **D** | M | D | C | macOS: `npm uninstall -g vercel` BEFORE `brew install vercel-cli`; any non-brew vercel assumed npm. Linux: installed → OK, never updated; no detection |
| setup-vercelcli.ps1 | D | n/a | M | C | **M** | M | M | n/a | M | D | C | Installed → OK; never updated (registry update: re-run npm). Persistent PATH check fresh install only |
| setup-modal.sh | D | n/a | D | C | C | D | D | C | M | M | C | uv absent → `pip install --user` (registry non-preferred fallback) installed automatically. Non-uv modal → `uv tool install` alongside, old copy not reported or removed, no post-check |
| setup-modal.ps1 | D | n/a | D | C | C | D | D | C | M | M | C | As .sh plus `python -m pip` fallback, which is not in the registry at all |
| setup-python.sh | D | n/a | D | C | C | n/a | n/a | n/a | M | **D** | C | Target `3.14` hard-coded (registry: same; maps to `pinned-minor`). Has the best post-check (resolved path vs uv shim, names the shadow dir) but reports WARN, not ERROR |
| setup-python.ps1 | D | n/a | D | C | C | n/a | n/a | n/a | M | **D** | C | As .sh; shadow = WARN |
| setup-perl.sh | **D** | C | M | n/a | n/a | M | M | n/a | M | M | C | macOS: registry preferred = system `/usr/bin/perl`, but the script ERRORs "Homebrew not found" when brew is missing (a working perl reported broken) and installs brew perl (registry non-preferred). minVersion check → WARN |
| setup-perl.ps1 | D | n/a | M | C | M | M | M | n/a | M | D | C | Any perl on PATH accepted (Git Bash's bundled perl included, though the registry manages Strawberry and check-lib prepends it). No winget upgrade |
| setup-bash.sh | D | n/a | D | C | **M** | n/a | n/a | n/a | M | **D** | C | Homebrew bash never upgraded (registry update `brew upgrade bash`). Shadowed Homebrew bash → WARN "PATH ordering issue" (Standard 4: ERROR). Detection by version, not method |
| setup-bash.ps1 | C | n/a | C | n/a | M | n/a | n/a | n/a | n/a | D | C | Fixed Git Bash paths (deliberate: avoids WSL). Script probes 3 paths; registry `knownPaths.windows` lists 1. No Git for Windows upgrade |
| setup-google-chrome.sh | C | C | M | C | C | n/a | C | n/a | n/a | D | C | Exemplar for NA (`write_environment_skip`) and PREREQ (root, apt, amd64 gates). Detection = binary presence; Playwright Chromium preserved (matches "unknown never removed"). `google-chrome` resolution not post-checked (fixed `CHROME_BIN`) |
| setup-google-chrome.ps1 | C | C | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | C | NA row only |
| aitools-install Step 8 (node, .sh/.ps1) | D | D | M | D | M | M | M | n/a | M | D | C | Inline, no setup script. `command -v node` → OK for any node: on this Mac it reports Homebrew `node` 26.3.1 while preferred `node@22` (22.22.3) is installed, keg-only, off PATH. Linux → WARN "install manually" instead of NO-METHOD. No update |
| aitools-install Step 9 (claude-code) | D | n/a | M | C | C | M | M | n/a | M | D | C | `claude update` with exit code (C). Homebrew cask / winget / deprecated npm installs not detected |
| setup-user-cursor (cursor-agent-cli part) | D | n/a | D | C | M | M | M | n/a | M | D | C | Installs agent via curl when missing; no `agent update`; manages `agent → cursor-agent` symlink. Installs ripgrep via brew with no registry entry (I-13) |
| pwsh (macOS) | M | M | M | M | M | M | M | M | M | M | M | Registry: macOS supported; no installer step or setup script (plans/tooling-resolution backlog #5) |
| nss-tools | C | C | M | C | n/a | n/a | n/a | n/a | n/a | D | C | Inside setup-google-chrome.sh |
| setup-user-claude, -cursor (config), -mcp, -skills, -settings, -hooks, -shell, setup-cursor-ide-mcp | n/a | | | | | | | | | | | Managed-file deployment, not tool support (governed by managed-file-deployment.md) |

### Migration batching

One `.sh/.ps1` pair (2 files) per batch; 3 files only where a lib or generator file joins. Order = risk first (data-loss F1 violations), then silent-wrong, then gaps. Each batch: verbatim edits in a plan, fresh sub-agent with the error-handling rules block (plan-execution.md), main-agent verification (`bash -n`, PS1 parser, section 10 test matrix), intents for each migrated script drafted and approved before delegation (setup scripts have no intent headers today).

| Batch | Files | Why first / notes |
|---|---|---|
| B0 (docs) | this draft batch (protected) | Approve tree, rule, reference, skills, glossary, schema first |
| B1 | registry 1.1 data for go, typst, vercel-cli (via `/tool-registry`) + generator `scripts/gen-tool-specs.py` writing `generated/tool-specs/` (Q1-A) | Data the first script batches need |
| B2 | `aitools-lib.sh` (helpers, bash 3.2, removal guards) | Detection, install/update/remove, menu, report, `tool_support_run` |
| B3 | `aitools-lib.ps1` (parity) | Same contract |
| B4a | installers `aitools-install.sh/.ps1`: honour exit 2 (contract 7.5) | Fixes I-02 for both menus; small |
| B4b | entry points `scripts/aitools` / `aitools.ps1`: propagate exit 2, "aborted by user" | Completes I-02 |
| B5 | setup-typst pair | F1 violation (cargo/npm removed first) |
| B6 | setup-vercelcli pair | F1 violation (npm removed first); Linux/Windows update gap |
| B7 | setup-pandoc pair | F1 violation; `/usr/local` misclassification |
| B8 | setup-rust pair | F1 violation (brew rust removed first) |
| B9 | setup-go pair | choco removed first (PS1); richest existing logic → exemplar for replace + Linux NO-METHOD until `/tool-eval` |
| B10 | setup-datadog pair | old-tap F1 violation; unknown-source deletion; fallback decision (Q4) |
| B11 | setup-uv pair | PS1 silent OK; Linux NO-METHOD |
| B12 | setup-gh-cli pair | Runs at Step 1 — validates the no-parser design |
| B13 | setup-python pair | shadow WARN → ERROR; `pinned-minor` channel |
| B14 | setup-modal pair | fallback removal (Q4) |
| B15 | setup-perl pair | macOS system perl preferred; minVersion (Q5) |
| B16 | setup-bash pair | update + shadow severity |
| B17 | setup-google-chrome pair | small: resolution post-check |
| B18+ | new setup-node (M4), setup-claude-code, setup-cursor-agent, setup-pwsh | New onboarding via `/tool-adopt`; separate missions |
| later | MDM embed of specs + helpers in `build-deploy.sh`; check-post-push step 29 parity extension | After mission S3-Nine lands its build-deploy / check-post-push work |

## 5. INCIDENT findings

Not filed (sensor role). Severity per incident-governance.md.

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| I-01 | high | INCIDENT: Seven setup scripts uninstall or delete a tool before its replacement is verified, contrary to approved F1 ("install first, clean up second"); the rule F1 was meant to amend still says only "SHOULD detect and remove old installs" | setup-typst.sh/.ps1 "Cleanup non-preferred installs"; setup-pandoc.sh macOS migrate block; setup-rust.sh "Cleanup non-preferred installs"; setup-vercelcli.sh macOS migrate block; setup-go.ps1 "Cleanup non-preferred installs" (choco); setup-datadog.sh old-tap block. `plans/linux-install-hardening.md` F1 ("amends tool-lifecycle.md 'Install cleanup' in PR B"); `.claude/rules/tool-lifecycle.md` "Install cleanup" |
| I-02 | high | INCIDENT: `[x]abort` is documented as "stop the run (global)" and exits 2, but both installers treat exit 2 as a generic script failure and continue with the next step | `interactive-menus.md` "JSON field-level review" ("only `abort` is global (stops the run)"); `aitools-lib.sh` `prompt_diff_review` ("Exits with code 2 on abort"); `aitools-install.sh` `validate_and_run`; `aitools-install.ps1` `Invoke-ValidatedScript` |
| I-03 | high | INCIDENT: setup-datadog.sh deletes (`rm -f`) any non-Homebrew pup after a Homebrew install, including binaries of unknown origin | setup-datadog.sh "Installed via go install or another method -- migrate" block |
| I-04 | medium | INCIDENT: Stale data paths in governing skills: `/glossary` reads `reference/glossary.json` and `/frameworks` reads `reference/framework-registry.json`; both files live in `registries/` | `.claude/skills/glossary/SKILL.md` "Reading definitions"; `.claude/skills/frameworks/SKILL.md` "Reading frameworks"; `ls registries/` |
| I-05 | medium | INCIDENT: Framework registry "Tool operations" artifact lists `reference/tool-ops.json` (moved to `registries/`); "Tool lifecycle" entry stale (lastUpdated 2026-03-15, >90 days) | `registries/framework-registry.json` frameworks[Tool operations, Tool lifecycle] |
| I-06 | medium | INCIDENT: `reference/tool-registry.md` duplicates the JSON and has drifted (vercel macOS 50.23.2 vs JSON 50.28.0; Windows "pending" vs 50.17.1), yet check-post-push steps 9, 10 and 25 parse it and every setup script header cites it | `reference/tool-registry.md` "Vercel CLI" Lifecycle; `registries/tool-registry.json` `vercel-cli.versions`; `check-post-push.sh` steps 9, 10, 25 |
| I-07 | medium | INCIDENT: Registry `nonPreferredMethods[].detection` values are prose or install commands and cannot drive detection (pandoc `"pip install pandoc"`, `"/usr/local/bin/pandoc not from Homebrew"`; go all `null`) | `registries/tool-registry.json` pandoc, go |
| I-08 | medium | INCIDENT: `lifecycle.platformStatus` holds non-enum values (`"supported (source build)"` datadog-pup windows; `null` google-chrome macos/windows) | `registries/tool-registry.json`; enum in `reference/tool-evaluation-criteria.md` "Tool Platform States" |
| I-09 | medium | INCIDENT: Registry says macOS preferred `brew install node@22`, but node@22 is keg-only and off PATH on nobul-mac; `node` resolves to Homebrew `node` 26.3.1; registry lastVerified 24.1.0 matches neither; installer Step 8 reports OK for any node | `brew info node@22 --json` (keg_only: versioned_formula), `which -a node`, `ls -l /opt/homebrew/bin/node` (2026-10-20); `aitools-install.sh` Step 8 |
| I-10 | medium | INCIDENT: setup-perl.sh reports ERROR "Homebrew not found" on a Mac without Homebrew although the registry's preferred macOS method is the system perl, and it installs brew perl (non-preferred) | setup-perl.sh macOS branch; registry `perl.install.macos` |
| I-11 | low | INCIDENT: Versions are tracked three times — registry `versions`, `registries/tool-versions.json`, `reference/tool-registry.md` — and check-post-push hard-codes `TOOL_CMDS` that duplicate registry `versionCheck` | `check-post-push.sh` step 21 `TOOL_CMDS` |
| I-12 | low | INCIDENT: tool-evaluation.md gate "Every install method decision MUST be documented in reference/evaluations/" — one evaluation file exists for 18 registry tools | `.claude/rules/tool-evaluation.md` "Gates"; `ls reference/evaluations/` |
| I-13 | low | INCIDENT: setup-user-cursor installs ripgrep via Homebrew although ripgrep has no registry entry (bundled-dependency graduation / install method discovery) | setup-user-cursor.sh ripgrep block; registry `cursor-agent-cli.lifecycle.dependencies` |
| I-14 | low | INCIDENT: `managed-file-deployment.md` cites `tool-lifecycle.md` "Deployment pattern updates", a section that does not exist | `.claude/rules/managed-file-deployment.md` "Updating this table" |
| I-15 | low | INCIDENT: sources-of-truth table omits `.claude/skills/*` and `reference/tool-registry.md`, while check-post-push step 10 treats the latter as protected | `.claude/rules/sources-of-truth.md`; `check-post-push.sh` step 10 |
| I-16 | low | INCIDENT: script-standards-detail says summary detail is "Max 30 characters (compliance-checked)"; no enforcing check found (grep of `scripts/check-*`, libs), and runtime details exceed it (`go version` line, PS1 "version check failed after upgrade") | `reference/script-standards-detail.md` "Summary detail text rules" |
| I-17 | low | INCIDENT (D-TS9): no intent statement in `.claude/rules/interactive-menus.md`, `sources-of-truth.md` (drafts add one), `cross-platform.md`, `script-standards.md`, `managed-file-deployment.md`, `config-file-safety.md`, `documentation-standards.md`; `reference/tool-evaluation-criteria.md`, `tool-evaluation-playbook.md`, `user-repo.md`, `script-standards-detail.md`, `managed-file-deployment.md`, `cross-platform-detail.md`, `tool-registry.md`; every `scripts/setup-*.sh` and both libs | grep for `**Intent**` / `Intent:` |
| I-18 | low | INCIDENT: `setup-bash.sh/.ps1` headers cite `reference/tool-registry.json` (never existed there; now `registries/`) | setup-bash.sh / .ps1 header |
| I-19 | low | INCIDENT: tool-registry skill lists `delivery`, `health`, `maintenance`, `evaluation` as required fields; 16 of 18 tool entries have none of them | `.claude/skills/tool-registry/SKILL.md` step 1; registry (only google-chrome, nss-tools have them) |
| I-20 | low | TODO(glossary): "provenance" is governed as an aitools component but also used for supply-chain verification (`/tool-eval`) and install origin (`detect_go_provenance`, `Get-GoProvenance`) | `registries/glossary.json` `provenance`; lib function names |
| I-21 | low | INCIDENT: `reference/tool-evaluation-criteria.md` "Tool Platform States" says per platform "(macOS, Windows)" and points to `reference/tool-registry.md`; Linux and environments are missing | criteria "Tool Platform States", "Special Cases" |
| I-22 | high | INCIDENT (found by S5-Tools-A, verified for setup-go.sh): tool setup scripts ignore `AITOOLS_DRY_RUN`, which `aitools-install.sh` exports for `--dry-run`; a dry run installs and upgrades tools, and setup-go.sh can run `sudo rm -rf /usr/local/go` | `aitools-install.sh` ("if $DRY_RUN; then export AITOOLS_DRY_RUN=1"); setup-go.sh has no DRY_RUN reference |
| I-23 | medium | INCIDENT: `.cursor/rules/tool-lifecycle.mdc` already differs from the `.md` rule (it still has "Dotprofile priority" and "Deployment pattern updates"); I-14's missing section exists only in the mirror | `grep` of `.cursor/rules/tool-lifecycle.mdc` (lines with both headings) |
| I-24 | medium | INCIDENT: I-02 extends to the entry point: `scripts/aitools` turns any installer non-zero into "Completed with errors" | `scripts/aitools` install path (`installer_rc`) |
| I-25 | low | INCIDENT: `cross-platform.md` "One script per tool (D-ENV0)" names `install_via_brew` / `install_via_apt`, which do not exist in `aitools-lib.sh` | lib function list |
| I-26 | low | INCIDENT: `sources-of-truth.md` lists `registries/*.json` paths, while `governed-data-access.md` says rules MUST NOT reference JSON paths (pre-existing tension; the draft keeps the existing rows) | both rules |

Open incident #65 ("CLAUDE.md deploy list" no longer exists) was being re-carried by the first `/tool-adopt` draft; revision 2 removes the item and cites #65.

## 6. What I verified vs what is unknown

- Verified by reading: every `scripts/setup-*` tool script (both languages), `aitools-lib` detection/menu/summary helpers, installer Steps 1-21 and both script runners, the registry, the rules and references listed in the brief.
- Verified by command on nobul-mac: node@22 keg-only and off PATH; active node is Homebrew `node` 26.3.1.
- Unknown: Claude Code web image node location; nvm-windows path; nodejs.org pkg id (marked `_unverified` in the registry draft); whether any check enforces the 30-char limit outside `scripts/` (I-16); Windows behaviour of every PS1 claim (read, not run — no pwsh run on this Mac).
- Coordination: at 19:42 another session created untracked copies of the project skills under `shared/skills/` (including `tool-eval/` and `tool-registry/`, same sizes as the `.claude/skills/` originals) and modified `scripts/build-deploy.sh`, `check-hook-parity.py`, `check-post-push.sh/.ps1` (S3-Nine's scope). If project skills are moving to `shared/skills/`, the `/tool-adopt`, `/tool-eval`, `/tool-registry` drafts must land at the new path and the documentation-standards "no same-name skills at both levels" rule applies. I did not touch these files.
- Not read (outside my access list): mission S5-Profile outputs in the sibling scratch directory — the Session Commander should reconcile section 8 of the reference with M3's schema.

## 7. Adversarial review disposition

Reviewer: S5-Tools-A (fresh sub-agent, read-only), full findings in
`/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Tools/S5-Tools-A-review.md`
(55 findings: 4 blocker, 29 major, 22 minor; 9 incidents). I spot-checked three
claims (the `.mdc` sections, `scripts/aitools` exit handling, incident #65): all true.

| Finding | Disposition |
|---|---|
| D-01 blocker: script shape aborts under `set -e` | **Fixed**: `rc=0; tool_support_run … || rc=$?`, post-config only on rc 0; conditional-context rule for helpers (ref 7, 7.6; /tool-adopt step 4) |
| A-01 blocker: parser story contradicts | **Fixed**: specs justified by MDM self-containment, minimal Linux, no evaluation; exception store may degrade (ref 7.1, 8) |
| D-03 blocker: registry draft breaks its schema | **Fixed**: `kind` optional for non-preferred (null); image-provided `autoUpdates: true`; placeholder marked not writable |
| D-02 blocker: unguarded `path:` removal | **Fixed**: five guards + warn-logged command (ref 7.3); test row |
| A-02 F3 vs OK for exceptions | **Fixed as a decision**: proposed D-TS10 / Q2 |
| A-03 two summary rows | **Fixed**: failed update only warns; installer's extra row documented as expected |
| A-04 evaluating → ERROR | **Fixed**: EVALUATING leaf (WARN), proposed D-TS12 / Q11 |
| A-05 SHADOWED severity basis | **Fixed**: cites plan decision 10; D-TS11 / Q10; companion severity-guide edit |
| A-06 duplicates tool-ops resolution | **Fixed**: T7 uses tool-ops `resolution` when it exists; rule item 6 cites decision 10 |
| A-07 all skills protected | **Fixed**: row limited to the three tool skills; all skills = Q8 |
| A-08 generated files in `scripts/` | **Fixed**: `generated/tool-specs/` + git-safety companion edit |
| A-09 NA helper | **Fixed**: NA via the helpers; platform variant = Q12 |
| A-10 node example mismatch | **Fixed**: registry note now predicts REPLACE-BLOCKED; node@22 kept as a method |
| A-11 environment redefined | **Fixed**: "API value" wording |
| B-01 two checklists | **Fixed**: /tool-registry points to /tool-adopt step 5 |
| B-02 schema in three places | **Fixed**: reference section 6 is the only authority; skill and `meta.schemaRules` point to it; Q9 for the convention |
| B-03 ACTION text differs | **Fixed**: rule says "text per the reference" |
| B-04 aitool-eval card stale | **Companion edit listed** |
| B-05 overrides vs exceptions | **Fixed** (ref 8) |
| C-01..C-03 tree gaps | **Fixed**: broken update via T7; VERSION-UNKNOWN leaf; dry run as overlay |
| C-04 exception path | **Fixed**: PATH-resolved path, case-insensitive, `versionedPath` |
| C-05 system/bundled kinds | **Fixed** (node rule P; section 4) |
| C-06 line moves orphan installs | **Fixed**: old line kept as a method; check 10; /tool-eval step 7 |
| C-07 Linux family | **Fixed**: `family` field, T1 matching, `tool_linux_family` |
| C-08 environment specificity | **Fixed**: most specific wins |
| C-09 duplicate method ids | **Fixed**: unique per tool; check 3 |
| C-10 knownPaths verification | **Fixed**: `{path, verified}` shape; T3 uses verified only |
| C-11, C-12, C-13, C-15, C-16, C-17 | **Fixed** (menu prompt `[i/k/x]`; "without --force"; per-sub-check reasons; version half for kept/held; `[i]` loop documented; local env status disallowed) |
| C-14 "detection" naming | **Partly**: §9 retitled "Pre-commit conformance check"; the registry field keeps the name `detection` (pre-existing) — TODO(glossary) folded into I-20 |
| D-04 Windows probe order | **Fixed**: package-database probes before path-only; `--accept-source-agreements`; trial classification required (choco wrapping MSI stays unverified) |
| D-05 shared install dir removal | **Fixed**: removal null unless trialled; node winget-current set to null |
| D-06 realpath implementation | **Fixed**: perl `Cwd::abs_path` / PS7 `ResolveLinkTarget`; symlink test row |
| D-07 entry point exit 2 | **Fixed**: contract includes `scripts/aitools` / `.ps1`; batch B4b; I-24 |
| D-08 executed update strings | **Fixed**: `update` display-only; builders from `kind`+`package`; generator quoting |
| D-09 fallback profile | **Fixed**: writer refuses fallback; reader matches platform |
| D-10 MDM scope | **Fixed**: out of scope for first batches; sequenced after S3-Nine |
| D-11 check 9 false positives | **Fixed**: excludes `mktemp` paths; allowlist marker |
| D-12 summary length / paths | **Fixed**: `shadowed (see log)`, `<ver> (kept)`, check 11 |
| D-13, D-14 | **Fixed** (conditional context; `script-url` https + host check) |
| E-01..E-03 intents | **Fixed** (registry `meta.intent` drafted; generator emits an intent header; interactive-menus scope) |
| F-01 node linux status change | **Surfaced** as an explicit M4/commander decision in the draft (`_statusChange`) |
| F-02 go linux knownPaths | **Fixed** (proposal noted in the go entry) |
| F-03 nvm-windows token | **Left** unverified for M4 |
| F-04 framework entry paths | **Fixed** (plain paths, PS1 check, generator; write only once paths exist) |
| F-05 "installer run" | **Fixed** |
| Review incidents I-1..I-9 | Merged into section 5 (I-22..I-26 new; others were already I-02, I-14, I-07/I-08, I-04) |

Not re-reviewed after revision 2: a second adversarial pass was not run; the
Session Commander may want one on `reference/tool-support-decision-tree.md` only.
