"""Parse the tool registry and print the pywinpty entry's key fields and tool order."""
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
tools = list(data["tools"].keys())
print("parse: ok")
print("meta.lastUpdated:", data["meta"]["lastUpdated"])
print("tools order:", ", ".join(tools))
entry = data["tools"]["pywinpty"]
print("pywinpty keys:", ", ".join(entry.keys()))
print("platformStatus:", entry["lifecycle"]["platformStatus"])
print("versions.windows:", entry["versions"]["windows"])
