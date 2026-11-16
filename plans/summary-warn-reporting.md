# Summary panel and logging: each warning and error once, every error with its reason

Version 4.5 (2026-11-15). Earlier versions the same day: v1.0, v2.0, v2.1,
v3.0, v3.1, v3.2, v4.0, v4.1, v4.2, v4.3, v4.4.
- v4.4 applies prompt 8: the broader Go fix (Appendix B.6).
- v4.5 applies the assumption review (prompt 9) and the commander's answers
  to it (prompt 10). Appendix D shows how each assumption shaped this
  version.
- v4.1 is v4.0 revised by three independent verifier runs (Appendix B.3).
- v4.2 is v4.1 revised by two fresh verifier runs (Appendix B.4).
- v4.3 applies the commander's prompt 7 answers (Appendix B.5).

Owner: Session Commander a9074793-c.
- The plan runs from start to finish without the commander. It stops only
  where the surfacing duty requires (section 0).
- It ships as one PR from `fix/summary-warn-reporting`, and the PR includes
  this plan.

**Intent**: **Purpose**:
1. The end-of-run panel lists every warning and every error of a run once,
   and a tool's row is never recoloured.
2. Every error line states what failed and why.
3. The bash and PowerShell setup, entry-point, install and build scripts
   write their log entries through the `aitools-lib` helpers, with OS guards
   and environment conditionals as `.claude/rules/cross-platform.md`
   requires.
4. `reference/logging.md` specifies all of this, including a formal,
   generalized template for the run summary file and the panel.
5. Two bugs are filed as GitHub issues and fixed.
6. A unified-logging roadmap item is analysed and filed as a GitHub issue.

**Scope**:
- the spec (`reference/logging.md`) and the documents in section 6;
- `scripts/aitools-lib.sh` / `.ps1`;
- the bash and PowerShell scripts in section 11's groups;
- the compliance checks, tests, golden files and CI steps;
- three GitHub issues (section 4).

**NOT in scope: implementing unified logging.** Prompt 6 ordered: "suggesting
a roadmap item as a gh issue for unified logging across python, shell, ps1,
perl, hooks, install, deploy scripts. it should suggest specs. the
implementation of this is out of scope for the plan, make sure that is clear".
Prompt 5 ordered: "build-deploy.sh and all other scripts should be using the
helpers to write their log entries ... ensuring that they all use the
aitools-lib* functions". This plan reconciles the two:
- It moves the bash and PowerShell scripts that can load `aitools-lib` onto
  its helpers: setup scripts, entry points, the installers and
  `build-deploy.sh` (prompt 5).
- It does not implement a unified logging design across languages. It does not
  change hooks, Python tools, Perl helpers, the shell aliases, the check
  library's `checks.log` vocabulary, the package launchers under
  `packaging/` (stubs today), or the few bash and PowerShell files that
  cannot load the library. These are analysed and filed as the roadmap issue
  (A7; prompt 6).

Also NOT in scope: the causes of the machine's other warnings (registration,
the logins).

**Audience**: the agent that executes it and its delegates, and the commander
(review-after).

## 0. How to execute this plan

- **Phases.** Run the five phases in order (sections 8-12). Inside a phase,
  run the steps marked parallel at the same time.
- **Stated deviations from strict phase order.** Each is a step moved to an
  earlier phase because a later step depends on it (Appendix C; prompt-turn
  item 4.9). The rest of each phase keeps the commander's order.
  1. **The draft PR opens in Phase 1**, not Phase 5. Windows CI runs only on a
     PR, and it is the only place the `.ps1` suites run. A7 needs the PR number
     to cite. Phase 5 still ships it: it fills in the body and marks it ready.
  2. **The three GitHub issues are filed in Phase 2** (A5, A7), not Phase 4.
     I0's commits and S1's text cite their numbers.
  3. **S1 starts once A1 is done**, with two placeholders (the roadmap issue
     number, the A2 marker additions) that S1b fills in. A2-A8 finish
     alongside it.
  4. **Phase 4's first steps start once S1 is committed**, while S2's
     documentation delegates finish.
- **No approval gates.** Stop only for the surfacing duty (prompt-turn
  checklist item 5): a question only the commander can answer, which blocks
  the work. Raise it as a session RFI and carry on with everything it does not
  block. The questions open at this version (section 14) each have a default:
  use the default unless the commander has answered otherwise.
- **Delegation: delegate as much as possible** (prompt 10).
  - The plan assumes that one session can run it from start to finish
    (prompt 10).
  - The lead orchestrates, and keeps its own context for that. Only these steps
    are the lead's:
    - Phase 1 (orientation, branch, draft PR);
    - writing each delegation prompt;
    - reviewing each delegate's result (its diff, its report, a spot check of
      its claims);
    - merging, pushing, and editing the PR.
  - Every other step, reading and writing alike, goes to a delegate:
    inventories, design maps, the spec text, documents, code, tests, golden
    files and issue bodies. Independent steps are delegated in parallel.
  - When a step is too large for one delegate, split it into delegates of
    about 2-3 files each.
  - Load `/delegate` before every delegate; each delegation prompt carries
    every element `/delegate` requires.
  - Every Phase 3 and Phase 4 delegation prompt states, as a D-DEL6
    resolution citing prompts 4-6, which spec governs, by absolute worktree
    path:
    - the branch's `reference/logging.md` section 8;
    - once D1 is merged, also the branch's script standards. Delegates
      launched before that are told that section 8 governs alone.

    A delegate loads the main checkout's older rules, which say "always pair
    ACTION with a log_warn carrying the same instruction" and "Every
    `log_error` / `LogError` for a file write failure MUST be paired with
    `write_summary ERROR`" (`reference/script-standards-detail.md`). The
    prompt names those as superseded.
  - Parallel delegates that write code each work in their own worktree, on a
    branch created from `fix/summary-warn-reporting` (`git worktree add -b
    <group branch> <path> fix/summary-warn-reporting`), with a file set no
    other delegate touches. The prompt gives the command and the path; do not
    rely on a tool's default base branch.
  - Delegates commit on their own branch; the lead merges each one. Each
    delegate returns its PR-body material: every changed summary and golden
    line (old -> new, with the reason), and its level changes.
  - Group branches get no CI, because CI runs only on pull requests to `main`
    and pushes to `main` (`.github/workflows/check.yml`). The lead pushes after
    each merge, so Windows CI checks every group's `.ps1` changes.
  - Delegates open no PRs: the commander ordered one PR ("ship everything as a
    pr"), which takes precedence over D-DEL4 under D-DEL6.
- **Work rules.**
  - Batches of about 2-3 files, with that batch's suites run before the next
    batch.
  - Versions, not drafts (D-DEL5).
  - Run `build-deploy.sh`, setup scripts and `aitools` only under an isolated
    `HOME`. Where they would call package managers or tool CLIs, `PATH` holds
    only stub commands plus `/usr/bin:/bin`, so nothing on the real machine is
    installed or upgraded.
  - Temporary files go in the session scratch directory (`/scratch`).

## 1. The commander's words (verbatim)

Prompt 1 (2026-11-15), with the panel the commander pasted:

> i think there is a bug with our logging/error/warning/ok/verified reporting.  node.js, claude code, and some of the managed claude artifacts show as yellow warning in the summary but i dont see a reason why? also if they are yellow, the summary should state what went wrong, and instead it's just the name and version of the script/tool take a look.  find the rca using /investigate but dont change any code yet

```
[2026-11-15T19:19:00Z] [aitools] [ok] All up to date (0.74.0+648)

────────────────────────────────────────────────────────
  [ok]  gh cli           gh version 2.104.0 (2026-11-12)
  [ok]  aitools config   verified
  [ok]  shell            managed block unchanged
  [ok]  config.json      n/a (written by installer)
  [ok]  harness files    114 verified
  [ok]  pandoc           pandoc 3.14
  [ok]  rust/cargo       cargo 1.100.0 (3acc79c0c 2026-11-05)
  [ok]  typst            typst 0.15.1 (unknown commit)
  [ok]  uv               uv 0.13.8 (Homebrew 2026-11-12 aarch64-apple-darwin)
  [ok]  python           Python 3.14.10 (uv)
  [ok]  pywinpty         n/a (macos)
  [ok]  go               go version go1.27.4 darwin/arm64
  [ok]  perl             5.034001
  [ok]  bash             5.3.15
  [ok]  google chrome    n/a (local)
  [ok]  cursor cli       verified
  [ok]  cursor rules     7 verified
  [ok]  cursor skills    22 verified
  [ok]  claude mcp       verified
  [ok]  skills           n/a (fanned out)
  [ok]  cursor ide mcp   verified
  [ok]  claude settings  verified
  [ok]  claude hooks     21 verified
  [!]   node.js          v26.3.1
  [!]   claude code      2.1.325 (Claude Code)
  [!]   vercel cli       not authenticated
  [!]   modal cli        not authenticated
  [!]   datadog cli      not authenticated
  [!]   claude.md        skipped (user review)
  [!]   claude rules     7 verified
  [!]   claude skills    22 verified

  ACTION REQUIRED -- run before tools are ready:
  >>  Run: aitools user init (registers this machine)
  >>  vercel login -- authenticate vercel CLI
  >>  modal setup -- authenticate modal (browser flow)
  >>  Add /Users/new-jose/go/bin to PATH -- go install binaries
  >>  pup auth login -- authenticate Datadog CLI
────────────────────────────────────────────────────────
Mac:aitools-nobul-jose new-jose$ 
```

Prompt 2: "put all of scripts/aitools-lib* into context".

Prompt 3:

> provide a new thorough proposed plan of action to remediate the issues i raised at the start of this session

Prompt 4:

> 3) warnings should be batched written after ok/verfied and before purple action needed.  there should be no distinction between child and parents? what am i missing.  if a tool/script produces a warning during its run, its warning should be batched together with other warnings in the summary.  what am i missing? can we implement this? what in our documentation needs to change? 4) yes 5) think about this more thoroughly.  document state changes in how we track warnings/errors across tools and scripts propose modifications to reference/logging.md before implementing 6) yes, but dont do anything yet, revise the plan first to include all feedback in this prompt.  present new plan first 7) wait.  produce a new version of the plan, then verify the new version of the plan line by line against this entire session from start to now line by line verbatim and revise if necessary

Prompt 5:

> The panel is repeating warnings twice? we can get rid of item 3 from it right? it is already covered by item 2.  the yelllow WARN rows ARE the warnings block. build-deploy.sh and all other scripts should be using the helpers to write their log entries, they should not be writing logs directly.  this is a bug.  expand the scope of the plan to include auditing scripts for this and ensuring that they all use the aitools-lib* functions with proper OS guards/conditionals depending on environment/operating system.  put all of script-standards.md into context.  have the plan also document our logging logic and state machine as necessary and/or point to logging.md for what we are defining here as the spec.  dont put approval gates in the plan, the plan should execute from start to finish ideally without my involvement unless surfacing duty prevents it. put all of aitools.md into context if it's not already in context. for the expected panel for your run, the warnings block and yellow would be collapased into one per this prompt.  please re-state this to ensure you understand the format i want. for open rfis: 1) no 7) no 3) 8)yes 9) approved 10) include filing gh issues as part of the plan, dont do it yet, they are part of the scope and will be in the next revisioin of the plan 11) yes, use a write_action helper function, but im not too worried about advice appearing twice.  the warning should be descriptive of what needs to be done, so if its a login, it should log that.  12) yes, explain further what you mean by no-reason problem? 13) yes.  Please revise the plan and create a new version that incorporates this prompt with answers to all of your questions and new feedback, then follow the same verify procedure as the last prompt to check the plan against the session line by line verbatim including this iprompt and whatever may follow.  Lastly, do a 3rd check on the plan, look at the order of execution, see if anything can be parallized, what can be moved to the beginning vs the end.  the plan should first) instruct the agent to orient itself in a targeted way for the plan second) understand what it needs to do to achieve the objectives asked third) focus on the spec and documentation of the plan fourth) focus on implementatino of the spec and execution of the mission objectives fifth) ship everything as a pr.  ask any open questions

Prompt 6:

