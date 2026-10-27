# S3-MdmWinTool-Research notes: building `.intunewin` on macOS, Linux and Windows (version 1.0)

Delegate: S3-MdmWinTool-Research (level 2 under S3-MdmWinTool). All sources read on
2026-10-26 with chrome-devtools (own isolated tab, `evaluate_script` returning
`innerText`), unless marked otherwise. WebSearch was used only to find sources. No
WebFetch, no Firecrawl, no downloads. Quotes are verbatim. "Inference" marks
anything no source states.

## Summary (5 lines)

1. **No official Microsoft cross-platform packer exists.** The Content Prep Tool's "Linux executable?" issue (#26) has been open since 2020 and is labelled "enhancement". Microsoft closed the Cloud Shell request (#86) by pointing to it. I found no Microsoft GitHub Action, DevOps task or Graph SDK packaging command.
2. **The format is partly documented by Microsoft.** The crypto and upload side is official: the Graph `fileEncryptionInfo` and `mobileAppContentFile` reference pages, plus Microsoft's MIT sample code (`microsoft/mggraph-intune-samples`), which encrypts a file as `[HMAC-SHA256 32][IV 16][AES ciphertext]`. The `.intunewin` container (zip layout, `Detection.xml` schema) is documented only by the community.
3. **Seven community packers exist.** The strongest is `simeoncloud/IntuneAppBuilder`: owned by a company org, Apache-2.0, a .NET 8 tool, 231.4K NuGet downloads, and integration tests that publish to a real Intune tenant. svrooij/ContentPrep checks out as the prior notes said (GPL-3.0, 32 stars, sole maintainer, v0.4.2 of 2025-10-03, author disclaimer). The other five have 3 to 31 stars and personal owners.
4. **Wine works, by community report.** Reports cover Debian, Fedora and Arch with `winetricks dotnet48`; one user failed on Ubuntu 22.04 and WSL. I found no macOS report. One user says licence "clause 4e" forbids a hosted packaging service (not verified: I did not read the PDF).
5. **Recommendation (ranked principles):** keep the official tool on a `windows-2022`/`windows-2025` runner (principles 1 and 2). If a non-Windows host becomes a requirement, run IntuneAppBuilder through `/tool-eval`. Or skip the container: Microsoft documents the crypto and Graph upload, so a native build is possible when upload goes through Graph. Design 3(c) stands, but its stated reason ("a `.intunewin` needs Microsoft's tool") is wrong as a fact.

## Candidate comparison

Read date 2026-10-26 for every number. Stars and contributors come from GitHub repo pages; downloads from NuGet and PSGallery.

