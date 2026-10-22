# S3-M3-Docs-Check findings (2026-10-22)

Independent check of the S3-M3-Docs protected-file drafts
(`S3-M3-Docs/S3-M3-Docs-drafts/`) against the code as shipped. Report only; no
draft was changed.

Code read: origin/feature/m3-rekey 1c89444 (PR #86), origin/feature/m3-b4-setup-user-claude
c179dae (PR #83), origin/feature/m3-b5-build-deploy b595632 (PR #95), origin/main 15cc56a.
The extracted copies under `.scratch/session-Docs/code/{rekey,b4,b5}/` are byte-identical to
those branch blobs (checked with `git show | cmp`, every file). Live dotprofile read only
(`/Users/new-jose/repos/aitools-nobul-jose`, HEAD db37f89).

Counts: **1 blocker, 4 major, 16 minor.** Every OLD block matches its target exactly once.

## 1. OLD-block verification (priority 1)

Method: `.scratch/session-DocsChk/check-old.pl` extracts every `OLD...:` block (up to `NEW`
or a `====` line, trailing blank lines dropped) and counts its occurrences in the target:
`git show origin/main:<path>` for docs, `git show origin/feature/m3-rekey:<path>` for
scripts (both .sh and .ps1), the live file and `HEAD:` for the dotprofile.

| Draft | Blocks | Result |
|---|---|---|
| reference/tool-support-decision-tree.md.edit.txt | 9 | all count=1 (lines 56, 309, 399, 400, 564, 605, 616, 629, 738; match the cited lines) |
| reference/script-standards-detail.md.edit.txt | 4 | all count=1 (88, 121, 179, 247) |
| reference/logging.md.edit.txt | 2 | all count=1 (60, 106) |
| dot-claude/rules/managed-file-deployment.md.edit.txt | 2 | all count=1 (49, 102) |
| dot-claude/rules/deploy-paths.md.edit.txt | 4 | all count=1 (49, 65, 71, 38) |
| dot-cursor/rules/managed-file-deployment.mdc.edit.txt | 2 | all count=1 (30, 59) |
| shared/claude-shared.md.edit.txt | 1 | count=1 (36) |
| shared/skills/tool-adopt/SKILL.md.edit.txt | 2 | all count=1 (216, 211) |
| plans/tool-support-and-machine-profile.md.edit.txt | 4 | all count=1 (23, 108, 32, 106) |
| registries/glossary.json.edit.txt | 2 | all count=1 (447, 443) |
| dotprofile/claude/CLAUDE.md.edit.txt | 2 | count=1 in live file and in HEAD (50, 42) |
| dotprofile/profile.json.edit.txt | 1 | count=1 in live file and in HEAD (1) |
| scripts/setup-user-config.sh.edit.txt | 3 | edit 1 in .sh (4), edit 2 in .ps1 (3), edit 3 in both (.sh 227, .ps1 233) |
| scripts/aitools-profile.sh.edit.txt | 3 | edit 1a in both (.sh 9, .ps1 8); 1b .sh at 18; 1b .ps1 at 15 |
| scripts/aitools-lib.sh.edit.txt | 0 (insert) | anchor line `# log helpers", PR #89, ...` is at aitools-lib.sh:468 and aitools-lib.ps1:398, as cited |

## 2. Findings

| id | draft file | draft text (quote) | what the code says (branch:file:line) | severity | suggested fix |
|---|---|---|---|---|---|
| F1 | reference/user-repo.md L271-272 | "**A new id** creates the profile: `aitools user init --alias <new>` registers this machine without a terminal (P-Q12; commander decision 1)." (not VERIFY-marked) | True only on Path 3 (new repo). On Path 1/2 (profile.json exists) user init passes the alias to `resolve` as an override (m3-rekey:scripts/aitools:290-291); an unknown alias is a resolver error, `via=none` (scripts/aitools-profile.sh:662, 877); `ui_register_flow` then calls `ui_choose` (scripts/aitools:434-435), which without a terminal logs ERROR `machine profile` `not registered` + ACTION and returns 1 (scripts/aitools:311-315). Same in aitools.ps1:898-925, 1062-1066. | blocker | Mark `VERIFY after #86 batch 5` and say what happens today ("today: works on Path 3 only; on an existing profile.json a new alias without a terminal ends with ERROR not registered"). |
| F2 | reference/user-repo.md L287-290 | "**No profile.json** (user init Path 1 without one, Path 3 new repo): `register --create` scaffolds ... user init commits and pushes it (commander decision 6). `VERIFY after #86 batch 5` (Path 3 commits in a later step today)." | Path 1 and Path 2 register nothing when profile.json is missing: the flow runs only `if [ -f "$user_repo_dir/profile.json" ]` (m3-rekey:scripts/aitools:1181-1183, 1208-1216; aitools.ps1:1135-1137, 1177). Only Path 3 calls `ui_register` with `--create` (scripts/aitools:1243, 384). The VERIFY note names only the Path 3 commit timing. | major | Extend the note: "today Path 1/2 skip registration when profile.json is missing; Path 3 scaffolds it and commits it in the initial commit". |
| F3 | reference/user-repo.md L356-359 (also scripts/setup-user-config.sh.edit.txt edits 1-2 "callers prompt, then pass --machine-id" / "-MachineId") | "`aitools user init` (GitHub user, dotprofile path, chosen profile: `--machine-id <key>` / `-MachineId <key>`; the old `--machine-alias` / `-MachineAlias` is accepted for one release ...)" | user init passes the deprecated flag today: `writer_args+=(--machine-alias "$machine_alias")` (m3-rekey:scripts/aitools:1302), `-MachineAlias` (scripts/aitools:1296; aitools.ps1:1261). The writer accepts both (setup-user-config.sh:79-106; .ps1:44-45, 93-103). | major | Mark `VERIFY after #86 batch 5` ("today user init passes --machine-alias <alias>"). The code-intent drafts can keep --machine-id if they land with batch 5; say so in the draft. |
| F4 | reference/user-repo.md L324-325; dotprofile/profile.json.edit.txt and user-repo.md L96 meta.intent audience | "`~/.aitools/config.json` is ... **derived**: its only writer is `setup-user-config.sh` / `setup-user-config.ps1`." / "aitools-profile.sh/.ps1 (the resolver; the only writer of machine profiles and toolExceptions ...)" | The v1 -> v2 migration in `aitools user init` writes config.json directly (`cfg.machineAlias = process.argv[2]; fs.writeFileSync(f, ...)`, m3-rekey:scripts/aitools:234-242; aitools.ps1:224-230) and writes alias-keyed machine profiles without machine.id or alias (scripts/aitools:181-230, `v2.profiles[alias] = {...}`; extra v1 machines become `machine1`, `machine2`). | major | Either qualify both claims ("except the legacy v1 -> v2 migration in `aitools user init`, which predates this design") or treat it as a code deviation. INCIDENT below. |
| F5 | reference/user-repo.md L313-316 | "No flag day: code that predates revision 2.2 still matches an id-keyed profile through its `machine.id` (step 3) or its hostname, so migrating does not break a machine that has not updated; it sees one extra warning until it does." | True for main's resolver (origin/main:scripts/aitools-profile.sh:419, 519-530). Not for main's setup-user-claude.sh (pre-#83), which picks `p.profiles[cfg.machineAlias] \|\| hostname match (os.hostname) \|\| Object.values(p.profiles)[0]` (origin/main:scripts/setup-user-claude.sh:111-119). After `migrate` the alias key is gone, so such a machine falls to the node hostname (macOS kernel name, not LocalHostName) and then to the first profile -- another machine's values. | major | Say that the claim holds for the resolver only, and that machines must run #83 (no first-profile fallback) before the live dotprofile is migrated; the existing guard sentence ("only after the reader is merged to main and pulled on every machine") should name #83 explicitly. |
| F6 | reference/user-repo.md L247-248; tree edit 6 | "4 refused (`register`: the alias is used by another profile)" / "4 refused (`register` only: the alias is used by another profile)" | `register --claim KEY` of a profile registered to another machine also exits 4 (m3-rekey:scripts/aitools-profile.sh:1313-1316). user-repo.md L279-280 says so itself. (The resolver and lib headers have the same gap: aitools-profile.sh:35-37, aitools-lib.sh:138.) | minor | "4 refused (`register`: the alias is used by another profile, or `--claim` names another machine's profile)". |
| F7 | reference/user-repo.md L236-239 | "On `none` ... the run reports `write_summary ERROR "machine profile" "no machine match"` plus one `ACTION Run: aitools user init (pick or register this machine's profile)`." | setup-user-config (first entry of every run) writes its own ERROR `machine profile` `no machine match` and a different ACTION `Run: aitools user init (profiles: <aliases>)` (m3-rekey:scripts/setup-user-config.sh:220-221); the lib then writes its ACTION once per run (aitools-lib.sh:366-367, `_aitlib_action_once` dedupes exact text only) and one ERROR row per consumer (not deduped). | minor | "... reports ERROR `machine profile` `no machine match` (setup-user-config and every consumer) and an ACTION to run `aitools user init`". |
| F8 | reference/user-repo.md L352 (machineId row) | "Removed when the derivation matched a profile but yields no id" | Removed only when the derivation yields a machineAlias and config.json had a machineId (m3-rekey:scripts/setup-user-config.sh:274-281). A hostname match or an `AITOOLS_MACHINE_ALIAS` override matches a profile but yields no alias (aitools-profile.sh:1173-1178), and the cached machineId is kept. | minor | "Removed when the derivation yields an alias but no id (a 2.1 alias-keyed profile, or a choice of another profile); kept when nothing is derived". |
| F9 | reference/user-repo.md L350 (githubUser row) | "`--github-user`, else `profile.json identity.github`" | Third fallback: the existing config.json githubUser (m3-rekey:scripts/aitools-profile.sh:1167-1169). | minor | Add "else the current config.json value". |
| F10 | reference/user-repo.md L493 (CLI table) | "register this machine's profile (re-keying 2.1 profiles)" (not VERIFY-marked) | Today register re-keys only this machine's own 2.1 profile that already has its machine.id (aitools-profile.sh:1281-1298, 1363-1365). user init does not run `migrate` and does not pass `--claim` (no `migrate`/`claim` in m3-rekey:scripts/aitools user init code; grep). The live profiles have no machine.id, so nothing is re-keyed today. | minor | Mark `VERIFY after #86 batch 5`. |
| F11 | dot-claude/rules/deploy-paths.md.edit.txt edit 1, last paragraph | "Every resolver-consuming deploy script (`setup-user-claude`, `-settings`, `-cursor`) resolves the dotprofile and this machine's profile when it runs" | setup-user-settings and setup-user-cursor call only `resolve_user_repo_path` / `Resolve-UserRepoPath` (m3-b5:scripts/setup-user-settings.sh:67, .ps1:54; setup-user-cursor.sh:190, .ps1:173); only setup-user-claude resolves the machine profile (setup-user-claude.sh:84). | minor | "... resolves the dotprofile (setup-user-claude also this machine's profile) when it runs". |
| F12 | reference/user-repo.md L439-446 | "They use the live dotprofile when it exists on the machine and the embedded copies otherwise" | setup-user-settings has no snapshot fallback: "without a dotprofile the sync is skipped" (m3-b5:scripts/build-deploy.sh:1164-1170); setup-user-cursor's fallback is the two embedded preference defaults (build-deploy.sh:773-777). | minor | "setup-user-claude uses the live dotprofile when it exists and the embedded copies otherwise; setup-user-cursor falls back to the build-time cursor.cli values; setup-user-settings skips the sync without a dotprofile". |
| F13 | dot-claude/rules/managed-file-deployment.md.edit.txt edit 1; dot-cursor mirror edit 1 | "override → environment → `profiles[<machine id>]` → config.json `machineId` (only when the id cannot be detected) → hostname (warns) → no match = ERROR" | Step 4L, the 2.1 cache (config.json machineAlias naming an alias-keyed profile), sits between machineId and hostname (m3-rekey:scripts/aitools-profile.sh:485-486, 722-738). | minor | Add "→ (2.1) config.json `machineAlias`" or say "summary; full order in user-repo.md". |
| F14 | reference/logging.md.edit.txt edit 2 | "The tool writes no `write_summary` row and raises no `ERRORS` / `WARNINGS` except in its OS guard." | The resolver also calls `log_warn` from `logging_init`'s environment check (m3-rekey:scripts/aitools-lib.sh:666, 674-676) and from `backup_file` on a failed backup (aitools-lib.sh:898-901, via `backup_pf`, aitools-profile.sh:1009-1013). These counters live in the resolver's own process (the caller's are not touched). | minor | "... and touches no counters of its caller (its own counters, raised only by the OS guard and lib helpers, end with its process)". |
| F15 | scripts/aitools-lib.sh.edit.txt (new section intent) | "NOT a writer of deploy.log (the child writes its own) or of summary rows (... Invoke-ChildRelayed adds one ERROR row only for a throw)." | run_child_relayed / Invoke-ChildRelayed log_error to deploy.log for a failed child (m3-rekey:scripts/aitools-lib.sh:595, 600, 613, 617; aitools-lib.ps1:518, 523, 527). The throw row is written only when SUMMARYTOOL is passed (aitools-lib.ps1:519). | minor | "NOT a copier of the child's lines to deploy.log (the child writes its own; the relay logs one error for a failed child)"; "... adds one ERROR row only for a throw, when given a summary tool name". |
| F16 | scripts/aitools-profile.sh.edit.txt edit 1b | "aitools-profile.sh:17-19" OLD starts "# exports), aitools `user init`, ..." | The OLD text is lines 18-19. Line 17, left unchanged, says "under Git Bash on Windows it uses the AITOOLS_USER_REPO_PATH the entry point exports" -- no entry point exports it (no match in m3-rekey or m3-b5 scripts/aitools, aitools.ps1; user-repo.md draft L47 says "do not export it yet"). | minor | Cite 18-19, and extend the OLD/NEW to lines 16-17 so the header stops claiming the export. INCIDENT below (same stale claim in build-deploy.sh). |
| F17 | dotprofile/profile.json.edit.txt header; dotprofile/claude/CLAUDE.md.edit.txt | "/Users/new-jose/repos/aitools-nobul-jose/profile.json at HEAD bce27bb"; "claude.settings (12 keys)" | Dotprofile HEAD is db37f89 now (`git log`); profile.json is unchanged since bce27bb (`git log bce27bb..HEAD -- profile.json` empty), claude/CLAUDE.md changed in 8901ed9 but both OLD blocks still match. claude.settings has 13 keys (live file lines 19-46). The uncommitted effortLevel medium -> high change is as described. | minor | Update the HEAD and the key count. |
| F18 | reference/tool-support-decision-tree.md.edit.txt edit 8 | "A `profile.json` that already had uncommitted changes before the write is written but not committed (a warning asks for a manual commit). A failed commit or push is a warning: ... ACTION `run git push in <userRepoPath>`" | For the dirty case the wrapper also reports "saved but not pushed" + ACTION `run git push in <dir>` (m3-rekey:scripts/aitools-lib.sh:443-447; aitools-lib.ps1:371-376): the dirty warning contains "commit", so it is picked as the reason. A push does not help when nothing was committed. | minor | Document it as is ("the dirty case also gets the push ACTION") or fix the code; INCIDENT below. |
| F19 | reference/tool-support-decision-tree.md.edit.txt edit 7 | "Allowed only when the matched profile is this machine's (`owner` = `this`) and the resolved via (`AITLIB_MACHINE_VIA`) is `id`, `environment` or `override`." | exception-set resolves the profile itself (m3-rekey:scripts/aitools-profile.sh:1050-1074); `tool_exception_record` passes no AITLIB_ values (aitools-lib.sh:422-425). Same algorithm, so the result agrees, but the gate is not AITLIB_MACHINE_VIA. | minor | "the via of exception-set's own resolution (the same as `AITLIB_MACHINE_VIA`)". |
| F20 | reference/logging.md.edit.txt edit 1 | "`deploy.jsonl` | the installers' `log` override and the child relay (`jsonl_record` / `Write-JsonlRecord`, `run_child_relayed` / `Invoke-ChildRelayed` in `aitools-lib`)" | The installers still write deploy.jsonl with their own helpers (m3-rekey:scripts/aitools-install.sh:124-125, 135 `jsonl_write`, 153 `relay_child_log`) until the call-site follow-up; the draft's source note says so, the row does not. | minor | Add "(the installers' own copies until the call-site follow-up)" or land edit 1 with that follow-up, as script-standards edit 2 does. |
| F21 | reference/user-repo.md L276-277 | "the other profile is not touched and every resolve of that alias then warns" | The conflict check at register is case-insensitive over alias and key (aitools-profile.sh:1331-1338); the per-resolve duplicate warning compares `alias` fields case-sensitively (aitools-profile.sh:621-627). A duplicate that differs only in case (Laptop / laptop key) is allowed with `--allow-duplicate-alias` and then never warns. | minor | "warns when the aliases are identical" or align the code. |

## 3. Checked and found correct

Resolution and schema (reference/user-repo.md against m3-rekey:scripts/aitools-profile.sh):
- "Which dotprofile" steps 1-6, including errors for a missing env/argument path, warning
  and continue for a missing config path, scan only when githubUser is unknown (:419-473).
- `~` expansion in userRepoPath/reposPath, both resolvers (.sh :232-239, .ps1 :168-170);
  `--path-form mixed` (.ps1 :328); UTF-16 message text and config-warning / profile-error
  split (.sh :217-230, 407, 851; .ps1 :163).
- "Which machine profile" steps 1, 2, 3, 4, 4L, 5, 6 with their via values, misses and
  errors (:631-765); hostname sources (scutil LocalHostName, COMPUTERNAME, uname -n) and
  short-host rule (.sh :373-392, .ps1 :292-303); MachineGuid / IOPlatformUUID /
  machine-id sources (.sh :346-371, .ps1 :270-288).
- owner values and their meaning (:547-567); id-keyed vs legacy rule (:495-528); the
  warnings list (:599-627, 675, 694-701); identity-level values on no match (:879-880).
- Exit codes 0-3 as listed; lib wrappers never return 2 and map 2/3/4 (aitools-lib.sh:136-147,
  .ps1 :116-127); the consumer detail-line format (aitools-lib.sh:357, .ps1 :291).
- register: one key written (this id, or environment:claude-code-web), alias order
  (--alias, current alias, short hostname), alias format and id-shape refusal, conflict
  refusal exit 4 with owner/ownerKey and the `--claim` hint for an unregistered profile,
  re-key of this machine's 2.1 profile in place, `--claim` rules, exit 3 without an id,
  fields written (alias, machine.id, hostname unless matched, os, arch, shell; name/company
  only when neither profile nor identity has one), `--create` scaffold with
  meta.schemaRevision "2.2" (:1219-1431).
- user init: temp -> validate -> backup -> move, commit only profile.json, push
  best-effort (scripts/aitools:377-419, 345-372; aitools.ps1:999-1048, 953-994); the
  no-terminal ERROR `not registered` + ACTION `Run: aitools user init --alias <alias>`
  (scripts/aitools:311-315; aitools.ps1:920-924); menu numbered + [n] + [s] in both.
  The draft's VERIFY note "today's menu passes --alias <key>, which register refuses with
  exit 4 and the hint --claim <key>" is right for an unclaimed legacy key.
- migrate: re-key rules, alias = old key, unclaimed left, both refusal conditions, write
  path, commit message, outcomes and exit 3 for a snapshot (:1443-1548).
- commit_profile: dirty-before check, identity.git fallback, GIT_TERMINAL_PROMPT=0 plus
  BatchMode unless GIT_SSH_COMMAND is set, rejected-push advice (:943-1005).
- setup-user-config: outcomes created/updated/verified/recovered (WARN), exit 0/1 never 2,
  bad-arguments ERROR for both flags, info routing of cache warnings, the one ACTION after
  the config row with its counted log_warn, precedence of the three advice texts
  (setup-user-config.sh:72-106, 165-189, 331-381; .ps1 :83-103); version 3; machineAlias
  not saved from AITOOLS_MACHINE_ALIAS or a hostname match; userRepoPath not saved from
  AITOOLS_USER_REPO_PATH (aitools-profile.sh:1157-1185).
- build-deploy: dotprofile from AITOOLS_USER_REPO_PATH else resolve_user_repo_path in a
  child bash, config.json not read; the entry points do not export the variable (draft
  L47 is right; only check-pre-push sets it) (m3-b5:scripts/build-deploy.sh:170-215).
- Templates (m3-b4:scripts/setup-user-claude.sh / .ps1): token list, display forms (~/...,
  %USERPROFILE%\...), one-pass literal substitution, empty value keeps its token, adopt
  filter longest first with PROFILE_NAME winning equal text, ERROR `claude.md` `not
  deployed: dotprofile unresolved`, footer format, PowerShell footer without arch
  (.sh :65-214, .ps1 :77-185). Snapshot keys version, identity, cursor, profiles
  (aitools-json.pl:38, 285-291). Resolver embedding into claude/settings/cursor deploy
  scripts and the build failure for an unembedded dependency (build-deploy.sh:355-545).
- Parity (bash/PowerShell): resolver commands, owner rule, exception-set refusals,
  derive-config machineId rule, register exit 4 messages, migrate (aitools-profile.ps1:451-459,
  568-574, 904-906, 1031, 1136-1177, 1251-1315); write_summary OK -> WARN in both
  (aitools-lib.sh:860-869, .ps1 :752-761); jsonl escaping in both (aitools-lib.sh:488-540,
  .ps1 :435-463); relay counters (sh :478-485, 559-560; ps1 :409-416, 482-483).
- Tree draft: every cited line range in its header and edits 3-7 (aitools-lib.sh:314-369,
  371-402, 404-464; .ps1 :307-335; aitools-profile.sh:31-38, 900-941, 943-1005, 969-972,
  990-993, 996-999, 1021-1135, 1044-1074, 1085-1087, 1132, 1137-1191, 1180-1184);
  PS1 result names `$script:AitLibToolExcResult` / `AitLibToolExcPushed`; the "Not
  changed" Reader note (in-process `& aitools-profile.ps1`, aitools-lib.ps1:139-168).
- script-standards draft: every cited function line (sh :286, 333, 378, 419, 531, 569,
  589; ps1 :218, 263, 312, 350, 449, 489, 510); jsonl_record argument order; setup-user-config
  ordering comment (setup-user-config.sh:367-381).
- logging draft: cited lines aitools-profile.sh:39-43, 70-79, 81-85, 247-266; .ps1 37-41;
  aitools-lib.sh:150-227, 296, 307, 356, 363; section 6 is the last decision on main and
  "## Migration status" follows it.
- deploy-paths draft: cited build-deploy ranges; check-pre-commit step 13 still lists
  setup-user-claude/-cursor (m3-b5:scripts/check-pre-commit.sh:267), as the follow-up says.
- managed-file-deployment draft: main still has the first-profile fallback
  (origin/main:scripts/setup-user-claude.sh:116-119); /tool-adopt step 5 wording
  (origin/main:shared/skills/tool-adopt/SKILL.md:150, 159).
- dotprofile profile.json draft notes 1-5: migrate re-keys only profiles with machine.id
  (sh:1469-1481); this Mac's LocalHostName is `nobul-mac` (scutil), so today's resolve
  matches nobul-mac by hostname and picking it is refused with exit 4 and the --claim hint
  (sh:1339-1351); no command writes meta.intent (sh:1242); ui_commit has no dirty check
  (scripts/aitools:345-356). Live profiles as described (laptop/nobul-mac/workstation,
  no machine.id, no meta, no overrides).
- glossary draft code cites (aitools-profile.sh:25-30, 495-528, 1219-1431).
- "VERIFY after #86 batch 5" markers present on: confirm prompt for duplicate alias,
  --claim from the menu, Path 3 commit timing, menu showing alias/owner, user init
  running migrate. Missing on F1, F2 (partly), F3, F10.

Not checked (unknown): the PowerShell resolver line by line beyond the parity points
above; `S3-M3-Install` claim "aitools-install.sh at 9462ed0:136-137"; deploy-harness
(PR #88) claims; R16 coexistence of script-standards edits.

## 4. INCIDENT markers (not filed)

- INCIDENT: v1 -> v2 profile migration in `aitools user init` writes `~/.aitools/config.json`
  `machineAlias` directly with node and creates alias-keyed profiles without machine.id
  or alias (m3-rekey:scripts/aitools:121-242; aitools.ps1:130, 224-230), bypassing
  setup-user-config (the declared only writer) and the resolver.
- INCIDENT: stale comment claims the entry points export AITOOLS_USER_REPO_PATH
  (m3-b5:scripts/build-deploy.sh:173-174; m3-rekey:scripts/aitools-profile.sh:16-18); no
  entry point does.
- INCIDENT: for a profile.json that was dirty before exception-set, the wrappers advise
  "run git push in <dir>" although nothing was committed (aitools-lib.sh:443-447,
  .ps1:371-376); the wrapper header comments also still say 3 = "matched by hostname
  only or not at all" (aitools-lib.sh:413-414, .ps1:345-346), narrower than the refusals
  now shipped.
- INCIDENT: `aitools user init --alias <new>` without a terminal fails on an existing
  profile.json (F1) -- P-Q12 / commander decision 1 not met until batch 5.
