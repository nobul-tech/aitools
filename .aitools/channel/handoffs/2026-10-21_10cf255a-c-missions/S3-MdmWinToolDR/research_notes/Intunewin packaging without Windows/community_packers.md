# Community (non-Microsoft) `.intunewin` packers, with focus on macOS and Linux (as of 2026-10-26)

Researcher: S3-MdmWinToolDR-Community (mission MDM-WINTOOL-DR, commander Jose). Read date for every source: 2026-10-26.

Method and reading status:
- Repo facts (owner type, stars, licence SPDX, pushed_at, releases, contributor count with `anon=1`, issues) come from `gh api` on 2026-10-26. Raw output: `.scratch/s3-mdmwtdr-community/` (scripts `repo-facts.sh`, `repo-facts2.sh`, `readmes.sh`, `pypi.sh`; READMEs saved under `readmes/`).
- Registry facts come from the NuGet search API, npm search API, PyPI JSON API and crates.io API (metadata only; nothing downloaded or installed).
- Re-read in the browser (chrome-devtools, own isolated page): the ContentPrep GPL-3.0 LICENSE, the IntuneAppBuilder Apache-2.0 LICENSE, the iamawrapper custom LICENSE (read in full), the IntuneAppBuilder.Console NuGet page, the WrapTune-MacOS tenant claim, and IntuneAppBuilder issue #53. The PowerShell Gallery page for `SvRooij.ContentPrep.Cmdlet` returned a browser error page (not read).
- READMEs were read in full for ContentPrep, IntuneAppBuilder, volodymyrsmirnov/IntuneWin, WinTuner, kenchan0130/intunewin, iamawrapper and intunewin-rs (raw README via `gh api`). For WrapTune-MacOS, LetsGoIntunePackager, lwalthert/intunewin, maxihafer/content-prep, notapkgtool, SwitchHunt, IntunewinBuilder, New-IntuneWin and IntuneGet I read keyword-matched lines only (partial read). For intunewin-mac I read the first 60 lines.
- WebSearch returned nothing relevant for two queries ("GitHub Action create intunewin ubuntu linux", "svrooij ContentPrep ..."). Discovery therefore relied on `gh search repos`, `gh search code` (`IntunePackage.intunewin`, `SvRooij.ContentPrep`, `intunewin` in `action.yml`) and the registry APIs. A search cannot prove absence.

## 1. svrooij/ContentPrep (NuGet `SvRooij.ContentPrep`, PSGallery `SvRooij.ContentPrep.Cmdlet`)

### Takeaway
A sole-maintainer, personal-account, GPL-3.0 C# re-implementation targeting net8.0 and netstandard2.0, so it runs wherever .NET runs (macOS, Linux). Its main production evidence is that the same author's WinTuner (260 stars) packages with it and publishes to Intune. Its own README warns it is not a replacement for the Microsoft tool. Last release v0.4.2 on 2025-10-03, about 12.8 months ago.

