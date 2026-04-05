# aidefend — Design Document
#
# [PROVENANCE]
# document: AIDEFEND-DESIGN
# version: 1.2.0
# created: 2026-04-05T14:35Z
# updated: 2026-04-05T17:20Z
# license: MIT — NOBUL (https://nobul.tech)
# basis: AIDEFEND-DESIGN v1.0.0 (75cf0e16), v1.1.0 (53b20abe),
#   nobul-jose/aitools harness-db-schema.sql, cross-platform-detail.md,
#   framework-provenance.md, tool-registry.json (16 managed tools)
#
# [INTENT]
# purpose: Define the full architecture, roadmap, registry schema,
#   threat model, and competitive landscape for aidefend.
# scope: Architecture and design only. NOT source code. NOT deployment.
#   NOT registry data (see registry/ in repo).
# audience: Any agent building or extending aidefend.
#
# [AGENT]
# name: Agent Coffee / Agent Replacement
# session: ff4220d3-9563-4a2e-8fb2-443136c33f8d
# role: Research, architecture, design (informed re-execution)
#
# [SESSION]
# url: https://claude.ai/chat/ff4220d3-9563-4a2e-8fb2-443136c33f8d
# date: 2026-04-05
# commander: Jose Palencia Castro (jose@nobul.tech)

---

## WHAT IS AIDEFEND

aidefend is aitools' supply chain defense tool. It replaces
axios-scan (v1-v4). It is not a scanner — it learns, acts,
surfaces, and defends. Active defense with operational learning.

Decision D-021, session ff4220d3.

## LINEAGE

axios-scan was built March 31, 2026 — the night the axios npm
package was compromised by UNC1069. The Commander saw the attack
and built the first scanner within hours. Datadog flagged it
as "axios." aitools calls the campaign "axios" per Datadog
provenance (D-022).

v1-v4 were Python, focused on the axios npm compromise. v5 is
aidefend — graduation to full supply chain defense.

## THE THREAT LANDSCAPE (as of 2026-04-05)

### Campaign 1: TeamPCP
Method: CI/CD credential cascading
Scope: 1,000+ SaaS environments (Mandiant)
Chain: Trivy (Mar 19) → Checkmarx (Mar 21) → LiteLLM (Mar 24) →
Telnyx (Mar 27) → CanisterWorm npm (46+ packages)
Partners: Vect (ransomware), ShinyHunters (data leak)
Victim: EU Commission — 92GB exfiltrated
CISA KEV deadline: April 8, 2026

### Campaign 2: UNC1069 / Sapphire Sleet
Method: Social engineering of individual maintainers
Scope: axios npm — 100M+ weekly downloads
Attack: Fake company, cloned founder identity, RAT bypassed 2FA

Two different campaigns. Different tradecraft. Potentially cooperating.

## ARCHITECTURE

### Integration with the Harness

aidefend is a managed tool in the aitools harness. It writes to
harness-db when available:

- **intelligence_items table** — sweep findings, threat matches,
  credential exposures. Each item has provenance: source, session,
  timestamp, confidence level.
- **provenance_edges table** — links between findings (this
  credential file → this compromised service → this campaign).
  Enables invalidation propagation: when a new compromise is
  discovered, all related findings are re-evaluated.
- **events table** — sweep runs, registry updates, lockdown actions.
  Ships to Datadog via write path 5 (SOS/heartbeat).

When harness-db is not available (standalone mode, first run),
aidefend outputs JSONL reports and terminal recommendations.
The JSONL can be imported into harness-db later.

### CLI Interface

```
aidefend sweep ~                    # full sweep
aidefend sweep /                    # entire machine
aidefend sweep / --baseline         # establish baseline
aidefend sweep ~ --diff baseline    # compare against baseline
aidefend check npm                  # targeted ecosystem
aidefend check github               # workflow audit
aidefend check pypi                 # pip/site-packages
aidefend check credentials          # credential exposure
aidefend check persistence          # LaunchAgents, daemons, hooks
aidefend check signatures           # code signature verification
aidefend check listeners            # network listener inventory
aidefend check browser              # browser extension audit
aidefend check autoupdate           # auto-update paths
aidefend check vpn                  # VPN client audit
aidefend check mitm                 # CA trust store / MITM detection
aidefend check secrets              # known breach checking
aidefend status                     # current posture summary
aidefend sbom                       # generate machine SBOM
```

### Cross-Platform (D-039)

aidefend supports macOS, Linux, and Windows from day one. Windows
deployment deferred until Commander's Windows machine is trusted.

