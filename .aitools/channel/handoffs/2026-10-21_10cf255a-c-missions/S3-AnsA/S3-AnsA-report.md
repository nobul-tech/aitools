# S3-AnsA report: answers to the held HARNESS draft questions (2026-10-26)

From S3-AnsA to Session Commander 10cf255a-c. Read-only mission: no repo files were changed. The only files written are in this folder, plus scratch scripts in `/Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/`.
Fact base: origin/main 5976553. None of the Q1-Q4 target files changed since 8a9dcb5 (S3-AnsA-Git §1). PR #99 is OPEN at head df10361, with no commits since 2026-10-23T02:20Z.

## Summary (5 lines)
1. **Q3 and Q4: answered from the commander's words; apply them.** Q3 rests on HARNESS Q5 ("`%USERPROFILE%\repos` everywhere", approved "4) approved"). Q4 rests on "1d) approved", which covers the twin as it stands at df10361.
2. **Q1b: answered; add `.claude/hooks`.** The commander said "hooks/ is populated with all of shared/hooks and .claude/hooks" (2026-10-22T00:04:12Z).
3. **Q1 and Q2: answered, with corrected text.** The critic found wording problems in the held proposals, and I fixed them. The facts hold on main. Q2 is the commander's ordered design (both scripts fan out) but is not yet the code.
4. **Q1c is open. The commander never decided the step-7 trigger policy.** It was never put to him, and the gap was never filed as an incident (four missions raised it as markers only). Suggested answer below.
5. **New blocking items:**
   - The same false "setup-user-claude fan-out" claim is already merged in two protected files.
   - PR #111 Edit 3 rewrites the same deploy-paths bullet.
   - PR #110 narrows the Cursor fan-out.
   - New `.mdc` text beyond df10361 is not covered by "1d".

## Q1. deploy-paths.md / .mdc staleness note

**Answer:** apply a corrected note. The approved parenthetical is false for `shared/`: `scripts/check-pre-push.sh:123` and `.ps1:126` match `^shared/`.

The held proposal needed four changes (S3-AnsA-Critic A1):
- It used "directories" for things that are files: the bin CLIs and `scripts/deploy-harness.*`.
- It listed `<userRepoPath>/claude/rules`, which an aitools pre-push can never see.
- Its "not yet" implies a policy that does not exist (see Q1c).
- It has to include `.claude/hooks` if Q1b lands.

**Final text to apply.** It goes directly after the "Every `scripts/deploy-harness.*` source ..." bullet in `.claude/rules/deploy-paths.md`, and the same text goes into `.cursor/rules/deploy-paths.mdc`:

```
Because of that last bullet, a change to any of those sources makes the
dotprofile `deploy/deploy-harness.*` stale until `build-deploy.sh` runs again.
Pre-push step 7 triggers only on the `shared/` ones, and then rebuilds and
diffs the whole dotprofile `deploy/`. A push that changes only `reference/`,
`registries/`, `.claude/hooks`, `.claude/skills`, `.claude/rules`,
`scripts/deploy-harness.*` or the bin CLIs does not trigger it, and
`<userRepoPath>/claude/rules` lives in the dotprofile repo, which an aitools
push never sees.
```

If Q1b is not applied, drop `.claude/hooks,` from the list.

