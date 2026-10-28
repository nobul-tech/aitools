export const meta = {
  name: 'missions-gate-ledger-path32-hooks',
  description: 'Run missions GATE, LEDGER, DEPLOY-PATH and HOOKS in parallel; each commander ships its own PR; each PR is independently reviewed',
  phases: [
    { title: 'Missions', detail: 'one mission commander per mission, worktree-isolated, ships its own PR(s)' },
    { title: 'Review', detail: 'independent read-only reviewer per mission PR' },
  ],
}

const REPO = '/Users/new-jose/repos/aitools'
const OUT = '.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions'
const PRIOR = REPO + '/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions'

const RULE_FILES = ['agentic-standards','aitool-eval','aitool-ops','aitools-workspace','artifact-harvesting','config-file-safety','cross-platform','deploy-paths','documentation-standards','frameworks','git-safety','glossary','governed-data-access','hook-rollout','incident-governance','interactive-menus','managed-file-deployment','plan-execution','relay-outbound','script-standards','smoke-test-pattern','sources-of-truth','tool-evaluation','tool-lifecycle','tool-ops','web-sources']
  .map(n => '  - ' + REPO + '/.claude/rules/' + n + '.md').join('\n')

const PACKET = `
## Rules (delegation duty element 2)
Before other work, read in full every project-scope and user-scope rule below that is not already in your context:
- Project: ${REPO}/CLAUDE.md and each of:
${RULE_FILES}
- User: /Users/new-jose/.claude/CLAUDE.md, /Users/new-jose/.claude/rules/concurrent-agents.md, /Users/new-jose/.claude/rules/delegation.md
- Error-handling block for any code you write: ${REPO}/reference/plan-execution-detail.md
- The handoff that defines these missions: ${REPO}/.aitools/channel/handoffs/2026-10-21_360aa8f3-8.md (read in full)

Critical rules restated:
- USO Simple Bash: never use $(...), backticks, &&, ||, ; or globs in rm inside Bash tool calls. Use separate Bash calls. Commit messages go in a scratch file and are committed with git commit -F. Pipelines (|) are OK.
- USO Dedicated tools: Read/Edit/Write/Grep/Glob for file ops. Perl, not sed/awk, for non-trivial string work. The standing-order-guard hook blocks cat/head/tail/sed/awk outside a pipeline, even read-only sed -n (incident #82): use Read.
- USO No silent failures in reusable code (script-standards.md error-handling table).
- Protected files (.claude/rules/sources-of-truth.md table: registries/*.json, .claude/rules/*.md, CLAUDE.md, reference/* listed there, intent statements anywhere, ROADMAP.md, plans/*.md) are NEVER written before the commander approves the exact content. Put drafts under your mission folder instead (that folder is not protected).
- Cross-platform: every .sh change gets its .ps1 pair (and vice versa), identical menu options/order; bash -n and the pwsh parser check (cross-platform.md "Pre-validation convention") on every touched script. pwsh is at /opt/homebrew/bin/pwsh.
- Never run scripts/build-deploy.sh, or any check that calls it, without an isolated HOME (HOME=<fresh dir under your worktree .aitools/scratch/>). It rm -rf's and rebuilds the real dotprofile deploy/ (#86).
- Never run aitools, aitools install, or setup-user-* against the real HOME.

## Skills
Read and follow the delegation skill (not yet deployed, read it from this path, read-only): ${REPO}/shared/skills/delegate/SKILL.md. It is the version on branch docs/delegate-read-all-rules (PR #54). Other skills: /incident, /glossary, /intent-writing, /scratch as your mission needs; if a skill will not load, read its SKILL.md (project skills: ${REPO}/.claude/skills/<name>/SKILL.md; user skills: ${REPO}/shared/skills/<name>/SKILL.md) and follow it by hand. The /incident skill points at the dead path reference/incidents.json; the registry is registries/incidents.json (#84).

## Operational learning (carry forward; source in parentheses)
- You run in a git worktree created from origin/main. You cannot Write outside it (incident #83). Write every output inside your worktree. Read-only absolute paths into ${REPO} work.
- Subagents do not inherit the delegating agent's conversation; put everything in the prompt (delegation.md governing principle).
- Background delegates can be denied writes: use WRITE_BLOCKED (delegation.md element 5).
- Nesting cap: CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH default 3. You are at depth 2 or less; your delegates may be unable to delegate further. Give each delegate a whole task (delegate SKILL.md "Environment limits").
- Claude Code refuses subagent writes of *.md files whose name starts with REPORT/SUMMARY/FINDINGS/ANALYSIS; the D-DEL1 prefix avoids it (delegate SKILL.md).
- Nested .claude/ hazard: never create a .claude/ folder inside your mission output; name draft folders dot-claude/ (handoff section I).
- Session restarts kill running delegates (that is how S4-Review A/B were lost). Commit and push your outputs early and often.
- registries/incidents.json is ~2,027 lines, over Read's 2,000-line default. Read it fully with offset/limit before choosing an id; 86 ids exist, next is #87 (handoff F8).
- check-pre-push step 7 currently FAILS on every setup-script change: it expects aitools/deploy/ but the build target moved to the dotprofile (issue #32, being fixed by mission DEPLOY-PATH in parallel). Record that failure as known (#32) in your PR body; it is not a blocker for you.
- main has ruleset 16468370: PRs need 1 approval; no direct pushes (handoff C.1).
- Firecrawl credits are exhausted; use chrome-devtools for docs that feed protected files (handoff I).
- The Grep tool is sometimes not provisioned to delegates; bash grep in a pipeline is allowed (handoff G17).
- Mission drafts from session 360aa8f3-8 are at ${PRIOR}/ (read-only provenance; draft folders named dot-claude/ mean .claude/). Do not write into that folder.

## WRITE_BLOCKED
If any write or tool call is denied by a permission check or hook, do not retry it in another form. Record WRITE_BLOCKED: <what> -- <exact denial text>, put the content in your response, and continue.

## Name prefix (D-DEL1)
Every *.md file you create starts with your name plus a hyphen (given in your identity below). A draft that mirrors a repo path keeps the repo file name inside a folder that starts with your prefix (e.g. <PREFIX>-drafts/reference/x.md).

## Shipping (D-DEL4)
You ship your own PR(s): work on the branch named below (create it from origin/main in your worktree with git switch -c), commit with git commit -F, run the pre-push checks that apply (bash ${'<worktree>'}/scripts/check-pre-commit.sh and check-pre-push.sh; inspect each for build-deploy calls first and isolate HOME if so; record anything not run and why), git push -u origin <branch>, then gh pr create -R nobul-tech/aitools --base main --head <branch> --body-file <file>. PR body: summary, commits, verification results, anything not run, and the line "🤖 Generated with [Claude Code](https://claude.com/claude-code)". Commit messages end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Return every PR URL. Never push to main, never force-push, never merge or approve your own PR, never tag. Protected-file content ships only as drafts in your mission folder unless the commander approved it. A denied push or PR is WRITE_BLOCKED.

## Recursion (you are a mission commander)
You bear the delegation duty toward your own delegates. Use the delegate skill above. Every delegation prompt you write must carry, verbatim, everything in this packet (rules list, critical rules, skills, operational learning, WRITE_BLOCKED, D-DEL1, D-DEL4 shipping, and this recursion clause) plus the learning your mission adds. Name delegates <your name>-<role> with prefix <your name>-<role>-. Delegates inside your mission must not open separate PRs unless you assign them a branch; prefer that you integrate their output into your branch. If the Agent tool is not available to you, do the work yourself and say so in your result. Verify what each delegate returns (delegate SKILL.md "Verifying what comes back") before relying on it.

## Final response
Start with a 5-line summary. Then: PR URLs, branch, files changed, verification results, anything not run, WRITE_BLOCKED lines, INCIDENT: markers (do not file them, the session commander triages), open questions for the commander (each with a suggested answer). Cite a source for every factual claim; say "unknown" rather than guess.
`

