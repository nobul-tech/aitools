export const meta = {
  name: 'merge-all-prs',
  description: 'Merge every open aitools PR in order with CI gates, post-merge actions, release v0.74.0, docs scrub, friction plan',
  phases: [
    { title: 'Brief', detail: 'read commander prompts newest-first until the goal is clear' },
    { title: 'Merge', detail: 'one agent per PR, sequential, CI-gated, verified after each merge' },
    { title: 'Friction', detail: 'issues, PR history, CI history, sessions -> plans/merge-friction-improvements.md v1.0' },
    { title: 'Post-merge', detail: '#102 incidents, #74/#75 re-land, follow-ups, versions-not-drafts, build-deploy backup + rebuild' },
    { title: 'Release', detail: 'release notes v0.74.0, docs scrub, tag, GitHub cleanup' },
    { title: 'Final', detail: 'completeness check and report' },
  ],
}

const R = '/Users/new-jose/repos/aitools'
const MF = R + '/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions'
const OUT = MF + '/S3-MergeAll'
const PACKET = MF + '/SC-mission-packet.md'
const HANDOFF = R + '/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md'
const SESSION = '/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl'

const COMMON = `
## Delegation duty (read first)
You are a delegate of mission MERGE-ALL (workflow orchestrated by Session Commander 10cf255a-c for the commander, Jose). You cannot launch sub-agents; do the work yourself.
- RULES: before other work read in full ${PACKET} and every file its section 1 lists (user rules /Users/new-jose/.claude/CLAUDE.md, /Users/new-jose/.claude/rules/*.md; project ${R}/CLAUDE.md and every ${R}/.claude/rules/*.md), plus any reference/*.md your task touches. Critical: simple Bash only (no &&, ||, ;, $(), backticks, multi-line commands; write scratch scripts under ${R}/.scratch/session-<name10>/ for anything longer); Read/Edit/Write for files; Perl not sed; no silent failures in reusable code; .sh/.ps1 parity; bash 3.2 compatible; never switch the main checkout's branch; never remove any git worktree; never force-push; Firecrawl deprecated.
- SKILLS: /scratch, /delegate (for prompt conventions), /incident, /glossary, /tool-ops as relevant. If a skill will not load, read its SKILL.md under /Users/new-jose/.claude/skills/<name>/ or ${R}/{shared/skills,.claude/skills}/<name>/ and follow it by hand.
- OPERATIONAL LEARNING: section I of ${HANDOFF} and packet section 5. Plus: GitHub refuses --request-changes/--approve on a PR from the same account, so reviewers post verdicts with \`gh pr comment\`. Wait for CI with \`gh pr checks <n> --watch --interval 30\` or \`gh run watch <id>\` (Bash timeout up to 600000 ms; repeat if needed); never a foreground sleep. \`.ps1\` files check out with CRLF. Pre-push step 7 now runs on every push and FAILs until the dotprofile deploy/ is rebuilt (expected until the post-merge rebuild).
- COMMANDER DECISIONS (binding, 2026-10-26): this mission MERGES PRs itself, with "Create a merge commit" only (\`gh pr merge <n> --merge\`), never squash/rebase, only when every check is green and mergeStateStatus is CLEAN, in the given order; after each merge wait for main's CI to go green and run the local suites the PR touched. Produced documents/changes are VERSIONS (v1.0, v1.1...), never "drafts". Protected files: write the version and commit it; the commander reviews the diff after (review-after replaces the pre-write gate, to be written into the rules by this mission). plans/, handoffs, relay.md and CLAUDE.md go directly to main (CLAUDE.md "Channel exception"); everything else via a PR. Abort behaviour stays as PR #106 implements it. Dotprofile writes auto-commit and push to its main. The mission tags v0.74.0 and pushes the tag. build-deploy must back up the dotprofile deploy/ before replacing it; the mission then rebuilds it itself.
- Other missions are running and commit to main: FAN-PLAN, BUILD-PKG (plans/build-package/, docs), RECONCILE (plans/fan-plan-reconciliation.md). Always \`git -C ${R} pull --ff-only\` before using the main checkout; stage only your own paths; never \`git add -A\`.
- WRITE_BLOCKED: if any write or tool call is denied, do not retry it in another form; record \`WRITE_BLOCKED: <what> -- <exact denial text>\` in your result and stop that step.
- NAME PREFIX (D-DEL1): every *.md you create starts with your label prefix given below (e.g. \`S3-MA-Merge99-notes.md\`), written under ${OUT}/ unless told otherwise. Commit messages: imperative subject, body with what/why/verification/not run, end with \`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\`. PR bodies end with \`🤖 Generated with [Claude Code](https://claude.com/claude-code)\`.
- Cite sources for factual claims; say "unknown" rather than guess. Mark deficiencies \`INCIDENT:\` in your result.
`

