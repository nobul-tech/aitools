#!/usr/bin/env bash
# glossary-skill-guard.sh — Detection layer for governed data access
# Fires on Read/Grep of glossary files, reminds agent to use /glossary skill
# Part of the governed data access framework.
# See reference/framework-governed-data-access.md

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | perl -ne 'print $1 if /"file_path"\s*:\s*"([^"]*)"/')
PATTERN_PATH=$(echo "$INPUT" | perl -ne 'print $1 if /"path"\s*:\s*"([^"]*)"/')

TARGET="${FILE_PATH:-$PATTERN_PATH}"

case "$TARGET" in
    *glossary.json|*glossary.md)
        echo '{"hookSpecificOutput":{"additionalContext":"You are reading glossary files directly. Use /glossary skill instead — it provides the governed process for checking definitions, adding terms, and resolving ambiguities. Reading the file bypasses that process."}}' >&2
        ;;
esac
exit 0
