# S2-Layout-A — Harness deploy map (read-only research)

Author: S2-Layout-A (delegate of S2-Layout). Date: 2026-10-20 (local) / session 360aa8f3-8.
Repos: aitools `/Users/new-jose/repos/aitools` (branch main, HEAD 51a34d8, with staged
changes to scripts/build-deploy.sh, check-hook-parity.py, check-post-push.* — the staged
build-deploy diff replaces the hardcoded hook preflight list with hooks-manifest.json; it
does not touch skills/rules/CLAUDE.md embedding). Dotprofile `/Users/new-jose/repos/aitools-nobul-jose`.
Line numbers are the working-tree files as read on this date.

---

## 0. Working-tree state you must know before recommending anything

- `shared/skills/` contains 9 UNTRACKED dirs created 2026-10-20 19:42:
  audit, frameworks, glossary, governed-data, harvest, incident, tool-eval, tool-ops,
  tool-registry (`git status --short shared` → `?? shared/skills/audit/` … ). The tracked
  copies of these live in `.claude/skills/` (project level; `git ls-files .claude/skills`).
  Author unknown (another session/agent). Because both deploy paths discover `shared/skills/*/`
  dynamically (setup-user-skills.sh:60-67; build-deploy.sh:1105-1116), the NEXT `aitools`
  run or build-deploy would deploy these 9 project skills user-level, creating same-name
  skills at both levels — contradicts `.claude/rules/documentation-standards.md` "Skill
  placement: No project overrides of user skills".
  INCIDENT: (state, not code) untracked project-skill copies in shared/skills/ would be
  auto-deployed to ~/.claude/skills and ~/.cursor/skills on the next run.
- `~/.claude/skills/` is missing `delegate` (tracked in shared/skills/delegate since before
  the dotprofile deploy at bff225a, which embeds it — deploy/setup-user-skills.sh:5873,8269).
  The live dir was last deployed Jun 14-21 (ls timestamps); `delegate` has not been deployed
  on this Mac. `~/.cursor/skills/` likewise lacks `delegate`.
- `~/.claude/rules/` holds only `concurrent-agents.md`; dotprofile `claude/rules/` also has
  `delegation.md` (not yet deployed here).
- Dotprofile `claude/skills/` (31 firecrawl* dirs) is UNTRACKED (`git -C aitools-nobul-jose
  status --short` → `?? claude/skills/`; `git log -- claude/skills` empty).
- Live `~/.claude/CLAUDE.md` (190 lines) contains "Hi agent, this is Jose…" which is in
  neither template (dotprofile claude/CLAUDE.md 189 lines, shared/claude-shared.md 140 lines)
  — hand edit on the live file (drift; adopt flow exists in setup-user-claude.sh:212-226).

---

## 1. Skills

### Dev path: scripts/setup-user-skills.sh (bash) / .ps1

- Sources:
  - `shared/skills/` — `SKILLS_SRC="$REPO_DIR/shared/skills"` (setup-user-skills.sh:43; ps1:36)
  - dotprofile `<userRepoPath>/claude/skills` if the dir exists (sh:48-52; ps1:38-44).
    userRepoPath read via `read_config_key ~/.aitools/config.json userRepoPath` (sh:48).
  - Nothing else.
- Discovery: any subdir with a `SKILL.md` (sh:60-67 shared, 69-79 dotprofile names not
  already in shared). Name precedence: dotprofile wins when both have the skill
  (sh:93-98; ps1:79-84).
- Targets: `~/.claude/skills` and `~/.cursor/skills` (sh:54-56; ps1:48-50). Same skill
  list to both (sh:143-169).
- Copy vs symlink: COPY of content. Only `SKILL.md` is deployed:
  `deploy_managed_file "$(cat "$src")" "$dest_dir/SKILL.md" …` (sh:104-112). Subdirs
  (`tests/`, `rules/`, assets) are NOT deployed. Evidence: `~/.claude/skills/aitool-ops/`
  has only SKILL.md + SKILL.md.bak.* (ls); shared/skills/delegate/tests,
  investigate/tests, optimize-plan/tests, planning/tests never reach targets.
