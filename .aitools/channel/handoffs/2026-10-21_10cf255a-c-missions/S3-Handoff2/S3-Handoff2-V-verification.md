# S3-Handoff2-V: verification of handoff 2026-10-22_10cf255a-c (v1)

**Verifier:** S3-Handoff2-V, delegated by S3-Handoff2 (Session Commander 10cf255a-c). Read-only on repo files.
**Checked:** 2026-10-22 local / 2026-10-23 UTC, about 1 hour after the handoff was written (02:16Z).
**Inputs read in full:** the handoff (`.aitools/channel/handoffs/2026-10-22_10cf255a-c.md`), `MF/S3-Handoff2/S3-Handoff2-S2-session-state-audit.md`, `plans/tool-support-and-machine-profile.md`, the prior handoff `2026-10-21_360aa8f3-8.md`, `MF/SC-mission-packet.md`, `~/.claude/rules/delegation.md`, `~/.claude/skills/handoff/SKILL.md` (Step 5).
**Probes:** `.scratch/session-ho2v/check-paths.sh` (55 paths) and `.scratch/session-ho2v/inc.py` (incident states), in the ho10cf worktree scratch. They are one-off probes and need not be preserved.

## Verdict: NEEDS AMENDMENTS

The handoff is accurate and well layered. Every fact I spot-checked holds (table below). It has no structural problems, so it does not need a rewrite. But a fresh agent would get stuck at three points in the first wave:
1. Who merges the PRs.
2. How to tell whether the two "running" missions are still alive.
3. How to re-land #74/#75 without a force-push. #71 was squash-merged, and the remote stacked branches have moved.

Beyond those three, it has broken thread references in section B, a thread-number collision with the prior handoff, and one false fact (the main checkout is "clean").

| # | Criterion | Result |
|---|---|---|
| 1 | Self-containment | NEEDS AMENDMENT |
| 2 | Reference integrity (incl. lifecycle) | PASS (one lifecycle note) |
| 3 | Reading order | PASS |
| 4 | Scope governance | PASS (one optional note) |
| 5 | Completeness vs the audit | NEEDS AMENDMENT (minor gaps) |
| 6 | Consistency (internal and with the prior handoff) | NEEDS AMENDMENT |
| 7 | Claude Code operational correctness | NEEDS AMENDMENT |
| 8 | Ambiguity scan | NEEDS AMENDMENT (3 High) |
| 9 | Barrier test | NEEDS AMENDMENT |

## Fact spot-checks (all against gh/git at verification time)