const MISSIONS = [
  {
    key: 'GATE', name: 'S3-Gate', branch: 'docs/gate-ab-review',
    intent: `**Intent**: **Purpose**: Prepare everything the commander needs to approve, on one page, every open decision that M2 (tool support), M3 (machine profile) and the S2-Layout PRs depend on. **Scope**: the A/B adversarial pass on decision tree rev 3, rev 4 with blocker/major fixes, fixes or defect list for the S5-Tools drafts, drafts of the undrafted protected-file rows, and the consolidated review-page content. NOT writing any protected file in place. NOT code changes. NOT filing incidents (mission LEDGER). NOT the decision record plans/tool-support-and-machine-profile.md (comes after the commander answers). **Audience**: the commander (answers), the session commander (publishes the page as an Artifact), missions LAYOUT and PROFILE+TOOLS (consume the decisions).`,
    work: `## Work
Output folder (inside your worktree): ${OUT}/S3-Gate/
1. Delegate S3-Gate-A (correctness) and S3-Gate-B (cross-platform/bootstrap) in parallel on the decision tree rev 3 at ${PRIOR}/S4-Review/S4-Review-drafts/reference/tool-support-decision-tree.md. Inputs they also need: ${PRIOR}/S4-Review/S4-Review-report.md (esp. §2, the ~45 rev-2 dispositions S4 did not re-check), ${PRIOR}/S5-Tools/S5-Tools-report.md, ${PRIOR}/S5-Tools/S5-Tools-A-review.md, ${PRIOR}/S4-Review/S4-Review-C-review.md, the rules listed above, ${REPO}/scripts/aitools-lib.sh and .ps1, ${REPO}/scripts/aitools and aitools.ps1, ${REPO}/scripts/aitools-install.sh and .ps1.
   - A: correctness against .claude/rules/* (tool-lifecycle, tool-evaluation, interactive-menus, managed-file-deployment, script-standards, config-file-safety, cross-platform); re-verify every rev-2 disposition S4 did not re-check; every leaf (NA, EVALUATING, NO-METHOD, PREREQ, INSTALL-FAIL, EXCEPTION, HOLD, KEEP, ABORT, REPLACE-FAIL, REPLACE-BLOCKED, OK, SHADOWED, NOT-ON-PATH, VERSION-UNKNOWN, BELOW-MIN) reachable and consistent with SD-4/SD-5/SD-6.
   - B: APFS case-sensitivity (S4-9), PS1 and Windows paths, bash 3.2 on macOS, first run without node (aitools Step 2 vs installer Step 8), exit 2 = user abort and the RP guard (replace never removes the only resolving copy), Git Bash vs WSL bash.
   Each writes S3-Gate-A-review.md / S3-Gate-B-review.md with findings rated blocker/major/minor, each with file:section evidence.
2. Write rev 4: ${OUT}/S3-Gate/S3-Gate-drafts/reference/tool-support-decision-tree.md applying blocker and major fixes only, plus S3-Gate-rev4-changelog.md mapping each change to a finding id.
3. S4 §2 "Not fixed in a copy": apply C-08, C-09 (rest), C-22, C-28, C-33 to copies of the S5-Tools drafts under ${OUT}/S3-Gate/S3-Gate-drafts/ (keep dot-claude/ naming), or list each as a known defect with reason.
4. Draft the S4 §5.1 protected-file rows marked NOT DRAFTED: 14 (.cursor mirrors), 15 (git-safety.md), 16 (script-standards-detail.md), 25 (per-script intents). Row 17 (aitool-eval card): mark void if PR-c retires the card, else draft. Put drafts under S3-Gate-drafts/.
5. Write the review-page content: ${OUT}/S3-Gate/S3-Gate-review-page.md. Each item: id, question, options, recommendation, why, what it blocks, source. Sections:
   (a) BLOCKING: N-Q1 (toolExceptions shape + writer; recommended shape {decision:"keep", detected:{platform,method,path,version}, decidedAt, decidedBy, reason} owned by reference/user-repo.md, writer aitools-profile.js exception-set), D-TS10/11/12, N-Q3, T-Q1, T-Q9, P-Q1, P-Q2, P-Q3, P-Q8..Q11 batch, S2-Layout Q-A and Q-B (${PRIOR}/S2-Layout/S2-Layout-report.md §4), S2-Layout §6 six questions (incl. SD-8 extension to incident/glossary/frameworks, shared/registries + aitools-registry.py), C.1 (does M2 absorb tooling-resolution Workstream A? recommended yes; B and C stay separate; see ${REPO}/ROADMAP.md and ${REPO}/plans/tooling-resolution-and-artifact-registry.md), PR-b vs M2 sequencing (recommended PR-a -> PR-b -> M2 skill/registry edits), PR-a protected-file path fixes (${PRIOR}/S2-Layout/S2-Layout-B-registry-consumers.md tables 1-2) as an approval item, and every blocker the A/B pass raised that needs a commander decision.
   (b) PROTECTED-FILE BATCH: S4 §5.1's 25 rows with status (drafted / drafted by S3-Gate / void / carved out) and draft path; plus S2-Layout §5 sibling impact (sources-of-truth.md lists registries at shared/registries/ once PR-b is approved).
   (c) GLOSSARY: C-14 "detection signature", open_glossary_items from ${PRIOR}/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json, the proposed terms.
   (d) NON-BLOCKING (pre-answer): T-Q3 (answered by SD-5: [x]abort exits 2), T-Q4..T-Q8, T-Q12, P-Q4..P-Q7, P-Q12, P-Q13, N-Q2, N-Q4, N-Q6, N-Q5 (resolved).
   (e) KNOWN DEFECTS left in drafts.
   Already-approved decisions SD-1..SD-8 (handoff D.3) are context, not questions; do not re-ask them.
6. Also write ${OUT}/S3-Gate/S3-Gate-review-page.json: {"items":[{"id","section","question","options":[...],"recommendation","why","blocks","source"}]} for the session commander to render as an Artifact.
7. Ship: branch ${'docs/gate-ab-review'}, one PR containing only files under ${OUT}/S3-Gate/. Title: "Gate: A/B review of tool-support tree, rev 4, consolidated review page". Commit early (after step 1) and push, then update.`,
  },
  {
    key: 'LEDGER', name: 'S3-Ledger', branch: 'docs/incidents-87-plus',
    intent: `**Intent**: **Purpose**: Prepare the session's backlog of harness deficiencies for filing, so they are tracked rather than living only in mission reports. **Scope**: incidents #87-#113 from S4-Review, the de-duplicated S2-Layout §7 findings, the G17 verifier findings, and affected-list extensions on #21, #55, #59, #76, all as a review-ready draft batch. NOT writing registries/incidents.json in place (protected; the commander approves the batch first). NOT fixing any incident. NOT the /incident skill path fix (#84 belongs to LAYOUT PR-a). **Audience**: the commander (approval), future sessions and /audit (consumers).`,
    work: `## Work
Output folder (inside your worktree): ${OUT}/S3-Ledger/
1. Read ${'<worktree>'}/registries/incidents.json in full (offset/limit; ~2,027 lines). Record the exact last id and confirm the next id (expected #87). Read ${REPO}/.claude/rules/incident-governance.md for required fields and field-quality rules.
2. Take ${PRIOR}/S4-Review/S4-Review-incidents-draft.json (#87-#113). Validate every entry against the required fields and quality rules; fix thin entries; verify every cited file:line still holds on origin/main (code moved in PRs #50-#53).
3. De-duplicate the 18 findings in ${PRIOR}/S2-Layout/S2-Layout-report.md §7 against existing #50, #59, #70, #80, #84 and the S4 set. New ones get ids after the S4 set. For each dropped finding, say which incident covers it.
4. Add the G17 findings from the handoff (section G, G17): (1) /handoff does not warn that preserved drafts mirroring .claude/ paths become nested discoverable skills; (2) /delegate not deployed and delegation.md not in ~/.claude/rules (RE-CHECK first: ls /Users/new-jose/.claude/skills and /Users/new-jose/.claude/rules; as of 2026-10-21 delegation.md IS present in ~/.claude/rules; if resolved, record as closed-on-filing or drop with reason); (3) Grep tool sometimes not provisioned to delegates; (4) S4 §5.2 cites PR creation times as merge times. Source: ${PRIOR}/S3-Handoff-V-verification.md.
5. Draft affected-list extensions for #21, #55, #59, #76 (old -> new, with reason).
6. Write: ${OUT}/S3-Ledger/S3-Ledger-incidents-batch.json (the exact entries to append, ready to paste), ${OUT}/S3-Ledger/S3-Ledger-affected-updates.json, and ${OUT}/S3-Ledger/S3-Ledger-review.md (a table: id, title, severity, source, dedupe note; plus the list of dropped duplicates). Validate both JSON files parse (python3 -m json.tool).
7. Ship: branch docs/incidents-87-plus, one PR containing only files under ${OUT}/S3-Ledger/. Title: "Ledger: draft incident batch #87+ for commander approval". The PR body states that registries/incidents.json is NOT modified; a follow-up commit on this branch will apply the batch after approval.`,
  },
  {
    key: 'DEPLOY-PATH', name: 'S3-Path32', branch: 'fix/issue-32-pre-push-deploy-path',
    intent: `**Intent**: **Purpose**: Fix check-pre-push step 7 so it checks the build output where it now lives, unblocking every setup-script change. **Scope**: GitHub issue #32 (nobul-tech/aitools): step 7 expects aitools/deploy/ but build-deploy.sh now targets the dotprofile deploy/; fix in scripts/check-pre-push.sh and scripts/check-pre-push.ps1 with parity, plus any check-lib helper they need. NOT the M3 deploy redesign (cross-mission batch X-B2 revisits this step later). NOT other check steps. **Audience**: every agent and the commander running pre-push checks.`,
    work: `## Work
Output folder (inside your worktree): ${OUT}/S3-Path32/
1. gh issue view 32 -R nobul-tech/aitools (full body and comments). Read scripts/check-pre-push.sh and .ps1 step 7, scripts/check-lib.sh/.ps1, scripts/build-deploy.sh (how it resolves the target: userRepoPath from ~/.aitools/config.json), ${REPO}/.claude/rules/deploy-paths.md, ${REPO}/.claude/rules/git-safety.md.
2. Design the fix: step 7 must resolve the dotprofile deploy/ the same way build-deploy.sh does; when userRepoPath is unresolvable, SKIP (not FAIL) with a clear message; the frozen aitools/deploy/ must not be required. Keep bash/PS1 output identical (step names, PASS/FAIL/WARN/SKIP semantics).
3. Implement in both scripts. bash -n and the pwsh parser check on both.
4. Verify: run step 7 (or the whole pre-push check) with HOME set to a fresh isolated dir (no config -> SKIP path) AND with an isolated HOME containing a config.json whose userRepoPath points to a temp fake dotprofile you build under your worktree .aitools/scratch/ (PASS and FAIL paths). Never touch the real dotprofile. Record exact commands and outputs in ${OUT}/S3-Path32/S3-Path32-verification.md.
5. Ship: branch fix/issue-32-pre-push-deploy-path, PR titled "Fix check-pre-push step 7 to check the dotprofile deploy/ (closes #32)". PR body includes "Closes #32" and notes that X-B2 (M3) will revisit this step.`,
  },
  {
    key: 'HOOKS', name: 'S3-Hooks', branch: 'fix/hook-lifecycle',
    intent: `**Intent**: **Purpose**: Give hooks a governed lifecycle with a single source, so dotprofile copies cannot shadow shared/hooks and the install prompts fail safely. **Scope**: setup-user-hooks fixes for #80 (the adopt path must write shared/hooks only, decision SD-2), #81 (bare read -r at an EOF), #82 (standing-order-guard blocks read-only sed -n), mirrored into the duplicated build-deploy.sh logic; plus a draft hook-lifecycle rule and a recommendation for where it sits. NOT writing the rule in .claude/rules/ (protected; draft only). NOT changing hook behaviour beyond these incidents. NOT the delegation-duty-guard rollout. **Audience**: aitools install on every machine; every agent working under the hooks.`,
    work: `## Work
Output folder (inside your worktree): ${OUT}/S3-Hooks/
1. Read incidents #80, #81, #82 in registries/incidents.json (read the file fully with offset/limit, or grep for '"id": 80' etc. in a pipeline). Read scripts/setup-user-hooks.sh and .ps1, shared/hooks/standing-order-guard.sh, shared/hooks/hooks-manifest.json, scripts/build-deploy.sh (setup-user-hooks embedding: deploy-paths.md says that logic is duplicated), ${REPO}/.claude/rules/hook-rollout.md, interactive-menus.md, managed-file-deployment.md, ${REPO}/reference/managed-file-deployment.md.
2. #80 (SD-2): the adopt path in setup-user-hooks must write the adopted content to the aitools shared/hooks source only, never to dotprofile claude/hooks/. Mirror in build-deploy.sh. Both platforms. Keep every Deploy-ManagedFile return value handled at every call site (interactive-menus.md return-value contract).
3. #81: replace bare read -r with the /dev/tty + EOF-safe pattern (interactive-menus.md: EOF at the prompt = log a warning, auto-select overwrite). PS1 uses [Console]::ReadLine() null check. Parity.
4. #82: let read-only sed -n (and head/tail/cat reads if the incident covers them) pass standing-order-guard without weakening the destructive checks. Per hook-rollout.md, a matching-logic change resets that check to observe: add a mode variable if the check has none, set it to observe, and update the enforcement table in a DRAFT of hook-rollout.md (protected: draft only, under S3-Hooks-drafts/dot-claude/rules/hook-rollout.md). Smoke-test the hook: clean input exit 0, violation inputs give the expected outcome, sed -n now passes; record commands and outputs.
5. Draft the hook-lifecycle rule: ${OUT}/S3-Hooks/S3-Hooks-drafts/dot-claude/rules/hook-lifecycle.md, with an intent block (protected: draft only), plus S3-Hooks-placement.md recommending where it fits (new rule vs extending hook-rollout.md or managed-file-deployment.md) with reasons.
6. Verify: bash -n and pwsh parse on every touched script; run setup-user-hooks.sh under an isolated HOME (fake config + fake dotprofile under your worktree .aitools/scratch/) through the adopt path and the EOF path (stdin from /dev/null and a terminal-less run); if build-deploy is run, isolated HOME only. Record in ${OUT}/S3-Hooks/S3-Hooks-verification.md.
7. Ship: branch fix/hook-lifecycle, one PR with the code fixes plus the ${OUT}/S3-Hooks/ drafts. Title: "Hooks: adopt writes shared/hooks only, EOF-safe prompts, sed -n reads pass the guard (#80, #81, #82)". PR body lists the protected drafts as awaiting approval (not applied).`,
  },
]

