# Tool Lifecycle

**Intent**: **Purpose**: Document the framework for evaluating,
approving, integrating, maintaining, and health-tracking managed tools,
including the desired-state model behind the tool support decision tree.
**Scope**: What software asset management and configuration management
principles we adopted and why. NOT the evaluation requirements
(`@.claude/rules/tool-evaluation.md`). NOT the operational directives
(`@.claude/rules/tool-lifecycle.md`). NOT the decision tree detail
(`@reference/tool-support-decision-tree.md`). NOT tool data (use
`/tool-registry` skill). **Audience**: Agents onboarding new tools, agents
running `/tool-adopt`, framework adoption work.

> DRAFT — needs commander approval (modified intent statement).

## Source Discipline

Software asset management — lifecycle phases, approval gates,
deprecation paths. Tools are assets with costs (maintenance, security
surface, PATH complexity) and benefits. The lifecycle gates cost
evaluation before committing to benefits.

Extended with provenance verification (supply chain security) and
health flags (continuous monitoring) to address the reality that
tools degrade over time — vendors deprecate runtimes, maintainers
go inactive, install methods change upstream.

Extended (2026-10) with configuration management's desired-state
reconciliation: ITIL service asset and configuration management (a
definitive record of approved configuration items and the authorised way
to change them) and desired state configuration as practised by
PowerShell DSC and Ansible (declare the target state, test the actual
state, change only what differs, idempotently). Software asset
management's exception register (an approved deviation from the
standard, with owner and date) supplies the tool exception.

## How We Adopted It

- **5-phase lifecycle** → Discovery, Evaluation, Approved, Integrated,
  Deprecated
- **Phase 2 gate** → hard stop requiring user approval before
  integration code. Prevents sunk-cost commitment.
- **Per-platform status** → tools approved on one platform may still
  be evaluating on another; per-environment status overrides it
- **Install method discovery** → upstream install commands verified
  via official docs. Process in `/tool-eval` skill
- **Health flags** → continuous monitoring adapted as per-platform
  health indicators. Criteria in `/tool-eval` skill, requirements
  in `@.claude/rules/tool-evaluation.md`
- **Provenance verification** → supply chain security adapted as
  install method traceability. Process in `/tool-eval` skill
- **Evaluation provenance** → decision rationale preserved in
  `reference/evaluations/`. Process in `/tool-eval` skill

### Tool support (desired-state reconciliation)

| Discipline concept | Harness artifact |
|--------------------|------------------|
| Definitive record of approved items and their authorised change method | Tool registry: one preferred method per platform and environment, plus detection signatures and removal recipes for every known method (`/tool-registry`) |
| Test actual state before changing it | Install-method detection: none / preferred / non-preferred / unknown |
| Change only what differs, idempotently | Decision tree: install when absent, update when preferred, otherwise ask (`@reference/tool-support-decision-tree.md`) |
| Change control for deviations | Interactive menu for non-preferred and unknown installs; non-interactive runs change nothing and report WARN + ACTION |
| Exception register | Tool exception per machine in the dotprofile profile (`profiles.<alias>.toolExceptions`) |
| Release management | Update channels (`latest-stable` default, `lts`, `pinned-*`, `vendor-auto`) |
| Make-before-break change | Replace installs and verifies the preferred copy before removing the old one (issue #12) |
| Verification after change | Post-check: the command resolves to the managed binary (script-standards Standard 4) |

What we did not adopt: automatic remediation of unknown installs (DSC would
enforce the declared state; the harness never removes what it cannot
identify), and periodic drift scans outside `aitools install` (the check
runs when the installer runs).

## How It's Maintained

- Lifecycle and update directives in `@.claude/rules/tool-lifecycle.md`
- Evaluation principles in `@.claude/rules/tool-evaluation.md`
- Decision tree, schema 1.1 fields, helper contract in
  `@reference/tool-support-decision-tree.md`
- Post-push checks verify tool command availability and version
- Pre-commit "Tool support conformance" step validates registry data the
  tree reads and setup-script conformance
- `/tool-registry` skill provides governed access to tool data
- `/tool-eval` skill runs evaluations and updates health flags
- `/tool-adopt` skill integrates a tool and migrates setup scripts
- Install methods re-verified via Chrome DevTools skill when modifying
  setup scripts

## Implementing Artifacts

- `@.claude/rules/tool-lifecycle.md` (operational rule, update policy, trigger directives)
- `@.claude/rules/tool-evaluation.md` (evaluation principles)
- `@reference/tool-support-decision-tree.md` (decision tree detail)
- `.claude/skills/tool-registry/SKILL.md` (registry data access)
- `.claude/skills/tool-eval/SKILL.md` (evaluation process)
- `.claude/skills/tool-adopt/SKILL.md` (integration and script migration)
- `@reference/tool-evaluation-criteria.md` (evaluation framework)
- `@reference/tool-evaluation-playbook.md` (install discovery process)
- `reference/evaluations/` (evaluation research)
- `scripts/aitools-lib.sh` / `.ps1` tool support helpers (`tool_support_run` / `Invoke-ToolSupport`)
- `scripts/setup-*.sh/.ps1` (per-tool setup scripts)
- `scripts/gen-tool-specs.py` and `generated/tool-specs/` (registry data for setup scripts)
- `scripts/check-pre-commit.sh/.ps1` "Tool support conformance" step (pre-commit check)
- Planned hook (detection layer): PreToolUse reminder on edits to `scripts/setup-*` (spec in the decision tree reference)

## Cross-References

- Framework registry: `/frameworks` skill
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Governed data access: `@.claude/rules/governed-data-access.md`
- Tool operations (resolution, verification): `@reference/framework-tool-ops.md`
- Managed file deployment (the other "adopt"): `@reference/framework-managed-file-deployment.md`