| Claim (handoff section) | Check | Result |
|---|---|---|
| #74 base `fix/registry-paths`, #75 base `feature/user-level-skills`, both merged (D.2) | `gh pr view 74/75 --json baseRefName,mergedAt,mergeCommit` | Confirmed. #74: 04:24:16Z, merge commit 66e680f. #75: 04:24:26Z, f61d6fc. `git merge-base --is-ancestor 66e680f origin/main` exits 1 |
| 7 governance skills still in `.claude/skills/`; `shared/skills/{aitool-ops,aitool-eval}` exist (D.2) | `git ls-tree -d 8a9dcb5 .claude/skills/ shared/skills/` | Confirmed. `~/.claude/skills/` has none of the 7 |
| Open PRs #97-#100, all base `main` (D.4) | `gh pr list --state all --limit 15` | Confirmed. **Moved since write time (not a defect):** #101 `docs/m3-approved-drafts`, #102 `docs/mf-incidents` ("File M3 incidents #146-#161"), and #103 `fix/mf-dotprofile-adopt-push` are now open, all base main |
| Latest tag v0.73.2; v0.73.3 notes untagged (C, G9) | `git tag --list "v0.7*"`, `RELEASE_NOTES.md:15` | Confirmed |
| Dotprofile 825aed4 has no `deploy/deploy-harness.*` (D.1, G8) | `git show --stat 825aed4` | Confirmed: 42 `deploy/setup-*` files plus profile.json. It also has **no `deploy/setup-user-config.*`**, which supports "predates #93's output". Committed 01:59:05Z, 89 s after #93 merged |
| Main checkout 105 behind, HEAD 638d3ee (A, G6) | `git rev-list --left-right --count main...origin/main` | `0 105`, confirmed. **"it is clean" is false**: see A-4 |
| #96 merged with no comments or reviews (E1) | `gh pr view 96 --json comments,reviews,mergedBy` | 0 comments, 0 reviews, merged by nobul-jose. Confirmed |
| 95b9805 is the only written approval (E1) | `git log -1 95b9805`, `merge-base --is-ancestor 95b9805 origin/docs/harness-approved-drafts` | Exists, and it is on #99's branch (exit 0). The body says "commander approval 2026-10-22 (S3-Harness2 launch decisions)" |
| 23 claimed-fixed incidents still open; #144 correctiveAction stale (G5) | `inc.py` on `registries/incidents.json` (3,453 lines) | All 24 listed ids are `open` (23, plus #112 pending #99). #144 still says "PR #60 (open)". Highest id 145. Confirmed |
| #85 edited `.claude/skills/tool-ops/SKILL.md` and `shared/skills/aitool-ops/SKILL.md` (E1) | `gh pr view 85 --json files` | Confirmed |
| #99 Follow-ups: 3 allowlist lines, 2 held paragraphs, the `.mdc` twin to confirm (D.4) | `gh pr view 99 --json body` | Confirmed |
| Dotprofile has an uncommitted `claude/CLAUDE.md` (G3) | `git -C ~/repos/aitools-nobul-jose status`, `log` | **Moved since write time:** the commander committed it as 525ee49 at 02:14:05Z (19:14 local, "Sync CLAUDE.md template with shared and repair aitools links"). Only `sessions/.DS_Store` is dirty now |
| No CI for `tests/deploy-harness` (G16) | grep `.github/workflows` for deploy-harness | No hits. Confirmed |

## 1. Self-containment: NEEDS AMENDMENT

The decisions in D.3 are inline and specific enough to act on. Section E's first actions are concrete. Missing:

- **S-1. Merge authority is never stated.** E step 2 says "Land the in-flight PRs". Every session PR was merged by `nobul-jose`. The `main` ruleset (16468370 "Reibung") now has only `deletion` and `non_fast_forward` rules and no required approval (`gh api repos/nobul-tech/aitools/rulesets/16468370`). That makes this a policy question the ruleset does not answer. See A-1 for the fix.
- **S-2. The binding plan names superseded artifacts.** A fresh agent reading the plan (reading order 2) will hit names the code no longer uses:
  - N-Q1 says "aitools-profile.js exception-set / exception-get".
  - P-Q6 says "profiles.<alias>.googleDrives".
  - The prior handoff, which the plan cites, describes an `aitools-registry.py` resolver and `shared/registries/`.

  The handoff uses the correct current names but never says the plan text is superseded there. See A-9.

## 2. Reference integrity: PASS

I checked 55 paths with `check-paths.sh` against the ho10cf worktree (origin/main 8a9dcb5). All exist except these four, and the handoff explains each one:
- `MF/S3-M3Lead/S3-M3Lead-plan.md`: on #97's branch, as B says. It exists in worktree `m3lead`.
- `MF/S3-Profile/S3-Profile-Review3-pr79-80-82.md`: untracked in `m3lib`, as F4 says. It exists there.
- `S3-M3-Migrate`: a mission name, not a path.
- `tests/rules-fanout/`: future work (G12).

The dotprofile `claude/rules/delegation.md` exists. `scripts/aitools-json.pl` still contains `DRAFT` (G2). `reference/tool-ops-claude-code.md:17` still says "Current version: 2.1.81" (G.5).

Lifecycle:
- The handoff, `MF/S3-Handoff2/` and `.aitools/channel/relay.md` (modified) are **untracked or uncommitted in ho10cf** (`git status --short`). They survive only through S3-Handoff2's PR, so that PR must include all three (A-12).
- The audit's 1C method cites `S3-Handoff2-S2-drafts.sh` and `-grep.sh` "in this scratch dir" (`ho10cf/.scratch/session-ho2/`). Worktree scratch is never harvested and is deleted when the worktree is removed (S3-SR-4). Copy them into `MF/S3-Handoff2/` (A-12) or accept that they will be lost.
- The handoff itself never cites a scratch path. Good.

