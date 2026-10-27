# S3-BuildPkg-Lang: implementation language and tooling for build-package

Author: S3-BuildPkg-Lang (level 2, delegated by S3-BuildPkg), 2026-10-26.
Read-only evaluation. No code, no commits, no installs, no registry writes.

## Summary (5 lines)

1. Recommend one bash script, `scripts/build-package.sh`, with one function per package kind (`intune`, `pkg`, `deb`) chosen by capability, not by OS. It is the second bash-only build-script exception after build-deploy.sh, and it needs two new rows in protected `cross-platform.md` (drafted below).
2. Build hosts: `.intunewin` on Windows (IntuneWinAppUtil.exe, run from Git Bash), `.pkg` on macOS (pkgbuild/productbuild), `.deb` on Ubuntu (dpkg-deb). One CI workflow can build all three, as three native jobs on the runners check.yml already uses (macos-14, ubuntu-latest, windows-2022).
3. Logging: source aitools-lib (`logging_init`), not a second `blog` override. script-standards requires the framework, and the `blog` override is a documented exception for build-deploy only.
4. Lifecycle: IntuneWinAppUtil is a third-party download and needs `/tool-eval` Phase 1, a protected registry entry, and the Phase 2 gate before any integration code. pkgbuild/productbuild/dpkg-deb ship with the OS (nothing to install). Do not adopt nfpm. The rules have no category for build-host-only tools (INCIDENT below).
5. Checks: add pre-push step 11 that stages the payload (`--stage-only`) under an isolated HOME. Leave native package builds to CI. Renumber the "1-10" skip label in both check-pre-push files.

## 0. Sources read

- Mission packet, S3-BuildPkg brief, every `.claude/rules/*.md` (in context), user rules.
- `scripts/build-deploy.sh` L1-120 and its structure (grep of functions and `# ===` banners).
- `scripts/check-pre-push.sh` (full), `scripts/check-pre-commit.sh` L95-121 and its step ids, `scripts/check-post-push.sh` step list and L200-279, grep of `check-pre-push.ps1`, `check-pre-commit.ps1`, `check-post-push.ps1` and `aitools.ps1` for build-deploy calls.
- `.github/workflows/check.yml` (full; the only workflow file).
- `tests/` layout (deploy-harness, deploy-harness-mdm, logging, managed-files, profile, rules-fanout-cursor).
- `reference/script-standards-detail.md` L60-179 and the exemptions table at L1156-1162; `reference/tool-evaluation-criteria.md` L96-179; `reference/tool-support-decision-tree.md` L1-623 (the section 7 bash 3.2 rule and the `kind` enum); `reference/logging.md` grep.
- `/tool-registry` skill (loaded), then a read-only python read of `registries/tool-registry.json` following the skill's step 1; glossary entry "managed tool" (`registries/glossary.json` L219-221, read via grep; the `/glossary` skill was not invoked).
- S3-MdmPkg outputs (grep for packaging terms).

Not read: the `reference/cross-platform-detail.md` body (only the rule summary in cross-platform.md), `reference/plan-execution-detail.md`, `reference/tool-evaluation-playbook.md` beyond a grep, and the open PRs. Not run: anything on Windows or Linux, and no packaging tool.

## 1. Language options

### Criteria and what each option scores

