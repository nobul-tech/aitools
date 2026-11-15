# fa81-01-rca report (v1.0)

**Intent**: **Purpose**: Give the commander and the session commander the root causes of two events in session 87795dc3, found with the `/investigate` method: (RCA-1) delegates pushed commits straight to main; (RCA-2) the session commander's Read calls on agent `.output` files failed. Also give the incident and GitHub issue filed for each. **Scope**: both RCAs, with timelines, 5 Whys, Swiss cheese layers, barrier analysis and suggested fixes; the filed artifacts; conflicts; other findings. NOT the fixes themselves (issues #177 and #178 propose them). NOT any open PR, worktree or running mission. **Audience**: the commander (pepe), who answers the issues; the session commander, who relays this.

Mission fa81-01-rca, delegated by the Session Commander of session 87795dc3-e9b0-4f82-937b-139b3f13fa81 (level 1), 2026-11-14 local / 2026-11-15 UTC. Claude Code 2.1.325, Windows 11.

## Results

| | RCA-1: direct pushes to main | RCA-2: `.output` Read errors |
|---|---|---|
| Incident | #181 (open, medium) | #182 (open, medium) |
| Issue | https://github.com/nobul-tech/aitools/issues/177 | https://github.com/nobul-tech/aitools/issues/178 |
| Incident commit (main) | `235bc5130eb77b5015ccad0ba3bb77aa3dfc7aac` | same commit |

Incident ids: #180 is claimed by open PR #172 (its `registries/incidents.json` diff adds `"id": 180`; PR #166's body also notes #180 went to #172). No other open PR touches `incidents.json`. The max on main (`1b34fa2`) was 179, parsed in full. I took 181 and 182 and skipped 180.

