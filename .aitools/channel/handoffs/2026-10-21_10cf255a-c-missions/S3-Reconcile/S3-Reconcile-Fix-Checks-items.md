# S3-Reconcile-Fix-Checks items: check scripts, hooks, tests/CI, harvest/scratch

S3-Reconcile-Fix-Checks (level 3) for S3-Reconcile-Fix, 2026-10-26. Read-only on the
repo. Base: origin/main 60e7fd7, re-fetched at the end: 560de56 (#104 merged; it
adds one channel file only, `git diff --stat 60e7fd7 origin/main`). Every draft
anchor re-checked on 560de56: 0 problems (`.scratch/session-rcfixk/anchors-all.sh`).
Drafts: `S3-Reconcile-Fix-drafts/checks/edits-*.txt` (format and applier as in the
subbrief). Scratch: `/Users/new-jose/repos/aitools/.scratch/session-rcfixk/`.

## Summary (5 lines)

1. 14 markers checked: 12 OPEN with drafts or specs, 1 COVERED (R11, anchors still apply), 1 NOT A DEFICIENCY (old step-7 trigger on PR branches: moot once MERGE-ALL merges).
2. Reproduced on origin/main: #171 (catch-up harvested the live session's dir and deleted its pointer), #73 (6 bookkeeping/staging files harvested per dir), #184 (rc 141 above the pipe buffer), #185 (`accept & adopt` invisible to steps 30 and 31), #209 (5 later-line forms pass silently), step 20 (bare paths and `.pl/.ps1`).
3. 9 draft files, 38 OLD/NEW blocks. Every block applies to a mktemp export, and bash -n, the pwsh parser and py_compile pass. Patched tests: harvester fixture (original vs patched), hook 16/16 on bash 5 and on /bin/bash 3.2, step 30/31 regexes (bash and pwsh), check-path-refs probe plus full tree 0 dead, managed-files 57/57 with the patched lib.
4. The three un-CI'd suites pass locally on origin/main: deploy-harness 45/45, deploy-harness-mdm 30/30 (it needs a committed tree), rules-fanout-cursor 78/78 with 1 SKIP. CI steps drafted for macos and linux.
5. New: `printf | grep -q` under pipefail gives a false "no match" on large input (54 sites, probed). The #184 and #172 fixes touch lib, entry-point and hook files, so route by file owner. Protected text: hook-rollout.md only.

---

### L1 #171: catch-up looks a scratch dir up by a 10-char prefix, so a longer `session-<name>` is never harvested and the miss harvests the live session named in `.current-session`; live dirs of other sessions/delegates are harvested mid-flight
- Source marker(s): S3-ScratchRule-report.md:63 (SR-8); Ledger 4.2 L1 #171
- Status on origin/main 560de56: OPEN
- Evidence: `scripts/ait-harvest.py:94` `SCRATCH_PREFIX_LEN = 10`; `harvest_scratch` :773-786 (truncates `session_id[:10]`, falls back to `.current-session`); `_catchup_harvest` :1139-1146 passes `dir_prefix` (whole name) which harvest_scratch re-truncates; no liveness guard for scratch dirs (transcripts have one, :1093). Probe (`test-harvest.py`, fake repo, temp HOME, ONLY_LONG=1): original harvests the OWN live dir under the name `session-reconcile-_*`, writes `.harvested` into it, deletes `.current-session`, and leaves `session-reconcile-fix` unharvested (retried every start). Full fixture: original also harvests `session-live` (recent files).
- Severity: high
- Fix: `harvest_scratch(..., dir_name=)` takes the exact dir and never falls back to the pointer; catch-up passes `dir_name=sd.name` and skips dirs with a change in the last 30 min (`_scratch_dir_recent`, same LIVE_MTIME_SECONDS). Drafts `edits-harvest.txt` HV-3, HV-4, HV-6, HV-7, HV-8; docs `edits-scratch-docs.txt` SD-1, SD-5.
- Files: scripts/ait-harvest.py (code, no); shared/skills/scratch/SKILL.md (docs, no; Intent untouched)
- Gate: none (code). SD-1/SD-5 after R2/R3 if they edit the same lines (re-anchor).
- Verification: apply + py_compile OK. Patched: `session-reconcile-fix` harvested under its full name, own dir untouched, `session-live` skipped ("possibly-live"), pointer kept. Re-run `python3 .scratch/session-rcfixk/test-harvest.py <orig> <patched>` (and with ONLY_LONG=1).
- Decision needed: none

