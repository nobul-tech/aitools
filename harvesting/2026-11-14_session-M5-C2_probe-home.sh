#!/usr/bin/env bash
# probe: does a pwsh started with HOME/USERPROFILE overridden see them as $HOME?
set -euo pipefail
S=/c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks/.scratch/session-M5-C2
mkdir -p "$S/probe-home"
W=$(cygpath -w "$S/probe-home")
HOME="$S/probe-home" USERPROFILE="$W" pwsh -NoProfile -Command '"HOME=$HOME"; "USERPROFILE=$env:USERPROFILE"; "GetFolderPath=" + [Environment]::GetFolderPath("UserProfile")'
