# S2-Layout-B: registry consumer inventory

Delegate S2-Layout-B (read-only), session 360aa8f3-8, 2026-10-20. Repos: aitools
`/Users/new-jose/repos/aitools` (branch main, working tree has staged S3-Nine work and
untracked `shared/skills/{audit,frameworks,glossary,governed-data,harvest,incident,tool-eval,tool-ops,tool-registry}/`),
dotprofile `/Users/new-jose/repos/aitools-nobul-jose`.

Method: grep for `(registries|reference)/(incidents|glossary|framework-registry|tool-ops|tool-registry|tool-versions)\.json`
over scripts/ shared/ .claude/ .cursor/ reference/ plans/ (excluding plans/mission-command-briefing/) rfcs/ tests/ .github/
CLAUDE.md ROADMAP.md README.md registries/; a second grep for bare `<name>.json` in code dirs; dotprofile claude/ profile.json
deploy/. Scanner: `s2b-scan.sh`; raw output `s2b-aitools-prefixed.out`, `s2b-aitools-bare.out`, `s2b-dot.out`, `s2b-sizes.out`
(same directory). Excluded per brief: .claude/worktrees/, harvesting/, .scratch/, aitools deploy/ (frozen), sessions/ archives,
RELEASE_NOTES.md (41 historical hits), .aitools/channel/.

No WRITE_BLOCKED events. One tool call was blocked by the standing-order hook (`cat` of check.yml); used Read instead.

## 0. Headline findings

1. **No consumer resolves a registry path from `~/.aitools/config.json` `repoPath`.** Every skill cites a cwd-relative path
   (`registries/x.json` or `@registries/x.json` / `@reference/x.json`; `@` is plain text in a SKILL.md). Check scripts resolve
   `$SCRIPT_DIR/..`. The single hook that reads a registry uses an env var nobody sets, then a hardcoded `~/repos/aitools`.
   So a user-level skill reaching a registry from any repo has no mechanism today. `config.json` does hold
   `"repoPath": "/Users/new-jose/repos/aitools"` (`~/.aitools/config.json:4`).
2. **Registries are written only by agents via skills.** No script, hook, python module, test, or CI step writes any of the six
   registries (grep of scripts/, shared/hooks/, tests/, .github/ finds only readers). Only two programmatic readers exist:
   `check-post-push` step 10 (existence) and step 21 (tool-versions.json content), plus the dead tool-ops hook.
3. **Stale `reference/<x>.json` paths are the majority.** Of the active consumer references (skills, rules, hooks, scripts,
   .cursor rules, reference docs; excluding plans/rfcs/registry data), 52 lines cite `reference/<x>.json` (stale) vs 18 citing
   `registries/<x>.json`. Only `/tool-registry` and `/tool-ops` (step 1) were repointed in b2641c0.
4. **Incident #70 verified** (section 2.1). Plus three new defects: check-post-push.ps1 steps 10 and 21 still use
   `reference/tool-versions.json` (bash was fixed, PS1 was not); pre-commit step 16 PS1 pattern misses `registries/`;
   the incidents.json PreToolUse validator in incident-governance.md is not in hooks-manifest.json.

## 1. Consumer table

Legend: stale = cites `reference/<x>.json` (file does not exist there; `find reference -name '*.json'` returns nothing).
Resolution: **cwd** = relative to agent cwd / repo root, only works when cwd is the aitools root; **SD** = `$SCRIPT_DIR/..`
(`REPO_ROOT`, check-post-push.sh:7, check-pre-commit.sh:8, check-post-push.ps1:8); **env+hc** = env var then hardcoded abs path;
**text** = comment/doc only, never resolved.

### 1.1 Hooks

