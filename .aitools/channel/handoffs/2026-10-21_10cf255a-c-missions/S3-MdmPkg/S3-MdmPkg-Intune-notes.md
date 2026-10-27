# S3-MdmPkg-Intune notes: Intune script/app delivery limits

Delegate: S3-MdmPkg-Intune (level 3, delegated by S3-MdmPkg). Read date for
every source: 2026-10-26. Read method for every source: chrome-devtools
(real browser, `evaluate_script` returning `main.innerText`). No WebFetch, no
Firecrawl. Quotes are verbatim from the page text.

URL note: every starting URL under `/intune/intune-service/...` now
redirects to a new path under `/intune/device-management/...` or
`/intune/app-management/...`. The final (redirected) URLs are listed below.
Pages show "Last updated on 04/14/2026" (Remediations 04/16/2026, macOS agent
10/23/2026).

## Limits table

| Mechanism | Platform | Limit (verbatim) | Context | URL | Read date | Read method |
|---|---|---|---|---|---|---|
| Platform script (PowerShell) | Windows 10+ | "The script must be less than 200 KB (ASCII)." | User ("Run this script using the logged on credentials: Select Yes (default)") or system (No) | https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows | 2026-10-26 | chrome-devtools |
| Remediations (detection + remediation script package) | Windows only | Script size: unknown (not stated). Stated: "You can have up to 200 script packages." / "The maximum allowed output size limit is 2,048 characters." | User or system ("Run this script using the logged-on credentials") | https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations | 2026-10-26 | chrome-devtools |
| Win32 app (.intunewin) | Windows | "Windows application size must not be greater than 30 GB per app." | "Install behavior: Set the install behavior to either System or User." | https://learn.microsoft.com/en-us/intune/app-management/deployment/win32 | 2026-10-26 | chrome-devtools |
| Win32 app PowerShell script installer | Windows | "Scripts are limited to 50 KB in size" | "Scripts run in the same context as the app installer (system or user context)" | https://learn.microsoft.com/en-us/intune/app-management/deployment/win32 (also add-win32: "maximum size 50 KB") | 2026-10-26 | chrome-devtools |
| Windows LOB / AppX / MSIX | Windows | "The maximum file size for Windows Line-of-business (LOB) apps, Windows Universal AppX, Windows Universal AppX bundle, Windows Universal MSIX, and Windows Universal MSIX bundle, have a maximum size limit of 8 GB per app." | unknown (not read) | https://learn.microsoft.com/en-us/intune/app-management/deployment/ | 2026-10-26 | chrome-devtools |
| Shell script | macOS 12.0+ | "The script file must be less than 1 MB in size." | "Run script as signed-in user: Select Yes ... Choose No (default) to run the script as the root user." | https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos | 2026-10-26 | chrome-devtools |
| Custom attribute (shell script) | macOS | "The result returned by the shell script must be 20KB or less." (script size: unknown) | unknown | https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos | 2026-10-26 | chrome-devtools |
| LOB app (managed, signed .pkg) | macOS | "macOS LOB apps have a maximum size limit of 2 GB per app." | unknown (installer; not stated) | https://learn.microsoft.com/en-us/intune/app-management/deployment/add-lob-macos | 2026-10-26 | chrome-devtools |
| Unmanaged PKG app (macOS app (PKG)) | macOS | "The PKG file is smaller than 8 GB in size." | unknown (not stated) | https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos | 2026-10-26 | chrome-devtools |
| Unmanaged PKG pre/post-install scripts | macOS | "Each pre-install or post-install script must be less than 15360 characters long." | unknown (not stated) | https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos | 2026-10-26 | chrome-devtools |
| DMG app | macOS | "DMG app is smaller than 8 GB in size." | n/a (installs .app to /Applications) | https://learn.microsoft.com/en-us/intune/app-management/deployment/add-dmg-macos | 2026-10-26 | chrome-devtools |

The HARNESS-2 claim (Windows PowerShell script <200 KB, macOS shell script
<1 MB) is confirmed verbatim; the URLs have moved (above).

## Per-mechanism detail

