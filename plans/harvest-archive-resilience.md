# Resilient session/scratch harvesting + Windows harvest RCA (v3)

> Regenerated from scratch after loading the full `reference/` corpus, then
> reconciled line-by-line against v1. Key corrections from v1 are listed under
> "What changed from v1" at the end. Four review passes (logging, `.sh`/`.ps1`
> parity, harvest/archive/scratch logic, uncaught function-exit error logging)
> are folded through the design and called out explicitly in §6.

## 0. Before you start (load context first)

**Load these source files into context in full before editing anything** — the
changes span the shared library, both CLI entry points, and the build pipeline,
and the parity/logging passes require seeing all of them together:

- `scripts/aitools-lib.sh` and `scripts/aitools-lib.ps1` (logging, `logging_init`/
  `Initialize-Logging`, `deploy_managed_file`, summary, backup — the migration in
  §14 centers here)
- `scripts/aitools` and `scripts/aitools.ps1` (CLI entry points; `sessions archive`,
  `deploy_configs`/`Deploy-Configs` — §4/§9)
- `scripts/build-deploy.sh` (hook/lib embedding; required-file check, embed blocks,
  `extract_between` — §2/§5/§9)
- The hooks being changed: `shared/hooks/session-archive.sh`,
  `shared/hooks/harvest-session.sh`, `shared/hooks/scratch-init.sh`,
  `shared/hooks/harness-db-sessionstart.sh`, `shared/hooks/harness-db-sessionend.sh`
- `scripts/harness-db.py` (the stdlib Python helper pattern `ait-harvest.py` mirrors)
- `scripts/setup-user-hooks.sh` and `.ps1` (registration — the RCA fix, §2/§5)

### This session's transcript (the full deliberation that produced this plan)

The reasoning, RCA, four passes, and every commander decision behind this plan are
in this session's JSONL transcript. Read it for context the plan summarizes:

- **Path:** `~/.claude/projects/C--Users-jdpal-repos-aitools/8f1728f5-8043-4ab9-ae38-0f080e04d844.jsonl`
  (session id `8f1728f5`; ~2.5 MB and growing until this session ends).

**Reader tools** (in this repo; run from the aitools repo root). Interpreter:
`python3` on macOS/Linux, `python` or `py -3` on Windows.

| Script | Use |
|--------|-----|
| `scripts/read-session.py` | Text only (COMMANDER + AGENT lines, tool noise dropped) — default for skimming/searching |
| `scripts/read-session-full.py` | Full fidelity (tools, hooks, thinking) — forensic detail |

```bash
# Skim the last N exchanges
python3 scripts/read-session.py "$HOME/.claude/projects/C--Users-jdpal-repos-aitools/8f1728f5-8043-4ab9-ae38-0f080e04d844.jsonl" --last 40

# Find a topic (e.g. the RCA, logging decision, a pass)
python3 scripts/read-session.py "<path>" --search "MergeHookEntry"
python3 scripts/read-session.py "<path>" --search "logging"

# Full dump to a file (avoid flooding the terminal)
python3 scripts/read-session-full.py "<path>" --output .scratch/session-8f1728f5-full.md
```

```powershell
# Windows (pwsh) — forward slashes work in the Python path argument
py -3 scripts\read-session.py "$env:USERPROFILE\.claude\projects\C--Users-jdpal-repos-aitools\8f1728f5-8043-4ab9-ae38-0f080e04d844.jsonl" --last 40
```

Run `python3 scripts/read-session.py --help` for all flags. Do not commit JSONL
transcripts into this repo (they archive to the dotprofile via the very hook this
plan fixes).

## 1. Context

**Proven loss (this session).** Two Windows sessions on 2026-06-14 (`8376040a`,
`8f8513bf` @1.28 MB) never reached the dotprofile — not committed locally, not
pushed. Two independent failures combined:

1. **SessionEnd-only fragility.** Archiving and harvesting fire *only* at
   `SessionEnd`. `SessionEnd` does not run on abrupt exit / sleep / offline, so
   any non-graceful end silently loses that session's carry-forward — violating
   the cross-machine carry-forward principle (`.claude/rules/aitools-workspace.md`).
2. **Windows harvest has never worked** (RCA §2). `harvest-session.sh` and
   `scratch-init.sh` are *deployed as files* but never *registered* in
   `settings.json` on Windows.

**Goal.** (a) Add a `SessionStart` catch-up that recovers what `SessionEnd`
missed; (b) factor the triplicated archive/harvest logic into one stdlib-only
Python helper, `ait-harvest.py`, with one function per carry-forward source;
(c) fix the Windows registration bug *and* make the bug-class structurally
impossible; (d) file the GitHub-issue backlog this session surfaced.

**Commander decisions (this session):** Python helper, **stdlib only**, named
**`ait-harvest.py`**, single module with **per-source functions**. Catch-up
**synchronous** with a **~10 s graceful deadline**, reconciling archive + harvest
onto one mechanism. Scope = **archive + push + harvest**. Cursor sessions →
**ROADMAP + GitHub issue** (not built now). Windows fix = **patch now +
structural fix**.

## 2. RCA — Windows harvest no-op (recurring)

**Immediate cause.** `scripts/setup-user-hooks.ps1` deploys `scratch-init.sh`
(SessionStart) and `harvest-session.sh` (SessionEnd) as files (Resolve-HookSource
L78–79, dest vars L106–107, dry-run L130–131) but has **no `MergeHookEntry` call**
for either (merge list L407–468) and **no validation count** (L553–578). The bash
node-block registers and validates both.

**Why Windows-only.** `deploy_configs` runs `.ps1` on Windows, `.sh` on macOS.
macOS registers them; Windows writes the files and never wires them. Corroborated
by `tool-ops-claude-code.md` #23, which shows `harvest-session.sh` firing as a
SessionEnd hook (on macOS).