| Candidate | Type | Publisher | Licence | Latest release / last commit | Adoption | Platforms | Hard blocks | Yellow flags | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| IntuneWinAppUtil (Microsoft) | Official exe (.NET Framework 4.7.2) | `microsoft` org | Proprietary (PDF) | v1.8.7 2025-08-13 (per PkgWin notes; the Eval delegate owns this) | 1.6k stars (PkgWin) | Windows; Linux via Wine (community) | none known | see Eval | Reference baseline; preferred |
| simeoncloud/IntuneAppBuilder | .NET 8 global tool + SDK (`IntuneAppBuilder.Console`) | `simeoncloud` org (Simeon, a company) | Apache-2.0 | NuGet 4.1.0 "5 months ago" (about May 2026); last commit 2026-05-18; no GitHub releases or tags | 72 stars, 5 forks, 14 contributors; NuGet total 231.4K, 140/day | Windows, macOS, Linux (.NET 8); MSI metadata on Windows only | none found | <500 stars; no tagged releases (provenance is the NuGet package only); needs .NET 8 SDK; not official | Best non-official candidate. Needs `/tool-eval` before use |
| svrooij/ContentPrep (`SvRooij.ContentPrep` lib, `SvRooij.ContentPrep.Cmdlet` module) | C# library + binary PowerShell module | `svrooij` personal account | GPL-3.0 | GitHub v0.4.2 2025-10-03; NuGet 0.4.2 "Last updated 10/3/2025"; PSGallery 0.4.0 7/16/2025 | 32 stars, 2 forks, 1 contributor; NuGet 13.3K; PSGallery 44,510; used inside WinTuner (260 stars) | netstandard2.0 + net8.0 lib; module "Minimum PowerShell version 5.1"; Linux use reported by a user | none (sole author, not a fork) | sole maintainer; <500 stars; no release in 12+ months (12.8 months); copyleft; author: "not a replacement for the Microsoft tool" | Not recommended |
| kenchan0130/intunewin | Go CLI + Go API | `kenchan0130` personal | Apache-2.0 | v0.0.7 2026-09-23 (first release 2025-12-09); last commit 2026-10-14 | 7 stars, 0 forks; 1 human contributor (+ renovate, github-actions, Claude) | Windows, macOS, Linux binaries | none | <500 stars; sole maintainer; pre-1.0; `pack` takes no setup-file argument, so how `Detection.xml` `SetupFile` is filled is unknown | Not recommended |
| lwalthert/intunewin | Go CLI | `lwalthert` personal | MIT | no releases; last commit 2026-09-01 | 3 stars, 1 contributor | Windows, Linux, macOS (native MSI reader) | none | <500 stars; sole maintainer; no releases; author says most tests are AI-generated | Not recommended |
| LetsGoIntunePackager (michelbragaguimaraes; fork omichelbraga) | Go CLI + TUI | personal | MIT | 1 tag; last commit 2026-09-21 | 5 stars, 2 forks | Windows, macOS, Linux (amd64/arm64) | none | <500 stars; personal; claims "Generates packages identical to Microsoft's official tool", which random keys make impossible byte-for-byte (inference) | Not recommended |
| thefinder808/WrapTune-MacOS | macOS GUI + `wraptune` CLI (.NET, Avalonia) | `thefinder808` personal | MIT | v2.0.1 latest (6 releases); last commit 2026-08-04 | 31 stars; contributors: thefinder808, Claude, dependabot | macOS only (signed, notarized DMG) | none | <500 stars; sole maintainer; no Linux host | Not recommended for CI |
| maxihafer/content-prep | Go CLI + Docker image | `maxihafer` personal | none shown on the repo page | v1.0.1 (7 releases); last commit 2025-03-03 | 3 stars, 1 contributor | any Go target; `ghcr.io` image | none | no licence seen; sole maintainer; <500 stars; README contradicts Microsoft on cipher mode and digest (see below) | Do not use, and do not cite it as a format source |
| MSEndpointMgr/IntuneWin32App | PowerShell module (packaging + Graph upload) | `MSEndpointMgr` community org | MIT | 1.5.0 (last commit 2026-01-25); no tags | 516 stars, 119 forks, 8 contributors | packaging Windows-only: it downloads and runs `IntuneWinAppUtil.exe` | none | issue #164: also calls AzCopy.exe and msiexec.exe | Not a cross-platform packer. Its upload side may help (out of scope) |
| Native implementation (aitools code) | openssl + perl/pwsh + zip | aitools | n/a | n/a | n/a | macOS (LibreSSL 3.3.6 verified), Linux (openssl presence on target images unknown), Windows (.NET) | n/a | maintenance burden; container layout is reverse-documented | Feasible. Lowest risk if upload is through Graph |

Not opened (search result only, so unverified): alcavix/IntuneWin-Creator, described by WebSearch as an MIT Windows-only WPF GUI. Not a cross-platform option either way.

## 1. simeoncloud/IntuneAppBuilder

Source: https://github.com/simeoncloud/IntuneAppBuilder (read 2026-10-26); https://www.nuget.org/packages/IntuneAppBuilder.Console (read 2026-10-26).

- "Package MSI and Win32 application packages as .intunewin format to Microsoft Intune with this cross-platform tool."
- "Get .NET 8 SDK (or higher)" / "dotnet tool install -g IntuneAppBuilder.Console"
- Pack output: "MyAppInstallFiles.intunewin.json - this file contains metadata about the packaged app / MyAppInstallFiles.intunewin - this file can be used directly to publish the app using the IntuneAppBuilder publish command / MyAppInstallFiles.portal.intunewin - this file can be uploaded to the Intune Portal as a Win32 app"
- "The Windows Installer COM service is used to retrieve information about MSIs if one is included in your application. When the tool is running on a non-Windows system, the tool will log a warning and continue creating the package without the additional MSI metadata." Our payload's setup file is a script, not an MSI (design section 5, inference), so this gap does not matter here.
- Acceptance evidence: "The IntegrationTests project publishes real apps to a Microsoft Intune tenant. It authenticates via the Microsoft Graph client credentials (app-only) flow." / "In CI the same values are sourced from the TEST_AADAUTH_TENANT_ID, TEST_AADAUTH_CLIENT_ID, and TEST_AADAUTH_CLIENT_SECRET GitHub repository secrets." This is the only candidate with tenant tests in its own CI. I did not read the CI runs, so whether they pass now is unknown.
- History: in microsoft/Microsoft-Win32-Content-Prep-Tool#26 (2020-04-30), admin-simeon wrote: "We've decided to open source the Intune application packaging and publishing component of our Microsoft 365 Management Suite which has the same functionality as this tool ... It is written in dotnet core (3.1) and is cross platform." Its README says the kenchan0130 packer is "inspired by simeoncloud/IntuneAppBuilder".
- NuGet: "IntuneAppBuilder.Console 4.1.0 / .NET 8.0", "Total 231.4K / Current version 2.0K / Per day average 140", "Last updated 5 months ago", Owners: "simeon". Version rows: "4.1.0 2,024 5 months ago", "4.0.0 8,117 12/19/2024".
- GitHub: 72 stars, 5 watching, 5 forks, 14 contributors, "No releases published", 0 tags, last commit 2026-05-18 ("Merge pull request #56"), 3 open issues.
- Not read: the source code (so its cipher mode and `Detection.xml` fields are unverified); the GitHub security tab; the CI run history.
- Health (proposed, inference): Windows yellow, macOS yellow, Linux yellow (not official, <500 stars, no tagged release).

