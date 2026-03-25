#!/usr/bin/env python3
"""
Extract Write tool call contents from session Z1IhGrcgGO transcript.
Searches main transcript and all subagent transcripts for Write tool calls
targeting .scratch/session-Z1IhGrcgGO/ paths.
"""

import json
import os
import sys
from pathlib import Path

SESSION_DIR = Path("/Users/pepe/.claude/projects/-Users-pepe-repos-aitools/e059186f-45b2-461b-a4ba-e33cd23f9ee1")
MAIN_TRANSCRIPT = SESSION_DIR.with_suffix(".jsonl")
SUBAGENT_DIR = SESSION_DIR / "subagents"
TARGET_PATH_FRAGMENT = "session-Z1IhGrcgGO"
OUTPUT_DIR = Path("/Users/pepe/repos/aitools/harvesting")
SCRATCH_DIR = Path("/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH")

# Target files we're looking for
TARGET_FILES = [
    "session-state-audit.md",
    "findings-index.md",
    "schwerpunkt-assessment.md",
    "rule-effectiveness-audit.md",
    "governed-data-investigation.md",
    "q4-lifecycle-investigation.md",
    "q10-artifact-roles-investigation.md",
    "q4-q10-ambiguity-audit.md",
    "carry-forward-provenance.md",
    "carry-forward-frameworks.md",
    "carry-forward-barrier-C.md",
    "s2-post-push-aar.md",
    "post-push-fix-briefing.md",
    "briefing-cluster-analysis.md",
    "harness-cicd-investigation.md",
    "cicd-feasibility.md",
    "aitools-in-tool-ops-investigation.md",
    "scratch-deletion-rca.md",
    "verification-lifecycle-gap-audit.md",
    "session-transition-testing.md",
    "provenance-deep-research.md",
    "briefings-location-decision.md",
    "promotion-definition-draft.md",
    "promotion-definition-audit.md",
    "repo-project-definition-draft.md",
    "carry-forward-barrier-A.md",
    "carry-forward-barrier-B.md",
    "artifact-roles-tension-investigation.md",
    "intent-heuristic-findings.md",
    "intent-audit-findings.md",
]

def extract_writes_from_jsonl(filepath):
    """Extract Write tool calls from a JSONL file. Returns list of (file_path, content, source)."""
    results = []
    line_num = 0
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line_num += 1
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Look for assistant messages with tool_use content blocks
            if obj.get("type") == "assistant" and "message" in obj:
                msg = obj["message"]
                if "content" in msg:
                    for block in msg["content"]:
                        if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "Write":
                            inp = block.get("input", {})
                            fp = inp.get("file_path", "")
                            content = inp.get("content", "")
                            if TARGET_PATH_FRAGMENT in fp:
                                results.append((fp, content, str(filepath), line_num))

            # Also check for direct tool_use at top level (different JSONL format)
            if obj.get("type") == "tool_use" and obj.get("name") == "Write":
                inp = obj.get("input", {})
                fp = inp.get("file_path", "")
                content = inp.get("content", "")
                if TARGET_PATH_FRAGMENT in fp:
                    results.append((fp, content, str(filepath), line_num))

            # Check content array at top level
            if "content" in obj and isinstance(obj["content"], list):
                for block in obj["content"]:
                    if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "Write":
                        inp = block.get("input", {})
                        fp = inp.get("file_path", "")
                        content = inp.get("content", "")
                        if TARGET_PATH_FRAGMENT in fp:
                            results.append((fp, content, str(filepath), line_num))

    return results


def extract_writeblocked_content(filepath):
    """Search for WRITE_BLOCKED signals and assistant text content that contains file analysis."""
    results = []
    line_num = 0
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line_num += 1
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Look for assistant messages containing WRITE_BLOCKED
            if obj.get("type") == "assistant" and "message" in obj:
                msg = obj["message"]
                if "content" in msg:
                    for block in msg["content"]:
                        if isinstance(block, dict) and block.get("type") == "text":
                            text = block.get("text", "")
                            if "WRITE_BLOCKED" in text and len(text) > 200:
                                results.append((text, str(filepath), line_num))

            # Also at top level
            if "content" in obj and isinstance(obj["content"], list):
                for block in obj["content"]:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text = block.get("text", "")
                        if "WRITE_BLOCKED" in text and len(text) > 200:
                            results.append((text, str(filepath), line_num))

    return results


