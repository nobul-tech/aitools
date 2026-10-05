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
| Browser | `google-chrome-stable` (verified 154.0.8037.97-1), installs to `/opt/google/chrome/chrome` | Download: `https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb`. Apt repo written by the package: `https://dl.google.com/linux/chrome-stable/deb/ stable main` (`/etc/apt/sources.list.d/google-chrome.sources`, key `/usr/share/keyrings/google-chrome.gpg`). Signing key and repo docs: `https://www.google.com/linuxrepositories/`, `https://dl.google.com/linux/linux_signing_key.pub` | `scripts/setup-google-chrome.sh`, run by `aitools install` (Step 20b) and by the environment setup script (each new container). The package also installs `/etc/cron.daily/google-chrome` (repo/key upkeep). |
| Chrome runtime libraries | The package's `Depends`: ca-certificates, fonts-liberation, libasound2, libatk-bridge2.0-0, libatk1.0-0, libatspi2.0-0, libc6, libcairo2, libcups2, libcurl (any of 3-gnutls/3-nss/4/3), libdbus-1-3, libexpat1, libgbm1, libglib2.0-0, libgtk-3-0 (or libgtk-4-1), libnspr4, libnss3, libpango-1.0-0, libudev1, libvulkan1, libx11-6, libxcb1, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxkbcommon0, libxrandr2, wget, xdg-utils | `dpkg-query -W -f '${Depends}' google-chrome-stable`; Ubuntu 24.04 (noble) archive + security | Transitively, by `apt-get install` of the Chrome `.deb`. Do not install or pin them individually. On the verified install apt added 54 packages (mostly Perl modules and X utilities pulled in by `xdg-utils`) and upgraded 8 (`perl`, `perl-base`, `perl-modules-5.38`, `libperl5.38t64`, `libgbm1`, `libgl1-mesa-dri`, `libglx-mesa0`, `mesa-libgallium`). |
| NSS tools | `libnss3-tools` (verified 2:3.98-1ubuntu0.2; provides `certutil`) | Ubuntu noble archive | `setup-google-chrome.sh`: `apt-get install -y libnss3-tools` when `certutil` is missing. Upgrades `libnss3` to the matching version. |
| Proxy CA trusted by Chrome | Root's NSS store `sql:/root/.pki/nssdb` containing every certificate of `/root/.ccr/agent-proxy-ca.crt` with trust `C,,`: `ccr-agent-proxy` for the first, `ccr-agent-proxy-<n>` for the n-th | CA file provided by the environment (`/root/.ccr/README.md`); not managed by aitools. It is a bundle: 2 certificates on 2026-10-05. `certutil -A -i <bundle>` imports only the first, so each certificate is imported separately (D-ENV9) | `setup-google-chrome.sh` creates the store if missing and matches each bundle certificate by SHA-256 fingerprint under any nickname: present -> kept (trust set to `C,,` if it is not a trusted CA); missing -> imported. A nickname is deleted only when that import needs it and it holds a certificate not in the bundle; every other entry is left alone, so a store the environment already maintains is not rewritten. See Unknowns for CA rotation. |
| MCP server | `chrome-devtools-mcp@latest` (verified 1.10.1) | `/tool-registry` skill (`chrome-devtools-mcp`); flags from `chrome-devtools-mcp --help` | `setup-user-mcp.sh` (Claude Code) and `setup-cursor-ide-mcp.sh` (Cursor) write the arguments below when the environment is `claude-code-web`. |
| Node.js / npx | `/opt/node22` (v22.22.2) | Environment image | Not managed by this decision. |

Environment detection (for scripts): `CLAUDE_CODE_REMOTE=true` is set in Claude Code web
sessions (observed 2026-10-05, with `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE=cloud_default`).
Scripts read it only through the library API (`is_claude_code_web`, `AITOOLS_ENVIRONMENT`;
`@.claude/rules/cross-platform.md` "Environment branches").

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
setup script: `setup-google-chrome.sh` and `setup-user-mcp.sh` were tested in a session on
2026-10-05 (stubbed fresh container, isolated `HOME`, and a dry run on the live container);
the fallback repeats their steps.