## 3. Reading order: PASS

The order is: handoff (situation and actions), the binding plan, the packet (rules), the audit (depth), the tree (M2 design), then the prior handoff (provenance). It builds context progressively and has no circular dependencies. One optional addition (A-10): the packet tells a mission *commander* to read all of `reference/*.md`. The handoff does not say whether the accepting session counts as a commander for that purpose.

## 4. Scope governance: PASS

- There is exactly one Schwerpunkt: ship v0.74.0 from an integrated main. It is compound but has one end state. The "why not M2" rationale is explicit.
- The 9 hard exclusions each have specific rationale, and the 3 soft exclusions are bounded.
- The boundary between do-now and defer is clear: G.4 is DEFERRED and F5 forbids M2 code.
- Optional: say whether the commander confirmed this Schwerpunkt or S3-Handoff2 proposed it (the `/handoff` Step 1). J says the assessment was S3-Handoff2's own.

## 5. Completeness vs the audit: NEEDS AMENDMENT (minor)

Section 0 items 1-5, every PR in 1A, the 1B decisions, 1D, 1E.1-1E.11 and the metrics are all represented. Missing:

- **C-1. PR #54 follow-up.** The dotprofile `claude/rules/delegation.md` element-2 wording is drafted "waiting on commander approval". Its location is unknown and so is whether it was applied (audit 1C last rows, Unknowns). It is not in G2 or G.5.
- **C-2. S3-M3-Audit** (the read-only audit of all of M3, `S3-M3Lead-plan.md:91` on #97's branch): the audit lists it as "Not run". The handoff mentions only mf-audit's "M3 logging audit". Whether the two are the same is unknown.
- **C-3. The installer relay-helper switch** that Hookin owns (audit 1E.3, `S3-M3-LibKey-report.md:51,:88`) is missing from G11.
- **C-4. Operational learning from audit 6 that is not in I:**
  - "the isolated-HOME rule does not cover the cwd: a relative path from config.json writes into the agent's cwd" (`S3-M3-UserInit-report.md:98`).
  - "my first pre-commit invocation used a relative path, so it ran against the main checkout" (`S3-SpecRewrite-report.md:34`).
- **C-5. G.5 omits** N-Q6 scope (PR #78 follow-up) and SpecRewrite Q9/A1 wording (audit 1E.7).

## 6. Consistency: NEEDS AMENDMENT

- **K-1. Section B cites wrong thread ids.** "M2 tool support (G8)" should be **G18**; G8 is the dotprofile `deploy/` rebuild. "Logging (G10)" should be **G20**; G10 does not exist (the numbering jumps from G9 to G11).
- **K-2. Thread ids collide with the prior handoff.**
  - G.6 uses the prior handoff's G1-G17 ("G7/G8 (PR-b/c)", "G15 (machine ids)").
  - E step 6 says "(G15 from the prior handoff)", while this handoff's own G15 is the Cursor canary and its G7 is Windows.

  A reader cannot tell which G7 or G15 is meant.
- **K-3. Section H's "Fan-out" entry reads as present fact for setup-user-claude.** On main only the Cursor fan-out shipped (#87). The setup-user-claude fan-out is G12 (in flight, needs Q1). #99's body says the same: "`setup-user-claude` has no `~/.aitools/rules` fan-out on main".
- **K-4. G9 says "BLOCKED (G1-G8)", but E step 2 also lands the in-flight PRs first** (G11-G13 belong to HARNESS-2). Which threads block the release is ambiguous.
- **K-5. F2 ("approved ... on #96/#99 counts") contradicts #99 itself.** #99 marks the `.mdc` twin "please confirm" and holds 2 paragraphs for re-approval.
- **K-6. G2 is "READY (partly in flight)" while F6 says do not interfere with HARNESS-2 worktrees.** E step 2's "apply the 3 allowlist lines" to #99 means editing a HARNESS-2 branch.
- **K-7. A cites only `managed-file-deployment.md` for the managed-file model.** The authoritative text is `.claude/rules/agentic-standards.md` "Managed-file review choices and merge" (line 47; the mfd rule at line 27 points to it). The packet section 6 names agentic-standards.md too.
- Prior handoff: the handoff correctly supersedes F1 (9 copies: G6 done), SD-6/SD-7 (raw ids, `profiles.<machineId>`) and the `/delegate`-not-deployed note (now deployed: `~/.claude/skills/delegate`). Its staleness commands are compatible. Apart from S-2/A-9, I found no other conflict.

## 7. Claude Code operational correctness: NEEDS AMENDMENT

Present and correct:
- WRITE_BLOCKED.
- The subagent context gap.
- Agent tool, not workflows; level-3 delegates have no Agent tool.
- `gh pr review --comment` and GitHub's refusal of `--request-changes` from the same account.
- standing-order-guard, CRLF in `.ps1` files, worktree removal deleting ignored files, the 10-character scratch name.
- `dot-claude/` (nested-skill hazard).

No non-existent Claude Code feature is assumed. Missing:

- **O-1. Missions do not outlive the session that launched them.** M3-FINISH and HARNESS-2 are Agent-tool missions of Session Commander 10cf255a-c (packet section 3). When that session ends, they stop wherever they are, possibly mid-edit (mf-adopt, h2-draftsm3b and h2-manifest had uncommitted edits at write time). D.4 and F6 assume they may still be running, but give no way to tell.
- **O-2. The accepting session's own skills.**
  - Started in the main checkout, it loads the 105-commits-old `.claude/skills/` as well as the old rules. A only mentions rules.
  - Once #74 is re-landed, the 7 governance skills leave `.claude/skills/` and are absent from `~/.claude/skills/` until the commander runs `aitools`. `/incident` (E step 5, after step 3) will not load. The packet section 2 fallback (Read the SKILL.md and follow it by hand) applies.
- **O-3. Grep and Glob are not always provisioned to delegates.** This verifier had neither. The prior handoff recorded it (its G17(3)). The packet tells delegates to "use Read/Grep".
- **O-4. Waiting.** I says "run a scratch script with an `until` loop". The audit's recorded workaround was the **Monitor** tool (`S3-Incidents-report.md:32`). The Bash tool also blocks a foreground `sleep`. Name Monitor.

## 8. Ambiguity scan: NEEDS AMENDMENT

**Pass 1 (undefined terms, vague instructions, unclear references)**

| Sev | Where | Finding |
|---|---|---|
| High | E2, E3 | Who merges (S-1) |
| High | D.4, F6, E2 | "while they run" / "in flight" has no liveness test (O-1) |
| High | E1, E3, G1, B | "open a new PR per branch, rebased on main": the branches cannot be rebased without a force-push. See barrier step 3 |
| Medium | B | G8 and G10 refs (K-1) |
| Medium | F2 | Scope of "approved on #96/#99" (K-5) |
| Medium | G9 | Which threads block the release (K-4) |
| Medium | G3, E4 | "Needs `aitools user init` on nobul-mac": F1 forbids agents from running `aitools`, so the commander runs it. Not stated |
| Medium | A | "(it is clean)" is false (A-4) |
| Low | E1 | "commit 95b9805": no location given (it is on #99's branch `docs/harness-approved-drafts`) |
| Low | J | "verification by an independent delegate (S3-Handoff2-V, see below)": nothing below |
| Low | D.2, G2 | Codes (SD-8-ext, S2L-QA, T-Q9, E-paths-PRb, R-rows, B10) resolve only through the plan or the audit. Acceptable for an agent reader; keep them out of commander-facing questions (E1 already does) |

**Pass 2 (multiple meanings, naming collisions)**

| Sev | Where | Finding |
|---|---|---|
| Medium | G.6, E6 | Thread G-numbers shared with the prior handoff (K-2) |
| Medium | Plan vs D.3 | `aitools-profile.js` vs `aitools-profile.sh/.ps1`; `profiles.<alias>` vs `profiles.<machineId>` (S-2) |
| Low | D.4 | Missions named by worktree, PRs named by number; branch names absent. A fresh agent seeing #101-#103 cannot map them without `git worktree list` (A-6) |
| Low | H | "Fan-out" present vs in flight (K-3) |

## 9. Barrier test (first wave of section E): NEEDS AMENDMENT

I simulated a fresh agent in a new session, cwd `~/repos/aitools`.

- **Step 0, re-assess.** The four commands run as written. The agent sees #101-#103, which D.4 does not name. The worktree list (50 worktrees) does map them, but only by inference. *Friction (A-6).* The agent cannot tell from the handoff whether M3-FINISH and HARNESS-2 are alive. *Stuck (O-1, A-2).*
- **Step 1, ask the commander.** The four questions are clear and each has a suggested answer. **Executable.** The "re-land" suggestion promises something step 3 cannot do as written (below).
- **Step 2, land the PRs.**
  - It is unclear whether the agent merges or asks the commander to. *Stuck or risky (S-1).*
  - "Apply the 3 allowlist lines" to #99 collides with F6 if HARNESS-2 is alive (K-6).
  - The rebase order across `setup-user-claude.*`, `setup-user-config.*` and `deploy-harness.*` is stated. **Executable.**
- **Step 3, re-land #74/#75.**
  - On origin, `feature/user-level-skills` is now at **f61d6fc** (PR-b plus PR-c merged in) and `fix/registry-paths` at **66e680f**, not ed1b75c and 2375fea. Those two exist only as the remote `refactor/retire-reference-cards` head (2375fea) and the local worktree `layout-b` (ed1b75c).
  - #71 was **squash-merged** (6dc9c99, one parent). The stack therefore still carries PR-a's 4 original commits: 0db8cc9, 24b56d3, 01355d5, 63ce030.
  - "Rebased on main" means rewriting a pushed branch, and F7 and D-DEL4 forbid force-push. Pushing `layout-b` to `feature/user-level-skills` would be non-fast-forward, and the ruleset blocks that.
  - Conflicts go beyond #85 and #71: #99 item (a) edits `.claude/skills/tool-ops/SKILL.md` (the Intent Scope), and if #99 lands first (E step 2), the move must carry that edit.

  *Stuck without the amendment (A-3).*
- **Step 4.** B10 needs `aitools user init` on the real HOME, which F1 forbids for agents. *Friction (A-7).* G3's dotprofile-dirt precondition has since been resolved by 525ee49.
- **Step 5.** If step 3 has merged, `/incident` is not loadable (O-2). The fallback works if the agent knows it (A-8). Id selection is covered by F8. #102 now claims #146-#161, so new filings start at #162 if #102 merges. The handoff's "(or after whatever mf-inc filed)" covers this.

## Required amendments (S3-Handoff2 applies these)

**A-1 (High; E step 2).** After "Land the in-flight PRs", insert:
> **Merging is the commander's.** The accepting session prepares each PR (base is `main`, rebased, reviewer verdict posted as a PR comment, checks recorded). It then asks the commander to merge, in batches, in the order below. Agents and delegates never merge. The `main` ruleset (16468370) only blocks deletion and non-fast-forward pushes, so nothing technical stops an agent merge; this is policy.

**A-2 (High; D.4 heading, and F6).**
- Change D.4's heading to "In flight at write time (check whether each one is still alive before touching it)" and add under the table:
  > These missions were Agent-tool delegates of Session Commander 10cf255a-c and stop when that session ends. Treat a mission as **stopped** when the Session Commander session has ended, or when its worktree has no new commit and no file change for 2 hours (`git -C <worktree> log -1 --format=%cI`, `git -C <worktree> status --short`). For a stopped mission, read its uncommitted diff and its hand-back. Then finish the work in the **same worktree and branch** with a fresh delegate (D-DEL4), or report it to the commander. Never remove the worktree (F4).
- Change F6 to:
  > Do NOT interfere with M3-FINISH or HARNESS-2 worktrees and branches while they are alive (D.4 has the test). Read-only inspection is fine. Once one has stopped, take it over in place, as D.4 says.

**A-3 (High; E step 1 first bullet, E step 3 and G1).**
- E1 first bullet, replace from "Suggested yes" to the end of the bullet with:
  > Suggested yes. Re-land on **new** branches off `origin/main`; never rebase or force-push the old ones. `feature/user-level-skills` is now f61d6fc on origin (PR-b plus PR-c) and `fix/registry-paths` is 66e680f. #71 was squash-merged (6dc9c99), so the stack still carries PR-a's original commits 0db8cc9, 24b56d3, 01355d5 and 63ce030: drop them. Cherry-pick PR-b's commits 4aa4728, 1b34195 and ed1b75c onto `feature/user-level-skills-reland`, and PR-c's commits 6d3cacf, 7b45433 and 2375fea onto `refactor/retire-reference-cards-reland` (stacked; retarget it to `main` when the first merges). Expect conflicts with #71's step numbering and with #85, which edited `.claude/skills/tool-ops/SKILL.md` and `shared/skills/aitool-ops/SKILL.md`. Expect one with #99 item (a) too, if #99 lands first: it edits the tool-ops SKILL.md Intent, which then moves with the skill. One delegate, with an independent reviewer.
- G1 "Needed" column, change to:
  > New PRs from new branches cherry-picked onto origin/main (E step 1). Then the commander runs `aitools` on every machine (PR #74 "ACTION after merge"). Until then, the 7 skills are not loadable at either level (I).
- Section B row "Re-land LAYOUT PR-b/c (G1)", change the branch text to:
  > branches `feature/user-level-skills` (now f61d6fc on origin; PR-b head was ed1b75c, still in worktree `layout-b`) and `refactor/retire-reference-cards` (2375fea)

**A-4 (Medium; A "Main checkout warning").** Replace "(it is clean, and `main...origin/main` = `0 105`)" with:
> (`main...origin/main` = `0 105`, a fast-forward. The working tree has local harvesting changes that origin/main does not touch: `M harvesting/harvest-manifest.json` and untracked `harvesting/2026-10-23_session-f486b184-c_*` files. `git pull --ff-only` works; the commander decides whether to commit them through `/harvest`)

Then add this sentence:
> Skills load from it too: its `.claude/skills/` are the pre-session versions.

**A-5 (Medium; section B and G.6, E step 6).**
- B: "M2 tool support (G8)" becomes "M2 tool support (G18)"; "Logging (G10)" becomes "Logging (G20)".
- G.6: prefix every prior-handoff thread with `P-` (P-G1 ... P-G17) and add a lead sentence:
  > Prior-handoff threads are written P-G1..P-G17 to avoid collisions with this handoff's G-numbers.
- E step 6: "(G15 from the prior handoff)" becomes "(P-G15)".

**A-6 (Low; D.4 table).** Add the branch to each worktree:
- `mf-adopt`: `fix/mf-dotprofile-adopt-push`
- `mf-nomach`: `feature/mf-config-no-machine` (#98)
- `mf-audit`: `docs/mf-audit`
- `mf-inc`: `docs/mf-incidents`
- `h2-hookin`: `feature/harness-hookin`
- `h2-manifest`: `feature/harness-rules-manifest` (#100)
- `h2-draftsh`: `docs/harness-approved-drafts` (#99)
- `h2-draftsm3`: `docs/m3-approved-drafts`
- `h2-draftsm3b`: `docs/m3-approved-intents`
- `m3lead`: `docs/m3-lead-plan` (#97)

**A-7 (Medium; G3 "Needed", E step 4).** G3: "Needs `aitools user init` on nobul-mac" becomes:
> Needs the **commander** to run `aitools user init` on nobul-mac (F1: agents never run it against the real HOME)

E4: append:
> (the commander runs `aitools user init`; the session prepares and verifies)

**A-8 (Medium; section I, new bullets).**
> - **Delegates sometimes lack Grep and Glob.** Tell them to use Bash `grep`/`find` in pipelines or scratch scripts when those tools are absent (S3-Handoff2-V had neither).
> - **Skills after the re-land.** Once #74 merges, the 7 governance skills are missing at both levels until the commander runs `aitools`. Read `shared/skills/<name>/SKILL.md` and follow it by hand (packet section 2). Better: finish G5 (`/incident`) before the re-land merges.
> - **Waiting:** use the Monitor tool with an until-loop. A foreground `sleep` and an inline `until ...;` are blocked.
> - **Relative paths escape isolation.** A relative path in `config.json` writes into the agent's cwd under an isolated HOME (S3-M3-UserInit-report.md:98). A relative-path check script ran against the main checkout (S3-SpecRewrite-report.md:34). Run checks from the worktree, by absolute path.

**A-9 (Medium; section H, new bullet).**
> - **Superseded names you will meet in the plan and the prior handoff:**
>   - `aitools-profile.js` is now `scripts/aitools-profile.sh/.ps1` (P-Q3).
>   - `profiles.<alias>` is now `profiles.<machineId>` (M3Lead decision 5), including P-Q6's googleDrives.
>   - The `aitools-registry.py` resolver and `shared/registries/` were dropped (SD-8-reg).
>   - Hashed `machine.id` is now raw ids (P-Q2).

**A-10 (Medium; H "Fan-out").** Replace with:
> - **Fan-out:** a consumer copies `~/.aitools/rules/*.md` (skipping `*.bak.*`) into its tool's rule directory. On main only setup-user-cursor does it (`.mdc` files, #87). setup-user-claude's fan-out is G12 (in flight, needs HARNESS Q1).

**A-11 (Medium; F2, G9, G2/E2).**
- F2: append:
  > Exceptions: #99's `.cursor/rules/deploy-paths.mdc` twin ("please confirm") and its 2 held paragraphs need the commander's explicit confirmation.
- G9 "Status": change to:
  > BLOCKED (G1-G8, and G11-G13 landed or explicitly deferred by the commander)
- E step 2 "#99 (apply the 3 allowlist lines from its Follow-ups first)": change to:
  > #99 (its owner, or after HARNESS-2 has stopped a fresh delegate on `docs/harness-approved-drafts`, first adds the 3 allowlist lines from its Follow-ups)

**A-12 (Low; completeness and lifecycle).**
- G.5: add "PR #54 follow-up: dotprofile `delegation.md` element-2 wording (draft location unknown; applied: unknown)", "N-Q6 scope (PR #78 follow-up)" and "SpecRewrite Q9/A1 wording".
- G17: add "S3-M3-Audit (read-only audit of all M3, S3-M3Lead-plan.md:91): not run; unknown whether mf-audit covers it".
- G11: add "also owns the installer relay-helper switch (S3-M3-LibKey-report.md:51, :88)".
- J: change "(S3-Handoff2-V, see below)" to "(S3-Handoff2-V, report at `MF/S3-Handoff2/S3-Handoff2-V-verification.md`)".
- E1: change "commit 95b9805" to "commit 95b9805 (on #99's branch `docs/harness-approved-drafts`)".
- Shipping: S3-Handoff2's PR must include the handoff, the whole `MF/S3-Handoff2/` folder (audit plus this report) and the relay.md edit. Copy `S3-Handoff2-S2-drafts.sh` and `S3-Handoff2-S2-grep.sh` from `.scratch/session-ho2/` into `MF/S3-Handoff2/`, or drop the audit's "in this scratch dir" claim. Worktree scratch is lost when the worktree is removed.

**Optional (no verdict impact).**
- E: add one line saying whether the commander confirmed the Schwerpunkt.
- A: name `.claude/rules/agentic-standards.md` "Managed-file review choices and merge" as the authoritative managed-file text (K-7).
- A: say whether the accepting session reads all of `reference/*.md` (the packet's commander duty).

## INCIDENT markers (not filed)

- INCIDENT: Stacked PRs #74/#75 merged into stale bases. The repo has no guard: GitHub retargets a stacked PR automatically only when the base branch is deleted on merge, and here the bases were kept. Suggested resolution: a `gh pr merge` wrapper or check that refuses a base other than `main`, or delete head branches on merge. Same family as #144.
- INCIDENT: `/handoff` Step 5 says to read the schwerpunkt-assessment file, but this session put the assessment inside handoff section E. The skill has no variant for an inline assessment.
