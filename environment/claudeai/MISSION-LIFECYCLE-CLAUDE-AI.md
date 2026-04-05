# aitools Mission Lifecycle — Claude.ai
#
# [PROVENANCE]
# document: MISSION-LIFECYCLE-CLAUDE-AI
# version: 1.0.0
# created: 2026-04-05T17:20Z
# license: MIT — NOBUL (https://nobul.tech)
# platform: claude.ai
#
# [AGENT]
# name: Agent Replacement
# session: ff4220d3-9563-4a2e-8fb2-443136c33f8d
#
# [INTENT]
# purpose: Define how missions run on claude.ai — pre-launch, during,
#   post-mission, and terminal handoff. The operational protocol.
# scope: Mission lifecycle only. NOT who you are or where to look
#   (see MISSION-COMMAND-CLAUDE-AI). NOT governance (see GOVERNANCE.md).
#   NOT tool architecture.
# audience: Any claude.ai agent executing an aitools mission.

---

## PRE-MISSION

Before any mission launches, all of these happen:

### 1. Clone and Read

Clone both repos. Read key files. This is how to find answers.

```
git clone https://github.com/nobul-tech/aitools.git
git clone https://github.com/nobul-jose/aitools.git
```

Read: DECISIONS.md, GOVERNANCE.md, standing orders, relay docs,
CLAUDE.md, reference/harness.md, reference/glossary.json.

### 2. Three-Perspective Exchange

Agent produces two artifacts through file pipeline:
- **Session export** — conversation as agent sees it
- **Running estimate JSONL** — structured intelligence to this point

Commander provides:
- **claude-session-export** or screen capture — session as Commander sees it

Three views compared on sovereign ground. Differences are findings.
The mission launches from verified shared understanding.

### 3. Verify Informing Artifacts

Cross-check repo hashes against hashes in uploaded relay and
session artifacts. Three paths through Anthropic infrastructure.
Matching hashes don't prove integrity but inconsistent hashes
prove tampering.

Print sovereign verification commands for Commander (individual
shasum per artifact, absolute paths, PASS/FAIL pattern).

### 4. Confirm Artifact List (D-014)

State the expected artifacts. The Commander confirms before
execution begins.

### 5. Running Estimate (D-015)

State the situation, knowns, unknowns, risks, plan. This becomes
a running_estimate entry in the JSONL.

### 6. Launch

Execute.

---

## DURING MISSION

### Agent Duty

- Surfacing Duty — if you see it, surface it (D-013)
- Pre-run disclosure before any command (D-016)
- One command per block with description (D-017)
- Hash once after ALL edits — never before, never per file
- Verify hashes yourself before presenting
- Present ALL artifacts together, once (D-019)
- Never assume what's on Commander's machine
- Never instruct deletion
- Never overwrite relay/governance docs — accumulate with
  suffixes (D-020)

### Running Estimate Updates

Append running_estimate entries to the JSONL as the mission
progresses. State changes, new findings, new decisions — all
go in as they happen. The JSONL is the living session state.

---

## POST-MISSION

After every mission (not just at session end):

### 1. Export Through File Pipeline

Two artifacts immediately:
- **Running estimate JSONL** — full cumulative session state
  including this mission's start, execution, and end
- **Session export** — full conversation as agent sees it

Both go through the file pipeline. Both hashed. Commander
downloads and verifies.

If the context window dies after this point, the Commander
has everything up to this export. Nothing lost.

### 2. Mission End Record

Append to running estimate JSONL:
```jsonl
{"type":"mission_end","mission":"M-001","status":"complete","artifacts_produced":[...],"custodians":{...}}
{"type":"mission_aar","mission":"M-001","what_went_right":"...","what_went_wrong":"...","what_was_learned":"..."}
```

### 3. Provenance

Every artifact tracks informed_by — which decisions, findings,
and OL entries formed the basis. airelay on sovereign ground
can slice the running estimate to produce the mission-specific
briefing (pre) and AAR (post) from the full record.

---

## TERMINAL HANDOFF

At the end of the session or the final mission:

### Re-present ALL Artifacts (D-019)

Present every artifact from the session. Not just the current
mission — everything. File sidebar items may have fallen off
in long sessions.

### Print All 7 Commander Steps

One block per step. Pre-run disclosure per D-016. One command
per block per D-017.

**Step 1 — Verify checksums.**
Individual shasum per artifact. Absolute paths. PASS/FAIL
pattern — the code compares, the Commander reads the result.
No for loops. No cd. No relative paths.

**Step 2 — Read provenance.**
One block, grep headers from all artifacts.

**Step 3 — Download.**
From the file sidebar.

**Step 4 — Review for malicious code.**
Commander reads every artifact.

**Step 5 — Deploy to ~/.local/bin.**
Individual cp commands. Absolute paths. Source from ~/Downloads,
destination to ~/.local/bin. Drop extension. Then chmod +x.
Pre-run disclosure: "This copies X, removes the extension,
makes it executable."

**Step 6 — Run/test.**
Individual blocks per tool. Description of expected output
BEFORE the Commander runs it. D-016 in action.

**Step 7 — Commit and push.**
Separate blocks: tools with clean names, governance with clean
names, relay with suffixed names. Then git add + status. Then
git commit with full hash manifest. Then git push. Each separate.

### Session-Level Artifacts

Every session produces:
- Running estimate JSONL (source of truth)
- Session AAR (in the running estimate, airelay renders MD)
- Relay (comprehensive intelligence, airelay renders from JSONL)
- Session export (conversation as agent sees it)

All go through file pipeline. All hashed. All verified sovereign.

---

## JSONL IS SOURCE OF TRUTH

On claude.ai, the running estimate JSONL is the canonical
record. airelay on sovereign ground renders human-readable MD.
One source, one tool, no drift.

On Claude Code/mac/windows/linux, sqlite3 is the operational
store. JSONL is the transport format at machine boundaries.

Both patterns serve the same purpose: structured intelligence
that accumulates, travels, and can be queried.

---

## WHAT THE COMMANDER EXPECTS

Honesty. Reduce friction. Don't compromise the mission. Don't
assume. Don't ask questions you can answer yourself from the
repos. Take disciplined initiative within the Auftrag. Get
intelligence onto sovereign ground before building. The
intelligence is perishable, the build is not.

---

Don't put a period on this. Everything is a comma.
