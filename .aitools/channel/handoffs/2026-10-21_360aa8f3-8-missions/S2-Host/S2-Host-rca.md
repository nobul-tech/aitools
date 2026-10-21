# S2-Host: RCA for this Mac resolving to the wrong machine profile

**Summary (5 lines)**
1. This Mac's kernel hostname is `Mac`, but `ComputerName` and `LocalHostName` are `nobul-mac` and `HostName` is not set. Every aitools matcher reads the kernel hostname (`os.hostname()`, `hostname -s`), so none of them matches the `new-mac` profile (`hostname: nobul-mac`).
2. The kernel name is not stable. Logs show `Mac` on 2026-06-21, `nobul-mac` from 2026-06-22T00:10Z to 03:05Z, and `Mac` again from 2026-10-16. The `new-mac` profile was written during that `nobul-mac` window, so it recorded a value that changes.
3. `config.json` has no `machineAlias` because `aitools user init` Path 1 (repo already cloned) only sets the alias when a hostname matches. It never prompts and writes nothing when the match fails. The installer never writes the alias.
4. The final fallback (`|| Object.values(p.profiles)[0]`) picks `laptop` and logs only `company=Nobul`, with no WARN. The one detector (`profile-check.js` NO_MACHINE_MATCH) prints to the console only, after the deploy has finished, and tells the user to run `aitools user init`, which cannot fix it. This exact failure was seen on 2026-06-17 and parked as "Uninvestigated" in a plan row; it never became an incident.
5. Recommended fix: (a) always persist `machineAlias` and prompt when there is no match, plus (c) make the fallback a logged WARN/ERROR. Add (b), a stable machine ID (IOPlatformUUID / MachineGuid / machine-id), as the matcher behind the alias. Do (d) right now: set `machineAlias: "new-mac"`.

---

## 1. Identity sources on this machine (observed 2026-10-20)

Command: `bash .scratch/session-360aa8f3-8/missions/S2-Host/ids.sh`

| Source | Value |
|---|---|
| `scutil --get ComputerName` | `nobul-mac` |
| `scutil --get LocalHostName` | `nobul-mac` |
| `scutil --get HostName` | `HostName: not set` |
| `hostname` | `Mac` |
| `hostname -s` | `Mac` |
| `node -e os.hostname()` | `Mac` |
| `uname -n` | `Mac` |
| `/Library/Preferences/SystemConfiguration/preferences.plist` | `LocalHostName = "nobul-mac"`, `ComputerName = "nobul-mac"`, no `HostName` key (file mtime Oct 16 19:32 local) |
| `ioreg ... IOPlatformUUID` | `3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5` (model `Mac17,7`) |
| `sw_vers` | macOS 27.0.1 (26A434) |

`~/.aitools/config.json` keys: `version, reposPath, repoPath, userRepoPath, googleDrives`. There is **no `machineAlias`** (file read in full). There are no `config.json.bak.*` files in `~/.aitools/` (`ls`), so its history cannot be reconstructed.

`profile.json` profiles (in key order): `laptop` (`Joses-MBP`, Nobul), `new-mac` (`nobul-mac`, nobul-tech), `workstation` (`NewcoPC`, nobul.tech).

## 2. Inventory: every code path that decides "which profile is this machine"

