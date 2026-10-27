# S3-BuildPkg-PkgMac notes: unsigned flat .pkg of aitools for Intune (unmanaged PKG) and Jamf Pro

Delegate: S3-BuildPkg-PkgMac (level 2, delegated by S3-BuildPkg). Date: 2026-10-26.
Read date for every web source: 2026-10-26.
Read methods: `cd` = chrome-devtools (real browser; `innerText`, or an a11y snapshot for
learn.jamf.com, whose body text is not exposed to `innerText`); `ws` = WebSearch result
summary only (lower confidence, nothing verbatim from the page); `man` = man page on this
Mac; `run` = command run on this Mac.
Build host: macOS 27.0.1 (BuildVersion 26A434), `xcode-select -p` =
`/Library/Developer/CommandLineTools`, `/usr/bin/pkgbuild` and `/usr/bin/productbuild`
dated Sep 24 (root:wheel). pkgbuild has no version flag (`pkgbuild --version` requires an
argument, `run`); `generator-version="InstallCmds-883 (26A434)"` in the built PackageInfo.
Scratch (throwaway, nothing installed):
`/Users/new-jose/repos/aitools/.scratch/session-pkgmac/` (build-test-pkg*.sh, logs, saved man
pages and Jamf snapshots).

## Summary

1. A plain `pkgbuild --root ... --scripts ...` component pkg wrapped with `productbuild
   --package` builds unsigned on this Mac with stock tools; scripts run as root
   (`auth="root"` in PackageInfo) with a 600 s default timeout.
2. Intune unmanaged PKG needs a real `.app` bundle in "Included apps" to report success and
   to drive updates by version. The stub-app idea (Critic O4) is CONFIRMED by the docs and
   by a test build: pkgbuild records the stub's `CFBundleShortVersionString` in the pkg.
3. Jamf: package plus policy (Once per computer, or Ongoing plus a Smart Group on an
   extension attribute that reads a version marker). Jamf truncates policy logs at 25 KB.
4. Root to console user: `stat -f %Su /dev/console`, then `launchctl asuser <uid> sudo -u
   <user> -H <cmd>` (`launchctl asuser` does not change credentials, so `sudo -u` is
   required). If no user is logged in, defer to a `/Library/LaunchAgents` agent that runs
   at the next login.
5. Gatekeeper checks downloaded, quarantined items; the docs say nothing on unsigned pkgs
   that an MDM agent installs as root. Treat that as **unknown**. Build gap found: on this
   host every payload file carries `com.apple.provenance`, and pkgbuild archives it as
   AppleDouble `._*` entries that `--filter` does not remove (INCIDENT 1).

## 1. pkgbuild / productbuild

### Component vs distribution (product archive)
- `man pkgbuild`: "A "component package" contains payload to be installed by the macOS
  Installer. Although a component package can be installed on its own, it is typically
  incorporated into a product archive, along with a "distribution" and localized resources,
  using productbuild(1)." (man)
