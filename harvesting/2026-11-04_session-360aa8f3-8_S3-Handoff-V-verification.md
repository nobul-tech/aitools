# S3-Handoff-V verification: handoff 2026-10-21_360aa8f3-8.md (v1)

Verifier: S3-Handoff-V (delegate of S3-Handoff, Session Commander 360aa8f3-8). Read-only except this file.
Baseline: handoff sections D and G (commander fact list), S4-Review-report.md, S2-Layout-report.md. Prior handoff: handoff-46ee1c2b-1.md.

## Facts verified (read-only, 2026-10-21)

| Claim | Result |
|---|---|
| HEAD 04cbdf0, then 26c37b2, 4081cf3, c491c59 | TRUE (`git log --oneline -4`) |
| `origin/main..main` = only 04cbdf0 | TRUE |
| `git diff origin/main main` touches only `.gitignore` + `harvesting/` | TRUE (78 files, all `harvesting/` except `.gitignore`) |
| No modified tracked files (N-Q5 resolved) | TRUE: `git status --short` shows only untracked: handoff, MISSIONS dir, the 9 `shared/skills/*` copies |
| The 9 copies are byte-identical to `.claude/skills/*` | TRUE (`diff -rq`: no "differ" lines) |
| PR #50/#51/#52 mergedAt 02:54:28Z / 02:54:43Z / 02:56:00Z; merge commits c491c59 / 4081cf3 / 26c37b2 | TRUE (`gh pr list --json mergedAt,mergeCommit`). Note: S4-Review §5.2 says "02:33Z" / "02:44Z"; those are creation times. The handoff is the correct one |
| Dotprofile 2ce89ce, c15dbdb, bce27bb pushed | TRUE (dotprofile `main...origin/main` in sync). A later commit, 6a9ef57 "Archive session ... (trading)", is from another session |
| `machineAlias: "nobul-mac"` at line 18 | TRUE |
| incidents.json is 2,027 lines with 86 ids and max id 86 | TRUE |
| `/incident` skill still points to `reference/incidents.json` | TRUE (SKILL.md:8,48,88,124) |
| `/delegate` absent from `~/.claude/skills` | TRUE. Also: `~/.claude/rules/` holds only `concurrent-agents.md`, so `delegation.md` is not loaded in context |
| pwsh installed at `/opt/homebrew/bin/pwsh` | TRUE (7.6.3) |
| v0.73.3 notes exist, untagged; latest tag v0.73.2 | TRUE (RELEASE_NOTES.md:15; tags) |
| Issue #32 = check-pre-push step 7 expects `aitools/deploy/` | TRUE (OPEN) |
| RCA dates (Mac / nobul-mac 06-22 00:10Z-03:05Z / Mac from 10-16) | TRUE (S2-Host-rca.md:5, 66-71) |
| Tree rev 3 in S4-Review-drafts | TRUE (header line 5) |
| M3 "8 code batches" | TRUE (B1-B8 in S5-Profile-plan.md) |
| 16 decision-tree leaves | TRUE (count in H) |
| main branch rules | NEW FACT: no classic protection (404). Repository ruleset 16468370 on main: `pull_request` (1 approving review), `non_fast_forward`, `deletion`. No signing rule |

## Criterion results

### 1. Self-containment: PASS
Layer 1 holds the Schwerpunkt, SD-1..SD-8 with enough detail to implement, exclusions, threads, and the first actions. If the scratch were deleted, nothing is lost: everything is in MISSIONS/. The gate questions are only named (D-TS10/11/12, N-Q1, N-Q3, T-Q1, ...), not described. That is acceptable, because step 3 (build the page) has to read S4 §3 anyway.

### 2. Reference integrity: NEEDS AMENDMENT (minor)
- Every path I checked exists: all section B files, `reference/plan-execution-detail.md`, the dotprofile `delegation.md`, the prior handoff, and `relay.md`. `plans/tool-support-and-machine-profile.md` does not exist, but it is correctly offered only as a suggestion.
- No live `.scratch/` paths are used. The handoff explicitly says not to use them.
- (a) The header says "tracked copy" and section J says "copied", but the handoff and the whole MISSIONS dir are **untracked** today. Nothing is gitignored, which I checked with `git status --untracked-files=all`. They survive this session but do not carry across machines until they are committed.
- (b) Section B, skill layout row: `S2-Layout-B-registry-consumers.md` and `S2-Layout-C-review.md` are missing the `S2-Layout/` directory prefix that the other entries carry.
- (c) See 7(a). The preserved MISSIONS tree contains nested `.claude/skills/` and `.claude/rules/` directories, and they will be committed.