**Provenance**
- Approval of the original MDM draft (#93):
  - 2026-10-23T02:01:33Z, uuid 0527e51d: "protected drafts approved. laurnch harness-2,".
  - This answered the assistant's 01:59:48Z item "approve those protected drafts" (#96 and the HARNESS PRs). The list it referred to (00:36:13Z item 5) names #93.
- Code:
  - `check-pre-push.sh:123`, `.ps1:126` (step 7 trigger);
  - `check-pre-push.sh:148-169` (the rebuild-and-diff);
  - `deploy-harness.sh:254-266`, `.ps1:238-247` (sources and bin list);
  - `build-deploy.sh:1710-1729` (parses every `add_source`).

**Confidence:** high on the facts. The wording is new, so it needs the commander's sight because it is protected text.

**Sequencing:** PR #111 (`feature/harness-mdm-followups`, OPEN; approved under "1e") has an Edit 3 that rewrites the tail of the same bullet. Its base is "the file as PR #99 writes it". Apply this note in a way that keeps Edit 3's OLD anchor line intact, or re-anchor Edit 3. The phrase `deploy/deploy-harness.*` still covers its new `deploy-harness.payload`.

### Q1b. Add `.claude/hooks`

**Answer:** yes. In the sources bullet, write `shared/hooks`, `.claude/hooks`, `shared/skills`, ... in both the .md and the .mdc.

**Provenance**
- Commander, 2026-10-22T00:04:12Z, uuid 65461507: "1) hooks/ is populated with all of shared/hooks and .claude/hooks. reference with all of reference/. registries with all of registries/, skills with all of shared/skills and .claude/skills."
- It is not overridden. The older AskUserQuestion answer of 2026-10-21T02:15:49Z, "lets keep a single version for now in shared/hooks", was about dotprofile `claude/hooks` copies, and it is older anyway.
- Code: `deploy-harness.sh:257`, `.ps1:241`.

**Confidence:** high.

**Caveats:**
- `.claude/hooks` has no tracked files on main (`git ls-tree origin/main .claude/` lists only commands, rules and skills). The bullet is correct as a source list.
- Do not reflow the line PR #111 Edit 3 anchors on.

### Q1c. Fix step 7 instead?

**Status:** open (ambiguous). There is no commander decision.

**What exists:**
- The policy question was raised as H-MDM Q3 (S3-H-MDM-handback.md:125-126). The 2026-10-22 handoff lists it as open (handoff:212).
- It was never in a question list the commander answered: a grep of user prompts and AskUserQuestion answers finds nothing (S3-AnsA-Trans, S3-AnsA-Critic).
- It is not filed in `registries/incidents.json`, on main or on PR #102. No GitHub issue exists either (S3-AnsA-Git §3, spot-checked with `git grep -i "step 7"` on the registry).

**Question for the commander:** should step 7 trigger on every deploy-harness source?
- Suggested answer: yes. Widen the regex to `reference/`, `registries/`, `.claude/(hooks|skills|rules)/`, `scripts/deploy-harness.*` and the bin CLIs.
- When the only thing stale is `deploy-harness.*`, report a WARN that names the rebuild command. Keep FAIL for the extracted-logic scripts. This is the H-MDM suggestion.
- The S3-H-MDM reviewer's caution (verdict N2): widening means most pushes hit the known stale-deploy failure until the dotprofile is rebuilt. That is the reason for WARN.
- Meanwhile, apply the Q1 note as written. It describes main truthfully, with no "yet".

## Q2. reference/managed-file-deployment.md closing paragraph

**Answer:** apply the corrected paragraph.

**Final text to apply.** It goes directly after the "Deployed harness (`~/.aitools`)" table, before the "`userRepoPath` resolution" paragraph:

```
Rules reach Cursor from `~/.aitools/rules/` through the `setup-user-cursor`
fan-out, and Claude Code through `setup-user-claude` once it fans out (today
it deploys `<userRepoPath>/claude/rules/` directly). Conflict handling and
its assumptions: `@reference/harness.md` "Deployed harness (`~/.aitools`)".
```

If PR #110 merges first, replace "Rules reach Cursor" with "User-level rules reach Cursor" (#110 fans out only `shared`/`dotprofile` rules).

**Provenance**
- The commander ordered the design:
  - 2026-10-22T01:12:49Z, uuid fc194c92: "we need to wait for deploy-harness to run, then setup-user-claude.sh/ps1 and setup-user-cursor.sh/ps1 should fan them out."
  - 2026-10-22T03:52:53Z, uuid 1110b464: "store all three in a single top level directory ~/.aitools/rules ...".
  - 2026-10-23T01:58:29Z, uuid e073aea3: "3) put aitools rules in the user space of claude code". The assistant read this at 02:01:55Z as all rules to `~/.claude/rules` and Cursor user-level only, then launched HARNESS-2. The Cursor half is commander-implied.
  - 2026-10-26T21:58:13Z, uuid cb1f0201: "6) re-factoring setup-user-claude and the fan-out requires a mission to create a plan" (FAN-PLAN).
- Code: `setup-user-cursor.sh:389` reads `~/.aitools/rules`. `setup-user-claude.sh:13,291-292` reads `$USER_REPO_PATH/claude/rules`. There is no `aitools/rules` in setup-user-claude.sh/.ps1, and no open PR adds one (S3-AnsA-Git §1).
- The deploy-paths text already says "(and `setup-user-claude` once it fans out)" (PR #99 `deploy-paths.md:31`), so the two files agree.

**Confidence:** high.

## Q3. shared/cursor-rules/user-rules.md:28

**Answer:** yes, apply it.

**Final text** (replaces line 28):

```
- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
```

This is the draft already on PR #99: `S3-H2-DraftsH-drafts/shared/cursor-rules/user-rules.md.edit.txt`.

**Provenance**
- What the commander was asked:
  - 2026-10-22T22:09:16Z, uuid a2228969: "**Q5:** the Windows repos path is `%USERPROFILE%\repos` everywhere. cross-platform.md says `C:\repos`, so that's a protected edit."
  - The re-list at 2026-10-23T00:36:13Z, item 4: "HARNESS Q2–Q6: ... `%USERPROFILE%\repos` ... **Yes.**"
- His answer: 2026-10-23T01:58:29Z, uuid e073aea3: "4) approved".
- The narrower "cross-platform.md only" scope came from the orchestrator prompt to S3-H2-DraftsH (uuid 009f1f4b), not from the commander (S3-AnsA-Trans).
- Corroboration:
  - the new line is byte-identical to `shared/claude-shared.md:36`;
  - the commander's own `~/.claude/CLAUDE.md` says the same;
  - `scripts/aitools-install.ps1:324,333` defaults to `Join-Path $env:USERPROFILE "repos"`.

**Confidence:** high.

**Follow-up:** incident #112's `affected` list omits this file.

## Q4. Derived .cursor/rules/deploy-paths.mdc twin

**Answer:** approved as derived. This is recorded provenance, not a new decision.

**Provenance**
- Commander, 2026-10-26T21:58:13Z, uuid cb1f0201: "1d) approved".
- It answered the assistant at 2026-10-24T22:46:02Z: "d. The `.mdc` twin in #99 (`deploy-paths.mdc`), derived from approved text. Suggest: confirm."
- The approved version is PR #99 head df10361 (no later commits).

**Confidence:** high.

**Limits:**
1. The approval covers that text only. The Q1, Q1b and #111 edits to the `.mdc` are new protected text, so show them together with the .md edits.
2. Lines the twin inherited from main's condensed `.mdc` still contradict its `.md`: "Verify via pre-commit steps 3+10", and "MDM path (`deploy/setup-*.sh/.ps1`)". PR #99 did not introduce them (S3-AnsA-Critic A4).

## Additional questions found (surfacing duty, with suggested answers)

1. **The same false fan-out claim is already merged.**
   - Where: `.claude/rules/managed-file-deployment.md:48` ("Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out"), `reference/harness.md:154-155`, and `.claude/rules/aitools-workspace.md:52` ("copied to each tool's rules location by `setup-user-claude` / `setup-user-cursor`"). The PR #111 Manifest drafts say "the fan-out consumers".
   - Should these get the Q2 correction too, or stay as design statements until FAN-PLAN ships?
   - Suggest: correct them in the same batch with the Q2 wording pattern ("..., and Claude Code through `setup-user-claude` once it fans out"). All three are protected.
2. **Cursor rule parity is ambiguous.**
   - Parity was "killed" in 03933a5 (RELEASE_NOTES.md:1087), yet `.cursor/rules/cursor-rule-parity.mdc` and `reference/cursor-practices.md:151-179` still require it.
   - Do .mdc twins stay required?
   - Suggest: yes for twins that exist (the commander's "1d" treats the twin as maintained), and file an incident to reconcile the two records. Whether the original "parity killed" was the commander's own words is unknown.
3. **Order of applying the edits.**
   - Suggest: merge #99 (after the Q1/Q2/Q3 edits are added to it), then rebase #111 and apply Edit 3 on top. #110 can go either way; use the conditional Q2 wording.

## INCIDENT markers (not filed; for the Session Commander)
- INCIDENT (medium): the pre-push step 7 trigger (`check-pre-push.sh:123`, `.ps1:126`) misses the deploy-harness sources `reference/`, `registries/`, `.claude/{hooks,skills,rules}`, `scripts/deploy-harness.*` and the bin CLIs. Four missions raised it and nobody filed it. The incident text should say the gap is the trigger, not the comparison.
- INCIDENT (medium): protected docs on main state a setup-user-claude `~/.aitools/rules` fan-out that does not exist. See additional question 1.
- INCIDENT (low): `deploy-paths.mdc` contradicts `deploy-paths.md` in places, and no check enforces parity.
- INCIDENT (low): incident #112's `affected` list omits `shared/cursor-rules/user-rules.md`.
- INCIDENT (low): `S3-H-MDM-handback.md:106` lists `shared/rules/` as a step-7 miss, but `^shared/` matches it. That error went into the approved draft.
- INCIDENT (low, tooling): my `user-prompts.py` skips AskUserQuestion answers, because they arrive as tool_result. S3-AnsA-Trans wrote `ask-answers.py` to cover them. I ran it on 10cf255a: 9 answers, all from 2026-10-21, and none settles Q1-Q4 beyond the hooks item.

## Delegates and verification
- **S3-AnsA-Trans** (transcripts f486b184, 360aa8f3, 0d7004b4, 8c943007, the dotprofile archives, and 10cf255a subagent prompts). File: `S3-AnsA-Trans-findings-q1-q4.md`.
  - It found no newer or contradicting commander words.
  - Verified: I re-ran `ask-answers.py` on 10cf255a myself.
- **S3-AnsA-Git** (git, PRs, release notes, incidents, handoffs). File: `S3-AnsA-Git-findings-q1-q4.md`.
  - Spot-checked: the step-7 registry grep, RELEASE_NOTES.md:1087, PR #99 `deploy-paths.md:31` "once it fans out", and PR #99's state and files.
- **S3-AnsA-Critic** (independent; it did not see my reasoning). File: `S3-AnsA-Critic-verdict.md`.
  - Verdicts: A1 and A2 weakened (both fixed above); A1b, A1c, A3 and A4 stand.
  - Spot-checked: PR #110's body (user-level-only Cursor fan-out, citing HARNESS Q1) and PR #111's branch and state.
- **Me:** I read the current session's main-thread user prompts and the assistant text they answered, newest first. Code checks on origin/main are cited inline.
- **Not done:**
  - I read only the parts of `reference/*.md` that bear on these questions, not all of them.
  - Nobody read the review comments on #110 or #111.
  - Correction relayed: the "abort ends only that setup script" item is superseded (PR #106 behaviour kept). I added it to the common brief, so S3-AnsA-Critic, launched after that edit, received it. S3-AnsA-Trans and S3-AnsA-Git had already finished by then. It does not affect any answer here.
- WRITE_BLOCKED: none.
