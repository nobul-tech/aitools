# Feedback Analysis and Work Product

**Session**: 2d439e32-3
**Date**: 2026-03-25
**Author**: S3-Commander (2-deep delegation session)

---

## Item 1: Provenance Skill Naming

**Feedback**: Skill name should be /aitool-provenance. Audience is all aitools users. Need to trace provenance of the naming error and catch everything else that originated from it.

### Analysis

The proposed-framework-provenance.md (line 8) names the skill as `/aitool-provenance` (user-level) and `/provenance` (project-level). This is CORRECT per the established naming convention:
- User-level skills: `/aitool-*` prefix (deployed to ~/.claude/skills/)
- Project-level skills: no prefix (deployed to .claude/skills/)

Evidence from existing skills:
- `/aitool-ops` (user) / `/tool-ops` (project)
- `/aitool-eval` (user) / `/tool-eval` (project)

The naming IS correct in the framework doc. The commander's feedback may have been reacting to an earlier version or a different file that used a wrong name. The proposed-framework-provenance.md already uses the right naming on line 8: "future `/aitool-provenance` user-level skill" and on line 214-215.

**Provenance trace**: The framework doc was written by a subagent in session c0dc2ddc-f. The naming convention was correctly applied. No blast radius found -- no other files reference a wrong provenance skill name.

### Action

No naming fix needed. The convention is already correct in the proposed framework doc. When implementing:
- `shared/skills/aitool-provenance/SKILL.md` -- user-level reference card
- `.claude/skills/provenance/SKILL.md` -- project-level CRUD

---

## Item 2: CLAUDE.md Self-Awareness from nobul-ops

**Feedback**: There is work from nobul-ops that incorporates self-awareness into CLAUDE.md. Find it and use it to make aitools what it claims to be.

### Analysis

The reconciled-claude-md.md from session RnTOD5XJFi (at .scratch/session-RnTOD5XJFi/reconciled-claude-md.md) IS the self-aware version. It was produced by reconciling the original CLAUDE.md with a version that adds:

1. **Agent Operating Principles** section -- directives that override default agent behavior:
   - "Treat static files as assumptions" -- context overrides files
   - "Recency weight" -- most recent instruction carries most weight
   - "Verify, don't infer" -- read the actual file, don't assume
   - "The harness IS code + governance + state + OL"
   - "Carry forward operational learning"
   - "Delegation duty is critical" -- subagents are blank slates

2. **"may be stale"** markers on sections that change frequently (harness table, project structure)

3. **Shipped capabilities** section -- what agents should actively USE, not just know about

The nobul-ops CLAUDE.md (nobul-ops/CLAUDE.md) has the SAME pattern. Both repos now use the "self-aware" CLAUDE.md format with Agent Operating Principles. The aitools repo's CLAUDE.md was updated to this format in the reconciled version.

**Current state**: The committed CLAUDE.md in aitools (the one loaded in context above) is still the OLD format -- it does NOT have Agent Operating Principles. The reconciled version sits in scratch. This is the gap.

### Action

The reconciled-claude-md.md from session RnTOD5XJFi should be merged with the provenance additions from proposed-claude-md-changes.md to produce the definitive CLAUDE.md. This is a protected file requiring commander review.

Draft produced at: session-2d439e32-3/proposed-claude-md-final.md

---

## Item 3: aitools vs Harness Terminology Confusion

**Feedback**: We keep using aitools and harness as the same thing. Confusing and redundant.

### Analysis

The confusion is real and documented in three places:
1. CLAUDE.md mission: "The harness -- aitools and the tools, context, state..."
2. reference/harness.md: defines harness as 5 (soon 6) components
3. Multiple rules reference "harness" and "aitools" interchangeably

The governed vocabulary (via /glossary skill) should define these terms precisely. The distinction:

- **aitools** = the CLI tool and its repo. It is one component (Orchestration).
- **harness** = aitools + everything it manages. The full system: Platform + Configuration + Orchestration + Managed Tools + Frameworks + Provenance.

The confusion occurs because:
1. The aitools REPO contains the harness definition, governance, and implementation
2. The aitools CLI orchestrates the harness
3. When working IN the aitools repo, they feel like the same thing
4. Outside the aitools repo, you experience the harness but interact with aitools

This does NOT need a massive reconciliation mission. It needs:
1. Clear glossary entries (via /glossary skill) -- aitools is the CLI/repo, harness is the system
2. Consistent usage in CLAUDE.md: "The harness is what aitools builds and manages"
3. The proposed-harness.md already has the right framing in line 1-6

### Action

