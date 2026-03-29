# Operational Learning -- MC fix-and-ship

**Session**: 8236ca9c (delegated)
**Status**: Failure mode (D-1)
**Mission**: Verify and fix Stop hook registration changes from previous MC

## Findings

### Previous MC changes were structurally correct

The previous MC (stop-hook-registration) made changes to 3 files:
- `scripts/setup-user-hooks.sh` -- added resolve, dest, deploy, CMD vars, mergeHookEntry calls, and validation for 3 Stop hooks
- `scripts/setup-user-hooks.ps1` -- mirror of .sh changes
- `scripts/build-deploy.sh` -- added hook verification, HOOK_* reads, _embed_hook calls, PS1 embedding, and $hookFiles entries

The Session Commander's concern about duplication was investigated and found to be unfounded for this specific case. The `mergeHookEntry` calls are ONLY in `setup-user-hooks.sh` and are EXTRACTED by `build-deploy.sh` via sentinel markers (`extract_between`). They are NOT duplicated in `build-deploy.sh`'s template sections. The deploy/ output has each `mergeHookEntry('Stop', ...)` exactly once.

### Pre-existing bug found and fixed: undefined dest vars in deploy path

The deploy path (deploy/setup-user-hooks.sh and .ps1) had a pre-existing bug: the "Legacy dest vars" section only defined 2 variables (`HOOK_DEST` and `GUARD_DEST`), but the extracted sections reference 15 `*_DEST` variables. The 13 missing variables (GLOSSARY_DEST through HARNESS_DB_END_DEST) were undefined, which would crash the deploy script under `set -euo pipefail` (`-u` flag makes unbound variables fatal).

This bug existed before the previous MC's changes -- the 3 new Stop hook dest vars were just 3 more instances of the same pre-existing problem.

**Fix**: Added all 15 dest variable definitions to both the bash and PS1 deploy template sections in `build-deploy.sh`.

### No duplication issue

The concern raised in the session conversation -- that mergeHookEntry calls might be duplicated between setup-user-hooks.sh and build-deploy.sh -- does not apply here. Build-deploy.sh EXTRACTS the merge logic from setup-user-hooks.sh using sentinel markers. The sections it replaces are:
1. Hook deployment (cp from repo -> heredoc embedding)
2. Claude preferences (runtime profile.json read -> build-time embedding)

Everything else, including CMD variables, mergeHookEntry calls, and validation, is extracted verbatim.

## OL items

OL-44: The deploy path (MDM) had silent undefined-variable bugs for all hooks added after session-archive and standing-order-guard. Nobody caught this because the deploy path is rarely tested in practice -- `aitools` CLI uses the scripts/ path.

OL-45: The previous MC's approach was correct despite the Commander's concern. The MC correctly identified that mergeHookEntry calls belong ONLY in setup-user-hooks.sh (extracted by build-deploy.sh) and NOT in build-deploy.sh's template sections. The Session Commander's question "shouldnt build-deploy.sh generate from setup-user-hooks?" was answered affirmatively -- it DOES extract from setup-user-hooks.sh for the merge logic sections.

OL-46: The "Legacy dest vars" label was misleading -- it implied only 2 vars were needed for backward compatibility, when in fact ALL dest vars used by the extracted merge section need to be redefined in the deploy template.
