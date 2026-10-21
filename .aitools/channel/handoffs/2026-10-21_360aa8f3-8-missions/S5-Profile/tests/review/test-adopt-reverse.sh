#!/usr/bin/env bash
# test-adopt-reverse.sh -- B4 adopt_claude_md reverse substitution with a path value,
# written the way the plan prescribes (shell-interpolated into a perl s/// string).
set -euo pipefail
USER_REPO_DISPLAY="~/repos/aitools-nobul-jose"
content='Repo: ~/repos/aitools-nobul-jose
Other: text'
rc=0
out=$(printf '%s' "$content" | perl -pe "s/\\Q${USER_REPO_DISPLAY}\\E/{{USER_REPO_PATH}}/g" 2>&1) || rc=$?
printf 'plan form: exit=%s\n%s\n' "$rc" "$out"
# Existing adopt form with a value containing / or @ (company "A/B", email-like)
PROFILE_COMPANY="A/B"
rc=0
out=$(printf '%s' "Company: A/B" | perl -pe "s/\\Q${PROFILE_COMPANY}\\E/{{PROFILE_COMPANY}}/g" 2>&1) || rc=$?
printf 'existing form, company A/B: exit=%s\n%s\n' "$rc" "$out"
IDENTITY_GIT_EMAIL="jose@nobul.tech"
rc=0
out=$(printf '%s' "Email: jose@nobul.tech" | perl -pe "s/\\Q${IDENTITY_GIT_EMAIL}\\E/{{IDENTITY_GIT_EMAIL}}/g" 2>&1) || rc=$?
printf 'existing form, email with @: exit=%s\n%s\n' "$rc" "$out"
# Env-var form (safe)
rc=0
out=$(printf '%s' "$content" | V="$USER_REPO_DISPLAY" perl -pe 's/\Q$ENV{V}\E/{{USER_REPO_PATH}}/g' 2>&1) || rc=$?
printf 'env form: exit=%s\n%s\n' "$rc" "$out"
