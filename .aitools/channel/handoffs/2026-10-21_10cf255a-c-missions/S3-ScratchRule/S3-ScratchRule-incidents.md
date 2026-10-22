# S3-ScratchRule incidents (for the session commander to triage and file)

Not filed. IDs `S3-SR-n` are local labels; the commander assigns registry
ids (registries/incidents.json ends at #86 on origin/main). Evidence detail:
`S3-ScratchRule-findings.md` (section in brackets). Discovery context for
all: mission SCRATCH-RULE, session 10cf255a-c, 2026-10-21; audited
`shared/skills/scratch/SKILL.md`, `shared/hooks/{scratch-init,harvest-session,session-catchup,standing-order-guard,intelligence-stop}.*`,
`shared/hooks/hooks-manifest.json`, `scripts/ait-harvest.py`,
`.claude/rules/{aitools-workspace,artifact-harvesting,hook-rollout,incident-governance}.md`,
`shared/claude-shared.md`, dotprofile `claude/CLAUDE.md`, the main checkout's
`.scratch/` and `harvesting/`; two probes with an isolated `HOME`.

INCIDENT: S3-SR-8 (high, operational / spec deviation) -- Catch-up harvest
truncates an orphaned dir's suffix to 10 characters, so `session-<name>` with
a name over 10 characters is never harvested and the miss harvests the dir
named in `.scratch/.current-session` (a live session's), marks it
`.harvested` and deletes the pointer. Evidence: ait-harvest.py:1126, :1131,
:760, :763-773; probe-long-name.sh output [8b]. Expected: harvest_scratch
harvests the dir it was asked for (docstring :752). Impact: wrong files
harvested under the wrong name; live session's hook telemetry loses its dir;
the orphan is retried every SessionStart. The mission packet tells
delegates to use `session-<YOUR-NAME>` (names up to 15+ chars). Suggested:
pass the dir path (not a prefix) from `_catchup_harvest` to
`harvest_scratch`; never fall back to `.current-session` when called for a
specific dir. Affected: scripts/ait-harvest.py, tests/.

INCIDENT: S3-SR-3 (high, operational) -- `.scratch/.current-session` is one
pointer per checkout shared by all concurrent sessions: every SessionStart
overwrites it (scratch-init.sh:70) and every harvest, including catch-up
harvests of other sessions' dirs, deletes it (ait-harvest.py:863-867).
Observed: pointer absent in the main checkout while session 10cf255a-c was
live; its dir holds `.harvested` = 2026-10-21T05:05:52Z although the session
kept writing there [4]. Expected: hook-rollout.md "Implementation" (blocks
recorded as hook_block events when the pointer exists) and scratch-init.sh
header ("fixes .current-session race condition"). Impact: standing-order-
guard, delegation-duty-guard, sh-file-fixup and others silently drop or
misroute events; agents told to read it get no dir or another session's.
Suggested: hooks derive the dir from the stdin session_id (as
intelligence-stop.py:375-376 does); harvest_scratch stops unlinking the
pointer, or the pointer is replaced by per-session files. Affected:
shared/hooks/*.sh that read the pointer, scripts/ait-harvest.py,
scripts/harness-db.py:501-502, shared/skills/handoff/SKILL.md:59-60.

INCIDENT: S3-SR-5 (medium, spec deviation) -- Harvest classifier keeps
staging and bookkeeping files as "code" artifacts: commit messages not named
`commit-msg*` (msg-*.txt, dotprofile-commit-v71.txt), PR and issue bodies,
`.harvested`, `.intelligence-last-check`, `events.jsonl`. Evidence:
ait-harvest.py:703-723, :844-853; /Users/new-jose/repos/aitools/harvesting/
listing; probe [8]. Expected: artifact-harvesting.md "What MUST NOT be
harvested" (commit message files, temp output captures). Impact: harvesting/
fills with noise the promotion review must wade through (20+ events.jsonl,
20+ .intelligence-last-check). Overlaps #73 (substring rule, subdirs) --
consider filing as an amendment to #73. Suggested: treat dotfiles,
`events.jsonl`, names starting `pr-body`/`issue-body` as ephemeral; record
skipped harness files in the log. Affected: scripts/ait-harvest.py, tests/.

INCIDENT: S3-SR-1 (medium, ambiguity / spec deviation) --
`.claude/rules/aitools-workspace.md:37` and `:64-68` state that scratch and
harvesting moved to `.aitools/scratch/` and `.aitools/harvesting/`; every
hook and the harvester use `<root>/.scratch/` and `<root>/harvesting/`
(scratch-init.sh:40, ait-harvest.py:759, :779); only aitools-dashboard.sh:180-184
/.ps1:128 read `.aitools/scratch/` [1]. Impact: agents following the rule
write where nothing harvests or finds them; the dashboard looks in an empty
namespace. Suggested: decide -- either amend the rule to say the move is
planned, not done (protected edit), or implement the move in one change
across hooks, harvester, dashboard, skills. Affected: aitools-workspace.md,
plus the code if implemented.

INCIDENT: S3-SR-2 (medium, documentation drift) -- Several files still say
the SessionEnd hook deletes scratch: /handoff SKILL.md:318-319 ("deleted by
the SessionEnd hook (harvest-session.sh lines 164-166)"), :367, :545, :598;
shared/claude-shared.md:124 and dotprofile claude/CLAUDE.md:167 ("The
SessionEnd hook handles cleanup"). Code: nothing is deleted
(ait-harvest.py:752-754, :796-798; harvest-session.sh is 65 lines) [2].
Impact: agents reason about scratch lifetime from a false premise (the
/scratch skill did until this PR); the templates propagate it to every
machine. Suggested: correct /handoff (not protected, intent unchanged) and
both templates (protected, wording in S3-ScratchRule-deploy-gap.md option B).

INCIDENT: S3-SR-4 (medium, gap) -- A git worktree's `.scratch/` is never
harvested (catch-up and SessionEnd sweep only the session's own root,
ait-harvest.py:759, :1108) and `git worktree remove` deletes it without
warning (probe [5]). No spec says what happens to delegate scratch in
worktrees. Impact: delegate scripts and notes in worktree scratch are lost
when the worktree is cleaned up. Suggested: either a catch-up sweep of
`git worktree list` roots, or a stated policy (now in the /scratch skill)
that worktree scratch is disposable and hand-backs go to tracked paths.

INCIDENT: S3-SR-6 (low, spec deviation) -- standing-order-guard.sh:164
scratch-check message: "Write it to a temp .sh or .ps1 file using the Write
tool, execute with Bash, then clean up." It names no session scratch dir and
"clean up" contradicts harvesting and the rm-glob ban. Owned by parallel
mission S3-HooksFix; suggested text: "Write it to a script in your session
scratch directory (/scratch skill) with the Write tool, then run it with
one Bash call."

INCIDENT: S3-SR-7 (low, spec deviation) -- `.claude/rules/incident-
governance.md` "Hook specifications" describes a SubagentStart hook that
serves "skill content + governance duty + scratch namespace";
shared/hooks/hooks-manifest.json registers no SubagentStart hook. Impact:
readers assume delegates receive a scratch namespace; they receive nothing
(the reason the delegate case exists in the /scratch skill). Suggested:
mark the SubagentStart spec as planned, or implement it with a per-delegate
scratch path.

Not an incident, noted: the /scratch skill's examples (`$(cat ...)`,
multi-line heredocs) were blocked by the guard's enforce-mode checks; fixed
in this PR [7].
