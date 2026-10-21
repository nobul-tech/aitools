## 3. Open questions, merged and de-duplicated

Sources: S5-Tools-report.md §3 (T-Q1..T-Q12), S5-Profile-report.md §8 (P-Q1..P-Q13), new (N-Q*). "Blocking" = blocks the combined docs approval (gate) or the named batch. Recommendation and reasoning are the missions' unless marked S4.

### Decide in the approval gate (blocking)

| # | Question | Options | Recommendation | Why | Changes | Blocks |
|---|---|---|---|---|---|---|
| N-Q1 (S4) | toolExceptions shape and engine | (a) merged shape + `aitools-profile.js exception-get/set` (S4 X1/X4); (b) M2 shape + perl/`ConvertFrom-Json`; (c) M3 shape as drafted | **(a)** | One owner (user-repo.md), one write path for a shared git file, node available whenever a dotprofile exists; (b) fails on minimal Linux and reformats JSON in PS; (c) lacks platform and uses install kinds | user-repo.md, tree §8/§3/§7.2, aitools-profile.js (new batch X-B1), glossary `tool exception` | gate; M2 B2/B3 |
| T-Q2 = D-TS10 | Recorded exception: OK or WARN? | OK `<ver> (kept)` / WARN | **OK** | The user decided it; permanent WARN trains people to ignore WARN. Departs from F3 for recorded exceptions only | tree §3 | gate |
| T-Q10 = D-TS11 | SHADOWED = ERROR although another copy runs? | ERROR / WARN | **ERROR** | "supported" = resolves to the managed copy (tooling-resolution decision 10); WARN is how the python shadow went unnoticed. Needs the severity-guide line in script-standards-detail.md | tree §3, rule item 6, script-standards-detail | gate |
| T-Q11 = D-TS12 | Platform still `evaluating`: WARN or ERROR? | WARN `under evaluation` + ACTION / ERROR | **WARN** | Nothing the user caused is broken; ERROR fires on every Linux run for node | tree §3, T0 | gate |
| N-Q3 (S4) | Glossary renames from M3 | keep `machine identity`/`derived config` / rename to `machine id`/`aitools config` | **Rename** | `identity` already means the user (profile.json `identity`); "derived" is not a scope modifier, so the composed form fails /audit (`reference/framework-governed-vocabulary.md`) | glossary.json + glossary.md (merged draft) | gate (glossary batch) |
| T-Q1 | How setup scripts get registry data | (A) generated specs in `generated/tool-specs/` embedded by build-deploy; (B) runtime JSON parse; (C) hard-coded + pre-commit compare | **A**, C as stopgap before the generator | One source; MDM self-contained; no evaluation of registry text; B fails on minimal Linux. Needs git-safety.md edit (generated/ = generated, tracked) | tree §7.1, git-safety.md, deploy-paths.md (later MDM embed) | gate; M2 B1 |
| T-Q9 | Where the registry schema is documented | rule / skill / reference | **Reference §6 only**; amend framework-three-layer-governance.md "Schema" separately | single authority; S4-Review-C C-08 shows the skills still restate it and contradict it — fix the skill drafts (section 2) | tree, /tool-registry, /tool-adopt, /tool-eval drafts | gate |
| P-Q1 | Company/name level | identity-level defaults + per-profile overrides / per-profile only | **identity.company = "nobul-tech", identity.name = "Jose"**; delete per-profile `Nobul`/`nobul.tech`/`pepe` only after all 3 machines run 2.1 code | matches GitHub org and CLAUDE.md; older code still reads per-profile company | dotprofile profile.json (B10) | B10 |
| P-Q2 | Hash machine ids | raw / hashed (HMAC, fixed key) | **HMAC-SHA256, key `aitools-machine-id-v1`** | no raw hardware ids in git; deterministic | aitools-profile.js, user-repo.md (text fixed, X16) | gate |
| P-Q3 | Resolver in one JS module vs native bash+PS1 | JS / native | **JS** | one definition; build-deploy can call it; cost = needs node, which deploy already needs. N-Q1 extends the same module to exceptions | aitools-profile.js | gate |
| P-Q8 | MDM template: switch deploy/ to the dotprofile template | switch / keep shared | **Switch** in M3 B5 | dev and MDM must match (deploy-paths.md); changes MDM output (incident draft #96) | build-deploy.sh | M3 B5 |
| P-Q9 | build-deploy on corrupt profile.json | fail loudly / silent defaults | **Fail (exit 1)**; corrupt config.json = skip with WARN | corrupt source of truth is a real error; config.json must stay repairable (review H3) | build-deploy.sh B5 | M3 B5 |
| P-Q10 | deploy/ adopt-back into the dotprofile | allow / read-only | **Read-only** (deploy script sets `USER_REPO_PATH=""` after resolving) | MDM endpoints must not push to git | build-deploy.sh B5 | M3 B5 |
| P-Q11 | MDM and no-node | ERROR everywhere / identity-level strings when node absent, WARN for unregistered in deploy/ only, document `AITOOLS_MACHINE_ALIAS` | **as recommended** | unregistered MDM endpoints would ERROR every run | build-deploy.sh, user-repo.md | M3 B5 |

### Decide before the named batch (non-blocking for the gate)

| # | Question | Options | Recommendation | Why | Changes | Blocks |
|---|---|---|---|---|---|---|
| T-Q3 | `[x]abort` scope | whole run (exit 2) / this tool | **Whole run**, and fix installers (incident draft #87) | matches the governed managed-file abort | installers, entry points | M2 B4a/B4b |
| T-Q4 | Keep automatic fallback methods (modal pip, datadog cargo on macOS) | keep / remove | **Remove**; missing manager = PREREQ ERROR + ACTION | fallbacks install non-preferred methods without a decision (tool-evaluation.md) | setup-modal, setup-datadog | M2 B10, B14 |
| T-Q5 | Below minVersion | ERROR / WARN | **ERROR + ACTION** | harness cannot run on it | setup-bash, setup-perl | M2 B15, B16 |
| T-Q6 | Query upstream for "latest" | yes / no | **No** | update command is the mechanism | tree §4 | none |
| T-Q7 | `reference/tool-registry.md` duplication | JSON canonical + md generated (phased) / keep both | **JSON canonical; banner now; generator later**; same for tool-versions.json | covered by incident #21 (extend) | tool-registry.md, check-post-push steps 9/10/25 | later batch |
| T-Q8 | Protect all project skills in sources-of-truth | all / three tool skills only | **All, as a separate decision** — and after S2-Split decides where skills live | intents are already protected; table silent (incident draft #102) | sources-of-truth.md | after S2-Split |
| T-Q12 | Platform-level n/a row | new `write_platform_skip` / reuse environment helper | **New platform variant** | environment helper prints the environment name | lib, script-standards-detail | M2 B2/B3 |
| P-Q4 | Writer prompts? | writer silent, user init prompts / writer prompts | **As drafted** | sync and installer stay non-interactive | setup-user-config | M3 B3 |
| P-Q5 | Pin kernel HostName (`sudo scutil --set HostName nobul-mac`) | yes / skip | **Skip** | resolver reads LocalHostName (= nobul-mac); registration makes it moot | none | none |
| P-Q6 | googleDrives in profile.json | now / later | **Later** (under `profiles.<alias>.googleDrives` when labels mean something) | detected machine state | none | none |
| P-Q7 + T-Q1 MDM part | Generate deploy/setup-user-config and embed tool specs/helpers for MDM | yes in a follow-up / no | **Yes, one follow-up MDM batch** after M3 B8 and M2 B3 (both now unblocked by PR #50) | keeps dual-path parity; one build-deploy batch instead of two | build-deploy.sh, deploy-paths.md "What IS auto-embedded" (add aitools-profile.js, generated/tool-specs) | X-B4 |
| P-Q12 | Non-interactive registration | `aitools user init --alias <A>` / none | **`--alias`** (the merged interactive-menus draft's ACTION text uses it; drop that text if rejected) | Claude Code web and scripted setups | scripts/aitools(.ps1), interactive-menus.md | M3 B6/B7 |
| P-Q13 | Token reverse order on adopt | `{{PROFILE_NAME}}` wins / git name wins | **`{{PROFILE_NAME}}` wins** (today's behaviour) | "Jose" is both | setup-user-claude | M3 B4 |
| N-Q2 (S4) | Dotprofile commits: register auto-commits+pushes, `[k]eep` only adds ACTION | as drafted / both auto-commit / neither | **As drafted** | user init is an explicit dotprofile command; setup scripts must never touch git (P-Q10 logic) | tree §8 | X-B1 |
| N-Q4 (S4) | knownPaths field name `verified` collides with the governed outcome | rename / keep + define | **Keep + define** in tree §6 (C-18) | no churn; meaning tied to script-standards "KnownPaths empirical verification" | tree §6 | M2 B1 |
| N-Q5 (S4) | Local checkout carries stale pre-merge S3-Nine edits | reset the 4 files to origin/main / keep | **Reset** before any batch (commander action) | a commit from here reverts merged PR #50 fixes (section 1) | local working tree only | every batch |
| N-Q6 (S4) | Ambiguous preferred methods: own detail? | reuse `no method for <platform>` / `two methods for <platform>` | **Own detail** (C-11; applied in the S4 copy) | a registry conflict is not a missing method | tree T1, §3 | M2 B2 |

Dropped as duplicates: none of the 25 mission questions duplicate each other exactly; P-Q7 and the MDM half of T-Q1 are merged (one MDM batch). T-Q8 is now coupled to S2-Split.
