# Write Failure RCA: Subagent Could Not Write to Scratch Directory

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Failed file**: `/Users/pepe/repos/aitools/.scratch/session-Z1IhGrcgGO/scope-creep-analysis.md`
**Successful comparator**: `/Users/pepe/repos/aitools/.scratch/session-Z1IhGrcgGO/session-state-audit.md`

---

## 1. Root Cause Determination

**Primary cause: Hypothesis A -- Permission prompt that could not be approved.**

The subagent was likely running as a **background** subagent. Background subagents in Claude Code auto-deny any permission prompt that was not pre-approved before launch. The Write tool requires per-session approval (it is not a read-only tool), and if the parent agent did not pre-approve Write permissions for the scratch path before launching the background subagent, the Write call would have been silently auto-denied.

**Contributing factor: Hypothesis E is a plausible secondary cause** -- if the subagent exhausted its context window completing the ~400-line analysis, it may have hit compaction or turn limits before successfully executing the Write call, but this would typically manifest as truncation rather than a "needs Write permission" message.

## 2. Evidence

### 2.1 Claude Code permission model for subagents

From the official documentation at `code.claude.com/docs/en/sub-agents.md`:

> **Background subagents** run concurrently while you continue working. Before launching, Claude Code prompts for any tool permissions the subagent will need, ensuring it has the necessary approvals upfront. Once running, the subagent **inherits these permissions and auto-denies anything not pre-approved**.

And:

> **Foreground subagents** block the main conversation until complete. Permission prompts and clarifying questions are passed through to you.

This is the critical distinction. A foreground subagent can surface permission prompts to the user for approval. A background subagent cannot -- it auto-denies.

### 2.2 Write tool requires approval

From the permissions documentation at `code.claude.com/docs/en/permissions.md`:

| Tool type         | Approval required | "Yes, don't ask again" behavior |
|-------------------|-------------------|---------------------------------|
| File modification | Yes               | Until session end               |

The Write tool is a "File modification" tool. It requires approval every session. If the subagent ran in the background without Write being pre-approved for the scratch path, the permission prompt would have been auto-denied.

### 2.3 The successful subagent comparison

The session-state-audit subagent successfully wrote to the same directory. This proves:
- The path is valid and writable at the OS level
- The `.scratch/` directory exists
- No hook blocks writes to `.scratch/`

The difference between the two subagents must be in their execution mode (foreground vs background) or in whether Write permissions were pre-approved for each.

### 2.4 Hooks ruled out

All hooks were reviewed:
- **standing-order-guard.sh**: Only fires on `PreToolUse` for `Bash` tool. Does not affect Write.
- **sh-file-fixup.sh**: Fires on `PostToolUse` for `Write|Edit`, but only acts on `.sh` files (exits immediately for `.md`). Cannot block.
- **glossary-skill-guard.sh**: Only fires on `Read|Grep`. Does not affect Write.
- **block-claude-code-guide.sh**: Only fires on `Agent` tool. Does not affect Write.

No hook blocks Write to scratch directories.

### 2.5 Settings ruled out

The `.claude/settings.local.json` permissions were reviewed. There are no `deny` rules for Write or Edit. There are no path restrictions that would block `.scratch/` writes.

### 2.6 The subagent's own report

The subagent reported needing "Write permission" and offered to present inline. This is consistent with a permission prompt being auto-denied (background mode) rather than a hook block (which would show the hook's stderr message) or a tool unavailability (which would say the tool is not available).

## 3. Prevention: Prompt Additions for the Delegating Agent

The delegating agent (main agent or coordinator) must ensure Write permissions are available to the subagent. There are three approaches, in order of preference:

### Option A: Run the subagent in foreground (simplest)

If the subagent needs to write files, run it in the foreground so permission prompts pass through to the user. This is the safest approach. The main agent should NOT request background execution for subagents that need to write output files.

### Option B: Pre-approve Write permissions before launching

If background execution is required (e.g., for parallelism), ensure Write permissions for the target path are already approved in the session before launching. The main agent can:
1. Write a small placeholder file to the target path first (this triggers the permission prompt for the user)
2. Then launch the background subagent

### Option C: Use permissionMode in the subagent definition

For trusted subagents writing only to scratch directories, the delegation prompt can specify `permissionMode: "acceptEdits"` which auto-accepts file edit permissions. However, this applies broadly and should be used cautiously.

## 4. Corrected Delegation Prompt Template

```
You are a research subagent. Your task is: [TASK DESCRIPTION]

IMPORTANT -- File output:
- Write your full analysis to: [TARGET_PATH]
- You MUST write the file using the Write tool before completing.
- If the Write tool is unavailable or blocked, report this as your
  FIRST line of output so the parent agent can retry.
- Do NOT offer to "present inline instead" -- the parent agent
  needs the file on disk for harvesting and carry-forward.

Output format: [FORMAT SPEC]

Constraints:
- [TASK-SPECIFIC CONSTRAINTS]
```

**And the parent agent must add these delegation behaviors:**

1. **Always launch file-writing subagents in the foreground** unless there is a specific reason for background execution AND Write permissions have been pre-approved for the target path.

2. **Verify the output file exists** after the subagent completes. If it does not exist, retry once in the foreground.

3. **If launching in background for parallelism**, first write a placeholder to the target directory (e.g., `touch` equivalent via Write tool) to trigger the permission prompt, then launch the background subagent.

---

## 5. Barrier Analysis

### What barrier was missing?

The **delegation duty** lacked a verification step. The parent agent:
1. Launched the subagent with a write target
2. Did not verify the write succeeded
3. Did not have a retry mechanism

### What barrier would prevent recurrence?

| Layer | Barrier | Implementation |
|-------|---------|----------------|
| Prevention | Delegation prompt template that explicitly instructs the subagent to fail loudly if Write is blocked | Prompt template above |
| Prevention | Parent agent always launches file-writing subagents in foreground | Delegation duty rule |
| Detection | Parent agent verifies output file exists after subagent completion | Post-delegation check |
| Detection | Subagent reports "WRITE_BLOCKED" as first output line on failure | Prompt template above |

### Delegation duty components that were missing

1. **Permission pre-flight**: Before delegating a task that requires Write, ensure the subagent will have Write access (foreground mode or pre-approved permissions).
2. **Output verification**: After the subagent returns, check that the expected output artifact exists on disk.
3. **Retry protocol**: If the output is missing, retry once in foreground mode before giving up.