- deploy_managed_file = interactive diff review + backup (`SKILL.md.bak.<ts>` seen in
  ~/.claude/skills/aitool-ops/). "accept & adopt" copies the target back to
  `<userRepoPath>/claude/skills/<name>/SKILL.md` and syncs to the other target (sh:114-134).
- Prune: NONE. Additive only. No `rm` anywhere in setup-user-skills.sh (grep `rm -|unlink|prune`
  → no hits). A skill removed from shared/ or dotprofile stays in both targets forever.
- Reverse discovery: scans `~/.claude/skills/*/` only (not cursor) for dirs with SKILL.md that
  are in neither source, offers `[a]dopt to dotprofile` — copies SKILL.md only (sh:173-217;
  ps1:165-199). Globbing `*/` follows symlinks.

### MDM path: build-deploy.sh → <userRepoPath>/deploy/setup-user-skills.{sh,ps1}

- Embeds ONLY `shared/skills/*/SKILL.md` (build-deploy.sh:1105-1116 bash; 1213-1225 ps1).
  Dotprofile `claude/skills` is NOT embedded (no reference to claude/skills except the
  adopt-back target, 1085-1086, 1189).
- Embedding mechanism (bash): per skill, a heredoc
  `cat > "$_skill_tmp/<name>.md" <<'__SKILL_<NAME_UPPER>__'` + SKILL.md + marker
  (1110-1113), then `deploy_embedded_skill "<name>" "$SKILLS_DEST" …` per skill per target
  (1123-1125, 1137-1139). PS1: `$skill_<name_underscored> = @' … '@` here-strings (1220-1222).
- Why the dotprofile deploy/setup-user-skills.sh "only contains skills/incident and
  skills/tool-eval path strings": those are NOT deployments — they are text inside embedded
  SKILL.md bodies: line 3434 "`.claude/skills/tool-eval/SKILL.md` (project-level skill)"
  (inside aitool-eval) and line 7421 "Incident filing: `.claude/skills/incident/SKILL.md`"
  (inside investigate). The generated file actually embeds 14 skills (heredoc markers at
  lines 2066…8114) and calls deploy_embedded_skill for them at 8264-8277 (claude) and
  8287-8300 (cursor): a11y-debugging, aitool-continue, aitool-eval, aitool-ops,
  chrome-devtools, delegate, handoff, intent-audit, intent-writing, investigate,
  mission-control, optimize-plan, planning, scratch. Generated at bff225a (2026-10-05).
  Grep for literal `skills/<name>` path strings is the wrong probe; grep `^deploy_embedded_skill`.
- No reverse discovery in the MDM path (not emitted), no prune.
- INCIDENT: dev/MDM parity gap — dotprofile `claude/skills/` deployed by the dev path
  (setup-user-skills.sh:49-79) but never embedded by build-deploy.sh (1105-1116).
  `.claude/rules/deploy-paths.md` requires the two paths to "produce equivalent results".

### Deploy target choice and rm -rf (build-deploy.sh)

- Default `DEPLOY_DIR="$REPO_ROOT/deploy"` (28), overridden to `"$_urp/deploy"` when
  config.json userRepoPath exists (154-160, 184-186); exits 0 with warn if unset (187-189).
- `rm -rf "$DEPLOY_DIR"` then `mkdir -p` (252-253) — i.e. it wipes
  `/Users/new-jose/repos/aitools-nobul-jose/deploy/` on every build. Other rm -rf are temp
  dirs only (`$RULES_SRC` 416/437, `$_skill_tmp` 1146 inside generated scripts).

### firecrawl* skills — how they got where they are

1. 2026-06-28 13:41: a third-party skills installer populated `~/.agents/skills/firecrawl*`
   (real dirs, firecrawl has `rules/install.md`, `rules/security.md`) and created relative
   symlinks `~/.claude/skills/firecrawl* -> ../../.agents/skills/firecrawl*` (ls -la).
   It wrote `~/.agents/.skill-lock.json` (version 3; `"source": "firecrawl/cli"`,
   `"sourceUrl": "https://github.com/firecrawl/cli.git"`, installedAt 2026-06-28T20:41Z,
   lock lines 1-23). Exact command unknown (lock format is the open `skills` CLI's; not
   verified). Nothing in aitools references `.agents/` or `skill-lock` (grep scripts/,
   shared/, reference/, registries/ → no hits).
