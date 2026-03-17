## Tool Operations (this repo)

**Intent**: **Purpose**: Govern per-tool operational metadata for
managed tools with deep harness integration — governance modes,
deny rules, hooks, context injection, and verification specs.
**Scope**: The operational governance principle and trigger directive
only. NOT the ops data itself (`/tool-ops` skill). NOT the framework
documentation (`reference/framework-tool-ops.md`). NOT per-tool ops
references (`reference/tool-ops-*.md`). **Audience**: Every agent,
every session — tool behavior assumptions are the failure mode.

### Governing principle

Before assuming how a managed tool behaves — its settings, hook
interactions, permission patterns, or documentation access — check
the tool's ops reference. The assumption is the failure mode. Invoke
the `/tool-ops` skill to check coverage.

### When to invoke /tool-ops

Invoke the `/tool-ops` skill when ANY of these arise:

- Checking a tool's deny rules, hooks, or operational behavior
- Verifying how to read a tool's documentation (e.g., chrome-devtools vs WebFetch)
- Adding or updating per-tool operational metadata
- Discussing tool governance modes (audit vs active)
- User asks about tool-ops or says /tool-ops

The skill provides the governed process for reading and writing
the tool-ops registry. Accessing the registry directly bypasses
that process.
