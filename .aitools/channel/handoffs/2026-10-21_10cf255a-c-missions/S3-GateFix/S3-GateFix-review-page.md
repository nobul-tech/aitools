# S3-GateFix review page: tool support, machine profile, skill layout, /tool-adopt

**Intent**: **Purpose**: Every open decision that M2 (tool support), M3 (machine profile), the S2-Layout PRs and the early /tool-adopt ship depend on, one item per decision, for the session commander to publish as one review page Artifact and for the commander to answer. **Scope**: Sections ta (TOOL-ADOPT approval), k (approved context, not questions), a (blocking gate questions), b (protected-file batch rows), c (glossary), d (non-blocking, pre-answer), e (known defects left in drafts). NOT re-asking approved decisions (SD-1..SD-8, D-TS13, the managed-file model: section k). NOT the decision record plans/tool-support-and-machine-profile.md (written after the answers). **Audience**: The session commander (publishes it); the commander (answers it); missions TOOL-ADOPT, LAYOUT and PROFILE-TOOLS (consume the answers).

Generated from the review-page JSON by `S3-GateFix-render-review-page.py` (the JSON is the single source; edit it, then re-render). S3-GateFix (mission GATE-FIX, Session Commander 10cf255a-c), 2026-10-21; built on the S3-Gate page merged in PR #58.

## Summary

1. (ta) TOOL-ADOPT approval: ship /tool-adopt now as a process-only user-level skill: 5 items, 5 open.
2. (k) CONTEXT: approved, not questions: 3 context items (approved; nothing to answer).
3. (a) BLOCKING: decide at the gate: 26 items, 24 open (D-TS13 approved; REV4 superseded).
4. (b) PROTECTED-FILE BATCH: approve each row's draft: 25 protected-file rows (21 drafted, 2 text-only, 1 void, 1 carved-out; drafted by S3-GateFix: R1, R4, R16; earlier mission: R2, R7, R8, R9, R10, R11, R12, R13, R17, R18, R19, R20, R21, R22, R23, R24; S3-Gate: R3, R5, R6, R14, R15, R25), plus 1 question(s).
5. (c) GLOSSARY decisions: 7 items, 7 open.
6. (d) NON-BLOCKING: pre-answer before the named batch: 18 items, 18 open.
7. (e) KNOWN DEFECTS left in drafts: accept or send back: 13 items, 12 open (E-independence resolved).
8. New in this revision: REV5, TA-PLACE, TA-SKILL, TA-INTENT, TA-GLOSSARY, TA-M2, E-rev5-minors, E-node-corrupt, E-merge-revert, E-mdc-model, E-relay-exit2. Changed: D-TS13, T-Q1, S2L-Q1, R1, R4, R7, R16, E-rev4-minors, E-independence.
9. Suggested answer order: Section ta (TA-PLACE, TA-SKILL, TA-INTENT, TA-GLOSSARY, TA-M2): these alone let mission TOOL-ADOPT ship /tool-adopt now → N-Q1 and D-TS10..D-TS12: every M2/M3 code batch waits on them (D-TS13 is already approved) → REV5 and the row batch (section b) → The S2-Layout items: PR-a can start as soon as item PR-a is answered.