Draft two glossary entries for /glossary skill submission:
- **aitools**: The CLI tool and its source repository. One of six harness components (Orchestration). Does not include the things it manages.
- **harness**: aitools and everything it manages -- tools, context, state, artifacts, frameworks, and provenance. The full system deployed across projects, platforms, and users.

---

## Item 4: Web Portal Proposal is Stale

**Feedback**: The whole thing is stale. Needs to be rewritten from aitools today.

### Analysis

The proposal-web-portal.md was written by S2-Portal subagent during session c0dc2ddc-f. It reflects the state of understanding at that point -- before several key decisions:

**Stale assumptions in the proposal**:
1. Recommends Cloudflare Pages/Workers/D1 architecture -- but D-VERCEL-STOPGAP decided Vercel for now
2. Proposes auth with Auth0 -- premature for a single-user dashboard
3. Proposes sync model with POST endpoints -- but D-RELAY-PATTERN decided relay/tunnel pattern (no DB sync)
4. Proposes Preact/vanilla SPA framework -- but the actual implementation uses pure Python HTML generation
5. Proposes "mc.nobul.tech" domain -- but D-DOMAIN decided nobulai.tools (already registered and deployed)
6. Proposes 10-14 day timeline -- but Phase 0 was completed in the same session

**What the proposal got right**:
- The core insight: session data needs to be visible from any device
- The dashboard views (active sessions, history, incidents, OL index) are still the right vision
- Offline-first / staleness indicators

### Action

Rewrite produced at: session-2d439e32-3/proposal-web-portal-v2.md

---

## Item 5: Deploy Mission Control to nobulai.tools

**Feedback**: Get all the mission control stuff on nobulai.tools before end of session.

### Status: DONE

Mission control deployed to nobulai.tools with current session data:
- 200 messages
- 30 decisions
- 205 observations
- 6 commander feedback items (from the session viewer)
- All tabs working: Messages, Governance, Delegations, Missions, State, Commander Feedback

Deployment: Vercel static snapshot at https://nobulai.tools
Export script: .scratch/session-2d439e32-3/export-mission-control.py

---

## Item 6: Session Viewer UX Bugs

**Feedback**: 4 bugs identified:
1. Forward slash (/) on Chrome macOS moves cursor to filter toolbar
2. "Send" button misleads -- feedback is queued, not sent immediately
3. Line numbers would help -- contextual feedback should capture line numbers
4. Checkout flow -- user couldn't submit all feedback; no way to "check out" without file context

### Bug Analysis

**Bug 1: Forward slash captures focus**
Location: session-viewer.py line 1043-1049. The `/` key handler does `e.preventDefault()` and focuses the search box. This is a common vim-style shortcut but conflicts with Chrome's built-in "Quick Find" behavior and is unintuitive for non-developer users. More critically, it prevents typing `/` in the feedback textarea because the condition checks for INPUT/TEXTAREA but the modal text area is checked via `fbModal.classList.contains('visible')` -- if the modal isn't active, `/` typed in any context gets swallowed.

**Fix**: The handler should also check if the feedback modal overlay is visible. But more fundamentally, `/` should only trigger focus when Ctrl or Cmd is pressed, or should be removed entirely since there's a dedicated search box.

**Bug 2: "Send Message" misleading**
Location: session-viewer.py line 836. The button says "Add Feedback" (not "Send Message") and the modal title says "General Guidance". But the submit button inside the modal says "Send" which implies real-time delivery. The toolbar button tooltip says "Saved to session DB for agent review" -- correct but not visible enough.

**Fix**: Change "Send" to "Queue Feedback" or "Save". Add explanatory text: "Feedback is saved to the session DB. Agents read it on /rewind or at delegation boundaries."

**Bug 3: Line numbers in contextual feedback**
Location: session-viewer.py line 1067-1096. The context menu captures the nearest heading but not line numbers from the rendered content. The rendered HTML doesn't preserve line number information from the source markdown.

**Fix**: When rendering markdown, add `data-line` attributes to block elements. The context menu handler can then read `data-line` to include line number context.

**Bug 4: Checkout flow for general feedback**
Location: The "Add Feedback" button (line 836) opens a general feedback modal. After submitting, there's no "batch checkout" -- each message is submitted individually. The last general message (feedback #8) didn't submit because the user hit "Send" but nothing happened -- possibly because the textarea was empty or a JS error occurred.

**Fix**: Add a batch feedback mode: collect multiple messages, show them in a queue, submit all at once with a "Submit All" button. Add visual confirmation that feedback was saved.

### Action

Bug fixes documented. These are improvements to session-viewer.py (scratch file, not committed code). Fixes would be applied if/when the viewer is promoted to scripts/.
