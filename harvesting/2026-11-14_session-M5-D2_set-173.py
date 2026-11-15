"""Set closed incident #173's closedIn to the release version (keep the PR/SHA text). Usage: python set-173.py <incidents.json>"""
import json
import sys

path = sys.argv[1]
raw = open(path, "rb").read()
d = json.loads(raw.decode("utf-8"))
if (json.dumps(d, indent=2, ensure_ascii=False) + "\n").encode("utf-8") != raw:
    sys.exit("round trip not byte-identical; refusing to write")
old = "PR #144 (fix/console-and-profile, merge c66d4b1); release version unknown, pending a RELEASE_NOTES entry for #144"
new = "v0.76.2 (PR #144, fix/console-and-profile, merge c66d4b1)"
hits = [i for i in d["closed"] if i["id"] == 173]
if len(hits) != 1 or hits[0].get("closedIn") != old:
    sys.exit(f"unexpected #173 state: {[h.get('closedIn') for h in hits]}")
hits[0]["closedIn"] = new
c172 = [i for i in d["closed"] if i["id"] == 172][0]
print("172 closedIn", c172.get("closedIn"))
with open(path, "wb") as fh:
    fh.write((json.dumps(d, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
print("173 closedIn ->", new)
