# S3-Reconcile-Ledger findings: incident-ledger sync plan

**Delegate:** S3-Reconcile-Ledger (read-only research delegate of S3-Reconcile, Session Commander 10cf255a-c) · **Date:** 2026-10-26 · **Code baseline:** origin/main 8953371 (fetched 2026-10-26; code identical to 8e490d7 for every file cited: commits after it add only mission folders) · **Registry read:** registries/incidents.json on origin/main and origin/docs/mf-incidents, parsed in full with python3 json (`.scratch/session-rcledg/parse.py`).

## Summary (5 lines)

1. Registry on main: 145 ids (138 in `incidents`, 7 in `closed`), max 145, no duplicates, no gaps; next free id on main is **#146**. PR #102 (OPEN, MERGEABLE/CLEAN, merges into main without conflict) drafts **25 entries #146-#170**; after it applies, the next free id is **#171**.
2. Commander approval of the #146-#170 batch is in his own words: "1) protected drafts approved." (2026-10-24T22:45:50Z, uuid c86608ca), answering the SC message of 2026-10-23T05:16:38Z (uuid d773202c) that listed "the incident batch #146–#170. Suggest: yes."
3. The 23 claimed fixes (24 ids with #112): **17 close**, **6 update and keep open** (#74, #76, #77, #102, #116, #144), **1 keep open** (#112, until PR #99 merges). Three more verified close candidates: #86, #94 (and #33 unverified).
4. Markers: 162 marker lines from the named sources (excluding M3/MF sources that #102 already triaged) reduce to **47 new incidents (#171-#217 provisional)**, 8 updates of existing entries, and the rest already covered, fixed on main, or dropped.
5. Proposed order: merge #102 and apply it (#146-#170) first; then PR-L0 (closures and updates, no new ids), then five filing PRs L1-L5 (#171-#217), applied strictly in id order. All are protected writes to `registries/incidents.json`, which the channel exception does not cover, so each lands by PR after the commander approves its content.

## 1. Registry state and next id

Source: `python3 .scratch/session-rcledg/parse.py origin/main origin/docs/mf-incidents` (output verbatim):

```
== origin/main: meta=2026-10-21 open=138 closed=7
   max open=145 max closed=82 max all=145 dups=[]
   gaps=[]
== origin/docs/mf-incidents: meta=2026-10-21 open=138 closed=7
   max open=145 max closed=82 max all=145 dups=[]
```

- `registries/incidents.json` is the same on both refs (#102 does not touch it; `git diff --stat origin/main...origin/docs/mf-incidents` lists only 5 files under `S3-MF-Incidents/`).
- Next free id on main: **#146**. After #102's apply step: **#171** (#102's own dry run: "registry after: 163 incidents, 7 closed, max 170, unique True", PR #102 comment 2026-10-23T05:14:19Z).
- Closures do not consume ids (an entry moves from `incidents` to `closed` and keeps its id, /incident SKILL.md "Closing an incident").

## 2. PR #102 (docs/mf-incidents)

- State: OPEN, `mergeable: MERGEABLE`, `mergeStateStatus: CLEAN` (`gh pr view 102 --json`). `git merge-tree --write-tree origin/main origin/docs/mf-incidents` exits clean (tree e120f4e). Base main.
- Drafted ids: **#146-#170, 25 entries, contiguous** (`.scratch/session-rcledg/batch.py` on `S3-MF-Incidents-batch.json`), 14 medium + 11 low (PR comment 2026-10-23T05:15:46Z). The PR title still says "#146-#161" and the body still says "4 medium, 12 low": stale, cosmetic.
- Apply step: `S3-MF-Incidents-apply.py` (dry run default, `--write`; appends only; validates ids sequential from registry max + 1). It cannot close entries.
- Review trail: three independent re-checks posted as PR comments (2026-10-23T02:21Z, 02:28Z, 05:14Z), each "changes needed (small)", each answered by a fix commit (fadbbb0, 27ea6bc, fa90df0). No re-check after fa90df0 is on the PR.
- **Approval evidence (commander's own words):**
  - SC message 2026-10-23T05:16:38Z (uuid d773202c-c611-4710-9d89-6031adfa8b46): "**Protected drafts:** ... and the incident batch #146–#170. Suggest: yes." and "Answering 'all suggestions approved' covers both lists."
  - Jose, 2026-10-24T22:45:50Z (uuid c86608ca-5220-4f95-aa8c-31497c92fdb3): "1) protected drafts approved.  2) dotprofile pushes outside of main branch should error out 3) logging suggestions all accepted 4) re-state harness-2s decisions/questions".
  - So #146-#170 are approved as content. Point 2 changes #165's resolution (the SC suggested "WARN + ACTION, don't push"; Jose decided ERROR). The draft's suggestedResolution should name that decision before apply (see 4.3).
- Earlier "incidents approved" (prompt 2026-10-21, transcript prompt #8) concerns the #74-#145 batches, not #102.

## 3. The 23 claimed fixes, re-verified on origin/main

PR merge state from `gh pr view` (`.scratch/session-rcledg/prs.sh`); fix commits from `git log -S` (`.scratch/session-rcledg/pick.sh`). "closedIn" uses PR + commit (the /incident skill allows "version, or PR and commit"); version: **unknown**, v0.74.0 is not released (handoff 2026-10-22 G9). closedDate: the date the close is written.

| # | Observation (one line) | Claimed PR (state, merge commit) | Code evidence on origin/main | Verdict |
|---|---|---|---|---|
| 129 | Merge-without-adopt reverted by next run's auto-deploy (deploy state) | #68 MERGED 1d67da9 | Deploy-state helpers removed in 1d67da9 (`git log -S initialize_deploy_state`); reference/managed-file-deployment.md:40-42 "Removed 2026-10-21: ... the deploy-state helpers ... and the auto-merge menu"; merge exists only as `[m]erge & adopt` (aitools-lib.sh:1626, :1732; .ps1:1689) | **close** (closedIn #68 1d67da9; spec 378423c #70) |
| 130 | Bash deploy state treats missing node as corrupt manifest | #68 MERGED | No `deploy_state` code left (git grep: only the removal note at managed-file-deployment.md:41) | **close** (#68 1d67da9). Also comment on GitHub issue #30: its deploy-state rows are moot |
| 84 | /incident skill names reference/incidents.json | #71 MERGED 6dc9c99 | .claude/skills/incident/SKILL.md:48 "Read `registries/incidents.json` in full"; no `reference/incidents.json` in any live source (git grep; hits only in generated aitools `deploy/`, rfcs/, channel) | **close** (#71 6dc9c99) |
| 93 | framework-registry :183 lists reference/tool-ops.json | #71 MERGED | registries/framework-registry.json:183 `"registries/tool-ops.json",` | **close** (#71). The 'Tool lifecycle' refresh it mentioned was deferred to M2 by the entry itself |
| 102 | sources-of-truth.md lacks a .claude/skills row and reference/tool-registry.md; post-push step 10 lists tool-registry.md | #71 MERGED | Half fixed: check-post-push.sh:217 / .ps1:252 "reference/tool-registry.md is deprecated, T-Q7" (no longer listed). Not fixed: sources-of-truth.md Protected files table still has no `.claude/skills/*/SKILL.md` row | **update, keep open**: narrow to the skills row (path depends on the user/project skill split, #74/#75 re-land) |
| 114 | check-post-push.ps1 reads reference/tool-versions.json | #71 MERGED | No `tool-versions` read in check-post-push.ps1; :532 "(tool-versions.json was deleted, S2L-Q6 ...)" | **close** (#71) |
| 115 | No check that cited repo paths exist | #71 MERGED | check-pre-commit.sh:470-493 / .ps1:361-391 step 20 "Path references" runs scripts/check-path-refs.py with an allowlist | **close** (#71). Seeded-failure test not re-run here |
| 116 | Step 16 misses registries/ on PS1, tool-ops/tool-versions, and the claimed @-referenced scope | #71 MERGED | Code fixed: both scan `.claude/rules`, `.cursor/rules`, CLAUDE.md with `(reference\|registries)/` and 5 names (sh:342-345, ps1:340-345); comments now say "the @-referenced files of CLAUDE.md are not scanned" (sh:337-338). Not fixed: `.claude/rules/governed-data-access.md` "Enforcement" still says "Scope: pre-commit checks .claude/rules/, CLAUDE.md, and any @ referenced files in CLAUDE.md" | **update, keep open**: narrow to the rule text (protected draft) |
| 122 | /incident next id from a truncated read, incidents array only | #71 MERGED | SKILL.md:48-56 read in parts, "Note the highest ID across both the `incidents` and the `closed` arrays", python one-liner over both | **close** (#71) |
| 74 | Machine identity from kernel hostname, not scutil | #73 MERGED 507a6e1 | Matching fixed: resolver uses `scutil --get LocalHostName` (aitools-profile.sh:373-386, c1308f6) and machine ids; profile-check.js:119-123 "os.hostname() ... is never used (P-Q5)"; setup-user-claude.sh:94-100. Residual: telemetry `host` fields still from the kernel name: check-lib.sh:49 `hostname -s`, aitools-lib.sh:511 (`_aitlib_jsonl_init`), aitools-install.sh:126 | **update, keep open** (lower to low): narrow to the jsonl/checks `host` field, or close and file the residual. Suggest: update |
| 75 | user init never prompts for or persists the alias | #82 MERGED 8b8a6f3, #86 MERGED 21da322 | ui_register_flow (scripts/aitools:651-) registers this machine, prompts on a terminal, ERROR "not registered (no terminal)" (:404); config.json via setup-user-config with --machine-id (:1006-1033) | **close** (#82 f5939a2, #86 bb43536). Windows profile-function gap is #170 |
| 77 | Profile-mismatch check console-only, after deploy, wrong advice, false positive | #82/#86 MERGED | Fixed: false positive (profile-check.js:117-135 checks cached machineId); advice now works (`aitools user init` registers). Not fixed: check_profile still prints with raw `printf '\033[33mprofile: ...'` (scripts/aitools:89, :98), not logged or counted, and runs after deploy_configs (scripts/aitools:2207-2219) | **update, keep open**: narrow to logging/summary and ordering |
| 97 | user init writes config.json/profile.json without backup; swallowed catch | #82/#86 MERGED | config.json has one writer in user init, setup-user-config (scripts/aitools:1006-1033), which backs up (setup-user-config.sh:341, .ps1:339); profile.json via register to a temp file, validate, `backup_file "$pf"` (scripts/aitools:483-542; aitools.ps1:1138); the `could not update profile` catch is gone | **close** (#82 f5939a2). Residual config.json write in the entry-point key rename is a new entry (#192 below) |
| 76 | Silent first-profile fallback; spec endorses it | #83 MERGED 652c479, #95 MERGED da6ead7 | Code fixed: no `Object.values(p.profiles)[0]` anywhere (#102 triage row 14; setup-user-claude.sh:65-70 "no hostname or first-profile fallback"). Docs not fixed: .claude/rules/managed-file-deployment.md:51, .cursor/rules/managed-file-deployment.mdc:31, reference/managed-file-deployment.md:393, reference/user-repo.md:84 still say "then first profile". PR #101 (docs/m3-approved-drafts) removes all but reference/managed-file-deployment.md:393 | **update, keep open**: docs half; after #101 merges, only :393 remains |
| 78 | build-deploy bakes the building machine's profile values into deploy/ | #95 MERGED | build-deploy.sh has no `{{PROFILE_` tokens, no PROFILE_VALS, no identity defaults; deploy/setup-user-claude resolves on the target machine (setup-user-claude.sh:65-90 via the resolver; c421511) | **close** (#95 c421511). Docs in `affected` (deploy-paths.md, user-repo.md) not re-read |
| 95 | Hardcoded identity defaults in build-deploy | #95 MERGED | `git log -S 'IDENTITY_GIT_EMAIL="jose@nobul.tech"'` last touch c421511 (removal); no hit on main | **close** (#95 c421511) |
| 98 | inline_lib_* match any line naming the lib | #95 MERGED | build-deploy.sh:137 `/^\s*source\s.*aitools-lib\.sh/`, :164 `/^\s*\.\s.*aitools-lib\.ps1/` (c421511) | **close** (#95 c421511) |
| 109 | `eval "$PROFILE_VALS"` in build-deploy | #95 MERGED | Removed in c421511 (`git log -S`) | **close** (#95 c421511) |
| 110 | Token interpolation corrupts & and $ | #83/#95 MERGED | bash: perl with values via %ENV (setup-user-claude.sh:149-162, bc1f80f); PS1: MatchEvaluator (setup-user-claude.ps1:149); build-deploy no longer interpolates | **close** (#83 bc1f80f) |
| 99 | adopt filter builds a perl program from shell values | #83 MERGED | Adopt filter takes values from %ENV with quotemeta (setup-user-claude.sh:183-215; current form from 1d67da9/a87ffce) | **close** (#83; #68 1d67da9) |
| 111 | ait-harvest reads config.json as utf-8 (BOM breaks archiving) | #90 MERGED 7e3b48b | ait-harvest.py:212 `read_text(encoding="utf-8-sig")` (4b345cc) | **close** (#90 4b345cc) |
| 144 | #56/#58 merged over changes-needed reviews; sed guard in observe | #60 MERGED 845a935, #70 MERGED 378423c | Consequence fixed: standing-order-guard.sh:57 `MODE_SED="enforce"` (845a935). Process half partly: /delegate SKILL.md:257-264 has reviewers post verdicts as PR comments "so the verdict is visible before merge" (378423c). Not present: a rule that a changes-needed verdict blocks merge until a re-check passes (handoff 2026-10-22 I lists four more PRs merged before reviews were addressed). correctiveAction still says "PR #60 (open)" | **update, keep open**: fix correctiveAction (#60 merged 2026-10-22T02:48:58Z, 845a935; #70 378423c) and narrow to the merge gate |
| 145 | /scratch skill disagrees on location, deletion, attribution | #61 MERGED 29133cc, #70 | Skill realigned: `.scratch/session-<id>/` (:30), "Nothing in `.scratch/` is deleted by the harness" (:167), attribution copied from instructions (:119-122). The disagreement left is in the rule: .claude/rules/aitools-workspace.md still names `<repo>/.aitools/scratch/` (and :71) | **close** (#61 29133cc); the rule residual is new #174 |
| 112 | cross-platform.md says C:\repos\ | #99 OPEN | origin/main .claude/rules/cross-platform.md:8 still `C:\repos\`; origin/docs/harness-approved-drafts:8 has `%USERPROFILE%\repos\` | **keep open** until #99 merges, then close. Add `shared/cursor-rules/user-rules.md:28` to `affected` (S3-AnsA-report.md:171) |

Counts: close 17 (#129, #130, #84, #93, #114, #115, #122, #75, #97, #78, #95, #98, #109, #110, #99, #111, #145); update 6 (#74, #76, #77, #102, #116, #144); keep 1 (#112). The handoff G5 says "23"; its list names 24 ids because #112 is conditional.

**Additional close candidates (not in G5):**
- **#86** (build-deploy rm -rf leaves a half-built deploy/): fixed. build-deploy.sh:613 "Build into a staging dir; it replaces <dotprofile>/deploy only at the very end", :2302 `mv "$DEPLOY_DIR" "$DEPLOY_DIR_FINAL"` (PR #95, #102 triage close list).
- **#94** (pointer to tool-lifecycle.md "Deployment pattern updates"): fixed. .claude/rules/managed-file-deployment.md:104 and .mdc:59 now cite "Onboarding checklist", which exists in tool-lifecycle.md. Fix commit not identified.
- **#33**: suggested by the #102 reviewer; **not verified** here.

## 4. Markers

### 4.1 Sources and method

- Collected with `.scratch/session-rcledg/markers.py`: `git grep -n INCIDENT` on origin/main over the missions folder, the main-checkout working tree (untracked S3-BuildPkg/S3-FanPlan/S3-Reconcile), and 19 PR branches (#97-#116 heads, including feature/harness-hookin for S3-AbortDocs). 592 lines mention INCIDENT; `filter.py` keeps 162 real marker lines.
- **Excluded**: S3-M3-*, S3-Profile and S3-MF-Incidents (triaged by #102, rows 1-56); S3-BuildPkg and S3-FanPlan (running missions, not in this task's source list; BuildPkg-PkgWin-notes.md:158 repeats the Intune URL item); my own briefs.
- The audit 1E.8 list (S3-Handoff2-S2-session-state-audit.md:148) names 22 files. Its M3 files are covered by #102. The rest (S3-Harness, DiffUX, SourceTruth, SpecRewrite, RegCC, GateFix, ScratchRule, HooksFix, Incidents) are below, with the newer sources (HARNESS split hand-backs S3-H-*, HARNESS-2 S3-H2-*, AbortDocs, MdmPkg, AnsA, AnsB, Handoff2-V, MF-Fix3/4/5/6, MF-Relay, MF-NoMachine, MF-Runner, MF-Adopt).
- Each candidate was checked against all 170 titles and full text (`titles.py` regex scan), and its live state on origin/main by git grep (`verify.sh`, output in `.scratch/session-rcledg/verify.txt`). Severity follows the incident-governance table.

### 4.2 New incidents to file (draft titles; ids provisional, from #171 after #102)

**Batch L1: harvest, scratch, handoff and process (#171-#180)**

| Id | Draft title | Sev | Affected | Source marker(s) | Main evidence |
|---|---|---|---|---|---|
| 171 | The catch-up harvester matches scratch dirs by a 10-character prefix, so a longer `session-<name>` is never harvested and the miss makes it harvest the live session named in `.current-session` | high | scripts/ait-harvest.py, shared/hooks/session-catchup.sh, shared/hooks/scratch-init.sh | S3-ScratchRule-report.md:63; -incidents.md:13 (SR-8) | ait-harvest.py:92-94 `SCRATCH_PREFIX_LEN = 10`; only a doc workaround exists (/scratch SKILL.md:64-67) |
| 172 | `.scratch/.current-session` is one pointer per checkout, overwritten by every SessionStart and deleted by every harvest, so concurrent sessions misroute or drop hook telemetry | high | shared/hooks/scratch-init.sh, scripts/ait-harvest.py, hooks that read `_cs_file` | ScratchRule-report.md:64; -incidents.md:27 (SR-3) | /scratch SKILL.md:51 "session's start overwrites it and any harvest deletes it". Related #71 (different cause) |
| 173 | A git worktree's `.scratch/` is never harvested and `git worktree remove` deletes it without warning | medium | scripts/ait-harvest.py, shared/hooks/session-catchup.sh | ScratchRule-report.md:68 (SR-4); handoff I (S3-Hooks scripts lost) | /scratch SKILL.md:79-81 documents it; no code handles it |
| 174 | aitools-workspace.md describes a `.aitools/scratch/` + `.aitools/harvesting/` namespace and a `~/.aitools/deploy-state/` row that the harness does not use | medium | .claude/rules/aitools-workspace.md | ScratchRule-report.md:66 (SR-1); SpecRewrite-report.md:53 | aitools-workspace.md:48 `deploy-state/` row, :71; "Workspace structure" table names `scratch/` under `<repo>/.aitools/`; /scratch SKILL.md:42 "no hook or harvester uses that path today". Closes #145's residual |
| 175 | /handoff SKILL.md says scratch directories are deleted by the SessionEnd hook, though the harvester deletes nothing | medium | shared/skills/handoff/SKILL.md | ScratchRule-report.md:67 (SR-2) | handoff SKILL.md:318, :367, :545, :598. (The CLAUDE.md-template half of SR-2 is fixed: claude-shared.md:124 "Nothing in scratch is deleted") |
| 176 | /handoff Step 5 reads only a separate schwerpunkt-assessment file and has no variant for an assessment written inside the handoff | low | shared/skills/handoff/SKILL.md | S3-Handoff2-V-verification.md:267 | handoff SKILL.md:210, :239, :355 |
| 177 | No guard stops a stacked PR from merging into a stale base branch; #74/#75 merged into bases already merged to main | medium | shared/skills/delegate/SKILL.md, reference/pre-push-checklist.md | S3-Handoff2-V-verification.md:266; handoff 2026-10-22 I | `gh pr view 74/75`: base fix/registry-paths / feature/user-level-skills, merge commits NOT on main (prs.sh). Family of #144, #151 |
| 178 | No file-ownership lock exists between parallel missions, so a PR opened mid-mission edits files another mission owns | low | shared/skills/delegate/SKILL.md (ownership clause pattern) | S3-H2-DraftsM3b-handback.md:74 (docs/m3-approved-intents) | Packet section 6 states ownership per launch prompt only. Process |
| 179 | reference docs still describe the removed managed-file model (deploy-state migration, auto-merge menu, deploy-state dir) | medium | reference/agentic-framework.md, reference/post-push-checklist.md, reference/logging.md | SpecRewrite-report.md:53 | agentic-framework.md:170-178 "## Deploy state migration"; post-push-checklist.md:186 "auto-merge"; logging.md:38 "deploy-state". Glossary half routed to /glossary (4.4) |
| 180 | config-file-safety.md "Interactive managed file deployment" still uses the 3-way "when both sides differ" wording, and its backup section does not cover JSON written by the library | low | .claude/rules/config-file-safety.md | SpecRewrite-report.md:52 | config-file-safety.md:121 "when both sides differ" |

**Batch L2: library and deploy code (#181-#190)**

| Id | Draft title | Sev | Affected | Source marker(s) | Main evidence |
|---|---|---|---|---|---|
| 181 | backup_dir / Backup-Dir back up a directory only when it holds `*.md`, so an all-`.mdc` `~/.cursor/rules` never gets the directory backup config-file-safety.md requires | medium | scripts/aitools-lib.sh, scripts/aitools-lib.ps1 | S3-H-Cursor-handback.md:66; -Review-verdict.md:88; S3-Harness-handback.md:54 | aitools-lib.sh:925 `find ... -name '*.md'`; aitools-lib.ps1:820 `-Filter "*.md"` (9923a3c changed only -LiteralPath) |
| 182 | The bash AI merge runs invoke_ai inside `$(...)`, so AI_REJECT_REASON never reaches the caller and a failed merge logs "unknown error" | low | scripts/aitools-lib.sh | S3-SourceTruth-report.md:52; -Audit-findings.md:118 | aitools-lib.sh:1439 `merged=$(... invoke_ai ...)`, :1448 `${AI_REJECT_REASON:-unknown error}` |
| 183 | The AI merge prompt labels its diff "local vs source" while bash feeds a SOURCE->LOCAL diff and PS1 an unordered Compare-Object listing, so the two platforms give the model different, mislabelled input | medium | scripts/aitools-lib.sh, scripts/aitools-lib.ps1 | S3-DiffUX-handback.md:41-44 | aitools-lib.sh:1179 and .ps1:1123 "## Differences (unified diff: local vs source)"; .ps1:1629-1633 Compare-Object |
| 184 | `printf ... \| head` under pipefail can abort with SIGPIPE on large input, and the remaining instances in reusable scripts were never audited | low | scripts/aitools-lib.sh, scripts/aitools, shared/hooks/delegation-duty-guard.sh | S3-DiffUX-handback.md:45 | aitools-lib.sh:1456 `printf '%s\n' "$merged" \| head -30 \| while ...`; scripts/aitools:2022. Severity: marker said high; low because not reproduced on main (probe at filing) |
| 185 | check-post-push step 30 extracts return values with `\w[\w-]*`, so it never checks `accept & adopt` | low | scripts/check-post-push.sh, scripts/check-post-push.ps1 | S3-SourceTruth-report.md:59 | check-post-push.sh:766, :799; .ps1:904, :937 |
| 186 | The deploy tracker has no `removed` outcome, so a pruning consumer cannot report removals in its row | low | scripts/aitools-lib.sh, scripts/aitools-lib.ps1, reference/managed-file-deployment.md | S3-H2-Cursor-handback.md:74 (feature/harness-cursor-user-rules) | no `removed` outcome in deploy_tracker_record (git grep) |
| 187 | deploy-harness add_source filters `*.md` / `*.bak.*` case-sensitively in bash but case-insensitively in PowerShell, while both headers say names are compared case-insensitively | low | scripts/deploy-harness.sh, scripts/deploy-harness.ps1 | S3-H2-Manifest-handback.md:95 (feature/harness-rules-manifest); S3-FanPlan-Lib-findings.md:397 (probe) | deploy-harness.sh:26 header vs :197 `case ... *.bak.*`; .ps1:193 `-like` |
| 188 | A user abort (exit 2) in a setup script is logged by the lib relay as "<label> failed (exit 2)" with an ERROR row, so the summary reports a user choice as a failure | low | scripts/aitools-lib.sh, scripts/aitools-lib.ps1, scripts/aitools-install.sh, scripts/aitools-install.ps1 | S3-H2-Hookin-handback.md:46; S3-AbortDocs-handback.md:61 | aitools-lib.sh:613, .ps1:523. Commander kept #106's behaviour (common brief 2026-10-26); options: accept, or WARN "aborted by user" |
| 189 | The profile-mirror menu prints "[x]abort : stop the run" and deploy_abort comments cite "abort ends the whole run, T-Q3", though only a deploy-harness exit 2 stops a run | low | scripts/aitools-lib.sh, scripts/aitools-lib.ps1, .claude/rules/interactive-menus.md | S3-AbortDocs-handback.md:55, :67-69 | aitools-lib.sh:2376, .ps1:2359, interactive-menus.md:119. Check #106's 3de51d6 first: it may already cover the rule text |
| 190 | Two backup copies (`*.sh.bak.2026-06-21T*`) are tracked in shared/hooks, a source directory | low | shared/hooks/harness-db-sessionstart.sh.bak.2026-06-21T203304Z, shared/hooks/standing-order-guard.sh.bak.2026-06-21T203334Z | INCIDENT (this delegate) | `git ls-tree origin/main shared/hooks`. deploy-harness skips them (sh:197), git does not |

**Batch L3: entry points, installer, user init (#191-#200)**

| Id | Draft title | Sev | Affected | Source marker(s) | Main evidence |
|---|---|---|---|---|---|
| 191 | `aitools user init` claims an unowned profile named by `--alias`, AITOOLS_MACHINE_ALIAS, `[n]ew` or the default hostname without asking, with or without a terminal, against the approved row-3 text; the resolver comments say `--claim` is passed only after a terminal pick | high | scripts/aitools, scripts/aitools.ps1, scripts/aitools-profile.sh, scripts/aitools-profile.ps1 | S3-AnsB-report.md:207-208; S3-AnsB-CodeVer-results.md:62 | scripts/aitools:493-495 `extra+=(--claim "$okey"); mode=claim`; aitools-profile.sh:1299 and .ps1:1134 comments. Code citations from AnsB (bb43536); I read :479-499 |
| 192 | The `aitools` entry points rewrite ~/.aitools/config.json themselves (aiToolingRepoPath -> repoPath) with no backup or validation, bypassing setup-user-config, the declared single writer | medium | scripts/aitools, scripts/aitools.ps1 | S3-AnsB-report.md:209; S3-H2-DraftsM3-handback.md:65 and drafts/reference/user-repo.md.edit.txt:138 (docs/m3-approved-drafts) | scripts/aitools:1445-1469 node `writeFileSync`, no backup_file. Residual of #97 |
| 193 | When build-deploy skips because the AITOOLS_USER_REPO_PATH directory is missing, the warning goes only to deploy.log and the entry point prints OK "Rebuilt" | low | scripts/aitools, scripts/aitools.ps1, scripts/build-deploy.sh | S3-AnsB-report.md:229 | scripts/aitools:2054-2056 (build output redirected to LOG_FILE, then `log_ok "Rebuilt"`); aitools.ps1:2011 |
| 194 | tool_exception_record header comments still say exit 3 means "matched by hostname only or not at all" | low | scripts/aitools-lib.sh, scripts/aitools-lib.ps1 | S3-H2-DraftsM3-handback.md:66 | aitools-lib.sh:414, .ps1:346 |
| 195 | bootstrap.ps1 runs the installer with Windows PowerShell (`powershell`), not pwsh 7, and ignores its exit code | medium | scripts/bootstrap.ps1 | S3-GateFix-B-review.md:84 | bootstrap.ps1:48 `& powershell -NoProfile ...` |
| 196 | aitools.ps1 hardcodes one Git Bash path while setup-bash.ps1 probes three, none marked `# Verified:` | low | scripts/aitools.ps1, scripts/setup-bash.ps1 | S3-GateFix-B-review.md:86 | aitools.ps1:1989; setup-bash.ps1:28-30 |
| 197 | cross-platform-detail.md recommends Refresh-Path against Git Bash PATH shadowing, but its own "Refresh-Path behavior" says Refresh-Path only adds entries | low | reference/cross-platform-detail.md | S3-GateFix-B-review.md:85 | Not re-read here (ambiguity as reported) |
| 198 | The installer's `claude update` "up to date" match never fits what the updater prints, so an up-to-date run logs "claude update finished" | low | scripts/aitools-install.sh, scripts/aitools-install.ps1 | S3-RegCC-report.md:68; -Check-report.md:122 | aitools-install.sh:660, .ps1:583 `already.*up.to.date\|no update` |
| 199 | aitools-install Step 9 runs no Claude Code authentication check, against script-standards "Post-install authentication check" | low | scripts/aitools-install.sh, scripts/aitools-install.ps1 | S3-RegCC-report.md:72 | only `gh auth status` exists (install.sh:375, .ps1:281) |
| 200 | relay-outbound-prompt.sh still uses a bare EOF-unsafe `read -r choice < /dev/tty` | low | scripts/relay-outbound-prompt.sh (+ .ps1 twin unverified) | S3-HooksFix-report.md:70; -bare-reads.md:3; S3-Incidents-report.md:35 | relay-outbound-prompt.sh:77. The other listed sites are fixed (no other match on main; lib uses read_tty_choice, aitools-lib.sh:1366-1372) |

**Batch L4: docs, tool-ops, Cursor (#201-#210)**

| Id | Draft title | Sev | Affected | Source marker(s) | Main evidence |
|---|---|---|---|---|---|
| 201 | tool-ops-claude-code.md is stale: "Current version 2.1.81" (2.1.307 installed), item #1 gives two different last-verified versions, item #25 (no agent continuation) looks obsolete | medium | reference/tool-ops-claude-code.md, shared/skills/delegate/SKILL.md ("No follow-up messages") | S3-RegCC-report.md:69, :71; -Check-report.md:123 | tool-ops-claude-code.md:17, :100. Handoff G.5 also lists item #25 |
| 202 | shared/claude-shared.md (and the user CLAUDE.md built from it) says Claude Code on Windows always uses Git Bash and is not configurable; upstream has a PowerShell tool and PowerShell as primary shell when enabled | medium | shared/claude-shared.md, reference/tool-ops-claude-code.md | S3-RegCC-report.md:70; -Check-report.md:124 | claude-shared.md:81. Protected; propagates to every machine |
| 203 | managed-file-deployment.md and harness.md state a setup-user-claude fan-out of `~/.aitools/rules` that does not exist | medium | .claude/rules/managed-file-deployment.md, reference/harness.md | S3-AnsA-report.md:169; -Critic-verdict.md:139 | managed-file-deployment.md:48; harness.md:154-155 "the fan-out in `setup-user-claude` / `setup-user-cursor`". Resolves when FAN-PLAN's fan-out lands; file anyway until then |
| 204 | Cursor twins of Claude rules drift (deploy-paths.mdc contradicts deploy-paths.md), and whether parity is required is ambiguous: cursor-rule-parity.mdc and cursor-practices.md require it, 03933a5 removed it | low | .cursor/rules/deploy-paths.mdc, .cursor/rules/cursor-rule-parity.mdc, reference/cursor-practices.md | S3-AnsA-report.md:170; -Git-findings-q1-q4.md:97; -Critic-verdict.md:140; S3-H2-DraftsH-handback.md:118 | As cited (AnsA verified on main) |
| 205 | The `~/.cursor/AGENTS.md` relay mirror (install Step 22, `aitools` deploy) appears never to be loaded by Cursor | medium | scripts/aitools, scripts/aitools.ps1, scripts/aitools-install.sh, scripts/aitools-install.ps1 | S3-H-Cursor-handback.md:65; S3-Harness-handback.md:53 | aitools:1189; aitools-install.sh:845-847; .ps1:780-787. Needs the Cursor canary (handoff G15) |
| 206 | The rules fan-out contract does not say how Claude Code `paths:` scoping translates to each tool's scoping (Cursor user-rule globs are relative to $HOME) | low | reference/harness.md (fan-out contract), reference/tool-ops-cursor.md (once it lands) | S3-H-Cursor-handback.md:67; -Review-verdict.md:87; S3-Harness-handback.md:52 | Relevant to FAN-PLAN |
| 207 | reference/cursor-practices.md says Cursor User Rules are not file-accessible and the CLI reads only SQLite rules + project files, stale since `~/.cursor/rules` | low | reference/cursor-practices.md | S3-H-Cursor-handback.md:68; S3-Harness-handback.md:55 | cursor-practices.md:127, :137, :145 |
| 208 | reference/harness.md's intent scope is "architecture only", but it holds the operational conflict-handling section | low | reference/harness.md | S3-H-Core-handback.md:51; S3-Harness-handback.md:51 | Intent change is protected |
| 209 | standing-order-guard checks only a command's first token, so a multi-line command's later lines (`ls` + newline + `sed -i ...`) are not checked | low | shared/hooks/standing-order-guard.sh | S3-HooksFix-report.md:71 | Read, not tested, by HooksFix; probe at filing |
| 210 | build-deploy embeds skills and setup-user-claude rules through unchecked heredocs; only the deploy-harness payload is integrity-checked | low | scripts/build-deploy.sh | S3-H-MDM-handback.md:111 | Not re-verified |

**Batch L5: MDM path (#211-#217)**

| Id | Draft title | Sev | Affected | Source marker(s) | Main evidence |
|---|---|---|---|---|---|
| 211 | No size gate exists for generated deploy scripts; 7 generated .ps1 files are at least 200,000 B (the Intune limit) and the build passes; the Jamf limit is undocumented | medium | scripts/build-deploy.sh, .claude/rules/deploy-paths.md | S3-MdmPkg-report.md:190; -Build-notes.md:268; -Jamf-notes.md:127; S3-H2-MDM-handback.md:77 | no size check in build-deploy.sh (git grep `wc -c\|200000`: none). #111 adds one for deploy-harness only |
| 212 | The dev-path deploy order exists twice and differs (aitools-install.sh vs scripts/aitools), neither runs deploy-harness although the generated header says it runs first, and no MDM run-order manifest or README order includes it | medium | scripts/aitools-install.sh, scripts/aitools, scripts/aitools.ps1, README.md, scripts/build-deploy.sh | S3-MdmPkg-report.md:193; -Critic-review.md:98, :200; -Build-notes.md:277; S3-H-MDM-handback.md:110; S3-H2-MDM-handback.md:89 | scripts/aitools:1151 list (no deploy-harness); README.md has no deploy-harness. PR #106 changes the aitools half. Related #6 |
| 213 | The MDM path does not give "equivalent results" on a clean endpoint (no pwsh 7, node, Claude Code CLI or Homebrew install, no config.json bootstrap keys), and no doc says how deploy/ reaches an endpoint | medium | .claude/rules/deploy-paths.md, scripts/build-deploy.sh | S3-MdmPkg-report.md:194; S3-H2-MDM-handback.md:79 | deploy-paths.md:19 claim (MdmPkg). BUILD-PKG is the resolution mission |
| 214 | No spec says which run context (SYSTEM/root or the console user) each MDM-path script needs, and no script resolves the console user | medium | .claude/rules/deploy-paths.md, reference/managed-file-deployment.md | S3-MdmPkg-report.md:195; -Critic-review.md:202; -Jamf-notes.md:121 | "No spec exists for" (MdmPkg grep) |
| 215 | The library is embedded twice in the generated setup-user-claude, -cursor and -settings | low | scripts/build-deploy.sh | S3-MdmPkg-report.md:191; -Build-notes.md:271 | build-deploy.sh:707, :866, :1239 pass a resolver block to inline_lib_*; doubling not re-measured here |
| 216 | build-deploy's `trap 'rm -rf "$MDM_TMP"' EXIT` replaces the earlier EXIT traps, so BUILD_TMP (and the embed temp dir) leak on every build | low | scripts/build-deploy.sh | S3-MdmPkg-report.md:192; -Build-notes.md:275 | build-deploy.sh:320, :500, :1706 (three `trap ... EXIT`). Fixed on PR #111: close at once if #111 merges first |
| 217 | In the generated deploy-harness.ps1 an uncaught error inside `try { } finally { }` returned rc 0 under `pwsh -File` | low | scripts/build-deploy.sh, scripts/deploy-harness.ps1 | S3-H2-MDM-handback.md:83 (feature/harness-mdm-followups) | Reviewer probe only; scope unknown. Re-probe before filing |

### 4.3 Updates to existing or drafted entries (same protected gate)

| Entry | Update | Source |
|---|---|---|
| #73 | Extend: the classifier also harvests bookkeeping and staging files (msg-*.txt, PR bodies, `.harvested`, `.intelligence-last-check`, `events.jsonl`). Live evidence: this checkout's untracked `harvesting/2026-10-23_session-f486b184-c_.intelligence-last-check` and `..._events.jsonl` | S3-ScratchRule-report.md:65 (SR-5) |
| #87 | Resolution text is stale: it prescribes D-TS13's abort marker, which was reversed (packet section 6: "bare exit 2 = user abort; NO abort-marker file"), and the commander kept #106's behaviour. Add the residual ambiguity evidence: a `set -e` death, a syntax error and a truncated generated script also exit 2 | S3-Gate-B-review.md:63; S3-H2-Hookin-handback.md:47-48; S3-H2-MDM-handback.md:80 |
| #105 | Add: /tool-registry SKILL.md lists `overrides` as a per-tool section (it is top-level, SKILL.md:78) and has no field schema for `maintenance.*`, `versions.notes`, `versions.maintenanceFile`, `install.deprecated[].notes` | S3-RegCC-report.md:73; -Check-report.md:126 |
| #112 | Add `shared/cursor-rules/user-rules.md:28` to `affected`; close after PR #99 merges | S3-AnsA-report.md:171 |
| #51 | Recurrence: 2.1.307 sub-agents have no Grep/Glob (S3-RegCC-Check; this delegate's own tool list has neither), so the USO "Dedicated tools" text names tools that are absent | S3-RegCC-report.md:74; -Check-report.md:125 |
| #6 | Optional: cross-reference #212 (README MDM order omits deploy-harness) | S3-H-MDM-handback.md:110 |
| #166 (draft, #102) | Before apply: add the case of an existing file that already holds two keys differing only in case (bash engine keeps both, PS reader rejects, writers disagree, probe P3) | S3-MF-Fix3-Review-pr114.md:46 (fix/mf-audit-config) |
| #165 (draft, #102) | Before apply: record the commander decision "dotprofile pushes outside of main branch should error out" (2026-10-24T22:45:50Z, uuid c86608ca) in suggestedResolution | Transcript 10cf255a |
| #102 row 49 | Still pending: file "resolve_machine uses one message for not-v2 and no-profiles" only if PR #114 does not merge | S3-MF-NoMachine-report.md:70; #102 triage row 49 |

### 4.4 Already covered, fixed on main, or dropped

| Marker (source) | Disposition |
|---|---|
| Summary detail 30-char rule unenforced (S3-Gate-A-review.md:118) | covered: #103 |
| Installers' second ERROR row keyed by script name (S3-Gate-A-review.md:119) | covered: #142 |
| ensure_tool_on_path unguarded array (S3-Gate-B-review.md:64) | covered: #143 |
| Exit-2 ambiguity (Gate-B:63, H2-Hookin:48, H2-MDM:80) | update #87 (4.3) |
| user init ignores setup-user-hooks exit code (S3-GateFix-B-review.md:83) | fixed on main: scripts/aitools:1052-1062 checks hook_rc (2 = abort, 127, non-zero ERROR); aitools.ps1:1669-1682 |
| Pre-push step 7 trigger misses deploy-harness inputs (AnsA-report:168, Git-findings:65/96, Critic:138, H-MDM:104, H2-MDM:88, Harness:57) | fixed on main: 8e490d7 (check-pre-push.sh:110-113 "step 7 always runs", commander 2026-10-26). Not filed; mention in release notes |
| `shared/rules/` listed as a step-7 miss in an approved draft (AnsA-report:172) | moot after 8e490d7; draft errata on PR #111: fix in the PR |
| Backup-File without -LiteralPath (S3-H2-Cursor-handback.md:73; S3-H2-Manifest-handback.md:89) | fixed on main: 9923a3c (commander-ordered). Not filed |
| bash `_merge_validate` always returned 0 (S3-SourceTruth-report.md:51) | fixed by #68. Not filed (release notes only) |
| interactive-menus JSON auto-adopt direction wrong (SpecRewrite-report:47) | fixed: interactive-menus.md now "When the live file has a leaf that profile.json lacks, that leaf is auto-adopted" |
| cli-config.json listed under sync_managed_json (SpecRewrite-report:48) | fixed: agentic-standards.md "cli-config.json uses its own merge (setup-user-cursor)" |
| setup-user-claude rules adopt auto commit+push (SpecRewrite-report:49) | fixed: no git commit/push in setup-user-claude.sh (git grep) |
| Broken refs "Deployment pattern updates" / "MCP server isolation" (SpecRewrite-Check:116-117, report:51) | fixed on main (no citation left outside .cursor/rules/tool-lifecycle.mdc headings); close #94 |
| Adopt notice vs N-Q2 commit/push (S3-H-Core-handback.md:50; Harness:50; MF-Adopt) | covered: #164 (#102) |
| Fan-out contract copies `.bak` files (S3-H-Core-handback.md:52) | fixed: harness.md:159-160 "skips `*.bak.*`"; deploy-harness skips (sh:197, ps1:193) |
| build-deploy rm -rf leaves partial deploy/ (S3-H-MDM-handback.md:101; Harness:56) | covered by #86, which is fixed: close #86 |
| Windows repos path (S3-H-ToolOps-handback.md:58; -Review:36; Harness:59) | covered: #112 |
| check-path-refs-allow.txt:11-12 stale (S3-H-ToolOps-handback.md:59; H2-DraftsH:117; Harness:60) | not stale on main: reference/tool-ops-cursor.md does not exist on main (`git ls-tree`); it arrives with 76a4c45 (a PR branch). Remove the entries in that PR |
| managed-file-deployment.md abort continues vs SD-5 (S3-H2-Hookin-handback.md:47) | resolved by decision: keep #106's behaviour, docs fixed on #106 (3de51d6) |
| Intune URLs moved (MdmPkg-report:196; Intune-notes:118) | dropped: no harness file outside the channel cites `/intune/intune-service/` (git grep) |
| Dotprofile deploy/ stale (MdmPkg-report:189; Build-notes:262) | dropped as incident: tracked state, handoff G8 (commander rebuild) |
| H2-MDM truncation guard placed by offset (H2-MDM-handback:86) | dropped: PR-internal on #111; fix in the PR |
| Decision 2 (cached alias) recorded nowhere (AnsB-report:210; Transcripts:6, :34, :128) | not an incident: record it in plans/tool-support-and-machine-profile.md (channel exception, direct to main). Action for S3-Reconcile's plan |
| Handoff :102 attributes "one writer" to P-Q4; PR #95 body stale; AnsB brief errors (AnsB-report:211-213; Transcripts:85, :129-130) | dropped: record errata, not harness artifacts. Fix the handoff line directly if it is still relied on |
| user-prompts.py skips AskUserQuestion answers; sidechain user entries (AnsA-Trans:87-88; AnsA-report:173) | dropped: mission scratch tooling. Unknown whether scripts/read-session.py has the same gap (worth one check) |
| SR-6 guard scratch message says "clean up" (ScratchRule-report:69) | fixed: no scratch "clean"/"delet" text in standing-order-guard.sh (git grep) |
| SR-7 SubagentStart scratch hook not registered (ScratchRule-report:70) | covered: #126 |
| Grep/Glob missing in sub-agents (RegCC:74, Check:125) | update #51 |
| upstream changelog vs setup page on the PowerShell tool (RegCC-Check:127) | dropped: informational, upstream |
| MF-Fix4 node-not-found row; MF-Fix5 deploy-paths.md stale; MF-Relay mktemp, New-Item, --alias | covered: #167, #146, #153, #169, #170 |
| MF-Relay-ReviewA, MF-Runner, MF-NoMachine-Review, H2-DraftsM3b-Review | "none new" |
| Glossary term "profile" keyed by alias (S3-H2-DraftsM3-handback.md:67) | route to /glossary (registries/glossary.json:443 "keyed by machine alias"); commander approved the term fix 2026-10-24 ("1) protected drafts approved", uuid c86608ca, answering SC message bc9706dc of 2026-10-23T03:16Z: "The `user-repo.md` edits A–J, and the glossary term 'profile' ... Suggest: approve") |
| Glossary: "auto-merge menu", "merge-conflict menu", "accept & adopt" describe the removed model; candidates "review menu", "failed" (SpecRewrite-report:53) | route to /glossary |

**Needs verification before filing (not counted above):**
- check-path-refs.py reads `scripts/aitools-json.pl/.ps1` as one path (S3-H2-DraftsH-handback.md:116, author says unverified).
- A user-created hook adopted to the dotprofile is never deployed by any path (S3-Incidents-report.md:36; intended under SD-2: unknown).
- setup-user-skills adopts a shared skill into a dotprofile fork (S3-SpecRewrite-report.md:50; under the new model; not re-read).
- The real dotprofile deploy/ rebuilt by an outside process on 2026-10-21 03:42:49Z (S3-SourceTruth-report.md:53; operational; cause unknown, possibly #136's step 3 --fix).
- PS1 console input corrupted after Start-AiSpinner's job (S3-SourceTruth-report.md:60; pty harness only).

## 5. Filing plan

**Order**
1. **Merge #102, then apply it** (approved, #146-#170). First apply the two pre-apply edits in 4.3 (#165 decision, #166 two-keys case) on the PR branch. Its apply script checks that ids run from registry max + 1, so anything that adds ids must wait for it.
2. **PR-L0 "ledger sync: close and update"**: no new ids. Closes 17 + #86 + #94 (19), updates #74, #76, #77, #102, #116, #144 and the 4.3 rows for #73, #87, #105, #112, #51. #102's apply script only appends, so L0 needs a small close/update script (same guards: round-trip, temp -> validate -> replace, dry run by default). It can land before or after step 1 (closures touch other entries), but sequencing it after step 1 avoids a rebase of the same file.
3. **PR-L1 to PR-L5**: #171-#180, #181-#190, #191-#200, #201-#210, #211-#217, applied strictly in id order, each rebased after the previous one merges (same file, sequential ids). Re-check "max + 1" at write time: if another session files first, renumber the whole remaining range.
4. Close #112 when #99 merges, #216 if #111 merges first, and #76's last doc line after #101.

**Approval and landing.** `registries/incidents.json` is protected (sources-of-truth.md) and governed. The commander's approvals so far cover #146-#170 only. L0-L5 need their own approval. The channel exception (CLAUDE.md:77-82: handoffs, relay.md, plans/, CLAUDE.md) does not cover registries/, so each batch lands by worktree + PR (main's ruleset needs a PR with 1 approval). Suggested way to save the commander's time: present L0-L5 in one review page and take one approval, then ship them as sequential PRs (or one PR with six commits, applied in order).

**Id ranges:** main today: next #146. After #102: #171. L1 #171-#180, L2 #181-#190, L3 #191-#200, L4 #201-#210, L5 #211-#217. Max after all: #217.

## 6. Open questions (with suggested answers)

1. **One approval for L0-L5, or six?** Suggest one review page and one approval, six sequential PRs (or one PR with six commits).
2. **Residuals after a fix: update the old entry or close it and file new?** Suggest: update when the title still describes the residual (#74, #76, #77, #102, #116, #144), close + new when it does not (#145 -> #174, #97 -> #192).
3. **File already-fixed defects for provenance** (step-7 trigger, Backup-File LiteralPath, `_merge_validate`)? Suggest no: name them in the v0.74.0 release notes.
4. **#33**: close with #146 as its residual? Suggest verify in L0 (setup-user-hooks is the only template left, per the #102 reviewer).
5. **Version for closedIn**: suggest "PR #N (commit)" now and add "v0.74.0" when it is tagged.

## 7. INCIDENT markers from this delegate (not filed)

- INCIDENT: shared/hooks holds two tracked backup files (`harness-db-sessionstart.sh.bak.2026-06-21T203304Z`, `standing-order-guard.sh.bak.2026-06-21T203334Z`), drafted as #190.
- INCIDENT: PR #102's title and body still say #146-#161 and "4 medium, 12 low"; the batch is #146-#170, 14 medium and 11 low. Cosmetic; fix before merge.
- INCIDENT: #87's suggestedResolution prescribes the D-TS13 abort marker, a decision that was reversed (packet section 6). Drafted as an update in 4.3.
- INCIDENT (tooling): this delegate had no Grep or Glob tool (#51 recurrence).

## Provenance and limits

- Not read in full this run: .claude/rules files not already in my context (config-file-safety.md, deploy-paths.md, documentation-standards.md, hook-rollout.md, managed-file-deployment.md, relay-outbound.md, tool-evaluation.md, tool-lifecycle.md, web-sources.md), and the reference/* files the common brief lists. I cited specific lines from several of them through git grep. The handoff 2026-10-22 was read for sections G and I only.
- Not run: any probe or test; no Windows. Markers marked "as cited" rely on the source mission's evidence.
- Scratch scripts: /Users/new-jose/repos/aitools/.scratch/session-rcledg/ (parse.py, pr102.py, batch.py, claimed.py, prs.sh, g.sh, pick.sh + pick-in.txt, markers.py, filter.py, titles.py, verify.sh, before.py; outputs markers.tsv, real.tsv, verify.txt, prompts.txt, asks.txt).
- No sub-delegates were used.
