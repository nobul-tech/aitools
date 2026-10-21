"""Print meta.intent (shape) of each registry JSON and selected glossary terms (read-only)."""
import json
import glob

for f in sorted(glob.glob("/Users/new-jose/repos/aitools/registries/*.json")):
    d = json.load(open(f))
    meta = d.get("meta", {}) if isinstance(d, dict) else {}
    intent = meta.get("intent")
    shape = type(intent).__name__
    keys = list(intent.keys()) if isinstance(intent, dict) else None
    print(f"{f.split('/')[-1]}: meta keys={list(meta.keys())} intent={shape} {keys}")

g = json.load(open("/Users/new-jose/repos/aitools/registries/glossary.json"))
terms = g.get("terms", g)
for t in ("alias", "config", "adoption", "accept & adopt", "environment", "platform", "provenance",
          "managed tool", "detection", "dotprofile", "dotprofile repo", "user", "verified", "registry", "exception"):
    v = terms.get(t) if isinstance(terms, dict) else None
    if v is None:
        print(f"-- {t}: (absent)")
    else:
        print(f"-- {t}: {json.dumps(v)[:400]}")