### Windows platform scripts (PowerShell)
Source: run-powershell-scripts-windows (URL above).
- Run frequency: "Once the script executes, it doesn't execute again unless there's a change in the script or policy."
- Retry: "If the script fails, the Intune management extension retries the script three times for the next three consecutive Intune management extension check-ins."
- Per user: "PowerShell scripts assigned to the device run for every new user that signs in, except on multi-session SKUs where user check-in is disabled."
- Timeout: "PowerShell scripts time out after 30 minutes."
- Ordering: "PowerShell scripts are executed before Win32 apps run."
- Sign-in: "End users aren't required to sign in to the device to execute PowerShell scripts." (How this combines with user context when nobody is signed in: unknown.)
- Signing: "Enforce script signature check: Select Yes (default) if the script must be signed by a trusted publisher."
- Host: 32-bit by default ("Select No (default) runs the script in a 32-bit PowerShell host"). Windows PowerShell host, not pwsh 7 (inferred from the SysWOW64 WindowsPowerShell path in the troubleshooting snippet; pwsh support: unknown).
- Join requirement: "Devices that are only registered with your workplace or organization in Microsoft Entra ID don't receive the scripts." Also "Scripts don't run on Surface Hubs or Windows in S mode."
- Remote fetch: not prohibited or documented; nothing on proxies. A script can call the network like any PowerShell (inference, not stated).

### Remediations
Source: deploy-remediations (URL above).
- Windows only; Entra joined or hybrid joined; MDM enrolled (Enterprise/Pro/Education) or co-managed.
- Licensing: "Windows Enterprise E3 or E5 ... Windows Education A3 or A5 ... Windows Virtual Desktop Access (VDA) per user". Extra licensing cost compared with platform scripts.
- Encoding: "Ensure the scripts are encoded in UTF-8." With signature check: "UTF-8, not UTF-8 BOM".
- Schedule: Once / Hourly ("must be less than 24 hours") / Daily. Custom packages: "The scripts are rerun every 24 hours."
- Policy retrieval: after restart, "After a user signs into the client", "Once every 8 hours".
- Remediation runs only "if the detection script uses exit code exit 1".
- Script size limit: unknown (not on this page).

