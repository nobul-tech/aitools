**Manifest-as-generator landed in v0.71.0.**

`setup-user-hooks.{sh,ps1}` + `build-deploy.sh` (§15-16) now *generate* hook deployment + `settings.json` registration by looping over `hooks-manifest.json`. The dev path reads the manifest at runtime; the self-contained MDM deploy path embeds the registration list (`REGS_JSON` / `$regs`) at build time, so the node merge block is identical dev and deploy. The ~10 hardcoded touchpoints per hook are gone — adding a hook is now one manifest entry.

`check-hook-parity.py` (post-push step 32) rewritten to verify the new invariant: both scripts are manifest-driven and no hardcoded per-hook registration list has resurfaced.

This was driven by a `/investigate` RCA: the recurring hook-registration drift class (7 incidents across v0.60–v0.70, one silent ~3 months) traced to the manifest being an audit source only, never the generator. Verified on bash (strip-and-regenerate + generated-deploy dry-run/live) and PowerShell (`MergeHookEntry` + `$regs` loop: 18 register once, idempotent); `check-post-push` 0 FAIL.

Also fixed a pre-existing latent MDM bug found while testing the generated deploy script: the preferences embed emitted `const effortLevel = high;` (unquoted → ReferenceError) whenever effortLevel was set.

The remaining #7 items (aitools-lib logging migration, old log-path cleanup, doc consolidation) are unaffected and still open.
