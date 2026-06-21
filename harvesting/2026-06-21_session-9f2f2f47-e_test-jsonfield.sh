#!/usr/bin/env bash
# Validate the escape-aware json_field regex against samples.
set -uo pipefail

json_field_old() {
    local json="$1" key="$2"
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
    if [[ "$json" =~ $pattern ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

json_field_new() {
    local json="$1" key="$2"
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*\"((\\\\.|[^\"\\\\])*)\""
    if [[ "$json" =~ $pattern ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

count_nl() {
    local c="$1"
    local stripped="${c//\\n/}"
    echo $(( (${#c} - ${#stripped}) / 2 ))
}

S1='{"tool_name":"Bash","tool_input":{"command":"echo \"line one\"\necho \"line two\"\necho \"three\""}}'
S2='{"tool_name":"Bash","tool_input":{"command":"git status"}}'
S3='{"tool_name":"Bash","tool_input":{"command":"echo \"a && b\" \necho ok"}}'

for label in S1 S2 S3; do
    sample="${!label}"
    old="$(json_field_old "$sample" command)"
    new="$(json_field_new "$sample" command)"
    echo "[$label] OLD => '$old' (nl=$(count_nl "$old"))"
    echo "[$label] NEW => '$new' (nl=$(count_nl "$new"))"
    echo "---"
done