| file:line | path cited | stale | type | R/W | resolution |
|---|---|---|---|---|---|
| shared/hooks/tool-ops-session-audit.sh:23-24 | `$AITOOLS_REPO_PATH/reference/tool-ops.json` | y | hook (SessionEnd) | R (existence only, content never parsed) | env `AITOOLS_REPO_PATH` (set nowhere: only grep hit is this file) |
| shared/hooks/tool-ops-session-audit.sh:25-26 | `$HOME/repos/aitools/reference/tool-ops.json` | y | hook | R | hardcoded abs (`~/repos/aitools`; wrong for `C:\repos` Windows layout in cross-platform.md) |
| shared/hooks/tool-ops-session-audit.sh:85-88 | `.../reference/tool-ops-claude-code.md` (not a registry) | n | hook | R | env+hc |
| shared/hooks/glossary-skill-guard.sh:31-32 | `*glossary.json\|*glossary.md` (basename glob) | n/a | hook (PreToolUse Read\|Grep) | detection only | path-agnostic: matches any path ending in glossary.json; survives any move |
| dotprofile deploy/setup-user-hooks.sh:2235-2238, .ps1:2377-2380 | embedded copy of the stale hook | y | generated setup script | -- | same as source |
| dotprofile deploy/setup-user-hooks.sh:3101, .ps1:3250 | embedded glossary guard | n/a | generated | -- | -- |

### 1.2 Check scripts and CI

