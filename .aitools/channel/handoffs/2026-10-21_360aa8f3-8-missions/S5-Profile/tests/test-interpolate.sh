#!/usr/bin/env bash
# test-interpolate.sh -- check the B4 interpolate_token helper (values with & $ / \)
set -euo pipefail
SHARED_CONTENT='Company: {{PROFILE_COMPANY}}
Name: {{PROFILE_NAME}} / {{PROFILE_NAME}}
Repo: {{USER_REPO_PATH}}
Left: {{IDENTITY_GIT_EMAIL}}'
interpolate_token() {
    local token="$1" value="$2"
    [ -n "$value" ] || return 0
    SHARED_CONTENT=$(TOKEN="$token" VALUE="$value" perl -0777 -pe 's/\Q{{$ENV{TOKEN}}}\E/$ENV{VALUE}/g' <<< "$SHARED_CONTENT")
}
interpolate_token "PROFILE_COMPANY" 'A&B $(echo pwned) \1 /x'
interpolate_token "PROFILE_NAME" "Jose"
interpolate_token "USER_REPO_PATH" "~/repos/aitools-nobul-jose"
interpolate_token "IDENTITY_GIT_EMAIL" ""
printf '%s\n' "$SHARED_CONTENT"
