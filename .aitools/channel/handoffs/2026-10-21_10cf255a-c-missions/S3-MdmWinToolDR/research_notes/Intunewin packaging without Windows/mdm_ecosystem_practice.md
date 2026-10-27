# Ecosystem practice: how Intune/MDM tools and vendors build and upload Win32 (.intunewin) packages, and which do it without Windows (as of 2026-10-26)

Researcher: S3-MdmWinToolDR-Ecosystem (mission MDM-WINTOOL-DR). All reads dated 2026-10-26. Web pages quoted below were read with chrome-devtools (own isolated page); repo facts and source code were read with `gh api` (raw file contents, GraphQL repo metadata). Nothing was downloaded, installed or run. Firecrawl not used. Pages were read in full unless marked "partial". "Read" for GitHub source code means the full file via the contents API.

Repo metadata snapshot (`gh api graphql`, 2026-10-26):

| Repo | Owner type | Stars | Forks | Last push | Licence | Latest release |
|---|---|---|---|---|---|---|
| MSEndpointMgr/IntuneWin32App | Organization | 516 | 119 | 2026-01-25 | MIT | none on GitHub (PSGallery 1.5.0) |
| svrooij/WinTuner | User | 260 | 37 | 2026-07-13 | GPL-3.0 | v1.4.1, 2026-07-03 |
| svrooij/ContentPrep | User | 32 | 2 | 2025-10-03 | GPL-3.0 | v0.4.2, 2025-10-03 |
| simeoncloud/IntuneAppBuilder | Organization | 72 | 5 | 2026-05-18 | Apache-2.0 | none (NuGet only) |
| Micke-K/IntuneManagement | User | 2,118 | 384 | 2026-10-25 | MIT | 3.11.0, 2026-09-23 |
| almenscorner/IntuneCD | User | 429 | 55 | 2026-07-02 | MIT | v2.6.0, 2026-05-29 |
| almenscorner/intune-uploader (the "IntuneUploader" AutoPkg processors) | User | 83 | -- | 2026-10-05 | Apache-2.0 | -- |
| PSAppDeployToolkit/PSAppDeployToolkit | Organization | 2,434 | 567 | 2026-10-26 | LGPL-3.0 | 4.1.8, 2026-01-14 |
| aaronparker/packagefactory (PSPackageFactory) | User | 88 | -- | 2026-07-20 | MIT | -- |

`almenscorner/IntuneUploader` does not exist (GraphQL NOT_FOUND); the project is `almenscorner/intune-uploader`.

## 1. MSEndpointMgr IntuneWin32App PowerShell module

