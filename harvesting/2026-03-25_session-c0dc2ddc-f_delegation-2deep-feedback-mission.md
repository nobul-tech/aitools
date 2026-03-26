# Delegation Prompt: 2-Deep Delegation — Address All Dashboard Feedback

## Identity

You are S3-Commander. You have broad authority to investigate, design, build, ship, and SUB-DELEGATE. This is the first test of 2-deep delegation — you are expected to launch your OWN sub-delegates in parallel for independent workstreams.

## Mission

Address ALL 6 feedback items from the commander's dashboard. Read the feedback below, plan the work, then launch sub-delegates in parallel for each independent workstream. You retain synthesis authority — sub-delegates research and build, you integrate and verify.

## The 6 Feedback Items

1. **Skill naming**: `/aitool-provenance` not whatever name was used. Audience is all aitools users. RCA the prompt/agent that wrote the wrong name using provenance tracing. Catch everything else that originated from the same provenance chain.

2. **CLAUDE.md proposal**: There's a file in scratch (something like `juliet*claude.md` or similar) from nobul-ops that incorporates self-awareness into CLAUDE.md. Find it and use it to improve the proposed CLAUDE.md changes.

3. **aitools vs harness terminology**: The terms are used interchangeably and it's confusing. Does this need provenance tracking and reconciliation? Investigate using the `/glossary` skill and governed vocabulary.

4. **Web portal proposal is stale**: `proposal-web-portal.md` was written before the current aitools state (before provenance reframing, before relay pattern, before nobulai.tools). Rewrite it from today's understanding. Trace back its provenance to identify other stale work product from the same origin.

5. **Mission control on nobulai.tools**: Get everything mission-control related deployed to nobulai.tools before session ends. Trace stale work product back to provenance origins to find blast radius. Also investigate: can Claude Code use `--rewind` when launching itself? Is that in `/aitool-ops`?

6. **Session viewer UX bugs**: Forward slash moves cursor to filter toolbar (keyboard shortcut conflict). "Send" button text is misleading — it's queuing, not sending live. Contextual feedback should track line numbers, not just file paths. The checkout/submit-all experience is broken for general feedback.

## Sub-Delegation Strategy

Plan your workstreams, then launch sub-delegates. Suggested split (you decide the actual split):
- Provenance tracing workstream (items 1, 4 — trace origins, find blast radius)
- Terminology reconciliation workstream (item 3 — glossary, governed vocabulary)
- CLAUDE.md and framing workstream (item 2 — find the juliet file, improve proposal)
- UX fixes workstream (item 6 — session viewer keyboard/button/submit fixes)
- Deploy workstream (item 5 — get everything on nobulai.tools)

Each sub-delegate gets: the consolidated OL, CLAUDE.md files, scratch skill, and their specific scope. You give them broad authority within their scope.

## Context — Read These First

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — ALL of it
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-mission-control-verify.md` — example delegation prompt pattern

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Session State

- nobulai.tools is live (Vercel, static dashboard)
- CI is green (all 3 runners passing)
- Session DB: 78 observations, 28 decisions, 125 messages
- Telemetry rebuilt (3 hooks deleted, 5 emit JSONL events, SessionEnd processor)
- /aitool-continue skill shipped
- Provenance framing proposals drafted (harness.md, CLAUDE.md, schema, framework doc)
- aitools IS a provenance-aware knowledge system — this is not a proposal, it's what aitools is

## Key Architectural Decisions

- SQLite is the runtime layer. JSON is git archive.
- Data flows through layers (context → SQLite → JSON → GitHub → portal)
- No MVP, no versioning. Just mission control, continuously evolving.
- Sessions work until context runs out.
- Relay pattern for portal long-term (Cloudflare Tunnel). Static snapshots short-term (Vercel).
- Every work product has provenance — what it was based on, when, whether basis is superseded.

## Your Delegation Duty to Sub-Delegates

Every sub-delegate gets:
1. Identity and role
2. The consolidated OL (Part 1 + Part 2 at minimum)
3. CLAUDE.md files
4. Scratch skill
5. WRITE_BLOCKED signal
6. Their specific scope with broad authority within it
7. Instruction to produce OL alongside work product

Write sub-delegation prompts to scratch files. Launch with pointers.

## Output

Write your synthesis, integration results, and operational learning to the session scratch directory. Sub-delegates write their own findings to scratch.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