> can we change the spec to capture the reason for errors? is this technically feasible? re-read everything you have in context line by line verbatim before you answer, then the plan, and think about what in the plan would change.  if the answer is yes, then write a new version of the revised plan with this in mind.  for open rfis: 13) the hooks should use it, but the plan should include filing this as a GH issue on the repo, it should not include impleenting it 15) file this as part of the same issue for 14, we need unified logging, have the plan include analyzing the codebase and suggesting a roadmap item as a gh issue for unified logging across python, shell, ps1, perl, hooks, install, deploy scripts.  it should suggest specs.  the implementation of this is out of scope for the plan, make sure that is clear 16) ignore 17) ignore 18) no 19) yes, this should be documented in the logging.md file, with formal structure, it should not reference any session or run, it should be a generalized template.  please revise the plan to include this if its not already there.  Apply the same rigourus review process to the plan and your prompt turn on this turn as you did in the last, with several verifier runs.  produce a new version of the plan

Prompt 7 (answers to the v4.2 questions):

> 20) yes 23) yellow and red only 24) logging-only edits are exempt, run check for two bug fixes.  re-state the bug fixes 25) i like this idea, they should be demoted to info unless you think the scope creep is too much 26) dont worry about it

Prompt 8 (answer to RFI 5899-27):

> 27) the broader fix for this plan/pr

Prompt 9:

> read everything in context verbatim line by line and extract any and all assumptions that you made when formulating the plan.  resolve ambiguities on your own if you can, surface what you cant as RFIs.  only surface assumptions that would change the content of the plan.  defer any modifications to the plan on this turn to later turns

Prompt 10 (answers to the assumption review and RFI 5899-28):

> for assumption 5, check the latest PRs/commits for correct version or have the executing agent do it.  75 is not correct assumption 9, lets assume a single session can, the lan should instruct the executing agent to delegate as much as possible.  rfi 28) lets just fix the block always adds bug, dont file zsh issue, we dont manage zsh so just leave as is.  produce new refined version of plan with this feedback, new answers, and how your assumptions inform the new version

## 2. Objectives and acceptance criteria

| ID | Objective | Accepted when |
|---|---|---|
| O1 | The panel has the format in 2.1 | The end-to-end run (I8) shows, structurally: green for exactly the tools with no warning or error (`go` included); one yellow line per warning, in log order; a red line shaped `<name> <what>: <reason>` for the forced failure; the four ACTION lines of 2.2; no duplicate line |
| O2 | Every warning and every error is recorded once, where it is logged, by whichever script logs it; parent and child scripts are treated the same | Tests L1-L12 pass in bash and PowerShell |
| O3 | No row is ever recoloured | Step 13; test L1 |
| O4 | The bash and PowerShell scripts in scope write their log entries through the `aitools-lib` helpers and write no log or summary file directly | The new compliance step (I2) passes; its exceptions are exactly those listed in `logging.md` section 8.1 |
| O5 | Every script in scope has the OS guard and the environment conditionals that `.claude/rules/cross-platform.md` requires | `tests/os-guards` passes; the A3 findings are fixed; no direct `CLAUDE_CODE_REMOTE` read outside the library |
| O6 | Every error line states what failed and why | Tests L13-L17 and the reason cases of L18-L31 pass; every `write_error` passes a reason (step 13); the PR lists the remaining reason-less `log_error` calls, each with why |
| O7 | `reference/logging.md` is the spec: rules, helpers, state machine, and a formal, generalized template for the run summary file and the panel, naming no session or run | S1 applied; the S1 review finds no session-, run- or machine-specific text |
| O8 | Two bugs filed and fixed; the unified-logging roadmap issue filed with suggested specs and not implemented | Three issues exist; the PR has `Fixes` for the two bugs and `Refs` for the roadmap issue |
| O9 | Ship | One PR; CI passes on macOS, Linux and Windows |

### 2.1 The panel format

The commander confirmed this with "19) yes" (prompt 6), answering the
restatement in the v3.2 reply. Lines marked *(v4)* were added after that
confirmation: they follow from prompt 6's error-reason question or from the
verifier runs.

The panel has four sections, in this order:

1. **Green**: one line per tool whose status is OK and that has no warning or
   error. The section is not capped or cut (prompt 7, "23) yellow and red
   only"). A tool's first OK record gives its line, as today.
2. **Yellow**: every warning of the run, each listed once, in the order it was
   logged. Each line names the tool, or the script when no tool is known, and
   says what is wrong or what to do. A tool with a warning appears here and
   not in green.
3. **Red**: every error of the run, each listed once, in log order. Each line
   names the tool or script and states what failed and why *(v4)*. A tool with
   an error appears here and not in green.
4. **Purple**: the ACTION lines. The same advice may also appear in a yellow
   line. Identical ACTION lines are shown once, with no `(xN)` *(v4)*.

Line rules (prompt 5, answer 8; prompt 7, "23) yellow and red only"):
- yellow and red text cut to 70 characters;
- identical yellow and red lines collapse into one, followed by `(xN)`;
- at most 20 yellow and 20 red lines, then a `+N more in deploy.log` line;
- the 16-character name column *(v4)*;
- for errors, the part saying what failed is cut first, so the reason survives
  *(v4)*;
- DETAIL lines under their tool's line, in its colour *(v4)*.

`reference/logging.md` section 8.5 states this as a formal, generalized
template (Appendix A).

### 2.2 Expected panel for the pasted run (illustrative wording)

This shows the same machine state as the pasted run, after the PR.
- Green lines appear in the order the run writes them; here the four newly
  green rows are listed last for comparison.
- Yellow lines appear in log order.
- The run had no errors.

```
  [ok]  gh cli           gh version 2.104.0 (2026-11-12)
  [ok]  shell            managed block unchanged
  [ok]  config.json      n/a (written by installer)
  [ok]  harness files    114 verified
  [ok]  pandoc           pandoc 3.14
  [ok]  rust/cargo       cargo 1.100.0 (3acc79c0c 2026-11-05)
  [ok]  typst            typst 0.15.1 (unknown commit)
  [ok]  uv               uv 0.13.8 (Homebrew 2026-11-12 aarch64-apple-darwin)
  [ok]  python           Python 3.14.10 (uv)
  [ok]  pywinpty         n/a (macos)
  [ok]  go               go version go1.27.4 darwin/arm64
  [ok]  perl             5.034001
  [ok]  bash             5.3.15
  [ok]  google chrome    n/a (local)
  [ok]  cursor cli       verified
  [ok]  cursor rules     7 verified
  [ok]  cursor skills    22 verified
  [ok]  claude mcp       verified
  [ok]  skills           n/a (fanned out)
  [ok]  cursor ide mcp   verified
  [ok]  claude settings  verified
  [ok]  claude hooks     21 verified
  [ok]  node.js          v26.3.1
  [ok]  claude code      2.1.325 (Claude Code)
  [ok]  claude rules     7 verified
  [ok]  claude skills    22 verified
  [!]   build-deploy     25 generated scripts over the Intune script limit (200000)
  [!]   aitools config   this machine is not registered -- run: aitools user init
  [!]   vercel cli       not authenticated -- run: vercel login
  [!]   modal cli        not authenticated -- run: modal setup (browser flow)
  [!]   datadog cli      not authenticated -- run: pup auth login
  [!]   claude.md        skipped (user review): local differs from source

  ACTION REQUIRED -- run before tools are ready:
  >>  Run: aitools user init (registers this machine)
  >>  vercel login -- authenticate vercel CLI
  >>  modal setup -- authenticate modal (browser flow)
  >>  pup auth login -- authenticate Datadog CLI
```

Differences from the pasted panel:
- `node.js`, `claude code`, `claude rules` and `claude skills` are green.
- `aitools config` moves from green to yellow, because it has a warning.
- `go` stays green, and its PATH ACTION is gone: the managed PATH block now
  always puts Go's bin directory on PATH (issue 2).
- The five yellow tool lines say what is wrong or what to do.
- build-deploy's 25 per-script size warnings show as one line. Each script's
  line and hint stay in deploy.log as detail lines. Earlier versions of this
  plan said 23: that count came from a truncated log read.
- `setup-cursor-ide-mcp`'s two warnings are gone once the PR fixes that bug.

An error line, as the 8.5 grammar renders brew's message for a missing
formula:

```
  [ERR] pandoc           brew install failed: Error: No available formula with the name "pan...
```

## 3. Root cause (unchanged)

- `write_summary` / `Write-Summary` turn an OK row into WARN when the script's
  warning count is above 0, and keep the OK text.
- The child-log relay adds a child's warnings to its parent's count.
- The spec asked for this: `reference/script-standards-detail.md` says "the row
  reports the script's state so far, not only its own step". Origin: commits
  `a88e2e4f` and `693a7e7d`.
- The same mechanism hides warnings logged after a row is written:
  `setup-cursor-ide-mcp` logged two warnings while its row stayed `[ok]`.
- Errors have the same gap (answer 12). An error line says which step failed
  ("brew install failed", "script failed (exit 1)"), not why. The cause is in
  output that reaches only deploy.log, or that nothing captures.

## 4. Decisions recorded

| Question | Commander's answer | In this plan |
|---|---|---|
| RFI 5899-1 (raised after prompt 1), file an incident | Prompt 5, "1) no" | No incident is filed |
| RFI 5899-3 to 5899-6 (v1.0) | Prompt 4: "3)" asked about batching, child and parent, and docs; "4) yes"; "5)" document the state changes and propose `logging.md` text; "6) yes, but dont do anything yet" | 3) 2.1 and section 5; 4) the 70-character cut in 2.1 (carried on by 8); 5) section 5 and Appendix A; 6) Phase 5 |
| RFI 5899-7, commit the plan to main | Prompt 4, "7) wait"; prompt 5, "7) no" | The plan ships inside the PR. The untracked copy in the main checkout is left in place (no deletion was ordered) and noted in the PR body |
| RFI 5899-8 to 5899-13 (v2.1) | Prompt 5: 8) yes; 9) approved; 10) file the GitHub issues as part of the plan; 11) `write_action`, the warning says what to do; 12) errors the same way; 13) build-deploy collapsed | 2.1; Appendix A; A5; 5.2; the red section; G2 |
| RFI 5899-14, hooks use the library | Prompt 6, "13) the hooks should use it, but the plan should include filing this as a GH issue on the repo, it should not include impleenting it" | No hook changes. The need is filed in the roadmap issue (A7) |
| Why prompt 6's "13)" answers RFI 5899-14 | Prompt 5 had already answered "13) yes"; the RFIs open before prompt 6 were 5899-14 to 5899-20; his list (13, 15, 16, 17, 18, 19) skips 14 and 20 (20 stays open, see below); "the hooks should use it" answers RFI 14 ("Should hooks use the library too?"); and his item 15 says "the same issue for 14" | Closed: RFI 5899-21 of v4.0 is withdrawn |
| RFI 5899-15, Python tools | Prompt 6, item 15: same issue; analyse the codebase; a roadmap item with specs across python, shell, ps1, perl, hooks, install and deploy scripts; implementation out of scope | A7; the Intent's "NOT in scope" |
| RFI 5899-16, the blank "3)" | Prompt 6, "16) ignore" | Dropped |
| RFI 5899-17, two stale hook backups | Prompt 6, "17) ignore" | Dropped: the plan does not touch them |
| RFI 5899-18, incident #178 | Prompt 6, "18) no" | The plan does not touch the incidents registry. #178 covers the entry points' appends, which become false, and two hooks, which stay. A.3 drops the entry-point half and keeps "(open incident #178)" on the hooks clause. The registry entry is left as it is |
| RFI 5899-19, the panel format | Prompt 6, "19) yes ... documented in the logging.md file, with formal structure, it should not reference any session or run, it should be a generalized template" | Appendix A, sections 8.4 and 8.5. Read as "no particular session or run": "run" appears only as a term defined in 8.0 |
| RFI 5899-22 (v4.0), the error-marker list | Not answered | Withdrawn: the anchored, case-insensitive marker rules in `logging.md` 8.3 settle it, extended from A2's findings in S1b |
| RFI 5899-20, `write_warn` and `write_error` | Prompt 7, "20) yes" | 5.2; `write_summary WARN` / `ERROR` retired in I5 |
| RFI 5899-23, cut and cap for green and purple | Prompt 7, "23) yellow and red only" | 2.1; `logging.md` 8.5 |
| RFI 5899-24, the install-method check | Prompt 7, "24) logging-only edits are exempt, run check for two bug fixes" | A8 covers only the two bug fixes (the Cursor `agent` CLI and Go) |
| RFI 5899-25, demoting warnings about a step the user asked for | Prompt 7, "25) i like this idea, they should be demoted to info unless you think the scope creep is too much" | Demoted, under the narrow rule in `logging.md` 8.3 ("What is a warning"). The scope is small: the rule and its test, A2's list, and one line per site changed in the groups. Skips stay warnings (`claude.md` stays yellow) |
| RFI 5899-26, the untracked plan copy | Prompt 7, "26) dont worry about it" | No action; the plan leaves it alone |
| RFI 5899-27, how wide the Go fix is | Prompt 8, "27) the broader fix for this plan/pr" | Issue 2's fix: the managed PATH block always puts Go's bin directory on PATH; `setup-go` stops advising a profile edit |
| RFI 5899-28, write the block into zsh's profile too | Prompt 10, "rfi 28) lets just fix the block always adds bug, dont file zsh issue, we dont manage zsh so just leave as is" | No zsh changes and no zsh issue. Issue 2's fix is the block's Go line only |
| Assumption 5 of the review, the release version | Prompt 10, "for assumption 5, check the latest PRs/commits for correct version or have the executing agent do it.  75 is not correct" | Checked 2026-11-15: newest release v0.77.25 (PR #183), so the next minor is v0.78.0. The executing agent re-checks at ship time (Phase 5) |
| Assumption 9 of the review, one session | Prompt 10, "lets assume a single session can, the lan should instruct the executing agent to delegate as much as possible" | Section 0, "Delegation: delegate as much as possible" |
| Error reasons | Prompt 6: "can we change the spec to capture the reason for errors?" Yes (5.5) | R11; `write_error TOOL WHAT REASON`; `error_reason`; tests L13-L31 |

**The three GitHub issues**:
1. **`setup-cursor-ide-mcp`**: the twins have different defects.
   - The `.sh` runs `agent mcp remove <server>`, which fails with `error: too
     many arguments for 'mcp'. Expected 0 arguments but got 2.`
   - The `.ps1` runs `agent mcp disable <server>`, a subcommand the `.sh`
     comment says Cursor dropped.
   - The `.sh` header still says "disabled via `agent mcp disable`".

   Filed in A5; fixed in I0.
2. **`setup-go.sh` warns about Go's bin directory on every run, with advice
   that cannot work.** Filed in A5; fixed in I0 with the broader fix (prompt
   8), limited to the PATH block's Go line (prompt 10).
   - **Symptom**: every run logs "Added ~/go/bin to PATH for this session
     only", advises `export PATH="$GOPATH_BIN:$PATH"` (the `$` is escaped, so
     the variable name is printed), and writes the ACTION "Add ~/go/bin to
     PATH".
   - **Cause**, found on the machine that produced the pasted run
     (2026-11-15):
     - The managed PATH block (`setup-user-shell.sh`, in `~/.bash_profile`)
       adds `$HOME/go/bin` only when that directory exists (`[ -d
       "$HOME/go/bin" ]`). It does not exist yet, because nothing has been
       installed with `go install`, so the block skips it.
     - `setup-go` checks that `${GOPATH:-$HOME/go}/bin` is on PATH, finds it
       missing, and warns.
     - The block does reach zsh on that machine: `~/.zprofile` runs `source
       ~/.bash_profile`. aitools does not manage zsh, and this plan leaves zsh
       as it is (prompt 10).
   - **Fix**:
     - The block's Go line becomes `export PATH="$PATH:${GOPATH:-$HOME/go}/bin"`,
       with no existence check. Binaries installed later are found without a
       new shell, and a PATH directory that does not exist is harmless. It
       also names the directory as `setup-go` does.
     - `setup-go.sh` no longer advises a profile edit or writes an ACTION. When
       Go's bin directory is not on the current PATH, it adds it for the
       session and logs at info that new shells get it from the managed
       block. The escaped-variable line goes away with the advice.
   - **Windows**: `setup-go.ps1` already writes Go's bin directory to the
     persistent user PATH (`Ensure-GopathBinOnPath`), so the `.ps1` twins do
     not change.