### 3. Reading order: PASS
The order is handoff, then S4 (decision package), then S2-Layout, then depth files. It builds progressively and has no circular dependency. One snag: S4 refers to "S2-Split" as the pending skill-placement mission (X22, T-Q8, §5.1 preamble), and a reader only learns from section B that S2-Layout superseded it. A one-line pointer in A fixes this (amendment 10).

### 4. Scope governance: PASS (one clarification recommended)
- There is one Schwerpunkt and it is clear.
- The 8 hard exclusions are specific and each has a rationale.
- Each soft exclusion is bounded.
- Every G thread is classified.
- Gap: G11 (M5) and G12 (M6) are READY and independent, but nothing says whether the accepting session may do them while it waits on the gate, or whether they need a FRAGORD. See amendment 9.

### 5. Completeness: NEEDS AMENDMENT
These are covered: every S4 §3 gate question, the §5.1/§5.2 batches, the §4 incident drafts, S2-Layout §4 Q-A/Q-B, §5 PR-a/b/c, the §6 questions, §7 by reference, all D.1 shipped items, and SD-1..8.

These are missing:
- (a) S4 §3 **"Decide before the named batch"** (16 items: T-Q3..T-Q8, T-Q12, P-Q4..P-Q7, P-Q12, P-Q13, N-Q2, N-Q4, N-Q6; N-Q5 is resolved). Section E step 3 lists only the blocking table. Some of these overlap approved SDs: T-Q3 `[x]abort` = whole run appears already settled by SD-5.
- (b) S4 §2 **"Not fixed in a copy"**: edits that must be made to the S5-Tools drafts (C-08, C-09 rest, C-14 "detection signature" glossary decision, C-22, C-28, C-33). Without them the gate would approve skill drafts that S4 knows contradict the reference §6.
- (c) S4 §5.1: **5 of the 25 protected rows are "not drafted"**: rows 14 (.cursor mirrors), 15 (git-safety.md), 16 (script-standards-detail.md), 17 (aitool-eval card) and 25 (per-script intents). The gate cannot approve content that does not exist yet.
- (d) S4 §4 **glossary routing**: `open_glossary_items` in `glossary.terms-draft.json` (M2 I-20, `detection`, `user config`, "profile" with three meanings, "recovered").
- (e) S2-Layout §5 **sibling impact on S4**: the S4 `sources-of-truth.md` draft re-lists `registries/*.json` and needs the `shared/registries/` paths plus skill citations once PR-b is approved.
- (f) S2-Layout §5 **PR-d** (optional, later) is not mentioned. Low.
- (g) S2-Layout §3 cross-check: S4 §5.1 row 17 ("refresh aitool-eval card") conflicts with PR-c, which retires that card.

### 6. Consistency: NEEDS AMENDMENT
**Against the prior handoff 46ee1c2b-1:**
- (a) Prior F hard: "Do NOT direct-push to `main` until the branch-protection question (Section G) is resolved." The new G2 offers `git push origin main` (owner bypass) without saying whether that question was ever answered. Live state: a repository ruleset requires a PR with 1 approving review on main, and there is no signing rule. A direct push is therefore a bypass of the ruleset.
- (b) The prior Schwerpunkt is still "In Progress, pending" in ROADMAP.md:11: Step 0 then Workstreams A/B/C of `plans/tooling-resolution-and-artifact-registry.md`. M2 (tool support) overlaps Workstreams A/B, and S4 cites "tooling-resolution decision 10". The new handoff never says whether M2 supersedes, absorbs or runs beside A/B/C. A fresh agent sees two live Schwerpunkte.
- (c) The prior handoff's other open threads are not carried and not marked: `tool-versions.json` stale, the check-post-push step 26 `paste` bug, issue #7, and branch protection. The `framework-registry.json:183` stale path is now in PR-a (S2-Layout E4), but the handoff does not say so.
- (d) The prior I said "bash grep is hard-blocked, use the Grep tool". In this verifier session the Grep tool is **absent**, and bash `grep` ran unblocked. The new I still says "Use Read/Grep".

