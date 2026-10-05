# Evaluation: Google Chrome (headless) for chrome-devtools-mcp — Linux, Claude Code web environment — 2026-10-05

**Intent**: **Purpose**: Preserve the discovery, trials and evidence behind decisions
D-CHR1–D-CHR3 (Google Chrome as a managed tool; root + `--headless` + `--no-sandbox` in
the Claude Code web environment). **Scope**: Research as performed on 2026-10-05: sources
read, options compared, trial commands and results, system changes, unknowns. NOT the
current configuration or requirements (`reference/tool-ops-google-chrome.md`). NOT registry
data (`/tool-registry` skill). **Audience**: Agents re-evaluating Chrome or chrome-devtools-mcp
support, the `/tool-eval` skill.

Method: delegated research mission S2-Chrome (general-purpose sub-agent, hands-on trials
authorized by the commander), report saved by Session Commander 3030c86a-9, which
re-verified options R1 (L1) and R4 itself. Sources were read with WebFetch, not
chrome-devtools: making chrome-devtools work was the subject of the evaluation
(`web-sources.md` exception; JavaScript-rendered pages are flagged below). Trial scripts and
outputs lived in the session scratch directory and are not preserved beyond this file.

Outcome: the commander chose **R4** (section 6) on 2026-10-05. Decisions are recorded in
`reference/tool-ops-google-chrome.md`.

## Summary

1. A symlink at `/opt/google/chrome/chrome` fixes nothing alone; `chrome-headless-shell`
   refuses root exactly like Chrome.
2. Four stacked problems: (a) no Chrome at the default path; (b) Chrome refuses root
   unless the sandbox is off; (c) the MCP defaults to headful (`headless: false`) and there
   is no X server; (d) Chrome does not trust the agent-proxy CA (net_error -202 on every
   HTTPS page). Root had no NSS store, although `/root/.ccr/README.md` says it is set up.