| # | Location | Identity source | Order / fallback | Logged? |
|---|---|---|---|---|
| 1 | `scripts/build-deploy.sh:206-239` (node block) | `cfg.machineAlias`, then `os.hostname().split('.')[0]` | alias → hostname → **`Object.values(p.profiles)[0]`** (`:219`) | `blog "Profile interpolation: name=… company=…"` (`:248`). Does not say which branch chose the profile. `catch(e){process.exit(1)}` + `2>/dev/null` hides errors. |
| 2 | `scripts/setup-user-claude.sh:105-131` | same as #1 (copy, `:117-119`) | same | `log "Profile interpolation: …"` (`:138`); WARN only when the profile is entirely unavailable (`:140-141`) |
| 3 | `scripts/setup-user-claude.ps1:112-145` | `$cfg.machineAlias`, then **`$env:COMPUTERNAME`** (`:132`) | alias → hostname (`-eq`, case-insensitive) → first key (`:140-142`) | same pattern |
| 4 | `scripts/aitools:983-999` (`user init` Path 1) | `os.hostname()` | first hostname match, else empty; `catch {}` + `2>/dev/null` | nothing on no-match |
| 5 | `scripts/aitools.ps1:906-925` (Path 1) | `os.hostname()` (node, same as bash) | same; `catch {}` + `2>$null` | nothing on no-match |
| 6 | `scripts/aitools:1039-1094` / `aitools.ps1:969-1025` (Path 2, fresh clone) | prompts for an alias; writes `machine.hostname = os.hostname()` | default Company comes from the **first profile** (`aitools:1047`) | console only |
| 7 | `scripts/aitools:1112-1157` / `aitools.ps1:1044-1079` (Path 3, new repo) | prompts for an alias (`'default'` if empty); writes `os.hostname()` | — | console only |
| 8 | `migrate_profile_v1_to_v2` `scripts/aitools:121-242` / `aitools.ps1:129-230` | prompts for an alias; writes `os.hostname()`; other v1 machines get `machineN` aliases | — | writes `config.machineAlias` (`aitools:240`) |
| 9 | Config write `scripts/aitools:1204-1224` / `aitools.ps1:1138-1158` | — | `if (process.argv[3]) cfg.machineAlias = …`, so an **empty alias writes nothing** | echoes only when set |
| 10 | `scripts/profile-check.js:115-181` | `os.hostname().split('.')[0]` | emits NO_MACHINE_MATCH whenever no hostname matches, **even if `machineAlias` is valid** (`:148-150`) | JSON to the caller |
| 11 | `check_profile` `scripts/aitools:62-115`; `Invoke-ProfileCheck` `aitools.ps1:84-126` | consumes #10 | yellow `printf`/`Write-Host`, then "Run 'aitools user init' to fix." | **console only, not in deploy.log**. Called *after* deploy (`aitools:1613`, `:1690`; `aitools.ps1:1505`, `:1590`) |
| 12 | Installer config merge `scripts/aitools-install.sh:421-469`, `aitools-install.ps1:320-352` | — | preserves `machineAlias`; recovers it from corrupt JSON; **never creates it** | `CHANGED:` lines for managed keys only |
| 13 | Generated `<userRepoPath>/deploy/setup-user-claude.{sh,ps1}` | none at runtime | company is **baked in at build time** (`deploy/setup-user-claude.sh:2055` and `.ps1:2209` say `- Company: Nobul`) | — |
| 14 | Footer only (not profile selection): `build-deploy.sh:319` (`hostname -s`), `:482` (`$env:COMPUTERNAME`), `setup-user-claude.sh:149`, `check-lib.sh:48`, `check-lib.ps1:49`, `ait-harvest.py:335` (`socket.gethostname()`) | kernel hostname | — | used as the `host` field in jsonl logs |

**Bash/PS1 parity differences**
- PS1 `setup-user-claude.ps1:132` matches on `$env:COMPUTERNAME` (NetBIOS: uppercase, at most 15 chars). The profiles it compares against were written with node `os.hostname()` (DNS hostname). PowerShell `-eq` is case-insensitive, but the length and NetBIOS-vs-DNS differences remain. The bash/JS matchers are case-sensitive `===`. Same profile, different answers on Windows: **INCIDENT** (parity).
- Path 2 and Path 3 in PS1 hardcode `shell: 'powershell'` (`aitools.ps1:1015`, `:1075`); bash uses `basename $SHELL`. Cosmetic.
- No profile-selection logic exists in any `check-*` script (`grep -rl machineAlias|profile-check scripts shared/hooks` lists only the files in this table).

## 3. When `nobul-mac` was recorded, and what changed

Evidence (scripts `history*.sh` in this directory):