- `man productbuild`: "A product archive is a flat file with a .pkg extension." Mode 5
  "Synthesize a distribution for one or more component packages"; `--package pkg-path`
  "The component package at pkg-path is added to the product archive and to the
  synthesized distribution." Example: `productbuild --package /tmp/a.pkg --package
  /tmp/b.pkg Product.pkg`. (man)
- Key pkgbuild options (verbatim from man):
  - `--identifier`: "The macOS Installer recognizes a package as being an upgrade to an
    already-installed package only if the package identifiers match, so it is advisable to
    set a meaningful, consistent identifier".
  - `--version`: "Packages with the same identifier are compared using this version, to
    determine if the package is an upgrade or downgrade. If you don't specify a version, a
    default of zero is assumed".
  - `--install-location`: "whether or not the default install location is actually used by
    the macOS Installer depends on the distribution file you deploy with the package."
  - `--scripts`: "If this directory contains scripts named preinstall and/or postinstall,
    these will be ran as the top-level scripts of the package. ... Any other files under
    scripts-path will be used only if the top-level or component-specific scripts invoke
    them. If the script needs to run for longer than 10 minutes, it should be added as a
    component-specific script with the BundleInstallScriptTimeout component key added."
  - `--nopayload`: "Indicates that the package will contain only scripts, with no payload."
  - `--ownership`: default "recommended" (root:wheel).
  - `BundleInstallScriptTimeout`: "This key is only respected on versions of macOS newer
    than macOS 15.0."
  - `BundleIsRelocatable`: "For packages built with pkgbuild on macOS 27 and later, this
    option defaults to false." (Older build hosts default to true per general practice:
    **unverified**; pin it to false in a component plist so the stub app is never
    "relocated" to a copy the user moved.)
  - `BundleIsVersionChecked` "Don't install bundle if newer version on disk?"; `--analyze`
    sets it to `true` by default (test 4 below). A rollback to an older version would then
    skip the stub app. Set false if rollbacks must work.
- Does Intune unmanaged PKG need a distribution pkg? No: the page lists "Component
  packages" and "Unsigned packages" and "Packages without a payload" as installable
  (add-unmanaged-pkg-macos, cd). Jamf: only PreStage (enrollment) packages must be "flat,
  distribution style .pkg files and signed" (S3-MdmPkg-Jamf-notes.md L47, cd); for policy
  installs Jamf states no format requirement (Packages, Package_Management pages, cd).
  Recommendation: always ship the productbuild product archive. It costs one command, and
  the same file then stays valid if PreStage or signing is added later.
- Build host: pkgbuild/productbuild exist only on macOS (they ship in /usr/bin; no Linux
  build documented by Apple). Linux alternatives found by search (ws, **all unverified, not
  evaluated per /tool-eval, not recommended**): bomutils `mkbom` (github.com/hogliux/bomutils,
  fork github.com/otaran/bomutils), xar, `apepkg` (github.com/peetinc/ape-pkg, "Linux port
  of munki-pkg"), jbomutils (github.com/jindrapetrik/jbomutils). Recommendation: build on a
  macOS host (a CI macOS runner; runner availability not checked here).

### Test build (step 6; nothing installed)
Script: `.scratch/session-pkgmac/build-test-pkg.sh`, log `build-test-pkg.log` (run).

```
pkgbuild --root "$S/root" --identifier tech.nobul.aitools-test --version 0.0.1 \
  --install-location / --scripts "$S/scripts" "$S/out/aitools-test-component.pkg"
productbuild --package "$S/out/aitools-test-component.pkg" "$S/out/aitools-test-0.0.1.pkg"
productbuild --synthesize --package "$S/out/aitools-test-component.pkg" "$S/out/distribution.xml"
pkgbuild --nopayload --identifier tech.nobul.aitools-test-nopayload --version 0.0.1 \
  --scripts "$S/scripts" "$S/out/aitools-test-nopayload.pkg"
