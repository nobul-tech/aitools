# MERGE-ALL mission brief

**Version:** v1.0 · **Written:** 2026-10-26 (UTC, after 23:01Z) · **By:** S3-MA-Brief (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)
**Source:** the commander's own prompts and AskUserQuestion answers in transcript
`~/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl`,
read newest first (lines 7306 back to 5980) with
`.scratch/session-mabrief/user-prompts.py` and `dump-lines.py` (non-sidechain
entries only). Quotes are verbatim, typos included. Line numbers are JSONL
line numbers in that file.

---

## 1. Goal (commander's words, 2026-10-26T22:55:20Z, line 7264)

> launch a new mission to merge all prs. it should carry forward all OL. pass through this session file and let it read it in reverse chronilogical order until its goal is clear. it should be an orchestrator and divide the work up to several agents. it should launch agents to verify the work. it should launch agents to suggest improvements and new unit tests as well as new CI/CD steps that will catch issues we've run into. it should read in github issues and look at PR history and all other available data (commander session files) to see where there is friction we can reduce. i dont like the overhead of worktrees/prs, and i dont like that produced work is often "draft". documents/changes agents produce should be treated as versions, not drafts, how do we document and steer behavior here? in the /delegate skill or delegation rule, or in CLAUDE.md file? i want it across all projects, so it should probably be user-scope. the mission should, at its end, have merged any and all open PRs on github in the right order, and it should handle all errors and CI/CD failures. it should not merge PRs until all github CI/CD checks/auto merge status are green. it should check its work after each merge. aask any open questions. ultracode

### Goal, as one sentence

Merge all 19 open PRs on `nobul-tech/aitools` in the order below, with merge
commits, each only when every check is green and GitHub reports CLEAN; verify
main (CI + touched local suites) after each merge; fix every error and CI
failure on the way; then do the post-merge work (section 3), tag v0.74.0, and
leave main, the dotprofile and GitHub clean.

### Deliverables

1. Every open PR merged (none left open), in order, merge commits only.
2. Post-merge work (section 3) shipped and merged the same way.
3. **D-DEL5 "versions, not drafts"** in the user rule and the `/delegate`
   skill, and the protected-file gate changed to review-after (section 2, A2).
4. `plans/merge-friction-improvements.md` **v1.0**: improvements, new unit
   tests and new CI/CD steps that would have caught the issues hit, each with
   evidence from GitHub issues, PR history and session files (A6). Plan only;
   an executing mission implements it.
5. build-deploy backs up before replacing the dotprofile `deploy/`; the mission
   rebuilds `deploy/` itself and commits and pushes the dotprofile (A4).
6. Release notes v0.74.0 (thorough), docs scrub, tag v0.74.0 pushed (A5).
7. Verifier agents on every merge step and on every produced version.

## 2. Commander decisions (binding), newest first

### A. MERGE-ALL decisions (2026-10-26)

**A1. Merging: the mission merges, merge commits, in order, checks after each step.**
2026-10-26T22:59:58Z (line 7286). Question: "The mission will merge PRs itself.
Today's policy (handoff E2, D-DEL4) is that only you merge. Confirm the mission
may merge, and how?" Answer:
> merge commits, mission merges, in the correct order, and checks after each step, etc

