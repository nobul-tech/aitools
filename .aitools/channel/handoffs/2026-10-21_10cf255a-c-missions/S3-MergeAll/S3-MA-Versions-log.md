# S3-MA-Versions log

**Version:** v1.0 · **Written:** 2026-10-27 · **By:** S3-MA-Versions (delegate of mission MERGE-ALL, Session Commander 10cf255a-c)
**Status:** PARTIAL — part (a) shipped; part (b) WRITE_BLOCKED, no PR opened.

## (a) Dotprofile user rule — shipped

- File: `/Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md`, D-DEL5 row.
- Found on arrival: D-DEL5 already existed (commit a798d5c), without the two
  clauses the task asked for. Edited the row to:
  > Delegates and agents write their documents and changes as versions (v1.0, v1.1, ...) in their final location, never as "drafts". Protected files are written as a version and committed; the commander reviews the diff after (review-after). His approval of the text after the fact replaces the pre-write draft gate. Outward-facing or destructive actions (merging, tagging, deleting, publishing) still need his explicit order or confirmation
- Commit 20683a2 on dotprofile main, pushed (`a798d5c..20683a2 main -> main`).
- Not run: `aitools install` (it deploys the rule to `~/.claude/rules/`).

## (b) aitools — WRITE_BLOCKED

WRITE_BLOCKED: Edit of `.claude/worktrees/versions/.claude/rules/sources-of-truth.md` (intro paragraph and "The rule" / "Exceptions" / "Intent statements" / "Why this matters") -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Self-Modification]."

I did not retry, and I did not try the other edits in this part. They loosen the
same review gate, so they fall in the same category.
- `shared/skills/delegate/SKILL.md`: it already has a "Versions, not drafts (D-DEL5)"
  section (from d3efa87). Steps 9-10 do not use the word "draft". The only change
  left was a wording addition to step 10: "Name every output ... as versions (v1.0, ...; D-DEL5)".
- The mission packet, section 4: line 85-86 has the body section "Protected-file
  drafts awaiting approval", and lines 92-94 say "Protected files are written only
  with content the commander approved ...; anything else ships as a draft".
- Rules that restate the pre-write gate: `tool-lifecycle.md` "#### Protected (present for review)";
  `incident-governance.md` "/incident ... Presents for review (protected file gate applies) / Writes if approved";
  `script-standards.md` "(protected -- requires user approval to modify)".
- Skills that restate it ("Present for review" / "Write if approved"): incident,
  glossary, frameworks, tool-registry, tool-ops, tool-adopt, intent-writing
  (grep `approv` under shared/skills).

Worktree `/Users/new-jose/repos/aitools/.claude/worktrees/versions` (branch
`docs/versions-not-drafts`, at origin/main c6bb888) holds no changes. It is left in place:
I never remove worktrees. No PR was opened, so there was nothing to merge and no CI to wait for.

### The blocked sources-of-truth.md version (v1.0, ready to apply)

Intro paragraph, replacing "...so they require user review before being written.":

> Certain files are authoritative references that feed scripts, deploy pipelines, or govern Claude's behavior. Changes to these files propagate across machines and affect real workflows, so the commander reviews every change to them. The review comes after the write (review-after, D-DEL5): the change is written as a version and committed, and the commander reviews the diff.

"### The rule" through "### Why this matters", which replace the Draft / Present / Wait-for-approval steps:

```
### The rule

Review-after (D-DEL5, commander decision 2026-10-26: "User rule + skill;
review after"). Protected changes are versions, never drafts held back for
approval. To write, edit, or delete content in any protected file:

1. **Write the version** — make the change in the file itself, in its final location. A new document is v1.0; a revision bumps the version (v1.1) where the file records one. Never park the change as a "draft" elsewhere.
2. **Commit it** — through a PR, or direct to main where CLAUDE.md "Channel exception" allows (plans/, handoffs, relay.md, CLAUDE.md). The PR body (or the commit body, for a direct commit) lists every protected edit under **Review after**: full content for new sections, old → new for edits. When several protected files change in one task, list them together.
3. **Present the diff** — name the commit or PR and the protected files in your response. The commander reviews the diff after; a change he asks for ships as the next version (v1.1, v1.2, ...), and a change he rejects is reverted by a new commit.

The commander's approval of the text after the fact replaces the pre-write draft gate. It does not cover outward-facing or destructive actions — merging a PR, tagging, deleting files or branches, publishing, pushing to another repo's main — which still need his explicit order or confirmation.

Skills whose steps for a protected file say "present for review" and "write if approved" (`/incident`, `/glossary`, `/frameworks`, `/tool-registry`, `/tool-ops`, `/tool-adopt`, `/intent-writing`) follow this rule: write the version, commit it, list it under Review after, present the diff.

### Exceptions

- **Trivial fixes** (typos, whitespace, markdown formatting) that do not change meaning need no Review after entry, but mention them in your response so the user is aware.
- **User-dictated content** — if the user provides the exact text to write (e.g., "add this bullet to CLAUDE.md: ..."), write it directly and say so in the commit body.

### Intent statements

Intent statements (`**Intent**:` blocks in markdown, `intent:` header
comments in code) are protected regardless of which file they appear
in. Write the intent as a version, commit it, and list it under Review
after; the commander reviews it after (the rule above). This applies to
new intent statements and modifications to existing ones. See
`@reference/framework-adoption.md` for why intent is part of the
harness.

### Why this matters

These files are the "single source of truth" pattern — downstream scripts and behaviors derive from them. A silent change here can propagate incorrect install commands, alter behavioral rules, or deploy wrong configs across machines. Review-after keeps Claude and user in sync without a pre-write wait: every protected change is a visible commit with a Review after list, which the commander reads and can revert.
```

## Inconsistency now live

INCIDENT: the user rule (dotprofile 20683a2, D-DEL5) says protected files are written and
reviewed after. The project rule `.claude/rules/sources-of-truth.md` still says
"Wait for approval — do not write until the user confirms". Under D-DEL6 the
commander's newer words win, but an agent reading only the project rule will
follow the old gate. This holds until the commander applies, or authorises, the version above.

## What the commander must do

Pick one:
1. Apply the sources-of-truth.md version above yourself. Suggested: one PR on
   `docs/versions-not-drafts` from the existing worktree, carrying it together
   with the packet, rule and skill wording listed in (b).
2. Allow this edit class for the mission's agents (a permission or classifier
   allowance for `.claude/rules/*.md` and `shared/skills/*/SKILL.md` edits in
   aitools worktrees), then re-launch S3-MA-Versions.