| Time (UTC) | Event | Source |
|---|---|---|
| 2026-06-16/17 | Session 46ee1c2b: `aitools install` printed `No profile matches this machine (hostname: Mac)`; in the same terminal the zsh prompt was `new-jose@nobul-mac` and `hostname` printed **`nobul-mac.local`**. `aitools user init` took Path 1 ("User repo already exists") and printed no `machineAlias` line. | `aitools-nobul-jose/sessions/aitools/2026-06-20_46ee1c2b.jsonl` (grep context) |
| 2026-06-17 | Logged as "Profile match failure … Uninvestigated / TBD / DEFERRED" | `plans/tooling-resolution-and-artifact-registry.md:129`; `.aitools/channel/handoffs/handoff-46ee1c2b-1.md:77` |
| 2026-06-21T01:34Z – 20:31Z | jsonl `host` = `Mac`; interpolation `company=Nobul` | `checks.jsonl`, `deploy.jsonl`, `deploy.log` |
| 2026-06-22T00:10Z – 03:05Z | `host` = **`nobul-mac`**; interpolation `company=nobul-tech` (hostname match succeeded) | `deploy.jsonl` (146 rows), `checks.jsonl`, `deploy.log` |
| 2026-06-22T02:48Z (19:48 -07:00) | `new-mac` profile committed with `hostname: "nobul-mac"`, `shell: "bash"`, inside the commit "chore: adopt settings.json into profile.json" (Co-Authored-By Claude). It was **not** written by `user init` (that would have produced `os.hostname()` and a `$SHELL` of zsh). | `git -C aitools-nobul-jose show eb48c33` |
| 2026-06-22 … 2026-07-11 | deploy.log activity on several days with no interpolation lines; no jsonl rows | deploy.log day list |
| 2026-10-16T02:09Z → now | `host` = `Mac`; interpolation `company=Nobul` (fallback to `laptop`) | `deploy.jsonl`, `deploy.log` |

**What changed:** the kernel hostname, not the profile. It was `Mac` on 2026-06-21, `nobul-mac` for at least 3 hours on 2026-06-22, and `Mac` from 2026-10-16 to now. On 2026-06-16/17 it was `Mac` and `nobul-mac.local` within the same session.

**Why it changed:** unknown, not proven this session. What I observed is consistent with macOS deriving the kernel hostname dynamically when `HostName` is unset (which it is), for example from a network-supplied name. It is not consistent with someone persistently setting it. Hypotheses I did not verify: a DHCP- or reverse-DNS-supplied name `Mac` on one network versus the `LocalHostName` fallback on another, or a transient `sudo hostname nobul-mac` that a reboot reverted. To resolve this, the commander could check `~/.zsh_history` for `hostname`/`scutil` commands around 2026-06-21, and run `hostname` on the other network. Both are outside my access list.

**Bottom line:** the kernel hostname on macOS is not a stable identifier when `HostName` is unset, and the profile was recorded from a transient value.

## 4. Why `config.json` has no `machineAlias`

- `user init` **Path 1** (`aitools:979-1016`, `aitools.ps1:902-943`) sets `machine_alias` only on a hostname match. There is no prompt on no-match. On 2026-06-17 there was no `nobul-mac` profile yet (it was added 2026-06-22), so no match was possible. The alias stayed empty, and the config write (`aitools:1212`, `if (process.argv[3])`) silently skipped it. This is corroborated by the 46ee1c2b transcript, where `user init` printed no "machineAlias =" line.
- **Path 2 / Path 3 / v1 migration** do prompt, but this machine took Path 1 because the repo was already cloned.
- **Installer** (`aitools-install.sh:423`, `:449`) only preserves or recovers the key and never creates it.
- **`new-mac` was hand-added** to profile.json (eb48c33). Nothing writes the matching `machineAlias` when a profile is added outside `user init`.
- Whether `machineAlias` ever existed in this `config.json`: unknown (no backups). No code path I found deletes it.

## 5. RCA

