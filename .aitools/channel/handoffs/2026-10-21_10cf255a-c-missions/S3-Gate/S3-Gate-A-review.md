# S3-Gate-A review: tool support decision tree rev 3, correctness lens

**Intent**: **Purpose**: Give the commander and mission S3-Gate a rated list of correctness defects in decision tree rev 3, checked against the governing `.claude/rules/*`, plus a re-verification of the rev-2 dispositions S4-Review did not re-check, so rev 4 can fix the blockers and majors before the gate. **Scope**: Rev 3 of `reference/tool-support-decision-tree.md` (S4-Review copy) against tool-lifecycle, tool-evaluation, interactive-menus, managed-file-deployment, script-standards (and its detail reference), config-file-safety and cross-platform; leaf reachability; consistency with SD-4/SD-5/SD-6. NOT cross-platform execution and bootstrap (S3-Gate-B). NOT the sibling drafts (S3-Gate step 3). NOT filing incidents. **Audience**: S3-Gate (writes rev 4), the session commander, the commander at the gate.

## Summary

1. 16 findings: 0 blockers, 4 majors, 12 minors. Rev 3 has no blocker on this lens. The exit-2 collision (S3-Gate-B B-01) is a blocker, but it belongs to B's lens.
2. The majors are these. A-01: replace and update skip the build-prerequisite gate. A-02: dry run reports ERROR for every tool it would install. A-03: the `brew-formula` probe can never match, because `brew --prefix` returns the opt symlink (shown on this Mac). A-04: the RP guard cannot be evaluated, because the tree never says where the preferred binary lives after R1.
3. All 16 leaves can be reached, and each has one summary row and one exit code. SD-4, SD-5 and SD-6 are reflected as written. Rev 3 still marks D-TS10/11/12 and the SD-6 shape as pending, which is correct.
4. I re-checked 50 rev-2 dispositions against the rev 3 text (S5-Tools-report §7 and S5-Tools-A, minus the 5 S4 spot-checked). 43 hold. 5 hold only in part (A-03, C-03, D-04, D-06, D-11). 2 were fixed in the sibling drafts, not in the tree (B-01, B-03). None regressed.
5. Independence caveat: the Agent tool was not provisioned in this session. So S3-Gate wrote this pass and the B pass itself, as two separate passes over the tree. They are not independent reviewers. Treat the findings as one reviewer's, and spot-check them.

Reviewed: `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/S4-Review/S4-Review-drafts/reference/tool-support-decision-tree.md` (rev 3, 537 lines), read in full on 2026-10-21. "REF §n" below means that file. Sources were read at origin/main c8573ed.

## Findings