## 2. svrooij/ContentPrep (re-checked against the PkgWin notes)

Sources: https://github.com/svrooij/ContentPrep and /releases; https://www.nuget.org/packages/SvRooij.ContentPrep/; https://www.powershellgallery.com/packages/SvRooij.ContentPrep.Cmdlet/0.4.0; https://wintuner.app/docs/related/content-prep-tool (all read 2026-10-26).

The prior notes are confirmed: GPL-3.0, 32 stars, 1 contributor, v0.4.2. The last commit on the release list is 2025-10-03 (v0.4.2 released "2025-10-03T13:48:24Z"). The author's warning is verbatim the same.

New facts:
- Motivation: "I wanted to be able to use in WingetIntune without having to rely on a closed-source tool that had a dependency upon Windows. I want to run this in the cloud and using closed source executable was not really an option."
- WinTuner page: "eventually figured out how to create those .intunewin files with just C# code (platform independed)." / "As of version 0.8.4 WinTuner includes these commands" / "If you're having issues the Microsoft support probably won't help you, if you dind't use their official tool."
- Packages: NuGet `SvRooij.ContentPrep` 0.4.2 targets ".NET 8.0" and ".NET Standard 2.0", "Total 13.3K". PSGallery `SvRooij.ContentPrep.Cmdlet` 0.4.0, "44,510 downloads", "Minimum PowerShell version 5.1", cmdlets `New-IntuneWinPackage` and `Unlock-IntuneWinPackage`, "licensed under GNU GPLv3". The gallery entry declares no OS compatibility tags (I saw none in Package Details).
- There is no dotnet CLI tool for packaging. `SvRooij.Winget-Intune.Cli` (WebSearch result, not opened) downloads Microsoft's tool, is Windows only, and is deprecated in favour of WinTuner.
- Linux use, by user report: MSEndpointMgr/IntuneWin32App#164 (2024-06-09) says to use `New-IntuneWinPackage` "because it creates a .intunewin file in a cross-platform way both on Windows and Linux".
- Tests: `tests/SvR.ContentPrep.Tests` contains `FrameworkCompatibility.cs`, `Packager.Tests.Arguments.cs`, `Packager.Tests.cs`, `TestHelper.cs`. I saw no test against the official tool or a tenant in the file names. I did not read the file contents.
- GitHub releases v0.4.0 (2025-07-16), v0.3.0 (2025-06-01) and v0.2.0 (2024-10-02) have only "Source code" assets. Distribution is NuGet and PSGallery.
- Health (proposed): all platforms yellow, with four yellow flags (sole maintainer, low adoption, no release in 12+ months, author disclaimer). Copyleft matters only if aitools redistributes or links it (inference).

## 3. kenchan0130/intunewin

Source: https://github.com/kenchan0130/intunewin and /releases (read 2026-10-26).
- "A cross-platform CLI tool for creating and extracting Microsoft Intune .intunewin files." / "Cross-platform: Works on Windows, macOS, and Linux"
- Usage: "intunewin pack <source-folder> <output-file.intunewin>". There is no setup-file argument, so how it fills `Detection.xml` `SetupFile` is unknown (not read).
- "Metadata/Detection.xml: Contains encryption keys, file sizes, and hash information / Contents/IntunePackage.intunewin: The encrypted and compressed source folder"
- "This implementation is inspired by simeoncloud/IntuneAppBuilder."
- Releases: v0.0.7 (2026-09-23), v0.0.6 (2026-07-22), v0.0.5 and v0.0.4 (2026-02-22), v0.0.3 (2025-12-09). Each has 9 assets, built by goreleaser, and is marked "Immutable". 7 stars.

