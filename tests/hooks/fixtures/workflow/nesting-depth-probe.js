export const meta = {
  name: 'nesting-depth-probe',
  description: 'Probe how deep delegation can nest when the first delegate is a workflow agent',
  phases: [{ title: 'Probe', detail: 'one workflow agent that tries to delegate 3 levels deep' }],
}

const PROBE = `You are Probe-L1, a nesting-depth probe launched as a WORKFLOW agent by Session Commander 10cf255a-c (aitools repo, Claude Code on macOS). Read-only: do not edit, write, commit or push anything.

Do exactly this:
1. Report your level (L1) and the full list of tool names available to you right now. Say explicitly whether you have: Agent, Workflow, ToolSearch, SendMessage. If you have ToolSearch, run it with query "select:Agent,Workflow" and say what it returns.
2. Run this Bash command and report the output: printenv CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH
3. If you have an Agent tool, launch ONE delegate with it, giving it this same prompt with every "L1" replaced by the next level number (L2, then L3, then L4) and "WORKFLOW agent" replaced by "Agent-tool delegate". If you have no Agent tool but have Workflow, launch a one-agent workflow with the same instruction and say you used Workflow. Stop recursing at L4. If a launch fails, quote the exact error text.
4. Return JSON only: {"chain":[{"level":"L1","launchedVia":"workflow","tools":[...],"hasAgent":bool,"hasWorkflow":bool,"depthEnv":"...","launchError":null|"exact text"}, ...entries returned by your delegate appended in order]}.

ultracode`

phase('Probe')
const r = await agent(PROBE, { label: 'Probe-L1 (workflow)', phase: 'Probe', agentType: 'general-purpose', effort: 'low' })
return r