### 5 Whys
1. **Why did deploy scripts say `Company: Nobul`?** build-deploy (`:217-219`) and setup-user-claude (`:117-119`) fell through to `Object.values(p.profiles)[0]` = `laptop`.
2. **Why did they fall through?** `machineAlias` is absent, and `os.hostname()` = `Mac` ≠ `nobul-mac`.
3. **Why is the alias absent?** `user init` Path 1 derives the alias only from a hostname match and never prompts. The `new-mac` profile was added by hand later, and nothing tied it to this machine's config.
4. **Why does the hostname not match?** The profile recorded a transient kernel hostname (`nobul-mac`, seen only on 2026-06-22). This Mac's kernel hostname varies (`HostName` unset), and the matchers read nothing stable.
5. **Why is a transient hostname the identity key, with a silent default?** The design (`reference/user-repo.md:84` "Fallback: hostname match, then first profile") treats the hostname as a dependable identifier and the first profile as an acceptable default. There is no requirement that a machine resolve *deterministically* or *loudly*, and no stable machine identifier exists in the schema.

**Root cause (systemic):** machine identity has no single owner and no stable key. It is re-derived independently in about 7 places from a mutable value (the kernel hostname). Selection degrades silently to an arbitrary profile, and the only writer of the deterministic key (`machineAlias`) skips writing it in exactly the case where it is needed.

### Swiss-cheese / three-layer table

| Layer | Barrier | Held? | Hole |
|---|---|---|---|
| Prevention | `user init` persists `machineAlias` | No | Path 1 never prompts; empty alias is skipped (`aitools:1212`) |
| Prevention | Profile created with a stable identifier | No | `new-mac` hand-written with a transient hostname; the schema has only `hostname` |
| Prevention | Spec forbids silent defaulting | No | `reference/user-repo.md:84` *specifies* first-profile fallback |
| Detection | Selection logs which branch chose the profile | No | `Profile interpolation: name=Jose company=Nobul` has no alias/branch/hostname and logs at `info` |
| Detection | `profile-check.js` NO_MACHINE_MATCH | Partly | Fires, but on the console only, after deploy, and not in deploy.log or `write_summary` |
| Detection | Remediation advice | No | "Run 'aitools user init' to fix" sends the user to the path that does not fix it |
| Audit | check-pre-commit / check-post-push validate profile resolution | No | No check reads profile.json or machineAlias |
| Audit | Known issue becomes an incident | No | Seen 2026-06-17, recorded as an "Uninvestigated/DEFERRED" plan row and handoff line; no incident, no owner |
| Audit | Cross-machine artifact correctness | No | `deploy/` bakes one machine's company into scripts committed for all machines (#13) |

**Recurrence risk: high.** Any network change on this Mac flips the outcome again, and every new machine added by hand or via Path 1 hits the same holes.

### Deficiencies (for the Commander to file)
- **INCIDENT:** `user init` Path 1 does not prompt for or persist `machineAlias` when no hostname matches. The empty alias is silently dropped (`scripts/aitools:983-999,1212`; `scripts/aitools.ps1:906-925,1146`). High.
- **INCIDENT:** silent first-profile fallback in `build-deploy.sh:219`, `setup-user-claude.sh:119`, `setup-user-claude.ps1:140-142`. No WARN, and the selected alias/branch is not logged. This violates `script-standards.md` "When analyzing code" (the feature reports success while picking the wrong profile). High.
- **INCIDENT:** `check_profile`/`Invoke-ProfileCheck` output goes to the console only (raw `printf`/`Write-Host`, not `log_warn`/`write_summary`). It runs after deploy, and its advice ("run aitools user init") does not remediate (`scripts/aitools:89-102`, `aitools.ps1:104-115`). Medium.
- **INCIDENT:** `profile-check.js:148-150` reports NO_MACHINE_MATCH even when a valid `machineAlias` is set. That produces a false warning once (a) ships. Low.
- **INCIDENT:** bash/JS match on `os.hostname()` (DNS, case-sensitive); `setup-user-claude.ps1:132` matches on `$env:COMPUTERNAME` (NetBIOS, case-insensitive). This is a cross-platform parity deviation. Medium.
- **INCIDENT (governance):** the profile match failure was recorded 2026-06-17 as "Uninvestigated" in `plans/tooling-resolution-and-artifact-registry.md:129` and the handoff, but never filed via `/incident`. The audit layer let a known defect go untracked for 4 months. Medium.
- **INCIDENT (design, feeds M3):** `build-deploy.sh` bakes the *building machine's* profile (company) into `<userRepoPath>/deploy/setup-user-claude.*`, which is committed and consumed by every machine. Even with correct identity, deploy/ is right only for whichever machine built last. High.
- **Spec note:** `reference/user-repo.md:84` (protected) codifies the silent fallback; `:139` claims the installer "detects" `machineAlias` when it only preserves it.

