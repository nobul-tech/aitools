# Artifact Harvesting

Version 1.2 (2026-11-01). Merges the rule `artifact-harvesting.md` and
`reference/framework-artifact-harvesting.md` into one document, and adds a
description, rebuilt from the code, of what the SessionStart and SessionEnd
hooks actually do. v1.1: the hook fixes for gaps G1–G6 are in the code, and
sections 4–8 describe the fixed behaviour. v1.2: the Known gaps section was
removed (commander); the gap ids G1–G6 used below are defined in
`RELEASE_NOTES.md` v0.74.1.

**Intent**: **Purpose**: Be the single reference for artifact harvesting in
aitools: why it exists (source discipline), what must and must not be
harvested, promoted or pruned (criteria), and exactly how the
SessionStart/SessionEnd hooks move files from session scratch into
`harvesting/`, the channel handoffs and the harvest manifest (mechanism).
Spec and mechanism are kept side by side, so it is plain wherever the code
is behind the spec. **Scope**: Source discipline and adoption rationale,
harvest/prune/promote/generalize criteria, the hook pipeline
(`scratch-init.sh`, `session-catchup.sh`, `harvest-session.sh`,
`session-archive.sh` and their helper `scripts/ait-harvest.py`), the
manifest lifecycle, channel touchpoints, safety guards and known gaps. NOT the
step-by-step harvesting and promotion process or manifest edits (`/harvest`
skill). NOT scratch directory conventions and naming (`/scratch` skill). NOT
the harness DB, KPI telemetry or Stop hooks beyond the files they leave in
scratch. **Audience**: Agents harvesting, promoting or pruning artifacts;
agents changing the harvest hooks or `ait-harvest.py`; agents designing
harvesting improvements.

---

## 1. Governing principle

Every session produces artifacts beyond the primary deliverable: utility
scripts, exploration tools, research documents, prompt patterns. Each is a
tactical solution to a real problem. Left in scratch, they are lost.
Harvested and evaluated, they become candidates for harness improvement.

Two directories keep throwaway work apart from work that may be reusable:

| Directory | Tracked | Role |
|---|---|---|
| `.scratch/session-<name>/` | gitignored | Ephemeral working files of one session (or delegate) on one machine |
| `harvesting/` | tracked, except the manifest | Staging area: harvested artifacts waiting to be promoted or pruned, plus the harvest manifest. In aitools the manifest (`harvest-manifest.json`) is gitignored and machine-local (commander, 2026-11-13): each machine's harvester keeps its own, and a machine that has none starts an empty one |

Harvesting is automated: the hooks copy reusable scratch files at session end
and recover what an abrupt exit missed at the next session start, so no one
has to remember to save a script. Evaluation (promote or prune) is partly
automated (section 6) and partly a human or agent decision (`/harvest`
skill).

## 2. Source discipline

**Reuse engineering** (Disciplined Agile): deliberately identifying,
extracting, generalizing and publishing reusable assets from working code.
PMI/DA lifecycle: identify → obtain → generalize → validate → publish.

Extended with:

- **Staging pipeline** (Linux kernel `drivers/staging/`): code that works but
  is not mainline quality waits in staging with an explicit expectation:
  promote it or remove it. Staging is never a permanent parking lot.
- **Toil automation** (Google SRE): manual, repetitive, automatable work moves
  runbook → script → tool → platform. Harvested scripts are at the "script"
  stage; promotion moves them toward "tool".
- **Tactical-to-strategic programming** (Ousterhout): code written to solve
  an immediate problem may deserve investment to become a proper
  abstraction. The harvesting lifecycle is that bridge.

### How we adopted it

| Concept | aitools implementation | Status |
|---|---|---|
| Identify / obtain | `.scratch/` → `harvesting/` copy at SessionEnd (`harvest-session.sh` → `ait-harvest.py harvest`), recovered at SessionStart (`session-catchup.sh` → `ait-harvest.py catchup`) | Implemented |
| Staging with expiry | Manifest `pruneAfter` = harvested + 30 days; SessionStart audit re-classifies past-due entries | Implemented (status only; files never deleted) |
| Generalize / validate | `/harvest review`: AI analysis of artifacts against the harness inventory, git history and KPIs | On demand only |
| Publish (promote) | `/harvest` skill: move or refactor into `scripts/`, `shared/skills/`, check scripts, `shared/shell/`; manifest `promoted` | Manual |
| KPI-driven lifecycle | Datadog metrics: inventory, age distribution, promotion rate, generalization actions (`plans/datadog-log-integration.md`) | Planned, not implemented: no hook or script emits harvest KPIs |

