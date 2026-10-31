#!/usr/bin/env bash
# Context for ambiguous PR hits and existing incident ids (scratch, read-only).
set -uo pipefail
D=/Users/new-jose/repos/aitools/.scratch/session-remedwr/prs
R=/Users/new-jose/repos/aitools
ctx() { printf '\n=== %s\n' "$1"; grep -n -E -- "$2" "$3" | grep -E '^[0-9]+:\+' | head -n "${4:-8}"; }
files() { printf '\n=== files %s\n' "$1"; grep -E '^diff --git' "$D/$1.diff" | perl -ne 'print "  $1\n" if m{ b/(\S+)}'; }
for p in pr100 pr103 pr106 pr109 pr110 pr111 pr112 pr113 pr115 pr116; do files "$p"; done
ctx "pr109 node not found" 'node not found' "$D/pr109.diff"
ctx "pr112 node not found" 'node not found' "$D/pr112.diff"
ctx "pr116 GIT_TERMINAL_PROMPT" 'GIT_TERMINAL_PROMPT' "$D/pr116.diff"
ctx "pr116 AppendAllText" 'AppendAllText|mkdir -p "\$LOG_DIR"' "$D/pr116.diff"
ctx "pr116 rotate" '_rotate_log|Rotate-Log' "$D/pr116.diff"
ctx "pr106 rotate" '_rotate_log|Rotate-Log' "$D/pr106.diff"
ctx "pr101 first profile" 'first profile' "$D/pr101.diff"
ctx "pr106 AITOOLS_DEPLOY" 'AITOOLS_DEPLOY' "$D/pr106.diff"
ctx "pr106 MDM deploy" 'MDM deploy' "$D/pr106.diff"
ctx "pr110 backup_dir" 'backup_dir' "$D/pr110.diff"
ctx "pr111 rev-parse ps1" 'rev-parse|LASTEXITCODE' "$D/pr111.diff" 12
ctx "pr103 LASTEXITCODE" 'LASTEXITCODE = 1|Get-Command git' "$D/pr103.diff"
ctx "pr106 deploy_scripts" 'deploy_scripts=|deployScripts|DEPLOY_SCRIPTS' "$D/pr106.diff"
ctx "pr112 SHELL" 'SHELL' "$D/pr112.diff"
printf '\n=== incidents ids near lines\n'
for ln in 15 39 93 117 1752 1806 2066 2210 2808 3421; do
    perl -ne 'BEGIN{$t='"$ln"'} push @l,$_; if($.==$t){ for my $i (reverse 0..$#l){ if($l[$i]=~/"id":\s*(\d+)/){print "line $t -> id $1\n"; last} } ; exit }' "$R/registries/incidents.json"
done
printf '\n=== incidents status for those\n'
grep -n -E '"status"' "$R/registries/incidents.json" | head -n 0
python3 -I -c '
import json
d=json.load(open("/Users/new-jose/repos/aitools/registries/incidents.json"))
want=["first profile","per-machine values","node@22","backup_file before JSON","Hook scripts deployed without backup","bare `git push`"]
for arr in ("incidents","closed"):
    for i in d.get(arr,[]):
        t=i.get("title","")
        if any(w in t for w in want):
            print(arr, i.get("id"), i.get("status"), i.get("severity"), "|", t[:110])
print("max id open", max(i["id"] for i in d.get("incidents",[])), "closed", max([i["id"] for i in d.get("closed",[])] or [0]))
'
printf '\n=== pr102 drafted ids for push/cursor-node/first-profile\n'
python3 -I - "$D/pr102.diff" <<'PY'
import re,sys
txt=open(sys.argv[1]).read().splitlines()
add=[l[1:] for l in txt if l.startswith('+') and not l.startswith('+++')]
cur=None
for l in add:
    m=re.search(r'"id":\s*(\d+)',l)
    if m: cur=m.group(1)
    if '"title"' in l and any(k in l for k in ('bare `git push`','node not found','first profile','adopt_managed_file')):
        print(cur, l.strip()[:140])
PY