The block runs `setup-google-chrome.sh` from the harness clone of aitools when it is there.
It sets `AITOOLS_ENVIRONMENT=claude-code-web` because the setup script runs before Claude
Code starts and is not documented to receive `CLAUDE_CODE_REMOTE` (unverified). When `claude` is on `PATH` it also runs
`setup-user-mcp.sh`, which writes the D-CHR2 arguments to `~/.claude.json`. Without the
clone (or before this script is merged to its default branch) the inline fallback does the
Chrome, NSS tools and CA steps; the MCP arguments are then written by the next
`aitools install`.

```bash
# aitools: Google Chrome for chrome-devtools-mcp (reference/tool-ops-google-chrome.md, D-CHR1-3, D-ENV9)
AITOOLS_SCRIPTS=/home/user/aitools/scripts
if [ -f "$AITOOLS_SCRIPTS/setup-google-chrome.sh" ]; then
  AITOOLS_ENVIRONMENT=claude-code-web bash "$AITOOLS_SCRIPTS/setup-google-chrome.sh"
  if command -v claude >/dev/null 2>&1; then
    AITOOLS_ENVIRONMENT=claude-code-web bash "$AITOOLS_SCRIPTS/setup-user-mcp.sh"
  fi
else
  # Fallback: same steps as setup-google-chrome.sh, without its logging and checks.
  if [ ! -x /opt/google/chrome/chrome ]; then
    deb_dir=$(mktemp -d)
    curl -fsSL -o "$deb_dir/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb_dir/chrome.deb" \
      || { apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb_dir/chrome.deb"; }
    rm -rf "$deb_dir"
  fi
  command -v certutil >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y libnss3-tools
  db=/root/.pki/nssdb; ca=/root/.ccr/agent-proxy-ca.crt
  # Certificates are matched by SHA-256 fingerprint under any nickname (D-ENV9).
  fps() { perl -MMIME::Base64 -MDigest::SHA=sha256_hex -0777 -ne 'while (/-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----/sg) { print sha256_hex(decode_base64($1)), "\n" }'; }
  nicks() { certutil -L -d "sql:$db" | perl -ne 'next if /^\s/ || /^Certificate Nickname/; print "$1\n" if /^(.+?)\s+\S*,\S*,\S*\s*$/'; }
  trust_of() { certutil -L -d "sql:$db" | perl -ne 'print "$1" if /^\Q'"$1"'\E\s+(\S*,\S*,\S*)\s*$/'; }
  fp_of() { certutil -L -d "sql:$db" -n "$1" -a < /dev/null | fps | head -n 1; }
  holder() { nicks | while IFS= read -r h; do [ "$(fp_of "$h")" = "$1" ] && { echo "$h"; break; }; done; }
  mkdir -p "$db"
  [ -f "$db/cert9.db" ] || certutil -N -d "sql:$db" --empty-password
  if [ -r "$ca" ]; then
    bundle=$(fps < "$ca")
    i=0
    for fp in $bundle; do
      i=$((i + 1))
      h=$(holder "$fp")
      if [ -n "$h" ]; then   # already in the store: keep its nickname, make sure it is a trusted CA
        t=$(trust_of "$h")
        case "${t%%,*}" in *C*) ;; *) certutil -M -d "sql:$db" -n "$h" -t C,, || echo "aitools chrome: trust on $h failed" >&2 ;; esac
        continue
      fi
      nick=ccr-agent-proxy; [ "$i" -gt 1 ] && nick="ccr-agent-proxy-$i"
      if nicks | grep -qx -- "$nick"; then
        if printf '%s\n' "$bundle" | grep -qx -- "$(fp_of "$nick")"; then
          m=2; while nicks | grep -qx -- "ccr-agent-proxy-$m"; do m=$((m + 1)); done
          nick="ccr-agent-proxy-$m"   # taken by another bundle certificate: next free nickname
        else
          certutil -D -d "sql:$db" -n "$nick"   # holds a CA that is not in the bundle: replace it
        fi
      fi
      perl -0777 -ne 'my @c = /(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)/sg; print $c['"$i"' - 1], "\n";' "$ca" \
        | certutil -A -d "sql:$db" -n "$nick" -t C,, || echo "aitools chrome: import of $nick failed" >&2
    done
  else
    echo "aitools chrome: $ca not found; HTTPS pages will fail in Chrome" >&2
  fi
fi
```

