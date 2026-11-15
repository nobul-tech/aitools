"""Inspect incidents.json: meta, last open entry, round-trip fidelity. Usage: python inspect-reg.py <file>"""
import json
import sys

path = sys.argv[1]
raw = open(path, "rb").read()
d = json.loads(raw.decode("utf-8"))
print("top keys", list(d.keys()))
print("meta", json.dumps(d["meta"], ensure_ascii=True)[:600])
last = d["incidents"][-1]
print("last open id", last["id"], "keys", list(last.keys()))
print(json.dumps(last, indent=2, ensure_ascii=True)[:3000])
for ea in (False, True):
    out = (json.dumps(d, indent=2, ensure_ascii=ea) + "\n").encode("utf-8")
    print("round trip ensure_ascii", ea, out == raw, "crlf in raw", b"\r\n" in raw)