3. Best, sandbox ON (tested G4, L1): Google Chrome stable 154 .deb (SHA256 matches
   Google's signed apt index) + unprivileged user `chromeuser` + root launcher
   `chrome-devtools-mcp-nonroot` + `--headless`. Renderers measured with seccomp=2 and
   own user/PID namespaces.
4. Fallback, sandbox OFF (tested M1, M2, G3): root + `--headless --chromeArg=--no-sandbox`.
   With the sandbox off, a renderer exploit runs as root in the container.
5. No edits to `~/.claude.json`, `~/.cursor/mcp.json` or git repos; no permission-check
   denials of commands. System changes in section 7.

## 1. Environment limits

| Limit | Probe | Output |
|---|---|---|
| User | `id` | `uid=0(root)` |
| Disk | `df -h /` | 252G total, 15G free (61% -> 63% after installs) |
| RAM / shm / CPU | `free -h`; `df -h /dev/shm`; `nproc` | 15Gi, no swap; 16G; 4 |
| Seccomp/caps of agent shell | `/proc/self/status` | `CapEff 000001fffeffffff`, `NoNewPrivs 0`, `Seccomp 0` |
| User namespaces | `max_user_namespaces`; `unshare --user --map-root-user true` | 64300; exit 0 |
| Proxy | env; `$HTTPS_PROXY/__agentproxy/status` | `HTTPS_PROXY=http://127.0.0.1:44177`, enabled; no `HTTP_PROXY` |
| TLS trust | README vs `ls /root/.pki/nssdb`, `which certutil` | README says browser NSS store set up; observed none, no certutil |
| Chrome honours proxy env | T3 | yes; failure was cert -202, not connect |
| `/root` perms | `ls -ld /root` | `drwx------` (non-root cannot read `/root/.ccr`) |
| Existing uid 1000 | `getent passwd 1000` | `ubuntu` (not used) |
| apt | `apt-get install libnss3-tools` | exit 0 |
| Google hosts | trials | dl.google.com, storage.googleapis.com reachable |
| Node | `node --version` | v22.22.2 |
| Pre-installed browsers | `--version`; `ldd` | Playwright chromium-1194 + headless_shell, 141.0.7390.37, no missing libs |
| Display / D-Bus | stderr | no X server; D-Bus errors harmless |
| Persistence | CLAUDE.md, env docs | reclaim wipes filesystem; setup script runs per new session |
| MCP config | `~/.claude.json` | `npx chrome-devtools-mcp@latest --isolated` (not edited) |

## 2. Install options

Sources (WebFetch): Chrome for Testing dashboard (googlechromelabs.github.io/chrome-for-testing,
Stable 154.0.8037.92); developer.chrome.com/blog/chrome-for-testing ("trustworthy content
only", no auto-update); developer.chrome.com/blog/chrome-headless-shell; Puppeteer
`@puppeteer/browsers` README; www.google.com/linuxrepositories (key command only; repo
line not returned by WebFetch); pptr.dev/troubleshooting (non-root USER recommended;
JS-rendered); chrome-devtools-mcp README + docs/troubleshooting.md ("officially supports
Google Chrome and Chrome for Testing only"; "Run as a non-root user"); Chromium
linux_sandboxing.md at an old pinned commit (current URLs 404).

| Option | Version | Root to install | Runs as root w/o --no-sandbox | Survives reclaim | Flags |
|---|---|---|---|---|---|
| Google Chrome stable .deb | 154.0.8037.97-1 | yes | no (G1) | no (setup script) | officially supported; SHA256 matches signed index; +468 MB, 54 new / 8 upgraded pkgs (incl. perl, mesa); adds apt source + cron.daily |
| CfT `chrome` (`@puppeteer/browsers`) | 154.0.8037.92 | no (`--path`) | no (inferred) | no | supported; "trustworthy content only" |
| CfT `chrome-headless-shell` | 154.0.8037.92 | no | no (C1) | no | old headless mode |
| Playwright Chromium (pre-installed) | 141.0.7390.37 | present | no (T1) | yes (image; not re-verified) | yellow: unsupported by the MCP; 13 majors behind |
| Playwright headless_shell | 141.0.7390.37 | present | no (T2) | yes (image) | same |

## 3. How chrome-devtools-mcp finds a browser (v1.10.1)

Sources: `--help`; `build/src/BrowserManager.js` `#launch()`, `config/browser-options.js`,
bundled Puppeteer `third_party/index.js` (~L86585, ~L91751).

- Default: Puppeteer `chrome` channel -> `getChromeLinuxOrWslLocation()`:
  stable `/opt/google/chrome/chrome`, beta `/opt/google/chrome-beta/chrome`, canary
  `/opt/google/chrome-canary/chrome`, dev `/opt/google/chrome-unstable/chrome`. No
  Puppeteer download cache.
- Flags: `-e, --executablePath`; `--channel`; `--headless` (default false for the MCP
  server -> `--headless=new`); `--isolated`; `--userDataDir`; `-u, --browserUrl`;
  `-w, --wsEndpoint` (+`--wsHeaders`); `--autoConnect` (Chrome 144+); `--proxyServer`;
  `--acceptInsecureCerts`; `--config <json>`.
- Chrome args: repeatable `--chromeArg` (`--chromeArg=--no-sandbox` worked, M1);
  `--ignoreDefaultChromeArg`; env `PUPPETEER_DANGEROUS_NO_SANDBOX=true` (M7).
- `rootSandboxLaunchError()` appends the root/crbug.com/638180 paragraph to ANY launch
  failure when uid 0 and `--no-sandbox` not in `--chromeArg` -- it masked "executable not
  found" (M0) and "Missing X server" (M3/M4).
- Page tools need `pageId` (`--pageIdRouting` default true).

## 4. Symlink and wrapper tricks

- Symlink `/opt/google/chrome/chrome` -> Playwright Chromium fixes only (a). As root it
  still fails (M4, M5: `Target closed` + root paragraph). Works only with `--headless`
  plus `--chromeArg=--no-sandbox` (M6) or the env var (M7), plus the CA in NSS. It also
  makes Chromium 141 masquerade as Google Chrome; `--executablePath` does the same openly.
- Wrapper at that path (`exec .../chrome --no-sandbox --headless=new "$@"`, M8) works with
  the config unchanged but disables the sandbox invisibly. Removed after the trial.
- Sandbox measured (`sandbox-proc.sh`): ON as chromeuser -> renderers `seccomp=2`, own
  user/PID namespaces. OFF as root -> all `seccomp=0`, host namespaces, uid 0. A renderer
  exploit then has root: `/root/.claude.json`, proxy setup, repos under `/home/user`.

## 5. Trials

Harnesses: `trial-direct.sh` (`--headless --dump-dom https://www.google.com`, fresh
profile); `mcp-client.mjs` (initialize -> list_pages -> navigate_page -> take_snapshot;
success = `RootWebArea "Google"`).

| # | Binary | User | Sandbox | CA | Result |
|---|---|---|---|---|---|
| T1 | PW Chromium | root | on | no | exit 1 "Running as root without --no-sandbox is not supported" |
| T2 | PW headless_shell | root | on | no | same |
| T3 | PW Chromium | root | off | no | Privacy error, -202 |
| T4 | PW headless_shell | root | off | no | 40-byte page, -202 |
| -- | `apt-get install -y libnss3-tools`; `nss-import.sh` | root | | | ccr-agent-proxy C,, added |
| T5 | PW Chromium | root | off | yes | `<title>Google</title>` |
| T6 | PW headless_shell | root | off | yes | `<title>Google</title>` |
| U1 | PW Chromium | chromeuser | on | no | starts; -202 |
| U2/U3 | PW Chromium / headless_shell | chromeuser | on | yes | `<title>Google</title>` |
| G1 | Google Chrome 154 | root | on | yes | exit 1, root refusal |
| C1 | CfT headless-shell 154 | root | on | yes | exit 1, root refusal |

| # | MCP args / launcher | User | Sandbox | Result |
|---|---|---|---|---|
| M0 | `--isolated` | root | -- | executable not found + root paragraph |
| M1 | `--isolated --headless --executablePath=<PW chrome> --chromeArg=--no-sandbox` | root | off | pass |
| M2 | M1 with headless_shell | root | off | pass |
| M3 | M1 without `--headless` | root | off | Missing X server |
| M4/M5 | symlink; `--isolated` / `+--headless` | root | on | Target closed + root paragraph |
| M6 | symlink; `--isolated --headless --chromeArg=--no-sandbox` | root | off | pass |
| M7 | symlink; `--isolated --headless` + `PUPPETEER_DANGEROUS_NO_SANDBOX=true` | root | off | pass |
| M8 | wrapper; `--isolated` | root | off (hidden) | pass (not recommended) |
| M9 | `--isolated --headless --executablePath=<PW chrome>` as chromeuser | 1001 | on | pass |
| M10 | root client -> `runuser -u chromeuser -- npx ...` | 1001 | on | pass |
| G2 | Google Chrome; `--isolated` | root | on | Target closed + root paragraph |
| G3 | Google Chrome; `--isolated --headless --chromeArg=--no-sandbox` | root | off | pass |
| G4 | `runuser -u chromeuser -- env NODE_EXTRA_CA_CERTS=... npx -y chrome-devtools-mcp@latest --isolated --headless` | 1001 | on | pass |
| C2/C3 | CfT headless-shell / chrome via `--executablePath` as chromeuser | 1001 | on | pass |
| L1 | launcher `chrome-devtools-mcp-nonroot --isolated --headless`, after deleting chromeuser's `.pki` | 1001 | on | pass (re-verified by delegating agent) |
| LIVE | this session's MCP `list_pages` after Chrome install | root | on | Target closed + root paragraph |

## 6. Recommendations

All need `--headless` and the proxy CA in the browser user's NSS store.

### R1 (recommended, sandbox ON, tested G4/L1): Google Chrome + chromeuser + launcher

```bash
curl -fsSL -o /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/google-chrome-stable_current_amd64.deb
apt-get install -y libnss3-tools
useradd -m -s /bin/bash chromeuser
install -m 755 /home/user/.scratch/session-3030c86a-9/s2-chrome/chrome-devtools-mcp-nonroot /usr/local/bin/chrome-devtools-mcp-nonroot
```

Proposed config (not applied; back up `~/.claude.json` first):
`"chrome-devtools": {"type":"stdio","command":"/usr/local/bin/chrome-devtools-mcp-nonroot","args":["--isolated","--headless"]}`

Success: `list_pages` -> `1: about:blank [selected]`; navigate -> `Successfully navigated
to https://www.google.com.`; snapshot `RootWebArea "Google"`.
Rollback: restore `.bak`; `rm /usr/local/bin/chrome-devtools-mcp-nonroot`;
`userdel -r chromeuser`; `apt-get purge -y google-chrome-stable`; `apt-get autoremove -y`;
`rm /etc/apt/sources.list.d/google-chrome.sources /usr/share/keyrings/google-chrome.gpg /etc/apt/trusted.gpg.d/google.asc`.
Reclaim: `setup-script-block.sh` (idempotent; copies the launcher from
`environments/claude-code-web/chrome-devtools-mcp-nonroot` in the dotprofile clone if
committed -- a repo change outside the mission -- or inline it). ~470 MB, ~25 s/session.
Caveats: `aitools install` rewrites the MCP config (durable fix = Linux/web branch in
aitools MCP setup); mid-session pickup via `/mcp` untested.

### R2 (sandbox ON, tested C2/C3): Chrome for Testing + chromeuser
`npx -y @puppeteer/browsers install chrome@stable --path /opt/cft`; add
`--executablePath=/opt/cft/chrome/linux-<ver>/chrome-linux64/chrome`. Versioned path; deps
on a fresh image untested. Rollback `rm -rf /opt/cft` + R1 user/launcher rollback.

### R3 (sandbox ON, tested M9/M10/U2): Playwright Chromium 141 + chromeuser
No download. `--executablePath=/opt/pw-browsers/chromium-1194/chrome-linux/chrome`.
Yellow flags: unsupported, 13 majors behind, `-1194` changes with the image.

### R4 (fallback, sandbox OFF, tested M1/M2/G3): root + `--no-sandbox`
`apt-get install -y libnss3-tools`; `nss-import.sh`. Args
`["-y","chrome-devtools-mcp@latest","--isolated","--headless","--executablePath=/opt/pw-browsers/chromium-1194/chrome-linux/chrome","--chromeArg=--no-sandbox"]`
(drop `--executablePath` if Google Chrome installed). Trusted pages only. Rollback: revert
config; `rm -rf /root/.pki`.

Not recommended: symlink alone; hidden no-sandbox wrapper; `--acceptInsecureCerts`;
`PUPPETEER_DANGEROUS_NO_SANDBOX`.

## 7. System changes left in place

| # | Change | Undo |
|---|---|---|
| 1 | `libnss3-tools` installed; `libnss3` 3.98-1ubuntu0.1 -> 0.2 | `apt-get purge -y libnss3-tools` |
| 2 | `/root/.pki/nssdb` with proxy CA | `rm -rf /root/.pki` |
| 3 | `/usr/local/share/ccr/{agent-proxy-ca,ca-bundle}.crt` | `rm -rf /usr/local/share/ccr` |
| 4 | user `chromeuser` (uid 1001) + NSS store + npx cache | `userdel -r chromeuser` |
| 5 | `/etc/apt/trusted.gpg.d/google.asc`; `/root/.gnupg` | `rm /etc/apt/trusted.gpg.d/google.asc` |
| 6 | google-chrome-stable 154.0.8037.97-1 (+54 new, 8 upgraded pkgs incl. perl, mesa); `/opt/google/chrome`, `/usr/bin/google-chrome*`, apt source, keyring, `/etc/cron.daily/google-chrome` | `apt-get purge -y google-chrome-stable`; `apt-get autoremove -y`; rm source/keyring (upgrades not reverted) |
| 7 | `/var/lib/apt/lists/dl.google.com_*` | delete or leave |
| 8 | scratch `cft/` (656M), `dl/` (136M) | `rm -rf` |
| 9 | npx caches (root, chromeuser) | harmless |

Not touched: `~/.claude.json`, `~/.cursor/mcp.json`, repos, the live MCP server (now fails
with `Target closed` + root paragraph instead of "executable not found").

## 8. Unknowns

- Whether `/root/.ccr/agent-proxy-ca.crt` exists / is stable when the setup script runs
  (launcher re-syncs each start, so moot for R1-R3).
- `/mcp` reconnect picking up a config change: untested.
- README "browser NSS store already set up": false for root here; worth reporting.
- CfT deps on a fresh image; CfT `chrome` as root (inferred).
- Playwright browsers surviving reclaim: from the brief.
- Google apt repo line read from the file the .deb wrote, not a docs page.
- Chromium sandbox doc cited at an old commit.
- chrome-devtools-mcp sends usage statistics and CrUX lookups by default
  (`--no-usage-statistics`, `--no-performance-crux` disable them).

## Addendum: R4 with Google Chrome at the default path (delegating agent)

`node mcp-client.mjs --isolated --headless --chromeArg=--no-sandbox` (spawns `npx -y chrome-devtools-mcp@latest` with those args) as root, Google Chrome 154 installed, root NSS store with the proxy CA: `Successfully navigated to https://www.google.com.` and `RootWebArea "Google"`.
