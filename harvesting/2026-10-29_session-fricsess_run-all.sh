#!/usr/bin/env bash
# Run typed-prompts.py over every non-subagent archived aitools session, with a friction grep.
set -euo pipefail
dir=/Users/new-jose/repos/aitools-nobul-jose/sessions/aitools
files=()
for f in "$dir"/*.jsonl; do
    case "$f" in
        *_subagent-*) continue ;;
    esac
    files+=("$f")
done
python3 /Users/new-jose/repos/aitools/.scratch/session-fricsess/typed-prompts.py --max-chars 900 \
    --grep "${1:-why did|why is|again|i told|already said|stop |dont |do not|frustrat|overhead|worktree|draft|context|wast|hold up|not what|wrong|annoy|hmmm|no need to show|just write|just do|confus|lost here|messy|false start}" \
    "${files[@]}"
