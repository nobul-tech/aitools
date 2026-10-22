VERDICT: NO BLOCKING FINDINGS (B1 and B3 fixed; B2 minimum fix accepted, with the skip-writer question left to the commander)

# S3-H-MDM-Review: re-verification of PR #93 at 3e1a97d

Scope: the 3e1a97d diff (`scripts/build-deploy.sh`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`) checked against my earlier review (pullrequestreview-5621367406). All runs were on macOS with isolated HOMEs under scratch, and nothing in the repo was edited.

## Test suite

`bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`: **29 passed, 0 failed, 0 skipped**, the same as the commit message claims. Three cases are new: a corrupted block in the .sh, a corrupted block in the .ps1, and a truncated .sh.

## B1 (payload integrity): FIXED, verified by running it

- **Code:** `mdm_unpack` (.sh) and `Expand-MdmPayload` (.ps1) now take the size and sha256 as arguments and check both before writing anything. The unpacked count is compared with `MDM_EMBEDDED_BLOCKS` / `$mdmEmbeddedBlocks`. The .sh also requires the line `# --- END OF GENERATED SCRIPT (deploy-harness.sh) ---`.
- **My original repro, re-run** (the base64 of `dotprofile/claude/rules/dollar.md` replaced with `QUJD`):
  - exit **1**
  - `ERROR|harness files|1 embedded file(s) damaged`
  - `dollar.md` was not deployed; the other 135 were
  - Before the fix this gave exit 0, an OK row, and the file deployed with content `ABC`.
- **Extra case, truncated at a block boundary** (everything from the 50th `mdm_unpack` line onward removed): exit 1, `ERROR|harness files|script truncated`. This is the case I worried about, where bash ends quietly with exit 0. It is now caught.
- **Extra case, one whole block removed** (comment, call, base64 and delimiter of `nonl.md`; the rest of the script intact): exit 1, `ERROR|harness files|1 embedded file(s) damaged`, `nonl.md` not deployed. The count check catches it.
- **.ps1:** it has no end marker. I worked out by reading the code (not by running it) that truncation still fails: section 2 opens `try {` and the closing `} finally {` is the last block, so a truncated .ps1 gives a parse error and does not run. The new test case covers a corrupted block in the .ps1, per the commit.

## B3 (Windows build): FIXED by reading the code (still not run on Windows)

- **(a) Every path perl opens now arrives as a perl argument.**
  - `mdm_snapshot_dir`: a single perl gets `"$mode" "$raw" "$lsf" "$dir" "$stage_rel" "$MDM_MANIFEST"` as arguments. It writes both the listing and the manifest lines, so the `$src` and `$lsf` stored in the manifest come from converted arguments.
  - Bin entries are appended by perl from its arguments.
  - `mdm_emit_payload` gets the manifest path as an argument.
  - There are no bash `printf` writes of MSYS paths into the manifest any more.
- **(b) Executable bits come from `git ls-files -s -z`** (`100755` gives 1). Bin CLIs use `git ls-files -s -- <cli>`, with `-x` only as the fallback when a file is untracked or git fails (that case warns), and on the non-git disk fallback. A rebuild embeds 22 `exec=1` blocks, and the test's dev-vs-MDM exec-bit comparison passes.
- **Residual, non-blocking:** a tracked symlink (mode `120000`) is embedded with exec=0, while the dev path's `fix_exec` follows `-x` of the link target. No source directory has a symlink today, as far as I know.

## B2 (self-contained claim and fresh endpoint): MINIMUM FIX ACCEPTED

- The headers no longer say "Self-contained". They now say that deploy/ ships as a directory with the config writer, that config.json needs the installer's bootstrap keys, and that without them the run deploys the harness files and then exits 1.
- This matches what I see: an empty HOME still gives exit 1 with `ERROR|aitools config|missing bootstrap values` and `ERROR|harness files|config.json not generated`, plus `OK|harness files|136 added`.
- That is now honest, documented behaviour, so it no longer blocks.
- **Open for the commander:** should the MDM variant skip the writer, with an OK `n/a (no bootstrap)` row, when no bootstrap exists? My suggested answer is still yes, because otherwise Jamf and Intune report every first run as failed.

## Non-blocking items

- **N1 fixed:** the .ps1 directories are parsed and compared as a list. My earlier repro (`registries` changed to `registriesX` in the .ps1) now fails the build with exit 1.
- **N5 fixed:** the managed-scope span is extracted into both MDM headers.
- **N6 fixed:** the build warns on `git status --porcelain` output for each snapshotted directory.
- **N7 fixed:** the `mktemp` result is checked.
- **N2, N3 and N4 stay open as follow-ups.** N4 still reproduces: a reworded heading leaves 49 files and a partial `deploy-harness.sh`. The partial file now lacks the end marker, so if it is ever run it fails with "script truncated" instead of exiting 0. That makes N4 lower risk than before.

## Not verified

- Any Windows build or run. B3 is checked by reading the code only.
- The .ps1 truncation behaviour, which I reasoned about but did not run.
