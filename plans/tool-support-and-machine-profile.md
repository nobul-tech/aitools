# Tool support and machine profile: gate decisions

**Intent**: **Purpose**: Record every commander decision taken at the tool-support gate, so the
implementation missions (M2 tool support, M3 machine profile, S2-Layout PRs, /tool-adopt,
deploy-harness) build on decided text rather than conversation. **Scope**: The decisions and
notes from the review page (S3-GateFix, PR #66) and the chat clarifications that override
them. NOT the designs themselves (the decision tree rev 5, the drafts in the mission
folders). NOT the managed-file model (`.claude/rules/agentic-standards.md`). **Audience**:
Every agent implementing M2, M3, LAYOUT, TOOL-ADOPT or HARNESS.

Decided 2026-10-21 by the commander. Source of the answers: the review page artifact
(https://claude.ai/artifact/Mqm6D32Xt5gKGUxPZTMSDY, collection `answers`, 95 of 95
answered). Item text and options: `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/
S3-GateFix/S3-GateFix-review-page.json`.

## Decisions that change the drafts

- **D-TS13 reversed**: bare exit 2 = user abort; no abort marker.
- **Registries stay in `registries/`** (SD-8-reg): deploy-harness copies them to
  `~/.aitools/registries/` (macOS/Linux) and `%USERPROFILE%\.aitools\registries\` (Windows).
  LAYOUT PR-b does not move them.
- **SD-8 extended** to 7 user-level skills (adds incident, glossary, frameworks).
- **Machine identity**: raw machine ids (P-Q2); resolver is native `scripts/aitools-profile.sh/.ps1`
  (P-Q3), not JavaScript; one scutil command that reports `nobul-mac`, and scripts that take
  hostnames from DNS are removed (P-Q5).
- **`tool-versions.json` is deleted** and every reference remediated; `tool-registry.md` is
  deprecated, references point to the `/tool-registry` skill (S2L-Q6, T-Q7).
- **LAYOUT and M2 run in parallel** (C-SEQ).
- **/tool-adopt does the work** (evaluate when needed, write the registry entry and setup
  scripts), at user level (TA-PLACE, TA-SKILL).
- **Dotprofile writes auto-commit and push** (N-Q2).
- **Re-run the correctness (A) review as an independent delegate** (E-independence).

## All items

| Item | Section | Question | Decision | Note |
|------|---------|----------|----------|------|
| N-Q1 | Blocking gate questions | toolExceptions: which shape, who owns it, and who writes it? | (a) {decision:"keep", detected:{platform, method, path, version}, decidedAt, decidedBy, reason}; shape owned by reference/user-repo.md; tree section 8 owns when it is written, read and matched; writer and reader = aitools-profile.js exception-set / exception-get |  |
| D-TS10 | Blocking gate questions | A recorded tool exception (KEEP, EXCEPTION): report OK or WARN? | OK <ver> (kept) |  |
| D-TS11 | Blocking gate questions | SHADOWED (the command resolves to another copy that runs): ERROR or WARN? | ERROR shadowed (see log) + ACTION |  |
| D-TS12 | Blocking gate questions | A platform whose registry status is still 'evaluating': WARN or ERROR? | WARN under evaluation + ACTION run /tool-eval | if it installs successfully without errors, it should report OK, not WARN. we pass-through the warning/error. if action is required, pass through a WARN. if it failed, log ERROR |
| D-TS13 | Blocking gate questions | NEW from the A/B pass: should exit 2 count as a user abort only when an abort marker file exists? | (b) Bare exit 2 = user abort. No abort-marker file (chat, 2026-10-21: "exit 2 = abort is fine for a user abort; avoid this"). Rev 5 section 7.5 marker text is not implemented |  |
| REV4 | Blocking gate questions | Approve decision tree rev 4 (rev 3 plus the A/B blocker and major fixes) as the version that lands as reference/tool-support-decision-tree.md? | Superseded by REV5 (approved) | no idea what rev 3 rev 4 mean, i need more context in how you present questions |
| REV5 | Blocking gate questions | Approve decision tree rev 5 (rev 4 plus the PR #58 review fixes and the independent B-pass fixes) as the version that lands as reference/tool-support-decision-tree.md? | Approve rev 5 |  |
| N-Q3 | Blocking gate questions | Glossary renames from M3: keep 'machine identity' and 'derived config', or rename them to 'machine id' and 'aitools config'? | Rename to machine id / aitools config |  |
| T-Q1 | Blocking gate questions | How do setup scripts get registry data? | (see note) | they pull it from registries/tool-registry.json, needs to be supported it as standalone, dev, and MDM style |
| T-Q9 | Blocking gate questions | Where is the tool registry schema documented? | In the /tool-registry skill |  |
| P-Q1 | Blocking gate questions | Where do company and name live in profile.json? | Recommendation: identity.company = "nobul-tech", identity.name = "Jose". Delete the per-profile Nobul / nobul.tech / pepe values only after all 3 machines run 2.1 code |  |
| P-Q2 | Blocking gate questions | Hash machine ids before storing them in git? | raw ids |  |
| P-Q3 | Blocking gate questions | Machine resolver: one JS module, or native bash plus PS1? | Native bash and PowerShell | aitools-profile.sh/ps1 living in scripts/ |
| P-Q8..Q11 | Blocking gate questions | MDM and build-deploy batch: approve the four answers together? | Approve all four as recommended |  |
| S2L-QA | Blocking gate questions | S2-Layout Q-A: when a skill moves level, git mv it (no copies), or keep both copies? | git mv, never two copies | audit the scripts, checks, libs, and setup-user-skills.sh.ps1 for all changes and remediation required |
| S2L-QB | Blocking gate questions | S2-Layout Q-B (= S2-Layout section 6 Q2): approve the protected spec in S2-Layout-evidence E6 (path map) and E7 (drafts D1-D6) up front as the review step, then ship 3 small PRs? | (see note) | approved e6/e7 as well as anything beyond that is recommended to avoid holding this up. |
| S2L-Q1 | Blocking gate questions | Do audit and governed-data stay project-level? | Keep audit and governed-data project-level (/tool-adopt placement is item TA-PLACE) |  |
| S2L-Q3 | Blocking gate questions | Delete the 9 untracked shared/skills copies before any aitools run? | Already done: no action |  |
| S2L-Q4 | Blocking gate questions | If PR-b check V5 fails (Claude Code web does not list the user-level skills), how does Claude Code web get them? | (see note) | can we use claude.ai account skills but also do a check for claude code web, and if we are in the web, then deploy skills to the project level? or set the project directory to the home directory when in claude code or vice versa? |
| S2L-Q5 | Blocking gate questions | Rename shared/ (for example to user/ or home/)? | Not now; revisit after PR-b with an rc-rewrite fix |  |
| S2L-Q6 | Blocking gate questions | Does tool-versions.json (no skill, hand-edited) move with the registries? | (see note) | tool-versions.json is deprecated, the tool-registry.json should keep track of versions. it should be deleted. check for references for it and remediate as required. |
| SD-8-ext | Blocking gate questions | SD-8 pending half (1): do incident, glossary and frameworks also move to user level (shared/skills/)? | Yes, with the 4 already approved (7 total) |  |
| SD-8-reg | Blocking gate questions | SD-8 pending half (2): registries at shared/registries/, read through the deployed aitools-registry.py resolver (live clone, then the ~/.aitools/registries/ read-only snapshot, then 'unavailable')? | Registries stay in registries/ | they are copied to ~/.aitools/registries/ by deploy-harness.sh and to %USERHOME\.aitools\registries on windows or whatever by deploy-harness.ps1 |
| C.1 | Blocking gate questions | Does M2 absorb tooling-resolution Workstream A? | Yes: the new tool-support work (M2) takes over tooling-resolution Workstream A's resolver and verification scope; B and C stay separate (chat 2026-10-21) | no idea what any of this means. M2/t7/a8/ etc, the letter and number combinations mean nothing to me here, need you to spell it out. |
| C-SEQ | Blocking gate questions | Sequencing of S2-Layout PR-b against the M2 skill and registry edits? | In parallel |  |
| PR-a | Blocking gate questions | Approve the protected-file path fixes that S2-Layout PR-a batch 2 makes (the stale reference/*.json paths in S2-Layout-B tables 1.1-1.5)? | Approve: the fixes are path repoints only (reference/<x>.json to registries/<x>.json, or the governing skill), no meaning change |  |
| R1 | Protected-file batch | reference/tool-support-decision-tree.md (new; new intent) | approve the draft |  |
| R2 | Protected-file batch | .claude/rules/tool-lifecycle.md (rewrite; modified intent) | approve the draft |  |
| R3 | Protected-file batch | reference/framework-tool-lifecycle.md (edit; modified intent) | approve the draft |  |
| R4 | Protected-file batch | tool-adopt SKILL.md (new; new intent). Now proposed at shared/skills/tool-adopt/ (section ta) | approve the draft |  |
| R5 | Protected-file batch | tool-eval SKILL.md (edit; modified intent) | approve the draft |  |
| R6 | Protected-file batch | tool-registry SKILL.md (edit; modified intent) | approve the draft |  |
| R7 | Protected-file batch | .claude/rules/interactive-menus.md (edit; new intent) | approve the draft |  |
| R8 | Protected-file batch | .claude/rules/sources-of-truth.md (edit; new intent) | approve the draft |  |
| R9 | Protected-file batch | .claude/rules/glossary.md (7 term lines) | approve the draft |  |
| R10 | Protected-file batch | registries/glossary.json (7 terms added, managed tool modified) | approve the draft |  |
| R11 | Protected-file batch | registries/tool-registry.json schema 1.1 (+ node/go illustrative entries; modified meta.intent) | approve the schema and meta.intent; entries only after /tool-eval |  |
| R12 | Protected-file batch | registries/framework-registry.json (Tool lifecycle entry) | approve; write only once every listed path exists |  |
| R13 | Protected-file batch | .claude/rules/managed-file-deployment.md (2 edits) | approve the draft |  |
| R14 | Protected-file batch | .cursor/rules/managed-file-deployment.mdc, interactive-menus.mdc, tool-lifecycle.mdc (mirrors) | approve the drafts |  |
| R15 | Protected-file batch | .claude/rules/git-safety.md (generated/ is generated and tracked) | approve the draft |  |
| R16 | Protected-file batch | reference/script-standards-detail.md (6 edits) | approve the edits |  |
| R17 | Protected-file batch | shared/skills/aitool-eval/SKILL.md (refresh derived card) | void: PR-c retires the card |  |
| R18 | Protected-file batch | reference/user-repo.md (rewrite; new intent; owns the toolExceptions shape) | approve the draft |  |
| R19 | Protected-file batch | shared/claude-shared.md + dotprofile claude/CLAUDE.md (Cross-Platform Awareness lines) | approve the draft |  |
| R20 | Protected-file batch | .claude/rules/deploy-paths.md (setup-user-claude row; aitools-profile.js auto-embedded) | approve the text |  |
| R21 | Protected-file batch | .claude/rules/config-file-safety.md (reference example) | approve the text |  |
| R22 | Protected-file batch | code intents for scripts/aitools-profile.js, scripts/setup-user-config.sh/.ps1, lib section intents (both libs) | approve the drafts |  |
| R23 | Protected-file batch | meta.intent of ~/.aitools/config.json (in the writers) and dotprofile profile.json | approve the drafts |  |
| R24 | Protected-file batch | registries/incidents.json (27 new entries #87-#113 + affected updates) | carved out to mission LEDGER |  |
| R25 | Protected-file batch | intent headers for the 26 migrated tool setup scripts (M2 B5-B17) | approve the template and table |  |
| R-S2L5 | Protected-file batch | S2-Layout section 5 sibling impact: after PR-b, should the sources-of-truth.md draft (row 8) list the registries at shared/registries/ and cite the skills instead of JSON paths? | Yes (fold into row 8) |  |
| C-14 | Glossary | Govern 'detection signature' for the tool registry field (typed probes that identify an install method), separate from the governed 'detection' (the hook layer)? | (a) Govern 'detection signature'; keep the JSON key 'detection' |  |
| G-provenance | Glossary | 'provenance' is governed as an aitools component, but tool documents say 'provenance verification' (supply chain) and code says 'provenance' for install origin. What to do? | (b) Govern 'install provenance' as a second term | can also be tool distribution provenance or something like that |
| G-verified | Glossary | knownPaths entry field 'verified' (a date and version trial record) vs the governed outcome 'verified': rename or keep and define? (= N-Q4) | Keep the field and define it in tree section 6 |  |
| G-recovered | Glossary | The deployment outcome 'recovered' (setup-user-config, user-repo.md 'Config Schema (v3)') is not governed, while created, updated and verified are. Govern it? | Govern 'recovered' with the M3 batch |  |
| G-terms | Glossary | Approve the 7 proposed terms (tool adoption, tool exception, update channel, machine profile, machine alias, machine id, aitools config) and the modified 'managed tool'? | Approve with the E-glossary-1 fix |  |
| G-profile | Glossary | 'profile' has three ungoverned meanings (shell profile, profile.json, machine profile). Add a governed disambiguation? | (see note) | shell profile, profile.json = user profile, machine profile is a field in profile.json. profile should also mean user profile, not shell, not machine |
| G-userconfig | Glossary | The composition example 'user config' resolves only to ~/.claude/settings.json, while ~/.aitools/config.json is also a user-deployed config. Fix the example? | (see note) | aitools config should encompass ALL managed config data for all tools for a user. this is for claude, cursor cli, shell variables, and also conf aitools config.json itself. it is the aitools harness config, for short. |
| T-Q3 | Non-blocking | [x]abort scope: the whole run or only this tool? | Answered by SD-5: the whole run (exit 2) | Implemented by PR #106 and kept by the commander 2026-10-26 ("keep functionality, update docs on whatever current state is"): only an exit 2 from deploy-harness stops the run (installer Step 8b, `aitools` sync); an exit 2 from any other setup script is an ERROR row `script failed (exit 2)` and the run continues. Detail: reference/managed-file-deployment.md "[x]abort" |
| T-Q4 | Non-blocking | Keep automatic fallback methods (modal pip, datadog cargo on macOS)? | Remove them; a missing manager = PREREQ ERROR + ACTION | this should be documented in the decision tree of tool-lifecycle.md and tool-support-decision-tree.md. make sure to log errors and log error on summary |
| T-Q5 | Non-blocking | Below minVersion (bash < 5.0, perl < 5.010): ERROR or WARN? | (see note) | the harness manages bash and perl, it should update them and if it fails to update it should log a warning, also print it in summary, and continue |
| T-Q6 | Non-blocking | Must verification query upstream for the channel's newest version number? | No; the update command is the mechanism |  |
| T-Q7 | Non-blocking | Resolve the reference/tool-registry.md duplication how? | (see note) | tool-registry.md is old and should be deprecated, only tool-registry.json is valid. tool-registry.md references should point to the tool-registry skill |
| T-Q8 | Non-blocking | Protect all project skills in sources-of-truth.md? | (see note) | none should be protected |
| T-Q12 | Non-blocking | Platform-level n/a row: a new write_platform_skip, or reuse the environment helper? | New platform variant (write_platform_skip / Write-PlatformSkip, n/a (<platform>)) |  |
| P-Q4 | Non-blocking | Does the config writer prompt? | Writer silent; aitools user init prompts (chat 2026-10-21) | what? need more context here |
| P-Q5 | Non-blocking | Pin the kernel HostName (sudo scutil --set HostName nobul-mac)? | Skip | document exactly what command to run and only use that one that reports nobul-mac on macs with sc util. cleanup any scripts that pull other hostnames from DNS |
| P-Q6 | Non-blocking | Move googleDrives into profile.json now? | Later, under profiles.<alias>.googleDrives | later, but it should be under profiles.machineid or whatever.google drives and it should store the path and the name of the drive or whatever we can pull |
| P-Q7 | Non-blocking | Generate deploy/setup-user-config and embed tool specs and helpers for MDM (+ T-Q1 MDM part)? | (see note) | yes, but tool specs should be in the registry no? |
| P-Q12 | Non-blocking | Non-interactive registration: add aitools user init --alias <A>? | Add --alias |  |
| P-Q13 | Non-blocking | Token reverse order on adopt: {{PROFILE_NAME}} wins, or the git name wins? | {{PROFILE_NAME}} wins (today) |  |
| N-Q2 | Non-blocking | Dotprofile commits: register auto-commits and pushes, while [k]eep only adds an ACTION? | Both auto-commit and push (confirmed in chat 2026-10-21); the existing dotprofile auto-commit/push in setup-user-claude is kept | both auto commit and push |
| N-Q4 | Non-blocking | knownPaths field name 'verified' collides with the governed outcome: rename, or keep and define? | Keep and define |  |
| N-Q6 | Non-blocking | Ambiguous preferred methods: their own detail, or reuse 'no method for <platform>'? | The registry schema allows only one preferred install method per platform; a violation gets its own detail message (chat 2026-10-21) | i need more context here. what is this in reference to? |
| N-Q5 | Non-blocking | Local checkout carries stale pre-merge S3-Nine edits: reset? | Resolved |  |
| B-09 | Non-blocking | NEW from the B pass: on Windows, do you run Git Bash inside Windows Terminal (ConPTY), or in mintty? | I use PowerShell for aitools |  |
| E-rev4-minors | Known defects | Rev 4 leaves the minor A/B findings open. Accept them as known defects for a later revision? | Accept |  |
| E-S4-7 | Known defects | The S4 interactive-menus.md draft (row 7) does not mention the abort marker (D-TS13 is approved) | Fix at write time |  |
| E-glossary-1 | Known defects | The glossary terms draft still says 'machine identity' and 'identity overrides' inside the 'machine profile' definition after renaming the term to 'machine id' (C-15 applied only to the term name) | Fix at write time: '...holding one machine's (or one hosted environment's) per-machine overrides of identity name/company, machine id, and tool exceptions...' |  |
| E-paths-PRb | Known defects | Skill and registry paths in rows 3-6, 8, 11, 12 are the current .claude/skills/ and registries/ paths | Retarget after PR-b (C-SEQ) |  |
| E-registry-resolveBy | Known defects | The registry schema 1.1 draft predates rev 4: it has no resolveBy | Add when the bash entry migrates (M2 B16) |  |
| E-go-knownPaths | Known defects | The go Linux knownPaths proposal has verified: null, so the generator drops it and T3 cannot use it until it is verified | Verify on Linux in M2 B9 |  |
| E-unreviewed | Known defects | Drafts not re-reviewed by S3-Gate: user-repo.md (row 18), the M3 code and intents (rows 22-23), claude-shared.md edit (row 19) | Accept S4/S5-Profile review |  |
| E-independence | Known defects | The A/B pass was done by one agent (S3-Gate), not two independent reviewers: the Agent tool was not provisioned in this session | Re-run A and B as independent delegates |  |
| TA-PLACE | TOOL-ADOPT approval | Where does /tool-adopt live: user level (shared/skills/tool-adopt/, deployed to ~/.claude/skills/) or project level (.claude/skills/tool-adopt/ in aitools)? | (a) User level, process-only now, next to /tool-eval and /tool-registry, which SD-8 already moves to user level | it should not obe process only, it should do work to evaluate (if needed) and adopt the tool |
| TA-SKILL | TOOL-ADOPT approval | Approve the /tool-adopt skill text for shipping now at shared/skills/tool-adopt/SKILL.md? | (a) Approve the S3-GateFix draft as written |  |
| TA-INTENT | TOOL-ADOPT approval | Approve the /tool-adopt intent statement (new intent; protected wherever it appears)? | (a) Approve the revised intent (verbatim from the draft's '## Intent' block): "Purpose: Carry a managed tool from 'evaluated' to 'supported' on each target platform and environment, so its registry entry and setup scripts meet the tool lifecycle rule today and the tool support decision tree once it lands. Scope: Preferred-method confirmation (invoking /tool-eval when missing), registry data through /tool-registry, setup-script creation or migration in the aitools repo, onboarding integration, verification, and maintenance of the registry and the tool-lifecycle rule; which steps wait for the decision-tree machinery (M2). NOT install-method research or health flags (/tool-eval). NOT the registry write process (/tool-registry). NOT the managed-file review choices [a]ccept & adopt and [m]erge & adopt, which copy the deployed file or an AI merge back to the repo (the source of truth) and are unrelated to tool adoption (aitools reference/managed-file-deployment.md). NOT framework adoption (aitools reference/framework-adoption.md). Audience: Any agent, in any repo, that integrates a tool, migrates a setup script, or answers a 'no method for <platform>' ERROR; the commander, who approves every protected change it drafts." |  |
| TA-GLOSSARY | TOOL-ADOPT approval | Approve the glossary entry 'tool adoption' (SD-3 named the skill; D-TS6 requires the disambiguation), so it can land with the skill ahead of the rest of the glossary batch? | (a) Revised definition: "The /tool-adopt process that makes a managed tool supported on a platform and environment: an approved preferred method in the tool registry (running /tool-eval when there is none), the registry data its setup scripts need (after M2: the data the tool support decision tree reads), setup scripts in the aitools repo, installer and build integration, and verification. Runs after /tool-eval. Not the managed-file review choices '[a]ccept & adopt' and '[m]erge & adopt' (the deployed file, or an AI merge, copied back to the repo, the source of truth), and not framework 'adoption' (mapping a discipline's concepts into the harness)." Source: shared/skills/tool-adopt/SKILL.md; reference/tool-support-decision-tree.md (after M2). Plus the term line 'tool adoption' in .claude/rules/glossary.md |  |
| TA-M2 | TOOL-ADOPT approval | Which parts of /tool-adopt wait for M2? | (a) As in the draft's 'Today and after M2' table: registry schema 1.1 fields (step 3), the decision-tree setup-script shape and tool_* helpers (step 4), generated tool specs and gen-tool-specs.py (step 5), the test matrix and the 'Tool support conformance' pre-commit step (step 6). Everything else ships now |  |
| E-rev5-minors | Known defects | Rev 5 leaves some S3-GateFix-B minors open. Accept them as known defects for M2 to settle? | Accept |  |
| E-node-corrupt | Known defects | bash deploy state needs node and moves the manifest aside as .corrupt | Accept as known; resolved by mission SOURCE-TRUTH |  |
| E-merge-revert | Known defects | Accepted merges are reverted on the next run | Accept as known; resolved by mission SOURCE-TRUTH |  |
| E-mdc-model | Known defects | The row R14 mirror managed-file-deployment.mdc describes JSON review as 'per-leaf overwrite/adopt/skip/abort', and the .claude rule it mirrors says the same | Re-mirror after the managed-file spec rewrite lands |  |
| E-relay-exit2 | Known defects | The relay outbound prompt's [q] makes 'aitools' exit 2 after the summary, the same code as a user abort | Accept: documented as outside the D-TS13 contract (rev 5 section 7.5) |  |

95 items.
