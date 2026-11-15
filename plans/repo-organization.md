# Repo organization

**Intent**: **Purpose**: Make the aitools repo smaller, flatter to read and
easier to orient in, without changing what it deploys. **Scope**: What is
cluttered today (measured), the proposed changes in small batches, and which
batches need the commander's order. NOT the map of what aitools is
(`reference/aitools.md`). NOT changes to deploy behaviour. **Audience**: The
commander deciding which batches to run; the session that executes them.

v1.0 (2026-11-04), session 9dd9059f-2

## 1. What was measured (2026-11-04, `git ls-files`)

| Area | Tracked files | Size | Finding |
|------|--------------:|-----:|---------|
| `harvesting/` | 907 | ~153 MB | 6 `.tar` repo snapshots (2026-10-29) = ~136 MB; four are 31-34 MB each |
| `.aitools/channel/handoffs/` | 1,080 | -- | 2 mission working dirs hold ~1,060 of them (`S3-CursorVerify` alone: 375) |
| `.aitools/channel/` (top) | 9 | ~0.6 MB | two full-session transcripts (one 431 KB) and `pre-failure-mode/`: origins material beside live state |
| `deploy/` | 36 | 3.1 MB | frozen; still reset on every pull; already incomplete (no deploy-harness, settings or google-chrome) |
| `rfcs/` | 20 | 446 KB | v1, v2 and v3 copies side by side (0004 has four files); two numbering schemes (`0001-...`, `RFC-0001-...`) |
| `plans/` | 43 | 1.7 MB | finished plans beside live ones; `linux-install-hardening.md` is 398 KB |
| `RELEASE_NOTES.md` | 1 | 294 KB | every version since v0.1 in one file |
| `shared/hooks/` | 2 | -- | tracked `*.bak.2026-06-21*` files in a deploy source |
| `reference/` | 47 | 634 KB | `tool-registry.md` marked DEPRECATED (43 KB); `claude-code-effectiveness.md` is a historical copy |
| orientation | 4 files | -- | README "What's here", CLAUDE.md "How the harness is organized", `shared/README.md` and `reference/harness.md` each restate the layout |

## 2. Blocker: the uncommitted working tree

The working tree, uncommitted on main, deletes `sources-of-truth.md`,
`relay-outbound.md`, the `audit` skill and `artifact-harvesting`, and moves
`frameworks`, `glossary` and `incident` from `shared/skills/` to
`.claude/skills/`. `scripts/check-path-refs.py` reports **46 dead path
references** caused by that change: 31 are to `sources-of-truth.md`, in 18
files. Land it, with its references fixed, or set it aside before running any
batch below. Otherwise the batches mix with it.

## 3. Batches

Each batch is 2-3 changes, verified before the next (UCI smaller batches).
**Order** = needs the commander's explicit order (destructive or
outward-facing).

| Batch | Change | Order? | Verify |
|-------|--------|--------|--------|
| B1 Weight | Untrack the 6 `harvesting/*.tar` files (`git rm --cached`) and gitignore `harvesting/*.tar`; move the two mission dirs out of `.aitools/channel/handoffs/` (into `harvesting/` or the dotprofile), keeping each mission's final handoff `.md` | yes | `git count-objects -vH`; the handoff skill still finds its files |
| B1b History | Rewrite git history to drop the tars (`git filter-repo`); the clone stays ~136 MB larger until this is done | yes (force-push; every clone re-clones) | fresh clone size |
| B2 Junk | `git rm` the two `shared/hooks/*.bak.*`; retire `.cursor/rules/relay-outbound.mdc` and `sources-of-truth.mdc` with their `.claude` twins; delete deprecated `reference/tool-registry.md` | no | pre-commit, path-refs, cursor parity |
| B3 One map | README, CLAUDE.md and `shared/README.md` each keep a 3-5 line summary and point to `reference/aitools.md` for the layout; fix the `reference/harness.md` contradiction (Cursor fan-out: "shared and dotprofile rules only (R-2)" vs "every non-retired rule (all three sources)") | no (CLAUDE.md is a channel path) | CLAUDE.md under 200 lines; path-refs |
| B4 Archive | `rfcs/`: keep the latest version of each RFC, one numbering scheme (keep the `RFC-0001-...` file name: user CLAUDE.md links it); `plans/done/` for shipped plans (error-handling-audit, per-platform-tool-approval, harvest-archive-resilience, ...); older RELEASE_NOTES sections to `release-notes/` | no | ROADMAP links resolve; path-refs |
| B5 Retire `deploy/` | Delete the frozen `deploy/`, the pre-pull reset in `scripts/aitools` and `.ps1`, pre-commit steps 3 and 10 that inspect it; update `.claude/rules/git-safety.md` | yes | CI on all three OSes; `check-pre-push` step 7 |

**Not recommended**: regrouping `scripts/` into subdirectories. The flat
paths are wired into build-deploy's extraction, deploy-harness sources,
hook paths in `settings.json`, the bootstrap one-liner URLs, MDM, tests and
CI. The blast radius is large and the gain cosmetic. `reference/aitools.md`
section 5 groups the scripts by role instead.

## 4. Local machine hygiene (not tracked, no repo change)

- 108 stale `.scratch/session-*` dirs (more than 24 h old) and 164
  `.claude/worktrees/` entries: run a cleanup script, not `rm` globs (USO).
- `~/repos/aitools-nobul-jose/.git/index.lock` is 93 h old (SessionStart
  harvest warning). Session archives cannot commit until it is removed.
  First check that no git process is running.

## 5. Decisions needed

| ID | Question | Suggested |
|----|----------|-----------|
| RO-1 | Land or set aside the uncommitted working-tree change first? | Land it in its own PR with the 46 references fixed |
| RO-2 | Run B1 (untrack tars, move mission dirs)? | Yes: the largest, safest win |
| RO-3 | Rewrite history (B1b)? | Later and separately; only if clone size hurts (CC web, Cursor cloud clone it) |
| RO-4 | Retire `deploy/` (B5)? | Yes, after the build-package path lands |
