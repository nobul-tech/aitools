# S3-ScratchRule report (mission SCRATCH-RULE)

1. The /scratch skill is rewritten to match the code: nothing is deleted, the dir is `.scratch/session-<10-char id>/`, it is found from the SessionStart context line, and the delegate and worktree cases plus a PR-body pattern are documented.
2. The rule `shared/rules/scratch.md` is drafted (74 lines, with an intent block). It is a draft awaiting approval in the mission folder, not live.
3. Two probes against the real harvester found a high-severity bug (S3-SR-8): a session-dir suffix longer than 10 characters makes catch-up harvest the live session's dir. The packet's own `session-<YOUR-NAME>` advice triggers it in the main checkout.
4. Deployment: recommend A + B now. A puts the rule in dotprofile `claude/rules/`, the same route as `delegation.md`. B fixes the stale USO sentence in both templates. All options touch protected content.
5. Eight `INCIDENT:` markers, not filed. Pre-push has one new false-positive FAIL (step 2 `scratch\.` matches the rule's file name).

## PR, branch, files

- PR: https://github.com/nobul-tech/aitools/pull/61
- Branch: `feature/scratch-rule` from origin/main db4b3c5. Worktree: `/Users/new-jose/repos/aitools/.claude/worktrees/scratch-rule`
- Files changed:
  - `shared/skills/scratch/SKILL.md`. The intent block is unchanged; the description frontmatter is updated.
  - `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-ScratchRule/`:
    - `S3-ScratchRule-findings.md`
    - `S3-ScratchRule-drafts/shared/rules/scratch.md`
    - `S3-ScratchRule-deploy-gap.md`
    - `S3-ScratchRule-incidents.md`
    - `S3-ScratchRule-report.md`

## Resolution of the six known inconsistencies

1. **Location.** The code uses `<git root>/.scratch/session-<session_id[:10]>/` (scratch-init.sh:34-40, :60-70; ait-harvest.py:759, :92-94). `.aitools/scratch/` (aitools-workspace.md:37, :64-68) is not implemented; only aitools-dashboard.sh:180-184 reads it. The harvester also writes `<root>/harvesting/`, not `.aitools/harvesting/` (ait-harvest.py:779). The skill now documents what runs. The rule text is protected, so this goes to the incident list (S3-SR-1).
2. **Lifecycle.** Nothing is deleted. `harvest-session.sh` is a 65-line shim. `harvest_scratch` copies non-ephemeral top-level files and skips ephemeral ones without unlinking them (ait-harvest.py:752-754, :796-798, :812-833). It writes `.harvested` (:873-875) and deletes only `.current-session` (:863-867). artifact-harvesting.md:65-67 is correct. The stale claim survives in /handoff SKILL.md:318-319, :367, :545, :598 and in both templates' "The SessionEnd hook handles cleanup" (S3-SR-2).
3. **Attribution.** The example now uses a placeholder plus the instruction to copy the attribution line from the current instructions.
4. **Delegates.** The skill now says to use the path in the delegation prompt, or `mkdir -p <repo-or-worktree root>/.scratch/session-<name>`, with the name at most 10 characters (S3-SR-8). Main agents read the `Session scratch directory:` line (scratch-init.sh:119). `.current-session` is only a checked hint: it is shared per checkout, and was observed missing while session 10cf255a-c was live (S3-SR-3).
5. **Worktrees.** Each worktree has its own `.scratch/` (git toplevel). It is never swept by harvest (ait-harvest.py:759, :1108), and `git worktree remove` deletes it with exit 0 (probe 1). Hand-backs therefore go to tracked paths (S3-SR-4).
6. **shared/rules.** It is absent on origin/main. It exists only as an empty untracked dir in the main checkout. User rules deploy only from the dotprofile `claude/rules/` (setup-user-claude.sh:265-266; build-deploy.sh:164-165). See the deployment options.

Also found:
- The skill's own examples were blocked by the guard: `$(...)` via MODE_SUBSHELL, and heredocs of 4+ lines via MODE_SCRATCH (standing-order-guard.sh:50-51, :161-165).
- The classifier harvests commit messages not named `commit-msg*`, PR and issue bodies, `.harvested`, `.intelligence-last-check` and `events.jsonl` (S3-SR-5). The evidence is in the `/Users/new-jose/repos/aitools/harvesting/` listing.

## Verification

- **Probe 1:** `.scratch/session-S3-ScratchRule/probe-worktree-remove.sh` (gitignored). It runs the real `ait-harvest.py harvest` in a throwaway repo with `HOME` isolated. Output is quoted in findings section "Probe".
- **Probe 2:** `.scratch/session-S3-ScratchRule/probe-long-name.sh`. It runs `ait-harvest.py catchup`. Output is quoted in findings section 8b.
- **`bash scripts/check-pre-commit.sh`:** 7 PASS, 10 SKIP, 2 WARN, 1 FAIL.
  - FAIL step 6: pre-existing, the `harvesting/` file mode.
  - WARN step 3: build freshness.
  - WARN step 11: the dotprofile has its own uncommitted changes.
- **`bash scripts/check-pre-push.sh`:** 5 PASS, 1 SKIP, 2 WARN, 2 FAIL.
  - FAIL step 7: pre-existing, the dotprofile `deploy/` is stale. It now also lists setup-user-skills, as expected.
  - FAIL step 2: new false positive. `blocklist_pattern` contains `scratch\.` (check-pre-push.sh:56), which matches `scratch.md`.
- `bash -n` and the pwsh parser were not needed: no scripts changed.

## Not run

- `build-deploy.sh` against the real HOME, `aitools`, `setup-user-*`: forbidden by the packet. Pre-push step 7 runs the build isolated.
- No tests in `tests/`: no code changed.

## Reading coverage

I read the packet in full, `delegation.md`, all project rules (in context), and the mission files. Of reference/, I read only `framework-artifact-harvesting.md` and `user-repo.md`. The other commander-level reference files in packet section 1 were not read. They were judged not to bear on this documentation-only mission.

## WRITE_BLOCKED

None.

## INCIDENT markers (full text in S3-ScratchRule-incidents.md)

- INCIDENT: S3-SR-8 (high): catch-up truncates a dir suffix longer than 10 characters, then harvests the dir named in `.current-session` (a live session's), marks it `.harvested`, and deletes the pointer.
- INCIDENT: S3-SR-3 (high): `.scratch/.current-session` is one pointer per checkout, overwritten by every SessionStart and deleted by every harvest. Hook telemetry is dropped or misrouted.
- INCIDENT: S3-SR-5 (medium): the classifier harvests staging and bookkeeping files (msg-*.txt, PR bodies, `.harvested`, `.intelligence-last-check`, `events.jsonl`). Overlaps #73.
- INCIDENT: S3-SR-1 (medium): aitools-workspace.md states the `.aitools/scratch/` and `.aitools/harvesting/` move; the code never made it.
- INCIDENT: S3-SR-2 (medium): /handoff skill and both CLAUDE.md templates still say scratch is deleted or cleaned up.
- INCIDENT: S3-SR-4 (medium): worktree `.scratch/` is never harvested and is deleted silently by `git worktree remove`.
- INCIDENT: S3-SR-6 (low): the standing-order-guard scratch message names no session dir and says "clean up". Owned by S3-HooksFix.
- INCIDENT: S3-SR-7 (low): incident-governance.md specifies a SubagentStart hook serving a scratch namespace; none is registered.
- Also low, new: pre-push step 2 `scratch\.` false-positives on any file named `scratch.*` (check-pre-push.sh:56).

## Open questions for the commander

1. **Approve the rule text** (`S3-ScratchRule-drafts/shared/rules/scratch.md`)? Suggested: approve. It is 74 lines and limited to principle, triggers, delegation duty and enforcement. The detail stays in the skill.
2. **Rule file name.** The mission named it `scratch.md`, which fails pre-push step 2 on every push that touches it. Suggested: rename it `scratch-files.md`, which does not match. The alternative is to narrow the blocklist to `^scratch\.` at a path root, a change to a check script.
3. **Deployment.** Suggested: A + B now (dotprofile `claude/rules/` copy, plus the template USO wording fix), and C later. Details are in S3-ScratchRule-deploy-gap.md.
4. **Skill intent update.** The draft is in PR #61 under "Protected-file drafts". Suggested: approve. "cleanup" describes behaviour that no longer exists.
5. **Packet advice `session-<YOUR-NAME>`.** It hits S3-SR-8 when used in the main checkout with a name longer than 10 characters. Suggested: amend future packets to "a name of 10 characters or fewer" until S3-SR-8 is fixed.

## Delegates used

None. The mission was small and sequential, and the evidence needed first-hand probes.
