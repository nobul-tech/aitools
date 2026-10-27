# Official Microsoft tooling for Intune Win32 (.intunewin) packaging and upload (as of 2026-10-26)

Researcher: S3-MdmWinToolDR-Official (mission MDM-WINTOOL-DR). All pages read 2026-10-26. Licence, Learn quotes and Graph quotes were read with chrome-devtools (own tab) from the rendered page or, for the licence PDF, from the PDF text layer via the viewer's own pdf.js (all 3 pages read in full). Repo facts via `gh api`. No binary was downloaded or run. No Firecrawl tool used.

## 1. Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe): version, runtime, platforms, licence, cross-platform requests

### Takeaway
v1.8.7 (released 2025-08-13) is current; the only stated prerequisite is ".NET Framework 4.7.2" and Microsoft publishes no macOS/Linux/.NET (Core) build. The licence allows unlimited copies but forbids working around technical limitations (4a), reverse engineering (4b) and sharing/publishing or hosting it for others (4e). The Linux request (#26, 2020) is open with no substantive Microsoft reply; a Microsoft engineer closed the Cloud Shell request (#86) by pointing to #26.

### Cited Findings
- Repo `microsoft/Microsoft-Win32-Content-Prep-Tool`: 1,556 stars, 298 forks, 38 open issues, not archived, last push 2026-08-24T18:57:35Z; GitHub API reports no detected licence (`license: null`; the terms are a PDF) — `gh api repos/microsoft/Microsoft-Win32-Content-Prep-Tool` (2026-10-26)
- Releases (all with 0 uploaded assets): v1.8.7 2025-08-13T21:30:41Z ("Changed SHA256 to use FIPS-compliant algorithm. Refactored logging to prevent crashes. Added silent mode support. Used compliant crypto algorithms."); v1.8.6 2024-02-28; v1.8.5 2023-11-06; v1.8.4 2022-05-10 ("Fixed an issue with version 1.8.3 where the Win32PrepTool will not work with files greater than 4gb.") — `gh api .../releases`
- README (rendered, read in full): "Version 1.8.7"; "Use the Microsoft Win32 Content Prep Tool to pre-process Windows Classic apps. The packaging tool converts application installation files into the .intunewin format."; "Prerequisites / .NET Framework 4.7.2"; "By downloading and using Microsoft Win32 Content Prep Tool, you agree to such license terms. If you do not accept them, do not use the software."; flags `-h -v -c -s -o -a -q -qq` ("-qq ... there will be no console output"); "Note: The generated .intunewin file contains all compressed and encrypted source setup files and the encryption information to decrypt it. Please keep it in the safe place as your source setup files." — [README](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
- README names no OS, no CPU architecture, no macOS/Linux. x64 / PE32+ is a claim from the earlier mission's binary parse, NOT re-verified here (no binary download allowed) — [earlier findings](/Users/new-jose/repos/aitools/plans/build-package/mdm-windows-tool-findings.md) section 2.2
- Licence PDF (pinned commit `1d6cfcbdf8c28edc596337031f74df951f38f718`, 3 pages, read in full), verbatim:
  - Preamble: "BY USING THE SOFTWARE, YOU ACCEPT THESE TERMS."
  - "1. INSTALLATION AND USE RIGHTS. You may install and use any number of copies of the software."
  - "2. THIRD PARTY COMPONENTS. The software may include third party components with separate legal notices or governed by other agreements, as may be described in the ThirdPartyNotices file(s) accompanying the software."
  - "3. DATA COLLECTION. The software may collect information about you and your use of the software and send that to Microsoft. ... Your opt-out rights, if any, are described in the product documentation."
  - "4. SCOPE OF LICENSE. The software is licensed, not sold. Microsoft reserves all other rights. Unless applicable law gives you more rights despite this limitation, you will not (and have no right to): a) work around any technical limitations in the software; b) reverse engineer, decompile or disassemble the software, or attempt to do so, except and only to the extent required by third party licensing terms governing use of certain open-source components that may be included with the software; c) remove, minimize, block, or modify any notices of Microsoft or its suppliers in the software; d) use the software in any way that is against the law; or e) share, publish, rent, or lend the software, or provide the software as a stand-alone hosted offering for others to use."
  - "6. SUPPORT SERVICES. Microsoft is not obligated under this agreement to provide any support services for the software."
  - "10. DISCLAIMER OF WARRANTY. THE SOFTWARE IS LICENSED "AS IS." ..."; "11. ... ONLY DIRECT DAMAGES UP TO U.S. $5.00."
  - No clause addresses platforms, emulation (Wine), CI use or re-implementation of the file format. — [Licence PDF](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/blob/master/Microsoft%20License%20Terms%20For%20Win32%20Content%20Prep%20Tool.pdf)
- Issue #26 "Linux executable?": opened 2020-02-04, state open, label `enhancement`, 10 comments, all with author_association NONE (no Microsoft reply in the thread). Content: Wine+Mono works on Debian (2020-04-02); same commenter cancelled a hosted packager web app "as it is not allowed by the license terms (clause 4e)"; simeoncloud announced IntuneAppBuilder (2020-04-30); Wine + `winetricks dotnet48` reported on Fedora/Arch (2024-02-16); Ubuntu 22.04 attempt failed for one user; LetsGoIntunePackager mentioned (2026-09-07) — `gh api .../issues/26` and `/issues/26/comments`; [issue #26](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/26)
- Issue #86 "Is this tool compatible with Azure CloudShell (PowerShell)?" (2023-01-19) closed 2025-01-24 by `ameltzer-MSFT` with the single comment "#26" (author_association shown as NONE, i.e. not a public org member; the -MSFT handle suggests Microsoft staff) — `gh api .../issues/86`
- An issue search for mac/macos/linux/core/cross-platform in the repo found only #26 as a platform request (others: #12 "Can I get 64bit version?" closed 2019; #35 "1.7 fails to run on windows core" closed) — `gh api search/issues` (2026-10-26)

### Inferences
- "Windows only" is an inference from the .NET Framework prerequisite, the absence of any other build and #26; Microsoft never states it in the README.
- Clause 4(e) is what the #26 commenter read as barring a hosted packaging service; clause 4(a) is the one most relevant to Wine/patching. Neither forbids writing an independent packer, because the licence only governs "the software".

### Gaps
- CPU architecture (x64 vs AnyCPU/arm64) not verifiable without downloading the binary; Microsoft documents none.
- Whether 1.8.7 actually sends telemetry (clause 3): unknown; no product documentation of opt-out found.
- No Microsoft roadmap reply on #26 in six and a half years.

## 2. Microsoft Learn: is the tool required, size limits, supported source types

### Takeaway
Learn uses "must": "Before you can add a Win32 app to Microsoft Intune, you must prepare the app by using the Microsoft Win32 Content Prep Tool." The admin center Win32 flow accepts only a `.intunewin`. Apps are capped at 30 GB. Any installer that installs silently is allowed (exe, msi, script).

### Cited Findings
- "Before you can add a Win32 app to Microsoft Intune, you must prepare the app by using the Microsoft Win32 Content Prep Tool." — [Prepare Win32 app content](https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package) (last updated 04/14/2026); same sentence also in [Win32 app management](https://learn.microsoft.com/en-us/intune/app-management/deployment/win32) (last updated 04/14/2026). Note: the old URL `.../deployment/apps-win32-app-management` now returns 404.
- "Windows application size is capped at 30 GB per app." — create-win32-package and [add-win32](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32) (04/14/2026); win32 page: "Windows application size must not be greater than 30 GB per app."
- "Apps must support silent installation: Win32 apps deployed through Intune must be able to install without user interaction." — create-win32-package
- "You can download the Microsoft Win32 Content Prep Tool from GitHub as a .zip file." and "The Microsoft Win32 Content Prep Tool zips all files and subfolders when it creates the .intunewin file." — create-win32-package
- Source types: "-s <setup_file> Setup file (such as setup.exe or setup.msi)."; "For the MSI setup file, this tool retrieves required information for Intune." — create-win32-package. Learn gives no list of allowed extensions; any file in the setup folder is packed.
- "select a Windows installation file with the extension .intunewin." and "Be sure to use the latest version of the Microsoft Win32 Content Prep Tool. If you don't use the latest version, you'll see a warning that says the app was packaged using an older version of the tool." — [add-win32](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32)
- PowerShell script installer (inside the Win32 app type): "For PowerShell script installations, select PowerShell script to upload your install script (maximum size 50 KB). ... Intune packages the script with the app content and runs it in the same context as the app installer." — add-win32; win32 page: "Scripts are limited to 50 KB in size".
- Win32 support for "32-bit Windows, 64-bit Windows, and ARM64 operating system architecture" (target devices, not build hosts) — [win32](https://learn.microsoft.com/en-us/intune/app-management/deployment/win32)

### Inferences
- The "must" is a documented requirement for the admin-center path; Microsoft does not say that a Graph upload of a third-party-built package is unsupported, nor that it is supported. The script installer still needs a `.intunewin` content file (it replaces only the install command).

### Gaps
- No Learn page names the build-host OS for the tool.

## 3. Microsoft Graph upload flow for win32LobApp; encryption and Detection.xml documentation; official samples; non-Windows clients

### Takeaway
Graph documents the flow (mobileApp -> contentVersions -> files -> Azure Storage SAS -> commit with fileEncryptionInfo) and the fileEncryptionInfo field constraints (16-byte IV, 32-byte mac and macKey, ProfileVersion1, SHA256), but the reference pages do not name AES-256-CBC or HMAC-SHA256; those appear only in Microsoft's MIT sample code. Detection.xml / the `.intunewin` container are not documented by Microsoft anywhere I found; the official Win32 sample requires a pre-built `.intunewin` and reads Detection.xml. The commit page's link to the encryption sample (aka.ms/fileencryptioninfo) is broken.

### Cited Findings
- fileEncryptionInfo properties (verbatim): "encryptionKey Binary The key used to encrypt the file content."; "initializationVector ... Must be 16 bytes."; "mac ... The hash of the concatenation of the IV and encrypted file content. Must be 32 bytes."; "macKey ... The key used to compute the message authentication code of the concatenation of the IV and encrypted file content. Must be 32 bytes."; "profileIdentifier ... Currently, only ProfileVersion1 is supported."; "fileDigest ... The file digest prior to encryption. ProfileVersion1 requires a non-null FileDigest."; "fileDigestAlgorithm ... ProfileVersion1 currently only supports SHA256 for the FileDigestAlgorithm." No cipher, mode, padding or MAC algorithm is named; encryptionKey has no stated length. — [fileEncryptionInfo](https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-fileencryptioninfo?view=graph-rest-1.0) (last updated 09/13/2024)
- mobileAppContentFile: methods include create, "commit action ... Commits a file of a given app." and "renewUpload action ... Renews the SAS URI for an application file upload."; properties `azureStorageUri` ("Created by the service upon receiving a valid mobileAppContentFile"), `isCommitted`, `size`, `sizeEncrypted`, `manifest` ("Indicates the manifest information, containing file metadata."), `uploadState` (azureStorageUriRequestSuccess ... commitFileSuccess, commitFileFailed ...), `isDependency` — [mobileAppContentFile](https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-mobileappcontentfile?view=graph-rest-1.0) (10/10/2025)
- Commit: `POST /deviceAppManagement/mobileApps/{mobileAppId}/contentVersions/{mobileAppContentId}/files/{mobileAppContentFileId}/commit`; permissions DeviceManagementApps.ReadWrite.All (delegated or application); body `fileEncryptionInfo`, "A PowerShell script example of the file upload process using the ProfileVersion1 encryption scheme can be found at https://aka.ms/fileencryptioninfo."; returns 204 — [commit action](https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-commit?view=graph-rest-1.0) (10/10/2025)
- `https://aka.ms/fileencryptioninfo` returns `302` to `https://www.bing.com?ref=aka&shorturl=fileencryptioninfo` (dead short link) — `curl -sI` (2026-10-26)
- `microsoftgraph/powershell-intune-samples` returns 404 on the GitHub API (repo gone); successor `microsoft/mggraph-intune-samples`: MIT, 285 stars, not archived, pushed 2026-09-25 — `gh api`
- Official LOB readme flow: "1. Identify the key metadata ... 2. ... POST to new LOB App 3. Create a content version ... Create a new file entry ... Wait for File entry SAS URI ... 4. Encrypt the file for upload ... 5. Upload to Azure Storage 6. Commit the file" — [LOB_Application/readme.md](https://github.com/microsoft/mggraph-intune-samples/blob/main/LOB_Application/readme.md)
- `Win32_Application_Add.ps1`: "The script extracts the detection.xml file from the .intunewin file and uses the information to create the app in Intune. The script then uploads the .intunewin file to Azure Storage and commits the file to the service."; `.PARAMETER SourceFile The path to the .intunewin file.`; it reads `$DetectionXML.ApplicationInfo.EncryptionInfo.EncryptionKey / macKey / initializationVector / mac / fileDigest / fileDigestAlgorithm`, hard-codes `profileIdentifier = "ProfileVersion1"`, reads `ApplicationInfo.UnencryptedContentSize`, opens the package with `[IO.Compression.ZipFile]::OpenRead`, uploads in chunks with `x-ms-blob-type = BlockBlob`; requires modules Microsoft.Graph.Devices.CorporateManagement and Microsoft.Graph.Authentication. It does NOT encrypt; it relies on the pre-built `.intunewin` — [Win32_Application_Add.ps1](https://github.com/microsoft/mggraph-intune-samples/blob/main/LOB_Application/Win32_Application_Add.ps1)
- The readme's only Win32 prerequisite listed is about the target ("Windows 10 version 1607 or later"); MSI detection can use "the MSI codes stored in the detection.xml file inside the package" — readme
- Microsoft's own statement of the difference: "Unlike a Win32 `.intunewin` file, an `.msix`/`.appx` package is **not** pre-encrypted and does **not** contain a `detection.xml`. ... the script encrypts the package itself" and "Encrypts a copy of the package (AES + HMAC-SHA256)" — readme, MSIX section (sample added 2026-06-16, commit 0614686)
- `MSIX_Application_Add.ps1` crypto: `[System.Security.Cryptography.Aes]::Create()` (key via `AesCryptoServiceProvider.GenerateKey()`), `HMACSHA256` with a separate generated key, output layout written as HMAC (32) + IV (16) + ciphertext via `CryptoStream`, HMAC computed over the bytes after the HMAC slot (IV + ciphertext), `Get-FileHash -Algorithm SHA256` of the plaintext as fileDigest, `profileIdentifier = "ProfileVersion1"`, `fileDigestAlgorithm = "SHA256"` — `gh api .../LOB_Application/MSIX_Application_Add.ps1` lines 549-662. The sample does not set Mode/Padding, so .NET defaults apply (CBC/PKCS7 per .NET docs, as recorded by the earlier mission; not re-read here).
- Graph PowerShell SDK: "PowerShell 7 and later is the recommended PowerShell version for use with the Microsoft Graph PowerShell SDK on all platforms." — [Install the Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0) (03/26/2025)

### Inferences
- Graph is a REST API and the SDK is documented as cross-platform, so uploading an existing `.intunewin` (or a self-encrypted content file) from macOS/Linux is within documented Microsoft surface. No Microsoft page restricts Graph Win32 uploads to Windows clients; none explicitly blesses it either.
- A Graph-only route could, in principle, skip the `.intunewin` container (encrypt the inner zip, commit fileEncryptionInfo directly), as the MSIX sample does for MSIX. For `win32LobApp` Microsoft gives no sample of that; whether the service accepts a Win32 content file not produced by the tool is untested and undocumented.

### Gaps
- No Microsoft documentation of Detection.xml schema, the outer zip layout, or the inner zip; only sample code that reads element names.
- Whether `mobileAppContentFile.manifest` must be populated for win32LobApp (MSIX requires base64 file name) is not documented in what I read.
- I did not read the win32LobApp resource page itself (field list) this session.

## 4. Newer Microsoft alternatives that avoid `.intunewin`

### Takeaway
None fits a custom bash/PowerShell-based installer payload for a fleet without packaging: the Enterprise App Catalog and Microsoft Store (new) only deploy catalogue/Store apps; Windows LOB upload takes MSI/MSIX/APPX directly (no `.intunewin`, but requires building an MSI or MSIX); platform PowerShell scripts take a single script under 200 KB with no payload.

### Cited Findings
- Enterprise App Catalog: "a collection of prepackaged Win32 apps that are designed and prepared by Microsoft to support Intune. The catalog contains both Microsoft apps and non-Microsoft apps."; "The Enterprise App Catalog is a feature of Enterprise App Management (EAM), which is part of Microsoft Intune Suite and available for trial and purchase." — [Add an Enterprise App Catalog app](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-enterprise-catalog-app) (06/03/2026)
- Microsoft Store app (new): "The Microsoft Store supports Universal Windows Platform (UWP) apps, desktop apps packaged in .msix, and now Win32 apps packaged in .exe or .msi installers."; "Win32 store apps are supported (in preview)"; apps are found by "Search the Microsoft Store app"; client "need to be able to support the Intune Management Extension (IME)". No private or custom WinGet source is mentioned. — [Add Microsoft Store apps](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-microsoft-store)
- Windows LOB: "select a Windows installation file with the extension .msi, .appx, or .appxbundle." and "The file extensions for Windows apps include .msi, .appx, .appxbundle, .msix, and .msixbundle."; "Only one command-line argument can be specified. If the .MSI file needs more than one command-line argument, consider using Win32 app management." — [Add a Windows LOB app](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-lob-windows) (04/14/2026)
- Microsoft MIT sample uploads MSIX via Graph with client-side encryption (no `.intunewin`, no Content Prep Tool) — [mggraph-intune-samples readme](https://github.com/microsoft/mggraph-intune-samples/blob/main/LOB_Application/readme.md)
- Platform PowerShell scripts: "The script must be less than 200 KB (ASCII)."; "Once the script executes, it doesn't execute again unless there's a change in the script or policy."; "PowerShell scripts time out after 30 minutes."; "PowerShell scripts are executed before Win32 apps run." — [Add PowerShell scripts to Windows devices](https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows) (04/14/2026)
- Autopilot caveat: mixing Win32 and LOB apps during Autopilot enrollment "might fail as they both may attempt to use the Trusted Installer service at the same time" — [win32](https://learn.microsoft.com/en-us/intune/app-management/deployment/win32)

### Inferences
- For a bash/PowerShell installer plus a file tree, the official options are: (a) Win32 `.intunewin` (Windows-built), (b) wrap the payload as MSIX or MSI and use LOB upload (MSI can be built on non-Windows with third-party tools such as WiX-alternatives; MSIX tooling is evaluated by others, out of scope), or (c) a platform script under 200 KB that downloads the payload itself (bootstrapper pattern; loses app-level detection/reporting).
- Enterprise App Catalog and Store do not accept customer-authored apps, so they are not alternatives for aitools.

### Gaps
- Whether a custom/private WinGet REST source can be targeted by the Store app type: not documented on the page read; I found no Microsoft statement.
- MSIX packaging on macOS/Linux (Microsoft's MSIX tooling platform support) not researched here.

## 5. Official Microsoft statement or roadmap on cross-platform packaging

### Takeaway
None found. Intune What's New (last updated 10/12/2026, weeks back to March 24, 2026) contains zero mentions of "Content Prep", "intunewin" or "IntuneWinAppUtil", and #26 has no Microsoft reply.

### Cited Findings
- What's New page text: 0 hits for "Content Prep", 0 for "intunewin", 0 for "IntuneWinAppUtil"; Win32 items in 2026 are delivery-side only (push notifications for Win32 app changes; faster Win32 delivery after ESP; "Managed Win32 app content now requires HTTPS delivery" week of June 15, 2026; IME minimum 1.58.103.0; deployment plans for "Win32 and Enterprise app catalog apps") — [What's new in Microsoft Intune](https://learn.microsoft.com/en-us/intune/whats-new/) (last updated 10/12/2026; old URL `/intune/fundamentals/whats-new` 404s)
- #26 open, no Microsoft comment; #86 closed by ameltzer-MSFT with "#26" — section 1
- Web search (extended) for a 2026 Tech Community announcement of a macOS/Linux/cross-platform Content Prep Tool returned only third-party pages — WebSearch 2026-10-26

### Inferences
- Microsoft's de facto position: Windows tool only, cross-platform request parked as "enhancement".

### Gaps
- The What's New archive (pre-March 2026) and the Intune Tech Community blog were not read in full; a search cannot prove absence.

## Re-check of earlier findings (mdm-windows-tool-findings.md)
- v1.8.7 latest, 2025-08-13: CONFIRMED. .NET Framework 4.7.2: CONFIRMED (README). x64: NOT re-verified (no binary). Learn "must": CONFIRMED verbatim. #26 open since 2020-02-04: CONFIRMED. Licence 4(a)/4(e) text: CONFIRMED verbatim; also 4(b) reverse-engineering and 3 data collection.
- New vs earlier notes: the commit page's aka.ms/fileencryptioninfo link is dead; Microsoft's own readme (MSIX section, 2026-06) states `.intunewin` is "pre-encrypted" and contains `detection.xml`, and names "AES + HMAC-SHA256" in prose; Win32 PowerShell script installer (50 KB) exists but still rides in a `.intunewin`; the Learn win32 overview URL moved to `/deployment/win32`.

INCIDENT: (low, upstream) Graph commit-action page links its ProfileVersion1 sample to https://aka.ms/fileencryptioninfo, which redirects to Bing (dead link).