So: `gh pr merge <n> --merge` only (never squash or rebase), only when every
check is green and `mergeStateStatus` is `CLEAN`. This overrides, for this
mission, handoff 2026-10-22 E step 2 ("Merging is the commander's"),
`delegation.md` D-DEL4's "never merge", and packet section 4 "never ... merge".
Why merge commits: the Session Commander's 22:49:16Z analysis (line 7257) —
stacked branches (#112 contains #103; #113 contains #103+#98; #114 contains
#98+#108; #115 contains #113; #116 contains #115; #110 and #111 contain #100)
and reviewer verdicts cite exact SHAs; squash would re-conflict as after #71.
Leave every branch until the whole chain has merged (auto-delete is off).

**A2. Versions, not drafts: user rule + skill; protected files reviewed after.**
2026-10-26T22:59:58Z (line 7286). Answer: "User rule + skill; review after
(Recommended)". The option text:
> New decision D-DEL5 in the user rule ~/.claude/rules/delegation.md and the /delegate skill: delegates write final versions (v1.0, v1.1...) in place, never 'draft'. Protected files: written as a version and committed; you review the commit/PR diff instead of a pre-write draft. The mission drafts the sources-of-truth.md change to match.

Note: "drafts the sources-of-truth.md change" in the option text is
superseded by the commander's own choice of "review after" and the computed
decision "write the version and commit it": the mission **writes** the
sources-of-truth.md change as a version (v1.0) and commits it; the commander
reviews the diff after. The user rule lives in the dotprofile
(`~/repos/aitools-nobul-jose/claude/rules/delegation.md`, deployed to
`~/.claude/rules/delegation.md`); the `/delegate` skill source is
`shared/skills/delegate/SKILL.md`. Dotprofile writes auto-commit and push to
its main (N-Q2).

**A3. Post-merge actions (multi-select), 2026-10-26T22:59:58Z (line 7286).** Selected:
- "Fix-forward #116 conflicts (Recommended)" — merge main into #116's branch,
  resolve `check.yml` and installer conflicts, re-test, independent re-review,
  then merge.
- "Apply #102 incidents (Recommended)" — run the approved apply script to file
  #146-#170 in `registries/incidents.json` and ship it.
- "Re-land #74/#75 (Recommended)" — cherry-pick LAYOUT PR-b/c onto new
  branches off main, PR, green, merge.
- "Small follow-ups" — #111's `--skip-config` in installer Step 8b; approved
  drafts from #103/#108/#105 rows 5-6.
- Plus free text, verbatim:
  > any and all cleanup on github, update release notes, do a thorough scrub on documentation and update it, be descriptive, launch this as its own mission orchestrator etc and breakdown the work as necessry.  release notes should be thorough, it should check the modification time of release notes and then look at commit/pr messages to populate any and all changes since release notes were last updated.  ask any open questions on this

**A4. Dotprofile `deploy/` rebuild: the mission, with a backup, not rm -rf.**
2026-10-26T22:59:58Z (line 7286), to "build-deploy rm -rf's the real
dotprofile deploy/. Who runs it?":
> why do we need to do a rm -rf? cant it just overwrite files? do a backup of the deploy and then do a rm -rf if necessary (the mission, not me the commander)

2026-10-26T23:01:36Z (line 7306): "Back up, then rebuild (Recommended)":
> Small PR: build-deploy copies deploy/ to deploy.bak.<UTC>/ (keep 5), builds into a temp dir, and swaps it in only on success (stale files removed, nothing half-built on failure). Then the mission runs it on the real dotprofile and commits + pushes deploy/.

This overrides handoff F.1 / packet section 5 ("never run build-deploy
against the real HOME") for this one rebuild, after the backup PR has merged.
The `.ps1` side and `config-file-safety.md` directory backup retention (keep
at most 5) apply.

**A5. Release: a separate orchestrator mission after the merges, and it tags.**
2026-10-26T23:01:36Z (line 7306): "Same, and the mission tags". The option it
amends ("Second mission after merges; v0.74.0, no tag") reads:
> The merge mission ends, then a docs+release mission writes v0.74.0 (folding the untagged v0.73.3 notes, everything since RELEASE_NOTES.md was last modified, from commit and PR messages) and scrubs docs; you tag.

With "and the mission tags": "it creates and pushes the v0.74.0 tag after the
notes merge." Together with A3's "launch this as its own mission
orchestrator": MERGE-ALL launches a RELEASE sub-orchestrator after the last
merge; it writes the notes, scrubs docs, and creates and pushes `v0.74.0`.
This overrides D-DEL4's "never tag" for that mission.

**A6. Verify depth: main CI after every merge.** 2026-10-26T23:01:36Z (line 7306): "Main CI after every merge (Recommended)":
> After each merge: wait for main's CI run to go green and run the local suites the PR touched; only then merge the next. Slow (roughly 10-15 min per PR), safest.

**A7. Improvement agents: plan v1.0, not implementation.** 2026-10-26T23:01:36Z (line 7306), free text:
> plan v1.0, plans/merge-friction-improvements.md

So the file is `plans/merge-friction-improvements.md` (not the
`plans/merge-friction/` directory the option proposed), version v1.0,
committed directly to main (plans/ channel exception).

### B. Decisions earlier on 2026-10-26 that shape this mission

**B1. Pre-push step 7 always runs** (22:39:56Z, line 6779, item 1: "q1c pre-push step 7 should always run before pushing. update docs/rule/reference file as necessary"; 22:42:03Z, line 6831: "I do it on main now"). Done: 8e490d7 "Run pre-push step 7 on every push". Consequence: every push FAILs step 7 until the dotprofile `deploy/` is rebuilt (A4). Expected; record it, do not treat it as a blocker until the rebuild.

**B2. plans/ and project CLAUDE.md bypass worktrees/PRs** (22:39:56Z, line 6779: "no worktrees/prs, this should bypass all of that. the plans directory should skip worktrees/prs etc as the others have. thats a decision. update the claude.md of the project accordingly and commit/push directly"; 22:17:19Z, line 6494, item 3: "project claude.md also bypassess worktrees etc, add it to the list"; 21:58:13Z, line 6071, item 7: "channel exception for handoffs should just do it on main and commit/push, no worktree/pr overhead"). Done: 5976553, 1af8851; `CLAUDE.md` "### Channel exception (direct to main)" (line 79). Everything else still ships via a PR.

**B3. No drafts: produced work is version 1.0** (22:39:56Z, line 6779: "no drafts, the produced plan should be executable by another sessions, it should be version 1.0 etc."; 22:33:08Z answer, line 6721: "produced materials should be not be drafts, they should be trated as version 1.0 of working docs"). A2 makes this a user-scope rule.

**B4. Abort behaviour stays as PR #106 implements it; docs match it** (22:17:19Z, line 6494, item 2: "update the docs to match the current implementation of PR #106. lets keep functionality, update docs on whatever current state is"). Done by ABORT-DOCS on #106's branch (3de51d6; comment https://github.com/nobul-tech/aitools/pull/106#issuecomment-6428754577). #106 therefore carries protected doc edits; read that comment before merging #106.

**B5. Supported platforms/environments** (22:33:08Z answer, line 6721): "we limit the platforms we support to mac, windows, linux, claude code web, cursor cloud for now (supported platforms/environments. update docs as required". Feeds the docs scrub (A3/A5).

**B6. Backup-File/Backup-Dir `-LiteralPath` fix direct on main** (21:58:13Z, line 6071, item 5: "fix it directly on main, no worktree/pr overhead, just commit it and push it"). Done: 9923a3c. Note #103 also edits aitools-lib: check it merges cleanly over 9923a3c.

**B7. HARNESS-2 items** (21:58:13Z, line 6071): "1d) approved" (the #99 `.mdc` twin at head df10361), "1e) approved" (Manifest/Cursor/MDM delegate doc drafts, after a reviewer checks them against merged code), "3) sure" (row 6 wording: "... or --no-machine when they leave this machine unregistered"). Item 6: setup-user-claude fan-out is FAN-PLAN's (a running mission; do not touch).

### C. Decisions 2026-10-24 (line 6024, 22:45:50Z)

> 1) protected drafts approved. 2) dotprofile pushes outside of main branch should error out 3) logging suggestions all accepted 4) re-state harness-2s decisions/questions

