# S3-MA-Layout log v1.0: re-land of LAYOUT PR-b (#74) and PR-c (#75)

**Version:** v1.0 · **Written:** 2026-10-27T08:25Z · **By:** S3-MA-Layout (a delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)

## Result

Both re-lands are on main as merge commits. Before each merge every check was green and the state was CLEAN. After each merge, main CI went green.

| PR | Branch | Head | Merge commit | Merged (UTC) | PR CI | Main CI after merge |
|---|---|---|---|---|---|---|
| [#128](https://github.com/nobul-tech/aitools/pull/128) PR-b re-land | `feature/user-level-skills-reland` | f0a24f3 | 72c94c3 | 2026-10-27T07:49:38Z | run 40467945271: windows, macos, linux; CodeQL; Analyze | CI 40469468182 success; Push on main 40469466911 success |
| [#129](https://github.com/nobul-tech/aitools/pull/129) PR-c re-land | `refactor/retire-reference-cards-reland` | ebd3430 | a63ad2d | 2026-10-27T08:06:01Z | windows, macos, linux; CodeQL; Analyze, all SUCCESS | CI 40471208313 success; Push on main 40471207416 success |

Worktrees: `/Users/new-jose/repos/aitools/.claude/worktrees/relandb` and `relandc`. Both are kept, along with their branches; none was removed.

## Commits

| Re-land | Original | Subject |
|---|---|---|
| ae02d36 | 4aa4728 | Move seven governance skills to user level (shared/skills) |
| 02034cb | 1b34195 | Add the S2L-Q4 design note |
| f0a24f3 | ed1b75c | Make cross-repo registry access safe; clarify step 21 and shared/README |
| 7edbb84 | 6d3cacf | Retire the aitool-ops and aitool-eval reference cards |
| 7645824 | 7b45433 | Record mission LAYOUT follow-ups |
| 287bf43 | 2375fea | Follow-ups: add the SD-2 rule for skills |
| ebd3430 | (new) | Repoint the last live citations of the retired reference cards |

All cherry-picks used `-x`. PR-a's old commits (0db8cc9, 24b56d3, 01355d5, 63ce030) were dropped.

## Conflicts and how they were resolved

1. `scripts/check-path-refs-allow.txt` (PR-b, content): PR-b added a fixture line for `reference/tool-ops-cursor.md`. Main had already removed it because 76a4c45 created that file. I kept main's version, and step 20 found 0 dead paths.
2. `shared/skills/aitool-ops/SKILL.md` (PR-c, modify/delete): main had edited the card in e0d2c03 and d9348f3 (#85: read order and source precedence). That content already lives in `/tool-ops` "Per-tool ops references (where to read them)", so I deleted the card as PR-c intended.
3. `shared/skills/tool-ops/SKILL.md` (PR-c, content): I kept both sections, #85's read order and PR-c's source-of-record table. The Intent from e4e1dea (#99 item a) moved with the skill in PR-b and auto-merged unchanged. `git diff -M` against main's `.claude/skills/tool-ops/SKILL.md` shows a single hunk, "Where the files live".
4. #71's step numbering: there was no conflict. Main ends at pre-commit step 20, and step 21 is new in both `.sh` and `.ps1`.
5. Live references to the retired cards that the cherry-picks could not cover. Main added them after PR-c was written, so the new commit ebd3430 fixes them:
   - `reference/rules.md` "Reference-card pattern" cited the deleted rules, giving 2 dead paths.
   - `shared/skills/delegate/SKILL.md` had 2 citations of `/aitool-ops`, now `/tool-ops`.

## Verification

Local runs, all on macOS:
- `check-skill-levels.py`, with the dotprofile:
  - relandb: 22 user / 2 project / 0 collisions.
  - relandc: 20 / 2 / 0.
  - Main after each merge: the same numbers.
- `check-path-refs.py`: 0 dead paths on both branches and on main after each merge.
- Isolated HOME `setup-user-skills.sh`, exit 0:
  - relandb: all 7 moved skills are byte-identical in `~/.claude/skills` and `~/.cursor/skills`.
  - relandc: all 20 skills are byte-identical, and neither card was deployed.
- `/bin/bash -n`, the pwsh parser and `py_compile` passed on the touched scripts.
- `check-pre-commit.sh`: steps 20 and 21 PASS on both branches. Step 6 FAIL is the known harvesting file. Step 11 WARN is uncommitted changes in the dotprofile, which belong to another session.
- `check-pre-push.sh`: step 7 FAIL is the known stale dotprofile `deploy/`, expected until the MERGE-ALL rebuild. Steps 1, 5, 6 and 8 are WARNs only.

## Not run

- An independent reviewer. I am a level-2 delegate without the Agent tool, so I could not launch one. Each PR has an author verification comment instead ([#128](https://github.com/nobul-tech/aitools/pull/128#issuecomment-6436546049), [#129](https://github.com/nobul-tech/aitools/pull/129#issuecomment-6436796152)), and both say plainly that they are not independent reviews.
- V4: I did not re-run build-deploy against a copy of the dotprofile. CI's "Build deploy scripts" and "Check deploy drift" passed on all three platforms.
- V5 (Claude Code web) and Windows end to end.

## ACTION for the commander

- Run `aitools` on every machine. Until it runs, sessions on aitools do not load the 7 governance skills from `.claude/skills/`. In the meantime, read `shared/skills/<name>/SKILL.md` by hand.
- `setup-user-skills` has no prune (incident #119), so `~/.claude/skills/aitool-{ops,eval}` and the `~/.cursor/skills` copies stay. Either delete them by hand or wait for FAN-PLAN FO-2 (PR #119) and FO-6 (PR #125).

## Effects on other missions

- FAN-PLAN PRs #122 and #126 edit `shared/skills/aitool-ops/SKILL.md`, which is now deleted. #126 also edits `documentation-standards.md`, `framework-governed-vocabulary.md` and `reference/rules.md`. Expect conflicts on those PRs: drop the card edits and keep "Reference-card pattern (retired)".
- `reference/rules.md` still gives the dated counts "9 of the 26" and "17 of the 26". Main now has 24 project rules.

INCIDENT: The handoff recipe (2026-10-22 E step 1) asked for PR-c stacked on PR-b's branch, which is the pattern that caused D.2. I opened #129 against `main` instead, so it could not merge into a stale base. A stacked re-land should use base `main` and merge in order. Recommendation for `plans/merge-friction-improvements.md`.
INCIDENT: Delegates at level 2 cannot launch the independent reviewer that the handoff's "one delegate, with an independent reviewer" calls for. The orchestrator has to launch reviewers itself.
