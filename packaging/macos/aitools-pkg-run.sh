#!/bin/bash
# aitools-pkg-run.sh -- aitools per-user setup runner for the macOS .pkg (package launcher)
#
# Installed to /Library/Application Support/aitools/bin/aitools-pkg-run.sh.
# Intent (batch B8b, plans/build-package/implementation-plan.md): run the user
# phase of the existing installer from the read-only payload. Steps when
# implemented:
#   1. refuse when run as root (only postinstall switches user; BP-10)
#   2. exit 0 at once when ~/.aitools/pkg-version equals
#      /Library/Application Support/aitools/VERSION (runs once per version, BP-13)
#   3. log to ~/.aitools/logs (standard location, BP-16)
#   4. AITOOLS_FORCE=1 (non-interactive: overwrite with backups), then run
#      "/Library/Application Support/aitools/repo/scripts/aitools-install.sh"
#      --phase user --package-mode (BP-6: no git pull, no build-deploy, adopt
#      disabled, gh auth skipped)
#   5. on success write ~/.aitools/pkg-version = VERSION; on failure leave it,
#      so the next login retries
# Run context: the console user (not root). Started by postinstall through
#   `launchctl asuser <uid> sudo -u <user> -H`, or at login by the LaunchAgent
#   tech.nobul.aitools.firstrun (BP-7). No terminal: never prompt.
# Platform: macOS only (bash 3.2, /bin/bash). Package launcher: exempt from the
#   .sh/.ps1 pairing (category "package launchers", BP-5, pending P-1).
# Follows: BP-2, BP-5, BP-6, BP-7, BP-10, BP-11, BP-13, BP-16.
# Safe to re-run: yes once implemented (version marker; managed files backed up).
#
# VERSION 1.0 SCAFFOLDING: refuses to run (exit 1).

set -euo pipefail

printf '[%s] [aitools-pkg-run] [error] not implemented in v1.0 scaffolding (batch B8, plans/build-package/implementation-plan.md)\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
exit 1
