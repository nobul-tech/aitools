# S3-BuildPkg report: build-package, a parallel package-based distribution of aitools

Author: S3-BuildPkg (orchestrator, level 1 under Session Commander 10cf255a-c). Date: 2026-10-26.
Version 1.0 working documents are in `plans/build-package/`. This folder holds the delegates' files, the shared brief and the decisions contract.

## 1. Summary (5 lines)

1. **Design.** build-package ships the PUBLIC aitools tree at a pinned git ref, never the dotprofile `deploy/`. The package runs the existing dev-path installer from that payload (a new `--phase system|user` and `--package-mode`), so a fleet package carries no personal data and adds no third copy of setup logic. build-deploy.sh and the MDM path are untouched.
2. **Answers.** The language is one bash `scripts/build-package.sh`, with each kind built on its native host: `.pkg` on macOS, `.intunewin` on Windows through Git Bash, `.deb` on Ubuntu. One CI workflow runs three jobs. One `Architecture: all` `.deb` covers Ubuntu 24.04 and 22.04.
3. **Run context drives the design.** Windows: a System Win32 app with no winget CLI (Microsoft: "not supported in the system context") plus a dependent User Win32 app. macOS: the pkg postinstall runs as root, then the user phase runs as the console user through `launchctl asuser` + `sudo -u`, with a LaunchAgent fallback when no one is logged in. Linux: postinst only lays down files; `aitools-setup` runs as the user, or as root in containers.
4. **Delivered.** design.md, implementation-plan.md (batches B0-B14 with letter suffixes), remediation.md (118 items: 3 critical) and doc-edits-pending.md. Also the scaffolding (`build-package.sh` CLI with dry-run, `packaging/` launcher stubs, a 36-case test) and the supported platforms/environments docs.
5. **Review.** An independent reviewer returned APPROVE WITH CHANGES (0 blocking, 13 should-fix, 8 nits). All are fixed and pushed. The commander has 7 decisions to make (P-1..P-7, section 5).

## 2. Commits pushed to main (nobul-tech/aitools)

