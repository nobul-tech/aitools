# Google Chrome Operations

**Intent**: **Purpose**: Record how aitools supports Google Chrome — the browser that
chrome-devtools-mcp drives — in each environment, what it needs and from which source
of truth, and the decisions behind the configuration. **Scope**: Chrome as a managed
tool and its managed dependencies (runtime libraries, NSS tools, proxy CA trust), the
chrome-devtools-mcp launch arguments per environment, security consequences, and
verification. NOT the chrome-devtools-mcp server entry or other MCP servers (`/tool-registry`
skill). NOT the evaluation research (`reference/evaluations/google-chrome-linux-2026-10-05.md`).
NOT setup-script internals. **Audience**: Agents configuring or troubleshooting
chrome-devtools-mcp, agents writing Chrome setup scripts or environment setup scripts,
the `/tool-eval` and `/tool-registry` skills.

## Decisions

| # | Decision | Date | By |
|---|---|---|---|
| D-CHR1 | Google Chrome is a managed tool. It is the browser chrome-devtools-mcp launches; chrome-devtools-mcp "officially supports Google Chrome and Chrome for Testing only" (chrome-devtools-mcp README). First supported in the Claude Code web environment (platform: Linux); macOS and Windows not yet evaluated. | 2026-10-05 | commander |
| D-CHR2 | In the Claude Code web environment, chrome-devtools-mcp runs Chrome **as root** with `--headless` and `--chromeArg=--no-sandbox` (option R4 of the evaluation). | 2026-10-05 | commander |
| D-CHR3 | Chrome's runtime libraries, `libnss3-tools`, and root's NSS store holding the agent-proxy CA are managed dependencies in that environment. | 2026-10-05 | commander |

Alternatives tested and not chosen (evaluation record has the evidence):

| Option | Why not chosen |
|---|---|
| R1: non-root user `chromeuser` + launcher script (sandbox on) | Commander chose R4. R1 keeps Chrome's sandbox but adds a user account, a launcher, `runuser`, and a per-start CA sync to keep alive across reclaims. Remains the documented upgrade path if the security trade-off changes. |
| R2: Chrome for Testing + non-root user | Versioned install path; same extra parts as R1. |
| R3: pre-installed Playwright Chromium 141 | Degraded: not a browser chrome-devtools-mcp supports, 13 major versions behind stable (`tool-evaluation.md` principles 1, 3). |
| Symlink `/opt/google/chrome/chrome` -> another binary | Fixes only the missing executable; still fails as root. |
| Wrapper script at `/opt/google/chrome/chrome` adding `--no-sandbox` | Disables the sandbox invisibly to anyone reading the MCP config. |

## Why the default config fails in the Claude Code web environment

Four independent problems; all four must be addressed:

1. **No Chrome at the default path.** With no `--executablePath`, chrome-devtools-mcp
   uses Puppeteer's `stable` channel path `/opt/google/chrome/chrome`
   (`getChromeLinuxOrWslLocation()` in the bundled Puppeteer). The image ships only
   Playwright Chromium under `/opt/pw-browsers`.
2. **Root.** Every session runs as `uid=0`. Chrome (and `chrome-headless-shell`) exits
   with `Running as root without --no-sandbox is not supported. See https://crbug.com/638180.`
3. **No display.** chrome-devtools-mcp defaults to a headed browser (`headless: false`);
   the container has no X server (`Missing X server to start the headful browser`).
4. **Proxy CA not trusted by Chrome.** The environment's agent proxy re-terminates TLS.
   Chrome trusts the NSS store, not the system bundle, and root had no NSS store, so
   every HTTPS page fails with `net_error -202` (ERR_CERT_AUTHORITY_INVALID).
   `/root/.ccr/README.md` states the browser NSS store is already set up; it was not.

chrome-devtools-mcp appends its "running as root" paragraph to *every* launch failure
when uid is 0 and `--no-sandbox` is not in `--chromeArg`, so problems 1 and 3 surface
with a misleading root message.

## Requirements and sources of truth (Claude Code web environment)

