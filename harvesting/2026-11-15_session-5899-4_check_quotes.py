#!/usr/bin/env python3
"""Compare section-1 quotes and every inline "..." quote in the plan against the commander's prompts."""
import json
import re
import sys

jsonl = sys.argv[1]
plan_path = sys.argv[2]

prompts = []
with open(jsonl, encoding="utf-8") as f:
    for line in f:
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != "user" or d.get("isSidechain"):
            continue
        c = d.get("message", {}).get("content")
        texts = []
        if isinstance(c, str):
            texts.append(c)
        elif isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "text":
                    texts.append(b.get("text", ""))
        for t in texts:
            if t.startswith("Base directory") or t.startswith("<task-notification") or t.startswith("Another Claude session"):
                continue
            if t.startswith("<system-reminder>"):
                continue
            prompts.append(t)

print("prompt count:", len(prompts))
for i, p in enumerate(prompts, 1):
    print(i, repr(p[:80]))

plan = open(plan_path, encoding="utf-8").read()
lines = plan.split("\n")

# Section 1 block quotes: lines starting with "> " between "## 1." and "## 2."
s = plan.index("## 1. The commander's words")
e = plan.index("## 2. Objectives")
sec1 = plan[s:e]
blocks = re.findall(r"^> (.*)$", sec1, re.M)
alltext = "\n".join(prompts)
for b in blocks:
    ok = b in alltext
    print("BLOCKQUOTE", "OK" if ok else "MISMATCH", repr(b[:80]))
    if not ok:
        # find longest matching prefix
        k = len(b)
        while k > 0 and b[:k] not in alltext:
            k -= 1
        print("   matches up to char", k, "of", len(b), ":", repr(b[max(0,k-30):k+40]))

# Prompt 1 vs MSG1 first line (strip trailing space)
p1 = prompts[0].split("\n")[0]
print("P1 trailing-space in transcript:", repr(p1[-5:]))

# pasted panel
m = re.search(r"```\n(\[2026-11-15T19:19:00Z\].*?)```", sec1, re.S)
panel = m.group(1)
src = prompts[0]
ps = src.index("[2026-11-15T19:19:00Z]")
pe = src.index("</pasted_content")
srcpanel = src[ps:pe]
print("PANEL equal:", panel == srcpanel)
if panel != srcpanel:
    for i, (a, b) in enumerate(zip(panel, srcpanel)):
        if a != b:
            print("  first diff at", i, repr(panel[i-20:i+20]), repr(srcpanel[i-20:i+20]))
            break
    print("  lens", len(panel), len(srcpanel), repr(panel[-40:]), repr(srcpanel[-40:]))

# Inline quotes in whole plan: "..." spans of >= 12 chars attributed to the commander
inline = re.findall(r'"([^"\n]{12,})"', plan.replace("\n", " ").replace("  ", " "))
norm_all = re.sub(r"\s+", " ", alltext)
for q in inline:
    qq = re.sub(r"\s+", " ", q)
    parts = [x.strip() for x in qq.split("...")]
    found = all(x in norm_all for x in parts if x)
    print("INLINE", "OK " if found else "NOT-IN-PROMPTS", repr(qq[:110]))