| ID | Sev | REF section | Finding | Evidence | Fix (rev 4 applies majors) |
|---|---|---|---|---|---|
| A-01 | major | §2 mermaid (R1), node rules R1/T4/P | Replace and install-alongside skip node P. The menu edges go straight to R1 ("install or update preferred FIRST"), and T4 updates without P. So a missing manager, or a missing build prereq for a `cargo-git` source build, is only found when the install command fails. The result is REPLACE-FAIL (WARN, no remedy), not PREREQ, and Layer 1 never runs before the build | script-standards.md "Build prerequisite validation" ("Call `Check-BuildPrereqs` / `check_build_prereqs` before the build ... skip the build"); REF §2 edges `M -- "[r]eplace ..." --> R1`, `T2 -- preferred --> T4`; REF node rule P is reached only from T3 | R1 and T4 run the P checks first. If R1 fails P, the leaf is REPLACE-FAIL with detail `<ver> (prereq missing)` plus the PREREQ ACTION, and the old copy is kept (it works, so WARN). If T4 fails P, it logs a warning and goes on to T7 (same as a failed update). Add both to §2 node rules and to the §10 test matrix |
| A-02 | major | §2 "Dry run" overlay, §10 | The overlay runs "every read-only node" and replaces acting nodes with a log line. T7 is read-only, so on a machine without the tool it runs after the skipped I and reaches NOT-ON-PATH (ERROR, exit 1). Likewise a skipped T4 on an old version reaches BELOW-MIN. A dry run on a fresh machine therefore reports ERROR for every tool and the installer counts failures. This contradicts "reports the leaf it would reach" and the §10 row "dry run, each class → the leaf it would reach" | REF §2 "Dry run ... runs every read-only node ... replaces each acting node (I, T4, R1, R3, exception write)"; REF T7 rule; `aitools-install.sh` exports `AITOOLS_DRY_RUN` (line 129) | After a skipped acting node, do not run T7. Report the acting node's success edge as the predicted outcome: OK `dry-run: would <verb>` (`would install`, `would update`, `would replace`), exit 0. Read-only paths with no acting node (OK, HOLD, EXCEPTION, NA, NO-METHOD, ...) keep their real leaf with the `dry-run:` detail prefix |
| A-03 | major | §5 `brew-formula` probe | "the realpath is under `brew --prefix <name>`". `brew --prefix <name>` prints the opt symlink (`/opt/homebrew/opt/node`), while the binary's realpath is in the Cellar (`/opt/homebrew/Cellar/node/26.3.1/bin/node`). As written, the probe never matches, so every Homebrew install is non-preferred or unknown | Command output on nobul-mac, 2026-10-21: `brew --prefix node` → `/opt/homebrew/opt/node`; perl `abs_path("/opt/homebrew/bin/node")` → `/opt/homebrew/Cellar/node/26.3.1/bin/node`, `abs_path("/opt/homebrew/opt/node")` → `/opt/homebrew/Cellar/node/26.3.1` | "the binary's realpath is inside the realpath of `brew --prefix <name>`, compared at a path-component boundary (`<prefix>/`)". Same component-boundary rule for `uv-tool`, `npm-global` and `path:` globs |
| A-04 | major | node rule RP, §7.2 `tool_install` | RP needs "the preferred binary's directory", but nothing defines where the preferred binary is after R1. `tool_install` returns only 0/1. For a linked Homebrew formula the binary's own directory (Cellar) is never on PATH; the directory on PATH holds a symlink. Read literally, every brew replace stops at REPLACE-BLOCKED. Read loosely ("the symlink's directory"), the implementer must guess | REF RP rule; REF §7.2 `tool_install` "0 installed and binary verified / 1 failed"; A-03 evidence (Cellar vs `/opt/homebrew/bin`) | `tool_install` / `tool_update` (R1) print the preferred binary path: the first verified `knownPaths` entry for the method that exists, else for `brew` `{brew_prefix}/bin/<cmd>` when linked, else `{brew_opt:<formula>}/bin/<cmd>`. RP becomes: "a directory on PATH (Windows: persistent User or Machine PATH) holds `<cmd>` whose realpath equals the preferred binary's realpath, and that realpath differs from the old copy's realpath". The two sub-check reasons stay separate |
| A-05 | minor | §3 intro | "that second row is expected and `show_summary` keeps one row per tool (highest severity)". The installer's row is keyed `${name%.sh}` (`setup-go`), the script's row by its label (`go`), so `show_summary` shows both | `aitools-install.sh` `validate_and_run` (`write_summary ERROR "${name%.sh}" ...`); `show_summary` dedups by field 2 only; script-standards-detail "Tool name table" (`go` ← setup-go) | Say "the panel shows both rows (`setup-<x>` and `<label>`); expected". Or have the runners pass the label. Not applied (minor) |
| A-06 | minor | §2 "Kept / held copies" | REPLACE-FAIL and REPLACE-BLOCKED keep the old copy in use but skip the version half of T7. Only EXCEPTION, KEEP and HOLD run it. A kept-by-failure copy below `minVersion` then reports WARN. The version half also names only BELOW-MIN, not VERSION-UNKNOWN | REF row "Kept / held copies"; REF §3 REPLACE-FAIL/REPLACE-BLOCKED rows | Add REPLACE-FAIL and REPLACE-BLOCKED to the row, and say a failed probe there gives VERSION-UNKNOWN |
| A-07 | minor | §4 `pinned-major` | "installed major other than `pin` = HOLD-style WARN". This is not a leaf in §3, and it is not said whether T4 still updates or T7 still runs | REF §4 table; §3 has no pin row | Name it as a T4 outcome: no update; T7 runs; WARN detail `<ver> (pin <pin>)` + ACTION |
| A-08 | minor | §3 intro vs reference | The KEEP carry-forward ACTION without a paired `log_warn` contradicts script-standards-detail "Severity decision guide" and "ACTION items" ("Always pair with a `log_warn`") until that reference is edited | `reference/script-standards-detail.md` lines "always pair ACTION with a log_warn" (two places) | Row 16 draft (S3-Gate-drafts) adds the exemption line |
| A-09 | minor | §7.6 | `if [ "$rc" -eq 2 ]; then exit 2; fi` skips the exit footer that every setup script must end with. This is intended, but not documented as an exception | script-standards.md "Exit footer" | Row 16 draft adds the exit-2 exemption to the exit-footer section |
| A-10 | minor | §7.6 | Post-config runs only when `rc` is 0. A tool that works but is SHADOWED (rc 1) skips the auth check that script-standards requires "on every run" | script-standards.md "Post-install authentication check" | Run auth checks when the command resolves (rc 0, or the leaf is SHADOWED) |
| A-11 | minor | §8 Engine | The writer names temp → validate → backup → move, but not the diff logging and three-outcome reporting that config-file-safety requires for JSON writes, and not the managed-fields header | config-file-safety.md "Diff logging on overwrite", "Managed vs preserved fields" | "log the changed `toolExceptions.<slug>` fields (old → new); outcome created/updated; header lists `profiles.<alias>.toolExceptions.<slug>` as managed" |
| A-12 | minor | §6, §7 | The library selects registry rows by `$AITOOLS_PLATFORM` (T0, T1, the exception match). cross-platform.md "Dead code from platform guards" says to branch on capability, not identity. This is data selection, not a code branch, but the tree does not say so | cross-platform.md "Dead code from platform guards" | One sentence in §7: "Selecting registry data by platform value inside the library is data lookup, not a platform branch" |
| A-13 | minor | §7.2 | `tool_exception_get` output has no alias, but the EXCEPTION log line prints `(profile <alias>)`. `tool_exception_record` arguments omit `platform` and `by`, which §8 passes to `exception-set` | REF §3 EXCEPTION row; REF §8 Engine flags | Output `<alias>|<platform>|<method>|<path>|<decidedAt>`; the record arguments add the script base name |
| A-14 | minor | §9 checks 9 and 11 | Check 9 "not a `mktemp` result" cannot be decided statically. Check 11 "with typical values" is undefined | REF §9 | Check 9: flag literal removal commands only, with the allowlist marker. Check 11: a fixed sample table (ver `24.13.1`, platform `windows`, manager `homebrew`) |
| A-15 | minor | T2 probe order | "preferred method first" brings D-04 back when the preferred detection is path-only (Windows `msi`, Linux go tarball). A package manager that wraps the vendor installer at the same path is then classified preferred | REF T2 rule; S5-Tools-A D-04 | When the preferred probe is path-only, package-database probes run first |
| A-16 | minor | §1 D-TS table | F3 is cited as "a working tool kept as-is is WARN". HOLD follows it; D-TS10 departs from it for EXCEPTION/KEEP only. That is correct, but REPLACE-FAIL/REPLACE-BLOCKED (also "kept as-is") are not named | REF §1 F1-F4 row | Name REPLACE-FAIL/REPLACE-BLOCKED as F3 (WARN) cases |

