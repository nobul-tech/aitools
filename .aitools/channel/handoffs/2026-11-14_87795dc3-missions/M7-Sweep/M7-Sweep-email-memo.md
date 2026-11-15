# M7-Sweep email memo: the secondary Google account address in the public repo

Version 1.0, 2026-11-14. Written by M7-Priv for M7-Sweep (item 7 of M7-Sweep,
session 87795dc3). The address itself is never written here: it is called "the
secondary Google account address" throughout, and its path-sanitized form (the
address with `@` and `.` turned into `-`, as Claude Code names its
`~/.claude/projects/` directories) "the sanitized form".

**Intent**: **Purpose**: give the commander what he needs to decide whether to
rewrite git history, or replace the four `.tar` archives, to remove the
secondary Google account address from the public repository nobul-tech/aitools.
**Scope**: every location of the address (current files, `.tar` members,
history), what this PR removes and what remains, what history rewriting and
`.tar` replacement involve and cost, a recommendation, and other personal data
seen in the same files. NOT a change to history or to the `.tar` files (nothing
is rewritten; the commander decides). NOT edits to the other personal data
listed in "Other findings". **Audience**: the commander; M7-Sweep.

Commander's order (session 87795dc3, 2026-11-14): "25) launch mission go fix
them, dont bother filing incidents, check to see if these were already fixed by
the other running missions first, if not do it" (RFI fa81-25 suggestion: "Item 7
only gets a decision memo; nothing is rewritten.").

## 1. Decision needed

| # | Question | Suggested answer |
|---|----------|------------------|
| D1 | Rewrite git history to remove the address? | No (section 6) |
| D2 | Remove or replace the four `.tar` files on main? | Remove them from main in a follow-up PR (`git rm`), unless they are still needed; history keeps them either way (section 5) |
| D3 | Redact the other personal data listed in section 7 from the tip? | Yes for the private-matter folder name and the third parties' personal addresses, in one follow-up PR; the commander names which |

## 2. Where the address is (origin/main 5f962b1, before this PR)

Source: `git grep -n -I -i` with M7-Sweep's scan pattern on 5f962b1, and
M7-Sweep's scan (`email-scan.py` / `email-scan.txt` in its scratch), re-run
read-only by M7-Priv; first commits from `git log -S` (all refs).

### 2.1 Tracked text files (redacted by this PR)