### Takeaway
IntuneWin32App does not pack natively: `New-IntuneWin32AppPackage` downloads Microsoft's `IntuneWinAppUtil.exe` from the repo's `master` branch into `$env:TEMP` and runs it, so packaging is Windows-only. Upload (`Add-IntuneWin32App`) is Graph plus Azure Storage block-blob PUTs (derived from Microsoft's Win32_Application_Add.ps1 sample), with an optional AzCopy path that downloads the Windows AzCopy build. macOS use is not declared and has an open auth bug.

### Cited Findings
- `New-IntuneWin32AppPackage` defaults `IntuneWinAppUtilPath` to `(Join-Path -Path $env:TEMP -ChildPath "IntuneWinAppUtil.exe")`; if absent it runs `Start-DownloadFile -URL "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"` and then invokes it with `-c ... -s ... -o ... -q`, checking `ExitCode -eq 0` and then that the `.intunewin` exists — [Public/New-IntuneWin32AppPackage.ps1](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/Public/New-IntuneWin32AppPackage.ps1) (gh api, full file)
- It downloads from the moving `master` path with no hash or signature check (no such code in the function) — same file
- Chunk upload: `Invoke-AzureStorageBlobUploadChunk` does `Invoke-WebRequest "$StorageUri&comp=block&blockid=$ChunkID" -Method Put` with `x-ms-blob-type: BlockBlob`; header says it is "a modified function that was originally developed by Dave Falkus and is available here: https://github.com/microsoftgraph/powershell-intune-samples/blob/master/LOB_Application/Win32_Application_Add.ps1" — [Private/Invoke-AzureStorageBlobUploadChunk.ps1](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/Private/Invoke-AzureStorageBlobUploadChunk.ps1)
- Alternative AzCopy upload path downloads `https://aka.ms/downloadazcopy-v10-windows` and resolves `azcopy_windows_amd64*` under `$env:TEMP` — [Private/Invoke-AzureCopyUtility.ps1](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/Private/Invoke-AzureCopyUtility.ps1)
- Private helpers include `Invoke-AzureStorageBlobUpload`, `...UploadFinalize`, `...UploadRenew`, `Wait-IntuneWin32AppFileProcessing`, `Expand-IntuneWin32AppCompressedFile` — `gh api repos/MSEndpointMgr/IntuneWin32App/contents/Private`
- Manifest: `ModuleVersion = '1.5.0'`, `PowerShellVersion = '5.0'`, `# CompatiblePSEditions = @()` (commented out, i.e. no declared Core/macOS/Linux support) — [IntuneWin32App.psd1](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/IntuneWin32App.psd1)
- Open issue #182 "Bug - Authentication Header not working on MacOS" (2024-10-10, open) — `gh search issues --repo MSEndpointMgr/IntuneWin32App macOS`
- PowerShell Gallery: 961,872 total downloads; 1.5.0 current (103,848 downloads), "Last Published 1/25/2026"; 1.4.4 had 519,761; owner NickolajA; "Minimum PowerShell version 5.0" — [PSGallery IntuneWin32App](https://www.powershellgallery.com/packages/IntuneWin32App) (chrome-devtools)

### Inferences
- The most-downloaded community Win32 module treats the official exe as *the* packer and fetches it at runtime; the ecosystem norm is "download Microsoft's exe on a Windows host", not bundling it (consistent with licence 4(e) no-redistribution).
- Upload (Graph + Azure Blob REST) is plain HTTP and would be portable in principle; packaging is the only hard Windows dependency. With `$env:TEMP` unset on macOS/Linux pwsh, even the default path logic would fail (inference from code; not tested).

### Gaps
- Not tested whether `Add-IntuneWin32App` works under pwsh 7 on macOS/Linux with a pre-built `.intunewin`; only the open #182 bug was found.

## 2. svrooij WinTuner (WinGet apps to Intune)

### Takeaway
WinTuner packs natively by default with svrooij's own `SvRooij.ContentPrep` library (a reimplementation of the Microsoft tool) and only uses `IntuneWinAppUtil.exe` when an env var opts in, which it refuses on non-Windows. Its author states package and publish are cross-platform. It is a personal GPL-3.0 project, self-described beta, with ~152K PSGallery downloads.

### Cited Findings
- Default packager registration: `if (Environment.GetEnvironmentVariable("WINGETINTUNE_USE_PROCESS_PACKAGER") == "true") { if (Environment.OSVersion.Platform != PlatformID.Win32NT) { throw new NotSupportedException("Process packager is only supported on Windows"); } services.AddTransient<IIntunePackager, ProcessIntunePackager>(); } else { services.AddTransient<IIntunePackager, LibraryIntunePackager>(); }` — [src/WingetIntune/WingetServiceCollectionExtension.cs](https://github.com/svrooij/WinTuner/blob/main/src/WingetIntune/WingetServiceCollectionExtension.cs) (gh api, full file)
- `LibraryIntunePackager` uses `SvRooij.ContentPrep.Packager` (`packager.CreatePackage(...)`, plus `CreateUploadablePackage` for "partial" packages) — [src/WingetIntune/Intune/LibraryIntunePackager.cs](https://github.com/svrooij/WinTuner/blob/main/src/WingetIntune/Intune/LibraryIntunePackager.cs)
- `ProcessIntunePackager` doc comment: "This implementation uses the IntuneWinAppUtil.exe tool to create the .intunewin package." — `gh search code IIntunePackager --repo svrooij/WinTuner` (text match in src/WingetIntune/Intune/ProcessIntunePackager.cs)
- Upload: "Old IAzureFileUploader implementation is not used anymore, it does not work correctly. //...AzCopyAzureUploader"; uses `ChunkedAzureFileUploader`; Graph base `https://graph.microsoft.com/beta` — WingetServiceCollectionExtension.cs
- README: "This is the PowerShell version of the WinTuner application, requiring PowerShell 7.4 (net8.0)." and "This is a beta application, it's not yet ready for production use." — [github.com/svrooij/WinTuner](https://github.com/svrooij/WinTuner) (chrome-devtools; README is short, read in full)
- Older CLI (NuGet SvRooij.Winget-Intune.Cli 0.9.0): "The package and publish commands are cross-platform, and should work on any platform that supports dotnet 8. ... The msi command is still windows only, as it uses the Microsoft.Deployment.WindowsInstaller package." and "Some commands run the winget in the background and are thus Windows-only" — [NuGet 0.9.0](https://www.nuget.org/packages/SvRooij.Winget-Intune.Cli/0.9.0) (chrome-devtools)
- Current CLI page: "This application is depreceated, please move to the PowerShell module." Last updated 5/28/2025 — [NuGet SvRooij.Winget-Intune.Cli](https://www.nuget.org/packages/SvRooij.Winget-Intune.Cli/)
- PSGallery: 151,968 total downloads; 1.4.1 (4,208) "Last Published 7/3/2026"; 1.3.2 had 14,233; owner svrooij; "Stephan van Rooij 2024, licensed under GNU GPLv3"; "Minimum PowerShell version 7.4" — [PSGallery WinTuner](https://www.powershellgallery.com/packages/WinTuner) (chrome-devtools)
- Docs cmdlets include `New-WtWingetPackage` ("Downloads the installer for the package and creates an .intunewin file for uploading in Intune"), `Deploy-WtWin32App`, `Test-WtIntuneWin`, and a "ContentPrep" category — [wintuner.app docs](https://wintuner.app/docs/category/wintuner-powershell/), [New-WtWingetPackage](https://wintuner.app/docs/wintuner-powershell/New-WtWingetPackage/) (chrome-devtools)

### Inferences
- WinTuner is the clearest real-world case of a widely used (150K+ downloads) tool that ships non-Microsoft-packed `.intunewin` content to Intune tenants by default, i.e. Intune evidently accepts it in practice. This is user-adoption evidence, not a Microsoft statement of support.
- The current module's own docs (read) do not state macOS/Linux support; the explicit cross-platform statement is on the deprecated CLI. The code path (Library packager, no Windows check) is platform-neutral, but WinGet-related commands and `Test-WtIntuneWin` (Windows Sandbox) are Windows-bound (inference from code and docs).

### Gaps
- No WinTuner doc page found that states the PowerShell module's supported OSes. Not tested on macOS.
- No telemetry/acceptance data from WinTuner on how many uploads come from non-Windows hosts.

## 3. Other tools: IntuneManagement, IntuneCD, intune-uploader, AutoPkg, PSADT, Master Packager, IntuneAppBuilder, PSPackageFactory

### Takeaway
None of the large admin tools build `.intunewin` on non-Windows: IntuneManagement and IntuneCD only consume/back up apps; PSADT and Master Packager document the Microsoft tool (Master Packager also has its own Windows GUI converter). The Mac-admin ecosystem (AutoPkg + almenscorner/intune-uploader) does native ProfileVersion1 AES-256-CBC + HMAC-SHA256 encryption in Python, but only for macOS app types, not Win32. IntuneAppBuilder calls itself cross-platform, but its own CI (including tenant tests) runs on `windows-latest`.

### Cited Findings
- **Micke-K/IntuneManagement**: README "Version 4.0 is in beta. A full rewrite that also runs on macOS and Linux"; v3 prerequisites ".Net 4.7", "PowerShell 5.1"; "[^2]: Export is support but .intunewin files will not be exported. The .intunewin file must exist in the exported folder or in the folder defined in Settings -> App packages folder."; "The app encryption and upload is based on [Graph PowerShell Intune Examples]" — [README](https://github.com/Micke-K/IntuneManagement) (gh api raw, full)
- IntuneManagement source has no `IntuneWinAppUtil` hit (`gh search code`: 0 results); `EndpointManager.psm1` only opens `*.intunewin` files and saves "Encrypted intunewin (*.encrypted)" — consumes, does not build — `gh api .../Extensions/EndpointManager.psm1` grep
- **almenscorner/IntuneCD**: repo tree has `backup/Intune/Applications.py` but no `update/Intune/Applications.py` (update modules exist only for AppConfiguration, AppProtection, AppleEnrollmentProfile) — `gh api .../git/trees/HEAD?recursive=1`
- **almenscorner/intune-uploader**: "Set of AutoPkg processors for uploading to Intune"; LOB mode needs "a pkg file that is signed with a valid Apple Developer ID certificate and notarized" — [README](https://github.com/almenscorner/intune-uploader)
- intune-uploader `encrypt_app()`: `encryptionKey = os.urandom(32)`, `hmacKey = os.urandom(32)`, `initializationVector = os.urandom(16)`, `profileIdentifier = "ProfileVersion1"`, PKCS7 padding, `Cipher(algorithms.AES(encryptionKey), modes.CBC(initializationVector))`, HMAC-SHA256 over IV+ciphertext, output `signature + iv_data`, file digest SHA256 of plaintext; app lookup filters `isof('microsoft.graph.macOSDmgApp') or isof('microsoft.graph.macOSPkgApp') or isof('microsoft.graph.macOSLobApp')` — [IntuneUploaderLib/IntuneUploaderBase.py](https://github.com/almenscorner/intune-uploader/blob/main/IntuneUploader/IntuneUploaderLib/IntuneUploaderBase.py) (gh api, lines 344-407, 584)
- almenscorner/intune-autopkg-tools: BSD-3-Clause, 11 stars, pushed 2025-04-14 — `gh search repos IntuneUploader`
- **PSAppDeployToolkit** official guide: prerequisites include "The Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe)."; "IntuneWinAppUtil.exe -c C:\Packages\YourApp -s Invoke-AppDeployToolkit.exe -o C:\Output" — [psappdeploytoolkit.com deploy-with-intune](https://psappdeploytoolkit.com/docs/how-to/deploy-with-intune) (chrome-devtools, full page)
- **Master Packager**: "There are two ways to create an .intunewin file: Microsoft Win32 Content Prep Tool; Master Packager Toolbox"; the toolbox converter "supports both conversion and extraction"; "If you are using Intune Integration in Master Packager Toolbox, the .intunewin file is created automatically during the upload workflow." — [Master Packager .intunewin File Format](https://docs.masterpackager.com/master-packager-suite/master-packager-toolbox/intune/intunewin-file-format/) (chrome-devtools, full)
- **simeoncloud/IntuneAppBuilder** README: "Package MSI and Win32 application packages as .intunewin format to Microsoft Intune with this cross-platform tool."; outputs `.intunewin` (for its publish command) and `.portal.intunewin` ("can be uploaded to the Intune Portal as a Win32 app"); "When the tool is running on a non-Windows system, the tool will log a warning and continue creating the package without the additional MSI metadata."; "The IntegrationTests project publishes real apps to a Microsoft Intune tenant" — [README](https://github.com/simeoncloud/IntuneAppBuilder) (gh api raw, full)
- IntuneAppBuilder CI: both `Build` (including `dotnet test` with tenant secrets) and `Deploy` jobs are `runs-on: windows-latest` — [.github/workflows/ci.yml](https://github.com/simeoncloud/IntuneAppBuilder/blob/master/.github/workflows/ci.yml)
- **aaronparker/packagefactory** (PSPackageFactory) `import-package.yml`: `runs-on: windows-latest`, caches `MSAL.PS, IntuneWin32App, Evergreen, VcRedist`, `Connect-MSIntuneGraph` with client secret, runs `New-Win32Package.ps1 ... -Import $true` — [import-package.yml](https://github.com/aaronparker/packagefactory/blob/main/.github/workflows/import-package.yml) (gh api, full)
- **Ben Whitmore / MSEndpointMgr, 2026-08-16**: "You build the .intunewin first with the Win32 Content Prep Tool (typically)"; script downloads `https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe`; "the .intunewin is just a ZIP file. Inside it, IntuneWinPackage\Metadata\Detection.xml holds the encryption info ... and IntuneWinPackage\Contents holds the encrypted payload you will upload"; "Every step is a Graph call except the upload, which goes straight to Azure Blob Storage using the SAS URI that Graph returns"; "Commit the file, passing Intune the encryption keys so it can decrypt and validate"; "Run the packaging script on PowerShell 7 ... It also runs on Windows PowerShell 5.1 if you have .NET Framework 4.7.2 or later." — [Creating a Win32 App in Intune with PowerShell and Microsoft Graph](https://msendpointmgr.com/2026/08/16/win32-app-intune-powershell-graph/) (chrome-devtools; 86K-char article, searched by keyword, partial read)

### Inferences
- Graph upload never sends the outer `.intunewin` zip, only the encrypted inner payload plus `fileEncryptionInfo` at commit (Whitmore). So for API-based publishing, what Intune validates is the ProfileVersion1 encryption, not the container. intune-uploader shows that Python-native ProfileVersion1 encryption is accepted by Intune for macOS app types; the same `fileEncryptionInfo` type is used for Win32 (inference, consistent with earlier findings 3.2).
- IntuneAppBuilder's tenant tests run on Windows, so they do not show that its macOS/Linux output is accepted (inference from ci.yml). This weakens the earlier findings' "CI tests that publish to a real Intune tenant" as cross-platform evidence.
- Master Packager is a Windows desktop product; whether its converter wraps the Microsoft tool or is native is not stated (unknown).

### Gaps
- Master Packager: native or wrapped packer — not stated in docs read.
- AutoPkg/Munki: no processor found that produces Win32 `.intunewin`; a search cannot prove there is none.
- Flexera AdminStudio and EMCO MSI Package Builder appear in search results with `.intunewin` conversion features (Windows products); pages not read.

## 4. Commercial vendors (Patch My PC / Scappman, Robopack, Liquit)

### Takeaway
No commercial vendor read publicly says which packer it uses. Patch My PC Publisher runs on a Windows client or server; Patch My PC Cloud and Robopack are SaaS (Robopack tests on provisioned VMs). Scappman is now part of Patch My PC. Nothing found for Liquit.

### Cited Findings
- Patch My PC Publisher V3.x: "can be installed on either a Microsoft Windows client or Windows Server operating system ... when publishing applications and updates solely to Microsoft Intune"; Intune-only on Windows 11 needs WSUS RSAT tools; "Some organizations have strict security or operational requirements mandating the use of Publisher instead of Patch My PC Cloud" — [Intune Software Requirements for Patch My PC Publisher](https://docs.patchmypc.com/patch-my-pc-publisher/requirements/intune-requirements/software) (chrome-devtools, read to the RSAT section; partial)
- Patch My PC ideas portal: a request for the "Ability to download .intunewin content for applications published via Patch my PC Cloud" (PATCHMYPC-I-6072, merged from I-5999) — via WebSearch snippet of [ideas.patchmypc.com PATCHMYPC-I-5999](https://ideas.patchmypc.com/ideas/PATCHMYPC-I-5999) (NOT re-read in browser)
- Scappman: "following the takeover of Scappman by Patch My PC, the solution has changed completely to Patch My PC" — WebSearch snippet of [VanRoey](https://www.vanroey.be/en/infrastructure/scappman-microsoft-intune/) (NOT re-read in browser)
- Robopack Custom Packaging: "Click Convert Package and upload your installer"; with Analyze and Test it "Uploads to secure storage; Scans for viruses; Provisions a virtual machine; Installs the app ...; Generates a detection method for Intune" — [Robopack Custom Packaging](https://docs.robopack.com/docs/features/custom-packaging/) (chrome-devtools, first ~3,500 chars; partial)

### Inferences
- The SaaS vendors build `.intunewin` server-side; the customer needs no Windows host. Whether their backend is Windows + the Microsoft exe or a native packer is not public. Patch My PC Cloud users cannot even download the `.intunewin` (inferred from the idea request), so the package stays in the vendor pipeline.

### Gaps
- Packer and backend OS for Patch My PC Cloud, Robopack, Scappman, Liquit: unknown (no public statement found).
- Liquit: no relevant source found.

## 5. CI templates and cross-platform MDM tooling (Jamf, Kandji, others)

### Takeaway
Every Win32 pipeline found runs on a Windows runner (`windows-latest`) with the Microsoft tool via IntuneWin32App, including IntuneAppBuilder's own CI. No Microsoft-published GitHub Action or Azure DevOps task that builds `.intunewin` was found, and no Jamf/Kandji tool that produces Windows Intune packages.

### Cited Findings
- PSPackageFactory: `runs-on: windows-latest` + IntuneWin32App — [import-package.yml](https://github.com/aaronparker/packagefactory/blob/main/.github/workflows/import-package.yml)
- IntuneAppBuilder CI: `runs-on: windows-latest` — [ci.yml](https://github.com/simeoncloud/IntuneAppBuilder/blob/master/.github/workflows/ci.yml)
- Searches for an ubuntu/macOS GitHub Action building `.intunewin`, an Azure DevOps YAML example, and Jamf/Kandji Win32 tooling returned nothing relevant (WebSearch, 2026-10-26; three queries)

### Inferences
- In practice the ecosystem treats "Windows runner + official exe" as the default CI pattern. Non-Windows packing exists (WinTuner/ContentPrep, IntuneAppBuilder, small Go tools), but no published CI template using it on Linux/macOS was found.
- Jamf/Kandji manage Apple devices; producing Windows Intune packages is out of their scope (inference; no source).

### Gaps
- A search cannot prove absence of a Microsoft Action/DevOps task or a Linux CI template.

## 6. Does the ecosystem show Intune accepts non-Microsoft-packed content?

### Takeaway
Yes, by practice, not by Microsoft statement. WinTuner packs with a non-Microsoft library by default and has ~152K downloads. IntuneAppBuilder publishes real apps to tenants. intune-uploader encrypts natively for macOS types. Microsoft's docs still say Win32 apps "must" be prepared with its tool (prior findings 3.4), and the earlier findings note a documented warning for packages stamped with an old `ToolVersion`.

### Cited Findings
- WinTuner default `LibraryIntunePackager` (SvRooij.ContentPrep) — [WingetServiceCollectionExtension.cs](https://github.com/svrooij/WinTuner/blob/main/src/WingetIntune/WingetServiceCollectionExtension.cs); adoption — [PSGallery WinTuner](https://www.powershellgallery.com/packages/WinTuner)
- IntuneAppBuilder integration tests "publishes real apps to a Microsoft Intune tenant" — [README](https://github.com/simeoncloud/IntuneAppBuilder)
- Native ProfileVersion1 encryption accepted for macOS app types — [IntuneUploaderBase.py](https://github.com/almenscorner/intune-uploader/blob/main/IntuneUploader/IntuneUploaderLib/IntuneUploaderBase.py)
- Microsoft "must" + old-version warning — re-check of `/Users/new-jose/repos/aitools/plans/build-package/mdm-windows-tool-findings.md` 3.4 and 4.3 (not re-read on Learn by this researcher)

### Inferences
- "Accepted in practice" covers the Graph upload path (the encrypted payload + keys). For portal upload of a community-built container, WinTuner's default `CreatePackage` output and IntuneAppBuilder's `.portal.intunewin` are the evidence; neither is Microsoft-supported.
- Corrections to the earlier findings file: (a) IntuneWin32App downloads from `raw/master` with no hash check, the same moving URL Microsoft's member endorsed; (b) IntuneAppBuilder's tenant tests run only on Windows; (c) the AutoPkg project is `intune-uploader` (83 stars, Apache-2.0), and it is macOS-only.

### Gaps
- No Microsoft statement found that accepts or rejects third-party-packed Win32 content. No tenant acceptance test by this mission.

CONFLICT: none recorded.
INCIDENT: (low, harness) The prompt names `almenscorner/IntuneUploader`, which does not exist; the repo is `almenscorner/intune-uploader`. Delegation prompts should carry `gh api`-verified repo slugs.
INCIDENT: (low, harness) The shared chrome-devtools browser switches the selected page when other researchers open pages (page 28/29 became selected mid-session). Pass `pageId` explicitly on every call. The skill does not say so.
