## Session Scratch Files

**Intent**: **Purpose**: Govern where every agent puts the temporary files a
session produces — temp scripts, captured logs, commit messages, PR and
issue bodies — so they land in one session scratch directory instead of
being inlined in tool calls or scattered across the repo. **Scope**: The
governing principle, when to invoke the `/scratch` skill, the delegating
agent's duty to name a delegate's scratch directory, and the enforcement
layers. NOT directory layout, file naming or the commit and PR patterns
(`/scratch` skill). NOT harvest classification, promotion or pruning
(`/harvest` skill; aitools `.claude/rules/artifact-harvesting.md`). NOT the
Bash command limits themselves (USO "Simple Bash commands only", enforced
by the standing-order-guard hook). **Audience**: Every agent in every repo,
and every agent that writes a delegation prompt.

### Governing principle

A session's temporary files live in its session scratch directory,
`<root>/.scratch/session-<id>/`, and nowhere else:

- every script longer than about three lines, or that needs `&&`, `||`,
  `;`, `$(...)` or backticks;
- every captured command or check output;
- every commit message (`git commit -F`);
- every PR, issue or comment body (`gh ... --body-file`).

Nothing that must carry forward lives there. Handoffs, plans, mission
reports, decisions and drafts for review go to a tracked path and are
committed. Scratch never leaves the machine, and in a git worktree it is
deleted with the worktree.

Files go in with the Write tool, not with heredocs or `echo` redirects in
Bash. Agents do not delete scratch files; the harvester decides what to
keep.

### When to invoke /scratch

Invoke the `/scratch` skill when ANY of these arise:

- Writing a temp script, a commit message, or a PR or issue body
- Capturing a command's or check's output to a file
- The standing-order-guard blocks a long or compound Bash command
- You need your session scratch directory and the `Session scratch
  directory:` line is not in your context
- You are a delegate, or you work in a git worktree
- Choosing a file name whose harvest outcome matters
- User says `/scratch`

### Delegation duty

A delegate gets no SessionStart hook and so has no scratch directory.
Every delegation prompt states, by absolute path, the scratch directory the
delegate creates and uses: `<the delegate's repo or worktree
root>/.scratch/session-<short name>/`, the short name at most 10
characters. The prompt tells the delegate to invoke `/scratch`, and names
the tracked path for anything it hands back. This is part of delegation
element 6, Access (user rule `delegation.md`).

### Enforcement

| Layer | Mechanism | State |
|-------|-----------|-------|
| Prevention | This rule; the `/scratch` skill; USO "Scratch files for complex scripting" | Always in context once deployed |
| Detection | standing-order-guard hook: blocks Bash commands of 4+ lines and `&&`, `\|\|`, `;`, `$(...)`, backticks | Enforce |
| Detection | delegation-duty-guard hook: checks the seven delegation elements | Observe; does not yet check for a scratch path |
| Audit | SessionEnd and SessionStart harvest of `.scratch/session-*` into `harvesting/` (aitools) | Copies only; never deletes |

### Cross-references

- Directory, naming, patterns, lifecycle: `/scratch` skill
- Harvesting process: `/harvest` skill
- Delegation prompts: `/delegate` skill; user rule `delegation.md`
- Hook rollout states: aitools `.claude/rules/hook-rollout.md`
- Workspace namespaces: aitools `.claude/rules/aitools-workspace.md`