## 3. Criteria (spec) and what implements them

The criteria below are the governance spec. The "Implemented as" column says
what the code does today; where they differ, the code is behind the spec.
Not implemented: the "keep" flag, the 7-day promotion rule, manual-flag
semantics, the `aitools` sync candidate prompt, harvest KPIs, and the
"already committed elsewhere" exclusion; `type` is always `code`.

### 3.1 What MUST be harvested

At session end, every non-ephemeral file in the session scratch directory
that represents reusable work:

- Code (scripts, utilities, one-off tools)
- Prompts (patterns that produced good results)
- Research (evaluation documents, analysis outputs)
- Patterns (approaches that could be generalized)

### 3.2 What MUST NOT be harvested

| Spec | Implemented as (`_is_ephemeral()` in `scripts/ait-harvest.py`) |
|---|---|
| Harness bookkeeping (not in the original spec) | `.harvested`, `.intelligence-last-check`, `events.jsonl`, and every name starting with `.` |
| Commit message files | Only names starting `commit-msg`. Other message files (`msg-*.txt`, `commit-1.txt`, PR bodies) are harvested |
| Build/check logs | Names ending `.log`; `.md` names containing `log`, `output` or `dump` |
| Temp output captures | Names ending `.tmp`. Other captures (`.txt`, `.out`, `.json`, `.tar`) are harvested |
| Files already committed to a permanent location | Not checked |

### 3.3 Pruning criteria

Spec: an artifact MUST be auto-pruned when ALL are true:

- Age > 30 days since harvested
- Zero references in git log
- Not flagged "keep" in the manifest
- Status is still `harvested` (never reached `candidate`)

Implemented as: once today is past `pruneAfter` (harvested + 30 days), an
entry whose status is neither `promoted` nor `pruned` becomes `pruned` if its
file name never appears in `git log --all` under `harvesting/`. There is no
"keep" flag. Pruning changes the manifest status only; the file stays in
`harvesting/` until someone deletes it.

### 3.4 Promotion criteria

Spec: an artifact becomes a promotion candidate when ANY is true:

- Referenced in git log (used in a commit)
- Manually flagged by user or agent
- Age > 7 days AND a similar pattern is detected in the harness inventory

Promotion candidates MUST be presented to the user for review.

Implemented as: only at the same past-`pruneAfter` audit, an entry whose
file name appears in `git log --all` under `harvesting/` becomes
`candidate`. "Referenced" therefore means "the harvested file itself was
committed to `harvesting/`", not "used in a commit". No entry becomes a
candidate before it is 30 days old. The 7-day rule is not implemented. A
manual flag is a hand edit of the manifest through the `/harvest` skill.

### 3.5 Generalization

Artifacts that solve a specific problem may generalize into harness tools.
Generalization is evaluated by `/harvest review` (AI analysis against the
harness inventory, git history and KPIs). Triggers:

- On demand: `/harvest review`. Implemented (skill-driven).
- `aitools` sync when candidates exist. **Not implemented**: `scripts/aitools`
  has no candidate prompt.
- Periodic Modal job for cross-session pattern analysis. Future.

## 4. Components