function missionPrompt(m) {
  return `# Mission ${m.key}: commanded by ${m.name}

${m.intent}

## Your identity
You are ${m.name}, mission commander for mission ${m.key}, delegated by Session Commander 10cf255a-c (aitools repo, commander Jose). Parallel missions running now, so you do not overlap: GATE (S3-Gate, docs/gate-ab-review, files under ${OUT}/S3-Gate/), LEDGER (S3-Ledger, docs/incidents-87-plus, files under ${OUT}/S3-Ledger/), DEPLOY-PATH (S3-Path32, fix/issue-32-pre-push-deploy-path, scripts/check-pre-push.*), HOOKS (S3-Hooks, fix/hook-lifecycle, scripts/setup-user-hooks.*, shared/hooks/standing-order-guard.sh, build-deploy.sh hook section). Do not touch another mission's files.
Your name prefix (D-DEL1): ${m.name}-
Your branch (D-DEL4): ${m.branch}, created from origin/main in your worktree. Repo: nobul-tech/aitools, base main.
${PACKET}
${m.work}`
}

const RESULT = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    prUrls: { type: 'array', items: { type: 'string' } },
    branch: { type: 'string' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    verification: { type: 'string' },
    notRun: { type: 'array', items: { type: 'string' } },
    writeBlocked: { type: 'array', items: { type: 'string' } },
    incidents: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
    delegatesUsed: { type: 'array', items: { type: 'string' } },
    fullReport: { type: 'string' },
  },
  required: ['summary', 'prUrls', 'branch', 'verification', 'notRun', 'writeBlocked', 'incidents', 'openQuestions', 'fullReport'],
}