3. **Unified logging roadmap**: "Unified logging across Python, shell,
   PowerShell, Perl, hooks, install and deploy scripts", with suggested specs.
   Analysed and filed in A7; not implemented.

## 5. The spec: logging logic and state machine

`reference/logging.md` section 8 is the spec. Phase 3 writes it from
Appendix A; the code, the checks and the script standards follow it. This
section gives the reasoning.

### 5.1 Rules

- **R1, the library writes the logs**: in-scope scripts write log entries and
  summary records only through the `aitools-lib` helpers. The exceptions are
  listed in `logging.md` section 8.1.
- **R2, recorded at the source**: each warning and error is recorded once, by
  the script that logs it, in the run summary file. Parent and children are
  treated the same.
- **R3, a WARN or ERROR record is one warning or one error**, never a tool's
  status. `write_summary WARN` / `ERROR` are retired.
- **R4, no recolouring**: OK, DETAIL and ACTION records are written as the
  caller wrote them.
- **R5, the relay shows and decides failure**:
  - It prints a child's lines and mirrors them to `deploy.jsonl`.
  - A child's warnings are not added to the parent's count.
  - A failed child is one error of the parent. It is counted in the parent's
    error count, so the parent exits 1 as today.
  - It is recorded (one red line) only when the child recorded no error.
    Otherwise it is logged at error level and counted, but not recorded
    again.
  - A user abort (exit 2) keeps today's outcome (`.claude/rules/interactive-menus.md`
    "Abort"): one WARN record for `deploy-harness`, which stops the run with
    exit 2, and one ERROR record for any other script, after which the run
    continues. The child's own "Aborted by user" line is logged and counted,
    not recorded.
- **R6, each script counts its own** warnings. The error count includes the
  failed children (R5).
- **R7, the panel**: `logging.md` section 8.5.
- **R8, outside a run** (no `AITOOLS_SUMMARY_FILE`): nothing is recorded.
- **R9, fail-safe**: a summary record that cannot be written is ignored, as a
  log line is. This extends `logging.md` section 5's one sanctioned silent
  failure.
- **R10, platform and environment** come only from the library API.
- **R11, every error has a reason**: what failed (WHAT) and why (REASON). The
  reason is derived as `logging.md` section 8.3 specifies.

### 5.2 Helpers

Bash names, with the PowerShell twins in brackets. The twins avoid the
built-in `Write-Error` and `Write-Warning`; a probe in the verifier run
confirmed that the names below collide with nothing.

| Helper | deploy.log | Count | Run summary file |
|---|---|---|---|
| `log`, `log_ok`, `log_detail` | the line | none | none |
| `log_warn TEXT` | `[warn]` TEXT | warnings +1 | WARN record, name = script |
| `write_warn TOOL TEXT` (`Write-AitWarn`) | `[warn]` TEXT | warnings +1 | WARN record, name = TOOL |
| `write_action TOOL TEXT ACTION` (`Write-AitAction`) | `[warn]` TEXT | warnings +1 | WARN record and ACTION record |
| `log_error TEXT` | `[error]` TEXT | errors +1 | ERROR record, name = script, empty reason. Use it only for an error whose TEXT already states its cause; the script standards (D1) say so, `logging.md` 8.2 only states its effect |
| `write_error TOOL WHAT REASON` (`Write-AitError`) | `[error]` WHAT: REASON | errors +1 | ERROR record, name = TOOL |
| `error_reason OUTPUT EXIT_CODE` (`Get-AitErrorReason -Output -ExitCode [-ErrorRecord]`) | the full OUTPUT as detail lines | none | none; it returns one reason line (`logging.md` 8.3) |
| `write_summary OK\|DETAIL\|ACTION` | none | none | the record |

- **Relay internal.** The relay and `_managed_abort` / `Invoke-ManagedAbort`
  use a library-internal path: an error-level line, counted, not recorded.
  Nothing else may use it (R5).
- **New PowerShell relay.** A native-command relay (`Invoke-NativeRelayed`)
  streams a native command's output through the existing line relay, so that
  `aitools.ps1` can relay `build-deploy.sh` run through `bash.exe`.
- **Overrides become options.** The installers' `deploy.jsonl` writing and the
  profile resolver's console-on-stderr become library options; no script
  overrides a logging function.
- **During the migration only (until I5):**
  - `log_warn` and `log_error` record nothing (a library switch, off);
  - the legacy `write_summary WARN` / `ERROR` write their old 3-field records,
    which the reader accepts (`logging.md` 8.4).

  So a half-migrated script writes each warning or error once.

### 5.3 State (before and after)