### Cited Findings
- Personal account (`owner.type: User`), 32 stars, 2 forks, GPL-3.0, created 2023-10-14, last push 2025-10-03T13:48:24Z, 0 open issues, not archived, not a fork. Description: "Open-source implementation of Win32ContentPrepTool written in C#" — `gh api repos/svrooij/ContentPrep`, https://github.com/svrooij/ContentPrep
- Releases: v0.4.2 2025-10-03, v0.4.0 2025-07-16, v0.3.0 2025-06-01. Contributors: 1 — `gh api repos/svrooij/ContentPrep/releases`, `.../contributors?anon=1`
- Licence re-read in the browser: "GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007" — https://github.com/svrooij/ContentPrep/blob/main/LICENSE.txt
- The library targets `net8.0;netstandard2.0`. Its only package dependency is `Microsoft.Extensions.Logging.Abstractions` 8.0.3. `PackageRequireLicenseAcceptance` is True. Authors: "Stephan van Rooij" — https://github.com/svrooij/ContentPrep/blob/main/src/SvR.ContentPrep/SvR.ContentPrep.csproj
- README: "I wanted to be able to use in WingetIntune without having to rely on a closed-source tool that had a dependency upon Windows. I want to run this in the cloud" — https://github.com/svrooij/ContentPrep
- README warning: "This is not a replacement for the Microsoft tool, it is a re-implementation of the tool based upon public available information. It is not feature complete and it might not work for your use case. If you need a tool that works, use the Microsoft tool. This library is provided as-is, without any warranty or support." — https://github.com/svrooij/ContentPrep
- README: "It allows you to create packages that can be uploaded to Intune and it allows you to decrypt those packages." So it packs and decodes — https://github.com/svrooij/ContentPrep
- NuGet `SvRooij.ContentPrep`: 0.4.2, 13,291 total downloads, owner `svrooij`, `verified: False` — NuGet search API `https://azuresearch-usnc.nuget.org/query?q=ContentPrep`
- Dependents: WinTuner's `WingetIntune.csproj` references `SvRooij.ContentPrep` Version 0.4.0, and the repo has `src/WingetIntune/Intune/LibraryIntunePackager.cs` — https://github.com/svrooij/WinTuner/blob/main/src/WingetIntune/WingetIntune.csproj
- Other code dependents found by code search: `jorgeasaurus/WingetIntunePublisher` (build.ps1, psd1), `jorgeasaurus/Win32Forge` (psd1), `mtniehaus/AutopilotBranding` (makeapp.ps1), `andrew-s-taylor/public` (two Intune scripts), `aollivierre` repos — `gh search code "SvRooij.ContentPrep"`
- WinTuner: personal account, 260 stars, 37 forks, GPL-3.0, 5 contributors, latest v1.4.1 2026-07-03, last push 2026-07-13. README: "Take any app from WinGet and upload it to Intune in minutes"; "Creating an `intunewin` file automatically"; "This is a beta application, it's not yet ready for production use." — `gh api repos/svrooij/WinTuner`, https://github.com/svrooij/WinTuner
- Issue history: 3 issues ever (#3 a type-initializer error, closed; #9 "SetupFile can't be outside of SourcePath", closed). No issue reports Intune rejecting a ContentPrep package — `gh api repos/svrooij/ContentPrep/issues?state=all`
- The earlier finding (S3-MdmWinTool Probe trial 5) says ContentPrep built a package on this Mac, with `ToolVersion="1.8.6.0"` in Detection.xml — /Users/new-jose/repos/aitools/plans/build-package/mdm-windows-tool-findings.md sections 3.1 and 3.2. I did not re-run it (research only).

### Inferences
- Cross-platform: plausible on macOS and Linux, because netstandard2.0/net8.0 carry no Windows-only dependency in the csproj. This is supported by the earlier Probe run on macOS. I have no direct Linux evidence.
- Intune acceptance: indirect only. WinTuner publishes to Intune with ContentPrep 0.4.0. No public issue reports a rejection, but the repo's low issue volume is weak evidence.
- Flags. Hard blocks: none (active within 24 months, no advisories seen, not a fork or typosquat). Yellow: sole maintainer, personal account, fewer than 500 stars, no release in 12+ months (v0.4.2 is from 2025-10-03, so it just crossed 12 months), GPL-3.0 copyleft, NuGet not verified, and the author's own "not a replacement" disclaimer.

### Gaps
- PSGallery download count and latest cmdlet version: the PSGallery page errored and the API returned an error. The earlier 44,510 figure is unverified.
- Security advisories: I did not query `gh api repos/svrooij/ContentPrep/security-advisories` (it needs owner permission). None are visible in the issues.
- No blog post on svrooij.io was read. WebSearch found none.

## 2. simeoncloud/IntuneAppBuilder (`IntuneAppBuilder.Console` dotnet tool)

### Takeaway
A company-org (Simeon Cloud), Apache-2.0, net8.0 dotnet tool that claims cross-platform packing and publishing, with 231.4K NuGet downloads. It has a documented Intune-rejection episode (2025-08, reporter-closed as an Intune backend change). CI runs only on `windows-latest`, so its tenant tests do not exercise macOS or Linux packing. Its last commit was 2026-05-18. The earlier facts (Organization, Apache-2.0, 72 stars, pushed 2026-05-18) re-check as correct.

### Cited Findings
- `owner.type: Organization`, 72 stars, 5 forks, Apache-2.0, created 2020-04-11, last push 2026-05-18T13:48:14Z, 3 open issues, not archived. Description: "A cross platform, Intune application packaging and deployment console tool and SDK" — `gh api repos/simeoncloud/IntuneAppBuilder`
- No GitHub releases (empty releases list). Contributors: 16 with `anon=1` (the earlier research said 12 from the API and 14 on the page; the count depends on the method) — `gh api .../releases`, `.../contributors?anon=1`
- Licence re-read in the browser: Apache License 2.0, "Copyright 2023 Simeon Cloud" — https://github.com/simeoncloud/IntuneAppBuilder/blob/master/LICENSE
- README: "IntuneAppBuilder is an open source component from the Simeon Microsoft 365 Management toolset. Learn more about Simeon's full functionality at https://simeoncloud.com." — https://github.com/simeoncloud/IntuneAppBuilder
- Install route: "Get .NET 8 SDK (or higher)", then `dotnet tool install -g IntuneAppBuilder.Console`. `pack` writes three files, including "MyAppInstallFiles.portal.intunewin - this file can be uploaded to the Intune Portal as a Win32 app" — https://github.com/simeoncloud/IntuneAppBuilder
- Non-Windows caveat (README): "When the tool is running on a non-Windows system, the tool will log a warning and continue creating the package without the additional MSI metadata." — https://github.com/simeoncloud/IntuneAppBuilder
- The Console project targets `net8.0` with `PackAsTool` true and depends on `System.CommandLine` 2.0.0-beta1.21308.1 (a 2021 beta) — https://github.com/simeoncloud/IntuneAppBuilder/blob/master/Source/Console/Console.csproj
- NuGet page (browser): "IntuneAppBuilder.Console 4.1.0", ".NET 8.0", "Total 231.4K", "Current version 2.0K", "Per day average 140", "Last updated 5 months ago", owner "simeon" — https://www.nuget.org/packages/IntuneAppBuilder.Console. NuGet API: `verified: False`, authors `['Simeon']`.
- CI (`ci.yml`): triggers on push and pull_request to master only. There is no schedule trigger now. Build, test and deploy run on `runs-on: windows-latest`. `dotnet test` gets the tenant secrets `TEST_AADAUTH_*`. Deploy pushes to nuget.org — https://github.com/simeoncloud/IntuneAppBuilder/blob/master/.github/workflows/ci.yml
- The README says the IntegrationTests "publishes real apps to a Microsoft Intune tenant" and "The tests will create and then delete apps in the target tenant" — https://github.com/simeoncloud/IntuneAppBuilder
- CI runs: master push 2026-05-18T13:48 success and 2026-05-18T13:02 success. Scheduled runs on 2026-05-14 through 2026-05-18 all failed. The PR run on 2026-05-18 failed — `gh api repos/simeoncloud/IntuneAppBuilder/actions/runs`
- Issue #53 (opened 2025-09-19, closed 2025-10-01), re-read in the browser: "As of 8th August, files generated by this tool cannot be uploaded to Microsoft Intune through the web interface or Graph API." The portal said "File format is not recognized."; Graph said `commitFileFailed`. The reporter closed it: "Closing as this seems to have been caused by a backend change on Intune's side where they have changed certain enforcements on Azure storage upload. Apologies!" No maintainer reply is shown — https://github.com/simeoncloud/IntuneAppBuilder/issues/53
- Issue #46 (open since 2024-06-30): "The IntuneAppBuider binary does not work on macOS arm". Two users report that it works on Apple Silicon with the .NET 7 SDK, or with `DOTNET_ROLL_FORWARD=LatestMajor` under .NET 8/9 (that issue predates the 2024-12 move to .NET 8) — https://github.com/simeoncloud/IntuneAppBuilder/issues/46
- Issue #54 (open since 2025-11-26): "Request to Provide Official Docker Image for IntuneAppBuilder". Issue #57 (opened 2026-10-25, open): "Packages are created without titles if trailing slash is placed at end of source directory name" — `gh api .../issues?state=all`
- Commit and PR activity: the maintainers are Simeon-named accounts (`ashek-simeon`, `mzorzella-simeon`, `rdorta-simeon`, `jeff-simeon`, `Fred-Simeon`, `admin-simeon`). Recent PRs are 2024-12 (#48-#52, .NET 8 and Azure.Storage.Blobs migration) and 2026-05 (#55, #56) — `gh api .../issues?state=all`
- kenchan0130/intunewin says "This implementation is inspired by simeoncloud/IntuneAppBuilder" — https://github.com/kenchan0130/intunewin

### Inferences
- Simeon Cloud is a real company org whose staff accounts do the commits. Low churn (gaps of 2024-12 to 2026-05) suggests maintenance mode.
- Acceptance evidence: on 2026-05-18 a push-triggered CI run passed with the tenant secrets available, so the tenant publish tests presumably passed on Windows then. This is an inference: I did not read the job log. Before that, five scheduled runs failed. #53 shows that Intune backend changes can break community-packed uploads silently for weeks. The breakage was "fixed" without any change to the tool, per the reporter.
- Cross-platform packing is claimed, and #46 gives user reports for macOS arm. No Linux report was found, and CI never runs on macOS or Linux.
- Flags. Hard blocks: none. Yellow: fewer than 500 stars, no GitHub releases (provenance is NuGet only, unverified), a 2021 beta dependency, a Windows-only CI, a 17-month commit gap (2024-12 to 2026-05), and an open macOS-arm issue. "No release in 12+ months" does not apply: NuGet 4.1.0 is about 5 months old.

### Gaps
- Whether the scheduled-run failures were caused by tenant upload failures or by something else (job logs not read).
- Why the schedule trigger was removed (no commit message read).
- Security advisories not queried.

## 3. All other packers found (inventory)

### Takeaway
About fifteen other projects write `.intunewin` without Microsoft's exe. Every one is personal or tiny (0-48 stars), and most are less than a year old. Several more projects that look like packers actually wrap `IntuneWinAppUtil.exe` and are Windows-only. No PyPI, npm or crates.io package exists that packs `.intunewin`. No GitHub Marketplace action that packs natively on Ubuntu was found. No Docker image was found (IntuneAppBuilder #54 asks for one).

### Cited Findings

**Native packers that can run on macOS and/or Linux:**

| Project | Lang / runtime | Owner | Licence | Stars | Last push | Latest release | Contributors | Packs / decodes | Platforms claimed | Intune-acceptance evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| kenchan0130/intunewin | Go | User | Apache-2.0 | 7 | 2026-10-16 | v0.0.7 2026-09-23 | 4 | pack + unpack | "Works on Windows, macOS, and Linux" | none in README |
| lwalthert/intunewin | Go | User | MIT | 3 | 2026-09-01 | none | 1 | pack (+MSI metadata) | Linux, macOS, Windows | none seen; "the majority of tests was generated by AI" |
| michelbragaguimaraes/LetsGoIntunePackager | Go | User | MIT | 5 | 2026-09-21 | v1.0.0 2025-12-04 | 2 | pack | Linux, macOS, Windows; ships a GitHub Actions example on ubuntu | claims "100% Compatible: Generates packages identical to Microsoft's official tool" (unverified, and random keys make byte-identity impossible) |
| maxihafer/content-prep | Go | User | none | 3 | 2025-03-03 | v1.0.1 2025-03-03 | 1 | pack | "pure go" | none |
| name/nexus | Go | User | GPL-3.0 | 2 | 2025-03-02 | 0.0.3 2025-03-02 | 1 | packaging + management (not read in detail) | unknown | none |
| Hardcoreprawn/intunewin-rs | Rust | User | MIT | 0 | 2026-06-22 | v0.4.0 2026-02-28 | 2 | pack | "Windows, Linux, and macOS"; store-only inner zip ("We never compress") | none in README |
| INSPIRATIONlabs/iamawrapper | Rust | Organization (INSPIRATIONLABS GmbH) | custom source-available (SPDX NOASSERTION) | 1 | 2026-08-20 | v0.2.3 2026-01-14 | 1 | create + extract (also macOS .pkg) | Win/macOS/Linux x64 and arm64 | README: "Output files are fully compatible with Microsoft Intune" (claim only) |
| thefinder808/WrapTune-MacOS | .NET 10 (Avalonia GUI + `wraptune` CLI) | User | MIT | 31 | 2026-10-01 | v2.0.1 2026-08-01 | 2 | pack, inspect, extract | macOS app; CLI "can run in CI (the engine is pure managed .NET; it doesn't even need macOS)" | "deployed to a real Intune tenant and installed on Windows endpoints (Zoom, Chrome Enterprise, PowerShell 7)"; ships an independent `tools/verify-intunewin.py` |
| volodymyrsmirnov/IntuneWin (NuGet `IntuneWinFile`) | .NET Standard 2.0 lib | User (NuGet owner `apptimized`) | MIT | 8 | 2020-10-16 | 1.0.0 2020-10-16 | 2 | create + extract | any .NET | none; "the file format is not publicly documented ... some of the features might be missing or misbehave". NuGet: 3,770 downloads |
| jorgeasaurus/IntuneHydrationKit (`Private/WinGet/New-IntuneWinPackage.ps1`) | PowerShell + .NET | User | MIT | 150 | 2026-10-27 | v1.4.0 2026-10-04 | 3 | pack (internal function, gated on `SupportsCrossPlatformIntuneWin`) | cross-platform pwsh (implied by its capability gate) | none seen; it stamps `ToolVersion` '1.4.0.0' |
| ThomasHoins/New-IntuneWin | PowerShell 5.1 + .NET | User | GPL-3.0 per API, but README says "Add the license of your choice here" | 0 | 2026-10-20 | none | 1 | pack, verify, unpack | "Windows PowerShell 5.1 ... PowerShell 7 has not been tested" (effectively Windows) | "A package created by this script was successfully uploaded through the Intune admin center for a script-based Win32 app (Install.bat). MSI packages and large packages have not been tested." |
| AlecDusheck/intunewin-mac | Python | User | none | 0 | 2026-09-22 | none | -- | pack, inspect, extract, publish | Apple Silicon Mac | none; repo description: "You probably shouldn't use this." |
| autopkg/iancohn-recipes (`IntuneWinCreatorBase.py`) | Python AutoPkg processor | Organization `autopkg` (community recipe org; author Ian Cohn) | Apache-2.0 header in the file; repo licence null | 1 | 2026-10-22 | none | -- | pack (stamps `TOOL_VERSION = "1.8.7.0"`) | macOS (AutoPkg) | none seen |
| deadarcher/SwitchHunt | TypeScript, in-browser WebCrypto | User (RFF) | MIT | 48 | 2026-10-20 | v1.1.0 2026-08-30 | 1 | builds `.intunewin` in the browser | any browser | README: "uploadable straight to Intune" (claim only) |
| bradhawkins85/MyPortal (`app/services/intunewin.py`) | Python app | User | AGPL-3.0 | 0 | 2026-10-27 | v0.10.0 2026-10-27 | -- | packing service inside a portal app (not read) | unknown | none |

Sources: `gh api repos/<owner>/<repo>` and `/releases` and `/contributors` (2026-10-26); READMEs via `gh api .../readme` at https://github.com/kenchan0130/intunewin, https://github.com/lwalthert/intunewin, https://github.com/michelbragaguimaraes/LetsGoIntunePackager, https://github.com/maxihafer/content-prep, https://github.com/Hardcoreprawn/intunewin-rs, https://github.com/INSPIRATIONlabs/iamawrapper, https://github.com/thefinder808/WrapTune-MacOS (tenant and CI quotes re-read in the browser), https://github.com/volodymyrsmirnov/IntuneWin, https://github.com/ThomasHoins/New-IntuneWin, https://github.com/AlecDusheck/intunewin-mac, https://github.com/deadarcher/SwitchHunt; code: https://github.com/jorgeasaurus/IntuneHydrationKit/blob/main/Private/WinGet/New-IntuneWinPackage.ps1, https://github.com/autopkg/iancohn-recipes/blob/main/IntuneProcessors/IntuneLib/IntuneWinCreatorBase.py; NuGet API for `IntuneWinFile`.

- iamawrapper LICENSE (read in full in the browser). It grants "Use the Software to package your own applications" and "internal business operations". It forbids: "a) Use the Software to build, create, or provide a Competing Product". "Competing Product" includes "Software packaging or deployment tools", "Mobile Device Management (MDM) solutions", "Endpoint management platforms" and "Software distribution services". Also: "This License terminates automatically if You violate any of its terms." — https://github.com/INSPIRATIONlabs/iamawrapper/blob/main/LICENSE
- New-IntuneWin documents a failure mode: "The outer ZIP entries must use ZIP method 0 (stored) ... In Windows PowerShell 5.1 (.NET Framework), `CompressionLevel.NoCompression` still writes Deflate blocks ... A package built with .NET's `NoCompression` uploaded to Intune failed with 'Your app is not ready yet'." — https://github.com/ThomasHoins/New-IntuneWin
- WrapTune-MacOS: "This proves format and cryptographic correctness. A real tenant upload remains the authoritative check for tenant-side rules." — https://github.com/thefinder808/WrapTune-MacOS

**Projects that look like packers but call Microsoft's `IntuneWinAppUtil.exe` (Windows-only packaging):**
- MSEndpointMgr/IntuneWin32App: Organization, 516 stars, MIT, 124 open issues, last push 2026-01-25, 8 contributors. The earlier research (section 3.1) found it downloads and runs IntuneWinAppUtil.exe; I did not re-read that code — `gh api repos/MSEndpointMgr/IntuneWin32App`
- KelvinTegelaar/CIPP-API `Tools/IntuneWin/New-IntuneWinPackage.ps1` runs `Start-Process -FilePath "$PSScriptRoot\IntuneWinAppUtil.exe"` — https://github.com/KelvinTegelaar/CIPP-API/blob/master/Tools/IntuneWin/New-IntuneWinPackage.ps1
- RogerCibrian/notapkgtool (PyPI `napt` 0.12.0, Apache-2.0, 19 stars, sole maintainer). "It runs on Windows, Linux, and macOS; creating .intunewin packages requires Windows."; "Uses IntuneWinAppUtil ... for creating .intunewin packages" — https://github.com/RogerCibrian/notapkgtool, https://pypi.org/pypi/napt/json
- ugurkocde/IntuneGet (141 stars, licence NOASSERTION; npm `@ugurkocde/intuneget-packager` 1.4.2): "Packaging | GitHub Actions | Windows runner for .intunewin file generation"; "Local Packager | npm package for on-premises"; "Run the local packager on your own Windows infrastructure" — https://github.com/ugurkocde/IntuneGet
- clstrickland/Intune-Win32-Packager (composite GitHub Action, 0 stars, no licence, last push 2025-04-14). Step 1: "Download and Extract IntuneWinAppUtil.exe" from `.../Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe` — https://github.com/clstrickland/Intune-Win32-Packager/blob/main/action.yml
- rafallz10100/IntunewinBuilder (23 stars, no licence): "Native Windows 10/11 GUI application distributed as an MSI installer"; OS "Windows 10 or Windows 11". Whether it embeds the Microsoft exe is unknown — https://github.com/rafallz10100/IntunewinBuilder
- Also found and not packers (GUIs or wrappers for IntuneWinAppUtil, uploaders, decoders only): FlorianSLZ/IntuneWin32Deployer, rink-turksma/IntunePrepTool ("using the MS Win32 Content Prep Tool"), gioxx/IntuneWinAppUtilGUI, mabdulkadr/IntuneWin-Utility ("using Microsoft's IntuneWinAppUtil.exe"), imabdk/intunewin-contextprep, damienvanrobaeys/Intunewin_Create_Extract (59 stars, no licence; not read), call4cloud-code/Intunewin-Downloader-Public (downloader) — `gh search repos intunewin`

**Registries:**
- PyPI: `intunewin`, `pyintunewin`, `intunewin-py`, `python-intunewin`, `intunewinapputil`, `intune-win32`, `intunewin-tools`, `contentprep` and `notapkgtool` all return HTTP 404. Only `napt` exists, and it wraps the Microsoft exe — PyPI JSON API `https://pypi.org/pypi/<name>/json`
- npm search "intunewin": only `psadt-deploy-skill` and `@ugurkocde/intuneget-packager` (a Windows packager service) — `https://registry.npmjs.org/-/v1/search?text=intunewin`
- crates.io search "intunewin": no crates — `https://crates.io/api/v1/crates?q=intunewin`
- NuGet search "intunewin": `IntuneWinFile` 1.0.0 (3,770 downloads, owner `apptimized`) and `IntuneAppBuilder.Console` 4.1.0 (231,359). "ContentPrep": `SvRooij.ContentPrep` 0.4.2 (13,291). All `verified: False` — NuGet search API

### Inferences
- A packer that works on Linux and macOS is technically easy: about 200 lines of code using standard AES-256-CBC, HMAC-SHA256 and zip. That is why so many have appeared (most since 2025-12). None has independent third-party evidence of Intune acceptance beyond the author's own claim. The strongest author claims are WrapTune-MacOS (named apps installed on endpoints) and New-IntuneWin (one portal upload).
- Known tenant-side failure modes from the evidence: (a) a Deflate-compressed outer zip gives "Your app is not ready yet" (New-IntuneWin); (b) an Intune backend change in 2025-08 rejected IntuneAppBuilder output ("File format is not recognized", `commitFileFailed`) for about 7 weeks (#53). Packers also disagree on `ToolVersion` (ContentPrep 1.8.6.0, iancohn 1.8.7.0, IntuneHydrationKit 1.4.0.0). Microsoft's add-win32 page warns about packages from older tool versions (earlier findings section 3.4).
- iamawrapper's licence is likely incompatible with aitools' package path, depending on whether aitools counts as a "Software packaging or deployment tool" or a "Software distribution service". The use is internal, but the restriction wording is broad. This needs commander or legal judgement. I would treat it as a yellow-to-red flag (no OSI licence).

### Gaps
- No GitHub Marketplace listing was browsed directly. The marketplace search pages were not loaded, so a native Ubuntu packing action could exist there unseen.
- No Docker Hub or GHCR search was done.
- Several READMEs were read partially (listed under "Method and reading status").

## 4. Evidence of production use / Intune acceptance

### Takeaway
Only two community packers show production-scale use: IntuneAppBuilder (231.4K NuGet downloads, a company product, tenant integration tests) and ContentPrep through WinTuner. Everything else is author-asserted, single-upload or unproven. No independent blog or Microsoft statement endorsing any community packer was found.

### Cited Findings
- IntuneAppBuilder: tenant-publishing integration tests in CI (Windows runner), the #53 rejection and recovery, and 231.4K downloads — sections 2 above; https://github.com/simeoncloud/IntuneAppBuilder/issues/53, https://www.nuget.org/packages/IntuneAppBuilder.Console
- ContentPrep: WinTuner depends on it and uploads to Intune; 13,291 NuGet downloads — https://github.com/svrooij/WinTuner/blob/main/src/WingetIntune/WingetIntune.csproj
- WrapTune-MacOS: "deployed to a real Intune tenant and installed on Windows endpoints (Zoom, Chrome Enterprise, PowerShell 7), with the official tool nowhere in the chain." — https://github.com/thefinder808/WrapTune-MacOS
- New-IntuneWin: one successful admin-center upload of an `Install.bat` app — https://github.com/ThomasHoins/New-IntuneWin
- iamawrapper, LetsGoIntunePackager and SwitchHunt: compatibility claims only, with no test evidence cited — their READMEs (see table)

### Inferences
- The IntuneAppBuilder download totals, the earlier critic's per-version flat 2.5-3.3K and today's "Current version 2.0K" suggest that many downloads come from automation (Simeon's own pipelines). This is an inference.
- No community packer gives a guarantee. Acceptance depends on undocumented tenant-side checks that Microsoft has changed without notice (#53). Any adoption needs our own tenant acceptance test, repeated over time.

### Gaps
- No independent third-party blog post confirming acceptance was found (WebSearch gave nothing relevant).
- Microsoft's position on third-party packers was not researched here (the earlier findings section 3.4 covers the "must use Content Prep Tool" wording).

## 5. Hard blocks and yellow flags (aitools criteria)

### Takeaway
No candidate hits a hard block on the facts checked. None is official. IntuneAppBuilder has the fewest yellow flags. ContentPrep is next, but it now has no release in 12+ months. Every other packer carries several yellow flags (sole maintainer, very low adoption, pre-1.0, or no licence). iamawrapper's custom licence is a special case.

### Cited Findings
(The facts behind every row are cited in sections 1-3.)

| Candidate | Hard blocks | Yellow flags |
|---|---|---|
| simeoncloud/IntuneAppBuilder | none found | <500 stars; NuGet unverified, no GitHub releases; Windows-only CI; 2021 beta dependency; commit gap 2024-12 to 2026-05; open macOS-arm issue #46; past Intune rejection #53 |
| svrooij/ContentPrep | none found | sole maintainer, personal account; 32 stars; last release 2025-10-03 (>12 months); GPL-3.0; self-declared "not a replacement" |
| kenchan0130/intunewin | none | 7 stars; pre-1.0 (v0.0.7); personal account |
| WrapTune-MacOS | none | 31 stars; 2 contributors; personal; created 2026-05 (young); macOS-first; .NET 10 SDK to build |
| intunewin-rs | none | 0 stars; personal; 6 open issues; no push since 2026-06 |
| iamawrapper | none of the listed hard blocks | 1 star; sole contributor; non-OSI licence restricting packaging/MDM/distribution "Competing Products", with automatic termination |
| LetsGoIntunePackager | none | 5 stars; 1 release; overclaims "identical" output |
| lwalthert/intunewin | none | 3 stars; no releases; AI-generated tests |
| maxihafer/content-prep | none | no licence; 3 stars; sole maintainer; no release since 2025-03 |
| name/nexus | none | 2 stars; sole maintainer; no release since 2025-03 |
| volodymyrsmirnov/IntuneWin (`IntuneWinFile`) | **inactive 2+ years** (last push 2020-10-16): hard block | -- |
| New-IntuneWin | none | 0 stars; no real licence text; PS 5.1 only; created 2026-10-20 |
| intunewin-mac | none | no licence; 0 stars; author says "You probably shouldn't use this." |
| IntuneHydrationKit packer | none | packing is an internal function, not a product; 150 stars for the kit as a whole |
| iancohn AutoPkg processor | none | 1 star; repo licence null (per-file Apache-2.0) |
| SwitchHunt | none | browser-only, not CLI/CI; sole maintainer |

### Inferences
- Typosquatting: no squatted package names were seen. The PyPI and crates names are unclaimed, which itself is a risk: someone could squat `intunewin` later.
- "Personal fork when official exists": none of these are forks (`fork: false` for all those checked). The official tool is closed-source, so no fork is possible anyway.

### Gaps
- Security advisories were not queried for any repo (`/security-advisories` usually needs owner rights). I found no CVE mention in issues or READMEs, but I did not search the CVE databases.

INCIDENT: (low, harness) WebSearch returned unrelated results for both focused queries (one answer fabricated a maintainer name, "Stef Vrooij", that contradicts the csproj author "Stephan van Rooij"). Discovery for niche developer tooling should default to `gh search repos/code` plus the registry APIs. The `/tool-eval` playbook could say so.
INCIDENT: (low, harness) The PowerShell Gallery web page loaded as a chrome error page, and the v2 OData `Search()` API returned "An error has occurred." No fallback route is documented for PSGallery facts.