| Event | Hook (`shared/hooks/`) | Calls | Role in harvesting | Blocking |
|---|---|---|---|---|
| SessionStart | `scratch-init.sh` | `harness-db.py` | Creates `.scratch/session-<full session id>/` (reuses the session's legacy `session-<id[:10]>/` if it exists), writes `.scratch/.current-session`, reports stale dirs and the newest handoff | Synchronous |
| SessionStart | `session-catchup.sh` | `ait-harvest.py catchup --deadline 10` | Recovers what SessionEnd missed: reports a stale dotprofile `index.lock`, archives orphan or grown transcripts, commits archives left uncommitted, harvests scratch dirs with pending files; audits the manifest; pushes the dotprofile | Synchronous, ~10 s budget |
| SessionEnd | `harvest-session.sh` | `ait-harvest.py harvest` | Harvests this session's scratch dir (new or changed files only) | Synchronous |
| SessionEnd | `session-archive.sh` | `ait-harvest.py archive` | Copies the transcript and subagent transcripts to the dotprofile, commits those paths only, pushes | Detached (`nohup` + `disown`); returns at once |
| SessionEnd | `harness-db-sessionend.sh` | `harness-db.py` | Not harvesting: ends the DB session, processes `events.jsonl` (finds the full-id or legacy scratch dir), exports `.aitools/channel/running-estimate.json` | Synchronous |
| Stop | `intelligence-stop.sh`/`.py`, `command-channel-stop.sh` | | Not harvesting, but they write `.intelligence-last-check` and `events.jsonl` into the scratch dir; the harvester never copies them | Every turn |

**Scratch names are never truncated.** A dir name is used verbatim
everywhere (harvested file names, routed handoff names, manifest `session`).
The 10-character form `session-<id[:10]>` survives only as a lookup fallback
for dirs created before 2026-10-31, and as the session DB file name
(`.aitools/sessions/<id[:10]>.db`) and Session Commander ID, which were
left as they are.

All four hook shims are standalone bash (no aitools-lib), pass the raw hook
stdin JSON to Python, and always exit 0. They resolve the helper in this
order: `<git root>/scripts/ait-harvest.py`, `~/.claude/hooks/ait-harvest.py`
(deployed through the `deploy` list of the hooks manifest), then
`~/repos/aitools/scripts/ait-harvest.py`. Hook registration lives in the
hooks manifest in `shared/hooks/`.

Claude Code starts all hooks of one event in parallel, so `scratch-init.sh`
and `session-catchup.sh` race each other. Since v1.1 that race is harmless:
catch-up never resolves a dir through `.current-session` and skips the
current session's own dir by name (G1).

## 5. Flow

### 5.1 Session lifecycle

```
 SESSION START   (SessionStart hooks run in parallel)
 ==========================================================================================
  scratch-init.sh                              session-catchup.sh
  |- dir = .scratch/session-<full id>/         '- ait-harvest.py catchup --deadline 10
  |    (legacy session-<id[:10]>/ of the          |- AITOOLS_DEPLOY_IN_PROGRESS set? -> skip all
  |     same session reused if present;           |- acquire ~/.aitools/locks/harvest.lock
  |     unsafe or empty id -> mktemp)             |    live holder -> skip all (never blocks)
  |- write .scratch/.current-session              |- [L] dotprofile .git/index.lock > 10 min old?
  |- print "Stale scratch dirs: N"                |      -> log + print a warning (never deleted)
  |- print "Handoff available: <newest>"          |- [A] ARCHIVE transcripts, ALL projects
  |    (every *.md in .aitools/channel/           |      ~/.claude/projects/*/*.jsonl
  |     handoffs/, newest by leading date)        |      skip: own session, empty, mtime < 30 min,
  '- harness-db init + session start              |            < 3 records, archive not smaller
                                                  |      --> archive_claude_session()  (5.4)
                                                  |- [C] COMMIT archive files left uncommitted
                                                  |      under <dotprofile>/sessions/
                                                  |- [H] HARVEST scratch dirs, THIS repo
                                                  |      every .scratch/session-* except own
                                                  |      (full or legacy name), with pending
                                                  |      files, idle >= 30 min
                                                  |      --> harvest_scratch(dir by path)  (5.2)
                                                  |- [M] AUDIT the harvest manifest once  (6)
                                                  '- [P] PUSH dotprofile if ahead of upstream
                                                  (lock heartbeat between steps; released in finally)

 DURING THE SESSION
 ==========================================================================================
  agents (Write tool) ---------------------> .scratch/session-<full id>/<files>
  delegates (any name length) -------------> .scratch/session-<name>/<files>   (/scratch skill)
  intelligence-stop (Stop) ----------------> <session dir>/.intelligence-last-check
  Stop + PreToolUse guards ----------------> <session dir>/events.jsonl
                                              (via .current-session, when it exists)

 SESSION END   (SessionEnd hooks run in parallel; nothing they print reaches Claude)
 ==========================================================================================
  harvest-session.sh --------> ait-harvest.py harvest --> harvest_scratch(own dir)  (5.2)
  session-archive.sh --nohup-> ait-harvest.py archive --> archive_claude_session()  (5.4)
  harness-db-sessionend.sh --> harness-db.py end / process-events / ship / export
                                  '--> .aitools/channel/running-estimate.json  (tracked)

  If any of these is cut off (crash, sleep, kill, offline), the next
  SessionStart catch-up [A]/[C]/[H] recovers it.
```

### 5.2 `harvest_scratch()`: scratch to harvesting

```
  input: a dir (catch-up passes each dir by path)  OR  a session id (SessionEnd)
     |
     v
  dir given? -> use it as is
  else resolve_session_dir(id):
       .scratch/session-<full id>/  ->  .scratch/session-<id[:10]>/ (legacy)
       ->  no id at all: the dir in .scratch/.current-session
       (a known id never falls back to the pointer)
     |   none found -> log "no session dir", return
     v
  tag = dir name after "session-", verbatim
  record = <dir>/.harvested  (JSON: file -> size + mtime at its harvest;
                              legacy timestamp marker: files not modified
                              after it count as harvested)
     |
     v
  for each top-level FILE in dir, sorted (subdirectories are ignored)
     |
     |-- ephemeral? (5.3) -------------------- yes --> skip (counted; left in scratch)
     |-- unchanged since its recorded harvest? yes --> skip (counted)
     |
     |-- name starts "handoff"? -------------- yes --> copy to
     |                                                 .aitools/channel/handoffs/
     |                                                   <date>_session-<tag>_<name>
     |                                                 (tracked, no manifest entry)
     v
  copy to harvesting/<date>_session-<tag>_<name>
          (name taken? harvesting/<date>_<n>_session-<tag>_<name>, n = 1, 2, ...)
     |
     '--> manifest entry: status=harvested, pruneAfter=date+30d       (6)
     |
     v  after the loop
  write the manifest atomically (temp file + os.replace), only if something was harvested
  delete .scratch/.current-session ONLY if it names this dir   (G6)
  write <dir>/.harvested atomically: the record plus every file copied now
  log "harvest <tag>: N harvested, U unchanged since last harvest, M ephemeral skipped"
```

`<date>` is today's UTC date at harvest time, not the session's date.
Copies use `shutil.copy2`; scratch files are never moved or deleted. A file
that changed after its harvest is copied again (a new version, so it gets the
`_<n>_` collision name on the same day).

### 5.3 Classification (`_is_ephemeral()`)

Checked in this order, on the file name (case-insensitive):

| Rule | Result |
|---|---|
| `.harvested`, `.intelligence-last-check`, `events.jsonl`, or any name starting with `.` | Ephemeral (harness bookkeeping) |
| Starts with `commit-msg`, or ends with `.log` or `.tmp` | Ephemeral |
| Extension `.py .sh .ps1 .js .ts .go .rs .pl` | Harvest |
| `.json`: starts with `package-lock`, `node_modules` or `tsconfig`, or ends with `.config.json` | Ephemeral |
| Any other `.json` | Harvest |
| `.md` whose name contains `log`, `output` or `dump` | Ephemeral |
| Any other `.md` | Harvest |
| `.yaml .yml .toml .csv .sql .html .txt` | Harvest |
| Anything else: no extension, other `.jsonl`, `.diff`, `.patch`, `.tar`, `.out` | Harvest (never silently dropped) |

Handoff routing (`handoff*`) is decided after this check: `handoff-notes.log`
is ephemeral, not routed.

### 5.4 `archive_claude_session()`: transcripts to the dotprofile

Not harvesting proper, but it shares the helper, the lock and the catch-up.

```
  transcript (~/.claude/projects/<dir>/<session-id>.jsonl)
     |  dotprofile = config.json userRepoPath (missing/unset -> skip, logged)
     |  zero-byte -> skip
     v
  project = git root name of the transcript's first recorded cwd
            (repo gone -> sanitized cwd name; no cwd -> sanitized projects-dir name)
  dest    = <dotprofile>/sessions/<project>/<mtime-date>_<id8>.jsonl
     |  dest exists and is not smaller than the transcript -> skip "already archived"
     |  dest smaller (the session grew: resumed or continued) -> copy again   (G5)
     v
  copy transcript; copy each subagents/*.jsonl (two layouts probed) as
       <date>_<id8>_<subagent file stem>.jsonl  (named after the file, so a
       later subagent never shifts earlier names; a grown copy is replaced; a
       byte-identical legacy <date>_<id8>_subagent-<n>.jsonl is not duplicated)
     v
  git add + git commit -- <those paths only>   (other staged dotprofile work is
       never swept into the commit)
       "Archive session ..." / "Update archived session ..."
  push only if: no merge/rebase in progress, origin exists, upstream set, HEAD not detached;
  pull --rebase first unless tracked files are dirty; every git call deadline-bounded
  (any failure: log the reason; files left uncommitted are committed by catch-up [C])
```

The archive file prefix stays 8 characters; that is an archive name, not a
scratch name.

## 6. The harvest manifest

The manifest lives in `harvesting/` of each project and is governed data:
read and change it through the `/harvest` skill (schema and editing rules
are there). The hooks write it as follows.

| Writer | When | What |
|---|---|---|
| `harvest_scratch()` | SessionEnd, catch-up [H] | Adds one entry per harvested file, keyed by its `harvesting/` file name: `harvested` (date), `session` (`<project>/<date>_<tag>`), `description` ("Auto-harvested from session scratch"), `type` (always `code`), `language` (from extension; `null` when unknown), `status` (`harvested`), `promotedTo` (`null`), `pruneAfter` (date + 30 days). Creates the manifest with `meta` `{schemaVersion, lastAudit: null}` if missing; an unreadable manifest is logged and replaced with a fresh one |
| `_audit_manifest()` | catch-up [M], once per SessionStart | For entries past `pruneAfter` and not `promoted`/`pruned`: one `git log --all --name-only -- harvesting` pass; name found → `candidate`, else → `pruned`. Sets `meta.lastAudit` when anything changed. Deadline-bounded; on git failure every past-due entry becomes `pruned` |
| `/harvest` skill (agent or user) | By hand | Corrects `description`/`type`/`language`; promotes (`promoted`, `promotedTo`) |

The per-dir harvest record (`<scratch dir>/.harvested`) is not the
manifest. It stays in scratch and only answers "has this file, at this size
and mtime, been copied already?":

```json
{"version": 1, "lastHarvest": "<UTC>", "files": {"<name>": {"size": 123, "mtime": 1761950000.0}},
 "legacyTime": 1761900000.0}
```

`legacyTime` appears only when the dir carried a pre-v1.1 timestamp-only
marker; files not modified since then count as harvested.

Status lifecycle:

```
              harvest_scratch()
   (file) -----------------------> harvested
                                       |
                    catch-up audit, only once today > pruneAfter (harvested + 30 d)
                                       |
              +------------------------+------------------------+
              | file name ever committed under harvesting/      | never committed
              v                                                 v
          candidate                                          pruned   (file kept; delete by hand)
              |
              | /harvest skill: approved and moved/refactored into the harness
              v
          promoted   (promotedTo = <target path>)
```

The hooks never commit the project repo. Harvested files and manifest
updates stay as working-tree changes in `harvesting/` until someone commits
the files (`/harvest` skill, "Commit the artifact"; in aitools the manifest
is gitignored, so only the harvested files are committed). Because
"referenced in git" means "committed under `harvesting/`", committing
`harvesting/` is what turns entries into candidates at their next audit.

## 7. Channel interaction

| Touchpoint | Direction | Detail |
|---|---|---|
| `.aitools/channel/handoffs/` | scratch → channel | `harvest_scratch()` copies every non-ephemeral `handoff*` file from scratch to `<date>_session-<tag>_<name>` here (tracked, Channel exception: committed direct to main). No manifest entry. Copied again only when the scratch file changed |
| `.aitools/channel/handoffs/` | channel → session | `scratch-init.sh` counts every top-level `*.md` here and announces the one with the latest leading `YYYY-MM-DD` (undated legacy names rank last). Issue #138 tracks settling one naming scheme |
| `.aitools/channel/running-estimate.json` | DB → channel | Written by `harness-db-sessionend.sh` at SessionEnd, not by the harvester; listed because it is the other SessionEnd carry-forward into the channel |
| `.aitools/channel/relay.md`, `channel/session-*/` | none | The harvester neither reads nor writes them |

## 8. Safety guards

- **Never deletes scratch.** `scratch-init.sh` once removed stale dirs and
  destroyed 30 unharvested artifacts (2026-03-21). Since then stale dirs are
  only counted, `harvest_scratch()` only copies, and the audit only changes
  status. The harvest record (not deletion) makes a dir settle.
- **Hooks never break Claude Code.** Every shim and subcommand exits 0. When
  Python or the helper is missing, or the helper exits non-zero, the shim
  writes one line to its own fallback log (`harvest-session.log`,
  `session-catchup.log`, `session-archive.log`). The helper logs to
  `~/.aitools/logs/ait-harvest.log` (5 MB × 5, `[UTC] [ait-harvest] [level]`);
  a top-level `except` logs any unhandled error and returns 0.
- **Single-flight catch-up.** `~/.aitools/locks/harvest.lock`, created with
  `O_CREAT|O_EXCL` (atomic on POSIX and Windows). The holder refreshes a
  heartbeat; a contender steals only when the heartbeat is older than 90 s
  and the dotprofile has no live `.git/index.lock` (one older than 10
  minutes counts as stale), otherwise it skips its sweep. Released in
  `finally` and `atexit`. SessionEnd `harvest` and `archive` do not take the
  lock.
- **Stale dotprofile index lock.** Catch-up reports a `.git/index.lock` older
  than 10 minutes in the log and on stdout (SessionStart adds it to Claude's
  context). It never deletes it: a live git may own it.
- **Archive commits are scoped.** `git commit -- <paths>`: only the archive
  files, never other work staged in the dotprofile.
- **Liveness.** The global transcript sweep skips any transcript modified in
  the last 30 minutes and its own session (stdin `session_id`, never a DB
  lookup). The scratch sweep skips the current session's own dir by name and
  any dir modified in the last 30 minutes (another live session or delegate
  in the same repo).
- **Deadline.** Catch-up has a 10 s budget enforced in Python (no portable
  `timeout(1)`); each sweep stops cleanly when it is spent.
- **Atomic writes** for the manifest and the harvest record (temp file +
  `os.replace`).
- **Deploy guard.** `AITOOLS_DEPLOY_IN_PROGRESS=1` makes catch-up skip.
- **Detached archive.** Claude Code gives SessionEnd hooks a short grace
  window; the synchronous copy + commit + push overran it ("Hook cancelled"
  on every exit), so since 2026-06-21 the archive runs detached.

## 9. Maintenance and implementing artifacts

| Artifact | Role |
|---|---|
| `shared/skills/harvest/SKILL.md` (`/harvest`) | Process: harvest by hand, manifest schema and edits, promotion, pruning, `/harvest review`, KPI definitions |
| `/scratch` skill, user rule `scratch.md` | Scratch directory, naming, delegate scratch dirs |
| `shared/hooks/scratch-init.sh` | SessionStart: scratch dir, pointer, handoff discovery |
| `shared/hooks/session-catchup.sh` | SessionStart shim → `ait-harvest.py catchup` |
| `shared/hooks/harvest-session.sh` | SessionEnd shim → `ait-harvest.py harvest` |
| `shared/hooks/session-archive.sh` | SessionEnd shim (detached) → `ait-harvest.py archive` |
| `scripts/ait-harvest.py` | All archive, harvest, catch-up and audit logic (stdlib Python 3.10+; macOS, Linux, Windows Git Bash) |
| `scripts/harness-db.py` (`find_session_scratch_dir`), `shared/hooks/intelligence-stop.py` | Find the full-id or legacy scratch dir for `events.jsonl` and the intelligence marker |
| `tests/harvest/test-ait-harvest.py` | Unit tests for G1–G6 (CI: linux, macOS, Windows) |
| `harvesting/` | Tracked staging directory and the harvest manifest (`/harvest` skill) |

When changing the harvest logic: change `scripts/ait-harvest.py`, keep the
shims thin, keep the never-delete and always-exit-0 guards, run
`tests/harvest/test-ait-harvest.py`, and update sections 5 and 6 of this
file in the same change.

## Cross-references

- Harvesting process and manifest: `/harvest` skill
- Scratch files: `/scratch` skill
- Framework registry: `/frameworks` skill
- Workspace layout (`.scratch/`, `harvesting/`, channel): `@.claude/rules/aitools-workspace.md`
- Logging: `@reference/logging.md`
- Hook rollout and lifecycle: `@.claude/rules/hook-rollout.md`, `@.claude/rules/hook-lifecycle.md`
- Datadog integration (planned KPIs): `@plans/datadog-log-integration.md`
- Archive design: `@plans/harvest-archive-resilience.md`
- Handoff naming incident: issue #138
