# S4-Review report: M2 + M3 reconciliation, decision-tree re-review, one decision list

**Intent**: **Purpose**: Give Session Commander 360aa8f3-8 one consistent decision package for the M2 (tool support) and M3 (profile/config) drafts, so the commander can approve both in one pass. **Scope**: Cross-mission conflicts and their fixes, the adversarial re-review of the decision-tree reference, merged open questions, merged incident drafts, the combined protected-file list and batch order. NOT a rewrite of either design. NOT the .claude vs shared/ skill placement (S2-Split). **Audience**: Session Commander 360aa8f3-8, then Jose.

## Summary

1. The two designs agree in substance; they conflict in 22 places (section 1). Two conflicts were blockers. First, the toolExceptions shape was defined twice, differently. Second, M2's writer rule assumed config.json `machineAlias` plus a "first profile" fallback that M3 removes, so after registration it would never write. Both are fixed in `S4-Review-drafts/`: user-repo.md owns the shape, the tree §8 owns the semantics, and node `aitools-profile.js` is the one engine.
2. The decision-tree re-review drew 35 findings from reviewer C (2 blockers, 16 majors, 17 minors) and 9 more of my own (section 2). Reviewers A (correctness vs rules) and B (cross-platform/bootstrap) produced no output: the session restarted mid-run. I covered those lenses only with targeted checks, so a fresh A/B pass is still owed before the tree is approved.
3. There are 25 mission questions plus 6 new ones (section 3). Fourteen are blocking: nine block the docs approval gate and five block a named batch. The new blocking ones are N-Q1 (exception shape/engine) and N-Q3 (glossary renames: `machine id`, `aitools config`). D-TS10/11/12 are still pending and are now marked that way in the tree.
4. Incidents: 27 drafts (#87-#113) in `S4-Review-incidents-draft.json`. The remaining mission findings were dropped as covered by #21, #50, #54, #55, #59, #74-#78 and #84; four existing incidents need their `affected` lists extended.
5. One protected-file batch (25 rows), one batch order of 19 steps, with 4 new cross-mission batches X-B1 to X-B4. Two things changed since the briefs. PR #50 and PR #52 are already merged, and B0 is done (`nobul-mac`). One blocking pre-step: this checkout still holds stale pre-merge S3-Nine edits, and a commit from here would revert merged fixes.

Files: `S4-Review-report.md` (this), `S4-Review-incidents-draft.json`, `S4-Review-C-review.md` (full reviewer C table), `S4-Review-drafts/` (`reference/tool-support-decision-tree.md` rev 3, `reference/user-repo.md`, `dotprofile/profile.json`, `.claude/rules/{interactive-menus,sources-of-truth,glossary,tool-lifecycle}.md`, `.claude/rules/managed-file-deployment.md.edit.txt`, `registries/glossary.terms-draft.json`), `S4-Review-scratch/` (helper scripts, origin/main incidents copy). No WRITE_BLOCKED. Nothing was written outside `missions/S4-Review/`.

## 1. Overlaps and contradictions between M2 (S5-Tools) and M3 (S5-Profile)

Corrected copies are under `S4-Review-drafts/` (mirroring repo paths). Originals untouched.

| # | Topic | M2 says | M3 says | Resolution (S4-Review) | Edit recorded in |
|---|---|---|---|---|---|
| X1 | toolExceptions **shape** (blocker; also S4-Review-C C-01) | `{decision, method, path, platform, environment, decided, by, note}` (decision-tree ref §8) | `{decision, detected:{method,path,version}, decidedAt, reason}` (user-repo.md "Profile Schema") | One shape, owned by **user-repo.md** (M3 owns the schema): `{decision:"keep", detected:{platform, method, path, version}, decidedAt, decidedBy, reason}`. Dropped: `environment` (the machine profile already carries `machine.environment`; never matched, C-21), `note` (→ `reason`, nullable). Renamed: `decided`→`decidedAt`, `by`→`decidedBy` (= script base name, C-34). Added from M2: `platform` (inside `detected`, `$AITOOLS_PLATFORM` values, not `machine.os` node values). `version` informational, never matched | `S4-Review-drafts/reference/user-repo.md` "Profile Schema" + `toolExceptions` bullet; `S4-Review-drafts/reference/tool-support-decision-tree.md` §8, §3 EXCEPTION/KEEP, §7.2 rows |
| X2 | `method` vocabulary (C-03) | registry method id or `unknown` | example `<brew\|winget\|manual\|...>` (install kinds; `manual` in no enum) | Registry method id or `unknown`. M3's example would never match T5 | user-repo.md copy |
| X3 | Which profile the exception lives in (blocker; C-02) | `<alias>` = `config.json machineAlias`; writer refuses on "fallback (hostname or first profile)" | resolver decides (override → environment → machine.id → alias → hostname → none); no first-profile fallback; `machineAlias` is a cached result | `<alias>` = resolver result (`MACHINE_ALIAS`/`MACHINE_VIA`). Writer allowed for `via` ∈ {id, environment, alias, override}; refused (rc 3) for `hostname`/`none`/no dotprofile | tree §8 "Location", "Writer"; §7.2 |
| X4 | Exception **engine** | perl `JSON::PP` / `ConvertFrom-Json`, "or whatever M3 standardises", must work at Step 1 without node | every profile.json read/write goes through node `aitools-profile.js` (temp → validate → backup → move in `register`) | `aitools-profile.js exception-get` / `exception-set` subcommands, wrapped by M2's `tool_exception_get/record`. One write implementation for a shared git-tracked file in both shells; avoids `ConvertTo-Json` reformatting and the minimal-Linux `JSON::PP` gap. Step 1 is not a real constraint: on a fresh machine gh runs before node AND before any dotprofile exists, so there is nothing to read; later runs have node. No node → reader rc 1 (no exception), writer rc 1 | tree §8 "Engine", "Bootstrap"; user-repo.md copy; new batch **X-B1** (section 5) |
| X5 | Warning promotion (new, S4-Review) | `write_summary` promotes OK→WARN once WARNINGS>0 (verified `aitools-lib.sh` `write_summary`, lines 344-353) | `resolve_machine_profile` calls `log_warn` (node missing; "matched by hostname only"; alias disagrees) and writes its own summary rows | If the exception reader called the M3 wrapper as-is, every non-preferred tool's row would turn WARN on this Mac until it registers (`via=hostname` today per S5-Profile T0). Fix: reader called only at T5, logs resolver warnings as `log_detail`, one `log_warn` only when the store is unavailable | tree §8 "Reader" |
| X6 | KEEP severity vs ACTION pairing (C-05) | KEEP = OK `(kept)` (D-TS10) but "every ACTION pairs with a log_warn" → promoted to WARN | -- | Carry-forward ACTION `commit profile.json` written without a paired warn (the one exception, stated in §3 and §8); refused/failed write = WARN `<ver> (kept, not saved)` | tree §3 KEEP row + note |
| X7 | Who commits the dotprofile | KEEP → ACTION "commit profile.json" (no auto-commit) | `register` commits and pushes best-effort (user-repo.md "Registration") | Keep both as drafted (user init is an explicit dotprofile command; setup scripts never commit); stated in §8. Open question **N-Q2** | tree §8 "Carry-forward" |
| X8 | Exit 2 semantics (new) | exit 2 from a setup script = user abort; installers stop the run (§7.5) | lib wrappers return 2 = "no match / error" (`aitools-lib.sh.profile-block.sh` lines 57, 95, 131) | Rule line: a script never passes a helper's rc 2 through as its exit code. Verified no M3 script draft uses `exit 2` (grep) | `S4-Review-drafts/.claude/rules/interactive-menus.md` "Tool install-method menu" |
| X9 | interactive-menus.md scope (C-35) | edits intent + tool-menu section; "installers apply the same rule to their own prompts … otherwise use the default" | adds a third menu (user init: numbered aliases, `[n]ew`, `[s]kip`) whose non-terminal outcome is ERROR + ACTION, not a default | Merged copy adds "Machine registration menu" section and widens intent; also C-24 (`[k]eep` vs `[s]kip` persistence) and C-25 (abort stops the run only once 7.5 lands) | interactive-menus.md copy |
| X10 | Glossary terms (both add; C-14..C-18) | tool adoption, tool exception, update channel; modify managed tool | machine profile, machine alias, machine identity, derived config | One batch of 7 terms. Renamed: `machine identity` → **machine id** (profile.json `identity` = the user, C-15); `derived config` → **aitools config** (standalone; "derived" is no scope modifier, C-17). Fixed: `tool exception` (version check still runs, C-07; "machine profile" not "dotprofile profile", C-30), `machine alias` (example `nobul-mac`; not the base artifact `alias`, C-16), `machine profile` (not a shell profile), `managed tool` (inline installer owners, C-29), `update channel` (points to the reference list, C-09) | `S4-Review-drafts/registries/glossary.terms-draft.json`, `S4-Review-drafts/.claude/rules/glossary.md` |
| X11 | `.claude/rules/managed-file-deployment.md` (both edit) | companion: fix dangling "Deployment pattern updates" pointer (I-14) | "Content sources": replace "Fallback: hostname match, then first profile" | One edit file, both changes; pointer retargeted to `/tool-adopt` step 5 (the content survives only at `.cursor/rules/tool-lifecycle.mdc:135`, verified) | `S4-Review-drafts/.claude/rules/managed-file-deployment.md.edit.txt` |
| X12 | `sources-of-truth.md` (M2 edits; M3 none) | intent + 3 rows | user-repo.md gains schemas/resolution/writers | Merged copy also updates the `reference/user-repo.md` row description | sources-of-truth.md copy |
| X13 | `meta.intent` conventions | registry `meta.intent` object `{purpose, scope, audience}` | profile.json and config.json `meta.intent` same object | Consistent with `shared/skills/intent-writing/SKILL.md` "JSON files" and every existing registry (`meta.intent` dict in all 5 registries, checked). Version keys differ on purpose: registries use `meta.schemaVersion` ("1.1"); profile.json keeps top-level `version: 2` + `meta.schemaRevision: "2.1"` (older releases destroy any other version, S5-Profile §2); config.json `version: 3`. No edit; recorded so nobody "harmonises" it | -- |
| X14 | profile.json `meta.intent` audience | -- | omits the tool-exception reader/writer | Audience now names `aitools-profile.js` as the only writer of machine entries and toolExceptions and the tool setup scripts via the helpers | `S4-Review-drafts/dotprofile/profile.json` |
| X15 | `new-mac` → `nobul-mac` | none in M2 (C grep) | profile.json draft key, user-repo.md:160, :184, glossary example, plan B0/B2/B4/B5/B6 expected outputs, 5 test scripts | Fixed in the three landing drafts. Plan expected outputs and test scripts (`test-writer.sh:24,26`, `test-resolver.sh:21-23,30`, `test-lib-wrappers.sh:22`, `run-ps1-test.sh:9`, `review/test-review-resolver.sh:14`) must be updated before re-running (C list). B0 is DONE: live `~/.aitools/config.json` has `machineAlias: "nobul-mac"`, dotprofile `profile.json` has the `nobul-mac` key (commit bce27bb, read 2026-10-21) | profile.json, user-repo.md copies |
| X16 | M3 draft text vs M3 code (new) | -- | user-repo.md says machine.id = "first 16 hex of the SHA-256"; `aitools-profile.js` `machineId()` uses `crypto.createHmac('sha256','aitools-machine-id-v1')` (line 174) | Doc now says HMAC-SHA256 with the fixed key | user-repo.md copy |
| X17 | Draft profile.json vs live file (new) | -- | B10 says "apply migrated profile.json" | The draft was built before bce27bb; B10 must re-derive from the live file (add meta, identity.name/company, `nobul-mac.machine.id`), not copy the draft | report only |
| X18 | Lib batches touch the same files | B2 `aitools-lib.sh`, B3 `.ps1` (tool helpers, bash 3.2 rule) | B2 both libs (resolver wrappers, `validate_json_config` move) | Serialise: M3 B2 first. M3's lib block is bash-3.2 safe (`<<<`, `$'\t'`, `local`; no `declare -A`/`mapfile`; read in full) | section 5 |
| X19 | Installer / entry-point overlap | B4a `validate_and_run` / `Invoke-ValidatedScript` exit 2; B4b entry points | B3/B3b Step 5 + Step 21; B6/B7 user init, env export, deploy list | M3's plan carries verbatim `old` blocks from the tree, M2's batches have none yet: land M3 B3/B3b and B6/B7 first, then write M2 B4a/B4b against the new tree | section 5 |
| X20 | check scripts | §9 new pre-commit step; step 29 parity extension | H5/M7: pre-push step 7 must pass `AITOOLS_USER_REPO_PATH` explicitly, unset `AITOOLS_PROFILE_FILE`/`AITOOLS_MACHINE_ALIAS`, add `aitools-profile.js` to its trigger regex | Owner was "check-pre-push owner" (none). New batch **X-B2** before M3 B6/B7 (the first batch that exports the variable). Step 29 extension for both new menus = **X-B3** | section 5 |
| X21 | `setup script` scope (C-13) | rule/trigger/hook say `scripts/setup-*` | `setup-user-config` is a new `scripts/setup-*` that is NOT a tool script | "tool setup script = named by a registry `lifecycle.setupScript`" in the rule and the planned hook | `S4-Review-drafts/.claude/rules/tool-lifecycle.md`, tree §9 |
| X22 | S2-Split dependency (flag only, not decided) | `.claude/skills/tool-adopt/` (new), `tool-eval/`, `tool-registry/` drafts; sources-of-truth rows; framework-registry entry artifact paths; glossary `source` fields; managed-file-deployment pointer to `/tool-adopt` | `.claude/skills/glossary` and `/incident` path findings (#59, #84) | Every path above moves if S2-Split moves project skills to `shared/skills/`. The working tree already holds untracked copies at `shared/skills/{audit,frameworks,glossary,governed-data,harvest,incident,tool-eval,tool-ops,tool-registry}/` (`git status`, 2026-10-21); documentation-standards "No project overrides of user skills" forbids same-name skills at both levels | -- |

**Local checkout hazard (blocking pre-step, not a design conflict).** PR #50 (S3-Nine) and #52 (incidents #74-#86) are MERGED (`gh pr list`, origin/main 26c37b2). The local `main` working tree still has the pre-merge S3-Nine edits staged in `scripts/build-deploy.sh`, `check-hook-parity.py`, `check-post-push.sh/.ps1`, and they differ from merged main: e.g. local `build-deploy.sh` exits 1 when node is missing (main: WARN + exit 0) and `continue`s on a missing hook source (main: `exit 1`, "never skip") (`git diff origin/main -- scripts/build-deploy.sh`). A commit from this checkout would revert merged fixes. Before any batch: reset these four files to `origin/main` (commander's call; I did not touch them), then re-verify every M3 `old` block against c491c59 (the plan's B5 claims not to touch lines 66-107, which is where the differences are, but the precondition "matches exactly once" must be re-checked).
## 2. Adversarial review of `reference/tool-support-decision-tree.md` (revision 2)

**Coverage.** I launched three reviewers with different lenses.
- **S4-Review-C** (ambiguity, duplication, vocabulary) completed. Its full table is in `S4-Review-C-review.md`.
- **S4-Review-A** (correctness vs rules) and **S4-Review-B** (cross-platform and bootstrap) wrote nothing. B left only `S4-Review-B-scratch/probe.sh`. The session restarted while they were running; the scratchpad was reset at the same time.

I covered A's and B's lenses only with targeted checks (S4-1..S4-9 below):
- read the existing helpers, the installer exports and the `write_summary` promotion;
- read the M3 lib block for bash 3.2 safety;
- grepped the M3 drafts for exit-2 use.

**The tree has not had a full correctness or Windows-execution pass. Recommend re-running A and B on `S4-Review-drafts/reference/tool-support-decision-tree.md` (rev 3) before the gate.**

### Fixed in the S4 copy (rev 3)

| ID | Sev | Section | Finding | Fix |
|---|---|---|---|---|
| C-01 | blocker | §8 | Two toolExceptions shapes, circular ownership | Merged shape; user-repo.md owns it (section 1 X1) |
| C-02 | blocker | §8, §7.2 | Writer refuses after registration (assumes config alias, "first profile" fallback) | via-based rule (X3) |
| C-03 | major | M3 user-repo.md | `method` examples are install kinds | registry method id or `unknown` |
| C-04 | major | M3 user-repo.md | "non-managed install" collides with governed "managed tool" | wording replaced in shape |
| C-05 | major | §3 KEEP | ACTION→log_warn→OK promoted to WARN, defeating D-TS10 | carry-forward ACTION exempt; WARN `(kept, not saved)` on failure |
| C-06 | major | §3, rule item 6 | D-TS10/11/12 pending but written as settled | rows marked "(pending)"; rule item 6 qualified |
| C-07 | major | glossary | "no post-check" contradicts version check | glossary draft fixed |
| C-09 | major | rule, glossary, FW, /tool-adopt | channel list restated 4× | rule and glossary point to the reference (FW and /tool-adopt still to fix, below) |
| C-10 | major | rule item 4 | `[i]nstall alongside` missing | rule copy fixed |
| C-11 | major | T1 | specificity tie undefined; ambiguity misreported | specificity = count of explicit matching dimensions; own detail `two methods for <platform>` + ACTION |
| C-12 | major | rule vs §9 | MUST without migration clause | rule copy: unmigrated scripts get fixes only; other changes migrate via /tool-adopt |
| C-13 | major | rule, §9 hook | "setup script" includes `setup-user-*` (and M3's new `setup-user-config`) | "tool setup script = named by `lifecycle.setupScript`" in rule and hook |
| C-15..C-17 | major | M3 glossary | identity / alias / "derived" collisions | renames + disambiguation (X10) |
| C-18 | major | §6 | `verified` field vs governed outcome | §6 defines the field's meaning (N-Q4) |
| C-19 | minor | §7.1 | generator and unverified known paths | generator emits only verified entries |
| C-20 | minor | §3 PREREQ | `not provided by claude-code-web` = 31 chars | `not in <env> image` |
| C-21, C-34 | minor | §8 | `environment` unused; `by` undefined | dropped / `decidedBy` = script base name |
| C-23 | minor | §7 | "adopt" claim inaccurate | reworded |
| C-24, C-25, C-35 | minor | interactive-menus | keep vs skip persistence; abort is future behaviour; third menu out of scope | merged copy |
| C-26, C-27 | minor | §2, rule | "Standard 4" cites the wrong file; "#12" ambiguous | cite script-standards-detail; "GitHub issue #12" |
| C-31, C-32 | minor | intents | rule purpose overstates; reference scope misses §7.5, /audit, hook | both intents redrafted (protected: need approval) |

### Not fixed in a copy: edits the M2 author must make to sibling drafts

These are recorded, not drafted, because the files are M2's and the fixes are mechanical.
- **C-08 (major).** `/tool-registry`, `/tool-adopt` and `/tool-eval` restate §6 and contradict it in three ways:
  - they say `kind` is required everywhere;
  - they say `update` or `autoUpdates` is required;
  - they say one preferred method "per environment".

  Replace each restatement with "every field in the reference 'Tool registry schema 1.1', validated by its conformance checks 1-6".
- **C-09, rest.** In the framework doc and `/tool-adopt` step 3, point to "Update channels".
- **C-14 (major).** Govern "detection signature" for the registry field, kept separate from the hook-layer term `detection`. This is a glossary item and needs a decision.
- **C-22.** In `/tool-adopt` and `/tool-eval`, replace "exception rule" / "exception to the decision tree" with "deviation from the decision tree".
- **C-28.** In the skills, cite sections by title, not by number.
- **C-29, C-30.** Glossary (done).
- **C-33.** In the framework doc, move the DRAFT banner above the intent block.

### S4-Review's own findings (correctness and cross-platform lenses, partial)

| ID | Sev | Section | Finding | Evidence | Disposition |
|---|---|---|---|---|---|
| S4-1 | major | §8 reader | Calling the M3 wrapper from a tool script would promote OK rows to WARN through resolver warnings | `aitools-lib.sh` `write_summary` lines 344-353 (WARNINGS>0 → WARN); profile block `log_warn` lines 88, 112 | fixed (X5) |
| S4-2 | major | §8 engine | perl/`ConvertFrom-Json` engine conflicts with M3's single node module, and `ConvertTo-Json` would rewrite a shared git file | M3 plan B1/B2; X4 | fixed: `exception-get/set` subcommands (new batch X-B1) |
| S4-3 | minor | §7.5 | "installers pass AITOOLS_FORCE" is wrong: the entry points export it | `scripts/aitools:307, :1577`; installers only read it (`aitools-install.sh:180`, `.ps1:87`) | fixed |
| S4-4 | minor | §7.5 / menus | Exit 2 = abort collides with lib return code 2 = error | profile block lines 57, 95, 131 | rule line added (X8) |
| S4-5 | minor | §8 PS1 | Exception reader must decode node output via a temp file | cross-platform.md "PowerShell pipeline encoding" | fixed |
| S4-6 | minor | §10 | No tests for a refused write, a missing store, the reader staying silent for preferred tools, or dry run with a pty | -- | 5 rows added |
| S4-7 | info | §7 | bash 3.2 rule: the M3 lib block complies | profile block read in full | none |
| S4-8 | info | §1, §7.2 | Cited helpers exist | `tty_interactive`, `read_tty_choice`, `Test-InteractiveConsole`, `Read-ConsoleChoice`, `Write-EnvironmentSkip`, `Refresh-Path`, `check_build_prereqs`, `diagnose_build_failure` (grep) | none |
| S4-9 | minor | §5 | macOS can use case-sensitive APFS volumes, so "case-insensitive on macOS" path matching can match the wrong path there | general platform fact; unknown whether any of Jose's machines use one | flag only; propose "case-insensitive on Windows; on macOS case-insensitive unless the volume is case-sensitive" for reviewer B |

**Prior-review fixes that landed (spot-check).** These rev-2 claims are present in the text:
- D-01: `rc=0; tool_support_run … || rc=$?` (§7.6);
- D-02: five removal guards (§7.3);
- A-04: EVALUATING leaf;
- C-04: PATH-resolved path, `versionedPath`;
- D-07: entry points in §7.5.

I did not re-verify the other ~45 dispositions. That was A's job.
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
## 4. INCIDENT findings, merged and de-duplicated

Checked against #1-#86 in origin/main 26c37b2 `registries/incidents.json`. PR #52 merged, so main already has #74-#86; the table was extracted with `S4-Review-scratch/list-incidents.sh`. Full entries, with every required field from incident-governance.md: `S4-Review-incidents-draft.json`.
- All drafts are `status: open`, because the mission plans are not repo plans yet.
- `linked` names the batch that would fix each one.
- Filing is the commander's call. The `/incident` skill still points to `reference/incidents.json` (#84); file into `registries/incidents.json`.

### New drafts (#87-#113)

| Draft id | Sev | Title (short) | From |
|---|---|---|---|
| 87 | high | Exit 2 / `[x]abort` treated as ordinary failure by both installers and `scripts/aitools` | M2 I-02 + I-24 |
| 88 | high | setup-datadog.sh `rm -f`s unknown-origin pup | M2 I-03 |
| 89 | high | Tool setup scripts ignore AITOOLS_DRY_RUN (dry run can `sudo rm -rf /usr/local/go`) | M2 I-22 |
| 90 | medium | Registry detection/platformStatus data not machine-usable | M2 I-07 + I-08 |
| 91 | medium | Step 8 OK for any node; preferred node@22 keg-only off PATH | M2 I-09 |
| 92 | medium | setup-perl.sh requires brew although system perl is preferred | M2 I-10 |
| 93 | medium | Framework registry Tool-ops path / Tool-lifecycle entry stale | M2 I-05 |
| 94 | medium | managed-file-deployment.md dangling pointer; tool-lifecycle.mdc drift | M2 I-14 + I-23 |
| 95 | high | build-deploy.sh hardcodes one user's identity defaults, used silently | M3 |
| 96 | medium | MDM embeds shared template, dev path the dotprofile template | M3 |
| 97 | medium | user init writes config/profile without backup; swallowed write error | M3 |
| 98 | medium | `inline_lib_*` replace any line naming the lib | M3 review I-a/H1 |
| 99 | medium | `adopt_claude_md` perl program built from shell values (`@`, `/`) | M3 review I-b/H6 |
| 100 | medium | Empty catches in `aitools`, `aitools.ps1`, `hh.ps1` (re-verified, line numbers corrected) | M3 review I-c |
| 101 | medium | UNVERIFIED: Git Bash user init writes MSYS-form userRepoPath | M3 |
| 102 | low | sources-of-truth omits project skills and tool-registry.md | M2 I-15 |
| 103 | low | 30-char summary limit "compliance-checked" but unchecked | M2 I-16 |
| 104 | low | Missing intents (D-TS9) | M2 I-17 |
| 105 | low | /tool-registry required fields absent in 16/18 entries | M2 I-19 |
| 106 | low | `reference/evaluations/` gate unmet (1 file / 18 tools) | M2 I-12 |
| 107 | low | ripgrep installed with no registry entry | M2 I-13 |
| 108 | low | cross-platform.md names nonexistent `install_via_brew/apt` | M2 I-25 |
| 109 | low | build-deploy `eval` of profile values | M3 |
| 110 | low | Token interpolation breaks on `&` / `$` | M3 |
| 111 | low | ait-harvest.py utf-8 without BOM handling | M3 |
| 112 | low | cross-platform.md `C:\repos\` vs `%USERPROFILE%\repos` | M3 review I-e |
| 113 | low | "Standard 4" cited as a rule section | S4-Review-C |

### Dropped as covered (update the existing entry instead)

| Finding | Covered by | Suggested update |
|---|---|---|
| M2 I-01 (7 scripts remove before verify; rule "SHOULD") | #55 (go, typst, rule ordering) | extend `affected`: setup-pandoc.sh, setup-rust.sh, setup-vercelcli.sh, setup-go.ps1, setup-datadog.sh |
| M2 I-04, M3 glossary-path finding | #59 (+ #84 for /incident) | add `.claude/skills/frameworks/SKILL.md` to `affected` |
| M2 I-18 (setup-bash headers cite `reference/tool-registry.json`) | #59 (same class) | add `scripts/setup-bash.sh/.ps1` |
| M2 I-06, I-11 (tool-registry.md / tool-versions.json drift, checks parse md, `TOOL_CMDS`) | #21 | update observation: JSON exists, md and tool-versions still parsed by check-post-push steps 9, 10, 21, 25 |
| M2 I-21 (criteria omit Linux) | #54 | none |
| M2 I-26 (sources-of-truth lists JSON paths) | #50 | none |
| M3 "build-deploy interpolates the building machine's profile" | #78 | none |
| M3 user-repo.md:139 "detects machineAlias" | #75 / #76 (user-repo rewrite) | none |
| M3 carried S2-Host items (Path 1 never persists alias, first-profile fallback, check_profile, NO_MACHINE_MATCH, PS1 COMPUTERNAME, parked defect) | #74, #75, #76, #77, #79 | none |
| C: managed-file-deployment.md still says "first profile" fallback | #76 | add `.claude/rules/managed-file-deployment.md` to `affected` |

Routed to `/glossary`, not incidents: M2 I-20 (provenance); C's TODO(glossary) items (`detection`, `user config` example, "profile" with three meanings, "recovered"). These are listed in `glossary.terms-draft.json` `open_glossary_items`.
## 5. Combined approval batch and implementation order

### 5.1 Protected files in the one approval batch

Path = repo path (S2-Split may move `.claude/skills/*` paths). "Draft" = where the review copy lives (S4 = `S4-Review-drafts/`, T = `S5-Tools-drafts/`, P = `S5-Profile-drafts/`).

| # | Path | New/edit | Mission | Intent status | Draft |
|---|---|---|---|---|---|
| 1 | `reference/tool-support-decision-tree.md` | new | M2 (+S4 rev 3) | new intent, DRAFT (S4 widened scope: exit-2 contract, /audit additions, hook, shape owner) | S4 |
| 2 | `.claude/rules/tool-lifecycle.md` | edit (rewrite) | M2 (+S4 fixes) | modified intent, DRAFT (S4 rewording per C-31) | S4 |
| 3 | `reference/framework-tool-lifecycle.md` | edit | M2 | modified intent, DRAFT | T (+ C-33 banner placement, C-09 channel row) |
| 4 | `.claude/skills/tool-adopt/SKILL.md` | new | M2 | new intent, DRAFT | T (+ fixes in section 2 / C-08, C-22, C-28) |
| 5 | `.claude/skills/tool-eval/SKILL.md` | edit | M2 | modified intent, DRAFT | T (+ C-08, C-22) |
| 6 | `.claude/skills/tool-registry/SKILL.md` | edit | M2 | modified intent, DRAFT | T (+ C-08) |
| 7 | `.claude/rules/interactive-menus.md` | edit | M2 + M3 (merged) | new intent (file had none), DRAFT | S4 |
| 8 | `.claude/rules/sources-of-truth.md` | edit | M2 + M3 (merged) | new intent (file had none), DRAFT | S4 |
| 9 | `.claude/rules/glossary.md` | edit (7 terms) | M2 + M3 (merged) | unchanged | S4 |
| 10 | `registries/glossary.json` | 7 terms added, `managed tool` modified | M2 + M3 (merged) | n/a | S4 `glossary.terms-draft.json` |
| 11 | `registries/tool-registry.json` | schema 1.1 (+ node/go illustrative entries) | M2 | modified `meta.intent`, DRAFT | T |
| 12 | `registries/framework-registry.json` | edit (Tool lifecycle entry) | M2 | n/a | T (write only once paths exist) |
| 13 | `.claude/rules/managed-file-deployment.md` | edit (2 changes) | M3 + M2 (merged) | none today (incident draft #104) | S4 `.edit.txt` |
| 14 | `.cursor/rules/managed-file-deployment.mdc`, `tool-lifecycle.mdc`, `interactive-menus.mdc` | mirror edits | M2 + M3 | n/a | not drafted (mirror of 2, 7, 13) |
| 15 | `.claude/rules/git-safety.md` | edit (`generated/` fully generated, tracked) | M2 companion | none | not drafted |
| 16 | `reference/script-standards-detail.md` | edit (SHADOWED severity line, `n/a (<platform>)`, `<ver> (kept)`, `under evaluation`) | M2 companion | none | not drafted |
| 17 | `shared/skills/aitool-eval/SKILL.md` | refresh derived card | M2 companion | existing | not drafted |
| 18 | `reference/user-repo.md` | edit (rewrite) | M3 (+S4) | new intent, DRAFT | S4 |
| 19 | `shared/claude-shared.md` + `<dotprofile>/claude/CLAUDE.md` | edit (Cross-Platform Awareness lines) | M3 | n/a | P `claude-shared.md.edit.txt` |
| 20 | `.claude/rules/deploy-paths.md` | edit (setup-user-claude row; aitools-profile.js auto-embedded) | M3 | none | P report §5 |
| 21 | `.claude/rules/config-file-safety.md` | edit (reference example) | M3 | none | P report §5 |
| 22 | code intents: `scripts/aitools-profile.js`, `scripts/setup-user-config.sh/.ps1`, lib section intents (both libs) | new | M3 | new intents, DRAFT | P |
| 23 | `meta.intent` of `~/.aitools/config.json` (in the writers) and dotprofile `profile.json` | new | M3 (+S4 audience) | new, DRAFT | P / S4 profile.json |
| 24 | `registries/incidents.json` | 27 new entries (#87-#113) + `affected` updates to #21, #55, #59, #76 | S4 | n/a | `S4-Review-incidents-draft.json` |
| 25 | Intents for each migrated setup script (M2 B5-B17) | new | M2 | drafted per batch, approved before delegation | not yet |

Pending-decision rows inside the batch: D-TS10/11/12 (marked "pending" in the S4 copy), N-Q1, N-Q3.

### 5.2 Implementation order (one sequence, both missions)

PR #50 (S3-Nine) merged 2026-10-21T02:33Z and PR #52 at 02:44Z (`gh pr list`), so "land after S3-Nine" is satisfied; what remains is re-verifying the plan's `old` blocks against origin/main c491c59 and resetting the local checkout (N-Q5).

| Step | Batch | Files | Depends on | Conflict notes |
|---|---|---|---|---|
| 0 | N-Q5 reset | local `scripts/build-deploy.sh`, `check-hook-parity.py`, `check-post-push.sh/.ps1` → origin/main | -- | commander action |
| 0b | M3 B0 | none | -- | **DONE** (config.json `machineAlias: nobul-mac`; dotprofile bce27bb) |
| G | approval gate | section 5.1 | 0 | one review page |
| 1 | M3 B1 | `aitools-profile.js` (new), `profile-check.js` | G | tests: update `new-mac` in 5 test scripts first (X15) |
| 2 | **X-B1 (new)** | `aitools-profile.js` (`exception-get`/`exception-set`, same temp→validate→backup→move as `register`) | 1 | M3 owns the file; tool semantics from tree §8 |
| 3 | M3 B2 | `aitools-lib.sh`, `aitools-lib.ps1` | 1 | before M2 B2/B3 (same files, X18) |
| 4 | M3 B3, B3b | `setup-user-config.sh/.ps1` (new), `aitools-install.sh`; `aitools-install.ps1` | 3 | before M2 B4a (same files, X19) |
| 5 | M3 B4 | `setup-user-claude.sh/.ps1` | 3 | -- |
| 6 | M3 B5 | `build-deploy.sh` | 1, 5 | re-verify old blocks vs c491c59; P-Q8..Q11 |
| 7 | **X-B2 (new)** | `check-pre-push.sh/.ps1` step 7: pass `AITOOLS_USER_REPO_PATH` explicitly, unset `AITOOLS_PROFILE_FILE`/`AITOOLS_MACHINE_ALIAS`, add `aitools-profile.js` to the trigger regex (S5-Profile-A H5, M7) | 6 | must land before step 8 (first export of the variable) |
| 8 | M3 B6, B7 | `scripts/aitools`, `scripts/aitools.ps1` | 4, 6, 7 | before M2 B4b (same files) |
| 9 | M3 B8a-c | settings/skills/cursor/check-lib/ait-harvest | 3 | -- |
| 10 | M2 B1 | registry 1.1 data (go, typst, vercel-cli) via `/tool-registry`; `scripts/gen-tool-specs.py`; `generated/tool-specs/` | G | needs git-safety.md edit (5.1 #15) |
| 11 | M2 B2, B3 | `aitools-lib.sh`; `aitools-lib.ps1` (tool helpers incl. `tool_exception_get/record` wrapping X-B1) | 2, 3, 10 | bash 3.2 rule |
| 12 | M2 B4a, B4b | installers exit 2; entry points exit 2 | 4, 8 | closes incident draft #87 |
| 13 | M2 conformance step | `check-pre-commit.sh/.ps1` "Tool support conformance" (WARN phase) | 10, 11 | not batched in the M2 report; added here |
| 14 | M2 B5..B17 | one tool script pair per batch, order as M2 (typst, vercelcli, pandoc, rust, go, datadog, uv, gh-cli, python, modal, perl, bash, google-chrome) | 11, 12 | each closes part of #89 (dry run) and #55 |
| 15 | **X-B3 (new)** | `check-post-push.sh/.ps1` step 29: menu parity for `tool_method_menu` and the user init registration menu | 8, 11 | both menus must exist |
| 16 | M3 B9 | protected docs written (approved at G) | G, 1-9 | user-repo.md, claude-shared.md + dotprofile template, rules, glossary |
| 17 | M3 B10 | dotprofile profile.json (re-derived from the live file, X17); each machine runs `aitools user init` once | 8 | commander |
| 18 | **X-B4 (new)** MDM | `build-deploy.sh`: embed `generated/tool-specs`, tool helpers, `deploy/setup-user-config.*` | 6, 9, 11 | P-Q7 + T-Q1; one build-deploy batch |
| 19 | M2 B18+ | setup-node (M4), setup-claude-code, setup-cursor-agent, setup-pwsh via `/tool-adopt` | 14 | also `shared/claude-shared.md` rows (after step 16, same file) |

Docs (step 16) can also land right after G if the commander prefers docs-first; the ordering above lands docs once the code they describe exists, which keeps `/audit` from flagging spec-without-code drift.