## Leaf reachability and consistency

| Leaf | Reached from | Summary row | Exit | Consistent with |
|---|---|---|---|---|
| NA | T0 `n/a` | OK `n/a (...)` | 0 | cross-platform.md "Environment branches" |
| EVALUATING | T0 `evaluating` | WARN | 0 | D-TS12 (pending); tool-lifecycle "Under Evaluation guard" |
| NO-METHOD | T1 none/tie | ERROR | 1 | D-TS2 |
| PREREQ | P | ERROR | 1 | script-standards "Build prerequisite validation" (but see A-01: R1/T4 skip P) |
| INSTALL-FAIL | I fail | ERROR | 1 | F2; `diagnose_build_failure` |
| EXCEPTION | T5 match | OK | 0 | D-TS4, D-TS10 (pending), SD-6 |
| HOLD | T6 no; menu EOF/empty/other | WARN | 0 | D-TS3, SD-5 (non-interactive: WARN, change nothing) |
| KEEP | menu `k` | OK / WARN `(kept, not saved)` | 0 | SD-5, SD-6 |
| ABORT | menu `x` | WARN | 2 | SD-5 ("exit 2, stops the run"); see S3-Gate-B B-01 |
| REPLACE-FAIL | R1 fail | WARN | 0 | F1 |
| REPLACE-BLOCKED | RP no | WARN | 0 | D-TS3 "verify it resolves"; see A-04 |
| OK | T7 | OK | 0 | SD-4 (update then verify) |
| SHADOWED | T7 | ERROR | 1 | D-TS11 (pending) |
| NOT-ON-PATH | T7; T3 hit | ERROR | 1 | script-standards-detail "Standard 4" |
| VERSION-UNKNOWN | T7 | ERROR | 1 | -- |
| BELOW-MIN | T7; version half for kept/held | ERROR | 1 | T-Q5 |

Every leaf is reachable and writes one row (A-05 aside). The two notes (REMOVE-MANUAL, REMOVE-FAIL) correctly lead into T7. SD-4: §4 holds "every run brings a preferred install to its channel's latest and verifies it". SD-5: the menus, HOLD, the `[i]nstall` alongside option for unknown installs, and "never removed" all match. SD-6: the location, the via-based writer, and "shape pending at N-Q1" all match the handoff D.3.

## Re-verification of rev-2 dispositions (S5-Tools-report §7)

S4 spot-checked D-01, D-02, A-04, C-04 and D-07; they are not repeated here. Status: **holds** = the rev 3 text has the fix; **partly** = fixed with a gap; **sibling** = fixed in a sibling draft, not the tree.

