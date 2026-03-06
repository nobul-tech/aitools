# Datadog Log Integration

- **Status**: Planned (roadmap)
- **Priority**: High
- **Created**: 2026-03-06
- **Origin**: Accepted to Datadog startup program. Research session evaluated Datadog products,
  alternatives (Axiom, Better Stack, Seq, Grafana/Loki, New Relic), and MCP server landscape.

## Problem

aitools generates structured logs (`[timestamp] [script-name] [level] message`) from deploy/setup
scripts across macOS and Windows. These logs are written to local files (`deploy.log`, `checks.log`)
with no aggregation, search, alerting, or cross-machine visibility. Debugging failures requires
SSH/RDP to the affected machine and manual log reading.

## Decision

Use Datadog Log Management (startup program: up to $100K credits, 1 year Pro tier) as the primary
log platform. Plan for post-credits migration to Axiom (500 GB/month free tier, official MCP server).

### Why Datadog (short term)
- Free credits for a year -- no cost during evaluation and adoption
- Official MCP server for AI-assisted log analysis in Claude Code / Cursor
- CI Visibility for pipeline-level tracing of `aitools install` / `aitools gitpull` runs
- Full platform access: dashboards, monitors, alerting

### Why Axiom (long term)
- 500 GB/month free tier (effectively unlimited for this use case)
- Official remote MCP server (OAuth, `mcp.axiom.co/mcp`) -- requires Pro plan ($25/mo)
- APL query language (Kusto-inspired) -- powerful for ad-hoc analysis
- HTTP API is a single curl call -- identical integration pattern to Datadog
- Migration = change endpoint URL and API key in `log_ship` function

### What we're NOT using
- Datadog Agent (heavy daemon, designed for server fleets -- overkill)
- APM / Infrastructure / RUM / Synthetics (web app and server focused)
- OpenTelemetry (stable spec but overengineered -- no native bash/PS SDK)

## Design

### Phase 1: Foundation (tools + log shipping)

**Onboard Datadog CLI (Pup) and MCP Server:**
- Add to `reference/tool-registry.md` (supported status)
- Add Pup to `scripts/aitools-install.sh/.ps1` (brew/go install)
- Add Datadog MCP to `setup-user-mcp.sh/.ps1` (disabled by default, `aitools --addmcp datadog`)
- Add `setup-datadog.sh/.ps1` script pair for Pup install + auth check

**Add `log_ship` helper to aitools-lib:**
- Bash: `log_ship` function in `aitools-lib.sh` -- collects log lines during script execution,
  POSTs as JSON batch to Datadog HTTP Logs API at script exit
- PowerShell: `LogShip` function in `aitools-lib.ps1` -- same pattern with `Invoke-RestMethod`
- Endpoint: `https://http-intake.logs.datadoghq.com/api/v2/logs`
- Auth: `DD-API-KEY` header, key read from `~/.aitools/config.json` (`datadogApiKey`)
- Tags: `ddsource=aitools`, `service=deploy`, `ddtags=env:<machine>,script:<name>`
- Opt-in: only ships if `datadogApiKey` is configured (no-op otherwise)
- Graceful: network failures logged locally but never abort the script

### Phase 2: Dashboards and alerting

- Create Datadog log pipeline to parse `[timestamp] [script-name] [level] message` format
- Dashboard: error rates by script, by machine, over time
- Monitors: alert on `[error]` in any setup script (email or Slack)
- Log Archives: configure S3/GCS archive for long-term storage at lower cost

### Phase 3: CI Visibility

- Add `datadog-ci` to GitHub Actions workflows
- Trace `aitools install` and `aitools gitpull` as pipeline executions
- Custom tags: machine, platform, tool versions
- Pipeline-level dashboards: run duration trends, failure rates

### Phase 4: MCP integration

- Enable Datadog MCP server in Claude Code and Cursor
- Document usage patterns: "show me errors from last deploy", "what failed on Windows this week"
- Evaluate MCP Preview access (may require Datadog allowlisting)

### Phase 5: Post-credits migration planning

- Evaluate Axiom adoption timing (before credits expire)
- Implement Axiom as secondary log sink (dual-write during transition)
- Swap primary endpoint from Datadog to Axiom
- Evaluate Axiom MCP server (Pro plan requirement vs free tier limitation)

## Integration Pattern

The lightest possible integration -- zero new dependencies beyond curl/Invoke-RestMethod:

```bash
# Bash (aitools-lib.sh) -- conceptual
log_ship() {
    local api_key
    api_key=$(read_config_key "$HOME/.aitools/config.json" "datadogApiKey") || return 0
    # POST collected log lines as JSON array
    curl -s -X POST "https://http-intake.logs.datadoghq.com/api/v2/logs" \
        -H "DD-API-KEY: $api_key" \
        -H "Content-Type: application/json" \
        -d "$LOG_BUFFER" || log_warn "Failed to ship logs to Datadog"
}
```

```powershell
# PowerShell (aitools-lib.ps1) -- conceptual
function LogShip {
    $apiKey = ReadConfigKey "$env:USERPROFILE\.aitools\config.json" "datadogApiKey"
    if (-not $apiKey) { return }
    try {
        Invoke-RestMethod -Uri "https://http-intake.logs.datadoghq.com/api/v2/logs" `
            -Method POST -Headers @{ "DD-API-KEY" = $apiKey } `
            -ContentType "application/json" -Body $script:logBuffer
    } catch {
        LogWarn "Failed to ship logs to Datadog: $_"
    }
}
```

## Alternatives Evaluated

| Tool | Free Tier | MCP Server | Verdict |
|------|-----------|------------|---------|
| **Axiom** | 500 GB/mo, 30-day retention | Official (Pro+ plans) | Long-term target after Datadog credits |
| **Better Stack** | 3 GB, 3-day retention | Official | Good DX, Vercel integration. Limited free tier. |
| **Seq** | Free single-user (self-hosted) | Community only | Best for self-hosted. No official MCP. |
| **Grafana/Loki** | 50 GB/mo | Official (3 servers) | Good open-source option. Heavier setup. |
| **New Relic** | 100 GB/mo | Official (preview) | Generous free tier. Complex UI. |
| **SigNoz** | Open source | None | Best OSS option. No MCP. |
| **Splunk** | Trial only | Official (beta) | Enterprise pricing, overkill. |
| **Honeycomb** | Trial/limited | Official (Enterprise only) | Trace-focused, not log-focused. |

## Config Key

New key in `~/.aitools/config.json`:

```json
{
  "datadogApiKey": "your-dd-api-key-here"
}
```

Set during `aitools install` or manually. When absent, log shipping is silently disabled.