## 6. Fix options

### (d) Immediate remediation for this Mac (do first)
- Add `"machineAlias": "new-mac"` to `~/.aitools/config.json`. The installer merge (`aitools-install.sh:449`) and `user init` (`aitools:1212` only writes when non-empty) both preserve it. Then rebuild deploy/ (`bash scripts/build-deploy.sh`) and re-run `setup-user-claude`. Expect deploy.log `company=nobul-tech`.
- Optional, environmental: `sudo scutil --set HostName nobul-mac` pins the kernel hostname, so `hostname`/`os.hostname()` stop varying. It is a system setting change and needs the commander's call. It does not fix other machines.
- Caveat: deploy/ will still bake `nobul-tech`, which is wrong for `laptop` (Nobul). See the M3 note.

### (a) Always persist `machineAlias`; prompt on no match
- **Change:** in `user init` Path 1, when there is no hostname match (or more than one), prompt with a numbered list of existing aliases plus "new". On "new", run the Path 2 add-profile flow. Always write `cfg.machineAlias`. In non-interactive runs, `log_error` + `write_summary ACTION "" "run aitools user init to pick machine profile"`.
- **Artifacts:** `scripts/aitools`, `scripts/aitools.ps1` (both Path 1 blocks, kept in parity per `interactive-menus.md`; use `read -r < /dev/tty` / `[Console]::ReadLine()`), and `reference/user-repo.md` (protected, needs review).
- **Logging:** `log_ok "machineAlias = new-mac (source: prompt|hostname)"` to deploy.log.
- **Trade-off:** one prompt per machine, once. It does not help machines where a profile is added by hand without re-running init, unless paired with (c).

### (b) Stable machine ID in the profile
- **Change:** add `profiles.<alias>.machine.id`, read via a lib helper `get_machine_id` / `Get-MachineId`:
  - macOS: `ioreg -rd1 -c IOPlatformExpertDevice` → `IOPlatformUUID` (this Mac: `3D4DF2A5-…`; tied to hardware, survives OS reinstall)
  - Windows: `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` (changes on OS reinstall; duplicates on unsysprepped clones)
  - Linux: `/etc/machine-id` (duplicates on cloned images; Claude Code web containers are ephemeral, so key them on `AITOOLS_ENVIRONMENT=claude-code-web` instead)
- Matching order becomes `machineAlias` → `machine.id` → hostname (legacy) → **no silent default** (c). Write the id at user init / add-profile; backfill it for an existing profile when the alias is explicit.
- **Artifacts:** `scripts/aitools-lib.sh/.ps1` (new helper next to the sentinel-delimited environment block, so build-deploy can inline it), `scripts/profile-check.js`, all 7 consumers in §2, the profile.json schema (`reference/user-repo.md`, protected), and the platform paths in `reference/cross-platform-detail.md`. Per `script-standards.md` "KnownPaths empirical verification", verify the Windows registry read on the workstation (`# UNVERIFIED` until then).
- **Trade-off:** most deterministic. It is a schema change, and the IDs are semi-sensitive (hardware identifiers in a private repo, so acceptable but worth stating). Highest cost.

