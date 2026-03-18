#!/usr/bin/env python3
"""Analyze planning brief reading order for #53/#54 placement."""
import json
import sys

with open('/Users/pepe/repos/aitools/plans/mission-command-briefing/planning-brief.json') as f:
    data = json.load(f)

all_ids = set(d['id'] for d in data['decisions'])

in_order = set()
for phase in data['meta']['readingOrder']['sequence']:
    for item in phase['items']:
        if isinstance(item, int):
            in_order.add(item)

missing = all_ids - in_order
extra = in_order - all_ids

print(f'Total decisions: {len(all_ids)}')
print(f'IDs in readingOrder: {len(in_order)}')
print(f'Missing from readingOrder: {sorted(missing)}')
print(f'In readingOrder but not a decision: {sorted(extra)}')

print()
print('=== Current reading order ===')
for phase in data['meta']['readingOrder']['sequence']:
    print(f'\n{phase["phase"]}')
    for item in phase['items']:
        if isinstance(item, int):
            for d in data['decisions']:
                if d['id'] == item:
                    print(f'  #{item}: {d["decision"][:90]}')
                    break
        else:
            print(f'  {item}')

# Dependency analysis for #53
print('\n\n=== Decision #53 dependency analysis ===')
for d in data['decisions']:
    if d['id'] == 53:
        print(f'Decision: {d["decision"][:100]}')
        print(f'Related: {d["related"]}')
        print(f'Status: {d["status"]}')
        # Check which related are in which phase
        for rel_id in d['related']:
            for phase in data['meta']['readingOrder']['sequence']:
                if rel_id in phase['items']:
                    print(f'  #{rel_id} is in: {phase["phase"]}')
                    break
            else:
                print(f'  #{rel_id} is NOT in any phase')

# Dependency analysis for #54
print('\n\n=== Decision #54 dependency analysis ===')
for d in data['decisions']:
    if d['id'] == 54:
        print(f'Decision: {d["decision"][:100]}')
        print(f'Related: {d["related"]}')
        print(f'Status: {d["status"]}')
        for rel_id in d['related']:
            for phase in data['meta']['readingOrder']['sequence']:
                if rel_id in phase['items']:
                    print(f'  #{rel_id} is in: {phase["phase"]}')
                    break
            else:
                print(f'  #{rel_id} is NOT in any phase')

# Which decisions reference #54 in their related?
print('\n\n=== Decisions referencing #54 ===')
for d in data['decisions']:
    if 54 in d.get('related', []):
        for phase in data['meta']['readingOrder']['sequence']:
            if d['id'] in phase['items']:
                ph = phase['phase']
                break
        else:
            ph = 'NOT IN ANY PHASE'
        print(f'  #{d["id"]} ({ph}): {d["decision"][:80]}')
