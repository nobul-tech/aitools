# S3-MdmPkg-Jamf notes: Jamf Pro (plus Iru/Kandji and Workspace ONE) script and package delivery

**Author**: S3-MdmPkg-Jamf (delegate of S3-MdmPkg, Session Commander 10cf255a-c)
**Read date**: 2026-10-26 for every source below.
**Read methods**: `cd` = chrome-devtools (a11y snapshot or `innerText` in a real browser);
`ws` = WebSearch result summary only (lower confidence); `gh` = GitHub API.
Snapshots are saved in `/Users/new-jose/repos/aitools/.claude/worktrees/mdmpkg/.scratch/session-mdmpkg/jamf/`.
Jamf Pro docs version read: **11.33.0** (shown in each page's header).

## Bottom line

1. **Jamf Pro documents no size limit for a script object.** Neither the admin docs nor the
   API reference states one (`scriptContents` is a plain `string`, no maxLength). The size
   limit is **unknown**. Community evidence: 80 KB scripts work; a ~10,000-line script
   (super, current `main` is 860,318 bytes) failed to save through the web UI with a 403
   (cause not resolved in the thread). A 607,000-line script was pushed toward a .pkg by
   Jamf Heroes. **Our ~450 KB deploy scripts sit in the untested zone. Do not rely on
   pasting them into a Jamf script object.**
2. **Packages have no documented size limit at the sizes we need.** The only official
   number is a CloudFront 30 GB download caveat. The community reports a 5 GB cap through
   the Jamf Sync path to JCDS. Our deploy/ fits easily in a .pkg.
3. **Jamf scripts and packages run as root**, so a script that writes `~/.claude` must
   resolve the console user. Jamf passes the logged-in user as `$3` (per a Jamf white paper
   and the community, read via ws), and it can be empty when nobody is logged in.
4. **Recommended shape for Jamf**: either (a) a **signed flat .pkg** of deploy/ with a
   postinstall that runs the setup scripts for the console user, or (b) a **small bootstrap
   script** (well under 80 KB) in a script object that downloads a release asset or clones
   the dotprofile repo, with parameters 4-11 carrying the URL, version and repo. Both fit
   documented Jamf mechanisms. Neither depends on the unknown script size limit.

## Limits table (Jamf Pro)

| Mechanism | Limit (verbatim or "unknown") | Execution context | Can fetch remote content | Source (read 2026-10-26) | Method |
|---|---|---|---|---|---|
| Script object (Settings > Computer management > Scripts; Policy "Scripts" payload) | **unknown**. The docs state no limit. API: `scriptContents` `string`, no maxLength | root: "Scripts deployed from Jamf Pro are automatically run as the root user." (Jamf 100 course, Lesson 25) | Yes, it is a shell script (curl/git are whatever macOS provides). The docs say nothing on network fetches | https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Scripts ; https://developer.jamf.com/jamf-pro/reference/post_v1-scripts ; https://learn.jamf.com/bundle/jamf-100-course-current/page/Lesson_25.html | cd |
| Script storage | "To run a script on computers, the script must be stored on the distribution point you plan to deploy it from and in Jamf Pro, or in the Jamf Pro database." | n/a | n/a | Scripts page (above) | cd |
| Policy log output | "Jamf Pro truncates the output of policy logs after they reach 25 KB in size." | n/a | n/a | Scripts page (above) | cd |
| Script parameters | API body fields `parameter4` ... `parameter11` (8 custom). $1 mount point, $2 computer name, $3 username are reserved (from a white paper, not the admin docs) | n/a | n/a | API ref (above), cd. Reserved $1-$3: https://resources.jamf.com/documents/white_papers/apple-scripting-201.pdf (ws only; the PDF would not render, no poppler) | cd / ws |
| Parameter value length | **unknown** officially. Community 2013: truncated at "~280" characters | n/a | n/a | https://community.jamf.com/t5/jamf-pro/displaymessage-sh-message-getting-cut-off-maximum-characters/m-p/81422 | ws |
| Package (PKG or DMG; Policy "Packages" payload: install, cache, install cached) | **No size limit stated** in Packages / Package Management | Installer runs as root (macOS installer; Jamf docs do not state it) | The package is downloaded from a distribution point | https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Packages ; .../Package_Management ; .../Policy_Payload_Reference | cd |
| Package upload | "Direct upload" requires a cloud distribution point as the principal one. Otherwise, a manual copy to the file share plus a package record | n/a | n/a | Package_Management (above) | cd |
| Distribution: cloud DP (JCDS, S3/CloudFront, Akamai, Rackspace) | "Due to the file size download limit set by Amazon CloudFront, files larger than 30 GB may not download successfully." Disallowed filename characters: `/ : ? < > \ * \| " [ ] { } @ ! % ^ #` | n/a | HTTPS (JCDS: "All communication with the JCDS is over SSL using port 443.") | https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Cloud_Distribution_Point ; https://learn.jamf.com/bundle/technical-articles/page/Jamf_Cloud_Distribution_Service_Communication.html | cd |
| JCDS upload size | **unknown** officially. Community: Jamf Sync got `EntityTooLarge ... max allowed size = 5368709120` (5 GiB). A direct upload via Settings > Packages worked for the same >5 GB pkg | n/a | n/a | https://community.jamf.com/general-discussions-2/jamf-sync-large-file-34769 | cd |
| Distribution without an MDM profile | "On computers with macOS 10.15 or later that do not have an MDM profile, you must use an HTTP, HTTPS, or cloud distribution point to install packages." | n/a | n/a | Package_Management (above) | cd |
| Files and Processes payload | **No limit stated.** "This payload also allows you to execute commands." | Not stated in docs (assumed root, like every policy payload: **unverified**) | Yes, any shell command | Policy_Payload_Reference (above) | cd |
| Self Service | A policy with a Scripts or Packages payload can be "made available in Self Service" (Scripts page, policy step "Self Service tab"). The Jamf 100 lesson walks through running a script from Self Service | Same as the policy (root) | Same as the payload | Scripts page; Lesson 25 (above) | cd |
| PreStage (ADE) enrollment packages | "PKGs must be signed using a certificate the device trusts at the time of enrollment." "Packages must be built as flat, distribution style .pkg files and signed by a certificate that is trusted by managed computers." Signing source: Jamf Pro built-in CA or an Apple Developer Program account | Installed "while in Setup Assistant" (before a user exists) | Downloaded from the DP; custom manifest needed for a non-Jamf HTTPS server | https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Installing_Packages_during_Automated_Device_Enrollment ; search snippet of .../Computer_PreStage_Enrollment_Payload_Reference | cd |

## Community evidence on script size (labelled; not official)

- sdagley (Jamf Heroes), about 5 years ago: "I don't know if there's a limit, but I have scripts in
  the 2000 line/80KB range and have never had a problem with them running." On a
  ~607,000-line script with embedded binaries: "I wouldn't want to have a script that large
  in the Jamf Pro database", and he recommended a Composer .pkg with a postinstall instead.
  https://community.jamf.com/general-discussions-2/deploying-or-converting-a-bourne-shell-script-via-jamf-24462 (cd)
- Billy_Baggins, about 2 years ago, pasting Macjutsu `super` (5.0.0-beta2, "close to 10,000 lines"):
  "if I try to copy and paste the whole thing, I get a 403 error". Smaller scripts saved fine.
  A responder's paste worked in Arc. A second super-admin got the same 403. The thread ends
  without a resolution. https://community.jamf.com/general-discussions-2/403-error-when-copying-and-pasting-too-much-script-34225 (cd)
  - Size reference: `super` on current `main` is **860,318 bytes**
    (`gh api repos/Macjutsu/super/contents/super --jq .size`, 2026-10-26). The 5.0.0-beta2
    ref no longer resolves (HTTP 404), so the exact size that failed is **unknown**.
  - Interpretation (mine, unverified): a 403 on save suggests a request-size or WAF rule on the
    Jamf Cloud web tier, not a database column. The API path (`POST /api/v1/scripts`) may
    behave differently. **Untested.**
- No source found for a MySQL column type (MEDIUMTEXT/LONGTEXT) or max_allowed_packet for
  the scripts table (ws, two queries). **Unknown.**

## Other MDMs (brief)

| MDM | Mechanism | Limit | Context | Notes | Source | Method |
|---|---|---|---|---|---|---|
| Iru (formerly Kandji) | Custom Script Library Item (Audit Script + optional Remediation Script) | **None stated** on the page (searched for size, limit, KB, MB, character: no hits) | "Custom scripts are always executed as the root user." "If a shell or interpreter is not specified, the default shell (/bin/sh) is used." | Frequencies: "Install once per device", "Run every 15 min", "Run daily", "Run on-demand from Self Service". Non-zero audit exit leads Iru to run the remediation script | https://docs.iru.com/en/endpoint/library/library-items-profiles/custom-scripts-overview | cd |
| Iru (Kandji) | Custom Apps (pkg upload) | **unknown** (no doc found) | n/a | n/a | ws (no relevant hit) | ws |
| Workspace ONE UEM (Omnissa) | Scripts resource (Resources > Scripts, macOS) | **None stated** (page searched for size/limit/KB/MB: no hits) | Tutorial sets "the Execution Context to System"; its sample loops on `/dev/console` to find the logged-in user | Languages: "Bash, Python 3, and Zsh". Requires Hub 2310+ / UEM 2310+ in that tutorial. Scripts resource is licence-gated ("included in the Workspace ONE Advanced, Enterprise, Desktop Essentials, and UEM Essentials..."). The alternative for unlicensed tenants is "internal apps as payload-free packages". Page changelog last entry 06/13/2025 | https://techzone.omnissa.com/distributing-scripts-macos-workspace-one-operational-tutorial | cd |
| Mosyle | not checked (time) | unknown | unknown | unknown | none | none |

## Notes for the bootstrap pattern

- **The root context is the main design constraint on every MDM checked** (Jamf: Lesson 25;
  Iru: Custom Scripts; WS1: "System"). Under root, `$HOME` and `~` are root's. A bootstrap
  must resolve the console user (`stat -f %Su /dev/console` or `scutil` "State:/Users/ConsoleUser";
  my suggestion, no doc read). On Jamf, `$3` can carry it, but it can be empty with no
  logged-in user (community, ws). The bootstrap should then write as that user (`sudo -u
  <user> -H` or `launchctl asuser`) and fix ownership. **Our setup scripts were never
  designed to run as root against another user's HOME: this is a real gap (see INCIDENT 1).**
- **No user at run time**: PreStage packages install "while in Setup Assistant", before a
  user exists. A user-scoped `~/.claude` install cannot run there. Use a recurring or login
  trigger policy (Jamf) or "Install once per device" with a console-user wait (Iru, WS1
  sample pattern).
- **Small bootstrap script** fits every mechanism and avoids the unknown size limit. Pass the
  release URL, version pin and checksum via Jamf parameters 4-11. Keep output small: Jamf
  truncates policy logs at 25 KB, so the bootstrap should log to `~/.aitools/logs` and
  print only a summary.
- **Fetching remote content**: none of the docs restrict network access from scripts. A
  bootstrap needs `curl` (in macOS) or `git` (Command Line Tools; may be absent on a fresh
  Mac: **unverified, not checked here**). A release-asset download with curl plus a checksum
  is more robust than `git clone` on an unprovisioned endpoint. For a private dotprofile repo,
  the bootstrap needs a credential. Jamf parameters are visible to Jamf admins and in the
  policy config, so the credential must not go there: **open design question**.

## Notes for a signed .pkg of deploy/

- Jamf: a .pkg is the documented, size-safe path. Upload through the UI requires a cloud
  principal DP. A checksum "is calculated after the package has been uploaded", and Jamf
  can use it to validate packages.
- Signing is **required only for PreStage enrollment packages** (flat, distribution-style,
  signed by a certificate the device trusts; Jamf built-in CA or an Apple Developer
  certificate). For ordinary policy installs, the Jamf docs I read state no signing
  requirement (**unverified whether Gatekeeper/notarization blocks unsigned pkgs installed by
  the jamf binary; not checked**).
- A postinstall runs as root (standard macOS installer behaviour; not read from a doc
  today), so it faces the same console-user problem as a script.
- Filename restrictions on a cloud DP: no `/ : ? < > \ * | " [ ] { } @ ! % ^ #`, and no spaces
  if uploading via Safari. Use names like `aitools-deploy-<version>.pkg`.
- WS1: an "internal app" payload-free package is the fallback when the Scripts resource is
  not licensed. The same .pkg serves both Jamf and WS1.

## INCIDENT markers (not filed)

- INCIDENT: The deploy/ setup scripts (`<userRepoPath>/deploy/setup-*.sh`) are positioned as
  the MDM path (`.claude/rules/deploy-paths.md` "Dual Deployment Paths"), but every MDM checked
  runs scripts as root (Jamf, Iru, WS1 System). No rule or reference I read defines how the MDM
  path resolves the target user's HOME or ownership under root. Classification: governance
  ambiguity ("No spec exists for: MDM root execution context and target-user resolution").
  Verify against the scripts before filing; I did not read the deploy scripts (out of scope).
- INCIDENT: The Jamf script size limit is undocumented, and there is a credible community report
  of a 403 on saving a large script. Any plan that pastes the ~450 KB deploy scripts into Jamf
  script objects is at risk. Record "use .pkg or a bootstrap" as the Jamf delivery decision.

## Unknowns (explicit)

- Jamf script object maximum size (UI and API), and the cause of the 403: unknown.
- Jamf parameter value maximum length: unknown officially (community ~280, 2013).
- JCDS maximum upload size via the UI and API: unknown officially.
- Whether the Files and Processes "execute command" runs as root: not stated in the docs read.
- Iru Custom Apps and Mosyle limits: not found or not checked.
- WS1 Scripts size limit and whether a "Current User" context exists for macOS: not stated on
  the page read.

## WRITE_BLOCKED

None.