| State | Where | Before | After |
|---|---|---|---|
| Warning count | `WARNINGS` / `$script:warnings`, per script | `log_warn`; relayed child warn lines; read by the footer, by the promotion and by `read_menu_choice` | `log_warn`, `write_warn`, `write_action`; read by the footer and by `read_menu_choice` |
| Error count | `ERRORS` / `$script:errors` | `log_error`, including the relay's for a failed child; read by the footer and the fan-out validation | `log_error`, `write_error`, and the relay's failed-child error (R5); the same readers |
| Child counts | `AITLIB_CHILD_WARNINGS` / `AITLIB_CHILD_ERRORS` | set by the relay | set by the relay; the error count, plus the exit code, decides failure |
| Summary records | the run summary file | OK / WARN / ERROR / ACTION / DETAIL, one per tool; OK promoted | OK / DETAIL / ACTION as written; one WARN per warning; one ERROR per error, with its reason |
| Log lines | `deploy.log`, `deploy.jsonl` | the library; three logging overrides (the installers, the resolver, build-deploy's `blog*`); the entry points' direct appends (build-deploy and relay-sync output); one hand-written summary record (the generated deploy-harness guard) | the library only, except the writers in `logging.md` 8.1 |
| Exit footer | each script | warnings include the children's | the script's own warnings; errors include failed children |
| Panel | the renderer | OK, WARN, ERROR, ACTION; one line per tool; ACTION lines never de-duplicated | green, yellow, red, purple (`logging.md` 8.5); identical ACTION lines shown once |

### 5.4 Events

`logging.md` section 8.6 lists them. The events that change:
- A relayed child's warn line: no longer counted in the parent.
- A failed child: one parent error, recorded only when the child recorded
  none (R5).
- Each warning or error helper: writes its record.
- The renderer: draws four sections.

### 5.5 Error reasons: feasibility (prompt 6)

The answer is yes, it is technically feasible.

**Where the reason comes from.**
- `.claude/rules/script-standards.md` "External command error handling"
  already requires capturing install and upgrade output and checking exit
  codes. Most error paths therefore have the output in a variable. It reaches
  only deploy.log today, for example `brew upgrade uv failed (see log above)`
  (`setup-uv.sh`).
- About 17 bash sites stream the output through `while read` and capture
  nothing (for example `brew install pandoc failed` in `setup-pandoc.sh`).
  They must capture or tee first; A2 marks them.

**How the reason reaches the error line.**
- `error_reason` applies the order in `logging.md` 8.3:
  1. a known build signature (`diagnose_build_failure`, called inside), as
     `<NAME>: <REMEDY>`;
  2. the exception message (PowerShell);
  3. the first line matching an anchored error marker;
  4. the last non-empty line;
  5. `no output (exit <N>)`.

  It strips CR, ANSI codes and a structured `[ts] [script] [level]` prefix,
  and logs the full output as detail lines.
- A verifier probe ran `error_reason` under macOS `/bin/bash` 3.2.57 and pwsh
  7, without `grep -P` and without an early-exit pipeline. It returned the
  results tests L13-L15 expect.

**Crashed children.**
- The bash relay and the native PowerShell relay see only a child's stdout. A
  bash crash message (from `set -e`, a missing command, a syntax error) goes to
  stderr.
- So they tee the child's stderr to a temporary file while it still reaches
  the console. A failed child's reason is `error_reason` over its last 20
  stderr lines; when there are none, over its last stdout line. Its WHAT is
  `<label> failed (exit <N>)`.
- An in-process PowerShell child (`Invoke-ChildRelayed`) has no separate
  stderr. Its reason is the exception message when it threw (WHAT `<label>
  failed (exception)`). Otherwise it is the error records it wrote (stream 2,
  captured with `2>&1`), else its last output line.
- Children that are not relayed today are moved onto the relay (G1):
  `validate_and_run` in the installers, and the setup-script loops of
  `scripts/aitools` / `aitools.ps1`.

**Limits.**
1. A reason is only as informative as the failing tool's output; some tools
   print nothing, and then the reason is the exit code.
2. A multi-line cause is one line in the panel; the full output stays in
   deploy.log.
3. A check can require that a reason is passed. It cannot judge whether the
   reason is useful. The tests cover extraction, and the PR lists the paths
   whose reason is only the exit code.
4. The panel may show a line of command output, which deploy.log already
   holds. The panel prints to the user's terminal. On the package path
   (`build-package` runs `aitools-install`; a scaffold today) it also lands in
   the installer's log, which MDM collects.
5. While the relay tees a child's stderr, the child's stderr is no longer a
   terminal (`[ -t 2 ]` is false). So colour and progress bars that tools draw
   on stderr disappear in relayed runs. The relay already does this to
   stdout. Prompts are unaffected: they go to `/dev/tty` (bash) or through
   `[Console]` (PowerShell).

## 6. Documentation that changes (Phase 3)

| File | Change | Delegate |
|---|---|---|
| `reference/logging.md` | Appendix A | S1 (a delegate; the lead reviews) |
| `.claude/rules/script-standards.md` | See below | D1 |
| `.cursor/rules/script-standards.mdc` | The same (twin) | D1 |
| `reference/script-standards-detail.md` | See below | D1 |
| `reference/managed-file-deployment.md` | The auth pattern; `failed` outcomes use `write_error`, with the write error as the reason | D2 |
| `.claude/rules/managed-file-deployment.md`, `.cursor/rules/managed-file-deployment.mdc` | "Outcome tracking" | D2 |
| `.claude/rules/interactive-menus.md`, `.cursor/rules/interactive-menus.mdc` | "Return value contract" (the ERROR row) and "Abort" (the runner's rows become `write_warn` / `write_error` with a reason) | D2 |
| `reference/tool-support-decision-tree.md` | Section 3's notes (lines on the promotion), the four table rows and the bullet that mention it, and the outcome table's WARN and ERROR rows become helper calls with a reason source | D2 |
| `reference/cross-platform-detail.md` | "Reporting a step that does not apply" | D3 |
| `reference/plan-execution-detail.md` | The `log_error` pairing checks become "`write_error` with a reason" | D3 |
| `reference/smoke-test-pattern-detail.md` | The panel grep list | D3 |
| `reference/ait-shellintegration.md` | The managed PATH block's Go line is `export PATH="$PATH:${GOPATH:-$HOME/go}/bin"`, with no existence check (issue 2) | D3 |
| `reference/harness.md`, `reference/artifact-manifests.md`, `reference/managed-context.md`, `reference/managed-configuration.md`, `reference/framework-managed-file-deployment.md` | Text that prescribes "`log_error` + an ERROR row" becomes `write_error` | D4 |
| `RELEASE_NOTES.md` | New minor version | Phase 5 |

**The script-standards files (D1)**:
- In `.claude/rules/script-standards.md` (and its `.mdc` twin):
  - "Error and warning tracking requirement";
  - "Required logging helpers": add the new helpers; logging.md 8.2 owns
    their effects, and the rule keeps usage;
  - "Standalone build logging": removed;
  - "End-of-run summary": OK / DETAIL / ACTION records plus the helpers;
    WARN / ERROR records retired; point to `logging.md` 8;
  - "Config and file update reporting": the 30-character detail limit applies
    to OK and DETAIL text, not to warning or error lines;
  - "External command error handling": pass `error_reason` to `write_error`;
  - "Post-install authentication check": `write_action`;
  - "Build prerequisite validation".
- In `reference/script-standards-detail.md`:
  - "Function definition";
  - "Summary file format": point to `logging.md` 8.4;
  - the severity categories and decision guide;
  - "ACTION items";
  - "Summary coverage rule";
  - "Three outcomes" and "Summary detail text rules" (the 30-character limit);
  - "Logging-summary pairing rule";
  - the library and override tables;
  - the logging override exceptions (build-deploy removed);
  - "Exit footer";
  - every example that pairs a log call with a WARN or ERROR row.

Decision rows in `reference/skills.md` and `reference/rules.md` record past
decisions and stay as they are.

## 7. Scale (inventory 2026-11-15, re-run by the verifier)

| What | Count |
|---|---|
| `write_summary WARN` / `Write-Summary "WARN"` call sites | 111 |
| `write_summary ERROR` / `Write-Summary "ERROR"` call sites | 478 |
| ACTION writes | 80 direct, plus 66 through `_aitlib_action_once`, `Write-AitLibActionOnce`, `ui_action` and `Write-UiAction` |
| Lines that mention `log_warn` / `LogWarn` | 552 (`grep -rn "log_warn\|LogWarn" scripts \| wc -l`; another grep gave 553) |
| Logging functions defined outside the library (in scope) | `build-deploy.sh` (`blog*`); `aitools-install.sh` / `.ps1` (`log*` / `Log*`); `aitools-profile.sh` / `.ps1` (`log` / `Log`) |
| Direct appends to `deploy.log` (in scope) | `scripts/aitools` (build-deploy output, relay-sync output); `scripts/aitools.ps1` (`Add-Content`, the same two). `sync-relay-to-cursor-agents.py` only prints a deploy.log-shaped line; the parents append it |
| Direct summary append (in scope) | The generated deploy-harness truncation guard in `build-deploy.sh`, written by hand before the library loads |
| Bash sites that stream output without capturing it | About 17 |
| Out of scope (roadmap issue) | All hooks that write their own logs (`standing-order-guard.sh`, `tool-ops-session-audit.sh`, `harvest-session.sh`, `session-catchup.sh`, `session-archive.sh`, `harness-db-sessionend.sh`); Python component logs; Perl helpers; `shared/shell/aliases.*` (`clip2md.log`); the package launcher stubs (`packaging/macos/postinstall`, `packaging/windows/install-system.ps1`) |
| Test suites that read the summary file or its rows | At least 20; A6 lists them |

## 8. Phase 1: orient (targeted)

The lead agent does this.

1. **Branch and draft PR.**
   - Create the worktree and branch `fix/summary-warn-reporting` from
     `origin/main`.
   - Copy this plan into it at `plans/summary-warn-reporting.md`, commit,
     push, and open the PR as a draft (`gh pr create --draft --body-file`).
     The draft gives Windows CI from the first change, and a PR number for A7
     to cite. Group branches get no CI.
   - Leave the untracked copy in the main checkout (prompt 5, "7) no"; prompt
     7, "26) dont worry about it").
2. **Read in full**:
   - every user-scope and project-scope CLAUDE.md and rule;
   - `reference/aitools.md`;
   - `reference/logging.md`;
   - `.claude/rules/script-standards.md`;
   - `.claude/rules/cross-platform.md`;
   - `.claude/rules/deploy-paths.md`;
   - `.claude/rules/interactive-menus.md`;
   - `~/.claude/rules/tool-lifecycle.md`.
3. **Read these sections**:
   - `reference/script-standards-detail.md`: "End-of-run summary", "Logging
     architecture", the override and exemption tables, the external-command
     and build-failure patterns;
   - in `aitools-lib.sh` / `.ps1`: the relay, logging, `write_summary`, the
     tracker, `deploy_managed_file`, the fan-out, `show_summary`,
     `diagnose_build_failure`, `_aitlib_action_once`;
   - in `aitools-install.sh` / `.ps1`: the logging overrides,
     `validate_and_run`, Step 5;
   - in `scripts/aitools` / `aitools.ps1`: the run loop, `ui_action` /
     `Write-UiAction`, the build-deploy and relay-sync calls;
   - in `build-deploy.sh`: the header and the embedded summary calls;
   - `tests/logging`, `tests/os-guards`, `tests/profile/test-install.sh`,
     `check-script-compliance` steps 3, 12 and 13;
   - `.github/workflows/check.yml`.
4. **Load the skills** `/delegate`, `/scratch`, `/tool-ops`, `/tool-registry`,
   `/tool-adopt` and `chrome-devtools`.

## 9. Phase 2: understand

- **In parallel**: A1, A2, A3, A4, A7 and A8, as delegates or by the lead.
- **Afterwards**: A5 follows A4. A6 follows A1-A3.
- **Overlap**: S1 starts as soon as A1 is done (section 0, deviation 3).
- Findings go to the session scratch directory.

**A1, log writers**: every in-scope place that writes a log entry or summary
record without the library, starting from section 7; and every bash or
PowerShell file that cannot load the library (for `logging.md` 8.1).

**A2, calls and reasons**: one delegate per provisional Phase 4 group (the
groups in section 11), plus one for the library's own call sites (I1). It
covers every WARN, ERROR and ACTION call site, including the wrappers, and
every `log_warn` / `log_error`, per script, marking:
- each pair: a log call and a record for the same event;
- the tool it concerns;
- for each error path, its reason source: captured output, exit code,
  exception, build signature, or none;
- each site that streams output without capturing it;
- the error markers that actually occur in captured outputs (for the
  `error_reason` marker list);
- each warning that reports a step the user explicitly asked for in this run,
  by the rule in `logging.md` 8.3 ("What is a warning"), to be demoted in its
  group;
- the tests that assert summary records inline, not through golden files
  (for I1b).

**A3, guards and environment**: run `tests/os-guards` and list:
- guards that differ from `.claude/rules/cross-platform.md`;
- direct `CLAUDE_CODE_REMOTE` reads outside the library (none on 2026-11-15);
- platform branches below a guard;
- environment branches without a recorded decision.

**A4, the Cursor `agent mcp` command**: read the current Cursor CLI
documentation for removing or disabling an MCP server (`chrome-devtools`, user
rule `web-sources.md`), the `/tool-registry` cursor cli entry, and both twins.

**A5, file the two bug issues** (`gh issue create --repo nobul-tech/aitools
--label bug --body-file`; the repository has no `roadmap` label):
- Issues 1 and 2 of section 4, with the deploy.log lines, the twin
  differences and the A4 finding.
- A delegate writes each body. The lead reviews it and files the issue.
- Record the numbers.

**A6, finish the design** (one delegate per group, from that group's A2
findings; the lead reviews and settles group membership): per script:
- map each pair to `write_warn` / `write_action` / `write_error`;
- map each unpaired `log_warn` to a tool where the code knows it;
- map each error path to its reason source;
- map each `log_error` either to `write_error` (a reason exists) or to "keep",
  with why.

Then assign every in-scope script to exactly one Phase 4 group. For each test
suite, list the groups whose scripts feed it. A suite fed by more than one
group is regenerated only once, in I5: `profile`, `b8-consumers`,
`aitools-entry`, `bootstrap`, `claude-mdm`, `deploy-harness*` and
`build-deploy` at least.

**A7, unified logging: analyse and file the roadmap issue.** Read-only, then
one `gh issue create`. **Implementing it is out of scope.**
- **Inventory** every logging writer across:
  - Python: `scripts/*.py`, `shared/hooks/*.py`;
  - shell: `scripts/*.sh`, the extensionless entry points,
    `shared/shell/aliases.sh`;
  - PowerShell, including `shared/shell/aliases.ps1`;
  - Perl: `scripts/*.pl`, `tests/os-guards/*.pl`;
  - hooks: every `shared/hooks/*.sh`;
  - install: `aitools-install.*`, `bootstrap.*`, `hh.*`;
  - deploy: `build-deploy.sh`, the generated `deploy/` scripts,
    `build-package.sh`, `packaging/`.
- **For each writer, record**: the destination file, the line format, the
  levels, the counters, the rotation, the fail-safe behaviour, and whether it
  takes part in the run summary.
- **Suggested specs for the issue**:
  1. one cross-language contract: the line format and levels of `logging.md`
     section 5, and the run summary file of section 8.4 as the interface any
     language can append to;
  2. a thin helper per language: a Python module, a Perl module, and hooks
     sourcing a deployed copy of the library. Prompt 6 says "the hooks should
     use it"; the spec sets a timing budget for how the library loads in
     hooks, not whether hooks use it;
  3. checks per language;
  4. a migration order.
- **File it** as a roadmap item: "Unified logging across Python, shell,
  PowerShell, Perl, hooks, install and deploy scripts", with `gh issue create
  --repo nobul-tech/aitools --label enhancement`.
  - It includes the commander's answers on hooks ("the hooks should use it",
    prompt 6, "13)", read as RFI 5899-14) and on Python (prompt 6, item 15).
  - The body states that the draft PR implements only the bash and PowerShell
    part listed in this plan's Intent.
  - Record the number: `logging.md` 8.1 cites it.

**A8, the install-method verification gate**
(`~/.claude/rules/tool-lifecycle.md`, "Install command verification gate").
- **What**: run it for the two bug fixes only: the Cursor `agent` CLI
  (`setup-cursor-ide-mcp`) and Go (`setup-go`). Verify each tool's current
  upstream install method with `chrome-devtools`. Logging-only edits are
  exempt (prompt 7, "24) logging-only edits are exempt, run check for two bug
  fixes").
- **How**:
  - one delegate verifies, read-only, and returns its findings;
  - the lead records them through `/tool-registry` on
    `fix/summary-warn-reporting`, in one commit.
- **Before**: I0 needs A8 ("Record the findings ... first, then change the
  scripts"). The G4 groups do not.

## 10. Phase 3: spec and documentation

**S1, the spec first** (after A1)
- Apply Appendix A to `reference/logging.md`, with the 8.1 exceptions from
  A1. The roadmap issue number is a placeholder until S1b.
- Review the result. No sentence may refer to a session, a particular run or
  machine, this plan, or a person: the spec is a generalized template (prompt
  6, item 19). "Run" and "entry point" appear only as the defined terms in
  8.0.
- Run `python3 scripts/check-path-refs.py`: it scans `reference/`, so every
  repository path the new text cites must exist. It does not scan `plans/`.
- Commit and push.

**S1b** (after A2 and A7): fill in the roadmap issue number, and add to 8.3's
marker rules any error marker A2 found that they miss. One commit.

**S2, in parallel after S1**: four delegates, each with its own file set from
section 6 (D1, D2, D3, D4).
- Each delegate runs `python3 scripts/check-path-refs.py` on its result.
- The lead reads each result against `logging.md` section 8 before merging
  it.

**Overlap**:
- I1 and I2 depend only on S1, so they start while S2 runs.
- I0 also needs A4, A5 and A8 for its two tools.
- I3 waits for S2, A6 and the I0 merge.

## 11. Phase 4: implement and execute

**Before I1: the shared fixture.** A delegate writes one fixture of the
expected summary records and panel lines for tests L1-L31, used by both
languages, so that their parity is mechanical.

I0, I1 (bash), I1 (PowerShell) and I2 then run in parallel: four delegates,
disjoint files.

**I0, the two bugs** (after A4, A5 and A8 for these tools). One commit per
fix, referencing its issue.
- **Issue 1**: the `setup-cursor-ide-mcp` twins (the `agent mcp` command from
  A4, plus the `.sh` header comment).
- **Issue 2**:
  - `setup-user-shell.sh`: the block's Go line only;
  - `setup-go.sh`: no profile advice, no ACTION;
  - `tests/setup-user-shell/test-setup-user-shell.sh`: the block's new Go
    line, and an existing block with the old line refreshed to the new one.

  No zsh change. `setup-user-shell` also belongs to G3, which migrates its
  logging on top of I0.
- **Merge**: the lead merges I0 before I1b, so I1b regenerates any golden file
  I0 touches.

**I1, the core library**: `aitools-lib.sh` with `tests/logging/test-logging.sh`,
and `aitools-lib.ps1` with `tests/logging/test-logging.ps1`.
- **Implement 5.2**:
  - the helpers, `error_reason` / `Get-AitErrorReason`, and
    `Invoke-NativeRelayed`;
  - the relay rules (R5, `logging.md` 8.3), its stderr capture, and the name
    fallback;
  - `_managed_abort` / `Invoke-ManagedAbort` on the non-recording path;
  - the migration switch and the legacy 3-field records;
  - the jsonl and stderr options;
  - the renderer (`logging.md` 8.5) and the reader rules (8.4).
- **Counting code points.** Bash cuts and pads in Perl with `-CSD`, which
  `show_summary` already uses. PowerShell counts runes, not `.Length`.
- **Migrate the library's own call sites**, each with its tool name and, for
  errors, its reason:
  - `deploy_managed_file`: the write error or the merge error;
  - the JSON review;
  - the tracker: it writes an OK status record only, and the failures are red
    lines;
  - the fan-outs;
  - the resolver wrappers: the resolver's error lines;
  - `dotprofile_commit_push`: git's output;
  - `_aitlib_action_once`.
- **PowerShell without Windows**: the PowerShell delegate cannot run the
  Windows-guarded suite on macOS. It runs the pwsh parser and scratch
  exercises of the library under macOS pwsh; CI runs the suite after the
  merge.
- **Merge and push together**: the lead merges I1 (both languages) and I2
  together, then pushes once. The old step 13 fails on the new
  `write_summary`, so the two must not reach CI separately.
- **I1b, update every test expectation** that changes because of I0 and I1
  alone, mainly the promotion's removal. Delegates do it, one per few suites.
  - Golden files are regenerated with `UPDATE_GOLDEN=1` in the suites that
    support it (about 19).
  - Other suites, and the records asserted inline in about 20 harnesses (A2's
    list), are edited by hand, each changed line listed old -> new.
  - CI is green before I3 starts.

**I2, the checks** (`check-script-compliance.sh` / `.ps1`, and
`.github/workflows/check.yml`)
- **Step 13**, rewritten:
  1. `write_summary` / `Write-Summary` never change the category.
  2. Every `write_error` / `Write-AitError` call passes a non-empty reason.
  3. The relay changes no parent warning count.
  4. Legacy `write_summary WARN` / `ERROR` calls are reported during I3 and
     fail from I5.
- **Step 3**: accept `write_error`, `write_warn` and `write_action` as the
  logging before an `exit 1`.
- **Step 12**: from I5, allow only OK, DETAIL and ACTION.
- **A new step** checks the in-scope scripts for:
  - a logging function defined outside the library;
  - an append to a `.log`, `.jsonl` or `$AITOOLS_SUMMARY_FILE` outside the
    library;
  - `Add-Content` to a log;
  - a direct `CLAUDE_CODE_REMOTE` read.

  The exceptions are exactly those in `logging.md` 8.1. It reports during I3
  and fails from I5.
- **Report, then fail**: one constant per twin (`STRICT_SUMMARY`) switches
  rule 4, step 12 and the new step from report to fail. I5 sets it.
- **Tests and CI**: tests in `tests/check-script-compliance`, each with its CI
  step in `check.yml` (FO-0: a suite without a CI step fails
  `check-ci-suites.pl`).

**I3, migrate the call sites** (after I1b, I2, S2 and A6 are done and I0 is
merged)
- The groups run in parallel, each on its own files; both languages of a
  script stay in one group.
- Golden files are regenerated by the group (`UPDATE_GOLDEN=1`, or by hand
  where a suite has no update mode) only for suites that only that group feeds
  (A6). Every suite fed by more than one group waits for I5.

| Group | Files | Order |
|---|---|---|
| G1, entry points | `scripts/aitools`, `aitools.ps1`, `aitools-install.sh` / `.ps1`, `tests/profile/test-install.sh` / `.ps1`. Changes: <br>- remove the overrides; <br>- route `validate_and_run`, the bash setup-script loop and `aitools.ps1`'s loop (in-process `Invoke-ChildRelayed`) through the relay; the unreachable Windows branch of `scripts/aitools`' loop is removed; <br>- run build-deploy through the relay (`Invoke-NativeRelayed` in PowerShell); <br>- log the relay-sync output through the library; <br>- migrate `ui_action` / `Write-UiAction`; <br>- create and draw the summary file only when `AITOOLS_SUMMARY_FILE` is not already set (`logging.md` 8.4, 8.5) | parallel |
| G3, user setup | `setup-user-claude`, `-cursor`, `-config`, `-settings`, `-hooks`, `-mcp`, `-shell`, `-skills`; `deploy-harness`; `aitools-profile` (override removed) | parallel |
| G4a, tools A-M | `setup-bash`, `-cursor-ide-mcp` (on top of I0), `-datadog`, `-gh-cli`, `-go` (on top of I0), `-google-chrome`, `-modal` | parallel |
| G4b, tools N-Z and helpers | `setup-pandoc`, `-perl`, `-python`, `-pywinpty`, `-rust`, `-typst`, `-uv`, `-vercelcli`; `aitools-dashboard`, `analyze-session.sh`, `init-hh-hooks.sh`, `aitools-json.ps1`, `_validate-ps1.ps1`, `githooks/pre-commit` | parallel |
| G2a, build tools | `build-deploy.sh`'s own logging: source the library; `logging_init "build-deploy"`; `blog*` replaced. The Intune size warnings become one `write_warn "build-deploy"` per limit (one line today), with each script's line and hint as `log_detail`. Also `build-package.sh` (its comments on one row per tool) | parallel |
| G2b, build-deploy's generated code | `build-deploy.sh`'s embedded summary calls converted to G3's and G4b's conventions (it embeds and extracts `setup-user-*`, `deploy-harness` and `setup-pywinpty.ps1`); the truncation guard's hand-written record in the 4-field form | after G2a, G3 and G4b |

For each script, each group:
- **Pairs**:
  - a WARN pair becomes `write_warn TOOL TEXT`;
  - a warning with advice becomes `write_action TOOL TEXT ACTION`, the text
    saying what needs to be done (answer 11);
  - an ERROR pair becomes `write_error TOOL WHAT REASON`. Capture or tee
    streamed output first, then pass `error_reason`. For example: `write_error
    "pandoc" "brew install failed" "$(error_reason "$out" "$rc")"`.
- **Unpaired**: an unpaired `log_warn` about a known tool becomes `write_warn
  TOOL`. An unpaired `log_error` becomes `write_error` when A6 found a reason.
- **Demotions**: a warning that reports a step the user explicitly asked for
  in this run (A2's list) becomes `log` at info, as `logging.md` 8.3 "What is
  a warning" says. For example, `Diff in <file> -- overwriting (--force)`.
  Anything left unresolved stays a warning, such as a skipped review or a
  non-interactive overwrite of local edits. The PR lists each demotion.
- **Guards**: fix the A3 findings.
- **Tests**: run the group's own suites after each 2-3 scripts.

**I5, after every group is merged** (delegates; the lead merges)
- Turn the recording switch on permanently and remove it.
- Remove `write_summary WARN` / `ERROR`.
- Set `STRICT_SUMMARY` in both compliance twins and update their tests.
- Regenerate every cross-group suite (`UPDATE_GOLDEN=1`, or by hand).
- Run every suite on macOS and Linux, and the `.ps1` suites in CI on Windows.
- Step 3, step 12, step 13 and the new step must all pass.

**I6, I7 and I8 run in parallel after I5**, each under its own isolated `HOME`
and `AITOOLS_LOG_DIR`.

**I6, the replay test**: a new suite with its CI step. "CLAUDE.md skipped"
needs a terminal, so it reuses the pty harness in `tests/profile`. It
replays the pasted run's order:
- a parent relays a child that records a warning with an ACTION, then writes
  `OK|node.js|v26`;
- setup-user-claude runs with CLAUDE.md skipped;
- a child crashes after writing `boom` to stderr.

Expected: `node.js`, `claude rules` and `claude skills` green; one yellow
`claude.md` line; one yellow `aitools config` line and its ACTION; one red line
with the crash reason; no duplicate line; the parent exits 1.

The same pty run also answers a review menu in a relayed child. The menu must
appear, and accept its answer, exactly as before the change.

**I7, the deploy paths**:
- `bash scripts/build-deploy.sh` under an isolated `HOME` with a copy of the
  dotprofile: the generated scripts inline the new library, and build-deploy
  logs through it;
- `check-pre-push`;
- `build-package.sh --dry-run`.

**I8, end-to-end panel**:
- Run `aitools install` under an isolated `HOME`, with a fake dotprofile and
  `PATH` set to a stub directory plus `/usr/bin:/bin` only. The stubs cover
  every command the run calls; any command not stubbed is simply absent, so
  nothing real is installed or upgraded.
- Reproduce the pasted run's warnings: unauthenticated vercel / modal / pup
  stubs, an unregistered machine, a locally edited CLAUDE.md.
- Add one forced failure: the `brew` stub prints `Error: No available formula
  with the name "pandoc".` and exits 1 for `pandoc` only.
- Check O1 structurally.

## 12. Phase 5: ship

- **Release notes**: `RELEASE_NOTES.md`, the next minor version. Read the
  newest `## v...` heading of `RELEASE_NOTES.md` on `origin/main` at ship time
  and the latest merged PRs (`gh pr list --state merged`), because other PRs
  claim versions too. Then take the next minor. On 2026-11-15 the newest was
  v0.77.25 (PR #183), so that is v0.78.0. The git tags (v0.74.0) and the
  panel's `0.74.0+648` lag behind and are not the source.
- **Commits**: made per step, with messages from scratch files (`git commit
  -F`). Push the last ones.
- **PR body**: fill in the draft PR's body (`gh pr edit --body-file`), then
  mark it ready (`gh pr ready`). The body contains:
  - `Fixes #<issue 1>`, `Fixes #<issue 2>`, `Refs #<roadmap issue>`;
  - O1-O9 and how each was verified;
  - every changed summary and golden line, old -> new, with the reason;
  - every warning demoted to info, with the rule it meets;
  - the `log_error` calls kept without a separate reason, and the error paths
    whose reason is only the exit code;
  - a sentence that hooks, Python, Perl, the shell aliases and `checks.log`
    are unchanged and covered by the roadmap issue;
  - a note that the plan's untracked copy remains in the main checkout.
- **CI**: wait for macOS, Linux and Windows; fix failures until all three
  pass.
- **Report** the PR URL. Merging is the commander's.

## 13. Test cases (logging suite, bash and PowerShell, from one shared fixture)

**L1-L12**:

| Case | Input | Expected |
|---|---|---|
| L1 | `log_warn w`; `write_summary OK tool v1` (switch on) | `OK\|tool\|v1` unchanged; `WARN\|<script>\|w` |
| L2 | `write_warn tool w`; `write_summary OK tool v1` | Panel: no green `tool`; one yellow `tool  w` |
| L3 | `write_action tool w "do X"` | `WARN\|tool\|w`, `ACTION\|\|do X`; warning count +1 |
| L4 | `write_error tool what why`; `log_error f` (switch on) | `ERROR\|tool\|what\|why`, `ERROR\|<script>\|f\|`; error count +2 |
| L5 | A parent relays a child that runs `log_warn w` (switch on) | One `WARN` record (the child's script name); parent warning count unchanged |
| L6 | A child runs `write_error t what why` and exits 1 | Exactly one ERROR record in the file; parent error count +1; parent exit 1 |
| L7 | `\|`, CR and LF in every field | Each record keeps its field count |
| L8 | (a) `AITOOLS_SUMMARY_FILE` unset; (b) set to an empty existing file | (a) nothing recorded, no failure; (b) nothing rendered |
| L9 | Renderer: the same warning 3 times; a text over 70 characters; 25 warnings | `(x3)`; cut at 70 with `...`; 20 lines, then `+5 more in deploy.log` |
| L10 | Renderer: a mixed file | Order: green, yellow, red, purple; DETAIL lines under their tool's line, in its colour |
| L11 | `read_menu_choice` at end of input | Still detected (`tests/menus` unchanged) |
| L12 | PowerShell: an in-process child through `Invoke-ChildRelayed` logs a warning | One `WARN` record |

**L13-L17, error reasons**:

| Case | Input | Expected |
|---|---|---|
| L13 | `error_reason` over brew-style output containing `Error: No available formula` | That line |
| L14 | `error_reason` over output with no marker | The last non-empty line, with CR, ANSI and any `[ts] [script] [level]` prefix stripped |
| L15 | `error_reason ""` with exit code 2 | `no output (exit 2)` |
| L16 | Renderer: an error whose what-and-reason text is over 70 characters | The 8.5 cut algorithm: WHAT shortened only as far as needed, not below 20 characters; then the reason |
| L17 | bash: a child crashes after writing `boom` to stderr and a log line to stdout, with no record. PowerShell: an in-process child throws `boom`, or runs `Write-Error boom` and exits 1 | One red line from the parent: `<label> failed (exit <N>): boom` (bash, and PowerShell `Write-Error`), or `<label> failed (exception): boom` |

**L18-L31, edge cases**:

| Case | Input | Expected |
|---|---|---|
| L18 | Output containing `0 failed`, `NOTE: x` and `SOURCE: y` | Not matched as markers; `ERROR: z` (pip style) is matched |
| L19 | Output matching a build signature | `<NAME>: <REMEDY>` |
| L20 | `log_error "x"` (empty reason); and `log_error` with a 100-character text | Red line `x`, with no trailing `: `; the long text cut at 70 |
| L21 | Two identical errors | One red line with `(x2)` |
| L22 | 25 errors, with DETAIL lines under some tools | Collapse first; DETAIL lines do not count toward the 20; the DETAIL lines of tools beyond the cap are not shown |
| L23 | A non-ASCII text over 70 characters, including a character outside the BMP; the same under `LC_ALL=C`; a non-ASCII name in the 16-character column | Cut and padded by code points, the same in bash and PowerShell and in every locale |
| L24 | A 3-field (legacy) ERROR record; an unknown record kind | Read with an empty reason; skipped and logged at detail |
| L25 | A DETAIL line with no line for its tool | Not shown |
| L26 | A WARN line whose name equals a tool name | That tool's green line is suppressed |
| L27 | `write_summary WARN` / `ERROR` (legacy) and `log_warn` with the switch off | One record per warning or error, never two |
| L28 | A child aborts (exit 2): `deploy-harness`, then another setup script | One yellow `harness files` line and exit 2; one red line for the other script, and the run continues; no second record from the child |
| L29 | Two OK records for one tool; two identical ACTION records | The first OK record's status shown; the ACTION shown once |
| L30 | A WARN record with an empty name; an ACTION whose instruction contains `\|` | The first is skipped and logged at detail; the instruction is kept whole |
| L31 | `write_error tool what ""` | deploy.log line `[error] what`, with no `: ` |
| L32 | A managed file that differs: (a) under `--force`; (b) non-interactive; (c) skipped at the review menu | (a) an info line, no WARN record; (b) and (c) one WARN record each |

## 14. Open questions at v4.5

None. Every RFI raised for this plan is answered or withdrawn (section 4).

## Appendix A. `reference/logging.md` text (Phase 3, S1)

This revises the v2.1 text (prompt 5, "9) approved") for prompts 5 and 6.
Section 8 is a generalized template: it names no session, no particular run or
machine, no plan and no person (prompt 6, item 19). `<roadmap issue>` is A7's
number.

**A.1 Intent** (replace the Purpose and Scope sentences; check with
`/intent-writing`):

> **Intent**: **Purpose**: Single source of truth for the aitools logging
> standard: where logs live, how they rotate, how paths are formed per
> platform, the log-line format, which code may write logs, and how warnings
> and errors are recorded across the scripts of one run and shown in the
> end-of-run panel. **Scope**: The decided standard and its rationale,
> including the run summary file format and the panel template (section 8),
> and the effect each logging helper has on logs, counts and the run summary
> file. NOT when a script should use which helper, or the script block order
> (`@.claude/rules/script-standards.md` +
> `@reference/script-standards-detail.md`, which point here for the helpers'
> effects). NOT check-vs-setup semantics beyond noting they share the
> directory. **Audience**: Every agent or script that emits logs, and anyone
> changing the logging substrate (`aitools-lib.{sh,ps1}`, `harness-db.py`,
> `ait-harvest.py`, hooks, check-lib).

**A.2 Section 3, table rows** (keep the rest of each cell):
- `deploy.log`: replace "setup scripts (via `aitools-lib`
  `logging_init`/`Initialize-Logging`)" with "every in-scope script through
  `aitools-lib` (`logging_init` / `Initialize-Logging`), including the entry
  points and `build-deploy.sh` (section 8.1)". Keep "the PowerShell `[RELAY]`
  prompt under `hh.ps1` ...".
- `deploy.jsonl`: replace "called by the installers' `log` / `Log` override"
  with "called by the library's `log` / `Log` when the jsonl option is set (the
  installers set it)".

**A.3 Section 5**:
- In "A failed log write is swallowed (the only sanctioned
  silent-suppression in the harness)", add after the parenthesis: "(section
  8.3 extends it to run summary records)".
- Replace the sentence "These log writers outside the lib use the same
  helpers ... the installers' `log` / `Log` override and their Step 22 relay
  sync output (`run_relay_sync` / `Invoke-RelaySync`), the profile resolver's
  `log` / `Log` override, and check-lib's ..." with:

  > The installers' jsonl writing and the profile resolver's stderr console
  > are library options, and check-lib's `checks.log` / `checks.jsonl` writes
  > (`_aitlib_log_append` with the file as its argument; `Write-CheckLogText`
  > in PowerShell) use the same helpers; check-lib's log directory is created
  > fail-safe too.

- Replace the sentence beginning "Not fail-safe yet (open incident #178)" with:

  > The `aitools` entry points and `build-deploy.sh` log through the library
  > (section 8). Not fail-safe yet (open incident #178): the hooks
  > `standing-order-guard.sh` (its log directory and observe-mode line) and
  > `tool-ops-session-audit.sh` (its result line), listed in section 8.1.

**A.4 Section 7**:
- After "Its console log lines go to stderr", add "(the library's stderr
  console option)".
- Replace "`warn` with `log_warn` (counted)" with "`warn` with `write_warn
  <tool>` or `log_warn` (counted, recorded)".
- Replace "`error` with `log_error` (counted)" with "`error` with `write_error
  <tool> <what> <the resolver's error line>` (counted, recorded)".
- Replace "and turns advice the user must act on into one ACTION with one
  counted `log_warn`" with "and turns advice the user must act on into
  `write_action` (one warning that says what to do, and one ACTION)".

**A.5 New section 8** (after section 7, before "Migration status"):

> ### 8. Log entries, warnings and errors across scripts
>
> #### 8.0 Terms
>
> - **Entry point**: a script that starts a run: `aitools`, `aitools install`,
>   `aitools user init`, `build-package.sh`.
> - **Run**: one invocation of an entry point, together with every script it
>   runs.
> - **Child**: a script that an entry point (or another script) runs as a
>   separate script.
> - **Relay**: the library's child runners, which run a child and relay its
>   output: `run_child_relayed` (bash), `Invoke-ChildRelayed` (an in-process
>   PowerShell child) and `Invoke-NativeRelayed` (a native command from
>   PowerShell). Also the captured-output relays `relay_child_log` and
>   `Send-ChildLog`.
> - **Record**: one line of the run summary file.
> - **Panel line**: one line of the end-of-run panel.
> - **Tool**: a name from the tool name table
>   (`@reference/script-standards-detail.md`).
>
> Tool names and script names share one namespace: a script whose name equals a
> tool name is that tool.
>
> #### 8.1 Writers
>
> Setup scripts, entry points, the installers and `build-deploy.sh`, in bash and
> PowerShell, write log entries and run summary records only through the
> `aitools-lib.sh` / `.ps1` helpers (8.2). They define no logging functions of
> their own, and append to no log or run summary file directly.
>
> These writers keep their own logging until the unified-logging roadmap item
> (GitHub issue #<roadmap issue>) is implemented:
> - the hooks;
> - the Python tools (their component logs, section 3);
> - the Perl helpers;
> - `shared/shell/aliases.*` (`clip2md.log`);
> - the check library (`checks.log` / `checks.jsonl`, section 6);
> - the package launcher stubs under `packaging/`;
> - the files that cannot load the library:
>   - the OS-guard lines of `bootstrap.sh` and `hh.sh`;
>   - `relay-outbound-prompt.sh`. The `.ps1` writes through the library when
>     it loads, and otherwise writes nothing;
>   - the truncation guard of the generated `deploy-harness` scripts, which
>     writes one ERROR record by hand before the library loads.
>
> #### 8.2 Helpers
>
> | Helper (bash / PowerShell) | deploy.log | Count | Run summary file |
> |---|---|---|---|
> | `log`, `log_ok`, `log_detail` / `Log`, `LogOk`, `LogDetail` | the line | none | none |
> | `log_warn TEXT` / `LogWarn` | `[warn]` TEXT | warnings +1 | one WARN record, name = the script |
> | `write_warn TOOL TEXT` / `Write-AitWarn` | `[warn]` TEXT | warnings +1 | one WARN record, name = TOOL |
> | `write_action TOOL TEXT ACTION` / `Write-AitAction` | `[warn]` TEXT | warnings +1 | one WARN record and one ACTION record |
> | `log_error TEXT` / `LogError` | `[error]` TEXT | errors +1 | one ERROR record, name = the script, empty reason |
> | `write_error TOOL WHAT REASON` / `Write-AitError` | `[error]` WHAT: REASON (WHAT alone when REASON is empty) | errors +1 | one ERROR record, name = TOOL |
> | `error_reason OUTPUT EXIT_CODE` / `Get-AitErrorReason` | OUTPUT as detail lines | none | none; returns one reason (8.3) |
> | `write_summary OK\|DETAIL\|ACTION` / `Write-Summary` | none | none | the record |
>
> A helper given an empty TOOL uses the logging script's name.
>
> #### 8.3 Rules
>
> - **Recorded at the source.** Each warning and error is recorded once, by
>   the script that logs it. Every script of a run inherits the run summary
>   file, so a parent and its children follow the same rule.
> - **A WARN or ERROR record is one warning or one error**, never a tool's
>   status. A tool's status is its OK record, and it is never recoloured.
> - **Children.**
>   - **Relayed lines.** The relay prints a child's lines. It mirrors the
>     structured lines (`[<time>] [<script>] [<level>] <message>`) to
>     deploy.jsonl. It counts the `warn` and `error` lines, but not the exit
>     footer (`COMPLETED with ...`, `FAILED with ...`), in the child counts.
>     A child's warnings are not added to the parent's warning count.
>   - **A failed child** (non-zero exit, a throw, or error lines with exit 0)
>     is one error of the parent, counted in its error count.
>   - **Recording that error.** The relay records it only when the child
>     recorded no ERROR record while it ran. Otherwise it is logged at error
>     level and counted, but not recorded again.
>   - **Its name** is the summary tool given to the relay. Without one, it is
>     the base name, without extension, of the first argument ending in `.sh`
>     or `.ps1`, else the relay's label.
>   - **Its WHAT** is `<label> failed (exit <N>)`, or `<label> failed
>     (exception)` when an in-process PowerShell child threw.
>   - **Its REASON**, the first that applies:
>     - the exception message (a throw);
>     - `error_reason` over the child's last 20 stderr lines (bash and native
>       children: the relay tees stderr, which still reaches the console), or
>       over the error records it wrote (in-process PowerShell children);
>     - `error_reason` over its last stdout line.
>   - **A user abort (exit 2)** keeps its outcome:
>     - `deploy-harness` aborted: one WARN record (`harness files`, `aborted by
>       user`), and the run stops with exit 2;
>     - any other child aborted: one ERROR record (`<label> failed (exit 2)`,
>       `aborted by user`), and the run continues.
>
>     The child's own abort line is logged and counted, not recorded.
> - **Each script counts its own warnings.** Its exit footer reports its own
>   warning count, and an error count that includes its failed children.
> - **Every error has a reason.** An error states what failed (WHAT) and why
>   (REASON). `error_reason` derives the reason, taking the first of these that
>   applies:
>   1. a known build-failure signature (`diagnose_build_failure` /
>      `Diagnose-BuildFailure`), as `<NAME>: <REMEDY>`;
>   2. the exception message, when an exception is given (PowerShell);
>   3. the first line of the output that matches an error marker:
>      - `error:` or `fatal:`, in any case, at the start of the line or after a
>        space;
>      - `E: ` at the start of the line;
>   4. the last non-empty line of the output;
>   5. `no output (exit <N>)`.
>
>   Before matching, CR, ANSI CSI sequences (`ESC [` ... final byte) and a
>   leading `[<time>] [<script>] [<level>] ` prefix are removed from each
>   line. The full output is logged as detail lines.
> - **What is a warning.**
>   - A warning reports something that is wrong, or that still needs the
>     user. Examples: a tool not authenticated; a managed file left differing
>     after a skipped review; local edits overwritten in a non-interactive run.
>   - A step the user explicitly asked for in the same run, and that completed
>     as asked, is logged at info, not as a warning. Example: an overwrite
>     under `--force`.
> - **Outside a run** (no `AITOOLS_SUMMARY_FILE`), nothing is recorded.
> - **Fail-safe.** A record that cannot be written is ignored, as a log line
>   is (section 5). This extends section 5's one sanctioned silent failure to
>   records.
>
> #### 8.4 Run summary file format
>
> - An entry point that finds `AITOOLS_SUMMARY_FILE` unset creates the file
>   (empty) and exports its path. One that finds it set writes to that file
>   and does not create it.
> - The file is UTF-8, with one record per line and fields separated by `|`.
> - A writer replaces CR and LF in any field with a space, and `|` with `/` in
>   every field except an ACTION's `<instruction>`.
>
> ```
> OK|<tool>|<status>
> DETAIL|<tool>|<detail>
> WARN|<name>|<text>
> ERROR|<name>|<what>|<reason>
> ACTION||<instruction>
> ```
>
> | Field | Meaning |
> |---|---|
> | `<tool>` | A tool name (8.0) |
> | `<name>` | `<tool>` when the writer names one; otherwise the logging script's name |
> | `<status>` | The tool's state when it is fine: a version, `verified`, `n/a (<reason>)` |
> | `<detail>` | One item of the tool's outcome (`added: <item>`) |
> | `<text>` | What is wrong, or what to do |
> | `<what>` | The step that failed |
> | `<reason>` | Why it failed (8.3); empty only for an error recorded by `log_error` |
> | `<instruction>` | The command or step the user must take |
>
> **Reader rules**:
> - For an ACTION record, everything after the second `|` is the instruction.
> - For other kinds, a missing trailing field is empty (so a 3-field ERROR
>   record has an empty reason), and extra fields are joined back with `/`.
> - A record of an unknown kind, or any record other than ACTION with an empty
>   name or tool, is skipped and logged at detail.
>
> #### 8.5 Panel format
>
> **When it is drawn.** The entry point that created the file draws it once,
> at the end of the run, and then deletes it. An entry point that found the
> file already set draws nothing. (`AITOOLS_SUPPRESS_SUMMARY_DISPLAY` is how
> the creator tells a nested installer so.) When `AITOOLS_PRESERVE_SUMMARY=1`,
> a copy is kept as `last-summary.txt` in the log directory. Nothing is drawn
> when the file is missing or empty.
>
> **Notation.** `X*` means zero or more X; `X+` one or more; `[X]` optional;
> `"..."` literal text; `<x:16>` the field padded with spaces to 16
> characters, never cut; `<x:70>` the field cut to 70 characters (below).
>
> ```
> panel         = blank rule green-block yellow-block red-block [action-block] rule
> blank         = an empty line
> rule          = bash: U+2500 x 56; PowerShell: "-" x 60
> green-block   = (green-line detail-line*)*
> yellow-block  = (yellow-line detail-line*)* [more-line]
> red-block     = (red-line detail-line*)* [more-line]
> action-block  = blank action-header action-line+
> green-line    = "  [ok]  " <tool:16> " " <status>
> yellow-line   = "  [!]   " <name:16> " " <text:70> [" (x" N ")"]
> red-line      = "  [ERR] " <name:16> " " <what> [": " <reason>]   (cut below) [" (x" N ")"]
> detail-line   = 26 spaces <detail>
> more-line     = 8 spaces "+" N " more in deploy.log"
> action-header = "  ACTION REQUIRED -- run before tools are ready:"
> action-line   = "  >>  " <instruction>
> ```
>
> **Rules.**
> - **Green**: one line per tool that has an OK record and no WARN or ERROR
>   record under its name. A tool's first OK record gives its position and
>   its status.
> - **Yellow and red**:
>   - every WARN / ERROR record, in file order;
>   - identical records (same name and text; for errors, same name, what and
>     reason) collapse into the first, followed by `(xN)`;
>   - after collapsing, at most 20 lines per section; the rest are counted in
>     one `more-line`.
>   - DETAIL lines do not count toward the 20.
> - **DETAIL lines** follow their tool's first panel line, in its colour. A
>   tool's DETAIL lines are not shown when that line is beyond the cap or does
>   not exist.
> - **ACTION lines** keep file order; identical ones are shown once.
> - **Cutting.**
>   - Lengths and padding count Unicode code points, in every locale.
>   - `cut(s, n)`: `s` itself when it is at most `n` code points long;
>     otherwise its first `n - 3` code points followed by `...`.
>   - A yellow line's `<text>` is `cut(text, 70)`.
>   - A red line, with `w` = the length of `<what>` and `r` = the length of
>     `<reason>`:
>     - with an empty reason, the line is `cut(what, 70)` with no `": "`;
>     - otherwise, if `w + 2 + r <= 70`, both are shown whole;
>     - otherwise `<what>` becomes `cut(what, max(20, 70 - 2 - r))`, and then
>       `<reason>` becomes `cut(reason, 70 - 2 - w')`, where `w'` is the new
>       length of `<what>`. The `": "` separator counts toward the 70.
>   - Green status, DETAIL and ACTION lines are not cut.
> - **Colours**:
>   - bash: green 32, yellow 33, red 31, ACTION bold magenta 1;35 (ANSI);
>   - PowerShell: `Green`, `Yellow`, `Red`, `Magenta`;
>   - a `more-line` and DETAIL lines take their section's colour.
>
> #### 8.6 State and events
>
> | State | Owner | Changed by | Read by |
> |---|---|---|---|
> | `WARNINGS` / `$script:warnings` | each script process | `log_warn`, `write_warn`, `write_action` | exit footer; `read_menu_choice` end-of-input fallback |
> | `ERRORS` / `$script:errors` | each script process | `log_error`, `write_error`, the relay (a failed child) | exit footer (exit 1); fan-out validation |
> | `AITLIB_CHILD_WARNINGS` / `AITLIB_CHILD_ERRORS` (`$script:AitLibChildWarnings` / `$script:AitLibChildErrors`) | the parent, per relayed child | the relay | the relay's failure decision (the error count and the exit code) |
> | Run summary file | the run | the helpers of 8.2; the writers of 8.1 | the panel; the relay (ERROR records written while a child ran); ACTION de-duplication; checks that inspect it |
> | `deploy.log`, `deploy.jsonl` | the log directory (`~/.aitools/logs/`, or `AITOOLS_LOG_DIR`) | the helpers of 8.2; the writers of 8.1 | people, telemetry |
>
> | Event | Effect |
> |---|---|
> | An entry point starts | Creates and exports `AITOOLS_SUMMARY_FILE` unless it is already set |
> | `logging_init` / `Initialize-Logging` | Counts reset to 0; the run summary file is untouched |
> | A warning helper | Logged; warning count +1; one WARN record (plus an ACTION record for `write_action`) |
> | An error helper | Logged, with its reason when it has one; error count +1; one ERROR record |
> | `write_summary` | Its record is appended as written |
> | The relay sees a child's line | Printed; a structured line mirrored to deploy.jsonl; a warn or error line (not the exit footer) adds 1 to the child count |
> | A child fails | Parent error count +1; one ERROR record from the relay only if the child recorded none (8.3) |
> | A child aborts (exit 2) | As 8.3: one WARN record and exit 2 for `deploy-harness`; one ERROR record for any other child |
> | Exit footer | The script's counts; exit 1 when its error count is above 0 |
> | The entry point that created the file ends | Panel drawn (8.5); file deleted; `last-summary.txt` kept when `AITOOLS_PRESERVE_SUMMARY=1` |

**A.6 Cross-references** (add a line):

> - When to use which helper, the tool name table and the severity guide: `@reference/script-standards-detail.md` "End-of-run summary"

## Appendix B. Verification records

- **B.1** v2.0 -> v2.1: ten revisions.
- **B.2** v3.0 -> v3.1: twelve revisions.

**B.3: v4.0 -> v4.1, three independent verifiers** (run in parallel, each
without the others' output or the lead's notes; read-only)
- **5899-1-Verify-words**: against the commander's six prompts, extracted
  from the transcript.
  - Confirmed: every section 1 quote verbatim; the RFI mapping, including the
    "13)" reading; no incident, backup or gate activity; prompt 5's phases;
    prompt 6's demands.
  - 10 findings, all applied:
    - a deletion with no order: removed;
    - a paraphrase shown as a quote: fixed;
    - the scope reconciliation: written, with both quotes;
    - the pasted panel: added to section 1;
    - additions to the confirmed format: marked *(v4)*;
    - B.3 written;
    - the decisions table's "4)" place: given;
    - the timing-budget wording;
    - the #178 wording;
    - RFI 5899-21: closed with evidence.
- **5899-2-Verify-facts**: against the code and the docs.
  - Confirmed: the counts; the root cause; the overrides and appends; the
    renderer facts; the PowerShell names; `error_reason` probed under bash 3.2
    and pwsh 7.
  - 28 findings, all applied:
    - the Python relay sync only prints (not an exception any more);
    - the relay sees no stderr, and most children are not relayed (stderr
      capture added; children moved onto the relay);
    - the relay's own `log_error` would record twice (R5);
    - the name fallback;
    - a PowerShell native relay;
    - merging I1 and I2 together;
    - steps 3 and 12;
    - legacy 3-field records;
    - golden ownership in `profile`;
    - `test-install.sh`;
    - `b8-consumers`;
    - G2 after G3;
    - the truncation guard;
    - the full hook list;
    - the hook fail-safe statement kept;
    - the `[RELAY]` writer kept;
    - streamed output;
    - one reason order;
    - `error_reason` calls the signature;
    - anchored markers;
    - empty reasons;
    - the missing documents and the 30-character rules;
    - the files that cannot load the library;
    - unassigned scripts;
    - the twins' bug differences;
    - the ACTION counts;
    - CI steps;
    - minor naming.
- **5899-3-Verify-spec**: Appendix A as a spec, and the order.
  - Confirmed: the phase order; no gates; no session or run references; the
    padding and colours match the renderers.
  - 21 spec findings and 12 order findings, all applied except one question
    (RFI 5899-23):
    - the relay double record and the parent's exit code;
    - who writes the detail output;
    - one reason grammar;
    - the signature format;
    - the empty-reason grammar;
    - the cut algorithm and unit;
    - red collapse;
    - the cap and DETAIL lines;
    - DETAIL colour;
    - formal notation and the leading blank line;
    - reader rules;
    - the 8.1 scope (check-lib, aliases, guards);
    - the Intent rewritten;
    - A.3 keeps the hooks as not fail-safe and updates the override sentence;
    - section 7's `log_error` bullet;
    - the 8.6 readers and events;
    - name collision;
    - defined terms;
    - A.2 keeps the rest of the cell;
    - structural acceptance for O1;
    - ten more tests;
    - S1's dependencies;
    - the draft PR in Phase 1;
    - I6-I8 in parallel;
    - the build-deploy and G3 coupling;
    - cross-group goldens;
    - the red-CI window (switch and legacy records);
    - the new step's schedule;
    - delegates loading old rules;
    - missing documents (D4);
    - A2 split per group;
    - the shared fixture;
    - the tool-lifecycle gate (A8, RFI 5899-24).
**B.4: v4.1 -> v4.2, two fresh verifiers** (each new, read-only, without
the first round's reports)
- **5899-4-Reverify-words-facts**: against the six prompts (quotes re-checked
  character for character, including the pasted panel) and the repository.
  - Confirmed: every B.3 fix, except two that the body did not name (now
    named).
  - Findings applied:
    - **Words**:
      - the warning demotion had no order: removed, now RFI 5899-25;
      - the phase moves are now stated deviations (section 0);
      - the reading of "run" is stated;
      - RFI 23 now covers the cut too;
      - "skips only 14" corrected to "14 and 20";
      - a paraphrase replaced by the exact rule text;
      - RFI 5899-22 closed as withdrawn.
    - **Facts**:
      - 25 Intune warnings, not 23 (the earlier count came from a truncated
        log read);
      - #178 kept on the hooks clause;
      - only `relay-outbound-prompt.sh` cannot load the library;
      - the entry points must honour an existing summary file (G1);
      - the wrapper count is 66;
      - the green count;
      - the 5.3 "before" row;
      - the 5.5 example;
      - G1's Windows branch.
    - **Consistency**:
      - I0's and I3's prerequisites;
      - S1b;
      - A2's library slice;
      - L5 and L8;
      - the relay event;
      - the untracked plan copy (RFI 5899-26);
      - `b8-consumers` named;
      - the package launchers.
- **5899-5-Reverify-spec-order**: Appendix A, and the order.
  - Confirmed: A.2-A.4 match the current `logging.md` verbatim; the renderer
    facts; the phases; no gates.
  - Findings applied:
    - **The relay**:
      - the PowerShell in-process child's reason (a throw, then its error
        records);
      - the reason input order (stderr first, teed);
      - the name fallback defined;
      - the user-abort rule (keeps today's outcome);
      - the five relay functions named, the structured-line mirroring, the
        footer not counted, the PowerShell state names.
    - **Panel and file rules**:
      - one rule for creating and drawing the file;
      - an explicit cut algorithm;
      - the red example taken from the grammar;
      - code points in every locale, with an implementation note;
      - `relay-outbound-prompt.ps1`;
      - empty-name, empty-reason and CSI-only rules;
      - the "only sanctioned" sentence;
      - the `log_warn` wording in section 7;
      - the usage sentence moved out of 8.2;
      - green keeps today's first-OK rule, and the ACTION de-duplication is
        listed and tested;
      - ACTION instructions keep `|`.
    - **Order and dependencies**:
      - S1b applies A2's markers, which also covers pip's `ERROR:`;
      - I0 and I3 prerequisites, and I0 merged before I1b;
      - A8: the delegates verify and the lead records;
      - the `STRICT_SUMMARY` report-to-fail switch;
      - I1b covers inline test expectations;
      - delegates launched before D1 follow section 8 alone;
      - I8 runs with stub-only `PATH`;
      - a push after each group merge;
      - the phase moves stated as deviations;
      - S1 earlier, with placeholders;
      - G2 split into G2a and G2b (G2b also after G4b);
      - I6 uses the pty harness.
    - **Tests**: L28-L31 added.
**B.5: v4.2 -> v4.3, the commander's prompt 7 answers**
- 20) yes: the new helpers, and `write_summary WARN` / `ERROR` retired.
- 23) the cut and the cap apply to yellow and red only.
- 24) A8 covers only the two bug fixes; logging-only edits are exempt.
- 25) Warnings about a step the user explicitly asked for are demoted, under a
  narrow rule (`logging.md` 8.3 "What is a warning") and test L32. The lead
  judged the scope small: the rule, one test, A2's list, and one line per site
  in the groups. Skips and non-interactive overwrites stay warnings.
