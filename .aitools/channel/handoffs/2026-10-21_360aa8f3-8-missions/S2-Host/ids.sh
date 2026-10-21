#!/usr/bin/env bash
set -uo pipefail
for k in ComputerName LocalHostName HostName; do
  printf 'scutil %s: ' "$k"; scutil --get "$k" 2>&1
done
printf 'hostname: '; hostname
printf 'hostname -s: '; hostname -s
printf 'node os.hostname: '; node -e 'console.log(require("os").hostname())'
printf 'uname -n: '; uname -n
sw_vers
ioreg -rd1 -c IOPlatformExpertDevice | grep -E 'IOPlatformUUID|model'
echo '--- config.json'
cat /Users/new-jose/.aitools/config.json
echo '--- profile.json profiles'
node -e 'const p=require("/Users/new-jose/repos/aitools-nobul-jose/profile.json"); for (const [k,v] of Object.entries(p.profiles||{})) console.log(k, JSON.stringify({hostname:v.hostname, machine:v.machine, company:v.company, keys:Object.keys(v)}))'
echo '--- profile.json top keys'
node -e 'const p=require("/Users/new-jose/repos/aitools-nobul-jose/profile.json"); console.log(Object.keys(p), p.version||p.schemaVersion)'
