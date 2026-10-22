# S3-Hooks placement: where the hook-lifecycle rule sits

Where the hook-lifecycle governance drafted by mission HOOKS should live, with the
options weighed. Written by S3-Hooks, 2026-10-21. Every protected file below is a draft awaiting
approval; nothing here has been applied to `.claude/rules/` or `.cursor/rules/`.

## Recommendation

**Option A: a new rule, `.claude/rules/hook-lifecycle.md`**, with its Cursor mirror
`.cursor/rules/hook-lifecycle.mdc`, plus one cross-reference line in
`hook-rollout.md` (already in the hook-rollout draft). Leave
`managed-file-deployment.md` unchanged except an optional pointer (below).

## Options weighed

| Option | For | Against |
|--------|-----|---------|
| **A. New rule `hook-lifecycle.md`** (recommended) | One home for the decision SD-2 and everything that follows from it (source, deploy equivalence, adopt target, user-created hooks, retire). Scoped `paths:` frontmatter (`shared/hooks/**`, `scripts/setup-user-hooks.*`, `scripts/build-deploy.sh`) loads it only when hook code is touched. Matches the existing split of `managed-file-deployment.md` (all file types) vs per-concern rules. ~110 lines, inside the documentation-standards 40-100 line band give or take the frontmatter and decisions table | One more rule file; needs a `.cursor` mirror and a row in `reference/cursor-practices.md` "Rule Correspondence" (cursor-rule-parity.mdc) |
| B. Extend `hook-rollout.md` | Already the hook rule; agents editing hooks already load it | Its subject is observe-then-enforce for PreToolUse checks, one phase of the lifecycle. Adding deploy/adopt/retire roughly doubles it (92 lines today) and mixes two audiences: someone tuning a check vs someone changing the deploy scripts. Its `paths:` are broad (`scripts/**`, `reference/**`, ...), so the lifecycle text would load on unrelated work |
| C. Extend `managed-file-deployment.md` | Owns the "Shell script" deployment type and already points to the adopt target in the reference | It governs all deployment types at the type level; hook-only topics (manifest, reverse discovery, retirement lists, MDM stale files) would make it the one type with a sub-chapter. It has no rollout content, so hooks would still be split across two rules |

## What else changes if A is approved

| File | Change | Draft |
|------|--------|-------|
| `.claude/rules/hook-lifecycle.md` | New | `S3-Hooks-drafts/dot-claude/rules/hook-lifecycle.md` |
| `.cursor/rules/hook-lifecycle.mdc` | New mirror | `S3-Hooks-drafts/dot-cursor/rules/hook-lifecycle.mdc` |
| `.claude/rules/hook-rollout.md` | `MODE_SED` row (#82), exemption-test step, log note, pointer to hook-lifecycle | `S3-Hooks-drafts/dot-claude/rules/hook-rollout.md` (+ `.diff`) |
| `.cursor/rules/hook-rollout.mdc` | Same, mirror | `S3-Hooks-drafts/dot-cursor/rules/hook-rollout.mdc` (+ `.diff`) |
| `reference/cursor-practices.md` | One "Rule Correspondence" row after the `hook-rollout.md` row (cursor-practices.md:167), columns Claude Code = `.claude/rules/hook-lifecycle.md`, Cursor = `.cursor/rules/hook-lifecycle.mdc`, Notes = `Condensed` | Row text here; not a protected file, but held back so it does not point at a rule that does not exist yet |
| `.claude/rules/managed-file-deployment.md` | Optional: in "Content sources", after "Hooks: canonical source in `shared/hooks/`, deployed to `~/.claude/hooks/`" add "; lifecycle: `@.claude/rules/hook-lifecycle.md`" | Text given here only |
| `reference/managed-file-deployment.md` | None needed: "Shell Script Deployment Detail" already says adopt targets `shared/hooks/` (that is the spec the code now meets) | -- |
| `registries/incidents.json` #80/#81/#82 | Close after the PR merges (correctiveAction, preventionLayer = this rule + the guard smoke tests) | Not drafted (Session Commander triages) |

`.claude/rules/sources-of-truth.md` needs no edit: its `.claude/rules/*.md` and
`.cursor/rules/*.mdc` rows already cover the new files.

## Open point for the decision

The draft keeps reverse discovery's `[a]dopt to dotprofile` for user-created
(non-manifest) hooks. SD-2 says "the adopt path must write shared/hooks only"; I read
that as the manifest-hook adopt (the `accept & adopt` outcome), because incident #80's
suggested resolution says "the dotprofile holds only user-created hooks". If SD-2 was
meant to cover user-created hooks too, the reverse-discovery menu changes (for example
to `[a]dopt to shared/hooks (unregistered)` / `[s]kip`) and the draft's "User-created
hooks" section changes with it.