2. 2026-10-15 19:11: dotprofile `claude/skills/firecrawl*/SKILL.md` created (SKILL.md only,
   no `rules/`) — consistent with reverse discovery adopt (setup-user-skills.sh:173-217,
   SKILL.md-only copy at 205) following the symlinks. Inference from timestamps; not logged
   here.
3. 2026-10-15 19:13: `~/.cursor/skills/firecrawl*/SKILL.md` real dirs (SKILL.md only, 17603
   bytes = same size as source) — dev-path deploy of dotprofile skills to cursor.
   For `~/.claude/skills/firecrawl*`, the dev path writes `SKILL.md` THROUGH the symlink into
   `~/.agents/skills/…` (deploy_managed_file on `$dest_base/$skill_name/SKILL.md`), i.e.
   aitools and the third-party installer co-own those files.
   INCIDENT: setup-user-skills writes through foreign symlinks in ~/.claude/skills into
   ~/.agents/skills (third-party-managed), and adoption drops skill subdirs (firecrawl/rules/).
   Also: firecrawl skills were never evaluated via /tool-eval as far as this audit can see
   (unknown — not checked in tool-registry).

### ~/.claude/skills/synced — what writes it

Not aitools. `~/.claude/skills/synced/<org-uuid>_<uuid>/` holds `manifest.json` with
entries `"source": "anthropic-example"` / `"anthropic"` (import-memory, doc-coauthoring,
docs, computer-use, …, pdf, xlsx, pptx, docx) plus `.last-complete-round` (2026-10-20 20:20)
and a `.bucket-…` marker. These are the claude.ai account/org skills synced by Claude Code
itself (they appear in-session as `anthropic-skills:*`). No aitools file mentions `synced`
(grep → no hits). Reverse discovery ignores it because `synced/` has no top-level SKILL.md
(setup-user-skills.sh:181).

---

## 2. CLAUDE.md and rules

### Dev path: scripts/setup-user-claude.sh / .ps1
- Template order: `<userRepoPath>/claude/CLAUDE.md` first, else `shared/claude-shared.md`
  (header sh:5-7; logic sh:64-90; ps1:5-6, 60-70). `{{PLACEHOLDER}}` interpolation from
  profile.json (sh:97+). Target `~/.claude/CLAUDE.md`, sole owner overwrite with review +
  adopt back to dotprofile (sh:212-226; ps1:287).
- Rules: source `<userRepoPath>/claude/rules/*.md` (sh:262-266), target `~/.claude/rules`
  (sh:269). Additive: managed files via deploy_managed_file (sh:321), unmanaged preserved and
  logged (sh:362-368), backup_dir first (sh:309). No shared/ rule source exists (no
  shared/rules dir; `ls shared` = claude-shared.md cursor-rules hooks mcp shell skills).

### MDM path (build-deploy.sh §1)
- Embeds `shared/claude-shared.md` ONLY (CLAUDE_SHARED=build-deploy.sh:44; read at the
  "Read shared content" block ~108; heredoc emit 330-332). It does NOT embed
  `<userRepoPath>/claude/CLAUDE.md`. Verified: dotprofile deploy/setup-user-claude.sh has 2 of
  the 4 headings `Time Compression|What aitools IS|Identity|Coaching` (same as
  claude-shared.md) while claude/CLAUDE.md and live ~/.claude/CLAUDE.md have 4.
  INCIDENT: MDM CLAUDE.md is built from shared/claude-shared.md while the dev path prefers
  the dotprofile template — the two paths deploy different CLAUDE.md content
  (deploy-paths.md "Template sync" / "Dual deployment paths must produce equivalent results").
- Rules: embeds `<userRepoPath>/claude/rules/*.md` at build time (148-170, 410-439), reusing
  the extracted "rules deploy logic" block (432-433).

