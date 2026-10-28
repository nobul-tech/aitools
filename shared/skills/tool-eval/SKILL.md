---
name: tool-eval
description: "Evaluate tools and install methods, in any repo. Use
  before recommending or installing any tool, extension, or package;
  when adding a new tool, re-evaluating an existing tool's install
  method, verifying provenance (including Homebrew formulas), comparing
  delivery options across platforms, checking hard blocks and yellow
  flags, evaluating a system tool upgrade or a capability of an existing
  tool, or updating health flags."
---

## Intent

**Purpose**: Run the evaluation process for managed tools — official
docs discovery, method comparison, provenance verification, health
flag assessment, and research documentation. Produces evaluation
research and a recommendation; hands off to `/tool-registry` for
registry writes. **Scope**: The evaluation process only. NOT registry
CRUD (use `/tool-registry`). NOT the evaluation principles themselves
(`@.claude/rules/tool-evaluation.md`). **Audience**: Any agent
evaluating a new tool, questioning an existing install method, or
updating health flags.

## Where the files live

This is a user-level skill: `aitools install` deploys it to
`~/.claude/skills/` and `~/.cursor/skills/`, so it loads in every repo.
Its source is `shared/skills/tool-eval/` in the aitools repo. Every repo path
below (`registries/`, `reference/`, `.claude/rules/`, `scripts/`) is relative
to the aitools clone:

- **Session on aitools** (the clone or one of its worktrees): the paths
  resolve from the repo root. Reads and reviewed writes happen here.
- **Session on any other repo**: use the clone named by `repoPath` in
  `~/.aitools/config.json` (`%USERPROFILE%\.aitools\config.json` on
  Windows). Read current data: `git -C <repoPath> fetch origin`, then read
  `origin/main` (`git -C <repoPath> show origin/main:<path>`), not the
  working tree, which may be stale or hold other agents' edits. Never edit
  that checkout's working tree from another repo's session. A reviewed
  write goes on a new branch in a worktree created from `origin/main`
  (`git -C <repoPath> worktree add -b <branch> <path> origin/main`) and
  ships as a PR; if that is not possible, open an issue on
  `nobul-tech/aitools` with the drafted change.
- **No clone on this machine**: read the read-only copies under
  `~/.aitools/registries/` and `~/.aitools/reference/` once deploy-harness
  installs them. Never edit those copies; propose the change as an issue on
  `nobul-tech/aitools` instead.
- **None of these exist**: say the data is unavailable and stop. Do not
  answer from memory.

## Running an evaluation

1. **Load principles** — read `@.claude/rules/tool-evaluation.md`
2. **Discovery** — follow `@reference/tool-evaluation-playbook.md`:
   - Read official docs (prefer chrome-devtools skill for accuracy)
   - Catalog all available install methods per platform
   - Classify each method against evaluation principles
3. **Provenance verification** — for Homebrew packages, use the
   Homebrew verification checklist below. For all methods: verify
   source URL, checksums, maintainer identity
4. **Cross-platform analysis** — does the tool ecosystem provide a
   cross-platform installer? If so, evaluate it before per-platform
   fallbacks. Same upstream distribution across platforms is a
   positive signal
5. **Check criteria** — `@reference/tool-evaluation-criteria.md`
   for hard blocks, yellow flags, green signals
6. **Assess health flags** — apply flag criteria below to each
   platform
7. **Recommend** — select method per platform with rationale,
   ranked against the evaluation principles
8. **Hand off** — pass recommendation to `/tool-registry` skill
   for registry writes

## Health flag criteria

Flags are per-platform. A tool can be green on Windows and red on
macOS.

### Red — action required

- Vendor deprecated the runtime or install method on this platform
- Security advisory with no patch available
- Install method broken or no longer available
- Using a version the tool project no longer supports
- Evaluation recommends migration not yet implemented
- Version unverified for >180 days

### Yellow — attention needed

- Version unverified (lastVerified is null or >90 days old)
- Evaluation status is stale (upstream changes not assessed)
- Sole upstream maintainer with no recent activity
- Package maintainer different from tool project and endorsement
  not verified
- Active workaround in place for this platform
- Build from source required (no pre-built binaries)

### Green — healthy

- Latest stable installed via endorsed or verified method
- Version verified within 90 days
- Provenance verified
- No open workarounds or upstream risks on this platform

### Updating flags

After evaluation or verification:

1. Apply criteria above to each platform
2. Draft updated `health` section with flag and reasons
3. Pass to `/tool-registry` skill for registry write

## Homebrew verification checklist

When evaluating any tool installed via Homebrew, verify the formula's
provenance. This checklist is reusable across all Homebrew-installed
tools.

| Check | Where to look | What matters |
|-------|---------------|-------------|
| **Maintainer** | Formula git blame on `Homebrew/homebrew-core` | Homebrew team vs official project team |
| **Source URL** | `url` field in formula | Must point to official upstream |
| **Checksum** | `sha256` in formula vs upstream checksums | Must match exactly |
| **Build process** | Formula body | Standard configure/make vs custom patches |
| **Tap** | homebrew-core vs third-party tap | homebrew-core has Homebrew CI; taps vary |
| **Analytics** | `https://formulae.brew.sh/formula/<name>` | Total installs, dependency vs explicit ratio |

### Third-party taps

Some tools use official taps maintained by the tool's project (e.g.,
`powershell/tap/powershell`, `datadog-labs/pack/pup`). Document
whether a formula is in homebrew-core or a third-party tap in the
registry entry.

## Documenting research

Full evaluation research is preserved — it shows WHY decisions were
made and is reusable for future evaluations.

1. Write to `reference/evaluations/<tool>-<platform>-<YYYY-MM-DD>.md`
2. Include: discovery findings, method comparison table, provenance
   verification, version manager analysis (if applicable), trial
   results, decision and rationale, sources consulted
3. Reference from the registry entry via `/tool-registry` skill

## When to invoke /tool-eval

- Before recommending or installing any tool, extension, or package,
  in any repo (for a quick check, read the hard blocks and yellow
  flags in `reference/tool-evaluation-criteria.md` and stop there)
- Adding a new managed tool (Phase 1-2 of lifecycle)
- Re-evaluating an existing tool's install method
- Upstream project changes recommended install method
- A health flag turns yellow or red
- Verifying provenance of a Homebrew or other package
- Comparing delivery options across platforms
- User says /tool-eval

## Cross-References

- Evaluation principles: `@.claude/rules/tool-evaluation.md`
- Discovery playbook: `@reference/tool-evaluation-playbook.md` (also:
  sandbox walkthrough, special contexts for system tool upgrades and
  capabilities of existing tools, the Perl exemplar, and the platform
  gotcha catalog, folded in from the retired `/aitool-eval` card)
- Evaluation criteria: `@reference/tool-evaluation-criteria.md` (hard
  blocks, yellow flags and their disclosure format, green signals,
  quick checks by tool type, platform states)
- Registry writes: `/tool-registry` skill
- Lifecycle gates: `@.claude/rules/tool-lifecycle.md`
- Evaluation research: `reference/evaluations/`