- 26) No action on the untracked plan copy.
- New RFI 5899-27: how wide the `setup-go.sh` fix is.

**B.6: v4.3 -> v4.4, prompt 8 ("27) the broader fix for this plan/pr")**
- Read-only checks on the machine that produced the pasted run gave the
  causes:
  - `SHELL=/bin/zsh`;
  - the PATH block is in `~/.bash_profile` only, not `~/.zprofile`;
  - `~/go/bin` does not exist;
  - `GOPATH` is unset.
- Issue 2 is restated with these causes and the broader fix.
- I0 gains `setup-user-shell.sh` and its test suite.
- 2.2 and O1: `go` stays green and the Go ACTION goes, leaving four ACTION
  lines.
- `reference/ait-shellintegration.md` is added to D3.
- Section 14 is now empty.

**B.7: v4.4 -> v4.5, the assumption review (prompts 9 and 10)**
- **The Go cause was wrong in v4.4.** B.6 recorded "the PATH block is in
  `~/.bash_profile` only, not `~/.zprofile`", read as "zsh never sees the
  block". But `~/.zprofile` line 5 is `source ~/.bash_profile`, and `$PATH`
  confirms the block runs.
  - The earlier grep looked for the block's marker, not for a `source` line.
  - The only cause is the block's existence check on a missing `~/go/bin`.
  - Issue 2 is restated, and its fix is the Go line only (prompt 10, "rfi 28").
