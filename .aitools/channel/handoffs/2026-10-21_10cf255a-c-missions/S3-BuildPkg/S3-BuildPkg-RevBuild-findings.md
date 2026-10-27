# S3-BuildPkg-RevBuild findings: build-deploy.sh and deploy-harness.sh/.ps1, reviewed for package-based distribution

Delegate: S3-BuildPkg-RevBuild (level 2, for S3-BuildPkg). Date: 2026-10-26. Read-only review; no code
changed, no commits. Line numbers are aitools `main` (`5976553`, checked out at `/Users/new-jose/repos/aitools`).

## 0. Summary (5 lines)

1. build-deploy.sh can already produce a package staging tree: set `AITOOLS_USER_REPO_PATH=<staging parent>` and the output lands in `<staging parent>/deploy` (L188, L218). With an EMPTY directory there, the build runs with no personalisation (verified: exit 0, 50 files, HOME untouched). It has no output-dir flag, no strict mode (every skip exits 0), and no version stamp.
2. Personalisation is whatever dotprofile it is pointed at. The script hardcodes no user. But a build from Jose's dotprofile embeds his CLAUDE.md template, his profile.json snapshot (identity, email, machine hostnames) and his rules into 6 scripts plus the deploy-harness snapshot. Such a build must never ship to a fleet.
3. The library is inlined 27 times per platform: once in 21 script pairs, twice in setup-user-claude/-cursor/-settings. A "sibling library" mode is cheap, because every source script already loads `aitools-lib` from its own directory, and the lib finds `aitools-profile` next to itself.
4. The dev deploy-harness cannot run from a package payload. Every source goes through `git rev-parse` and `git ls-files` (`add_source`, deploy-harness.sh:182-192), so a non-git tree gives one ERROR per source, nothing deployed except bin, and exit 1. The generated MDM variant (git shim plus snapshot, and #111's payload file) is the one a package can ship.
5. Both scripts write to `$HOME` / `$env:USERPROFILE` with no override and no console-user resolution. Under root or SYSTEM (pkg postinstall, Intune Win32 System context, dpkg postinst) they deploy into root's or SYSTEM's profile. Without a TTY, every differing file is overwritten.

## 1. Inputs of build-deploy.sh

### 1a. Environment variables

| Variable | Use | Citation |
|---|---|---|
| `AITOOLS_USER_REPO_PATH` | The dotprofile. When set, the resolver is not run. It is the **only** lever for the output location. | build-deploy.sh:188-189, 218 |
| (unset) → child bash runs `resolve_user_repo_path` | Sources aitools-lib.sh and calls `logging_init` in a child, so it reads `~/.aitools/config.json` and writes `~/.aitools/logs` under `$HOME`. The resolution order is env, argument, config, convention, then scan (`AITLIB_USER_REPO_VIA`, aitools-lib.sh:281-312). rc 1 or 3 skips the build with exit 0. | :190-209 |
| `AITOOLS_SUMMARY_FILE` | Dropped for the child (`env -u`) | :195 |
| `TMPDIR` | `BUILD_TMP` (`mktemp -d "${TMPDIR:-/tmp}/build-deploy.XXXXXX"`) | :315 |
| `BASH` | Child shell | :195 |
| `PERLIO` | Forced to `:perlio` | :39 |
| `HOME` | Not read by the build itself when `AITOOLS_USER_REPO_PATH` is set. Verified: an isolated HOME stayed empty (run in §3c). | grep of build-deploy.sh: `$HOME` appears only inside emitted heredocs (:1273-1274, 1478) |

### 1b. Config keys

build-deploy reads no config.json key itself ("config.json is not read here", :183). Only the child resolver path reads config.json, and which keys it reads belongs to the RevLib slice (`aitools-profile.sh`).

### 1c. Repo files (aitools, from `REPO_ROOT` = `$(dirname $0)/..`, :31)

- `shared/claude-shared.md`: required (:52-55).
- `shared/skills/*/SKILL.md`: at least one required (:57-70).
- `shared/hooks/hooks-manifest.json` and every file it lists, found in shared/hooks/ or scripts/ (:75-103).
- `scripts/sync-relay-to-cursor-agents.py`: must exist, but is not embedded (:106-110).
- `scripts/aitools-lib.sh` / `.ps1`: inlined.
- `scripts/aitools-profile.*` and `scripts/aitools-json.*`: resolver copies.
- `scripts/setup-*.sh` / `.ps1`: bodies.
- `scripts/deploy-harness.*`.
- The harness source directories parsed from the `add_source` lines: `reference`, `registries`, `shared/hooks`, `.claude/hooks`, `shared/skills`, `.claude/skills`, `shared/rules`, `.claude/rules` (:1711-1735), plus the bin CLIs (:1737-1748).

The snapshot takes the **working tree**. Uncommitted changes only WARN (:1771-1775), and a directory outside git is snapshotted whole from disk (:1776-1792).

### 1d. Tools

- node: required. Without it the build is skipped with exit 0 (:86-89). Used at :90, 1510, 1523, 1599, 1618.
- perl: core modules MIME::Base64, Digest::SHA and File::Find.
- git: optional, with a disk fallback.
- pwsh: optional. Without it the build only WARNs that PS1 validation was skipped (:2279).
- seq, tail, tr, mktemp, chmod.
- No network.

### 1e. What it personalises, and where (all from the dotprofile `_urp`)

| Content | Source | Embedded into | Citation |
|---|---|---|---|
| CLAUDE.md template | `$_urp/claude/CLAUDE.md`, else `shared/claude-shared.md` | the resolver "claude" block: setup-user-claude.sh/.ps1 | :244-254, 513, 561 |
| profile.json snapshot | `perl aitools-json.pl snapshot $_urp/profile.json` | setup-user-claude.* (the "claude" block) | :265-277, 515-517, 563-565, 601-603 |
| Cursor CLI defaults (vimMode, model) | profile.json `cursor.cli` | setup-user-cursor.sh/.ps1, via `subst_cursor_defaults` | :263-312, 820-886 |
| User rules | `$_urp/claude/rules/*.md` | setup-user-claude.* ("claude" block) **and** the deploy-harness snapshot (`dotprofile/claude/rules`) | :223-236, 518-521, 566-569, 1835 |
| Output location | `$_urp/deploy` (`rm -rf`, then `mv`) | n/a | :218, 616-618, 2298-2305 |

### 1f. Fleet (N users) and what assumes Jose

- **There is no hardcoded user in build-deploy.sh.** `grep -i -E "jose|nobul|/Users/"` matches nothing, and `$HOME` / `USERPROFILE` occur only in emitted runtime code. The tool is per-dotprofile: one build, one user.
- **Whatever dotprofile it is pointed at becomes the embedded identity.** For `aitools-nobul-jose`:
  - `claude/CLAUDE.md` mentions "jose" 5 times;
  - `profile.json` holds `"github": "nobul-jose"`, `"email": "jose@nobul.tech"`, and three machine `hostname`s (`Joses-MBP`, `nobul-mac`, `NewcoPC`) (grep, profile.json:4-74).

  All of it goes into setup-user-claude.* as the fallback for "a machine without the dotprofile" (:669-671, 681-685). On a fleet endpoint, which has no dotprofile, that fallback **is** what runs, so every user would get Jose's CLAUDE.md, identity and rules.
- **Shared content also names Jose's repo.**
  - `shared/claude-shared.md:29-30` links `nobul-jose/aitools`. This is the fallback template even with no dotprofile.
  - Shipped skills name him: `shared/skills/aitool-continue/SKILL.md:120` ("who Jose is"), :131/390/399 (nobul-ops).
  - The harness snapshot includes `.claude/rules` (26 project rules) and `reference/` / `registries/`. Eight reference files and three registries match `jose|nobul`, for example `reference/do-what-feels-right.md`, `registries/incidents.json`.
  - aitools is public, so this is not a secret leak. It is still not fleet-neutral content.
- **Fleet options:**
  - (a) one build per user dotprofile, giving N personalised packages;
  - (b) one neutral package, built with an empty "dotprofile", with per-user content resolved at run time from a live dotprofile found by the resolver (convention or scan). The endpoint then needs the dotprofile cloned, so git, network and auth;
  - (c) a neutral package plus a per-user data file next to it.

  build-deploy supports (a) as is and (b) by the empty-dir trick (§3c). It does not support (c).

## 2. Outputs

### 2a. Generated files (main: 50; #111 adds `deploy-harness.payload` = 51)

| # | File pair | How it is assembled | Lib copies | Citation |
|---|---|---|---|---|
| 1 | setup-user-claude.sh/.ps1 | `extract_between` on preamble, END preamble→BEGIN rules deployment, →BEGIN rules deploy logic, rules deploy logic, exit; plus generated "profile and template source" and "rules fallback" blocks; `inline_lib_*` with the **resolver-claude** block | 2 | :620-805 |
| 2 | setup-user-cursor.sh/.ps1 | `extract_span` header + `cursor body` (with `subst_cursor_defaults`) + exit; `inline_lib_*` with the **resolver** block | 2 | :807-909 |
| 3 | setup-cursor-ide-mcp, -vercelcli, -pandoc, -rust, -typst, -gh-cli, -python, -uv, -modal, -go, -datadog, -perl, -bash, -google-chrome, -user-shell (15 pairs) | header + `tail -n +2 src.sh` (.ps1: `cat`), then `inline_lib_*`; nothing else | 1 | :911-1195 |
| 4 | setup-user-mcp | `mcp body` + exit, `inline_lib_*` | 1 | :1197-1221 |
| 5 | setup-user-settings | `settings body` + exit, `inline_lib_*` with the **resolver** block | 2 | :1223-1252 |
| 6 | setup-user-skills | `skills body`→`BEGIN skill discovery`; then each SKILL.md as a heredoc `__SKILL_<NAME>__` (.ps1: `@' '@`); `deploy_embedded_skill` per skill × 2 destinations; exit | 1 | :1254-1449 |
| 7 | setup-user-hooks | `hooks body`→`BEGIN hook deployment`; each manifest file as a heredoc `__EMB_<FILE>__` (.ps1: a here-string in `$hookFiles`); `REGS_JSON` / `$regs` built from the manifest at build time; `END hook deployment`→`END hooks body`; exit | 1 | :1451-1634 |
| 8 | setup-user-config, aitools-profile | `tail -n +2` + `inline_lib_*` | 1 | :1636-1658 |
| 9 | aitools-json.pl / .ps1 | copied with a header | 0 | :1660-1673 |
| 10 | deploy-harness.sh/.ps1 | **main:** header + `extract_span` scope; `set -euo pipefail`→`# 2. Dotprofile` + `inline_lib_*`; MDM section 2 (perl check, truncation guard, `mdm_unpack` + `git()` shim); **base64 payload inline** (`mdm_emit_payload`); `# 3. The six directories`→EOF with `replace_once` adopt `""`; end marker. **#111:** body markers, a bootstrap check, and the payload moved to a sibling `deploy-harness.payload` whose sha256 is embedded in the scripts. | 1 | :1675-2203; pr111 diff build-deploy.sh hunks @1695-2483 |

Post-build steps:

- resolver-once check (:2210-2218);
- pwsh ParseFile on every .ps1 (:2225-2282);
- `chmod +x` (:2288);
- CRLF for .ps1 (:2294);
- staged swap (:2298-2305).

### 2b. Run-time sibling dependencies (F1), verified against the code

| Generated file | Needs beside it at run time | Citation |
|---|---|---|
| deploy-harness.sh/.ps1 | `setup-user-config.*` (called by path). That one needs `aitools-profile.*` and `aitools-json.*` beside it. With #111 it also needs `deploy-harness.payload`. | deploy-harness.sh:99, .ps1:89; build-deploy.sh:1905-1906, 2055-2056; pr111 `MDM_PAYLOAD="$SCRIPT_DIR/deploy-harness.payload"` |
| setup-user-config.* | `aitools-profile.*` and `aitools-json.*`, found through the lib's lookup "next to aitools-lib", which for an inlined lib means next to the script | aitools-lib.sh:168-172 (`d=dirname BASH_SOURCE[0]`; `${AITOOLS_PROFILE_SH:-$d/aitools-profile.sh}`) |
| setup-user-claude, -cursor, -settings | Nothing: the resolver is embedded and `AITOOLS_PROFILE_SH` / `_PS1` points at it (:525, 583) | |
| Every other script | Nothing beside it | |
| All of them | External tools: perl (JSON engine, deploy-harness unpack), node (hooks merge, cursor). git: the deploy-harness shim passes calls through, and the dev deploy-harness requires git. | MdmPkg Build notes §1 (re-checked at :1955-1959, 2004-2015) |
| State ordering | deploy-harness first: setup-user-cursor fans out `~/.aitools/rules` (:855, 895). deploy-harness needs the installer's bootstrap keys `reposPath` / `repoPath` (:1916-1919). | |

### 2c. Order comments (the only ordering that exists)

- build-deploy.sh:855 and :895: "Run deploy-harness.sh first: step 4 fans out ~/.aitools/rules".
- build-deploy.sh:1913-1914 and :2063-2064: "Run it FIRST in an MDM sequence".
- build-deploy.sh:1916-1919 and :2066-2069: bootstrap keys from aitools-install.

There is no manifest, entry point or run-all script in deploy/. This confirms MdmPkg Build notes §4.

### 2d. Verified, with a correction to the MDM report

- **The BUILD_TMP trap leak is real.** `trap 'rm -rf "$MDM_TMP"' EXIT` (:1706) replaces `trap _cleanup_build_tmp EXIT` (:320). My run left `run1/tmp/build-deploy.8s23k3` behind (`ls` after the build). #111 fixes it: `MDM_TMP="$BUILD_TMP/mdm"` with no second trap.
- **The library is in those scripts twice.** The "library twice" claim (:436-437) holds for 6 files: `RESOLVER_SH_FILES` / `_PS1_FILES` include aitools-lib, and the block is passed to `inline_lib_*` at :707, 803, 866, 907, 1239, 1251.
- **Correction:** the lib is not inlined in **every** generated script. aitools-json.pl/.ps1 carry none (:1660-1673). Per platform there are 27 copies (21 × 1 + 3 × 2), about 3.8 MB of .sh and 4.2 MB of .ps1 in total, using the MdmPkg lib sizes 140,653 / 154,937 B.

## 3. Reuse for packaging

### 3a. Can build-package call build-deploy.sh?

Yes, with caveats. There is no output-dir parameter, but the output is always `"$AITOOLS_USER_REPO_PATH/deploy"` (:218), so build-package can point the variable at a staging parent it owns.

The caveats:

- **The swap deletes `<parent>/deploy` first** (`rm -rf "$DEPLOY_DIR_FINAL"`, :2298), and the swap is not atomic. If `mv` fails after the `rm`, no deploy/ is left (:2298-2305).
- **Every skip exits 0** (:86-89, 203-217). A CI build-package that does not check that `<parent>/deploy` exists and is fresh will package nothing, or a stale tree, and pass.
- **PS1 validation is optional** (:2279). A Linux or macOS CI runner without pwsh ships unvalidated .ps1 files.
- **The snapshot is the working tree** (:1771-1775). A release build must run from a clean clone or archive at a tag.
- **There is no version, commit or build stamp** in any output (grep `version|rev-parse HEAD|describe`: none). A package cannot report what it carries, so Q4 (updates) has no data to work with.

### 3b. Flags that would make it a package builder

| Flag (suggested) | Effect | Where |
|---|---|---|
| `--out DIR` | Write to DIR instead of `<urp>/deploy`. Refuse a DIR that holds non-generated files. | :218, 616, 2298 |
| `--no-personal` | Skip the dotprofile entirely: no template, no profile snapshot, no rules, no cursor defaults, no `dotprofile` harness source. This works today with an empty directory (§3c); a flag would make it explicit and testable. | :222-312, 1835 |
| `--strict` | Every skip becomes exit 1 (node, dotprofile, pwsh missing); uncommitted or non-git sources fail; size gates apply to all files. | :86-89, 203-217, 1771-1779, 2279 |
| `--lib sibling` | Do not inline the library. Copy `aitools-lib.sh/.ps1` once and keep each source's own `source "$(dirname BASH_SOURCE)/aitools-lib.sh"` line. Drop the resolver block, because the lib finds `aitools-profile` next to itself (aitools-lib.sh:171-172). | `inline_lib_*` :124-173; resolver :417-608 |
| `--payload sibling` | Already #111's behaviour for deploy-harness. Extend it to skills and hooks, which are the big embeds (192 KB and 130 KB, MdmPkg §2c). | :1254-1634 |
| `--stamp VERSION` | Write a `BUILD-INFO` file (version, aitools commit, dotprofile commit or "none", build time UTC) and one header line per generated file. | new |

### 3c. Empirical check: a no-personalisation build

Script: `/Users/new-jose/repos/aitools/.scratch/session-rvbuild/run-nodp.sh`. It ran:

```
env HOME=<scratch>/home TMPDIR=<scratch>/tmp AITOOLS_USER_REPO_PATH=<scratch>/nodp bash scripts/build-deploy.sh
```

where `nodp` was an empty directory, against main 5976553.

- **Result:** rc=0, "Build complete: 50 scripts generated", all PS1 files passed pwsh validation, and HOME stayed empty.
- **Log lines:**
  - "Template fallback: shared/claude-shared.md";
  - WARN "No profile.json ... embed no profile snapshot";
  - "dotprofile/claude/rules not found -- not embedded";
  - "Harness snapshot: 132 files from 7 source directories".
- **Sizes:** setup-user-claude.sh is 417,828 B (431,160 B with Jose's dotprofile per MdmPkg); deploy-harness.sh/.ps1 are 2,270,279 / 2,301,221 B. The other sizes match MdmPkg's main build.
- **Trap leak:** the leaked `tmp/build-deploy.8s23k3` was left behind.

### 3d. Or assemble directly from scripts/?

Only partly.

- **Possible:** for the 15 plain tool pairs plus setup-user-mcp, setup-user-config and aitools-profile, the deploy/ file is just the source plus the lib (§2a row 3). A package that ships `scripts/<x>` and `scripts/aitools-lib.*` side by side gets the same behaviour, with no build step and one lib copy.
- **Also possible:** dev setup-user-skills and setup-user-hooks read `$REPO_DIR/shared/...` (setup-user-skills.sh:42-43, setup-user-hooks.sh:54). A payload that mirrors the repo layout (`scripts/`, `shared/`, `reference/`, `registries/`, `.claude/`) lets them run unchanged.
- **Blockers:**
  - dev deploy-harness needs git work trees (§5);
  - dev setup-user-claude commits and pushes to the dotprofile on adopt (setup-user-claude.sh:371-382; RevSetup slice);
  - the dotprofile-sourced parts (template, profile, rules) need a dotprofile.
- **Suggested split:**
  - build-package assembles the plain scripts plus the lib directly;
  - it runs build-deploy (`--no-personal --lib sibling`, or the empty-dir trick until the flags exist) only for setup-user-claude, -cursor, -settings, -skills, -hooks and deploy-harness;
  - or, if the generated set is used whole, it calls build-deploy once into a staging parent.

## 4. Library inlining

- **How it works:** `inline_lib_bash` / `inline_lib_ps1` (:124-173) replace the **first** line that sources the lib with the whole lib, plus an optional BLOCK_FILE. The build fails if no such line exists.
- **Copies:** 1 per file, 2 in setup-user-claude/-cursor/-settings (the resolver block carries `aitools-lib.*` again, :436-437), 0 in aitools-json.*. That is 27 per platform. A post-build invariant requires exactly one resolver block in each of those 6 files (:2210-2218).
- **Switch to ship it once:**
  1. **Do not inline.** Every source already loads the lib from its own directory, for example setup-uv.sh:14, setup-user-claude.sh:32, setup-uv.ps1:9 and setup-user-claude.ps1:27. Copy `aitools-lib.sh/.ps1` into the output and emit the source line untouched.
  2. **Drop the resolver block in sibling mode.** The lib's `_aitlib_profile_run` already looks for `aitools-profile.sh` beside itself (aitools-lib.sh:171-172), and aitools-profile.* and aitools-json.* are already copied into deploy/ (:1642-1673). The resolver block is only needed for single-file distribution, which a package is not.
  3. **The "claude" fallbacks** (template, profile snapshot, rules; :511-522) would become sibling data files (`fallback/claude/CLAUDE.md`, etc.), or be omitted under `--no-personal`.
  4. **The post-build invariant** (:2210-2218) and #112's try/finally check become mode-dependent.
- **Effect:** each plain script drops from ~145-165 KB to ~5-30 KB. That removes the Intune 200 KB problem for every file except the skills and hooks embeds. Those disappear too if the skill and hook files ship as data.

## 5. deploy-harness.sh / .ps1

- **Sources** (deploy-harness.sh:254-272; .ps1:238-257):
  - `reference`, `registries` (tree);
  - `shared/hooks`, then `.claude/hooks` (flat);
  - `shared/skills`, then `.claude/skills` (units);
  - `shared/rules`, `.claude/rules`, then dotprofile `claude/rules` (flat-md);
  - bin: harness-db.py, read-session.py, read-session-full.py from `$SCRIPT_DIR`.

  The repo root is `$SCRIPT_DIR/..` (.sh:78; .ps1:76-77).
- **The git requirement:** `add_source` refuses any source that is not in a git work tree. It logs `log_error` and writes the ERROR row "`<label>: not a git checkout`" (.sh:181-186; .ps1:161-168). Only `git ls-files -z` entries are deployed (.sh:188; .ps1:174). **A package payload is not a work tree.** By code reading (not run), the dev script there gives an ERROR row for each of the 8 or 9 sources, deploys only the 3 bin CLIs (bin is not git-gated, .sh:266-272), and exits 1.
- **The .ps1 rev-parse check is defeated when git is not installed.** Verified with `/Users/new-jose/repos/aitools/.scratch/session-rvbuild/git-missing.ps1` (pwsh, macOS): `& <missing> ... 2>$null` leaves `$LASTEXITCODE` at its previous value (printed `LASTEXITCODE=0`), so .ps1:163-164 passes. The `ls-files` call then ends the try statement, `$lsRc` stays `$null`, and .ps1:182 reports "git ls-files failed" with an empty message. So it is not silent, but the error is misleading, and the "not a git checkout" guard never fires without git.
- **Outputs:**
  - `~/.aitools/{reference,registries,hooks,rules,skills,bin}`, each file through `deploy_managed_file` with the adopt target = the repo file (.sh:309; .ps1:289);
  - config.json, through the sibling `setup-user-config.*`;
  - with #100/#111, also `rules/.aitools-rules-manifest` (pr111 diff, deploy-harness.sh hunk @376).

  Preserved files are logged and never deleted (.sh:344-379).
- **Run context:**
  - `HARNESS_DIR="$HOME/.aitools"` (.sh:79) and `Join-Path $env:USERPROFILE ".aitools"` (.ps1:78). There is no override variable. Logs go to `$HOME/.aitools/logs` unless `AITOOLS_LOG_DIR` is set (aitools-lib.sh:72).
  - The work dir is `mktemp -d` (TMPDIR), removed by trap (.sh:81-87).
  - The review menu needs stdin to be a TTY. The plan is read on fd 3 for that reason (.sh:337-342).
- **Exit codes:** 0 done (warnings possible); 1 errors (duplicates, config.json not generated, git failures); 2 user abort at a menu (.sh:31-35, 404-413; the abort comes from the lib). Under #106, only deploy-harness's exit 2 stops a run (brief, commander decisions).
- **config.json bootstrap keys:** `reposPath` and `repoPath` (build-deploy.sh:1916-1919). Without them:
  - main: the writer fails, giving ERROR "config.json not generated" and exit 1 (.sh:111-114);
  - #111 MDM variant: `read_config_key` checks the keys and, if absent, sets `SKIP_CONFIG="no bootstrap"`, giving `OK|config.json|n/a (no bootstrap)` and exit 0.

  #111 also adds `--skip-config` / `-SkipConfig` on dev and MDM (pr111 diff, deploy-harness.sh hunks @65, @115). The dotprofile comes from `userRepoPath` in config.json (.sh:120-129); without it, dotprofile rules are skipped (info).
- **Run from deploy/ (MDM variant) vs from the repo:**
  - The MDM variant replaces section 2. Sources are unpacked to `$WORK/src/{aitools,dotprofile}`, `REPO_DIR`, `SCRIPT_DIR` and `DOTPROFILE` are re-pointed there (build-deploy.sh:2030-2032), and a `git()` function answers `rev-parse --is-inside-work-tree` and `ls-files -z` from `.aitools-mdm-ls-files`, passing any other call to the real git (:2004-2015; .ps1 :2141-2165, which returns 127 cleanly when git is missing).
  - Dotprofile rules are the **build-time** dotprofile's.
  - The adopt target is `""` (:2041, 2193).
  - Since the main build-time snapshot embeds files at build time, the MDM variant needs neither a repo nor git at run time.
- **What #111 changes:**
  - the payload becomes a sibling file, with a whole-file sha256 checked with CRs removed, then a size and sha256 check per record;
  - a path-traversal check;
  - marker-based extraction (`extract_markers`, `extract_marked`);
  - the truncation guard becomes the first command;
  - a no-bootstrap n/a path and `--skip-config`;
  - a size gate on deploy-harness only (ps1 ≥ 200,000 or sh ≥ 1,000,000 fails; within 5% warns);
  - an ASCII ps1 header;
  - the trap-leak fix.

  Sizes after #111: 177,181 / 190,907 B plus a 2,085,269 B payload (MdmPkg §2b).
- **#106** makes deploy-harness Step 8b of the installer and first in the sync. It calls it **without** `--skip-config`, because #111 is unmerged (pr106 diff L662-762, L413/447). If the script is absent it logs WARN "deploy-harness.sh not found -- skipping (MDM deploy)".

## 6. What breaks under root/SYSTEM, without a TTY, without git, without network, or on Linux

| Condition | Effect | Citation |
|---|---|---|
| **root / SYSTEM** (pkg postinstall, Intune Win32 System context, dpkg postinst) | Every target is `$HOME` / `$env:USERPROFILE`: deploy-harness (.sh:79, .ps1:78), skills (build-deploy.sh:1273-1274, 1371-1372), hooks (:1478, 1571), logs (aitools-lib.sh:72). They resolve to root's or SYSTEM's profile, not the console user's. Exact HOME values under each installer: **unknown** (not measured). No script resolves the console user (brief). If HOME is redirected while running as root, the files are root-owned in the user's home. | |
| **No TTY** (every MDM run) | The non-interactive fallback picks overwrite (interactive-menus.md "Non-interactive fallback"). A recurring run silently replaces user edits to `~/.aitools/**`, skills, hooks and CLAUDE.md (each is logged). Exit 2 cannot happen. This is Q5's default. | |
| **No git, build side** | Works: the snapshot falls back to disk (:1776-1792) and the bin mode to `-x` (:1845-1853), with WARN lines. | |
| **No git, dev deploy-harness** | Nothing but bin deploys, exit 1 (§5). | |
| **No git, MDM variant** | Works. The shim only passes non-snapshot calls through, which the lib uses for protected-file checks (:2001-2003). Whether any of those run with adopt `""`: unknown (RevLib). | |
| **No network** | build-deploy: none needed. deploy-harness: none needed. The dotprofile adopt push (#103, N-Q2) needs network but cannot happen on MDM (adopt `""`). | |
| **Linux / Ubuntu** | deploy-harness.sh's OS guard allows Linux (.sh:44-48). It uses perl, find, cut and mktemp; no BSD/GNU `stat` or `date` divergence was found in either script. | |
| **Linux perl modules** | The MDM variant needs Digest::SHA, MIME::Base64 and (#111) File::Path in perl at run time. Whether `ubuntu:22.04` / `ubuntu:24.04` images with only `perl-base` include Digest::SHA: **unknown**. Verify with `perl -MDigest::SHA -MMIME::Base64 -MFile::Path -e1` in both containers. No docker or podman was available here (`command -v` returned nothing). | |
| **Linux, other** | node is needed by setup-user-hooks and -cursor at run time (not deploy-harness). The `claude-code-web` environment exists only on Linux (cross-platform.md). Cursor cloud has no environment value yet (brief). | |
| **Windows build** | Git Bash only. PS1 validation hides the parser's stderr (`2>/dev/null`, :2239) but prints the messages on stdout. | |

## 7. Remediations

Severity follows incident-governance.md: critical = deployment, data loss, security, cross-machine propagation; high = silent wrong behaviour; medium = drift or inconsistency; low = cleanup.

1. **build-deploy.sh, top level (:218, 244-312, 511-522).** A build from a personal dotprofile embeds identity, emails, hostnames, CLAUDE.md and rules as the fallback that runs on any endpoint without a dotprofile. Shipped to a fleet, every user gets Jose's identity. **Critical.** Fix: a `--no-personal` mode, and build-package must refuse a non-empty dotprofile unless it is told this is a per-user build. No PR fixes this.
2. **deploy-harness.sh `add_source` / .ps1 `Add-Source` (.sh:181-192, .ps1:161-186).** The git work-tree requirement makes the dev script unusable from a package payload. **High** (exit 1 with nothing deployed, in a package context). Fix: ship the generated MDM variant plus its payload in packages, or add a source-listing mode, such as lifting the MDM `.aitools-mdm-ls-files` shim into the dev script behind a flag. #111 makes the MDM variant package-friendly but leaves the dev script as it is.
3. **deploy-harness.sh:79 / .ps1:78, and every emitted `$HOME` / `USERPROFILE` target.** There is no target-home override and no console-user resolution, so root or SYSTEM installs land in the wrong profile. **Critical** (deployment). Fix: the package's post-install runs the scripts **as** the console user, with HOME/USERPROFILE set (launchctl asuser / sudo -u; Intune "User" install context or a scheduled task; a per-user login hook on Linux). Optionally add `AITOOLS_HOME` to the lib. No PR.
4. **build-deploy.sh:86-89, 203-217, 2279.** Skips exit 0, and PS1 validation is optional. **High** for packaging (a silent empty or stale package). Fix: a `--strict` flag (or `AITOOLS_BUILD_STRICT=1`) that makes them exit 1. No PR.
5. **build-deploy.sh:1771-1779.** A dirty or non-git working tree is embedded with only a WARN. **Medium.** Fix: `--strict` fails it; build-package builds from a clean clone at a tag. No PR.
6. **build-deploy.sh, all outputs.** There is no version or commit stamp. **Medium** (blocks Q4 update detection). Fix: `--stamp` writes `BUILD-INFO` and a header line. No PR.
7. **build-deploy.sh `inline_lib_*` (:124-173) and the resolver (:417-608).** 27 lib copies per platform; 6 files carry two. **High** (7 .ps1 files over Intune's 200 KB). Fix: `--lib sibling` (§4). #111 fixes deploy-harness's size only, by moving the payload.
8. **build-deploy.sh, skills and hooks embeds (:1254-1634).** 192 KB and 130 KB of embedded data. **Medium.** Fix: sibling data files, in the same pattern as #111's payload. No PR.
9. **build-deploy.sh, size gate.** Only deploy-harness is gated, and only by #111 (pr111 build-deploy.sh @2467). **Medium.** Fix: gate every generated .ps1 at 200,000 B (and .sh at 1 MB) when a target needs single-file scripts. A package target can relax it. #111 covers part of it.
10. **build-deploy.sh:1706 vs :320.** The trap replacement leaks BUILD_TMP on every build (reproduced). **Low.** Fixed by **#111**.
11. **build-deploy.sh:2298-2305.** `rm -rf` and then `mv` is not atomic: a failed `mv` leaves no deploy/. **Medium** (with `--out` pointing at a release dir). Fix: `mv` the old dir aside, `mv` the new one in, then remove the old one. No PR.
12. **build-deploy.sh:2288.** `chmod +x ... 2>/dev/null || true` has no comment and no check (script-standards "Error handling requirements"). **Low.** Fix: check each file or comment the exemption. No PR.
13. **build-deploy.sh:2232-2239 (Windows branch).** `2>/dev/null` on the pwsh parse has no comment. **Low.** Fix: capture stderr into the error output, as the macOS branch does (:2259-2269). No PR.
14. **deploy-harness.ps1 `Add-Source` (:163-164, 174-176).** Without git, the stale `$LASTEXITCODE` passes the work-tree check and the ls-files error is empty (reproduced). **Low.** Fix: set `$global:LASTEXITCODE = 1` before the call, or check `Get-Command git` once and report "git not found". No PR.
15. **deploy-harness (main), config.json without bootstrap keys** (.sh:104-114). ERROR and exit 1 on any fresh endpoint. **High** for MDM and packages (every first run fails). Fixed for the MDM variant by **#111** (n/a row, exit 0). The package must still decide who writes `reposPath` / `repoPath`, or whether they make sense without a repo (RevSetup/RevInstall).
16. **No run-order manifest** (build-deploy.sh:855, 895, 1913, 2063: comments only). **Medium.** Fix: build-deploy emits `deploy/RUN-ORDER` (deploy-harness, then setup-user-config's dependants, ...), and the package's post-install reads it. No PR; #106 covers only the dev path.
17. **Shared content that names one user** (shared/claude-shared.md:29-30; shared/skills/aitool-continue/SKILL.md:120-131, 390-399). **Medium** for a fleet. Fix: tokenise or move to the dotprofile (protected file; commander review). No PR.
18. **Linux perl module availability** (MDM deploy-harness at run time). **Unknown severity until measured.** Fix: verify in ubuntu:22.04/24.04; if missing, the package declares a `perl` dependency (deb `Depends: perl`). No PR.

## 8. INCIDENT markers (not filed; the delegating agent files them)

- INCIDENT: build-deploy.sh embeds the build-time dotprofile's identity (profile.json snapshot: github, email, machine hostnames), CLAUDE.md template and rules as the run-time fallback for endpoints without a dotprofile (:244-312, 511-522, 669-685). Nothing marks a deploy/ as single-user, so a fleet package built from it would apply one user's identity to all users. (Remediation 1.)
- INCIDENT: dev deploy-harness.sh/.ps1 cannot run outside a git work tree (`add_source`, .sh:181-192). Every source gives an ERROR and only bin deploys, so a package that ships scripts/ as is fails on first run. (Remediation 2.)
- INCIDENT (re-confirmed, reproduced): build-deploy.sh:1706 replaces the :320 EXIT trap, so BUILD_TMP leaks on every build (`run1/tmp/build-deploy.8s23k3` remained). Fixed by #111.
- INCIDENT: build-deploy.sh exits 0 on every skip (node missing, no dotprofile, resolver error; :86-89, 203-217). That is correct for the `aitools` loop, but a CI or package build cannot tell a skip from a build except by checking the output. (Remediation 4.)
- INCIDENT: build-deploy.sh:2288 `2>/dev/null || true` and :2239 `2>/dev/null` have no explanatory comment, which deviates from script-standards "Error handling requirements". (Remediations 12, 13.)
- INCIDENT: deploy-harness.ps1:163-164 relies on `$LASTEXITCODE` after `& git ... 2>$null`. When git is absent the value is stale, so the work-tree guard passes (reproduced with pwsh 7 on macOS). (Remediation 14.)
- INCIDENT: generated outputs carry no build version or commit (grep of build-deploy.sh). (Remediation 6.)

## 9. Open questions, with suggested answers

- **Q-B1. Generic or per-user packages?** Suggested: one neutral package (`--no-personal`), with per-user data delivered separately (a dotprofile clone, or a per-user data file). Per-user packages multiply the build, signing and assignment work by N, and embed PII in an artifact.
- **Q-B2. Reuse build-deploy, or assemble directly?** Suggested: reuse build-deploy with new `--out`, `--no-personal`, `--lib sibling`, `--strict` and `--stamp` flags. That keeps one generator, as the I6 debt in deploy-paths.md argues. Until the flags exist, the empty-dir `AITOOLS_USER_REPO_PATH` trick plus a post-check of `<parent>/deploy` works today (§3c).
- **Q-B3. Which deploy-harness does a package ship?** Suggested: the generated MDM variant with #111's payload (no git needed). Make #111 a dependency of build-package.
- **Q-B4. Who writes the bootstrap keys on a package endpoint?** Unknown; it is the RevSetup/RevInstall slice. With #111, their absence is a non-error n/a row, but then config.json is never generated. Check what reads config.json afterwards.

## 10. Files and commands

- Read in full: scripts/build-deploy.sh (2310 lines), scripts/deploy-harness.sh (413), scripts/deploy-harness.ps1 (373); aitools-lib.sh:240-349 (resolver).
- The brief, MdmPkg Build notes and FanPlan Harness findings were read in full; §2d and §5 reuse them with citations.
- PR diffs: #111 (build-deploy.sh and deploy-harness.sh hunks), #112 (build-deploy.sh hunk), #100 (file list; its manifest code is inside #111's diff), #106 (deploy-harness call sites, via grep).
- Scratch (`/Users/new-jose/repos/aitools/.scratch/session-rvbuild/`):
  - `run-nodp.sh`, with its output in `run1/` (build.log, nodp/deploy, the leaked tmp/build-deploy.*);
  - `git-missing.ps1`.
- Not done:
  - The mission packet was read in full and all project and user rules were in context. The packet's reference subset was **not** read: script-standards-detail, cross-platform-detail, logging, managed-file-deployment, plan-execution-detail, harness. Nor were plans/tool-support-and-machine-profile.md and the 360aa8f3-8 handoff. reference/user-repo.md was checked only by grep (only :195 mentions build-deploy). Findings that cite rules cite the `.claude/rules` files, not those references.
  - Scratch is in the main checkout's `.scratch/session-rvbuild/`, as the launch prompt said. The packet §2 says a worktree. Nothing in the main checkout's tracked files was touched.
  - No Windows run.
  - No Ubuntu container.
- WRITE_BLOCKED: none.
