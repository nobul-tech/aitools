# Investigation: Missing Briefing JSONs

**Date**: 2026-03-21
**Investigator**: S3 (this session), delegated to S2 subagent (a5fc1bdc94575788c)
**Delegation duty**: Output inspected, 3 claims spot-checked, artifact written here.

## Findings

### Nothing was deleted — but carry-forward is broken

**Observation**: The planning-brief.json at `plans/mission-command-briefing/planning-brief.json` is intact (tracked in git, committed March 16). The running-estimate.json at `.aitools/channel/session-uyZ7TELqpP/20260316T190000Z_s3_running-estimate.json` exists locally but is gitignored.

**Expected**: The workspace rule (`.claude/rules/aitools-workspace.md`) specifies `channel/running-estimate.json` as "tracked" and `channel/session-*/` as "gitignored." The `.gitignore` line 47 has a blanket `.aitools/` entry that ignores everything under `.aitools/`, contradicting the workspace rule.

**Impact**: Running estimates cannot carry forward between machines (cross-machine carry-forward principle violated). If the user switches to Windows, the March 16 running-estimate is invisible.

### .gitignore vs workspace rule contradiction

- **Commit c6ab931** (March 16, 18:39): Added `.aitools/` to `.gitignore`
- **Commit 69cfd78** (March 16, 19:17): Created workspace rule specifying `running-estimate.json` as tracked
- These contradict. The gitignore wins at the filesystem level.

### No new running estimates since March 16

The infrastructure was designed (decision #50 in planning brief) but never built:
- No `channel-init.sh` script
- No `/delegate` skill
- No `/channel` skill
- SessionStart hook does not create/update running estimates

### Missing session archives (March 18-20)

Last archived aitools session: `2026-03-17_e059186f.jsonl`. Sessions that produced commits v0.62.3-v0.62.6 (March 18-19) were NOT archived. Cannot audit those conversations.

### Prior data loss documented

The running-estimate itself records (deviations section): "2 S2 AAR files lost — harvest-session.sh silently deleted .json". This was the `.json` bug in harvest-session.sh — fixed in source but the fix requires `aitools install` to deploy.

## Spot-check results

| Subagent claim | Verified? | Method |
|---|---|---|
| .gitignore line 47 = `.aitools/` | YES | `grep` confirmed |
| planning-brief.json exists in plans/ | YES | `glob` found 17 files in mission-command-briefing/ |
| "Nothing was lost" | PARTIALLY — planning-brief safe, running-estimate at risk, 2 AARs previously lost | Read running-estimate deviations section |

## Classification

This is an **incident (spec deviation)**: the workspace rule specifies tracked files, but the .gitignore contradicts it. The cross-machine carry-forward principle (design principle in CLAUDE.md and workspace rule) is violated for running estimates.
