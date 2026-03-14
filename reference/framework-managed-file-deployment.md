# Managed File Deployment

**Intent**: **Purpose**: Document the framework for deploying and
reconciling harness content across machines. **Scope**: What
configuration management principles we adopted and why. NOT the state
machine, menu options, or return value contracts (those are in
`@reference/managed-file-deployment.md` and
`@.claude/rules/managed-file-deployment.md`). **Audience**: Agents
working on deployment scripts, framework adoption work.

## Source Discipline

Configuration management — drift detection, reconciliation, and state
machines. Managed configurations deployed to multiple machines drift
from source. The system must detect drift, present reconciliation
options, and track outcomes.

## How We Adopted It

- **Deployment types** → markdown, JSON config, shell script — each
  with appropriate merge strategy
- **Interactive review** → diff display for text, field-level review
  for JSON. User sees what changes before it happens.
- **Adoption flow** → user modifications flow back to source (adopt),
  preventing fork divergence
- **Backup before write** → every deployment backs up the target
- **Three-outcome tracking** → every deployment resolves to created,
  updated, or unchanged — no silent ambiguity
- **Non-interactive fallback** → `AITOOLS_FORCE` env var and
  non-terminal stdin auto-select overwrite for CI/MDM

## How It's Maintained

- Deployment type table updated when new file types are onboarded
- Menu parity audit (check-post-push step 29) verifies PS1 and bash
  menus match
- Return value coverage audit (step 30) verifies all callers handle
  all outcomes
- `@reference/managed-file-deployment.md` is the state machine spec

## Implementing Artifacts

- `@.claude/rules/managed-file-deployment.md` (deployment type rule)
- `@reference/managed-file-deployment.md` (state machine spec)
- `@.claude/rules/interactive-menus.md` (menu patterns)
- `@.claude/rules/config-file-safety.md` (JSON write safety)
- `deploy_managed_file()` / `Deploy-ManagedFile` in aitools-lib

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Source-of-truth protection: `@reference/framework-source-of-truth.md`
