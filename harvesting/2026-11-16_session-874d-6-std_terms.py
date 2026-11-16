"""Read-only lookup of governed terms (per /glossary 'Reading definitions')."""
import json
import sys

path = "/Users/new-jose/repos/aitools/registries/glossary.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
terms = data.get("terms", {})
for name in sys.argv[1:]:
    entry = terms.get(name)
    print("==", name)
    print(json.dumps(entry, indent=1, ensure_ascii=False) if entry else "  (not in terms)")
