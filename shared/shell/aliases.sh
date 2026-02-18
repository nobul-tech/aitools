#!/usr/bin/env bash
# AI Tooling shell aliases — source from ~/.bashrc or ~/.zshrc
# Usage: source "/path/to/ai-tooling/shared/shell/aliases.sh"

# Claude Code launcher with CLAUDE.md check
cc() {
  if [ ! -f "CLAUDE.md" ] && [ ! -f "CLAUDE.local.md" ]; then
    echo "No CLAUDE.md found in $(pwd)."
    read -rp "Create one with 'claude /init'? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      claude /init
    fi
  fi
  claude "$@"
}

# Quick resume last session
alias ccr='claude -c'

# Interactive session picker
alias ccs='claude --resume'

# ---------------------------------------------------------------------------
# clip2md -- Clipboard HTML -> Markdown with AI-powered naming
# Requires pandoc. Optional: Claude Code CLI for auto-naming and summaries.
# macOS only (uses osascript for clipboard access).
# ---------------------------------------------------------------------------

# Logging helper: appends to ~/Library/Logs/ai-tooling/clip2md.log
_clip2md_log() {
  local logdir="$HOME/Library/Logs/ai-tooling"
  mkdir -p "$logdir" 2>/dev/null || return 0
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '[%s] %s\n' "$ts" "$1" >> "$logdir/clip2md.log" 2>/dev/null
}

