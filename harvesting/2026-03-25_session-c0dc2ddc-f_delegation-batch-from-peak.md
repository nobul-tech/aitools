# Peak-Context Mission Batch

These missions are launched from the highest-context point in this session (~850K tokens, 16+ hours of accumulated understanding, all corrections internalized, provenance framing active, rewind capability understood). Each carries the deep understanding into persistent work product.

## Mission 1: Build Knowledge Query System
Build `~/.aitools/knowledge.db` with FTS5. Scanner ingests work product from aitools, nobul-ops, marse, dotprofile sessions. CLI: `aitools knowledge search "..."`. Python API for agents. Use sqlite-utils. Reuse scanner patterns from build-ol-index-v2.py. This is the stop gap for querying knowledge work NOW.

## Mission 2: Build /aitool-continue Skill
Note: the future timeline shipped this in v0.67.0. Read what was shipped (check git log and the scratch files). Evaluate whether it captures everything from this session's understanding. If not, improve it. The skill should make the agent self-aware of aitools — operational learning, understanding of subagents, delegation patterns, provenance, rewind capability. It's what loads at session start or after rewind.

## Mission 3: Implement Provenance Tables
Add knowledge_items, provenance_edges, and nogood_sets tables to harness-db-schema.sql and harness-db.py. Based on the provenance investigation findings. Every observation, decision, and work product should be linkable to its basis. When a basis is falsified, downstream items are flaggable.

## Mission 4: Build Credits Tracking Tool v2
Upgrade credits.nobul.tech from AWS-only to multi-provider. The design exists in credits-tool-design.md. 16 programs inventoried. This is real — Cloudflare was just applied for, Datadog is active, Auth0 and Okta are active. The tool tracks them all.

## Mission 5: Deploy Updated Mission Control
Re-export session DB (now has 90+ messages, 16 decisions, 43+ observations including rewind OL) and redeploy to Vercel. The dashboard should reflect the current state including everything the future shipped.