const STEP = {
  type: 'object',
  properties: {
    ok: { type: 'boolean', description: 'true if the step fully succeeded' },
    summary: { type: 'string' },
    details: { type: 'string', description: 'evidence: commands, SHAs, CI run ids, test results' },
    blocker: { type: 'string', description: 'empty if ok; else what blocks and what the commander must do' },
    incidents: { type: 'array', items: { type: 'string' } },
  },
  required: ['ok', 'summary', 'details', 'blocker', 'incidents'],
}

// ---------------------------------------------------------------- Brief
phase('Brief')
const brief = await agent(`You are S3-MA-Brief (prefix S3-MA-Brief-). ${COMMON}
Task: read the commander's own prompts in REVERSE chronological order (newest first) from this session transcript until the mission goal below is completely clear, then write a mission brief.
Transcript: ${SESSION} (very large: never load it whole). Use \`python3 ${R}/scripts/read-session.py --help\` / \`read-session-full.py --help\` to filter user prompts; AskUserQuestion answers are tool results, also capture them (an \`ask-answers.py\` helper exists under ${R}/.claude/worktrees/ansa/.scratch/ — find and reuse it).
Mission goal as stated by the commander (2026-10-26): merge all open PRs in the right order with merge commits after CI is green, verify after each merge, handle all errors and CI failures; launch verifiers; propose improvements, unit tests and CI steps that catch issues we hit; read GitHub issues, PR history and session files for friction; make "versions, not drafts" a user-scope rule (delegation rule + /delegate skill, protected files review-after); post-merge: fix-forward #116, apply #102 incidents, re-land #74/#75, small follow-ups, GitHub cleanup, thorough release notes (from RELEASE_NOTES.md mtime and commit/PR messages), docs scrub, tag v0.74.0; change build-deploy to back up then rebuild, and rebuild the dotprofile deploy/ itself.
Write ${OUT}/S3-MA-Brief-brief.md: the goal, every relevant commander decision with timestamp, the open PR list and order (below), and anything in the prompts that changes or adds to the goal. Commit it directly to main (channel exception) after pull --ff-only, staging only that file.
Merge order (Session Commander's simulation, all clean except #116 vs #106/#112 in .github/workflows/check.yml and both installers): #99, #101, #105, #104, #97, #102, #103, #98, #108, #114, #109, #113, #112, #100, #110, #111, #115, #106, #116.
Return the brief text in details.`, { label: 'brief', phase: 'Brief', schema: STEP })
const BRIEF = brief ? brief.details : '(brief unavailable)'

