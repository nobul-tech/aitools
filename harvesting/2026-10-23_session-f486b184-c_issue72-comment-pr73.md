Same class of gap in PR #73 (native profile resolver, `scripts/aitools-profile.ps1`):

- `tests/profile/test-profile.sh` (180 assertions, bash vs PS1 parity, byte-identical output including the files `register` writes) runs the PS1 resolver on macOS and Linux only, with its OS guard bypassed (`AITOOLS_PROFILE_TEST_ANY_OS=1`, `scripts/aitools-profile.ps1` OS guard).
- The suite never runs on Windows: it is bash-driven, and `scripts/aitools-profile.sh` stops at its MINGW/MSYS guard. The Windows job runs three native smoke commands only (`machine-id`, `hostname`, `resolve` without a dotprofile).
- So `resolve`, `derive-config`, `snapshot` and `register` -- including the `profile.json` write that is shared through git across machines -- have not run on Windows. Windows-specific behavior (path handling under `USERPROFILE`, line endings of written files, case-insensitive property names) is untested where it matters. Not observed failing; unverified.

Separate CI failure on #73, now fixed on the branch (d977807): the Windows step's intended `resolve` exit 1 became the step's exit code, because the runner appends `exit $LASTEXITCODE` to `shell: pwsh` steps. Worth a line in the CI-authoring guidance: a pwsh step whose last native call exits non-zero on purpose must end with `exit 0`.

Suggested addition to "Done when": the PS1 side of `test-profile.sh` (or a PS1 twin) runs natively on the Windows runner.