| Disposition | Status | Where in rev 3 / note |
|---|---|---|
| A-01 parser story | holds | §7.1 three reasons; §8 node engine |
| A-02 F3 vs OK | holds | D-TS10 pending; §1 |
| A-03 two summary rows | partly | the T4 promotion holds; the "one row per tool" claim is wrong (A-05 above) |
| A-05 SHADOWED basis | holds | D-TS11 cites plan decision 10 |
| A-06 tool-ops resolution | holds | T7 rule cites B1 `managedPath` |
| A-07 all skills protected | holds (sibling) | S4 sources-of-truth draft line 32 lists the 3 tool skills only |
| A-08 generated files | holds | §7.1 `generated/tool-specs/`; companion = row 15 |
| A-09 NA helper | holds | §3 NA row |
| A-10 node example | holds (sibling) | registry draft note predicts REPLACE-BLOCKED; the version mismatch is marked illustrative |
| A-11 environment wording | holds | §1 "API value" |
| B-01 two checklists | sibling | `/tool-registry` draft step 2 points to `/tool-adopt` step 5 |
| B-02 schema in three places | holds | §6 "single authority"; C-08 (skills restate it) is fixed in S3-Gate copies |
| B-03 ACTION text | sibling | S4 rule draft item 1 "text per the reference" |
| B-04 aitool-eval card | holds | companion row 17 (void under PR-c) |
| B-05 overrides vs exceptions | holds | §8 Location |
| C-01 broken update | holds | T4 rule → T7 |
| C-02 version unknown | holds | VERSION-UNKNOWN leaf |
| C-03 dry run | partly | overlay present; T7-after-skip gap (A-02) |
| C-05 system/bundled | holds | node rule P; §4 |
| C-06 line moves | holds | §4 `lts`; check 10 |
| C-07 Linux family | holds | §1, T1, `tool_linux_family` |
| C-08 environment specificity | holds | T1 specificity rule |
| C-09 duplicate ids | holds | §6 `.method`; check 3 |
| C-10 knownPaths shape | holds | §6 `knownPaths` |
| C-11 `[i/k/x]` prompt | holds | §7.4 |
| C-12 "without --force" | holds | §3 HOLD ACTION |
| C-13 RP reasons | holds | RP rule "separate reasons" |
| C-14 "detection" naming | partly | §9 retitled; glossary item open (review page section c) |
| C-15 version half | holds | "Kept / held copies" (gap: A-06) |
| C-16 `[i]` loop | holds | "Unknown" row |
| C-17 local env status | holds | §6 `lifecycle.environments` |
| D-03 registry draft | holds (sibling) | `kind` null allowed (§6); image-provided `autoUpdates: true` (draft line 157) |
| D-04 probe order | partly | package-db before path-only; preferred-first gap (A-15) |
| D-05 shared dir removal | holds | §6 `.removal` |
| D-06 realpath | partly | perl `Cwd::abs_path` is fine; the PS1 side resolves only the last component (S3-Gate-B B-04) |
| D-08 executed update strings | holds | §6 `update` display only; §7.1 quoting |
| D-09 fallback profile | holds | §8 via-based writer |
| D-10 MDM scope | holds | §7.5 third bullet |
| D-11 check 9 false positives | partly | mktemp exclusion cannot be decided statically (A-14) |
| D-12 summary length | holds | `shadowed (see log)`, check 11 |
| D-13 conditional context | holds | §7 intro |
| D-14 script-url | holds | §6 `.kind`; check 6 |
| E-01 registry meta.intent | holds (sibling) | schema draft |
| E-02 spec intent header | holds | §7.1 example `# intent:` |
| E-03 interactive-menus scope | holds (sibling) | S4 IM intent names the JSON contract |
| F-01 node linux status | holds (sibling) | registry draft `_statusChange` |
| F-02 go knownPaths | partly-sibling | proposal has `verified: null`, so §7.1 drops it and T3 cannot use it until verified (expected, and noted on the review page) |
| F-03 nvm-windows token | left | unverified, M4 |
| F-04 framework entry paths | holds (sibling) | plain paths; check-pre-commit.ps1 and generator listed |
| F-05 glossary wording | holds (sibling) | "Every installer run" |

## INCIDENT markers (not filed)

- INCIDENT (low): `reference/script-standards-detail.md` "Summary detail text rules" says "Max 30 characters (compliance-checked)". No check enforces it. This is already S4 draft #103, so it is a duplicate and should not be filed twice.
- INCIDENT (medium): `aitools-install.sh` `validate_and_run` and `aitools-install.ps1` `Invoke-ValidatedScript` key their failure row by script base name, not by the tool name table. Every failing tool therefore shows two ERROR rows today (`validate_and_run`; script-standards-detail "Tool name table"). New; not in #87-#113 (checked against S4 §4 titles).
