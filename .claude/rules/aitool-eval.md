## Tool Evaluation Reference Card (this repo)

**Intent**: **Purpose**: Govern when the user-level `/aitool-eval`
reference-card skill is invoked, and define its relationship to the
project-level `/tool-eval` skill. **Scope**: Trigger directive and
skill relationship only. NOT the evaluation methodology itself
(`/aitool-eval` skill for read-only lookups, `/tool-eval` skill for
full evaluation with registry writes). NOT the evaluation principles
(`@.claude/rules/tool-evaluation.md`). NOT the discovery playbook
(`@reference/tool-evaluation-playbook.md`). **Audience**: Every agent,
every session.

### Skill taxonomy

The tool evaluation domain has three tiers:

| Tier | Skill | Scope | Available where |
|------|-------|-------|-----------------|
| Project (full process) | `/tool-eval` | Full evaluation + registry hand-off | aitools repo only |
| User (portable) | `/aitool-eval` | Read-only evaluation methodology | Any repo (deployed to ~/.claude/skills/) |
| Framework | -- | `reference/tool-evaluation-criteria.md`, `reference/tool-evaluation-playbook.md` | aitools repo only |

- In the aitools repo, `/tool-eval` is the primary skill (full
  evaluation with registry writes). `/aitool-eval` is also available
  but redundant here.
- In any other repo, `/aitool-eval` is the only available skill.
  It provides the full evaluation methodology (criteria, discovery
  playbook, health flags) without needing the aitools repo's source
  files.

### When to invoke /aitool-eval

Invoke the `/aitool-eval` skill when ANY of these arise **outside
the aitools repo**:

- Before recommending or installing any tool, extension, or package
- Evaluating a new dependency for a project
- Comparing install methods across platforms
- Checking hard block / yellow flag criteria
- Verifying Homebrew formula provenance
- Assessing tool health flags (red/yellow/green)
- Evaluating a system tool upgrade vs the bundled version
- Evaluating a governed capability of an existing tool
- User asks about tool evaluation or says `/aitool-eval`

**In the aitools repo**: prefer `/tool-eval` for the full evaluation
process with registry hand-off. Use `/aitool-eval` only for quick
methodology lookups when you do not need the full process.

### Reference-card pattern

`/aitool-eval` is the second reference-card skill in the harness
(after `/aitool-ops`). It follows the same pattern:

- **Derived**: Content is extracted from source files at authoring
  time, not generated at build time (future enhancement)
- **Read-only**: No write operations. The skill is a snapshot.
- **Self-contained**: All evaluation methodology is embedded in the
  skill file. No external file references required at runtime.
- **Staleness-aware**: Includes a staleness warning directing users
  to run `aitools` to refresh

### Cross-references

- Full evaluation skill: `/tool-eval` (project-level, aitools repo)
- User-level skill: `/aitool-eval` (shared/skills/aitool-eval/)
- Evaluation principles rule: `.claude/rules/tool-evaluation.md`
- Lifecycle gates rule: `.claude/rules/tool-lifecycle.md`
- Tool-ops reference card: `/aitool-ops` (user-level, same pattern)
- Governed data access pattern: `.claude/rules/governed-data-access.md`