The Session Commander recorded what these cover (22:46:02Z, line 6041):
"The approved protected drafts are M3-FINISH's three: the helper contract in
`managed-file-deployment.md`, the aitools-profile exemption, and the incident
batch #146–#170. A dotprofile push from any branch other than main will now be
an ERROR (#165). I-1, I-2 and I-4 are accepted as suggested." These are the
"approved drafts from #103/#108" in A3's small follow-ups and the authority
for applying #102.

## 3. Work list

### 3.1 Merge order (Session Commander simulation, 2026-10-26T22:49:16Z, line 7257)

All 19 open PRs are from this session, all target `main`, CI green on all
(CodeQL "neutral" on docs-only #102). Simulated in this order: 18 clean, #116
conflicts.

| Step | PRs, in order | Notes |
|---|---|---|
| 1 | #99 → #101 → #105 → #104 → #97 → #102 | Docs and records only; verdicts non-blocking |
| 2 | #103 → #98 → #108 → #114 → #109 → #113 → #112 | M3-FINISH code |
| 3 | #100 → #110 → #111 → #115 → #106 | Harness code; #100/#111 blocking findings fixed and re-verified |
| 4 | #116 last, after fix-forward | Conflicts with #106/#112 in `.github/workflows/check.yml` (trivial: keep all jobs) and both installers (real; #116's body says how) |

Flat: #99, #101, #105, #104, #97, #102, #103, #98, #108, #114, #109, #113,
#112, #100, #110, #111, #115, #106, #116.

Checked by S3-MA-Brief at write time (`gh pr list -R nobul-tech/aitools
--state open`): exactly these 19 are open, all base `main`, none draft;
`mergeStateStatus` was `UNKNOWN` for all (GitHub not yet computed), so
re-query each before merging.

Before-merge notes (line 7257):
- **#102**: title says "#146-#161" but the M3-FINISH report (line 5980) says
  the batch is #146-#170 (25 incidents). Verify the count in the batch file.
  After merge run `S3-MF-Incidents-apply.py --write`; `registries/incidents.json`
  is not under the channel exception, so that change ships as its own PR. Parse
  the whole incidents.json before relying on ids.
- **#106**: carries protected abort-doc edits (B4).
- **#111**: last commit 8caa79e was not re-reviewed (UTF-8 fix, tests 64/64).
  Get it reviewed before merging. After it merges: installer Step 8b passes
  `--skip-config` (today `aitools install` runs the config writer twice).
- **#103, #108, #105**: approved drafts still to apply after the merges —
  #103's helper contract in `reference/managed-file-deployment.md`; #108's
  script-standards entry for the resolver (I-3); #105 rows 5 and 6, which wait
  for #98. #105 row 8 needs a new version after #103 and #106 merge
  (RECONCILE's plan covers it — coordinate, do not duplicate).
- **#74/#75**: still not on main, no PR (handoff 2026-10-22 D.2, E step 1 has
  the cherry-pick recipe: PR-b 4aa4728, 1b34195, ed1b75c; PR-c 6d3cacf,
  7b45433, 2375fea; drop PR-a's 0db8cc9, 24b56d3, 01355d5, 63ce030). Once #74
  re-lands, the 7 governance skills are missing at both levels until `aitools`
  runs: read `shared/skills/<name>/SKILL.md` by hand.

### 3.2 Post-merge, in order

1. #116 fix-forward (in its existing worktree/branch `fix/mf-installer-relay`;
   merge `main` in, never rebase or force-push), re-test, independent
   re-review, merge.
2. Apply #102 incidents (PR).
3. Re-land #74, then #75 (new branches off main; PR each; green; merge).
4. Small follow-ups: Step 8b `--skip-config`; approved drafts (3.1).
5. D-DEL5 + sources-of-truth.md review-after (A2), as versions, committed.
6. build-deploy backup-then-swap PR (.sh, and any .ps1 counterpart), merged;
   then rebuild the real dotprofile `deploy/` and commit + push the dotprofile
   (A4). After that, pre-push step 7 should PASS; verify it.
7. `plans/merge-friction-improvements.md` v1.0 (A7), direct to main.
8. RELEASE sub-orchestrator (A3, A5): GitHub cleanup, release notes v0.74.0,
   docs scrub, tag `v0.74.0` and push the tag.

### 3.3 Release-notes boundary (for A3)

- Last commit touching `RELEASE_NOTES.md`: 075c3da, 2026-10-03T05:09:35Z,
  "PR C1: EOF-safe prompts, one interactivity rule, --force reaches install
  (v0.73.3)" (`git log -1 -- RELEASE_NOTES.md`).
- File mtime in the main checkout: 2026-10-20T19:05:52-0700
  (2026-10-21T02:05:52Z) — this is a checkout/pull time, not an edit, so the
  git commit date is the boundary to use.
- Latest tag: v0.73.2 (`git tag --sort=-creatordate`); v0.73.3 notes exist but
  are untagged, and v0.74.0 folds them (handoff 2026-10-22 C, G9).

## 4. Things in the prompts that change or add to the goal

1. **The mission merges and tags.** Reverses "merging is the commander's" and
   D-DEL4's never-merge/never-tag for this mission (A1, A5). Packet section 4
   and the handoff still say otherwise; D-DEL5's write-up should record the
   exception so later delegates are not confused.
2. **The mission runs build-deploy against the real dotprofile** once, after
   the backup change merges (A4). Reverses handoff F.1 for that run only.
3. **Protected files: review-after replaces the pre-write gate** (A2), to be
   written into `.claude/rules/sources-of-truth.md` (and the user rule) by this
   mission.
4. **Friction reduction is a deliverable**, scoped as a plan (A7), fed by GitHub
   issues, PR history and commander session files. The commander's stated
   frictions: "the overhead of worktrees/prs" and work left as "draft".
5. **"ultracode"**: per packet section 3, it only helps if the Workflow tool is
   present; Agent-tool delegates do not have it. Orchestrate with the Agent tool.
6. **Release notes from commit and PR messages since the last notes update,
   "thorough", "be descriptive"** (A3).
7. **GitHub cleanup** ("any and all cleanup on github") — scope not defined;
   see Q2.

## 5. Running missions (do not touch their files)

FAN-PLAN (setup-user-claude fan-out plan), BUILD-PKG (`plans/build-package/`,
docs; scaffolding committed to main: 568fb5b, 8953371, 0ddd127), RECONCILE
(`plans/fan-plan-reconciliation.md`; covers #105 row 8, the false fan-out
claims, AnsA/AnsB apply batch). They commit to main: `git pull --ff-only`
before using the main checkout; stage only your own paths.

## 6. Open questions (each with a suggested answer)

- **Q1. Worktrees/PRs for code.** The commander dislikes their overhead (line
  7264), but only plans/, handoffs, relay and CLAUDE.md are exempted (B2).
  Suggested: keep PRs for code and other files (CI is the merge gate this
  mission depends on); put the overhead reduction into
  `plans/merge-friction-improvements.md` as proposals.
- **Q2. "any and all cleanup on github"**: which items? Suggested: after the
  last merge, delete the merged head branches (all PRs merged, so stacks no
  longer need them), close issues whose fix is verified in code on main with a
  comment citing the commit, and remove stale `refs/mdmpkg/*` refs — but never
  remove another agent's worktree. Ask before deleting branches of unmerged
  work (`feature/user-level-skills`, `fix/registry-paths`,
  `refactor/retire-reference-cards`) until #74/#75 have re-landed.
- **Q3. Release-notes boundary**: file mtime vs commit date (3.3). Suggested:
  the commit date of 075c3da plus everything since tag v0.73.2.
- **Q4. #102 range** #146-#161 (title) vs #146-#170 (report). Suggested: trust
  the batch file contents; fix the PR title.
- **Q5. Windows verification** (handoff G7) is not in the commander's MERGE-ALL
  orders. Suggested: release v0.74.0 with CI-only Windows coverage and say so in
  the release notes' "Verified on".

## 7. Provenance

- Prompts and answers: transcript lines 7306, 7286, 7264, 7257 (Session
  Commander analysis, not a commander decision), 7065, 6831, 6779, 6721, 6494,
  6071, 6041 (Session Commander record of the 2026-10-24 answers), 6024, 5980.
- Repo facts: `git -C /Users/new-jose/repos/aitools log --oneline -25
  origin/main`, `git log -1 -- RELEASE_NOTES.md`, `git tag`, `stat` of
  RELEASE_NOTES.md, `gh pr list -R nobul-tech/aitools --state open`, all run
  2026-10-26 by S3-MA-Brief.
- Read and stopped at line 5980 (2026-10-23T05:16Z): the goal was clear and
  older prompts are covered by handoff
  `.aitools/channel/handoffs/2026-10-22_10cf255a-c.md` and the plan file.