Cross-platform conventions follow nobul-jose/aitools patterns:
- OS detection before platform-specific checks
- Absolute paths, never relative
- Permission errors handled gracefully
- Platform-specific paths in lookup tables, not hardcoded

| Check | macOS | Linux | Windows |
|-------|-------|-------|---------|
| Persistence | LaunchAgents/Daemons | systemd, cron | Registry Run, Task Scheduler |
| Privileged | /Library/PrivilegedHelperTools | setuid, /usr/libexec | Program Files, System32 |
| Auto-update | Keystone, MAU | apt, snap | Windows Update, Winget |
| CA trust | Keychain, /etc/ssl/certs | /etc/ssl/certs | certmgr.msc |
| VPN | SystemExtensions | NetworkManager | TAP adapters, WireGuard |
| Package mgrs | Homebrew, pip, npm | apt, pip, npm, snap | winget, choco, scoop |
| Shell history | .bash_history, .zsh_history | same | PSReadLine history |
| Browser | ~/Library/App Support | ~/.config | AppData\Local |

**Windows + WSL:** WSL is a third environment on Windows machines.
Own filesystem, own packages, own credentials, own CA store. But
cross-boundary access (/mnt/c/ from WSL, \\wsl$\ from Windows)
means compromise in either reaches both. aidefend sweeps Windows
native, each WSL distribution, and the bridge between them.

### Filesystem Walk

Smart targeting. Knows which filenames indicate supply chain trust:

