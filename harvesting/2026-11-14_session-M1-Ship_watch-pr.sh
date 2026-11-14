#!/usr/bin/env bash
# watch-pr.sh <pr>: print each check as it finishes; exit when none is pending
pr="$1"
prev=""
while true; do
    s=$(gh pr checks "$pr" --repo nobul-tech/aitools --json name,bucket,link 2>&1)
    if ! printf '%s' "$s" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' >/dev/null 2>&1; then
        echo "gh error: $s"
        sleep 30
        continue
    fi
    cur=$(printf '%s' "$s" | node -e 'const a=JSON.parse(require("fs").readFileSync(0,"utf8")); for (const c of a) if (c.bucket!=="pending") console.log(c.name+": "+c.bucket+" "+c.link)' | sort)
    new=$(comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur"))
    if [ -n "$new" ]; then printf '%s\n' "$new"; fi
    prev="$cur"
    pending=$(printf '%s' "$s" | node -e 'const a=JSON.parse(require("fs").readFileSync(0,"utf8")); console.log(a.length===0 ? 1 : a.filter(c=>c.bucket==="pending").length)')
    if [ "$pending" = "0" ]; then echo "ALL CHECKS DONE"; break; fi
    sleep 30
done
