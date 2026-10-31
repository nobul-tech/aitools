# Draft: reference/tool-ops-claude-code.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

UNVERIFIED: the facts below come from https://code.claude.com/docs/en/memory as
read by S3-FanPlan-Ref with WebFetch on 2026-10-26 (S3-FanPlan-Ref-findings.md
3.1). `.claude/rules/web-sources.md` requires a chrome-devtools read before
this text goes into a protected file: re-read the page, check every clause,
then write. Base: main.

## Edit 1 -- "### MEDIUM -- Affects developer experience or specific features": new row after item 21

OLD:

```
| 21 | `agent_id`/`agent_type` in hook events (distinguishes main vs subagent) | 2.1.68 | 2.1.74 (2026-03-13) | -- (not yet used) | -- |
```

NEW:

```
| 21 | `agent_id`/`agent_type` in hook events (distinguishes main vs subagent) | 2.1.68 | 2.1.74 (2026-03-13) | -- (not yet used) | -- |
| 28 | User-level rules (`~/.claude/rules/`): every `.md` loads in every project, before project rules, with no precedence on conflict; `paths:` globs resolve against the session's primary working directory; `paths` is the only frontmatter field read; frontmatter that does not parse loads the rule unconditionally. Unknown: recursion into subdirectories at user level, case of the `.md` extension | 2.1.307 | 2.1.307 (2026-10-26, docs only, UNVERIFIED) | `scripts/setup-user-claude.sh/.ps1` (rules fan-out), `scripts/deploy-harness.sh/.ps1`, `reference/harness.md` | -- (code.claude.com/docs/en/memory) |
```

## Why

The rules fan-out puts 28 rules into `~/.claude/rules`; the harness has no
record of how Claude Code loads user-level rules (S3-FanPlan-Ref INCIDENT 1).
Plan `plans/rules-fanout-claude.md` risk R1.
