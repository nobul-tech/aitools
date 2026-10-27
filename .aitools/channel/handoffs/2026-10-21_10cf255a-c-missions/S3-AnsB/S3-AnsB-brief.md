# S3-AnsB delegate brief (shared by every S3-AnsB delegate; read in full)

**Intent**: **Purpose**: Give every S3-AnsB delegate the shared rules, learning, access and
question list for mission ANSWER-1B. **Scope**: shared part only; each launch prompt adds the
delegate's own task. NOT a decision record. **Audience**: S3-AnsB-CodeVer, S3-AnsB-GitHist,
S3-AnsB-Transcripts, S3-AnsB-Critic.

## 1. Rules (read before other work, by absolute path, unless already in your context)

- Mission packet: /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md
  -- read it in full AND every file in its section 1 (user rules, project CLAUDE.md files,
  every /Users/new-jose/repos/aitools/.claude/rules/*.md; for delegates the reference subset:
  reference/script-standards-detail.md, cross-platform-detail.md, logging.md,
  managed-file-deployment.md, plan-execution-detail.md, plus reference/user-repo.md).
- User: /Users/new-jose/.claude/CLAUDE.md, /Users/new-jose/.claude/rules/concurrent-agents.md,
  /Users/new-jose/.claude/rules/delegation.md
- Project: /Users/new-jose/repos/aitools/CLAUDE.md, /Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md
- Recursion: if you delegate, pass the packet path and this brief path unchanged, with the
  instruction to read both and the packet's section 1, and this same recursion instruction.

Critical rules restated:
- READ-ONLY mission. Edit nothing in any repo except your own output file(s) in
  /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-AnsB/
  and your scratch dir. Never switch the main checkout's branch. Never commit.
- Never run aitools, aitools install, setup-user-*, deploy-harness or build-deploy.sh.
- Simple Bash only: no &&, ||, ;, $(), backticks, multi-line commands; scratch scripts for
  anything longer. cat/head/tail/sed/awk only inside a pipeline (else use Read).
- Governed JSON (registries/glossary.json) only via the /glossary skill (read-only lookup).
- Firecrawl is deprecated: do not use it.
- Only the commander's own words (user prompts, AskUserQuestion answers, artifact answers he
  typed) or a record that quotes them count as "commander decided". Agent/delegate text is not
  a decision. A newer commander statement overrides an older one. Distinguish "commander
  decided" from "inferred from code".

## 2. Skills
/scratch (scratch dirs), /glossary (read-only), /incident (read-only), /investigate if useful.
If a skill will not load, read /Users/new-jose/.claude/skills/<name>/SKILL.md or
/Users/new-jose/repos/aitools/{shared/skills,.claude/skills}/<name>/SKILL.md and follow it by hand.

## 3. Operational learning (carry forward)
- Section I of /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md and packet section 5.
- CORRECTION (SC 10cf255a-c relaying the commander, 2026-10-26): the "[x]abort ends only that
  setup script; installer continues" decision is SUPERSEDED -- the commander keeps PR #106's
  current abort behaviour (S3-AbortDocs updates the docs). The channel exception is documented
  in /Users/new-jose/repos/aitools/CLAUDE.md (main 5976553: handoffs, relay.md and CLAUDE.md go
  directly to main).
- Commander decisions 2026-10-26 (session 10cf255a, not yet in files): dotprofile pushes from a non-main branch are an
  ERROR; handoffs and relay.md committed directly to main (channel exception); M3-FINISH
  protected drafts and logging suggestions approved; row 6 wording "... or --no-machine when
  they leave this machine unregistered" approved.
- Commander decisions 2026-10-22 (session 10cf255a, found by S3-AnsB in the transcript):
  2026-10-22T20:40:43Z "1) yes" to SC question 1 "`aitools user init --alias <new>` with no
  terminal: create the profile, but refuse an alias that belongs to another machine unless you
  confirm interactively?"; Q2 (cached alias -> register silently) was answered only "what?
  cached alias? cached how?" -- SC recorded it as PENDING; 2026-10-22T20:44:23Z "ok we need to
  rename it to like profiles.<machineID> to disambiguate between the various meanings of alias.
  aitools user init should create the profile.json file, and we deploy-harness should generate
  and deploy the config.json file from profile.json." 2026-10-22T03:34:05Z "NQ6) there should
  only be one" (context to be verified: which question NQ6 was). 2026-10-23T02:01:33Z
  "protected drafts approved." (approval of the #96 rows incl. row 3 user-repo.md text).
- M3Lead commander decisions 1-7: origin/docs/m3-lead-plan, file
  .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3Lead/S3-M3Lead-plan.md section 2.
- Delegates launched with Agent have it at levels 1-2, lose it at level 3. You may lack
  Grep/Glob: use grep/find in pipelines or scratch scripts. .ps1 files check out with CRLF.
- origin/main is 480b901 (drafts cite 8a9dcb5; 9923a3c and 480b901 came after: Backup-File
  -LiteralPath, and a handoff). Check whether cited lines moved.

## 4. Access (absolute paths)
- /Users/new-jose/repos/aitools (main checkout, read only). Read code at origin/main with
  `git -C /Users/new-jose/repos/aitools show origin/main:<path>` or the detached worktree
  /Users/new-jose/repos/aitools/.claude/worktrees/ansb (origin/main 480b901, read only).
- PR branches: `git -C /Users/new-jose/repos/aitools show origin/<branch>:<path>`;
  `gh pr view <n> -R nobul-tech/aitools --json ...`, `gh pr diff <n> -R nobul-tech/aitools`.
  Open PRs of interest: #98 feature/mf-config-no-machine, #113 fix/mf-lib-runner-result,
  #114 fix/mf-audit-config, #116 fix/mf-installer-relay, #101 docs/m3-approved-drafts,
  #115 fix/mf-lib-relay, #108 fix/mf-audit-profile-json, #106 feature/harness-hookin.
- Drafts under question (on PR #101 branch):
  origin/docs/m3-approved-drafts:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-DraftsM3/S3-H2-DraftsM3-drafts/reference/user-repo.md.edit.txt
  origin/docs/m3-approved-drafts:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-DraftsM3/S3-H2-DraftsM3-drafts/registries/glossary.json.edit.txt
  origin/docs/m3-approved-drafts:reference/user-repo.md (the file as landed on #101)
  origin/docs/m3-approved-drafts:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-DraftsM3/S3-H2-DraftsM3-handback.md
- Approval page: /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-Docs/S3-M3-Docs-approval-page.md (rows 2, 3)
- Transcripts: /Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/*.jsonl (live),
  /Users/new-jose/repos/aitools-nobul-jose/sessions/ (archive, read only).
  Prompt extractor (user prompts only): python3 /Users/new-jose/repos/aitools/.claude/worktrees/ansb/.scratch/session-ansb/user-prompts.py FILE --max-chars N
  Window dumper (assistant text + user prompts + AskUserQuestion answers in a time window):
  python3 /Users/new-jose/repos/aitools/.claude/worktrees/ansb/.scratch/session-ansb/window.py FILE START END
  Harness readers: python3 /Users/new-jose/repos/aitools/scripts/read-session.py --help
- Scratch: create /Users/new-jose/repos/aitools/.claude/worktrees/ansb/.scratch/session-<NAME> (NAME <= 10 chars).

## 5. The questions (edits on PR #101's draft; see the draft file for exact OLD/NEW)
For each of edits A, B, C, D, E, F, G, H, I, J and the glossary "profile" edit
("keyed by machine alias" -> "keyed by machine id"):
(a) is the NEW text true against origin/main code; (b) does it match or contradict a
commander decision; (c) will an open PR (#98, #113, #114, #116, others) make it false on
merge; (d) final text.
Special: C (user init claims an unowned profile with --claim instead of asking: did the
commander decide that? the approved row-3 text says --claim is passed "after the user picks
that profile at a terminal"); H (entry points rename aiToolingRepoPath in config.json
themselves vs "setup-user-config is the only writer" / "there should only be one": document
the exception or file a fix?); M3Lead decision 2 (silent registration of a cached alias, PENDING).

## 6. Name prefix (D-DEL1)
Every *.md you create starts with `S3-AnsB-<Role>-` (your role is in your launch prompt).
Never start a name with REPORT/SUMMARY/FINDINGS/ANALYSIS.

## 7. WRITE_BLOCKED
If any write or tool call is denied, do not retry it in another form. Record
`WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your response, continue.

## 8. Deliverable shape
One file S3-AnsB-<Role>-results.md in the S3-AnsB folder; your final response repeats it,
starting with a 5-line summary. Cite file:line / commit / PR URL / session id + timestamp for
every claim. Say "unknown" rather than guess. Mark deficiencies `INCIDENT:` (do not file).