pkgutil --payload-files / --check-signature / --expand
```

Payload root: `root/Library/Application Support/aitools-test/VERSION`; scripts:
`postinstall` (mode 755) that echoes `$1..$4`, `id -un`, `COMMAND_LINE_INSTALL` and the
console user.

`pkgutil --payload-files aitools-test-0.0.1.pkg` (verbatim):
```
.
./Library
./Library/Application Support
./Library/Application Support/aitools-test
./Library/Application Support/aitools-test/VERSION
./Library/Application Support/aitools-test/._VERSION
./Library/Application Support/._aitools-test
./Library/._Application Support
./._Library
```
Other results (run):
- `pkgutil --check-signature`: `Status: no signature`, exit 1 (an unsigned pkg makes
  check-signature exit non-zero; a CI gate must not treat that as a build failure).
- Expanded product: `Distribution`, `aitools-test-component.pkg/{Bom,PackageInfo,Payload,Scripts/postinstall}`
  (plus `Scripts/._postinstall`).
- PackageInfo: `identifier="tech.nobul.aitools-test" version="0.0.1" install-location="/"
  auth="root"`, `<postinstall file="./postinstall" timeout="600"/>`.
- Synthesized distribution: `<options customize="never" require-scripts="false"
  hostArchitectures="x86_64,arm64"/>`, `<pkg-ref ... version="0.0.1" onConclusion="none">`.
- Sizes: product 3,515 B, component 2,953 B, payload-free 1,458 B.
- pkgbuild printed `write: Permission denied` four times on every build but still wrote the
  package; cause unknown (probably the agent sandbox; not seen as a failure).

**AppleDouble finding** (build-test-pkg2.sh, -pkg3.sh, run): every file the agent wrote
carries `com.apple.provenance`. `xattr -cr` does not remove it (still listed afterwards),
`COPYFILE_DISABLE=1` does not stop the `._*` entries, and `--filter '/\._'` does not remove
them (they are generated from the xattrs, not present on disk). Apple: "Gatekeeper also
tracks the provenance of files written by downloaded software." (Gatekeeper page, cd).
Effect at install time (xattr restored vs stray `._` files on disk): **unknown, needs a VM
install test**. INCIDENT 1 below.

**Stub-app test** (build-test-pkg4.sh, run): payload
`/Library/Application Support/aitools-test/aitools-test.app` with Info.plist
(`CFBundleIdentifier tech.nobul.aitools-test`, `CFBundlePackageType APPL`,
`CFBundleShortVersionString 0.0.2`, `LSUIElement true`, executable `Contents/MacOS/aitools-test`
= `#!/bin/sh` / `exit 0`). `pkgbuild --analyze` found the bundle:
```
BundleHasStrictIdentifier true / BundleIsVersionChecked true /
BundleOverwriteAction upgrade / RootRelativeBundlePath Library/Application Support/aitools-test/aitools-test.app
```
PackageInfo then lists `<bundle path="./Library/Application Support/aitools-test/aitools-test.app"
id="tech.nobul.aitools-test" CFBundleShortVersionString="0.0.2" CFBundleVersion="0.0.2"/>`,
and the Distribution carries the same `<bundle-version>`. Whether Intune fills "Included
apps" from this metadata on upload: **unknown** (likely, not verified). Whether Intune
detects an app outside /Applications: the page allows "Packages that install apps outside
/Applications/" but does not say detection works there: **unknown, test it**.

## 2. Scripts: arguments, context, console user

- Arguments (Apple "Software Delivery Legacy Guide", Specifying Install Operations,
  https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/SoftwareDistribution4/Install_Operations/Install_Operations.html,
  cd; page marked "Retired Document", updated 2010-09-15):
  - "$1: Full path to the installation package the Installer application is processing."
  - "$2: Full path to the installation destination."
  - "$3: Installation volume (or mountpoint) to receive the payload."
  - "$4: The root directory for the system"
  - postinstall env: "$SCRIPT_NAME, $INSTALLER_TEMP, $PACKAGE_PATH, $RECEIPT_PATH."
  - "The first three install operations, Preflight, Preinstall, and Preupgrade, can stop an
    install. When one of the corresponding executables returns anything other than 0,
    Installer cancels the install."
  - No current (non-retired) Apple page with this table was found. pkgbuild's own man page
    names only preinstall/postinstall (man).
  - **Conflict to note:** in a *Jamf script object*, `$3` is the username (Jamf white
    paper, ws, S3-MdmPkg-Jamf-notes.md L38). In a *pkg* postinstall, `$3` is the target
    volume. aitools code must never read `$3` as the user.
- `installer` env: "COMMAND_LINE_INSTALL  Set when performing an installation using the
  installer command." (man installer). "The installer command requires root privileges to
  run." (man)
- Run context: root. Evidence: `auth="root"` in the built PackageInfo (run); `installer`
  needs root (man); "Scripts deployed from Jamf Pro are automatically run as the root user"
  (Jamf notes, cd). Intune does not state the context for pkg scripts (unknown), but its
  prerequisite "The PKG file successfully runs using the installer command in Terminal"
  (add-unmanaged-pkg-macos, cd) implies the agent uses `installer`.
