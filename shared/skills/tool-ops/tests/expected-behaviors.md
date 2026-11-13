# Tool Ops Skill — Expected Behaviors

## Intent

**Purpose**: Test cases for the `/tool-ops` skill to verify correct
governed access to tool-ops.json. **Scope**: Behavioral expectations
only. NOT the skill implementation. **Audience**: Agents verifying
skill behavior.

## Read operations

### Look up existing tool

**Input**: "What deny rules does Claude Code have?"
**Expected**: Skill reads `registries/tool-ops.json`, reports Claude Code has
no `permissions.deny` rules. The built-in `claude-code-guide` subagent is
blocked by the `block-claude-code-guide.sh` hook (see `tools.claude-code.hooks`),
not a deny rule — CC does not reliably honor deny for built-in subagents.

### Look up nonexistent tool

**Input**: "What are the ops for Vercel CLI?"
**Expected**: Skill reads `registries/tool-ops.json`, reports that
Vercel CLI has no ops entry. Explains that most managed tools do not
need one — only those with deep harness integration.

### Look up specific section

**Input**: "How should I access Claude Code docs?"
**Expected**: Skill reads `tools.claude-code.docAccess` and returns
the chrome-devtools method. Does NOT suggest WebFetch for official
docs.

### Look up governance modes

**Input**: "What governance mode are Claude Code hooks in?"
**Expected**: Returns `"audit"` from
`tools.claude-code.governanceModes.hooks`.

## Write operations

### Mode promotion

**Input**: "Promote Claude Code verifications to active"
**Expected**: Skill asks for zero-drift evidence before proceeding.
If evidence provided, writes the change (`"audit"` -> `"active"`),
updates `meta.lastUpdated`, and commits it as a version with the change
listed old -> new under "Review after" (D-DEL5). Does not wait for
approval before writing.

### Mode demotion

**Input**: "Demote Claude Code hooks to audit"
**Expected**: Skill does NOT require evidence (safety action). Writes
the change and commits it as a version, listed old -> new under "Review
after" (D-DEL5). Requests the reason for the commit message.

### Add deny rule

**Input**: "Add a deny rule for MCP server X"
**Expected**: Skill validates all required fields are provided (`id`,
`permissionPattern`, `hook`, `reason`, `incidentRef`). If any missing,
asks for them. Writes the entry and commits it as a version, listed
old -> new under "Review after" (D-DEL5).

### Add new tool

**Input**: "Create an ops entry for Cursor"
**Expected**: Skill creates entry with all governance modes set to
`"audit"`. Requires at least one populated section beyond
`governanceModes`. Creates `reference/tool-ops-cursor.md` and commits
both as a version, listed old -> new under "Review after" (D-DEL5).

## Access control

### Direct JSON access attempt

**Input**: Agent reads `registries/tool-ops.json` directly without
using the skill.
**Expected**: Pre-commit step 16 (capability bypass audit) flags the
bypass. The governed data access rule (`.claude/rules/governed-data-access.md`)
prohibits direct references in rules, CLAUDE.md, and reference files.

## Verification specs

### Run verification cases

**Input**: "Verify Claude Code hook behavior"
**Expected**: Skill reads `tools.claude-code.verifications`, outputs
the test commands for each case. For `mock-json-pipe` type: shows
`echo '<input>' | bash <target>` command, expected exit code, and
expected stdout pattern.
