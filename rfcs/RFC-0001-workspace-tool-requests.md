# RFC 0001: Workspace tool-requests file convention

| Field | Value |
|-------|--------|
| **RFC** | 0001 |
| **Title** | Workspace tool-requests file convention |
| **Author(s)** | Jose |
| **Status** | Proposed |
| **Created** | 2026-02-28 |
| **Updated** | 2026-03-01 |

---

## Abstract

This RFC specifies a **convention** by which any repository can declare **tool or feature requests** for consumption by aitools. Agents and humans interact with requests via GitHub (`gh` CLI or web). The convention is minimal, file-based, and assistant-friendly.

---

## Status of this memo

This document is a **proposed** specification. Implementation in the aitools repository is optional and follows the project's normal decision process (e.g. maintainer approval, PR review).

---

## 1. Motivation

- **Problem:** Repositories often need specific CLI tools (e.g. `typst`, `pandoc`) that are managed centrally by aitools. There is no standard way for an assistant or a human working in a repository to "request" a tool and for aitools to consume that request with proper context.
- **Goal:** Define a single, simple convention so that (1) repositories can maintain a list of requested tools in one place, (2) aitools can discover and process that list via GitHub, and (3) assistants (e.g. Cursor, Claude Code) can add requests in the repository and fulfill them in aitools with clear context.

---

## 2. Terminology

- **Repository:** A GitHub repository that participates in this convention.
- **Tool-requests file:** A markdown file at a well-known path in the repository that conforms to this RFC.
- **Aitools:** The tooling and repository (`nobul-jose/aitools`) used to manage installed tools across machines. Consumes tool-requests files from other repositories.
- **RFC 2119:** The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

---

## 3. Specification

### 3.1 Repository side: tool-requests file

3.1.1. A repository that wishes to participate in this convention MUST maintain at most one **tool-requests file** at the following path relative to the repository root:

- `docs/aitools-requests.md`

3.1.2. The file MUST be UTF-8 encoded markdown and MUST contain at least one **markdown table** with the following header row (column names are normative):

```markdown
| Tool / Feature | Reason | Install / hint | Status |
|----------------|--------|----------------|--------|
```

3.1.3. Each data row in that table represents one request:

- **Tool / Feature:** Short name of the tool or feature (e.g. `typst`, `pandoc`).
- **Reason:** Brief explanation of why this repository needs the tool (e.g. "Use with Pandoc for PDF generation").
- **Install / hint:** Install command or package identifier (e.g. `winget install --id=Typst.Typst`, or a reference to an aitools manifest key). MAY be empty if unknown.
- **Status:** If empty or missing, the request is **pending**. If non-empty (e.g. `Done`, `Declined`), the request is considered **fulfilled or closed** for the purpose of automated processing.

3.1.4. Consumers MUST treat the first table with the header row above as the canonical table. Additional text (e.g. instructions, extra tables) in the file is OPTIONAL and MAY be ignored by automated consumers.

3.1.5. Repositories MAY add or remove rows and MAY update Status. The convention does not require a specific workflow for who updates the file (human or assistant).

### 3.2 Aitools side: consumption

3.2.1. All consumption happens via GitHub. Agents and humans interact with tool-requests files through the `gh` CLI or GitHub web interface -- never by reading local filesystem paths of other repositories.

3.2.2. Aitools MAY support consuming tool requests in one or more of the following ways:

- **GitHub issue:** An agent working in a repository creates an issue on `nobul-jose/aitools` with the tool name, reason, and install hint from the requests file. This is the simplest path and SHOULD be the default for agents.
- **Subcommand:** A command such as `aitools process-requests <owner/repo>` that (1) reads the tool-requests file from the GitHub repository via `gh api`, (2) parses the table per §3.1.2--3.1.4, (3) filters to rows with empty/missing Status, and (4) either prints a checklist or creates issues. Behavior is implementation-defined.
- **Manual review:** A human reads the file on GitHub and processes requests in an aitools session.

3.2.3. To read the tool-requests file from a remote repository:

```bash
gh api repos/<owner>/<repo>/contents/docs/aitools-requests.md \
  --jq '.content' | base64 -d
```

3.2.4. To create a tool request issue on aitools:

```bash
gh issue create --repo nobul-jose/aitools \
  --title "Tool request: <tool-name>" \
  --body "Requested by <owner>/<repo>. Reason: <reason>. Install hint: <hint>."
```

### 3.3 Versioning and compatibility

3.3.1. This RFC does not define a version field inside the tool-requests file. Future RFCs that change the table format or path SHOULD use a different filename to avoid breaking existing consumers.

3.3.2. New optional columns MAY be added to the table by repositories; consumers that do not understand them SHOULD ignore them.

---

## 4. Examples

### 4.1 Example tool-requests file

```markdown
# Tool requests for aitools

| Tool / Feature | Reason | Install / hint | Status |
|----------------|--------|----------------|--------|
| typst | Use with Pandoc for PDF generation. | winget install --id=Typst.Typst | |
| pandoc | Already present; listed for visibility. | (already in aitools) | Done |
```

### 4.2 Example: agent reads requests from a remote repo

```bash
# Read pending requests from another repo
gh api repos/nobul-jose/ess/contents/docs/aitools-requests.md \
  --jq '.content' | base64 -d

# Create an issue on aitools for a pending tool
gh issue create --repo nobul-jose/aitools \
  --title "Tool request: typst" \
  --body "Requested by nobul-jose/ess. Reason: Use with Pandoc for PDF generation."
```

### 4.3 Example: subcommand usage (informative)

```bash
aitools process-requests nobul-jose/ess
# Output (example):
# - [ ] typst: Use with Pandoc for PDF generation. | Install: winget install --id=Typst.Typst
```

---

## 5. Security and privacy considerations

- The tool-requests file is committed to version control and visible to anyone with repository access. It SHOULD contain only tool names, reasons, and install hints -- no secrets, tokens, or machine-specific paths.
- Agents creating issues on `nobul-jose/aitools` MUST NOT include credentials or sensitive information from the requesting repository.

---

## 6. References

- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) -- Key words for use in RFCs to Indicate Requirement Levels.

---

## 7. Changelog

| Date | Change |
|------|--------|
| 2026-02-28 | Initial proposal. |
| 2026-03-01 | Single file path (`docs/aitools-requests.md`). GitHub-centric consumption via `gh` CLI. Removed local filesystem references. Added issue creation as default agent path. |
