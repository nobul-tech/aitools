# S5-Tools-A review: tool-support framework drafts

Summary (5 lines):
1. 55 findings: 4 blocker, 29 major, 22 minor, plus 9 `INCIDENT:` repo deficiencies (section I).
2. Blockers: the section 7.5 script shape breaks under `set -e`; section 7.1 and section 8 disagree on whether a JSON parser exists at Step 1; the registry draft breaks its own schema (`kind: "-"`, node's claude-code-web method has no update path and an invalid probe); `path:` removal has no safety guards.
3. Biggest design gaps: an LTS line move leaves the old preferred install with no method (no leaf handles it, and nobul-mac shows this today); Windows probe order and `winget list` matching can misclassify choco/MSI installs; nothing handles Linux package-manager families (dnf); a tool exception's `path` is undefined (resolved path vs realpath).
4. The tree has gaps: no edge for "update failed and tool broken", none for "version unknown", DRY-RUN has no node and cannot reach "ask", and UPDATE-FAIL writes two summary rows although the reference says one.
5. Duplication: two onboarding checklists that disagree (/tool-adopt vs /tool-registry), and the schema is written in three places, none of them the rule. The drafts carry forward open incident #65 and leave the `.cursor/rules/*.mdc` mirrors stale.

Reviewed: every file under `S5-Tools-drafts/` as of 2026-10-20 19:41 (the decision tree and registry draft re-read after the RP / REPLACE-BLOCKED revision). Sources checked: the live rules, `scripts/aitools-lib.sh/.ps1`, `aitools-install.sh/.ps1`, `scripts/aitools`, `setup-go.sh/.ps1`, `registries/tool-registry.json`, `glossary.json`, `framework-registry.json`, `incidents.json`, and the plans the drafts cite.

---

## A. Contradictions

**A-01 — blocker — decision tree §7.1 vs §8 (internal)**
- **Finding:** §7.1 rejects reading the registry at run time because no JSON parser exists at Step 1, and so introduces generated spec files. §8 then requires the exception reader and writer to parse and write `profile.json` at Step 1 with perl `JSON::PP` / `ConvertFrom-Json`. Both cannot be true.
- **Evidence:** §7.1 "not by parsing JSON at run time (no JSON parser is guaranteed at installer Step 1...)"; §8 "macOS and most Linux have perl with `JSON::PP` (a core module); Windows has `ConvertFrom-Json`".
- **Fix:** Pick one engine statement. Either (a) perl JSON::PP and ConvertFrom-Json are the Step-1 parsers, so §7.1 can read the registry directly and spec files are needed only for the MDM path, which has no registry. Or (b) say the specs exist because MDM deploy scripts are self-contained (`deploy-paths.md`), not because of the parser. Both readings need a stated fallback for minimal Linux: Debian `perl-base` lacks JSON::PP (unknown for the Claude Code web image).

**A-02 — major — tool-lifecycle.md draft / decision tree §3 vs F3**
- **Finding:** The reference cites F3 as "kept tool is WARN", yet EXCEPTION and KEEP write OK.
- **Evidence:** decision tree §1 "F1-F4 | ... / kept tool is WARN /"; `plans/linux-install-hardening.md` F3 "A working tool kept as-is is WARN, not ERROR"; §3 "EXCEPTION ... OK `<ver> (kept <method>)`".
- **Fix:** Get an explicit commander decision (proposed: OK for a recorded exception, because the user decided it and it is not a caveat). Record it as D-TS10 and stop citing F3 as support.

**A-03 — major — decision tree §3 "exactly one summary row" vs leaves and installers**
- **Finding:** UPDATE-FAIL writes WARN and then continues to T7, which writes OK, so two rows. Every exit-1 leaf also gets a second ERROR row from the installer.
- **Evidence:** §3 "Every leaf writes exactly one summary row"; UPDATE-FAIL row "WARN `<ver> (update failed)`" plus mermaid `UF --> T7`; `aitools-install.sh` `validate_and_run` "write_summary ERROR ... "script failed (exit $script_rc)""; C-F3 "Orchestrators add ERROR ... when a child dies".
- **Fix:** Make UPDATE-FAIL "via T7" (log_warn only, so T7's OK auto-promotes to WARN through `write_summary`). State that the installer's extra row is expected, or have `validate_and_run` skip its row for exit 1 when the child wrote an ERROR row.

**A-04 — major — decision tree T0 vs tool-lifecycle "Under Evaluation guard"**
- **Finding:** T0 turns per-platform `evaluating` into NO-METHOD (ERROR, exit 1, ACTION `run /tool-eval`) and cites the guard. The guard covers only tools evaluating on ALL platforms and says nothing about severity. With the node draft (linux = evaluating), every linux/local run turns today's WARN into an ERROR.
- **Evidence:** §2 Node rules T0 "`evaluating` also ends it as NO-METHOD (Under Evaluation guard...)"; tool-lifecycle.md "Tools with `evaluating` status on ALL platforms MUST NOT have setup scripts"; registry draft node linux note "replaces today's 'install manually' WARN".
- **Fix:** Give `evaluating` its own leaf (proposed: WARN `under evaluation` + ACTION, exit 0), or get commander confirmation that ERROR is intended. Stop citing the guard.

**A-05 — major — tool-lifecycle.md draft rule 6 / SHADOWED vs severity guide**
- **Finding:** SHADOWED is ERROR, yet the tool works because another copy runs. The severity guide says WARN means the tool works.
- **Evidence:** `script-standards-detail.md` "Severity categories": "WARN means the tool itself works; ERROR means it doesn't"; Standard 4 covers only "isn't in persistent PATH"; rule draft "shadowed or off PATH is ERROR (script-standards Standard 4)".
- **Fix:** Cite the real basis, `plans/tooling-resolution-and-artifact-registry.md` decision 10 ("resolving to the managed copy"), and add a severity-guide line for shadowing in the same batch.

**A-06 — major — decision tree §2 T7 / §7 `tool_resolution_check` vs tooling-resolution plan**
- **Finding:** The post-check duplicates the tool-ops `resolution` + `verifications` design (managedPath, pathPrecedence). The rewritten tool-lifecycle.md also drops the planned decision-10 gate (B4).
- **Evidence:** plan decision 5 "Install-path facts live in tool-registry `knownPaths`; tool-ops `resolution` references them"; decision 10; B4 "`.claude/rules/tool-lifecycle.md` (add the decision-#10 gate)".
- **Fix:** Name one owner. Proposed: T7 consumes tool-ops `resolution` when it exists, and the rule carries the decision-10 gate (or a note that it is pending).

**A-07 — major — sources-of-truth.md draft vs D-TS1..9**
- **Finding:** Adds `.claude/skills/*/SKILL.md` (every project skill: incident, glossary, audit...) to the protected list. No decision covers that; it is scope creep for this batch.
- **Evidence:** draft row "`.claude/skills/*/SKILL.md` | Project skills — governed processes...". D-TS7 covers only maintaining the registry and rule.
- **Fix:** Present it as its own commander decision, or limit it to `tool-adopt`, `tool-eval`, `tool-registry`.

**A-08 — major — sources-of-truth.md draft "Generated files ... `scripts/tool-specs/*`" vs git-safety.md**
- **Finding:** This puts generated files inside a source directory. git-safety says generated content lives in fully generated dirs (`deploy/`), and a build step that creates diffs in source directories must be fixed.
- **Evidence:** git-safety.md "scripts/ is source — never bulk-reset ... If a build step creates noise diffs in source directories ... fix the build step".
- **Fix:** Pick a generated location (for example `generated/tool-specs/`), or amend git-safety.md in the same batch.

**A-09 — minor — decision tree §3 NA leaf vs cross-platform.md "Environment branches"**
- **Finding:** NA does not name `write_environment_skip` / `Write-EnvironmentSkip`, and adds `n/a (<platform>)`, which is not in the governed outcome table.
- **Evidence:** cross-platform.md "report one `OK` row `n/a (<environment>)` with `write_environment_skip`"; script-standards-detail "Governed summary outcomes" lists only `n/a (<environment>)`.
- **Fix:** Route NA through the helper. Add a platform variant, a helper and a governed row, or reuse `n/a (<platform>)` deliberately.

**A-10 — minor — RP example vs registry draft**
- **Finding:** The node example contradicts the registry draft, and the registry note's prediction contradicts RP.
- **Evidence:** RP node rule "preferred `node@22` is keg-only"; registry draft macOS preferred `"package": "node@24"`; registry note "[r]eplace would remove `node` and then fail the post-check" (RP now blocks this as REPLACE-BLOCKED).
- **Fix:** Align the versions and update the note to REPLACE-BLOCKED.

**A-11 — minor — §1 "environment" vs glossary.json "environment"**
- **Finding:** The draft defines the governed term as `local` or `claude-code-web`. The governed definition is broader (Cursor cloud agents, claude.ai...).
- **Fix:** Say "environment value (API: `local` | `claude-code-web`)" rather than redefining the term.

## B. Duplication

**B-01 — major — /tool-adopt SKILL §5 vs /tool-registry SKILL step 2 (draft)**
- **Finding:** Two onboarding checklists that disagree.
  - tool-registry adds "tool skill" and "evaluation provenance file".
  - tool-adopt adds the dotprofile template row, the deployment types table and the auth check.
- **Evidence:** tool-registry draft step 2 "(the `/tool-adopt` checklist): setup scripts, installer step, build pipeline copy block, tool skill, check script entries, CLAUDE.md entries, evaluation provenance file"; tool-adopt §5 lists a different set.
- **Fix:** Keep the checklist only in /tool-adopt §5 (the union). tool-registry step 2 says only "per `/tool-adopt` step 5".

**B-02 — major — schema in decision tree §6 + tool-registry SKILL "Schema" + registry `meta.schemaNotes`; none in the rule**
- **Finding:** The same schema is in three places, and the three-layer convention puts it in the rule.
- **Evidence:** framework-three-layer-governance.md "Schema": "Entry schemas are registry-specific, documented in the rule"; draft tool-registry SKILL "Field rules ...: `@reference/tool-support-decision-tree.md` section 6"; registry draft `meta.schemaNotes`.
- **Fix:** Make §6 the single authority. Make the SKILL table and `schemaNotes` pointers, not restatements. Either add a one-line rule pointer ("schema: decision tree §6") or amend the convention, and say which in the batch.

**B-03 — minor — tool-lifecycle.md draft "Tool support decision tree" items 1-6 restate decision tree §2**
- **Finding:** This duplication is acceptable for a rule, but item 1's ACTION text differs from the reference.
- **Evidence:** rule "`run /tool-eval <tool>`" vs §3 "`run /tool-eval <slug> -- no <platform> method`".
- **Fix:** Use one string, or have the rule say "ACTION per the reference".

**B-04 — minor — shared/skills/aitool-eval/SKILL.md (user reference card) is derived from /tool-eval**
- **Finding:** The draft changes to the /tool-eval health criteria (green = "latest release of its update channel"; yellow = pinned/LTS end-of-support) and to Recommend/Hand off will leave the card stale.
- **Evidence:** aitool-eval.md "Derived: content is extracted from source files at authoring time"; card "Step 7: Recommend", "Step 8: Hand off".
- **Fix:** Add the card refresh to the batch.

**B-05 — minor — profile.json `overrides` vs new `profiles.<alias>.toolExceptions`**
- **Finding:** Two neighbouring concepts for "intentional deviation", with no cross-reference.
- **Evidence:** user-repo.md "`overrides` -- intentional deviations from upstream tool defaults".
- **Fix:** For M3, add one sentence to §8 separating them.

## C. Ambiguity and tree completeness

**C-01 — major — mermaid T4**
- **Finding:** There is only a "fail, tool runs" edge. Update failed and the tool no longer runs (a broken upgrade) reaches no leaf.
- **Fix:** Add `T4 -- fail, tool broken --> T7` (T7 then reports BELOW-MIN or NOT-ON-PATH), or an UPDATE-BROKEN ERROR leaf.

**C-02 — major — T7 / `tool_version` "version unknown"**
- **Finding:** No leaf covers a binary that resolves but whose version probe fails or prints nothing. The T7 rule says "the version probe must run", but the four T7 edges do not cover that failure.
- **Fix:** Add a VERSION-UNKNOWN leaf (proposed: ERROR, because a binary that cannot report a version is not verified), or fold it into BELOW-MIN with its own detail text.

**C-03 — major — DRY-RUN**
- **Finding:** DRY-RUN has no node in the tree. §1 defines "interactive" as excluding dry run, so a non-preferred install in dry run reaches HOLD (log_warn, WARN), not DRY-RUN "would ... ask". The DRY-RUN row says OK, while HOLD's warning would auto-promote it.
- **Fix:** Put a dry-run gate before every acting node (I, T4, R1, R3, exception write). State that a dry run reports the leaf it would reach and writes nothing (proposed: detail `dry-run: would <verb>`, category as the real leaf).

**C-04 — major — §8 exception `path` semantics**
- **Finding:** It is not defined whether `path` is the PATH-resolved command path or the realpath. Probes use realpath (§5). With realpath, a kept brew `node` goes stale on every `brew upgrade` (Cellar/<ver>) and a kept nvm install on every `nvm use` (`~/.nvm/versions/node/<ver>/`), so the menu reappears. Windows and macOS (APFS) paths are case-insensitive, and the bash comparison is not.
- **Fix:** Store the PATH-resolved command path (stable symlink). Match case-insensitively on windows/macos. Match by method id for user-managed methods (nvm/volta/goenv), or allow a directory glob.

**C-05 — major — §6 `install.<platform>[].kind`: `system` / `bundled` as preferred**
- **Finding:** `tool_install` "builds the command from kind + package". No install or update behaviour is defined for `system` or `bundled`, yet the registry draft makes node `image-provided` (`kind: system`) preferred in claude-code-web. When that binary is absent, the tree reaches `I` with nothing to run.
- **Fix:** Define "system/bundled: not installable. Absent = PREREQ-style ERROR `not provided by <environment>`", and require `autoUpdates: true` or the `vendor-auto` channel for these kinds.

**C-06 — major — §4 `lts` / pinned channel line moves**
- **Finding:** When /tool-eval moves the preferred package to a new line (node@24 to node@26), the old line's formula matches no method, so every machine's managed install becomes `unknown`. Unknown is never removed and gets `[i]nstall alongside`. The live evidence already exists: registry draft note "node@22 22.22.3 is installed ... keg_only" on nobul-mac, a line covered by no method in the draft.
- **Fix:** Require that a line move keeps the old line as a `preferred: false` method with `detection` and `removal` (for example `brew-uninstall:node@24`). Add a check-pre-commit item for it. Add this to /tool-eval step 7.

**C-07 — major — §6 / T1: no Linux package-manager family**
- **Finding:** `platform` is governed as "Linux is further distinguished by package-manager family (apt, dnf)". The schema distinguishes only `environments`, so an apt-preferred method on a dnf machine ends at PREREQ ERROR.
- **Evidence:** glossary.json "platform"; aitool-eval card "Distro detection: apt vs dnf vs pacman vs apk".
- **Fix:** Add `install.linux[].family` (absent = any) to T1's matching rule, or record "Linux = apt family only" as an explicit decision.

**C-08 — major — T1 with `environments`**
- **Finding:** "Absent = every environment" means a default method plus an environment-specific override both match in claude-code-web, so T1 reports more than one preferred method and NO-METHOD. The only workaround is listing every environment.
- **Fix:** Let the most specific match win (an explicit `environments` beats absent), or state that every preferred method on a platform with an override must list its environments, and add that to check 1.

**C-09 — major — §6 `update` keys "method ids or `all`"**
- **Finding:** Method ids repeat across platforms in one tool today (claude-code `native` on two platforms; vercel-cli `npm` three times). One `update.<id>` cannot carry different per-platform commands.
- **Evidence:** registry claude-code methods `['native','homebrew','native-powershell','native-cmd','winget','native','npm']`.
- **Fix:** Require method ids unique per tool across platforms, or key `update` by `<platform>.<method>`. Add the rule to check 3.

**C-10 — major — `knownPaths` "verified" entries (T3, `tool_known_path_hit`)**
- **Finding:** T3 uses "each verified `knownPaths` entry", but string entries carry no verification marker. The existing formats mix `~`, `%USERPROFILE%`, absolute paths and rust-cargo's objects with `verified`. The draft adds `{token}` syntax without migrating the old forms.
- **Evidence:** registry `python.knownPaths.macos ["~/.local/bin/python3", ...]`, `rust-cargo.knownPaths.windows [{"verified": "2026-03-11 (v3.01)", ...}]`; script-standards "KnownPaths empirical verification".
- **Fix:** Define the knownPaths 1.1 shape (`{path, verified}` with tokens) and its migration, or make T3 treat every string as verified and say so.

**C-11 — minor — §7.3 menu prompt line for the unknown case**
- **Finding:** The choice line still shows `[r/k/x]` when `[i]` replaces `[r]`.
- **Fix:** Specify `Choice [i/k/x]`. Also note that the mermaid edges "(non-preferred only)" and "(unknown only)" define which letter is valid; `r` typed at an unknown menu = HOLD.

**C-12 — minor — HOLD ACTION under `--force` in a terminal**
- **Finding:** The ACTION "run aitools install in a terminal" is wrong when the user is already in one.
- **Fix:** Use "run aitools install in a terminal without --force".

**C-13 — minor — REPLACE-BLOCKED log text when RP fails on "same realpath"**
- **Finding:** The log says "would not resolve on PATH", but the real cause is that there is no separate copy. Detection order should prevent this case; if it occurs, it signals misdetection.
- **Fix:** Use a distinct reason string per RP sub-check.

**C-14 — minor — governed "detection"**
- **Finding:** glossary.json defines detection as "The second layer of three-layer governance: hooks firing in real-time". The drafts use it for (1) install-method signatures (the registry field) and (2) a pre-commit check ("§9 Detection: pre-commit conformance check"), which is not a hook. A pre-commit script is not the Detection layer by the framework table ("Hooks firing in real-time").
- **Fix:** Retitle §9 "Pre-commit conformance check". File a `TODO(glossary):` for "install detection" as a qualified term (the field name predates this, from `nonPreferredMethods.detection`).

**C-15 — minor — HOLD and EXCEPTION/KEEP skip T7**
- **Finding:** A kept or held copy below `minVersion` or in `blocked` still reports WARN/OK.
- **Fix:** Run the version half of T7 for kept and held copies (BELOW-MIN stays ERROR), or record that decision explicitly.

**C-16 — minor — `[i]nstall alongside` outcome loop**
- **Finding:** After `[i]` the first run is SHADOWED ERROR. Every later interactive run re-classifies the unknown copy and shows the menu again.
- **Fix:** Document this, or offer to record a "keep, preferred installed" exception after `[i]`.

**C-17 — minor — §6 `lifecycle.environments.<env>`**
- **Finding:** It is not platform-qualified. An entry for `local` would override every platform's status.
- **Fix:** Restrict it to non-`local` environments, or document the semantics.

## D. Implementability and safety

**D-01 — blocker — §7.5 script shape under `set -euo pipefail`**
- **Finding:** `tool_support_run "go" "go"; rc=$?` aborts the script under `set -e` whenever the tree returns 1 or 2. The tool-specific steps and the exit footer never run, which goes against Standard 2 and the exit footer rule. Return 2 survives only by accident. Inside the function, any helper returning non-zero outside an `if`/`||` context also aborts (for example `tool_preferred_method` returning 1 or 3).
- **Evidence:** script-standards-detail Standard 2 "`set -euo pipefail` kills the script on failure before `write_summary` runs"; the existing pattern in `aitools-install.sh` `validate_and_run` is "`bash "$script" || script_rc=$?`".
- **Fix:** Use `rc=0; tool_support_run "go" "go" || rc=$?`. State that every helper with a non-zero "normal" return is called in a conditional context, and gate tool-specific post-config on `rc -eq 0`, not only `rc -ne 2`. The current shape runs GOPATH steps after NO-METHOD.

**D-02 — blocker — §6 `removal` `path:<dir>` (sudo)**
- **Finding:** No guard is specified. A registry typo or token expansion (`path:{home}`, `path:{brew_prefix}`, an empty `{gopath}`) becomes `sudo rm -rf` of a home or prefix directory.
- **Evidence:** §6 "`path:<dir>` (sudo when not owned)". Today's single instance is hard-coded (`setup-go.sh` "`sudo rm -rf "$CLEANUP_TARGET"`" with `CLEANUP_TARGET="/usr/local/go"`).
- **Fix:** Specify the guards `tool_remove` must check:
  - (a) the detected binary's realpath is inside `<dir>`;
  - (b) `<dir>` is not `/`, `$HOME`, `/usr`, `/usr/local`, `/opt/homebrew`, a `{brew_prefix}` root, or any token root;
  - (c) every token expands to a non-empty value;
  - (d) `<dir>` is not a symlink;
  - (e) the last path segment matches the tool, or there is an allowlist.

  Log the exact command at warn before running it.

**D-03 — blocker — registry draft vs its own schema (§6) and checks (§9)**
- **Finding:** The draft violates its own enum and checks:
  - `"kind": "-"` on 13 methods, but "-" is not in the §6 kind enum.
  - node `image-provided` (preferred in claude-code-web) has no `update.image-provided`, no `autoUpdates: true`, and the channel is `lts`, so it fails check 2.
  - `"detection": "path:_unverified"` fails check 3.
- **Evidence:** registry draft methods list: `('macos','nodejs-org-pkg','-')`, `('linux','image-provided','system')`; §9 checks 2-3.
- **Fix:** Make `kind` optional (or allow `null`) for `preferred: false` methods and say so in §6. Give image-provided `autoUpdates: true` or a channel override. Keep the M4 placeholders out of anything that is run through the checks.

**D-04 — major — §5 Windows detection order and `winget list` matching**
- **Finding:** Path-only probes ordered before package-database probes misclassify installs:
  - Chocolatey's `nodejs-lts` and `golang` packages wrap the vendor MSI, so the binary lands in `%ProgramFiles%\nodejs` / `Program Files\Go`. In registry order `nodejs-org-msi` / `msi` (path-only) come before `chocolatey`, so a choco install is classified MSI with `removal: null`, and the choco recipe never runs. (That the choco packages wrap the MSI is unknown/unverified here; trial it.)
  - `winget list` also lists ARP entries it can correlate to a source package, so a nodejs.org MSI may match `winget:OpenJS.NodeJS.LTS` and be classified preferred. (Unverified; trial it.)
  - The existing `Get-GoProvenance` passes `--accept-source-agreements`; the §5 probe omits it, and first-run winget prompts.
- **Evidence:** registry draft node windows order `winget-lts, winget-current, nodejs-org-msi, nvm-windows, chocolatey`; draft note "detection order (preferred first) separates it from a plain MSI at the same path"; `aitools-lib.ps1` `Get-GoProvenance`.
- **Fix:** Order rule: package-database probes (winget/choco/scoop/brew/dpkg/pkgutil) before path-only probes, regardless of registry order. Require a trial-verified classification table per method in the /tool-eval output. Add `--accept-source-agreements` to the winget probe.

**D-05 — major — removal of `winget-current` when `winget-lts` shares `%ProgramFiles%\nodejs`**
- **Finding:** The recipe `winget-uninstall:OpenJS.NodeJS` after installing LTS into the same directory could uninstall the product that now holds LTS. RP's realpath-differs check probably blocks it, but only by accident; the reason logged would be misleading (C-13).
- **Fix:** Note that methods sharing an install directory get `removal: null` unless a trial proves the recipe is safe.

**D-06 — major — §5 `path:` probe "realpath" under bash 3.2 and on PowerShell**
- **Finding:** Both sides lack a defined way to resolve the real path:
  - macOS `/bin/bash` 3.2 has no `realpath` builtin. `realpath(1)` and `readlink -f` exist only on recent macOS releases (versions unknown here).
  - On PowerShell, "-like on the resolved path" is undefined for junctions and symlinks (nvm-windows symlinks into `%ProgramFiles%\nodejs`, as the registry draft note says).
- **Fix:** Name the implementation (perl `Cwd::abs_path` on bash; `[IO.Path]`/`ResolveLinkTarget` on PS 7). Add a test-matrix row with a symlinked binary.

**D-07 — major — §7.4 exit-2 contract incomplete**
- **Finding:** The `aitools` entry point collapses any installer non-zero to 1 and prints "Completed with errors". Exit 2 never reaches the user as an abort.
- **Evidence:** `scripts/aitools` install path "`if [ $installer_rc -eq 0 ] ... else log "Completed with errors ..." "error"; overall_rc=1`".
- **Fix:** Add `scripts/aitools` / `aitools.ps1` to §7.4 (propagate 2, print "aborted by user"). Say whether `validate_and_run` writes its "script failed (exit 2)" ERROR row (proposed: no).

**D-08 — major — §4 and §6 `update.<method>` strings vs §5 "The registry never holds shell code to evaluate"**
- **Finding:** `update` values are shell command strings (`"brew upgrade node@24"`), plus prose for custom kinds (`"custom: tool_custom_update in setup-go.sh replaces ..."`). If `tool_update` runs them, the registry holds executed shell code. The generated `.sh` spec is sourced, so registry text with a `'` breaks out of `TOOL_METHODS='...'`.
- **Fix:** Have `tool_update` build the update from `kind` + `package` (as `tool_install` does), with `update.<method>` kept for display and check 6. Require the generator to shell-quote every value and reject control characters. Check 2 should not count prose as an update path.

**D-09 — major — §8 profile selection fallback**
- **Finding:** Machine matching falls back to "hostname match, then first profile". A machine without `machineAlias` would write its exception into another machine's profile.
- **Evidence:** user-repo.md "Machine matching -- ... Fallback: hostname match, then first profile."
- **Fix:** The writer refuses the first-profile fallback (treat it as "no dotprofile": warn + ACTION `aitools user init`). The reader ignores exceptions whose `platform` differs from the current one.

**D-10 — major — §7.1 spec files for the MDM path**
- **Finding:** "embedded by `build-deploy.sh`" is the only mention. The deploy scripts must also inline every `tool_*` helper (`inline_lib_*`), and today's installer skips tool setup scripts in MDM ("setup-go.sh not found — skipping (MDM deploy)"). It is unknown whether the tree runs in MDM at all.
- **Evidence:** deploy-paths.md "MDM path ... self-contained"; `aitools-install.sh` Step 17.
- **Fix:** State MDM scope (in or out). S3-Nine is editing `build-deploy.sh` now, so sequence this after it.

**D-11 — major — check 9 false positives**
- **Finding:** `rm -rf` appears in legitimate temp cleanup, and the go linux custom update must replace `/usr/local/go` (go.dev's documented `rm -rf /usr/local/go && tar ...`).
- **Evidence:** `setup-google-chrome.sh` "`rm -rf "$deb_dir"`".
- **Fix:** Limit check 9 to removal of tool install locations, or route custom-update replacement through a library helper and allowlist that.

**D-12 — minor — §3 summary detail limits**
- **Finding:** `shadowed by <dir>` puts a path in the summary ("No file paths (those go in log lines)"). `<ver> (kept <method>)` can exceed 30 characters (`24.13.1 (kept homebrew-current)` = 31). Silent truncation by `tool_report` hides that.
- **Fix:** Use `shadowed (see log)` and short method labels, and make the check flag over-length templates.

**D-13 — minor — §5 probe `npm-global` / `uv-tool`**
- **Finding:** Each needs its manager to run, and npm needs node, which may be the tool being replaced (node itself). Fine as a non-match, but D-01's conditional-context rule must cover it.

**D-14 — minor — `script-url` kind**
- **Finding:** It executes a remote installer chosen by registry text.
- **Fix:** Require https, an official-domain match with `source`, and the /tool-eval provenance record, as check 6.

## E. Intent statements

**E-01 — minor — registry `meta.intent` not updated (D-TS9)**
- **Finding:** The scope still reads "NOT lifecycle gates or onboarding checklists (.claude/rules/tool-lifecycle.md)", but the checklist moved to /tool-adopt, and purpose now includes detection, removal and channels.
- **Evidence:** registry `meta.intent.scope`.
- **Fix:** Draft a `meta.intent` change in the schema 1.1 batch.

**E-02 — minor — generated spec files have no intent header (D-TS9)**
- **Evidence:** §7.1 example header "# GENERATED from the tool registry (/tool-registry) -- do not edit".
- **Fix:** The generator emits `# intent:` with purpose, scope and audience (consumers: `tool_spec_load`, the build-deploy embed).

**E-03 — minor — interactive-menus.md new intent**
- **Finding:** Scope says "Menu behaviour and defaults only", but the file also defines JSON field-level review semantics (auto-adopt, granularity).
- **Fix:** Add "and the JSON field-level review contract" to scope. The other intents pass (they have purpose, scope with NOT, and specific audience). The tool-lifecycle and tool-adopt intents use "tool support decision tree" and "supported" (registry status) without a pointer in the purpose line; acceptable because the scope cites the reference.

## F. JSON drafts

**F-01 — major — registry draft node linux**
- **Finding:** The draft silently changes `platformStatus.linux` from `supported` to `evaluating` and drops the current preferred `nodesource-or-nvm` entry. The `_draft.verification` text mentions only go linux.
- **Evidence:** live registry node `"linux": "supported"`, method `nodesource-or-nvm`.
- **Fix:** List the status change as an explicit commander decision (M4).

**F-02 — major — registry draft go**
- **Finding:** go has no `knownPaths`. On Linux, `/usr/local/go/bin` is often off PATH, so T3 misses and `I` reinstalls over the existing preferred tarball.
- **Fix:** Add a verified `knownPaths.linux ["/usr/local/go/bin/go"]` with the proposal.

**F-03 — minor — registry draft tokens**
- **Finding:** nvm-windows uses `{userprofile}\AppData\Local\nvm\*` although `{localappdata}` exists. The nvm-windows default `NVM_HOME` is unknown (unverified; the draft says the same).

**F-04 — minor — framework-registry entry draft**
- **Finding:** Artifact strings carry annotations ("reference/tool-support-decision-tree.md (new)"), which will fail any existence check on artifact paths. The list omits `scripts/check-pre-commit.ps1` (parity) and the spec generator.
- **Fix:** Use plain paths, and add the missing ones.

**F-05 — minor — glossary terms draft**
- **Finding:** Valid against glossary.json fields (`definition`, `source`, `sourceDiscipline`). "update channel" says "Every aitools install run", but `aitools` (sync) also runs the installer.
- **Fix:** Use "every installer run".

---

## I. INCIDENT: repo deficiencies (not draft problems)

- **INCIDENT I-1 (high): tool setup scripts ignore dry run.** `aitools-install.sh` runs `setup-go.sh` and the other tool scripts with `AITOOLS_DRY_RUN=1` exported, but they never read it; only the `setup-user-*`, `setup-cursor-ide-mcp` and `setup-google-chrome` scripts do (grep of `scripts/`). A dry run therefore installs, upgrades and, in `setup-go.sh`, runs `sudo rm -rf /usr/local/go`. Evidence: `aitools-install.sh` "`if $DRY_RUN; then export AITOOLS_DRY_RUN=1; fi`"; `setup-go.sh` has no DRY_RUN reference.
- **INCIDENT I-2 (high): user abort does not stop the run.** Exit 2 from `[x]abort` (`prompt_diff_review`, `prompt_json_field_review` "exit 2") is treated as a generic failure. `validate_and_run` / `Invoke-ValidatedScript` continue, and `scripts/aitools` reports it as "Completed with errors". interactive-menus.md "only `abort` is global (stops the run)" is not true in practice.
- **INCIDENT I-3 (medium): a cross-reference points to a missing section.** `.claude/rules/managed-file-deployment.md` cites `@.claude/rules/tool-lifecycle.md` "Deployment pattern updates", which exists only in `.cursor/rules/tool-lifecycle.mdc`. The draft rewrite does not add it.
- **INCIDENT I-4 (medium): Cursor rule mirrors drift.** `.cursor/rules/tool-lifecycle.mdc` and `interactive-menus.mdc` already differ from the `.md` rules (the .mdc has "Dotprofile priority" and "Deployment pattern updates"). The drafts widen the gap, and `.cursor/rules/*.mdc` is protected.
- **INCIDENT I-5 (medium): the drafts re-carry open incident #65.** "Tool onboarding checklist and /tool-registry skill require a 'CLAUDE.md deploy list' entry that no longer exists". tool-adopt §5 still says "`CLAUDE.md` deploy list".
- **INCIDENT I-6 (low): cross-platform.md "One script per tool (D-ENV0)" names helpers that do not exist.** It cites `install_via_brew` / `install_via_apt`, which are absent from `aitools-lib.sh` (function list). The tree's `tool_install` would be the real home; say so in the batch.
- **INCIDENT I-7 (low): registry shapes are inconsistent.** `knownPaths` has three shapes; `update` keys include platform names (`bash.update.windows`); `platformStatus` holds `None` and `supported (source build)`.
- **INCIDENT I-8 (low): sources-of-truth.md lists JSON paths.** It names `registries/*.json`, while governed-data-access.md says rules "MUST NOT reference JSON file paths". This tension pre-exists; the draft extends the tool-registry row.
- **INCIDENT I-9 (low): glossary pointers are stale.** glossary.json "managed tool" points at `reference/tool-registry.md` (the draft fixes this), and the /glossary skill reads the stale `reference/glossary.json` path (known from the mission brief).

## Checks passed (spot-verified)

- The mermaid tree's other paths all reach a leaf. The menu letters r/i/k/x do not collide within one menu.
- The rule draft is about 100 lines and directive. No draft rule names a governed JSON path.
- The new skill has its trigger directive in the rule and a detection hook spec (framework-adoption.md step 7). The hook is unbuilt; track it via `/incident` when filing is allowed.
- D-TS1..9 are each reflected: D-TS9 is partial (E-01, E-02); D-TS3's "verify it resolves" is now enforced by RP.
- All three JSON drafts parse (python `json.load`).
