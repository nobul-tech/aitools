# S3-BuildPkg-PkgWin notes: aitools as an Intune Win32 app (.intunewin), unsigned, fleet

Delegate: S3-BuildPkg-PkgWin (level 2 under S3-BuildPkg). Read date for every
source: 2026-10-26. Read method: chrome-devtools (own tab, `evaluate_script`
returning `main.innerText`), unless marked otherwise. No WebFetch, no Firecrawl.
Quotes are verbatim. "Inference" marks anything not stated by a source.

## Summary (5 lines)

1. Only the Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`, v1.8.7, 2025-08-13, Microsoft, proprietary licence) is official. It needs .NET Framework 4.7.2, so it runs on a Windows build host only. No official macOS/Linux packager exists. One unofficial GPL-3.0 reimplementation exists (svrooij/ContentPrep) and is unverified.
2. Win32 install and uninstall commands run under a 32-bit IME host: `powershell.exe` launches 32-bit Windows PowerShell (`%SystemRoot%\Sysnative\...` forces 64-bit). Intune does not document pwsh 7. The uninstall command does not expand environment variables. Timeout is 60 min by default, 1440 max. A Retry code means 3 attempts, 5 min apart.
3. Install behaviour is System or User. A User-context app assigned to users fails if it needs admin rights. Dependencies install automatically and need no assignment. Supersedence handles update (no uninstall) and replace (uninstall). A Required app whose detection fails is offered again within about 24 h. Available apps are not reinstalled.
4. Detection: MSI, File (exists / date / version / size), Registry, or a custom PowerShell script (exit 0 plus STDOUT, and nothing on STDERR). Script size limit and run context are not documented. A version marker file or registry value suits both apps. Logs are in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` (AppWorkload.log). Collect diagnostics accepts `%PROGRAMDATA%`-style paths.
5. Recommended design: a System app with the payload plus pwsh 7 (as a dependency app), and a User app with per-user config that depends on it. Per-user dotprofile: one generic User app that fetches the signed-in user's dotprofile when it runs. A per-user .intunewin means one app and one group per user, which does not scale. Two blockers: winget CLI is "not supported in the system context", and PowerShell 7.7+ ships no MSI (MSIX only, per-user).

## 1. IntuneWinAppUtil (Microsoft Win32 Content Prep Tool)

| Fact | Verbatim | Source |
|---|---|---|
| What it is | "Use the Microsoft Win32 Content Prep Tool to preprocess Windows classic (Win32) apps. The tool converts application installation files into the .intunewin format. The tool also detects some of the attributes that Intune requires to determine the application installation state." | [create-win32-package] |
| Zips whole folder | "The Microsoft Win32 Content Prep Tool zips all files and subfolders when it creates the .intunewin file. Be sure to keep the Microsoft Win32 Content Prep Tool separate from the installer files and folders" | [create-win32-package] |
| `-c` | "-c <setup_folder> Setup folder for all setup files. All files in this folder will be compressed into .intunewin file. Only the setup files for this app should be in this folder." | [gh-readme] |
| `-s` | "-s <setup_file> Setup file (e.g. setup.exe or setup.msi)." | [gh-readme] |
| `-o` | "-o <output_file> Output folder for the generated .intunewin file." | [gh-readme] |
| `-q` | "-q If specified, it will be in quiet mode. In quiet mode, there are no interactive prompts and existing content in the output folder (-o) will be overwritten if it exists. Also, if the output folder does not exist, it will be created automatically." | [gh-readme] |
| `-qq` | "-qq If specified, all conditions of -q will be applied and there will be no console output." | [gh-readme] |
| `-a`, `-v`, `-h` | "-a <catalog_folder> Catalog folder for all catalog files. All files in this folder will be treated as catalog file for Win10 S mode." / "-v Tool version (Only available starting version 1.8.2)." | [gh-readme] |
| Example | "IntuneWinAppUtil -c c:\testapp\v1.0 -s c:\testapp\v1.0\setup.exe -o c:\testappoutput\v1.0 -q" | [create-win32-package] |
| Relative refs | "put any files you need to reference into a subfolder of the setup folder. Then, use a relative path to reference the specific file you need." | [create-win32-package] |
| Encryption | "The generated .intunewin file contains all compressed and encrypted source setup files and the encryption information to decrypt it. Please keep it in the safe place as your source setup files." | [gh-readme] |
| Prerequisite (so it needs Windows) | "Prerequisites / .NET Framework 4.7.2" | [gh-readme] |
| Licence | "Review the Microsoft License Terms for Microsoft Win32 Content Prep Tool ... By downloading and using Microsoft Win32 Content Prep Tool, you agree to such license terms." The repo file is `Microsoft License Terms For Win32 Content Prep Tool.pdf`. It is a proprietary licence, not OSS. I did not read the PDF's terms (unknown: whether redistributing the tool is allowed). | [gh-readme] |
| Use latest | "Be sure to use the latest version of the Microsoft Win32 Content Prep Tool. If you don't use the latest version, you'll see a warning that says the app was packaged using an older version of the tool." | [add-win32] |
| Delivery | "You can download the Microsoft Win32 Content Prep Tool from GitHub as a .zip file." The binary `IntuneWinAppUtil.exe` is committed to the repo root. The latest release (v1.8.7) has only "Source code (zip)/(tar.gz)" assets. | [create-win32-package], [gh-releases] |

