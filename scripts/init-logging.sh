#!/usr/bin/env bash
# init-logging.sh — Initialize structured logging with auto-detected caller name.
# Source after aitools-lib.sh or check-lib.sh, before the OS guard.
# Enables log_error in guards for Datadog-parseable error messages.
# See .claude/rules/cross-platform.md "OS guard patterns".

_il_caller=$(basename "${BASH_SOURCE[1]}" .sh)
logging_init "$_il_caller"