- Default script timeout 600 s (`timeout="600"` in PackageInfo, run; pkgbuild man "10
  minutes"). A full aitools tool install (brew, node, etc.) can exceed 10 minutes: run it
  detached from the postinstall (LaunchDaemon or `launchctl asuser` job) or raise
  `BundleInstallScriptTimeout` (macOS > 15 only).
- Console user (all verified on this Mac, run):
  - `stat -f %Su /dev/console` printed `new-jose`.
  - `echo "show State:/Users/ConsoleUser" | scutil` printed a dictionary with
    `Name : new-jose`, `UID : 501`, `kCGSSessionOnConsoleKey : TRUE`. (Not documented in
    `man scutil`; the man page only documents `--get`/`--set`.)
  - At the login window both are commonly reported as `root` or `loginwindow`
    (**unverified**, cannot test here). Treat empty, `root`, `loginwindow` and `_mbsetupuser`
    as "no user".
- User-context step:
  - `man launchctl`: "asuser UID command [args] ... It does not modify the process'
    credentials (UID, GID, etc.) or adopt any user-specific environment variables." So use
    `launchctl asuser "$uid" sudo -u "$user" -H <cmd>`: asuser for the user's bootstrap
    namespace (keychain, GUI services), `sudo -u -H` for the UID and HOME.
  - `man sudo`: `-H, --set-home`, `-u user` (man).
- Homebrew from root (docs.brew.sh, cd):
  - Installation: "The macOS .pkg installer supports only Apple Silicon"; "To specify an
    alternate install user, such as when the package is installed at the login window
    before a user has logged in, create /var/tmp/.homebrew_pkg_user.plist with a
    HOMEBREW_PKG_USER value"; "falls back to the active console user. The selected user
    must exist before installation and must not be root."
  - "On macOS, MDM, Munki and Jamf workflows can run Homebrew as the active logged-in
    console user: brew as-console-user install wget ... It fails if no supported console
    user is logged in."
  - "brew as-brew-user install wget ... When sudo is disabled or unavailable, an
    already-root process switches through macOS login or Linux runuser instead."; "A
    root-owned prefix is rejected".
  - FAQ: "Homebrew runs formula builds and installations as the owning account because
    upstream build scripts should not have unrestricted system access."
  - Homebrew for Mac Admins: "The selected account can own the installation at the login
    window; nobody needs to be logged in." "The presence of /usr/bin/git alone is
    insufficient: without developer tools, it can be a macOS installation prompt stub".
    Unattended CLT: download the CLT .pkg from Apple Developer and "Deploy that package
    through your MDM as root."
  - So the old claim "brew refuses root" is superseded: current docs say brew runs as the
    owning account, and `brew as-console-user` / `as-brew-user` switch from root
    themselves. The aitools scripts' `brew` calls should run as the console user (or
    through `brew as-console-user`), never as root.
