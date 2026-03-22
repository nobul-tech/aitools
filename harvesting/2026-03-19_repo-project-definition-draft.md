# Governed Vocabulary Draft: "repo" and "project"

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Scope**: Definition drafting for two ungoverned terms used extensively
throughout the harness. Follows the /glossary skill's process as guidance.

---

## 1. Current Usage Inventory

### "repo" usage across the harness

| File | Usage | Meaning implied |
|------|-------|-----------------|
| `CLAUDE.md` Mission | "Multi-user via dotprofile repos" | git repositories specifically |
| `CLAUDE.md` Mission | "gives every project it touches" | any working directory |
| `CLAUDE.md` Dotprofile Repos | "Per-user companion repos" | git repositories |
| `CLAUDE.md` Cross-Platform Paths | "This repo" = `~/repos/aitools` | git repository |
| `CLAUDE.md` Key Decisions | "This directory is the home base" | directory/folder |
| `.claude/rules/aitools-workspace.md` L33 | "`<repo>/.aitools/`" | any working directory |
| `.claude/rules/aitools-workspace.md` L53 | "Project-scoped (.aitools/ at repo root)" | interchangeable with "project" |
| `.claude/rules/aitools-workspace.md` L58 | "`<repo>/.aitools/`" in scope boundary | any working directory |
| `reference/harness.md` L5 | "any project on any platform" | any working directory |
| `reference/harness.md` L28-29 | "Project (.claude/rules/...)" | the specific codebase/folder |
| `reference/user-repo.md` L174 | "within the project repo" | git repository |
| `reference/framework-governed-vocabulary.md` L65 | "project claude = CLAUDE.md in aitools repo root" | git repository |
| `glossary.json` scope modifier | `"project": "In the aitools repo, for this repo's sessions"` | the aitools git repo |
| `glossary.json` "aitools repo" | "The ~/repos/aitools repository" | git repository |
| `glossary.json` "dotprofile repo" | "The aitools-<username> companion repo" | git repository |
| `glossary.json` "deployment scope" | "project-level (one repo)" | any working directory |
| All `.claude/rules/*.md` headers | "(this repo)" | the aitools git repo |

