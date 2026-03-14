# Nobul Auth0 Platform

**Intent**: **Purpose**: Centralized identity and credential management for all
Nobul projects — CLI tools, web apps, and multi-machine developer workflows.
**Scope**: Auth0 tenant setup, `aitools auth` CLI, provider token management,
web app migration (vcard, credits), and multi-machine/RBAC. NOT individual tool
installer changes (those are tracked per-tool). **Audience**: Anyone implementing
auth features in aitools or Nobul web apps.

**Linked**: Gap #23 (credential storage undocumented; keychain prompts block install)

## Vision

One Auth0 tenant serving all Nobul projects. OAuth provider registrations
done once. Each app enables the connections it needs. aitools CLI gets
centralized credential management, web apps get authentication gating,
and the whole stack shares one identity layer.

## Auth0 Tenant

| Setting | Value |
|---------|-------|
| Tenant | `nobul.auth0.com` (migrate to `auth.nobul.tech` custom domain) |
| Plan | Auth0 for Startups (100K MAU, 12 months free) |
| After 12 months | Auto-downgrades to Free (25K MAU) |

## Provider Registrations (done once, shared across all apps)

### Social connections (Auth0 built-in)

| Provider | Registration URL | Used by |
|----------|-----------------|---------|
| GitHub | `github.com/settings/developers` → New OAuth App | aitools |
| Microsoft | `portal.azure.com` → App registrations | vcard, nobul-ops |
| Google | `console.cloud.google.com` → Credentials | vcard, credits |

### Custom OAuth2 connections (Auth0 custom social)

| Provider | Registration URL | Used by |
|----------|-----------------|---------|
| Vercel | `vercel.com/integrations/new` | aitools |
| Datadog | `app.datadoghq.com/apps` | aitools |

### Not via Auth0 (no OAuth provider API)

| Provider | Method | Used by |
|----------|--------|---------|
| Modal | Direct browser flow → `~/.modal.toml` | aitools |

## Applications

| App | Auth0 type | Connections | Auth flow |
|-----|-----------|-------------|-----------|
| `aitools` CLI | Native | GitHub, Vercel, Datadog | Device Authorization |
| `vcard.nobul.tech` | SPA | Microsoft, Google | PKCE redirect |
| `credits.nobul.tech` | SPA | Google (+ any you enable) | PKCE redirect |
| `nobul-ops` | Regular Web | All | Server-side redirect |

## How aitools gets provider tokens

Auth0 stores IdP (identity provider) access tokens when users authenticate
through social/custom connections. aitools retrieves them via the
Management API:

```
POST https://auth.nobul.tech/oauth/token
  → Auth0 access token (with read:user_idp_tokens scope)

GET https://auth.nobul.tech/api/v2/users/{user_id}
  → response.identities[].access_token (GitHub token, Vercel token, etc.)
```

These are the ACTUAL provider tokens with the scopes we requested.
Export as env vars → CLI tools use them instead of keychain.

## aitools CLI Interface

```bash
# First-time setup: authenticate with Auth0
aitools auth login
#   Opens browser → auth.nobul.tech Universal Login
#   User authenticates with GitHub, Vercel, Datadog
#   Tokens stored locally

# Check status (reads local files, no keychain)
aitools auth status
#   auth0          ✓ jose@nobul.tech
#   github.com     ✓ nobul-jose (repo, gist, workflow)
#   vercel         ✓ nobul-jose
#   datadog        ✗ not connected
#   modal          ✓ ~/.modal.toml present

# Connect a specific provider
aitools auth login datadog

# Refresh expired tokens
aitools auth refresh

# Revoke and clean up
aitools auth revoke
aitools auth revoke github

# Export to current shell (done automatically via shell integration)
eval $(aitools auth env)
```

## Token Storage (local)

```
~/.aitools/auth/
├── session.json        # Auth0 refresh token + user_id
├── github.json         # { "access_token": "gho_...", "scopes": [...], "expires_at": null }
├── vercel.json         # { "access_token": "...", "expires_at": "..." }
├── datadog.json        # { "access_token": "...", "expires_at": "..." }
└── .gitignore          # Everything in this dir is sensitive
```

- File permissions: `600` (owner only)
- NOT backed up in dotprofile — sensitive credentials
- Auth0 refresh token enables silent re-auth on token expiry
- `aitools auth status` reads file metadata only

## Shell Integration

Extend existing `aitools shell-init`:

