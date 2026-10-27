# MDM Windows tool findings: building `.intunewin` on macOS, Linux and Windows (v1.1)

**Intent**: **Purpose**: Tell the commander whether aitools can build Intune Win32 packages (`.intunewin`) on macOS and Linux as well as Windows, and with which tool. **Scope**: The `/tool-eval` of the Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`), the alternatives (community packers, a native build from the documented parts of the format, Windows CI only, Wine/Mono), and a build-host and CI recommendation for build-package. NOT the build-package implementation (`plans/build-package/implementation-plan.md`). NOT the tool registry write (the would-be entry is in section 2.9). **Audience**: The commander (Jose) and the build-package executing mission.

Mission MDM-WINTOOL, S3-MdmWinTool (orchestrator, level 1 under Session Commander 10cf255a-c), 2026-10-26. All sources were read on 2026-10-26. Web pages were read with chrome-devtools and API facts were checked with `gh api`. Full evidence is in the delegates' notes in `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinTool/` (Eval, Research, Probe, Critic). Their fact IDs (F1-F39) are cited here.

**Versions:**
- v1.0 (2026-10-26): mission MDM-WINTOOL, `/tool-eval` of the official tool and first pass on alternatives.
- v1.1 (2026-10-26): mission MDM-WINTOOL-DR (S3-MdmWinToolDR) deep-research pass, summarised in section 6. Statements it corrects are marked "*Superseded in v1.1*" where they stand, not deleted. The recommendation changes for non-Windows hosts and for the cross-platform alternative (6.3); the primary Windows path stands.

## 1. Summary and the answer

1. **Officially, `.intunewin` builds on Windows only.** Microsoft ships one packer, `IntuneWinAppUtil.exe` v1.8.7. It is a 62,520-byte x64 .NET Framework 4.7.2 console exe at commit `1d6cfcb`. Microsoft has no macOS or Linux build: the Linux request (#26) has been open since 2020.
2. **Hands-on on macOS (arm64): the official exe does not run unmodified.**
   - dotnet 10 refuses it as an x64 assembly. Mono, Wine and Rosetta 2 are absent.
   - A diagnostic copy with its architecture byte patched ran `-v`, then crashed while writing the package.
   - Licence clause 4(a) forbids working around the tool's technical limitations, so the patched route is ruled out.
3. **Community packers can build `.intunewin` on macOS and Linux. None is official.**
   - svrooij/ContentPrep produced a package on this Mac, with the same layout and size the Microsoft tool computed.
   - simeoncloud/IntuneAppBuilder is the strongest candidate: a company org, Apache-2.0, a .NET 8 tool, 231K NuGet downloads, and CI tests that publish to a real Intune tenant. *Superseded in v1.1 (6.2): its tenant tests run on `windows-latest` only, so non-Windows output is unproven, and Intune rejected its output for about 7 weeks in 2025 (#53). It is now ranked below a native encoder (6.3).*
   - Microsoft documents the encryption and the Graph upload. The container itself (zip layout, `Detection.xml`) is documented only by the community. *Superseded in v1.1 (6.2): Microsoft documents the encryption parameters and sizes only; AES-CBC/PKCS7/HMAC-SHA256 appear only in MIT sample code.*
4. **Licence.** Any number of copies may be used. Redistribution is forbidden (4(e)). CI therefore downloads the exe from Microsoft's pinned commit, checks our SHA-256 and the Authenticode signature, and never commits, caches, uploads or bundles it.
5. **Recommendation: build the Windows package on a GitHub-hosted `windows-2022` runner with the official tool** (evaluation principles 1 and 2). macOS and Linux report `n/a` for the `intune` kind, as design.md 3(a) and 3(c) already say. A cross-platform packer (IntuneAppBuilder first) is a follow-up `/tool-eval` only if the commander wants local Mac builds. *Revised in v1.1 (6.3): the Windows runner stands as rank 1. On non-Windows hosts a requested `intune` kind dispatches that runner (`gh workflow run` / `gh run download`) instead of only reporting ERROR. The all-platform alternative is a native ProfileVersion1 encoder in aitools first, IntuneAppBuilder second, both behind `/tool-eval`, `/tool-adopt` and a tenant test.*

**The answer:** Yes on Windows, with Microsoft's `IntuneWinAppUtil.exe` (runner `windows-2022`, health yellow, no hard blocks). On macOS and Linux it is not possible with any official tool. It is technically possible with unofficial packers, but none has passed evaluation, and Intune acceptance of their output was not tested by us. CI (macOS, Linux, Windows runners) still covers all three package kinds, because each kind builds on its native runner. *v1.1 (6.1): the official tool is Windows-only, but the `.intunewin` format is host-independent and can be built anywhere; no cross-platform option is fit to adopt without `/tool-eval` and a tenant acceptance test.*

## 2. `/tool-eval`: Microsoft Win32 Content Prep Tool

Evaluator: S3-MdmWinTool-Eval. Process: the `/tool-eval` skill steps 1-7. Step 8 (registry hand-off) was not done, by order. Spot-checked by the orchestrator (section 5.3).

### 2.1 Source and purpose

- Upstream: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool, owned by the `microsoft` org. Microsoft Learn points to it: "You can download the Microsoft Win32 Content Prep Tool from GitHub as a .zip file" (https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package, last updated 04/14/2026).
- Purpose: "converts application installation files into the .intunewin format" (README).
- Flags: `-c <setup_folder> -s <setup_file> -o <output_folder> -q` (also `-qq`, `-a`, `-v`, `-h`).
- No source code is published. The repo holds the compiled exe, the licence PDF, the README, ReleaseNotes.txt and SECURITY.md.

### 2.2 Platforms (verified)

| Platform / environment | Status | Evidence |
|---|---|---|
| Windows x64 | Supported, and the only official target | README "Prerequisites / .NET Framework 4.7.2". PE header: `Machine: 0x8664`, PE32+, console, `.NETFramework,Version=v4.7.2` (Probe and Eval parsed it independently). |
| Windows ARM64 | Unknown; not recommended for a build host | x64 exe. #159 reported a fatal error in 1.8.7 on ARM. ameltzer-MSFT replied "Same as #138. Should be addressed in latest release." 1.8.7 is already the latest release, so Microsoft claims 1.8.7 fixes it. Unverified. |
| macOS (arm64) | n/a | No Microsoft page mentions it. Probe trial 1 with dotnet 10.0.9: "The assembly architecture is not compatible with the current process architecture". Mono, Wine and Rosetta 2 are not installed. |
| Linux (Ubuntu 24.04/22.04) | n/a | #26 "Linux executable?" has been open since 2020-02-04 (`gh api`: `open`). Wine + `winetricks dotnet48` works by community report only. |
| Claude Code web, Cursor cloud | n/a | Ubuntu VMs, so the Linux row applies. |

Microsoft never says "Windows only" in so many words. The conclusion rests on the x64 .NET Framework binary, the absence of any other build, and the open Linux request.

### 2.3 Install and delivery per platform

| Method | Windows | Official? | Verdict |
|---|---|---|---|
| Raw exe at a pinned commit: `https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/1d6cfcbdf8c28edc596337031f74df951f38f718/IntuneWinAppUtil.exe` | yes | yes: Microsoft's own repo file. Microsoft org member brmcmill (#163, 2026-10-08) wrote "Try this one, good: https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe" | **Preferred.** No install step, no elevation, no PATH change. |
| GitHub repo zip (Learn's documented method) | yes | yes | Same exe. The `-master` zip moves, so pin a commit instead. |
| winget `Microsoft.Win32ContentPrepTool` | yes | Partly. The payload is official: InstallerUrl is Microsoft's `archive/refs/tags/v1.8.7.zip`, pinned by SHA-256. The manifest is community-made: user `evilbananas`, PR #319357, with `License: Unknown` and the architecture mislabelled x86 | Not preferred. |
| Chocolatey `intunewinapputil` | yes | no: "not affiliated with or endorsed by Microsoft" | Not preferred. |
| Scoop, Homebrew | none | -- | -- |
| macOS, Linux | none | -- | n/a |

### 2.4 Provenance

- Org `microsoft`. Latest release v1.8.7, published 2025-08-13T21:30:41Z. It has 0 uploaded assets, and no checksum is published (`gh api .../releases`, re-checked by the orchestrator).
- The exe changed after release. Microsoft said: "We had an issue with the exe and so we have updated the release with a new exe" (#153).
  - The tag `v1.8.7` now resolves to the pinned commit `1d6cfcb` (`gh api .../git/ref/tags/v1.8.7`, checked by the orchestrator).
  - The tag has moved once, so pin by commit, not by tag.
- Commit signing: only the GitHub merge commits are "valid". The two commits that changed the exe (`35a412b`, `99dbe4b`) are "unsigned" (F12).
- Our hashes, computed independently by two delegates:
  - SHA-256 of the exe at `1d6cfcb`: `c1ba45b5cb939e84af064bb7ff4b38fb3dfe33c8dc1078fd9b157672eae671f6`.
  - Git blob `566b5e0371a82ef5bd4e59f4314d72f0996d57f3` matches the contents API.
- Authenticode:
  - A PKCS#7 signature is present, with signer `CN=Microsoft Corporation` and issuer `CN=Microsoft Code Signing PCA 2011` (openssl pkcs7 output).
  - The digest and timestamp are not verified: there is no Windows host or osslsigncode here. CI checks them with `Get-AuthenticodeSignature`.
- Advisories: "There aren't any published security advisories".

### 2.5 Licence (PDF read in full by Eval and re-read by the orchestrator)

- "1. INSTALLATION AND USE RIGHTS. You may install and use any number of copies of the software." CI use is allowed.
- "4. SCOPE OF LICENSE ... you will not (and have no right to): a) work around any technical limitations in the software; b) reverse engineer, decompile or disassemble the software ...; e) share, publish, rent, or lend the software, or provide the software as a stand-alone hosted offering for others to use."
  - Under 4(e): never commit the exe to aitools or the dotprofile, never upload it as an Actions artifact or release asset, never put it in a payload, and never offer a packaging service for others.
  - Caching it with `actions/cache` is an open question. We suggest no cache: it is a 62 KB download (inference, not legal advice).
- "3. DATA COLLECTION. The software may collect information about you and your use of the software and send that to Microsoft." Whether 1.8.7 sends telemetry is unknown.
- README: "By downloading and using Microsoft Win32 Content Prep Tool, you agree to such license terms." A CI download accepts the terms for the account. This is a commander decision (Q1).
- Proprietary licence. Not OSI.

### 2.6 Latest release and activity

- v1.8.7 (2025-08-13) is the latest. There has been no release and no commit on master since, so it is 14.5 months old (`gh api`: latest two releases v1.8.7 2025-08-13, v1.8.6 2024-02-28). The critic found one README-only commit on the `test` branch (41aa672, 2026-08-24).
- Microsoft staff and members are still active:
  - Issue replies in 2025-08 (#153) and 2025-10 (#159).
  - Org MEMBER brmcmill on 2026-10-08 (#163, #165, #137; #163 checked with `gh api`).
- Adoption: 1.6k stars, 298 forks. Contributors: 11 on the repo page, 10 via `contributors?anon=1`.
- Exit codes: historically the tool exited 0 on errors (#4). Microsoft says "improved" but gives no detail.
- Console crash: #165 reports `ArgumentOutOfRangeException ... Console.MoveBufferArea ... WriteProgress`. #160 reports corrupted console output under pwsh 7.5+. The README says `-qq` gives "no console output". These are a CI risk (4.3).
- #167 "Unable to create intunewin packages": one unconfirmed report, 0 comments, no Microsoft reply. Its author guesses at a certificate-authority cause; the exe is signed through Microsoft Code Signing PCA 2011. Not a confirmed regression.

### 2.7 Health flags

| Platform | Flag | Reasons |
|---|---|---|
| Windows x64 | **yellow** | No release in 12+ months. The exe-changing commits are unsigned and no checksum is published. The release exe was replaced in place. Exit-code reliability is unknown. There is a console-buffer crash report (#165). `lastVerified` is null until Phase 2. Not red: official, latest, no advisories, Microsoft members active in 2026-10. |
| Windows ARM64 | yellow, not recommended | x64-only binary; the 1.8.7 ARM report is unresolved. |
| macOS, Linux, Claude Code web, Cursor cloud | n/a | No official build. |

### 2.8 Hard blocks and yellow flags

- **Hard blocks: none.** The publisher is verified (`microsoft`). It is active within 24 months. There are no advisories. It is not a fork and not a typosquat. It needs no special permissions.
- **Yellow flags (disclose):**
  - No release in 12+ months.
  - Proprietary licence with no redistribution and a telemetry clause.
  - Provenance gaps: no published checksum, unsigned content commits, and content changed after release.

### 2.9 How it runs in GitHub Actions

- **Runner `windows-2022`** (image 20261022.344.1) lists ".NET Framework: 4.7.2, 4.8, 4.8.1", "PowerShell 7.6.8", "Git 2.56.0.windows.3" and "Bash 5.3.15" (actions/runner-images Windows2022-Readme).
- `windows-2025` / `windows-latest` lists "4.8, 4.8.1". Microsoft documents those as in-place updates of 4.5, so 4.7.2 apps run on them.
- `windows-2019` is no longer offered. Do not use `windows-11-arm`. *v1.1 (6.2): `windows-11-arm` and `windows-11-vs2026-arm` exist, `windows-latest`/`windows-2025` now ship VS 2026, and no windows-2022 deprecation is announced. The "do not use Arm" advice stands because of #159.*
- Job steps:
  1. Fetch the exe with curl into `$RUNNER_TEMP`, from the pinned commit.
  2. `sha256sum -c` against our SHA-256.
  3. `Get-AuthenticodeSignature`: Status `Valid` and subject `O=Microsoft Corporation`, else fail.
  4. Run `build-package.sh intune` from Git Bash. It calls the exe with `cygpath -w` paths and `-q`, and captures stdout to a log.
  5. **Gate on the output file being present and non-empty, and on no `ERROR` lines.** Do not rely on the exit code.
  6. Rename the output, since it is named after the setup file (no output-name flag, issue #7).
  7. Upload only the `.intunewin` files as artifacts. Never upload or cache the exe.
- The full YAML sketch is in the Eval notes section 10. It is a sketch: Phase 2 measures the real exit codes, the `-v` output and relative-path behaviour.

### 2.10 What a registry entry would need (not written)

| Field | Value |
|---|---|
| name | IntuneWinAppUtil (Microsoft Win32 Content Prep Tool) |
| class | build-host tool (proposed lifecycle class, P-4 / RM-111) |
| official source | https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool ; https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package |
| publisher / licence | Microsoft Corporation / Microsoft Software License Terms (proprietary; 4(e) no redistribution; 3 telemetry) |
| version / pin | 1.8.7 (2025-08-13) / commit `1d6cfcbdf8c28edc596337031f74df951f38f718`, SHA-256 `c1ba45b5cb939e84af064bb7ff4b38fb3dfe33c8dc1078fd9b157672eae671f6` |
| preferred method, Windows | Download the raw exe at the pinned commit, then verify the SHA-256 and Authenticode. No install, no PATH change. |
| macOS / Linux | n/a |
| non-preferred (cleanup targets) | winget `Microsoft.Win32ContentPrepTool` (alias `intunewinapputil`), Chocolatey `intunewinapputil`, repo `-master` zip |
| version check | `IntuneWinAppUtil.exe -v` (since 1.8.2). The patched-copy diagnostic printed `1.8.7.0`; confirm unmodified on Windows in Phase 2. |
| platform status | Windows `evaluating`; macOS `n/a`; Linux `n/a` |
| concurrency | Likely safe with distinct `-o`: each run uses its own `%TEMP%\<guid>` (inference; test in Phase 2) |
| post-install config / auth | none; licence acceptance on download |
| dependencies | .NET Framework 4.7.2+ (4.8/4.8.1 in-place), Windows x64 |
| invocation / anti-patterns | `-c <folder> -s <full path to setup file> -o <out> -q`. Do not: run it with no args (it goes interactive); put it inside the setup folder; trust the exit code alone; pin by tag; commit, cache or upload the exe. |
| health | Windows yellow (2.7) |
| evaluation record | `reference/evaluations/intunewinapputil-windows-2026-10-26.md`, to be written from the Eval notes (tool-evaluation.md "Gates") |
| lastVerified | null until Phase 2 |

## 3. Alternatives (the tool is Windows-only)

Researcher: S3-MdmWinTool-Research. Hands-on: S3-MdmWinTool-Probe. Read date for all: 2026-10-26.

### 3.1 Comparison

| Candidate | Publisher | Licence | Latest / last activity | Adoption | Platforms | Hard blocks | Yellow flags | Verdict |
|---|---|---|---|---|---|---|---|---|
| **simeoncloud/IntuneAppBuilder** (`IntuneAppBuilder.Console`, dotnet tool) | `simeoncloud` org (company; `gh api`: Organization) | Apache-2.0 | NuGet 4.1.0 "5 months ago"; last push 2026-05-18 | 72 stars; 12 contributors (API; the repo page shows 14); NuGet 231.4K total, but per-version downloads are flat at about 2.5-3.3K (critic: the total may be inflated by automation, inference) | Windows, macOS, Linux (.NET 8 SDK) | none found | <500 stars; no tagged releases (provenance is NuGet only, NuGet `"verified":false`); not official; needs a .NET 8 SDK on the build host; no commits 2024-12 to 2026-05; its scheduled tenant tests failed on 2026-05-17/18 and the schedule trigger was then removed (critic) | Best non-official option, but weaker than it first looked. Run `/tool-eval` first if wanted. *v1.1 (6.2): weaker still: CI on `windows-latest` only; #53 rejection 2025-08 to 2025-10; 16 contributors with `anon=1`; now rank 4, behind a native encoder* |
| svrooij/ContentPrep (NuGet lib `SvRooij.ContentPrep`, PSGallery `SvRooij.ContentPrep.Cmdlet`) | `svrooij` personal | GPL-3.0 | v0.4.2 2025-10-03 | 32 stars, 1 contributor; NuGet 13.3K; PSGallery 44,510 (*v1.1: unverified, the PSGallery page errored*) | netstandard2.0/net8.0; **built a package on this Mac (Probe trial 5)** | none | sole maintainer; <500 stars; no release 12+ months; copyleft; author: "This is not a replacement for the Microsoft tool" | Not recommended |
| kenchan0130/intunewin (Go) | personal | Apache-2.0 | v0.0.7 2026-09-23 | 7 stars | all | none | tiny, sole maintainer, pre-1.0 | Not recommended |
| lwalthert/intunewin (Go) | personal | MIT | no releases | 3 stars | all | none | tiny; "majority of tests was generated by AI" | Not recommended |
| LetsGoIntunePackager (Go) | personal | MIT | 1 tag | 5 stars | all | none | tiny; overclaims "identical" output | Not recommended |
| WrapTune-MacOS (.NET GUI + CLI) | personal | MIT | v2.0.1 | 31 stars | macOS only (*v1.1: the CLI engine is pure managed .NET, "can run in CI … doesn't even need macOS"; Linux use undemonstrated*) | none | tiny; no Linux | Not recommended for CI |
| maxihafer/content-prep (Go) | personal | none seen | v1.0.1, 2025-03 | 3 stars | all | none | no licence; README contradicts Microsoft (AES-CTR, digest of ciphertext) | Do not use or cite |
| MSEndpointMgr/IntuneWin32App (PowerShell) | community org | MIT | 1.5.0, 2026-01 | 516 stars | **packaging Windows-only**: it downloads and runs IntuneWinAppUtil.exe (*v1.1: from the moving `raw/master` URL with no hash check; open macOS auth bug #182*) | -- | -- | Not a cross-platform packer |
| Official exe under Wine (+ `winetricks dotnet48`) | -- | Microsoft terms | -- | community reports in #26 (Debian, Fedora, Arch; one Ubuntu 22.04 failure, later fixed with wine-mono) | Linux; no macOS report | -- | fragile, unsupported; 4(a) "work around any technical limitations" is ambiguous here; design 3(a) already excludes it | Not recommended |
| Official exe under dotnet on macOS | -- | -- | -- | Probe trials 1-4 | -- | Requires patching the binary (voids the signature; conflicts with 4(a)/(c)), and it still crashes | -- | **Ruled out** |
| Intune Enterprise App Catalog | Microsoft | paid add-on ("requires a subscription on top of Intune Plan 1 or 2", critic) | -- | -- | Microsoft-hosted | -- | -- | Not an alternative: "a collection of prepared Microsoft and non-Microsoft applications ... hosted by Microsoft". Custom apps such as aitools cannot be added |
| Native build in aitools (openssl + perl/pwsh + zip) | aitools | -- | -- | -- | macOS (LibreSSL 3.3.6 `enc -aes-256-cbc -K -iv` verified; perl Digest::SHA HMAC verified; stock perl has no AES), Linux (openssl presence on target images unknown), Windows (.NET) | -- | aitools would own crypto code; the container is reverse-documented | Feasible only if upload goes through Graph. *v1.1 (6.3): now the preferred all-platform alternative (rank 3), python3 + openssl / .NET, behind `/tool-eval`, `/tool-adopt` and a tenant test* |

### 3.2 Is the `.intunewin` format documented?

**Partly by Microsoft, partly reverse-documented.**

- **Microsoft-documented:**
  - Encryption parameters: Graph `fileEncryptionInfo`.
    - "initializationVector ... Must be 16 bytes."
    - "mac ... The hash of the concatenation of the IV and encrypted file content. Must be 32 bytes."
    - "macKey ... Must be 32 bytes."
    - "Currently, only ProfileVersion1 is supported."
    - "fileDigest ... The file digest prior to encryption."
    - SHA256 only.
  - Key length: the Graph service error "ProfileVersion1 requires an EncryptionKey that is 32 bytes long". *v1.1 (6.2): not on the Learn page (32 bytes is stated only for `mac` and `macKey`); treat as unverified but implied by every implementation.*
  - Upload flow: Graph `mobileAppContentFile`, with create, commit and renewUpload.
  - Cipher and layout, as MIT sample code rather than a spec: `microsoft/mggraph-intune-samples` `macOS_Application_PKG_Add.ps1` writes `[HMAC-SHA256 32][IV 16][AES ciphertext]` using .NET `Aes` defaults. Those defaults are CBC and PKCS7 per the .NET API docs.
  - Inference: Win32 content uses the same ProfileVersion1 scheme as that macOS-PKG sample. This rests on the shared `fileEncryptionInfo` type.
- **Not documented by Microsoft (community only):**
  - The outer zip layout: `IntuneWinPackage/Contents/IntunePackage.intunewin` plus `IntuneWinPackage/Metadata/Detection.xml`.
  - The `Detection.xml` schema and `ToolVersion`.
  - The inner zip compression.
  - The only Microsoft trace is the `Win32_Application_Add.ps1` sample, which *reads* those element names.
- **Observed by us (Probe, ContentPrep output on macOS):**
  - The outer zip has both entries Stored. `Detection.xml` holds `EncryptionKey`, `MacKey`, `InitializationVector`, `Mac`, `ProfileIdentifier` and `FileDigest` in **cleartext**, and `ToolVersion="1.8.6.0"`.
  - The outer size (1085 bytes) equals the size the Microsoft tool computed for the same input before it crashed (Probe trial 4).
- **Consequence:**
  - A `.intunewin` holds its own decryption keys. Treat built packages as confidential until uploaded. They contain no personal data by design (deploy-paths.md).
  - A native packer can rely on Microsoft sources only if it uploads through Graph, which needs no container. Producing a portal-uploadable `.intunewin` means adopting the community container schema.

### 3.3 Windows CI only

- The admin center accepts only a `.intunewin` for a Win32 app: "select a Windows installation file with the extension .intunewin" (add-win32).
- No Microsoft GitHub Action, Azure DevOps task or Graph SDK cmdlet that builds a `.intunewin` was found. A search cannot prove there is none.
- A GitHub-hosted Windows runner runs the official exe with every prerequisite preinstalled (2.9). This is the only path that uses the official tool, and it needs no Windows machine of our own.

### 3.4 Official cross-platform option

None. Issue #26 is open and labelled "enhancement", and Microsoft closed #86 (Cloud Shell, "Exec format error") by pointing to it.

Microsoft documents the tool as a requirement: "Before you can add a Win32 app to Microsoft Intune, you must prepare the app by using the Microsoft Win32 Content Prep Tool" (create-win32-package; quoted by the critic). It also warns about older tool versions: "If you don't use the latest version, you'll see a warning that says the app was packaged using an older version of the tool" (add-win32).

So the sentence in design.md 3(a), "a `.intunewin` needs Microsoft's tool", **matches Microsoft's documented requirement**. It is not a technical necessity, because community packers can write the format. Suggested wording: "Microsoft requires its Content Prep Tool, which runs only on Windows". The conclusion of 3(a) and 3(c) (a native Windows host) holds. (v1.0 before the critic called the 3(a) sentence "wrong as a fact". The critic's finding C1 corrected that.)

## 4. Recommendation for build-package

### 4.1 Build host

- **The Windows package (`intune` kind) builds on a Windows host only: in CI, the GitHub-hosted `windows-2022` runner.**
  - Principle 1 (official endorsement) and principle 2 (verified provenance) rank above principles 4 and 5 (cross-platform delivery, same upstream). That ranking selects the official exe over every community packer.
  - Microsoft's own docs also say Win32 apps "must" be prepared with the Content Prep Tool (3.4).
  - This keeps design.md 3(a), 3(c) and BP-4 as written. 3(a) only needs a citation for its claim (3.4).
- **On macOS and Linux**, `build-package.sh` reports OK `n/a (<host>)` for an unrequested `intune` kind, and ERROR + ACTION "build on Windows (CI job `intune`)" when the kind is requested (design.md 3(a)). *Revised in v1.1 (6.3): when the kind is requested on a non-Windows host, build-package prints or runs the dispatch (`gh workflow run package.yml -f kind=intune`, then `gh run download`) instead of only reporting ERROR.*
- **Local Windows builds** use the same pinned-commit fetch and checks, on any Windows 11 x64 host with .NET Framework 4.7.2+.
- **The commander's Mac cannot build the Windows package locally.** Use `workflow_dispatch` on the CI job. If local Mac builds become a requirement, run `/tool-eval` and `/tool-adopt` on IntuneAppBuilder on all three platforms (P-4), with a one-tenant acceptance test, before any code uses it. *Revised in v1.1 (6.3): the first candidate for local builds on every platform is a native ProfileVersion1 encoder in aitools; IntuneAppBuilder is the existing-tool alternative.*

### 4.2 CI job design (`.github/workflows/package.yml`, job `intune`)

- **Runner and trigger:**
  - `runs-on: windows-2022`.
  - `windows-2025` is a tested fallback before 2022 retires (retirement date not read). *v1.1: no windows-2022 deprecation is announced (actions/runner-images, read 2026-10-26).*
  - Triggers: a tag (release) and `workflow_dispatch`.
- **Tool steps:**
  - The env pins the commit `1d6cfcb...` and the SHA-256 `c1ba45b5...`.
  - The fetch step uses curl from raw.githubusercontent.com at that commit, then `sha256sum -c`.
  - Authenticode check with `Get-AuthenticodeSignature`.
  - No cache, no artifact for the exe.
- **Build steps:**
  - `bash scripts/build-package.sh intune --version <v> --intune-tool "$RUNNER_TEMP/iwau/IntuneWinAppUtil.exe"`.
  - The gate is: output exists and is non-empty, the log has no `ERROR` line, and the stage gates pass. The exit code is recorded but not trusted alone.
- **Artifacts:**
  - Upload `aitools-system-<v>.intunewin`, `aitools-user-<v>.intunewin`, `detect-user-<v>.ps1` and `SHA256SUMS` only.
  - Retention: short. The packages carry their own content keys (3.2).
- **Order:**
  - The Phase 2 gate (tool-lifecycle.md) comes first. The commander runs or approves a test build on Windows before any code calls the exe (implementation-plan.md section 8, B9a "hard stop").
  - The macOS (`pkg`, `macos-14`) and Linux (`deb`, `ubuntu-24.04`) jobs are unchanged. Each kind builds on its native runner (design.md 3(c)).

### 4.3 Risks

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Licence 4(e) breach via artifact, cache, commit or bundling | medium if not written down / high | Write the no-redistribution constraints into implementation-plan.md section 8 step 5 and R-12. The commander records licence acceptance (Q1). |
| The exit code hides failures (#4) | known / medium | Gate on the output file and the log, not the exit code. Phase 2 measures the real codes. |
| Microsoft replaces the exe again (#153) | low / medium | Pin the commit plus our SHA-256. A hash mismatch fails the build loudly. |
| Upstream stagnation: no release in 14.5 months; #167 is one unconfirmed failure report | low-medium / high for the Windows kind | Recheck #167 before B9a. Keep IntuneAppBuilder as the candidate fallback (Q3). |
| Telemetry from the tool in CI (clause 3) | unknown / low | Note it in the evaluation record. Accept for v1 (Q4). |
| `windows-2022` image retirement | certain eventually / low | Test `windows-2025` in the same PR as the job. |
| Intune warns on packages built with an older tool version (documented in add-win32). ContentPrep stamps `ToolVersion="1.8.6.0"` | certain for non-official packers that lag / medium | The official tool at the latest version avoids it. Any alternative needs a tenant acceptance test. |
| Console-buffer crash in CI (#165 `Console.MoveBufferArea ... WriteProgress`; #160 corrupted output) | possible when stdout is redirected / medium | Phase 2 tests `-q` with stdout redirected, and `-qq`. Prefer whichever does not crash, and keep the output-file gate. |
| Packages carry their own decryption keys | certain / low (no personal data in the payload) | Short artifact retention. Upload, then discard. |

## 5. Open questions, INCIDENT markers, delegates and verification

### 5.1 Open questions (with suggested answers)

1. **Who accepts the Microsoft licence terms for nobul-tech CI?** *Suggested:* the commander records it as a decision (P-8) before B9a. It covers use, not redistribution.
2. **Approve P-4 for this tool:** Windows-only build-host tool, registry entry with Windows `evaluating` and macOS/Linux `n/a`, Phase 2 on a Windows host or the runner? *Suggested:* approve. The evaluation record is written from the Eval notes.
3. **Evaluate IntuneAppBuilder now, or only if local Mac builds are needed?** *Suggested:* only if needed. CI covers the requirement, and principle 1 favours the official tool. Revisit if Microsoft stops maintaining the exe or #167 is a live regression. *Superseded in v1.1 by 6.4 Q7: the choice is now native encoder vs IntuneAppBuilder.*
4. **Telemetry: accept or block egress?** *Suggested:* accept for v1 and record it.
5. **Cache the exe in CI?** *Suggested:* no (62 KB).
6. **Delete the Probe's patched copy of the exe** (`.scratch/session-mdmw-prb/dl-x/patched/IntuneWinAppUtil.exe`)? Patching was diagnostic, but it conflicts with licence 4(a)/(c). *Suggested:* yes, delete it. Future probes must not modify licensed binaries.

### 5.2 INCIDENT markers (not filed)

- INCIDENT: (low, plan) design.md 3(a) says "a `.intunewin` needs Microsoft's tool" without citing a source. It matches Microsoft's documented "must" (3.4), but readers may take it as a technical limit. Suggested: cite the create-win32-package sentence. (Lowered from medium after the critic's finding C1.)
- INCIDENT: (medium, plan) implementation-plan.md R-12 and section 8 step 5 do not forbid uploading, caching, committing or bundling the exe, and do not name who accepts the licence.
- INCIDENT: (medium, plan) The B9/B11 build gate must not rely on IntuneWinAppUtil's exit code (#4).
- INCIDENT: (low, plan) design.md 3(c) names only "v1.8.7". It should name commit `1d6cfcb` and our SHA-256, because the release exe was replaced after release (#153).
- INCIDENT: (medium, process) The Probe ran a byte-patched copy of a licensed Microsoft binary as a diagnostic, before the licence had been read in this mission. Licence 4(a) forbids working around "technical limitations". The prompt allowed running the exe under an available runtime but did not forbid modifying it. *Suggested prevention:* the probe instructions in `/tool-eval` (and `/aitool-eval` sandbox walkthrough) say "read the licence before any trial; never modify a licensed binary".
- INCIDENT: (low, harness) GitHub code search found 0 hits in winget-pkgs, although the manifest exists. The playbook should use tree listings for package-manager discovery.
- INCIDENT: (low, harness) The `anthropic-skills:deep-research` skill writes `research_notes/` and `reports/` into the working directory and mandates its own sub-agent process. That conflicts with the mission's access paths and the chrome-devtools rule. The researcher did the research by hand. No rule says which wins.
- INCIDENT: (low, upstream) The winget locale manifest has a wrong PackageUrl (Azure CLI docs) and `License: Unknown`. `microsoftgraph/powershell-intune-samples` returns 404; its successor is `microsoft/mggraph-intune-samples`.

### 5.3 Delegates and verification

| Delegate | Task | Output | How I verified it |
|---|---|---|---|
| S3-MdmWinTool-Eval | `/tool-eval` of the official tool | `S3-MdmWinTool-Eval-notes.md` | Re-read the licence PDF in full (clauses 1, 3, 4(a)-(e) quoted above match). `gh api` releases: latest v1.8.7 2025-08-13T21:30:41Z, previous v1.8.6 2024-02-28. Its exe SHA-256 matches the Probe's independent download. |
| S3-MdmWinTool-Research | Alternatives and format | `S3-MdmWinTool-Research-notes.md` | `gh api` on simeoncloud/IntuneAppBuilder: Organization, 72 stars, Apache-2.0, pushed 2026-05-18, not archived (matches). `gh api` issue #26: `open`, "Linux executable?", 2020-02-04 (matches). |
| S3-MdmWinTool-Probe | Hands-on on macOS arm64 | `S3-MdmWinTool-Probe-notes.md` | Hash and blob SHA cross-checked against Eval. Its PE facts (x64, .NET Framework 4.7.2, PKCS#7) agree with Eval's separate parser. Read its trial logs in full. |
| S3-MdmWinTool-Critic | Independent refutation attempt, without the other notes | `S3-MdmWinTool-Critic-verdict.md` | See 5.4 |

The Eval and Research delegates had launched in parallel (to save time) because the prior PkgWin notes had already shown the .NET Framework 4.7.2 prerequisite. Eval then confirmed the tool is Windows-only, which met the precondition for the research.

### 5.4 Critic verdict

S3-MdmWinTool-Critic reviewed this file. It did not read the other delegates' notes, and it checked primary sources itself.

**Verdict: UPHELD WITH CORRECTIONS.** The recommendation stands. Full table: `S3-MdmWinTool-Critic-verdict.md`.

- **C1 (major)** was the 3(a) "wrong as a fact" claim. Corrected in 3.4 and in the INCIDENT, from Microsoft's documented "must".
- **Eleven minor findings, all applied:**
  - C2: the old-version warning is documented.
  - C3: Microsoft members were active in 2026-10, and there is a `test`-branch commit.
  - C4: a Microsoft member endorses the raw URL.
  - C5: the tag resolves to the pinned commit.
  - C6: the ARM "fix" is a Microsoft claim, unverified.
  - C7: the console-crash risk (#165).
  - C8: #167 is unconfirmed.
  - C9: extra IntuneAppBuilder yellow flags.
  - C10: the winget payload is official, the manifest is community.
  - C11: the Enterprise App Catalog is not an alternative.
  - C12: the contributor count.
- **Checked by the orchestrator:** C3/C4 (`gh api` issue #163 comments: brmcmill, MEMBER, 2026-10-08, "Try this one, good: https://raw.githubusercontent.com/...") and C5 (`gh api` tag ref = `1d6cfcb`).
- **Applied without re-check:** C1's Learn quote, C7, C9 and C11. They do not change the recommendation.
- **The critic also confirmed:** licence clauses 1, 3 and 4(a)-(e), the release dates, the unsigned exe commits, the runner .NET line, and the Graph `fileEncryptionInfo` quotes.
- **The critic could not check:** the exe hash and Authenticode (no binary download), telemetry, the windows-2022 retirement date, the other community packers, and whether any Microsoft Action or DevOps task builds `.intunewin`.

## 6. Deep-research pass (v1.1)

Mission MDM-WINTOOL-DR, coordinator S3-MdmWinToolDR, 2026-10-26. The commander's order: "it's a problem if we can only make MDM packages for windows. if it finds that it only runs on windows, ask it to use /deep-research skill to find an alternative." and "can it run on all platforms or does it have to be windows? if all platforms, then /tool-adopt and /tool-eval as required for all platforms".

Full report: [Dispatch Windows builds now, go native later (v1.0)](../../.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinToolDR/reports/Intunewin%20packaging%20without%20Windows.md). It synthesises five research notes (official Microsoft tooling, format and native build, community packers, emulation and CI runners, MDM ecosystem practice) in `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinToolDR/research_notes/Intunewin packaging without Windows/`. All web sources were read on 2026-10-26; code is cited at pinned commits in the report. This section summarises it; the report's citations carry the evidence.

### 6.1 What the research found

- **The official tool runs only on Windows; the format runs anywhere.** `IntuneWinAppUtil.exe` v1.8.7 (2025-08-13) is .NET Framework 4.7.2 with no macOS, Linux or .NET (Core) build. Linux request #26 has been open since 2020-02-04 with no Microsoft reply, and Intune's What's New page never mentions the tool. A `.intunewin` is a Stored (uncompressed) outer ZIP holding `IntuneWinPackage/Contents/IntunePackage.intunewin` (`HMAC-SHA256[32] | IV[16] | AES-256-CBC/PKCS7 ciphertext` of a ZIP of the source folder, "ProfileVersion1") and a cleartext `IntuneWinPackage/Metadata/Detection.xml` with the keys and digest. At least four independent implementations agree on it, and a size check against the official tool's output (5,957,009 plaintext bytes, giving exactly the 5,957,072 bytes measured) pins CBC/PKCS7.
- **Graph upload sends only the inner encrypted file.** Microsoft's MIT sample `Win32_Application_Add.ps1` (@ `631eea2`) reads `Detection.xml` for the keys, uploads only the inner file to the Azure Storage SAS URI and commits `fileEncryptionInfo`. A packer-less Graph pipeline therefore rests only on Microsoft-sourced pieces, and the container, `Detection.xml` schema and `ToolVersion` question drop out. Whether a Win32 content file the tool did not produce commits in a real tenant is **untested by this mission**.
- **Licence.** Clauses 4(a) (work around limitations), 4(b) (reverse engineer) and 4(e) (redistribute) restrict running and sharing the exe. No clause mentions an OS, emulation, CI, or re-implementing the format, so an independently written encoder does not engage it (not legal advice).
- **No cross-platform option is fit to adopt today without `/tool-eval` and a tenant acceptance test.** More than fifteen community packers exist. The two with real adoption carry yellow flags: IntuneAppBuilder (Organization, Apache-2.0, NuGet unverified, CI on Windows only, #53 rejection in 2025) and ContentPrep (personal, sole maintainer, GPL-3.0). Others are ruled out: Wine (community-only, distro-fragile, no macOS report), Mono/dotnet/patched or decompiled exe (licence), iamawrapper (its licence forbids "Competing Products"), `IntuneWinFile` (inactive 2+ years).
- **Ecosystem practice.** Every published Win32 CI pipeline found runs the official exe on a `windows-latest` runner. WinTuner packs with ContentPrep by default, and almenscorner/intune-uploader encrypts ProfileVersion1 in Python for macOS app types, so Intune accepts non-Microsoft ProfileVersion1 content in practice. GitHub Actions is free for this public repository on standard runners.
- **Microsoft alternatives that avoid `.intunewin`** (Enterprise App Catalog, Store app, Windows LOB MSI/MSIX, platform scripts) all change build-package's deliverable. Non-Windows MSI/MSIX tooling was not researched (unknown).

### 6.2 Corrections to v1.0

The report wins where it disagrees with v1.0 (it re-read primary sources and code at pinned commits). Each correction is marked inline where the v1.0 statement stands.

| Topic | v1.0 said | v1.1 (report) | Where marked |
|---|---|---|---|
| Microsoft documentation of the encryption | "Microsoft documents the encryption and the Graph upload" | Microsoft documents parameters and sizes only; AES/CBC/PKCS7/HMAC appear only in MIT sample code; the `aka.ms/fileencryptioninfo` pointer on the Graph commit page now redirects to Bing | 1 item 3 |
| 32-byte encryption key | Rests on a Graph service error string | Not on the Learn page; unverified but implied by every implementation | 3.2 |
| maxihafer "AES-CTR" | Contradicts Microsoft | Disproved by the size arithmetic (agree, strengthened) | none needed |
| IntuneAppBuilder as acceptance evidence | Strongest candidate; CI publishes to a real tenant | CI is `windows-latest` only, so non-Windows output is unproven; #53 rejection 2025-08 to 2025-10; 16 contributors with `anon=1` (v1.0: 12) | 1 item 3, 3.1 |
| WrapTune-MacOS | "macOS only", no Linux | CLI is pure managed .NET and "can run in CI … doesn't even need macOS"; author claims real-tenant deploys; Linux undemonstrated | 3.1 |
| Runner labels | "Do not use `windows-11-arm`"; retirement date not read | `windows-11-arm` and `windows-11-vs2026-arm` exist; `windows-latest`/`windows-2025` ship VS 2026; no windows-2022 deprecation announced. The Arm advice stands (#159) | 2.9, 4.2 |
| IntuneWin32App | Downloads and runs the exe | Also from moving `raw/master` with no hash check; open macOS auth bug #182 | 3.1 |
| ContentPrep PSGallery downloads | 44,510 | PSGallery page errored; unverified | 3.1 |
| Learn Win32 overview URL | `.../deployment/apps-win32-app-management` (S3-MdmWinTool notes) | That URL now 404s; the current page is `.../deployment/win32` | not cited in this file |
| AutoPkg route | Not covered | intune-uploader (Apache-2.0, 83 stars) encrypts ProfileVersion1 natively, macOS app types only | 6.1 |
| ARM fix claim | "Should be addressed in latest release", unverified | #138 closed 2025-10-15 "This should be fixed in the latest release" while the latest is still 1.8.7 (agree: unverified) | none needed |

**v1.0 claims that stand:** the official tool is Windows-only; the licence reading (use allowed, no redistribution, pin commit `1d6cfcb` plus our SHA-256 and Authenticode, never commit/cache/upload the exe); the `/tool-eval` result (Windows yellow, no hard blocks, Phase 2 gate pending); the CI job design in 2.9 and 4.2; the exit-code gate; Wine and the patched exe ruled out; the format being only partly Microsoft-documented.

### 6.3 Recommendation: what changed and why

The report's ranked recommendation:

| Rank | Option | Verdict |
|---|---|---|
| 1 | Official exe on a Windows host: GitHub-hosted `windows-2022` (fallback `windows-2025`) or local Windows x64, fetched per job at commit `1d6cfcb` with SHA-256 and Authenticode checks | **Adopt** (unchanged from v1.0 4.1/4.2) |
| 2 | Remote dispatch from non-Windows hosts: `gh workflow run package.yml -f kind=intune`, then `gh run download` | **Adopt** as build-package's answer on macOS, Ubuntu, Claude Code web and Cursor cloud |
| 3 | Native ProfileVersion1 encoder in aitools (`.sh` with python3 + openssl, `.ps1` with .NET `Aes`), built from Graph docs and MIT samples only | Best route to real all-platform builds; **not adopted until gated** |
| 4 | simeoncloud/IntuneAppBuilder | Candidate for `/tool-eval` if the commander prefers an existing tool over rank 3 |
| 5 | Parallels Windows 11 Arm VM on the commander's Mac | Optional manual route; test 1.8.7 on Arm first (#159) |
| 6 | ContentPrep, WrapTune CLI, kenchan0130/intunewin and other small packers | Not recommended |
| 7 | Official exe under Wine on x86_64 Linux | Not recommended |
| 8 | Mono-only, dotnet, patched or decompiled exe; iamawrapper; `IntuneWinFile`; impersonation "IntuneWinAppUtil" repos | Ruled out |

**What stands:** rank 1 is v1.0's recommendation (section 4.1 first bullet, 4.2). The official tool on `windows-2022` remains the primary path, for the same reason: evaluation principles 1 and 2 rank above 4 and 5.

**What changed, exactly:**

1. **Non-Windows hosts (v1.0 4.1, second bullet).** v1.0: on macOS and Linux a requested `intune` kind reports ERROR + ACTION "build on Windows". v1.1: build-package prints or runs the remote dispatch to the Windows runner and downloads the artifact. *Why:* the commander said Windows-only packaging is a problem. Dispatch makes build-package invocable from every host today without leaving Microsoft's supported path. It is cross-platform orchestration, not cross-platform building: the Windows step still runs on a Windows VM. This departs from design.md 3(a)'s ERROR + ACTION wording; design.md is not changed by this update.
2. **The all-platform alternative (v1.0 1 item 5, 4.1 last bullet, 5.1 Q3).** v1.0: IntuneAppBuilder first, and only if local Mac builds become a requirement. v1.1: a native ProfileVersion1 encoder in aitools first (rank 3), IntuneAppBuilder second (rank 4). *Why:* the encoder scores better on principle 2 (our own code; its basis is Microsoft docs and MIT samples) and principle 5 (the same code on every host), and with Graph upload every byte rests on a Microsoft source. IntuneAppBuilder is weaker than v1.0 said (6.2). The encoder conflicts with principle 4 ("don't rebuild what exists"), which ranks below principle 2. It requires the commander to accept aitools owning about 200 lines of crypto (the community researcher's estimate).
3. **The gate for any alternative.** Per the commander's order, rank 3 or rank 4 goes through `/tool-eval` and `/tool-adopt` on every platform (for rank 3: openssl and python3 delivery on macOS, Linux, Claude Code web, Cursor cloud; .NET on Windows), then a tenant acceptance test repeated on a schedule, because Intune's commit-time checks are undocumented and changed without notice in 2025 (#53). Rank 3 must not copy GPL ContentPrep code or inspect the exe.

**Sequence:** ship ranks 1-2 now; then decide rank 3 against rank 4 (Q7) and run the scheduled tenant test whichever wins.

### 6.4 Open questions and unknowns added in v1.1

7. **Native encoder (rank 3) or IntuneAppBuilder (rank 4) as the all-platform alternative?** *Suggested:* the native encoder, delivering through Graph upload, if the commander accepts aitools owning the crypto; otherwise IntuneAppBuilder through `/tool-eval`.
8. **Is the Graph-upload deliverable acceptable, or is a portal-uploadable `.intunewin` required?** *Suggested:* Graph upload first; a portal package means adopting the community `Detection.xml` schema and deciding what `ToolVersion` to stamp (the portal's "older version" warning most likely keys off it, unverified).

Unknowns to retire first (cheap): whether the Claude Code web GitHub proxy allows `actions:write` workflow dispatch and artifact download redirects; how Cursor cloud authenticates `gh` (a `GH_TOKEN` secret, undocumented default); whether `gh run watch`/`view` avoid GraphQL; whether openssl is present on the target Ubuntu images; whether a self-encrypted Win32 content file commits in a real tenant. `workflow_dispatch` also requires the workflow file on the default branch.

### 6.5 INCIDENT markers from the report (not filed)

The report lists ten INCIDENT findings (report section "INCIDENT findings reported by the researchers"). The two that bear on build-package:

- INCIDENT: (medium, security) Impersonation repos for IntuneWinAppUtil appear in GitHub search (`intpack/IntuneWinAppUtil` pointing to an 11 MB `intunew/IntuneWinAppUtil` v1.8.2 zip; `sltd31689-gif/IntuneWinAppUtil.exe` holding `.scr` files). build-package docs and `/tool-eval` notes should state that only `microsoft/Microsoft-Win32-Content-Prep-Tool` at a pinned commit plus a SHA-256 is acceptable.
- INCIDENT: (low, upstream) The Graph commit-action page links its ProfileVersion1 sample to `https://aka.ms/fileencryptioninfo`, which redirects to Bing. Cite `microsoft/mggraph-intune-samples` directly.
