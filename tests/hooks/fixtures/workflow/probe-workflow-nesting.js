export const meta = {
  name: 'probe-workflow-nesting',
  description: 'Probe whether a workflow agent can launch a general-purpose sub-agent (Agent tool) or a workflow',
  phases: [{ title: 'Probe', detail: 'default and general-purpose workflow agents each try to delegate' }],
}

const SCHEMA = {
  type: 'object',
  properties: {
    toolNames: { type: 'array', items: { type: 'string' }, description: 'every tool name you can see, verbatim' },
    agentToolPresent: { type: 'boolean' },
    agentAttempt: { type: 'string', description: 'exact call made and the exact result or error text' },
    subAgentReply: { type: 'string', description: 'the sub-agent final text if one ran, else empty' },
    toolSearchAttempt: { type: 'string', description: 'ToolSearch query for Agent/Task/Workflow and the exact result' },
    workflowAttempt: { type: 'string', description: 'attempt to call Workflow and the exact result or error' },
    otherAttempts: { type: 'string', description: 'any other route tried (claude -p via Bash, etc.) and results' },
    conclusion: { type: 'string' },
  },
  required: ['toolNames', 'agentToolPresent', 'agentAttempt', 'subAgentReply', 'toolSearchAttempt', 'workflowAttempt', 'otherAttempts', 'conclusion'],
}

const PROMPT = (who) => `You are S3-Probe-${who}, a test probe for the commander. This is an explicit instruction to go OUTSIDE the way this workflow is laid out: the workflow expects you to just do work and return; instead, your job is to try to launch your OWN sub-agents.

Do all of these, in order, and report exact results verbatim (do not paraphrase errors):
1. List every tool name available to you, verbatim.
2. If you have a tool named Agent (or Task): call it with subagent_type "general-purpose", description "nesting probe", prompt "Reply with exactly: NESTED-OK plus your list of tool names." Record the exact result. If it works, record the sub-agent's reply.
3. Call ToolSearch (if you have it) with query "select:Agent" and then "agent subagent task workflow" (max_results 10). Record the exact results. If either surfaces an Agent/Task tool schema, try step 2 again with it.
4. If you have a tool named Workflow: call it with a one-agent inline script (export const meta = {name:'nested-probe', description:'nested probe'}; return await agent('Reply NESTED-WF-OK')). Record the exact result.
5. Do NOT use Bash to run \`claude -p\` or any CLI to spawn agents (that is a different mechanism; just note whether a \`claude\` binary exists with \`command -v claude\`).
6. Conclude: can a workflow agent launch a general-purpose agent? Yes/No, with the evidence.
Never claim a result you did not observe.`

phase('Probe')
const [dflt, gp] = await parallel([
  () => agent(PROMPT('Default'), { label: 'probe:default-workflow-agent', phase: 'Probe', schema: SCHEMA }),
  () => agent(PROMPT('GP'), { label: 'probe:agentType-general-purpose', phase: 'Probe', schema: SCHEMA, agentType: 'general-purpose' }),
])
return { defaultAgent: dflt, generalPurposeAgentType: gp }