## 4. lwalthert/intunewin

Source: https://github.com/lwalthert/intunewin (read 2026-10-26).
- "This project tries to implement the functionality of the Microsoft Win32 Content Prep Tool in golang. It was made out of frustration with Microsoft's unwillingness to fix bugs in the official tool and regularly breaking it for months after new releases. It is fully cross-platform."
- "It is encrypted using AES256 in CBC mode with a random IV. It is also hashed using HMAC-SHA256. The AES encryption key, IV, HMAC hash, and HMAC key for the encrypted file are found in the "Detection.xml" file."
- "everything with AI and the majority of tests was generated by AI."
- CLI mirrors the official flags: "intunewin -c <setup_folder> -s <setup_file> -o <output_folder>". No releases, 3 stars, MIT, last commit 2026-09-01.

## 5. LetsGoIntunePackager

Source: https://github.com/michelbragaguimaraes/LetsGoIntunePackager (read 2026-10-26).
- "Unlike Microsoft's tool which only runs on Windows, LetsGoIntunePackager works on Linux, macOS, and Windows — making it perfect for CI/CD pipelines"
- Its README ships a `runs-on: ubuntu-latest` GitHub Actions example that curls the binary from "releases/latest".
- "Encryption: AES-256-CBC with PKCS7 padding / Authentication: HMAC-SHA256 over IV || Ciphertext / Output Format: [HMAC-32][IV-16][Ciphertext]" and "File Digest: SHA256 hash of compressed data"
- "100% Compatible: Generates packages identical to Microsoft's official tool". Every run uses random keys and the zip holds timestamps, so this cannot be byte-identical (inference). Read it as "format-compatible".
- It was mentioned in #26 (2026-09-07): "Might be useful for some CI or automations, I guess if you trust it. It has Claude as a contributor".

## 6. WrapTune-MacOS

Source: https://github.com/thefinder808/WrapTune-MacOS (read 2026-10-26).
- "Build Microsoft Intune .intunewin Win32 app packages natively on a Mac — no Windows VM, no Wine, no official tooling required."
- "AES-256-CBC payload encryption + HMAC-SHA256 integrity, with a distinct MAC key, using only the .NET base-class-library cryptography"
- "The result has been deployed to a real Intune tenant and installed on Windows endpoints (Zoom, Chrome Enterprise, PowerShell 7), with the official tool nowhere in the chain." This is the author's claim, not verified.
- It has a `wraptune` CLI ("pack, inspect, and extract for CI"), and `tools/verify-intunewin.py` ("Independent package verifier"). Distribution is a signed, notarized macOS DMG only. A Linux CLI build is not mentioned (unknown).
- It calls its implementation one "of the documented .intunewin format". It does not say who documented it. Microsoft documents only the crypto (section 10).

## 7. maxihafer/content-prep

Source: https://github.com/maxihafer/content-prep (read 2026-10-26).
- It gives the fullest community `Detection.xml` example: `<ApplicationInfo ToolVersion="1.8.4.0">`, `FileName` "IntunePackage.intunewin", `Name`, `UnencryptedContentSize`, `SetupFile`, and `EncryptionInfo` with `EncryptionKey` "(32 byte)", `MacKey` "(32 byte)", `InitializationVector` "(16 byte)", `Mac`, `ProfileIdentifier` "ProfileVersion1", `FileDigest`, `FileDigestAlgorithm` "SHA256".
- **It contradicts Microsoft:** "AES-CTR XORKeyStreamed Content" and "FileDigest ... Base64 encoded SHA256 hash of the encrypted content". Microsoft's Graph reference says fileDigest is "The file digest prior to encryption". Microsoft's sample hashes the source file and uses .NET `Aes` defaults (CBC) (section 10). Its example `FileDigest` value `47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=` is the SHA-256 of zero bytes (inference from the well-known value), so the example looks synthetic.
- I saw no LICENSE in the repo's Resources list. 3 stars.

## 8. MSEndpointMgr/IntuneWin32App

Sources: https://github.com/MSEndpointMgr/IntuneWin32App; raw `Public/New-IntuneWin32AppPackage.ps1`; issue #164 (read 2026-10-26).
- "This module was created to provide means to automate the packaging, creation and publishing of Win32 applications in Microsoft Intune." 516 stars, 8 contributors, MIT, last commit 2026-01-25 ("1.5.0").
- Packaging wraps the official exe: `Start-DownloadFile -URL "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -Path $env:TEMP` and then `Invoke-Executable -FilePath $IntuneWinAppUtilPath -Arguments "-c ... -s ... -o ... -q"`. Packaging is Windows only.
- #164 (open, 2024-06-09): "New-IntuneWin32AppPackage.ps1 calls IntuneWinAppUtil.exe / Invoke-AzureCopyUtility.ps1 calls AzCopy.exe / New-IntuneWin32AppBody.ps1 calls msiexec.exe ... will fail in Linux based OS".

