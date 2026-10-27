# S3-AnsA delegate common brief (read in full; pass this path and the packet path to any delegate you launch)

## Packet and rules
Read `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`
in full first, and every file in its section 1 that is not already in your
context (user: /Users/new-jose/.claude/CLAUDE.md, /Users/new-jose/.claude/rules/concurrent-agents.md,
/Users/new-jose/.claude/rules/delegation.md; project: /Users/new-jose/repos/aitools/CLAUDE.md,
/Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md and every file in
/Users/new-jose/repos/aitools/.claude/rules/ as listed in the packet; reference subset:
/Users/new-jose/repos/aitools/reference/script-standards-detail.md, cross-platform-detail.md,
logging.md, managed-file-deployment.md, plan-execution-detail.md). The delegation
duty is recursive: if you delegate, pass the packet path and this file's path
unchanged, with the same instruction.

Critical rules restated:
- READ ONLY. No edits to any repo except writing your own output file in
  /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-AnsA/
- Never run aitools, setup-user-*, deploy-harness or build-deploy against the real HOME.
- Simple Bash only: no `&&`, `||`, `;`, `$(...)`, backticks, multi-line commands.
  Pipelines are OK. Anything longer goes in a scratch script.
- Governed JSON (registries/*.json) only through its skill (/incident, /glossary...).
- Firecrawl is deprecated: do not use Firecrawl tools.
- Never paste whole transcripts into context; filter.
- Only the commander's own words (genuine user prompts, not tool results,
  not agent messages relayed as user turns, not assistant text) count as a
  commander decision. Agent/delegate text is not a decision. A newer
  commander statement overrides an older one. Distinguish "commander decided"
  from "inferred from code".

## Skills
/scratch, /glossary and /incident (read-only lookups). If a skill does not
load, read its SKILL.md under /Users/new-jose/.claude/skills/<name>/ or
/Users/new-jose/repos/aitools/shared/skills/<name>/ and follow it by hand.

## Operational learning
- Section I of /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md and packet section 5.
- CORRECTION (Session Commander, 2026-10-26): the earlier "[x]abort ends only
  that setup script; the installer continues" is SUPERSEDED: the commander keeps
  PR #106's current abort behaviour (S3-AbortDocs updates the docs). The channel
  exception is now in /Users/new-jose/repos/aitools/CLAUDE.md (main 5976553).
- Commander decisions 2026-10-26 (not yet in files): dotprofile pushes from a
  non-main branch are an ERROR; handoffs and relay.md are committed directly to
  main (channel exception); Backup-File literal-path fix is on main 9923a3c; the
  derived deploy-paths.mdc twin and the HARNESS Manifest/Cursor/MDM doc drafts
  are approved.
- Agent-tool delegates have the Agent tool at levels 1-2, lose it at level 3.
  Subagents may lack Grep/Glob: use grep/find in pipelines or scratch scripts.
- Session transcript filter scripts already written by S3-AnsA (use them):
  - `python3 /Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/session-ansa/user-prompts.py <jsonl> [--grep REGEX] [--max-chars N] [--oldest-first]`
    (genuine user prompts only, newest first by default)
  - `python3 /Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/session-ansa/prev-assistant.py <jsonl> <prompt-uuid>`
    (assistant text the user prompt was answering)
  - `python3 /Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/session-ansa/find-text.py <jsonl> <regex> [--window N] [--tools] [--sidechain]`
  - Harness readers: /Users/new-jose/repos/aitools/scripts/read-session.py and read-session-full.py (no user-only filter).
  Note: in the current session, subagent hand-back reports arrive as `user`
  entries that begin with agent-message text; those are NOT commander words.

## The four questions (context)
Q1. `.claude/rules/deploy-paths.md` staleness note: approved text "(pre-push
step 7 does not yet trigger on them)" is false for `shared/` (check-pre-push.sh
step 7 matches `^shared/`). Proposed correction lists what step 7 does not
trigger on. Q1b: add `.claude/hooks` to the deploy-harness sources bullet?
Q1c: should step 7 be fixed instead (incident "Pre-push step 7's trigger misses
deploy-harness inputs")?
Q2. `reference/managed-file-deployment.md` closing paragraph says rules reach
tools "through the setup-user-claude / setup-user-cursor fan-out"; only cursor
fans out on main. Proposed: "Rules reach Cursor ... and Claude Code through
setup-user-claude once it fans out (today it deploys <userRepoPath>/claude/rules/ directly)".
Q3. `shared/cursor-rules/user-rules.md:28` says `C:\repos\`; HARNESS Q5 decided
`%USERPROFILE%\repos\`. Apply here too?
Q4. Derived `.cursor/rules/deploy-paths.mdc` twin (PR #99) acceptable? Commander
said "1d) approved" 2026-10-26T21:58:13Z.

Already found by S3-AnsA in the current session 10cf255a (do not redo; look
for anything that contradicts or adds):
- 2026-10-22T01:12:49Z: "we need to wait for deploy-harness to run, then setup-user-claude.sh/ps1 and setup-user-cursor.sh/ps1 should fan them out."
- 2026-10-22T03:52:53Z: "store all three in a single top level directory ~/.aitools/rules ..."
- 2026-10-23T01:58:29Z: "3) put aitools rules in the user space of claude code 4) approved" (4 = HARNESS Q2-Q6 incl. %USERPROFILE%\repos).
- 2026-10-23T02:01:33Z: "protected drafts approved. laurnch harness-2"
- 2026-10-26T21:58:13Z: "1a) please restate all 3 ... 1d) approved 1e) approved"
- 2026-10-26T22:10:25Z: "1a) this is a bit conflated for me. launch a mission ..."

## Name prefix (D-DEL1)
Every *.md you create starts with your stated prefix (`S3-AnsA-<Role>-`).
Never start a name with REPORT/SUMMARY/FINDINGS/ANALYSIS.

## WRITE_BLOCKED
If any write or tool call is denied, do not retry it in another form. Record
`WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your
response, and continue.

## Deliverable shape
5-line summary first; then per question: evidence found (verbatim quote,
session id, timestamp, prompt uuid; or commit sha / PR number + URL / file:line),
classification (commander decided / commander-implied / inferred from code /
agent text only), and anything contradicting the findings above. INCIDENT:
markers. "unknown" rather than guess.