| Need | What | Source of truth | Managed how |
|---|---|---|---|
| Browser | `google-chrome-stable` (verified 154.0.8037.97-1), installs to `/opt/google/chrome/chrome` | Download: `https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb`. Apt repo written by the package: `https://dl.google.com/linux/chrome-stable/deb/ stable main` (`/etc/apt/sources.list.d/google-chrome.sources`, key `/usr/share/keyrings/google-chrome.gpg`). Signing key and repo docs: `https://www.google.com/linuxrepositories/`, `https://dl.google.com/linux/linux_signing_key.pub` | Environment setup script (each new container). The package also installs `/etc/cron.daily/google-chrome` (repo/key upkeep). |
| Chrome runtime libraries | The package's `Depends`: ca-certificates, fonts-liberation, libasound2, libatk-bridge2.0-0, libatk1.0-0, libatspi2.0-0, libc6, libcairo2, libcups2, libcurl (any of 3-gnutls/3-nss/4/3), libdbus-1-3, libexpat1, libgbm1, libglib2.0-0, libgtk-3-0 (or libgtk-4-1), libnspr4, libnss3, libpango-1.0-0, libudev1, libvulkan1, libx11-6, libxcb1, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxkbcommon0, libxrandr2, wget, xdg-utils | `dpkg-query -W -f '${Depends}' google-chrome-stable`; Ubuntu 24.04 (noble) archive + security | Transitively, by `apt-get install` of the Chrome `.deb`. Do not install or pin them individually. On the verified install apt added 54 packages (mostly Perl modules and X utilities pulled in by `xdg-utils`) and upgraded 8 (`perl`, `perl-base`, `perl-modules-5.38`, `libperl5.38t64`, `libgbm1`, `libgl1-mesa-dri`, `libglx-mesa0`, `mesa-libgallium`). |
| NSS tools | `libnss3-tools` (verified 2:3.98-1ubuntu0.2; provides `certutil`) | Ubuntu noble archive | Environment setup script: `apt-get install -y libnss3-tools`. Upgrades `libnss3` to the matching version. |
| Proxy CA trusted by Chrome | Root's NSS store `sql:/root/.pki/nssdb` containing `/root/.ccr/agent-proxy-ca.crt` as `ccr-agent-proxy` with trust `C,,` | CA file provided by the environment (`/root/.ccr/README.md`); not managed by aitools | Created and imported by the environment setup script; see Unknowns for CA rotation. |
| MCP server | `chrome-devtools-mcp@latest` (verified 1.10.1) | `/tool-registry` skill (`chrome-devtools-mcp`); flags from `chrome-devtools-mcp --help` | Existing MCP entry; arguments below. |
| Node.js / npx | `/opt/node22` (v22.22.2) | Environment image | Not managed by this decision. |

Environment detection (for scripts): `CLAUDE_CODE_REMOTE=true` is set in Claude Code web
sessions (observed 2026-10-05, with `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE=cloud_default`).

## Configuration (D-CHR2)

Claude Code `~/.claude.json`:

```json
"chrome-devtools": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "chrome-devtools-mcp@latest", "--isolated", "--headless", "--chromeArg=--no-sandbox"]
}
```

- `--isolated`: existing aitools override (temporary profile per session).
- `--headless`: no display in the container.
- `--chromeArg=--no-sandbox`: Chrome refuses root otherwise. `--chromeArg` is repeatable;
  the help also documents `--chrome-arg`.
- No `--executablePath`: Google Chrome is at the stable-channel default path.
- Not used: `--acceptInsecureCerts` (the CA import is the correct fix);
  `PUPPETEER_DANGEROUS_NO_SANDBOX=true` (works, but chrome-devtools-mcp's root
  diagnostic only checks `--chromeArg`).
- Optional, not decided: `--no-usage-statistics`, `--no-performance-crux` (chrome-devtools-mcp
  sends usage statistics and CrUX lookups by default).

## Environment setup script block

Paste into the Claude Code web environment's Setup script. Idempotent. Untested as a
setup script (each command was run in a session on 2026-10-05).

