# Operational Learning: Tool-Ops Verify Mission (Session 8236ca9c)

**Mission Commander**: tool-ops-verify (executed by assessment-lead)
**Date**: 2026-03-26

## OL Items

OL-TV1: All 12 deployed hooks have zero drift from source. The deployment pipeline (setup-user-hooks.sh) correctly deploys existing hooks. The gap is exclusively in REGISTERING new hooks -- the pipeline copies files but does not add settings.json entries for Stop hooks.

OL-TV2: tool-ops.json is severely incomplete. It documents 1 deny rule and 1 hook for claude-code, but the actual deployed state has 3 deny rules and 12 hooks (plus 3 unregistered). The registry was last updated 2026-03-15 and has not kept pace with hook development. This means governance mode audits based on tool-ops.json are working with incomplete data.

OL-TV3: The mock-json-pipe verification pattern defined in tool-ops.json works correctly for block-claude-code-guide.sh. Both test cases pass. This pattern could be extended to all PreToolUse hooks for automated verification.

OL-TV4: harness.db reports "attempt to write a readonly database" during status checks. Despite this error, the database contains valid data (4 sessions, 30 KPI events). The error may be a WAL checkpoint issue or file permissions. This needs investigation before relying on harness.db for production queries.

OL-TV5: The JSONL events pipeline works correctly -- hooks write to events.jsonl, format is valid, timestamps are UTC. The session DB events table is unused. The design appears to be JSONL-first with batch import at session end, but the import step may not be executing. The pipeline is half-built.

OL-TV6: OL-47 confirmed via mock testing. The standing-order-guard.sh code enforces ||, ;, and backticks (promoted 2026-03-24) but the hook-rollout.md rule still documents them as observe. Agents reading the rule will have incorrect expectations about hook behavior. This is a protected file that needs updating.

OL-TV7: The block-claude-code-guide.sh deny response includes rich corrective context (chrome-devtools alternatives, hook type schemas, incident reference). This is a good pattern -- deny decisions that teach rather than just block. Could be a model for future deny hooks.
