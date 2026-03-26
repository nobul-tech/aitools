# Delegation Prompt: Session Viewer Feedback UI

## Identity

You are S3-FeedbackUI. You have broad authority to build and ship.

## Mission

Add a feedback mechanism to the session viewer (`session-viewer.py` at `.scratch/session-c0dc2ddc-f/session-viewer.py`) so the commander can provide feedback on rendered files directly in the browser. This feedback persists and can be read by agents in future sessions.

### UX Specification

1. **Per-file contextual feedback**: When viewing a rendered markdown file, right-click anywhere on the rendered body → "Feedback" option → message box pops up with accept/cancel. The feedback is associated with the file being viewed (and ideally the section/line context where the right-click happened).

2. **Feedback queue panel**: Right-hand panel that shows accumulated feedback messages for the current file. Auto-hides when no feedback exists. Switching between files by clicking preserves state — each file has its own feedback queue.

3. **General guidance toolbar**: At the bottom of the page, a toolbar showing summary (number of accumulated messages). A "Send Message" button that opens a popup for general guidance — unlike the per-file feedback, this has no file/line/section provenance. It's the commander speaking broadly.

4. **Persistence**: Feedback writes to the session SQLite DB (`.aitools/sessions/c0dc2ddc-f.db`). Use the `commander_feedback` table if it exists, or create a new `viewer_feedback` table. Each entry: file_path, section_context (nullable), message, feedback_type (contextual vs general), timestamp.

5. **Styling**: Match the existing dark theme. Unobtrusive — the feedback mechanism should not interfere with reading.

### Backward Compatibility

The feedback written here needs to be readable by agents. When the commander rewinds to an earlier point in the session and tells the agent "read my feedback", the agent reads from the DB. The feedback is the communication channel from commander-in-the-future to agent-in-the-past.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — read Part 1 and Part 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/session-viewer.py` — the viewer to modify
6. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/session-command-center-v2.py` — has the feedback table pattern (commander_feedback) as reference

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Operational Learning to Carry Forward

- The name `/provenance` is wrong — should be `/aitool-provenance` (user-level skills with aitools scope use `/aitool-*` prefix)
- Audience for provenance framework should include USERS not just agents — aitools is for everyone
- The session viewer is on port 8440 currently
- Port conflicts are recurring — check port availability before binding
- The commander wants to communicate through the dashboard, not through the conversation — context here is expensive
- Feedback from the future (via /rewind) to agents in the past is a key use case

## Output

Modify `session-viewer.py` in place. Test it. Restart the server on port 8440. Write operational learning to scratch.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