- The answers and the resolved assumptions are applied: Appendix D.

**Lead's own check of v4.2**:
  - every round-2 finding was spot-checked against the code before it was
    applied: the summary-file reset in `scripts/aitools`, the library loading
    in `relay-outbound-prompt.ps1`, the 25-warning count, the wrapper count;
  - each was then edited in place.

## Appendix C. Order and parallelism

| # | Item | Placement |
|---|---|---|
| C1 | The PR number is needed by A7 and gives Windows CI | Draft PR at the end of Phase 1, step 1 (deviation 1) |
| C2 | S1 needs A1 (8.1 exceptions); A2's markers and A7's number can follow | S1 after A1, with placeholders; S1b after A2 and A7 (deviation 3) |
| C3 | I1 and I2 depend only on S1; I0 also needs A4, A5 and A8 for its tools | I1 and I2 after S1, alongside S2; I0 as soon as its prerequisites are done |
| C4 | Step 13 fails on the new `write_summary` | I1 and I2 merged together, then one push |
| C5 | The promotion's removal changes test expectations everywhere | I0 merged first; then I1b updates goldens and inline expectations before I3, so CI is green |
| C6 | Half-migrated scripts must not double-record | The switch is off and the legacy records kept until I5 |
| C7 | build-deploy's own logging is independent; its generated code embeds G3's and G4b's scripts | G2a alongside the other groups; G2b after G2a, G3 and G4b |
| C8 | Cross-group suites would conflict | Regenerated only once, in I5, after every group has merged |
| C9 | The bug fixes touch no core file | I0 alongside I1 |
| C10 | A2 is the largest inventory | One delegate per group |
| C11 | Parity between the two languages | One shared fixture before I1 |
| C12 | I6, I7 and I8 need only I5 | In parallel, each under its own `HOME` |
| C13 | Release notes describe the final state | Phase 5 |
| C14 | The issues are cited by I0's commits and by S1b | Filed in Phase 2 (deviation 2) |
| C15 | Windows CI per group | The lead pushes after each merge |

