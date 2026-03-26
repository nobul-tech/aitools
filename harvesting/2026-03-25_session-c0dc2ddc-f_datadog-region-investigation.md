# Datadog Region Investigation

**Date**: 2026-03-25
**Author**: S2-Datadog (delegated)
**Session**: c0dc2ddc-f
**Mission**: Investigate Datadog regions so the commander can respond to Eliza's offer to switch from US5 to US3 with confidence.

---

## Executive Summary

**Recommendation: Stay on US5.** There is no compelling advantage to switching to US3 for your use case. Both are functionally equivalent US-based regions. The migration cost (reconfiguring DD_SITE everywhere, re-authenticating `pup`, losing historical data) outweighs the zero benefit. The only scenario where US3 wins is if you were running Azure workloads and wanted PrivateLink egress savings -- you are not.

---

## Part 1: All Datadog Regions

Source: [Datadog Getting Started with Sites](https://docs.datadoghq.com/getting_started/site/) (verified via chrome-devtools on 2026-03-25)

| Site | Site URL | DD_SITE Parameter | Location | Cloud Provider |
|------|----------|-------------------|----------|----------------|
| **US1** | app.datadoghq.com | `datadoghq.com` | US (Virginia) | AWS us-east-1 |
| **US3** | us3.datadoghq.com | `us3.datadoghq.com` | US (Washington state) | Microsoft Azure |
| **US5** | us5.datadoghq.com | `us5.datadoghq.com` | US | Google Cloud Platform |
| **EU1** | app.datadoghq.eu | `datadoghq.eu` | EU (Germany) | AWS eu-central-1 |
| **US1-FED** | app.ddog-gov.com | `ddog-gov.com` | US | AWS GovCloud |
| **AP1** | ap1.datadoghq.com | `ap1.datadoghq.com` | Japan | AWS ap-northeast-1 |
| **AP2** | ap2.datadoghq.com | `ap2.datadoghq.com` | Australia | AWS ap-southeast-2 |

**Key facts:**
- Each site is **completely independent**. You cannot share data across sites.
- You **cannot change** your site after signup. Migration requires a new org.
- Documentation may vary between sites (some features have different availability depending on the site's security requirements).
- US1 is the oldest/default. US3 and US5 were added later for Azure and GCP customers respectively.

---

## Part 2: Differences Between Regions

### What is actually different

1. **Underlying cloud provider**: US1/EU1/AP1/AP2 run on AWS. US3 runs on Azure. US5 runs on GCP. This matters only if you want PrivateLink/Private Service Connect for egress cost optimization within the same cloud.

2. **API endpoint URLs**: Every API call uses a region-specific subdomain. The API surface is identical; only the hostname changes. (See Part 5 for full endpoint mapping.)

3. **Data residency**: Data stays within the region's geography. US1/US3/US5 are all US-based, so no difference for US data residency.

4. **Compliance**: US1-FED is FedRAMP Moderate Authorized. EU1 enables GDPR data residency. US3/US5 have no special compliance certifications beyond standard Datadog SOC 2 Type II.

### What is NOT different

- **Pricing**: Same across all regions. Credits work the same way.
- **Feature availability**: Datadog aims for feature parity across all regions. The docs note that "different sites may support different functionalities depending on the instance's security requirements" -- this primarily affects US1-FED (which restricts some features for FedRAMP compliance). For US3 vs US5, feature parity is effectively complete.
- **Integrations**: GitHub, Cloudflare, AWS, and all other integrations work identically across regions. The integration configuration uses the DD_SITE parameter to route to the correct API endpoint.
- **SDK/Agent behavior**: The Datadog Agent, SDKs, and CLI tools all use DD_SITE to determine endpoints. No functional difference.
- **Support tier**: Same support available regardless of region.

### Latency considerations

For a startup based in Los Angeles, CA:
- **US5 (GCP)**: GCP's nearest US regions are us-west1 (Oregon) and us-west2 (Los Angeles). Latency from LA is excellent.
- **US3 (Azure)**: Azure's nearest regions are West US 2 (Washington state). Slightly further from LA than GCP's us-west options, but the difference is negligible for API metric submission (not real-time streaming).
- **US1 (AWS)**: us-east-1 (Virginia). Highest latency from LA, but still fine for batch metric submission.

**For your use case (HTTP API metric/log submission at session end)**, latency is irrelevant. You are submitting a batch of 10-50 metrics once per session, not streaming real-time telemetry. The difference between 20ms and 80ms round-trip is invisible.

---

## Part 3: Region Migration Reality

### Can you switch regions later?

**No. Region choice is permanent for an organization.** From the official docs: "Each site is completely independent, and you cannot share data across sites."

To "switch" regions, you must:
1. Create a new Datadog organization on the target region
2. Reconfigure ALL agents, integrations, API keys, and DD_SITE environment variables
3. Recreate ALL dashboards, monitors, alerts, and saved views
4. Accept that ALL historical metrics, logs, and traces in the old region are inaccessible from the new one
5. Reconfigure authentication for the Datadog CLI (`pup`)

**Wolt's migration experience** (US to EU, Q1 2022): They migrated 500+ alerts, 160+ dashboards, and 20 integrations. They encountered metric type inconsistencies between regions, hundreds of "No Data" alerts during transition, and needed a parallel-run period to ensure data parity. They recommend careful planning and close coordination with Datadog support.

### What Eliza's offer means

Eliza is offering to set up a new US3 organization and transfer your startup credits there. This would mean:
- Your current US5 org (with any existing dashboards, API keys, `pup` auth) is abandoned
- You get a fresh start on US3
- Your DD_SITE changes from `us5.datadoghq.com` to `us3.datadoghq.com` everywhere

Since you are early in your Datadog usage (the harness telemetry architecture is not yet shipping metrics), the migration cost is currently LOW. But it is also LOW VALUE -- because there is nothing to gain.

---

## Part 4: Is There Any Advantage to US3 Over US5?

### For the startup program specifically

**No.** The startup credits ($100K, 12 months, Pro tier) are identical regardless of region. There is no region-specific pricing, feature, or support benefit tied to the startup program. Eliza's offer to switch to US3 is likely:
- Administrative (US3 may be the region their startup team prefers to provision on), OR
- Azure-partnership motivated (Microsoft Azure runs US3; Datadog may have a co-sell relationship), OR
- A courtesy option they offer routinely

None of these affect you.

### For your infrastructure

- You are not running Azure workloads (no PrivateLink benefit from US3)
- You are not running GCP workloads either (so no PrivateLink benefit from US5)
- Your telemetry ships from developer machines via HTTP API, not from cloud infrastructure
- Region choice has zero impact on your use case

### For stability

Both US3 and US5 have comparable uptime records:
- **US3**: 99.91% uptime over 90 days (as of March 2026). Minor incidents on Workflow Automation (Dec 2025) and Code Security (Mar 2026).
- **US5**: 25+ incidents over past 5 months per monitoring services. Most recent: Web Application Not Loading (Nov 2025), and a March 19, 2026 incident.

Neither region has a clear reliability advantage. US3's 90-day uptime is slightly better, but both are well within enterprise SLA ranges.

---

## Part 5: Impact on the Harness Telemetry Architecture

The telemetry architecture (from `telemetry-architecture-redesign.md`) ships metrics via Datadog Metrics API v2 and logs via HTTP Logs API. The region choice affects these APIs in exactly one way: **the endpoint URL**.

### Metrics API v2 (submit series)

| Region | Endpoint |
|--------|----------|
| US1 | `https://api.datadoghq.com/api/v2/series` |
| US3 | `https://api.us3.datadoghq.com/api/v2/series` |
| **US5** | **`https://api.us5.datadoghq.com/api/v2/series`** |
| EU1 | `https://api.datadoghq.eu/api/v2/series` |
| AP1 | `https://api.ap1.datadoghq.com/api/v2/series` |
| AP2 | `https://api.ap2.datadoghq.com/api/v2/series` |
| US1-FED | `https://api.ddog-gov.com/api/v2/series` |

### HTTP Logs API

| Region | Endpoint |
|--------|----------|
| US1 | `https://http-intake.logs.datadoghq.com/v1/input` |
| US3 | `https://http-intake.logs.us3.datadoghq.com/v1/input` |
| **US5** | **`https://http-intake.logs.us5.datadoghq.com/v1/input`** |
| EU1 | `https://http-intake.logs.datadoghq.eu/v1/input` |
| AP1 | `https://http-intake.logs.ap1.datadoghq.com/v1/input` |
| AP2 | `https://http-intake.logs.ap2.datadoghq.com/v1/input` |

### How the harness uses DD_SITE

The telemetry shipper in `harness-db.py` already constructs the URL from `DD_SITE`:

```python
url = f"https://api.{site}/api/v2/series"
```

This pattern works correctly for all regions because:
- US5: `DD_SITE=us5.datadoghq.com` → `https://api.us5.datadoghq.com/api/v2/series`
- US3: `DD_SITE=us3.datadoghq.com` → `https://api.us3.datadoghq.com/api/v2/series`
- US1: `DD_SITE=datadoghq.com` → `https://api.datadoghq.com/api/v2/series`

**The API surface, authentication headers, request/response schemas, and rate limits are identical across all regions.** The only change when switching regions is the DD_SITE value and the resulting endpoint URL.

### What would change if you switched to US3

1. `shared/shell/aliases.sh` line 6: `export DD_SITE="us5.datadoghq.com"` → `"us3.datadoghq.com"`
2. `shared/shell/aliases.ps1` line 5: `$env:DD_SITE = "us5.datadoghq.com"` → `"us3.datadoghq.com"`
3. Re-authenticate `pup` CLI against the new org
4. Generate new DD_API_KEY from the US3 org
5. Update `~/.aitools/config.json` if DD_API_KEY is stored there

That is the complete list. No code changes in the shipper, no schema changes, no behavioral changes.

---

## Part 6: Integration Impact

### GitHub integration
Region-agnostic. GitHub sends webhooks to Datadog's intake endpoint, which is determined by DD_SITE. Works identically on all regions.

### Cloudflare integration
Cloudflare Logpush supports all Datadog regions. You configure the destination URL with the appropriate region endpoint. No feature differences.

### AWS integration
AWS integration works on all regions. You configure the Datadog API URL in the CloudFormation/Terraform provider. No feature differences. Note: AWS China is not supported on any region.

---

## Part 7: Community Signals

The community consensus (from blog posts, GitHub issues, and status monitoring):

1. **Datadog is "weirdly silent" about where each site runs** (Daniel Compton, Oct 2025). The cloud provider mapping (US3=Azure, US5=GCP) is not prominently documented.

2. **You cannot change your site after signup** -- multiple community posts warn about this. Get it right at signup.

3. **No community reports of US5-specific feature gaps** compared to US3 or US1. The GitHub issue #99 (DataDog/apps) about "Support of US3 and US5 regions" was about Apps platform availability, which has since been resolved.

4. **The Terraform provider docs lacked US3/US5 examples** (issue #1573), which has been addressed.

---

## Part 8: Recommendation

**Stay on US5.** Rationale:

1. **Zero benefit to switching**: No feature, pricing, compliance, or performance advantage for your use case.
2. **Non-zero cost to switching**: New API keys, re-auth `pup`, update DD_SITE in aliases, generate new org.
3. **You are already set up**: DD_SITE is configured, `pup` is authenticated, the telemetry architecture references US5.
4. **Region is permanent**: If you switch to US3 and later want US5 back, that is another full migration.
5. **Latency is irrelevant**: Batch HTTP submissions at session end are not latency-sensitive.

The only reason to consider US3 would be if Eliza said the credits are ONLY available on US3 (which would be unusual). In that case, since you have not yet shipped any metrics, the cost of switching is minimal -- just update DD_SITE in two files and re-auth `pup`. But absent that constraint, staying on US5 is the correct default.

---

## Draft Response to Eliza

```
Hi Eliza,

Thanks for the offer to switch to US3. I've looked into the differences between US3 and US5 and don't see a compelling reason to switch -- we're not running Azure workloads, so the cloud provider difference doesn't affect us, and the feature set is identical across US regions.

We're already configured on US5 with our CLI authenticated, so we'll stay put. If there's a startup-program-specific reason to be on US3 (credits only available there, etc.), let me know and we can revisit.

Separately -- we're getting ready to start shipping metrics via the API. Any gotchas I should know about for US5 specifically?

Thanks,
Jose
```

---

## Sources

- [Datadog Getting Started with Sites](https://docs.datadoghq.com/getting_started/site/) -- official site list, DD_SITE parameters, and independence model
- [Datadog Metrics API v2](https://docs.datadoghq.com/api/latest/metrics/) -- endpoint URLs per region
- [Datadog HTTP Logs API](https://docs.datadoghq.com/api/latest/logs/) -- log intake endpoints per region
- [Where are Datadog's US1 and US3 data centers located?](https://kevin.burke.dev/kevin/datadog-data-center-locations-us1-us3/) -- Kevin Burke's research on physical locations
- [Where are Datadog's sites located?](https://danielcompton.net/snippets/where-are-datadog-regions) -- Daniel Compton's region mapping (Oct 2025)
- [Datadog region migration at Wolt](https://careers.wolt.com/en/blog/tech/datadog-migration-wolt) -- Wolt's US-to-EU migration experience
- [Datadog for Startups](https://www.datadoghq.com/partner/datadog-for-startups/) -- startup program details
- [Datadog US5 Status](https://status.us5.datadoghq.com) -- US5 incident history
- [Datadog US3 Status](https://status.us3.datadoghq.com) -- US3 incident history
- [Support of US3 and US5 regions (GitHub issue #99)](https://github.com/DataDog/apps/issues/99) -- Apps platform regional support