Path key: MISSIONS = .aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/ (read-only provenance). GATE = .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Gate/ (merged in PR #58; provenance). FIX = .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-GateFix/. Paths are relative to the aitools repo root.

## (ta) TOOL-ADOPT approval: ship /tool-adopt now as a process-only user-level skill

### TA-PLACE (new): Where does /tool-adopt live: user level (shared/skills/tool-adopt/, deployed to ~/.claude/skills/) or project level (.claude/skills/tool-adopt/ in aitools)?

- **Options:**
  - (a) User level, process-only now, next to /tool-eval and /tool-registry, which SD-8 already moves to user level
  - (b) Project level, as S2-Layout naming rule N3, item S2L-Q1 and row R4 assumed
  - (c) User level, plus a one-line documentation-standards.md 'Skill placement' edit that names harness-process skills as user-level
- **Recommendation:** (a), and (c) if you read the placement rule as forbidding it
- **Why:** /tool-adopt calls /tool-eval and /tool-registry. If those two move to user level (SD-8) and /tool-adopt stays in the project, it is the only one of the three missing outside aitools, while tool requests start in other repos (RFC-0001). The draft says the work itself always happens in the aitools repo. Cost: documentation-standards.md 'Skill placement' says user-level skill content is 'factual (patterns, gotchas, platform behavior), not project-specific opinions', and project-level holds 'governance workflows'. /tool-adopt is an aitools governance workflow, so (a) leans on the SD-8 precedent (harvest, tool-eval, tool-registry are also harness processes), and (c) removes the ambiguity
- **Blocks:** TA-SKILL; S2L-Q1 option text; row R4
- **Source:** mission GATE-FIX brief ('ship /tool-adopt early as a process-only user-level skill at shared/skills/tool-adopt/'); handoff 2026-10-21_360aa8f3-8.md D.3 SD-8; .claude/rules/documentation-standards.md 'Skill placement'; MISSIONS/S2-Layout/S2-Layout-report.md section 6 Q1

### TA-SKILL (new): Approve the /tool-adopt skill text for shipping now at shared/skills/tool-adopt/SKILL.md?

- **Options:**
  - (a) Approve the S3-GateFix draft as written
  - (b) Approve with changes (name them)
  - (c) Do not ship early; land the full skill with M2
- **Recommendation:** (a)
- **Why:** The process (scope, /tool-eval when no preferred method, registry data via /tool-registry, setup scripts, onboarding checklist, verify, maintain the rule) is usable today. A 'Today and after M2' table keeps it truthful before the decision tree exists, with an explicit switch-on condition. Changes against S3-Gate's draft: user-level 'Where this runs' section; registry only through /tool-registry ('never read or name a registry JSON file directly'); managed-file wording matches the approved model ([a]ccept & adopt and [m]erge & adopt, not '[a]dopt'); aitools-relative paths instead of @ links that would not resolve in other repos; step numbers kept (/tool-registry cites step 5, /tool-eval returns to step 2); the RFC-0001 issue path for requests from other repos. (c) leaves tool onboarding without a process skill until M2
- **Blocks:** mission TOOL-ADOPT ship; row R4
- **Source:** FIX/S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md (+ .s3gate-to-s3gatefix.diff); GATE/S3-Gate-drafts/dot-claude/skills/tool-adopt/SKILL.md

### TA-INTENT (new): Approve the /tool-adopt intent statement (new intent; protected wherever it appears)?

- **Options:**
  - (a) Approve the revised intent (verbatim from the draft's '## Intent' block): "Purpose: Carry a managed tool from 'evaluated' to 'supported' on each target platform and environment, so its registry entry and setup scripts meet the tool lifecycle rule today and the tool support decision tree once it lands. Scope: Preferred-method confirmation (invoking /tool-eval when missing), registry data through /tool-registry, setup-script creation or migration in the aitools repo, onboarding integration, verification, and maintenance of the registry and the tool-lifecycle rule; which steps wait for the decision-tree machinery (M2). NOT install-method research or health flags (/tool-eval). NOT the registry write process (/tool-registry). NOT the managed-file review choices [a]ccept & adopt and [m]erge & adopt, which copy the deployed file or an AI merge back to the repo (the source of truth) and are unrelated to tool adoption (aitools reference/managed-file-deployment.md). NOT framework adoption (aitools reference/framework-adoption.md). Audience: Any agent, in any repo, that integrates a tool, migrates a setup script, or answers a 'no method for &lt;platform&gt;' ERROR; the commander, who approves every protected change it drafts."
  - (b) Approve S3-Gate's intent unchanged (project-level wording)
  - (c) Revise
- **Recommendation:** (a)
- **Why:** Intent statements need approval before they are written (sources-of-truth.md 'Intent statements'). The revision keeps S3-Gate's purpose and exclusions and changes three things: the purpose says 'meet the tool lifecycle rule today and the tool support decision tree once it lands'; the scope adds 'setup-script creation or migration in the aitools repo' and 'which steps wait for the decision-tree machinery (M2)'; the managed-file exclusion now names '[a]ccept & adopt and [m]erge & adopt, which copy the deployed file or an AI merge back to the repo (the source of truth)'. Audience: 'any agent, in any repo'
- **Blocks:** TA-SKILL
- **Source:** FIX/S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md '## Intent'; .claude/rules/sources-of-truth.md 'Intent statements'

### TA-GLOSSARY (new): Approve the glossary entry 'tool adoption' (SD-3 named the skill; D-TS6 requires the disambiguation), so it can land with the skill ahead of the rest of the glossary batch?

- **Options:**
  - (a) Revised definition: "The /tool-adopt process that makes a managed tool supported on a platform and environment: an approved preferred method in the tool registry (running /tool-eval when there is none), the registry data its setup scripts need (after M2: the data the tool support decision tree reads), setup scripts in the aitools repo, installer and build integration, and verification. Runs after /tool-eval. Not the managed-file review choices '[a]ccept & adopt' and '[m]erge & adopt' (the deployed file, or an AI merge, copied back to the repo, the source of truth), and not framework 'adoption' (mapping a discipline's concepts into the harness)." Source: shared/skills/tool-adopt/SKILL.md; reference/tool-support-decision-tree.md (after M2). Plus the term line 'tool adoption' in .claude/rules/glossary.md
  - (b) The S4-Review draft definition unchanged
  - (c) Wait for the full glossary batch (rows R9, R10)
- **Recommendation:** (a)
- **Why:** The S4 draft says 'Not the managed-file [a]dopt choice or its accept & adopt outcome (local content written back to its source)'. Under the approved model there is no bare [a]dopt: the choices are [a]ccept & adopt and [m]erge & adopt, and both copy to the repo. The S4 draft also cites .claude/skills/tool-adopt/SKILL.md, which moves under TA-PLACE (a). Both files are protected (glossary.json via the /glossary skill, glossary.md is a rule)
- **Blocks:** TA-SKILL ship (the skill name needs its disambiguation, D-TS6); rows R9, R10 for this one term
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json terms_add['tool adoption']; mission packet section 6 (managed-file model); handoff D.3 SD-3; GATE/S3-Gate-drafts/reference/tool-support-decision-tree.md section 1 D-TS6

### TA-M2 (new): Which parts of /tool-adopt wait for M2?

- **Options:**
  - (a) As in the draft's 'Today and after M2' table: registry schema 1.1 fields (step 3), the decision-tree setup-script shape and tool_* helpers (step 4), generated tool specs and gen-tool-specs.py (step 5), the test matrix and the 'Tool support conformance' pre-commit step (step 6). Everything else ships now
  - (b) Ship nothing until M2
- **Recommendation:** (a)
- **Why:** Each M2 element is named with the condition that switches it on (reference/tool-support-decision-tree.md exists and /tool-registry reports schema 1.1), so the skill never tells an agent to run a script or check that does not exist yet. Until then, steps 3-6 follow the rules in force today (script-standards.md, tool-lifecycle.md 'Install cleanup')
- **Blocks:** TA-SKILL
- **Source:** FIX/S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md 'Today and after M2'; GATE/S3-Gate-drafts/reference/tool-support-decision-tree.md sections 6, 7.1, 9, 10

## (k) CONTEXT: approved, not questions

### CTX-SD: Approved in the prior session (SD-1..SD-8)

SD-1 D-DEL4; SD-2 one hook version in shared/hooks; SD-3 /tool-adopt name; SD-4 updateChannel default latest-stable; SD-5 non-preferred = HOLD non-interactive, menu replace/keep/abort (exit 2), unknown gets install alongside and is never removed; SD-6 [k]eep stored in profiles.&lt;alias&gt;.toolExceptions (shape pending = N-Q1); SD-7 profile.json is the source of truth, config.json derived, resolver order ending in none = ERROR; SD-8 tool-ops, tool-eval, tool-registry, harvest become user-level and registries move to user level (extension pending = items SD-8-ext, SD-8-reg).

Source: handoff 2026-10-21_360aa8f3-8.md section D.3

### CTX-DTS13: D-TS13 approved (2026-10-21): exit 2 is a user abort only with the abort marker

An [x]abort exits 2 AND writes an abort marker; runners treat exit 2 as a user abort only when the marker exists. Rev 5 section 7.5 names every launch site (the runners validate_and_run, Invoke-ValidatedScript, deploy_configs, Deploy-Configs, plus 'aitools user init' and bootstrap.sh/.ps1), has the first launch site in a run create the marker path and only it delete the file, defines that a script run without AITOOLS_ABORT_FILE still exits 2 but writes nothing (and its caller treats exit 2 as a failure), and has the entry point decide 'aborted' from the marker, never from deploy_configs' return value (an error count). The library half (write the line only when AITOOLS_ABORT_FILE is set) is mission SOURCE-TRUTH's.

Source: mission packet section 6; FIX/S3-GateFix-drafts/reference/tool-support-decision-tree.md section 7.5

### CTX-MF: Managed-file model approved (2026-10-21)

SOURCE is the source of truth; no ancestor, no deploy state. One review menu: [o]verwrite / [a]ccept & adopt / [m]erge & adopt (AI merge, text only) / [s]kip / [x]abort (unchanged, exit 2). Adopt and merge are copied to the repo immediately by the library. JSON is reviewed field by field and SOURCE owns every field. Before a write: back up; after: validate; on failure: restore, log, ERROR row, continue. Checked against it: rev 5 (T6 note 'force/non-interactive = overwrite', section 7.5 menu names, the section 7 helper-name note) and the tool-adopt, tool-eval, tool-registry and framework-tool-lifecycle drafts. The tool-adopt draft and the 'tool adoption' glossary text said '[a]dopt' and were fixed (TA-SKILL, TA-GLOSSARY). /tool-eval, /tool-registry and the framework draft do not describe adopt or merge. One mirror still conflicts: known defect E-mdc-model.

Source: mission packet section 6; .claude/worktrees/mfchoices/.claude/rules/agentic-standards.md 'Managed-file review choices and merge' (branch docs/managed-file-choices, not merged)

## (a) BLOCKING: decide at the gate

### N-Q1: toolExceptions: which shape, who owns it, and who writes it?

- **Options:**
  - (a) {decision:"keep", detected:{platform, method, path, version}, decidedAt, decidedBy, reason}; shape owned by reference/user-repo.md; tree section 8 owns when it is written, read and matched; writer and reader = aitools-profile.js exception-set / exception-get
  - (b) M2 shape {decision, method, path, platform, environment, decided, by, note}, read and written with perl JSON::PP / ConvertFrom-Json
  - (c) M3 shape as drafted {decision, detected:{method, path, version}, decidedAt, reason}
- **Recommendation:** (a)
- **Why:** One owner, and one write path for a shared, git-tracked file in both shells (temp, validate, backup, move, like register). Node is present whenever a dotprofile exists. (b) fails on minimal Linux (perl-base has no JSON::PP) and ConvertTo-Json reformats the file. (c) has no platform and uses install kinds that never match T5
- **Blocks:** Gate; SD-6 pending half; X-B1; M2 B2/B3
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 1 X1, X3, X4 and section 3 N-Q1; handoff 2026-10-21_360aa8f3-8.md D.3 SD-6; GATE/S3-Gate-drafts/reference/tool-support-decision-tree.md section 8

### D-TS10: A recorded tool exception (KEEP, EXCEPTION): report OK or WARN?

- **Options:**
  - OK &lt;ver&gt; (kept)
  - WARN &lt;ver&gt; (kept)
- **Recommendation:** OK &lt;ver&gt; (kept)
- **Why:** The user decided it, so it is not a caveat, and a permanent WARN trains people to ignore WARN. It departs from F3 ('kept as-is is WARN') for recorded exceptions only; HOLD, REPLACE-FAIL and REPLACE-BLOCKED stay WARN
- **Blocks:** Gate; tree section 3; script-standards-detail edits 3-4 (row 16)
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 (T-Q2 = D-TS10); MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q2

### D-TS11: SHADOWED (the command resolves to another copy that runs): ERROR or WARN?

- **Options:**
  - ERROR shadowed (see log) + ACTION
  - WARN
- **Recommendation:** ERROR
- **Why:** 'Supported' means the command resolves to the managed copy (tooling-resolution plan decision 10). WARN is how the python shadow went unnoticed. Needs the severity-guide line in script-standards-detail.md (row 16 edits 2-3)
- **Blocks:** Gate; tree section 3; tool-lifecycle.md item 6; row 16
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 (T-Q10 = D-TS11); plans/tooling-resolution-and-artifact-registry.md 'Confirmed decisions' 10

### D-TS12: A platform whose registry status is still 'evaluating': WARN or ERROR?

- **Options:**
  - WARN under evaluation + ACTION run /tool-eval
  - ERROR
- **Recommendation:** WARN
- **Why:** Nothing the user caused is broken. ERROR would fire on every Linux run for node
- **Blocks:** Gate; tree T0 and section 3
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 (T-Q11 = D-TS12)

### D-TS13 (changed): NEW from the A/B pass: should exit 2 count as a user abort only when an abort marker file exists?

- **Status:** APPROVED -- Commander, 2026-10-21 (mission packet section 6). Rev 5 section 7.5 applies it to every launch site, including deploy_configs / Deploy-Configs, aitools user init and bootstrap. No answer needed.
- **Options:**
  - (a) Installers export AITOOLS_ABORT_FILE. Every [x]abort (tool menu and managed-file menus) writes it, then exits 2. Exit 2 without the marker = ordinary failure (ERROR row, run continues). No helper uses return code 2
  - (b) Bare exit 2 = abort, as in rev 3
  - (c) A different exit code for abort (for example 77)
- **Recommendation:** (a)
- **Why:** Measured on /bin/bash 3.2: under set -e, a script exits 2 when grep or diff fail, when a function returns 2, and when a sourced file (a malformed generated tool spec) has a syntax error. With (b), those ordinary failures stop the whole install and print 'aborted by user'. (c) still collides with any command that exits 77 and changes the documented managed-file contract. A marker is unambiguous in bash and PowerShell. It refines SD-5 ('exit 2, stops the run'); it does not reverse it
- **Blocks:** Gate; M2 B4a/B4b (installers, entry points); the fix for incident draft #87; row 16 edit 6
- **Source:** GATE/S3-Gate-B-review.md B-01 and probe table; GATE/S3-Gate-drafts/reference/tool-support-decision-tree.md section 7.5

### REV4: Approve decision tree rev 4 (rev 3 plus the A/B blocker and major fixes) as the version that lands as reference/tool-support-decision-tree.md?

- **Status:** SUPERSEDED -- by REV5 (S3-GateFix): rev 5 = rev 4 plus the PR #58 review fixes and the S3-GateFix-B fixes. No answer needed.
- **Options:**
  - Approve rev 4
  - Approve rev 3 and treat rev 4 changes as follow-ups
  - Send back with changes
- **Recommendation:** Approve rev 4
- **Why:** Rev 3 has one blocker (B-01 exit 2) and 9 majors that implementers would hit. Examples: the brew-formula probe can never match (brew --prefix prints the opt symlink), RP cannot be evaluated, replace skips the build-prereq gate, a dry run reports ERROR for every tool it would install, and Windows bash resolves to WSL. Rev 4 adds one schema field (resolveBy) and one proposed decision (D-TS13). The intent statement is unchanged
- **Blocks:** Gate row R1; every M2 batch
- **Source:** GATE/S3-Gate-rev4-changelog.md; GATE/S3-Gate-A-review.md; GATE/S3-Gate-B-review.md

### REV5 (new): Approve decision tree rev 5 (rev 4 plus the PR #58 review fixes and the independent B-pass fixes) as the version that lands as reference/tool-support-decision-tree.md?

- **Options:**
  - Approve rev 5
  - Approve rev 4 and treat rev 5 changes as follow-ups
  - Send back with changes
- **Recommendation:** Approve rev 5
- **Why:** Rev 4 made only the installers export the abort marker. Most managed-file [x]abort choices happen in setup-user-* scripts launched by deploy_configs (plain 'aitools' and 'aitools gitpull'), which exported nothing, so an abort there would still be an ERROR 'script failed (exit 2)' and the run would continue. Rev 5 covers every launch site (the four runners, plus 'aitools user init' and bootstrap, found by S3-GateFix-B), defines the unset-marker case, keeps the entry point from reading deploy_configs' error count as an abort, and fixes the generator wording. It also merges the B-pass majors: bash helpers return results in globals, not on stdout (a $(...) subshell dropped WARNINGS and TOOL_UPDATE_STATE in a probe); Windows T2/T7/RP use the persistent PATH; RP compares file identity (-ef) and realpaths use /bin/realpath, because perl abs_path keeps the caller's case on APFS. The intent statement is unchanged
- **Blocks:** Gate row R1; every M2 batch
- **Source:** FIX/S3-GateFix-rev5-changelog.md; FIX/S3-GateFix-B-review.md; scripts/aitools deploy_configs ('return $errors'); scripts/aitools.ps1 Deploy-Configs

### N-Q3: Glossary renames from M3: keep 'machine identity' and 'derived config', or rename them to 'machine id' and 'aitools config'?

- **Options:**
  - Rename to machine id / aitools config
  - Keep machine identity / derived config
- **Recommendation:** Rename
- **Why:** profile.json 'identity' already means the user. 'derived' is not a scope modifier, so the composed form fails /audit (reference/framework-governed-vocabulary.md)
- **Blocks:** Gate (glossary batch, rows R9-R10)
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 N-Q3; MISSIONS/S4-Review/S4-Review-C-review.md C-15, C-17

### T-Q1 (changed): How do setup scripts get registry data?

- **Options:**
  - (A) generated, committed spec files in generated/tool-specs/; only the agent making an approved registry write runs the generator; pre-commit check 7 regenerates into a temporary directory and compares; build-deploy embedding for MDM is deferred (X-B4)
  - (B) parse the JSON at run time
  - (C) hard-coded values plus a pre-commit compare
- **Recommendation:** (A), with (C) as the stopgap for batches that land before the generator
- **Why:** One source; MDM deploy scripts stay self-contained; registry text is never evaluated. (B) fails on minimal Linux. build-deploy, the installers and the setup scripts never run the generator, so 'aitools' still syncs on a machine without harness python (S3-Gate-B B-06). Rev 5 fixes the rev 4 wording that said the generator 'runs only when registry data changes' while check 7 runs it on every commit, and drops 'embedded by build-deploy.sh' from the spec header (PR #58 review finding 3). Needs the git-safety.md edit (row R15)
- **Blocks:** Gate; M2 B1
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q1; MISSIONS/S4-Review/S4-Review-report.md section 3 T-Q1; GATE/S3-Gate-drafts/reference/tool-support-decision-tree.md section 7.1

### T-Q9: Where is the tool registry schema documented?

- **Options:**
  - Reference section 'Tool registry schema 1.1' only (skills and registry meta point to it)
  - In the rule
  - In the /tool-registry skill
- **Recommendation:** Reference only; amend framework-three-layer-governance.md 'Schema' separately
- **Why:** A single authority. C-08 showed the skills restated the schema and contradicted it; S3-Gate's copies of the skills now only point to it
- **Blocks:** Gate
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q9; GATE/S3-Gate-drafts-fixes.md

### P-Q1: Where do company and name live in profile.json?

- **Options:**
  - identity-level defaults plus per-profile overrides
  - per-profile only
- **Recommendation:** identity.company = "nobul-tech", identity.name = "Jose". Delete the per-profile Nobul / nobul.tech / pepe values only after all 3 machines run 2.1 code
- **Why:** Matches the GitHub org and CLAUDE.md. Older code still reads the per-profile company
- **Blocks:** M3 B10
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q1; MISSIONS/S5-Profile/S5-Profile-report.md section 8

### P-Q2: Hash machine ids before storing them in git?

- **Options:**
  - HMAC-SHA256 with fixed key aitools-machine-id-v1
  - raw ids
- **Recommendation:** HMAC-SHA256, key aitools-machine-id-v1
- **Why:** No raw hardware ids in a git repo; still deterministic. Windows MachineGuid and Linux /etc/machine-id reads are UNVERIFIED (handoff G15)
- **Blocks:** Gate; M3 B1
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q2

### P-Q3: Machine resolver: one JS module, or native bash plus PS1?

- **Options:**
  - One JS module (aitools-profile.js)
  - Native bash and PowerShell
- **Recommendation:** JS
- **Why:** One definition, and build-deploy can call it. It needs node, which deploy already needs. N-Q1 (a) extends the same module to tool exceptions
- **Blocks:** Gate; M3 B1
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q3

### P-Q8..Q11: MDM and build-deploy batch: approve the four answers together?

- **Options:**
  - Approve all four as recommended
  - Answer individually: P-Q8 MDM template, P-Q9 corrupt profile.json, P-Q10 deploy read-only, P-Q11 MDM without node
- **Recommendation:** Approve all four. P-Q8: build-deploy switches deploy/ to the dotprofile template (M3 B5). P-Q9: a corrupt profile.json fails the build (exit 1); a corrupt config.json is skipped with WARN. P-Q10: deploy/ is read-only (USER_REPO_PATH="" after resolving); MDM endpoints never push. P-Q11: without node, MDM uses identity-level strings, WARNs for an unregistered machine in deploy/ only, and documents AITOOLS_MACHINE_ALIAS
- **Why:** Dev and MDM output must match (deploy-paths.md). A corrupt source of truth is a real error, while config.json must stay repairable. Unregistered MDM endpoints would otherwise ERROR on every run
- **Blocks:** M3 B5
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q8, P-Q9, P-Q10, P-Q11

### S2L-QA: S2-Layout Q-A: when a skill moves level, git mv it (no copies), or keep both copies?

- **Options:**
  - git mv, never two copies
  - keep both
- **Recommendation:** git mv
- **Why:** Claude Code resolves a shared name as personal over project, so the deployed (often stale) copy wins. documentation-standards.md already forbids same-name skills at both levels, and symlinks don't help on Windows. Cost: Claude Code web loses project-level loading of those skills; test V5 before PR-b merges
- **Blocks:** PR-b
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 4 Q-A

### S2L-QB: S2-Layout Q-B (= S2-Layout section 6 Q2): approve the protected spec in S2-Layout-evidence E6 (path map) and E7 (drafts D1-D6) up front as the review step, then ship 3 small PRs?

- **Options:**
  - Approve E6/E7 now; the delegate ships exactly that content; anything beyond comes back as a draft
  - Draft PR with the protected edits
  - Drafts first, separate approval per PR
- **Recommendation:** Approve E6/E7 now
- **Why:** An unprotected-only PR would leave rules pointing at moved files; that one-pass failure left 52 stale paths after v0.69.0. One big PR goes against smaller batches. The PR review is a second check, not the approval
- **Blocks:** PR-b (and PR-c)
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 4 Q-B, section 6 Q2; MISSIONS/S2-Layout/S2-Layout-evidence.md E6, E7

### S2L-Q1 (changed): Do audit and governed-data stay project-level?

- **Change:** S3-Gate's first option also kept /tool-adopt project-level; that is now item TA-PLACE
- **Options:**
  - Keep audit and governed-data project-level (/tool-adopt placement is item TA-PLACE)
  - Move all 9 skills to shared/
- **Recommendation:** Keep them project-level
- **Why:** They only make sense inside the aitools tree (naming rule N3). 'Move all 9' adds 2 skills to PR-b batch 3
- **Blocks:** PR-b batch 3
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 6 Q1

### S2L-Q3: Delete the 9 untracked shared/skills copies before any aitools run?

- **Options:**
  - Already done: no action
  - Re-check
- **Recommendation:** Already done: no action
- **Why:** Verified 2026-10-21: ls /Users/new-jose/repos/aitools/shared/skills lists 14 entries and none of the 9 copies (audit, frameworks, glossary, governed-data, harvest, incident, tool-eval, tool-ops, tool-registry). Handoff exclusion F1 no longer applies
- **Blocks:** nothing (was: any aitools run)
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 6 Q3; handoff G1; ls output in this mission

### S2L-Q4: If PR-b check V5 fails (Claude Code web does not list the user-level skills), how does Claude Code web get them?

- **Options:**
  - claude.ai account skills for the moved skills
  - Keep project copies
  - An environment setup script that installs before session start
- **Recommendation:** claude.ai account skills; never keep project copies
- **Why:** Keeping copies breaks the one-name rule (N2) and brings back the shadowing problem
- **Blocks:** PR-b merge (only if V5 fails)
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 6 Q4

### S2L-Q5: Rename shared/ (for example to user/ or home/)?

- **Options:**
  - Not now; revisit after PR-b with an rc-rewrite fix
  - Rename to user/ now
- **Recommendation:** Not now
- **Why:** The installer never rewrites the shell rc source line, so a rename breaks every shell startup (aitools-install.sh lines 614-628). It touches about 89 files, and 'user' already has two meanings
- **Blocks:** nothing now
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 3 option B, section 6 Q5

### S2L-Q6: Does tool-versions.json (no skill, hand-edited) move with the registries?

- **Options:**
  - Yes, into shared/registries/; give it a governing skill later
  - No
- **Recommendation:** Yes
- **Why:** All governed data then lives in one place. It is already stale (handoff C.1)
- **Blocks:** PR-b batch 2
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 6 Q6

### SD-8-ext: SD-8 pending half (1): do incident, glossary and frameworks also move to user level (shared/skills/)?

- **Options:**
  - Yes, with the 4 already approved (7 total)
  - No, only the 4 approved in SD-8
- **Recommendation:** Yes
- **Why:** They are used in every repo: harvest runs everywhere, and /investigate and the glossary hook route to them. Today 4 of the 7 cite dead reference/*.json paths
- **Blocks:** PR-b batch 3
- **Source:** handoff D.3 SD-8; MISSIONS/S2-Layout/S2-Layout-report.md section 2 and section 3 'Recommended structure'

### SD-8-reg: SD-8 pending half (2): registries at shared/registries/, read through the deployed aitools-registry.py resolver (live clone, then the ~/.aitools/registries/ read-only snapshot, then 'unavailable')?

- **Options:**
  - Approve shared/registries + aitools-registry.py
  - Registries move, no resolver
  - Registries stay in registries/
- **Recommendation:** Approve
- **Why:** No consumer can reach a registry from another repo today (all paths are cwd-relative). The resolver gives user-level skills a path, a read-only fallback, and next-id for incidents.json (2,027 lines, over Read's default)
- **Blocks:** PR-b batches 1-2; row R8 sibling impact
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 3 'Registries (L2)'; MISSIONS/S2-Layout/S2-Layout-B-registry-consumers.md section 0

### C.1: Does M2 absorb tooling-resolution Workstream A?

- **Options:**
  - Yes: M2 absorbs Workstream A's resolver and verification scope (A5 resolver, the decision-10 verification gate via tree T7). B (tool-ops for every tool) and C (artifact registry) stay as separate later work
  - No: M2 and Workstream A stay separate
  - M2 absorbs all of A, including A1-A4 and A6-A8 (setup-user-shell, login-profile PATH block, agent symlink)
- **Recommendation:** Yes, first option
- **Why:** M2's T7 is the resolution verification that decision 10 requires, so keeping A5 separate would build two post-checks. The PATH-ownership half of A (A1-A4, A6-A8) is still needed before M4 node can replace (keg-only node@22 off PATH ends at REPLACE-BLOCKED), but it is shell work with its own reference (A8). I suggest keeping it in the tooling-resolution plan and sequencing it before M2 B18+
- **Blocks:** Gate; ROADMAP.md row 'Managed-tool resolution + artifact registry' (protected) update
- **Source:** handoff C.1; ROADMAP.md In Progress row 2; plans/tooling-resolution-and-artifact-registry.md 'Workstream A', 'Confirmed decisions' 10

### C-SEQ: Sequencing of S2-Layout PR-b against the M2 skill and registry edits?

- **Options:**
  - PR-a, then PR-b, then the M2 skill/registry edits retargeted to shared/ paths
  - M2 first, then PR-b moves the edited skills
  - In parallel
- **Recommendation:** PR-a, then PR-b, then M2
- **Why:** PR-b moves .claude/skills/tool-eval, tool-registry and registries/ to shared/. M2 drafts target the old paths; landing M2 first means editing the same protected files twice. PR-a is independent and lowers risk for both
- **Blocks:** M2 B1 and every skill write; PR-b
- **Source:** handoff E step 5; MISSIONS/S2-Layout/S2-Layout-report.md section 5 'Sibling-mission impacts'

### PR-a: Approve the protected-file path fixes that S2-Layout PR-a batch 2 makes (the stale reference/*.json paths in S2-Layout-B tables 1.1-1.5)?

- **Options:**
  - Approve: the fixes are path repoints only (reference/&lt;x&gt;.json to registries/&lt;x&gt;.json, or the governing skill), no meaning change
  - Approve per file
  - Reject
- **Recommendation:** Approve as path repoints
- **Why:** Protected files in that set: .claude/skills/{glossary, incident, frameworks, audit, tool-ops}/SKILL.md; shared/skills/{optimize-plan, intent-audit}/SKILL.md; .cursor/rules/{sources-of-truth, documentation-standards, tool-lifecycle}.mdc; ROADMAP.md line 28; registries/framework-registry.json line 183. Unprotected: scripts/check-post-push.ps1 lines 268, 520; shared/hooks/tool-ops-session-audit.sh; scripts/setup-bash.sh/.ps1 headers; reference/post-push-checklist.md, path-targeted-hooks-analysis.md. If PR-b is approved, files that PR-b moves should be repointed once, to the resolver or the skill, not twice. PR-a then takes only the files PR-b does not touch. Closes #84 and part of #59 and #70
- **Blocks:** PR-a
- **Source:** MISSIONS/S2-Layout/S2-Layout-B-registry-consumers.md tables 1.1-1.5; MISSIONS/S2-Layout/S2-Layout-report.md section 5 PR-a

## (b) PROTECTED-FILE BATCH: approve each row's draft

| Id | Row | State | Draft status | Options | Recommendation | Blocks | Draft |
|---|---|---|---|---|---|---|---|
| R1 (changed) | reference/tool-support-decision-tree.md (new; new intent) | drafted | drafted by S3-GateFix (rev 5; intent unchanged from rev 3) | approve the draft / approve with changes / reject | approve rev 5 (see REV5) | every M2 batch | FIX/S3-GateFix-drafts/reference/tool-support-decision-tree.md (+ .rev4-to-rev5.diff; FIX/S3-GateFix-rev5-changelog.md) |
| R2 | .claude/rules/tool-lifecycle.md (rewrite; modified intent) | drafted | drafted (S4-Review fixes C-06, C-09, C-10, C-12, C-13, C-26, C-27, C-31). Consistent with rev 4: item 4 says replace installs the preferred method first; rev 4 adds a prereq check before that install, which is detail in the reference | approve the draft / approve with changes / reject | approve | M2 B1+ | MISSIONS/S4-Review/S4-Review-drafts/dot-claude/rules/tool-lifecycle.md |
| R3 | reference/framework-tool-lifecycle.md (edit; modified intent) | drafted | drafted by S3-Gate (fixed copy: C-09, C-13, C-23, C-26, C-27, C-33) | approve the draft / approve with changes / reject | approve | M2 docs | GATE/S3-Gate-drafts/reference/framework-tool-lifecycle.md (+ .s5-to-s3gate.diff) |
| R4 (changed) | tool-adopt SKILL.md (new; new intent). Now proposed at shared/skills/tool-adopt/ (section ta) | drafted | revised by S3-GateFix for the early ship; decided by items TA-PLACE, TA-SKILL, TA-INTENT | approve the draft / approve with changes / reject | answer in section ta | M2 B5+ | FIX/S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md (+ .s3gate-to-s3gatefix.diff) |
| R5 | tool-eval SKILL.md (edit; modified intent) | drafted | drafted by S3-Gate (fixed copy: C-08, C-09, C-22, C-28). The path moves under PR-b | approve the draft / approve with changes / reject | approve; land at shared/skills/tool-eval/ after PR-b (C-SEQ) | M2 B1 | GATE/S3-Gate-drafts/dot-claude/skills/tool-eval/SKILL.md (+ .s5-to-s3gate.diff) |
| R6 | tool-registry SKILL.md (edit; modified intent) | drafted | drafted by S3-Gate (fixed copy: C-08, C-28; names rev 4's resolveBy) | approve the draft / approve with changes / reject | approve; land at shared/skills/tool-registry/ after PR-b, with the registry path read through aitools-registry.py | M2 B1 | GATE/S3-Gate-drafts/dot-claude/skills/tool-registry/SKILL.md (+ .s5-to-s3gate.diff) |
| R7 (changed) | .claude/rules/interactive-menus.md (edit; new intent) | drafted | drafted (S4 merge of M2 and M3). D-TS13 is approved, so at write time the 'Tool install-method menu' sentence 'Exit 2 from a setup script means user abort only' becomes '... means user abort only when the abort marker is written (reference "Contract with the installers and entry points")' | approve the draft / approve with changes / reject | approve with the abort-marker sentence | M2 B2/B3; M3 B6/B7 | MISSIONS/S4-Review/S4-Review-drafts/dot-claude/rules/interactive-menus.md |
| R8 | .claude/rules/sources-of-truth.md (edit; new intent) | drafted | drafted (S4). Sibling impact: once PR-b is approved, the registry rows must list shared/registries/ paths (or cite the governing skills, closing #50), and the tool-eval/tool-registry skill rows must move to shared/skills/ | approve the draft / approve with changes / reject | approve with the S2-Layout section 5 sibling change if SD-8-reg is approved | Gate | MISSIONS/S4-Review/S4-Review-drafts/dot-claude/rules/sources-of-truth.md; MISSIONS/S2-Layout/S2-Layout-report.md section 5 'Sibling-mission impacts' |
| R9 | .claude/rules/glossary.md (7 term lines) | drafted | drafted (S4) | approve the draft / approve with changes / reject | approve together with section c | glossary batch | MISSIONS/S4-Review/S4-Review-drafts/dot-claude/rules/glossary.md |
| R10 | registries/glossary.json (7 terms added, managed tool modified) | drafted | drafted (S4); one inconsistency (known defect E-glossary-1) | approve the draft / approve with changes / reject | approve with the fix in E-glossary-1 | glossary batch | MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json |
| R11 | registries/tool-registry.json schema 1.1 (+ node/go illustrative entries; modified meta.intent) | drafted | drafted (S5-Tools); the node values are ILLUSTRATIVE and _unverified (the draft says so). The node linux status change is an M4 decision | approve the schema and meta.intent; entries only after /tool-eval / approve with changes / reject | approve the schema and meta.intent; node and go values only after /tool-eval verifies them | M2 B1 | MISSIONS/S5-Tools/S5-Tools-drafts/registries/tool-registry.schema-1.1-draft.json |
| R12 | registries/framework-registry.json (Tool lifecycle entry) | drafted | drafted (S5-Tools) | approve; write only once every listed path exists / reject | approve; write after the paths exist | after M2 B1-B3 | MISSIONS/S5-Tools/S5-Tools-drafts/registries/framework-registry.tool-lifecycle-entry-draft.json |
| R13 | .claude/rules/managed-file-deployment.md (2 edits) | drafted | drafted (S4 edit file: resolver order replaces 'first profile'; dangling pointer retargeted to /tool-adopt step 5) | approve the draft / approve with changes / reject | approve | M3 B9 | MISSIONS/S4-Review/S4-Review-drafts/dot-claude/rules/managed-file-deployment.md.edit.txt |
| R14 | .cursor/rules/managed-file-deployment.mdc, interactive-menus.mdc, tool-lifecycle.mdc (mirrors) | drafted | drafted by S3-Gate. managed-file-deployment.mdc: the 2 edits of row 13. interactive-menus.mdc: tool menu and registration menu paragraphs. tool-lifecycle.mdc: rewritten to mirror row 2 and keep the 3 Cursor-only sections (cross-platform vetting, MCP isolation, MCP disable scope). It drops 'Lifecycle field completeness' (it cited reference/tool-registry.md and a stale reference/tool-versions.json path) and 'Dotprofile priority' (moved to /tool-adopt) | approve the drafts / approve with changes / reject | approve | with rows 2, 7, 13 | GATE/S3-Gate-drafts/dot-cursor/rules/ |
| R15 | .claude/rules/git-safety.md (generated/ is generated and tracked) | drafted | drafted by S3-Gate. generated/ is never hand-edited and regenerated only with its source; NOT in the pre-pull reset (nothing rewrites it during a run) | approve the draft / approve with changes / reject | approve | M2 B1 | GATE/S3-Gate-drafts/dot-claude/rules/git-safety.md |
| R16 (changed) | reference/script-standards-detail.md (6 edits) | drafted | drafted by S3-Gate; edit 6 reworded by S3-GateFix (PR #58 review finding 2). Platform skip row and outcome; tool helper row; SHADOWED severity line (D-TS11); KEEP OK and the ACTION-pairing exception (D-TS10); tool-support detail templates pointer; exit-2 exception to the exit footer (D-TS13, approved) | approve the edits / approve with changes / reject | approve, dropping the lines of any rejected pending decision (D-TS10, D-TS11, D-TS12, T-Q12) | M2 B2/B3 | FIX/S3-GateFix-drafts/reference/script-standards-detail.md.edit.txt |
| R17 | shared/skills/aitool-eval/SKILL.md (refresh derived card) | void | void if PR-c is approved. S2-Layout PR-c folds the card's unique sections into /tool-eval and the playbook, then deletes it. Not drafted; it needs a draft only if PR-c is rejected | void: PR-c retires the card / draft a refresh (only if PR-c is rejected) | void | nothing (PR-c) | MISSIONS/S2-Layout/S2-Layout-report.md section 5 PR-c |
| R18 | reference/user-repo.md (rewrite; new intent; owns the toolExceptions shape) | drafted | drafted (S4). Not re-reviewed by S3-Gate (outside this mission's lens) | approve the draft / approve with changes / reject | approve together with N-Q1 (a) | M3 B9; X-B1 | MISSIONS/S4-Review/S4-Review-drafts/reference/user-repo.md |
| R19 | shared/claude-shared.md + dotprofile claude/CLAUDE.md (Cross-Platform Awareness lines) | drafted | drafted (S5-Profile edit file) | approve the draft / approve with changes / reject | approve | M3 B9 | MISSIONS/S5-Profile/S5-Profile-drafts/shared/claude-shared.md.edit.txt |
| R20 | .claude/rules/deploy-paths.md (setup-user-claude row; aitools-profile.js auto-embedded) | text-only | drafted as text in the S5-Profile report section 5 (no separate file) | approve the text / approve with changes / reject | approve; also add generated/tool-specs to 'What IS auto-embedded' when X-B4 lands | M3 B5 | MISSIONS/S5-Profile/S5-Profile-report.md section 5 (lines starting 'deploy-paths.md') |
| R21 | .claude/rules/config-file-safety.md (reference example) | text-only | drafted as text in the S5-Profile report section 5 | approve the text / reject | approve | M3 B3 | MISSIONS/S5-Profile/S5-Profile-report.md section 5 (line starting 'config-file-safety.md') |
| R22 | code intents for scripts/aitools-profile.js, scripts/setup-user-config.sh/.ps1, lib section intents (both libs) | drafted | drafted (S5-Profile drafts) | approve the drafts / approve with changes / reject | approve | M3 B1-B3 | MISSIONS/S5-Profile/S5-Profile-drafts/scripts/ |
| R23 | meta.intent of ~/.aitools/config.json (in the writers) and dotprofile profile.json | drafted | drafted (S5-Profile writer; S4 profile.json audience fix) | approve the drafts / approve with changes / reject | approve; re-derive profile.json from the live file (X17), do not copy the draft | M3 B10 | MISSIONS/S5-Profile/S5-Profile-drafts/scripts/setup-user-config.sh; MISSIONS/S4-Review/S4-Review-drafts/dotprofile/profile.json |
| R24 | registries/incidents.json (27 new entries #87-#113 + affected updates) | carved-out | carved out. Mission LEDGER (S3-Ledger, branch docs/incidents-87-plus) owns incident filing this session. S3-Gate adds three INCIDENT markers for LEDGER's triage (see the S3-Gate result) | carved out to mission LEDGER | carved out | nothing in this gate | MISSIONS/S4-Review/S4-Review-incidents-draft.json; GATE mission brief |
| R25 | intent headers for the 26 migrated tool setup scripts (M2 B5-B17) | drafted | drafted by S3-Gate (template, per-script table, one filled example). Approving it lets each batch be delegated with an approved intent (D-TS9) | approve the template and table / approve with changes / draft per batch instead | approve the template and table | M2 B5-B17 | GATE/S3-Gate-drafts/S3-Gate-row25-setup-script-intents.md |

### R-S2L5: S2-Layout section 5 sibling impact: after PR-b, should the sources-of-truth.md draft (row 8) list the registries at shared/registries/ and cite the skills instead of JSON paths?

- **Options:**
  - Yes (fold into row 8)
  - No
- **Recommendation:** Yes
- **Why:** It keeps the protected list true after PR-b, and citing skills closes incident #50 (rules must not name governed JSON paths)
- **Blocks:** row 8 final text
- **Source:** MISSIONS/S2-Layout/S2-Layout-report.md section 5 'Sibling-mission impacts'

## (c) GLOSSARY decisions

### C-14: Govern 'detection signature' for the tool registry field (typed probes that identify an install method), separate from the governed 'detection' (the hook layer)?

- **Options:**
  - (a) Govern 'detection signature'; keep the JSON key 'detection'
  - (b) Leave 'detection' overloaded
  - (c) Rename the JSON key
- **Recommendation:** (a)
- **Why:** The rule draft already says 'detection signatures'. The framework doc uses both meanings in one list. Renaming the key churns data and scripts. This also closes open glossary item 2 ('detection')
- **Blocks:** glossary batch; the wording in rows 1, 3, 6
- **Source:** MISSIONS/S4-Review/S4-Review-C-review.md C-14; MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json open_glossary_items[1]

### G-provenance: 'provenance' is governed as an aitools component, but tool documents say 'provenance verification' (supply chain) and code says 'provenance' for install origin. What to do?

- **Options:**
  - (a) Keep 'provenance' for the component; use 'install class' for install origin (as the drafts do) and add a disambiguation sentence to the provenance definition
  - (b) Govern 'install provenance' as a second term
- **Recommendation:** (a)
- **Why:** The drafts already avoid the word for install origin. detect_go_provenance / Get-GoProvenance are replaced by tool_detect_method in M2
- **Blocks:** glossary batch
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json open_glossary_items[0]; MISSIONS/S5-Tools/S5-Tools-report.md I-20

### G-verified: knownPaths entry field 'verified' (a date and version trial record) vs the governed outcome 'verified': rename or keep and define? (= N-Q4)

- **Options:**
  - Keep the field and define it in tree section 6
  - Rename the field (for example 'trialled')
- **Recommendation:** Keep and define (already in rev 3 and rev 4 section 6)
- **Why:** No churn; the meaning is tied to script-standards 'KnownPaths empirical verification'
- **Blocks:** M2 B1
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json open_glossary_items[2]; S4-Review-C-review.md C-18

### G-recovered: The deployment outcome 'recovered' (setup-user-config, user-repo.md 'Config Schema (v3)') is not governed, while created, updated and verified are. Govern it?

- **Options:**
  - Govern 'recovered' with the M3 batch
  - Map it to an existing outcome
- **Recommendation:** Govern it, with the definition taken from the approved user-repo.md 'Config Schema (v3)' text
- **Why:** It names a distinct state (config.json rebuilt after it was found missing or unreadable). Its exact wording is M3's; S3-Gate did not review user-repo.md
- **Blocks:** M3 B3 summary text
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json open_glossary_items[3]

### G-terms: Approve the 7 proposed terms (tool adoption, tool exception, update channel, machine profile, machine alias, machine id, aitools config) and the modified 'managed tool'?

- **Options:**
  - Approve with the E-glossary-1 fix
  - Approve as drafted
  - Revise
- **Recommendation:** Approve with the E-glossary-1 fix
- **Why:** One batch for both missions. The renames depend on N-Q3
- **Blocks:** glossary batch (rows R9, R10)
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json terms_add, terms_modify

### G-profile: 'profile' has three ungoverned meanings (shell profile, profile.json, machine profile). Add a governed disambiguation?

- **Options:**
  - Rely on the 'machine profile' definition ('Not a shell profile')
  - Govern 'profile' itself
- **Recommendation:** Rely on the machine profile definition for now
- **Why:** The new definition already separates the two meanings that collide in these missions. A standalone 'profile' entry can follow if /audit flags it
- **Blocks:** nothing
- **Source:** MISSIONS/S4-Review/S4-Review-C-review.md 'INCIDENT / TODO(glossary) findings'

### G-userconfig: The composition example 'user config' resolves only to ~/.claude/settings.json, while ~/.aitools/config.json is also a user-deployed config. Fix the example?

- **Options:**
  - Keep 'user config' = settings.json and say so; ~/.aitools/config.json = 'aitools config'
  - Widen 'user config' to both files
- **Recommendation:** Keep it narrow and name 'aitools config' beside it
- **Why:** Widening it makes the composed term ambiguous; 'aitools config' (N-Q3) already names the other file
- **Blocks:** nothing
- **Source:** MISSIONS/S4-Review/S4-Review-C-review.md C-17 and TODO(glossary) list; reference/framework-governed-vocabulary.md 'Examples'

## (d) NON-BLOCKING: pre-answer before the named batch

### T-Q3: [x]abort scope: the whole run or only this tool?

- **Options:**
  - Answered by SD-5: the whole run (exit 2)
- **Recommendation:** Answered by SD-5 (whole run). D-TS13 (approved 2026-10-21) refines how exit 2 is recognised
- **Why:** SD-5 approved '[x]abort (exit 2, stops the run)'
- **Blocks:** M2 B4a/B4b
- **Source:** handoff D.3 SD-5; MISSIONS/S4-Review/S4-Review-report.md section 3 T-Q3

### T-Q4: Keep automatic fallback methods (modal pip, datadog cargo on macOS)?

- **Options:**
  - Remove them; a missing manager = PREREQ ERROR + ACTION
  - Keep
- **Recommendation:** Remove
- **Why:** Fallbacks install non-preferred methods without a decision (tool-evaluation.md governing principle). Cargo stays where it is the preferred method (datadog Windows)
- **Blocks:** M2 B10, B14
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q4

### T-Q5: Below minVersion (bash < 5.0, perl < 5.010): ERROR or WARN?

- **Options:**
  - ERROR + ACTION
  - WARN
- **Recommendation:** ERROR + ACTION
- **Why:** The harness cannot run on it; today's WARN hides a broken environment
- **Blocks:** M2 B15, B16
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q5

### T-Q6: Must verification query upstream for the channel's newest version number?

- **Options:**
  - No; the update command is the mechanism
  - Yes
- **Recommendation:** No
- **Why:** Querying differs per manager and is unreliable. Revisit if health flags need it
- **Blocks:** nothing
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q6

### T-Q7: Resolve the reference/tool-registry.md duplication how?

- **Options:**
  - JSON canonical; banner now; generator later (same for tool-versions.json)
  - Keep both hand-edited
- **Recommendation:** JSON canonical; banner now; generator later
- **Why:** The md has drifted (for example the vercel versions), yet checks parse it. Covered by incident #21 (extend it)
- **Blocks:** later batch
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q7

### T-Q8: Protect all project skills in sources-of-truth.md?

- **Options:**
  - All, as a separate decision, after the skill layout is settled
  - The three tool skills only
- **Recommendation:** All, as a separate decision after PR-b
- **Why:** Skill intents are already protected, but the table does not say so (incident draft #102)
- **Blocks:** after PR-b
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 T-Q8

### T-Q12: Platform-level n/a row: a new write_platform_skip, or reuse the environment helper?

- **Options:**
  - New platform variant (write_platform_skip / Write-PlatformSkip, n/a (&lt;platform&gt;))
  - Reuse write_environment_skip
- **Recommendation:** New platform variant
- **Why:** The environment helper prints the environment name, which is wrong for 'typst on Linux'. Row 16 edits 1 and 5 carry it
- **Blocks:** M2 B2/B3
- **Source:** MISSIONS/S5-Tools/S5-Tools-report.md section 3 Q12

### P-Q4: Does the config writer prompt?

- **Options:**
  - Writer silent; aitools user init prompts
  - Writer prompts
- **Recommendation:** As drafted (writer silent)
- **Why:** Sync and installer stay non-interactive
- **Blocks:** M3 B3
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q4

### P-Q5: Pin the kernel HostName (sudo scutil --set HostName nobul-mac)?

- **Options:**
  - Skip
  - Pin
- **Recommendation:** Skip
- **Why:** The resolver reads LocalHostName (= nobul-mac); registration makes it moot. The cause of the flip is unproven (handoff G14)
- **Blocks:** nothing
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q5

### P-Q6: Move googleDrives into profile.json now?

- **Options:**
  - Later, under profiles.&lt;alias&gt;.googleDrives
  - Now
- **Recommendation:** Later
- **Why:** It is detected machine state; labels do not mean anything yet
- **Blocks:** nothing
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q6

### P-Q7: Generate deploy/setup-user-config and embed tool specs and helpers for MDM (+ T-Q1 MDM part)?

- **Options:**
  - Yes, one follow-up MDM batch (X-B4) after M3 B8 and M2 B3
  - No
- **Recommendation:** Yes, X-B4
- **Why:** It keeps dual-path parity in one build-deploy batch instead of two
- **Blocks:** X-B4
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q7

### P-Q12: Non-interactive registration: add aitools user init --alias &lt;A&gt;?

- **Options:**
  - Add --alias
  - None
- **Recommendation:** Add --alias
- **Why:** Claude Code web and scripted setups need it; the interactive-menus draft's ACTION text uses it (drop that text if rejected)
- **Blocks:** M3 B6/B7
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q12

### P-Q13: Token reverse order on adopt: {{PROFILE_NAME}} wins, or the git name wins?

- **Options:**
  - {{PROFILE_NAME}} wins (today)
  - git name wins
- **Recommendation:** {{PROFILE_NAME}} wins
- **Why:** 'Jose' is both values today, and this keeps current behaviour
- **Blocks:** M3 B4
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 P-Q13

### N-Q2: Dotprofile commits: register auto-commits and pushes, while [k]eep only adds an ACTION?

- **Options:**
  - As drafted
  - Both auto-commit
  - Neither
- **Recommendation:** As drafted
- **Why:** user init is an explicit dotprofile command; setup scripts must never touch git (P-Q10 logic)
- **Blocks:** X-B1
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 N-Q2

### N-Q4: knownPaths field name 'verified' collides with the governed outcome: rename, or keep and define?

- **Options:**
  - Keep and define
  - Rename
- **Recommendation:** Keep and define (same as G-verified)
- **Why:** No churn
- **Blocks:** M2 B1
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 N-Q4

### N-Q6: Ambiguous preferred methods: their own detail, or reuse 'no method for &lt;platform&gt;'?

- **Options:**
  - Own detail 'two methods for &lt;platform&gt;'
  - Reuse
- **Recommendation:** Own detail (already in rev 3 and rev 4)
- **Why:** A registry conflict is not a missing method
- **Blocks:** M2 B2
- **Source:** MISSIONS/S4-Review/S4-Review-report.md section 3 N-Q6

### N-Q5: Local checkout carries stale pre-merge S3-Nine edits: reset?

- **Options:**
  - Resolved
- **Recommendation:** Resolved: no action
- **Why:** Handoff section E: git status on 2026-10-21 showed no modified tracked files; the git diff origin/main..main touched only .gitignore and harvesting/
- **Blocks:** nothing
- **Source:** handoff 2026-10-21_360aa8f3-8.md section E (closing paragraph)

### B-09: NEW from the B pass: on Windows, do you run Git Bash inside Windows Terminal (ConPTY), or in mintty?

- **Options:**
  - Windows Terminal
  - mintty
  - I use PowerShell for aitools
- **Recommendation:** Answer before M2 B3. If mintty, tell the delegate to test whether menus reach the non-interactive path
- **Why:** Under mintty without ConPTY, stdin is a pipe, so Test-InteractiveConsole is false and every menu (tool and managed-file) takes the non-interactive default when aitools is run from Git Bash. Unverified
- **Blocks:** M2 B3 test plan
- **Source:** GATE/S3-Gate-B-review.md B-09

## (e) KNOWN DEFECTS left in drafts: accept or send back

### E-rev4-minors (changed): Rev 4 leaves the minor A/B findings open. Accept them as known defects for a later revision?

- **Options:**
  - Accept
  - Fix before approval
- **Recommendation:** Accept
- **Why:** S3-Gate-A A-05..A-16 (A-08/A-09 are handled by row 16) and S3-Gate-B B-07, B-08 (Windows guard roots), B-11..B-13. B-10 is fixed in rev 5 (Get-Command -First 1), and B-07's APFS point is superseded by rev 5's case-insensitive compare plus file identity (S3-GateFix-B GB-05). One affects a stated fact: section 3 still says show_summary keeps one row per tool, but the installer's 'setup-&lt;x&gt;' row and the script's '&lt;label&gt;' row both show (A-05)
- **Blocks:** nothing
- **Source:** GATE/S3-Gate-rev4-changelog.md 'Findings not applied'

### E-S4-7: The S4 interactive-menus.md draft (row 7) does not mention the abort marker (D-TS13 is approved)

- **Options:**
  - Fix at write time
- **Recommendation:** Fix at write time (text in item R7)
- **Why:** The draft predates the A/B pass
- **Blocks:** row 7
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/dot-claude/rules/interactive-menus.md 'Tool install-method menu'

### E-glossary-1: The glossary terms draft still says 'machine identity' and 'identity overrides' inside the 'machine profile' definition after renaming the term to 'machine id' (C-15 applied only to the term name)

- **Options:**
  - Fix at write time: '...holding one machine's (or one hosted environment's) per-machine overrides of identity name/company, machine id, and tool exceptions...'
- **Recommendation:** Fix at write time
- **Why:** Otherwise the glossary contradicts its own rename
- **Blocks:** row 10
- **Source:** MISSIONS/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json terms_add['machine profile']

### E-paths-PRb: Skill and registry paths in rows 3-6, 8, 11, 12 are the current .claude/skills/ and registries/ paths

- **Options:**
  - Retarget after PR-b (C-SEQ)
- **Recommendation:** Retarget after PR-b
- **Why:** PR-b moves tool-eval, tool-registry and registries/ to shared/
- **Blocks:** rows 3-6, 8, 11, 12
- **Source:** GATE/S3-Gate-drafts-fixes.md 'Known defects'

### E-registry-resolveBy: The registry schema 1.1 draft predates rev 4: it has no resolveBy

- **Options:**
  - Add when the bash entry migrates (M2 B16)
- **Recommendation:** Add in M2 B16
- **Why:** Only the bash tool on Windows needs it today; the draft carries only node and go entries
- **Blocks:** M2 B16
- **Source:** MISSIONS/S5-Tools/S5-Tools-drafts/registries/tool-registry.schema-1.1-draft.json; rev 4 section 6

### E-go-knownPaths: The go Linux knownPaths proposal has verified: null, so the generator drops it and T3 cannot use it until it is verified

- **Options:**
  - Verify on Linux in M2 B9
- **Recommendation:** Verify in M2 B9
- **Why:** By design (only verified paths count, script-standards 'KnownPaths empirical verification')
- **Blocks:** M2 B9
- **Source:** MISSIONS/S5-Tools/S5-Tools-drafts/registries/tool-registry.schema-1.1-draft.json go _knownPathsProposal

### E-unreviewed: Drafts not re-reviewed by S3-Gate: user-repo.md (row 18), the M3 code and intents (rows 22-23), claude-shared.md edit (row 19)

- **Options:**
  - Accept S4/S5-Profile review
  - Request a review pass
- **Recommendation:** Accept S4-Review plus S5-Profile-A as the review of record
- **Why:** Outside this mission's lens; S5-Profile-A and S4-Review covered them
- **Blocks:** rows 18-23
- **Source:** MISSIONS/S5-Profile/S5-Profile-A-review.md; MISSIONS/S4-Review/S4-Review-report.md section 1

### E-independence (changed): The A/B pass was done by one agent (S3-Gate), not two independent reviewers: the Agent tool was not provisioned in this session

- **Status:** RESOLVED -- S3-GateFix-B, an independent delegate that did not read S3-Gate-B-review.md first, re-ran the cross-platform and bootstrap pass on rev 5 (FIX/S3-GateFix-B-review.md). S3-Gate-A (rule correctness) has not been repeated independently. No answer needed.
- **Options:**
  - Accept with spot-checks
  - Re-run A and B as independent delegates
- **Recommendation:** Accept with spot-checks of A-03 and B-01 (both carry command evidence)
- **Why:** Every blocker and major has file or command evidence; independence still matters for what was not found
- **Blocks:** nothing
- **Source:** GATE/S3-Gate-A-review.md and S3-Gate-B-review.md summaries

### E-rev5-minors (new): Rev 5 leaves some S3-GateFix-B minors open. Accept them as known defects for M2 to settle?

- **Options:**
  - Accept
  - Fix before approval
- **Recommendation:** Accept
- **Why:** Applied in rev 5: GB-01..GB-05 (majors), GB-07 (only the marker's creator deletes it; re-exec), GB-08 (cygpath -m at creation; GetTempFileName fallback), GB-09 (read with [ -s ], guarded truncation), GB-10 (explicit exit, check 12), GB-11 (3.2 rule covers every script), GB-15 ($script:DeployErrors), O-1 (tool_support_run is the one helper that returns 2), and S3-Gate-B B-10 (Get-Command -First 1). Open: GB-06 (section 8 exception match by file identity, done in aitools-profile.js), GB-12 (the no-node [k]eep ACTION names the wrong remedy), GB-13 (aitools.ps1 hard-codes one Git Bash path; bin\bash.exe vs usr\bin\bash.exe), GB-14 second half (macOS login PATH comes from setup-user-shell, not the process PATH), O-2 (abort logs error in managed-file menus, warn in the tool menu), O-3 (abort inside sync_managed_json leaves temp files; library side, SOURCE-TRUTH). Every Windows claim is UNVERIFIED (no Windows machine)
- **Blocks:** nothing
- **Source:** FIX/S3-GateFix-B-review.md; FIX/S3-GateFix-rev5-changelog.md

### E-node-corrupt (new): bash deploy state needs node and moves the manifest aside as .corrupt

- **Options:**
  - Accept as known; resolved by mission SOURCE-TRUTH
- **Recommendation:** Accept; SOURCE-TRUTH removes deploy state
- **Why:** initialize_deploy_state validates ~/.aitools/deploy-state/manifest.json with 'node -e JSON.parse(...)'. Without node the command fails, the valid manifest is treated as unreadable, renamed to manifest.json.corrupt, and a warning is logged. The approved model has no deploy state, so the code path goes away
- **Blocks:** nothing in this gate
- **Source:** scripts/aitools-lib.sh initialize_deploy_state; mission packet section 6 ('no ancestor, no deploy state')

### E-merge-revert (new): Accepted merges are reverted on the next run

- **Options:**
  - Accept as known; resolved by mission SOURCE-TRUTH
- **Recommendation:** Accept; SOURCE-TRUTH implements merge & adopt
- **Why:** Today [m]erge writes the AI merge to LOCAL only (state machine: '[m]erge --> AI merge --> updated'); SOURCE is unchanged, so the next run finds LOCAL different from SOURCE again, and a non-interactive run overwrites the merge. Under the approved model, merge & adopt copies the result to the repo in the same step
- **Blocks:** nothing in this gate
- **Source:** reference/managed-file-deployment.md 'State Machine' and 'Merge-Conflict Menu'; mission packet section 6

### E-mdc-model (new): The row R14 mirror managed-file-deployment.mdc describes JSON review as 'per-leaf overwrite/adopt/skip/abort', and the .claude rule it mirrors says the same

- **Options:**
  - Re-mirror after the managed-file spec rewrite lands
  - Fix the S3-Gate mirror now
- **Recommendation:** Re-mirror after the spec rewrite
- **Why:** The approved model names the choice 'accept & adopt' and makes SOURCE own every field. The .claude rule is outside this mission and is being rewritten by the managed-file spec work (S3-SpecRewrite), so fixing only the mirror now would make the two disagree
- **Blocks:** row R14 (managed-file-deployment.mdc only)
- **Source:** GATE/S3-Gate-drafts/dot-cursor/rules/managed-file-deployment.mdc line 16; .claude/rules/managed-file-deployment.md 'Deployment types'

### E-relay-exit2 (new): The relay outbound prompt's [q] makes 'aitools' exit 2 after the summary, the same code as a user abort

- **Options:**
  - Accept: documented as outside the D-TS13 contract (rev 5 section 7.5)
  - Change [q] to another exit code
- **Recommendation:** Accept for now
- **Why:** It runs in the entry point after the summary, not in a setup script, so no runner reads it. Only a caller of 'aitools' itself (a wrapper or CI) could confuse it with an abort; none is known
- **Blocks:** nothing
- **Source:** scripts/aitools ('relay_outbound_prompt "$repo_path" || return $?'); scripts/aitools.ps1 ('if ($relayRc -eq 2) { exit 2 }'); .claude/rules/relay-outbound.md ('[q] exit with code 2')
