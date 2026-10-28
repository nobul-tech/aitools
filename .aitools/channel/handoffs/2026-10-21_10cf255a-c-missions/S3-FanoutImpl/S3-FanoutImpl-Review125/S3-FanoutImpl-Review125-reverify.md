RE-VERIFY: APPROVE

S3-FanoutImpl-Review125 re-verified PR #125 at head 7754c15, against my verdict (issuecomment-6433598495) and the author's mapping (issuecomment-6433847474). All four findings are fixed, and I found nothing new.

## Findings

| Finding | Status | Evidence |
|---|---|---|
| B1: branch lacked FO-4 and FO-5 | Fixed | The first-parent log shows #124 merged (ffe6790, then 6d34dd8, which brings in 5267e9e) and #123 merged (f950d5e). With a harness present, the skills deploy to both tools (probe below) |
| N1: an adopt failure in fan-out mode wrote a `claude skills` row | Fixed | `SKILLS_ROW_TOOL` / `$skillsRowTool` (setup-user-skills.sh:60-67, .ps1:53-60). A pty probe with a read-only dotprofile `claude/skills` gives `OK skills n/a (fanned out)` and `ERROR skills adopt failed: fail<lang>` (exit 1), in sh and ps. Every remaining literal `claude skills` write is on the fallback path |
| N2: rows written twice in fallback mode | Fixed | See the dev-order probe below |
| N3: test gaps | Fixed | The suite now has 50 cases, up from 38. New cases cover pty adopt, adopt failure, empty harness, an unreadable target, and the dev-order runs |

**Dev-order probe.** I ran deploy-harness (when present), setup-user-claude, setup-user-skills and setup-user-cursor into one summary file, under an isolated HOME.
- **Without a harness:** one `OK claude skills 16 added` and one `OK cursor skills 16 added`. There are no `n/a (no harness skills)` rows, and the panel shows 16 added for both tools.
- **With a harness:** `OK claude skills 32 added`, `OK skills n/a (fanned out)` and `OK cursor skills 32 added`, one row each.

## What I ran (macOS, isolated HOMEs)

| Suite or probe | Result |
|---|---|
| tests/skills-legacy, bash 5 | 50/50 |
| tests/skills-legacy, /bin/bash 3.2 | 50/50 |
| tests/skills-legacy, `CI=true` | 50/50 |
| tests/skills-fanout | 158 passed, 1 skipped |
| tests/claude-mdm, bash 5 | 38/38 |
| tests/claude-mdm, /bin/bash 3.2 | 38/38 |
| Probes: empty harness, pty adopt, adopt failure, dangling manifest (sh and ps) | As expected. A dangling manifest gives `ERROR skills no adopt: manifest unreadable` in both languages |

## CI run 40450703903 (head 7754c15)

- macos and windows passed.
- linux failed in one step only, "Fan-out lib helper tests (bash + pwsh parity)", with `FAIL ps bd-special` and `FAIL parity bd-special`. This is the known FO-1 issue, so I do not count it here.
