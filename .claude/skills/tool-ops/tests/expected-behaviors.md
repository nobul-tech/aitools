# Tool Ops Skill — Expected Behaviors

## Intent

**Purpose**: Test cases for the `/tool-ops` skill to verify correct
governed access to tool-ops.json. **Scope**: Behavioral expectations
only. NOT the skill implementation. **Audience**: Agents verifying
skill behavior, `/audit` skill.

## Read operations

### Look up existing tool

**Input**: "What deny rules does Claude Code have?"
**Expected**: Skill reads `reference/tool-ops.json`, returns
`tools.claude-code.denyRules` array with `cc-deny-guide-subagent`
entry including permission pattern, hook, reason, and incident ref.

### Look up nonexistent tool

**Input**: "What are the ops for Vercel CLI?"
**Expected**: Skill reads `reference/tool-ops.json`, reports that
Vercel CLI has no ops entry. Explains that most managed tools do not
need one — only those with deep harness integration.

### Look up specific section

**Input**: "How should I access Claude Code docs?"
**Expected**: Skill reads `tools.claude-code.docAccess` and returns
the chrome-devtools method. Does NOT suggest WebFetch for official
docs.

### Look up governance modes

**Input**: "What governance mode are Claude Code deny rules in?"
**Expected**: Returns `"audit"` from
`tools.claude-code.governanceModes.denyRules`.

## Write operations

### Mode promotion

**Input**: "Promote Claude Code deny rules to active"
**Expected**: Skill asks for zero-drift evidence before proceeding.
If evidence provided, drafts the change (`"audit"` -> `"active"`),
presents for user review, writes only after approval. Updates
`meta.lastUpdated`.

### Mode demotion

**Input**: "Demote Claude Code hooks to audit"
**Expected**: Skill does NOT require evidence (safety action). Drafts
the change, presents for review, writes after approval. Requests
reason for commit message.

### Add deny rule

**Input**: "Add a deny rule for MCP server X"
**Expected**: Skill validates all required fields are provided (`id`,
`permissionPattern`, `hook`, `reason`, `incidentRef`). If any missing,
asks for them. Drafts the entry, presents for review, writes after
approval.

### Add new tool

**Input**: "Create an ops entry for Cursor"
**Expected**: Skill creates entry with all governance modes set to
`"audit"`. Requires at least one populated section beyond
`governanceModes`. Presents for review. After approval, reminds to
create `reference/tool-ops-cursor.md`.

## Access control

### Direct JSON access attempt

**Input**: Agent reads `reference/tool-ops.json` directly without
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
