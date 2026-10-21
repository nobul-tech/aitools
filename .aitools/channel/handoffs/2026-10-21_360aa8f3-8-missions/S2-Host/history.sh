#!/usr/bin/env bash
set -uo pipefail
DP=/Users/new-jose/repos/aitools-nobul-jose
echo '=== profile.json log (with patch, hostname/profiles lines only)'
git -C "$DP" log --follow --format='--- %h %ad %an %s' --date=iso-strict -p -- profile.json | grep -E '^--- [0-9a-f]{7}|hostname|"(laptop|new-mac|workstation|default|machine[0-9])"|"company"'
echo '=== config.json backups'
ls -la /Users/new-jose/.aitools/ | grep -i config
for f in /Users/new-jose/.aitools/config.json.bak.*; do
  [ -f "$f" ] || continue
  echo "--- $f"; grep -E 'machineAlias|userRepoPath' "$f"
done
echo '=== deploy.log mentions'
ls -la /Users/new-jose/.aitools/logs/ | grep deploy
grep -hE 'Profile interpolation|machineAlias|profile:|No profile matches|hostname' /Users/new-jose/.aitools/logs/deploy.log* | tail -n 40
echo '=== first/last deploy.log timestamps'
head -n 1 /Users/new-jose/.aitools/logs/deploy.log
echo '=== generated deploy company lines in dotprofile'
grep -rnE 'Company: |Machine: ' "$DP/deploy" 2>/dev/null | head -n 10
git -C "$DP" log --format='%h %ad %s' --date=iso-strict -n 15
echo '=== system log hostname evidence'
defaults read /Library/Preferences/SystemConfiguration/preferences.plist 2>&1 | grep -iE 'HostName|ComputerName'
