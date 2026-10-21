"""Print a markdown table (id, severity, title, source) of the S4-Review incident draft."""
import json

d = json.load(open("/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-incidents-draft.json"))
print("| Draft id | Sev | Title | Source finding |")
print("|---|---|---|---|")
for i in d:
    src = i["discoveryContext"].split("Found by mission ")[1].split(" (session")[0]
    print(f"| {i['id']} | {i['severity']} | {i['title']} | {src} |")