- package-lock.json, node_modules/ — npm
- requirements.txt, Pipfile.lock, poetry.lock — PyPI
- site-packages/ — installed Python packages
- .github/workflows/*.yml — GitHub Actions
- Dockerfile, docker-compose.yml — container images
- .vscode/extensions.json — VS Code extensions
- .pth files — Python persistence (LiteLLM vector)
- .git/hooks/ — arbitrary code execution
- .npmrc, .aws/credentials, .ssh/, .env — credential locations
- .bash_history, .zsh_history — command history exposure
- .bashrc, .zshrc, .bash_profile — dotfile secrets

### Auto-Update Detection

Classification: CRITICAL / HIGH / MEDIUM / INFO

Known paths: Homebrew, macOS, VS Code, Chrome/Keystone,
Chrome extensions, GitHub Actions by tag, npm postinstall,
Python .pth, Docker :latest, Git hooks, Vercel auto-deploy,
Adobe CC, Microsoft AutoUpdate, Slack, Zoom, Docker Desktop,
Spotify, 1Password, Cargo/rustup, App Store, Safari extensions,
Xcode CLT, Homebrew casks.

### VPN Client Audit (OL-S2-036)

VPN clients are highest-privilege software — total network MITM.
aidefend checks:
- Which VPN clients are installed
- Their LaunchDaemons and PrivilegedHelperTools
- Whether they installed CA certificates into system trust store
- Whether they auto-update and from where
- Network/kernel extension status

### MITM Detection (OL-S2-037)

Reference implementation: relay/2026-04-04/sandbox-recon-20260404.md
(Guapo's sandbox recon detecting Anthropic's four CAs)

aidefend checks:
- **CA trust store audit** — enumerate all CAs, flag non-standard,
  detect TLS inspection CAs, compare against baseline
- **Proxy detection** — HTTPS_PROXY, system network prefs, PAC files
- **Network extension audit** — system extensions, content filters,
  DNS overrides
- **Active cert verification** — compare certificate fingerprints
  for known sites against expected values

### Known Secrets/Breach Checking (OL-S2-038)

**Local scanning (never leaves machine):**
- Git history — secrets in git log (TeamPCP attack vector)
- Plaintext in .env, config files, YAML, JSON
- Shell history — API keys in command arguments
- SSH keys without passphrases

**Privacy-preserving external checks:**
- HIBP k-anonymity — first 5 chars of SHA-1, full email never sent
- Cross-reference credentials against compromised services in registry

**What aidefend never does:**
- Never reads or transmits actual secret values
- Never sends full credentials externally
- Reports locations, not values

### Credential Exposure Inventory

Inspired by Bagel (BoostSecurity). WHERE credentials live:
.npmrc, .aws/credentials, .git-credentials, .ssh/, .env,
Keychain, shell history, .docker/config.json, .kube/config,
.pypirc. Reports count and locations, never values.

### macOS-Specific

LaunchAgents (~/Library, /Library), LaunchDaemons (/Library),
/Library/PrivilegedHelperTools (root-level, most people never
audit), Login Items, crontabs, kernel extensions (/Library/
Extensions), system extensions (/Library/SystemExtensions),
code signatures (codesign --verify).

### Linux-Specific

systemd units (/etc/systemd/system/, ~/.config/systemd/user/),
crontabs (/etc/crontab, /etc/cron.d/, user crontabs), init.d
scripts (/etc/init.d/), setuid/setgid binaries (find / -perm
-4000), capabilities (getcap on binaries), LD_PRELOAD and
/etc/ld.so.preload (library injection, silent MITM on any
process), AppArmor/SELinux profiles, snap packages (auto-update
by default), flatpak packages, apt unattended-upgrades,
/etc/ssl/certs and /usr/local/share/ca-certificates/ (CA trust),
update-ca-certificates (custom CA injection), NetworkManager
dispatcher scripts, udev rules (/etc/udev/rules.d/), Docker
socket permissions (/var/run/docker.sock — root equivalent),
authorized_keys across all users.

### Windows-Specific

Registry Run/RunOnce keys (HKLM and HKCU), Task Scheduler,
Services (sc query, Get-Service), Startup folder, WMI event
subscriptions (invisible persistence), COM object hijacking,
DLL search order hijacking, Certificate store (certmgr.msc,
CurrentUser and LocalMachine), Windows Defender exclusions
(what's been told to ignore), PowerShell profiles ($PROFILE —
runs on every PS session), BITS jobs (Background Intelligent
Transfer, abused for C2), Credential Manager, hosts file
(C:\Windows\System32\drivers\etc\hosts), named pipes, Winget/
Chocolatey/Scoop package managers, Windows Update / Microsoft
Store auto-update, Group Policy objects.

### Windows + WSL (OL-S2-040)

WSL is a third environment. Own filesystem, own packages, own
credentials, own CA store. Cross-boundary access (/mnt/c/ from
WSL, \\wsl$\ from Windows) means compromise in either reaches
both. aidefend sweeps Windows native, each WSL distribution,
and the bridge between them.

## OUTPUT

1. **Sweep report** — JSONL, one line per finding, accumulates
2. **Lockdown recommendations** — terminal, actionable
3. **Surfacing output** — anomalies outside known patterns
4. **Registry update proposals** — JSONL for Commander review
5. **harness-db writes** — intelligence_items, provenance_edges

## REGISTRY

### Format
JSONL. One line per indicator. Accumulates (D-020).

### Schema
```jsonl
{"id":"AX-001","campaign":"axios","vector":"npm-package-hijack","package":"axios","ecosystem":"npm","compromised_versions":["1.14.1","0.30.4"],"safe_version":"1.14.0","actor":"UNC1069","date_discovered":"2026-03-31","cve":null,"source":"datadog","added_by":"Agent Coffee","session":"ff4220d3"}
```

### Location
Repo: registry/ in nobul-tech/aitools
Deployed: nobulai.tools via aideploy
Public: free for everyone (D-035)

## COMPETITIVE LANDSCAPE

Bagel (BoostSecurity) — credential inventory, privacy-first.
macos-trust — signature verification, persistence detection.
SBOM tools (Syft, CycloneDX, Trivy) — component inventory.
mac-security-audit — single-file macOS audit.

aidefend adds: supply chain threat matching, operational learning,
living registry, harness-db integration, MITM detection,
VPN auditing, cross-platform from day one.

## LANGUAGE

Python. stdlib-only. Consistent with other aitools tools.
Fallback notification via aisos (bash/curl, SIP-protected).

## ROADMAP

What we see ahead. Not phases. Not tiers. The order changes as
the intelligence changes. Everything is a comma.

**Core sweep engine:** Filesystem walk with smart targeting,
registry matching against seeded indicators, credential exposure
inventory (locations not values), auto-update path detection with
lockdown recommendations, .pth file detection, GitHub Actions
workflow scanning, git hooks audit, baseline generation, JSONL
output.

**Defense capabilities:** Code signature verification (macOS),
browser extension audit, network listener inventory, full
persistence detection (all three platforms), SBOM generation,
VPN client audit, MITM detection (CA trust store, proxy, active
cert fingerprinting), known breach checking (HIBP k-anonymity,
git history scanning).

**Intelligence integration:** harness-db integration
(intelligence_items, provenance_edges), registry auto-update
from nobulai.tools, scheduled sweeps, trend analysis across
baseline diffs, aisos integration for alerting, governance
proposals (structured JSONL for Commander review).

What gets built next depends on what we learn.

---

Everything is a comma.