**Contributing factors (Swiss cheese / three-layer):**
- *Prevention* — bash and PS1 hand-maintain **parallel hook-registration lists**
  with no enforced parity (rule fade). harvest registration entered bash at
  `60194f2` (2026-03-15); never ported to PS1. RELEASE_NOTES L510 ("PS1 parity —
  now *deploys* scratch-init/harvest") fixed file-copy parity but missed
  registration.
- *Detection* — the PS1 post-write validation omits the scratch-init/harvest
  counts, so the missing registration raises no error.
- *Audit* — `check-post-push` steps 29/30/31 audit **menu / return-value /
  state-machine** parity only; **nothing audits hook-registration parity**.
  No GitHub issue was ever filed.

**Root cause.** No single source of truth for hook registration. This is the
**same disease I6 cured on a different axis**: I6 (recurring, 3+ occurrences)
fixed `scripts/`↔`build-deploy.sh` template duplication via `extract_between`
sentinel extraction (v0.25.1, ~507 lines removed). The **bash↔PS1
hook-registration axis never received the equivalent single-source treatment** —
so this drift persisted. It is also the unfinished tail of **I5** (session-archive
silent no-op): I5's remediation (post-push #5/#17, surface-silent-failures rule)
only covered session-archive's *prerequisite*, not harvest/scratch *registration*.

**Corrective action (structural + environmental; recurrence 3+ ⇒ structural):**
- *Immediate remediation:* add the two missing PS1 `MergeHookEntry` calls + two
  validation counts; re-deploy on Windows; confirm live `settings.json`.
- *Structural:* derive registration from one **hooks manifest** consumed by bash,
  PS1, and `build-deploy.sh`; add a **check-post-push hook-registration parity
  audit** (new step 32).

**Recurrence risk after fix:** low (single source + parity audit close all three
layers).

## 3. Carry-forward source inventory ("what else am I missing")

| Source | Location | Today | Format | Gap |
|--------|----------|-------|--------|-----|
| Claude Code sessions | `~/.claude/projects/<sani-cwd>/<sid>.jsonl` | archived @SessionEnd | JSONL | SessionEnd-only; **path sanitization lossy** — derive project from JSONL `cwd`, not dir name (`tool-ops-claude-code.md` #4) |
| CC **subagent** transcripts | `…/<sid>/subagents/*.jsonl` | **never archived** | JSONL | archive copies only top-level (#16) |
| Scratch artifacts | `<repo>/.scratch/session-*/` | harvested @SessionEnd | files | broken on Windows; SessionEnd-only |
| **Cursor CLI sessions** | `~/.cursor/chats/<wshash>/<uuid>/store.db` (+`-wal`/`-shm`) | **never archived** | SQLite (live WAL) | unsafe to `cp`; workspace-hash→project mapping unknown → ROADMAP |
| Handoffs | `.aitools/channel/handoffs/` | routed by harvest | md | — |
| Harness DB → estimate | `.aitools/…` → `running-estimate.json` | exported @SessionEnd by `harness-db-sessionend.sh` | json | SessionEnd-only (separate hook) |

## 4. Architecture — `scripts/ait-harvest.py` (stdlib only)

Executable helper, sibling of `harness-db.py`; **standard library only**
(`json, subprocess, pathlib, shutil, os, sys, datetime, time, argparse`).
Per-source functions + an orchestrator, exposed as argparse subcommands:

- `archive_claude_session(transcript, cwd, session_id)` → copy the transcript
  **and its `subagents/*.jsonl`** to the dotprofile under the **flat existing
  naming** `sessions/<project>/<date>_<prefix>.jsonl` (subagents as siblings
  `…_<prefix>_subagent-<n>.jsonl` — *not* a directory; preserves `aitools
  sessions list/move` and existing archives). Project derived from the JSONL
  `cwd` field (lossy-path rule). Then commit + push (deadline-guarded). Idempotent
  via dest-exists.
- `harvest_scratch(cwd, session_id)` → port `harvest-session.sh` classification +
  handoff routing + `harvest-manifest.json` update + prune into stdlib `json`
  (drops the `node` dependency). Preserves the 30-file-loss guards (never delete
  scratch dirs; mark `pruned`, don't unlink). Leaves DB session-end marking to
  `harness-db-sessionend.sh` (removes today's overlap).
- `catchup(cwd, deadline=10)` → orchestrator:
  - **Archive (global):** scan `~/.claude/projects/*/*.jsonl`; archive any
    transcript with no dotprofile dest. **Skip** the current session and any
    transcript modified < ~2 min ago (still being written) and the **transient
    `claude update` session** (no real session dir / empty — see `tool-ops-claude-code.md`
    #23).
  - **Harvest (current repo):** harvest orphaned `.scratch/session-*` dirs whose
    SessionEnd never ran.
  - **Push:** if the dotprofile is ahead of `origin`, push.
- `archive_cursor_session(...)` → **ROADMAP stub only** (SQLite `.backup`/WAL
  checkpoint + workspace-hash→project mapping). Issue #5.

**Synchronous + graceful deadline (cross-platform).** `timeout(1)` is not
portable (absent/renamed on macOS + Git Bash), so the budget lives in Python: a
`time.monotonic()` deadline (default 10 s, `--deadline`), each git call via
`subprocess.run(..., timeout=remaining)`. Local copy/classify are sub-second;
only git network is variable, so offline fails fast and the sweep still completes
locally. Normal run < 2 s.

**Hook shims + new catch-up hook (bash-only, standalone — no `aitools-lib`):**
- `session-archive.sh` (SessionEnd) → `python … archive`.
- `harvest-session.sh` (SessionEnd) → `python … harvest`.
- NEW `shared/hooks/session-catchup.sh` (SessionStart) → `python … catchup
  --cwd "$CWD" --deadline 10` (models `harness-db-sessionstart.sh` Python
  resolution + silent-exit-0).
- `aitools sessions archive` (bash **and** ps1) delegate to the same helper —
  collapses the triplication.

## 5. Structural fix — single-source hook registration

One manifest (e.g. `shared/hooks/hooks-manifest.json`: `{file, event, matcher}`
per hook) consumed by:
- `setup-user-hooks.sh` (node block) and `.ps1` (`MergeHookEntry` loop) — generate
  registrations **and** validation counts from the manifest.
- `build-deploy.sh` — required-file check + embed list from the manifest.
- `check-post-push.{sh,ps1}` — **new step 32: hook-registration parity audit** —
  every manifest hook is registered in both scripts and present in a freshly
  merged `settings.json`. (This is the I6 `extract_between` pattern applied to the
  bash↔PS1 axis, and the path-targeted-hooks #3/#4/#5 parity idea finally enforced
  rather than left as an observe-only prompt.)

## 6. The four review passes (explicit)

**(1) Logging standardization.** Now a dedicated workstream — see **§14**.
Summary: unify ALL aitools logging to a single cross-platform location
**`~/.aitools/logs/`** (overriding the current 3-way split), add rotation (none
exists today), document the standard in a new **`reference/logging.md`**, and
keep the `[<utc-Z>] [<script>] [<level>] <msg>` format. `ait-harvest.py` emits
to `~/.aitools/logs/ait-harvest.log`; stdout `print()` for hook context, stderr
for agent-visible warnings. The existing **Windows bash↔PS1 split** (bash
`~/.local/state` vs PS1 `%LOCALAPPDATA%`, a latent bug) is dissolved by the move.

**(2) `.sh`/`.ps1` parity + cross-platform.** The RCA *is* a parity failure; §5 is
the durable fix. Hooks are bash-only on all platforms (correct — no `.ps1` hook
variants). Helper is Python (one source, no `.sh`/`.ps1` fork) — eliminates a
whole parity axis. CLI `sessions archive` must change in **both** `aitools` and
`aitools.ps1` (pre-commit #13, post-push #11/#29). No perl/CRLF/encoding concerns
(Python stdlib), so PERLIO / Strawberry-Perl gotchas don't apply.

**(3) Harvest / session-archive / scratch logic review.** Preserve: flat session
naming (user-repo.md); 30-file-loss guards (no scratch-dir deletion; `pruned` not
unlink); idempotent dest-exists; derive project from JSONL `cwd` (lossy path);
handoff routing to `.aitools/channel/handoffs/`. Add: subagent transcripts;
SessionStart catch-up (framework already envisions SessionStart audit/prune —
framework-artifact-harvesting); transient-update-session skip. De-dupe the
harness-db session-end call that both harvest and `harness-db-sessionend` make.

**(4) Uncaught function-exit / return error logging.** The current
`session-archive.sh` and `harvest-session.sh` have ~6 unlogged `exit 0` branches
each (missing fields, no config, no `userRepoPath`, transcript missing, dest
exists, no Python). `ait-harvest.py` logs **why** at `detail` level on every early
return, so deploy.log distinguishes "skipped (already archived)" from "skipped (no
userRepoPath)" from "didn't fire." Per plan-execution-detail audit checklist:
every error path increments an error count and pairs a log line; `cp`/git failures
are caught and logged, never silently swallowed; no `2>/dev/null`/`|| true`/empty
`except` without a checked result.

**(5) Perl usage (efficiency).** Reviewed per USO "Perl for string manipulation"
and the `grep -P` portability rule:
- **Python helper: perl-free** — `ait-harvest.py` uses stdlib `re`/`json`/`pathlib`;
  never shell out to perl from Python.
- **Hook shims: no bash JSON parsing at all** — do NOT replicate the current
  `json_field()` (`grep -o | sed | sed`, ~9 subprocesses for 3 fields) and do NOT
  rewrite it in perl. The shim passes **raw stdin straight to `ait-harvest.py`**,
  which parses with the `json` module (one process, robust). Most efficient and
  most correct.
- **check-post-push step 32: use perl** for source-pattern extraction, mirroring
  step 29 — `perl -ne 'print "$1\n" if /MergeHookEntry "(\w+)" "([\w.-]+)"/' …
  | sort -u` on `.ps1`, the equivalent on the bash node-block, compared to the
  manifest. (`perl -ne`, never `grep -P` — BSD grep lacks it.)
- **JSON manifest reads: `node` is correct, not perl** — perl is not a JSON parser
  without a CPAN module (against the repo's no-CPAN convention). node is **already a
  hard dependency of the hook-registration path** (the `settings.json` merge in
  `setup-user-hooks` is `node -e`), so a JSON `hooks-manifest.json` read via node
  adds no new dependency. A line-based manifest to "avoid node" would not remove
  node (the merge still needs it). Keep JSON + node here.
- **Bash log rotation: no perl** — size via `stat` (uname dispatch) + `mv` chain.

## 7. GitHub issues to file (drafts — review before filing; outward action)

1. **bug/high** — Windows `setup-user-hooks.ps1` never registers `scratch-init.sh`
   + `harvest-session.sh` (no `MergeHookEntry`/validation); harvest+scratch no-op
   on Windows since 2026-03-15. Repro: fresh Windows deploy → both absent.
2. **reliability/high** — No parity enforcement between bash/PS1 hook-registration
   lists; `check-post-push` audits menus only. → manifest + parity audit (§5).
3. **reliability/high** — Archive + harvest fire only at SessionEnd; abrupt/offline
   end loses the session. → SessionStart catch-up (umbrella for this plan).
4. **bug/med** — `session-archive` drops subagent transcripts (`…/subagents/*.jsonl`).
5. **feature/med** — Cursor CLI sessions (`~/.cursor/chats/*/store.db`) never
   archived; SQLite/WAL-safe copy + workspace→project mapping. → ROADMAP.
6. **observability/low** — Archive/harvest hooks exit 0 silently on all failure
   paths; no deploy.log trail. Resolved by `ait-harvest.py` logging.

(Per `incident-governance.md`, the parity-enforcement gap may also merit an
`incidents.json` entry cross-linked to #2; commander asked for GH issues.)

## 8. ROADMAP additions
- **Cursor CLI session archiving** (`archive_cursor_session`) — SQLite-safe,
  workspace-hash mapping. Linked to issue #5.

## 9. Files to change
- **New:** `scripts/ait-harvest.py`; `shared/hooks/session-catchup.sh`;
  `shared/hooks/hooks-manifest.json`.
- **Refactor to shims:** `shared/hooks/session-archive.sh`,
  `shared/hooks/harvest-session.sh`.
- **Registration/deploy (lockstep — deploy-paths.md):** `setup-user-hooks.sh` +
  `.ps1` (manifest-driven registration; interim patch = the 2 missing PS1 entries;
  deploy `ait-harvest.py` to `~/.claude/hooks/`); `build-deploy.sh` (required-file
  check, `cat` reads, bash + ps1 embed blocks for new hook + helper).
- **CLI:** `scripts/aitools` + `scripts/aitools.ps1` (`sessions archive` → helper).
- **Checks/docs:** `check-post-push.sh` + `.ps1` (step 32 parity audit);
  `.claude/rules/artifact-harvesting.md`, `reference/framework-artifact-harvesting.md`,
  `reference/user-repo.md` (subagents + catch-up + helper); `ROADMAP.md` (Cursor);
  `reference/tool-ops-claude-code.md` (register the new SessionStart catch-up
  hook + its stdin contract as a version-dep alongside #2/#8).

## 10. Phasing (plan-execution.md: verbatim edits, error-handling audit, fresh
sub-agent per batch, verification between)
0. File GH issues + ROADMAP entry (on approval; §7 drafts).
1. **Remediate Windows now** — add 2 PS1 `MergeHookEntry` + 2 validations,
   re-deploy, verify live `settings.json`.
2. **Helper + archive path** — `ait-harvest.py` (`archive` incl. subagents +
   `catchup` transcript half), shim `session-archive.sh`, wire `session-catchup.sh`,
   point CLI at helper. Solves the proven loss.
3. **Harvest reconcile** — port `harvest-session.sh` into the helper, shim it, add
   harvest to `catchup`.
4. **Structural** — hooks manifest single-source; `check-post-push` step 32.
5. **Deploy surface + docs**, then `build-deploy.sh`, parity, full verification.

## 11. Verification
- **Unit (`.scratch/`):** drive `ait-harvest.py archive|harvest|catchup` against a
  synthetic transcript (+subagents) + scratch dir; assert dotprofile dest +
  subagents copied, manifest entry, idempotent re-run, project derived from `cwd`,
  unreachable-remote returns within deadline, transient-update-session skipped.
- **Hook smoke (hook-rollout.md):** pipe SessionStart/SessionEnd JSON into the
  shims + catch-up; exit 0 + "recovered N" note. Smoke-test required (not just
  `bash -n`) — I12 lesson (set -u + unset var passes `bash -n`, crashes at runtime).
- **End-to-end:** orphan a transcript + scratch dir, start a new session, confirm
  both recovered and the current session skipped.
- **RCA fix:** fresh Windows deploy → `settings.json` has scratch-init + harvest;
  step 32 passes; break parity deliberately → step 32 fails.
- **Deploy/commit gates:** `build-deploy.sh` (count increments), `setup-user-hooks`
  dry-run, `check-post-push`; pre-commit #3/#6/#10/#13, pre-push secret scan.

## 12. What changed from v1 (line-by-line reconciliation)
- **Name** `session-archive.py` → **`ait-harvest.py`** (commander).
- **Structure** one blob → **per-source functions** (`archive_claude_session`,
  `harvest_scratch`, `archive_cursor_session`, `catchup`).
- **Session naming bug fixed:** v1 proposed a `<date>_<prefix>/` **directory**
  (would break `sessions list/move` + existing flat archives). v3 keeps **flat
  `.jsonl`** with subagent **siblings** (user-repo.md).
- **Timeout:** v1 hedged sync-or-background → v3 **synchronous + in-Python 10 s
  deadline** (commander; `timeout(1)` not portable).
- **RCA strengthened** with the exact PS1 `MergeHookEntry`/validation absence and
  the **I5/I6/I8** precedents (I6 = same disease, other axis; I5 = unfinished tail).
- **New logic/edge cases** from the corpus: lossy path sanitization (derive from
  `cwd`), **transient `claude update` session** skip, subagents, live-WAL SQLite,
  Windows deploy.log split, the de-dup of the harness-db session-end call.
- **Four explicit review passes** added (§6).
- **Structural fix located precisely:** `check-post-push` **step 32**, manifest as
  the bash↔PS1 single source — the missing analog to I6's `extract_between`.

## 13. Protected-file / process notes
`build-deploy.sh`, `setup-user-hooks.*`, `aitools*`, `check-post-push.*`,
`.claude/rules/*`, `reference/*`, `ROADMAP.md`, and the GitHub issue bodies are
protected / outward-facing — each concrete edit and each issue body is drafted and
presented for review before write/file (`sources-of-truth.md`). Plan mode limited
this exercise to one plan file; v1 is preserved in the session transcript and can
be materialized as a separate artifact on request.

## 14. Logging standardization workstream (commander directive)

Distinct but intertwined with the harvest fix (the new helper's logging depends on
it). **Document the decision first** in a new `reference/logging.md`, then migrate.

### 14.1 Decisions (to ratify in `reference/logging.md`)
- **Location:** one cross-platform path **`~/.aitools/logs/`** on macOS, Windows,
  Linux (and future Android). **Overrides** the deliberate 3-way native-dir split
  (RELEASE_NOTES L865) — justified: aitools logs are internal + Datadog-shipped,
  not consumed by OS log tooling; uniformity + discoverability win, and it kills
  the Windows bash↔PS1 split. (`~/.aitools/` is already the user-scoped namespace:
  config, deploy-state, proposed telemetry — `aitools-workspace.md`.)
- **Path separators:** native per language — bash forward-slash (`$HOME/.aitools/
  logs`, valid in Git Bash), PS1 `Join-Path` (backslash on Windows), Python
  `pathlib` (native per-OS). **Exception:** forward-slash when a path is written
  into a bash command string (e.g. `settings.json` hook commands).
- **Granularity:** **per-component files** — `ait-harvest.log`, `session-archive.log`,
  `session-catchup.log`, `harvest-session.log`, `harness-db.log`, `deploy.log`
  (setup), `checks.log`/`checks.jsonl` (checks). Directly fixes "did hook X fire?".
- **Rotation (none exists today):** size-based, **default 5 MB × 5 backups**
  (`<name>.log` → `<name>.log.1` … `.5`). Python: `logging.handlers.RotatingFileHandler`
  (stdlib). Bash: size-check rotate in `logging_init` (`stat` size → `mv` chain).
  PS1: size-check in `Initialize-Logging`. Same maxBytes/backupCount everywhere.
- **Format unchanged:** `[<utc-Z>] [<script>] [<level>] <msg>`, levels
  `info|ok|warn|error|detail`; file plain-text, console ANSI for warn/error;
  fail-safe (logging never crashes the tool).
- **Setup-vs-check separation preserved** (script-standards-detail "Logging
  architecture") — same dir, distinct files + semantics (OK/WARN/ERROR vs
  PASS/FAIL/WARN/SKIP).

### 14.2 `reference/logging.md` consolidates (today scattered)
Single source for the logging standard; the following keep only a directive +
pointer to it (layered-reference, no duplication):
- `.claude/rules/script-standards.md` (log format, helpers, levels, agentic/check/
  build logging)
- `reference/script-standards-detail.md` (**Platform log directories**, **Logging
  architecture: setup vs check**, **OS guard logging convention**, console colors)
- `.claude/rules/cross-platform.md` (OS-guard logging requirement)
- `.claude/rules/hook-rollout.md` (`~/.claude/hooks/logs/` observe-mode logs — fold
  into the unified location or document why they stay separate)

### 14.3 Migration (centralized — most callers inherit via aitools-lib)
- `scripts/aitools-lib.sh` — `AITOOLS_LOG_DIR` → `~/.aitools/logs`; add bash rotation
  + per-component `LOG_FILE` naming via `logging_init` arg.
- `scripts/aitools-lib.ps1` — `Initialize-Logging` → same path + PS rotation.
- `scripts/harness-db.py` — `_log_path()` → `~/.aitools/logs/harness-db.log` + adopt
  `RotatingFileHandler`.
- `scripts/ait-harvest.py` — RotatingFileHandler to `~/.aitools/logs/ait-harvest.log`.
- Hooks that log directly (`standing-order-guard.sh` → `~/.claude/hooks/logs/`,
  `tool-ops-session-audit.sh` jsonl) — reconcile to the unified location.
- `check-lib.sh/.ps1` (`CheckLogInit`/`check_log_init`) — checks.log/jsonl path.
- `clip2md` (`clip2md.log`).
- Datadog `ship` path — verify it reads the DB, not a hardcoded log path; update if
  it tails a log file.
- Regenerate `deploy/` (inlines aitools-lib) via `build-deploy.sh`.
- Docs: the four files in §14.2 + `aitools-workspace.md` (add `logs/` to the
  `~/.aitools/` table) + `managed-file-deployment.md` "Platform log directories".

### 14.4 Added GitHub issue
7. **bug/med** — Windows bash↔PS1 deploy.log location disagree (`aitools-lib.sh:28`
   `~/.local/state` vs PS1 `Initialize-Logging` `%LOCALAPPDATA%`); logs split by
   writer. Resolved by the `~/.aitools/logs/` unification.

### 14.5 Sequencing
`reference/logging.md` (decision doc, present for review) → aitools-lib (.sh/.ps1)
+ rotation → harness-db.py + ait-harvest.py → hooks/check-lib/clip2md reconcile →
rebuild deploy/ → docs consolidation → check-post-push verifies single location.
This can run as its own plan phase (Phase L) before/parallel to harvest Phase 2,
since ait-harvest.py's logging depends on the decided location.

## 15. Full-session review — gaps surfaced (do not skip)

### 15.1 Phase 0 — recover today's orphans NOW (before building anything)
The systemic fix does not recover data already lost. Two CC transcripts from
2026-06-14 are un-archived and still in `~/.claude/projects/C--Users-jdpal-repos-aitools/`:
`8376040a-…jsonl` and `8f8513bf-…jsonl` (1.28 MB). **Manually archive + commit them
to the dotprofile now** (the `aitools sessions archive <id>` primitive already does
this), independent of the helper build, before anything cleans them up.

### 15.2 Scope clarification — what is NOT recoverable on Windows
`scratch-init.sh` was *also* unwired on Windows (same RCA), so `.scratch/session-*`
dirs were **never created** here — there are **no past Windows scratch artifacts to
harvest** (nothing was written). The fix prevents *future* loss; it cannot recover
scratch that never existed. Only CC **transcripts** are retroactively recoverable
(CC writes those regardless of our hooks). The catch-up's harvest half will find
orphans only for sessions *after* scratch-init is restored (Phase 1).

### 15.3 macOS regression guard
macOS already registers `scratch-init`/`harvest` correctly (the bash path works).
The RCA fix touches shared code paths, so verification MUST confirm the **macOS
path is not regressed** — `setup-user-hooks.sh` dry-run on macOS still yields the
same 1-each hook counts; the manifest refactor produces identical `settings.json`
on both platforms. (We are on Windows; macOS check is deferred/noted per
pre-commit "tested: Windows".)

### 15.4 Leave-behind duty (relay)
The relay (`.aitools/channel/relay.md`) has been silent since 2026-04-01. At session
end, append an entry recording this session's operational learning: the Windows
harvest RCA (PS1 `MergeHookEntry` parity gap; I5/I6 lineage), the SessionEnd-only
fragility + SessionStart catch-up design, the unified `~/.aitools/logs/` decision,
and the node-vs-perl conclusion. This is outbound-git (commit/push is the
commander's call per `relay-outbound.md`).

### 15.5 Noted, out of scope
- `running-estimate.json` is a stale March skeleton on this machine; it is exported
  by `harness-db-sessionend.sh` (a *wired* hook), so it's a separate thread, not
  part of this plan.
- Cursor IDE/CLI session archiving → ROADMAP + issue #5 (this session runs in
  Cursor's terminal, but CC archives normally; Cursor's own `store.db` is deferred).

## 16. Concurrency — multiple same-machine sessions (commander-surfaced)

The design as written does NOT handle concurrent sessions gracefully. Three races:

| # | Race | Consequence |
|---|------|-------------|
| 1 | Concurrent git on the **dotprofile repo** — SessionStart catch-up now commits/pushes *on top of* SessionEnd doing so; two sessions hit the same repo at once | `.git/index.lock` contention, index corruption, failed/duplicate commits. **Amplifies a pre-existing SessionEnd-only race.** |
| 2 | Catch-up archives/harvests a **concurrent LIVE session's** transcript/scratch (mtime is a poor liveness signal — a paused live session looks stale) | Incomplete transcript archived; idempotent dest-exists skip then blocks the live session's SessionEnd from landing the *complete* version. Same for live scratch. |
| 3 | Concurrent **`harvest-manifest.json`** read-modify-write (two catch-ups, or catch-up + SessionEnd harvest) | Lost updates / corrupt JSON. |

Already safe: scratch **dirs** use per-session-id names (`scratch-init.sh` — fixed
the old `.current-session` race; RELEASE_NOTES "M4 AAR P3").

### Mitigations (all centralized in `ait-harvest.py`; shims just call it)
- **Single-flight machine lock.** Stdlib atomic lockfile in `~/.aitools/locks/harvest.lock`
  via `os.open(..., O_CREAT|O_EXCL|O_WRONLY)` (atomic on POSIX *and* Windows — `flock`
  is absent on macOS / `fcntl` is Unix-only, so do not use them). Write PID +
  timestamp; **stale-steal** if the lockfile is older than ~60 s (catch-up deadline
  is 10 s, so anything older is dead). The lock guards **every dotprofile git op,
  every manifest write, and the catch-up sweep**. A second session that can't grab
  the lock **skips** its sweep (the holder covers the global orphan set) rather than
  blocking — keeps SessionStart fast.
- **Liveness check (harness DB).** Before archiving/harvesting a session's artifacts,
  query the harness DB (`harness-db.py`): skip sessions **registered but not ended**
  (live/concurrent); only touch sessions that are **ended** or **absent from the DB
  AND stale** (mtime > ~15 min). Always skip your own session. Fallback when
  sqlite/Python-DB is unavailable: conservative mtime threshold (≥30 min) + the lock.
- **Atomic manifest writes.** Write `harvest-manifest.json` to a temp file + `os.replace`
  (atomic), under the lock.
- **Keep** `git add <specific-file>` (never `-A`) and `git pull --rebase` before push
  (the rebase handles the *cross-machine* race; the lock handles *same-machine*).

### Verification additions
- **Concurrency test:** launch two `ait-harvest.py catchup` (and an `archive`)
  processes simultaneously against a shared synthetic dotprofile + projects dir;
  assert no `index.lock` failure, no duplicate/partial archives, manifest stays
  valid JSON, and a live (registered-not-ended) session's transcript is left alone.

## 17. Managed hook inventory + lifecycle diagram (original asks #1 and #3)

### 17.1 Inventory (16 `.sh` + `intelligence-stop.py`; source `shared/hooks/`)

| Event | Hooks (canonical order) | This plan touches |
|-------|-------------------------|-------------------|
| SessionStart | `scratch-init.sh`, `dashboard-serve.sh`, `harness-db-sessionstart.sh` | + **`session-catchup.sh` [NEW]**; restore scratch-init on Win |
| SessionEnd | `session-archive.sh`, `harvest-session.sh`, `tool-ops-session-audit.sh`, `harness-db-sessionend.sh` | shim archive + harvest → `ait-harvest.py`; restore harvest on Win |
| Stop | `command-channel-stop.sh`, `failure-mode-identity-stop.sh`, `failure-mode-verify-stop.sh`, `intelligence-stop.sh` (+`.py`) | — |
| PreToolUse | `standing-order-guard.sh` (Bash), `glossary-skill-guard.sh` (Read\|Grep), `block-claude-code-guide.sh` (Agent), `delegation-duty-guard.sh` (Agent) | logging reconcile (§14) |
| PostToolUse | `sh-file-fixup.sh` (Write\|Edit) | — |

### 17.2 Lifecycle + data-flow diagram (harvest/archive across the hooks)

```
SESSION LIFECYCLE  (hooks run in bash on macOS + Windows; registered in settings.json)

 SessionStart ─┬─ scratch-init.sh            → creates .scratch/session-<sid>/ (per-sid, race-safe)
               ├─ dashboard-serve.sh         → live dashboard
               ├─ harness-db-sessionstart.sh → register session in harness.db  [LIVE]
               └─ session-catchup.sh  [NEW]  → ait-harvest.py catchup  (single-flight LOCK)
                        ├─ archive orphaned CC transcripts  (global; skip own + LIVE + <2min)
                        ├─ harvest orphaned scratch dirs     (current repo; ENDED-only via DB)
                        └─ push dotprofile if ahead
                                   │
                                   ▼
                        ──  session runs  ──   (.scratch/session-<sid>/ accumulates artifacts)
                                   │
                ┌──────────────────┴───────────────────┐
        graceful exit                            ABRUPT exit (close / sleep / offline)
                │                                        │  → no SessionEnd fires
 SessionEnd ─┬─ session-archive.sh → ait-harvest.py archive        orphaned transcript +
             │     transcript(+subagents/) → dotprofile/sessions/   scratch left on disk
             │     git add <file>/commit/pull --rebase/push (LOCK)         │
             ├─ harvest-session.sh → ait-harvest.py harvest                │ recovered by the
             │     .scratch/session-<sid>/ → harvesting/ + manifest        │ NEXT session's
             ├─ tool-ops-session-audit.sh                                  │ session-catchup.sh
             └─ harness-db-sessionend.sh → mark ENDED, export estimate     ▼
                                   │                              └──► (loops back to catch-up)
                                   ▼
 DATA SINKS:  ~/.claude/projects/<cwd>/<sid>.jsonl(+subagents/) → <dotprofile>/sessions/<project>/<date>_<prefix>.jsonl
              <repo>/.scratch/session-<sid>/                    → <repo>/harvesting/<date>_session-<prefix>_<file>
              handoff* files                                    → <repo>/.aitools/channel/handoffs/
              all hook/setup/check logs                         → ~/.aitools/logs/<component>.log   (§14)
```

The key resilience property the diagram shows: the **abrupt-exit path** (no
SessionEnd) is closed by the **next session's `session-catchup.sh`**, gated by the
lock (§16) and DB-liveness (§16) so it never touches a live concurrent session.

## 18. Ask → deliverable traceability (full session, in order)

| # | Commander ask | Deliverable |
|---|---------------|-------------|
| 1 | Did SessionEnd archive to dotprofile today? Check remote | Investigated; 2 orphans found → §15.1 |
| 2 | Map hooks we manage | §17.1 inventory |
| 3 | Map session-archive + factor logic into reusable code | §2, §4 (`archive_claude_session`), §9 |
| 4 | Map harvest hook + **diagram** with the various hooks (+ build-deploy/aitools in context) | §0 (load), §4 (`harvest_scratch`), **§17.2 diagram** |
| 5 | Graceful on network/abrupt end → harvest at session start | §4 `catchup`, §16, §17.2 |
| 6 | One `ait-harvest.py` with per-source functions (scratch / CC / Cursor); "what else am I missing?" | §4 functions, §3 inventory (+subagents, Cursor SQLite) |
| 7 | Logging libs + init-logging in context; be inline with logging | loaded; §6(1), §14 |
| 8 | `/investigate` RCA the Windows harvest issue (gh issues, notes, commits, sessions, dotprofile) | §2 RCA |
| 9 | Add Cursor to ROADMAP + file GH issues (re-read session for more) | §7, §8, §18 (this catalog) |
| 10 | Patch now + structural fix | §2 (patch), §5 (manifest + step 32) |
| 11 | Python hooks log to `~/.aitools/logs/`; rotation; remediate existing; don't like `.local` | §14 |
| 12 | All aitools logging; native path separators (win/pwsh vs mac/linux/android) | §14.1, §14.3 |
| 13 | macOS override to `~/.aitools/logs` | §14.1 |
| 14 | Document decision in `reference/logging.md`; consolidate scattered docs | §14.1, §14.2 |
| 15 | Read all non-json/sql `reference/` files; regenerate plan from scratch; compare to v1 → v3 | loaded 35; §12 reconciliation (v3) |
| 16 | Four passes: logging / `.sh`-`.ps1` parity / harvest-scratch logic / uncaught exits | §6(1)–(4) |
| 17 | Explicit transcript path + how to read it; load lib*/aitools*/build-deploy.sh at start | §0 |
| 18 | Scan plan for efficient perl use | §6(5) |
| 19 | Are we using node where we should use perl? | §6(5) (node=JSON correct; perl=text/step 32) |
| 20 | Review session; did I miss something? | §15 (Phase 0 recover, Win-scratch unrecoverable, macOS regression, relay duty) |
| 21 | Concurrent same-machine sessions handled gracefully? | §16 (lock + DB-liveness + atomic manifest) |
| 22 | Full line-by-line catalog of asks → deliverables (incl. hook diagrams) | **§17.2 diagram + this §18 catalog** |

**Partially met (flagged honestly):** "save a copy of the old plan / 3 versions"
(ask 15) — plan mode allows editing only this one plan file, so v1/v2 were not
saved as separate on-disk files; v1 is preserved verbatim in the session
transcript (§0 path) and can be materialized on request.

## 19. Plan verification — subagent fan-out (run FIRST, before any edits)

Before executing, launch **three parallel verification subagents** with discrete,
non-overlapping scopes (multi-perspective evaluator pattern). Each must read the
plan in full AND independently read this session's transcript with the reader
tools, so the verification is grounded in the actual deliberation — not just the
plan's self-report. Collect their structured findings, resolve any gap before
Phase 0.

**Shared briefing every verifier gets (delegation duty — subagents do not inherit
rules/CLAUDE.md, so pass paths explicitly):**
- **Plan:** `~/.claude/plans/imperative-gliding-newell.md` (read in full).
- **Transcript:** `~/.claude/projects/C--Users-jdpal-repos-aitools/8f1728f5-8043-4ab9-ae38-0f080e04d844.jsonl`
  via `python3 scripts/read-session.py "<path>" --search "<term>"` / `--last N`
  (text) and `scripts/read-session-full.py` (full fidelity) — run from the aitools
  repo root (Windows: `py -3`).
- **Source files** relevant to the scope (explicit paths from §0).
- **Output:** write findings to `.scratch/session-8f1728f5/verify-<scope>.md`
  (structured: PASS/CONCERN/GAP per item, with transcript/line citations). Emit
  `INCIDENT:` markers for any spec deviation found. If Write is denied, output
  `WRITE_BLOCKED` as the first line with the full findings inline.
- **Scope discipline:** stay in your lane; report gaps, don't expand scope. Cite
  sources for every claim (transcript turn, file:function) — synthesis is not
  evidence.

**Verifier A — Ask coverage (vs transcript).** Independently re-derive the list of
commander asks by reading the transcript end-to-end (`read-session.py`), then check
each against §18's catalog and the actual plan sections. Flag any ask missing,
mis-mapped, or only partially met (confirm the §18 "partially met" note is the only
one). Deliverable: a corrected ask→deliverable table.

**Verifier B — Technical soundness.** Read the plan + `scripts/setup-user-hooks.ps1`,
`scripts/setup-user-hooks.sh`, `scripts/build-deploy.sh`, `scripts/aitools-lib.{sh,ps1}`,
`scripts/harness-db.py`, and the touched hooks. Verify: the RCA is factually correct
(PS1 truly has no `MergeHookEntry`/validation for scratch-init/harvest); the
concurrency design (lock + DB-liveness + atomic manifest, §16) is sound and the lock
is genuinely cross-platform (no `flock`/`fcntl`); the logging migration (§14) is
complete and the format/rotation correct; the `.sh`↔`.ps1` parity fix (§5) closes
all three layers; flat session naming + lossy-path + subagents + transient-update
skip (§3/§4) are right; perl/node usage (§6.5) is correct.

**Verifier C — Adversarial completeness.** Read plan + transcript and hunt for what
the plan still misses: unhandled hooks/events, untested paths, edge cases (empty
transcript, `userRepoPath` unset, dotprofile detached/dirty, harness-db absent,
Cursor-only sessions, `claude update` transient session), and any place a silent
`exit 0` still hides a failure (pass 4). Challenge the design; propose the strongest
counter-example to "this is resilient + concurrency-safe."

**After fan-out:** read all three `verify-*.md`, fold confirmed gaps into the plan,
re-verify only the changed parts, then proceed to Phase 0. (Optional second pass:
re-launch the relevant verifier on the corrected plan.)

## 20. Verification fan-out RESULTS + folded amendments (2026-06-14)

Ran §19 (three subagents). Findings written to `.scratch/session-8f1728f5/verify-{coverage,technical,adversarial}.md`.
- **Verifier B (technical): PASS, 0 wrong.** RCA confirmed exactly (PS1 no
  `MergeHookEntry` L407–468 / no validation L552–578; bash registers L397–398 +
  validates L472–477). Parity, lock primitive, logging-no-rotation, lossy-path,
  flat-naming, perl/node — all verified with file:line.
- **Verifier A (coverage): COMPLETE, 0 deliverable gaps**, 2 nits (below).
- **Verifier C (adversarial): 1 design hole + 3 CRITICAL + 6 MAJOR + 4 MINOR.**

These amendments **supersede** the relevant earlier sections.

### 20.1 §16 CONCURRENCY — redesign (C lead + C1/C2 + m1/m2)
- **Liveness must NOT rely on the per-repo harness DB for the global sweep.**
  `harness-db.py` resolves `.aitools/harness.db` under the *catch-up's own* repo
  (`find_project_root`); a sweep in repo A cannot see a live session in repo B's
  DB → it would archive B's incomplete transcript and dest-exists then blocks B's
  SessionEnd (race #2, NOT closed). **New primary guard = the transcript itself:**
  skip any transcript whose **mtime is < ~30 min old** (conservative) OR whose
  last JSONL record is not a clean session end. The harness DB is at most a
  per-repo *optimization* (resolve the transcript's repo from its `cwd`, query
  that repo's DB) — never the sole signal. **"Skip your own session" uses the
  `session_id` from the catch-up hook's own stdin** (deterministic), never a DB
  lookup (CC may run same-event hooks before `harness-db-sessionstart`; M5).
- **Lock = heartbeat, not creation-age (C1).** SessionEnd's git ops are NOT
  deadline-bounded (`session-archive.sh:133-134`), so a slow-but-alive push can
  hold the lock > 60 s. The holder must **refresh the lockfile timestamp**
  periodically; a contender steals only if the timestamp **hasn't advanced** in N s
  **and** no `.git/index.lock` exists in the dotprofile. Store **(pid, start-time,
  hostname)**. **Never block — always skip when contended** (C2; PID-liveness isn't
  portable stdlib on Windows). Release via **`try/finally`/`atexit`** (m2); `mkdir
  -p ~/.aitools/locks` first (m1); document the ≤N s degraded window after a crash.

### 20.2 §4 EDGE CASES — explicit handling (C3 + M1 + M2 + M6)
- **Shim no-Python / pre-logging failure (C3):** the bash shim wraps the Python
  call in `|| true` (always exit 0) AND, on the no-Python / no-helper / non-zero-exit
  branches, appends a one-line reason to `~/.aitools/logs/session-catchup.log`
  **from bash** (Python may be the missing thing, or may die before logging init if
  `$HOME` unset / log dir unwritable). The pass-4 "log why" promise is bash's job
  for these branches, Python's for the rest.
- **Bad transcripts (M1):** zero-byte/unparseable → skip + log "empty/unreadable";
  missing `cwd` → fall back to the sanitized projects-dir name (old behavior) + log
  "cwd-derive failed"; `cwd` repo gone → still archive under the dir-name project
  (the transcript is the artifact).
- **Transient `claude update` session (M2):** skip by a **positive** signal
  (transcript < N records / update-session id pattern), not absence-of-dir. And
  `aitools install` sets `AITOOLS_DEPLOY_IN_PROGRESS=1`; catch-up **skips its sweep**
  when set (mirrors `AITOOLS_SKIP_RELAY_PROMPT`) to avoid catch-up × live-deploy
  dotprofile/lock contention.
- **dotprofile not clean (M6):** before git ops check upstream
  (`rev-parse --abbrev-ref --symbolic-full-name @{u}`), mid-op (`.git/rebase-*` /
  `MERGE_HEAD`), `git remote` (origin?). On any → **skip push, keep the local
  commit, log the specific reason** (no silent exit 0 — pass 4).

### 20.3 §14 LOGGING — corrections (M4 + m3)
- **Strike the Datadog worry** in §14.3: `ship_to_datadog` reads `kpi_events` from
  the DB, not a log tail (verified `harness-db.py:1267-1405`) — no log-path coupling.
- **Add migration step:** `grep -rn` for old log-path literals (`.local/state`,
  `Library/Logs`, `deploy.log`) across `scripts/`, `shared/`, `reference/`, checks;
  update/redirect each; verify `check-*` scripts that assert on log location.
- **Standardize the session-id prefix length:** `session-archive.sh` uses 8 chars,
  `harvest-session.sh`/`scratch-init.sh` use 10 (m3). Pick one (8, matching the
  archive naming + `aitools sessions archive`) everywhere to avoid cross-machine
  `<date>_<prefix>.jsonl` collisions on forked/resumed sessions.

### 20.4 §3 cosmetic (B)
Subagent transcripts are documented under `tool-ops-claude-code.md` **#16**
(Session Storage Internals), not #4 — fix the §3 citation.

### 20.5 §0/§18/§19 catalog + method (A: GAP-1, GAP-2)
- **§18 add row 23:** "Launch verification agents at end of plan (verify plan) →
  §19." (A's only catalog gap; the work exists.)
- **§0 + §19 method note:** `read-session.py` surfaces only the 3 inline user
  turns; the other 12 commander directives this session were **plan-mode feedback**
  (ExitPlanMode rejections / AskUserQuestion answers) that the readers render only
  as agent paraphrase. To enumerate ALL asks, recover them from the raw JSONL
  `tool_result` payloads (search `read-session-full.py` for `"want to proceed"` /
  `"questions have been answered"`), not `read-session.py` alone.
- **"Save a copy / 3 versions" (ask A7):** confirmed the only partially-met item.
  Now that we're out of plan mode, **materialize v1 as a saved copy + a v1→v3 diff**
  to fully honor it.

### 20.6 §17.2 / §15.5 — resilience scope caveat (M3)
The catch-up resilience property covers **CC sessions only**. Cursor-only workflows
(`agent` CLI, no CC transcript) have neither SessionEnd archiving nor SessionStart
catch-up until issue #5 — state this in the diagram/§15.5 (unrecovered surface,
not just "deferred").

### 20.7 New GitHub issue (m4 — a tool this plan depends on is broken)
8. **bug/med** — `scripts/read-session.py` crashes with `UnicodeEncodeError`
   (`'charmap' codec can't encode '→'`) on a default Windows console (cp1252) for
   any transcript with non-ASCII. §0/§19 depend on this tool. Fix:
   `sys.stdout.reconfigure(encoding='utf-8')` (or honor `PYTHONIOENCODING=utf-8`).

### 20.8 Tests to add (fold into §11/§16)
1. Orphaned **live** transcript in repo B, catch-up in repo A → B left alone.
2. Lock holder alive > 60 s (heartbeating) → contender does NOT steal.
3. Crashed holder (orphaned lock) → next sweep recovers after threshold.
4. Shim with no Python on PATH → exit 0 + logged reason (bash fallback).
5. Zero-byte transcript; transcript with missing `cwd`.
6. `AITOOLS_DEPLOY_IN_PROGRESS=1` → catch-up skips.
7. dotprofile detached-HEAD / no-origin / mid-rebase → exit 0, commit kept, reason logged.
8. Catch-up before vs after `harness-db-sessionstart` → own session always skipped via stdin sid.
9. Repo-wide grep for old log-path literals after §14 migration → none remain.