**Pattern**: "repo" is used in two distinct senses: (1) a git repository
specifically (aitools repo, dotprofile repo, "clone to ~/repos/"), and (2) any
working directory where the harness operates (`<repo>/.aitools/`, "every project
it touches").

### "project" usage across the harness

| File | Usage | Meaning implied |
|------|-------|-----------------|
| `CLAUDE.md` Mission | "any project on any supported platform" | any body of work in any folder |
| `CLAUDE.md` DP Skills as enablement | "Project-level skills (.claude/skills/) cover repo-specific frameworks" | this codebase |
| `CLAUDE.md` PSOs | "the project's check scripts" | this codebase |
| `.claude/rules/aitools-workspace.md` L5 | "project-scoped harness capabilities" | the working directory the harness touches |
| `.claude/rules/aitools-workspace.md` L19 | "working on the same project across multiple machines" | body of work, not a folder |
| `.claude/rules/aitools-workspace.md` L53 | "Project-scoped (.aitools/ at repo root)" | interchangeable with "repo" |
| `reference/harness.md` L5 | "any project on any platform" | any body of work |
| `reference/harness.md` L28 | "Project (.claude/rules/...)" | this codebase |
| `reference/user-repo.md` L91 | "project name derived from the working directory" | name for archival grouping |
| `reference/user-repo.md` L96 | "cwd may not match the project being worked on" | body of work (not tied to a single folder) |
| `glossary.json` "project coaching item" | "specific to this repo" | this codebase |
| `glossary.json` "project standing order" | "specific to this repo" | this codebase |
| `glossary.json` scope modifier "project" | "In the aitools repo, for this repo's sessions" | the aitools git repo specifically |
| `glossary.json` "deployment scope" | "project-level (one repo)" | one working directory |
| `glossary.json` "configuration" | "Exists at project and user deployment scope" | per-repo |

**Pattern**: "project" is used in three senses: (1) a body of work ("working
on the same project across multiple machines"), (2) the specific codebase
in this repo ("project's check scripts", "project standing order"), and
(3) interchangeably with "repo" ("project-scoped = at repo root").

---

## 2. Conversation Signals

### Primary signal: User statement (2026-03-17 session, quoted in S2 briefing analysis)

> "repo, as we have been using it in defining the context/scope of the
> tools/artifacts/state and frameworks, can be just a folder that lives
> on anything accessible via the os (local filesystems, nas, google drive,
> dropbox, onedrive, lucidelink, suite studios). a repo can also be a git
> repo, and then all the git stuff that comes along with it. similarly to
> how claude.md and agents.md artifacts work."

Key signals:
- **"can be just a folder"** -- repo is not git-only
- **"on anything accessible via the os"** -- filesystem-agnostic (local, NAS, cloud)
- **"can also be a git repo"** -- git is a specialization, not the default
- **"similarly to how claude.md and agents.md artifacts work"** -- Claude Code
  already operates in any folder; the harness should match this behavior
- The user explicitly listed concrete storage types: local filesystems, NAS,
  Google Drive, Dropbox, OneDrive, LucidLink, Suite Studios

### Supporting signal: User's actual projects (from b8a9ed4e session transcript)

The session transcript reveals the user's Claude Code project list includes
both git repos and Google Drive folders:
- `~/repos/aitools` (git repo)
- `~/repos/marse` (git repo)
- `~/repos/qr-contact` (git repo)
- `~/Library/CloudStorage/GoogleDrive-.../nobul-co-ai-tooling` (Google Drive)
- `~/Library/CloudStorage/GoogleDrive-.../nobul-co-website` (Google Drive)
- `~/Library/CloudStorage/GoogleDrive-.../Personal/legal-...` (Google Drive)

This empirically demonstrates the user already works in both git repos and
non-git folders as "projects."

### Supporting signal: S2 briefing analysis (2026-03-18)

The briefing analysis (section 2) proposed definitions that align with
the user's statement:
- **repo**: "Any folder accessible via the OS that a user works in"
- **project**: "The working context within a repo -- the codebase,
  configuration, and state that a user is actively developing"
- Also identified that the carry-forward principle needs amendment: "MUST be
  persisted in a way that survives machine switches" rather than specifically
  "tracked in git"

### Absence signal: No contradictory user statements found

Searched three session transcripts (2026-03-16 b8a9ed4e, 79b05dd0,
37ab88e4) for user messages containing definitional language about "repo"
or "project." Found no statements contradicting the 2026-03-17 definition.
The user has used both terms loosely throughout sessions without prior
formal definition.

---

## 3. Draft Definitions (JSON format)

```json
"repo": {
  "definition": "Any OS-accessible folder where a user works — local filesystem, NAS, or cloud-synced (Google Drive, Dropbox, OneDrive, LucidLink). A repo MAY also be a git repository, gaining tracking, branching, and pull-based carry-forward. The harness provides capabilities (.aitools/) to repos regardless of backing storage. Distinct from aitools repo and dotprofile repo (which are specific named repos that happen to be git repos).",
  "source": ".claude/rules/aitools-workspace.md"
},
"project": {
  "definition": "The body of work a user is actively developing within a repo — the codebase, configuration, artifacts, and operational state. A repo contains one project. Project-scoped means scoped to that body of work (stored in <repo>/.aitools/). Distinct from the scope modifier 'project' (which means 'in the aitools repo').",
  "source": ".claude/rules/aitools-workspace.md"
}
```

---

## 4. Ambiguity Removal Passes

### Pass 1: Undefined terms

**"repo" draft**:
- "OS-accessible folder" -- clear, no undefined terms
- "cloud-synced" -- clear from the parenthetical examples
- "backing storage" -- might be unfamiliar; but the preceding list makes it clear
- "capabilities (.aitools/)" -- defined term ("harness" governs this); parenthetical clarifies

**"project" draft**:
- "body of work" -- potentially vague. What distinguishes "body of work" from "folder contents"?
  Resolution: the phrase "actively developing" provides the human-intent dimension.
  A folder with abandoned files is still a repo but arguably not an active project.
  However, the harness treats them the same -- `.aitools/` doesn't care about intent.
  Revised: remove "actively developing" to avoid implying the harness only works on
  active projects. Replace with "develops or maintains."
- "operational state" -- defined via the workspace rule (.aitools/ contents)
- "scope modifier 'project'" -- this is a glossary facet; the distinction is needed
  but the parenthetical is awkward. Simplify.

### Pass 2: Vague mechanisms

**"repo" draft**:
- "gaining tracking, branching, and pull-based carry-forward" -- specific enough.
  Lists the concrete git capabilities that matter to the harness.
- "regardless of backing storage" -- clear mechanism boundary: harness doesn't
  care what storage backs the folder.

**"project" draft**:
- "A repo contains one project" -- is this always true? Could a monorepo contain
  multiple projects? In the harness model, `.aitools/` is per-folder. One folder,
  one `.aitools/`, one project. This is a design decision, not just a definition.
  The user's statement doesn't address monorepos. Keep the 1:1 mapping since it
  matches the workspace rule's design. A monorepo would be one project with
  multiple workspaces/packages -- still one `.aitools/`.
- "Project-scoped means scoped to that body of work" -- circular. Revise:
  "Project-scoped means stored in `<repo>/.aitools/` and specific to that repo's
  sessions and artifacts."

### Pass 3: Barrier test

**"repo" barrier test -- 3 examples**:

1. **`~/repos/aitools` (git repo)**: A repo. Also a git repo, so it gains
   git tracking, branching, carry-forward via pull. Has `.aitools/` for
   harness capabilities. Matches definition. Also happens to be the
   "aitools repo" governed term.

2. **Google Drive/nobul/project-x (cloud folder)**: A repo. Not a git repo.
   Cloud sync provides carry-forward instead of git pull. Can have
   `.aitools/` for harness capabilities (scratch, channel, briefings).
   `.aitools/harvesting/` persists via cloud sync. No git operations
   available (hooks that use `git add` must degrade gracefully).
   Matches definition.

3. **`/Volumes/NAS/shared-assets` (NAS mount)**: A repo. Not a git repo.
   No automatic carry-forward (NAS is accessible from multiple machines
   simultaneously, so carry-forward is "already there"). Can have
   `.aitools/`. Matches definition.

All three pass. The definition correctly describes each case without
forcing git assumptions.

**"project" barrier test -- 3 examples**:

1. **The aitools codebase**: The project within `~/repos/aitools`. The body
   of work is the CLI, scripts, rules, frameworks, plans, reference files.
   Project-scoped data in `.aitools/` (scratch, channel, harvesting, briefings).
   Matches definition.

2. **A client website in a Google Drive folder**: The project within
   `~/Library/CloudStorage/GoogleDrive-.../nobul-co-website`. The body of
   work is the website files. Could have `.aitools/` for harness capabilities
   (session scratch, briefings). Matches definition.

3. **A user's dotprofile repo**: The project within
   `~/repos/aitools-nobul-jose`. The body of work is the user's preferences,
   rules, session archives. Has its own `.aitools/` (if the user works
   on it with harness-enabled agents). Matches definition. Note: the
   "dotprofile repo" governed term names the specific repo; "project"
   names the body of work within it.

All three pass. The definition works for git repos, cloud folders, and
companion repos.

---

## 5. Interaction with Existing Governed Terms

### "aitools repo"

**Current definition**: "The ~/repos/aitools repository -- source of truth
for all harness content. Distinct from aitools (the CLI command)."

**Interaction**: "aitools repo" is a specific named repo. Under the new
definition, it is a repo that also happens to be a git repository. No
conflict. The existing definition says "repository" which is slightly
ambiguous -- it could mean git repo or just "a place where things are
stored." Given the path `~/repos/aitools` and the fact that it IS a git
repo, the current definition works. No change needed, but the relationship
is: aitools repo IS-A repo (general) AND IS-A git repo (specialization).

### "dotprofile repo"

**Current definition**: "The aitools-<username> companion repo storing
per-user preferences, claude templates, rules, and session archives.
Distinct from aitools repo."

**Interaction**: Same pattern as aitools repo. It is a specific named repo
that happens to be a git repo. No conflict. No change needed.

### "project" scope modifier

**Current facet definition**: `"project": "In the aitools repo, for this
repo's sessions"`

**Interaction**: This is the most important interaction to get right. The
scope modifier "project" currently means "in the aitools repo." The new
term "project" means "the body of work within a repo."

These are different concepts:
- Scope modifier "project" = a location qualifier for composed terms
  (e.g., "project rule" = a rule in `.claude/rules/` of the aitools repo)
- Term "project" = the general concept of a body of work in any repo

**Conflict?** Partial. The scope modifier's definition says "In the aitools
repo" -- it is aitools-specific. The term "project" is general. An agent
reading both might be confused: "does 'project' always mean the aitools
repo?"

**Resolution**: The scope modifier should be understood as "in the current
repo" (whichever repo the agent is working in), not "in the aitools repo"
specifically. However, the facet definition explicitly says "aitools repo."
This is because the facets were written for the aitools repo's glossary
rule, which says "(this repo)." The facet is correct for its context but
narrow.

**Recommendation**: The new "project" term definition should note the
distinction. The scope modifier facet may need a future update to
generalize from "In the aitools repo" to "In the current repo, for this
repo's sessions" -- but that is a separate change to propose via /glossary.

### "deployment scope"

**Current definition**: "Where a configuration, tool, hook, or MCP server
applies: user-level (all projects on the machine), project-level (one
repo), or managed-level (all users on the machine). Distinct from intent
scope."

**Interaction**: Uses "project-level (one repo)" -- which aligns with the
new definitions. A project is in one repo. Project-level deployment scope
means it applies to that one repo. No conflict.

### "configuration"

**Current definition**: "...Exists at project and user deployment scope."

**Interaction**: Uses "project" in the sense of "per-repo." Aligns with new
definition. No conflict.

---

## 6. Exemplar Calibration

### Style analysis of 5 recent glossary definitions

1. **"harness"**: "aitools and the tools, context, state, artifacts,
   frameworks, and provenance it manages. Five components: platform,
   configuration, orchestration, managed tools, frameworks."
   - Pattern: [what it IS]. [Enumeration].
   - One sentence + one enumerative fragment.

2. **"incident"**: "A tracked deficiency in the harness. Unifies the
   former 'gap' (code deviates from spec) and 'ambiguity' (no spec exists)
   types. Filed in incidents.json with structured fields. Severity:
   critical/high/medium/low. Lifecycle: open, planned, closed."
   - Pattern: [what it IS]. [History]. [Where it lives]. [Attributes].
   - One sentence + supporting fragments.

3. **"framework"**: "A governance structure built by adopting concepts from
   an established discipline. Bridges discipline to artifacts. Distinct
   from discipline (external field) and artifact (specific file). Each
   framework has a dedicated reference file and a registry entry."
   - Pattern: [what it IS with qualifying clause]. [Relationship].
   [Distinct-from]. [Implementation].
   - One sentence + three supporting fragments.

4. **"governed file"**: "A JSON registry file accessible only through its
   governing skill's process. The skill is the API; the JSON is the
   implementation detail. Current governed files: incidents.json (/incident),
   glossary.json (/glossary), framework-registry.json (/frameworks)."
   - Pattern: [what it IS]. [Metaphor]. [Enumeration].
   - One sentence + two supporting fragments.

5. **"controlled distribution"**: "The practice of not advertising governed
   file paths in rules or documentation. Access is routed through the
   governing skill, which is the only documented entry point. From ISO
   9001 document control."
   - Pattern: [what the practice IS]. [How it works]. [Source].
   - One sentence + two supporting fragments.

### Calibration findings

- First sentence: "[Subject] [verb] [what it is]" -- active, no restated title
- Supporting fragments: 1-4 short sentences expanding on relationships, implementation, or distinctions
- "Distinct from X" pattern used when sibling terms exist
- Total length: 1-4 sentences (30-60 words typical)
- Sources: the most relevant governing rule or reference file

### Calibrated drafts

**"repo"** (calibrated):

```json
"repo": {
  "definition": "Any OS-accessible folder where a user works — local filesystem, NAS, or cloud-synced (Google Drive, Dropbox, OneDrive, LucidLink). May also be a git repository, gaining tracking, branching, and pull-based carry-forward. The harness provides capabilities (.aitools/) regardless of backing storage. Distinct from aitools repo and dotprofile repo (specific named repos).",
  "source": ".claude/rules/aitools-workspace.md"
}
```

Word count: 49. Matches exemplar range (30-60).

**"project"** (calibrated):

```json
"project": {
  "definition": "The body of work a user develops or maintains within a repo — codebase, configuration, artifacts, and operational state. A repo contains one project. Project-scoped data lives in <repo>/.aitools/. Distinct from the scope modifier 'project' (which qualifies composed terms like 'project rule' for the current repo).",
  "source": ".claude/rules/aitools-workspace.md"
}
```

Word count: 50. Matches exemplar range.

---

## 7. Barrier Test Results

### "repo" barrier test summary

| Example | Type | Git? | Carry-forward | .aitools/ | Definition fits? |
|---------|------|------|---------------|-----------|-----------------|
| `~/repos/aitools` | Local filesystem | Yes | git pull | Yes | Yes |
| Google Drive/nobul/project-x | Cloud-synced | No | Cloud sync | Yes | Yes |
| `/Volumes/NAS/shared-assets` | NAS mount | No | Direct access | Yes | Yes |

No barrier failures. All three examples are correctly described by the
definition without requiring git.

### "project" barrier test summary

| Example | Repo | Body of work | .aitools/ scoping | Definition fits? |
|---------|------|-------------|-------------------|-----------------|
| aitools codebase | `~/repos/aitools` | CLI, scripts, frameworks | `.aitools/` at repo root | Yes |
| Client website | Google Drive folder | Website files | `.aitools/` in folder | Yes |
| Dotprofile repo | `~/repos/aitools-nobul-jose` | Preferences, archives | `.aitools/` at repo root | Yes |

No barrier failures. The 1:1 relationship (one repo, one project) holds for
all three examples.

### Edge case: monorepo

A monorepo (e.g., `~/repos/big-company` with 50 packages) would be one
repo, one project, one `.aitools/`. Individual packages are not separate
projects in the harness sense -- they are parts of one project. This
matches Claude Code's behavior (one `CLAUDE.md` at root).

---

## 8. Recommendation: Additional Terms Needed?

### "git repo" as a distinct governed term?

**Not recommended.** The "repo" definition already handles this with "May
also be a git repository, gaining tracking, branching, and pull-based
carry-forward." A separate "git repo" term would create a third concept
where two suffice. In natural language, "git repo" already has a clear
meaning. Governing it would add complexity without reducing ambiguity.

### Scope modifier "project" facet update?

**Recommended as follow-up.** The current facet definition `"project": "In
the aitools repo, for this repo's sessions"` should be updated to `"project":
"In the current repo, for this repo's sessions"` to generalize beyond the
aitools repo. This is a separate change to propose via /glossary since it
modifies a governed file.

### Carry-forward mechanism term?

**Not recommended now.** The workspace rule's carry-forward principle
currently says "tracked in git." With repos potentially being non-git
folders, this needs amendment to "persisted in a way that survives machine
switches." But this is a workspace rule amendment, not a new governed term.
"Carry-forward" is self-explanatory in context.

---

## Summary of Deliverables

1. **Two new governed terms**: "repo" and "project"
2. **Calibrated definitions** matching glossary exemplar style
3. **No conflicts** with existing governed terms (aitools repo, dotprofile repo, deployment scope)
4. **One known interaction**: scope modifier "project" facet should be generalized (separate follow-up)
5. **Source file**: `.claude/rules/aitools-workspace.md` (the workspace rule is the natural governing home for both terms)
6. **No additional governed terms needed** -- "git repo" as separate term rejected; carry-forward mechanism is a rule amendment not a vocabulary item
