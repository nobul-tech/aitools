RE-VERIFY: APPROVE

S3-FanoutImpl-Review124 re-verified #124 at head `7296a38`. The fix commits are 5267e9e, 3d351ac and 2fdcefb. The merge of origin/main after them, 2fdcefb..7296a38, only touches handoff `.md` files under `.aitools/channel/`, no code. My review N1-N4 are fixed, and I confirmed each with a probe, in .sh and .ps1. No blocking findings. Three new non-blocking items are listed below. Fix them as follow-ups (FO-5/FO-7) or in this PR, whichever the merge orchestrator prefers.

## N1-N4: verified

| Finding | Fix checked | Probe result (sh = ps) |
|---|---|---|
| N1 binary files | `_fanout_is_binary` / `Test-FanoutBinary` and `_fanout_copy_binary` / `Copy-FanoutBinary` (aitools-lib.sh:2853-2914, .ps1:2869-2935) | A NUL-holding `img.png` and a real PNG header `logo.png` with mode 755 are deployed byte-identical (`cmp`), exec bit kept, row `added`. The rerun is `3 verified`. After the harness copy changes: `updated`, bytes identical, `logo.png.bak.<UTC>` kept, no review menu. An invalid-UTF-8 (latin1) `notes.txt` with a user-edited DEST is overwritten byte for byte with `notes.txt.bak.<UTC>` kept |
| N2 OS junk blocks the prune | `_fanout_matches_ignoring_junk` / `Test-FanoutDirMatchesIgnoringJunk`, comparing a temp copy (FO-1's helper unchanged) | A retired `gone` holding `.DS_Store` is removed (`1 added, 1 removed`), and the backup keeps the `.DS_Store`. A retired `gone` with `Thumbs.db` is removed |
| N3 reserved names | `_fanout_skill_reserved` / `Test-FanoutSkillReserved` | A harness skill `synced` is a `failed` item, so the row is `ERROR 1 failed` and the run exits 1. Nothing is written into Claude Code's `synced/` tree (`synced/<uuid>/...` untouched, no `synced/SKILL.md`) |
| N4 DEST.bak retention | `_fanout_prune_dest_backups` / `Remove-FanoutOldDestBackups`, a literal regex | Seven `skills.bak.2026-01-0{1..7}T000000Z` dirs plus `skills.bak.2026-01-01T000000Z-1`, and the run's own new root: the newest 5 are kept (`01-04` to `01-07` and the new root), and `01-01`, `01-01-1`, `01-02` and `01-03` are pruned. The decoys `[skills].bak.2026-01-01T000000Z`, `skills.bak.[2026]`, `skills.bak.2026-01-01T000000Z.keep` and `skillsX.bak.2026-01-01T000000Z` are untouched |

The contract change in 5267e9e (with no `~/.aitools/skills`, an info log and no row) matches the code (aitools-lib.sh `fanout_harness_skills`, the `[ ! -d "$_fs_src" ]` branch, and its ps twin). claude-mdm now checks "no claude skills row".

## P1-P8 rerun (all sh = ps)

- **P1 live-like DEST:** the firecrawl-style relative symlinks are preserved. `fc2` (a symlink with a harness skill's name) is kept, with an ACTION row. `synced/` is untouched (now N3).
- **P2 `[ ] * ?` and space names:** deployed. The retired `gone [r]` is removed after a backup, and the decoy `gone` is kept. The rerun gives `4 verified`.
- **P3 retired skill with `.DS_Store`:** now removed (N2).
- **P4 exec bit `+x` and `a-x`:** follows the harness copy.
- **P5 dry run:** `OK dry run (no files written)`, nothing written.
- **P6 unreadable manifest:** `ERROR cannot read skills manifest`, failed item `.aitools-skills-manifest`, and the skill is still deployed.
- **P7 symlinked subdirectory:** written through. This is the library's documented behaviour, unchanged.
- **P8 binary:** byte-identical (N1). My first verdict gave the probe file as 15 bytes; it is 11, and it now deploys as 11.

## New non-blocking findings

- **R1: the binary test differs between sh and ps for surrogates and code points above U+10FFFF.** The perl `utf8::decode` (aitools-lib.sh:2853) accepts Perl's lax UTF-8. The .NET `UTF8Encoding(false, true)` is strict. I ran both detectors on the same files:

  | File | sh | ps |
  |---|---|---|
  | `\xed\xa0\x80` (surrogate) | text | binary |
  | `\xf4\x90\x80\x80` (above U+10FFFF) | text | binary |
  | `\xff`, `\xc0\xaf` (overlong), truncated `\xe2\x82` | binary | binary |
  | ASCII, `\xc3\xa9`, `\xef\xbf\xbe` | text | text |

  The deployed bytes are probably the same either way, but sh offers the review menu where ps does not. Fix: in the perl, decode strictly, for example `use Encode; eval { Encode::decode("UTF-8", $c, Encode::FB_CROAK); 1 } ? exit 1 : exit 0`. Add the two cases to the parity tests.
- **R2: a binary file at a DEST path that is a live symlink replaces the symlink.** Text files go through `deploy_managed_file`, which writes through a live symlink. `mv -f` (aitools-lib.sh:2902) and `File.Move(..., $true)` (.ps1:2920) replace the link itself. In my probe, `~/.claude/skills/s/b.bin -> ~/elsewhere/b.bin` became a regular file holding the new bytes. The link target was not updated, and the backup `b.bin.bak.<UTC>` is a copy of the old content (sh = ps). This fails safe, but it is inconsistent with the text path. Pick one behaviour and document it in FO-7.
- **R3 (documentation): any non-UTF-8 text file is now treated as binary.** That includes latin1 notes. A user's edit to the deployed copy is overwritten on every run without the review menu (a backup is kept). This is by design in 3d351ac, and FO-7 should say so.

## What I ran (macOS, isolated temp HOMEs)

| Run | Result |
|---|---|
| tests/skills-fanout (bash 5 + pwsh) | 168 passed, 0 failed, 1 skipped (case-only duplicate, APFS) |
| tests/skills-fanout --bash-only (/bin/bash 3.2) | 66 passed, 0 failed, 31 skipped |
| tests/claude-mdm (bash 5 / 3.2) | 38 / 38 passed, 0 failed |
| tests/rules-fanout (bash 5 / 3.2 --bash-only) | 118 passed, 1 skipped / 44 passed, 23 skipped; 0 failed |
| Probes P1-P8 + png / invalid UTF-8 / `.DS_Store` / `synced` / 7 DEST.bak roots with `[ ]` decoys / binary-over-symlink / UTF-8 detector parity | as above |
| `gh pr checks 124` on 7296a38 (run 40451332014) | windows, CodeQL and Analyze pass; **macos and linux were still in progress when I posted**. On the two earlier heads, fcf6edc (run 40447709562) and 5267e9e (run 40449035724), the only failed step was linux "Fan-out lib helper tests", case `bd-special` (ps and parity, 356 passed / 2 failed). That is the known FO-1 issue and I do not count it. This approval assumes 7296a38 is green apart from that. Any other red step is blocking |