const REVIEW = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['approve', 'changes-needed', 'no-pr'] },
    findings: { type: 'array', items: { type: 'object', properties: {
      severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
      file: { type: 'string' }, issue: { type: 'string' }, evidence: { type: 'string' } },
      required: ['severity', 'issue', 'evidence'] } },
    protectedFileViolations: { type: 'array', items: { type: 'string' } },
    scopeViolations: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['verdict', 'findings', 'protectedFileViolations', 'scopeViolations', 'notes'],
}

function reviewPrompt(m, r) {
  return `You are ${m.name}-Review, an independent read-only reviewer for mission ${m.key}, delegated by Session Commander 10cf255a-c. Your job is to try to find what is wrong with the mission's PR(s); default to skepticism.

Read first: ${REPO}/.claude/rules/sources-of-truth.md, ${REPO}/.claude/rules/script-standards.md, ${REPO}/.claude/rules/cross-platform.md, ${REPO}/.claude/rules/interactive-menus.md, /Users/new-jose/.claude/rules/delegation.md, ${REPO}/shared/skills/delegate/SKILL.md ("Verifying what comes back").
USO: no $(...), backticks, &&, ||, ; in Bash calls; use separate calls. Read-only: do NOT edit files, push, comment on, approve or merge any PR. If a tool call is denied, record WRITE_BLOCKED: <what> -- <text> and continue.

Mission intent:
${m.intent}

Mission work order (what it was told to do):
${m.work}

Mission commander's result:
${JSON.stringify(r, null, 2).slice(0, 20000)}

Do: for each PR URL, run gh pr view <url> --json files,commits,body,headRefName and gh pr diff <url>. Check: (1) every claimed file exists in the diff and matches the report; (2) no protected file (sources-of-truth.md table, intent statements) was written in place without approval (drafts under the mission folder are fine); (3) scope: nothing outside the work order; (4) for code: bash/PS1 parity, error-handling table compliance, no silent failures, every Deploy-ManagedFile return value handled; (5) D-DEL1 prefixes on every new *.md; no .claude/ folder inside mission output; (6) spot-check at least two factual claims against the source files and one item reported clean; (7) verification claims are backed by recorded commands/outputs. If there is no PR, verdict no-pr and say why.`
}

phase('Missions')
const results = await pipeline(
  MISSIONS,
  (m) => agent(missionPrompt(m), { label: m.key + ' (' + m.name + ')', phase: 'Missions', schema: RESULT, isolation: 'worktree', agentType: 'general-purpose' }),
  (r, m) => r ? agent(reviewPrompt(m, r), { label: m.key + ' review', phase: 'Review', schema: REVIEW, agentType: 'general-purpose' }).then(v => ({ mission: m.key, result: r, review: v })) : ({ mission: m.key, result: null, review: null }),
)
return results