| SHA | What |
|---|---|
| 0ddd127 | Brief + the ten wave-1 review/research files |
| 8953371 | Decisions contract BP-1..BP-20, batch IDs |
| 568fb5b | Scaffolding: build-package.sh, packaging/, tests/build-package/ |
| 5494d93 | Plan set (design, implementation-plan, remediation, doc-edits-pending) + supported platforms/environments docs |
| 32bf20c | cross-platform.md, deploy-paths.md, deploy-paths.mdc (after PR #99 merged) |
| 99740cc | Independent review verdict |
| 57e5b54 | Review fixes F1-F13, N1-N8 |
| 4cb6379 | Merge of origin/main (MERGE-ALL had merged #99, #101, #105). `pull --no-rebase` as the Session Commander instructed; no conflicts |

## 3. Files created or changed

**Created:**
- `plans/build-package/design.md`
- `plans/build-package/implementation-plan.md`
- `plans/build-package/remediation.md`
- `plans/build-package/doc-edits-pending.md`
- `scripts/build-package.sh`
- `packaging/macos/{postinstall,aitools-pkg-run.sh,tech.nobul.aitools.firstrun.plist}`
- `packaging/windows/{install-system,install-user,detect-user}.ps1`
- `packaging/linux/{control.in,postinst,aitools-setup}`
- `tests/build-package/test-cli.sh`
- This folder: the brief, decisions, ten wave-1 files, the reviewer verdict and this report.

**Changed:**
- `README.md` and `CLAUDE.md`
- `reference/cross-platform-detail.md`: the new authoritative "Supported platforms and environments" section; `cursor-cloud` marked proposed.
- `reference/harness.md`
- `reference/tool-evaluation-criteria.md`
- `ROADMAP.md`: a build-package row; dnf moved out of the Linux scope.
- `.claude/rules/aitools-workspace.md`
- `.claude/rules/cross-platform.md`
- `.claude/rules/deploy-paths.md`: the third, package path and an Equivalence list of seven reported differences.
- `.cursor/rules/cross-platform.mdc` and `.cursor/rules/deploy-paths.mdc`
- `shared/cursor-rules/user-rules.md`

**Not edited:** any file an open PR owned at the time. Those changes are drafted in doc-edits-pending.md. No existing script was edited.

## 4. Answers to the commander's questions (detail: design.md section 3)

- **Language:** bash. It is the second bash-only build-script exception after build-deploy.sh, with one function per kind. It needs the cross-platform.md exemption rows (P-1). A .sh/.ps1 pair would duplicate staging for no output difference. No other language removes the native-host requirement. (Lang)
- **One Linux package or one per release:** one. The payload is scripts. `Depends: bash, perl, python3, git, curl, ca-certificates` exist in both archives with no version floor that matters. pwsh and node are not Depends: neither is in the archives at a usable version, so the user phase installs them. (PkgLinux 1-2, Launchpad API data)
- **Build hosts:**
  - pkg: macOS only. pkgbuild/productbuild; a test build ran on this Mac.
  - intune: Windows only. IntuneWinAppUtil is the only official tool (needs .NET Framework) and is subject to a /tool-eval + Phase 2 gate.
  - deb: Ubuntu, dpkg-deb.
  - CI: macos-14, windows-2022 and ubuntu-24.04 jobs. `stage` runs anywhere.
- **Coexistence with build-deploy.sh:** fully parallel. build-package never calls build-deploy, and the dev and MDM paths are unchanged. Equivalence with the dev path holds by construction, with seven reported differences, now in deploy-paths.md. (BP-2)
- **MDM-PKG questions:**
  - Q1 = a package (public tree).
  - Q2 = fleet.
  - Q3 = Intune + Jamf.
  - Q4: updates are version-driven per channel (Win32 supersedence plus HKLM detection; pkg version plus stub-app version; Jamf Smart Group on a VERSION extension attribute; apt).
  - Q5: yes, overwrite managed files with backups, but only once per version, not on a schedule. Fix the backup-every-run defects.
  - Q6: never run the winget CLI in SYSTEM. Machine-wide prerequisites ship as separate Intune apps. User phase: `--scope user --exact --source winget`, per tool through /tool-eval.

## 5. Open questions (surfacing duty), each with a suggested answer

- **P-1:** approve the cross-platform.md exemption rows (bash-only build-package.sh; a "package launchers" category, including their exit policy). *Suggested:* approve. The rows are drafted in doc-edits-pending item 3.
- **P-2:** environment value `cursor-cloud`. It would be set explicitly by the Cursor `environment.json` install command, with the `/run/cursor/api.sock` socket (preview API) as a secondary signal. No documented env var exists (PkgLinux 5). *Suggested:* approve, and verify on one Cursor cloud run.
- **P-3:** fleet content tiers (`fleet` vs `harness` hooks, skills and MCP servers) and a neutral fleet CLAUDE.md template. Today a fleet user without a dotprofile gets Jose-specific hooks and MCP servers and literal `{{PROFILE_NAME}}` tokens (RevSetup 3). *Suggested:* approve. standing-order-guard and the failure-mode hooks stay `harness`.
- **P-4:** IntuneWinAppUtil as a build-host tool, plus a new "build-host tool" lifecycle class. The rules have no such class (Lang INCIDENT). *Suggested:* approve; run /tool-eval before batch B9.
- **P-5:** Intel Macs unsupported on the package path in v1 (the Homebrew .pkg is Apple Silicon only). *Suggested:* approve.
- **P-6:** dotprofile for fleet users. *Suggested:* in v1, `aitools user init` is run interactively once.
- **P-7:** your personal "I work on both Windows 11 and macOS" line in the dotprofile template. *Suggested:* change it to the five-item form (text in doc-edits-pending item 10).
- **Also open:** the `.deb` Maintainer address. It is a personal email in a public package. *Suggested:* a team or noreply address.
- **Follow-up now possible:** #101 and #105 have merged. Doc-edits-pending items 6 (claude-shared.md), 8 (logging.md) and 9 (glossary) can be applied once their OLD texts are re-verified against the merged files. Item 7 (decision tree) still waits on #106.

## 6. INCIDENT markers (not filed; remediation.md section "INCIDENT candidates" has 45 drafts)

Highest:
- INCIDENT (critical): build-deploy embeds the build-time dotprofile's identity, template and rules as the fallback for endpoints without a dotprofile. A fleet `deploy/` would give every user Jose's identity (RevBuild; RM-1).
- INCIDENT (critical): there is no spec and no helper for running as root/SYSTEM on behalf of a console user, and no guard. setup-user-* run as root configure the wrong account and report OK (RevLib, RevSetup, RevTools, RevInstall; RM-39).
- INCIDENT (critical for a fleet): the user-level session hooks run `scripts/ait-harvest.py` from whatever repo is the cwd (session-archive.sh L63-64, session-catchup.sh L45-46; RM-56, verified by me).
- INCIDENT (high): bootstrap.ps1:48 runs the installer under Windows PowerShell 5.1, which the library does not support (verified). An unknown installer flag exits 0 (`aitools-install.sh` L47-51, L76; verified by the reviewer).
- INCIDENT (high): setup-user-claude.sh:178 expands `$SHELL` under `set -u`, so it crashes in containers (verified).
- INCIDENT (medium): `show_summary` dedups rows by tool name, so a tool's extra OK rows vanish from the panel (verified, aitools-lib.sh `show_summary`).
- INCIDENT (medium): no spec covers build-host-only tools (Lang).
- INCIDENT (medium): the registry marks Linux supported for uv, go, typst, pwsh and node with no Linux method (RevTools; overlaps issue #19).
- INCIDENT (medium): RM-47. No code enforces the 2026-10-26 decision that a dotprofile push from a non-main branch is an ERROR. Now scheduled in B5b/B5d.
- INCIDENT (low): `.claude/rules/cross-platform.md` (now about 209 lines) and `deploy-paths.md` (about 170 lines) exceed the 40-100-line guideline.

## 7. Delegates and how I verified them

| Delegate | Role | Output | Verification by me |
|---|---|---|---|
| RevBuild | build-deploy, deploy-harness review | RevBuild-findings | Read deploy-harness.sh L175-192 (git work-tree guard) |
| RevInstall | entry points/installers | RevInstall-findings | grep bootstrap.ps1:48 `powershell` |
| RevLib | libraries | RevLib-findings | grep `AITOOLS_LOG_DIR` aitools-lib.sh:72 |
| RevSetup | setup-user-* | RevSetup-findings | grep setup-user-claude.sh:178 `$SHELL` |
| RevTools | tool setup scripts | RevTools-findings | grep: `Test-IsAdmin` has no callers |
| PkgWin | Intune Win32 | PkgWin-notes | Its winget quote was not in its captures, so I re-fetched the page (WebFetch): verbatim match |
| PkgMac | macOS pkg, Intune, Jamf | PkgMac-notes | Read the summary; the test build is in its scratch |
| PkgLinux | .deb, clouds | PkgLinux-notes | Checked the Cursor-socket citations in the notes |
| Lang | language/tooling | Lang-evaluation | check.yml runners match (macos-14, ubuntu-latest, windows-2022) |
| DocsInv | docs inventory | DocsInv-inventory | Checked PR file ownership myself (`gh pr list --json files`) |
| PlanWriter | design + plan | design.md, implementation-plan.md | Read design sections 1-3 and plan B3a |
| RemedWriter | remediation | remediation.md | RM-56 citation re-checked |
| ScaffoldWriter | scaffolding | build-package.sh, packaging/, test | Re-ran the test under an isolated HOME (32/32); audited `2>/dev/null` use |
| DocsWriter | doc edits | 9 files + pending | Read the CLAUDE.md, README and cross-platform-detail diffs; fixed two pre-commit step-20 path references |
| DocsApply | #99-freed rules | 3 files | Read the deploy-paths diff; fixed two points |
| Reviewer (independent; did not read the writers' notes or decisions) | /optimize-plan review | Reviewer-verdict | **APPROVE WITH CHANGES**. I confirmed F1 in code |
| Fixer | applied F1-F13, N1-N8 | 14 files | Re-ran the test (36/36); read the Equivalence diff |

**Checks:**
- check-pre-commit before each commit: only the known step 6 FAIL (a pre-existing harvesting file) and step 11 WARN (a pre-existing dotprofile `.DS_Store`).
- check-pre-push before each push: only the known step 7 FAIL (stale dotprofile `deploy/`) and a step 3 false positive (the documented placeholder `GH_TOKEN=proxy-injected`).
- I skipped check-pre-push for 8953371, which was a channel-only file.

**Not run:** any installer, setup script or package build on Windows or Linux; a Windows PowerShell 5.1 parse; the package test matrix (that is batch B12). The dotprofile was untouched (only its pre-existing `sessions/.DS_Store` change). No worktrees were created or removed.

WRITE_BLOCKED: none. Delegates reported none. Standing-order-guard refused one of RemedWriter's Bash calls (a grep containing backticks); it re-ran the grep without them.