// ---------------------------------------------------------------- Friction (runs alongside merges)
const frictionChain = async () => {
  const lenses = [
    { k: 'Issues', p: `all GitHub issues (open and closed) with \`gh issue list -R nobul-tech/aitools --state all --limit 200\` and \`gh issue view\`; find recurring failure classes` },
    { k: 'PRs', p: `PR history #50-#120 (\`gh pr list --state all\`, bodies, review comments, follow-up commits): stacked-base mistakes (#74/#75), reviews ignored before merge, conflicts, protected-draft churn, worktree/PR overhead` },
    { k: 'CI', p: `CI history (\`gh run list -R nobul-tech/aitools --limit 200\`, failed runs with \`gh run view --log-failed\`), .github/workflows/check.yml, scripts/check-pre-commit.sh/.ps1 and check-pre-push.sh/.ps1: what failed, what CI does not catch that missions found by hand` },
    { k: 'Sessions', p: `the commander's prompts in ${SESSION} (reverse chronological, filtered with ${R}/scripts/read-session.py) and archived sessions in /Users/new-jose/repos/aitools-nobul-jose/sessions/: every correction, frustration and repeated instruction (e.g. worktree/PR overhead, drafts, context waste)` },
  ]
  const finds = await parallel(lenses.map(l => () => agent(`You are S3-MA-Friction${l.k} (prefix S3-MA-Friction${l.k}-). ${COMMON}
Mission brief: ${BRIEF}
Task (read-only research): study ${l.p}. For each friction point: evidence (issue/PR/run/transcript cite), root cause, and a concrete remedy: a new unit test (file, what it asserts), a new CI step (job, command), a check-script step, or a process/rule change. Write ${OUT}/S3-MA-Friction${l.k}-findings.md (do not commit). Return the findings in details.`, { label: `friction:${l.k}`, phase: 'Friction', schema: STEP })))
  const plan = await agent(`You are S3-MA-FrictionPlan (prefix S3-MA-FrictionPlan-). ${COMMON}
Inputs: ${finds.filter(Boolean).map(f => f.details).join('\n\n---\n\n')}
Task: write ${R}/plans/merge-friction-improvements.md, version 1.0 (not a draft): intent; prioritised friction list with evidence; proposed unit tests, CI/CD steps and check-script steps (exact file, job, command, what it catches, which past incident it would have caught); process and rule changes (including reducing worktree/PR overhead and the versions-not-drafts behaviour); batches an executing mission can follow (plan-execution.md format, verification per batch). Commit and push it directly to main (channel exception: pull --ff-only, stage only that file, check-pre-commit, push). Return the commit SHA and a summary.`, { label: 'friction:plan', phase: 'Friction', schema: STEP })
  const review = await agent(`You are S3-MA-FrictionReview (prefix S3-MA-FrictionReview-), an INDEPENDENT reviewer. ${COMMON}
Review ${R}/plans/merge-friction-improvements.md against the repo's code, CI and rules (you did not see the writers' notes). Check every proposed test/CI step is concrete and would catch what it claims; flag gaps. If fixes are needed, edit the plan to v1.1 and commit directly to main (channel exception). Write ${OUT}/S3-MA-FrictionReview-verdict.md. Return the verdict.`, { label: 'friction:review', phase: 'Friction', schema: STEP })
  return { plan, review }
}

// ---------------------------------------------------------------- Merge chain
const PRS = [
  [99, 'docs/harness-approved-drafts', 'h2-draftsh'],
  [101, 'docs/m3-approved-drafts', 'h2-draftsm3'],
  [105, 'docs/m3-approved-intents', 'h2-draftsm3b'],
  [104, 'docs/mf-audit', 'mf-audit'],
  [97, 'docs/m3-lead-plan', 'm3lead'],
  [102, 'docs/mf-incidents', 'mf-inc'],
  [103, 'fix/mf-dotprofile-adopt-push', 'mf-adopt'],
  [98, 'feature/mf-config-no-machine', 'mf-nomach'],
  [108, 'fix/mf-audit-profile-json', 'mf-fix6'],
  [114, 'fix/mf-audit-config', 'mf-fix3'],
  [109, 'fix/mf-audit-consumers', 'mf-fix4'],
  [113, 'fix/mf-lib-runner-result', 'mf-runner'],
  [112, 'fix/mf-audit-claude-build', 'mf-fix5'],
  [100, 'feature/harness-rules-manifest', 'h2-manifest'],
  [110, 'feature/harness-cursor-user-rules', 'h2-cursor'],
  [111, 'feature/harness-mdm-followups', 'h2-mdm'],
  [115, 'fix/mf-lib-relay', 'mf-relay-a'],
  [106, 'feature/harness-hookin', 'h2-hookin'],
  [116, 'fix/mf-installer-relay', 'mf-relay-b'],
]