```bash
# ~/.bashrc / ~/.zshrc (already present):
eval "$(/Users/pepe/.local/bin/aitools shell-init)"

# shell-init now also exports (when tokens exist):
export GH_TOKEN="$(cat ~/.aitools/auth/github.json | jq -r .access_token 2>/dev/null)"
export VERCEL_TOKEN="$(cat ~/.aitools/auth/vercel.json | jq -r .access_token 2>/dev/null)"
export DD_ACCESS_TOKEN="$(cat ~/.aitools/auth/datadog.json | jq -r .access_token 2>/dev/null)"
```

When set, CLI tools skip keychain:
- `gh` checks `GH_TOKEN` first → keyring never touched
- `vercel` checks `VERCEL_TOKEN` first
- `pup` checks `DD_ACCESS_TOKEN` first

## vcard.nobul.tech Migration

vcard already has Microsoft/Google OAuth. Migration path:
1. Register vcard as an Auth0 SPA application
2. Enable Microsoft + Google connections for vcard app
3. Replace direct OAuth implementation with Auth0 SDK
4. Benefits: shared user pool with other Nobul apps, unified login page,
   Auth0 handles token refresh/rotation

## credits.nobul.tech Auth Gating

1. Register credits as an Auth0 SPA application
2. Enable Google connection (or whatever providers you want)
3. Auth0 SDK handles login/logout
4. Use Auth0 RBAC for access control (who can view/manage credits)
5. Organizations feature for per-team credit management

## Implementation Phases

### Phase 0: Auth0 Tenant Setup

- Configure tenant at auth0.com (already provisioned)
- Set up custom domain: `auth.nobul.tech`
- Register OAuth apps with GitHub, Vercel, Datadog (one-time)
- Configure social connections + custom connections in Auth0 dashboard
- Create `aitools` Native Application in Auth0

### Phase 1: `aitools auth` MVP — GitHub only

- Implement device authorization flow in `scripts/aitools-auth.sh/.ps1`
- Add `auth` subcommand to `scripts/aitools` and `scripts/aitools.ps1`
- Store Auth0 session + GitHub token in `~/.aitools/auth/`
- Export `GH_TOKEN` in shell integration
- Remove `gh auth status` keychain check from install
- Verify: `gh auth status` shows token-based auth, no keychain prompt

### Phase 2: Multi-provider (Vercel + Datadog)

- Add custom OAuth connections in Auth0 for Vercel, Datadog
- Extend `aitools auth` for multi-provider login
- Store per-provider tokens
- Export `VERCEL_TOKEN`, `DD_ACCESS_TOKEN`
- Remove remaining keychain-hitting auth checks from setup scripts

### Phase 3: Token lifecycle

- Background refresh during `aitools` sync (check expiry, use refresh token)
- `aitools auth status` with expiry info
- Graceful degradation when Auth0 unreachable (use cached tokens)
- Token rotation policies

### Phase 4: Web apps (vcard, credits)

- Migrate vcard.nobul.tech to Auth0 SDK
- Add auth gating to credits.nobul.tech
- Shared user pool across CLI + web

### Phase 5: Multi-machine + Organizations

- Auth0 knows user's connected providers → fast re-auth on new machine
- Organizations for team/B2B features
- RBAC for credits.nobul.tech access control
- Audit log via Auth0 logs API

## Dependencies

| Dependency | Status |
|-----------|--------|
| Auth0 tenant (Nobul LLC) | Provisioned (Startups plan) |
| Auth0 SDK (`auth0` npm or Python) | Install during Phase 0 |
| GitHub OAuth App | Register during Phase 0 |
| Vercel Integration | Register during Phase 2 |
| Datadog OAuth App | Register during Phase 2 |
| `jq` (for token parsing) | Already available via Homebrew |
| Custom domain DNS | Configure `auth.nobul.tech` CNAME |

## Key Files (aitools repo)

| File | Purpose |
|------|---------|
| `scripts/aitools-auth.sh` | Auth subcommand (bash) |
| `scripts/aitools-auth.ps1` | Auth subcommand (PS1) |
| `scripts/aitools` | Add `auth` dispatch |
| `scripts/aitools.ps1` | Add `auth` dispatch |
| `shared/shell/aliases.sh` | Token export in shell-init |
| `shared/shell/aliases.ps1` | Token export in shell-init |
| `reference/auth-providers.json` | Provider registry (scopes, endpoints, Auth0 connection IDs) |
| `.claude/rules/credential-management.md` | New rule for credential handling |
| `reference/tool-registry.md` | Update auth sections per tool |

## Framework

Extends Managed File Deployment (Configuration Management discipline):
- Auth File Policy updated: aitools-managed credentials in `~/.aitools/auth/`
- Setup scripts check env vars first, skip keychain when present
- Adopts concepts from: git-credential (pluggable backends), OWASP Secrets
  Management (platform-native + fallback), Auth0 Organizations (B2B delegation)