| Criterion | (a) bash-only `build-package.sh` | (b) `.sh` + `.ps1` pair | (c) bash orchestrator + per-OS backend scripts | (d) Python / Go / PowerShell-only |
|---|---|---|---|---|
| D-ENV0 "one script per tool" (cross-platform.md "One script per tool") | One script. Kind backends are functions inside it, chosen by capability | Conforms to the letter: the rule is "one `.sh` ... paired with one `.ps1`" | Violates it unless the split is recorded as an exception ("A script may be split only when its OS paths share almost nothing; record the split as an exception"). The backends share staging, versioning and the manifest, so the split does not qualify | Python: one file, but no `.ps1` pair, so it needs the same exception as (a). Go: a new toolchain. PS-only: no `.sh` pair |
| Cross-language approval (cross-platform.md "Cross-language script calls require explicit approval") | Needed only where a `.ps1` invokes it (a check-pre-push.ps1 step). Precedent: build-deploy row, approved 2026-02-17 | None needed | Same as (a), and more call sites | Python: harness python is called from bash/PS1 already (check-hook-parity.py, ait-harvest.py), but not for build scripts |
| script-standards (framework, block order, exit footer, `--help`) | Sources aitools-lib: full framework, counters, `write_summary`, exit footer | Twice the code. The PS1 twin would only re-shell to pkgbuild/dpkg-deb, which do not exist on Windows | As (a), spread over several files | Python/Go: no aitools-lib, so logging must be rebuilt (script-standards: "Do not define inline copies") |
| bash 3.2 (decision tree section 7: "The 3.2 rule covers every bash script the harness runs") | Must hold. The lib is already 3.2-bound. A local Mac may run `/bin/bash` 3.2 | Same for the `.sh` half | Same | n/a |
| Windows Git Bash | Git Bash is the harness-managed bash on Windows (cross-platform.md "Windows: managed bash"). It can launch IntuneWinAppUtil.exe directly. Arguments need `cygpath -w` (PkgWin to confirm the exe's path parsing) | The PS1 half would run natively | Same as (a) | PS-only runs natively everywhere pwsh is (pwsh is a managed tool), but it breaks the bash build precedent |
| "Simple, minimal" and "favor standard library" (user CLAUDE.md "Code Style Defaults") | Thin glue over the OS packagers. Nothing new | Doubles maintenance for no output difference: the same argument build-deploy.sh L22-26 makes | More files, more moving parts | Python stdlib could write a `.deb` (ar + tar) on any host. It cannot write a flat `.pkg` (xar/Bom/cpio) or a `.intunewin` (AES needs a third-party module). So the native-host requirement stays |
| CI testability | `bash -n` and the syntax loops in check.yml already cover `scripts/*.sh` in all three jobs. A `--stage-only` mode is testable on every runner, and each runner can build its native kind | Twice the tests | As (a) | Python: check.yml already py_compiles `scripts/*.py` |

### Recommendation: (a), with (c)'s separation inside one file

`scripts/build-package.sh`, bash only:

- `--kind intune|pkg|deb|all` (default: the kinds this host can build), `--stage-only`, `--out <dir>`, `--help`, and `--dry-run` if the plan wants parity with the other scripts (`AITOOLS_DRY_RUN`).
- Stage 1 (works on any host): assemble the payload tree and the version stamp from the chosen input (see open question Q1). This is what CI tests on all three runners.
- Stage 2, one function per kind: `package_intune`, `package_pkg`, `package_deb`. Each first checks its tool by capability (`command -v pkgbuild`, `command -v dpkg-deb`, a verified path for IntuneWinAppUtil.exe) and branches on that, never on `$AITOOLS_PLATFORM` (cross-platform.md "Dead code from platform guards": "branch on capability (`command -v pwsh`) not identity"). A missing tool for a requested kind is `log_error` plus an ERROR row and an ACTION. For a kind that was not asked for, it is an OK row `n/a (<host>)`. It is never a silent skip.
- No standard OS guard: it must run in Git Bash for the intune kind, like build-deploy (cross-platform.md "OS guard exemptions": build scripts).

Why not (b): a `.ps1` twin would duplicate the staging and call no tool the bash script cannot call. build-deploy.sh's own header (L22-26) gives this reasoning for not having a twin. Why not (d): no language removes the native-host requirement (above). Python or Go would add a second logging stack, which script-standards forbids for reusable scripts.

### Exception rows to draft (protected: `.claude/rules/cross-platform.md`, commander approval required)

Approved exceptions table (needed only if a `.ps1` calls it, e.g. a check-pre-push.ps1 step 11; section 5):

```
| `build-package.sh` | Build step run on build hosts (developer machines, CI), never on endpoints; one staging path for three package kinds; the kind tools are native executables that Git Bash can launch | <approval date> | `& $bashExe "$path/build-package.sh"` (bashExe = the Git Bash known-path lookup used by check-pre-push.ps1) |
```

OS guard exemptions table, Build scripts row:

```
| Build scripts | `build-deploy.sh`, `build-package.sh` | See cross-language exceptions |
```

The rationale differs from build-deploy's. build-deploy's output is platform-independent and committed (header L22-26). build-package's output is per-OS, uncommitted binary artifacts. The plan writers should not copy build-deploy's justification text.

## 2. Build hosts

| Package | Tool | Host it must run on | Local | GitHub Actions runner already in check.yml |
|---|---|---|---|---|
| `.intunewin` | IntuneWinAppUtil.exe (Microsoft Win32 Content Prep Tool) | Windows (brief: "a Windows .exe"; PkgWin to confirm there is no supported non-Windows build) | Jose's Windows 11 machine, from Git Bash | `windows-2022` (check.yml L330-331) |
| `.pkg` (unsigned, flat) | `pkgbuild` / `productbuild` | macOS only | Jose's Mac | `macos-14` (check.yml L25-26) |
| `.deb` | `dpkg-deb` | Debian/Ubuntu. Also a Claude Code web Linux container, which is Linux (cross-platform.md "Environment branches": `claude-code-web` exists only on Linux) | Ubuntu VM or container | `ubuntu-latest` (check.yml L225-226; which Ubuntu release that label resolves to today is unverified here) |

Can one workflow build all three? Yes, as three jobs (or a 3-entry matrix), each building its native kind and uploading the result. A single job cannot: no runner has all three tools. Recommendation:

- A new workflow, `.github/workflows/package.yml`, triggered by `workflow_dispatch` (and later by a release tag). Three jobs mirror check.yml's runners, and each runs `bash scripts/build-package.sh --kind <native>`. A final job, or a manual step, gathers the artifacts. Keep `check.yml` for validation: add only a `--stage-only` step, plus the native kind's build as a smoke test once the tool is approved, to each existing job.
- New external dependencies to evaluate: `actions/upload-artifact` (check.yml uses only `actions/checkout@v4`), and how the windows job gets IntuneWinAppUtil.exe (a pinned download with a hash check, or another method `/tool-eval` chooses). Both are install or recommend decisions under the user CLAUDE.md "Tool & Source Evaluation" gate.
- The repo is public (brief, Session Commander's notes). Artifacts from a public repo's workflow can be seen by others. Who can download them, and whether the payload may contain anything personal, is unknown here. See Q1: CI has no dotprofile (check.yml L176 "expected on CI without user profile"), so CI can only package shared content.
- bash on CI: macos-14 uses Homebrew bash 5 (check.yml L31-39). build-package must also pass under `/bin/bash` 3.2. Add a 3.2 step like the profile tests (check.yml L131-132).

## 3. Logging

Recommend: source aitools-lib and call `logging_init "build-package"`, the setup-script block order in script-standards.md ("Block order (bash reusable scripts)"), minus the standard OS guard (exempt as a build script).

- script-standards.md "Logging framework is required -- raw `echo` ... is not acceptable in reusable scripts", and "All helpers are defined in aitools-lib ... Do not define inline copies."
- The `blog` functions are a recorded exception for one script: script-standards.md "Standalone build logging" and script-standards-detail.md L160-163 "Logging overrides" (`scripts/build-deploy.sh` | `blog`, `blog_ok`, `blog_error` | "Standalone build tool; doesn't source aitools-lib.sh"). build-deploy reads the lib as text to inline it (`inline_lib_bash`, build-deploy.sh L124-145). build-package has no such reason not to source it.
- Copying `blog` would require a new row in the protected exemptions/overrides table, and the `blog` functions do not count errors (build-deploy.sh L43-46: no ERRORS counter). That conflicts with script-standards.md "Error and warning tracking requirement". Note: build-deploy's `blog_warn` (L45) is missing from the detail table's list (L163 lists blog, blog_ok, blog_error). This is a minor doc drift, not filed.
- Log file: `logging_init` writes `$AITOOLS_LOG_DIR/deploy.log` (aitools-lib.sh L658-661). logging.md section 3 wants a file per component (L53-66). Options: (i) use deploy.log for v1 (no lib change); (ii) add a `build-package.log` row to logging.md and a lib way to pick the file. Suggested: (i) now, (ii) as a follow-up if build logs crowd deploy.log. In CI and pre-push, set `AITOOLS_LOG_DIR` to a temp dir (the check-pre-push.sh step 7 pattern, L184).
- Summary rows: one `write_summary` row per kind (OK `<file name>` / ERROR / `n/a (<host>)`). This follows script-standards.md "Every code path (success AND failure) must call `write_summary`".

## 4. Tool lifecycle for the packaging tools

What the rules say:

- Glossary "managed tool": "A CLI tool, dependency, or build tool with an entry in the tool registry (/tool-registry skill). Each is installed through the tool support decision tree (a setup script, or an installer step that owns it inline), platform and environment lifecycle tracking, and a corresponding user skill." (registries/glossary.json L220).
- tool-lifecycle.md "Bundled dependency graduation": "If a bundled tool becomes a project requirement (USO, standing order, or widespread script dependency), it MUST graduate to a full managed tool."
- Precedent: everything build-deploy.sh needs on the build host (node, perl, bash) is a registered managed tool. Registry read: `node`, `perl`, `bash` have `platformStatus` supported on all three platforms. `perl` linux/macos and `bash` linux use method `system`, and `bash` windows uses `bundled`. But all three are also endpoint tools. NASM/CMake are build prerequisites in `buildPrereqs` (rust-cargo entry) and `check_build_prereqs` (aitools-lib.sh L2973-3000), without their own registry entries.
- The onboarding checklist (tool-lifecycle.md "Onboarding checklist") and Phases 3-5 (tool-evaluation-criteria.md L164-171) assume an endpoint tool: a setup script, an installer step, a build-deploy copy block, and a Managed CLI Tools row. None of these fit a tool only the build host needs: installing pkgbuild or IntuneWinAppUtil on every fleet endpoint would be wrong.

INCIDENT: (governance ambiguity) No spec exists for build-host-only tools, which a repo build script needs but endpoints never get. The glossary definition counts "build tool" as a managed tool, and the graduation rule forces graduation for "widespread script dependency". Yet the lifecycle phases 3-5 and the onboarding checklist require endpoint integration (setup script, installer step, build-deploy copy block, Managed CLI Tools row), which is wrong for IntuneWinAppUtil, pkgbuild/productbuild and dpkg-deb. Affected: `.claude/rules/tool-lifecycle.md`, `reference/tool-evaluation-criteria.md`, `reference/tool-support-decision-tree.md` section 6 (schema has no build-host marker). Suggested resolution: add a "build-host tool" class: registry entry plus `/tool-eval` evaluation plus the Phase 2 gate, then a build-host acquisition step (CI workflow step, or a check in the build script) instead of Phases 3-5. Alternative: treat them as `buildPrereqs` of a pseudo-entry for build-package. Discovered while evaluating task 4. Audited: tool-lifecycle.md, tool-evaluation-criteria.md L96-179, tool-support-decision-tree.md section 6, glossary L219-221, registry read.

Per tool, recommendation (pending the incident's resolution):

| Tool | Nature | Recommendation |
|---|---|---|
| IntuneWinAppUtil.exe | Third-party (Microsoft) executable download, Windows only. Whether winget or another manager carries it is unknown here (PkgWin) | Full `/tool-eval` Phase 1 and the Phase 2 gate. Hard blocks and yellow flags apply (publisher org, last release, signature) |
| pkgbuild / productbuild | Ship with macOS in `/usr/bin`, believed part of the base OS (PkgMac to confirm they need no Xcode/CLT) | Nothing to install. Check presence in build-package (`command -v`). Record the decision in the plan. Register as `kind: system` only if the incident resolution says build-host tools get entries |
| dpkg-deb | Part of the `dpkg` package, which is present on every Debian/Ubuntu system (PkgLinux to confirm in the container images) | Same as pkgbuild |
| nfpm | Third-party Go binary (GoReleaser project) | Do not adopt. dpkg-deb covers the Ubuntu-only scope (brief: "Linux (Ubuntu)"), and user CLAUDE.md "favor standard library over third-party when the gap is small" applies. Adopting it would mean a full lifecycle on Linux and macOS for no gain until RPM is in scope |

Steps the executing mission must do before integration code:

1. `/tool-eval` for IntuneWinAppUtil. Read the official docs with chrome-devtools (web-sources.md; Firecrawl is deprecated per the packet). Write `reference/evaluations/intunewinapputil-windows-<date>.md` (tool-evaluation.md "Gates": "Every install method decision MUST be documented in `reference/evaluations/`"). Set health flags per platform.
2. Draft the registry "Under Evaluation" entry (windows `evaluating`; macos and linux `n/a`) through `/tool-registry`. Present it for review: it is a protected file (sources-of-truth.md).
3. Phase 2 gate (tool-lifecycle.md "Phase 2 gate", hard stop): install on a Windows build host, give the commander a test command (for example, IntuneWinAppUtil on a folder holding one `.ps1`, quiet mode), and wait for explicit approval. Do not batch this approval with Phase 3+ work. Until then, write no code that calls IntuneWinAppUtil. The Under Evaluation guard (tool-lifecycle.md) lists setup scripts, installer entries, aliases, build-deploy entries and the CLAUDE.md table. build-package is not named there, but the gate's "before writing integration code" covers it.
4. For pkgbuild/productbuild/dpkg-deb: record in the plan that they are OS-provided and checked by capability (no install). Get the commander's answer on the incident above before adding registry entries.
5. Get commander approval for the two `cross-platform.md` rows (section 1). Cross-language calls need it: "ask the user, get approval, document the exception".
6. Evaluate `actions/upload-artifact` and the IntuneWinAppUtil acquisition step in CI before adding them (user CLAUDE.md gate).
7. Not needed: a Managed CLI Tools row in `shared/claude-shared.md` and CLAUDE.md, an `aitools-install` step, or a `build-deploy.sh` copy block. These are endpoint artifacts, and the incident resolution should state this explicitly.

## 5. Check-script integration

Current pattern (sources):

- pre-commit step 2 runs `bash -n` on staged `.sh` files, and step 3 "Build freshness" rebuilds with `--fix` (check-pre-commit.sh L103-121). Step ids run 1-20 and later (grep).
- pre-push step 7 rebuilds into a temp copy of the dotprofile under an isolated HOME. It runs only when deploy-relevant sources changed (regex at L123), then dry-runs three generated scripts (L107-229). The PS1 twin calls build-deploy.sh through a Git Bash known-path lookup (check-pre-push.ps1 L127-132, L186). Steps are 1-10, and the no-commits path prints `step_skip "1-10"` (check-pre-push.sh L40; check-pre-push.ps1 L37).
- post-push step 7 runs `bash build-deploy.sh` and then diffs `deploy/` (check-post-push.sh L204-211). Ids go up to 32, with letter suffixes (17b, 22a, 22b).
- CI pairing checks only `scripts/setup-*` (check.yml L197-220; post-push step 11, L257-279). So a bash-only `build-package.sh` trips no pairing check.

Recommendation:

- Add pre-push step 11, "package staging": when package-relevant sources change (`scripts/build-package.sh`, the deploy sources in step 7's regex, the package templates), run `build-package.sh --stage-only` under an isolated HOME and `AITOOLS_LOG_DIR`, with `< /dev/null`. Reusing step 7's fresh build output (`$d7_tmp/dot/deploy`) as input avoids a second rebuild. That means running step 11 before step 7 removes `$d7_tmp`, or moving the cleanup. PASS when staging succeeds and the manifest validates; SKIP when no relevant change; FAIL otherwise. Add the PS1 twin step through the Git Bash lookup (this is the call that needs the approved-exceptions row).
- Do not build native packages in pre-push. Most hosts lack two of the three tools, and builds are slow. CI does that (section 2).
- Update the "1-10" skip label to "1-11" in both check-pre-push.sh L40 and check-pre-push.ps1 L37. Keep both twins identical (cross-platform pairs). Check ids are bare integers in order. New steps take the next number; letter suffixes are used only for sub-checks of an existing step.
- Add `tests/build-package/test-build-package.sh` in the existing `tests/<area>/test-<area>.sh` pattern. Run it in all three check.yml jobs (stage-only), plus once with `/bin/bash` 3.2 on macos-14.
- pre-commit: nothing new. Step 2 already covers `scripts/*.sh`.

Observation, not filed: post-push step 7 (check-post-push.sh L204) runs `bash build-deploy.sh` with the real HOME and config, so it rebuilds the real dotprofile `deploy/`. The packet forbids this for agents ("Never run ... build-deploy.sh against the real HOME"). It is likely related to #86/#140. Whoever touches check-post-push should check whether it is tracked.

## 6. Open questions (with suggested answers)

- Q1. What does the package carry: the personalized dotprofile `deploy/` (built locally from Jose's profile), or a shared-only build that CI can produce from the public repo? Suggested: v1 packages the dotprofile `deploy/` and is built locally, because a fleet profile is a dotprofile. CI builds shared-only test packages to prove the pipeline. Either way, the parent should decide this: it determines whether CI artifacts are ever deliverables.
- Q2. Does the build-host tool class need registry entries for OS-provided tools? Suggested: no for pkgbuild/productbuild/dpkg-deb (`kind: system` would carry no install data), yes for IntuneWinAppUtil. Record the rule via the incident above.
- Q3. Is `--kind all` on one host ever meaningful? Suggested: the default builds every kind this host can build, and each other kind gets an OK `n/a (<host>)` row.
- Q4. Package version source: unknown here. `scripts/aitools --version` exists (post-push step 4). Suggested: reuse it so all three packages share one version string.

## 7. WRITE_BLOCKED

None.