def main():
    all_writes = []
    all_writeblocked = []

    # Search main transcript
    print(f"Searching main transcript: {MAIN_TRANSCRIPT}")
    writes = extract_writes_from_jsonl(MAIN_TRANSCRIPT)
    all_writes.extend(writes)
    print(f"  Found {len(writes)} Write calls targeting {TARGET_PATH_FRAGMENT}")

    wb = extract_writeblocked_content(MAIN_TRANSCRIPT)
    all_writeblocked.extend(wb)
    print(f"  Found {len(wb)} WRITE_BLOCKED text blocks")

    # Search all subagent transcripts
    if SUBAGENT_DIR.exists():
        jsonl_files = sorted(SUBAGENT_DIR.glob("*.jsonl"))
        print(f"\nSearching {len(jsonl_files)} subagent transcripts...")
        for jf in jsonl_files:
            writes = extract_writes_from_jsonl(jf)
            if writes:
                print(f"  {jf.name}: {len(writes)} Write calls found")
                all_writes.extend(writes)

            wb = extract_writeblocked_content(jf)
            if wb:
                print(f"  {jf.name}: {len(wb)} WRITE_BLOCKED blocks found")
                all_writeblocked.extend(wb)

    # Deduplicate by file path (keep last write for each path)
    writes_by_path = {}
    for fp, content, source, line_num in all_writes:
        basename = os.path.basename(fp)
        writes_by_path[basename] = (fp, content, source, line_num)

    print(f"\n=== SUMMARY ===")
    print(f"Total Write calls found: {len(all_writes)}")
    print(f"Unique files: {len(writes_by_path)}")
    print(f"WRITE_BLOCKED blocks: {len(all_writeblocked)}")

    # Report which target files were found
    found = set()
    not_found = set()
    for tf in TARGET_FILES:
        if tf in writes_by_path:
            found.add(tf)
        else:
            not_found.add(tf)

    print(f"\nTarget files found: {len(found)}/{len(TARGET_FILES)}")
    for f in sorted(found):
        _, content, source, _ = writes_by_path[f]
        print(f"  FOUND: {f} ({len(content)} bytes) from {os.path.basename(source)}")

    if not_found:
        print(f"\nTarget files NOT found: {len(not_found)}")
        for f in sorted(not_found):
            print(f"  MISSING: {f}")

    # Also show any non-target files found
    extra = set(writes_by_path.keys()) - set(TARGET_FILES)
    if extra:
        print(f"\nExtra files found (not in target list): {len(extra)}")
        for f in sorted(extra):
            _, content, source, _ = writes_by_path[f]
            print(f"  EXTRA: {f} ({len(content)} bytes) from {os.path.basename(source)}")

    # Write recovered files
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    recovered = []
    for basename, (fp, content, source, line_num) in sorted(writes_by_path.items()):
        if basename in set(TARGET_FILES) or basename in extra:
            out_path = OUTPUT_DIR / f"2026-03-19_{basename}"
            out_path.write_text(content, encoding='utf-8')
            recovered.append({
                "original_path": fp,
                "recovered_path": str(out_path),
                "size_bytes": len(content.encode('utf-8')),
                "source_transcript": source,
                "source_line": line_num
            })
            print(f"  Wrote: {out_path}")

    # Write WRITE_BLOCKED content
    wb_recovered = []
    for i, (text, source, line_num) in enumerate(all_writeblocked):
        out_path = SCRATCH_DIR / f"writeblocked-{i+1}-from-{os.path.basename(source)}.md"
        out_path.write_text(text, encoding='utf-8')
        wb_recovered.append({
            "recovered_path": str(out_path),
            "size_bytes": len(text.encode('utf-8')),
            "source_transcript": source,
            "source_line": line_num,
            "preview": text[:200]
        })
        print(f"  Wrote WRITE_BLOCKED content: {out_path}")

    # Write AAR
    aar = {
        "session": "5HyCwPtSDH",
        "mission": "Recover 30 lost files from session Z1IhGrcgGO",
        "date": "2026-03-21",
        "source_session": "Z1IhGrcgGO",
        "source_transcript": str(MAIN_TRANSCRIPT),
        "subagent_transcripts_searched": len(list(SUBAGENT_DIR.glob("*.jsonl"))) if SUBAGENT_DIR.exists() else 0,
        "total_write_calls_found": len(all_writes),
        "unique_files_found": len(writes_by_path),
        "target_files_total": len(TARGET_FILES),
        "target_files_recovered": len(found),
        "target_files_missing": sorted(list(not_found)),
        "extra_files_recovered": sorted(list(extra)),
        "writeblocked_blocks_found": len(all_writeblocked),
        "recovery_rate": f"{len(found)}/{len(TARGET_FILES)} ({100*len(found)/len(TARGET_FILES):.1f}%)",
        "recovered_files": recovered,
        "writeblocked_content": wb_recovered,
    }

    aar_path = SCRATCH_DIR / "m7-file-recovery-aar.json"
    aar_path.write_text(json.dumps(aar, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"\nAAR written to: {aar_path}")

    # Also save the detailed mapping for further investigation
    mapping_path = SCRATCH_DIR / "write-call-mapping.json"
    all_write_details = []
    for fp, content, source, line_num in all_writes:
        all_write_details.append({
            "file_path": fp,
            "basename": os.path.basename(fp),
            "content_length": len(content),
            "source": source,
            "line_num": line_num
        })
    mapping_path.write_text(json.dumps(all_write_details, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"Write call mapping written to: {mapping_path}")


if __name__ == "__main__":
    main()
