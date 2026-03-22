# Briefings Location Decision Analysis

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Scope**: Formal capture of the user's decision on briefing location, consistency audit against workspace rule and planning brief, barrier analysis, Q4 amendments.

---

## 1. Formal Decision Capture

### Decision: Briefings live at `.aitools/briefings/`

**Statement**: Briefings are a harness capability and live at `.aitools/briefings/` (project-scoped, inside the workspace namespace). NOT at repo root `briefings/`.

**Rationale**: Briefings ARE a harness capability. The harness provides structured decision-making to every project it touches -- just as it provides scratch (working space), channel (communication), and harvesting (artifact lifecycle). A briefing is not "project content" in the sense Q4 argued. It is a harness-provided capability for structuring decisions. The `/brief` skill (decision #45) governs briefing access, making briefings governed data in the same pattern as `incidents.json`, `glossary.json`, `framework-registry.json`. Governed data lives in the workspace namespace.

**What this amends**:

- **Decision #34** (namespace consolidation): Briefings are now explicitly included in `.aitools/`. Decision #34's component list should add `(14) .aitools/briefings/ -- structured decision documents (planning briefs, handoff prompts). Tracked in git`.
- **Q4 investigation**: Q4's Option C (`.aitools/briefings/`) was rejected with the rationale "Briefings are project content, not harness capabilities." The user's decision reverses this classification. Option C becomes the correct choice with corrected rationale. Option A (repo root `briefings/`) is now rejected.
- **Workspace rule** (`aitools-workspace.md`): Needs a `briefings/` row in the workspace structure table.

### Companion Decision: "Repo" vs "Project" Clarification

**Statement**: A "repo" as used in the harness context is not necessarily a git repo. It can be any folder accessible via the OS -- local filesystem, NAS, Google Drive, Dropbox, OneDrive, LucidLink, Suite Studios. A "repo" CAN also be a git repo, and then all the git capabilities come along with it (tracking, branching, carry-forward via pull). The term "project" and "repo" have been used loosely and interchangeably. This decision clarifies the scope.

**Implication for `.aitools/`**: `.aitools/` can exist in any folder, not just git repos. This is parallel to how `.claude/` works -- `claude.md` and `agents.md` function in any folder.

---

## 2. Repo/Project Terminology Analysis

### Current governed status

- **"repo"**: NOT a governed term. Not in `glossary.md` word list. Not in `glossary.json` terms.
- **"project"**: NOT a governed term. Appears only as a **scope modifier** in the glossary facets (`"project": "In the aitools repo, for this repo's sessions"`), meaning "in the aitools repo." NOT defined as a general-purpose term.
- **"aitools repo"**: IS a governed term. Definition: "The ~/repos/aitools repository -- source of truth for all harness content. Distinct from aitools (the CLI command)."
- **"dotprofile repo"**: IS a governed term. Definition: "The aitools-<username> companion repo storing per-user preferences..."

### Should they be governed?

**Yes -- both need governing.** The user identified that "repo" and "project" have been used loosely and interchangeably. The harness documentation uses both terms extensively:

- **Workspace rule** (aitools-workspace.md): Uses "project" 5 times, "repo" 3 times. Line 33 says `<repo>/.aitools/` but line 53 says "Project-scoped (.aitools/ at repo root)." These are used interchangeably here.
- **CLAUDE.md**: Uses "project" 13+ times, "repo" 10+ times. The Mission statement says "any project on any platform." The Project Structure section says "aitools/" at the top.
- **Harness.md**: Uses "project" 4 times ("any project on any platform," "project-level configuration").
- **Decision #34**: Says "at repo root in every project that uses aitools workspace features."

### Proposed definitions (for S3 to formalize via /glossary)

| Term | Proposed definition |
|------|-------------------|
| **repo** | Any folder accessible via the OS that a user works in. May be a git repository (enabling tracking, branching, carry-forward via pull), a cloud-synced folder (Google Drive, Dropbox, OneDrive), a NAS share, or a local directory. The harness provides capabilities (`.aitools/`) to repos regardless of their backing storage. Distinct from "aitools repo" and "dotprofile repo" which are specific named repos. |
| **project** | The working context within a repo -- the codebase, configuration, and state that a user is actively developing. A repo contains one project. "Project-scoped" means data about THIS project's sessions, artifacts, and operational state (stored in `<repo>/.aitools/`). |

### Implications for the workspace rule

The workspace rule currently says (line 22-23): "Project state that carries forward between sessions -- running estimates, consolidated findings, harvested artifacts -- MUST be tracked in git so it survives machine switches via pull."

If a repo is NOT a git repo (e.g., Google Drive folder), the carry-forward mechanism changes:
- **Git repos**: carry-forward via `git pull` (current assumption)
- **Cloud-synced folders**: carry-forward via cloud sync (Google Drive, Dropbox, OneDrive)
- **NAS/local**: no automatic carry-forward; user must manage manually

The workspace rule's carry-forward principle remains valid but needs to be expressed as "MUST be persisted in a way that survives machine switches" rather than specifically "tracked in git." Git is one mechanism; cloud sync is another. The principle is machine-independence, not git specifically.

---

## 3. Workspace Rule Consistency Check

### Does `.aitools/briefings/` fit the governing principle?

**Yes.** The governing principle states: "Channel, scratch, harvesting, and operational learning are harness capabilities. The harness (aitools + Claude Code) provides these to every project it works on."

Briefings are a harness capability in exactly the same way:
- **Channel**: harness provides structured inter-agent communication
- **Scratch**: harness provides ephemeral working space
- **Harvesting**: harness provides artifact lifecycle management
- **Briefings**: harness provides structured decision-making

The `/brief` skill (decision #45) governs briefing access, making them a capability the harness provides, not project-specific content.

### Should briefings be tracked or gitignored?

**Tracked.** Briefings contain decisions that carry forward across sessions and machines. Per the cross-machine carry-forward principle: "if data needs to survive a machine switch, it must be tracked." Briefings are living documents that accumulate decisions over multiple sessions. They are the opposite of ephemeral.

In a non-git repo (e.g., Google Drive), "tracked" means "persisted in the folder" (which cloud sync handles). The principle still holds -- briefings must survive machine switches.

### What changes in the workspace structure table?

Add a row:

| Directory | Tracked | Purpose |
|-----------|---------|---------|
| `briefings/` | tracked | Structured decision documents -- planning briefs, handoff prompts, delegation context |

Updated governing principle text should read: "Channel, scratch, harvesting, operational learning, and **briefings** are harness capabilities."

### .gitignore concern

**CRITICAL FINDING**: The repo-root `.gitignore` (line 47) has `.aitools/` which ignores the ENTIRE directory. Currently, NO `.aitools/` content is tracked in git -- confirmed by `git ls-files .aitools/` returning empty. The workspace rule says `harvesting/` and `channel/running-estimate.json` should be tracked, but the gitignore prevents this.

This means decision #34's namespace consolidation has NOT been fully implemented. `harvesting/` still lives at repo root (tracked). `.aitools/` only contains `channel/` (gitignored).

**For briefings to be tracked at `.aitools/briefings/`**, the `.gitignore` pattern must change from:
```
.aitools/
```
to selective patterns like:
```
.aitools/scratch/
.aitools/channel/session-*/
.aitools/.current-session
.aitools/channel/.current-session
```
This would allow `.aitools/briefings/`, `.aitools/harvesting/`, and `.aitools/channel/running-estimate.json` to be tracked.

Or alternatively, use a nested `.aitools/.gitignore` with negation patterns:
```
# Ignore everything by default
*
# But track these
!.gitignore
!briefings/
!briefings/**
!harvesting/
!harvesting/**
!channel/running-estimate.json
```

This is a prerequisite for the namespace consolidation to work as designed.

---

## 4. Barrier Analysis

### 4.1 What breaks if briefings are in `.aitools/briefings/` instead of repo root `briefings/`?

| Barrier | Severity | Impact | Mitigation |
|---------|----------|--------|------------|
| Q4 migration plan references `briefings/<name>/` at root | Low | Q4 migration paths need updating | Update Q4 paths to `.aitools/briefings/<name>/` |
| `.gitignore` currently blocks all `.aitools/` tracking | High | Briefings would be gitignored and invisible to git | Restructure `.gitignore` to selectively ignore `.aitools/` subdirectories (see section 3) |
| Planning brief currently at `plans/mission-command-briefing/planning-brief.json` | Medium | Needs migration to `.aitools/briefings/mission-command/planning-brief.json` | Include in migration plan |
| Visibility -- `.aitools/` is a hidden directory | Low | User's concern from Q4. But user has now explicitly chosen this location, overriding the visibility concern | User decision. IDE file explorers can be configured to show hidden dirs |
| References in handoff prompt and other files point to `plans/mission-command-briefing/` | Medium | All references need updating | Part of migration |
| `/brief` skill (decision #45) needs to know the path | Low | Skill reads from `.aitools/briefings/` instead of `briefings/` | Update skill spec |
| Decision #34 components need amendment | Low | Add briefings component | Draft amendment |

### 4.2 What breaks if the repo is NOT a git repo?

| Barrier | Severity | Impact | Mitigation |
|---------|----------|--------|------------|
| Carry-forward principle says "tracked in git" | High | Non-git repos have no git tracking | Amend principle: "persisted in a way that survives machine switches" -- git is one mechanism, cloud sync is another |
| `harvesting/` relies on git for carry-forward | Medium | In a Google Drive folder, harvesting files persist via cloud sync instead | Cloud sync provides the same persistence guarantee for static files |
| SessionEnd hook uses `git add`, `git commit` | Medium | Hook would fail in non-git folder | Hook must check for git presence before git operations; degrade gracefully |
| `.gitignore` patterns irrelevant in non-git folders | None | Non-issue -- no git, no gitignore | N/A |
| Session archiving (decision #36) auto-commits | Medium | Cannot auto-commit in non-git repo | Archive hook must handle non-git case: archive to folder without git operations |
| `aitools` CLI assumes git repo (`git checkout HEAD -- deploy/`) | Low | Only applies to the aitools repo itself, which IS a git repo | N/A for other projects |
| Diff review in deployment menus | Low | `git diff` unavailable; fall back to file comparison | Menus should use file diff when git unavailable |

### 4.3 Does the `.gitignore` pattern for scratch and channel still work?

**Current state**: `.aitools/` in root `.gitignore` ignores everything. This is too broad.

**Required state after namespace consolidation**:

| Path | Should be | Currently is |
|------|-----------|-------------|
| `.aitools/scratch/` | gitignored | gitignored (via `.aitools/` blanket) |
| `.aitools/channel/session-*/` | gitignored | gitignored (via `.aitools/` blanket) |
| `.aitools/channel/running-estimate.json` | tracked | gitignored (BUG) |
| `.aitools/harvesting/` | tracked | gitignored (BUG -- harvesting still at root) |
| `.aitools/briefings/` | tracked | gitignored (BUG -- would be ignored) |

The blanket `.aitools/` gitignore is a blocking issue for the entire namespace consolidation, not just briefings.

---

## 5. Q4 Amendments Needed

### 5.1 What Q4 got wrong

1. **Classification error**: Q4 classified briefings as "project content, not harness capabilities." The user's decision reverses this. Briefings ARE a harness capability -- the harness provides structured decision-making to every project it touches, just as it provides scratch, channel, and harvesting.

2. **Option C rejection rationale**: Q4 rejected Option C (`.aitools/briefings/`) based on three arguments:
   - "Violates the workspace governing principle" -- **Incorrect.** Briefings fit the principle once correctly classified as a harness capability.
   - "Visibility -- .aitools/ is a hidden directory" -- **Valid concern but overridden by user.** The user explicitly chose `.aitools/` despite this.
   - "Scope -- .aitools/ is designed to be portable" -- **Actually supports the decision.** Briefings SHOULD be portable across projects. Every project the harness touches gets the capability to create structured decision documents.

3. **Pre-consolidation paths**: Q4 used `harvesting/` at repo root throughout, contradicting decision #34 and the workspace rule which place it at `.aitools/harvesting/`. Already flagged as a blocker in the ambiguity audit.

### 5.2 What Q4 got right (still valid)

1. **Lifecycle analysis** (section 2): The lifecycle stages for briefings (draft, working, active, archived) are correct regardless of location. Moving from `briefings/` to `.aitools/briefings/` does not change the lifecycle.

2. **Content separation**: The distinction between what lives in briefings vs. what goes through harvesting is correct. Investigation reports, AARs, research synthesis still go through the harvesting pipeline. Only structured decision documents (brief JSON, handoff prompts, delegation context) live in briefings.

3. **The full lifecycle flow** (section 5) is correct in structure. The path labels need updating:
   - `harvesting/` becomes `.aitools/harvesting/`
   - `briefings/<name>/` becomes `.aitools/briefings/<name>/`
   - The arrows and promotion gates remain valid.

4. **The rule recommendation**: Q4 correctly identified that briefings need a governing rule. The rule content is valid -- it would be `.claude/rules/briefings.md` governing `.aitools/briefings/`.

5. **The "what lives in briefings" and "what does NOT live in briefings" tables** are correct and location-independent.

### 5.3 Specific Q4 text that needs updating

| Section | Current text | Corrected text |
|---------|-------------|----------------|
| Section 3, Option A assessment | "Strong option. Clean taxonomy..." | Option A rejected -- briefings are harness capabilities, not project content |
| Section 3, Option C assessment | "Rejected. Briefings are project content, not harness capabilities." | Accepted. Briefings ARE harness capabilities -- the harness provides structured decision-making to every project. |
| Section 3, Option C barrier "Violates workspace principle" | "Briefings are project-specific content, not harness capabilities" | Briefings are harness capabilities, same as channel, scratch, harvesting |
| Section 4, Recommended Decision | "Option A: briefings/ as a new top-level directory" | Option C: `.aitools/briefings/` |
| Section 5, lifecycle diagram paths | `harvesting/`, `briefings/<name>/` | `.aitools/harvesting/`, `.aitools/briefings/<name>/` |
| All path references | `briefings/` at root | `.aitools/briefings/` |

---

## 6. Recommended Next Steps for S3

### Immediate (before plan writing)

1. **Amend decision #34**: Add component `(14) .aitools/briefings/ -- structured decision documents (planning briefs, handoff prompts, delegation context). Tracked in git` via the `/brief` skill.

2. **Resolve the `.gitignore` blocker**: The blanket `.aitools/` pattern in the root `.gitignore` must be replaced with selective patterns. This blocks the entire namespace consolidation, not just briefings. Proposed:
   ```gitignore
   # aitools workspace -- selective ignore
   .aitools/scratch/
   .aitools/channel/session-*/
   .aitools/.current-session
   .aitools/channel/.current-session
   ```
   This allows tracking of `.aitools/briefings/`, `.aitools/harvesting/`, and `.aitools/channel/running-estimate.json`.

3. **Govern "repo" and "project"**: File via `/glossary` skill. Both terms are used extensively, loosely, and interchangeably. The user's clarification (repo = any OS-accessible folder; project = working context within that folder) needs to be the governed definition.

### Near-term (during plan writing)

4. **Amend the workspace rule**: Add `briefings/` row to the workspace structure table. Update the governing principle text to include briefings in the capability list.

5. **Amend the carry-forward principle**: Change "MUST be tracked in git" to "MUST be persisted in a way that survives machine switches" to accommodate non-git repos. Git tracking is one mechanism; cloud sync is another.

6. **Update Q4**: Apply the corrections from section 5.3. Q4's lifecycle analysis and content separation rules remain valid -- only the location and rationale change.

7. **Migration**: Move `plans/mission-command-briefing/planning-brief.json` and `handoff-prompt.md` to `.aitools/briefings/mission-command/`. Update all references.

### Deferred (implementation phase)

8. **Hook updates**: SessionEnd, SessionStart, and archival hooks must handle non-git repos gracefully. Check for git presence before git operations.

9. **`/brief` skill path**: Update skill spec to reference `.aitools/briefings/` instead of `briefings/`.

10. **Audit all "repo" and "project" usage**: Once governed, audit CLAUDE.md, workspace rule, harness.md, and all rules for consistent usage per the governed definitions.

---

## Appendix: Ambiguity Audit Blocker Resolution

The Q4-Q10 ambiguity audit identified 3 blockers. This decision resolves blocker #3:

| Blocker | Status after this decision |
|---------|--------------------------|
| 1. "Promotion" is undefined | Still open -- needs /glossary filing |
| 2. Q4 uses pre-consolidation paths | Resolved -- all paths now `.aitools/` |
| 3. Q4 proposes `briefings/` at root without acknowledging #34 | Resolved -- briefings now explicitly part of `.aitools/` per user decision. No exception needed. |