### Cursor rules
- `shared/cursor-rules/user-rules.md` — MANUAL: "Copy everything below the --- line and paste
  it into Cursor Settings > Rules" (user-rules.md:3-4). Line 7 claims "The setup-user-cursor
  script copies this to your clipboard automatically" — no such code: grep
  `clipboard|pbcopy|Set-Clipboard` in setup-user-cursor.sh/.ps1 → no hits; grep
  `cursor-rules|user-rules.md` across scripts/ → no hits.
  INCIDENT: shared/cursor-rules/user-rules.md:7 documents a clipboard copy that
  setup-user-cursor does not implement.
- `shared/cursor-rules/default.mdc` — template "copy to new projects as
  .cursor/rules/general.mdc" (default.mdc:2). Manual; nothing deploys it.
- Repo `.cursor/rules/*.mdc` — project-level, read by Cursor in this repo only; nothing deploys
  them (grep `.cursor/rules` in scripts/ → only none for deploy).
- setup-user-cursor.sh does three things: ripgrep, Cursor CLI + agent symlink, merge
  `~/.cursor/cli-config.json` (header 6-12; body 57-344). It deploys NO skills and NO rules.
  Cursor skills come from setup-user-skills (target 2). Cursor gets relay via
  `sync-relay-to-cursor-agents.py` → `~/.cursor/AGENTS.md` (scripts/aitools:395-419;
  aitools-install.sh:880-903; py:3,122).

---

## 3. Hooks

### Dev path: scripts/setup-user-hooks.sh / .ps1
- Manifest: `shared/hooks/hooks-manifest.json` is the single source of which files deploy
  and how they register (sh:5-8, 56-62). `hooks[]` = 18 registered entries (event, file,
  matcher); `deploy[]` = `intelligence-stop.py`, `ait-harvest.py` (copied, not registered)
  (manifest:8-31).
- Source resolution per file (sh:75-86; ps1:64-72): dotprofile `<userRepoPath>/claude/hooks/`
  FIRST, then `shared/hooks/`, then `scripts/` (this is how `scripts/ait-harvest.py` reaches
  `~/.claude/hooks/ait-harvest.py`). Dotprofile copies therefore SHADOW shared hooks (the
  "#80" issue). No `claude/hooks` dir exists in the dotprofile today (ls
  aitools-nobul-jose/claude → CLAUDE.md, effectiveness.md, rules, skills), so shadowing is
  latent on this Mac.
  Note: incidents #74-#86 are not in registries/incidents.json yet (highest id 73); they
  are a commander-approved batch staged in `.scratch/session-360aa8f3-8/msg-incidents.txt:1-9`
  ("#80-#82 hooks: dotprofile copies shadow shared/hooks, reverse-discovery…").
- Target: `~/.claude/hooks/<file>` via deploy_managed_file (review + backup) and chmod +x
  (sh:148-191). Stale cleanup: hardcoded list surfacing-duty-stop.sh, estimate-refresh-stop.sh,
  intent-sentinel-stop.sh (sh:199-213) — the only pruning anywhere in the deploy scripts.
  Reverse discovery of user-created `*.sh` → adopt to dotprofile (sh:215-249).
- settings.json registration: node block merges `hooks.<event>` entries with
  `command: bash "<HOME>/.claude/hooks/<file>"` (sh:274-279, mergeHookEntry ~301-322, dedupe,
  post-write validation ~393-415). Only the `hooks` key is managed (sh:10-14).

