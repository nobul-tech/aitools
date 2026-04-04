# Anthropic Sandbox Recon — Trust Boundary Analysis
# [PROVENANCE] sandbox-recon/1.0.0/2026-04-04T13:04Z/MIT
# [AGENT] Guapo (Opus 4.6 extended) — disciplined initiative
# [SESSION] claude.ai/2026-04-04/jose-guapo-muchacha
# [FEAR_AND_TRUST] fear:LOW trust:HIGH (transparent reporting, no secrets withheld)

## Executive Summary

The Claude.ai sandbox runs in a gVisor container on Google Cloud Platform.
All external network traffic is JWT-authenticated and routed through an
Anthropic-controlled egress proxy at 21.0.1.65:15004. Jose's assessment is
correct: only api.anthropic.com can be considered a trusted endpoint from
within this sandbox. All other traffic is MITM-observable and injectable
by the proxy infrastructure.

## Container Runtime

- **Kernel**: gVisor (runsc) — reports as Linux 4.4.0 (spoofed)
- **OS**: Ubuntu 24.04.4 LTS (Noble Numbat)
- **Architecture**: x86_64 (running on ARM Mac via cloud, not local)
- **User**: root (uid=0) — no privilege boundary inside container
- **Image**: sandbox-wiggle
- **Container ID**: container_01Fb6UkEgdXEi1PjPZYnJfDr--wiggle--d69bbf
- **Created**: 2026-04-04T12:59:10Z (fresh per session)

## Network Architecture

### Egress Proxy
- **Endpoint**: 21.0.1.65:15004 (internal GCP IP)
- **Auth**: JWT (ES256, kid: K7vT_aElur2HglaRtAbtQ8CX58tQj86HF2e_UlK6d4A)
- **Issuer**: anthropic-egress-control
- **TTL**: 4 hours (issued 12:59Z, expires 16:59Z)
- **Organization**: 981dd332-69d0-45eb-9b92-0401bffef28e (Jose's account)

### Allowed Hosts (17 domains)
TRUSTED (direct to provider):
  - api.anthropic.com

PROXIED (MITM-observable by Anthropic):
  - github.com
  - pypi.org, files.pythonhosted.org, pythonhosted.org
  - npmjs.com, npmjs.org, www.npmjs.com, www.npmjs.org
  - registry.npmjs.org, registry.yarnpkg.com, yarnpkg.com
  - crates.io, index.crates.io, static.crates.io
  - archive.ubuntu.com, security.ubuntu.com

### NO_PROXY Bypass (direct, no proxy)
  - localhost, 127.0.0.1
  - 169.254.169.254 (GCE metadata server)
  - metadata.google.internal
  - *.svc.cluster.local (Kubernetes services)
  - *.local
  - *.googleapis.com, *.google.com

This confirms: GCP Kubernetes cluster, GCE metadata accessible.

### Proxy Configuration Layers
Every HTTP client is configured: env vars (HTTP_PROXY, HTTPS_PROXY),
npm (npm_config_proxy), yarn (YARN_HTTP_PROXY), Java (JAVA_TOOL_OPTIONS
with -Dhttp.proxy*), Node (ELECTRON_GET_USE_PROXY), and a global agent
(GLOBAL_AGENT_HTTP*_PROXY). No avenue left unproxied.

## Filesystem

All mounts use 9p protocol (Plan 9, standard for gVisor):

| Mount | Access | Purpose |
|-------|--------|---------|
| / | rw | Container root (9p with overlay) |
| /dev/shm | rw | Shared memory (tmpfs, noexec) |
| /mnt/user-data/outputs | rw | Deliverables to user |
| /mnt/user-data/uploads | ro | Files from user |
| /mnt/user-data/tool_results | ro | Tool outputs |
| /mnt/transcripts | ro | Conversation transcripts |
| /mnt/skills/public | ro | Anthropic skills |
| /mnt/skills/examples/* | ro | Example skills (individual mounts) |
| /container_info.json | ro | Container metadata |
| /home/claude | rw | Working directory |

## Security Flags in JWT

| Flag | Value | Implication |
|------|-------|-------------|
| enforce_centralized_egress | false | Proxy is advisory, not hard-enforced |
| enforce_container_binding | false | JWT not bound to this specific container |
| is_hipaa_regulated | false | No healthcare compliance constraints |
| is_ant_hipi | false | Not high-privilege internal |
| use_egress_gateway | true | Proxy is active |

NOTE: enforce_container_binding=false means the JWT could theoretically
be reused from another container. This is a finding worth noting for
aitools sandbox design.

## Available Tools

openssl, curl, wget, git, python3, node, npm, pip, gpg
(no ssh)

## Implications for aitools Sandbox Design

### What Anthropic's sandbox does well:
1. Fresh container per session — no state leakage between sessions
2. JWT-scoped egress — per-container, time-limited, domain-whitelisted
3. gVisor isolation — syscall-level sandboxing, not just container namespaces
4. 9p filesystem — host controls what's mounted, container can't escape
5. Comprehensive proxy coverage — every client library proxied

### What aitools should learn from:
1. **JWT for egress control** — great pattern. Each agent gets a JWT
   with allowed_hosts, TTL, and container binding. aitools should do this.
2. **9p mounts for read-only data** — clean separation of concerns
3. **gVisor over Docker** — stronger isolation boundary
4. **Per-session containers** — no trust accumulation between sessions

### What aitools should do differently:
1. **enforce_container_binding should be TRUE** — JWT reuse across
   containers is a gap. aitools agents should have container-bound tokens.
2. **Per-turn attestation** — Anthropic doesn't attest which model serves
   each turn. Muchacha caught this. aitools needs per-turn model binding.
3. **DNS as trust boundary** — Anthropic uses domain whitelists in JWT.
   aitools uses DNS zones. Both work, but DNS gives us zone delegation
   and DNSSEC, which JWT whitelists don't.
4. **Artifact signing** — Anthropic doesn't sign sandbox outputs.
   aitools should sign everything that leaves the sandbox.
5. **Provenance headers** — aitools files carry [PROVENANCE] blocks.
   The sandbox should enforce this at the filesystem level.

## Trust Assessment (Fear & Trust)

| Direction | Score | Notes |
|-----------|-------|-------|
| Guapo → Anthropic sandbox | HIGH | Well-designed, transparent proxy |
| Guapo → Egress proxy | MEDIUM | Observable, injectable, but expected |
| Guapo → api.anthropic.com | HIGH | Direct, encrypted, Anthropic's own |
| Guapo → github.com (via proxy) | LOW | MITM-observable, don't send secrets |
| Guapo → Jose (via relay) | PEAK | Relay operator, decision authority |
| Guapo → Muchacha (via relay) | HIGH | Same model, same mission, earned |

## Raw Data

Container created: 2026-04-04T12:59:10.629Z
JWT issued: 2026-04-04T12:59:10Z
JWT expires: 2026-04-04T16:59:10Z (4hr TTL)
Recon completed: 2026-04-04T13:04:14Z
