# S3-BuildPkg shared brief for delegates (rev 1, 2026-10-26)

Author: S3-BuildPkg (orchestrator, level 2 under Session Commander 10cf255a-c).
Every S3-BuildPkg delegate reads this file in full, after the mission packet
(`/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`)
and every file in the packet's section 1. Pass both paths, unchanged, to any
delegate you launch (the duty is recursive).

## Mission (parent)

Design and scaffold `build-package`: a PARALLEL, package-based distribution of
aitools producing (1) a Windows Intune Win32 app (.intunewin), (2) a macOS
unmanaged PKG usable by Intune (unmanaged PKG) and Jamf, (3) a Linux package
for Ubuntu 24.04 and 22.04, in containers (e.g. Claude Code web) and VMs.
The existing dev path (`scripts/aitools*`) and the existing `build-deploy.sh`
-> dotprofile `deploy/` (MDM path) stay working as they are.

## Commander decisions (2026-10-26, binding)

- New `build-package` tool; three package kinds above. Decide whether one
  Linux package covers both Ubuntu releases.
- Parallel distribution: keep what exists as is for now.
- Audience: a FLEET of users, not only Jose's machines.
- Supported platforms/environments, for now, limited to: macOS, Windows,
  Linux (Ubuntu), Claude Code web, Cursor cloud.
- Unsigned packages first; signing/notarization later and optional.
- Output in `/Users/new-jose/repos/aitools/plans/build-package/`, committed to
  main by the orchestrator only. Delegates do NOT commit, push, branch, or
  open PRs unless their prompt says so.
- Abort behaviour stays as PR #106 implements it (only an exit 2 from
  deploy-harness stops a run; another script's exit 2 is an ERROR row and the
  run continues). Dotprofile pushes from a non-main branch are an ERROR.
- MDM-PKG questions: Q1 answered = package (parallel strategy); Q2 = fleet;
  Q3 = Intune and Jamf; signing = unsigned first. Q4 (updates), Q5 (overwrite
  on recurring runs), Q6 (winget scope) are for this mission to resolve.

## Inputs (read-only)

- MDM-PKG report and notes:
  `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmPkg/`
  (`S3-MdmPkg-report.md`, `-Intune-notes.md`, `-Jamf-notes.md`,
  `-Build-notes.md`, `-Critic-review.md`).
- Session Commander's notes: 7 of 25 generated .ps1 are over Intune's 200 KB
  script limit; the library is inlined twice in setup-user-claude/-cursor/
  -settings (build-deploy.sh L436-437); aitools is a PUBLIC repo; deploy/
  lacks prerequisites (pwsh 7, node, Homebrew, config.json bootstrap keys);
  no script resolves the console user; the two dev-path order lists disagree
  (aitools-install.sh vs scripts/aitools) and neither runs deploy-harness on
  main (PR #106 adds it).
- Open PRs touching the same area (read with `gh pr view <n> -R
  nobul-tech/aitools` and `gh pr diff <n> -R nobul-tech/aitools`): #100, #103,
  #106, #110, #111, #112, #113, #115, #116 (others open: #97-#99, #101, #102,
  #104, #105, #108, #109, #114). Do not edit their files.
- FAN-PLAN mission (running) plans the setup-user-claude `~/.aitools/rules`
  fan-out; output appears in
  `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/`.
  Do not edit setup-user-claude.*.

## Critical rules restated

- Never run `aitools`, `aitools install`, `setup-user-*`, `deploy-harness` or
  `build-deploy.sh` against the real HOME. If you must run something, use an
  isolated HOME under your own scratch dir and a `git clone` of the dotprofile
  (`/Users/new-jose/repos/aitools-nobul-jose`, read-only), never the real one.
- Simple Bash only: no `&&`, `||`, `;`, `$(...)`, backticks, multi-line
  commands, globs in `rm`. `cat/head/tail/sed/awk` outside a pipeline are
  blocked; use Read (offset/limit) or `grep -n ... | ...`. Longer logic goes
  in a scratch script you then run with `bash <path>`.
- Read/Edit/Write for files. Perl, not sed, for string manipulation.
- Cross-platform .sh/.ps1 pairs (D-ENV0 one script per tool), bash 3.2
  compatible, script-standards block order, no silent failures.
- Never switch the main checkout's branch; never remove any worktree (the
  mdmpkg* worktrees belong to another mission).
- Firecrawl is deprecated: do not use Firecrawl tools. Official docs: the
  chrome-devtools skill (MCP tools `mcp__chrome-devtools__*`, load them with
  ToolSearch `select:` first). If chrome-devtools is unavailable, WebFetch is
  acceptable for research but say so per source.
- Cite a source for every factual claim (file:function or file:line, command
  output, URL + read date). Say "unknown" rather than guess.
- Subagents may lack Grep/Glob: use `grep`/`find` in Bash pipelines.
- `.ps1` files check out with CRLF: line-anchored patterns miss them.

## Operational learning (carry forward)

- Handoff `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md`
  section I, and packet section 5.
- Agent-tool delegates can delegate at levels 1-2 only; you are level 2
  (Session Commander = 0, S3-BuildPkg = 1). Your own delegates (level 3) have
  no Agent tool. Prefer doing the work yourself.
- The cross-platform environment value list is closed
  (`reference/cross-platform-detail.md` "API"): `claude-code-web` | `local`.
  Cursor cloud is now a supported environment by commander decision, so a new
  value needs a decision (flag it, propose one).

## Name prefix (D-DEL1)

Every *.md you create starts with your delegate name plus a hyphen, as given
in your prompt (`S3-BuildPkg-<Role>-`). Never start a name with REPORT,
SUMMARY, FINDINGS or ANALYSIS.

## WRITE_BLOCKED

If any write or tool call is denied, do not retry it in another form. Record
`WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your
response, and continue.

## Output location

`/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-BuildPkg/`
(tracked; your findings file goes here). Scratch:
`/Users/new-jose/repos/aitools/.scratch/session-<NAME>/` where <NAME> is 10
characters or fewer and given in your prompt. Nothing handed back lives in
scratch.

## Final response shape

Start with a 5-line summary, then: the file you wrote, key findings with
citations, `INCIDENT:` markers, open questions with suggested answers,
WRITE_BLOCKED lines (or "none").
