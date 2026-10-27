# S3-MdmWinTool-Eval notes v1.0: /tool-eval of the Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe)

Delegate: S3-MdmWinTool-Eval (level 2 under S3-MdmWinTool, Session Commander 10cf255a-c).
Read date for every source: 2026-10-26. Method: chrome-devtools (own tab, `evaluate_script`
returning `innerText`, or the JSON body of an api.github.com / raw.githubusercontent.com URL)
unless marked otherwise. `gh api` (marked "gh") was used for three listings and one PR lookup.
The licence PDF and the exe were downloaded with curl into
`/Users/new-jose/repos/aitools/.scratch/session-mdmw-eval/dl/` and never executed; the PDF was
read with the Read tool; the exe's PE header was parsed read-only by
`.scratch/session-mdmw-eval/pe-sig.py` (`python3 -I`, script outside `dl/`). No WebFetch, no
Firecrawl. Quotes are verbatim. "Inference" marks anything no source states.
`/tool-eval` process followed by hand (steps 1-7); step 8 (registry hand-off) not done, by order.

## Summary (5 lines)

1. Official and only from Microsoft: `IntuneWinAppUtil.exe` v1.8.7 (latest; no release or commit after 2025-08-13 as of 2026-10-26), a 62,520-byte x64 .NET Framework console exe committed at the repo root of `microsoft/Microsoft-Win32-Content-Prep-Tool`; it is Authenticode-signed (Microsoft Code Signing PCA strings in the certificate blob; chain not validated on macOS), but the commits that changed it are "unsigned" and no checksum is published.
2. Platforms: Windows only. Microsoft publishes no macOS or Linux build (open request #26 since 2020; community reports Wine+Mono, unofficial); prerequisite ".NET Framework 4.7.2". macOS, Linux, Claude Code web and Cursor cloud are n/a for this tool.
3. Licence (read): "You may install and use any number of copies", but you may not "share, publish, rent, or lend the software, or provide the software as a stand-alone hosted offering for others to use" (4e). So: download at build time in CI (pinned commit + our SHA-256), never commit it to aitools, never upload it as an artifact, never ship it in a package. Using it implies accepting the terms; that acceptance is a commander decision for nobul-tech.
4. GitHub Actions: `windows-2022` lists ".NET Framework: 4.7.2, 4.8, 4.8.1"; `windows-2025` / `windows-latest` (windows-2025-vs2026) list "4.8, 4.8.1", which Microsoft documents as in-place updates of 4.5 that keep 4.7.2 apps working. windows-2019 is no longer in the Available Images table. Recommended runner: `windows-2022` (exact 4.7.2 present), x64.
5. Health: Windows yellow (no release in 12+ months; exe commits unsigned; no published checksums; v1.8.7 exe replaced after release; exit-code reliability unknown); no hard blocks; yellow flags: proprietary no-redistribution licence, no release in 12+ months. winget (`Microsoft.Win32ContentPrepTool`) and Chocolatey (`intunewinapputil`) packages exist but are community-submitted, not Microsoft; not preferred.

## 1. Facts table

| # | Fact | Verbatim quote | Source URL | Read date | Method |
|---|---|---|---|---|---|
| F1 | Purpose | "Use the Microsoft Win32 Content Prep Tool to pre-process Windows Classic apps. The packaging tool converts application installation files into the .intunewin format." | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool | 2026-10-26 | chrome-devtools |
| F2 | Version in README | "Version 1.8.7" | same | 2026-10-26 | chrome-devtools |
| F3 | Prerequisite | "Prerequisites / .NET Framework 4.7.2" | same | 2026-10-26 | chrome-devtools |
| F4 | Licence acceptance | "By downloading and using Microsoft Win32 Content Prep Tool, you agree to such license terms. If you do not accept them, do not use the software." | same | 2026-10-26 | chrome-devtools |
| F5 | Repo root files | `IntuneWinAppUtil.exe`, `Microsoft License Terms For Win32 Content Prep Tool.pdf`, `README.md`, `ReleaseNotes.txt`, `SECURITY.md`; "53 Commits", "11 Branches", "12 Tags" | same | 2026-10-26 | chrome-devtools |
| F6 | Adoption | "1.6k stars", "116 watching", "298 forks", "Contributors 11", Issues "28", Pull requests "10", "Releases 11" | same | 2026-10-26 | chrome-devtools |
| F7 | Latest release | v1.8.7 "Added FIPS compliance", tag commit `1d6cfcbdf8c28edc596337031f74df951f38f718`, created_at 2025-08-13T21:21:15Z, published_at 2025-08-13T21:30:41Z, author gvijaykumar201, 0 uploaded assets | https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest | 2026-10-26 | chrome-devtools (API JSON) |
| F8 | v1.8.7 notes | "Changed SHA256 to use FIPS-compliant algorithm. / Refactored logging to prevent crashes. / Added silent mode support. / Used compliant crypto algorithms." | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases | 2026-10-26 | chrome-devtools |
| F9 | Release history | v1.8.6 2024-02-28; v1.8.5 2023-11-06; v1.8.4 2022-05-10; 1.8.3 2021-06-23; v1.8.2 2020-12-04; v1.8.1 2020-04-23; v1.7 2020-03-20; v1.6 2019-10-30; v1.5 2019-03-20 (release `datetime` attributes) | same | 2026-10-26 | chrome-devtools |
| F10 | No newer tag | Tags page lists v1.8.7 first; all tags show "Verified" | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/tags | 2026-10-26 | chrome-devtools |
| F11 | Last commits | "Commits on Aug 13, 2025 / Merge pull request #156 from microsoft/fix_the_exe ... 1d6cfcb / Fixing the exe. ... 99dbe4b" (no later commits on master) | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/commits/master | 2026-10-26 | chrome-devtools |
| F12 | Commit signing | `1d6cfcb` committer "GitHub", verified true "valid"; `99dbe4b` "Fixing the exe." committer "Giridhar Vijaykumar", verified false "unsigned"; `cbc12f0` merge: true "valid"; `35a412b` "Updating tool to new version with fixes.": false "unsigned" | https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/commits?per_page=6 | 2026-10-26 | chrome-devtools (API JSON) |
| F13 | Exe blob at pinned commit | `IntuneWinAppUtil.exe` size 62520, git blob sha `566b5e0371a82ef5bd4e59f4314d72f0996d57f3`, download_url `https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/1d6cfcbdf8c28edc596337031f74df951f38f718/IntuneWinAppUtil.exe` | https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/contents/?ref=1d6cfcbdf8c28edc596337031f74df951f38f718 | 2026-10-26 | chrome-devtools (API JSON) |
| F14 | Our SHA-256 of the exe | `c1ba45b5cb939e84af064bb7ff4b38fb3dfe33c8dc1078fd9b157672eae671f6` (62,520 bytes) | download of F13 URL | 2026-10-26 | curl + `shasum -a 256` |
| F15 | Our SHA-256 of licence PDF | `57d5d3a3f075cddaf7637f162326a3f7ca0a43f100c006b77d22e58ffb428c91` (95,372 bytes) | raw URL at `1d6cfcb` | 2026-10-26 | curl + `shasum -a 256` |
| F16 | PE header | `machine=0x8664 magic=0x20b subsystem=3`; `clr_dir rva=0x2000 size=72`; `security_dir offset=52224 size=10296`; `WIN_CERTIFICATE ... revision=0x200 type=0x2`; "cert strings found: Microsoft Code Signing PCA, Microsoft Corporation, Microsoft Root Certificate Authority, Microsoft Time-Stamp" | local exe | 2026-10-26 | `pe-sig.py` (read-only) |
| F17 | Source archive at tag | `v1.8.7.zip` SHA-256 `33db05a672682efc5d59ca11a17c65a484b89e30dd67f1a90e4182f191fcfb7b`; archive comment `1d6cfcbdf8c28edc596337031f74df951f38f718`; contains `IntuneWinAppUtil.exe` 62520 bytes | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.7.zip | 2026-10-26 | curl + shasum + `unzip -l` |
| F18 | Advisories | "There aren't any published security advisories" | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/security | 2026-10-26 | chrome-devtools |
| F19 | v1.8.7 exe replaced after release | gvijaykumar201 on #153: "We had an issue with the exe and so we have updated the release with a new exe. Please try it out and let us know." | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/153 | 2026-10-26 | chrome-devtools |
| F20 | Exit codes (history) | #4 (2019): "The tool does not emit any usable exit code"; 1.8.2 sample "ERROR The setup file you specified cannot be accessed. ... echo %errorlevel% 0"; ameltzer-MSFT: "This has been improved in the latest release." then "closed this as completed" | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/4 | 2026-10-26 | chrome-devtools |
| F21 | Linux request | #26 (Open, 2020-02-04): "Any chance of getting this tool for Linux? I'd like to do the wrapping on a Linux server." / reply: "I was able to successfully run the tool on a Debian server using Wine and Mono." / "Unfortunately, I'll have to cancel my plans to create an Intune packager web app, as it is not allowed by the license terms (clause 4e)." | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/26 | 2026-10-26 | chrome-devtools |
| F22 | ARM64 | #159 (Closed): "The version 1.8.7 chaged the encriptation mode but it now gives a fatal error on Windows ARM." / ameltzer-MSFT (2025-10-15): "Same as #138. Should be addressed in latest release." | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/159 | 2026-10-26 | chrome-devtools |
| F23 | Console output issue | #160 (Open): "when running the intuneWinAppUtil.exe under PowerShell 7.5.x or using the CMD with Windows 11, the output to the console is corrupted"; later comment: "Windows Terminal > PowerShell 7.6.7 > IntuneWinAppUtil.exe = same corrupted output"; sample log shows a per-run temp dir "C:\Users\...\AppData\Local\Temp\e245528f-...\IntuneWinPackage\Contents\IntunePackage.intunewin" and output name "SPC-ScriptSync.intunewin" for setup file "SPC-ScriptSync.ps1" | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/160 | 2026-10-26 | chrome-devtools |
| F24 | Learn: delivery | "You can download the Microsoft Win32 Content Prep Tool from GitHub as a .zip file. The zipped file contains a folder named Microsoft-Win32-Content-Prep-Tool-master. The folder contains the prep tool, the license, a readme, and the release notes." Page mentions no macOS, Linux or .NET. "Last updated on 04/14/2026" | https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package | 2026-10-26 | chrome-devtools |
| F25 | Licence: use | "1. INSTALLATION AND USE RIGHTS. You may install and use any number of copies of the software." | licence PDF at `1d6cfcb` (F15) | 2026-10-26 | Read (pdf) |
| F26 | Licence: scope | "4. SCOPE OF LICENSE. The software is licensed, not sold. Microsoft reserves all other rights. ... you will not (and have no right to): a) work around any technical limitations in the software; b) reverse engineer, decompile or disassemble the software, or attempt to do so, except ...; c) remove, minimize, block, or modify any notices of Microsoft or its suppliers in the software; d) use the software in any way that is against the law; or e) share, publish, rent, or lend the software, or provide the software as a stand-alone hosted offering for others to use." | same | 2026-10-26 | Read (pdf) |
| F27 | Licence: data collection | "3. DATA COLLECTION. The software may collect information about you and your use of the software and send that to Microsoft. ... Your opt-out rights, if any, are described in the product documentation." | same | 2026-10-26 | Read (pdf) |
| F28 | Licence: export, support, warranty | "5. EXPORT RESTRICTIONS. You must comply with all domestic and international export laws..." / "6. SUPPORT SERVICES. Microsoft is not obligated under this agreement to provide any support services" / "10. ... THE SOFTWARE IS LICENSED “AS IS.”" / "11. ... ONLY DIRECT DAMAGES UP TO U.S. $5.00" | same | 2026-10-26 | Read (pdf) |
| F29 | winget package exists | `manifests/m/Microsoft/Win32ContentPrepTool/` with versions `1.8.6`, `1.8.7` | https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/Win32ContentPrepTool/1.8.7 | 2026-10-26 | gh (listing) + chrome-devtools |
| F30 | winget installer manifest | "PackageIdentifier: Microsoft.Win32ContentPrepTool ... InstallerType: zip / NestedInstallerType: portable ... PortableCommandAlias: intunewinapputil ... Architecture: x86 / InstallerUrl: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.7.zip / InstallerSha256: 33DB05A672682EFC5D59CA11A17C65A484B89E30DD67F1A90E4182F191FCFB7B" ("# Created with komac v2.14.0") | https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/m/Microsoft/Win32ContentPrepTool/1.8.7/Microsoft.Win32ContentPrepTool.installer.yaml | 2026-10-26 | chrome-devtools |
| F31 | winget locale manifest | "Publisher: Microsoft Corporation ... PackageUrl: https://docs.microsoft.com/en-us/cli/azure/ / License: Unknown" | .../Microsoft.Win32ContentPrepTool.locale.en-US.yaml | 2026-10-26 | chrome-devtools |
| F32 | winget submitter | PR #319357 "New version: Microsoft.Win32ContentPrepTool version 1.8.7", user `evilbananas` (type User, author_association CONTRIBUTOR), created 2025-12-03T19:28:29Z, merged 2025-12-03T23:30:23Z | https://api.github.com/repos/microsoft/winget-pkgs/pulls/319357 | 2026-10-26 | gh |
| F33 | Chocolatey package | "intunewinapputil 1.8.7.20250818", "Package Maintainer(s): chocolatey-community", "Software Author(s): Microsoft", "Downloads: 37,163", "Last Update: 18 Aug 2025", "Legal Disclaimer: Neither this package nor Chocolatey Software, Inc. are affiliated with or endorsed by Microsoft." | https://community.chocolatey.org/packages/intunewinapputil | 2026-10-26 | chrome-devtools |
| F34 | Scoop / Homebrew | No path matching `intune` or `contentprep` in the ScoopInstaller/Main or ScoopInstaller/Extras trees; `brew search intunewin`: "No formulae or casks found" | gh tree listings; local brew | 2026-10-26 | gh, brew |
| F35 | windows-2022 runner | "OS Version: 10.0.20348 Build 5761 / Image Version: 20261022.344.1" / ".NET Framework: 4.7.2, 4.8, 4.8.1" / "Bash 5.3.15(2)-release" / "Git 2.56.0.windows.3" / "PowerShell 7.6.8" | https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md | 2026-10-26 | chrome-devtools |
| F36 | windows-2025 runner | "OS Version: 10.0.26100 Build 33650 / Image Version: 20261021.278.1" / ".NET Framework: 4.8, 4.8.1" / "Git 2.56.0.windows.2" / "PowerShell 7.6.7" (Windows2025-VS2026-Readme; the older Windows2025-Readme shows the same .NET line, image 20261021.299.1) | https://github.com/actions/runner-images/blob/main/images/windows/Windows2025-VS2026-Readme.md | 2026-10-26 | chrome-devtools |
| F37 | Runner labels | "Windows Server 2025 x64 windows-latest, windows-2025, or windows-2025-vs2026"; "Windows Server 2022 x64 windows-2022"; "Windows 11 Arm64 arm64 windows-11-arm"; no Windows Server 2019 row | https://github.com/actions/runner-images | 2026-10-26 | chrome-devtools |
| F38 | .NET in-place updates | ".NET Framework 4.5.1, 4.5.2, 4.6, 4.6.1, 4.6.2, 4.7, 4.7.1, 4.7.2, and 4.8 are in-place updates to .NET Framework 4.5. In-place update means that they use the same runtime version, but the assembly versions are updated and include new types and members." ("Last updated on 03/16/2026") | https://learn.microsoft.com/en-us/dotnet/framework/install/versions-and-dependencies | 2026-10-26 | chrome-devtools |
| F39 | Registry | No `intune` / `contentprep` match in the tool registry (read-only grep) | `/tool-registry` data, read-only | 2026-10-26 | grep |

## 2. Source and purpose

- Upstream: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool, owned by the `microsoft` GitHub org (official). Microsoft Learn points to it as the download (F24).
- Purpose: wraps a setup folder into an encrypted `.intunewin` for upload to Intune as a Win32 app (F1). Flags `-c -s -o -a -q -qq -v -h` (README, F1 page; PkgWin notes table re-confirmed verbatim on the same read).
- Source code is not published; the repo holds a compiled exe, licence, README, release notes, SECURITY.md (F5). The licence forbids reverse engineering (F26 b).

## 3. Platforms (verified as far as sources go)

| Platform / environment | Status | Evidence |
|---|---|---|
| Windows 11 (x64) | Supported: the only official target | F3 (.NET Framework 4.7.2), F16 (PE32+ AMD64 .NET console exe), F24 |
| Windows on ARM64 | Unknown. The exe is AMD64 (F16), so it would run under x64 emulation (inference). #159 reports a fatal error in 1.8.7 on ARM, Microsoft says "Should be addressed in latest release" (F22), but no release followed 2025-08-13 except the in-place exe fix of the same day (F11, F19). Not recommended for build hosts until tested | F16, F22 |
| macOS | n/a: no official build; no Microsoft page mentions macOS (F24); .NET Framework runs only on Windows (inference, Microsoft's .NET Framework pages list only Windows versions, F38) | F24, F38 |
| Linux (Ubuntu 24.04/22.04) | n/a officially. Request #26 open since 2020-02-04 with no official build (F21). Community report: Wine + Mono works (F21; unverified, not a Microsoft-supported path) | F21 |
| Claude Code web / Cursor cloud | n/a (Ubuntu VMs; same as Linux) | F21 |

Conclusion for P-4 (design.md section 17): Windows only. Per the commander's P-4 text, evaluate and adopt for Windows as a build-host tool.

## 4. Install and delivery per platform

| Method | Windows | macOS | Linux | Official? | Notes |
|---|---|---|---|---|---|
| Raw exe at a pinned commit (`raw.githubusercontent.com/.../<sha>/IntuneWinAppUtil.exe`) | Yes | n/a | n/a | Yes (official repo; the file Microsoft ships) | Byte-exact, pinnable by commit, our SHA-256 F14. No elevation, no PATH change. Recommended |
| Repo zip from GitHub (Learn: "download ... as a .zip", F24) | Yes | n/a | n/a | Yes (Learn's documented method) | Learn describes the `-master` zip (moving target). The tag zip at v1.8.7 hashes to F17 and contains the same exe; tag content changed once after release (F19), so pin by commit, not tag |
| winget `Microsoft.Win32ContentPrepTool` | Yes | n/a | n/a | No: community submission (F32); manifest metadata partly wrong (F31) | Portable zip of the tag archive, hash matches F17. Not listed by Microsoft. Not preferred |
| Chocolatey `intunewinapputil` | Yes | n/a | n/a | No: "not affiliated with or endorsed by Microsoft" (F33) | Not preferred |
| Scoop, Homebrew | none | none | none | -- | F34 |
| Alternatives (svrooij/ContentPrep etc.) | -- | -- | -- | -- | Out of scope (S3-MdmWinTool-Research) |

Ranked against the evaluation principles: (1) official endorsement and (2) provenance select the raw exe from the official repo pinned by commit plus our SHA-256 and an Authenticode check. (3) latest stable: v1.8.7 is latest. (4)/(5) no cross-platform delivery exists. (6) automation: a curl + hash check is trivially scriptable. winget/choco lose on (1) and (2).

## 5. Provenance

- Org: `microsoft` (official).
- Commit signing: merge commits made through the GitHub UI are signed by GitHub ("valid"); the commits that actually changed the exe (`35a412b`, `99dbe4b`) are "unsigned" (F12). Tags show "Verified" because they point to web-flow merge commits (F10, F12; inference about cause).
- Checksums: none published by Microsoft (release has 0 assets, F7; README and release notes contain no hashes). Our recorded SHA-256: F14.
- Authenticode: the exe carries a PKCS#7 WIN_CERTIFICATE (type 0x2) whose blob contains "Microsoft Corporation", "Microsoft Code Signing PCA", "Microsoft Root Certificate Authority", "Microsoft Time-Stamp" (F16). This is string presence only: the chain and the hash were not validated on macOS (no `Get-AuthenticodeSignature`/`signtool`/`osslsigncode` run). Validation belongs in the CI recipe (section 9) and Phase 2.
- Content mutability: Microsoft replaced the v1.8.7 exe after first publishing (F19); release published_at (21:30:41Z) is 9 minutes after the tag commit (21:21:15Z) (F7, F11). Pin by commit SHA.
- Advisories: none published (F18). SECURITY.md routes reports to MSRC.

## 6. Licence (READ)

Proprietary Microsoft Software License Terms (not OSI). Key terms and what they mean for aitools (inference unless quoted):

- Use in CI is allowed: "You may install and use any number of copies" (F25). Nothing restricts automated or CI use.
- Redistribution is not allowed: 4(e) "share, publish, rent, or lend the software" (F26). Consequences:
  - Do not commit `IntuneWinAppUtil.exe` into the aitools repo or the dotprofile.
  - Do not upload it as a GitHub Actions artifact or release asset, and do not include it in any `.intunewin`/payload (Learn also says keep the tool out of the setup folder, PkgWin notes [create-win32-package]).
  - Fetch it from Microsoft's repo at build time (R-12's mitigation holds). `actions/cache` scoped to our repo is not "publishing" in the ordinary sense, but it stores a copy on GitHub's infrastructure under our account; safest is no cache (62 KB download). Inference; not legal advice.
  - Not "a stand-alone hosted offering for others to use": an aitools packaging service for third parties would breach 4(e) (the #26 commenter drew the same conclusion, F21). Building our own fleet packages is our own use (inference).
- 3. Data collection: the tool "may collect information ... and send that to Microsoft" (F27). Whether 1.8.7 sends telemetry, and any opt-out, is unknown (not documented in the README). Relevant for CI egress policies.
- 4(a) "work around any technical limitations": running it under Wine on Linux is not addressed explicitly (unknown); not a supported path anyway.
- Export (5), no support (6), "AS IS" (10), $5 damages cap (11) (F28).
- Acceptance: README "By downloading and using ... you agree" (F4). A CI workflow that downloads it accepts the terms on behalf of the account owner. This needs an explicit commander decision for nobul-tech (open question 1).

## 7. Latest release and activity

- Latest: v1.8.7, 2025-08-13 (F7). No release, tag or commit after that as of 2026-10-26 (F10, F11): 14.5 months without a release.
- Maintainer activity: Microsoft staff (gvijaykumar201, ameltzer-MSFT) answered issues on 2025-08-13 (#153) and 2025-10-15 (#159) (F19, F22). Issues continue to be filed in 2026 (#160, #167; dates from issue list, 2026-10-21 updates). No Microsoft reply to #160 seen.
- Release cadence historically: 1-2 per year 2019-2021, then 2022-05, 2023-11, 2024-02, 2025-08 (F9).

## 8. Health flags (per platform)

| Platform | Flag | Reasons |
|---|---|---|
| Windows (x64) | yellow | No release in 12+ months (F7); exe-changing commits unsigned and no published checksum, so provenance rests on Microsoft's Authenticode signature plus our pinned hash (F12, F14, F16); the v1.8.7 exe was replaced in place after release (F19); exit-code reliability in 1.8.7 unknown (F20); lastVerified null (no Phase 2 run yet). Not red: official, latest version, no advisories, Microsoft staff active in 2025 |
| Windows (ARM64 build host) | yellow (not recommended) | AMD64 exe (F16); 1.8.7 ARM failure report, fix status unverified (F22) |
| macOS | n/a | No official build (section 3) |
| Linux (Ubuntu 24.04/22.04) | n/a | No official build; Wine+Mono is a community report only (F21) |
| Claude Code web / Cursor cloud | n/a | Ubuntu VMs, as Linux |

## 9. Hard blocks and yellow flags

Hard blocks (reference/tool-evaluation-criteria.md): none.
- Unverified publisher: no (`microsoft` org). Inactive 2+ years: no (last commit 2025-08-13). Security advisories: none published (F18). Personal fork: no. Typosquatting: no. Excessive permissions: no (console exe, no elevation needed: inference from portable nature; to confirm in Phase 2).

Yellow flags (disclose):
- No release in 12+ months (v1.8.7, 2025-08-13).
- Licence: proprietary, no redistribution (4e), possible telemetry (3). Not "no licence", but not OSS.
- Provenance gaps: no published checksums; unsigned content commits; release content changed after publication.
- Not flagged: adoption (1.6k stars, 298 forks), sole maintainer (org-backed, several Microsoft committers over time), archived (no).

## 10. GitHub Actions run recipe (proposal; not tested, Phase 2 decides)

Runner: `windows-2022` (".NET Framework: 4.7.2, 4.8, 4.8.1", F35). `windows-2025` / `windows-latest` also qualifies via the 4.8/4.8.1 in-place update (F36, F38). Do not use `windows-11-arm` (section 3). windows-2019 is not offered (F37).

```yaml
# .github/workflows/package.yml, job "intune" (sketch)
intune:
  runs-on: windows-2022
  env:
    IWAU_COMMIT: 1d6cfcbdf8c28edc596337031f74df951f38f718   # v1.8.7 after the in-place exe fix (F7, F11)
    IWAU_SHA256: c1ba45b5cb939e84af064bb7ff4b38fb3dfe33c8dc1078fd9b157672eae671f6  # recorded 2026-10-26 (F14)
  steps:
    - uses: actions/checkout@<pinned-sha>
    - name: Fetch IntuneWinAppUtil (pinned commit + SHA-256)
      shell: bash   # Git Bash on the runner (Bash 5.3.15, Git 2.56.0.windows.3, F35)
      run: |
        set -euo pipefail
        mkdir -p "$RUNNER_TEMP/iwau"
        curl -fsSL -o "$RUNNER_TEMP/iwau/IntuneWinAppUtil.exe" \
          "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/${IWAU_COMMIT}/IntuneWinAppUtil.exe"
        echo "${IWAU_SHA256}  $RUNNER_TEMP/iwau/IntuneWinAppUtil.exe" | sha256sum -c -
    - name: Verify Authenticode signature
      shell: pwsh
      run: |
        $sig = Get-AuthenticodeSignature "$env:RUNNER_TEMP\iwau\IntuneWinAppUtil.exe"
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
          throw "IntuneWinAppUtil signature check failed: $($sig.Status) $($sig.SignerCertificate.Subject)"
        }
    - name: Build .intunewin (from Git Bash, as build-package.sh would)
      shell: bash
      run: |
        set -euo pipefail
        tool="$RUNNER_TEMP/iwau/IntuneWinAppUtil.exe"
        src_w="$(cygpath -w "$PWD/stage/win/system")"
        out_w="$(cygpath -w "$PWD/out/system")"
        "$tool" -c "$src_w" -s "$src_w\\install.cmd" -o "$out_w" -q > "$RUNNER_TEMP/iwau-system.log" 2>&1
        # Do not trust the exit code alone (#4, F20): require the output and no ERROR lines
        test -s "out/system/install.intunewin"
        if grep -q '^ERROR' "$RUNNER_TEMP/iwau-system.log"; then exit 1; fi
```

Notes on the recipe (inference unless cited):
- Output name follows the setup file's base name (`SPC-ScriptSync.ps1` -> `SPC-ScriptSync.intunewin`, F23); there is no output-name flag (open issue #7 "Command line option to change output file name", issue list). Rename after the build to `aitools-system-<v>.intunewin`.
- `-q` overwrites existing output and creates the folder; `-qq` also silences console output (README). Prefer `-q` with stdout captured to a log, so failures are diagnosable.
- Pass Windows paths (`cygpath -w`) to the exe; MSYS argument conversion of POSIX paths is a risk otherwise. Whether `-s` accepts a path relative to `-c` is undocumented (the Learn example uses a full path), so use the full path.
- Never upload `$RUNNER_TEMP/iwau/` as an artifact; never cache it (section 6).
- The `sha256sum -c` line uses two spaces (coreutils format). The shell steps here are a workflow sketch, not a reusable aitools script; the real step lives in `build-package.sh`/`package.yml` after Phase 2 and must follow script-standards.md.
- Invocation from pwsh is equally possible: `& "$env:RUNNER_TEMP\iwau\IntuneWinAppUtil.exe" -c $src -s "$src\install.cmd" -o $out -q`.

## 11. Would-be registry entry (Phase 1 fields; record via /tool-registry after commander review; not written)

| Field | Value |
|---|---|
| name / id | IntuneWinAppUtil (Microsoft Win32 Content Prep Tool) |
| class | build-host tool (proposed P-4 lifecycle class) |
| official source URL | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool ; Learn: https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package |
| publisher | Microsoft Corporation (`microsoft` GitHub org) |
| licence | Microsoft Software License Terms (proprietary; no redistribution, 4e; telemetry clause 3) |
| latest version / date | 1.8.7 / 2025-08-13 |
| pinned ref | commit `1d6cfcbdf8c28edc596337031f74df951f38f718` |
| pinned SHA-256 | `c1ba45b5cb939e84af064bb7ff4b38fb3dfe33c8dc1078fd9b157672eae671f6` (exe, 62,520 bytes) |
| preferred install, Windows | download raw exe at the pinned commit, verify SHA-256 and Authenticode (Valid, O=Microsoft Corporation); no install step, no PATH change |
| preferred install, macOS / Linux | n/a (no official build) |
| non-preferred methods (cleanup targets) | winget `Microsoft.Win32ContentPrepTool` (community, alias `intunewinapputil`); Chocolatey `intunewinapputil` (chocolatey-community); repo `-master` zip (unpinned) |
| version check command | `IntuneWinAppUtil.exe -v` ("Only available starting version 1.8.2"; 1.8.2 printed `1.8.2.0`, F20). Exact 1.8.7 output: unknown (Phase 2) |
| platform status | Windows `evaluating`; macOS `n/a`; Linux `n/a` |
| concurrency | Unknown. Each run uses its own temp dir under `%TEMP%\<guid>\IntuneWinPackage` (F23), so parallel runs with distinct `-o` likely work (inference; test in Phase 2) |
| post-install config | None (stateless). Licence acceptance is implicit on download (F4) |
| dependencies | .NET Framework 4.7.2 or later 4.x in-place update (F3, F38); Windows x64 |
| invocation | `IntuneWinAppUtil.exe -c <setup_folder> -s <setup_file> -o <output_folder> -q`; anti-patterns: running with no parameters (interactive prompts); putting the tool inside the setup folder; relying on the exit code alone; pinning by tag; committing or uploading the exe |
| authentication | None |
| health | Windows yellow (section 8); macOS n/a; Linux n/a |
| evaluation record | `reference/evaluations/intunewinapputil-windows-2026-10-26.md` (to be written by the orchestrator after review; tool-evaluation.md "Gates") |
| lastVerified | null until Phase 2 runs on Windows |

## 12. Corrections to S3-BuildPkg-PkgWin-notes.md section 1

| PkgWin claim | Verdict | Correction / evidence |
|---|---|---|
| v1.8.7, 2025-08-13, "Added FIPS compliance" | Confirmed | F7, F8 |
| Needs .NET Framework 4.7.2 | Confirmed | F3; also: 4.8/4.8.1 satisfy it (F38) |
| Exe committed in repo root; release has only source archives | Confirmed | F5, F7 (0 uploaded assets) |
| 1.6k stars, 298 forks, 116 watchers, 11 contributors, 28 issues, 10 PRs | Confirmed | F6 |
| "Commits are 'Verified'" | Partly wrong | Only GitHub web-flow merge commits are verified; the exe-changing commits `35a412b` and `99dbe4b` are "unsigned" (F12) |
| Last commit 2025-08-13 (Merge PR #156 "fix_the_exe") | Confirmed | F11 |
| Licence PDF not read; redistribution unknown | Resolved | Read: redistribution prohibited (4e), use unlimited (1), telemetry clause (3) (F25-F27) |
| Advisories unknown (security tab not checked) | Resolved | "There aren't any published security advisories" (F18) |
| "no published checksums seen" | Confirmed | F7; our SHA-256 recorded (F14) |
| Windows-only "inferred" | Strengthened, still partly inference | AMD64 .NET Framework exe (F16); no Microsoft page mentions macOS/Linux (F24); Linux request open since 2020 (F21) |
| Health Windows yellow; macOS and Linux n/a | Confirmed, reasons extended | section 8 |
| Not stated in PkgWin | New | v1.8.7 exe replaced after release (F19): pin by commit; winget and Chocolatey packages exist, both community (F29-F33) |
| winget "not supported in the system context" | Not re-verified | Out of my scope; I did not re-read the winget troubleshooting page |

## 13. INCIDENT markers (not filed)

- INCIDENT: (medium, plan) `plans/build-package/implementation-plan.md` R-12 mitigation "CI downloads it at build time (no redistribution)" is consistent with licence 4(e), but the plan does not forbid uploading the exe as a workflow artifact, caching it, committing it, or bundling it, and does not record who accepts the licence for nobul-tech. Suggested: add those constraints to section 8 step 5 and a P-n decision for licence acceptance.
- INCIDENT: (medium, plan) The B9/B11 build gate must not rely on IntuneWinAppUtil's exit code: historically it returned 0 on errors (#4, F20); Microsoft says "improved" without detail. Suggested: gate on output file presence and absence of `ERROR` lines; Phase 2 measures the real exit codes.
- INCIDENT: (low, plan) The pinned ref must be a commit SHA, not the tag: the v1.8.7 exe was replaced after release (F19). implementation-plan section 8 says "pinned commit" (consistent); design.md 3(c) names only "v1.8.7". Suggested: name commit `1d6cfcb...` and SHA-256 F14 in design.md 3(c).
- INCIDENT: (low, harness) GitHub code search (`gh api search/code`, repo:microsoft/winget-pkgs) returned 0 hits for "IntuneWinAppUtil", "Win32ContentPrepTool" and "Content Prep", while `manifests/m/Microsoft/Win32ContentPrepTool/` exists. Suggested: the tool-evaluation playbook should list package-manager discovery by directory/tree listing, not code search.
- INCIDENT: (low, upstream) winget locale manifest has `PackageUrl: https://docs.microsoft.com/en-us/cli/azure/` and `License: Unknown` (F31): community metadata error. Informational.

## 14. Open questions (with suggested answers)

1. Who accepts the Microsoft licence terms for nobul-tech's CI use? Suggest: the commander records acceptance as a P-n decision before B9a; it permits use, not redistribution.
2. windows-2022 or windows-2025 for the intune job? Suggest windows-2022 now (exact 4.7.2 listed, matches design.md), and windows-2025 as a tested fallback before windows-2022 retires (retirement date not read).
3. Cache the exe in CI? Suggest no: 62 KB, fetch each run from the pinned commit; avoids any 4(e) question.
4. Telemetry: block or accept? Suggest accept for v1 and note it in the evaluation record; unknown whether 1.8.7 sends anything.

## 15. Gaps in my own reading (honest)

- Read in full: the mission packet, tool-evaluation.md, web-sources.md, tool-lifecycle.md (in context), the /tool-eval SKILL.md, tool-evaluation-criteria.md, tool-evaluation-playbook.md, the PkgWin notes, design.md 3(c) and implementation-plan.md section 8 and R-12/P-4 rows, cross-platform-detail.md "Supported platforms and environments". Other rule files listed in the packet were in my context from the session start (CLAUDE.md files and `.claude/rules/*`). Not read: `plans/tool-support-and-machine-profile.md`, the prior handoff `2026-10-21_360aa8f3-8.md`, reference files script-standards-detail.md, logging.md, managed-file-deployment.md, plan-execution-detail.md (not needed for a research-only evaluation; I wrote no code). The /aitool-eval skill was not invoked (the criteria and playbook were read directly).
- Authenticode chain and hash not validated (no Windows host); only certificate-blob strings checked.
- Not tested: exit codes, `-v` output of 1.8.7, relative `-s` paths, parallel runs, telemetry, ARM64 behaviour, Wine/Mono. These belong to Phase 2 (Windows) or S3-MdmWinTool-Probe.
- Issues read: #4, #26 (first ~12 comments), #153, #159, #160; titles only for the rest of the first page of the issue list. #167 ("Unable to create intunewin packages", updated 2026-10-21) not opened: possible current regression, unknown.
- windows-11-arm readme not read. windows-2022 retirement date not read. windows-2019 retirement announcement not read (only its absence from the table).
- Microsoft Privacy and personal data in Intune page (README link) not read.

## Sources (all read 2026-10-26)

- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool (README, sidebar)
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/tags
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/commits/master
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/commit/99dbe4b
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/security
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues?q=is%3Aissue%20sort%3Aupdated-desc ; issues /4, /26, /153, /159, /160
- https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/commits?per_page=6
- https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/contents/?ref=1d6cfcbdf8c28edc596337031f74df951f38f718
- https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest
- https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/1d6cfcbdf8c28edc596337031f74df951f38f718/ReleaseNotes.txt
- Licence PDF: https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/1d6cfcbdf8c28edc596337031f74df951f38f718/Microsoft%20License%20Terms%20For%20Win32%20Content%20Prep%20Tool.pdf (downloaded, Read)
- Exe: https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/1d6cfcbdf8c28edc596337031f74df951f38f718/IntuneWinAppUtil.exe (downloaded, hashed, header parsed; not executed)
- Tag zip: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.7.zip (downloaded, hashed, listed)
- https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package (Last updated 04/14/2026)
- https://learn.microsoft.com/en-us/dotnet/framework/install/versions-and-dependencies (Last updated 03/16/2026)
- https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/Win32ContentPrepTool/1.8.7 ; raw installer and locale yaml; https://api.github.com/repos/microsoft/winget-pkgs/pulls/319357 (gh)
- https://community.chocolatey.org/packages?q=IntuneWinAppUtil ; https://community.chocolatey.org/packages/intunewinapputil
- ScoopInstaller/Main and ScoopInstaller/Extras git trees (gh); `brew search intunewin` (local)
- https://github.com/actions/runner-images ; images/windows/Windows2022-Readme.md ; Windows2025-VS2026-Readme.md ; Windows2025-Readme.md
