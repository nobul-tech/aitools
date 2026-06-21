#!/usr/bin/env bash
set -uo pipefail
zsh -ilc '
print "agent   -> $(command -v agent)"
print "version -> $(agent --version 2>&1 | head -1)"
print "grok    -> $(command -v grok)"
print "grokver -> $(grok --version 2>&1 | head -1)"
'