Transcripts (L = JSONL line): main = `C:\Users\jdpal\.claude\projects\C--Users-jdpal-repos-aitools\87795dc3-e9b0-4f82-937b-139b3f13fa81.jsonl`; subagents under `...\87795dc3-e9b0-4f82-937b-139b3f13fa81\subagents\`: M6-Polish `agent-a0c459c8f689338dc.jsonl` ("M6"), 38dc-23 `agent-ad1a4e079cfa8ecfb.jsonl`, 38dc-25 `agent-ac189d584bdb1af14.jsonl`, M6b-Finish `agent-ac7f1cd3cfaa92f19.jsonl`. Thinking blocks in the delegate transcripts are empty (redacted), so a delegate's reasoning comes from its text, its scripts, its commit messages and its later messages.

## RCA-1: delegates pushed to main

**Answer to the question "violation or permitted?"**: permitted by everything the two delegates had received, and against an intent that never reached them.
- CLAUDE.md "Channel exception" names both paths (`CLAUDE.md`, handoffs).
- `/delegate` on main at the time (`f345c41` L225, L231-234) let delegates push them and gave the procedure. The procedure is a temporary index onto `origin/main` "from a checkout other missions share". It does not say whether a worktree qualifies as "from the main checkout"; I read it as covered by the skill's own method.
- The only prohibition was in the session commander's brief to M6-Polish (main L4418: "Not authorised: ... direct pushes to main").
- M6-Polish did not put it into the briefs of 38dc-23 (M6 L2487) or 38dc-25 (M6 L2644). 38dc-23's brief said "CLAUDE.md goes direct to main per its "Channel exception"".
- Under D-DEL6, 38dc-25 ranked the rule (tier 1) above its brief and recorded a CONFLICT line (38dc-25 L1736). It later called its own reading wrong when M6-Polish pressed it (L1731).
- 38dc-23 pushed its post-merge report after M6b-Finish told it, post-merge, to "Update your report before watching main CI" with no route (38dc-23 L1011, L1050).
- M6b-Finish's notice said "every M6 brief says "no direct pushes to main unless the commander orders it"". That is not true of either level-2 brief. The session commander repeated the premise in RFI fa81-30 (main L7198).
- The commander kept both commits ("27) keep", main L7273).

### Timeline (UTC)

| Time | Event | Source |
|---|---|---|
| 2026-10-26 | CLAUDE.md "Channel exception": "committed directly to main from the main checkout, with no worktree and no PR: handoffs ..., relay.md, plans ..., and this CLAUDE.md" | CLAUDE.md |
| 11-14 17:33:31Z | Brief to M6-Polish: "Not authorised: ... direct pushes to main" | main L4418 |
| 22:05:35Z | Brief to 38dc-23: "CLAUDE.md goes direct to main per its "Channel exception""; no prohibition | M6 L2487 |
| 23:16:04Z | Brief to 38dc-25: no prohibition; "find it resolve any and all conflicts it finds" | M6 L2644 |
| 23:40:18Z | 38dc-25 pushes `d21994b` (`git push origin <sha>:main`, from its worktree via a temporary index) | 38dc-25 L944, L1731 |
| 11-15 00:19:39Z | Brief to 38dc-27: "CLAUDE.md goes direct to main only by the session commander" | M6 L2912 |
| 00:43:22Z | M6-Polish to 38dc-25 only: "Do not make any further direct pushes to main." | M6 L2983 |
| 00:53:45Z | First brief with "No direct pushes to main (including CLAUDE.md "Channel exception" paths)" (38dc-28) | M6 L3069 |
| 00:59:44-47Z | M6-Polish handoff `cb91ab2` (F: "no direct pushes to main ... unless the commander orders it"; G: "Delegate briefs must say: no direct pushes to main."), then "Prompt is too long" | `git show cb91ab2`; M6 L3096 |
| 01:10:25Z | Brief to M6b-Finish: "never push to main directly" | main L6567 |
| 01:12:31Z | 38dc-23 merges PR #167 (`8bf15d9`) | 38dc-23 L997 |
| 01:13:43Z | M6b-Finish to 38dc-23: "Update your report before watching main CI" | 38dc-23 L1011 |
| 01:14:30Z | 38dc-23 pushes `237bca9` ("Channel exception: handoffs") | 38dc-23 L1050-L1053 |
| 01:14:51Z | M6b-Finish: "STOP -- no more direct pushes to main ... every M6 brief says ..." | 38dc-23 L1060 |
| 01:21:44Z | `1b34fa2`, the commander's `/delegate` edit (his order, main L7032): direct-to-main list widened to 8 path kinds; Limits "or when given explicit instructions" | `git show 1b34fa2` |
| 01:30:33Z | "27) keep ... 30) launch a mission ..." | main L7273 |

The full table, with verbatim quotes per row, is in issue #177.

### RCA: delegates pushed to main under the Channel exception, against an intent that never reached them

**Immediate cause**: each delegate read CLAUDE.md "Channel exception" and `/delegate` "Direct-to-main documents" as permission for its path and pushed through a temporary index.

**Contributing factors**:
1. The Channel exception does not scope who may use it, nor whether a worktree plus temporary index counts as "from the main checkout". (layer: prevention)
2. D-DEL6 is silent on a brief that narrows a rule's permission; 38dc-25 chose "tier 1 for the route". (layer: prevention)
3. Brief limits are not inherited. The level-1 prohibition was dropped at level 2, and the correction reached one of two delegates. (layer: prevention)
4. No route was set for post-merge report updates. (layer: prevention)
5. Nothing detects a push to main: no hook (`shared/hooks/` grep), and the ruleset "Reibung" blocks only deletion and non_fast_forward. (layer: detection)
6. Audit came late and was inaccurate (orchestrators reading `git log`; "every M6 brief says ..."). (layer: audit)

**Root cause**: the harness grants a direct-to-main permission without scoping who may use it, from where, or whether a brief can withdraw it, and `/delegate` does not make a delegating agent pass its own shipping limits down.

**Recommended corrective action**:
- Type: structural.
- Action:
  1. Scope the CLAUDE.md "Channel exception" (who, how, and that briefs may narrow it), and align its path list with the commander's `1b34fa2` list.
  2. Add a narrowing clause to D-DEL6.
  3. In `/delegate`: inherited verbatim limits, a required skeleton line `Direct pushes to main: <forbidden | allowed for <paths>>`, and a post-merge rule.
  4. Add a push-to-main detection check in observe mode.
  5. Optionally, a post-push audit.
- Verification: replay both events (issue #177, "Barrier analysis"). 3 prevents both. 1 and 2 make `d21994b` unambiguously permitted. 4 detects but does not prevent.

**Recurrence risk**: high.

**5 Whys**: issue #177.

## RCA-2: Read errors on agent `.output` files

**Correction to the premise** (and to the session commander's added evidence and its L7378 answer): the instruction "Read the output file to retrieve the result" did not come from the completion `<task-notification>`s. Those say the report arrives as a hand-back message, or "This agent has not reported yet" (main L6706). It came from Claude Code's **post-compaction `task_status` reminders**: main L6614, L6616 and L6617 at 01:11:46Z, right after the compaction boundary L6604; also L2401 and L2403 after the first compaction, L2391. Those reminders also say `status: completed` for delegates that had not handed back. The contradiction with the launch result ("Do NOT Read or tail this file ...", main L6301) stands.

### Timeline (UTC, 2026-11-15)

| Time | Event | Source |
|---|---|---|
| 00:49:54Z | M7-Sweep launch result: "Do NOT Read or tail this file via the shell tool — it is the full subagent JSONL transcript ..." (38dc-23 and 38dc-26 were launched by M6-Polish; their warnings never reached the main session) | main L6301; M6 L2487, L2881 |
| 00:59:47Z | M6-Polish ends ("Prompt is too long") | M6 L3096 |
| 01:04:01Z | An orphaned level-2 delegate's hand-back (38dc-24) arrives in the main session | main L6432 |
| 01:11:46-47Z | Compaction; `task_status` reminders: "Read the output file to retrieve the result: ...\tasks\<id>.output" for M7-Sweep, 38dc-23, 38dc-26 | main L6604, L6614-L6617 |
| 01:12:40-43Z | 3x `tail -c` blocked: "Use the Read tool with offset parameter instead of 'tail'" | main L6684-L6689 |
| 01:12:46-49Z | 3x Read: "File content (3.5MB / 5.2MB / 3.8MB) exceeds maximum allowed size (256KB)" | main L6708-L6713 |
| 01:12:54-58Z | `last-text.py` workaround; M7-Sweep "Waiting." | main L6722-L6734 |
| 01:15:00Z | `/delegate` (deployed v2.1, no `output_file` text) loaded, after the reads | main L6863 |
| now | `ls -li`: `.output` and `agent-<id>.jsonl` share an inode, link count 2 | this mission |

### RCA: no retrieval path for a delegate's result after compaction

**Immediate cause**: Read on 3.5-5.2 MB files exceeds Read's 256 KB limit.

**Contributing factors**:
1. Claude Code's post-compaction reminder points to the `.output` file, contradicting the launch warning (upstream). (layer: prevention)
2. The launch warning was compacted away, or was in another agent's context. (layer: prevention)
3. No reader mode prints a delegate's report (`read-session*.py --help`). (layer: prevention)
4. `/delegate` and tool-ops say only "not the `output_file`". That is wrong once the hard link exists, and the deployed `/delegate` lags main. (layer: prevention)
5. `/delegate` was not reloaded after compaction before acting. (layer: prevention)
6. The guard redirected `tail` to a positional Read. (layer: detection)

**Root cause**: the harness never defined how an orchestrator retrieves a delegate's result once the hand-back is out of its context. Claude Code's reminder fills the gap with the transcript file.

**Recommended corrective action**:
- Type: structural plus documentation; environmental (upstream).
- Action:
  1. Add a `--report` mode to `read-session-full.py` (or a new bin CLI).
  2. Make the guard's `tail`/`head`/`cat` message name the reader for `tasks/*.output` and `*.jsonl`.
  3. Fix the `/delegate` text.
  4. Record the reminder in tool-ops.
  5. Run `aitools` to deploy.
  6. Optionally, report the contradiction upstream.
- Verification: replay 01:12Z (issue #178, "Barrier analysis"). 1 and 2 prevent it. 3 and 4 help only if `/delegate` is loaded before acting.

**Recurrence risk**: high (every compaction re-injects the reminder).

**5 Whys**: issue #178.

## Verification

Every claim traces to a source:
- Brief lines: decoded from the Agent `tool_use` inputs with a scratch script (`dump_agent.py`): main L4418, L6567; M6 L2487, L2644, L2912, L3069, and all 26 M6-Polish briefs grepped.
- Delegate actions: their transcripts at the cited lines.
- Commits: `git show --stat --format=fuller` on `d21994b`, `237bca9`, `1b34fa2`; `git log` on origin/main.
- Rule text: CLAUDE.md; `git grep` at `f345c41` and `8bf15d9`.
- Detection: grep of `shared/hooks/` (no match); `gh api repos/nobul-tech/aitools/rulesets/16468370`; `branches/main/protection` returns "Branch not protected".
- RCA-2: rendered attachment text (`rendered.py`), not only raw records; `ls -li` inode and link counts; `read-session*.py --help`; standing-order-guard L237.
- Incidents: `direct-commit.py` reparsed the file after the insert (ids unique, count +2, entries round-trip); `git diff --numstat` shows 54 added, 0 deleted.
- Issues: `gh issue create`, then `gh issue edit` to add the commit SHA.

Not run: check scripts (no code changed; one registry file and this report, direct to main); tests; CI on `235bc51` not watched.

## CONFLICT lines

- CONFLICT: `/incident` "Presents for review (protected file gate applies) / Writes if approved" vs the prompt "write the entries as versions and commit them" -- resolved by tier 2 (the prompt, carrying D-DEL5): committed without waiting.
- CONFLICT: `/investigate` step 7 (effectiveness tracker, coaching items) vs the prompt "dissemination is the incident plus the issue only" -- resolved by tier 2: tracker and coaching not touched.
- CONFLICT: CLAUDE.md "Channel exception" (`registries/` not listed; "from the main checkout") vs a direct commit of `registries/incidents.json` -- resolved by tier 1, the commander's newer words ("there is no need for a worktree here", main L7273; his `/delegate` edit `1b34fa2` lists `registries/`): committed onto origin/main through a temporary index, main checkout untouched.
- No conflict with the session commander's reading of "the gh issue should be on the main branch": issues on nobul-tech/aitools, fixes land on main.

## WRITE_BLOCKED

None.

## Other findings (INCIDENT: markers, not filed)

- INCIDENT: open PR #172 (incident #180) and commit `235bc51` both append to the end of the `incidents` array, so #172 will conflict on its next merge of main. Resolution: keep all three entries (180, 181, 182). Whoever merges #172 (M6b-Finish's queue) needs to know.
- INCIDENT (already raised as RFI 38dc-25-5, not re-filed): `/delegate` on main (the commander's edit) has a ten-element table and `PERMISSION_DENIED`, while `shared/rules/delegation.md`, the skill's own intent and the delegation hooks say eight elements and `WRITE_BLOCKED`.
- INCIDENT (inside #181's "expected"): three different direct-to-main path lists (CLAUDE.md; `/delegate` "In the aitools repo"; `/delegate` "Direct-to-main documents" after `1b34fa2`).
- Operational learning: `git show <rev>:<path> --output=<file>` writes an empty file on this machine and prints to stdout (already in the M6 briefs). Read blobs through Python `subprocess` instead.

## Open questions (each with a suggested answer)

1. Which direct-to-main list is current: CLAUDE.md's 4 path kinds, or your `/delegate` edit's 8? **Suggest:** your edit (newer); align CLAUDE.md in the #177 fix.
2. Post-merge report updates: hand-back only, or direct to main? **Suggest:** direct to main under the exception unless the brief forbids it. Hand-back-only facts were lost when M6-Polish ran out of context.
3. The push-to-main check: start in observe mode? **Suggest:** yes, per `.claude/rules/hook-rollout.md`. It is a new check that widens what is flagged.
4. Report the launch-warning vs post-compaction-reminder contradiction to Claude Code upstream? **Suggest:** yes. It is cheap, and the reminder will misdirect every long session until fixed.

## Provenance

v1.0, written by fa81-01-rca. Scratch scripts (not tracked): `C:\Users\jdpal\repos\aitools\.scratch\session-fa81-01\` (`q.py`, `dump_agent.py`, `rendered.py`, `maxid.py`, `incsearch.py`, `direct-commit.py`, issue bodies, `new-incidents.json`). No delegates used.
