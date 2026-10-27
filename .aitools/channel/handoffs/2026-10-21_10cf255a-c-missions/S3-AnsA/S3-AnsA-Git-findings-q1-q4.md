# S3-AnsA-Git findings: Q1-Q4 provenance in git, GitHub and release notes

Delegate S3-AnsA-Git (git/GitHub historian, for S3-AnsA). Read only. Date 2026-10-26.
origin/main at fetch: 5976553 (it moved during the run; it was 480b901 at first fetch).

## Summary (5 lines)
1. PR #99 is still OPEN and unmerged: 7 commits, last df10361 (2026-10-23T02:20Z), CI all green, one agent review (no blocking findings), one agent comment, and no commander comment on GitHub. Since 8a9dcb5, origin/main has not touched any Q1-Q4 file. It changed only `scripts/aitools-lib.ps1`, `CLAUDE.md` and channel files.
2. Q1/Q2: the originals are the S3-H-MDM draft (`deploy-paths.md:87-89`) and the S3-H-Core draft. Git records their approval only as agent text ("commander approval 2026-10-22 (S3-Harness2 launch decisions)" in the #99 commits). The false "does not yet trigger" note was already false when it was drafted: the S3-H-MDM reviewer cited `shared/` in the step 7 regex.
3. Step-7 incident: it is **not filed** in `registries/incidents.json` on main or on any branch (the max id is 145 on main; PR #102's batch #146-#170 has no such entry). It exists only as INCIDENT markers and as H-MDM Q3 "step 7 policy", which the 2026-10-22 handoff lists as open. No PR or plan changes `check-pre-push` step 7. The suggested direction: widen the trigger, and report a stale `deploy-harness.*` as a WARN.
4. `.claude/hooks`: the S3-Harness brief lists it as a commander requirement ("hooks <- shared/hooks + .claude/hooks"), and it was known to be absent on main (brief:75, PR #88 body). The S3-H-MDM draft's sources bullet leaves it out, and git says nothing about why. PR #111 Edit 3 rewrites the same bullet.
5. Q3/Q4: in git, Q5 covers only cross-platform.md. `user-rules.md` is protected but is not recorded as a mirror of anything, although line 28 has the same text as `shared/claude-shared.md:36` except for the path. Git has no record of a Q4 (.mdc twin) approval. On parity, the records conflict: parity was "killed" in 03933a5 / RELEASE_NOTES:1087, but `cursor-rule-parity.mdc` and `cursor-practices.md` still require it.

---

## 1. PR #99 state and origin/main drift since 8a9dcb5

- **PR #99** https://github.com/nobul-tech/aitools/pull/99, "Write the approved HARNESS protected-file drafts", head `docs/harness-approved-drafts`, state OPEN, mergedAt null (`gh pr view 99`).
  - Commits: e4e1dea (tool-ops Intent), 76a4c45 (Cursor tool-ops entry), 95b9805 (deploy-paths .md + .mdc), eaa7031 (managed-file-deployment subsection), 9e70ca6 (cross-platform.md Q5), dab978d (handback + review), df10361 (allowlist + user-rules.md draft). Last commit 2026-10-23T02:20:26Z.
  - Review: one review, by S3-H2-DraftsH-Review, posted under the `nobul-jose` login, state COMMENTED, "NO BLOCKING FINDINGS", on 9e70ca6 (https://github.com/nobul-tech/aitools/pull/99#pullrequestreview-5623165189). It is agent text.
  - Comment: one re-verify of df10361, also by the agent (https://github.com/nobul-tech/aitools/pull/99#issuecomment-6355840087). Nothing on the PR quotes the commander.
  - Checks: macos, linux, windows, CodeQL and Analyze all SUCCESS. mergeable = UNKNOWN at query time.
- **origin/main since 8a9dcb5**: 9923a3c (aitools-lib.ps1 -LiteralPath), 480b901 (handoff + relay), 5976553 (CLAUDE.md channel exception). `git diff --stat 8a9dcb5 origin/main -- .claude/rules .cursor/rules reference shared scripts CLAUDE.md` shows only `CLAUDE.md` and `scripts/aitools-lib.ps1`. **None of these changed**: deploy-paths.md/.mdc, reference/managed-file-deployment.md, shared/cursor-rules/user-rules.md, check-pre-push.sh/.ps1, setup-user-claude.sh/.ps1.
- **Step 7 trigger on main (unchanged)**: `scripts/check-pre-push.sh:123` (blame: c421511d, 2026-10-22):
  `grep -E '^(scripts/(setup-.*|build-deploy|aitools-lib|aitools-profile)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|shared/)'`. The PS1 twin is `scripts/check-pre-push.ps1:126`, with the same regex. So `shared/hooks|skills|rules` DO trigger; `reference/`, `registries/`, `.claude/*`, `scripts/deploy-harness.*`, `scripts/*.py` and the dotprofile `claude/rules` do not.
- **setup-user-claude fan-out**: none on main (the #99 review N4 cites `setup-user-claude.sh:13`; `git grep "aitools[/\\]rules"` finds no hit). Open PRs #103, #112, #113, #115 and #116 touch setup-user-claude.sh/.ps1. None of them adds `~/.aitools/rules`: my grep of their diffs for `aitools[/\\]rules|HARNESS_RULES` added lines found no hit. The S3-H-Claude fan-out mission never produced a PR (S3-Harness-handback.md:5,25; 2026-10-22 handoff:223 "G12 (in flight, needs HARNESS Q1)").
- **Open PRs touching Q-files** (scratch `pr-files.sh`):
  - #99: the Q1, Q2 and Q3 drafts.
  - #100, #110 and #111: the S3-H2-Manifest drafts for `reference/managed-file-deployment.md`. These are other edits (the User rules row and a manifest paragraph), not the closing paragraph.
  - **#111** (`feature/harness-mdm-followups`): a draft `S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt` whose base is "the file as PR #99 writes it". **Its Edit 3 rewrites the same "Every `scripts/deploy-harness.*` source" bullet** that Q1b would add `.claude/hooks` to (it moves the payload to `deploy/deploy-harness.payload`). Its hand-back repeats the step 7 INCIDENT (S3-H2-MDM-handback.md:88).
  - #101: `.claude/rules/managed-file-deployment.md` and its .mdc (the rule, not the reference).
  - #105: `shared/claude-shared.md`.

## 2. Q1/Q2 originals, approval records, Q5 scope, user-rules.md status

**Q1 original (S3-H-MDM)**
- Draft: `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H-MDM/S3-H-MDM-drafts/dot-claude/rules/deploy-paths.md:87-89` (on main via PR #93, merged 2026-10-23T01:57:36Z): "Because of that last bullet, ... stale until `build-deploy.sh` runs again (pre-push step 7 does not yet trigger on them)." The sources bullet is at :82-85 and has no `.claude/hooks`.
- The false claim predates the draft. The S3-H-MDM reviewer had already written: "The step 7 trigger (`scripts/check-pre-push.sh:114`) watches only `setup-*`, `build-deploy`, `aitools-lib` and `shared/`" (S3-H-MDM-Review-verdict.md:72; PR #93 review https://github.com/nobul-tech/aitools/pull/93#pullrequestreview-5621367406). The handback's own INCIDENT list also includes `shared/rules/` (S3-H-MDM-handback.md:106), although only `^shared/` is in the regex. **Inferred from code**: the parenthetical was wrong for `shared/*` from the start.
- Held correction: on the #99 branch, `S3-H2-DraftsH/S3-H2-DraftsH-drafts/dot-claude/rules/deploy-paths.md.edit.txt`. Its "New (proposed)" text and the "Optional, same bullet" `.claude/hooks` addition match the Q1/Q1b text in the delegate brief.

**Q2 original (S3-H-Core)**
- Draft: `S3-H-Core/S3-H-Core-drafts/reference/managed-file-deployment.md` (on main via #88). The closing paragraph is at lines 30-32, per the held draft's header.
- Held correction: on the #99 branch, `S3-H2-DraftsH/S3-H2-DraftsH-drafts/reference/managed-file-deployment.md.edit.txt`. Its New text matches Q2's proposed wording verbatim.
- The applied deploy-paths text already says "(and `setup-user-claude` once it fans out)" (#99 branch `.claude/rules/deploy-paths.md:31`, `.mdc:16`), which agrees with the Q2 correction.

**Approval records in git (both)**
- The #99 commit bodies 95b9805 and eaa7031 say "Why: commander approval 2026-10-22 (S3-Harness2 launch decisions)". This is **agent text only**: the launch prompt is not in git, and I found no commander quote.
- The 2026-10-22 handoff (`.aitools/channel/handoffs/2026-10-22_10cf255a-c.md:153`) says #99's ".mdc twin ('please confirm') and its 2 held paragraphs need the commander's explicit confirmation". This is agent text.
- Transcripts (S3-AnsA-Trans) must confirm the commander's actual words. The delegate brief lists 2026-10-23T02:01:33Z "protected drafts approved. laurnch harness-2" as the likely source.

**HARNESS Q5 record**
- `S3-Harness/S3-Harness-handback.md:46`: "Suggested: standardise on %USERPROFILE%\repos, which means a protected edit to cross-platform.md." The question names only cross-platform.md.
- `2026-10-22_10cf255a-c.md:106`: "HARNESS Q5 (decided in chat): ... `%USERPROFILE%\repos\`, not `C:\repos\` (PR #99 applies it to cross-platform.md)." This is agent text reporting a chat decision.
- #99 commit 9e70ca6 and df10361: "The Q5 approval covered cross-platform.md only, so this file [user-rules.md] was not edited". The Q3 draft is `S3-H2-DraftsH-drafts/shared/cursor-rules/user-rules.md.edit.txt`. The DraftsH handback Q3 (:124) suggests yes.
- Incident #112 (open, low) has `affected: ['.claude/rules/cross-platform.md']` only. Its observation cites `shared/claude-shared.md` as already saying `%USERPROFILE%\repos\`, and it does not name user-rules.md.
- **Classification**: git does not record whether Q5 was meant to cover user-rules.md. On its face Q5 is scoped to cross-platform.md (agent framing). The delegate brief's "4) approved" (2026-10-23T01:58:29Z) and the running estimate's "Q5 framed as '`%USERPROFILE%\repos` everywhere'" are transcript claims I cannot check from git.

**Is user-rules.md protected and a mirror?**
- Protected: yes. `.claude/rules/sources-of-truth.md:14` describes it as "Cursor User Rules template (manual copy if needed)", and `.cursor/rules/sources-of-truth.mdc:20` says the same.
- A mirror: **no recorded mirror relation**. The file names itself as its own "Source of truth" (`shared/cursor-rules/user-rules.md:6`). deploy-paths.md "Template sync" pairs only `shared/claude-shared.md` with `<userRepoPath>/claude/CLAUDE.md`.
- Content overlap (inferred from code): `user-rules.md:28` "- Projects live in git repos under `~/repos/` (macOS) / `C:\repos\` (Windows)" and `shared/claude-shared.md:36` "... / `%USERPROFILE%\repos\` (Windows)" are the same line except for the path. claude-shared.md has said `%USERPROFILE%\repos\` since f89dd99 (2026-03-01). user-rules.md was last changed in ced624b (2026-10-04), and its repos line dates from ac87068 (2026-02-12).
- user-rules.md is not deployed by any script (`reference/cursor-practices.md:139`: the clipboard workflow was removed in v3.11; "copy ... directly"). Incident #127 (open) records that line 7 still claims a clipboard copy.

## 3. The step-7 incident

- **Registry**: no entry. I searched origin/main `registries/incidents.json` read-only, as the /incident skill reads it: max id 145, 145 entries. The step-7 entries are #137 (PS1 compares only top-level files) and the closed issue #32. Branch `docs/mf-incidents` (PR #102, OPEN) has the same registry; its batch #146-#170 has no step-7 trigger entry. `git grep -i "trigger misses"` over all origin refs hits only `S3-Harness-handback.md:57`. **INCIDENT: the step-7 trigger deficiency has never been filed. The title in the brief ("Pre-push step 7's trigger misses deploy-harness inputs") does not exist in the registry.**
- **Where it is recorded (all agent text)**:
  - `S3-H-MDM/S3-H-MDM-handback.md:104-109`: INCIDENT, with a list of missing inputs.
  - :125-126, Q3 "Pre-push step 7 policy": "Suggested answer: widen the trigger, report a stale `deploy-harness.*` as WARN naming the rebuild command, and keep FAIL for the extracted-logic scripts."
  - `S3-H-MDM-Review-verdict.md:65-74` (N2): it notes that widening "means most pushes FAIL"; staleness policy is "the commander's call".
  - PR #93 body, follow-up: "Pre-push step 7 trigger regex: add `reference/`, `registries/`, `.claude/rules/`, `.claude/skills/`, `scripts/deploy-harness.*` and the writer scripts."
  - `S3-Harness/S3-Harness-handback.md:57`: "The pre-push step 7 trigger misses the new deploy-harness inputs (S3-H-MDM)."
  - PR #111 branch, `S3-H2-MDM-handback.md:88`: "INCIDENT (carried from S3-H-MDM, still open)".
  - Untracked, main working tree: `S3-FanPlan/S3-FanPlan-Checks-findings.md:335` "INCIDENT I-4 (medium)".
- **Status**: H-MDM Q1-Q5, which includes the step 7 policy (Q3), is listed as open in `2026-10-22_10cf255a-c.md:212`. I found no commander decision on step 7 policy in git.
- **Fix in any PR/plan**: none. No open PR touches `scripts/check-pre-push.sh/.ps1` (scratch `pr-files.sh` over PRs 97-116). `plans/tool-support-and-machine-profile.md` does not mention step 7. Pre-push step 7 FAIL ("stale dotprofile deploy/") is accepted as a known failure in the mission packet section 4 and in the PR #103/#112-#116 bodies. That is a different failure (stale content), not the trigger gap.

## 4. `.claude/hooks` as a deploy-harness source

- Origin: `S3-Harness/S3-Harness-brief.md:16,23`, under the heading "Commander requirements (verbatim from the S3-Harness launch prompt)": "hooks <- shared/hooks + .claude/hooks". In the contract, :74-76 says: "hooks = shared/hooks, .claude/hooks ... A missing source directory (e.g. .claude/hooks does not exist on main) is an info log, not an error." **Classification**: the brief labels it as commander text, but it reached git through an agent-written brief. The transcripts must confirm the commander's words.
- Implemented in 56af161 (2026-10-22, PR #88): `scripts/deploy-harness.sh:257` `add_source hooks ".claude/hooks" ...`, `.ps1:241`, header `deploy-harness.sh:18`.
- PR #88 body: "`.claude/hooks/` is an optional source absent on main (cited by the two docs)". Its review says "A missing `.claude/hooks` is logged as info."
- Docs that list it: `reference/harness.md:116,142`, `.claude/rules/aitools-workspace.md:51`, the S3-H-Core draft line 24 (`reference/managed-file-deployment.md:414` on #99), and the allowlist line added in df10361.
- Intended to exist? No record says a `.claude/hooks` directory is planned. It was designed as an optional, absent source. `git ls-tree origin/main .claude/` lists only commands, rules and skills (#99 review N1).
- The MDM bullet's omission: the S3-H-MDM draft (:82-85) lists the sources without `.claude/hooks`, and git does not say why. `build-deploy.sh:1712-1729` parses every `add_source` line, so `.claude/hooks` would be embedded if it existed (inferred from code). Q1b is only DraftsH's "Optional, same bullet" suggestion (agent text).
- Sequencing: PR #111 Edit 3 replaces the tail of the same bullet. Any Q1b edit must be merged with it.

## 5. .mdc twin approval and cursor-rule parity

- **Q4 approval in git**: none. #99 marks c3 "**Derived from approved text, please confirm**" (body; commit 95b9805; DraftsH handback :11,:24,:125 "I suggest yes. An alternative is to mirror the `.md` body verbatim under the `.mdc` frontmatter"). The review N2 found that the approved paragraphs are carried verbatim (agent text). The commander's "1d) approved" (2026-10-26T21:58:13Z, per the brief) exists only in transcripts.
- **Parity expectations: the records conflict.**
  - Killed: 03933a5 (2026-03-13, v0.54) deleted `.claude/rules/cursor-rule-parity.md`; commit body: "kill cursor rule parity". RELEASE_NOTES.md:1087: "**Cursor rule parity killed**: ... Claude Code and Cursor are separate tool harnesses managed independently — no parity requirement." :1104: "Replaced by 'Separate tool harnesses' design principle". The principle was in CLAUDE.md from 03933a5 and was removed from CLAUDE.md in b504c43 (2026-03-28, "swan song"). It survives in `plans/governance-and-compliance-framework.md:17`.
  - Still live: `.cursor/rules/cursor-rule-parity.mdc` (from f89dd99, never changed since; alwaysApply true): "When modifying rules in `.claude/rules/*.md`, also update the corresponding `.cursor/rules/*.mdc` file (and vice versa)." `reference/cursor-practices.md:151-179` "Rule Correspondence": "When changing rules, update both sets". :166 lists `deploy-paths.md` ↔ `deploy-paths.mdc` as "Near-identical", and :160 still lists the deleted `.claude/rules/cursor-rule-parity.md`.
  - In practice, agents keep treating the .mdc as a twin: the S3-Harness handback:33 says "The .mdc twin is not drafted"; the DraftsH handback:118 says it "already lagged ... The parity rule ... has no check"; S3-FanPlan-Checks C14 (untracked) says deploy-paths.mdc needs follow-up twin edits after #99.

## INCIDENT markers (not filed)
- INCIDENT (medium): the pre-push step 7 trigger gap was raised by four missions and never filed in `registries/incidents.json` (sources in section 3).
- INCIDENT (low): `.cursor/rules/cursor-rule-parity.mdc` and `reference/cursor-practices.md:151-179` require Claude/Cursor rule parity. 03933a5 and RELEASE_NOTES.md:1087 record that parity was removed. cursor-practices.md:160 maps a `.claude/rules/cursor-rule-parity.md` that no longer exists. So whether the .mdc twins are required is ambiguous.
- INCIDENT (low): incident #112's `affected` list omits `shared/cursor-rules/user-rules.md:28`, which carries the same `C:\repos\` line.
- INCIDENT (low): S3-H-MDM-handback.md:106 lists `shared/rules/` as a step-7 miss, but `^shared/` matches it. The same error went into the approved draft text (:89).

## Open questions (suggested answers)
- Q1c: should step 7 be fixed instead of documented? Git has no commander decision. I suggest both: apply the corrected note now, which is accurate against main, and file the step-7 incident with H-MDM Q3's suggested resolution (widen the trigger, WARN on a stale `deploy-harness.*`).
- Q1b: since PR #111 Edit 3 rewrites that bullet, I suggest making the `.claude/hooks` addition in the same edit, after #99 merges.

## Method / sources
`git fetch origin`; `gh pr view 99 --json ...`; `gh pr list --state all`; scratch scripts in `/Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/session-git/`: `pr-files.sh`, `pr-grep.sh`, `inc-find.py` and `grep-all-refs.sh`. Also `git show/grep/blame/log -S` on origin refs, `gh issue list --search`, and grep of RELEASE_NOTES.md, relay.md, handoffs and the gate plan (no hits for step 7, user-rules or parity in the relay or the plan). Not read: session transcripts (S3-AnsA-Trans's scope).

WRITE_BLOCKED: none.