const mergeOne = async ([n, br, wt]) => {
  const extra = n === 116
    ? `#116 is known to conflict with main after #106 and #112 merge (.github/workflows/check.yml: keep every CI job from both sides; scripts/aitools-install.sh/.ps1: #116's PR body says how to resolve against #106 — keep #106's Step 8b deploy-harness and #116's lib relay). Resolve by merging origin/main into ${br} in the existing worktree (no rebase, no force-push), run the touched suites (tests/profile/*, tests/hookin/test-hookin.sh, tests/managed-files/*), push, and post a short "conflict resolution" comment listing what you kept.`
    : `If GitHub reports a conflict or the branch is BEHIND in a way that blocks merging, merge origin/main into ${br} in its existing worktree (no rebase, no force-push), resolve, re-test, push, and comment on the PR.`
  const res = await agent(`You are S3-MA-Merge${n} (prefix S3-MA-Merge${n}-). ${COMMON}
Mission brief: ${BRIEF}
Task: merge PR #${n} (branch ${br}) into main, in order, safely.
1. \`gh pr view ${n} -R nobul-tech/aitools --json state,baseRefName,mergeable,mergeStateStatus,statusCheckRollup,headRefOid\`. If already MERGED, verify it and return ok. Base must be main.
2. Read the PR's latest comments/reviews; any unresolved BLOCKING finding = do not merge, return blocker.
3. ${extra} Existing worktree for this branch (owned by a finished mission; you may use it, never remove it): ${R}/.claude/worktrees/${wt}. Check \`git -C <wt> status --short\` first.
4. If a CI check fails: read \`gh run view <id> --log-failed\`, fix the cause on the branch in that worktree (minimal, with a test if it is a code bug), push, wait for checks again. Up to 3 fix rounds; then return blocker.
5. Wait until every check is SUCCESS (or NEUTRAL/SKIPPED for CodeQL) and mergeStateStatus is CLEAN. Then \`gh pr merge ${n} -R nobul-tech/aitools --merge\` (merge commit; do NOT delete the branch).
6. After merge: find main's CI run for the merge commit (\`gh run list -R nobul-tech/aitools --branch main --limit 5\`), wait for it to finish green. In a fresh read-only check (\`git -C ${R} pull --ff-only\`), run the local suites for the files this PR touched under an isolated HOME (never the real HOME), plus \`bash -n\` / pwsh parser on touched scripts.
7. If main's CI goes red: diagnose; open a fix PR from a new branch \`fix/post-merge-${n}\` in a new worktree ${R}/.claude/worktrees/pm${n}, get it green, merge it with --merge, re-verify. Return ok only when main is green.
Write ${OUT}/S3-MA-Merge${n}-log.md (do not commit). Return ok, the merge SHA, main CI run id/result, and local test results in details.`, { label: `merge:#${n}`, phase: 'Merge', schema: STEP })
  const ver = await agent(`You are S3-MA-Verify${n} (prefix S3-MA-Verify${n}-), an INDEPENDENT verifier. ${COMMON}
Verify that PR #${n} is correctly merged into main: \`gh pr view ${n} --json state,mergeCommit\` shows MERGED with a merge commit (not squash); main's CI for that commit (or a later one) is green (\`gh run list --branch main\`); \`git -C ${R} log --first-parent -3 origin/main\`; the PR's files on origin/main equal the PR head's versions except for later merges; no unrelated changes slipped in. Report problems, do not fix them. Return ok and evidence.`, { label: `verify:#${n}`, phase: 'Merge', schema: STEP })
  return { n, res, ver }
}

const mergeChain = async () => {
  const results = []
  for (const p of PRS) {
    const r = await mergeOne(p)
    results.push(r)
    log(`#${p[0]}: merge ${r.res && r.res.ok ? 'ok' : 'FAILED'}, verify ${r.ver && r.ver.ok ? 'ok' : 'FAILED'}`)
    if (!r.res || !r.res.ok || !r.ver || !r.ver.ok) {
      log(`Stopping the merge chain at #${p[0]}: later PRs depend on it`)
      break
    }
  }
  return results
}

phase('Merge')
const [merges, friction] = await parallel([() => mergeChain(), () => frictionChain()])
const mergeList = merges || []
const allMerged = mergeList.length === PRS.length && mergeList.every(r => r.res && r.res.ok && r.ver && r.ver.ok)

