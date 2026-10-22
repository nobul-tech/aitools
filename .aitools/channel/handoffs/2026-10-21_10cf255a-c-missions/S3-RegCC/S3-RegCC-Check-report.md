# S3-RegCC-Check: independent verification of the Claude Code registry entry draft

S3-RegCC-Check (level 2, delegated by S3-RegCC, mission REGISTRY-CC), 2026-10-21 (pages retrieved 2026-10-22T01:09-01:11Z).

## Summary

1. I checked about 120 claims. Almost all of them match their sources. The draft diff matches live to draft exactly: 136 changed leaves, 0 mismatches (scratch `diffcheck.py`).
2. One claim is plainly WRONG. `upstreamRisks[4]` (and the evaluation's sources table) says the anthropics/claude-code repo "has no licence file". It has `LICENSE.md`: "© Anthropic PBC. All rights reserved. Use is subject to Anthropic's Commercial Terms of Service". The GitHub API reports `license: null` only because that text is not an SPDX licence.
3. Windows **red** does not follow from the /tool-eval criteria as written. A null `lastVerifiedVersion` is a yellow criterion; the red ">180 days" criterion needs a lastVerified date, and the draft borrows a tool-ops item date for it. If red stays, tool-evaluation.md requires "a linked evaluation with migration plan", and the evaluation has none. macOS yellow and Linux yellow are correct.
4. The checks you asked for: (a) see item 3. (b) npm: CONFIRMED, the setup page never uses the word "deprecat" (0 matches). (c) PowerShell tool on by default for claude.ai and Console accounts when Git for Windows is installed: CONFIRMED, verbatim. (d) Every CLI advisory is patched at or below 2.1.260: CONFIRMED. 4 of the 35 advisories are for Claude Desktop. (e) SendMessage is offered in this 2.1.307 sub-agent session: CONFIRMED (whether it works was not tested). (f) The schema lists every section the draft adds. Top-level `maintenance`, `versions.notes` and `install.deprecated[].notes` are new to the whole registry.
5. New evidence for S3-RegCC: item #26 now reproduces on macOS 2.1.307 (my probe). Item #10 (CRLF) did not reproduce. Items #5 and #24 look obsolete for this session. Two omissions to add: `CLAUDE_CODE_OAUTH_TOKEN`, and the 2.1.126 change that makes PowerShell the primary shell.

## Sources used

- Official pages via chrome-devtools: https://code.claude.com/docs/en/setup (title "Advanced setup", 01:09:59Z, every tab panel read), https://code.claude.com/docs/en/changelog (01:10:20Z), https://code.claude.com/docs/en/authentication (01:10:36Z). Captures: `.scratch/session-S3-RegCC-Check/{setup,changelog,auth}.json`.
- `curl`: release manifests 2.1.302/304/306/307 plus `.sig` (HTTP 200 for all four); formulae.brew.sh cask JSON for `claude-code` and `claude-code@latest`; `https://claude.ai/install.sh`.
- `gh api`: Homebrew/homebrew-cask `Casks/c/claude-code.rb` and its commits; microsoft/winget-pkgs `manifests/a/Anthropic/ClaudeCode/` (listing, 2.1.302 files, commits); `users/spectopo`; `repos/anthropics/claude-code` (metadata, root contents, LICENSE.md, security-advisories, 35 entries). Saved under `.scratch/session-S3-RegCC-Check/dl/`.
- Local read-only commands (output quoted below): `claude --version`, `claude doctor`, `claude --help`, `claude auth --help`, `claude auth status --json` (keys only), `ls -la ~/.local/bin/claude`, `shasum -a 256`, `codesign --verify --verbose`, `spctl -a -vv -t install`, `npm ls -g @anthropic-ai/claude-code`, `printenv PATH`, `file`.
- Repo files (worktree registry-cc; db4b3c5 is an ancestor of HEAD; `registries/` clean): `registries/tool-registry.json`, `registries/tool-ops.json`, `registries/tool-versions.json`, `reference/tool-ops-claude-code.md`, `scripts/aitools-install.sh` and `.ps1`, `scripts/check-post-push.sh`, `reference/evaluations/`, `~/.aitools/logs/deploy.log`.

## Claim table: draft entry (`S3-RegCC-claude-code-entry.json`)

| Claim (field path) | Source checked | Verdict | Evidence | Correction if WRONG |
|---|---|---|---|---|
| source = code.claude.com/docs/en/setup | setup page | CONFIRMED | Page loads, title "Advanced setup" | -- |
| install.macos[0] native command, preferred | setup page | CONFIRMED | "Native Install (Recommended)"; "macOS, Linux, WSL: curl -fsSL https://claude.ai/install.sh \| bash" | -- |
| install.macos[0].notes: launcher symlink; replaced launcher not managed; `bash -s stable` / `<version>` | setup page; `ls -la` | CONFIRMED | "the native installer manages the launcher at ~/.local/bin/claude as a symlink into ~/.local/share/claude/versions/. If you replace that launcher ... auto-update and claude update leave it in place"; "bash -s stable", "bash -s 2.1.89" | -- |
| install.macos[1] Homebrew: stable cask about a week behind, @latest tracks latest, brew upgrade, CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1, brew cleanup | setup page (Homebrew tab and Update section) | CONFIRMED | "claude-code tracks the stable release channel, which is typically about a week behind"; "set CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE to 1"; "Run brew cleanup periodically" | -- |
| install.windows[0] `irm ... \| iex`, no Administrator, stable scriptblock form | setup page | CONFIRMED | "You do not need to run as Administrator."; tab: `& ([scriptblock]::Create((irm https://claude.ai/install.ps1))) stable` | -- |
| install.windows[1] native-cmd command | setup page | CONFIRMED | Verbatim match | -- |
| install.windows[2] winget; may fail while claude runs; manifest community-submitted | setup page; winget-pkgs commits | CONFIRMED | "On WinGet the upgrade may fail while Claude Code is running because Windows locks the executable"; commits authored by spectobot | -- |
| install.linux[0].notes Alpine: bash, curl, libgcc, libstdc++, ripgrep, USE_BUILTIN_RIPGREP=0 | setup page | CONFIRMED | "requires bash and curl ... and libgcc, libstdc++, and ripgrep at runtime ... then set USE_BUILTIN_RIPGREP=0" | -- |
| install.linux[1] apt: key URL, fingerprint 31DDDE24...ECACE, stable and latest deb lines, sudo | setup page, apt tab | CONFIRMED | Key URL, fingerprint and both deb lines match verbatim | -- |
| install.linux[2] dnf: repo file, baseurl stable/latest, gpgcheck=1, gpgkey | setup page, dnf tab | CONFIRMED | Matches verbatim | -- |
| install.linux[3] apk: key path, sha256 395759c1...168b6, stable/latest repos | setup page, apk tab | CONFIRMED | "should report 395759c1f7449ef4cdef305a42e820f3c766d6090d142634ebdb049f113168b6" | -- |
| install.deprecated[0].notes: setup page lists npm under "Advanced installation options" and never calls it deprecated | setup page | CONFIRMED | "Advanced installation options ... npm"; case-insensitive grep for "deprecat" over the full capture: 0 | -- |
| install.deprecated[0].notes: changelog 2.1.15 added an npm deprecation notice | changelog | CONFIRMED | 2.1.15 (January 21, 2026): "Added deprecation notification for npm installations" | -- |
| install.deprecated[0].notes: Node 22+; same native binary through a per-platform optional dependency; upgrade with @latest, not `npm update -g` | setup page | CONFIRMED | "requires Node.js 22 or later"; "installs the same native binary ... per-platform optional dependency"; "Avoid npm update -g" | (Optional precision: on older Node, npm warns with EBADENGINE instead of failing) |
| update.native: background checks on startup and periodically, take effect on next start; autoUpdatesChannel; minimumVersion | setup page | CONFIRMED | "checks for updates on startup and periodically ... take effect the next time you start" | -- |
| update.homebrew / winget / apt / dnf / apk / npm | setup page | CONFIRMED | Every command matches the docs | -- |
| versionCheck `claude --version` | local | CONFIRMED | `2.1.307 (Claude Code)` | -- |
| systemRequirements (OS list, 4 GB+, x64/ARM64, shells, supported countries, Git for Windows optional, Node 22+ for npm) | setup page | CONFIRMED | System requirements section matches; "Native Windows ... None; Git for Windows is optional" | -- |
| systemRequirements: Git for Windows required by the harness | cross-platform.md "Windows: managed bash" | CONFIRMED | Git Bash is the "harness-managed shell for bash scripts" | -- |
| notes: `claude doctor` read-only, shows method, channel, last update attempt | setup page; `claude doctor` | CONFIRMED | "prints read-only installation and settings diagnostics without starting a session"; output "Running: native (2.1.307)", "Auto-update channel: latest", "Last update attempt: success → 2.1.307 (2026-10-21)" | -- |
| notes: channels; DISABLE_AUTOUPDATER vs DISABLE_UPDATES | setup page | CONFIRMED | "DISABLE_AUTOUPDATER only stops the background check ... To block all update paths ... set DISABLE_UPDATES" | -- |
| notes: Git Bash curl installer and WinGet from Git Bash work on Windows | none available | UNVERIFIABLE | No Windows machine; the draft itself says "not re-verified" | -- |
| delivery.macos.upstreamSource install.sh -> downloads.claude.ai/.../darwin-<arch>/claude | install.sh; cask url | CONFIRMED | install.sh:38 `DOWNLOAD_BASE_URL="https://downloads.claude.ai/claude-code-releases"`; install.sh checks the binary against the manifest checksum (lines 158-215); cask url `.../#{version}/#{os}-#{arch}/claude` | -- |
| delivery.macos.officialEndorsement: cask in homebrew/cask, autobumped by BrewTestBot, url downloads.claude.ai, 2.1.304 arm sha256 = manifest | cask JSON, .rb, commits, manifest 2.1.304 | CONFIRMED | tap `homebrew/cask`, `autobump True`; the last 10 commits are all BrewTestBot; cask arm sha `b9ac5374...78e6a` = manifest 2.1.304 darwin-arm64 | -- |
| delivery.macos.provenanceVerified: SHA-256 of 2.1.307 = manifest; codesign valid; notarized, Anthropic PBC (Q6L2SF6YDW); GPG not checked | shasum, manifest, codesign, spctl | CONFIRMED | `5b113a7752119470f1da419cb0e608af3361cae25b614216b13022093958fb2a` both; "valid on disk", "satisfies its Designated Requirement"; "source=Notarized Developer ID", "origin=Developer ID Application: Anthropic PBC (Q6L2SF6YDW)" | -- |
| delivery.windows.upstreamSource win32-<arch>/claude.exe | winget InstallerUrl | CONFIRMED | `https://downloads.claude.ai/claude-code-releases/2.1.302/win32-x64/claude.exe` | -- |
| delivery.windows.officialEndorsement: submitted by community bot spectobot via Dumplings; Publisher Anthropic PBC; 2.1.302 sha = manifest | winget files, commits, users/spectopo | CONFIRMED (precision) | Header "Created with YamlCreate.ps1 Dumplings Mod"; "Publisher: Anthropic PBC"; x64 `3AB075F7...` = manifest `3ab075f7...`, arm64 `E2C445A4...` = `e2c445a4...`; commit author name "spectobot", GitHub login `spectopo`, bio "A bot that collaborates with @SpecterShell" | Optional: "spectobot (GitHub account spectopo)" |
| delivery.linux upstreamSource linux-<arch>[-musl]; signed apt/dnf/apk repos | manifest 2.1.307 platforms; setup page | CONFIRMED | platforms include linux-x64, linux-arm64, linux-x64-musl, linux-arm64-musl; "Claude Code publishes signed apt, dnf, and apk repositories" | -- |
| health.macos yellow, reason 1: active workaround #26 on this platform | /tool-eval yellow list; my probe | CONFIRMED (now) | Yellow: "Active workaround in place for this platform". The draft's evidence was the 2.1.289 web (Linux) observation. On macOS 2.1.307, Write of `REPORT-probe.md` from this sub-agent was refused: "Subagents should return findings as text, not write report files. Include this content in your final response instead." | Cite the macOS 2.1.307 observation |
| health.macos reason 2: tool-ops "Current version" 2.1.81; items #1-#25 not re-verified past 2.1.81; step 20 warns | tool-ops-claude-code.md:17; check-post-push.sh:435-443 | CONFIRMED | "**Current version**: 2.1.81"; the highest item "Last verified" is 2.1.81; step 20 runs `grep -q "2.1.81"` on "2.1.307 (Claude Code)", which does not match, so step_warn | -- |
| health.windows flag red | /tool-eval criteria; tool-evaluation.md Gates | WRONG as justified | Red needs "Version unverified for >180 days", which needs a date. `versions.windows.lastVerified` is null, which is the yellow criterion "Version unverified (lastVerified is null...)". The 2.1.74/2026-03-13 date is the last-verified date of tool-ops item #1, not a registry version check. tool-evaluation.md: "Red flags MUST have a linked evaluation with migration plan"; the evaluation has none for Windows (only "Open items 1") | Yellow (null lastVerified, active workaround #1, stale reference). If the commander wants red, record that the ">180 days" reading uses the item #1 date, and add a Windows plan to the evaluation |
| health.windows reason 1: 2.1.74 on 2026-03-13, 222 days | tool-ops-claude-code.md:38; date arithmetic | CONFIRMED (with a conflict) | Table: "2.1.74 (2026-03-13)"; Mar 13 to Oct 21 = 222 days. The same file's "Windows Shell Limitations" section says "Last verified: 2.1.62 (2026-02-27)" (line 388), so the file contradicts itself | -- |
| health.windows reason 2: PowerShell tool 2.1.84, Git for Windows optional 2.1.120 | changelog | CONFIRMED | 2.1.84: "Added PowerShell tool for Windows as an opt-in preview"; 2.1.120: "Git for Windows (Git Bash) is no longer required". More releases bear on it: 2.1.111 (progressive rollout), 2.1.126 ("Claude now treats PowerShell as the primary shell instead of defaulting to Bash"), 2.1.143 | Optional: add 2.1.126 |
| health.linux yellow: version and provenance unverified | criteria | CONFIRMED | Null lastVerified is yellow | -- |
| evaluation.status "current" | its own pendingChanges; criteria | WRONG (inconsistent) | pendingChanges says "(until written, treat status as stale)" and lists unassessed items (#1-#25, Windows/Linux trials). Yellow criterion: "Evaluation status is stale (upstream changes not assessed)" | "stale" until the trials and the #1-#25 review are done, or drop the parenthetical. Commander's call |
| evaluation.provenance path | reference/evaluations/ | CONFIRMED (pending) | Only `google-chrome-linux-2026-10-05.md` exists; the draft says the file is not written yet | -- |
| lifecycle.dependencies: Git Bash optional since 2.1.120; ripgrep bundled (system on Alpine) | changelog; setup page; doctor | CONFIRMED | "Search: OK (bundled)"; "ripgrep: usually included" | -- |
| lifecycle.invocation.antiPatterns `npx @anthropic-ai/claude-code` | user CLAUDE.md "Managed CLI Tools" | CONFIRMED (policy) | "never use `npx`" | -- |
| versions.macos 2.1.307 / 2026-10-21 | `claude --version`; doctor | CONFIRMED | -- | -- |
| versions.notes: 2.1.307 is the newest changelog entry (Oct 21, 2026) | changelog | CONFIRMED | The first heading is "2.1.307 / October 21, 2026" | -- |
| maintenance.harness: no setup-claude-code script; Step 9 runs `claude update` or the native installer | scripts/ listing; aitools-install.sh:679-710; .ps1:623-655 | CONFIRMED | No `setup-claude*` in scripts/; .sh line 687 `claude update`, line 701 install.sh; .ps1 line 629 and line 645 install.ps1 | -- |
| maintenance.harness: setup-user-claude/settings/hooks/skills/mcp | scripts/ listing | CONFIRMED (exist) | All five .sh/.ps1 pairs exist; I did not trace what each one configures | -- |
| maintenance.lastRun.macos 2026-10-21T16:20:22Z, Step 9, 2.1.306 up to date | deploy.log:6064-6070 | CONFIRMED | 6064 "Step 9: Claude Code CLI"; 6065 "already installed (2.1.306 (Claude Code))"; 6069 "Claude Code is up to date (2.1.306)". It is the last Step 9 in the log (grep) | -- |
| workarounds item 26: summary, severity high, lastVerified 2.1.289 (2026-10-05) | tool-ops-claude-code.md:61 | CONFIRMED (copy) | HIGH table, "2.1.289 (2026-10-05)" | Can become "2.1.307 (2026-10-21, macOS)" given my probe |
| workarounds item 27: summary, high, 2.1.307 (2026-10-21) | tool-ops:62, 286-323; changelog 2.1.217/2.1.219 | CONFIRMED | 2.1.219: "Subagents can now spawn nested subagents up to depth 3 by default (was 1)" | -- |
| workarounds item 1: critical, 2.1.74 (2026-03-13), upstream changed 2.1.84/2.1.120 | tool-ops:38; changelog | CONFIRMED | CRITICAL table | -- |
| workarounds item 5: high, 2.1.74 (2026-03-13) | tool-ops:52 | CONFIRMED (copy); substance looks obsolete | This sub-agent started with ~/.claude/CLAUDE.md, concurrent-agents.md, aitools CLAUDE.md and most .claude/rules/*.md injected as "Contents of ..." system context. I did not determine whether Claude Code loaded them natively or a SubagentStart hook injected them | Note "re-verify; contradicted 2.1.307 macOS" |
| workarounds item 24: high, 2.1.74 (2026-03-24) | tool-ops:58 | CONFIRMED (copy); substance changed | This 2.1.307 sub-agent has no Glob or Grep tool in its tool list at all | Note for re-verification |
| workarounds item 25: high, 2.1.81 (2026-03-24); 2.1.77 says use SendMessage; SendMessage offered in 2.1.307 | tool-ops:60; changelog 2.1.77; my tool list | CONFIRMED | 2.1.77: "use SendMessage({to: agentId}) to continue a previously spawned agent"; SendMessage is in this session's deferred-tool list. Not called, so whether it works is unknown | -- |
| workarounds item 11: medium, 2.1.51, platforms [macos] | tool-ops:69 | CONFIRMED (copy); platform UNVERIFIABLE | tool-ops gives no platform; the cited file `setup-user-mcp.sh` serves macOS and Linux | -- |
| workarounds item 10: medium, 2.1.51, Write CRLF on macOS | tool-ops:68; `file` | CONFIRMED (copy); not reproduced | Files I wrote with Write report "ASCII text" (no CRLF) on 2.1.307 | Candidate for removal |
| upstreamRisks[0]: 2.1.304 (Oct 19) to 2.1.307 (Oct 21) | changelog | CONFIRMED | 2.1.304 October 19, 2.1.305 October 20, 2.1.306 and 2.1.307 October 21 | -- |
| upstreamRisks[1]: many high advisories; all CLI advisories patched at or below 2.1.260 | security-advisories (35) | CONFIRMED | 28 high, 4 medium, 3 low. Highest CLI patched version: GHSA-gfvf-j8jh-jxxw "patched 2.1.260". Claude Desktop, not CLI: GHSA-v234-4jrq-mgg6, GHSA-4p2j-qj3c-6x84, GHSA-5p5x-5294-qhp3, GHSA-3rwf-2g6p-c2f9. GHSA-9f65-56v6-gxw7 also covers the VS Code and JetBrains extensions | Optional: name the Desktop advisories |
| upstreamRisks[1]: channel lag (Homebrew 2.1.304, @latest 2.1.306, WinGet 2.1.302, native 2.1.307) | cask JSON; winget listing; changelog | CONFIRMED | cask 2.1.304, @latest 2.1.306 (sha = manifest b5d795...), the highest winget directory is 2.1.302 (334 versions) | -- |
| upstreamRisks[2]: harness text "always uses Git Bash" may be wrong | user CLAUDE.md; setup page; changelog 2.1.126 | CONFIRMED | User CLAUDE.md: "Claude Code on Windows always uses Git Bash (not configurable)". The docs and 2.1.120/2.1.126 contradict it | -- |
| upstreamRisks[3]: #26 undocumented | tool-ops:274 | CONFIRMED | "Not in the official docs." | -- |
| upstreamRisks[3]: #4, #16, #17 undocumented | -- | UNVERIFIABLE | tool-ops does not say these are undocumented; I did not search the docs | -- |
| upstreamRisks[4]: "GitHub repo has no licence file" | gh api contents/ and LICENSE.md | **WRONG** | Root has `LICENSE.md`: "© Anthropic PBC. All rights reserved. Use is subject to Anthropic's [Commercial Terms of Service]". `license: null` in the repo API only means no SPDX licence was detected | "Proprietary licence (repo LICENSE.md: All rights reserved, Anthropic Commercial Terms of Service; WinGet: License Proprietary)" |
| upstreamRisks[4]: WinGet License Proprietary | winget locale.en-US | CONFIRMED | "License: Proprietary" | -- |
| authentication.method / setupCommand `claude auth login` | auth page; `claude auth --help` | CONFIRMED | "you ran claude auth login in your shell"; help lists `login`, `logout`, `status` | -- |
| authentication.checkCommand, checkNotes (keys loggedIn, authMethod) | `claude auth status --json` | CONFIRMED | Keys: analyticsDisabled, apiProvider, authMethod, configDirectory, email, loggedIn, orgId, orgName, projectsDirectory, subscriptionType; loggedIn=True, authMethod=claude.ai | -- |
| authentication.refreshCommand: startup warns 3 days before expiry | auth page; changelog 2.1.217 | CONFIRMED | "within three days of expiring ... Your login expires in 3 days · run /login to renew" | -- |
| authentication.logoutCommand `claude auth logout` | `claude auth --help` | CONFIRMED | "logout  Log out from your Anthropic account" | -- |
| authentication.tokenStorage | auth page | CONFIRMED | Keychain with 0600 file fallback; Linux 0600 file; Windows `%USERPROFILE%\.claude\.credentials.json`; CLAUDE_CONFIG_DIR moves it | -- |
| authentication.envOverride | auth page | CONFIRMED (incomplete) | ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, apiKeyHelper are in the precedence list. The token from `claude setup-token` is used through `CLAUDE_CODE_OAUTH_TOKEN`, which the draft does not name | Add `CLAUDE_CODE_OAUTH_TOKEN` (set from `claude setup-token`) |
| knownPaths.macos ~/.local/bin/claude -> versions/2.1.307 | `ls -la` | CONFIRMED | `/Users/new-jose/.local/bin/claude -> /Users/new-jose/.local/share/claude/versions/2.1.307` | -- |
| knownPaths.windows/linux paths from docs, UNVERIFIED | setup page uninstall and launcher text | CONFIRMED (as docs-derived) | `Remove-Item -Path "$env:USERPROFILE\.local\bin\claude.exe"`; "On macOS and Linux, the native installer manages the launcher at ~/.local/bin/claude" | -- |
| nonPreferredMethods npm detection, absent case exit 1 "(empty)" | `npm ls -g` | CONFIRMED | Exit 1, "/opt/homebrew/lib `-- (empty)" | -- |
| pathIssues ("Fix your PATH", "Check for conflicting installations") | setup page | CONFIRMED | Both phrases are present | -- |
| platformGotchas: Bash tool on Git Bash, CLAUDE_CODE_GIT_BASH_PATH; PowerShell tool on by default for claude.ai/Console accounts with Git for Windows; no sandbox on native Windows; WinGet lock; Linux not code-signed | setup page | CONFIRMED (incomplete) | "When Git for Windows is installed, the PowerShell tool is available alongside Bash: on by default for claude.ai and Console accounts, and enabled with CLAUDE_CODE_USE_POWERSHELL_TOOL=1 in Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry sessions"; "Linux: binaries are not individually code-signed" | Add: 2.1.126 "when the PowerShell tool is enabled, Claude now treats PowerShell as the primary shell instead of defaulting to Bash" |

## Claim table: draft evaluation (`claude-code-macos-2026-10-21.md`)

| Claim | Verdict | Evidence / correction |
|---|---|---|
| No earlier Claude Code evaluation; only google-chrome-linux-2026-10-05.md | CONFIRMED | `ls reference/evaluations/` |
| Changelog facts (2.1.307 newest, 2.1.15, 2.1.84, 2.1.120, 2.1.77, 2.1.217/2.1.219) | CONFIRMED | Changelog sections quoted above |
| Sources row: anthropics/claude-code "no licence file" | **WRONG** | Same correction as upstreamRisks[4] |
| Method catalog (cask supports Linux arches; WinGet community; npm on all three platforms) | CONFIRMED | Cask `os macos: "darwin", linux: "linux"` with linux sha256 values; npm platform list on the setup page |
| Provenance block (sha, codesign, spctl, cask 2.1.304 sha, WinGet 2.1.302 shas; GPG not checked) | CONFIRMED | Command outputs above. All four manifests have a `.sig` (HTTP 200); still not verified, because gpg is absent |
| Trial block (path, version, no elevation, ~/.local/bin on PATH, doctor lines) | CONFIRMED | `printenv PATH` contains /Users/new-jose/.local/bin; doctor output matches the four quoted lines |
| Health assessment | See the table above | Windows red: WRONG as justified; macOS and Linux: CONFIRMED |
| Open item 4: docs no longer use the word "deprecated" | CONFIRMED | 0 matches on the setup page (2.1.15 changelog still says "deprecation notification") |

## Claims I could not check, and why

- GPG signature of the manifests: gpg is not installed (draft and command-not-run). The `.sig` files exist.
- Anything about Windows or Linux on a real machine (versions, knownPaths, the Git Bash curl installer, WinGet from Git Bash): there is no machine.
- Whether SendMessage actually reaches an agent in 2.1.307: I had no target and did not call it.
- The exit code of `claude auth status --json` when logged out: I did not log out.
- Whether #4, #16 and #17 are absent from the official docs: I did not search the docs.
- Item #11's platform scope: tool-ops does not say.
- What each setup-user-* script configures: I checked only that the files exist.
- Not done (disclosed): I did not read the "first five" reference files (script-standards-detail, cross-platform-detail, logging, managed-file-deployment, plan-execution-detail). They govern script and plan work, not these claims. I followed the /tool-registry and /tool-eval SKILL.md files by hand and did not invoke the skills. I used the S3-RegCC page captures only to locate tabs, not as evidence; all quotes come from my own retrieval.

## INCIDENT markers (not filed)

- INCIDENT: `scripts/aitools-install.sh:693` and `.ps1:636` match "up to date" with `already.*up.to.date|no update`. The native `claude update` prints "Claude Code is up to date (<version>)" (setup page; deploy.log:6069), so an up-to-date run logs "claude update finished" instead of "Already up to date" (deploy.log:6070). Low severity.
- INCIDENT: `reference/tool-ops-claude-code.md` contradicts itself on item #1. The table (line 38) says "2.1.74 (2026-03-13)"; the "Windows Shell Limitations" section (line 388) says "Last verified: 2.1.62 (2026-02-27)". Medium severity.
- INCIDENT: user CLAUDE.md "Note: Claude Code on Windows always uses Git Bash (not configurable)" is contradicted by the setup page and changelog 2.1.120/2.1.126 (PowerShell tool, PowerShell as primary shell when enabled). Medium severity; it propagates to every machine.
- INCIDENT: the USO "Dedicated tools for file ops" names Grep and Glob, but this 2.1.307 sub-agent has no Grep or Glob tool. Item #24's premise has changed. Low to medium severity.
- INCIDENT: the /tool-registry SKILL.md schema has no field-level definitions for `maintenance.*` (lastRun, workarounds[] item/summary/platforms/severity/lastVerified, upstreamRisks), `versions.notes`, `versions.maintenanceFile` or `install.deprecated[].notes`. The claude-code draft is the first entry to use them, so it would set the schema by example. The SKILL table also lists `overrides` as a per-tool section, while it is a top-level key (SKILL.md:78). Low severity.
- INCIDENT: changelog 2.1.143 says "The PowerShell tool is now enabled by default on Windows for Bedrock, Vertex, and Foundry users", while the current setup page says it is "enabled with CLAUDE_CODE_USE_POWERSHELL_TOOL=1" in those sessions. This is an upstream docs conflict; the draft follows the setup page. Informational.

## Schema check, item (f)

- The SKILL.md schema table (lines 81-94) lists `delivery`, `health`, `evaluation` and `maintenance`, and step 1 (lines 41-49) gives the maintenance subfields "harness, last run per platform, workarounds, upstream risks". These match the draft's sections. CONFIRMED.
- Keys no other registry entry uses (scratch `keys.py`, 18 tools, schemaVersion 1.0):
  - top-level `maintenance` (new);
  - `versions.notes` (new);
  - `install.deprecated[].notes` (new);
  - `install.deprecated` and `versions.maintenanceFile`, which only claude-code has, already in the live entry.
- `delivery`, `health` and `evaluation.pendingChanges` are also used by google-chrome and nss-tools; `authentication.checkNotes` by datadog-pup; `knownPaths[].notes` by rust-cargo.

## WRITE_BLOCKED

- WRITE_BLOCKED: Write `.scratch/session-S3-RegCC-Check/REPORT-probe.md` -- "Subagents should return findings as text, not write report files. Include this content in your final response instead." This was my deliberate item #26 probe, not retried. The content was one line ("probe for tool-ops item 26 on macOS 2.1.307").

## Files

- Report: /Users/new-jose/repos/aitools/.claude/worktrees/registry-cc/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-RegCC/S3-RegCC-Check-report.md
- Scratch evidence: /Users/new-jose/repos/aitools/.claude/worktrees/registry-cc/.scratch/session-S3-RegCC-Check/ (setup.json, changelog.json/.txt, auth.json, dl/, cl.py, fetch.sh, summ.py, winget.sh, keys.py, diffcheck.py)
