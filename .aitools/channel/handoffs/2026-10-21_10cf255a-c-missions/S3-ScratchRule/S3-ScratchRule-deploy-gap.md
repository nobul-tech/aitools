# S3-ScratchRule: getting the scratch rule into agents' context

## The gap

- `shared/rules/` is not on origin/main and nothing deploys it. User rules
  reach `~/.claude/rules/` only from the dotprofile `claude/rules/`
  (`scripts/setup-user-claude.sh:265-266`; MDM path embeds the same source,
  `scripts/build-deploy.sh:164-165`; `reference/user-repo.md` "User Rules
  Deployment").
- Mission HARNESS (approved design, section 6 of the packet) will copy
  `shared/rules` to `~/.aitools/rules`, which no agent tool loads. RULES-FANOUT
  (later) would fan it out to `~/.claude/rules/` and Cursor. Until then a rule
  in `shared/rules/` is in no agent's context.
- Any deployment needs an `aitools` run, and nobody runs `aitools` on this
  machine until mission HOOKS-FIX merges (packet section 5).
- Every option writes a rule with an intent statement, so every option is a
  protected write needing the commander's approval of the text.

## Options

| # | Option | Reaches context | Protected files touched | Cost / risk |
|---|--------|-----------------|-------------------------|-------------|
| A | Put the approved rule in the dotprofile `claude/rules/scratch.md` (same route as `delegation.md`, D-DEL2) | `~/.claude/rules/` on every machine at the next `aitools` run, both deploy paths | The new rule (intent). Dotprofile repo, separate commit/PR | When RULES-FANOUT lands the rule must move to `shared/rules/` once (one copy, as SD-2 did for hooks), or two copies drift |
| B | Fix the pointer in the CLAUDE.md templates: USO "Scratch files for complex scripting" in `shared/claude-shared.md:124` and dotprofile `claude/CLAUDE.md:167` (template sync, deploy-paths.md) | Always in context (CLAUDE.md) | `shared/claude-shared.md` (protected table), dotprofile CLAUDE.md | Small. Does not carry the delegation duty or triggers; worth doing anyway because "The SessionEnd hook handles cleanup" is false today |
| C | Commit the rule to `shared/rules/scratch.md` now and wait for HARNESS + RULES-FANOUT | Not until RULES-FANOUT ships; HARNESS alone only reaches `~/.aitools/rules` | The new rule | Zero context in the meantime; the skill is the only carrier |
| D | aitools project rule `.claude/rules/scratch.md` | Only sessions in the aitools repo (most of today's work) | `.claude/rules/*.md` (protected) | Wrong scope: the rule is user-level; a later move to user level duplicates it |

## Recommendation

A + B now, C as the end state.

1. Approve the rule text (`S3-ScratchRule-drafts/shared/rules/scratch.md`).
2. Place it in the dotprofile `claude/rules/scratch.md` (A). It deploys with the
   first `aitools` run after HOOKS-FIX merges, on both machines, with the
   existing additive rules deploy and its diff review.
3. Replace the stale sentence in the USO line of both templates (B):
   old: `Write to the session scratch directory (per /scratch skill), execute. The SessionEnd hook handles cleanup.`
   new: `Write to the session scratch directory (per /scratch skill and the scratch rule), execute. Nothing in scratch is deleted; the SessionEnd hook harvests what is not ephemeral.`
4. When RULES-FANOUT ships, move the file to `shared/rules/scratch.md` and drop
   the dotprofile copy in the same change.

Why not C alone: the guard already blocks the bad patterns, but nothing tells
a delegating agent to give its delegate a scratch path (#83 was a mission brief
that named an unwritable one), or to keep the name short enough for the
harvester (S3-SR-8). Why not D: every repo needs it, not only aitools.
