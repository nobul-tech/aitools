# AGENTS.md

## Cursor Cloud specific instructions

### Overview

This is **aitools** — a sovereign AI infrastructure toolkit of standalone CLI scripts. There is no build system, no package manager, no test framework, and no external dependencies. All Python tools use stdlib only (Python >=3.6). The bash tool (`aisos.sh`) uses only `/bin/bash` and `/usr/bin/curl`.

### Runtime Requirements

- **Python >=3.6** (stdlib only, zero pip packages)
- **Bash** (3.2+ compatible)
- **curl** (system)

### Tools (all in `tools/`)

| Tool | Language | Purpose |
|------|----------|---------|
| `aifind.py` | Python | Smart file search with cloud sync exclusion |
| `aicatalog.py` | Python | Artifact triage, hashing, provenance extraction, Datadog correlation |
| `aideploy.py` | Python | Deploy to Cloudflare/Vercel |
| `aipublish.py` | Python | Generate public artifact index |
| `aisos.sh` | Bash | Heartbeat and SOS broadcast (Datadog + Cloudflare Worker) |
| `axios-scan-v4.0.1.py` | Python | Supply chain security scanner for axios npm compromise |
| `claude-session-export.py` | Python | Claude session export (macOS-specific, uses Keychain) |
| `dd-april4-chula.py` | Python | Push session events to Datadog |
| `sos-worker.mjs` | JS/ESM | Cloudflare Worker for SOS relay |

### Running Tools

All tools are invoked directly:

```bash
python3 tools/aifind.py --help
python3 tools/aicatalog.py /path/to/scan -v
bash tools/aisos.sh status
```

### Environment Variables (for tools that call external APIs)

See `WRITE-PATHS.md` for full details. Key variables:

- `DD_API_KEY` — Datadog write (required for `aisos`, `aicatalog --dd-push`, `dd-april4-chula`)
- `DD_APP_KEY` — Datadog read (required for `aicatalog --dd-query`)
- `DD_SITE` — defaults to `us5.datadoghq.com`
- `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` — for `aideploy` Cloudflare target

### Gotchas

- There are **no automated tests** in this repo. Verification is done by running tools directly.
- There is **no linting** configured. Python syntax can be checked with `python3 -m py_compile tools/<file>.py`.
- `claude-session-export.py` requires macOS Keychain — it will not work on Linux.
- `aisos.sh` references `sw_vers` (macOS-specific) but gracefully handles its absence on Linux.
- The design decision (D-002, D-003) explicitly bans npm/npx/Homebrew; no package managers are used.