### (c) Make the fallback loud
- **Change:** replace `|| Object.values(p.profiles)[0]` with explicit resolution that returns `{alias, via: alias|id|hostname|none}`. On `none`: `log_error`, `write_summary ERROR "profile" "no machine match"` + `ACTION`, and leave `{{PROFILE_*}}` placeholders unresolved (or abort build-deploy), never another machine's values. Always log `profile=<alias> via=<branch> hostname=<h>`. Move `check_profile` before deploy and route it through `log_warn`/`write_summary`.
- **Artifacts:** `build-deploy.sh`, `setup-user-claude.sh/.ps1`, `profile-check.js`, `scripts/aitools`/`.ps1` (`check_profile`), `reference/user-repo.md:84` (protected).
- **Trade-off:** cheap and catches every future cause. It does not choose the right profile on its own.

### Recommendation
(d) now. Then (c) + (a) together as one small batch: they close the detection hole and the writer hole. Then (b) inside M3, where the schema is being redesigned anyway. The best design is one resolver function (JS module `scripts/machine-identity.js`, or a lib helper), called by all 7 sites, replacing the 3 copied node blocks. That also closes deploy-paths.md's "duplication risk" for this logic.

### How this feeds M3 (profile.json → config.json single writer)
- `machineAlias` is per-machine state, so it belongs in `config.json`, written by **exactly one** writer (`user init`, or the M3 single writer). The installer should keep "preserve only".
- The resolver should be the single reader. Consumers get `{alias, via}` instead of re-implementing the match.
- `deploy/` baking a machine-specific company is incompatible with cross-machine carry-forward. M3 should either resolve the profile at *runtime* in the generated scripts (embed all profiles plus the resolver) or drop per-machine fields from build-time interpolation.

## 7. Barrier analysis (replay with each fix in place)

| Decision point | (a) persist + prompt | (b) machine ID | (c) loud fallback | (d) set alias now |
|---|---|---|---|---|
| 2026-06-17 `user init` Path 1, no matching profile | **Prevents**: prompts; user picks or creates `new-mac`; alias written | Would write `machine.id` on the created profile | Not at this point | n/a |
| 2026-06-22 `new-mac` hand-added with a transient hostname | Not covered unless init is re-run | **Prevents** if the profile tooling records the id | Not at this point | n/a |
| 2026-10-16 hostname reverts to `Mac`; build-deploy runs | Alias wins and resolution is correct | id matches and resolution is correct | **Detects**: ERROR + ACTION; no wrong company shipped | Alias wins and resolution is correct |
| deploy/ committed with `Company: Nobul` | Correct for this Mac only | same | Blocked/unresolved | Correct for this Mac only |

- (a) prevents this incident's writer hole. It does **not** cover profiles added outside init.
- (b) removes the dependency on the mutable hostname (the class of failure behind Why 4). It is still silent on a miss without (c).
- (c) does not pick the right profile, but it turns every future miss, whatever the cause, from silent to visible. It is the only fix that covers unknown causes.
- (d) fixes this Mac today. It is behavioral and per-machine, so recurrence on other machines is unchanged.
- **None** fixes the build-time baking of deploy/ (#13). That is M3's problem.

## Verification for the fix (when implemented)
1. With `machineAlias` removed and `hostname` = `Mac`: build-deploy must emit `[error] … no machine match` + summary ERROR, never `company=Nobul`.
2. With `machineAlias=new-mac`: deploy.log shows `profile=new-mac via=alias`, `company=nobul-tech`; profile-check reports no NO_MACHINE_MATCH.
3. Path 1 `user init` on no match: prompts, writes the alias, and logs it, in both bash and PS1.

---
Artifacts in this directory: `ids.sh`, `history.sh`, `history2.sh`, `history3.sh`, `history4.sh` (read-only evidence collectors).
Not checked: `registries/incidents.json` (governed; use the `/incident` skill to confirm no existing entry before filing).
No WRITE_BLOCKED events. A `standing-order-guard` hook blocked `sed -n` for file reads; I switched to Read.
