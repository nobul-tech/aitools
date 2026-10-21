# S2-Split-A adversarial review: the case for "everything in shared"

## (a) Evidence the draft missed

- **M1. User-level artifacts already hand off to project-only skills, so the split is broken today.** `shared/skills/investigate/SKILL.md:154,235` sends agents to `/incident` (`.claude/skills/incident/SKILL.md`). `shared/skills/scratch/SKILL.md:14,142` points to the `/harvest` skill. The user-level hook `shared/hooks/glossary-skill-guard.sh:35` tells agents in every repo to "Use /glossary skill". Outside aitools, all three lead to a skill that does not exist there.
- **M2. Repo resolution is already solved and populated.** `aitools-install.sh:421-468` manages `repoPath` in `~/.aitools/config.json`. On this Mac it is `"repoPath": "/Users/new-jose/repos/aitools"` (`~/.aitools/config.json:4`). There are two hook precedents for a user-level artifact reaching into the repo: `tool-ops-session-audit.sh:21-27` and `harvest-session.sh:47-52`.
- **M3. The draft treats placement as protecting correctness, but the skills are already path-broken inside aitools.** `paths.txt` shows `MISSING reference/incidents.json` (audit, incident), `reference/glossary.json` (glossary) and `reference/framework-registry.json` (frameworks, tool-ops). Keeping these skills in `.claude/skills` did not keep them correct. A1 is a pre-existing path bug, and placement does not cause it.
- **M4. The placement doctrine is being broken in the direction of "move" already.** `documentation-standards.md:89-90` says "Never create same-name skills at both levels". The current tree does exactly that, with 9 identical copies (`paths.txt:456-464`). Both fixes satisfy the rule: delete the shared copies (the draft's fix) or delete the project copies (the commander's fix). Doctrine does not pick between them.

## (b) Flaws in A1-A7

- **A1 (repo-relative paths).** This is a one-line fix per skill: "resolve `AITOOLS=<repoPath from ~/.aitools/config.json>`, use `$AITOOLS/registries/...`". It is a design gap, not a reason to stay project-scoped (M2, M3).
- **A2 (personal shadows project).** This only bites while both copies exist. With the source only in `shared/`, nothing gets shadowed. The deploy lag it describes (~4 months stale) applies equally to `delegate`, `handoff` and `investigate`. The cure is running the deploy.
- **A3 (cloud sessions).** This is the strongest point, but it proves too much. Personal skills don't load in cloud sessions ("All your projects on this machine, but not Cowork or cloud sessions", code.claude.com/docs/en/skills). So the 18 shared skills the harness depends on (scratch, delegate, handoff, investigate, planning) are already missing there. Keeping 8 governance skills project-level saves a small piece of a harness that cloud sessions already lack. The same table lists a "claude.ai account" skill channel that loads in cloud sessions, which the draft never mentions. Whether a cloud container running `aitools install` gets personal skills is unknown and untested.
- **A4 (live with branch).** I concede this is real for editing iteration. It is weak for consumption, because shared skills have the same lag and nobody argues `delegate` should be project-only.
- **A5 (rules are project-level).** This argues for moving the rules too (the draft's own F6 and F7), not for keeping the skills. The commander's position includes governing rules.
- **A6 (deliberate design).** The design's own test is "Patterns would be wrong or misleading in another project" (`plans/governance-and-compliance-framework.md:113-116`). The commander's operative instruction, dotprofile `claude/CLAUDE.md:8` (F1), says to use tool-registry, tool-ops and tool-eval in non-aitools repos. That is the later and more authoritative intent. The principle explaining the split was deleted in b504c43 (F5). The reference cards built to bridge the gap duplicate knowledge: `aitool-ops` (341 lines) and `aitool-eval` (609 lines) are snapshot copies that are "staleness-aware" by design. One source is better than two drifting copies.
- **A7 (no check).** This applies equally to either direction.

## (c) Designs that make "everything in shared" work

1. **Repo resolver preamble** in each skill: read `repoPath` from `~/.aitools/config.json`, fall back to `$AITOOLS_REPO_PATH`, then `~/repos/aitools` (the hook precedent). If none resolves, run read-only and say so.
2. **Context-aware writes.** When cwd equals repoPath, write the registry behind the protected-file review gate, with the gate text inlined into the skill. Otherwise file a `gh issue` on aitools, per RFC 0001. This fixes `/incident`'s cross-repo write risk without keeping it project-only.
3. **Plugin.** Package the skills as an aitools plugin, giving namespaced `/aitools:incident`. Per the docs, "Both load, because plugin skills are namespaced", so there is no shadowing. A project can enable a plugin in `.claude/settings.json`, which may cover cloud sessions; that is unverified. Caveat: `${CLAUDE_PLUGIN_ROOT}` is the install cache, not the repo, so the resolver from item 1 is still needed.
4. **Do not use `${CLAUDE_SKILL_DIR}` for this.** It resolves to `~/.claude/skills/<name>`, not the repo. `--add-dir ~/repos/aitools` does load project skills per-session, but it is manual and every launch needs it.
5. **Deliver rules through a `shared/rules/` deploy**, so trigger directives (F6) and `delegation.md` (F7) load everywhere.

## (d) What the draft gets right (conceded)

- Harvest should move. That is F2, and I agree.
- Never ship both copies. Add the dual-level check.
- `delegation.md` in `.claude/rules` is a duplicate. Delete it and deploy instead.
- `/audit` and `/governed-data` are genuinely about aitools' internal structure.
- Cloud-session loss is real until tested.

## Verdict per skill

| Skill | Verdict | Strongest reason |
|---|---|---|
| harvest | move | Harvesting runs in every repo (`ait-harvest.py:779`). The skill is the only missing piece. |
| incident | move (+resolver, gh-issue routing outside aitools) | Surfacing duty is continuous and harness-wide. User-level `/investigate` already hands off to it (M1). |
| tool-registry | move | The commander's CLAUDE.md:8 orders its use in non-aitools repos (F1). |
| tool-ops | move | F1, and it retires the drifting `aitool-ops` snapshot copy. |
| tool-eval | move | Global CLAUDE.md requires evaluation before any recommend or install in every repo. F1. It also retires the `aitool-eval` copy. |
| glossary | move (read everywhere; write only when cwd=repoPath) | The user-level hook `glossary-skill-guard.sh:35` already points every repo at `/glossary`. |
| frameworks | move (read-mostly) | "Check before assuming" applies in any repo. Weakest of the moves. |
| governed-data | keep | It creates and audits aitools registries and has no cross-repo use case. |
| audit | keep (or move; harmless either way) | It audits aitools' own rules. `disable-model-invocation` means it costs nothing if moved. |

Net: 7 move, 2 keep, against the draft's 1 move, 8 keep. The precondition for moving is the repo resolver plus deleting the `.claude/skills` copies in the same change. Without the resolver, moving reproduces A1 in every repo.
