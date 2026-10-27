# S3-BuildPkg-PkgLinux notes: Linux packaging research

Author: S3-BuildPkg-PkgLinux (level 2 under S3-BuildPkg). Date: 2026-10-26.
Every web fact below was read on 2026-10-26 with chrome-devtools (real
browser; page text extracted with `evaluate_script`). No WebFetch, no
Firecrawl. Quotes are verbatim.

## Summary (5 lines)

1. Format: ONE `.deb`, `Architecture: all`, built with `dpkg-deb` (or nFPM) on an `ubuntu-24.04` CI runner; a tarball is the fallback for non-apt hosts only.
2. One package serves 22.04 and 24.04: the payload is scripts; Depends only on base packages present in both (bash, perl, python3, git, curl, ca-certificates) with no version floors. PowerShell must NOT be a Depends (not in Ubuntu's archive).
3. postinst does root-level work only (files under /opt/aitools, a /usr/bin/aitools-setup symlink); per-user work runs from `aitools-setup` as the target user (or root in a container). Detection = `dpkg-query -W aitools`.
4. Claude Code web: Ubuntu 24.04 x86_64 VM, setup script runs as root before Claude Code, apt works, snapshot cache ~7 days, signal `CLAUDE_CODE_REMOTE=true` (sessions/hooks; not set in setup scripts). Cursor cloud: Ubuntu VM, install script per Build, user very likely `ubuntu` with passwordless sudo; no documented general env-var signal (unknown) — closest documented signals are the metadata socket `/run/cursor/api.sock` (`agent/runtime` = `managed`) and the hook-only `CURSOR_CODE_REMOTE`.
5. Neither cloud carries `~/.claude` or `~/.cursor` from the user's machine; the package must be installed by the environment's setup/install script every cache rebuild, and the per-user step must be non-interactive.

## 1. Format choice

Payload: bash, pwsh and perl scripts plus markdown, JSON and hooks. No
compiled code.

| Option | Fit | Evidence |
|---|---|---|
| `.deb`, `Architecture: all` | Best. Architecture-independent by definition; apt resolves Depends; dpkg tracks files (clean remove/upgrade); `dpkg-query` gives detection; offline-installable file | deb-control(5): "Note that the all value is meant for packages that are architecture independent. Some examples of this are shell and Perl scripts, and documentation." (https://manpages.ubuntu.com/manpages/noble/man5/deb-control.5.html) |
| tarball + install script | Works anywhere, but no dependency resolution, no file tracking, detection is ad hoc | (design judgement) |
| snap | Not recommended: Claude Code web and Cursor cloud are containers/VMs where snapd needs systemd; strict confinement blocks writing `~/.claude` | unknown/unverified for both clouds; not researched further |
| PPA / own apt repo | Later. Needs a signed repo and hosting; first release can be a GitHub release asset | (design judgement; signing deferred by commander decision) |

Dependencies resolve only when the archive has them. deb-control(5): "The
package maintenance software will not allow a package to be installed if the
packages listed in its Depends field aren't installed (at least not without
using the force options)."

Installing a local file: Microsoft's own PowerShell manual install uses
`sudo dpkg -i <file>.deb` then `sudo apt-get install -f` ("Resolve missing
dependencies and finish the install (if necessary)")
(https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu).
`apt-get install ./file.deb` (one step, resolves Depends) is widely used, but
the noble apt(8)/apt-get(8) man pages do not document it; apt-get(8) says
"Each package is a package name, not a fully qualified filename"
(https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html). Treat
`apt-get install -y ./aitools_<v>_all.deb` as unverified from docs; verify it
in CI on 22.04 and 24.04 and keep `dpkg -i` + `apt-get install -f -y` as the
documented fallback.

**Recommendation:** `.deb`, `Architecture: all`, published as a GitHub release
asset (aitools is a public repo, so no auth is needed to download it).

## 2. One package for 22.04 and 24.04?

Versions from the Launchpad API (official Ubuntu archive;
`https://api.launchpad.net/1.0/ubuntu/+archive/primary?ws.op=getPublishedSources&source_name=<src>&exact_match=true&status=Published&distro_series=.../<series>`).
packages.ubuntu.com returned HTTP 500 for every query on 2026-10-26, so it
was not used. Highest non-proposed pocket shown:

| Package (source) | jammy 22.04 | noble 24.04 |
|---|---|---|
| bash | 5.1-6ubuntu1.1 | 5.2.21-2ubuntu4 |
| perl | 5.34.0-3ubuntu1.9 | 5.38.2-3.2ubuntu0.6 |
| python3 (python3-defaults) | 3.10.6-1~22.04.1 | 3.12.3-0ubuntu2.1 |
| git | 1:2.34.1-1ubuntu1.18 | 1:2.43.0-1ubuntu7.4 |
| curl | 7.81.0-1ubuntu1.30 | 8.5.0-2ubuntu10.16 |
| jq | 1.6-2.1ubuntu3.2 | 1.7.1-3ubuntu0.24.04.2 |
| coreutils | 8.32-4.1ubuntu1.4 | 9.4-3ubuntu6.3 |
| sudo | 1.9.9-1ubuntu2.7 | 1.9.15p5-3ubuntu5.24.04.4 |
| nodejs | 12.22.9~dfsg-1ubuntu3.6 | 18.19.1+dfsg-6ubuntu5 |
| powershell | NOT PUBLISHED | NOT PUBLISHED |

What matters:
- bash >= 5.1, perl >= 5.34, python3 >= 3.10, git >= 2.34 on both. The repo
  targets bash 3.2 (packet section 5), so no bash floor is needed.
- git: Claude Code's local-bundle upload needs "git 2.31 or later"
  (https://code.claude.com/docs/en/claude-code-on-the-web); jammy's 2.34 and
  noble's 2.43 both pass.
- **PowerShell is in neither archive.** Microsoft: "Ubuntu comes preconfigured
  with a package repository that includes .NET packages, but not PowerShell."
  Microsoft's repo path is per release (`packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb`),
  but the GitHub release is a "universal .deb package" usable on both
  (https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu).
  Supported: 24.04 until 2029-05-31, 22.04 until 2027-06-01 (same page).
- **Ubuntu nodejs is far too old** (12 on jammy, 18 on noble). Node must come
  from the tool's own setup script (the `/tool-eval` path, issue #14), not
  from Depends. Claude Code web already ships Node 20/21/22 at `/opt/node2x`
  (cloud-environments page).

**Conclusion:** one `aitools_<v>_all.deb` for both releases. Depends lists only
packages present in both archives with no version floor:
`Depends: bash, perl, python3, git, curl, ca-certificates`;
`Recommends: jq, sudo`. PowerShell, node, gh and the other managed tools are
installed by `aitools-setup` through the existing setup scripts, not by apt
Depends (a Depends on `powershell` makes the install fail on a host without
the Microsoft repo). Per-release builds buy nothing for a script payload.

## 3. Build host

Local check on this Mac (2026-10-26): `command -v dpkg-deb docker podman nfpm fpm brew`
printed only `/opt/homebrew/bin/brew` (exit 1): none of dpkg-deb, docker,
podman, nfpm, fpm is installed. Nothing was installed.

| Builder | Verdict | Evidence |
|---|---|---|
| `dpkg-deb` on an Ubuntu CI runner | **Recommended.** Part of dpkg, the canonical tool, present on every Ubuntu image, no third-party dependency | GitHub runner images README: `ubuntu-latest` or `ubuntu-24.04` (x64), `ubuntu-22.04` also available (`gh api repos/actions/runner-images/readme`, 2026-10-26) |
| `dpkg-deb` on macOS via Homebrew | Possible (homebrew/core `dpkg` 1.23.11, GPL-2.0-or-later, source deb.debian.org). Caveat: "This installation of dpkg is not configured to install software" (build only). Not recommended as the release host: file ownership/modes must be root:root, which is easier on Linux | `brew info --json=v2 dpkg` |
| nFPM | Acceptable alternative (declarative YAML; deb and rpm; `arch: all` supported; scripts postinstall/preremove; depends/recommends). goreleaser org, MIT, 2,677 stars, pushed 2026-10-26, latest v2.48.0 (2026-10-12), homebrew/core formula. Passes hard blocks; no yellow flags found. Useful if rpm (issue #10 dnf) is added later | https://nfpm.goreleaser.com/docs/configuration/ ; `gh api repos/goreleaser/nfpm` |
| fpm | Not recommended: personal account (jordansissel), license NOASSERTION in GitHub metadata, 789 open issues, Ruby dependency. Active (v1.18.0, 2026-08-26). Yellow flags: sole/personal maintainer, license unclear | `gh api repos/jordansissel/fpm` |
| Docker ubuntu container on Mac | Not available locally (no docker/podman) | local check |

**Recommendation:** build in GitHub Actions on `ubuntu-24.04` with `dpkg-deb
--root-owner-group --build`, then install-test the artifact on `ubuntu-22.04`
and `ubuntu-24.04` runners (closes part of issue #19's gap: CI never runs the
installer). nFPM only if rpm becomes a requirement. Per tool-evaluation.md,
adopting nFPM as a build dependency needs a `/tool-eval` record.

## 4. Maintainer scripts

- Run as root by dpkg; must be idempotent: "It is necessary for the error
  recovery procedures that the scripts be idempotent."
  (https://www.debian.org/doc/debian-policy/ch-maintainerscripts.html)
- Must exit non-zero on error: "you almost always need to use set -e" (same).
- Non-interactive: "Maintainer scripts are not guaranteed to run with a
  controlling terminal and may not be able to interact with the user. They
  must be able to fall back to noninteractive behavior if no controlling
  terminal is available." (same, 6.3). So the aitools managed-file review
  menus must never run inside postinst; `DEBIAN_FRONTEND=noninteractive` is a
  debconf convention, not a guarantee for our own prompts.
- Home directories: Policy 10.7.5 "User configuration files (dotfiles)" says
  /etc/skel "should be as empty as we can make it ... there is no easy (or
  necessarily desirable) mechanism for ensuring that the appropriate dotfiles
  are copied into the accounts of existing users when a package is
  installed." (https://www.debian.org/doc/debian-policy/ch-files.html). This
  supports doing per-user work outside postinst.
- `/usr/local` is off limits to package payloads: "packages must not place any
  files in /usr/local, either by putting them in the file system archive to be
  unpacked by dpkg or by manipulating them in their maintainer scripts."
  (https://www.debian.org/doc/debian-policy/ch-opersys.html). Relevant because
  setup-go.sh manages `/usr/local/go` (issue #12): it may do so at
  `aitools-setup` time, never from postinst.
- Finding the target user (for `aitools-setup`, not postinst):
  1. not root (`id -u` != 0): the invoking user.
  2. root with `SUDO_USER` set and not `root`: that user. sudo(8): "SUDO_USER:
     Set to the login name of the user who invoked sudo." "SUDO_UID: Set to
     the user-ID of the user who invoked sudo."
     (https://manpages.ubuntu.com/manpages/noble/man8/sudo.8.html)
  3. root, no SUDO_USER: root IS the user (Claude Code web; `HOME=/root`).
     Do not guess "first UID >= 1000" or `logname` (no login session in a
     container; `logname` fails without a utmp entry — unverified detail).
  An explicit `--user <name>` flag should override all of this.
- systemd: none assumed. postinst must not call `systemctl`. Claude Code web
  documents `service postgresql start` (SysV-style), not systemctl
  (cloud-environments page).

## 5. Cloud environments

### Claude Code web (Anthropic-hosted cloud environment)

Source: https://code.claude.com/docs/en/cloud-environments and
https://code.claude.com/docs/en/claude-code-on-the-web (2026-10-26).

- OS/arch: "each session gets a fresh virtual machine (VM) running Ubuntu 24.04
  on x86_64".
- Getting software in: "To add packages that aren't pre-installed, use a setup
  script." Setup scripts: "A setup script is a Bash script that runs when a new
  cloud session starts, before Claude Code launches." "Scripts run as root on
  Ubuntu 24.04, so apt install and most language package managers work."
  Script box takes text or a file "up to 64 KB".
- Constraints: "Exit zero: if the script exits non-zero, the session fails to
  start." "keep the script's total runtime under roughly five minutes so the
  environment cache can build." "The environment's variables aren't set yet:
  the script runs before the session sets the environment's environment
  variables. Set any value the script needs in the script itself."
- Persistence: "When setup completes within roughly five minutes, Anthropic
  snapshots the filesystem and reuses that snapshot as the starting point for
  later sessions." Rebuilt "when you change the environment's setup script or
  allowed network hosts, and when the cache reaches its expiry after roughly
  seven days." Mid-session installs "don't carry over to other sessions".
- Network (Trusted default) includes `github.com`, `objects.githubusercontent.com`,
  `release-assets.githubusercontent.com`, `packages.microsoft.com`,
  `archive.ubuntu.com`, `security.ubuntu.com`, `ppa.launchpad.net`,
  `registry.npmjs.org`, `pypi.org` (expanded "Default allowed domains" lists).
  Caveat: "A source archive you fetch over a github.com/{owner}/{repo}/archive/
  or codeload.github.com URL gets that same 403 when the repository isn't
  attached, even a public one." Whether a `releases/download/` URL of a
  non-attached repo is also refused is **unknown**; test it before relying on
  a GitHub release asset as the download path (fallback: commit the .deb or
  fetch from the attached repo).
- Home/user: setup scripts run as root; the doc's own example confirms
  `/root/.claude/CLAUDE.md`. User-level `~/.claude/...` from the user's
  machine does not carry over: "Your user ~/.claude/CLAUDE.md — No — Lives on
  your machine, not in the repo." User-level SessionStart hooks: "don't
  expect them in the cloud."
- Signal: "the session VM's environment carries that variable
  [`CLAUDE_CODE_REMOTE`] as true, it's never true locally". Also
  `CLAUDE_CODE_REMOTE_SESSION_ID` exists. Not documented as set during the
  setup script (consistent with reference/cross-platform-detail.md: the setup
  script must set `AITOOLS_ENVIRONMENT=claude-code-web` itself).
- Pre-installed: Python 3 + uv, Node 20/21/22 (22 on PATH), Go, Rust, docker,
  git, gh, jq, yq, ripgrep (Installed tools table). PowerShell, typst, pandoc:
  not listed (install via setup script).
- gh: `GH_TOKEN` reads as the placeholder `proxy-injected`; "The proxy rejects
  subcommands that use GraphQL, such as gh pr and gh issue." Relevant to any
  setup-gh-cli auth check (it would report a false "not authenticated" or
  fail on GraphQL).
- Resources: 4 vCPU, 16 GB RAM, 30 GB disk.

### Cursor cloud agents (formerly Background Agents)

Sources: https://cursor.com/docs/cloud-agent , https://cursor.com/docs/cloud-agent/setup ,
https://cursor.com/docs/cloud-agent/metadata , https://cursor.com/docs/hooks ,
https://cursor.com/docs/cloud-agent/security-network (2026-10-26).

- OS: "Cloud agents run on isolated Ubuntu machines." Ubuntu release of the
  default image: **unknown** (not stated). The recommended Docker Dockerfile
  pins `docker-ce=5:28.5.2-1~ubuntu.24.04~noble`, which suggests a noble base,
  but that is inference.
- Getting software in: agent-led setup, a saved snapshot, or a Dockerfile in
  `.cursor/environment.json`. "Both options let you specify an install
  script. Cursor runs it while creating a Build". Example:
  `{"build": {"dockerfile": "Dockerfile", "context": ".."}, "install": "pnpm install && ./custom_script.sh"}`.
  "The install script must be idempotent. It runs for every Build and may run
  on previously prepared disk state." "The install command runs from your
  project root."
- Persistence: "A successful Build captures the resulting disk state and
  becomes active. New agents start from the active Build." "Builds preserve
  disk state only." Snapshots "stored for a maximum of 30 days of inactivity".
- User/root: **unknown for the default image.** Evidence it is a non-root user
  with sudo: startup example "add sudo service docker start in start", and the
  recommended Dockerfile creates user `ubuntu` with
  `ubuntu ALL=(ALL) NOPASSWD:ALL`. So `aitools-setup` must handle "non-root
  user with passwordless sudo" (VM-like), not only root.
- Network: "The agent has internet access by default"; admins can restrict to
  "Default + allowlist" or "Allowlist only".
- Home: "User-level hooks from ~/.cursor/hooks.json are also not available
  since cloud VMs don't have access to your local home directory." Project
  `.cursor/hooks.json` runs; `sessionStart`/`sessionEnd` hooks do NOT run in
  cloud agents.
- Signal (env var): **no documented general env var for "running in Cursor
  cloud" was found.** Documented candidates:
  1. Metadata socket, readable by install scripts and hooks: "The agent reads
     keys over the Unix socket at CURSOR_AGENT_SOCKET. On Cursor-managed VMs
     the default is /run/cursor/api.sock." Key `agent/runtime`: "managed on
     Cursor-managed Cloud Agent VMs." Page is marked "Preview ... subject to
     change, including breaking changes". Whether `CURSOR_AGENT_SOCKET` is
     actually exported in the environment is unknown (the docs always write
     `${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}`).
  2. Hook env var: "CURSOR_CODE_REMOTE — Set to the string "true" when running
     in a remote workspace — For remote workspaces" (hooks page). Hook-only,
     and "remote workspace" may also cover SSH/dev-container remotes; not
     documented as set in install scripts.
  Proposed: new environment value `cursor-cloud`, resolved when the socket
  `${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}` exists (file test, no curl
  needed) on Linux, overridable by `AITOOLS_ENVIRONMENT`; the environment.json
  install script sets `AITOOLS_ENVIRONMENT=cursor-cloud` explicitly (same
  pattern as the Claude Code web setup script). Needs a commander decision
  (closed value list, reference/cross-platform-detail.md "API").

## 6. Container vs VM differences the package must handle

| Concern | Claude Code web | Cursor cloud | Ubuntu VM / desktop |
|---|---|---|---|
| Installer identity | root (setup script) | unknown; likely `ubuntu` + NOPASSWD sudo | admin via sudo |
| Target user | root, `HOME=/root` | likely `ubuntu` | `SUDO_USER` / invoking user |
| sudo | not needed (root); presence unknown | present (inferred) | present |
| systemd | not assumed (`service` used in docs) | not assumed (`sudo service docker start`) | usually present; do not depend on it |
| FS persistence | snapshot of setup-script output, ~7 day expiry | Build disk snapshot, 30-day inactivity | persistent |
| Interactive TTY | none (setup script) | none (install script) | maybe |
| Network | Trusted allowlist (packages.microsoft.com, GitHub included) | open by default | open |
| GUI | none → Cursor IDE, chrome-devtools headed mode n/a (D-CHR2 headless args already exist) | has a remote desktop ("Remote desktop control"), but the Cursor IDE install is n/a | yes |
| User-level `~/.claude`, `~/.cursor` from the user | not carried over | not carried over | the real target |
| Homebrew | refuses root (issue #10) | n/a | optional fallback |

Implications: every per-user step must be non-interactive under
`AITOOLS_FORCE` semantics (interactive-menus.md non-interactive fallback);
GUI tools (Cursor IDE) report `write_environment_skip` rows; nothing can rely
on systemd; dotprofile clone needs credentials the clouds may not have
(Claude Code web GitHub proxy covers attached repos only — dotprofile
reachability is **unknown**).

## 7. Recommended Linux package design

- **Name**: `aitools`; file `aitools_<version>_all.deb` (version must start
  with a digit; no `v` prefix — nFPM config page states the same for deb).
- **Prefix**: `/opt/aitools/` (FHS add-on package location; not
  `/usr/local`, which Policy forbids). Alternative `/usr/share/aitools` is
  equally valid for arch-independent data; `/opt` keeps the tree
  self-contained and mirrors the macOS PKG layout. Payload: `scripts/`,
  `shared/`, `registries/`, `reference/` subset, `VERSION`.
- **Entry point**: `/usr/bin/aitools-setup` (symlink or 5-line wrapper into
  `/opt/aitools/scripts/`). Runs as the target user, or as root in a
  container. Flags: `--user <name>`, `--force` (non-interactive),
  `--environment <value>`.
- **postinst** (`configure`): `set -e`; validate payload; create the symlink;
  write `/opt/aitools/VERSION`; NO per-user writes, NO network, NO prompts,
  NO systemctl. Idempotent. Optionally print one line: "run aitools-setup".
- **prerm/postrm**: remove the symlink; never touch home directories.
- **Control**:
  ```
  Package: aitools
  Version: <x.y.z>
  Architecture: all
  Maintainer: nobul-tech <jose@nobul.tech>
  Depends: bash, perl, python3, git, curl, ca-certificates
  Recommends: jq, sudo
  Description: aitools harness (Claude Code / Cursor configuration and tools)
  ```
- **Detection**: `dpkg-query -W -f='${Status} ${Version}\n' aitools`
  (installed + version), `test -x /usr/bin/aitools-setup`.
- **Cloud hooks**:
  - Claude Code web setup script (root, before Claude Code):
    download the .deb (URL reachability under Trusted: see section 5
    unknown), `apt-get update`, `apt-get install -y ./aitools_<v>_all.deb`
    (fallback `dpkg -i` + `apt-get install -f -y`),
    `AITOOLS_ENVIRONMENT=claude-code-web aitools-setup --force`, `exit 0`
    discipline per doc ("Append || true to non-critical commands") — note
    this collides with USO "no silent failures"; the script must log the
    failure before continuing.
  - Cursor `.cursor/environment.json` `install`: same, with `sudo` and
    `AITOOLS_ENVIRONMENT=cursor-cloud`; idempotent per Build.
- **Build**: CI job on `ubuntu-24.04`: stage tree, `dpkg-deb --root-owner-group --build`,
  `lintian` (optional), install-test matrix `ubuntu-22.04` + `ubuntu-24.04`
  (plus a root `ubuntu:24.04` container job to model Claude Code web),
  run `aitools-setup --force` twice, assert exit 0 and zero `[error]` lines
  (matches issue #19 acceptance).

## Repo facts used

- Environment block: `scripts/aitools-lib.sh` lines 34-53 (BEGIN/END markers);
  values `claude-code-web|local`; `CLAUDE_CODE_REMOTE=true` → claude-code-web;
  non-Linux forced to `local`.
- Issues: #10 (Linux epic; Claude Code web Ubuntu 24.04 root run corrupted
  config.json and deleted Go), #14 (brew-only setup scripts have no Linux
  path), #19 (Linux CI never runs the installer).

## INCIDENT markers (not filed)

- INCIDENT: `reference/tool-ops-claude-code.md` "Session Behavior" and
  item #27 say nothing about cloud setup scripts, snapshot caching, the GitHub
  proxy GraphQL refusal (`gh pr`/`gh issue` 403) or `GH_TOKEN=proxy-injected`;
  any setup-gh-cli auth check in Claude Code web will misreport. Spec gap
  (ambiguity), medium.
- INCIDENT: the environment value list is closed (`reference/cross-platform-detail.md`
  "API") while Cursor cloud is a commander-supported environment; no value or
  signal exists. Governance ambiguity, medium.
- INCIDENT: Claude Code web setup scripts must exit 0 ("Append || true to
  non-critical commands") which conflicts with USO "No silent failures"
  unless each `|| true` is preceded by a logged check; no rule covers
  cloud-setup scripts. Ambiguity, low.

## Open questions (with suggested answers)

1. Cursor cloud environment value and signal? Suggest `cursor-cloud`,
   signal = metadata socket exists on Linux, plus explicit
   `AITOOLS_ENVIRONMENT` in the install script.
2. Download path for the .deb in Claude Code web (release asset of a
   non-attached repo may 403)? Suggest a one-session test; fallback: the user's
   repo commits a pinned copy, or the setup script clones aitools (public) via
   git (`github.com` is proxied for attached repos only — also needs testing).
3. Does Cursor's default image run as root or `ubuntu`? Suggest
   `aitools-setup` supports both, tested with a `ubuntu` + NOPASSWD sudo
   container job.
4. `/opt/aitools` vs `/usr/share/aitools`? Suggest `/opt/aitools` for parity
   with the macOS PKG.
5. Dotprofile access in clouds (private repo, no user credentials)? Unknown;
   suggest `aitools-setup` runs with shared/ defaults when the dotprofile is
   unreachable and reports WARN, not ERROR.

## WRITE_BLOCKED

none
