#!/usr/bin/env bash
# gh-facts.sh -- read-only GitHub facts for pywinpty (M3-Fixes-D)
set -uo pipefail
echo "=== repo"
gh api repos/andfoy/pywinpty --jq '{full_name, owner_type: .owner.type, fork, archived, stargazers_count, forks_count, open_issues_count, pushed_at, created_at, license: .license.spdx_id, default_branch, has_security_policy: .security_and_analysis}'
echo "=== latest release"
gh api repos/andfoy/pywinpty/releases/latest --jq '{tag_name, name, published_at, author: .author.login}'
echo "=== recent releases"
gh api 'repos/andfoy/pywinpty/releases?per_page=6' --jq '.[] | "\(.tag_name) \(.published_at)"'
echo "=== last commits on main"
gh api 'repos/andfoy/pywinpty/commits?per_page=5' --jq '.[] | "\(.sha[0:8]) \(.commit.committer.date) \(.author.login // .commit.author.name) \(.commit.message | split("\n")[0])"'
echo "=== contributors (top 8)"
gh api 'repos/andfoy/pywinpty/contributors?per_page=8' --jq '.[] | "\(.login) \(.contributions)"'
echo "=== security advisories (repo)"
gh api repos/andfoy/pywinpty/security-advisories --jq 'length, (.[] | "\(.ghsa_id) \(.severity) \(.summary)")'
echo "=== global advisories for pip ecosystem pywinpty"
gh api 'advisories?ecosystem=pip&affects=pywinpty' --jq 'length, (.[] | "\(.ghsa_id) \(.severity) \(.summary)")'
echo "=== SECURITY.md"
gh api repos/andfoy/pywinpty/contents/SECURITY.md --jq '.path' 2>&1
echo "=== LICENSE"
gh api repos/andfoy/pywinpty/contents/LICENSE.txt --jq '.path' 2>&1
gh api repos/andfoy/pywinpty/license --jq '.license.spdx_id + " " + .path' 2>&1
echo "=== issue 564"
gh api repos/andfoy/pywinpty/issues/564 --jq '{title, state, created_at, updated_at}' 2>&1
echo "=== aitools issue 72"
gh issue view 72 --repo nobul-tech/aitools --json title,state,body,updatedAt,closedAt --jq '.title, .state, .updatedAt, .closedAt, .body'