## 9. Windows CI only (scope c)

- GitHub-hosted images (https://github.com/actions/runner-images, read 2026-10-26): "Windows Server 2025 | x64 | windows-latest, windows-2025, or windows-2025-vs2026" and "Windows Server 2022 | x64 | windows-2022".
- Windows2022-Readme (image "20261022.344.1", OS "10.0.20348 Build 5761"): ".NET Framework: 4.7.2, 4.8, 4.8.1", "PowerShell 7.6.8", "Git 2.56.0.windows.3". So the official exe's prerequisite and Git Bash are present on `windows-2022`. The exact meaning of that ".NET Framework" line (runtime or developer packs) was not checked. I did not read the windows-2025 readme.
- No official Microsoft cross-platform option found:
  - Content Prep Tool #26 "Linux executable?" (opened 2020-02-04) is **Open**, labelled "enhancement" by Adam Meltzer (ameltzer-MSFT). #86 (Cloud Shell: "Exec format error") was "closed this as completed" by ameltzer-MSFT on 2025-01-24 with only the comment "#26". https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/26 and /86.
  - The Intune admin center needs a `.intunewin` for a Win32 app: "select a Windows installation file with the extension .intunewin" (https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32, read 2026-10-26). It accepts no raw-file upload for Win32.
  - Microsoft Graph upload takes the encrypted inner file plus `fileEncryptionInfo`, not the outer `.intunewin` (section 10). Microsoft's `Win32_Application_Add.ps1` sample still expects a `.intunewin` as input.
  - WebSearch found no Microsoft GitHub Action, Azure DevOps task or Graph PowerShell SDK cmdlet that builds `.intunewin`. A search proves only that I did not find one.
- Licence risk for CI or a service: in #26 (2020-04), davidhaymond wrote: "I'll have to cancel my plans to create an Intune packager web app, as it is not allowed by the license terms (clause 4e)." I did not read the licence PDF, so whether 4e restricts CI use is unknown. The Eval delegate should read clause 4e.

## 10. Is the `.intunewin` format documented?

**Answer: partly.** Microsoft documents the encryption parameters and the Graph upload contract, and publishes MIT sample code that does the encryption. Microsoft does not document the `.intunewin` container (outer zip layout, `Detection.xml` schema, `ToolVersion`, inner zip rules). Those are reverse-documented by the community.

| Aspect | Microsoft-documented? | Source and what it says |
|---|---|---|
| Encryption info fields | Yes | Graph `fileEncryptionInfo` (https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-fileencryptioninfo?view=graph-rest-1.0, "Last updated on 09/13/2024"): "initializationVector ... Must be 16 bytes." / "mac ... The hash of the concatenation of the IV and encrypted file content. Must be 32 bytes." / "macKey ... Must be 32 bytes." / "profileIdentifier ... Currently, only ProfileVersion1 is supported." / "fileDigest ... The file digest prior to encryption. ProfileVersion1 requires a non-null FileDigest." / "fileDigestAlgorithm ... ProfileVersion1 currently only supports SHA256" |
| Key length | Yes (service error text) | Graph error quoted in Microsoft Q&A 1621399: "ProfileVersion1 requires an EncryptionKey that is 32 bytes long." A 32-byte key means AES-256 (inference). |
| Cipher, MAC algorithm, file layout | Yes, as Microsoft sample code (MIT), not as a spec | `microsoft/mggraph-intune-samples` `LOB_Application/macOS_Application_PKG_Add.ps1` ("Copyright (c) Microsoft Corporation ... Licensed under the MIT license"): `$aes = [System.Security.Cryptography.Aes]::Create()`; `$hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256`; it writes `$hmacLength + $initializationVector.Length` placeholder bytes, then the ciphertext through `CryptoStream`, then the IV at offset `$hmacLength`, then `$hmac = $hmacSha256.ComputeHash($finalStream)` over IV+ciphertext, and writes the HMAC at offset 0. Keys: `$encryptionKey = GenerateKey`, `$hmacKey = GenerateKey`, `$initializationVector = GenerateIV`. Digest: `(Get-FileHash $sourceFile -Algorithm SHA256)` of the plaintext. `profileIdentifier = "ProfileVersion1"`. The sample targets macOS PKG upload; that Win32 uses the same ProfileVersion1 scheme is inference, supported by the shared `fileEncryptionInfo` type. |
| AES mode and padding | Yes (.NET defaults) | `SymmetricAlgorithm.Mode`: "The default is CBC." `SymmetricAlgorithm.Padding`: "The default is PKCS7." (learn.microsoft.com .NET 8 API pages). The sample does not override either, so it uses AES-256-CBC with PKCS7 (inference from the defaults plus the 32-byte key). |
| Upload flow | Yes | Graph `mobileAppContentFile` (…/intune-apps-mobileappcontentfile, "Last updated on 10/10/2025"): methods Create, "commit action ... Commits a file of a given app", "renewUpload action"; properties `size`, `sizeEncrypted`, `azureStorageUri`, `isCommitted`, `manifest`, `uploadState` (`commitFileSuccess`, `commitFileFailed`, ...). |
| `Detection.xml` element names | Only implicitly (a Microsoft sample reads them) | `Win32_Application_Add.ps1` (same repo) reads `ApplicationInfo.Name`, `.FileName`, `.SetupFile`, `.UnencryptedContentSize`, `.MsiInfo.MsiProductCode/MsiProductVersion/MsiPublisher/MsiRequiresReboot/MsiUpgradeCode/MsiExecutionContext`, `.EncryptionInfo.EncryptionKey/macKey/initializationVector/mac/fileDigest/fileDigestAlgorithm`. It opens the `.intunewin` with `[IO.Compression.ZipFile]::OpenRead` and extracts entries by name. This is a consumer, not a schema. |
| Outer zip layout (`IntuneWinPackage/Contents/IntunePackage.intunewin`, `IntuneWinPackage/Metadata/Detection.xml`), `ToolVersion`, inner zip compression | No | Community only: lwalthert, maxihafer, LetsGoIntunePackager, kenchan0130 READMEs. Intune docs say only "zips all files and subfolders" (create-win32-package, "Last updated on 04/14/2026"). WebSearch for `"Detection.xml" intunewin site:learn.microsoft.com` found only a Q&A thread whose answer links a community decoder as "none-official". |

Side note: the old Microsoft sample repo `microsoftgraph/powershell-intune-samples` returns 404 (read 2026-10-26). The successor is `microsoft/mggraph-intune-samples` (285 stars, MIT, last commit 2026-09-25).

### What a native implementation needs (if chosen)

Each item cites its source. Tool checks were run on this Mac on 2026-10-26.

1. Zip the payload folder to `IntunePackage.intunewin` (plaintext zip). Compression rules: unknown, community tools differ (maxihafer "without any compression", LetsGo "Deflate"). Tools: `/usr/bin/zip` on macOS (not run), perl `IO::Compress::Zip` (not checked), .NET `ZipFile` on Windows.
2. Random 32-byte AES key, 32-byte HMAC key, 16-byte IV (Graph `fileEncryptionInfo` plus the Q&A error). Tool: `openssl rand` (not run).
3. Encrypt with AES-256-CBC and PKCS7 (Microsoft sample plus .NET defaults). macOS ships `LibreSSL 3.3.6` (`/usr/bin/openssl version`, verified). Its `enc -help` lists `-aes-256-cbc`, `-K key ... as a hexadecimal string` and `-iv IV ... as a hexadecimal string` (verified). Stock perl has no AES: `Can't locate Crypt/Rijndael.pm` (verified). python3 stdlib has no AES (launch prompt; not re-checked). On Ubuntu, whether `openssl` is in the base images and containers is unknown, so it would need a `Depends`.
4. File = HMAC(32) || IV(16) || ciphertext. HMAC-SHA256 key = macKey, over IV||ciphertext (Microsoft sample, Graph `mac` description). Stock perl `Digest::SHA` `hmac_sha256_hex` works (verified: it printed a 64-hex digest). `openssl dgst -hmac` was not checked.
5. fileDigest = SHA-256 of the plaintext zip, `fileDigestAlgorithm` "SHA256" (Graph, sample). Tools: perl `Digest::SHA` or `shasum -a 256`.
6. For portal upload only: write `Detection.xml` (community schema) and the outer zip (community layout). For Graph upload: skip both, send `fileEncryptionInfo` and the sizes in the commit (Microsoft-documented). The Win32 Graph app body (`win32LobApp`: `fileName`, `setupFilePath`, commands, rules) is a documented Graph resource that I did not read (gap).
7. Risk (inference): the admin center warns when content was "packaged using an older version of the tool" (add-win32). It presumably reads `ToolVersion`, so a native packer must choose a value. That is a compatibility decision Microsoft does not document.

## 11. Mono / Wine community reports (scope d)

All from microsoft/Microsoft-Win32-Content-Prep-Tool#26 (read 2026-10-26). I matched the dates to comments by the order of the page's timestamps (inference).
- davidhaymond (2020-04-02): "I was able to successfully run the tool on a Debian server using Wine and Mono."
- g3rhard (2022-11-25) on IntuneAppBuilder: "App works good (tested with one app), but still - for Windows I'll prefer tool from this repo, as it didn't require .Net."
- OfficialEsco (2023-07-30): "Managed to make it run via Wine by installing .NET Framework 4.7.2 as per the Prerequisites ... winetricks dotnet472 ... edit: I got mscoree.dll not found but after wiping the wine data and installing .NET Framework 4.8 it works ... winetricks dotnet48"
- French-Asgeir (2024-02-16): "I'm trying to use it with an Ubuntu 22.04 action-runner, but I can't even get it to work on WSL Ubuntu-22.04"
- OfficialEsco (2024-02-16): "its been working for me on 2 Fedoras and 1 Arch install ... Install Wine / Install Winetricks / Install Wine-mono / winetricks dotnet48 ... wine InTuneWinAppUtil.exe -c Temptest/ -s Temptest/IntuneWinAppUtil.exe -o Temptest/ ... Successfully created IntuneWin"
- French-Asgeir (2024-02-19): "I wasn't installing mono, it seems to work now. Thank you !" Ubuntu success is implied but not stated.
- None of these reports says whether Intune accepted the output. I found no macOS Wine or Mono report. Mono alone, without Wine, is not reported anywhere I read.
- Assessment (inference): fragile (winetricks installs Microsoft .NET Framework into a prefix, which is interactive "Follow the installation prompts"), with an unread licence clause, and design 3(a) already rules out "IntuneWinAppUtil under Wine". Not recommended. The Probe delegate tests it hands-on.

## 12. Recommendation, ranked against the evaluation principles

1. **Official `IntuneWinAppUtil.exe` on a GitHub-hosted Windows runner** (`windows-2022` now; `windows-2025` is `windows-latest`). Principle 1 (official endorsement) and principle 2 (provenance) override principles 4 and 5 (cross-platform delivery, same upstream). Design 3(c) stands. **Correction to design 3(a):** the sentence "a `.intunewin` needs Microsoft's tool" is wrong as a fact. The right reason is "Microsoft's tool is the only official packer". Health: per the Eval delegate.
2. **If the commander wants a macOS or Linux build host** (to drop the Windows runner, or to build locally on the Mac): `IntuneAppBuilder.Console` through `/tool-eval` and `/tool-adopt` on all three platforms (P-4). It ranks above the rest on principle 2 (company org, 14 contributors, Apache-2.0, NuGet provenance), principle 4 (one .NET 8 tool on every OS), and acceptance evidence (tenant integration tests). Disclose: not official, <500 stars, no tagged releases, needs the .NET 8 SDK on the build host (a new managed dependency).
3. **Native build in aitools**, worth it only if fleet releases upload through Microsoft Graph. In that case the reverse-documented container is not needed at all, and every crypto parameter has a Microsoft source (section 10). On macOS this uses stock tools only (LibreSSL `openssl enc -aes-256-cbc`, perl `Digest::SHA`); on Windows, .NET. The cost is aitools owning crypto code plus a Graph upload client, and it needs a tenant test. It does not yield a portal-uploadable `.intunewin` unless the community `Detection.xml` schema is also adopted.
4. Not recommended: svrooij/ContentPrep (four yellow flags plus the author's disclaimer), kenchan0130, lwalthert, LetsGoIntunePackager, maxihafer (tiny personal projects; maxihafer has no licence and contradicts Microsoft), WrapTune-MacOS (macOS GUI, personal), Wine/Mono (fragile, licence question, excluded by 3(a)).

## INCIDENT markers (not filed)

- INCIDENT: (medium, plan) `plans/build-package/design.md` section 3(a) says "a `.intunewin` needs Microsoft's tool". Evidence: Microsoft documents the crypto and Graph upload (section 10), and seven community packers exist, one with tenant integration tests. The conclusion (native Windows host) still holds under principle 1, but the stated reason is a factual error that later sessions may repeat.
- INCIDENT: (low, upstream) The maxihafer/content-prep README says AES-CTR and a digest of the encrypted content, which contradicts Microsoft's Graph reference ("prior to encryption") and Microsoft's sample (CBC defaults). Any future aitools format note must cite Microsoft sources, not this README.
- INCIDENT: (low, harness) The `anthropic-skills:deep-research` skill requires the caller to act only as coordinator, spawn subagents that follow its own researcher.md, and write `research_notes/` and `reports/` into the working directory (here the main checkout). That conflicts with the mission's access paths, the chrome-devtools-for-citations rule and delegation duty. I loaded it, followed none of its process, and did the research by hand (WebSearch for discovery, chrome-devtools for every cited page). No harness rule says which wins when a mandated skill conflicts with the mission's access rules.
- INCIDENT: (low, upstream link rot) `https://github.com/microsoftgraph/powershell-intune-samples` returns "Page not found". Community modules (for example the macOS_IntuneManagement module found by WebSearch) credit it. Its successor is `microsoft/mggraph-intune-samples`. I did not check whether any aitools file references the old URL.

## Gaps in my reading (honest)

- I did not read the Content Prep Tool licence PDF (clause 4e). The Eval delegate owns the official tool.
- I did not read IntuneAppBuilder source code or CI run history, the ContentPrep test file contents, or the WrapTune `verify-intunewin.py`. Every candidate's cipher and `Detection.xml` output is as its README claims, and only IntuneAppBuilder has tenant-test evidence.
- I did not check any candidate's GitHub security advisories tab. Advisories are unknown for all of them.
- IntuneAppBuilder 4.1.0's exact publish date is unknown: NuGet shows "5 months ago" and the last commit is 2026-05-18.
- I did not read the Graph `win32LobApp` resource or the commit action pages, or the `windows-2025` runner readme. I did not run `openssl rand`, `openssl dgst -hmac`, `zip` or `IO::Compress::Zip`. Ubuntu stock `openssl` presence is unknown.
- I did not open alcavix/IntuneWin-Creator or `SvRooij.Winget-Intune.Cli` (search results only).
- I read the packet, the user and project rules listed in it (all `.claude/rules/*.md` were in context or read), tool-evaluation-criteria.md and tool-evaluation-playbook.md in full, and design.md sections 3(a)-(c) and 17 (P-4). I did NOT read the reference subset (script-standards-detail.md, cross-platform-detail.md, logging.md, managed-file-deployment.md, plan-execution-detail.md), `plans/tool-support-and-machine-profile.md` or the prior handoff. This mission wrote no code and no registry entries, so I judged them not load-bearing.
- I did not invoke `/aitool-eval`. I applied the criteria from `reference/tool-evaluation-criteria.md` directly (read in full).

## Sources (read 2026-10-26, chrome-devtools unless noted)

- https://github.com/simeoncloud/IntuneAppBuilder ; https://www.nuget.org/packages/IntuneAppBuilder.Console
- https://github.com/svrooij/ContentPrep ; /releases ; /tree/main/tests/SvR.ContentPrep.Tests ; https://www.nuget.org/packages/SvRooij.ContentPrep/ ; https://www.powershellgallery.com/packages?q=ContentPrep ; https://www.powershellgallery.com/packages/SvRooij.ContentPrep.Cmdlet/0.4.0 ; https://wintuner.app/docs/related/content-prep-tool ; https://github.com/svrooij/WinTuner
- https://github.com/kenchan0130/intunewin ; /releases
- https://github.com/lwalthert/intunewin
- https://github.com/michelbragaguimaraes/LetsGoIntunePackager
- https://github.com/thefinder808/WrapTune-MacOS
- https://github.com/maxihafer/content-prep
- https://github.com/MSEndpointMgr/IntuneWin32App ; https://raw.githubusercontent.com/MSEndpointMgr/IntuneWin32App/master/Public/New-IntuneWin32AppPackage.ps1 ; https://github.com/MSEndpointMgr/IntuneWin32App/issues/164
- https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-fileencryptioninfo?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-mobileappcontentfile?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/answers/questions/1621399/error-profileversion1-requires-an-encryptionkey-th
- https://github.com/microsoft/mggraph-intune-samples ; /tree/main/LOB_Application ; raw `LOB_Application/macOS_Application_PKG_Add.ps1` ; raw `LOB_Application/Win32_Application_Add.ps1`
- https://github.com/microsoftgraph/powershell-intune-samples (404)
- https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.symmetricalgorithm.mode?view=net-8.0 ; …symmetricalgorithm.padding?view=net-8.0
- https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package ; …/add-win32
- https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/issues/26 ; /issues/86
- https://github.com/actions/runner-images ; /blob/main/images/windows/Windows2022-Readme.md
- Local (this Mac): `/usr/bin/openssl version`, `/usr/bin/openssl enc -help`, perl `Digest::SHA` HMAC, perl `Crypt::Rijndael` (absent)
