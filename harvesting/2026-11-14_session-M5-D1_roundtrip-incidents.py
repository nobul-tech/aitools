"""Check which json.dumps settings reproduce registries/incidents.json byte for byte."""
import json
import sys
from pathlib import Path

p = Path(sys.argv[1]) / "registries" / "incidents.json"
raw = p.read_bytes()
text = raw.decode("utf-8")
print("CRLF:", b"\r\n" in raw, "trailing newline:", raw.endswith(b"\n"), "BOM:", raw.startswith(b"\xef\xbb\xbf"))
d = json.loads(text)
for indent in (2, 4):
    for ea in (False, True):
        out = json.dumps(d, indent=indent, ensure_ascii=ea)
        for tail in ("", "\n"):
            if out + tail == text:
                print(f"MATCH indent={indent} ensure_ascii={ea} tail={tail!r}")
print("done")