**Internal:**
- (e) SD-8 mixes what was approved with what is only recommended. "tool-ops, tool-eval, tool-registry, harvest + registries to user level" (approved) sits in the same row as the "S2-Layout extends this to incident, glossary, frameworks... `aitools-registry.py`... audit/governed-data/tool-adopt stay project-level (S2-Layout §6 Q1, recommended)" (not approved; §6 Q1 and Q2 are gate items in E3).
- (f) SD-6 is listed as approved but says "N-Q1(a), still to confirm at the gate", and the line after D.3 lists N-Q1 as unapproved. The approved part (per-machine `[k]eep` in `profiles.<alias>.toolExceptions`) and the pending part (exact shape and engine) should be split.
- (g) SD-5 states abort = exit 2, stops the run. S4 still lists that as open (T-Q3). The page should mark T-Q3 as answered by SD-5.

### 7. Claude Code operational correctness: NEEDS AMENDMENT
These are already documented: WRITE_BLOCKED, the subagent context gap, worktree write limits (#83), restart loss, standing-order-guard, build-deploy isolation, and the guard's observe mode.

Gaps:
- (a) **Nested skill discovery hazard (High).** Claude Code loads nested `<subdir>/.claude/skills` "once Claude works on files there" (S2-Layout-evidence.md E2, from the Claude Code skills docs). MISSIONS holds `S5-Tools/S5-Tools-drafts/.claude/skills/{tool-adopt,tool-eval,tool-registry}/SKILL.md`, and section B tells agents to read exactly there. An agent opening those drafts can get unapproved draft skills named `tool-eval` and `tool-registry` loaded beside, or in place of, the live project skills. That is the N2 one-name violation this very handoff forbids (F5). `S4-Review-drafts/.claude/rules/` and `S5-Tools-drafts/.claude/rules/` are similar. I did not verify whether nested `.claude/rules` load. Once committed, this also affects Claude Code web clones.
- (b) **`/delegate` is not invocable.** It is absent from `~/.claude/skills`, and redeploying is blocked by F1 until G1. Yet CLAUDE.md and the handoff route the delegation duty through `/delegate`. The fallback is to Read `shared/skills/delegate/SKILL.md` directly. `delegation.md` is also not in `~/.claude/rules`, so D-DEL1..4 are not in context unless read explicitly.
- (c) The Grep tool can be absent (see 6d). Bash `grep` worked in this session.
- (d) Deleting the 9 copies (E1) with `rm -rf` + a glob or `&&` violates the USO and is hook-blocked. The handoff does not say how to do it.
- (e) E3 says "The commander answers on that page". An Artifact page can collect answers only with runtime capabilities (`artifact-capabilities` skill, `db`); otherwise the answers come back in chat. Low.

### 8. Ambiguity scan

**Pass 1: undefined terms, vague instructions, unclear references**

| # | Finding | Where | Severity |
|---|---|---|---|
| A1 | "Fold blocker and major fixes into a rev 4 copy": no location named for the A/B reviewer outputs or rev 4. Section I says "preserve outputs to tracked paths early", but this step gives no path. Writing into the 360aa8f3-8 MISSIONS folder would mutate preserved provenance | E2 | High |
| A2 | What the A reviewer must check is not stated. S4 §2: "I did not re-verify the other ~45 dispositions. That was A's job." The B lens includes S4-9 but not the Windows-execution gap (PS1 runtime never executed) | E2 | Medium |
| A3 | PR-a "can start as soon as approved": approved by what? The 52 stale-path fixes touch protected files (e.g. `registries/framework-registry.json:183`, `ROADMAP.md:28`, `.cursor` rules), and PR-a is not covered by the E6/E7 spec (that is PR-b). Is PR-a its own gate item, or trivial-fix class? | E5, F3, G6 | Medium |
| A4 | "FRAGORD" is used without definition (not in the governed glossary list) | F | Low |
| A5 | E4's decision file and ROADMAP row are protected files (`plans/*.md`, `ROADMAP.md`). Not stated: whether recording the commander's answers counts as user-dictated content, or whether the file text is presented first | E4 | Low |
| A6 | "registration" / `register` (aitools-profile.js) is used in D/H context but not defined | H | Low |

**Pass 2: multiple meanings, naming collisions**

| # | Finding | Where | Severity |
|---|---|---|---|
| B1 | "E6/E7" (S2-Layout evidence sections) collides with handoff section E and its numbered steps. E3 writes "approve the E6/E7 spec" and F3 writes "S2-Layout E6/E7 spec" | E3, F3 | Medium |
| B2 | "D1-D6" (S2-Layout E7 drafts) vs handoff sections D.1-D.4 | B | Low |
| B3 | "G" = the gate step in the S4 §5.2 sequence ("0 → G (gate) → ...") vs section G and threads G1..G15 | E5 | Low |
| B4 | "F2" in I means "section F, hard exclusion 2". S4 also cites "F3" (a failure-severity rule in the tree) in D-TS10. The handoff does not repeat F3, so this is a risk only when cross-reading | I | Low |
| B5 | "user rule" for the dotprofile `delegation.md`: in governed vocabulary "user" = deployed to ~/, but this rule is not deployed on this Mac (dotprofile rule) | A | Low |
| B6 | "tracked copy" (header) means "in a tracked location", but the files are untracked today | header | Low |

### 9. Barrier test (simulated first wave, section E)
- **Re-assess.** All staleness commands work (zsh expands `~`). PASS.
- **E1, two yeses.** Clear and easy to ask.
  - Barrier: after the "yes", the agent has no compliant deletion recipe (7d) and may fight the hook.
  - Barrier: on "push main", the agent finds the prior handoff's hard exclusion against direct pushes (6a) and a PR-required ruleset, and has no guidance. Most likely it asks again, costing the commander a round-trip.
- **E2, A/B pass.** The input exists. Barriers:
  - The output location is undefined (A1).
  - The A scope is undefined (A2).
  - `/delegate` cannot be invoked (7b). The agent must read `shared/skills/delegate/SKILL.md`, which nothing tells it to do.
  - Reading `S5-Tools-drafts/` to brief reviewers can load draft skills (7a).
- **E3, review page.** Inputs exist. Barriers:
  - The page will omit the non-blocking questions, the S4 §2 draft fixes, and the 5 undrafted rows (5a-c). The commander would then be asked again later, or would approve with known defects.
  - SD-8, SD-6 and SD-5 vs T-Q3 leave the agent unsure which items are already decided (6e-g).
- **E4, record.** Works, apart from the protected-file question (A5).
- **E5, execute.** PR-a's approval status is unclear (A3). The PR-b-first sequencing advice is clear.
- **Overall.** An agent can execute the wave, but it would need about 3 to 5 clarifying round-trips to the commander, and it carries one real hazard (7a).

## Required amendments

1. **Section I, new first bullet (7a).** Add:
   "**Nested `.claude/` in MISSIONS (hazard).** Claude Code loads nested `<dir>/.claude/skills` once it works on files there. `MISSIONS/S5-Tools/S5-Tools-drafts/.claude/skills/` holds DRAFT `tool-adopt`, `tool-eval` and `tool-registry`, which share names with live skills. Read draft files with Read only, and never treat a skill that appears from there as live."
   **Preferred fix before commit (S3-Handoff or the commander):** rename `S4-Review-drafts/.claude` → `S4-Review-drafts/dot-claude` and `S5-Tools-drafts/.claude` → `S5-Tools-drafts/dot-claude`, then update section B and add to J: "`.claude/` directories inside MISSIONS were renamed `dot-claude/` so Claude Code does not discover draft skills; report paths that say `S*-drafts/.claude/...` map to `dot-claude/`."
2. **Header + J (2a).** Replace "(tracked copy of the session scratch `missions/`...)" with "(copy of the session scratch `missions/`; untracked until the session's closing commit — commit this handoff and MISSIONS/ before ending, or they do not reach other machines)".
3. **Section B, skill layout row (2b).** Change "`S2-Layout-B-registry-consumers.md` (...), `S2-Layout-C-review.md`" to "`S2-Layout/S2-Layout-B-registry-consumers.md` (...), `S2-Layout/S2-Layout-C-review.md`".
4. **Section E step 1 and G2 (6a).** Replace the push bullet with:
   "Ship `main` (04cbdf0). Recommended: open a PR from a branch (`chore/housekeeping-harvest`), because the main ruleset requires a PR with 1 approving review. The prior handoff 46ee1c2b (F, hard) forbade direct pushes until branch protection was decided, and that question is still unanswered. Direct `git push origin main` only if the commander explicitly confirms the bypass."
   In G2 "Needed", use: "PR (recommended) or commander-confirmed bypass; also answers 46ee1c2b's branch-protection thread".
   Also add to E1 the deletion recipe: "Delete with nine separate `rm -rf /Users/new-jose/repos/aitools/shared/skills/<name>` calls, or one scratch cleanup script; no globs or `&&` (USO)."
5. **Section C (or new C.1) (6b, 6c).** Add:
   "**Relation to 46ee1c2b's Schwerpunkt.** ROADMAP.md:11 still lists `plans/tooling-resolution-and-artifact-registry.md` (Step 0 → Workstreams A/B/C) as In Progress, pending. M2 builds on its decision 10 and overlaps Workstreams A/B. Whether M2 supersedes them is undecided: put it on the review page as a gate question (recommended: M2 absorbs A's resolver/verification scope; B and C stay as separate later work). 46ee1c2b's other threads are not carried here: `tool-versions.json` stale (now moving under PR-b, S2-Layout §6 Q6), step-26 `paste` bug, issue #7, branch protection (see E1). `framework-registry.json:183` is fixed by PR-a."
6. **Section D.3, SD-8 and SD-6 rows (6e, 6f).** SD-8:
   "Approved: `tool-ops`, `tool-eval`, `tool-registry`, `harvest` become user-level skills, and the registries move to user level. NOT yet approved (gate, S2-Layout §6 Q1/Q2): extending the move to `incident`, `glossary`, `frameworks`; `shared/registries/` + the `aitools-registry.py` resolver; keeping `audit`, `governed-data` and `tool-adopt` project-level. Moves are `git mv`, no copies."
   SD-6:
   "Approved: `[k]eep` is stored per machine in dotprofile `profile.json` `profiles.<alias>.toolExceptions`. Pending at the gate (N-Q1): the exact shape (recommended `{decision:"keep", detected:{platform, method, path, version}, decidedAt, decidedBy, reason}`, owned by `reference/user-repo.md`) and the writer (`aitools-profile.js exception-set`)."
7. **Section E step 3, add bullets (5a-5e, 5g, 6g).** Add after the S2-Layout §6 bullet:
   - "S4-Review §3 'Decide before the named batch' (T-Q3..T-Q8, T-Q12, P-Q4..P-Q7, P-Q12, P-Q13, N-Q2, N-Q4, N-Q6) as a second, non-blocking section, so the commander can pre-answer them. Mark T-Q3 as answered by SD-5 and N-Q5 as resolved."
   - "S4-Review §2 'Not fixed in a copy': apply C-08, C-09 (rest), C-22, C-28 and C-33 to the S5-Tools drafts before the page (or list them as known defects), and put C-14 ('detection signature') on the page as a glossary decision."
   - "Flag S4 §5.1 rows 14, 15, 16, 17 and 25 as NOT DRAFTED. Either draft them for the page or carve them out of the gate. Row 17 (refresh the aitool-eval card) is void if PR-c retires the card."
   - "The `open_glossary_items` in `S4-Review-drafts/registries/glossary.terms-draft.json`."
   - "S2-Layout §5 sibling impact: the S4 `sources-of-truth.md` draft must re-list registries at `shared/registries/` and cite skills once PR-b is approved."
   - "The M2-vs-tooling-resolution question (C.1)."
   - "PR-a's protected-file path fixes (S2-Layout-B tables 1-2) as an explicit approval item."
8. **Section E step 2 (A1, A2).** Replace with:
   "**Owe the A/B adversarial pass.** Launch two reviewers on `MISSIONS/S4-Review/S4-Review-drafts/reference/tool-support-decision-tree.md` rev 3. A covers correctness vs rules, including re-verifying the ~45 rev-2 dispositions S4 did not re-check (S4 §2). B covers cross-platform and bootstrap: S4-9 APFS case-sensitivity, PS1 and Windows paths, bash 3.2. Write their reports and the rev 4 copy to a new tracked folder `.aitools/channel/handoffs/<new-session-date>_<new-session-prefix>-missions/S4-AB/` (not into the 360aa8f3-8 MISSIONS, which is provenance). S4-Review says the pass must happen before the gate."
9. **Section F, soft (scope, 4).** Add:
   "G11 (M5, issue #32) and G12 (M6, hooks) are outside the Schwerpunkt. Start them only on commander request. If started, coordinate G11 with X-B2 (same check-pre-push step 7)."
10. **Section A (3, B1).** Add after item 3:
   "S4-Review predates S2-Layout: where it says 'S2-Split', read S2-Layout. In this handoff 'E6/E7' always means S2-Layout-evidence.md §E6/§E7, not handoff section E."
   Also in E3 and F3, write "S2-Layout-evidence §E6/§E7".
11. **Section I (7b, 7c).** Replace the standing-order-guard bullet's "Use Read/Grep" with "Use Read and Grep when present. The Grep tool can be absent in a session; bash `grep` ran unblocked on 2026-10-21 (S3-Handoff-V)". Add:
   "**`/delegate` is not deployed** (absent from `~/.claude/skills`, and redeploying waits on G1). Read `shared/skills/delegate/SKILL.md` directly before delegating. `delegation.md` is not in `~/.claude/rules`, so read `~/repos/aitools-nobul-jose/claude/rules/delegation.md` explicitly. Its D-DEL rules are not in context otherwise."
12. **Section F hard (A4).** Add at the top of F: "FRAGORD = an explicit commander order amending this handoff's scope."
13. **Section E step 4 (A5).** Append: "Both files are protected. Show the commander the exact text (his answers plus the decisions table) before writing."

Optional (Low): add "S2-Layout PR-d (optional, later: move deployed `.py` helpers to `shared/bin`)" to G as DEFERRED.

## INCIDENT markers (not filed)

- **INCIDENT:** The `/handoff` skill (Step 4 template and delegation duty item 9) says to preserve work products to tracked locations, but it does not warn that copying drafts which mirror repo paths (`.claude/skills/...`, `.claude/rules/...`) into a tracked subfolder creates nested `.claude/` directories. Claude Code discovers those as live skills, which breaks the N2 one-name rule. Affected: `shared/skills/handoff/SKILL.md`, and mission draft conventions (S5-Tools, S4-Review). Severity: medium.
- **INCIDENT:** No `Grep` tool was provisioned to this delegate, while both the handoff (I) and the delegating brief tell delegates to "use Read/Grep". This recurs from 46ee1c2b I ("Grep-tool-absence friction"). Severity: low. (Bash `grep` is no longer blocked, so the dead end from 46ee1c2b is gone.)
- **INCIDENT:** CLAUDE.md ("How the harness is organized") routes the delegation duty through the `/delegate` skill, but on this Mac `/delegate` is not deployed and `delegation.md` is not in `~/.claude/rules`. Every session here runs without the D-DEL rules in context. This is a known drift (S2-Layout evidence E3), but no incident or G thread tracks it explicitly. Severity: medium.
- **INCIDENT (observation):** S4-Review §5.2 cites the PR #50/#52 merge times as 02:33Z/02:44Z. Those are the creation times; the actual mergedAt is 02:54:28Z/02:56:00Z. Severity: low (doc accuracy in a draft).

## Overall verdict: NEEDS AMENDMENTS

The handoff is accurate and well layered: every factual claim I checked holds. It does not need a rewrite. Amendments 1, 4, 5, 7 and 8 matter most. Without them a fresh agent hits a skill-discovery hazard, a direct-push conflict with the prior handoff, an unresolved second Schwerpunkt, an incomplete review page, and an unplaced A/B output. The rest are wording fixes. After they are applied, a quick self-check is enough; no re-verification is needed unless the MISSIONS `.claude` → `dot-claude` rename is done, in which case re-run the section B path check.