### L1 #172: `.scratch/.current-session` is one pointer per checkout, overwritten by every SessionStart and deleted by every harvest
- Source marker(s): S3-ScratchRule-report.md:64; -incidents.md:27 (SR-3)
- Status on origin/main 560de56: OPEN
- Evidence: `shared/hooks/scratch-init.sh:70` overwrites; `scripts/ait-harvest.py:876-880` unlinks it on EVERY harvest, including catch-up of an orphaned dir (probe: catch-up deleted the live session's pointer). Readers: `shared/hooks/{block-claude-code-guide.sh:19,block-explore-agent.sh:23,command-channel-stop.sh:167,delegation-duty-guard.sh:56,glossary-skill-guard.sh:11,sh-file-fixup.sh:21,standing-order-guard.sh:70}`, `shared/hooks/intelligence-stop.py:367`, `scripts/harness-db.py:501-502`, `scripts/ait-harvest.py:779`.
- Severity: high
- Fix: (a) drafted: delete the pointer only when it names the dir just harvested (HV-5; SD-4). (b) spec, not drafted (about 10 files): every reader derives its dir as `<git root>/.scratch/session-<session_id[:10]>` from its own stdin `session_id` (every hook payload carries it; scratch-init already names the dir that way, :61-63), and uses `.current-session` only when no session_id is present. Python readers (harness-db.py `find active session`, intelligence-stop.py) take the session id from their payload/argv. Test: two fake sessions A and B start in one checkout (B second); a hook event fired with A's session_id lands in `session-A/events.jsonl`.
- Files: scripts/ait-harvest.py (a); shared/hooks/*.sh x7, shared/hooks/intelligence-stop.py, scripts/harness-db.py, shared/hooks/scratch-init.sh (b) (code, no)
- Gate: none
- Verification: (a) probe above: pointer still present after catch-up. (b) the two-session test.
- Decision needed: (b) derive from stdin session_id? -- suggested: yes. It is deterministic and needs no new file. Keep the pointer for agents (the /scratch skill's step 2).

### L1 #173: a git worktree's `.scratch/` is never harvested, and `git worktree remove` deletes it without warning
- Source marker(s): S3-ScratchRule-report.md:68 (SR-4); handoff 2026-10-22 I
- Status on origin/main 560de56: OPEN (documented only: /scratch SKILL.md "Git worktrees")
- Evidence: `_catchup_harvest` sweeps only `git_root(cwd)/.scratch` (ait-harvest.py:1117-1123); `git grep -i worktree` in ait-harvest.py and shared/hooks finds only the dotprofile `worktree_dirty` helper.
- Severity: medium
- Fix (spec): in `catchup`, when `project_root` is the main worktree (`git rev-parse --git-dir` equals `--git-common-dir`), list `git worktree list --porcelain` roots and harvest each `<wt>/.scratch/session-*` (no `.harvested`, not recent) into the MAIN checkout's `harvesting/` with tag `session-<name>` plus a `wt-<worktree basename>_` prefix. That needs a `scratch_root` parameter on `harvest_scratch` (separate from the project_root used for harvesting/ and the manifest). Prevention: a new PreToolUse check (observe first, hook-rollout.md) that warns on `git worktree remove <path>` when `<path>/.scratch/session-*` holds a dir without `.harvested`. Test: fake repo + `git worktree add`, a delegate dir in the worktree, catch-up from the main checkout harvests it once.
- Files: scripts/ait-harvest.py; new check in shared/hooks/standing-order-guard.sh or a new hook + hooks-manifest.json (code, no)
- Gate: none
- Verification: the worktree fixture test; hook smoke tests per hook-rollout.md.
- Decision needed: harvest a worktree's scratch into the main checkout's harvesting/? -- suggested: yes. A worktree's own harvesting/ is lost on `git worktree remove` unless it was committed.

### #73 (update): the classifier harvests bookkeeping and staging files (msg-*.txt, PR bodies, `.harvested`, `.intelligence-last-check`, `events.jsonl`)
- Source marker(s): S3-ScratchRule-report.md:65 (SR-5); Ledger 4.3 #73
- Status on origin/main 560de56: OPEN
- Evidence: `_is_ephemeral` ait-harvest.py:716-736 (dot files and `.jsonl` fall to "unknown extension: harvest"; `.txt` is in ARTIFACT_EXTS). Live: untracked `harvesting/2026-10-23_session-f486b184-c_.intelligence-last-check` and `..._events.jsonl` in the main checkout (`git status --porcelain -- harvesting`). Probe: the original harvests 6 of 8 fixture files per dir (incl. `.intelligence-last-check`, `events.jsonl`, `msg-fix.txt`, `pr-body.md`).
- Severity: low
- Fix: dot files and `events.jsonl` are ephemeral; `.txt`/`.md` names starting `msg-`, `pr-body`, `issue-body`, `pr-comment` are ephemeral (HV-1, HV-2). Docs SD-2, SD-3 (the skill now says "msg-fix.txt is harvested"). Limit: free-form names (`issue72-comment-pr73.md`) still harvest.
- Files: scripts/ait-harvest.py (code); shared/skills/scratch/SKILL.md (docs) (protected: no)
- Gate: none
- Verification: patched run harvests only `notes.md` and `probe.sh` per dir ("2 harvested, 6 ephemeral skipped").
- Decision needed: none. #73 is already filed, so update it with this evidence when R13 L0 runs, or close it with this fix.

### L2 #184: `printf ... | head -N` under pipefail aborts with SIGPIPE on large input
- Source marker(s): S3-DiffUX-handback.md:45
- Status on origin/main 560de56: OPEN (reproduced)
- Evidence: probe `.scratch/session-rcfixk/probe-sigpipe.sh`, bash 5 and /bin/bash 3.2: 100 lines rc 0; 200000 lines rc 141 (both the `| while` and `x=$(... | head -1)` forms). Sites (`git grep`): `scripts/aitools-lib.sh:1456` (AI merge preview; `$merged` is a whole file: reachable above about 64 KB), `scripts/aitools:2022` (failed `git pull` output: small, but same pattern). Not reachable: `delegation-duty-guard.sh:151-152` (3 short lines), `setup-cursor-ide-mcp.sh:164` (short node output), `check-pre-push.sh:86` (in an argument, no `set -e` effect), `standing-order-guard.sh:294` (`$COMMAND` holds no real newline, so `head -1` reads to EOF).
- Severity: low
- Fix: here-string loop with a counter and `break` (no pipe). Drafts `edits-sigpipe.txt` SP-1 (lib, `local _pv_n=0 _pv_line`), SP-2 (aitools). No .ps1 twin (no SIGPIPE in PowerShell).
- Files: scripts/aitools-lib.sh, scripts/aitools (code, no). These are S3-Reconcile-Fix-Code's files: route to it or ship with its lib PR.
- Gate: none. #103/#106/#112/#113/#115/#116 edit these files, but both OLD anchors are unique on every one of those branches (`old-on-branches.pl`).
- Verification: apply + bash -n OK; `probe-preview.sh` (the loop under set -euo pipefail, /bin/bash 3.2, 200000 lines) completes; tests/managed-files 57/57 with the patched lib (incl. "merge & adopt", which shows the preview).
- Decision needed: none

### L2 #185: check-post-push step 30 extracts return values with `\w[\w-]*`, so it never checks `accept & adopt` (step 31 has the same gap)
- Source marker(s): S3-SourceTruth-report.md:59
- Status on origin/main 560de56: OPEN
- Evidence: `scripts/check-post-push.sh:766` (`\w[\w-]*`), :779 `for val in $(echo ... | tr ',' ' ')` would also split the value into "accept", "&", "adopt"; step 31 :799-803 and `.ps1` :904, :937-945 use `[\w-]+` on both libs, so bash and PS1 miss the value symmetrically and the sync check passes vacuously. Probe (`test-postpush-regex.sh`): old extraction `created,failed,skipped,updated,verified` (no accept & adopt) for returns, results and tracker on both platforms.
- Severity: low
- Fix: `[^"]+` for values, a quoted-alternative pattern for bash case labels, and a line-wise loop with `grep -qF --`. PS1: an unreadable caller becomes a finding, not a silent `continue` (error-handling rule). Drafts `edits-postpush.txt` PP-1..PP-8.
- Files: scripts/check-post-push.sh, scripts/check-post-push.ps1 (code, no)
- Gate: none (no open PR touches either file). FAN-PLAN Batch A adds a tracker `removed` outcome and a default branch: the new patterns pick up `removed`, and a `*)` label matches neither.
- Verification: new extraction `accept & adopt,created,failed,skipped,updated,verified` (results; tracker adds `added,preserved`), bash = PS1 in both. Negative test: a caller without the string reports `missing accept & adopt`. pwsh run of the PS1 perl calls (`test-postpush-ps1.ps1`): equal=True. bash -n and the pwsh parser pass. The full check-post-push was not run (real HOME rule).
- Decision needed: none

### L2 #190: two backup copies (`*.sh.bak.2026-06-21T*`) are tracked in shared/hooks
- Source marker(s): S3-Reconcile-Ledger-findings.md:243 (its own INCIDENT)
- Status on origin/main 560de56: OPEN
- Evidence: `git ls-tree -r origin/main` lists `shared/hooks/harness-db-sessionstart.sh.bak.2026-06-21T203304Z`, `shared/hooks/standing-order-guard.sh.bak.2026-06-21T203334Z`. `.gitignore` has `*.bak` (line under "# Temporary files") but no `*.bak.*`, so the library's `<file>.bak.<UTC>` form is not ignored.
- Severity: low
- Fix: `git rm` the two files (two separate commands, no glob) and add `*.bak.*` to .gitignore (draft `edits-bak.txt` BAK-1).
- Files: .gitignore, the two files (code, no)
- Gate: none
- Verification: with the patched .gitignore, `git ls-files -ci --exclude-standard` in an export lists exactly those two files, and nothing else tracked becomes ignored. After the commit, `git ls-tree -r HEAD | grep -c '\.bak\.'` returns 0.
- Decision needed: none

### L4 #209: standing-order-guard checks only the first token, so later lines of a 2-3 line command are not checked
- Source marker(s): S3-HooksFix-report.md:71
- Status on origin/main 560de56: OPEN (reproduced)
- Evidence: `shared/hooks/standing-order-guard.sh` `read -r FIRST_TOKEN _ <<< "$COMMAND"` and the first-token allowlist exits 0 for git/perl/etc. before the rm/cat/sed/awk checks. `$COMMAND` holds JSON-escaped `\n`, so lines 2-3 are never tokenized. Baseline smoke (`test-sog.sh`, original hook): `ls\nsed -i s/a/b/ f`, `git status\nrm -f *.tmp`, `ls -la\nawk 1 f`, `ls\nprintf x > f`, `ls\nls\nsed s/a/b/ f` all exit 0 with no log (5 FAIL vs the intended behaviour).
- Severity: low
- Fix: lines 2-3 get the same first-token checks via `check_later_line`. This widens what is matched, so hook-rollout.md applies: a new `MODE_LATER="observe"` whose `later_violation` logs `(later line)` WOULD-BLOCK entries and continues, so it never exits before line 1 is checked. Line 1 and every existing check are unchanged. Drafts `edits-sog.txt` SOG-1..SOG-3; protected doc row `edits-sog-docs.txt` SOGD-1 (hook-rollout.md state table).
- Files: shared/hooks/standing-order-guard.sh (code, no); .claude/rules/hook-rollout.md (docs, protected: YES)
- Gate: commander approval for SOGD-1 (protected). Promote MODE_LATER to enforce after a week of logs without false positives (hook-rollout.md).
- Verification: patched hook 16/16 on bash 5 and on /bin/bash 3.2: git status 0; `&&` 2; line-1 cat 2; line-1 `sed -n` in a two-line command 2; echo redirect 2; the 5 later-line forms 0 + log; later `cat | grep` 0, no log; two plain lines 0, no log; 4 lines 2 (scratch). The enforce copy blocks later `sed -i` and later `rm *.tmp` after `git` (2) and allows a later pipeline (0).
- Decision needed: none (observe is the rule). Known imprecision: a JSON `\\n` (literal backslash-n in the command) splits a line in the new check as it already does in the existing line count, and only in observe.

### F6 / FAN-PLAN Checks I-2: tests/deploy-harness, tests/deploy-harness-mdm, tests/rules-fanout-cursor are on main but not in CI
- Source marker(s): S3-FanPlan-Checks-findings.md:241, :333 (I-2); plans/rules-fanout-claude.md F6
- Status on origin/main 560de56: OPEN (all three suites exist, none is in `.github/workflows/check.yml`; no open PR adds them: `pr-ci-grep.sh`)
- Evidence: `git ls-tree origin/main tests` lists them. Local runs on a committed origin/main export outside the repo, isolated HOME: deploy-harness 45/45 (bash 5 and /bin/bash 3.2); deploy-harness-mdm 30/30 (on an uncommitted export it fails 2 "conflict" cases: the build reads sources with `git ls-files`, see INCIDENT below); rules-fanout-cursor 78/78 + 1 SKIP (`dupcase`: case-insensitive FS; runs on Linux). The MDM suite leaves the export's tree clean (`git status --porcelain` empty), so the later deploy-drift step is not affected.
- Severity: medium
- Fix: three bash steps in the macos and linux jobs after "User init tests" (`edits-ci.txt` CI-1, CI-2). Windows stays with F4. No /bin/bash 3.2 variant: these tests run `bash` from PATH and do not honour `AITOOLS_TEST_BASH`, so a 3.2 step would test only the harness.
- Files: .github/workflows/check.yml (code, no)
- Gate: re-anchor after MERGE-ALL merges #112 and #116 (they insert at the same anchor; the OLD text is still unique on #103/#112/#113/#115/#116 heads)
- Verification: apply OK; ruby YAML parse: macos 22 -> 25 steps, linux 15 -> 18, windows 12 unchanged. First CI run on the PR is the real test (pty cases need python3, MDM needs node/perl/git: all on the runners).
- Decision needed: none. Follow-up: make the three suites honour `AITOOLS_TEST_BASH` (as tests/profile does) for a real 3.2 run.

### Plan 8 / Barrier B8: pre-commit step 20 does not catch a repo path cited bare in parentheses
- Source marker(s): plans/fan-plan-reconciliation.md:425; S3-Reconcile-Barrier-results.md:111, :223
- Status on origin/main 560de56: OPEN (reproduced)
- Evidence: `scripts/check-path-refs.py` scans Markdown only for backticked spans and `@path` tokens (`scan`: `BACKTICK.findall + AT_PATH.findall`). Probe (`probe-pathrefs.sh`): `(see plans/missing-bare.md)` passes, `` `plans/missing-tick.md` `` is flagged.
- Severity: low
- Fix: add `BARE_PATH` (a top-level repo dir, a file extension, not preceded by a path/word char, so `~/.claude/...`, URLs and `<userRepoPath>/...` are skipped) to the Markdown scan. On main that finds 4 placeholders/examples, each given an allowlist entry. Drafts `edits-pathrefs.txt` CHK-P1a..P1d.
- Files: scripts/check-path-refs.py, scripts/check-path-refs-allow.txt (code, no). One script serves pre-commit .sh and .ps1, so there is no twin.
- Gate: none
- Verification: probe: bare missing path flagged, bare existing path, `~/` path and URL not flagged; full origin/main tree: 0 dead (4 before the allowlist entries: incident-governance.md:60, frameworks SKILL.md:104, smoke-test-pattern-detail.md:13, path-targeted-hooks-analysis.md:84). On all 16 open PR branches the patched checker finds only those same 4, which the allowlist clears after rebase. docs/m3-lead-plan already fails its own checker (9; stale base).
- Decision needed: widen step 20 (future prose citing a planned file bare will fail)? -- suggested: yes. Use a `path-ref: ignore` marker or an allowlist entry, as for backticks.

### Ledger 4.4: check-path-refs reads `scripts/aitools-json.pl/.ps1` as one path
- Source marker(s): S3-H2-DraftsH-handback.md:116 (author: unverified)
- Status on origin/main 560de56: OPEN. Worked around by allowlist entries `scripts/check-path-refs-allow.txt:34-35`.
- Evidence: `exists()` special-cases only `.sh/.ps1`. Probe: `` `scripts/aitools-json.pl/.ps1` `` flagged although both files exist.
- Severity: low
- Fix: generic `<stem>.<ext1>/.<ext2>` pair (`PAIR` regex), and drop the two allowlist lines and their header (CHK-P2a..P2c).
- Files: scripts/check-path-refs.py, scripts/check-path-refs-allow.txt (code, no)
- Gate: none
- Verification: probe: `.pl/.ps1` and `.sh/.ps1` pairs pass, `scripts/nope.sh/.ps1` (bare, missing) is flagged; full tree 0 dead after removing the allowlist lines.
- Decision needed: none

### Plan 8: every open PR branch carries the old step-7 trigger in its own check-pre-push
- Source marker(s): plans/fan-plan-reconciliation.md:423
- Status on origin/main 560de56: NOT A DEFICIENCY (transient; moot after MERGE-ALL)
- Evidence: `step7-branches.sh`: all 16 open branches lack 8e490d7 and differ from main in check-pre-push.sh/.ps1, but none of them changes either file itself (`merge-base..branch` diff empty). A merge commit therefore keeps main's step 7, with no conflict. The only effect: running a branch's own `scripts/check-pre-push.sh` before it merges main gives the old trigger.
- Severity: low
- Fix: none in code. Operational line for MERGE-ALL / executors: merge `origin/main` into a branch before running its pre-push checks (MERGE-ALL does this for CI anyway).
- Files: none
- Gate: none
- Verification: after MERGE-ALL, `gh pr list --state open` is empty or the remaining branches have merged main (`git merge-base --is-ancestor 8e490d7 origin/<b>`).
- Decision needed: none

### Plan 8: pre-push step 7 FAILs every branch that changes a deploy/ input
- Source marker(s): plans/fan-plan-reconciliation.md:408
- Status on origin/main 560de56: COVERED (R11)
- Evidence: `scripts/check-pre-push.sh:165` sets `d7_problems` "dotprofile deploy/ is stale" and :221 `step_fail "7"`. The committed dotprofile deploy/ is built from main, so a branch that changes an input differs. The R11 drafts `S3-Reconcile-Code-drafts/edits-step7.txt` E13a-c/E14a-c still anchor exactly once on 560de56, but only after rewriting their `@@@FILE main/` prefix to `scripts/` (that file uses an export-relative prefix, not repo-relative paths).
- Severity: medium
- Fix: R11 as planned
- Files: scripts/check-pre-push.sh/.ps1, reference/pre-push-checklist.md
- Gate: R11's gates (Q5; MERGE-ALL rebuild)
- Verification: `old-on-branches.pl` on the rewritten copy `.scratch/session-rcfixk/edits-step7-scripts.txt`: 0 anchor problems.
- Decision needed: none. Note for the applier: use `perl -pe 's{^\@\@\@FILE main/}{\@\@\@FILE scripts/}'`, or an export whose base dir holds `main/`.

### Plan 8 / Barrier B13: a full-tree export under the repo's `.scratch/` is loaded as project context and is harvester input
- Source marker(s): plans/fan-plan-reconciliation.md:426; S3-Reconcile-Barrier-results.md:234
- Status on origin/main 560de56: OPEN (docs) / NOT A DEFICIENCY (harvester half)
- Evidence: the harvester takes only TOP-LEVEL files of a session dir (`harvest_scratch` ait-harvest.py:800 `p for p in session_dir.iterdir() if p.is_file()`), and the skill already says "Files in subdirectories of the session dir are never harvested". So an export in `session-x/tree/` is not harvested. The context-loading half is the barrier delegate's observation (not re-tested here). No doc tells agents where to put exports.
- Severity: low
- Fix (decision taken: docs, no harvester skip): /scratch SKILL.md paragraph: never export a whole tree into `.scratch/`; use a `mktemp -d` dir outside the repo and `git show <ref>:<path>` (SD-6).
- Files: shared/skills/scratch/SKILL.md (docs, no)
- Gate: none (re-anchor if R2/R3 change the "Complex script pattern" end)
- Verification: apply OK. `grep -c "Never export a whole repo tree" shared/skills/scratch/SKILL.md` = 1.
- Decision needed: none. Cleanup: `/Users/new-jose/repos/aitools/.scratch/session-rcbar/tree` still exists (barrier export). S3-Reconcile removes it with a cleanup script (not a glob `rm`).

### Work item 6: .ps1 twins of the check scripts touched
- check-post-push.ps1: drafted (PP-5..PP-8), pwsh parser OK, perl calls run from pwsh.
- check-path-refs.py: one Python script for pre-commit .sh and .ps1 (its docstring), so no twin.
- ait-harvest.py: one Python helper, the hooks are shims, so no twin. standing-order-guard.sh: hooks are bash on all platforms (cross-platform.md "Hook portability"), so no twin.
- aitools-lib.ps1 / aitools.ps1 (#184): no SIGPIPE in PowerShell; no change.

---

## Draft files

| File | Blocks | Items | Apply on 560de56 | Checks run |
|---|---|---|---|---|
| checks/edits-harvest.txt | HV-1..HV-8 | #171, #172(a), #73 | ok | py_compile; test-harvest.py orig vs patched |
| checks/edits-scratch-docs.txt | SD-1..SD-6 | #171, #172, #73, B13 | ok | apply only (docs) |
| checks/edits-sigpipe.txt | SP-1, SP-2 | #184 | ok | bash -n; probe-preview.sh; managed-files 57/57 |
| checks/edits-postpush.txt | PP-1..PP-8 | #185 | ok | bash -n; pwsh parser; regex tests bash + pwsh |
| checks/edits-bak.txt | BAK-1 (+ 2 `git rm`) | #190 | ok | ls-files -ci |
| checks/edits-sog.txt | SOG-1..SOG-3 | #209 | ok | bash -n; 16/16 bash 5 and 3.2 |
| checks/edits-sog-docs.txt | SOGD-1 | #209 (PROTECTED) | ok | apply only |
| checks/edits-ci.txt | CI-1, CI-2 | F6 / I-2 | ok | YAML parse (ruby) |
| checks/edits-pathrefs.txt | CHK-P1a..d, CHK-P2a..c | step 20 bare, pair | ok | probe; full tree 0; 16 PR branches |

Error-handling audit of the drafts (plan-execution-detail.md rules): no new
`2>/dev/null` or `|| true`. HV-5 replaces a bare `except OSError: pass` with a
logged `log_detail`, and its read failure sets `pointed = ""`, which is checked
on the next line. `_scratch_dir_recent` logs and returns the conservative True.
PP-6 turns a silent `continue` into a finding. `later_violation` writes the log
the same way the existing `violation()` does.

## Not verified

- Windows: nothing ran natively (no PS1 suites, no Git Bash hook run).
- Linux/CI: the new check.yml steps have not run on a runner, and the rules-fanout-cursor `dupcase` case is untested here (case-insensitive macOS FS).
- check-post-push.sh/.ps1 end to end (not run against any HOME; the step 30/31 logic was tested in isolation).
- The hook inside a live Claude Code session (piped JSON only), and whether CC payloads ever carry real newlines in `tool_input.command`.
- That Claude Code loads a nested export's CLAUDE.md (B13): taken from the barrier delegate's observation.
- #172(b) and #173: specs only, nothing coded.

## INCIDENT markers (new; become FX items upstream)

- INCIDENT (medium): `printf/echo "$var" | grep -q pat` under `set -o pipefail` returns "no match" when `$var` exceeds the pipe buffer and the match comes early (grep exits, printf gets SIGPIPE, the pipeline is 141). Probe `.scratch/session-rcfixk/probe-grepq.sh`: 20000 lines -> "NO MATCH (rc 141 0)"; here-string `grep -q pat <<< "$var"` -> match. 54 sites in scripts/ and shared/hooks (`git grep -c`), e.g. `scripts/check-pre-push.sh:188, :191` (step 7 smoke: "resolver missing" / "Profile source: live" detection on a full dry-run output). Fix: here-strings; audit the 54 sites by input size.
- INCIDENT (low): `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` needs the aitools tree to be a committed git checkout (the build embeds `git ls-files`). On an uncommitted export it fails the 2 "conflict" cases with no hint. Its header says only "the sources are this repo (read only)". Fix: a precondition check (`git -C "$ROOT" ls-files | head` non-empty, else SKIP with a reason) or a header line.
- INCIDENT (low): `S3-Reconcile-Code-drafts/edits-step7.txt` names files `main/check-pre-push.sh(.ps1)`, not repo-relative paths, unlike the subbrief's format ("paths are repo-relative"). An applier run with the repo export as BASEDIR fails "cannot copy". Fix: rewrite the prefix before R11 applies it.
- INCIDENT (low, observation): the deployed standing-order-guard blocks a read-only multi-range print `sed -n '1,20p;135,160p' <file>` with the `;` check (seen in this run). The #82 exemption covers single ranges only. Leave as is or extend the exemption (narrowing: keeps enforce).
- INCIDENT (low): `.github/workflows/check.yml` also has no step for `tests/build-package/test-cli.sh` (on main). BUILD-PKG's to decide. Not drafted here.

## Open questions (each with a suggested answer)

1. #172(b): readers derive the session dir from their own stdin `session_id` instead of the shared pointer? -- Suggested: yes. Keep `.current-session` as the agents' hint only.
2. #173: harvest worktree scratch dirs into the main checkout's `harvesting/`, plus an observe-mode warning on `git worktree remove`? -- Suggested: yes to both.
3. #73: treat `msg-*`, `pr-body*`, `issue-body*` and `pr-comment*` (.txt/.md) as ephemeral? This reverses the /scratch skill's "msg-fix.txt is harvested". -- Suggested: yes. They are consumed by one command; SD-2/SD-3 update the skill.
4. Step 20 widening (bare paths) may fail future prose that cites planned files. -- Suggested: accept it; use the allowlist or the `path-ref: ignore` marker.
5. Ownership: SP-1/SP-2 (#184) and #172(b) touch lib/entry-point/hook files that S3-Reconcile-Fix-Code owns. -- Suggested: S3-Reconcile-Fix routes SP-1/SP-2 into Fix-Code's lib PR and keeps the hook/harvester items in one "harvest + hooks" PR.
6. CI 3.2 coverage for the three suites? -- Suggested: not now (they do not honour `AITOOLS_TEST_BASH`); file as a follow-up with F4.

## Provenance

Scratch scripts (all in `/Users/new-jose/repos/aitools/.scratch/session-rcfixk/`):
run-uncid.sh, run-mdm.sh (+ logs test-*.log, mdm-committed.log), probe-sigpipe.sh,
probe-grepq.sh, probe-preview.sh, probe-pathrefs.sh, test-pathrefs.sh,
pathrefs-branches.sh, pr-ci-grep.sh, pr-touch.sh, step7-branches.sh,
old-on-branches.pl, anchors-all.sh, apply-and-test.sh, test-harvest.py, test-sog.sh,
test-postpush-regex.sh, test-postpush-ps1.ps1, run-mf-patched.sh (+ mf-patched.log),
yaml-steps.rb, edits-step7-scripts.txt. Exports and test HOMEs: `mktemp -d` dirs
under /var/folders/... (outside the repo). No repo file other than this file and
the drafts folder was written. No commits, pushes or PRs. No sub-delegates.