| File | Line(s) on 5f962b1 | Form | What the line is | Commit that first added it there |
|------|--------------------|------|------------------|----------------------------------|
| `.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/S2-Layout/inventory2.txt` | 472, 473 | address (2) | a config dump: a Google Drive path, and its `"account"` value | `7d84197` 2026-10-20 (branch `docs/handoff-360aa8f3-8`, PR #53 head); on main through `c8573ed` 2026-10-20 (PR #53, "Handoff 360aa8f3-8 + housekeeping") |
| `harvesting/2026-03-22_6_40agent-human-messages.md` | 29 | address (2 on one line) | an `aitools install` log line ("Detected Google Drive: ... → ...") | `a417ae7` 2026-03-25 |
| `harvesting/2026-03-29_session-fbf7decb-9_1bc9fd30-full.md` | 2172, 2437, 2445, 2449, 2453, 2457, 2458 | sanitized form (7) | `~/.claude/projects/` directory names in `ls` output and `read-session.py` commands | `b504c43` 2026-03-28 ("swan song") |
| `harvesting/2026-03-29_session-fbf7decb-9_f078fb16-session.md` | 2838 | address (2 on one line) | a `config.json` `googleDrives` entry: path and `account` | `b504c43` 2026-03-28 |
| `plans/user-repo-and-session-hooks.md` | 197 | address (1) | a `googleDrives` example value | `500913a` 2026-02-19 ("Add session auto-archive via Claude Code SessionEnd hook") |

14 occurrences in 5 files, 12 lines. This PR replaces the address with
`<secondary Google account>` and the sanitized form with
`<secondary-Google-account>`; no other byte changes.

### 2.2 Files only in history

`a417ae7` (2026-03-25) also added six duplicates of the harvested file above:
`harvesting/2026-03-22_40agent-human-messages.md` and
`harvesting/2026-03-22_{1..5}_40agent-human-messages.md`. `d7a2d10`
(2026-06-21, "attempt to fix super slow harvest hooks") deleted them. They are
in every commit between those two and remain reachable from main.

### 2.3 The four `.tar` files (not touched)

All four were added by `63b7c85` (2026-10-31, "Fix harvest hooks: scratch names
verbatim, re-harvest only changes, archive retry, handoff discovery"); the
GitHub API lists no pull request for that commit. Git treats them as binary
(`git show --numstat` prints `-  -`; `git grep -I` skips them). Each holds
snapshots of the same five files, so each contains 14 occurrences:

| `.tar` file (size) | Members that hold the address (occurrences) |
|--------------------|---------------------------------------------|
| `harvesting/2026-10-29_session-ma-fci_main.tar` (31,191,040 bytes) | `.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/S2-Layout/inventory2.txt` (2), `harvesting/2026-03-22_6_40agent-human-messages.md` (2), `harvesting/2026-03-29_session-fbf7decb-9_1bc9fd30-full.md` (7, sanitized form), `harvesting/2026-03-29_session-fbf7decb-9_f078fb16-session.md` (2), `plans/user-repo-and-session-hooks.md` (1) |
| `harvesting/2026-10-29_session-ma106_main.tar` (33,617,920 bytes) | the same five members, same counts |
| `harvesting/2026-10-29_session-ma106_merged.tar` (33,669,120 bytes) | the same five members, same counts |
| `harvesting/2026-10-29_session-mg108_tree.tar` (32,583,680 bytes) | the same five members, same counts |

### 2.4 Every commit that changed the number of occurrences (`git log --all -S`)

`63b7c85` 2026-10-31 (adds the four `.tar` files); `c8573ed` 2026-10-20 and
`7d84197` 2026-10-20 (inventory2.txt); `d7a2d10` 2026-06-21 (deletes the six
duplicates); `b504c43` 2026-03-28 (two harvested session files); `a417ae7`
2026-03-25 (seven harvested copies); `500913a` 2026-02-19 (the plan).

## 3. What remains after this PR

- **The four `.tar` blobs on main**, at the tip, until they are removed. They
  are part of anything that copies the tree at main.
- **Every earlier commit.** The first occurrence is `500913a` (2026-02-19);
  1,110 of the 1,175 commits on main descend from it (`git rev-list --count
  --ancestry-path 500913a^..origin/main`). On GitHub (`git ls-remote origin`,
  2026-11-14): 119 of 125 branches contain `500913a` (the six that do not:
  `master`, `aigit-smoke/dd6fbde7-20260523T060352Z`, `claude/great-cray-R3Ne4`,
  `cursor/env-setup-agents-md-a271`, `cursor/rfc-mission-bridge-700b`,
  `nobul-grok/consolidated-tools-provenance`); all 9 tags (v0.69.0 to v0.74.0)
  contain it.
- **Pull request refs and diffs.** Of 139 `refs/pull/*/head` refs, 124 contain
  `500913a`, 5 do not (#2 to #6), 10 could not be checked locally (#34, #36,
  #39 to #43, #45 to #47: objects not fetched). PR #53's diff shows
  inventory2.txt being added. Open PRs at the time of writing include #156,
  #159, #165 to #169 and this PR.
- **Clones and worktrees.** This machine: one clone with 36 worktrees (`git
  worktree list`, 2026-11-14). Other machines and environments (the commander's
  Macs, Claude Code web, Cursor cloud) that cloned the repo: unknown count.
- **Other repositories.** `nobul-jose/aitools-failure-mode` (PRIVATE per `gh
  repo view`) has every `fm/*` branch containing `500913a`, so it holds the
  plan's copy in history. `nobul-jose/aitools` (PUBLIC): none of its `jose/*`
  branches contained `500913a` at this clone's last fetch (date unknown).
- **Forks**: `forkCount` 0 (`gh repo view nobul-tech/aitools`, 2026-11-14).
- **Caches outside GitHub** (search engines, archive services, mirrors):
  unknown. The repository has been public since at least its GitHub creation
  date, 2026-04-03 (`gh repo view`, `createdAt`); the whole history, back to
  2026-01-25, was pushed then or later.
- **Session transcripts.** The transcript of the M7-Priv session (and of
  M7-Sweep's scan) shows the address in tool output; the SessionEnd hook
  archives transcripts to the dotprofile `nobul-jose/aitools-nobul-jose`, which
  is PRIVATE (`gh repo view`, 2026-11-14).

## 4. What rewriting history would involve

Read in a browser (chrome-devtools) on 2026-11-14:
<https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository>.
Quotes are verbatim. The page documents git-filter-repo only; it does not
mention BFG, and no BFG fact in this memo was verified.

### 4.1 GitHub's procedure, quoted

- "Install the latest release of the git-filter-repo tool. You need a version
  with the --sensitive-data-removal flag, meaning at least version 2.47."
- "If you want to replace all text listed in ../passwords.txt from any
  non-binary files found anywhere in your repository's history, run the
  following command:" `git-filter-repo --sensitive-data-removal --replace-text ../passwords.txt`
- "If you want to delete a specific file from all branches/tags/refs, run the
  following command replacing PATH-TO-YOUR-FILE-WITH-SENSITIVE-DATA with the git
  path to the file you want to remove, not just its filename (e.g.
  src/module/phone-numbers.txt):" `git-filter-repo --sensitive-data-removal --invert-paths --path PATH-TO-YOUR-FILE-WITH-SENSITIVE-DATA`
- "Find out how many pull requests will be adversely affected by this history
  rewrite." ... "Once you move on to the next step, the rewrite becomes
  irreversible."
- `git push --force --mirror origin` -- "This command will fail to push any refs
  starting with refs/pull/, since GitHub marks those as read-only. Those push
  failures will be handled in the next section. If any other refs fail to push,
  you likely have branch protection turned on for that branch and will need to
  turn it off temporarily and redo the push."
- "If you only rewrite your history and force push it, the commits with
  sensitive data may still be accessible elsewhere:" "In any clones or forks of
  your repository" / "Directly via their SHA-1 hashes in cached views on GitHub"
  / "Through any pull requests that reference them".
- "You cannot remove sensitive data from other users' clones of your
  repository; you will have to send them the instructions from Make sure other
  copies are cleaned up: clones of colleagues in the git-filter-repo manual to
  have them do so themselves. However, you can permanently remove cached views
  and references to the sensitive data in pull requests on GitHub by contacting
  us through the GitHub Support portal."
- Support is given "The owner and repository name in question", "The number of
  affected pull requests", "The First Changed Commit(s) reported by
  git-filter-repo"; it will then "Dereference or delete any affected pull
  requests on GitHub. Deleting an entire pull request removes its conversation,
  reviews, and diffs.", "Run a garbage collection on the server to expunge the
  sensitive data from storage.", "Remove cached views."
- "Important: GitHub Support won't remove non-sensitive data, and will only
  assist in the removal of sensitive data in cases where we determine that the
  risk can't be mitigated by rotating affected credentials."
- "Collaborators must rebase, not merge, any branches they created off of your
  old (tainted) repository history. One merge commit could reintroduce some or
  all of the tainted history that you just went to the trouble of purging."

Side effects GitHub lists (quoted headings and key sentences):

- "Changed commit hashes: Rewriting history will change the hashes of the
  commits that introduced the sensitive data and all commits that came after."
- "Broken diff view for closed pull requests: ... This is true not only for the
  PR that introduced the sensitive data, but any PR that builds on a version of
  history after the sensitive data PR was merged".
- "Poor interaction with open pull requests: ... We recommend merging or closing
  all open pull requests before removing files from your repository."
- "High risk of recontamination: ... If a fellow developer has a clone from
  before your rewrite, and after your rewrite simply runs git pull followed by
  git push, the sensitive data will return."
- "Lost signatures on commits and tags: ... git-filter-repo will remove commit
  signatures and tag signatures for commits that pre-date the sensitive data
  removal as well."
- "Leading others directly to the sensitive data: ... clueful users with an
  existing clone will notice the history divergence and can use it to quickly
  and easily find the sensitive data still in their clone that you removed from
  the central repository."

### 4.2 What it would mean here

1. **Tool.** git-filter-repo (>= 2.47) is not a managed tool; it would go
   through `/tool-eval` before any install (user CLAUDE.md "Tool & Source
   Evaluation").
2. **Text blobs.** `--replace-text` with two literal rules (the address to
   `<secondary Google account>`, the sanitized form to
   `<secondary-Google-account>`) over every branch, tag and ref of a fresh
   clone. GitHub's text says it applies to "non-binary files".
3. **The `.tar` blobs.** Git classifies them as binary (section 2.3), so by
   GitHub's wording `--replace-text` would not change them (inference from the
   quoted sentence; not tested). Two options: drop them from all history
   (`--invert-paths --path` for each of the four), or rewrite them with a
   git-filter-repo blob callback that unpacks, edits and repacks each archive
   (a `.tar` header records each member's size and a checksum, so a
   different-length replacement cannot be a byte substitution). Dropping is
   simpler; it loses the archives everywhere.
4. **Scope of change.** The first changed commit would be `500913a`: 1,110 of
   1,175 commits on main get new hashes; 119 branches and all 9 tags are
   rewritten; about 124 pull requests lose their diffs or are deleted by Support
   (the number Support asks for).
5. **Coordination.** Merge or close the open PRs first (GitHub's
   recommendation); turn off branch protection on main for the force-push
   (`gh api repos/nobul-tech/aitools/branches/main` reports `protected: true`,
   2026-11-14); re-clone or carefully clean every clone: the 36
   worktrees on this machine, the commander's other machines, cloud
   environments; rebase (not merge) any surviving branch. Every commit SHA
   cited in RELEASE_NOTES.md, handoffs, mission reports, incidents and plans
   would point at a commit that no longer exists on GitHub.
6. **Other repos.** The private `nobul-jose/aitools-failure-mode` keeps its
   copy unless it is rewritten too (it is private, so the exposure is limited
   to its collaborators).
7. **Support may decline.** The address is not a credential. Whether GitHub
   Support treats an email address as sensitive data it will purge is unknown;
   without Support, PR refs and cached views keep the old commits reachable by
   SHA.

## 5. Replacing or removing the `.tar` files without rewriting history

| Option | Effect on the tip | Effect on history and size | Cost |
|--------|-------------------|----------------------------|------|
| Leave them | The address stays in four ~32 MB archives at main | none | none; anyone downloading or browsing main gets them |
| `git rm` the four files | Tip clean | Old blobs stay in history (no new data) | One PR; no tracked text file names any of the four archives (`git grep`, 2026-11-14); they are harvested session snapshots |
| Replace with redacted archives | Tip clean | Four new blobs (about 131 MB uncompressed) added on top of the four already in history | Regenerating four archives; no reader of them is known |

Either removal leaves the old blobs reachable through every commit since
`63b7c85`; only a history rewrite (section 4) removes those.

## 6. Recommendation

1. **Merge this PR** (the five text files). It is the change the commander
   ordered and costs nothing.
2. **Remove the four `.tar` files from main** in a follow-up PR, unless the
   commander still uses them. Reason: they are the only copies left at the tip,
   removal adds nothing to repository size, and replacing them adds another
   ~131 MB (uncompressed) of snapshots that no tracked file refers to.
3. **Do not rewrite history now.** Reasons: (a) the address has been public
   since 2026-04-03 at the latest, so copies already made cannot be recalled;
   (b) a rewrite changes 1,110 of 1,175 commit hashes, every tag and branch,
   and about 124 pull requests, and breaks the commit references across the
   harness's own records; (c) the open PRs and 36 local worktrees must be closed
   or rebuilt first; (d) GitHub Support only assists with "sensitive data" that
   cannot be mitigated by rotating credentials, and whether it would act for an
   email address is unknown, so a rewrite might still leave the commits
   reachable on GitHub by SHA.
4. **If the commander decides to rewrite anyway**, do it once, for every item
   in one pass (the address, the sanitized form, the private-matter folder name
   and the third-party addresses of section 7), at a moment with no open PRs,
   after a `/tool-eval` of git-filter-repo, and contact GitHub Support with the
   affected-PR count.

## 7. Other findings for the commander (not edited)

Counts only; no address or name is copied here. Source: an email-pattern scan
of each file on 5f962b1.

| File | Distinct addresses (occurrences) | What they are |
|------|----------------------------------|---------------|
| `harvesting/2026-03-29_session-fbf7decb-9_1bc9fd30-full.md` | 9 (85) | the commander's work address, which also appears in tracked sources such as `scripts/setup-user-claude.sh` and `shared/cursor-rules/user-rules.md` (36); three addresses at two other company domains that appear to be the commander's (41; not verified); two colleagues' addresses at the commander's company domain (2 each); one third party's address at another company (2); two automated sender addresses of public services (1 each) |
| `harvesting/2026-03-29_session-8a9efdbb-0_f5fa-latest4.txt` | 7 (13) | four personal-name addresses of individuals at a third-party company (7); one role address at that company (2); the commander's work address (1) and a Drive-path token built from it (3) |
| `.aitools/channel/relay.md` | 1 (1) | one of the addresses at another company domain that appear to be the commander's |

**A private matter in a folder name.** The sanitized directory names in
`harvesting/2026-03-29_session-fbf7decb-9_1bc9fd30-full.md` (the seven lines in
section 2.1) continue with a Google Drive folder name that identifies a private
personal matter of the commander (not quoted). This PR leaves that folder name
in place (only the address part is redacted). The same folder name appears on
20 lines in 8 tracked files: that file (10),
`harvesting/2026-03-29_session-8a9efdbb-0_f5fa-latest4.txt` (1),
`harvesting/2026-03-29_session-fbf7decb-9_1bc9fd30-text.md` (1),
`harvesting/2026-03-29_session-fbf7decb-9_f078fb16-session.md` (1),
`harvesting/2026-03-25_session-c0dc2ddc-f_consolidated-operational-learning.md`
(1), `rfcs/0001-nobulai-tools-product-definition.md` (1),
`rfcs/0001-v2-nobulai-tools-product-definition.md` (4) and
`rfcs/rfc-0004-v3-harness-architecture.md` (1); the four `.tar` files hold
copies of the harvested ones. This is likely more sensitive than the address.

## 8. Harvester check

Editing harvested files is safe for the harvester (`scripts/ait-harvest.py`):

- It records no content hash. `harvesting/harvest-manifest.json` (gitignored,
  local only) keys entries by file name (`harvested`, `session`, `description`,
  `type`, `language`, `status`, `promotedTo`, `pruneAfter`); the three edited
  harvested files keep their names.
- The per-directory harvest record (`.harvested`, function
  `_read_harvest_record`) stores the size and mtime of the scratch source file,
  not of the copy in `harvesting/`, so editing a copy does not make the
  harvester copy it again.
- The SessionStart audit (`_audit_manifest`) uses the base names of paths ever
  committed under `harvesting/`; names are unchanged.
- No check script reads these files' content (`scripts/check-*` and `tests/`
  searched for `harvesting`; `check-path-refs.py` skips `harvesting/`).

## Sources

- M7-Sweep's scan: `email-scan.txt` and `email-scan.py` in
  `.claude/worktrees/m7-docs/.scratch/session-M7-Sweep/` (scratch, untracked).
- Git queries run read-only by M7-Priv on 2026-11-14 against
  `C:\Users\jdpal\repos\aitools`: `git grep -n -I -i`, `git log --all -S`,
  `git rev-list --count`, `git ls-remote origin`, `git tag --contains`,
  `git branch -r --contains`, `git merge-base --is-ancestor`,
  `git worktree list`.
- `gh repo view` (nobul-tech/aitools, nobul-jose/aitools,
  nobul-jose/aitools-failure-mode, nobul-jose/aitools-nobul-jose) and
  `gh api repos/nobul-tech/aitools/commits/<sha>/pulls`, 2026-11-14.
- GitHub Docs, "Removing sensitive data from a repository", read 2026-11-14 in
  a browser (URL in section 4).