Critical path:

> Phase 1 (draft PR) -> A1 (with A2, A3, A4, A7, A8 running) -> S1 -> [D1-D4, fixture, I1-bash, I1-ps1, I2; I0 once A4, A5, A8 are done; S1b once A2, A7 are done] -> merge I0, then I1 and I2 together; I1b -> G1, G2a, G3, G4a, G4b (parallel) -> G2b -> I5 -> I6, I7, I8 (parallel) -> Phase 5

## Appendix D. How the assumption review shaped v4.5

Prompt 9 asked for every assumption behind the plan that would change its
content. Prompt 10 answered the open ones. Each row below gives the
assumption, how it was settled, and what changed.

| # | Assumption (v4.4) | Settled by | Result | Change in v4.5 |
|---|---|---|---|---|
| D1 | zsh never reads the managed PATH block, so the Go fix must write the block into `~/.zprofile` | Reading `~/.zprofile` and `$PATH` on the machine | False: `~/.zprofile` runs `source ~/.bash_profile`. Prompt 10: "we dont manage zsh so just leave as is" | Issue 2's cause and fix restated (section 4); the fix is the Go line only; no zsh profile, zsh test cases or zsh issue (I0, section 6) |
| D2 | Issues go to "the aitools repo" | `git remote -v` | `nobul-tech/aitools` | Named in A5 and A7 |
| D3 | Issues can carry a roadmap label | `gh label list` | No `roadmap` label exists | `bug` for issues 1 and 2; `enhancement` for the roadmap issue (A5, A7) |
| D4 | Every suite has a golden-file update path | grep the suites | `UPDATE_GOLDEN` exists in about 19 suites; the others assert inline or have no update mode | `UPDATE_GOLDEN=1` where it exists; hand edits elsewhere, each line listed (I1b, I3, I5) |
| D5 | The repository's checks do not apply to the plan's text | `scripts/check-path-refs.py` | It skips `plans/` but scans `reference/` | S1 and every D-delegate run it, so the new `logging.md` paths resolve |
| D6 | The next release is a minor bump from the panel's `0.74.0` | The release notes and the merged PRs; prompt 10: "75 is not correct" | The newest release is v0.77.25 (PR #183); the tags and `git describe` lag behind | Phase 5 reads the newest release-notes heading on `origin/main` and the merged PRs at ship time; v0.78.0 as of 2026-11-15 |
| D7 | Capturing a child's stderr is invisible to the child | The relay design; `build-deploy.sh` checks `[ -t 2 ]` | The child's stderr stops being a terminal, so stderr colour and progress bars disappear | Kept, and stated as limit 5 in 5.5 |
| D8 | The panel prints only to the user's terminal | The package path | `build-package` runs `aitools-install`, so the panel also lands in the installer's log, which MDM collects (the package path is a scaffold today) | Limit 4 in 5.5 corrected |
| D9 | Moving children onto the relay keeps menus working | Where prompts are written | Holds: prompts go to `/dev/tty` and `[Console]`; deploy-harness already runs on the relay | A review menu is answered through the relay in the I6 pty run |
| D10 | One session can run the whole plan | Prompt 10: "lets assume a single session can, the lan should instruct the executing agent to delegate as much as possible" | Assumed true | Section 0: the lead orchestrates and reviews; every other step is delegated; A5, I1b and I5 now name their delegates |
