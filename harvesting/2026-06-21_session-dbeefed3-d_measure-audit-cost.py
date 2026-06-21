#!/usr/bin/env python3
"""Quantify audit cost + duplication ratio in harvest-manifest.json."""
import json
import re
import datetime

d = json.load(open('harvesting/harvest-manifest.json'))
arts = d.get('artifacts', {})
today = datetime.date.today()
status: dict = {}
past_due_active = 0
for name, e in arts.items():
    s = e.get('status')
    status[s] = status.get(s, 0) + 1
    if s in ('promoted', 'pruned'):
        continue
    pa = e.get('pruneAfter')
    if not pa:
        continue
    try:
        pd = datetime.datetime.strptime(pa, '%Y-%m-%d').date()
    except ValueError:
        continue
    if today > pd:
        past_due_active += 1

print("status breakdown:", status)
print("active artifacts past prune date (=> git log call each):", past_due_active)
print("total artifacts:", len(arts))

base = set()
for n in arts:
    base.add(re.sub(r'^\d{4}-\d{2}-\d{2}_(\d+_)?(session-[0-9a-f]+_)?', '', n))
print("distinct underlying basenames:", len(base))