```bash
# aitools: Google Chrome for chrome-devtools-mcp (reference/tool-ops-google-chrome.md, D-CHR2/D-CHR3)
if [ ! -x /opt/google/chrome/chrome ]; then
  curl -fsSL -o /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/google-chrome-stable_current_amd64.deb
  rm -f /tmp/google-chrome-stable_current_amd64.deb
fi
command -v certutil >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y libnss3-tools
mkdir -p /root/.pki/nssdb
[ -f /root/.pki/nssdb/cert9.db ] || certutil -N -d sql:/root/.pki/nssdb --empty-password
if [ -r /root/.ccr/agent-proxy-ca.crt ]; then
  certutil -A -d sql:/root/.pki/nssdb -n ccr-agent-proxy -t C,, -i /root/.ccr/agent-proxy-ca.crt
else
  echo "aitools chrome: /root/.ccr/agent-proxy-ca.crt not found; HTTPS pages will fail in Chrome" >&2
fi
```

Cost per new container: about 470 MB disk, about 25 s. The MCP config above is not set by
this block; until aitools sets it (follow-ups), edit `~/.claude.json` and restart the
session.

## Security consequence of D-CHR2

With `--no-sandbox` as root, Chrome's renderer processes run with no seccomp filter and in
the host namespaces as uid 0 (measured: `seccomp=0` for every process; with the sandbox on
as a non-root user, renderers showed `seccomp=2` and their own user/PID namespaces). A
browser bug exploited by a visited page would run code as root in the container, with
access to `~/.claude.json`, the proxy setup, and the repositories under `/home/user`. The
container's short life limits persistence, not data access during the session. Use
chrome-devtools-mcp in this environment for trusted pages (official docs, our own sites);
Puppeteer's troubleshooting guide calls running without a sandbox "strongly discouraged".

## Verification

- `/opt/google/chrome/chrome --version` -> `Google Chrome 154.0.8037.97`.
- `certutil -L -d sql:/root/.pki/nssdb` lists `ccr-agent-proxy  C,,`.
- MCP: `list_pages`, then `navigate_page` to `https://www.google.com` -> `Successfully
  navigated to https://www.google.com.`; `take_snapshot` contains `RootWebArea "Google"`.
  Verified 2026-10-05 with a stdio client (`.scratch/session-3030c86a-9/s2-chrome/out/R4-verify.log`).

## Unknowns

- Whether `/root/.ccr/agent-proxy-ca.crt` exists when the environment setup script runs,
  and whether the CA changes during a session (`CCR_AGENT_PROXY_CA_WATCH_ENABLED=1` is set,
  which suggests rotation is watched). If it rotates, the NSS import must be repeated.
- Whether Claude Code picks up an MCP config change via `/mcp` without a session restart.
- Whether the `/root/.ccr/README.md` NSS claim is a regression or targets another user.

## Follow-ups (not done)

- Onboarding checklist (`tool-lifecycle.md`) for Google Chrome: setup script
  (`scripts/setup-google-chrome.sh`, Linux; `.ps1` decision for Windows), installer step,
  `build-deploy.sh` block, check-script `TOOL_CMDS`, CLAUDE.md Managed CLI Tools rows.
- MCP setup (`setup-user-mcp`, `setup-cursor-ide-mcp`): write the D-CHR2 arguments when
  `CLAUDE_CODE_REMOTE=true`, so `aitools install` stops overwriting them.
- Registry schema: platform keys only (`macos`/`windows`/`linux`); environment-specific
  support is recorded under a new `environments` key (schema change, see the registry
  entry).
- `/tool-ops` registry entry for Google Chrome, if its governance modes are needed.

## Cross-References

- Evaluation research: `reference/evaluations/google-chrome-linux-2026-10-05.md`
- Registry entries: `/tool-registry` skill (`google-chrome`, `nss-tools`, `chrome-devtools-mcp`)
- Environment notes: dotprofile `environments/claude-code-web/CLAUDE.md`
- Evaluation principles: `@.claude/rules/tool-evaluation.md`
- Lifecycle and onboarding: `@.claude/rules/tool-lifecycle.md`
- Web sources rule (chrome-devtools for docs): `@.claude/rules/web-sources.md`