- No user logged in (Jamf enrollment, login window): defer (section 7). Exiting non-zero
  so the MDM retries (Critic O2) is an option for Intune (retries "up to three time
  retries", cd) but burns the retries; Jamf "Once per computer" retries only if "Automatically
  re-run policy on failure" is on ("up to 10 times", cd).

## 3. Intune unmanaged PKG: detection, updates, uninstall

Source: https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos
(cd; "Last updated on 04/14/2026"). Verbatim:
- Allowed types: "Nonflat packages with a hierarchical structure / Component packages /
  Unsigned packages / Packages without a payload / Packages that install apps outside
  /Applications/ / Custom packages with scripts".
- "Included apps: ... Included app bundle IDs and build numbers are used for detecting and
  monitoring app installation status of the uploaded file. Included apps list should only
  contain the application(s) installed by the uploaded file. Any other type of file that
  isn't an application should be excluded from the Included apps list. If Included apps
  list contains files that aren't applications or if all the listed apps aren't installed,
  app installation status doesn't report success."
- "Ignore app version: Select Yes to install the app if the app isn't already installed on
  the device. This will only look for the presence of the app bundle ID. ... Select No to
  install the app when it isn't already installed on the device, or if the deploying app's
  version number doesn't match the version that's already installed on the device."
- "The CFBundleIdentifier and CFBundleShortVersionString can be found under the
  <app_name>.app/Contents/Info.plist file".
- "When you upload a new version of an available app to Intune, users do not need to take
  any action. It installs automatically."
- Pre-install: "If the preinstall script returns a nonzero code (indicating failure), the
  app doesn't install and reports its installation status as "failed". The preinstall
  script runs again for failed installations at the next device check-in (sync)."
- Post-install (Intune field): "Irrespective of the post-install script run status, an
  installed app reports its installation status as "success"." Limit: "less than 15360
  characters long"; agent "2309.007 or greater".
- "failed installations are retried at the next agent check-in with up to three time retries."
- Known issues: "The Uninstall assignment type isn't available. Only Required and Available
  assignments are currently supported." Retire: "A macOS app deployed using Intune agent
  will not automatically be removed from the device when the device is retired."
- Agent check-in "usually every 8 hours" (management-agent-macos, cd).
- Logs: agent logs in "/Library/Logs/Microsoft/Intune and ~/Library/Logs/Microsoft/Intune";
  "Collect logs" needs "the full absolute log file path", "60 MB (compressed) or 25 files",
  extensions ".log, .zip, .gz, .tar, .txt, .xml, .crash, .rtf"; "The system user folder is
  an invalid location for log files." (run-shell-scripts-macos, cd). So
  `/Library/Logs/aitools/*.log` is collectable; `~/.aitools/logs/*.log` too when given as an
  absolute path (`/Users/<name>/.aitools/logs/...`).

Conclusions:
- **Stub app: confirmed needed.** Without an app in Included apps, Intune cannot report
  success. Is an empty Included apps list even accepted at upload? **Unknown** (not stated).
- **Updates:** bump the stub's `CFBundleShortVersionString` and the pkg `--version` together
  on every build, keep "Ignore app version" = No, upload the new pkg to the same Intune app.
- **Failure visibility:** a pkg postinstall that runs the aitools setup must surface
  failure. Whether a non-zero *pkg* postinstall makes Intune report "failed" is **unknown**
  (the page covers only its own pre/post fields). Safer design: install the stub app LAST,
  only when setup succeeded? Not possible: the payload drops before postinstall. Option:
  postinstall deletes the stub app on fatal failure, so the detection fails and Intune
  retries. That is my design, not documented behaviour; test it on a VM.
- **Uninstall:** ship an uninstall script in the payload; Intune cannot run it (no
  Uninstall assignment), so it is run via an Intune shell script or manually.

## 4. Jamf Pro

Sources (cd, Jamf Pro Documentation 11.33.0, lastEdition Oct 23, 2026):
- Execution frequency (https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Execution_Frequency_for_Policies):
  - "Once per computer—This policy runs on any computer in the current scope one time only.
    If the Automatically re-run policy on failure checkbox is enabled, you can configure the
    policy to retry up to 10 times after a policy fails. If a log entry exists for a given
    computer in the policy's history, the policy will not run again for that computer until
    the log is flushed."
  - "Once per user per computer—This policy runs once per distinct username per distinct
    computer."
  - "Once every day / week / month" (no policy log in 24 h / 168 h / 720 h).
  - "Ongoing—This policy runs each time the specified trigger takes place." "When using an
    ongoing execution frequency with a recurring check-in trigger, policies will run during
    every check-in."
  - Triggers: "Startup", "Login—When a user logs in to a computer. Login hooks must be
    enabled in the Check-In section of Computer Management Settings.", "Network State
    Change", "Enrollment Complete—Immediately after a computer completes the enrollment
    process", "Recurring Check-In", "Custom—Initiate the policy manually using the jamf
    policy -event binary command."
  - "If multiple policies are triggered at the same time, the policies will run based on
    their name in alphanumeric order."
- Policy management (…/Policy_Management): "Policies are typically run by the jamf binary";
  `sudo jamf policy -id 15`; "Jamf Pro truncates the output of policy logs after they reach
  25 KB in size. If your environment relies on scripts with detailed error messaging, you
  may want to modify them to minimize the outputs". Self Service: "Click the Self Service
  tab and make the policy available in Self Service."
- Package management (…/Package_Management): direct upload needs a cloud principal DP; "A
  checksum is calculated after the package has been uploaded"; "Allow Package to be
  Uninstalled ... You must have pre-existing index information before you can uninstall
  the package."; FUT/FEU "applies to DMGs only" (so a pkg cannot use Jamf's
  user-template fill: user files must come from the postinstall).
- Inventory (…/Computer_Inventory_Collection_Settings): "Package receipts" is an
  optional additional inventory item; default application search path is "/Applications/"
  ("you can use the Computer Inventory Collection settings to specify custom search paths").
- Extension attributes (…/Computer_Extension_Attributes): "You can run a script that returns
  a data value each time a computer submits inventory"; "the text between the
  <result></result> tag is stored"; "Extension attributes can be used as criteria in a smart
  group".