### Win32 apps (.intunewin)
Sources: win32, add-win32, create-win32-package (URLs: https://learn.microsoft.com/en-us/intune/app-management/deployment/win32 , https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32 , https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package).
- Size: 30 GB per app (verbatim in table; repeated on add-win32 and create-win32-package: "Windows application size is capped at 30 GB per app.").
- Packaging: "The Microsoft Win32 Content Prep Tool zips all files and subfolders when it creates the .intunewin file." `-c <setup_folder>`: "All files in this folder are compressed into an .intunewin file." So a folder holding the ~450 KB / ~357 KB generated deploy scripts plus a small wrapper fits easily.
- Context: System or User; "User context refers to only a particular user. System context refers to all users of a Windows device." "When a device is enrolled by being Microsoft Entra registered, select System." "Users are not required to be logged in on the device to install Win32 apps."
- Timeout: "Default value is 60 minutes ... Max timeout value is 1440 minutes (1 day)."
- Retry: "The retry return code agent will attempt to install the app three times. It will wait for five minutes between each attempt." Reevaluation "follows a 24-hour cadence" (dependencies section).
- Check-in: "the Intune management extension agent checks every hour (or on service or device restart) for any new Win32 app assignments."
- Content download: "Windows devices can download Intune Win32 app content by using the delivery optimization component of Windows." (Content comes from Intune, not from a URL the admin provides.)
- Detection: custom detection script must exit 0 and write STDOUT; any STDERR = not installed. "We recommend encoding your script as UTF-8 BOM."
- Interaction: "Applications deployed through Intune must install silently and cannot require user interaction".
- PowerShell script installer (50 KB) is an alternative to a command line; runs "in the same context as the app installer".
- Supported for Entra registered devices (create-win32-package prerequisites), unlike platform scripts.

### macOS shell scripts
Source: run-shell-scripts-macos (URL above) and management-agent-macos (https://learn.microsoft.com/en-us/intune/app-management/deployment/management-agent-macos).
- Network: "Devices are connected directly to the Internet. Connection through a proxy is not supported."
- Shebang required: "Shell scripts begin with #! and must be in a valid location such as #!/bin/sh or #!/usr/bin/env zsh."
- Context: root (default) or signed-in user. "Shell scripts that are run as the signed-in user will run for all currently signed-in user accounts on the device at the time of the run." "An end user is required to sign in to the device to execute scripts running as a signed-in user."
- Frequency: "Choose Not configured (default) to run a script only once. Scripts with a frequency set will also run after a device restart."
- Retry: "Max number of times to retry if script fails" (default: no retry).
- Timeout: "Shell scripts that are running for longer than 60 minutes are stopped and reported as \"failed\"."
- Parallelism: "Shell scripts run in parallel on devices as separate processes." (ordering between scripts is not guaranteed; inference from the quote.)
- Check-in: agent "checks for new or updated scripts with Intune services usually every 8 hours. This check-in process is independent of the MDM check-in."
- Signing: no signing requirement stated (unknown whether any exists).

### macOS app types
- LOB (.pkg, managed): 2 GB; "The .pkg file is signed using a \"Developer ID Installer\" certificate"; "The .pkg file doesn't contain a bundle or disk image or .app file."; "The .pkg file contains a payload." Retry: "If installation fails, Intune retries every 24 hours." (add-lob-macos)
- Unmanaged PKG ("macOS app (PKG)"): 8 GB; agent 2308.006+; allows "Unsigned packages", "Packages without a payload", "Packages that install apps outside /Applications/", "Custom packages with scripts". Optional pre-install / post-install scripts (<15360 characters each; agent 2309.007+). Detection is by "Included apps" bundle IDs. Retry: "failed installations are retried at the next agent check-in with up to three time retries." No Uninstall assignment. (add-unmanaged-pkg-macos)
- DMG: 8 GB; "The DMG file must contain one or more files with .app extensions. DMG files containing other types of installer files will not be installed." Not a fit for scripts/config. (add-dmg-macos)

## Bootstrap-pattern notes (small script that clones or downloads the dotprofile repo / a release asset)

1. **Windows size**: the generated `setup-user-claude.ps1` (~450 KB) and `setup-user-skills.ps1` (~357 KB) exceed the 200 KB platform-script limit and the 50 KB Win32 script-installer limit. They fit inside a Win32 .intunewin (30 GB) as packaged files, with a command line or small wrapper as the installer.
2. **macOS size**: both fit under the 1 MB shell-script limit individually only if the bash counterparts are under 1 MB (bash sizes: unknown here; S3-MdmPkg-Build owns repo sizes). The unmanaged PKG type (8 GB, unsigned allowed, scripts allowed, no payload allowed) carries any size.
3. **Network at run time**: macOS scripts require a direct Internet connection, no proxy (quoted above). Windows: no network statement found (unknown); IME needs to reach Intune, so some network exists at run time (inference).
4. **User HOME**: scripts writing `~/.claude` need the user's HOME.
   - Windows platform scripts default to user context ("logged on credentials: Yes (default)") and re-run "for every new user that signs in" when assigned to the device. That fits per-user deployment.
   - Win32 apps in User context install for "only a particular user"; in System context HOME is the system profile (inference), so a system-context installer would have to resolve the signed-in user itself.
   - macOS scripts default to root; as root, `$HOME` is not the user's (inference). "Run script as signed-in user" runs for every signed-in user but needs someone signed in. The unmanaged PKG pre/post-install script context is unknown (not stated; macOS installer scripts usually run as root, not verified).
5. **git availability**: Intune documents nothing about git on endpoints. Unknown. A bootstrap that downloads a release asset (zip/tarball) over HTTPS avoids the git dependency; a clone needs git present (macOS: Xcode command line tools, Windows: Git for Windows, neither verified here).
6. **Run once**: Windows platform scripts and macOS scripts (default "Not configured") run once; Windows re-runs only on script/policy change. A bootstrap that should keep the harness current needs a macOS frequency, a Remediation schedule (license cost), or a Win32 version bump.
7. **Secrets**: Microsoft says "Don't include any type of sensitive information in scripts (such as passwords)" (platform scripts and Remediations pages). A private dotprofile repo needs credentials from somewhere else (unknown how; out of scope).

## Fit note (short)

Windows: Win32 app (.intunewin) is the only documented Intune mechanism that carries the ~450 KB generated scripts as-is; a <200 KB platform script that downloads a release asset is the alternative, in user context. macOS: shell script (<1 MB, direct Internet, user or root) for a small bootstrap; unmanaged PKG (8 GB) for a full payload.

## Unknowns

- Remediations script size limit.
- Custom-attribute script size limit.
- Unmanaged PKG / LOB install context and pre/post-install script context.
- Windows platform script behaviour in user context with nobody signed in.
- Whether Windows platform scripts can use pwsh 7.
- git presence on managed endpoints.
- Proxy support for Windows IME scripts.

## INCIDENT markers

- INCIDENT: (low) The starting URLs given in the launch prompt (`/intune/intune-service/apps/...`, `/fundamentals/remediations`) all redirect to new paths, and `.../apps/macos-intune-management-agent` returns 404. Any harness file citing the old Intune URLs (HARNESS-2 hand-back cited learn.microsoft.com, path not checked here) carries stale links; cite the redirected URLs above.

## Sources (all read 2026-10-26, chrome-devtools)

- https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows
- https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos
- https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations
- https://learn.microsoft.com/en-us/intune/app-management/deployment/win32
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
- https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package
- https://learn.microsoft.com/en-us/intune/app-management/deployment/ (Add apps; size limits)
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-lob-macos
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-dmg-macos
- https://learn.microsoft.com/en-us/intune/app-management/deployment/management-agent-macos
