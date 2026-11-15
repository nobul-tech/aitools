# M6-Polish handoff (v1.0, 2026-11-15 UTC)

Handoff from orchestrator **M6-Polish** to the accepting agent (the same Claude Code session after context compression, or anyone continuing). Self-contained: read this first. If time has passed since it was written, re-check every "state" line with `gh pr list --repo nobul-tech/aitools --state all --limit 20` and `git -C C:/Users/jdpal/repos/aitools fetch origin` before acting: the assumptions held at write time and may since have been overtaken.

## A. Who is who

| Role | Identity | Transcript |
|---|---|---|
| Commander | Jose ("pepe"), the user | (gives orders in the main session and directly to delegates) |
| Parent: Session Commander 87795dc3-e | main session 87795dc3-e9b0-4f82-937b-139b3f13fa81 | C:\Users\jdpal\.claude\projects\C--Users-jdpal-repos-aitools\87795dc3-e9b0-4f82-937b-139b3f13fa81.jsonl (17+ MB, never load whole) |
| M6-Polish (this orchestrator, level 1) | agent a0c459c8f689338dc, description "M6-Polish: leftover findings mission"; prefix 38dc for missions it launches | ...\87795dc3-e9b0-4f82-937b-139b3f13fa81\subagents\agent-a0c459c8f689338dc.jsonl |
| Every delegate (all levels, flat) | `agent-<id>.jsonl` + `.meta.json` ("description" = the mission name) | ...\87795dc3-e9b0-4f82-937b-139b3f13fa81\subagents\ |

Readers: `python C:\Users\jdpal\.aitools\bin\read-session.py --help`, `read-session-full.py --help` (--search, --last, --output). To find a delegate's id: grep its description in `subagents\*.meta.json`. Documented in reference/tool-ops-claude-code.md "Delegate Identity, Transcripts and Control" (PR #158).

## B. Mission M6-Polish: done