Cost per new container: about 470 MB disk, about 25 s. If the MCP arguments were not written
(no `claude` on `PATH` during the setup script), run `aitools install` or
`bash scripts/setup-user-mcp.sh` in the session and restart it.

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
- `certutil -L -d sql:/root/.pki/nssdb` lists `ccr-agent-proxy  C,,` and one
  `ccr-agent-proxy-<n>  C,,` per further certificate in the CA bundle (2026-10-05:
  `ccr-agent-proxy`, `ccr-agent-proxy-2`).
- `bash scripts/setup-google-chrome.sh --dry-run` -> summary `chrome proxy ca  verified (2 certs)`,
  nothing changed.
- MCP: `list_pages`, then `navigate_page` to `https://www.google.com` -> `Successfully
  navigated to https://www.google.com.`; `take_snapshot` contains `RootWebArea "Google"`.
  Verified 2026-10-05 with a stdio client (`.scratch/session-3030c86a-9/s2-chrome/out/R4-verify.log`).

## Unknowns

- Whether `/root/.ccr/agent-proxy-ca.crt` exists when the environment setup script runs,
  and whether the CA changes during a session (`CCR_AGENT_PROXY_CA_WATCH_ENABLED=1` is set,
  which suggests rotation is watched). If it rotates, the NSS import must be repeated.
- Whether Claude Code picks up an MCP config change via `/mcp` without a session restart.
- Whether the `/root/.ccr/README.md` NSS claim is a regression or targets another user.

## Follow-ups

Done (2026-10-05):

- Onboarding: `scripts/setup-google-chrome.sh` (Linux, Claude Code web; n/a elsewhere) and
  `.ps1` (Windows: reports n/a, D-ENV4), installer Step 20b in `aitools-install.sh/.ps1`
  (unconditional, D-ENV8), `build-deploy.sh` copy block pair, `reference/tool-registry.md`
  and script-standards tool names. No check-script `TOOL_CMDS` entry: no version check is
  added, because Chrome updates itself through the package's apt repo and cron job. No
  CLAUDE.md Managed CLI Tools row: Chrome is not a CLI agents invoke.
- MCP setup: `setup-user-mcp.sh` and `setup-cursor-ide-mcp.sh` write the D-CHR2 arguments
  when the environment is `claude-code-web`, so `aitools install` no longer overwrites them.
- CA bundle: every certificate is imported (D-ENV9).

Not done:

- Registry schema: platform keys only (`macos`/`windows`/`linux`); environment-specific
  support is recorded under the `environments` key (schema change, see the registry entry).
- `/tool-ops` registry entry for Google Chrome, if its governance modes are needed.
- Claude Code's local chrome-devtools args lack `-y` while Cursor's have it (incident filed).
- `check-post-push` step 3 checks only `--isolated`, not the environment's args (incident
  filed).

## Cross-References

- Evaluation research: `reference/evaluations/google-chrome-linux-2026-10-05.md`
- Registry entries: `/tool-registry` skill (`google-chrome`, `nss-tools`, `chrome-devtools-mcp`)
- Environment notes: dotprofile `environments/claude-code-web/CLAUDE.md`
- Evaluation principles: `@.claude/rules/tool-evaluation.md`
- Lifecycle and onboarding: `@.claude/rules/tool-lifecycle.md`
- Web sources rule (chrome-devtools for docs): `@.claude/rules/web-sources.md`
