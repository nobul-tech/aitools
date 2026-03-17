#!/usr/bin/env python3
"""Incident registry + framework registry + glossary health check."""
import json, sys, os

print("=== INCIDENT REGISTRY HEALTH ===")
d = json.load(open('reference/incidents.json'))
incidents = d['incidents']
ids = [i['id'] for i in incidents]
print(f"Total open: {len(incidents)}")
print(f"Total closed: {len(d.get('closed', []))}")
print(f"ID range: {min(ids)}-{max(ids)}")

dupes = [x for x in ids if ids.count(x) > 1]
print(f"Duplicate IDs: {set(dupes) if dupes else 'none'}")

sevs = {}
for i in incidents:
    s = i.get('severity', '?')
    sevs[s] = sevs.get(s, 0) + 1
print(f"Severity: {sevs}")

stats = {}
for i in incidents:
    s = i.get('status', '?')
    stats[s] = stats.get(s, 0) + 1
print(f"Status: {stats}")

required = ['id', 'title', 'status', 'severity', 'observation', 'expected', 'impact']
missing = []
for i in incidents:
    for f in required:
        if f not in i or i[f] is None:
            missing.append(f"  #{i['id']}: missing {f}")
print(f"Missing required fields: {len(missing)}")
for m in missing[:10]:
    print(m)

has_rc = sum(1 for i in incidents if i.get('rootCause') is not None)
has_ca = sum(1 for i in incidents if i.get('correctiveAction') is not None)
has_pl = sum(1 for i in incidents if i.get('preventionLayer') is not None)
print(f"rootCause populated: {has_rc}/{len(incidents)}")
print(f"correctiveAction populated: {has_ca}/{len(incidents)}")
print(f"preventionLayer populated: {has_pl}/{len(incidents)}")

# Check for old terminology
print("\n=== STALE TERMINOLOGY CHECK ===")
text = json.dumps(d)
for term in ['known-gaps', 'gap-governance', '/gap"', '"type": "gap"', '"type": "ambiguity"']:
    count = text.count(term)
    if count > 0:
        print(f"  FOUND: '{term}' appears {count} time(s)")
    else:
        print(f"  CLEAN: '{term}'")

print("\n=== FRAMEWORK REGISTRY HEALTH ===")
fr = json.load(open('reference/framework-registry.json'))
print(f"Active frameworks: {len(fr['frameworks'])}")
print(f"Pending frameworks: {len(fr.get('pending', []))}")
for fw in fr['frameworks']:
    ref = fw.get('referenceFile', '')
    exists = os.path.exists(ref) if ref else False
    status = 'OK' if exists else 'MISSING'
    print(f"  {fw['name']}: {ref} [{status}]")

print("\n=== TOOL-OPS REGISTRY HEALTH ===")
to = json.load(open('reference/tool-ops.json'))
for tool, data in to.get('tools', {}).items():
    modes = data.get('governanceModes', {})
    deny_count = len(data.get('denyRules', []))
    hook_count = len(data.get('hooks', []))
    ver_count = len(data.get('verifications', []))
    print(f"  {tool}: modes={modes}, deny={deny_count}, hooks={hook_count}, verifications={ver_count}")

print("\n=== GLOSSARY STALE SOURCES CHECK ===")
gl = json.load(open('reference/glossary.json'))
stale_sources = []
for term, entry in gl.get('terms', {}).items():
    src = entry.get('source', '')
    if 'gap-governance' in src or 'known-gaps' in src or 'claude-code-maintenance' in src:
        stale_sources.append(f"  {term}: {src}")
if stale_sources:
    print(f"Stale sources found: {len(stale_sources)}")
    for s in stale_sources:
        print(s)
else:
    print("All sources clean")

deprecated = [(t, e) for t, e in gl.get('terms', {}).items() if e.get('deprecated')]
print(f"Deprecated terms: {len(deprecated)}")
for t, e in deprecated:
    print(f"  {t} -> {e.get('replacedBy', '?')}")

print(f"\nTotal terms: {len(gl['terms'])}")