Items a-g are all merged and green on main. The full report is `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M6-Polish/M6-Polish-report.md` (PR #169, open).

| PR | Content | Merge | Main CI |
|---|---|---|---|
| #153 | g harvest (262 files; 2 dotprofile commit-message copies excluded) | 10d1839 | green |
| #155 | a #29 EOF tests | 00beb8e | green on rerun; thin timing margin fixed by #161 |
| #157 | f #174 log writers; d #177; e hh.ps1 pwsh 7 | 875e957 | green |
| #161 | fix-forward: managed-files 64 KB fixture | d229440 | green |
| #160 | 38dc-11: compliance check in CI, shared/rules/delegation.md, bootstrap under pwsh 7 (#179) | 91dba98 | green |
| #158 | 38dc-08: delegate identity docs | e24c106 | green |
| #164 | fix-forward: compliance check `grep -q` SIGPIPE | a54c34e | green |
| #162 | 38dc-19: bash aitools forwards to aitools.ps1 on Windows; OS guards on hh.sh, bootstrap.sh, init-hh-hooks.sh, analyze-session.sh; issue #163 (Python aitools.py) | f345c41 | green |
| #154 | b, c: no check builds against the real HOME or reads the frozen deploy/ (#136, #176) | 5f962b1 | green |

Also on main: d21994b (CLAUDE.md, one bullet, an UNAUTHORISED direct push by 38dc-25; RFI 38dc-14).

## C. Open PRs and merge queue (Schwerpunkt: land them in order, with zero defects)

Merge one at a time. Before each merge: merge origin/main into the branch (--no-ff, keep both sides), get CI green on every job (linux, macos, windows, CodeQL), check mergeStateStatus CLEAN, and confirm the independent review has no open blocking finding. Then `gh pr merge <n> --repo nobul-tech/aitools --merge`, watch main's CI on the merge commit, and tell the next mission. RELEASE_NOTES conflicts: take main's file and insert the branch's own entry; `git diff --numstat origin/main -- RELEASE_NOTES.md` must show 0 deletions.

| # | PR | Mission (self-merges unless noted) | Version | State at write time |
|---|---|---|---|---|
| 1 | #167 relay-outbound-prompt OS guards; check-*.ps1 stop calling Git Bash | 38dc-23 | v0.77.13 | CI and review running; goes first |
| 2 | #159 Windows test-practice docs | 38dc-26 (refreshes 38dc-12's work after main moved) | v0.77.6 | waits for #167 |
| 3 | #165 tool-ops/tool-registry reconcile; duplicate item numbers; probes | 38dc-25 | v0.77.14 | review PASS; waits for #159; must correct its record of d21994b |
| 4 | #168 `grep -q` pipefail race everywhere; compliance step 7 taught | 38dc-24 | v0.77.15 | waits for #165 |
| 5 | #166 Windows CI runs .ps1 only (15 ports, guards, os-guards, check-ci-suites v2, locked-file and ACL cases) | 38dc-27 (continues 38dc-13, which ran out of context) | v0.77.16 | draft; builds on #167 after it lands; merges last of the code PRs |
| 6 | #169 M6-Polish report, M6-G reports, this handoff | M6-Polish (NOT self-merged: needs an independent reviewer delegate first) | none | open |
| 7 | (to come) incident #180 + RCA: why M6-Polish re-asked an answered question | 38dc-28 | v0.77.17 | running; files incident, does the RCA with /investigate, files a GH issue, opens a PR after #169 |

The commander has been told each mission's slot. Tell each mission when the PR ahead of it merges (SendMessage to its agent id; find the id via `.meta.json` description).

## D. Open RFIs (commander's decision needed; each has a suggested answer)

- **RFI 38dc-12:** remove the now-dead Windows branches in the bash `scripts/aitools`? Suggest: yes, after #166, together with the `tests/hookin` case that still exercises one.
- **RFI 38dc-13:** a retired skill whose delete keeps failing can lose its only complete backup. Backups are pruned to 5, oldest first, on success; e9d6-19-report.md section 1(e). Suggest: skip a new backup when one exists, and never prune the oldest complete backup of a pending retire; a follow-up after #166.
- **RFI 38dc-14:** keep or revert d21994b? Suggest: keep; 38dc-25 corrects #165's body to show it as an unauthorised deviation.
- Withdrawn: **RFI 38dc-11**. The commander had already answered it (rule "ps1 on windows"; "5) add an OS guard to all of them"). Decided work: add the Windows guard to `bootstrap.ps1` and `hh.ps1` and drop their exemption rows, in a small mission after #166 (it touches the same table and os-guards files). **Not yet launched.**

## E. Commander decisions of 2026-11-14 that govern the work (verbatim excerpts)

- "15) yes, tell yhour delegate to make no mistakes"
- Mission naming: "descriptive of its mission objective and the number should be sequentially assigned, it should include a prefix of 4 hex digits of your subagent id (the last 4)" (M6-Polish's missions are 38dc-<n>; the last used is 38dc-28)
- "there is not budget, you can launch as many as you want"
- Platform rule: "unless a script is explicitly marked as cross-platform for good reasons, such as build-deploy.sh and all perl/python scripts, sh scripts and tests should only run on linux/mac and ps1 on windows"
- "tests should be .ps1 here on windows and executed as powershell scripts, git bash scripts cause known issues"
- "7) build-package.sh is approved, relay-outbound.sh/.ps1 need os guards they are not exempt, ..., the aitools-json and validate should be recorded as exempt ..., id like to avoid calling git bash on thowse ps1 scripts"
- "8) dont file incident, just launch mission to fix this" (but for the RFI re-ask: "file this as incident")
- "9) lets not worry about file locks, it should try to delete them. if it cant, it should log that it cant. it should retry on any and all turns, but it should NOT file any incidents"
- Self-merge of follow-up missions: "it should merge itself, if it cant you should do it or delegate the merge"

## F. Exclusions

- Hard:
  - no direct pushes to main, including the CLAUDE.md "Channel exception" paths, unless the commander orders it;
  - no squash/rebase merges, force-pushes, tags or `gh pr review --approve`;
  - never run aitools, setup-user-*, deploy-harness, build-deploy.sh, check-post-push or check-pre-commit -Fix against the real HOME;
  - on Windows run only .ps1 suites (`bash -n` parse only);
  - no incidents unless the commander orders one.
- Soft: the main checkout C:\Users\jdpal\repos\aitools is read-only for missions. A stray empty directory from a delegate may remain there: `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/38dc-13/`, for the commander to remove.

## G. Operational learning (carry forward to every brief)

- Every merge to main costs each open PR another merge-main-and-CI cycle. Assign versions and skill version lines up front, keep a merge queue, hold merges while a PR finishes its final CI.
- Known CI flakes: macOS test-workflow-delegation-guard "adversarial 476 KB prompt >= 100 ms" (one rerun). Until #168 lands, other `| grep -q` pipefail sites can still flake.
- Delegates re-deliver their hand-back on every resume while a background watcher of theirs is alive: tell them to stop their watchers before handing back. Long-running orchestrator delegates can run out of context (38dc-13): keep them lean, and brief continuations from the branch state.
- A pwsh started from Git Bash inherits Git's PATH (a bare `find` is Unix find). TaskStop does not kill a background script's children.
- Verify every SHA with `git rev-parse` (never guess one).
- Delegate briefs must say: no direct pushes to main.

## H. What the accepting agent does first

1. Re-check the state (section C) with gh and git.
2. Answer, or relay to the commander, RFIs 38dc-12, 38dc-13 and 38dc-14.
3. Shepherd the queue: tell each mission when its predecessor merges.
4. When #166 is merged, launch the bootstrap.ps1 / hh.ps1 Windows-guard mission (section D).
5. Before merging #169, launch an independent reviewer for it, and update the report's "state at writing" lines.
6. When all are merged, the session commander appends the relay entry (`.aitools/channel/relay.md`, Channel exception) with section G.

## Provenance

v1.0, written by M6-Polish (agent a0c459c8f689338dc) on the commander's "/handoff" order before context compression. Not verified by a separate verifier, because the context budget was too low for the /handoff skill's subagent workflow. Treat section C as a snapshot.