# AI helper: calls claude -p for filename + summary
# Outputs "filename|summary" on success, or "|summary" for summary_only mode.
# Returns non-zero on failure.
_clip2md_ai() {
  local md="$1"
  local summary_only="${2:-}"

  local prompt='Name this clipboard content saved as markdown. Analyze the actual body, not just headers or subject lines.

Filename rules:
- Lowercase, digits, hyphens only. No extension. Max 50 chars but shorter is better.
- Adapt to content type:
  Email/thread: compact-date-participant-topic (e.g. 250324-garcia-budget-review)
  Article/blog: source-topic (e.g. verge-ai-pricing)
  Docs: product-section (e.g. aws-iam-roles)
  Other: descriptive topic
- Dates: YYMMDD (e.g. 250324). Omit date if content has none.
- Be compact. Do not pad to fill 50 chars.

Summary: one line, max 80 chars, what the content is actually about.

Respond in EXACTLY this format with nothing else:
FILENAME|SUMMARY'

  local result
  result=$(printf '%s' "$md" | claude -p "$prompt" 2>/dev/null) || return 1

  # Normalize: strip newlines, trim whitespace
  result=$(printf '%s' "$result" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$result" ]; then return 1; fi

  # Parse on first pipe character
  local raw_name raw_summary
  if [[ "$result" == *"|"* ]]; then
    raw_name="${result%%|*}"
    raw_summary="${result#*|}"
  else
    raw_name="$result"
    raw_summary=""
  fi
  raw_name=$(printf '%s' "$raw_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  raw_summary=$(printf '%s' "$raw_summary" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Truncate summary to 80 chars at word boundary
  if [ ${#raw_summary} -gt 80 ]; then
    raw_summary="${raw_summary:0:80}"
    local trimmed="${raw_summary% *}"
    if [ -n "$trimmed" ] && [ "$trimmed" != "$raw_summary" ]; then
      raw_summary="$trimmed"
    fi
  fi

  if [ "$summary_only" = "summary_only" ]; then
    printf '|%s\n' "$raw_summary"
    return 0
  fi

  # Sanitize filename: lowercase, alnum + hyphens only
  local name
  name=$(printf '%s' "$raw_name" | tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9-]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')

  # Truncate to 50 chars at hyphen boundary
  if [ ${#name} -gt 50 ]; then
    local truncated="${name:0:50}"
    local at_hyphen="${truncated%-*}"
    if [ -n "$at_hyphen" ] && [ "$at_hyphen" != "$truncated" ]; then
      name="$at_hyphen"
    else
      name="$truncated"
    fi
    name="${name%-}"
  fi

  if [ -z "$name" ]; then name="clipboard"; fi

  # Reserved names (cross-platform safety)
  case "$name" in
    con|prn|aux|nul|com[1-9]|lpt[1-9])
      name="clip-$name" ;;
  esac

  printf '%s|%s\n' "$name" "$raw_summary"
}

# Clipboard HTML -> Markdown (requires pandoc)
clip2md() {
  # 1. Check pandoc
  if ! command -v pandoc &>/dev/null; then
    echo "clip2md: pandoc not found. Run 'aitools install' or 'brew install pandoc'" >&2
    _clip2md_log "error: pandoc not found"
    return 1
  fi

  # macOS only (uses osascript for clipboard)
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "clip2md: clipboard HTML extraction requires macOS (uses osascript)" >&2
    echo "clip2md: on Windows, use the PowerShell version instead" >&2
    return 1
  fi

  # 2. Extract clipboard HTML
  local html
  html=$(osascript -e 'the clipboard as «class HTML»' 2>/dev/null | \
    perl -ne 'print chr foreach unpack("C*",pack("H*",substr($_,11,-3)))')
  if [ -z "$html" ]; then
    echo "clip2md: no HTML content on clipboard" >&2
    _clip2md_log "warning: no HTML content on clipboard"
    return 1
  fi

  # 4. Strip Gmail noise (attrs, divs, nbsp)
  html=$(printf '%s' "$html" | perl -pe '
    s/\s*(style|class|target|saferedirecturl)="[^"]*"//gi;
    s/<\/?(div|span)[^>]*>//gi;
    s/&nbsp;/ /g')

  # 5-6. Convert via pandoc + clean output
  local md
  md=$(printf '%s' "$html" | pandoc -f html -t markdown | \
    perl -pe 's/\{=""\}//g; s/\x{00A0}/ /g; s/\x{202F}/ /g')

  if [ -z "$md" ] || [ -z "$(printf '%s' "$md" | tr -d '[:space:]')" ]; then
    echo "clip2md: pandoc produced empty output" >&2
    _clip2md_log "error: pandoc produced empty output"
    return 1
  fi

  # Word count (approximate, rounded to nearest 10)
  local word_count approx_words
  word_count=$(printf '%s' "$md" | wc -w | tr -d ' ')
  approx_words=$(( (word_count + 5) / 10 * 10 ))
  if [ "$approx_words" -eq 0 ] && [ "$word_count" -gt 0 ]; then
    approx_words="$word_count"
  fi

  # Join all args as the output filename (supports multi-word names)
  local outfile=""
  if [ $# -gt 0 ]; then
    outfile="$*"
  fi

  # 7. Determine mode
  if [ -z "$outfile" ]; then
    # --- AUTO-NAME MODE ---
    if ! command -v claude &>/dev/null; then
      echo "clip2md: auto-naming requires Claude Code CLI. Provide a filename or install claude." >&2
      _clip2md_log "error: autoname requires Claude Code CLI"
      return 1
    fi

    local temp_name=".clip2md-$$-$RANDOM.tmp"
    printf '%s' "$md" > "$temp_name"
    _clip2md_log "wrote temp $temp_name"

    # Call claude for filename + summary
    local ai_result
    ai_result=$(_clip2md_ai "$md")
    local ai_exit=$?

    if [ $ai_exit -ne 0 ] || [ -z "$ai_result" ]; then
      echo "clip2md: claude failed to generate filename" >&2
      _clip2md_log "error: claude failed"
      rm -f "$temp_name"
      _clip2md_log "cleanup: removed $temp_name"
      return 1
    fi

    local base_name="${ai_result%%|*}"
    local summary="${ai_result#*|}"

    # Collision avoidance
    local final_name="$base_name.md"
    local counter=2
    while [ -f "$final_name" ]; do
      final_name="$base_name-$counter.md"
      counter=$((counter + 1))
      if [ $counter -gt 100 ]; then break; fi
    done

    mv "$temp_name" "$final_name"
    _clip2md_log "renamed $temp_name -> $final_name"

    echo "Saved $final_name (HTML, ~$approx_words words)"
    if [ -n "$summary" ]; then
      echo "  $summary"
    fi
    _clip2md_log "saved $final_name (HTML, ~$approx_words words)"
  else
    # --- EXPLICIT NAME MODE ---
    # Ensure .md extension (strip if present, re-add)
    local name="${outfile%.[mM][dD]}.md"

    # Check overwrite
    if [ -f "$name" ]; then
      read -rp "$name exists. Overwrite? [y/N] " answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        _clip2md_log "aborted: user declined overwrite of $name"
        return 0
      fi
    fi

    printf '%s' "$md" > "$name"

    # Try AI summary if claude available
    local summary=""
    if command -v claude &>/dev/null; then
      local ai_result
      ai_result=$(_clip2md_ai "$md" "summary_only")
      if [ $? -eq 0 ] && [ -n "$ai_result" ]; then
        summary="${ai_result#|}"
      fi
    fi

    echo "Saved $name (HTML, ~$approx_words words)"
    if [ -n "$summary" ]; then
      echo "  $summary"
    fi
    _clip2md_log "saved $name (HTML, ~$approx_words words)"
  fi
}
