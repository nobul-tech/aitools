"""add-merge-allow.py -- add Bash(gh pr merge:*) to permissions.allow in a JSON settings file (scratch).

Usage: add-merge-allow.py <file> <json-path-to-settings>  (path "" = top level, "claude.settings" for profile.json)
Backs up the file first (<file>.bak.<UTC>), preserves key order, validates after writing.
"""
import json
import shutil
import sys
import time

RULE = "Bash(gh pr merge:*)"
path, keypath = sys.argv[1], sys.argv[2]
raw = open(path, encoding="utf-8").read()
data = json.loads(raw)
node = data
for k in [k for k in keypath.split(".") if k]:
    node = node.setdefault(k, {})
perms = node.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
if RULE in allow:
    print("already present in", path)
    sys.exit(0)
allow.append(RULE)
backup = path + ".bak." + time.strftime("%Y-%m-%dT%H%M%SZ", time.gmtime())
shutil.copy2(path, backup)
out = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
json.loads(out)
open(path, "w", encoding="utf-8").write(out)
check = json.load(open(path, encoding="utf-8"))
n = check
for k in [k for k in keypath.split(".") if k]:
    n = n[k]
assert RULE in n["permissions"]["allow"], "validation failed"
print("added", RULE, "to", path, "backup", backup)