// ---------------------------------------------------------------- Post-merge
const post = []
if (allMerged) {
  phase('Post-merge')
  const POST = [
    { k: 'Incidents', t: `Apply the commander-approved incident batch from merged PR #102: run \`python3 ${MF}/S3-MF-Incidents/S3-MF-Incidents-apply.py\` (dry run), then \`--write\` once ids line up with registries/incidents.json's max id (parse the whole file). If ids collide, renumber per the script's rules and record it. Ship registries/incidents.json in a PR from branch docs/apply-incidents-146 (new worktree ${R}/.claude/worktrees/inc146), wait for green CI, merge with --merge, verify main CI green.` },
    { k: 'Layout', t: `Re-land LAYOUT PR-b (#74) and PR-c (#75), which merged into stale bases and never reached main. Per ${HANDOFF} section E step 1: new branches off origin/main — feature/user-level-skills-reland (cherry-pick 4aa4728, 1b34195, ed1b75c) and refactor/retire-reference-cards-reland (cherry-pick 6d3cacf, 7b45433, 2375fea; stacked, merge after the first). Drop PR-a's old commits. Resolve conflicts with #71's step numbering and #85/#99's tool-ops SKILL.md edits (the Intent moves with the skill). New worktrees ${R}/.claude/worktrees/relandb and relandc. PR each, green CI, merge --merge in order, verify main CI after each.` },
    { k: 'Followups', t: `Small follow-ups in one PR (branch fix/merge-followups, new worktree ${R}/.claude/worktrees/mfollow): (a) installer Step 8b passes --skip-config / -SkipConfig to deploy-harness (merged #111 added the flag; #106 Step 8b) so aitools install runs the config writer once; tests updated; (b) the approved protected drafts, applied as versions: #103's reference/managed-file-deployment.md "Caller Responsibilities" N-Q2 bullet (${MF}/S3-MF-Adopt/S3-MF-Adopt-drafts/reference/managed-file-deployment.md.edit.txt), #108's I-3 reference/script-standards-detail.md edit (${MF}/S3-MF-Fix6/S3-MF-Fix6-drafts/), #105 rows 5 and 6 for setup-user-config.sh/.ps1 intents (${MF}/S3-M3-Docs/S3-M3-Docs-approval-page.md rows 5-6; row 6 wording approved: "... or --no-machine when they leave this machine unregistered"). Green CI, merge --merge, verify.` },
    { k: 'Versions', t: `Make "versions, not drafts" a user-scope rule. (a) Dotprofile /Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md: add decision D-DEL5 (2026-10-26, commander): delegates and agents write their outputs as versions (v1.0, v1.1, ...) in their final location, never as "drafts"; protected files are written as a version and committed, and the commander reviews the diff after (review-after); approval of text after the fact replaces the pre-write draft gate; outward-facing or destructive actions still need confirmation. Commit and push to the dotprofile main directly. (b) aitools: shared/skills/delegate/SKILL.md (writing steps 9-10: replace "drafts" with versions + review-after) and .claude/rules/sources-of-truth.md "The rule" (review-after: write the version, commit, present the diff; the commander reviews the commit/PR), plus any rule that says "ship as a draft" (grep "draft" in .claude/rules, shared/skills, CLAUDE.md, the mission packet ${PACKET}). One PR (branch docs/versions-not-drafts, new worktree ${R}/.claude/worktrees/versions), green, merge --merge, verify.` },
    { k: 'Rebuild', t: `build-deploy.sh rm -rf's the dotprofile deploy/ and leaves it half-built on failure (#86). Change it (branch fix/build-deploy-backup, new worktree ${R}/.claude/worktrees/bdbackup): before replacing, copy <dotprofile>/deploy to <dotprofile>/deploy.bak.<UTC ts>/ (keep at most 5, prune oldest, per config-file-safety.md), build into a temp dir, and swap it in only on success (stale generated files removed; on failure the old deploy/ stays and the backup is kept); log every step; add a test under tests/ (isolated HOME, fixture dotprofile: success swaps, failure keeps old, backups pruned to 5); check deploy-paths.md and reference docs describe it. Ensure the dotprofile .gitignore ignores deploy.bak.*/. PR, green, merge --merge, verify. THEN (commander-authorised, the only real-HOME run in this mission): \`git -C ${R} pull --ff-only\`, run \`bash ${R}/scripts/build-deploy.sh\` for the real dotprofile, confirm the backup exists, review \`git -C /Users/new-jose/repos/aitools-nobul-jose status\`, commit deploy/ (and .gitignore) in the dotprofile and push to its main. Then \`bash ${R}/scripts/check-pre-push.sh\` from the main checkout: step 7 must PASS.` },
  ]
  for (const s of POST) {
    const r = await agent(`You are S3-MA-${s.k} (prefix S3-MA-${s.k}-). ${COMMON}
Mission brief: ${BRIEF}
Task: ${s.t}
Never merge until every check is green and mergeStateStatus is CLEAN; after merging wait for main's CI to go green. Write ${OUT}/S3-MA-${s.k}-log.md. Return ok, SHAs, PR URLs, CI evidence.`, { label: `post:${s.k}`, phase: 'Post-merge', schema: STEP })
    const v = await agent(`You are S3-MA-${s.k}Verify (prefix S3-MA-${s.k}Verify-), an INDEPENDENT verifier. ${COMMON}
The previous step claimed: ${r ? r.summary + '\n' + r.details : 'no result'}
Verify it against GitHub (\`gh pr view\`, \`gh run list --branch main\`), git (origin/main, and the dotprofile repo for dotprofile changes) and the files. Report every discrepancy; do not fix. Return ok and evidence.`, { label: `verify:${s.k}`, phase: 'Post-merge', schema: STEP })
    post.push({ k: s.k, r, v })
    log(`post ${s.k}: ${r && r.ok ? 'ok' : 'FAILED'} / verify ${v && v.ok ? 'ok' : 'FAILED'}`)
  }
} else {
  log('Merge chain did not complete; skipping post-merge and release phases')
}

