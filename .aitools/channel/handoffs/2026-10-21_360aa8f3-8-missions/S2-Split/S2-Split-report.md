# S2-Split report: `.claude/` vs `shared/` placement

## Summary (5 lines)

1. The split was a deliberate design decision, not an accident: plans/governance-and-compliance-framework.md (decision 7 and "Skill Architecture", 2026-03-13) and documentation-standards.md "Skill placement". Under that design, project skills CRUD aitools-only registries and user skills hold project-agnostic patterns.
2. The commander's diagnosis is half right. Against the job aitools now has (one harness across every repo), the split fails. His own user CLAUDE.md sends agents in other repos to `/tool-registry`, `/tool-ops` and `/tool-eval`. Harvesting runs in every repo while `/harvest` exists only in aitools. The cross-repo trigger rules load only inside aitools. And the CLAUDE.md text that explained the split was deleted on 2026-03-28 (b504c43).
3. Moving all nine skills as they stand would break things. Seven of them read or write aitools-relative paths, so in another repo those resolve against the wrong cwd. Claude Code ranks personal skills above project skills, so stale deployed copies would shadow the repo copies (this Mac's deploy is about 4 months behind). Personal skills also don't load in cloud sessions.
4. Recommendation: delete the 9 untracked copies and the `.claude/rules/delegation.md` copy. Move `/harvest` to `shared/` (it is cross-repo by nature). Keep the 8 registry CRUD skills in the project, and serve other repos through user-level cards that read the aitools repo live via `repoPath`. Add a user-level rule source (`shared/rules/`) so harness policy (delegation, card triggers) reaches every repo. Add a check that blocks the same skill name at both levels.
5. 9 INCIDENT findings. The top three: the cross-repo trigger rules never load where they are needed; `tool-ops-session-audit.sh` has silently done nothing since 2026-06-15; and no framework governs artifact placement.

(Sections below are filled after adversarial review -- see "Adversarial review" for what changed.)