- Unsigned pkgs via the jamf binary: the Jamf docs read state no signing requirement for
  policy installs (signing only for PreStage, Jamf notes L47). Whether Jamf or macOS blocks
  an unsigned pkg installed by the jamf binary: **unknown** (not documented on the pages
  read; widely done in practice, unverified).
- Whether a non-zero pkg postinstall marks the Jamf policy "Failed": **unknown** (not stated).

Detection options for Jamf, best first:
1. Extension attribute script: `<result>` = contents of
   `/Library/Application Support/aitools/VERSION` (or `pkgutil --pkg-info tech.nobul.aitools`
   version). Smart Group "aitools version is not X" scopes an Ongoing/recurring policy.
2. Package receipts inventory (`pkgutil --pkgs`) plus a Smart Group on the receipt
   (criteria name not read: unknown).
3. Application inventory of the stub .app (needs a custom search path if the app is not in
   /Applications).

## 5. Gatekeeper and quarantine

- Apple Platform Security, "Gatekeeper and runtime protection in macOS"
  (https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web,
  cd, published December 19, 2024): "When a user downloads and opens an app, a plug-in, or
  an installer package from outside the App Store, Gatekeeper verifies that the software is
  from an identified developer, is notarized by Apple ... and hasn't been altered." Also:
  "all software in macOS is checked for known malicious content the first time it's opened,
  regardless of how it arrived on the Mac." "users can override Gatekeeper policies to open
  any software unless restricted by a device management service."
- Apple DTS forum answers (ws only; the forum showed a bot check in chrome-devtools):
  "In most cases Gatekeeper only runs if the item is quarantined"; "Unix-y networking tools,
  like curl and scp, don't quarantine the files they download"; "If you use an installer
  package to install the tool, it's no longer quarantined"; and "All the code you ship
  should be covered by a notarisation ticket." (https://developer.apple.com/forums/thread/128915
  and related threads, ws).
- What the docs do not say: whether an unsigned pkg that the Intune agent or the jamf binary
  passes to `installer` as root is checked by Gatekeeper. **Unknown.** `man installer`
  offers `-allowUntrusted` only for "a package signed by an untrusted (or expired)
  certificate", not for unsigned ones (man). Practical reading (inference): agents download
  with their own HTTP clients, which (like curl) do not set quarantine, so Gatekeeper's
  download check does not apply; double-clicking the same pkg from a browser download would
  be blocked. Verify on a VM before the fleet rollout.
- Payload binaries: the aitools payload is scripts (bash, PowerShell, Perl, JSON, md). A
  stub app with a shell-script executable contains no Mach-O, so it never needs signing to
  exist on disk; it is never launched. Any Mach-O added to the payload later would need at
  least an ad-hoc signature to run on Apple Silicon (general platform rule, not read today:
  unverified).
- LaunchAgent side effect: since macOS 13, launch agents show a "Login Items" / background
  item notification. Apple: "An organization has the ability to configure specified items
  using a new configuration payload"; rules can match "Service Label: The value of the
  launchd .plist Label parameter" or "Service LabelPrefix"; "When an item matches a rule,
  the item is automatically approved." (Manage login items and background tasks on Mac,
  https://support.apple.com/guide/deployment/manage-login-items-background-tasks-mac-depdca572563/web,
  cd, published December 17, 2025). So the fleet needs a Managed Login Items profile with
  `LabelPrefix tech.nobul.aitools` (both Intune and Jamf deliver configuration profiles;
  payload key names not read: unknown).

## 7. Recommended pkg design for aitools (proposal)

Identifiers: pkg `tech.nobul.aitools` (the `nobul.tech` domain reversed; commander to
confirm). Stub app bundle id `tech.nobul.aitools` too (Intune reports on it; one id is
simpler) or `tech.nobul.aitools.marker` if a separate id is wanted. Version: one value
`X.Y.Z` (aitools release) used for `pkgbuild --version`, `productbuild --version`, stub
`CFBundleShortVersionString`/`CFBundleVersion`, and the VERSION file.