### MDM path (build-deploy.sh §15/16)
- Embeds each manifest file from shared/hooks/ then scripts/ (1302-1321) — NOT dotprofile
  hooks — writing with plain `cat > "$HOOKS_DIR/<file>" <<'__EMB_…__'` (1314), i.e. no
  deploy_managed_file, no backup, no review. REGS_JSON embedded statically (1334-1337); the
  settings merge block is extracted from scripts/ (1343-1344).
  INCIDENT (parity/safety): MDM hook deploy overwrites ~/.claude/hooks/* without backup or
  review, and ignores dotprofile claude/hooks, unlike the dev path (setup-user-hooks.sh:75-86,
  156). Check whether an existing incident (#1 area: "silently overwritten", incidents.json:26)
  already covers the backup half.

### Hook-side repo resolution (relevant to a user-level layout)
- `ait-harvest.py` helper: `$PROJECT_ROOT/scripts/ait-harvest.py` → `~/.claude/hooks/ait-harvest.py`
  → `~/repos/aitools/scripts/ait-harvest.py` (session-archive.sh:61-69; same pattern
  session-catchup.sh:49-50, harvest-session.sh:51-52).
- `harness-db.py`: `~/.aitools/bin/harness-db.py` → `$PROJECT_ROOT/scripts/` →
  `~/repos/aitools/scripts/` (scratch-init.sh:103; harness-db-sessionstart.sh:64;
  harness-db-sessionend.sh:60).
- `dashboard-serve.sh:58-59` hardcodes `~/repos/aitools/scripts/generate-dashboard.py`.
- `tool-ops-session-audit.sh:23-26, 85-88` uses `$AITOOLS_REPO_PATH` env (nothing sets it —
  grep shows no writer) then `~/repos/aitools/reference/tool-ops.json` (wrong dir; already
  incident #70 per incidents.json:1580-1588).
- No hook reads `repoPath` from config.json. Hardcoded `~/repos/aitools` breaks in Claude
  Code web where repoPath is `/home/user/nobul-jose/repos/aitools`
  (environments/claude-code-web/CLAUDE.md:27).
  INCIDENT: hooks resolve the aitools repo via hardcoded `$HOME/repos/aitools` instead of
  config.json `repoPath` (session-archive.sh:67, scratch-init.sh:103, dashboard-serve.sh:58,
  etc.); wrong whenever reposPath differs (e.g. Claude Code web).

---

## 4. ~/.aitools/bin and other off-repo copies

- `harness-db.py`, `read-session.py`, `read-session-full.py` → `~/.aitools/bin/` by
  aitools-install.sh Step 6 (571-598; ps1:489-513): diff, backup, cp, no review.
  Not done by `aitools` (update) — grep scripts/aitools for harness-db/read-session/.aitools/bin
  → no hits. So `aitools` updates do NOT refresh ~/.aitools/bin; only `aitools install` does.
  (Live harness-db.py is dated Jun 21 17:17, deployed by the harvested scratch script
  harvesting/2026-06-22_session-3fb694ce-1_fix-and-deploy-hbin.sh:15-36.)
- `aitools` CLI → `~/.local/bin/aitools`; `hh.sh` → `~/.local/bin/hh` (aitools-install.sh:547-569).
  `~/.aitools/bin/aitools` and `~/.aitools/bin/hh.sh` (Jun 21 12:28) exist but NO current code
  writes them (grep `.aitools/bin` in scripts/ and shared/ → only the three Python CLIs and
  hook lookups). Writer unknown (older code or a manual copy); they are stale orphans.
- `aitools` itself runs build-deploy (scripts/aitools:1526) and `deploy_configs
  "$repo_path/scripts"` (1622, 1679) — the dev path, 7 setup-user-* scripts (357; Windows 314).
  aitools-install.sh Step 21 runs the same 7 from `$SCRIPT_DIR` (864-875).
- Registries / reference docs: NOTHING deploys them outside the repo. `grep registries/` in
  scripts/ and shared/hooks → only check-post-push.sh:233,448 (repo-local reads). Skills that
  cite `registries/…` or `reference/…` (20 SKILL.md files under shared/skills, incl. the
  untracked copies) resolve those paths against the current project root, so user-level skills
  that depend on registries only work when cwd is the aitools repo.

---

## 5. repoPath / userRepoPath in ~/.aitools/config.json

Live keys: version, reposPath, repoPath, userRepoPath, googleDrives[], machineAlias.

Writers:
- `repoPath`, `reposPath`, `version`, `googleDrives`: aitools-install.sh Step 5
  (421-468 merge; 458 `Object.assign(… repoPath)`; fallback printf 527); ps1:325, 381, 410.
  Preserves userRepoPath/machineAlias (423, 449).
- `userRepoPath` (+ machineAlias): `aitools user init` — scripts/aitools:1204-1220;
  aitools.ps1:1138-1154.
- Migration aiToolingRepoPath→repoPath: scripts/aitools:642-666; aitools.ps1:584-586.
- Test fixture writes: check-pre-push.sh:132; check-pre-push.ps1:158.

Runtime consumers of `repoPath`:
- scripts/aitools:637-640 (default `$HOME/repos/aitools`), 662; aitools.ps1:574, 594
- hh.sh:63 (`j.repoPath || j.aiToolingRepoPath`); hh.ps1:38
- aitools-dashboard.sh:124; aitools-dashboard.ps1:82
- No hook, no skill, no setup-user-* script reads repoPath (they use `$SCRIPT_DIR/..`).

Runtime consumers of `userRepoPath`:
- setup-user-skills.sh:48 / ps1:38-44 (dotprofile skills + adopt target)
- setup-user-claude.sh:68-80 (node) / ps1:70 (template + rules + adopt)
- setup-user-hooks.sh:67 / ps1:54-60 (dotprofile hook overrides + adopt)
- setup-user-settings.sh:62-64 (profile.json source of truth)
- build-deploy.sh:154-160 (rules + build target), 204-214 (profile interpolation)
- generated deploy scripts: deploy_embedded_skill (build-deploy.sh:1075), Deploy-EmbeddedSkill (1181-1182)
- scripts/aitools:1269, 1512 (pull dotprofile), 1610, 1699 (archive-inactive warning);
  aitools.ps1:1191, 1414-1416, 1501, 1602-1604
- scripts/ait-harvest.py:198-216 (session archive to dotprofile) — called by hooks
- shared/skills/audit/SKILL.md:55 mentions it in prose only.

Reusable "resolve the aitools repo" patterns:
- bash: `read_config_key "$HOME/.aitools/config.json" "repoPath"` with fallback
  `$HOME/repos/aitools` — scripts/aitools:637-640 (read_config_key from aitools-lib.sh).
- node one-liner (no lib): hh.sh:63 `const r = j.repoPath || j.aiToolingRepoPath || ''`.
- python: ait-harvest.py:198-216 reads config.json (`userRepoPath`) with logged skip paths —
  same shape works for repoPath.
- A user-level skill has no lib; the simplest portable instruction is "read
  `~/.aitools/config.json` key `repoPath` (fallback `~/repos/aitools`)". No skill does this
  today (grep repoPath in shared/skills and .claude/skills → none; aitool-continue/SKILL.md:145
  hardcodes `~/repos/aitools/`).

---

## 6. Claude Code web

- PR #48 / 51a34d8 changed: environment API in aitools-lib.sh/.ps1, setup-google-chrome.*,
  setup-user-mcp.sh + setup-cursor-ide-mcp.sh chrome args, aitools-install.sh/.ps1 (+15/+13:
  Step 20b Chrome), build-deploy.sh (+19), rules/reference docs, incidents (`git show --stat`).
  It did NOT change setup-user-skills, setup-user-claude, setup-user-hooks.
- Resolution: `AITOOLS_ENVIRONMENT` override, else `CLAUDE_CODE_REMOTE=true` →
  claude-code-web; Linux only (reference/cross-platform-detail.md:24-38). The env Setup script
  is not documented to receive CLAUDE_CODE_REMOTE, so it sets AITOOLS_ENVIRONMENT explicitly
  (44-46).
- aitools-install.sh has NO claude-code-web branch (grep `claude-code-web|is_claude_code_web|
  AITOOLS_ENVIRONMENT|CLAUDE_CODE_REMOTE` → none; Step 20b comment 847-851 says the script
  decides by environment). Only setup-user-mcp.sh:63-66 branches.
- How the harness gets there (dotprofile environments/claude-code-web/CLAUDE.md):
  container reclaim wipes the filesystem incl. /root (16-20); harness re-clones repos to
  /home/user/aitools*; working clones at /home/user/nobul-jose/repos/{aitools,aitools-nobul-jose}
  are repoPath/userRepoPath (27-28, 37); after a reclaim the user re-bootstraps manually:
  "Re-bootstrap aitools non-interactively" (47) via `AITOOLS_FORCE=1 aitools install
  --skip-gh-auth --repos-path /home/user/nobul-jose/repos --skip-drive-detection` under a pty
  (69-70). `/home/user/CLAUDE.md` is a manual cp of the env file (46, optional Setup-script
  line 52).
- Would `~/.claude/skills` exist there? Only after `aitools install` has run in the current
  container; it is lost on every reclaim and nothing re-runs it automatically (the documented
  Setup-script block only copies CLAUDE.md and Chrome — 49-53, 83-87). Evidence it has been run
  in at least one web container: incident #61 discoveryContext audits `/root/.claude/hooks/`
  and `/root/.claude/settings.json` (incidents.json:1370-1373, session 3030c86a-9). Whether
  project `.claude/skills` load in web depends on which repo is the session cwd
  (`/home/user`, env CLAUDE.md:9) — unknown, not verified.
  Implication for layout: anything that must be available in web sessions without a manual
  install must live in the repo (project level) or in the environment Setup script.

---

## 7. Project-level artifacts — confirmed NOT deployed

| Artifact | Tracked? | Deployed by anything? |
|---|---|---|
| `.claude/skills/*` (audit, frameworks, glossary, governed-data, harvest, incident, tool-eval, tool-ops, tool-registry; tests/ in audit, incident, tool-ops) | yes (git ls-files) | No. grep `.claude/skills` in scripts/ → only `~/.claude/skills` targets. Loaded by Claude Code only when cwd is this repo. |
| `.claude/rules/*.md` | yes | No (scripts mention only `~/.claude/rules` and dotprofile `claude/rules`). |
| `.claude/commands/pre-update.md` | yes | No. |
| `.claude/settings.local.json` | gitignored (.gitignore:35) | Not deployed; but `aitools mcp enable <srv>` WRITES it in the cwd project (scripts/aitools:883-904). |
| `.mcp.json` | gitignored (.gitignore:41) | Not deployed/written by scripts (no grep hit). Origin unknown (Jun 28 13:43). |
| `.cursor/mcp.json` | gitignored (.gitignore:42) | Not deployed; `aitools mcp enable` writes cwd `.cursor/mcp.json` as fallback when `agent mcp enable` fails (scripts/aitools:909-930). |
| `.cursor/rules/*.mdc` | yes | No. |
| `shared/cursor-rules/*` | yes | No (manual copy/paste). |

---

## INCIDENT summary (not filed)

1. Untracked project-skill copies in shared/skills/ (9 dirs) will auto-deploy user-level on
   next run — same-name at both levels (documentation-standards.md Skill placement).
2. Dev/MDM parity: dotprofile claude/skills deployed by dev path only (setup-user-skills.sh:49-79
   vs build-deploy.sh:1105-1116).
3. Dev/MDM parity: MDM CLAUDE.md embeds shared/claude-shared.md, dev path prefers dotprofile
   claude/CLAUDE.md (build-deploy.sh:44,330-332 vs setup-user-claude.sh:64-90).
4. MDM hooks: `cat >` overwrite without backup/review, dotprofile hooks ignored
   (build-deploy.sh:1302-1321 vs setup-user-hooks.sh:75-86,156).
5. setup-user-skills writes through third-party symlinks (~/.claude/skills/firecrawl* →
   ~/.agents/skills) and deploys/adopts SKILL.md only, dropping subdirs (sh:104-112, 205).
6. No skill pruning: removed skills persist in ~/.claude/skills and ~/.cursor/skills.
7. shared/cursor-rules/user-rules.md:7 claims a clipboard copy that does not exist.
8. Hooks hardcode `$HOME/repos/aitools` instead of config.json repoPath
   (session-archive.sh:67 and siblings; dashboard-serve.sh:58).
9. ~/.aitools/bin/aitools and ~/.aitools/bin/hh.sh are orphans with no current writer;
   ~/.aitools/bin Python CLIs are refreshed only by `aitools install`, not `aitools`.

WRITE_BLOCKED: none. One tool call was blocked by a hook (not a write): `head -c` on
~/.agents/.skill-lock.json → "USO: Dedicated tools -- Use the Read tool…"; re-done with Read.