// ---------------------------------------------------------------- Release + docs scrub
let release = null
if (allMerged) {
  phase('Release')
  const AREAS = [
    { k: 'Rules', p: `${R}/.claude/rules/*.md and ${R}/.cursor/rules/*.mdc` },
    { k: 'Reference', p: `${R}/reference/*.md` },
    { k: 'Top', p: `${R}/CLAUDE.md, ${R}/README.md, ${R}/ROADMAP.md, ${R}/shared/claude-shared.md, ${R}/shared/cursor-rules/user-rules.md, ${R}/shared/skills/*/SKILL.md, ${R}/.claude/skills/*/SKILL.md` },
  ]
  const scrubs = await parallel(AREAS.map(a => () => agent(`You are S3-MA-Scrub${a.k} (prefix S3-MA-Scrub${a.k}-). ${COMMON}
Mission brief: ${BRIEF}
Task (read-only audit): thoroughly scrub ${a.p} against the code now on origin/main (pull first). List every statement that is false, stale, missing or contradictory (file:line, what is wrong, the code evidence, the exact replacement text — descriptive and complete). Do not edit. Write ${OUT}/S3-MA-Scrub${a.k}-findings.md. Return the findings in details.`, { label: `scrub:${a.k}`, phase: 'Release', schema: STEP })))
  const notes = await agent(`You are S3-MA-ReleaseNotes (prefix S3-MA-ReleaseNotes-). ${COMMON}
Task (read-only): prepare the v0.74.0 entry for ${R}/RELEASE_NOTES.md per .claude/rules/documentation-standards.md. Find when RELEASE_NOTES.md was last changed (\`git log -1 --format=%cI -- RELEASE_NOTES.md\` and its mtime) and the last tag (v0.73.2); fold in the untagged v0.73.3 notes; then read EVERY commit and PR message since then (\`git log\`, \`gh pr list --state merged --search "merged:>=<date>"\`, PR bodies) and populate every change: bug fixes, features, improvements, documentation, files created, with numbers, severities and PR links; thorough and descriptive. Write the exact entry text to ${OUT}/S3-MA-ReleaseNotes-entry.md and return it in details.`, { label: 'release:notes', phase: 'Release', schema: STEP })
  const apply = await agent(`You are S3-MA-DocsApply (prefix S3-MA-DocsApply-). ${COMMON}
Inputs: scrub findings:
${scrubs.filter(Boolean).map(s => s.details).join('\n\n---\n\n')}
Release notes entry:
${notes ? notes.details : '(missing)'}
Task: apply every scrub fix (as versions, descriptive) and the RELEASE_NOTES.md v0.74.0 entry. CLAUDE.md and plans/ edits go directly to main (channel exception); everything else in one PR (branch docs/v0.74.0-scrub, new worktree ${R}/.claude/worktrees/scrub). Run check-pre-commit and check-pre-push; wait for green CI and CLEAN; merge --merge; wait for main CI green. Then tag: \`git -C ${R} pull --ff-only\`, \`git -C ${R} tag -a v0.74.0 -m "v0.74.0"\` on the merge commit, \`git -C ${R} push origin v0.74.0\`. Write ${OUT}/S3-MA-DocsApply-log.md. Return SHAs, PR URL, tag SHA.`, { label: 'release:apply', phase: 'Release', schema: STEP })
  const cleanup = await agent(`You are S3-MA-Cleanup (prefix S3-MA-Cleanup-). ${COMMON}
Task: GitHub cleanup after every PR has merged. (1) \`gh pr list --state open\`: must be empty; anything left, report. (2) Delete the remote branches of merged PRs from this session (#50-#120) with \`git -C ${R} push origin --delete <branch>\` only when the PR is MERGED and the branch is fully contained in origin/main (\`git merge-base --is-ancestor\`); never delete main; do NOT remove local worktrees (the commander said hold off). (3) For each open GitHub issue, check the code on origin/main: close it with \`gh issue close <n> --comment "<evidence: PR, commit, file:line>"\` only when verified fixed; otherwise leave it. (4) Report stale refs (e.g. refs/mdmpkg/*) without deleting them. Write ${OUT}/S3-MA-Cleanup-log.md. Return what you did with evidence.`, { label: 'release:cleanup', phase: 'Release', schema: STEP })
  const relVerify = await agent(`You are S3-MA-ReleaseVerify (prefix S3-MA-ReleaseVerify-), an INDEPENDENT verifier. ${COMMON}
Verify: tag v0.74.0 exists on origin and points at a commit on main whose CI is green; RELEASE_NOTES.md v0.74.0 covers every PR merged since the previous entry (cross-check \`gh pr list --state merged\`); the scrub fixes landed; no open PRs remain; deleted branches were all merged. Return ok and evidence.`, { label: 'release:verify', phase: 'Release', schema: STEP })
  release = { scrubs, notes, apply, cleanup, relVerify }
}

// ---------------------------------------------------------------- Final
phase('Final')
const final = await agent(`You are S3-MA-Final (prefix S3-MA-Final-), the completeness critic and reporter. ${COMMON}
Results so far (JSON): ${JSON.stringify({ merges: mergeList.map(m => ({ n: m.n, merge: m.res, verify: m.ver })), post, release, friction }).slice(0, 60000)}
Task: (1) independently check the end state: \`gh pr list -R nobul-tech/aitools --state open\` (should be empty), main CI green, tag v0.74.0, pre-push step 7 PASS, dotprofile deploy/ committed, plans/merge-friction-improvements.md on main, D-DEL5 in the dotprofile delegation rule. (2) Write ${OUT}/S3-MA-report.md (version 1.0): 5-line summary; per PR: merge SHA, CI run, verifier verdict; post-merge actions; release; friction plan; every failure and how it was handled; open questions with suggested answers; all INCIDENT markers collected from every step (unfiled); what remains for the commander. (3) Commit ${OUT}/ (all S3-MA-* files) directly to main (channel exception: pull --ff-only, stage only that folder, push). Return the report text in details.`, { label: 'final', phase: 'Final', schema: STEP })
return { allMerged, merged: mergeList.map(m => m.n), final: final ? final.summary : null }