Payload (`--install-location /`, ownership root:wheel):
```
/Library/Application Support/aitools/
  VERSION                       # "X.Y.Z" + build commit; read by Jamf EA and logs
  aitools.app/                  # stub for Intune detection (LSUIElement, sh executable)
  repo/                         # aitools tree at the release tag (scripts/, shared/, ...)
  bin/aitools-pkg-run.sh        # the user-context runner (bash 3.2)
  bin/aitools-uninstall.sh
/Library/LaunchAgents/tech.nobul.aitools.firstrun.plist   # RunAtLoad, runs the runner at login
```
Do not ship the personalized dotprofile `deploy/` (a fleet package is per-fleet, not
per-user; Critic O5). Per-user personal content comes from the user's own dotprofile at
run time, or not at all.

postinstall (root, short, bash 3.2, `set -euo pipefail`, under 15360 chars only matters
for the Intune *field*; the pkg's own script has no stated limit):
1. `mkdir -p /Library/Logs/aitools`; log every line with a UTC `...Z` timestamp to
   `/Library/Logs/aitools/install.log`; print only a short summary to stdout (Jamf 25 KB
   truncation; Intune collects the file).
2. Machine-scope prerequisites as root, each skipped if present: Command Line Tools (git;
   CLT pkg from Apple, a separate MDM package per Homebrew docs), Homebrew `.pkg` (Apple
   Silicon only) with `/var/tmp/.homebrew_pkg_user.plist` set to the console user if one
   exists. Intel Macs: Homebrew pkg unsupported, so a separate path or "unsupported".
   These are better as separate MDM packages with their own detection; the aitools
   postinstall then only checks and logs ERROR if missing.
3. Resolve the console user: `user=$(stat -f %Su /dev/console)`; treat empty, `root`,
   `loginwindow`, `_mbsetupuser` as none. `uid=$(id -u "$user")`.
4. If a user is present: `launchctl asuser "$uid" sudo -u "$user" -H
   "/Library/Application Support/aitools/bin/aitools-pkg-run.sh"` run detached (so the 600 s
   installer timeout does not kill a long setup), its own log in
   `/Users/<user>/.aitools/logs/pkg-run.log` plus a line in `/Library/Logs/aitools/install.log`.
5. If no user: do nothing more. The LaunchAgent in `/Library/LaunchAgents` ("Per-user agents
   provided by the administrator", man launchd) runs the runner at each user's next login.
   The runner compares `~/.aitools/pkg-version` with `VERSION` and exits at once when equal,
   so the agent is cheap on every later login and also covers additional users on the Mac.
6. Exit 0 for "setup deferred" or "setup started". Exit non-zero only for a broken payload
   (VERSION or repo missing), so a corrupt download is retried. Whether that fails the MDM
   install: unknown on both MDMs.

aitools-pkg-run.sh (user context): sets `AITOOLS_FORCE=1` (non-interactive; overwrite
semantics, Critic O5 and interactive-menus.md), runs the dev path from
`/Library/Application Support/aitools/repo` (aitools-install with gh-auth skipped), writes
`~/.aitools/pkg-version` on success. brew calls run as this user (Homebrew docs).

Detection and updates:
- Intune: Included apps = `tech.nobul.aitools` at X.Y.Z, Ignore app version = No; new
  build = new pkg upload to the same app. Note: Intune reports success when the stub is
  present, not when the per-user setup finished (the setup runs later). Per-user status
  needs a separate signal (an Intune custom attribute shell script that reads
  `~/.aitools/pkg-version` for the console user: design idea, not researched).
- Jamf: extension attribute on `/Library/Application Support/aitools/VERSION` (machine)
  and one on the console user's `~/.aitools/pkg-version` (user setup); Smart Group on
  "not current" scoping a policy with frequency Ongoing at Recurring Check-in (or Once per
  computer per version, a new policy per release).
- Receipt: `pkgutil --pkg-info tech.nobul.aitools` gives the installed version on both.

Build gates (CI, macOS host): `pkgutil --payload-files <pkg> | grep -c '/\._'` must be 0
(INCIDENT 1); `pkgutil --expand` and check PackageInfo `version`, `identifier`; stub
Info.plist version equals pkg version (`plutil -extract CFBundleShortVersionString raw`);
`bash -n` every script; `pkgutil --check-signature` exit 1 is expected while unsigned.

## INCIDENT markers (not filed)

- INCIDENT 1 (medium): pkgbuild on this Mac (agent session) archives AppleDouble `._*`
  entries for every payload and script file because each file carries
  `com.apple.provenance`; `xattr -cr`, `COPYFILE_DISABLE=1` and `--filter '/\._'` do not
  remove them (build-test-pkg2/3 logs). Install-time effect unknown. A build-package
  plan must build from a clean checkout on a host where payload files have no xattrs (CI
  runner), or copy the payload with a tool that drops xattrs (`ditto --norsrc --noextattr`:
  **not tested**), and gate on `pkgutil --payload-files | grep '/\._'`.
- INCIDENT 2 (medium, governance ambiguity): the meaning of `$3` differs between Jamf
  script objects (username) and pkg scripts (target volume). No aitools spec covers MDM
  argument conventions; a runner reused across both channels could treat `/` as a username.
- INCIDENT 3 (low): Apple's only page found for installer-script arguments and environment
  variables is a retired 2010 document; current behaviour on macOS 27 is assumed, not
  documented.

## Open questions (with suggested answers)

1. Identifier: `tech.nobul.aitools`? Suggested: yes, and the same id for the stub app.
2. Ship the aitools repo tree in the pkg, or a bootstrap that downloads a release asset?
   Suggested: ship the tree (offline-safe; Intune macOS "Connection through a proxy is not
   supported" for scripts, Intune notes L74) and keep personal content out of the pkg.
3. Prerequisites (CLT, Homebrew pkg, node, pwsh) inside the aitools postinstall or as
   separate MDM packages? Suggested: separate packages with their own detection; the
   aitools postinstall checks and reports ERROR when they are missing.
4. Delete the stub app on fatal setup failure to force Intune retries? Suggested: no for
   v1; report per-user status through a custom attribute / extension attribute instead,
   because the per-user setup runs after the install finishes.
5. Intel Macs: Homebrew pkg is Apple Silicon only. Suggested: declare Intel unsupported for
   the package path in v1 (pkg `hostArchitectures` stays `x86_64,arm64` but the runner logs
   ERROR on Intel without Homebrew), or require Homebrew pre-installed.

## Not done / unknowns

- No install of any pkg (forbidden); every install-time behaviour above is unverified:
  postinstall `$1..$4` values on macOS 27, `._` handling, Gatekeeper on agent installs,
  non-zero postinstall effect on Intune/Jamf status, Intune detection outside /Applications,
  console user at the login window. All need a disposable macOS VM.
- Jamf Composer and Self Service pages not read beyond the Policy Management Self Service
  step (pkgbuild covers Composer's role).
- Jamf Smart Group criteria names for package receipts: not read.
- Rules/reference: read the packet, brief, MDM-PKG notes, every rule in context (all
  `.claude/rules/*.md` were attached or read), `reference/cross-platform-detail.md`. Not
  read: `reference/tool-evaluation-criteria.md`, `reference/tool-evaluation-playbook.md`
  (no tool was recommended for install; the Linux build tools are listed as unverified only).

## WRITE_BLOCKED

None.

## Sources

- man pages on this Mac: pkgbuild(1), productbuild(1), pkgutil(1), installer(8),
  launchctl(1), launchd(8), sudo(8), scutil(8) (saved in scratch).
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos (cd)
- https://learn.microsoft.com/en-us/intune/app-management/deployment/management-agent-macos (cd)
- https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos (cd)
- https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Execution_Frequency_for_Policies (cd)
- https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Policy_Management (cd)
- https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Packages (cd)
- https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Package_Management (cd)
- https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Computer_Inventory_Collection_Settings (cd)
- https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Computer_Extension_Attributes (cd)
- https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/SoftwareDistribution4/Install_Operations/Install_Operations.html (cd, retired)
- https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web (cd)
- https://support.apple.com/guide/deployment/manage-login-items-background-tasks-mac-depdca572563/web (cd)
- https://docs.brew.sh/Installation , https://docs.brew.sh/FAQ , https://docs.brew.sh/Homebrew-for-Mac-Admins (cd)
- https://developer.apple.com/forums/thread/128915 and related DTS threads (ws only)
- https://github.com/peetinc/ape-pkg , https://github.com/otaran/bomutils , https://github.com/jindrapetrik/jbomutils (ws only, unverified)