**/aitool-eval check (no install):**
- Publisher: `microsoft` GitHub org (official). Commits are "Verified".
- Latest release: v1.8.7 "Added FIPS compliance", 2025-08-13 ("Changed SHA256 to use FIPS-compliant algorithm. Refactored logging to prevent crashes. Added silent mode support."). Last commit: 2025-08-13 (Merge PR #156 "fix_the_exe").
- Adoption: 1.6k stars, 298 forks, 116 watchers, 11 contributors, 28 open issues, 10 open PRs.
- Hard blocks: none. It is official, active within 24 months, and I saw no advisory (I did not check the GitHub security tab, so advisories are unknown).
- Yellow flags: proprietary licence (PDF terms not read). No release in the last 12 months (last release is 14.5 months before 2026-10-26). The binary is committed in git rather than shipped as a release asset, so provenance is only the repo commit (no published checksums seen).
- Health (proposed): Windows yellow (no release in 12+ months; no checksums). macOS and Linux n/a.

**Cross-platform build host:**
- Official: Windows only. This is inferred from the .NET Framework 4.7.2 prerequisite, and no Microsoft page mentions macOS or Linux.
- Unofficial, UNVERIFIED: `svrooij/ContentPrep` (https://github.com/svrooij/ContentPrep), "Open-source implementation of Win32ContentPrepTool written in C#", GPL-3.0, 32 stars, 1 contributor (Stephan van Rooij, personal account), latest v0.4.2, last commit 2025-10-03. The author's own warning: "This is not a replacement for the Microsoft tool, it is a re-implementation of the tool based upon public available information. It is not feature complete and it might not work for your use case. If you need a tool that works, use the Microsoft tool." Yellow flags: sole maintainer, low adoption, personal account, copyleft. Not recommended. Note it only.
- Practical options (inference, not researched): a Windows build machine or VM, or a Windows CI runner (for example GitHub Actions `windows-*`), which runs the official exe. Upload to Intune is manual in the admin center. Automation through Microsoft Graph was not researched (unknown).

## 2. Install and uninstall command constraints

| Fact | Verbatim | Source |
|---|---|---|
| Installer type | "Command line: Specify a command line to install the app" / "PowerShell script: Upload a PowerShell script to serve as the installer" | [add-win32] |
| Script installer size | "select PowerShell script to upload your install script (maximum size 50 KB) ... Intune packages the script with the app content and runs it in the same context as the app installer. Installation results appear in the Intune admin center based on the script's return code." | [add-win32] |
| MAA caveat | "If Multi-Admin Approval (MAA) is enabled for your tenant, you can't upload PowerShell scripts during app creation." | [add-win32] |
| 32-bit PowerShell | "Calling powershell.exe in either of these fields will result in a 32-bit Powershell instance being launched. To force 64-bit Powershell execution, use the following command: %SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" | [add-win32] |
| Uninstall env vars | "Environment variable expansion within the Uninstall command is not supported. If you require the use of environment variables, use a custom wrapper script within your Win32 package to wrap the appropriate command and use this script for the Uninstall command." | [add-win32] |
| Silent only | "Applications deployed through Intune must install silently and cannot require user interaction, such as dialog boxes, prompts, or UI input during installation." | [add-win32], [win32] |
| Max run time | "Default value is 60 minutes. If the app takes longer to install than the set installation time, the system will fail the app install. Max timeout value is 1440 minutes (1 day)." | [add-win32] |
| Return-code types | "Failed ... Hard reboot ... Soft reboot ... Retry: The retry return code agent will attempt to install the app three times. It will wait for five minutes between each attempt. Success: The return value that indicates the app was successfully installed." / "Return code entries are added by default during app creation." | [add-win32] |
| Default code values | Not listed on the page. Unknown. Read them from the admin center when creating the app. | [add-win32] |
| Architecture | "Support for 32-bit Windows, 64-bit Windows, and ARM64 operating system architecture" | [win32] |

**PowerShell 7:**
- Intune Win32 and platform-script pages do not mention PowerShell 7 or `pwsh`. The platform-script page offers only a "32-bit PowerShell host" or a "64-bit PowerShell host" and shows `C:\Windows\SysWOW64\WindowsPowerShell\v1.0` [platform-scripts]. Verified: Intune's default hosts are Windows PowerShell. Whether pwsh is supported as a host: not documented (unknown).
- "PowerShell 7 doesn't replace Windows PowerShell 5.1. It installs to a new directory and runs side-by-side with Windows PowerShell 5.1." Windows PowerShell 5.1 is "installed by default on Windows" [pwsh-win].
- pwsh location: "By default, the installer installs the package in $Env:ProgramFiles\PowerShell\7 ... The installed location is added to your $Env:PATH environment variable." [pwsh-win]
- How to call pwsh from a Win32 command line (inference, not documented by Intune): `"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File .\install.ps1`. Use the literal path or `%ProgramW6432%`, because in a 32-bit host `%ProgramFiles%` may expand to `Program Files (x86)`. The page documents this expansion only for detection and requirement paths ("expand any path environment variables in the 32-bit context"). Alternatively, the 64-bit Windows PowerShell 5.1 bootstrap (`%SystemRoot%\Sysnative\...`) can start pwsh. Not tested on a device.
- **Blocker for pwsh as a System prerequisite:** "Beginning with the PowerShell 7.7.0 release, there is no MSI package available. WinGet only installs the MSIX package." and "Store-based installations are installed for a single user. There is no option to install it for all users." [pwsh-win]. The current MSI is "PowerShell-7.6.6-win-x64.msi" / "PowerShell-7.6.6-win-arm64.msi". Its silent install is `msiexec.exe /package PowerShell-7.6.6-win-x64.msi /quiet ADD_PATH=1 USE_MU=1 ENABLE_MU=1 ...` (from the page's `$msiParams` example). The ZIP package is the other machine-wide option: "Unzip the contents to the location of your choice and run pwsh.exe ... For best results, install PowerShell to the $Env:ProgramFiles\PowerShell\7 folder" (manual PATH). 7.6 is listed as "Current LTS". The 7.6 end-of-support date was not read (unknown).
- **winget in System context:** "As packages can be registered for any user except NT AUTHORITY\SYSTEM (aka LocalSystem, aka System), the WinGet CLI is not supported in the system context. The Microsoft.WinGet.Client PowerShell module can be used in the system context with applications that are installed machine wide." [winget-ts]. Also: "Not all installers support installing in “user” scope vs. “machine” scope consistently." This bears on brief Q6 (winget scope). A System-context Win32 installer cannot call `winget`. It would need the Microsoft.WinGet.Client module (not evaluated) or direct MSI/ZIP installs.

## 3. Install behaviour, dependencies, supersedence, assignments, re-evaluation

| Fact | Verbatim | Source |
|---|---|---|
| Context | "User context refers to only a particular user. System context refers to all users of a Windows device." | [add-win32] |
| Entra registered | "When a device is enrolled by being Microsoft Entra registered, select System." | [add-win32] |
| Sign-in | "Users are not required to be logged in on the device to install Win32 apps." How a User-context app behaves with nobody signed in: unknown. | [add-win32] |
| User context + admin | "The Win32 app installation and uninstallation will happen under admin privilege (by default) when the app is set to install in user context and the user on the device has admin privileges." | [add-win32] |
| User targeting + no admin | "if the Win32 app requires device admin privileges or any other permissions that the standard user of the device doesn't have, the app will fail to install." | [add-win32], [troubleshoot-win32] |
| Dependencies | "If Intune has not yet installed an app on a device, any apps configured as dependent apps must be installed first." / "By default, the Automatically install option is set to Yes ... even if the dependent app isn't targeted to the user or device, Intune will install the app" / "You do not have to assign dependent apps" | [add-win32] |
| Dependency limits | "maximum of 100 dependencies" / "Any Win32 app dependency needs to also be a Win32 app." / "evaluation and installation of dependencies doesn't follow a specific order at a dependency level." / "Dependencies aren't applicable for uninstalling a Win32 app." | [add-win32] |
| Dependency retry | "Each dependency will adhere to Intune Win32 app retry logic (try to install three times after waiting for five minutes) and the global reevaluation schedule, which follows a 24-hour cadence." | [add-win32] |
| Supersedence | "To update an app, disable the uninstall previous version option. To replace an app, enable the uninstall previous version option." | [add-win32] |
| Supersedence targeting | "Superseding apps don't get automatic targeting. Each app must have explicit targeting to take effect." | [supersedence] |
| Supersedence limits | "There can be a maximum of 10 nodes in a supersedence relationship" and, on the same page, "There can only be a maximum of 11 nodes in a single supersedence graph." The page contradicts itself; plan for 10. | [supersedence] |
| In-place update | "With an in-place app update, admin can only swap the app content, update the metadata, and change the detection and install commands." | [supersedence] |
| Auto-update | Only for "Available for enrolled devices" assignments with Auto-update. "The total time to receive the superseding app will be 8-16 hours." / "The user must be signed in to the device to receive the superseding app." | [supersedence] |
| Assignments | "Required: The app is installed on devices in the selected groups. Available for enrolled devices: Users install the app from the company portal ... Uninstall" | [add-win32] |
| Available not reinstalled | "Win32 apps installed using the Available for enrolled devices assignment won't be automatically reinstalled by Intune if they're uninstalled from a device in any way." | [win32] |
| Re-offer on failed detection | "If Intune detects that the app isn't present on the device, Intune will offer the app again within approximately 24 hours. This will occur only for apps targeted with the required intent." | [add-win32] |
| Check-in | The two pages disagree. [win32]: "the Intune management extension agent checks every hour (or on service or device restart) for any new Win32 app assignments." [ime]: "The IME checks for new or updated installations with Intune services every 8 hours." | [win32], [ime] |
| Unenroll | "Win32 apps installed by Intune on a managed device won't be automatically uninstalled from that device if it's unenrolled from Intune management." | [win32] |
| Join types | "Devices must be enrolled in Intune and either: Microsoft Entra registered / Microsoft Entra joined / Microsoft Entra hybrid joined". Editions: "Enterprise, Pro, or Education". No S mode for IME. | [win32], [ime] |

What this means for Q5 (overwrite on recurring runs), as an inference from the quotes: a Win32 app does not rerun on a schedule. It reinstalls only when detection fails (Required, about every 24 h) or when the app is updated or superseded. If the detection rule checks the installed aitools version, an in-place content swap with a new version in the detection rule makes the old devices fail detection, so they reinstall. Re-running the installer therefore happens once per version, not on every check-in.

## 4. Detection rules

| Rule | Verbatim | Source |
|---|---|---|
| All rules AND | "The conditions for all rules must be met to detect the app." | [add-win32] |
| MSI | "Verify based on an MSI version check. This option can be added only once." | [add-win32] |
| File | "Verify based on file or folder detection, date, version, or size." / "Path ... This shouldn't include special characters such as , or \"." / 32-bit option: "Select No (default) to expand any path variables in the 64-bit context on 64-bit clients." | [add-win32] |
| Registry | "Verify based on value, string, integer, or version." / "A valid syntax is HKEY_LOCAL_MACHINE\Software\WinRAR or HKLM\Software\WinRAR." / "Select No (default) to search the 64-bit registry on 64-bit clients." | [add-win32] |
| Script | "The app will be detected when the script both returns a 0 value exit code and writes a string value to STDOUT." / "if any data is written to STDERR, the detection result is evaluated as not installed" / "Run script as 32-bit process on 64-bit clients: ... No (default) to run the script in a 64-bit process" / "We recommend encoding your script as UTF-8 BOM." | [add-win32] |
| Script size limit | Not stated. Unknown. | [add-win32] |
| Script run context | Not stated for detection scripts. Requirement scripts have "Run this script using the logged on credentials"; detection scripts list no such option. Unknown whether a detection script for a User-context app runs as that user. | [add-win32] |
| HKCU / %LOCALAPPDATA% in File/Registry rules for a User app | Not documented (unknown). The pages show only HKLM examples and environment-variable expansion in "32-bit/64-bit context". | [add-win32] |
| File version helper | `[System.Diagnostics.FileVersionInfo]::GetVersionInfo("<path to binary file>").FileVersion`, with an exit 0 / exit 1 sample. | [troubleshoot-win32] |

Suggested version markers (inference):
- **System app:** File rule, path `%ProgramData%\aitools`, file `version.txt`, method "exists". Or better, a Registry rule `HKLM\SOFTWARE\aitools` value `Version`, method "version", equals `<build version>`, 32-bit=No. A Registry version comparison detects one exact version without a script. File-rule version comparison reads a PE file version, so it does not suit a plain text file.
- **User app:** a custom detection script (64-bit, no signature check) that tests `HKCU:\Software\aitools\UserConfigVersion` or `$env:LOCALAPPDATA\aitools\user-version.txt` equals the expected version, writes it to STDOUT, and exits 0. This works only if the script runs as the user, which is not documented. Test on a device before relying on it. Fallback: a File or Registry rule using `%LOCALAPPDATA%` or HKCU, also undocumented for User context.

## 5. Logs and how failures surface

- IME logs: "IME logs on the client machine are typically in C:\ProgramData\Microsoft\IntuneManagementExtension\Logs. Use CMTrace.exe to view these log files." / "AppWorkload.log ... contains all logging information related to app deployment activities conducted by the IME." Also AgentExecutor.log ("Tracks PowerShell script executions"), AppActionProcessor.log ("detection and applicability check actions"), IntuneManagementExtension.log (main) [ime], [troubleshoot-win32].
- Content cache to exclude from AV: "C:\Program Files (x86)\Microsoft Intune Management Extension\Content" and "C:\windows\IMECache" (x64) [troubleshoot-win32].
- Collect diagnostics in the admin center (only after a failure): "You must specify the complete diagnostic file path." / "You can specify environment variables for diagnostic collection, such as the following: %PROGRAMFILES%, %PROGRAMDATA% %PUBLIC%, %WINDIR%, %TEMP%, %TMP%" / "Only exact file extensions are allowed, such as: .log, .txt, .dmp, .cab, .zip, .xml" / "The maximum diagnostic file to upload is 250 MB or 25 files" [ts-win32-install].
- Where the app's own log should go (inference from the list above): the System app should log under `%ProgramData%\aitools\logs\*.log`, which Collect diagnostics can reach. The User app writes `~/.aitools/logs` (the existing harness location, `reference/logging.md` per script-standards.md). `%USERPROFILE%` and `%LOCALAPPDATA%` are not in the documented variable list, so whether they work is unknown. Suggestion: the User installer also copies its run summary to `%ProgramData%\aitools\logs\user-<name>.log`. That needs a writable ACL, which the System app would have to set (inference).
- Surfacing: return codes map to Failed / Success / Retry / reboot types. Installation status appears in the admin center "based on the script's return code" [add-win32]. A detection that fails after a "successful" install is reported as a failure (inference; the docs only say status depends on detection). Users see toast notifications unless suppressed [win32].

## 6. Requirement rules

- "Operating system architecture: Choose the architectures needed to install the app." / "Minimum operating system: Select the minimum operating system needed to install the app." Also optional disk space, RAM, logical processors, CPU speed [add-win32]. The exact option lists (x64/x86/ARM64 labels, OS build list) were not shown in page text (unknown; read them in the admin center).
- Extra rules: File, Registry, or Script. For a script requirement: "if the existing code is 0, we'll detect the standard output (STDOUT) in more detail", plus "Run this script using the logged on credentials" and "Run script as 32-bit process on 64-bit clients" options [add-win32].
- ARM64 is supported by Win32 apps [win32]. pwsh ships `win-arm64` MSI and ZIP packages [pwsh-win]. Behaviour of `Sysnative` on ARM64: unknown.

## 7. Recommended two-app design (draft for S3-BuildPkg, inference built on the facts above)

**App A: "aitools (system)"**, System context, Required to device groups (or user groups; System context still installs machine-wide).
- Package folder: `win/system/` containing `install.cmd`, `uninstall.cmd`, `install.ps1`, the aitools payload (generated scripts, shared/, registries), and the prerequisite installers. Build: `IntuneWinAppUtil.exe -c win\system -s install.cmd -o out\system -q`.
- Install command: `install.cmd`. It runs `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"`. The script copies the payload to `%ProgramFiles%\aitools` (read-only payload) and writes `HKLM\SOFTWARE\aitools\Version`. It logs to `%ProgramData%\aitools\logs\system-install.log`. Exit codes: 0 success, 1 failed, and a Retry code (for example 1618) for transient lock or network errors.
- Uninstall command: `uninstall.cmd`, a wrapper because environment variables are not expanded in the uninstall field.
- Detection: Registry `HKLM\SOFTWARE\aitools`, value `Version`, version equals `<build version>`, 32-bit=No.
- Requirements: x64 and ARM64 (one app per architecture, or one app whose script picks the pwsh arch); minimum OS: decide (unknown which list the console offers).
- Prerequisites as separate Win32 dependency apps (auto-install = Yes), each with its own detection:
  - **pwsh 7.6 LTS MSI**: install `msiexec /i PowerShell-7.6.6-win-x64.msi /quiet ADD_PATH=1 USE_MU=1 ENABLE_MU=1`, detect the MSI product code. Risk: no MSI after 7.7, so plan the ZIP to `%ProgramFiles%\PowerShell\7` for later.
  - Node and Git: install methods not researched here. Use /tool-eval. Do not use the winget CLI from System context ([winget-ts]).

**App B: "aitools (user)"**, User context, Required to user groups, dependency on App A (auto-install = Yes).
- Install command (needs no admin): `"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%ProgramFiles%\aitools\user-install.ps1"`. This runs the existing `setup-user-*` flow non-interactively (`AITOOLS_FORCE`, non-terminal stdin, so overwrite per interactive-menus.md) against the user's real `%USERPROFILE%`. It writes `HKCU\Software\aitools\UserConfigVersion` and logs to `~/.aitools/logs`. The `%ProgramFiles%` expansion in a 32-bit install host is unverified. Alternatively, put `user-install.ps1` in App B's own package and call it relative to the package folder.
- Detection: custom script (64-bit), HKCU or `%LOCALAPPDATA%` marker equals version. The run-as-user behaviour must be tested on a device.
- The User app must never require admin, because a user-targeted app "will fail to install" if it does.

**Delivering a fleet user's personal data (dotprofile):**
- Intune assigns apps to groups ([add-win32] "Select groups to assign based on users or devices"). A per-user .intunewin holding one person's dotprofile would mean one app plus one group per user. It would also put personal data in a package that admins can download. Not recommended for a fleet.
- Recommended: one generic App B. At run time it resolves the signed-in user (for example `$env:USERNAME` / `whoami /upn`; resolution is not researched) and fetches that user's dotprofile (`git clone`/pull or an HTTPS release asset). Constraint: Microsoft's "Don't include any type of sensitive information in scripts" (MDM-PKG notes, platform scripts page). Credentials for private dotprofile repos must come from the user (for example an existing `gh auth`, or Git Credential Manager) and not from the package. A user without a dotprofile falls back to `shared/` defaults (the dev path already does this per deploy-paths.md).
- Updates: bump the version, swap the content in place, and change the detection version. Every Required device or user re-installs within about 24 h (re-offer rule), or within the hourly to 8-hourly IME check-in. Use supersedence only when the package shape changes (limit 10 nodes).

## INCIDENT markers

- INCIDENT: (low, upstream doc) The Intune supersedence page states both "maximum of 10 nodes" and "maximum of 11 nodes in a single supersedence graph" [supersedence]. Plans should cite 10.
- INCIDENT: (low, upstream doc) The IME check-in interval differs: "every hour" [win32] vs "every 8 hours" [ime]. Plans must not promise update latency below about 24 h.
- INCIDENT: (medium, harness) The MDM-PKG notes say Windows platform-script pwsh support is "unknown". It is now confirmed that Intune documents only Windows PowerShell hosts. The aitools PS 7 baseline (cross-platform.md: "Deploy scripts error on PS 5.1") means every Windows package needs pwsh installed first. From 7.7 the only winget/Store package is per-user MSIX, which cannot serve System context [pwsh-win]. Neither the brief nor the registry records this (registry not checked; use /tool-registry).
- INCIDENT: (medium, harness) The winget CLI is "not supported in the system context" [winget-ts]. Any aitools Windows setup script that calls `winget` will fail under an Intune System-context installer. This affects brief Q6.
- INCIDENT: (low, old URLs) `https://learn.microsoft.com/en-us/troubleshoot/mem/intune/app-management/troubleshoot-win32-apps` returns 404. `/intune/intune-service/apps/apps-win32-troubleshoot`, `/apps-win32-supersedence` and `/intune-management-extension` redirect to the URLs below (consistent with MDM-PKG's URL incident).

## Open questions (with suggested answers)

1. Build host for .intunewin? Suggest a Windows CI runner running the official `IntuneWinAppUtil.exe` (pinned commit, hash recorded by us), not the unofficial GPL reimplementation.
2. pwsh as prerequisite: MSI 7.6 LTS now, or ZIP? Suggest MSI 7.6 LTS as a dependency app now, with a planned ZIP-based app before 7.6 reaches end of support (date unknown; check the PowerShell support lifecycle page).
3. Does a User-context detection script run as the user and see HKCU? Unknown from docs. Suggest a one-device test before the plan commits to HKCU detection.
4. Upload automation (Graph API) for fleet release? Not researched. Suggest a follow-up research task.
5. Should IntuneWinAppUtil itself go through /tool-eval and the registry as a build-time tool? Suggest yes, as a Windows-only build dependency with health yellow.

## Gaps in my own reading (honest)

- I read the mission packet, the brief, the MDM-PKG Intune notes, the user and project rules in context, tool-lifecycle.md, tool-evaluation.md, web-sources.md and the /aitool-eval skill. I did NOT read `reference/tool-evaluation-criteria.md`, `reference/tool-evaluation-playbook.md` or `reference/cross-platform-detail.md` in full. I relied on the /aitool-eval skill, which embeds the criteria and playbook. I did not read the MDM-PKG report.
- Not read: the Content Prep Tool licence PDF; the default return-code values; the 7.6 LTS end-of-support date; Graph upload API; Microsoft.WinGet.Client module.

## Sources (all read 2026-10-26, chrome-devtools)

- [create-win32-package] https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package (Last updated 04/14/2026)
- [add-win32] https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32 (04/14/2026)
- [win32] https://learn.microsoft.com/en-us/intune/app-management/deployment/win32 (04/14/2026)
- [supersedence] https://learn.microsoft.com/en-us/intune/app-management/deployment/configure-win32-supersedence (04/14/2026)
- [ime] https://learn.microsoft.com/en-us/intune/device-management/tools/management-extension-windows (09/24/2026)
- [troubleshoot-win32] https://learn.microsoft.com/en-us/intune/app-management/deployment/troubleshoot-win32 (04/14/2026)
- [ts-win32-install] https://learn.microsoft.com/en-us/troubleshoot/mem/intune/app-management/troubleshoot-win32-app-install (03/30/2026)
- [platform-scripts] https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows
- [pwsh-win] https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.6 (09/21/2026)
- [winget-ts] https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting (07/19/2026)
- [gh-readme] https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool (README v1.8.7)
- [gh-releases] https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases and /commits/master
- (unofficial) https://github.com/svrooij/ContentPrep