| file:line | path cited | stale | type | R/W | resolution |
|---|---|---|---|---|---|
| scripts/check-post-push.sh:233 | `registries/tool-versions.json` (step 10 protected-file inventory) | n | check | R (existence) | SD |
| scripts/check-post-push.sh:448-450 | `$REPO_ROOT/registries/tool-versions.json` (step 21 version freshness, python parses `tools`) | n | check | R | SD |
| scripts/check-post-push.ps1:268 | `reference/tool-versions.json` (step 10) | **y** | check | R (existence) | SD (`Join-Path $script:RepoRoot`) |
| scripts/check-post-push.ps1:520-522 | `Join-Path $RepoRoot "reference" "tool-versions.json"` (step 21) | **y** | check | R | SD |
| scripts/check-pre-commit.sh:339-341 | regex `@?(reference\|registries)/[a-z0-9-]*\.json` over `.claude/rules/ CLAUDE.md` (step 16) | n/a | check (detector) | scan | cwd after `cd "$REPO_ROOT"` (check-pre-commit.sh:28) |
| scripts/check-pre-commit.ps1:336-339 | `Select-String '@?reference/.*\.json'` (step 16) | **misses registries/** | check (detector) | scan | SD |
| scripts/check-post-push.sh:214-215, 230, 636; .ps1:248, 265, 739; check-prereq-detection.ps1:199 | `reference/tool-registry.md` (markdown twin, not JSON) | n (file exists) | check | R | SD |
| .github/workflows/check.yml (whole file) | none | -- | CI | -- | CI never reads a registry: syntax checks, logging tests, build-deploy, deploy drift, script pairing only |

### 1.3 Skills (project `.claude/skills/` and the untracked `shared/skills/` copies; the copies are byte-identical, `diff -rq` 2026-10-20)

Every row exists twice: `.claude/skills/<s>/...:N` and `shared/skills/<s>/...:N` (same line numbers). Only `.claude/skills/` is
tracked; `shared/skills/<s>/` for these nine was created untracked at 19:42 today by another session.

| skill file:line | path cited | stale | R/W | resolution |
|---|---|---|---|---|
| tool-registry/SKILL.md:20, 67, 108 | `@registries/tool-registry.json` | n | R/W (step 1 read, write via review gate) | cwd |
| tool-registry/SKILL.md:77 | `registries/tool-registry.json` (schema note) | n | text | cwd |
| tool-ops/SKILL.md:20 | `registries/tool-ops.json` | n | R/W | cwd |
| tool-ops/SKILL.md:106 | `reference/framework-registry.json` | y | xref | cwd |
| tool-ops/tests/expected-behaviors.md:15, 23, 77 | `reference/tool-ops.json` | y | test spec | text |
| glossary/SKILL.md:12, 22, 35, 127 | `@reference/glossary.json` | y | R/W | cwd |
| incident/SKILL.md:8, 48, 88, 124 | `reference/incidents.json` | y | R/W (step 48: read highest id) | cwd |
| frameworks/SKILL.md:22, 45, 71 | `@reference/framework-registry.json` | y | R/W | cwd |
| audit/SKILL.md:103, 121 | `reference/incidents.json` | y | R | cwd |

User-level skills already deployed to `~/.claude/skills/` (tracked in shared/skills/):

| file:line | path cited | stale | R/W | resolution |
|---|---|---|---|---|
| shared/skills/optimize-plan/SKILL.md:34 | `reference/incidents.json` | y | R | cwd (breaks outside aitools even when fixed) |
| shared/skills/optimize-plan/SKILL.md:81, 116; tests/expected-behaviors.md:37; planning/SKILL.md:42; investigate/SKILL.md:16 | bare `incidents.json` | n/a | R (instructs agent to read it) | unresolved bare name |
| shared/skills/intent-audit/SKILL.md:131, 134, 135 | `reference/tool-ops.json`, `reference/incidents.json`, `reference/glossary.json` (list of approved meta.intents) | y | text | cwd |
| shared/skills/aitool-ops/SKILL.md:16, 39, 47, 71, 83 | bare `tool-ops.json`, `glossary.json` | n/a | snapshot (derived at authoring, no runtime read) | -- |
| shared/skills/aitool-eval/SKILL.md:42, 467 | bare `tool-registry.json` | n/a | snapshot | -- |
| dotprofile deploy/setup-user-skills.sh:6856-6860, 7818 (+ .ps1:5004-5008, 5966) | embedded copies of intent-audit / optimize-plan stale paths | y | generated | -- |

### 1.4 Rules (`.claude/rules/`, `.cursor/rules/`), CLAUDE.md

| file:line | path cited | stale | note |
|---|---|---|---|
| .claude/rules/sources-of-truth.md:9, 17, 22, 28, 32, 33 | `registries/{tool-registry,incidents,tool-versions,framework-registry,glossary,tool-ops}.json` | n | table rows; exempt from step 16 by the 3-pipe filter; this is incident #50 |
| .claude/rules/aitool-ops.md:18 | bare `tool-ops.json` | n/a | table row |
| .claude/rules/incident-governance.md:177, 195, 220 | bare `incidents.json` | n/a | process text |
| .cursor/rules/sources-of-truth.mdc:26 | `reference/tool-versions.json` | y | mirror drift from .claude version |
| .cursor/rules/documentation-standards.mdc:35 | `@reference/incidents.json` | y | .claude twin already says "/incident skill" |
| .cursor/rules/tool-lifecycle.mdc:58 | `reference/tool-versions.json` | y | |
| CLAUDE.md | none | -- | clean |

### 1.5 Reference docs, plans, rfcs, roadmap, setup scripts, registry data

| file:line | path cited | stale | type |
|---|---|---|---|
| reference/post-push-checklist.md:160 | `reference/tool-versions.json` | y | reference doc |
| reference/path-targeted-hooks-analysis.md:66, 67 | `reference/tool-versions.json`, `reference/incidents.json` | y | reference doc |
| reference/framework-*.md | none now (the #59 framework refs were replaced; plans/linux-install-hardening.md:6725-6726 records it) | -- | -- |
| scripts/setup-bash.sh:8, setup-bash.ps1:8 (+ dotprofile deploy/setup-bash.sh:9, .ps1:9) | `reference/tool-registry.json` | y | setup script header comment |
| ~30 other scripts/setup-*.sh/.ps1 headers | `reference/tool-registry.md` | n (md exists) | setup script header comment |
| plans/governance-and-compliance-framework.md:86, 335 | `@reference/framework-registry.json`, `reference/incidents.json` | y | plan |
| plans/tooling-resolution-and-artifact-registry.md:28 (current), 109, 128 (discusses the stale entry) | mixed | -- | plan |
| plans/linux-install-hardening.md:6725-6726, 7104-7239 (14 lines) | mixed, diff text of past edits | historical | plan |
| rfcs/0009-tool-operations-governance.md:209; rfcs/rfc-0004-v3-harness-architecture.md:367 | `reference/tool-ops.json`, `reference/glossary.json` | y | rfc (historical) |
| ROADMAP.md:28 | `reference/tool-versions.json` | y | roadmap (protected) |
| registries/framework-registry.json:183 | `reference/tool-ops.json` (artifact of "Tool operations") | y | registry data (S5-Tools I-05) |
| registries/incidents.json:457, 461, 1320, 1485, 1588-1594 | various | data | incident text, not a consumer |
| dotprofile claude/effectiveness.md:43 | `reference/incidents.json` | y | historical note |
| dotprofile profile.json, claude/rules/, claude/CLAUDE.md | none | -- | clean |
| tests/, scripts/*.py (harness-db.py, ait-harvest.py) | none | -- | no registry reads |

## 2. Specific checks

### 2.1 tool-ops-session-audit.sh (incident #70) -- CONFIRMED

- `shared/hooks/tool-ops-session-audit.sh:22-29`: `tool_ops` is set only if `$AITOOLS_REPO_PATH/reference/tool-ops.json` (line 23)
  or `$HOME/repos/aitools/reference/tool-ops.json` (line 25) exists; line 29 `[ -n "$tool_ops" ] || exit 0` exits silently.
- Neither path exists (registry is `registries/tool-ops.json`). `AITOOLS_REPO_PATH` is set nowhere in scripts/, shared/, or
  profile.json (grep -l returns only this hook).
- Deployed copy `~/.claude/hooks/tool-ops-session-audit.sh` is identical to source (`diff` empty) and registered SessionEnd in
  `~/.claude/settings.json:89`.
- Empirical: `~/.claude/hooks/logs/tool-ops-audit.jsonl` last modified **Jun 14 23:25**; commit b2641c0 (registry move, v0.69.0)
  is **Mon Jun 15 00:39 2026 -0700**. The hook has written nothing since the move: silent no-op for ~4 months.
- Even when it ran, it never read tool-ops.json content: lines 37-71 hardcode the block-claude-code-guide.sh tests (the comment
  at 38 claims "Run verification cases from tool-ops.json"). Log dir `~/.claude/hooks/logs` (line 32) is outside
  `~/.aitools/logs` (reference/logging.md). Line 33 `mkdir ... || exit 0` and lines 55/64/95 suppressions are commented.
- INCIDENT (extends #70): the hook's existence check is its only use of the registry; a fix that only repoints the path keeps the
  hardcoded verifications. Suggested: resolve repo via `~/.aitools/config.json` `repoPath`, read `registries/tool-ops.json`
  `verifications`, log a line when not found.

### 2.2 glossary-skill-guard.sh

- `shared/hooks/glossary-skill-guard.sh:26-37`: extracts `file_path` or `path` from tool input with perl; `case` on
  `*glossary.json|*glossary.md` emits `additionalContext` advising `/glossary`. Advisory only, exit 0 (line 38).
- Path-agnostic, so the registries/ move did not break it. Gaps: fires on `.claude/rules/glossary.md` (the always-loaded rule)
  and on the governing skill's own read; does not see Bash `grep`/`perl` reads; Grep without `path` (glob/pattern only) is
  missed; no equivalent guard for the other five registries. Telemetry depends on `.scratch/.current-session` at git root
  (line 11; incident #71).

### 2.3 check-pre-commit step 16 (capability bypass audit)

- Bash `scripts/check-pre-commit.sh:332-347`: scans `.claude/rules/` and `CLAUDE.md` only, regex
  `@?(reference|registries)/[a-z0-9-]*\.json`, keeps lines naming `glossary.json|framework-registry.json|incidents.json|tool-registry.json`,
  drops markdown table rows (`grep -v '^.*:.*|.*|.*|.*|'`). FAIL if any remain.
- PS1 `scripts/check-pre-commit.ps1:321-350`: same scope, pattern `'@?reference/.*\.json'` -- **does not match `registries/`**.
- INCIDENT (medium): step 16 bash/PS1 parity gap -- after the move, the PS1 step cannot detect any registry-path citation in rules.
- INCIDENT (low): both steps omit `tool-ops.json` and `tool-versions.json` from the governed list, and the header comment
  (sh:337, ps1:326) claims scope "any @-referenced files in CLAUDE.md", which is not implemented; governed-data-access.md
  "Enforcement" states the same scope. Skills, reference/, .cursor/rules/ are never scanned (#59 preventionLayer suggests it).
- The table-row exemption is why sources-of-truth.md's six JSON paths pass (#50).
- Current result if run (inferred, not executed): PASS -- all `.claude/rules` hits are sources-of-truth.md table rows; other
  rule mentions are bare names.
- No other check verifies registry paths exist or that skills cite resolvable paths (searched check-*.sh/.ps1, check-hook-parity.py).

### 2.4 check-post-push version freshness and inventory

- Bash fixed: step 10 `check-post-push.sh:233`, step 21 `:448` use `registries/tool-versions.json`.
- **INCIDENT (medium): PS1 not fixed.** `check-post-push.ps1:268` (step 10) checks `reference/tool-versions.json` -> on Windows
  step 10 always FAILs "1 file(s) missing"; `check-post-push.ps1:520-522` (step 21) -> always SKIPs "tool-versions.json not
  found", silently disabling version freshness on Windows since v0.69.0. Violates cross-platform parity and the deploy-paths
  "both paths equivalent" principle. Not visible in the staged S3-Nine diff (that diff touches only step 32).
- Step 21 also hardcodes `TOOL_CMDS` (sh:468-484, ps1:529-544) duplicating registry `versionCheck` (S5-Tools I-11); PS1 lacks
  `bash`.

### 2.5 .github workflows

`.github/workflows/check.yml` (366 lines, only workflow): never reads a registry and never runs check-pre-commit/check-post-push.
A registry move cannot break CI; equally, CI cannot catch a broken registry path.

## 3. governed-data-access.md violations (rules / CLAUDE.md / reference / .cursor rules / plans citing JSON paths)

Rule: `.claude/rules/governed-data-access.md` "What MUST NOT reference JSON file paths".

| file:line | cites |
|---|---|
| .claude/rules/sources-of-truth.md:9, 17, 22, 28, 32, 33 | six `registries/*.json` (incident #50, open, high; unfixed) |
| .cursor/rules/sources-of-truth.mdc:26 | `reference/tool-versions.json` |
| .cursor/rules/documentation-standards.mdc:35 | `@reference/incidents.json` |
| .cursor/rules/tool-lifecycle.mdc:58 | `reference/tool-versions.json` |
| reference/post-push-checklist.md:160 | `reference/tool-versions.json` |
| reference/path-targeted-hooks-analysis.md:66, 67 | `reference/tool-versions.json`, `reference/incidents.json` |
| plans/governance-and-compliance-framework.md:86, 335 | `@reference/framework-registry.json`, `reference/incidents.json` |
| plans/tooling-resolution-and-artifact-registry.md:28 | `registries/tool-registry.json` |
| plans/linux-install-hardening.md:6725-6726, 7104-7239 | many (diff of past edits; historical) |
| ROADMAP.md:28 | `reference/tool-versions.json` (ROADMAP not in the MUST-NOT list but is protected) |

Bare-name mentions (not paths, arguably compliant): `.claude/rules/aitool-ops.md:18`, `.claude/rules/incident-governance.md:177, 195, 220`.
CLAUDE.md: clean.

Note: tool-versions.json and tool-ops.json have no rule-level governing access statement in step 16; tool-versions.json has no
governing skill at all (it is read by check-post-push and edited by hand; sources-of-truth.md:22). INCIDENT (low):
tool-versions.json is a governed registry under `registries/` with no skill gate, contrary to the three-layer pattern
(frameworks.md).

## 4. Sibling mission proposals: new or moved paths

### 4.1 S5-Tools (`missions/S5-Tools/`)

| proposed path | new/edit | source |
|---|---|---|
| `reference/tool-support-decision-tree.md` | new (protected) | S5-Tools-report.md:14, 58 |
| `.claude/skills/tool-adopt/SKILL.md` | new **project** skill | S5-Tools-report.md:15, 61; drafts/.claude/skills/tool-adopt/SKILL.md |
| `.claude/skills/tool-eval/SKILL.md`, `.claude/skills/tool-registry/SKILL.md` | edit at project path | S5-Tools-report.md:62-63 |
| `generated/tool-specs/<slug>.sh/.ps1` | new tracked generated dir | S5-Tools-report.md:16, 45, 86 (Q1), 151, 234 |
| `scripts/gen-tool-specs.py` | new generator (reads tool-registry.json) | S5-Tools-report.md:151; drafts/reference/tool-support-decision-tree.md:271 |
| registry schema 1.1 (`registries/tool-registry.json` `meta.schemaVersion: "1.1"`, `meta.schemaRules`) | edit | S5-Tools-report.md:16, 68; drafts/registries/tool-registry.schema-1.1-draft.json:9-14 |
| `registries/glossary.json` +3 terms; `registries/framework-registry.json` tool-lifecycle entry (artifacts list `.claude/skills/tool-adopt/SKILL.md`, `scripts/gen-tool-specs.py`, `generated/tool-specs/`) | edit | drafts/registries/framework-registry.tool-lifecycle-entry-draft.json:19-20, 43-57 |
| `.claude/rules/sources-of-truth.md` new rows incl. `.claude/skills/tool-*` and `generated/tool-specs/*` note | edit | drafts/.claude/rules/sources-of-truth.md:20-50 |
| `.claude/rules/tool-lifecycle.md` (paths frontmatter `- .claude/skills/**`) | edit | drafts/.claude/rules/tool-lifecycle.md:11 |
| `reference/framework-tool-lifecycle.md` | edit | S5-Tools-report.md:60 |
| companion: `.claude/rules/git-safety.md` names `generated/` | edit (not drafted) | S5-Tools-report.md:75 |

### 4.2 S5-Profile (`missions/S5-Profile/`)

| proposed path | new/edit | source |
|---|---|---|
| `scripts/aitools-profile.js` (resolver: user-repo-path, resolve, derive-config, snapshot, register, machine-id) | new | S5-Profile-report.md:4, 143; S5-Profile-plan.md:52 |
| `scripts/setup-user-config.sh` / `.ps1` (only writer of `~/.aitools/config.json` v3) | new | S5-Profile-report.md:5, 144-145; S5-Profile-plan.md:182-183 |
| lib blocks in `scripts/aitools-lib.sh/.ps1` (`resolve_user_repo_path`, `resolve_machine_profile`) | edit | S5-Profile-report.md:146-147 |
| `~/.aitools/config.json` v3 with `meta`, `githubUser` | schema change | S5-Profile-report.md:97-100 |
| `<dotprofile>/profile.json` rev 2.1 (`machine.id`, `toolExceptions`, `meta.intent`) | edit | S5-Profile-report.md:87-93 |
| `deploy/setup-user-config.*` (MDM, follow-up) | new, proposed | S5-Profile-report.md:225 |
| env `AITOOLS_USER_REPO_PATH`, `AITOOLS_PROFILE_JS`, `AITOOLS_PROFILE_FILE`, `AITOOLS_MACHINE_ALIAS` | new env contract | S5-Profile-report.md:6; S5-Profile-plan.md:657, 742 |
| `reference/user-repo.md` rewrite | edit (protected) | S5-Profile-report.md:150 |

### 4.3 S4-Review (`missions/S4-Review/`, merged drafts)

| proposed path | new/edit | source |
|---|---|---|
| `scripts/aitools-profile.js` gains `exception-get` / `exception-set` (tool exceptions engine) | new subcommands | S4-Review-drafts/reference/tool-support-decision-tree.md:430-435; S4-Review-drafts/reference/user-repo.md:137 |
| same set as 4.1/4.2 (tree reference, tool-adopt, generated/tool-specs, gen-tool-specs.py, schema 1.1) | carried | S4-Review-drafts/reference/tool-support-decision-tree.md:268, 276, 470, 484 |
| glossary terms `aitools config`, `machine alias`, `machine id`, `machine profile`, `tool adoption`, `tool exception`, `update channel` | new | S4-Review-drafts/.claude/rules/glossary.md |
| incidents draft (`S4-Review-incidents-draft.json`) to append to `registries/incidents.json` | data | S4-Review-incidents-draft.json |

### 4.4 Location assumptions in sibling drafts

- **Assume skills stay project-level** (`.claude/skills/`): S5-Tools all skill drafts and the framework/glossary/sources-of-truth
  rows (S5-Tools-report.md:61-63; framework-registry draft :19-20, :47-49; glossary draft :11; sources-of-truth draft :29;
  tool-lifecycle draft :11 `- .claude/skills/**`). S4-Review flags this explicitly as an S2-Split dependency
  (S4-Review-drafts/.claude/rules/sources-of-truth.md:5-6; S4-Review-scratch/part-1-overlaps.md:28 X22) but keeps the paths.
  S5-Tools-report.md:212 also notes the untracked `shared/skills/` copies.
- **Assume registries stay at `registries/`**: every S5-Tools and S4-Review draft (tool-registry SKILL draft :25, :78, :88, :128;
  sources-of-truth drafts list `registries/*.json` rows -- re-exposing #50; S4-Review sources-of-truth.md:6 "registry JSON paths
  stay as today pending incident #50"). `scripts/gen-tool-specs.py` will read the registry; its path resolution is unspecified
  in the drafts (unknown; presumably `$SCRIPT_DIR/..`, build-time, aitools-only -- fine for a generator).
- S5-Profile: no registry reads; its resolver resolves the **dotprofile**, not the aitools repo -- `repoPath` stays a bootstrap
  key written by setup-user-config (S5-Profile-report.md:98). That is the hook a user-level skill could use to find registries
  (`<repoPath>/registries/`), but no draft proposes it.

## 5. Sizes and writers

`wc -l -c registries/*.json` (2026-10-20):

| registry | lines | bytes | last mtime | written by scripts? |
|---|---|---|---|---|
| framework-registry.json | 208 | 9,232 | Jun 20 | no (agent via /frameworks) |
| glossary.json | 406 | 31,931 | Oct 20 19:05 | no (agent via /glossary) |
| incidents.json | 1,705 | 143,359 | Oct 20 19:44 | no (agent via /incident; mtime today = some session wrote it) |
| tool-ops.json | 92 | 4,268 | Oct 20 19:05 | no (agent via /tool-ops) |
| tool-registry.json | 1,130 | 66,547 | Oct 20 19:05 | no (agent via /tool-registry) |
| tool-versions.json | 161 | 7,053 | Jun 15 | no (hand-edited; no skill; read by check-post-push step 21) |
| total | 3,702 | 262,390 | | |

No script writes any registry. S4-Review/S5 drafts add no script writer for registries either (aitools-profile.js writes
profile.json; gen-tool-specs.py reads tool-registry.json and writes generated/).

Note: local `registries/incidents.json` max id is 73; S4-Review-scratch/incidents-main.json (from origin/main) contains a later
incident ("/incident skill points to reference/incidents.json", ~line 1933) -- local main may be behind origin (unknown; not fetched).

## 6. INCIDENT list (not filed)

- INCIDENT (medium, confirms+extends #70): tool-ops-session-audit.sh silently no-ops since b2641c0; never parsed tool-ops.json;
  `AITOOLS_REPO_PATH` set nowhere; logs outside ~/.aitools/logs. Evidence 2.1.
- INCIDENT (medium): check-post-push.ps1:268 and :520 use `reference/tool-versions.json` -- Windows step 10 FAILs, step 21 SKIPs.
- INCIDENT (medium): check-pre-commit.ps1:336 step 16 pattern omits `registries/` (bash :339 includes it) -- parity gap.
- INCIDENT (low): step 16 (both) omits tool-ops.json/tool-versions.json and does not implement its documented "@-referenced
  files" scope; skills/reference/.cursor never scanned.
- INCIDENT (medium, extends #59): #59 lists only /incident and /glossary; also stale: /frameworks (SKILL.md:22, 45, 71),
  /audit (:103, :121), /tool-ops (:106 + tests :15, :23, :77), user-level optimize-plan (:34), intent-audit (:131-135),
  setup-bash.sh/.ps1:8, .cursor rules (3), reference docs (3), framework-registry.json:183, ROADMAP.md:28. #59's
  reference/framework-*.md items appear fixed.
- INCIDENT (low): incident-governance.md:220 "PreToolUse on incidents.json (agent)" validator is not in
  shared/hooks/hooks-manifest.json and not in ~/.claude/settings.json -- documented hook is not deployed (unknown whether it was
  ever implemented).
- INCIDENT (low): tool-versions.json is a governed registry with no governing skill (three-layer pattern incomplete).
- INCIDENT (medium, coordination): untracked byte-identical copies of nine project skills in shared/skills/ (created 19:42
  today). `scripts/setup-user-skills.sh:58-66` deploys every `shared/skills/*/SKILL.md`, so the next `aitools` run would deploy
  them user-level, creating same-name skills at both levels (documentation-standards.md "No project overrides of user skills")
  and shipping cwd-relative (mostly stale) registry paths that cannot resolve outside the aitools repo.
- INCIDENT (low): no consumer has a repo-root resolver for registries; a user-level skill (or the hook) needs
  `repoPath` from ~/.aitools/config.json or an equivalent, which no artifact provides today.
