# S3-AnsB-GitHist results: commander decisions in git / PR history (user-repo.md edits A-J, glossary "profile")

**Intent**: **Purpose**: Report every recorded commander decision, or record quoting him, that bears on the PR #101 re-approval edits A-J and the glossary "profile" edit, with provenance. **Scope**: git history (origin/main 480b901, PR branches), PR #73-#116 bodies/comments/reviews, RELEASE_NOTES.md, the gate plan, the M3Lead plan, handoffs, relay, incidents (read-only), dotprofile log. NOT transcripts (S3-AnsB-Transcripts). NOT code verification (S3-AnsB-CodeVer). **Audience**: S3-AnsB.

## Summary (5 lines)

1. C (claim via `--alias`): **no commander decision found**. The behaviour is an S3-M3-UserInit implementation choice (bb43536, PR #86 body). It contradicts the re-key design (c), the resolver review M3 fix, and the commander-approved row-3 sentence still in the landed file ("`--claim <key>`, which user init passes after the user picks that profile at a terminal").
2. M3Lead decision 2 (silent registration of a cached alias): **still PENDING** in every record. No PR body, comment or commit resolves it; the 2026-10-22 handoff (480b901) lists it as pending, with the suggested answer "keep the switch at 0".
3. H: "NQ6) there should only be one" is **about install methods**, not config.json writers: it is gate item N-Q6, recorded 6 minutes later in commit 9bbe9a4 / PR #67. The single-writer rule comes from SD-7 (commander-approved, 360aa8f3 handoff) and M3Lead decision 7 (commander, 2026-10-22). The `aiToolingRepoPath -> repoPath` rename dates from v0.24 (2026-02-28, 174b0d6 / f1bd38a, agent-authored) and was never reconciled with SD-7. No record decides "document the exception" or "fix it".
4. I, A/B, G, J: I matches decision 7 (commander). A/B, G and J are **agent-recorded only** (B5a Q1 suggestion, Review3 #82 minor 5, design (f)); no commander decision found, none contradicts one, except that G and J replace approved row-3 sentences.
5. Glossary "profile": the term was created from G-profile (commander's note) in PR #69, keyed "by machine alias" before decision 5. Row 2 of #96 left it out by **omission, not deliberately** (149d607: "Follow-up (not approved, not changed)"). No open PR other than #101 changes `reference/user-repo.md`.

Tags: **commander decided** = his own words or a record quoting them; **commander-approved text** = agent-drafted wording he approved in a batch; **agent-recorded** = agent text only; **none found**.

## Provenance notes (apply to everything below)

- Every GitHub PR body, comment and review in #73-#116 is posted by the account `nobul-jose`, but all 108 posts are agent text (reviewer/author signatures, e.g. "Reviewer: S3-M3-Resolver-Review"). No post reads as the commander's own words. Source: dumped with `gh pr view/api`, flattened in `.claude/worktrees/ansb/.scratch/session-githist/prs/pr-*.txt`.
- Commits are authored "Jose" but carry `Co-Authored-By: Claude`; their text is agent text unless it quotes him.
- The gate plan `plans/tool-support-and-machine-profile.md` has a Decision column (the option he picked; agent wording) and a Note column (his own typed words, artifact Mqm6D32Xt5gKGUxPZTMSDY).

---

## C. Does user init claim an unowned profile when `--alias` names it, without asking?

Findings, newest first:

1. **PR #101 review (S3-H2-DraftsM3-Review), 2026-10-23T02:21:49Z**, https://github.com/nobul-tech/aitools/pull/101 review PRR_kwDOR5NK3c8AAAABTyr59g: confirms edit C's cited lines (scripts/aitools:492-496, aitools.ps1:1086-1088) and calls the landed text "deletions only"; it does not notice that edit C contradicts the landed approved sentence. **agent-recorded.**
2. **Commander approval of #96 rows, 2026-10-23T02:01:33Z** ("protected drafts approved.", per brief section 3). Row 3's text, kept in the landed file (only its VERIFY note was cut, D4): "**A 2.1 profile with no `machine.id`** (unclaimed) is moved under this id only with `--claim <key>`, which user init passes after the user picks that profile at a terminal. `--claim` of another machine's profile is refused (exit 4)." Source: `480b901:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-Docs/S3-M3-Docs-drafts/reference/user-repo.md:282-286`. **commander-approved text.** Note: the approval page he approved from says (summary item 3, `S3-M3-Docs-approval-page.md:25-27`): "today's user init cannot register nobul-mac (register refuses `--alias nobul-mac` with exit 4 and asks for `--claim`)". So he was shown the refusal, not the `--alias` claim.
3. **PR #86 body, batch 5 section (S3-M3-UserInit), and commit bb43536 (2026-10-22T16:42:37-07:00)**: "Decision 1: `--alias <new>` without a terminal creates this machine's profile ... An alias that names a profile no machine owns claims it." (PR #86 body line "Decision 1", https://github.com/nobul-tech/aitools/pull/86). Report: `S3-M3-UserInit-report.md` item 1: "`--alias` naming a profile that no machine owns claims it (`--claim`)." No source given for this sub-point; it is attached to "Decision 1", whose recorded text says nothing about claiming. **agent-recorded (implementer choice).**
4. **PR #86 review S3-M3-UserInit-Review, 2026-10-22T23:58:48Z** (pullrequestreview-5622357229): "Req 3: `--claim KEY` from the menu." It does not flag the `--alias` claim path. **agent-recorded.**
5. **S3-M3-Resolver report (c78bf12)**, `S3-M3-Resolver-report.md:64`: "An alias-keyed entry without `machine.id` is claimed only with `--claim KEY` (batch 5 passes it after the user picks KEY at a terminal; design c)." and `:100`: "Fixed in 3ce5850: ... M3 (`--claim` instead of claiming through `--alias`)". `:118` open Q2: "Batch 5 must pass `--claim KEY` when the user picks an unclaimed profile at the terminal". **agent-recorded.**
6. **PR #86 review S3-M3-Resolver-Review, 2026-10-22T21:50:30Z**, major M3: "`register --alias X` claims an unclaimed legacy profile without a terminal, even one that plainly belongs to another machine ... Expected. Design (c) ... **Without a terminal it is not claimed** (decision 2 switch) ... Decision 1's spirit is the same: never silently take what may be another machine's profile." Fix (a): "Add a `--claim` flag that the UI passes only after its interactive choose." Probe P3 showed the Windows box's unowned `nobul-win` profile re-keyed under the Mac's id. **agent-recorded.**
7. **Re-key design (abd5bde, S3-M3-Register-keydesign.md section c)**: "Legacy alias-keyed entry without `machine.id` (unclaimed). The interactive choose offers it. ... Without a terminal it is not claimed (decision 2 switch)." **agent-recorded.**
8. **M3Lead decision 1 (2026-10-22)**, `origin/docs/m3-lead-plan:.../S3-M3Lead-plan.md` section 2: "`--alias <new>` without a terminal creates the profile. An alias whose profile carries a different machine's `machine.id` is refused, unless the run is interactive and the user confirms. Registration never silently overwrites another machine's id." Traces to the commander's "1) yes" at 2026-10-22T20:40:43Z (brief section 3). Recorded in the plan by 6957cee (on PR #101 branch only): "**Registration never overwrites another machine** (commander, 2026-10-22) ...". It covers new aliases and aliases of another machine's id-bearing profile; it is **silent on unowned (no `machine.id`) profiles**. **commander decided** (scope as stated).
9. **P-Q12 (gate, 2026-10-21)**: "Non-interactive registration: add aitools user init --alias <A>?" -> "Add --alias", Note empty. `plans/tool-support-and-machine-profile.md:108`. **commander decided** (only that `--alias` exists).
10. Live state that makes this matter: approval page `:25`: "no profile has `machine.id`" in the live dotprofile; dotprofile log shows no migrate/register commit since (latest profile.json commit 825aed4, 2026-10-22, effortLevel only). So `aitools user init --alias nobul-win` on the Mac would take the Windows profile through this path.

**Verdict for C: none found** (no commander decision for claiming via `--alias`). The only commander-approved wording on claims says the claim follows a terminal pick. Edit C adds a sentence that contradicts that approved sentence in the same file.

`INCIDENT:` the user-init `--alias` claim path (bb43536) re-opens resolver review M3 at the UI layer, against design (c) and the approved row-3 text, with no recorded decision; no reviewer of #86 batch 5 or #101 flagged it.

## M3Lead decision 2: silent registration via cached config.json `machineAlias`

1. **Handoff 2026-10-22_10cf255a-c.md (480b901, 2026-10-26)** `:107`: "**Pending decision** (M3Lead decision 2): should a cached config alias that points to a profile without `machine.id` register silently? Today: ask on a terminal, ERROR without one, behind a one-line switch (default 0, S3-M3-UserInit-report.md:23)." `:139`: "Suggested: keep today's behaviour (the switch stays 0)." **agent-recorded (still pending).**
2. **PR #116 body** ("The approved behaviour is untouched: decision 2, item 5, item 6"), **PR #113 review** ("Unchanged, as required: `AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0` (aitools:143)"), **PR #104 body** ("(b) decision 2 switch unchanged"). **agent-recorded**; none resolves it.
3. **6957cee commit message (2026-10-22T19:14:07-07:00)**: "Decision 2 still PENDING (scripts/aitools:137-143), not recorded." **agent-recorded.**
4. **PR #86 body / bb43536**: "Decision 2 (pending): one line per entry point, `AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0` / `$script:RegisterCachedAliasSilently = $false`. via=alias asks on a terminal and is ERROR without one; at 1 / `$true` it claims silently." **agent-recorded.**
5. **M3Lead plan section 2 item 2**: "PENDING: cached config alias ... keep today's behaviour (ask on a terminal, ERROR without one) behind a one-line switch". **agent-recorded**; the commander's only recorded reply is "what? cached alias? cached how?" (brief section 3, 2026-10-22T20:40:43Z; transcript, not my scope).
6. **PR #82 Review3 minor 1 (2026-10-22T05:23:09Z)**: "`via=alias` goes to the menu ... R18 says user init asks only on `none` or `hostname`. Either register the alias or update the spec." Origin of the question. **agent-recorded.**

**Verdict: none found** (never resolved in any git/PR record).

## H. config.json single writer; "there should only be one"; the `aiToolingRepoPath` rename

### What "NQ6) there should only be one" refers to
1. **PR #67** created 2026-10-22T03:35:01Z (56 s after the 03:34:05Z prompt): "Records every commander decision from the gate review page plus chat overrides (D-TS13 reversed, C.1, P-Q4, N-Q6, N-Q2)". Merged as **9bbe9a4** (2026-10-21T20:40:03-07:00 = 03:40Z), whose message says "N-Q6 (one preferred method per platform in the schema)". **agent-recorded, quoting a chat answer.**
2. **Plan row N-Q6** (`plans/tool-support-and-machine-profile.md:112`): question "Ambiguous preferred methods: their own detail, or reuse 'no method for <platform>'?"; Decision "The registry schema allows only one preferred install method per platform; a violation gets its own detail message (chat 2026-10-21)"; Note (his words): "i need more context here. what is this in reference to?". The prompt text in the brief ("the schema should only allow for one install method per platform and/or its own message") matches this row word for word. **commander decided** (install methods).
3. N-Q6 origin: S4-Review report section 3 (`2026-10-21_360aa8f3-8-missions/S4-Review/S4-Review-report.md:165`), registry preferred-method ambiguity.

=> "there should only be one" is **not** a config.json-writer decision.

### Where "setup-user-config is the only writer" comes from
1. **M3Lead decision 7 (2026-10-22)**: "config.json is generated from profile.json by deploy-harness (mission HARNESS owns scripts/deploy-harness.*), which calls setup-user-config.sh/.ps1 as the single writer." Traces to the commander's 2026-10-22T20:44:23Z prompt (brief): "aitools user init should create the profile.json file, and we deploy-harness should generate and deploy the config.json file from profile.json." Recorded in the plan by 6957cee: "**config.json is generated from profile.json by deploy-harness**, which calls `setup-user-config.sh/.ps1`, the single writer (commander, 2026-10-22)." (PR #101 branch; approved row 1). **commander decided** (the "single writer" words are the agent's; his words name deploy-harness generating config.json from profile.json).
2. **Handoff 2026-10-21_360aa8f3-8.md:98 (c8573ed, 2026-10-20)**, D.3 "Decisions approved by the commander this session": "SD-7 | `profile.json` (dotprofile, git) is the source of truth. `~/.aitools/config.json` is derived, with exactly one writer (`setup-user-config.sh/.ps1`)." **commander-approved (agent wording, SD label).** This is the earliest record of "exactly one writer".
3. **Commit 50e50f9 (2026-10-21)**: "Add setup-user-config.sh/.ps1: the single, node-free config.json writer (M3 B3)". **agent-recorded.**
4. **PR #86 batch 4 body**: "`setup-user-config.sh` / `.ps1` stays the only writer of `~/.aitools/config.json`; deploy-harness calls it." **agent-recorded.**
5. **Handoff 2026-10-22_10cf255a-c.md:102**: "**config.json** is derived from profile.json and has one writer, `setup-user-config.sh/.ps1`." **agent-recorded.**

### The `aiToolingRepoPath -> repoPath` rename (when, why, by whom)
1. **f1bd38a (2026-02-28T06:13:27-08:00)** "Rename repo from ai-tooling to aitools ... Config key aiToolingRepoPath renamed to repoPath with migration fallback." and **174b0d6 (2026-02-28T07:01:42-08:00)** "Auto-migrate stale aiToolingRepoPath -> repoPath in config.json (chicken-and-egg: installer couldn't run with old config key)". Both Co-Authored-By Claude Opus 4.6, tested Windows. **agent-recorded**; whether the commander ordered the repo rename is not in the commit text (unknown).
2. **RELEASE_NOTES.md:2563, 2570 (v0.24, 2026-02-28)**: "**Config key renamed `aiToolingRepoPath` to `repoPath`**: Both CLI entry points ... read `repoPath` first with fallback to `aiToolingRepoPath` for migration." / "| 6 | High | Config migration gap: rename left stale `aiToolingRepoPath` in config.json; added auto-migration to both CLI entry points |". **agent-recorded.**
3. The rename predates SD-7 by ~8 months. No later record reconciles it with the single-writer rule until S3-H2-DraftsM3: handback `:65` "INCIDENT: the `aitools` entry points write ~/.aitools/config.json themselves ... This bypasses setup-user-config, which reference/user-repo.md declares the only writer."; PR #101 body Follow-ups: "INCIDENT (not filed)". Review F1 (PR #101): "Approved text, inexact before D9 as well". **agent-recorded.**
4. Earlier mention, not as a conflict: S2-Layout-A-deploy-map.md:266 "Migration aiToolingRepoPath→repoPath: scripts/aitools:642-666" (360aa8f3 missions). The ConfigKey review (#86) saw it only as a `migrate` grep hit.
5. Not filed anywhere: no incident in registries/incidents.json matches (keyword scan: aiToolingRepoPath / only writer / single writer), and the PR #102 drafts (#146-#161) do not mention it.

**Verdict for H**: the single-writer rule is **commander-approved** (SD-7) and **commander decided** (decision 7). "There should only be one" is **not** about writers. "Document the exception" vs "fix the rename": **none found**. The approved row-3 text had a (different) "Known exception, to be removed" pattern for the v1 migration, so edit H reuses wording he approved once for a similar case.

`INCIDENT:` the brief (section 3) and the H question link "there should only be one" to config.json writers; records show it is N-Q6 (install methods). The entry-point config.json write is not filed as an incident (only unfiled `INCIDENT:` markers in the S3-H2-DraftsM3 handback and PR #101 body).

## I. PR #88: does a record say deploy-harness generates config.json from profile.json?

1. **6957cee plan bullet** (above): "config.json is generated from profile.json by deploy-harness, which calls `setup-user-config.sh/.ps1`, the single writer (commander, 2026-10-22)". **commander decided** (decision 7; his 20:44:23Z words).
2. **PR #88 body** (https://github.com/nobul-tech/aitools/pull/88): "generate `config.json` by calling the only writer, `setup-user-config.sh` / `.ps1`" and "S3-Harness brief (commander requirements): ... config.json generated from profile.json through the existing writer." Also: "runs `setup-user-config.sh` (no flags ...)"; "a non-zero exit is `log_error` + `ERROR|harness files|config.json not generated`". Merged 2026-10-23T01:29:56Z. **agent-recorded, citing commander requirements.**
3. **PR #86 batch 5 / bb43536**: "v1 -> v2 migration ... commits profile.json only and no longer writes config.json (decision 7)." **agent-recorded.**

**Verdict: edit I matches commander decision 7.**

## A / B. `AITOOLS_USER_REPO_PATH` exported by the entry points

1. **PR #101 body** (row-3 deletion D1): "they now pass it to build-deploy (scripts/aitools:2049-2055; aitools.ps1:1999-2007)". **agent-recorded.**
2. **PR #95 body** (merged 2026-10-23T01:23:09Z, written before #86 merged): "Neither exports `AITOOLS_USER_REPO_PATH` yet, so they use the resolver fallback (follow-up)" and "Entry points: `aitools` / `aitools.ps1` should export ... (owner: UserInit, #86)". Stale on merge: #86 (merged 00:59:29Z, earlier) already did it. **agent-recorded.**
3. **PR #86 body batch 5 / bb43536**: "build-deploy (B5a Q1 / #95): both entry points resolve the dotprofile ..., pull it, and pass it as `AITOOLS_USER_REPO_PATH` (forward slashes), scoped to the build call." UserInit report item 8, same. Review: "Req 8 (read): `env AITOOLS_USER_REPO_PATH=... bash build-deploy.sh` ...; PS sets and restores it in try/finally". **agent-recorded.**
4. **S3-M3-B5a report:115**, open Q1: "Should `aitools` / `aitools.ps1` export `AITOOLS_USER_REPO_PATH` before build-deploy? Suggest yes, by the UserInit owner (#86)." The 2026-10-22 handoff `:212` lists only "B5a Q2-Q3" as open, so Q1 was treated as closed by the #86 implementation, not by a recorded answer. **agent-recorded.**
5. M3Lead plan B5a row: "dotprofile from entry point". **agent-recorded.**

**Verdict: none found** (no commander decision; nothing contradicts one). No open PR body says it changes the build-deploy env (#106, #113, #115, #116 bodies grepped); code check is CodeVer's.

## G / J. user init and uncommitted profile.json; migrate on every run

G (dirty file):
1. **PR #101 review F2**: "True for migrate/exception-set ... False for user init, which refuses to write (scripts/aitools:657-669)". **agent-recorded.**
2. **PR #113 review**: tests `unregistered_once` "for alias-other, unregistered-notty, cached-alias-0 and dirty" (one `ERROR|machine profile|` row, no writer row). Consistent with edit G after #113. **agent-recorded.**
3. **PR #86 body batch 5 / bb43536**: "(5) A profile.json with uncommitted edits is never committed: registration is refused (ERROR), or not refreshed (WARN) when the machine is already registered." **agent-recorded.**
4. **PR #82 Review3 minor 5 (2026-10-22T05:23:09Z)**: "**Uncommitted local edits to profile.json are committed** under 'Register machine profile: <alias>', because register reads the working copy." **agent-recorded** (origin of the change).
5. **Approved row-3 text** (2026-10-23T02:01:33Z): "A commit is skipped when `profile.json` already had uncommitted changes before the write (register through user init excepted): the file is written, a warning asks the user to review and commit it by hand." The "(register through user init excepted)" clause was cut (D8) as disproved. **commander-approved text**, now partly false for user init.

J (migrate on every run):
1. **PR #101 review F5**: "It runs `migrate` on every clean profile.json (a no-op when none are 2.1). It never runs it when profile.json has uncommitted edits (scripts/aitools:657-671)". **agent-recorded.**
2. **PR #86 body / bb43536**: "migrate runs before resolve (backup, commit, push), so the writer's 're-keys machine profiles' ACTION clears". **agent-recorded.**
3. **Re-key design (f)**: "Run `aitools user init` (which calls `migrate` when legacy entries exist)". **agent-recorded.**
4. **Approved row-3 text**: "`aitools user init` runs `migrate` when 2.1 profiles exist." **commander-approved text.**
5. Decision 5 (commander, 2026-10-22, M3Lead plan item 5): "live dotprofile migrated with a backup, committed and pushed (N-Q2)" -- about migrating, not about when user init calls it. **commander decided** (migration itself).

**Verdict: none found** for both; edits G and J correct approved sentences to the shipped code.

## Glossary "profile" term

1. **149d607 (2026-10-22T19:14:08-07:00, PR #101 branch)**, row 2 applied: "Follow-up (not approved, not changed): the 'profile' term still says 'keyed by machine alias' (glossary.json 'profile')." **agent-recorded.** => left by omission, not by decision.
2. **#96 row 2 draft** (`S3-M3-Docs-drafts/registries/glossary.json.edit.txt`) covers only "machine alias" and "machine profile"; approval page row 2: "'machine alias', 'machine profile' definitions". No mention of "profile". **commander-approved text** (scope excludes "profile").
3. **Current definition** (read through the /glossary process, main checkout): "The user profile: profile.json ... A machine profile is a field inside it (one entry of its 'profiles' object, keyed by machine alias), not a separate file. ..." Source: "decision G-profile (plans/tool-support-and-machine-profile.md); reference/user-repo.md".
4. **Term created**: 162b5b7 / PR #69 (2026-10-21, "approved gate glossary terms"); 61975fe lists "profile" among the 7 terms. **agent-recorded**, implementing:
5. **G-profile (gate, 2026-10-21)**, Note in his words (`plans/...:95`): "shell profile, profile.json = user profile, machine profile is a field in profile.json. profile should also mean user profile, not shell, not machine". **commander decided** (meaning of "profile"; says nothing about keys).
6. **Decision 5 (commander, 2026-10-22)**: "`profiles.<machineId>` replaces `profiles.<alias>`" (M3Lead plan item 5; brief 20:44:23Z "rename it to like profiles.<machineID>"). **commander decided.** The edit "keyed by machine alias" -> "keyed by machine id" follows decisions 5 and G-profile.

**Verdict: edit matches commander decisions 5 and G-profile; not deliberately left.**

## Edit D, E, F (no separate question; records found in passing)

- D/F/E are corrections of approved text to shipped code (PR #101 review F3, F4, F6). F's "(suggested)" and "[-] ... (registered to another machine)" come from Review3 #82 M2 ("Mark these aliases in the menu ... and ask for confirmation") and Resolver Q2. E's Path 3 push comes from decision 6 (commander, 2026-10-22: "`aitools user init` scaffolds profile.json ... commits and pushes"). **agent-recorded** except decision 6.

## Open PRs and reference/user-repo.md

- Only **#101** changes `reference/user-repo.md` or the glossary (file lists of #97-#116 via `gh pr view --json files`).
- PRs touching the code behind the edits: #106, #113, #115, #116 (scripts/aitools, aitools.ps1); #98, #113, #114, #115, #116 (setup-user-config); #105, #108, #114 (aitools-profile). Bodies of interest:
  - **#113**: "User init passes `--no-machine` / `-NoMachine` to setup-user-config when it has concluded that this machine is not registered" and "M3-FINISH items 2 and 3 (commander): 'The lib runner accepts ...'". Affects the writer rows beside edit D/G text (fewer duplicate rows), not the quoted user-init row/ACTION text per its body.
  - **#98**: "M3-FINISH item 2 (commander, 2026-10-22): 'setup-user-config gains `--no-machine` / `-NoMachine` ...'". PR #101 body: "PR #98 ... may change the config.json caller text in user-repo.md. Re-check after it merges."
  - **#116**: "The approved behaviour is untouched: decision 2, item 5, item 6, and the config writer contract."
  - **#106**: abort/deploy-harness hook-in; no body mention of config.json writes, `AITOOLS_USER_REPO_PATH`, claim, migrate or dirty-file behaviour.
  - Whether any of them changes the cited lines: unknown from bodies (CodeVer).

## INCIDENT markers (not filed)

- `INCIDENT:` user init claims an unowned profile named by `--alias` without a terminal (bb43536) with no decision, against design (c), resolver review M3 and the approved row-3 sentence; edit C would document it as intended.
- `INCIDENT:` the entry-point `aiToolingRepoPath -> repoPath` config.json write (v0.24, 2026-02-28) conflicts with SD-7 / decision 7 and is not in incidents.json or the #102 drafts.
- `INCIDENT:` the brief's reading of "NQ6) there should only be one" as a config.json-writer statement is not supported by the records (it is N-Q6, install methods).
- `INCIDENT:` PR #95's body says the entry points do not export `AITOOLS_USER_REPO_PATH`; it merged after #86, which made that false (stale PR record).

## Method and limits

- Read: brief (all), packet (all), user and project rules in context, config-file-safety.md, deploy-paths.md, documentation-standards.md, hook-rollout.md, tool-evaluation.md, tool-lifecycle.md, web-sources.md. Not read for this git-only mission: the reference/*.md subset and the remaining rules (managed-file-deployment.md, relay-outbound.md); relay.md only grepped.
- Commands: `git log --all --grep / -S`, `git show`, `gh pr view/list`, `gh api .../pulls/N/comments` for #73-#116 (scripts in `.claude/worktrees/ansb/.scratch/session-githist/`), dotprofile `git log -- profile.json`, read-only keyword scan of incidents.json.
- No transcripts read (S3-AnsB-Transcripts). No delegates used. WRITE_BLOCKED: none (one `sed -n` with a two-range expression was refused by standing-order-guard; I used Read instead, no write involved).
