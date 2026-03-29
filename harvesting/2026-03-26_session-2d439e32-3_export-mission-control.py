#!/usr/bin/env python3
"""export-mission-control.py -- Export session DB to static HTML for Vercel deployment.

Purpose: Read session data from SQLite DB, embed into the command center HTML
template, and write a static index.html ready for `vercel deploy`.

Usage:
    python3 export-mission-control.py --db /path/to/session.db --out /path/to/dist/
    python3 export-mission-control.py --session c0dc2ddc-f --out /path/to/dist/

Safe to re-run. Overwrites existing output.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def extract_documents(scratch_dir: Path) -> list[dict[str, str]]:
    """Read all .md files from the scratch directory, categorized."""
    docs: list[dict[str, str]] = []
    if not scratch_dir.is_dir():
        return docs

    # Priority order for key reports
    priority_files = [
        "session-synthesis-report.md",
        "full-audit-report.md",
        "assumption-trace-report.md",
        "operational-learning.md",
        "meaning-reconstruction.md",
    ]
    proposal_prefix = ("provenance-proposal-", "proposed-")

    seen: set[str] = set()
    md_files = sorted(scratch_dir.glob("*.md"))

    def categorize(name: str) -> str:
        if name.startswith(proposal_prefix):
            return "proposal"
        if "report" in name or "audit" in name or "synthesis" in name:
            return "report"
        if "investigation" in name or "findings" in name or "trace" in name:
            return "analysis"
        if "operational-learning" in name:
            return "report"
        if "delegation" in name:
            return "delegation"
        if "feedback" in name:
            return "feedback"
        return "document"

    # Add priority files first
    for pf in priority_files:
        fp = scratch_dir / pf
        if fp.exists():
            content = fp.read_text(encoding="utf-8", errors="replace")
            docs.append({
                "filename": pf,
                "category": categorize(pf),
                "content": content,
                "size": len(content),
                "path": str(fp),
            })
            seen.add(pf)

    # Add proposals
    for fp in md_files:
        if fp.name in seen:
            continue
        if fp.name.startswith(proposal_prefix):
            content = fp.read_text(encoding="utf-8", errors="replace")
            docs.append({
                "filename": fp.name,
                "category": "proposal",
                "content": content,
                "size": len(content),
                "path": str(fp),
            })
            seen.add(fp.name)

    # Add remaining
    for fp in md_files:
        if fp.name in seen:
            continue
        content = fp.read_text(encoding="utf-8", errors="replace")
        docs.append({
            "filename": fp.name,
            "category": categorize(fp.name),
            "content": content,
            "size": len(content),
            "path": str(fp),
        })
        seen.add(fp.name)

    return docs


def extract_git_diffs(repo_root: Path, num_commits: int = 10) -> list[dict[str, str]]:
    """Get recent git commit diffs for protected file changes."""
    diffs: list[dict[str, str]] = []
    try:
        log_result = subprocess.run(
            ["git", "log", f"-{num_commits}", "--format=%H|%s|%ai"],
            cwd=repo_root, capture_output=True, text=True, timeout=10
        )
        if log_result.returncode != 0:
            return diffs
        for line in log_result.stdout.strip().split("\n"):
            if not line:
                continue
            parts = line.split("|", 2)
            if len(parts) < 3:
                continue
            sha, subject, date = parts
            # Get the diff for protected files
            diff_result = subprocess.run(
                ["git", "diff", f"{sha}^..{sha}", "--",
                 "CLAUDE.md", ".claude/rules/", "reference/",
                 "shared/", "ROADMAP.md", "RELEASE_NOTES.md"],
                cwd=repo_root, capture_output=True, text=True, timeout=10
            )
            diff_text = diff_result.stdout.strip() if diff_result.returncode == 0 else ""
            if diff_text:
                diffs.append({
                    "sha": sha[:8],
                    "subject": subject,
                    "date": date,
                    "diff": diff_text,
                })
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return diffs


def open_db(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5.0)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.row_factory = sqlite3.Row
    return conn


def extract_session_data(db_path: Path) -> dict[str, Any]:
    """Read all session data from the DB."""
    conn = open_db(db_path)
    data: dict[str, Any] = {}

    try:
        session = conn.execute("SELECT * FROM session LIMIT 1").fetchone()
        if session is None:
            return {"error": "No session record found in DB"}

        started = session["started_at"] or ""
        updated = session["updated_at"] or ""
        ended = session["ended_at"]

        duration_str = ""
        if started:
            try:
                start_dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
                end_dt = (
                    datetime.now(timezone.utc)
                    if not ended
                    else datetime.fromisoformat(ended.replace("Z", "+00:00"))
                )
                delta = end_dt - start_dt
                hours = int(delta.total_seconds() // 3600)
                minutes = int((delta.total_seconds() % 3600) // 60)
                duration_str = f"{hours}h {minutes}m" if hours > 0 else f"{minutes}m"
            except (ValueError, TypeError):
                pass

        data["session"] = {
            "sessionId": session["session_id"],
            "schwerpunkt": session["schwerpunkt"],
            "currentState": session["current_state"],
            "startedAt": started,
            "updatedAt": updated,
            "endedAt": ended,
            "duration": duration_str,
            "version": session["version"],
            "platform": session["platform"],
            "agentIdentity": session["agent_identity"],
            "status": "completed" if ended else "active",
        }

        # Messages
        messages = conn.execute(
            "SELECT * FROM messages ORDER BY created_at"
        ).fetchall()
        data["messages"] = [
            {
                "id": m["message_id"],
                "type": m["message_type"],
                "agentRole": m["agent_role"],
                "title": m["title"],
                "message": m["message"],
                "severity": m["severity"],
                "actionable": bool(m["actionable"]),
                "createdAt": m["created_at"],
            }
            for m in messages
        ]

        # Missions
        missions = conn.execute(
            "SELECT * FROM missions ORDER BY launched_at"
        ).fetchall()
        data["missions"] = [
            {
                "missionId": m["mission_id"],
                "parentMissionId": m["parent_mission_id"],
                "missionType": m["mission_type"],
                "description": m["description"],
                "status": m["status"],
                "launchedAt": m["launched_at"],
                "completedAt": m["completed_at"],
                "findingsCount": m["findings_count"],
                "keyResult": m["key_result"],
            }
            for m in missions
        ]

        # Delegations
        delegations = conn.execute(
            "SELECT * FROM delegation_log ORDER BY launched_at"
        ).fetchall()
        data["delegations"] = [
            {
                "entryId": d["entry_id"],
                "missionId": d["mission_id"],
                "agentType": d["agent_type"],
                "agentName": d["agent_name"],
                "promptSummary": d["prompt_summary"],
                "status": d["status"],
                "launchedAt": d["launched_at"],
                "completedAt": d["completed_at"],
                "tokenUsage": d["token_usage"],
                "durationMs": d["duration_ms"],
                "outcome": d["outcome"],
            }
            for d in delegations
        ]

        # Decisions
        decisions = conn.execute(
            "SELECT * FROM decisions ORDER BY decided_at"
        ).fetchall()
        data["decisions"] = [
            {
                "decisionId": d["decision_id"],
                "title": d["title"],
                "description": d["description"],
                "status": d["status"],
                "implementationEvidence": d["implementation_evidence"],
                "decidedAt": d["decided_at"],
                "implementedAt": d["implemented_at"],
            }
            for d in decisions
        ]

        # Observations
        observations = conn.execute(
            "SELECT * FROM observations ORDER BY created_at"
        ).fetchall()
        data["observations"] = [
            {
                "id": o["observation_id"],
                "category": o["category"],
                "text": o["text"],
                "status": o["status"],
                "evidence": o["evidence"],
                "severity": o["severity"],
                "createdAt": o["created_at"],
            }
            for o in observations
        ]

        # Completed work
        completed = conn.execute(
            "SELECT * FROM completed_work ORDER BY completed_at"
        ).fetchall()
        data["completedWork"] = [
            {
                "item": c["item"],
                "category": c["category"],
                "decidedBy": c["decided_by"],
                "completedAt": c["completed_at"],
            }
            for c in completed
        ]

        # Deviations
        deviations = conn.execute(
            "SELECT * FROM deviations ORDER BY created_at"
        ).fetchall()
        data["deviations"] = [
            {
                "description": dv["description"],
                "impact": dv["impact"],
                "batchOrigin": dv["batch_origin"],
                "createdAt": dv["created_at"],
            }
            for dv in deviations
        ]

        # Viewer feedback (from session-viewer.py)
        try:
            vf = conn.execute(
                "SELECT * FROM viewer_feedback ORDER BY created_at"
            ).fetchall()
            data["viewerFeedback"] = [
                {
                    "id": f["feedback_id"],
                    "filePath": f["file_path"],
                    "sectionContext": f["section_context"],
                    "message": f["message"],
                    "feedbackType": f["feedback_type"],
                    "createdAt": f["created_at"],
                }
                for f in vf
            ]
        except sqlite3.OperationalError:
            data["viewerFeedback"] = []

        # Commander feedback (from command-center-v2)
        try:
            cf = conn.execute(
                "SELECT * FROM commander_feedback ORDER BY created_at DESC"
            ).fetchall()
            data["feedback"] = [
                {
                    "id": f["feedback_id"],
                    "type": f["feedback_type"],
                    "message": f["message"],
                    "target": f["target"],
                    "status": f["status"],
                    "resolution": f["resolution"],
                    "createdAt": f["created_at"],
                    "acknowledgedAt": f["acknowledged_at"],
                    "resolvedAt": f["resolved_at"],
                }
                for f in cf
            ]
        except sqlite3.OperationalError:
            data["feedback"] = []

        # Counts
        pending_decisions = sum(
            1 for d in data["decisions"]
            if d["status"] not in ("approved", "rejected", "implemented")
        )
        pending_review_obs = sum(
            1 for o in data["observations"]
            if o.get("status") == "pending-review"
        )
        data["counts"] = {
            "messages": len(data["messages"]),
            "sitreps": sum(
                1 for m in data["messages"] if m["type"] == "sitrep"
            ),
            "findings": sum(
                1 for m in data["messages"] if m["type"] == "finding"
            ),
            "missions": len(data["missions"]),
            "delegations": len(data["delegations"]),
            "decisions": len(data["decisions"]),
            "pendingDecisions": pending_decisions,
            "observations": len(data["observations"]),
            "pendingReviewObs": pending_review_obs,
            "completedWork": len(data["completedWork"]),
            "deviations": len(data["deviations"]),
            "feedback": len(data.get("feedback", [])),
            "feedbackPending": sum(
                1
                for f in data.get("feedback", [])
                if f["status"] in ("submitted", "acknowledged")
            ),
            "viewerFeedback": len(data.get("viewerFeedback", [])),
        }

    except sqlite3.OperationalError as e:
        data["error"] = f"DB error: {e}"
    finally:
        conn.close()

    data["queriedAt"] = utcnow()
    data["dbPath"] = str(db_path)
    data["exportedAt"] = utcnow()
    return data


def build_static_html(data: dict[str, Any], scratch_dir: Path | None = None,
                      repo_root: Path | None = None) -> str:
    """Build the static HTML with all session data embedded."""
    # Embed documents from scratch dir
    if scratch_dir:
        data["documents"] = extract_documents(scratch_dir)
    else:
        data["documents"] = []

    # Embed git diffs
    if repo_root:
        data["gitDiffs"] = extract_git_diffs(repo_root)
    else:
        data["gitDiffs"] = []

    data_json = json.dumps(data, ensure_ascii=False, indent=None)
    # Escape </script> in JSON data to prevent HTML parser issues
    data_json = data_json.replace("</", "<\\/")

    html = HTML_TEMPLATE.replace("__SESSION_DATA_PLACEHOLDER__", data_json)
    return html


# The full HTML template -- self-contained, dark theme, all tabs
HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mission Control -- nobulai.tools</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>&#127919;</text></svg>">
<style>
:root {
  --bg-primary: #0d1117;
  --bg-secondary: #161b22;
  --bg-tertiary: #21262d;
  --bg-hover: #30363d;
  --border: #30363d;
  --border-light: #484f58;
  --text-primary: #e6edf3;
  --text-secondary: #8b949e;
  --text-muted: #6e7681;
  --accent-blue: #58a6ff;
  --accent-green: #3fb950;
  --accent-yellow: #d29922;
  --accent-red: #f85149;
  --accent-purple: #bc8cff;
  --accent-orange: #f0883e;
  --accent-cyan: #56d4dd;
  --font-mono: 'SF Mono', 'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace;
  --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
  --radius: 6px;
  --shadow: 0 1px 3px rgba(0,0,0,0.3), 0 1px 2px rgba(0,0,0,0.2);
}
* { margin: 0; padding: 0; box-sizing: border-box; }
html { font-size: 14px; scroll-behavior: smooth; }
body { background: var(--bg-primary); color: var(--text-primary); font-family: var(--font-sans); line-height: 1.5; min-height: 100vh; }

.header { position: sticky; top: 0; z-index: 100; background: var(--bg-secondary); border-bottom: 1px solid var(--border); padding: 12px 24px; box-shadow: var(--shadow); }
.header-top { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 6px; }
.header-title { font-size: 1.3rem; font-weight: 600; }
.header-title span { color: var(--text-secondary); font-weight: 400; font-size: 0.9rem; }
.session-meta { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; font-size: 0.82rem; }
.meta-item { display: flex; align-items: center; gap: 4px; }
.meta-label { color: var(--text-muted); }
.meta-value { font-family: var(--font-mono); color: var(--accent-blue); }
.schwerpunkt { font-size: 0.82rem; color: var(--text-secondary); line-height: 1.5; margin-top: 4px; padding: 6px 10px; background: var(--bg-tertiary); border-left: 3px solid var(--accent-blue); border-radius: 0 var(--radius) var(--radius) 0; }
.stats-bar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; margin-top: 10px; }
.stat-card { background: var(--bg-tertiary); border: 1px solid var(--border); border-radius: var(--radius); padding: 5px 12px; display: flex; align-items: center; gap: 6px; }
.stat-value { font-size: 1.1rem; font-weight: 700; font-family: var(--font-mono); }
.stat-label { font-size: 0.65rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; }
.stat-value.green { color: var(--accent-green); }
.stat-value.yellow { color: var(--accent-yellow); }
.stat-value.red { color: var(--accent-red); }
.stat-value.blue { color: var(--accent-blue); }
.stat-value.purple { color: var(--accent-purple); }
.stat-value.orange { color: var(--accent-orange); }
.stat-value.cyan { color: var(--accent-cyan); }
.stat-value.muted { color: var(--text-muted); }

.tab-nav { display: flex; gap: 0; border-bottom: 1px solid var(--border); background: var(--bg-secondary); overflow-x: auto; }
.tab-btn { background: none; border: none; border-bottom: 2px solid transparent; color: var(--text-secondary); padding: 10px 18px; cursor: pointer; font-size: 0.82rem; font-family: var(--font-sans); font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; transition: all 0.15s; white-space: nowrap; }
.tab-btn:hover { color: var(--text-primary); }
.tab-btn.active { color: var(--accent-blue); border-bottom-color: var(--accent-blue); }
.tab-btn.has-data { color: var(--accent-green); }
.tab-btn.has-data.active { border-bottom-color: var(--accent-green); }
.tab-panel { display: none; padding: 16px 24px; }
.tab-panel.active { display: block; }

.message-feed { max-height: 70vh; overflow-y: auto; }
.msg-item { display: grid; grid-template-columns: 70px 120px 1fr; gap: 10px; padding: 8px 12px; border-bottom: 1px solid rgba(48,54,61,0.4); font-size: 0.82rem; align-items: start; }
.msg-item:hover { background: var(--bg-tertiary); }
.msg-time { font-family: var(--font-mono); color: var(--text-muted); font-size: 0.75rem; white-space: nowrap; }
.msg-agent { font-family: var(--font-mono); font-size: 0.75rem; color: var(--accent-cyan); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.msg-text { color: var(--text-secondary); line-height: 1.5; word-break: break-word; }
.msg-severity { display: inline-block; font-size: 0.6rem; padding: 0px 5px; border-radius: 3px; font-weight: 600; text-transform: uppercase; margin-right: 4px; vertical-align: middle; }
.sev-routine { background: rgba(48,54,61,0.5); color: var(--text-muted); }
.sev-priority { background: rgba(88,166,255,0.2); color: var(--accent-blue); }
.sev-flash { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.sev-low { background: rgba(48,54,61,0.5); color: var(--text-muted); }
.sev-medium { background: rgba(210,153,34,0.15); color: var(--accent-yellow); }
.sev-high { background: rgba(240,136,62,0.2); color: var(--accent-orange); }
.sev-critical { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.type-badge { display: inline-block; font-size: 0.6rem; padding: 0px 5px; border-radius: 3px; font-weight: 600; text-transform: uppercase; margin-right: 4px; }
.type-sitrep { background: rgba(88,166,255,0.15); color: var(--accent-blue); }
.type-finding { background: rgba(63,185,80,0.15); color: var(--accent-green); }

.card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 8px; overflow: hidden; }
.card-header { padding: 10px 14px; cursor: pointer; display: flex; align-items: center; gap: 10px; }
.card-header:hover { background: var(--bg-tertiary); }
.card.expanded .card-body { display: block; }
.card-body { display: none; padding: 10px 14px; border-top: 1px solid var(--border); background: var(--bg-primary); font-size: 0.82rem; color: var(--text-secondary); line-height: 1.6; }
.card .collapse-icon { color: var(--text-muted); transition: transform 0.2s; font-size: 0.75rem; }
.card.expanded .collapse-icon { transform: rotate(90deg); }
.card-id { font-family: var(--font-mono); color: var(--accent-cyan); font-size: 0.8rem; font-weight: 600; white-space: nowrap; min-width: 80px; }
.card-title { font-weight: 600; font-size: 0.88rem; flex: 1; }

.status-badge { font-size: 0.65rem; padding: 2px 8px; border-radius: 10px; font-weight: 600; text-transform: uppercase; }
.status-launched { background: rgba(88,166,255,0.2); color: var(--accent-blue); }
.status-in_progress { background: rgba(210,153,34,0.2); color: var(--accent-yellow); }
.status-complete { background: rgba(63,185,80,0.2); color: var(--accent-green); }
.status-failed { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.status-decided { background: rgba(63,185,80,0.2); color: var(--accent-green); }
.status-implemented { background: rgba(63,185,80,0.3); color: var(--accent-green); }
.status-submitted { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.status-acknowledged { background: rgba(210,153,34,0.2); color: var(--accent-yellow); }
.status-resolved { background: rgba(63,185,80,0.2); color: var(--accent-green); }

.empty-state { text-align: center; padding: 40px 20px; color: var(--text-muted); }
.empty-state .empty-title { font-size: 0.95rem; font-weight: 600; margin-bottom: 4px; color: var(--text-secondary); }
.empty-state .empty-detail { font-size: 0.8rem; max-width: 400px; margin: 0 auto; }

.del-card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px 14px; margin-bottom: 8px; }
.del-header { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
.del-name { font-family: var(--font-mono); font-weight: 600; color: var(--accent-blue); }
.del-type { font-size: 0.65rem; padding: 1px 8px; border-radius: 10px; font-weight: 600; text-transform: uppercase; }
.del-meta { font-size: 0.78rem; color: var(--text-muted); display: flex; gap: 12px; flex-wrap: wrap; }
.del-prompt { font-size: 0.82rem; color: var(--text-secondary); margin-top: 6px; padding: 6px 10px; background: var(--bg-tertiary); border-left: 2px solid var(--border-light); border-radius: 0 var(--radius) var(--radius) 0; }

.section-title { font-size: 0.8rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 10px; font-weight: 600; }
.controls { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin-bottom: 12px; }
.filter-btn { background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-secondary); padding: 3px 10px; border-radius: var(--radius); cursor: pointer; font-size: 0.75rem; font-family: var(--font-sans); transition: all 0.15s; }
.filter-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
.filter-btn.active { background: var(--accent-blue); color: #fff; border-color: var(--accent-blue); }

.state-block { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px; margin-bottom: 10px; }
.state-block-title { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; font-weight: 600; }
.state-item { padding: 4px 0; border-bottom: 1px solid rgba(48,54,61,0.4); font-size: 0.82rem; color: var(--text-secondary); }
.state-item:last-child { border-bottom: none; }

.feedback-card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px 14px; margin-bottom: 8px; }
.feedback-card.contextual { border-left: 3px solid var(--accent-blue); }
.feedback-card.general { border-left: 3px solid var(--accent-purple); }
.fb-header { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
.fb-type { font-family: var(--font-mono); font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }
.fb-type.contextual { color: var(--accent-blue); }
.fb-type.general { color: var(--accent-purple); }
.fb-message { font-size: 0.85rem; color: var(--text-primary); line-height: 1.6; margin-bottom: 6px; }
.fb-meta { font-size: 0.75rem; color: var(--text-muted); display: flex; gap: 12px; flex-wrap: wrap; }
.fb-file { font-family: var(--font-mono); font-size: 0.75rem; color: var(--accent-cyan); }
.fb-section { font-size: 0.78rem; color: var(--accent-yellow); font-style: italic; }

.footer { padding: 12px 24px; border-top: 1px solid var(--border); color: var(--text-muted); font-size: 0.75rem; text-align: center; background: var(--bg-secondary); }

::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: var(--bg-primary); }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: var(--border-light); }

/* Quick feedback button */
.quick-feedback-btn {
  background: var(--bg-tertiary); border: 1px solid var(--accent-yellow); color: var(--accent-yellow);
  padding: 5px 14px; border-radius: var(--radius); cursor: pointer;
  font-size: 0.82rem; font-weight: 600; font-family: var(--font-sans);
  transition: all 0.15s; display: flex; align-items: center; gap: 6px;
}
.quick-feedback-btn:hover { background: rgba(210,153,34,0.15); border-color: var(--accent-orange); color: var(--accent-orange); }
.quick-feedback-btn .pending-badge {
  background: var(--accent-red); color: #fff; font-size: 0.6rem;
  padding: 0 5px; border-radius: 8px; font-weight: 700; min-width: 16px; text-align: center;
}

/* Feedback form */
.feedback-form { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 16px; margin-bottom: 16px; }
.feedback-form .form-title { font-size: 0.9rem; font-weight: 600; margin-bottom: 12px; color: var(--text-primary); }
.form-row { display: flex; gap: 10px; margin-bottom: 10px; align-items: flex-start; }
.form-row label { font-size: 0.78rem; color: var(--text-secondary); min-width: 60px; padding-top: 6px; }
.form-row select, .form-row textarea, .form-row input {
  flex: 1; background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-primary);
  padding: 6px 10px; border-radius: var(--radius); font-family: var(--font-sans); font-size: 0.82rem;
  outline: none; transition: border-color 0.15s;
}
.form-row select:focus, .form-row textarea:focus, .form-row input:focus { border-color: var(--accent-blue); }
.form-row textarea { min-height: 80px; resize: vertical; line-height: 1.5; }
.form-actions { display: flex; gap: 10px; justify-content: flex-end; margin-top: 10px; }
.btn-submit {
  background: var(--accent-blue); color: #fff; border: none; padding: 6px 20px;
  border-radius: var(--radius); cursor: pointer; font-size: 0.82rem; font-weight: 600;
  font-family: var(--font-sans); transition: all 0.15s;
}
.btn-submit:hover { background: #4d94e6; }
.btn-submit:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-cancel { background: var(--bg-tertiary); color: var(--text-secondary); border: 1px solid var(--border); padding: 6px 16px; border-radius: var(--radius); cursor: pointer; font-size: 0.82rem; font-family: var(--font-sans); }

/* Feedback modal */
.modal-overlay { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 1000; justify-content: center; align-items: flex-start; padding-top: 15vh; }
.modal-overlay.visible { display: flex; }
.modal { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 8px; padding: 20px; width: 500px; max-width: 90vw; box-shadow: 0 8px 30px rgba(0,0,0,0.5); }
.modal .modal-title { font-size: 1rem; font-weight: 600; margin-bottom: 16px; }

/* Toast notification */
.toast { position: fixed; bottom: 20px; right: 20px; background: var(--accent-green); color: #fff; padding: 10px 20px; border-radius: var(--radius); font-size: 0.85rem; font-weight: 600; z-index: 2000; opacity: 0; transition: opacity 0.3s; pointer-events: none; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
.toast.visible { opacity: 1; }
.toast.error { background: var(--accent-red); }

/* Document viewer */
.doc-list { display: flex; flex-direction: column; gap: 6px; }
.doc-item { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; }
.doc-header { padding: 10px 14px; cursor: pointer; display: flex; align-items: center; gap: 10px; }
.doc-header:hover { background: var(--bg-tertiary); }
.doc-item.expanded .doc-content { display: block; }
.doc-content { display: none; border-top: 1px solid var(--border); max-height: 75vh; overflow-y: auto; }
.doc-item .collapse-icon { color: var(--text-muted); transition: transform 0.2s; font-size: 0.75rem; }
.doc-item.expanded .collapse-icon { transform: rotate(90deg); }
.doc-filename { font-family: var(--font-mono); font-weight: 600; font-size: 0.85rem; flex: 1; }
.doc-cat { font-size: 0.6rem; padding: 2px 8px; border-radius: 10px; font-weight: 600; text-transform: uppercase; }
.doc-cat.report { background: rgba(88,166,255,0.2); color: var(--accent-blue); }
.doc-cat.proposal { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.doc-cat.analysis { background: rgba(210,153,34,0.2); color: var(--accent-yellow); }
.doc-cat.delegation { background: rgba(188,140,255,0.2); color: var(--accent-purple); }
.doc-cat.feedback { background: rgba(63,185,80,0.2); color: var(--accent-green); }
.doc-cat.document { background: rgba(48,54,61,0.5); color: var(--text-muted); }
.doc-size { font-size: 0.7rem; color: var(--text-muted); font-family: var(--font-mono); }
.doc-actions { display: flex; gap: 6px; }
.doc-fb-btn { background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--accent-yellow); padding: 2px 10px; border-radius: var(--radius); cursor: pointer; font-size: 0.7rem; font-weight: 600; }
.doc-fb-btn:hover { background: rgba(210,153,34,0.15); }
.doc-filter-bar { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 12px; }

/* Rendered markdown */
.md-render { padding: 16px 20px; background: var(--bg-primary); color: var(--text-secondary); font-size: 0.85rem; line-height: 1.7; }
.md-render h1 { font-size: 1.4rem; color: var(--text-primary); margin: 24px 0 12px 0; padding-bottom: 6px; border-bottom: 1px solid var(--border); font-weight: 700; }
.md-render h2 { font-size: 1.15rem; color: var(--text-primary); margin: 20px 0 8px 0; padding-bottom: 4px; border-bottom: 1px solid var(--border); font-weight: 600; }
.md-render h3 { font-size: 1rem; color: var(--accent-blue); margin: 16px 0 6px 0; font-weight: 600; }
.md-render h4 { font-size: 0.9rem; color: var(--accent-cyan); margin: 12px 0 4px 0; font-weight: 600; }
.md-render p { margin: 8px 0; }
.md-render ul, .md-render ol { margin: 6px 0 6px 20px; }
.md-render li { margin: 3px 0; }
.md-render code { font-family: var(--font-mono); background: var(--bg-tertiary); padding: 1px 5px; border-radius: 3px; font-size: 0.82em; color: var(--accent-orange); }
.md-render pre { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px 14px; margin: 10px 0; overflow-x: auto; }
.md-render pre code { background: none; padding: 0; color: var(--text-primary); font-size: 0.8rem; }
.md-render blockquote { border-left: 3px solid var(--accent-blue); padding: 4px 14px; margin: 8px 0; color: var(--text-muted); background: rgba(88,166,255,0.05); border-radius: 0 var(--radius) var(--radius) 0; }
.md-render strong { color: var(--text-primary); font-weight: 600; }
.md-render em { color: var(--accent-cyan); }
.md-render hr { border: none; border-top: 1px solid var(--border); margin: 16px 0; }
.md-render a { color: var(--accent-blue); text-decoration: none; }
.md-render a:hover { text-decoration: underline; }
.md-render table { border-collapse: collapse; margin: 10px 0; width: 100%; }
.md-render th { background: var(--bg-tertiary); padding: 6px 10px; border: 1px solid var(--border); font-size: 0.8rem; text-align: left; color: var(--text-primary); font-weight: 600; }
.md-render td { padding: 5px 10px; border: 1px solid var(--border); font-size: 0.8rem; }
.md-render .task-done { color: var(--accent-green); }
.md-render .task-pending { color: var(--accent-yellow); }

/* Git diff viewer */
.diff-item { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 8px; overflow: hidden; }
.diff-header { padding: 10px 14px; cursor: pointer; display: flex; align-items: center; gap: 10px; }
.diff-header:hover { background: var(--bg-tertiary); }
.diff-item.expanded .diff-body { display: block; }
.diff-body { display: none; border-top: 1px solid var(--border); max-height: 70vh; overflow-y: auto; }
.diff-item .collapse-icon { color: var(--text-muted); transition: transform 0.2s; font-size: 0.75rem; }
.diff-item.expanded .collapse-icon { transform: rotate(90deg); }
.diff-sha { font-family: var(--font-mono); color: var(--accent-purple); font-size: 0.8rem; font-weight: 600; min-width: 70px; }
.diff-subject { font-weight: 600; font-size: 0.85rem; flex: 1; }
.diff-date { font-size: 0.75rem; color: var(--text-muted); }
.diff-content { padding: 0; background: var(--bg-primary); font-family: var(--font-mono); font-size: 0.78rem; line-height: 1.5; white-space: pre-wrap; word-break: break-all; }
.diff-content .diff-line { padding: 1px 14px; }
.diff-content .diff-add { background: rgba(63,185,80,0.12); color: var(--accent-green); }
.diff-content .diff-del { background: rgba(248,81,73,0.12); color: var(--accent-red); }
.diff-content .diff-hunk { background: rgba(88,166,255,0.08); color: var(--accent-blue); font-weight: 600; padding: 4px 14px; }
.diff-content .diff-file { background: var(--bg-tertiary); color: var(--text-primary); font-weight: 700; padding: 6px 14px; border-bottom: 1px solid var(--border); }

/* Observation evidence viewer */
.obs-evidence { margin-top: 8px; padding: 10px 14px; background: var(--bg-tertiary); border-radius: var(--radius); border: 1px solid var(--border); }
.obs-evidence-title { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 6px; font-weight: 600; }

/* Document feedback form (inline per document) */
.doc-feedback-inline { padding: 10px 20px; background: var(--bg-secondary); border-top: 1px solid var(--border); }
.doc-feedback-inline textarea { width: 100%; background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-primary); padding: 8px 10px; border-radius: var(--radius); font-family: var(--font-sans); font-size: 0.82rem; min-height: 60px; resize: vertical; outline: none; }
.doc-feedback-inline textarea:focus { border-color: var(--accent-blue); }
.doc-feedback-inline .doc-fb-actions { display: flex; gap: 8px; margin-top: 6px; justify-content: flex-end; }

/* Pending Actions bar */
.pending-actions { background: var(--bg-secondary); border: 1px solid var(--accent-yellow); border-radius: var(--radius); padding: 12px 20px; margin: 12px 24px 0; display: flex; align-items: center; gap: 20px; flex-wrap: wrap; }
.pending-actions.clear { border-color: var(--accent-green); }
.pending-actions-title { font-size: 0.82rem; font-weight: 700; color: var(--accent-yellow); text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap; }
.pending-actions.clear .pending-actions-title { color: var(--accent-green); }
.pending-item { display: flex; align-items: center; gap: 6px; font-size: 0.82rem; cursor: pointer; padding: 4px 10px; border-radius: var(--radius); background: var(--bg-tertiary); border: 1px solid var(--border); transition: all 0.15s; }
.pending-item:hover { background: var(--bg-hover); border-color: var(--border-light); }
.pending-count { font-family: var(--font-mono); font-weight: 700; font-size: 1rem; }
.pending-count.red { color: var(--accent-red); }
.pending-count.yellow { color: var(--accent-yellow); }
.pending-count.green { color: var(--accent-green); }

/* Action buttons on cards */
.card-actions { display: flex; gap: 6px; padding: 10px 14px; border-top: 1px solid var(--border); background: var(--bg-secondary); }
.action-btn { padding: 4px 14px; border-radius: var(--radius); cursor: pointer; font-size: 0.75rem; font-weight: 600; font-family: var(--font-sans); transition: all 0.15s; border: 1px solid; }
.action-btn.approve { background: rgba(63,185,80,0.15); border-color: var(--accent-green); color: var(--accent-green); }
.action-btn.approve:hover { background: rgba(63,185,80,0.3); }
.action-btn.reject { background: rgba(248,81,73,0.15); border-color: var(--accent-red); color: var(--accent-red); }
.action-btn.reject:hover { background: rgba(248,81,73,0.3); }
.action-btn.amend { background: rgba(210,153,34,0.15); border-color: var(--accent-yellow); color: var(--accent-yellow); }
.action-btn.amend:hover { background: rgba(210,153,34,0.3); }
.action-btn.flag { background: rgba(240,136,62,0.15); border-color: var(--accent-orange); color: var(--accent-orange); }
.action-btn.flag:hover { background: rgba(240,136,62,0.3); }
.action-btn.comment { background: rgba(88,166,255,0.15); border-color: var(--accent-blue); color: var(--accent-blue); }
.action-btn.comment:hover { background: rgba(88,166,255,0.3); }
.action-btn:disabled { opacity: 0.4; cursor: not-allowed; }

/* Status badges for new lifecycle */
.status-approved { background: rgba(63,185,80,0.35); color: var(--accent-green); font-weight: 700; }
.status-rejected { background: rgba(248,81,73,0.3); color: var(--accent-red); }
.status-amended { background: rgba(210,153,34,0.3); color: var(--accent-yellow); }
.status-pending-review { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.status-flagged { background: rgba(240,136,62,0.25); color: var(--accent-orange); }

/* Pending review section */
.review-section { background: var(--bg-secondary); border: 2px solid var(--accent-red); border-radius: var(--radius); padding: 14px; margin-bottom: 16px; }
.review-section-title { font-size: 0.82rem; font-weight: 700; color: var(--accent-red); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 10px; display: flex; align-items: center; gap: 8px; }
.review-count-badge { background: var(--accent-red); color: #fff; font-size: 0.7rem; padding: 1px 7px; border-radius: 8px; font-weight: 700; }

/* Inline amend/comment input */
.inline-input { display: none; padding: 8px 14px; border-top: 1px solid var(--border); background: var(--bg-secondary); }
.inline-input.visible { display: block; }
.inline-input textarea { width: 100%; background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-primary); padding: 6px 10px; border-radius: var(--radius); font-family: var(--font-sans); font-size: 0.82rem; min-height: 50px; resize: vertical; outline: none; }
.inline-input textarea:focus { border-color: var(--accent-blue); }
.inline-input-actions { display: flex; gap: 6px; margin-top: 6px; justify-content: flex-end; }

/* Quick directive bar */
.directive-bar { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px 20px; margin: 8px 24px; display: flex; align-items: center; gap: 10px; }
.directive-bar-label { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; font-weight: 600; white-space: nowrap; }
.directive-types { display: flex; gap: 6px; flex-wrap: wrap; flex: 1; }
.directive-type-btn { padding: 4px 12px; border-radius: var(--radius); cursor: pointer; font-size: 0.75rem; font-weight: 600; font-family: var(--font-sans); transition: all 0.15s; border: 1px solid; }
.directive-type-btn.correction { background: rgba(240,136,62,0.1); border-color: var(--accent-orange); color: var(--accent-orange); }
.directive-type-btn.redirect { background: rgba(248,81,73,0.1); border-color: var(--accent-red); color: var(--accent-red); }
.directive-type-btn.approve-all { background: rgba(63,185,80,0.1); border-color: var(--accent-green); color: var(--accent-green); }
.directive-type-btn.reject-all { background: rgba(248,81,73,0.1); border-color: var(--accent-red); color: var(--accent-red); }
.directive-type-btn.context { background: rgba(88,166,255,0.1); border-color: var(--accent-blue); color: var(--accent-blue); }
.directive-type-btn.checkpoint { background: rgba(188,140,255,0.1); border-color: var(--accent-purple); color: var(--accent-purple); }
.directive-type-btn:hover { filter: brightness(1.3); }
.directive-shortcut { font-size: 0.7rem; color: var(--text-muted); font-family: var(--font-mono); white-space: nowrap; }

@media (max-width: 768px) {
  .msg-item { grid-template-columns: 60px 1fr; }
  .msg-agent { display: none; }
  .stats-bar { gap: 6px; }
  .header { padding: 8px 12px; }
  .tab-panel { padding: 12px; }
  .form-row { flex-direction: column; }
  .form-row label { min-width: unset; padding-top: 0; }
  .modal { width: 95vw; }
  .tab-btn { padding: 8px 12px; font-size: 0.75rem; }
  .pending-actions { margin: 8px 12px 0; padding: 10px 14px; gap: 12px; }
  .directive-bar { margin: 8px 12px; padding: 10px 14px; flex-wrap: wrap; }
  .card-actions { flex-wrap: wrap; }
}
</style>
</head>
<body>
<div id="app"></div>

<div class="modal-overlay" id="feedbackModal">
  <div class="modal">
    <div class="modal-title">Commander Directive <span style="font-size:0.75rem;color:var(--text-muted);font-weight:400">(Cmd+K)</span></div>
    <div class="form-row">
      <label for="qf-type">Type</label>
      <select id="qf-type">
        <option value="correction">Correction -- this is wrong, fix X</option>
        <option value="redirect">Redirect -- stop Y, do Z instead</option>
        <option value="approve">Approve -- this is approved, ship it</option>
        <option value="reject">Reject -- do not proceed with this</option>
        <option value="context">Context -- additional info for the agent</option>
        <option value="checkpoint">Checkpoint -- save state, report status</option>
      </select>
    </div>
    <div class="form-row">
      <label for="qf-target">Target</label>
      <input id="qf-target" type="text" placeholder="decision ID, observation ID, or topic">
    </div>
    <div class="form-row">
      <label for="qf-message">Message</label>
      <textarea id="qf-message" placeholder="Directive to the agent..."></textarea>
    </div>
    <div class="form-actions">
      <button class="btn-cancel" onclick="closeModal()">Cancel <span style="font-size:0.7rem;color:var(--text-muted)">(Esc)</span></button>
      <button class="btn-submit" onclick="submitModalFeedback()">Submit Directive</button>
    </div>
  </div>
</div>
<div class="toast" id="toast"></div>

<script>
var SESSION_DATA = __SESSION_DATA_PLACEHOLDER__;
var FEEDBACK_API = '/api/feedback';

function esc(str) { if (!str) return ''; return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
function timeOnly(iso) { if (!iso) return ''; var t = iso.indexOf('T'); if (t < 0) return iso; return iso.substring(t+1).replace('Z',''); }
function fmtSize(bytes) { if (bytes < 1024) return bytes + ' B'; return (bytes / 1024).toFixed(1) + ' KB'; }

// Markdown to HTML renderer (regex-based, zero deps, dark theme aware)
function renderMarkdown(md) {
  if (!md) return '';
  var html = esc(md);

  // Code blocks (``` ... ```)
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, function(m, lang, code) {
    return '<pre><code class="lang-' + lang + '">' + code + '</code></pre>';
  });

  // Inline code
  html = html.replace(/`([^`\n]+)`/g, '<code>$1</code>');

  // Headers (must be after code blocks to avoid matching inside them)
  html = html.replace(/^#### (.+)$/gm, '<h4>$1</h4>');
  html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');

  // Bold and italic
  html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/\*([^*\n]+)\*/g, '<em>$1</em>');

  // Blockquotes
  html = html.replace(/^&gt; (.+)$/gm, '<blockquote>$1</blockquote>');

  // Horizontal rules
  html = html.replace(/^---+$/gm, '<hr>');

  // Task lists
  html = html.replace(/^- \[x\] (.+)$/gm, '<li class="task-done">$1</li>');
  html = html.replace(/^- \[ \] (.+)$/gm, '<li class="task-pending">$1</li>');

  // Unordered lists
  html = html.replace(/^[\-\*] (.+)$/gm, '<li>$1</li>');

  // Ordered lists
  html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');

  // Wrap consecutive <li> in <ul>
  html = html.replace(/((?:<li[^>]*>.*<\/li>\n?)+)/g, '<ul>$1</ul>');

  // Tables
  html = html.replace(/^(\|.+\|)\n(\|[\s\-:|]+\|)\n((?:\|.+\|\n?)+)/gm, function(m, headerRow, sepRow, bodyRows) {
    var headers = headerRow.split('|').filter(function(c) { return c.trim(); });
    var rows = bodyRows.trim().split('\n');
    var t = '<table><thead><tr>';
    headers.forEach(function(h) { t += '<th>' + h.trim() + '</th>'; });
    t += '</tr></thead><tbody>';
    rows.forEach(function(row) {
      var cells = row.split('|').filter(function(c) { return c.trim(); });
      t += '<tr>';
      cells.forEach(function(c) { t += '<td>' + c.trim() + '</td>'; });
      t += '</tr>';
    });
    t += '</tbody></table>';
    return t;
  });

  // Links
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');

  // Paragraphs (lines not already wrapped)
  html = html.replace(/^(?!<[a-z])((?!<\/)[^\n]+)$/gm, function(m, line) {
    if (line.trim() === '') return '';
    return '<p>' + line + '</p>';
  });

  // Clean up empty lines
  html = html.replace(/\n{3,}/g, '\n\n');

  return html;
}

// Diff renderer
function renderDiff(diffText) {
  if (!diffText) return '';
  var lines = diffText.split('\n');
  var html = '';
  lines.forEach(function(line) {
    var cls = 'diff-line';
    if (line.startsWith('+++') || line.startsWith('---')) {
      cls += ' diff-file';
    } else if (line.startsWith('@@')) {
      cls += ' diff-hunk';
    } else if (line.startsWith('+')) {
      cls += ' diff-add';
    } else if (line.startsWith('-')) {
      cls += ' diff-del';
    }
    html += '<div class="' + cls + '">' + esc(line) + '</div>';
  });
  return html;
}

function relTime(iso) {
  if (!iso) return '';
  try {
    var dt = new Date(iso); var now = new Date(); var diffMs = now - dt;
    var mins = Math.floor(diffMs / 60000);
    if (mins < 1) return 'just now'; if (mins < 60) return mins + 'm ago';
    var hrs = Math.floor(mins / 60);
    if (hrs < 24) return hrs + 'h ' + (mins % 60) + 'm ago';
    return Math.floor(hrs / 24) + 'd ago';
  } catch(e) { return ''; }
}

// --- Feedback functions ---
var liveFeedback = [];

function showToast(msg, isError) {
  var t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'toast visible' + (isError ? ' error' : '');
  setTimeout(function() { t.className = 'toast'; }, 3000);
}

function openModal() {
  document.getElementById('feedbackModal').classList.add('visible');
  document.getElementById('qf-message').focus();
}

function closeModal() {
  document.getElementById('feedbackModal').classList.remove('visible');
  document.getElementById('qf-message').value = '';
  document.getElementById('qf-target').value = '';
}

function submitFeedback(type, message, target) {
  if (!message || !message.trim()) { showToast('Message cannot be empty', true); return; }
  fetch(FEEDBACK_API, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({type: type, message: message.trim(), target: target || null})
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.error) { showToast('Error: ' + data.error, true); return; }
    showToast('Directive submitted (#' + data.id + ')');
    refreshFeedback();
  })
  .catch(function(e) { showToast('Failed to submit: ' + e, true); });
}

// --- Decision/Observation action helpers ---
function submitDecisionAction(decisionId, action, comment) {
  var msg = 'Decision ' + decisionId + ': ' + action.toUpperCase();
  if (comment) msg += ' -- ' + comment;
  submitFeedback(action === 'amend' ? 'correction' : action, msg, decisionId);
  // Update local UI state
  var badge = document.getElementById('status-' + decisionId);
  if (badge) { badge.className = 'status-badge status-' + action + 'ed'; badge.textContent = action + 'ed'; }
  var btns = document.getElementById('actions-' + decisionId);
  if (btns) { btns.querySelectorAll('.action-btn').forEach(function(b) { b.disabled = true; }); }
}

function submitObsAction(obsId, action, comment) {
  var msg = 'Observation ' + obsId + ': ' + action.toUpperCase();
  if (comment) msg += ' -- ' + comment;
  submitFeedback(action === 'flag' ? 'correction' : action === 'comment' ? 'context' : 'approve', msg, obsId);
}

function showInlineInput(cardId, action) {
  var inp = document.getElementById('inline-' + cardId);
  if (inp) { inp.classList.toggle('visible'); inp.querySelector('textarea').focus(); }
}

function submitInlineAction(cardId, action, isDecision) {
  var inp = document.getElementById('inline-' + cardId);
  var comment = inp ? inp.querySelector('textarea').value : '';
  if (isDecision) { submitDecisionAction(cardId, action, comment); }
  else { submitObsAction(cardId, action, comment); }
  if (inp) { inp.classList.remove('visible'); inp.querySelector('textarea').value = ''; }
}

function openDirectiveModal(type, target) {
  document.getElementById('qf-type').value = type || 'correction';
  document.getElementById('qf-target').value = target || '';
  openModal();
}

function submitModalFeedback() {
  var type = document.getElementById('qf-type').value;
  var msg = document.getElementById('qf-message').value;
  var target = document.getElementById('qf-target').value;
  submitFeedback(type, msg, target);
  closeModal();
}

function submitInlineFeedback() {
  var type = document.getElementById('fb-type').value;
  var msg = document.getElementById('fb-message').value;
  var target = document.getElementById('fb-target').value;
  if (!msg || !msg.trim()) { showToast('Message cannot be empty', true); return; }
  submitFeedback(type, msg, target);
  document.getElementById('fb-message').value = '';
  document.getElementById('fb-target').value = '';
}

function refreshFeedback() {
  fetch(FEEDBACK_API, {cache:'no-store'})
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.feedback) {
      liveFeedback = data.feedback;
      renderFeedbackList();
      updateFeedbackBadge();
    }
  })
  .catch(function() {});
}

function renderFeedbackList() {
  var container = document.getElementById('liveFeedbackList');
  if (!container) return;
  if (liveFeedback.length === 0) {
    container.innerHTML = '<div class="empty-state" style="padding:20px"><div class="empty-title">No feedback submitted yet</div><div class="empty-detail">Use the form above or Cmd/Ctrl+K to submit commander feedback.</div></div>';
    return;
  }
  var html = '<div class="section-title">Submitted Feedback via GitHub (' + liveFeedback.length + ')</div>';
  liveFeedback.forEach(function(f) {
    html += '<div class="feedback-card ' + esc(f.status) + '">';
    html += '<div class="fb-header">';
    html += '<span class="fb-type ' + esc(f.type) + '">' + esc(f.type) + '</span>';
    html += '<span class="status-badge status-' + esc(f.status) + '">' + esc(f.status) + '</span>';
    html += '<span style="flex:1"></span>';
    html += '<span style="font-size:0.75rem;color:var(--text-muted)">#' + f.id + '</span>';
    html += '</div>';
    html += '<div class="fb-message">' + esc(f.title || f.message) + '</div>';
    if (f.comments > 0) html += '<div class="fb-meta"><span style="color:var(--accent-green)">Agent acknowledged (' + f.comments + ' comments)</span></div>';
    html += '<div class="fb-meta">';
    html += '<span>Created: ' + esc(relTime(f.createdAt)) + '</span>';
    if (f.url) html += '<span><a href="' + esc(f.url) + '" target="_blank" style="color:var(--accent-blue);text-decoration:none">View on GitHub</a></span>';
    html += '</div></div>';
  });
  container.innerHTML = html;
}

function updateFeedbackBadge() {
  var badge = document.getElementById('feedbackPendingBadge');
  var pendingCount = liveFeedback.filter(function(f) { return f.status === 'submitted'; }).length;
  if (badge) {
    if (pendingCount > 0) {
      badge.textContent = pendingCount;
      badge.style.display = '';
    } else {
      badge.style.display = 'none';
    }
  }
}

// Keyboard shortcut: Ctrl+K or Cmd+K for quick feedback
document.addEventListener('keydown', function(e) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
    e.preventDefault();
    var modal = document.getElementById('feedbackModal');
    if (modal.classList.contains('visible')) closeModal();
    else openModal();
  }
  if (e.key === 'Escape') closeModal();
});

// Poll for feedback updates every 30s
setInterval(refreshFeedback, 30000);

function switchToTab(tabName) {
  var btn = document.querySelector('#mainTabs .tab-btn[data-tab="' + tabName + '"]');
  if (btn) btn.click();
}

function renderDashboard(D) {
  if (!D || D.error) {
    document.getElementById('app').innerHTML = '<div class="empty-state"><div class="empty-title">' + (D && D.error ? esc(D.error) : 'No data') + '</div></div>';
    return;
  }
  var s = D.session || {};
  var messages = D.messages || [];
  var missions = D.missions || [];
  var delegations = D.delegations || [];
  var decisions = D.decisions || [];
  var observations = D.observations || [];
  var completedWork = D.completedWork || [];
  var deviations = D.deviations || [];
  var viewerFeedback = D.viewerFeedback || [];
  var counts = D.counts || {};

  var h = '';

  // HEADER
  h += '<div class="header"><div class="header-top"><div>';
  h += '<div class="header-title">Mission Control';
  if (s.status === 'active') h += ' <span style="color:var(--accent-green);font-weight:600;font-size:0.8rem">ACTIVE</span>';
  else h += ' <span style="color:var(--text-muted);font-size:0.8rem">COMPLETED</span>';
  h += ' <span style="color:var(--text-muted);font-size:0.75rem">nobulai.tools</span>';
  h += '</div>';
  h += '<div class="session-meta">';
  h += '<div class="meta-item"><span class="meta-label">Session:</span> <span class="meta-value">' + esc(s.sessionId) + '</span></div>';
  h += '<div class="meta-item"><span class="meta-label">Started:</span> <span class="meta-value">' + esc(s.startedAt ? s.startedAt.substring(0,16).replace('T',' ') : '') + 'Z</span></div>';
  h += '<div class="meta-item"><span class="meta-label">Duration:</span> <span class="meta-value">' + esc(s.duration) + '</span></div>';
  h += '<div class="meta-item"><span class="meta-label">Platform:</span> <span class="meta-value">' + esc(s.platform) + '</span></div>';
  h += '</div></div>';
  h += '<div style="display:flex;align-items:center;gap:10px">';
  h += '<button class="quick-feedback-btn" onclick="openModal()" style="background:var(--accent-yellow);color:#000;border-color:var(--accent-yellow);font-size:0.85rem;padding:6px 18px">Directive (Cmd+K) <span class="pending-badge" id="feedbackPendingBadge" style="display:none">0</span></button>';
  h += '<div style="font-size:0.75rem;color:var(--text-muted)">Snapshot: ' + esc(D.exportedAt) + '</div>';
  h += '</div>';
  h += '</div>';
  if (s.schwerpunkt && s.schwerpunkt !== 'unspecified') {
    h += '<div class="schwerpunkt"><strong>Schwerpunkt:</strong> ' + esc(s.schwerpunkt) + '</div>';
  }

  // Stats bar
  h += '<div class="stats-bar">';
  h += '<div class="stat-card"><div class="stat-value ' + (counts.messages > 0 ? 'blue' : 'muted') + '">' + (counts.messages || 0) + '</div><div class="stat-label">Messages</div></div>';
  h += '<div class="stat-card"><div class="stat-value ' + (counts.decisions > 0 ? 'green' : 'muted') + '">' + (counts.decisions || 0) + '</div><div class="stat-label">Decisions</div></div>';
  h += '<div class="stat-card"><div class="stat-value ' + (counts.observations > 0 ? 'cyan' : 'muted') + '">' + (counts.observations || 0) + '</div><div class="stat-label">Observations</div></div>';
  h += '<div class="stat-card"><div class="stat-value ' + (counts.missions > 0 ? 'purple' : 'muted') + '">' + (counts.missions || 0) + '</div><div class="stat-label">Missions</div></div>';
  h += '<div class="stat-card"><div class="stat-value ' + (counts.delegations > 0 ? 'blue' : 'muted') + '">' + (counts.delegations || 0) + '</div><div class="stat-label">Delegations</div></div>';
  h += '<div class="stat-card"><div class="stat-value ' + (counts.viewerFeedback > 0 ? 'yellow' : 'muted') + '">' + (counts.viewerFeedback || 0) + '</div><div class="stat-label">Feedback</div></div>';
  h += '</div></div>';

  // PENDING ACTIONS BAR
  var totalPending = (counts.pendingDecisions || 0) + (counts.pendingReviewObs || 0) + (counts.feedbackPending || 0);
  var paClass = totalPending > 0 ? 'pending-actions' : 'pending-actions clear';
  h += '<div class="' + paClass + '">';
  if (totalPending > 0) {
    h += '<div class="pending-actions-title">Pending Actions</div>';
    if (counts.pendingDecisions > 0) {
      h += '<div class="pending-item" onclick="switchToTab(\'governance\')"><span class="pending-count red">' + counts.pendingDecisions + '</span><span>decisions need review</span></div>';
    }
    if (counts.pendingReviewObs > 0) {
      h += '<div class="pending-item" onclick="switchToTab(\'governance\')"><span class="pending-count yellow">' + counts.pendingReviewObs + '</span><span>observations pending review</span></div>';
    }
    if (counts.feedbackPending > 0) {
      h += '<div class="pending-item" onclick="switchToTab(\'feedback\')"><span class="pending-count yellow">' + counts.feedbackPending + '</span><span>feedback unresolved</span></div>';
    }
  } else {
    h += '<div class="pending-actions-title">All clear</div>';
    h += '<span style="font-size:0.82rem;color:var(--text-secondary)">No pending actions. All decisions reviewed, all observations acknowledged.</span>';
  }
  h += '</div>';

  // QUICK DIRECTIVE BAR
  h += '<div class="directive-bar">';
  h += '<div class="directive-bar-label">Quick Directives</div>';
  h += '<div class="directive-types">';
  h += '<button class="directive-type-btn correction" onclick="openDirectiveModal(\'correction\')">Correction</button>';
  h += '<button class="directive-type-btn redirect" onclick="openDirectiveModal(\'redirect\')">Redirect</button>';
  h += '<button class="directive-type-btn approve-all" onclick="openDirectiveModal(\'approve\')">Approve</button>';
  h += '<button class="directive-type-btn reject-all" onclick="openDirectiveModal(\'reject\')">Reject</button>';
  h += '<button class="directive-type-btn context" onclick="openDirectiveModal(\'context\')">Context</button>';
  h += '<button class="directive-type-btn checkpoint" onclick="openDirectiveModal(\'checkpoint\')">Checkpoint</button>';
  h += '</div>';
  h += '<div class="directive-shortcut">Cmd+K</div>';
  h += '</div>';

  var documents = D.documents || [];
  var gitDiffs = D.gitDiffs || [];

  // TABS
  h += '<div class="tab-nav" id="mainTabs">';
  h += '<button class="tab-btn active" data-tab="messages">Messages (' + (counts.messages||0) + ')</button>';
  h += '<button class="tab-btn' + (documents.length > 0 ? ' has-data' : '') + '" data-tab="documents">Documents (' + documents.length + ')</button>';
  h += '<button class="tab-btn' + (counts.decisions > 0 ? ' has-data' : '') + '" data-tab="governance">Governance</button>';
  h += '<button class="tab-btn' + (gitDiffs.length > 0 ? ' has-data' : '') + '" data-tab="diffs">Git Diffs (' + gitDiffs.length + ')</button>';
  h += '<button class="tab-btn' + (counts.delegations > 0 ? ' has-data' : '') + '" data-tab="delegations">Delegations (' + (counts.delegations||0) + ')</button>';
  h += '<button class="tab-btn' + (counts.missions > 0 ? ' has-data' : '') + '" data-tab="missions">Missions (' + (counts.missions||0) + ')</button>';
  h += '<button class="tab-btn" data-tab="state">State</button>';
  h += '<button class="tab-btn has-data" data-tab="feedback">Feedback (' + viewerFeedback.length + ')</button>';
  h += '</div>';

  // MESSAGES TAB
  h += '<div class="tab-panel active" id="tab-messages">';
  if (messages.length === 0) {
    h += '<div class="empty-state"><div class="empty-title">No messages recorded</div></div>';
  } else {
    h += '<div class="controls"><div style="display:flex;gap:4px" id="msgTypeFilter">';
    h += '<button class="filter-btn active" data-filter="all">All (' + messages.length + ')</button>';
    h += '<button class="filter-btn" data-filter="sitrep">SITREPs (' + (counts.sitreps||0) + ')</button>';
    h += '<button class="filter-btn" data-filter="finding">Findings (' + (counts.findings||0) + ')</button>';
    h += '</div><div style="display:flex;gap:4px" id="msgOrderBtn">';
    h += '<button class="filter-btn active" data-order="newest">Newest first</button>';
    h += '<button class="filter-btn" data-order="oldest">Oldest first</button>';
    h += '</div></div>';
    h += '<div class="message-feed" id="messageFeed">';
    var sorted = messages.slice().reverse();
    sorted.forEach(function(m) {
      h += '<div class="msg-item" data-type="' + esc(m.type) + '">';
      h += '<div class="msg-time">' + esc(timeOnly(m.createdAt)) + '</div>';
      h += '<div class="msg-agent">' + esc(m.agentRole) + '</div>';
      h += '<div class="msg-text">';
      h += '<span class="type-badge type-' + esc(m.type) + '">' + esc(m.type) + '</span>';
      h += '<span class="msg-severity sev-' + esc(m.severity) + '">' + esc(m.severity) + '</span> ';
      if (m.title) h += '<strong>' + esc(m.title) + '</strong> ';
      h += esc(m.message);
      h += '</div></div>';
    });
    h += '</div>';
  }
  h += '</div>';

  // DOCUMENTS TAB
  h += '<div class="tab-panel" id="tab-documents">';
  if (documents.length === 0) {
    h += '<div class="empty-state"><div class="empty-title">No documents embedded</div><div class="empty-detail">Re-export with --scratch to embed session documents.</div></div>';
  } else {
    // Category filter bar
    var docCats = {};
    documents.forEach(function(d) { docCats[d.category] = (docCats[d.category]||0) + 1; });
    h += '<div class="doc-filter-bar" id="docCatFilter">';
    h += '<button class="filter-btn active" data-filter="all">All (' + documents.length + ')</button>';
    Object.keys(docCats).forEach(function(cat) {
      h += '<button class="filter-btn" data-filter="' + esc(cat) + '">' + esc(cat) + ' (' + docCats[cat] + ')</button>';
    });
    h += '</div>';
    h += '<div class="doc-list" id="docList">';
    documents.forEach(function(d, idx) {
      h += '<div class="doc-item" data-cat="' + esc(d.category) + '" id="doc-' + idx + '">';
      h += '<div class="doc-header" onclick="toggleDoc(' + idx + ')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="doc-cat ' + esc(d.category) + '">' + esc(d.category) + '</span>';
      h += '<span class="doc-filename">' + esc(d.filename) + '</span>';
      h += '<span class="doc-size">' + fmtSize(d.size) + '</span>';
      h += '<div class="doc-actions">';
      h += '<button class="doc-fb-btn" onclick="event.stopPropagation();openDocFeedback(\'' + esc(d.filename) + '\')">Feedback</button>';
      h += '</div>';
      h += '</div>';
      h += '<div class="doc-content">';
      h += '<div class="md-render">' + renderMarkdown(d.content) + '</div>';
      h += '<div class="doc-feedback-inline" id="docfb-' + idx + '" style="display:none">';
      h += '<div style="font-size:0.78rem;color:var(--accent-yellow);margin-bottom:6px;font-weight:600">Feedback on: ' + esc(d.filename) + '</div>';
      h += '<textarea id="docfb-msg-' + idx + '" placeholder="Your feedback on this document..."></textarea>';
      h += '<div class="doc-fb-actions">';
      h += '<button class="btn-cancel" onclick="document.getElementById(\'docfb-' + idx + '\').style.display=\'none\'">Cancel</button>';
      h += '<button class="btn-submit" onclick="submitDocFeedback(' + idx + ',\'' + esc(d.filename) + '\')">Submit</button>';
      h += '</div></div>';
      h += '</div></div>';
    });
    h += '</div>';
  }
  h += '</div>';

  // GIT DIFFS TAB
  h += '<div class="tab-panel" id="tab-diffs">';
  if (gitDiffs.length === 0) {
    h += '<div class="empty-state"><div class="empty-title">No git diffs available</div><div class="empty-detail">No recent commits modified protected files.</div></div>';
  } else {
    h += '<div class="section-title">Recent commits modifying protected files</div>';
    gitDiffs.forEach(function(d, idx) {
      h += '<div class="diff-item" id="diff-' + idx + '">';
      h += '<div class="diff-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="diff-sha">' + esc(d.sha) + '</span>';
      h += '<span class="diff-subject">' + esc(d.subject) + '</span>';
      h += '<span class="diff-date">' + esc(d.date) + '</span>';
      h += '</div>';
      h += '<div class="diff-body"><div class="diff-content">' + renderDiff(d.diff) + '</div></div>';
      h += '</div>';
    });
  }
  h += '</div>';

  // GOVERNANCE TAB
  h += '<div class="tab-panel" id="tab-governance">';

  // Pending review observations -- promoted to top
  var pendingObs = observations.filter(function(o) { return o.status === 'pending-review'; });
  if (pendingObs.length > 0) {
    h += '<div class="review-section">';
    h += '<div class="review-section-title">Pending Review <span class="review-count-badge">' + pendingObs.length + '</span></div>';
    pendingObs.forEach(function(o) {
      var cc = {observation:'blue',assumption:'yellow',fact:'green',finding:'cyan'};
      h += '<div class="card">';
      h += '<div class="card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="card-id" style="color:var(--accent-' + (cc[o.category]||'blue') + ')">' + esc(o.id) + '</span>';
      h += '<span class="card-title">' + esc(o.text) + '</span>';
      h += '<span class="status-badge status-pending-review">PENDING</span>';
      h += '</div><div class="card-body">';
      if (o.evidence) {
        h += '<div class="obs-evidence"><div class="obs-evidence-title">Evidence</div>';
        h += '<div class="md-render">' + renderMarkdown(o.evidence) + '</div>';
        h += '</div>';
      }
      if (o.createdAt) h += '<div style="margin-top:6px"><strong>Recorded:</strong> ' + esc(o.createdAt) + '</div>';
      h += '</div>';
      // Action buttons
      h += '<div class="card-actions" id="obs-actions-' + esc(o.id) + '">';
      h += '<button class="action-btn approve" onclick="event.stopPropagation();submitObsAction(\'' + esc(o.id) + '\',\'approve\')">Approve</button>';
      h += '<button class="action-btn flag" onclick="event.stopPropagation();submitObsAction(\'' + esc(o.id) + '\',\'flag\')">Flag</button>';
      h += '<button class="action-btn comment" onclick="event.stopPropagation();showInlineInput(\'obs-' + esc(o.id) + '\',\'comment\')">Comment</button>';
      h += '</div>';
      h += '<div class="inline-input" id="inline-obs-' + esc(o.id) + '">';
      h += '<textarea placeholder="Your comment on this observation..."></textarea>';
      h += '<div class="inline-input-actions">';
      h += '<button class="btn-cancel" onclick="document.getElementById(\'inline-obs-' + esc(o.id) + '\').classList.remove(\'visible\')">Cancel</button>';
      h += '<button class="btn-submit" onclick="submitInlineAction(\'obs-' + esc(o.id) + '\',\'comment\',false)">Submit</button>';
      h += '</div></div>';
      h += '</div>';
    });
    h += '</div>';
  }

  // Decisions with action buttons
  var pendingDec = decisions.filter(function(d) { return d.status !== 'approved' && d.status !== 'rejected' && d.status !== 'implemented'; });
  var reviewedDec = decisions.filter(function(d) { return d.status === 'approved' || d.status === 'rejected' || d.status === 'implemented'; });

  h += '<div class="section-title">Decisions Awaiting Review (' + pendingDec.length + ')</div>';
  if (pendingDec.length === 0 && reviewedDec.length === 0) {
    h += '<div class="empty-state" style="padding:20px"><div class="empty-title">No decisions recorded</div></div>';
  } else if (pendingDec.length === 0) {
    h += '<div style="padding:12px;color:var(--accent-green);font-size:0.85rem;font-weight:600">All decisions reviewed.</div>';
  } else {
    pendingDec.forEach(function(d) {
      h += '<div class="card">';
      h += '<div class="card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="card-id">' + esc(d.decisionId) + '</span>';
      h += '<span class="card-title">' + esc(d.title) + '</span>';
      h += '<span class="status-badge status-' + esc(d.status) + '" id="status-' + esc(d.decisionId) + '">' + esc(d.status) + '</span>';
      h += '</div><div class="card-body">';
      if (d.description) h += '<div>' + esc(d.description) + '</div>';
      if (d.implementationEvidence) h += '<div style="margin-top:6px"><strong>Evidence:</strong> ' + esc(d.implementationEvidence) + '</div>';
      if (d.decidedAt) h += '<div><strong>Decided:</strong> ' + esc(d.decidedAt) + '</div>';
      h += '</div>';
      // Action buttons
      h += '<div class="card-actions" id="actions-' + esc(d.decisionId) + '">';
      h += '<button class="action-btn approve" onclick="event.stopPropagation();submitDecisionAction(\'' + esc(d.decisionId) + '\',\'approve\')">Approve</button>';
      h += '<button class="action-btn reject" onclick="event.stopPropagation();submitDecisionAction(\'' + esc(d.decisionId) + '\',\'reject\')">Reject</button>';
      h += '<button class="action-btn amend" onclick="event.stopPropagation();showInlineInput(\'' + esc(d.decisionId) + '\',\'amend\')">Amend</button>';
      h += '</div>';
      // Inline amend input
      h += '<div class="inline-input" id="inline-' + esc(d.decisionId) + '">';
      h += '<textarea placeholder="What should change about this decision?"></textarea>';
      h += '<div class="inline-input-actions">';
      h += '<button class="btn-cancel" onclick="document.getElementById(\'inline-' + esc(d.decisionId) + '\').classList.remove(\'visible\')">Cancel</button>';
      h += '<button class="btn-submit" onclick="submitInlineAction(\'' + esc(d.decisionId) + '\',\'amend\',true)">Submit Amendment</button>';
      h += '</div></div>';
      h += '</div>';
    });
  }

  // Reviewed decisions (collapsed section)
  if (reviewedDec.length > 0) {
    h += '<div class="section-title" style="margin-top:16px">Reviewed Decisions (' + reviewedDec.length + ')</div>';
    reviewedDec.forEach(function(d) {
      h += '<div class="card">';
      h += '<div class="card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="card-id">' + esc(d.decisionId) + '</span>';
      h += '<span class="card-title">' + esc(d.title) + '</span>';
      h += '<span class="status-badge status-' + esc(d.status) + '">' + esc(d.status) + '</span>';
      h += '</div><div class="card-body">';
      if (d.description) h += '<div>' + esc(d.description) + '</div>';
      if (d.implementationEvidence) h += '<div style="margin-top:6px"><strong>Evidence:</strong> ' + esc(d.implementationEvidence) + '</div>';
      if (d.decidedAt) h += '<div><strong>Decided:</strong> ' + esc(d.decidedAt) + '</div>';
      h += '</div></div>';
    });
  }

  // Non-pending observations
  h += '<div class="section-title" style="margin-top:16px">Observations (' + observations.length + ')</div>';
  var nonPendingObs = observations.filter(function(o) { return o.status !== 'pending-review'; });
  if (observations.length === 0) {
    h += '<div class="empty-state" style="padding:20px"><div class="empty-title">No observations recorded</div></div>';
  } else {
    if (pendingObs.length > 0) {
      h += '<div style="padding:6px 0;font-size:0.78rem;color:var(--text-muted)">' + pendingObs.length + ' pending-review observations shown above.</div>';
    }
    nonPendingObs.forEach(function(o) {
      var cc = {observation:'blue',assumption:'yellow',fact:'green',finding:'cyan'};
      h += '<div class="card">';
      h += '<div class="card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="card-id" style="color:var(--accent-' + (cc[o.category]||'blue') + ')">' + esc(o.id) + '</span>';
      h += '<span class="card-title">' + esc(o.text) + '</span>';
      if (o.severity) h += '<span class="msg-severity sev-' + esc(o.severity) + '">' + esc(o.severity) + '</span>';
      h += '</div><div class="card-body">';
      if (o.evidence) {
        h += '<div class="obs-evidence"><div class="obs-evidence-title">Evidence</div>';
        h += '<div class="md-render">' + renderMarkdown(o.evidence) + '</div>';
        h += '</div>';
        var refDoc = findReferencedDoc(o.evidence, documents);
        if (refDoc !== null) {
          h += '<div style="margin-top:8px"><button class="doc-fb-btn" onclick="scrollToDoc(' + refDoc + ')">View referenced document</button></div>';
        }
      }
      if (o.createdAt) h += '<div style="margin-top:6px"><strong>Recorded:</strong> ' + esc(o.createdAt) + '</div>';
      h += '</div></div>';
    });
  }
  h += '</div>';

  // DELEGATIONS TAB
  h += '<div class="tab-panel" id="tab-delegations">';
  if (delegations.length === 0) {
    h += '<div class="empty-state"><div class="empty-title">No delegations recorded</div></div>';
  } else {
    delegations.forEach(function(d) {
      h += '<div class="del-card"><div class="del-header">';
      h += '<span class="del-name">' + esc(d.agentName) + '</span>';
      h += '<span class="status-badge status-' + esc(d.status) + '">' + esc(d.status) + '</span>';
      h += '</div><div class="del-meta">';
      if (d.launchedAt) h += '<span>Launched: ' + esc(timeOnly(d.launchedAt)) + '</span>';
      if (d.completedAt) h += '<span>Completed: ' + esc(timeOnly(d.completedAt)) + '</span>';
      h += '</div>';
      if (d.promptSummary) h += '<div class="del-prompt">' + esc(d.promptSummary) + '</div>';
      if (d.outcome) h += '<div style="font-size:0.82rem;color:var(--accent-green);margin-top:6px;padding:4px 10px;background:var(--bg-tertiary);border-radius:var(--radius)"><strong>Outcome:</strong> ' + esc(d.outcome) + '</div>';
      h += '</div>';
    });
  }
  h += '</div>';

  // MISSIONS TAB
  h += '<div class="tab-panel" id="tab-missions">';
  if (missions.length === 0) {
    h += '<div class="empty-state"><div class="empty-title">No missions recorded</div></div>';
  } else {
    missions.forEach(function(m) {
      h += '<div class="card"><div class="card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      h += '<span class="collapse-icon">&#9654;</span>';
      h += '<span class="card-id">' + esc(m.missionId) + '</span>';
      h += '<span class="card-title">' + esc(m.description) + '</span>';
      h += '<span class="status-badge status-' + esc(m.status) + '">' + esc(m.status) + '</span>';
      h += '</div><div class="card-body">';
      if (m.launchedAt) h += '<div><strong>Launched:</strong> ' + esc(m.launchedAt) + '</div>';
      if (m.keyResult) h += '<div><strong>Key Result:</strong> ' + esc(m.keyResult) + '</div>';
      h += '</div></div>';
    });
  }
  h += '</div>';

  // STATE TAB
  h += '<div class="tab-panel" id="tab-state">';
  if (s.currentState) {
    h += '<div class="state-block"><div class="state-block-title">Current State</div>';
    h += '<div style="font-size:0.82rem;color:var(--text-secondary);line-height:1.6">' + esc(s.currentState) + '</div></div>';
  }
  h += '<div class="state-block"><div class="state-block-title">Completed Work (' + completedWork.length + ')</div>';
  if (completedWork.length === 0) {
    h += '<div style="font-size:0.82rem;color:var(--text-muted)">No completed work recorded.</div>';
  } else {
    completedWork.slice().reverse().forEach(function(w) {
      h += '<div class="state-item">' + esc(w.item);
      if (w.category) h += ' <span style="color:var(--text-muted);font-size:0.75rem">[' + esc(w.category) + ']</span>';
      h += '</div>';
    });
  }
  h += '</div>';
  h += '<div class="state-block"><div class="state-block-title">Deviations (' + deviations.length + ')</div>';
  if (deviations.length === 0) {
    h += '<div style="font-size:0.82rem;color:var(--text-muted)">No deviations recorded.</div>';
  } else {
    deviations.forEach(function(d) {
      h += '<div class="state-item" style="color:var(--accent-orange)"><span style="color:var(--accent-red);margin-right:6px">*</span>' + esc(d.description) + '</div>';
    });
  }
  h += '</div></div>';

  // FEEDBACK TAB
  h += '<div class="tab-panel" id="tab-feedback">';

  // Inline feedback form
  h += '<div class="feedback-form"><div class="form-title">Submit Commander Directive</div>';
  h += '<div class="form-row"><label for="fb-type">Type</label><select id="fb-type">';
  h += '<option value="correction">Correction -- this is wrong, fix X</option>';
  h += '<option value="redirect">Redirect -- stop Y, do Z instead</option>';
  h += '<option value="approve">Approve -- this is approved, ship it</option>';
  h += '<option value="reject">Reject -- do not proceed</option>';
  h += '<option value="context">Context -- info for the agent</option>';
  h += '<option value="checkpoint">Checkpoint -- save state, report</option>';
  h += '</select></div>';
  h += '<div class="form-row"><label for="fb-target">Target</label>';
  h += '<input id="fb-target" type="text" placeholder="decision ID, observation ID, or topic"></div>';
  h += '<div class="form-row"><label for="fb-message">Message</label>';
  h += '<textarea id="fb-message" placeholder="Directive to the agent..."></textarea></div>';
  h += '<div class="form-actions"><button class="btn-submit" onclick="submitInlineFeedback()">Submit Directive</button></div></div>';

  // Live feedback list (populated via API)
  h += '<div id="liveFeedbackList"><div class="empty-state" style="padding:20px"><div class="empty-title">Loading feedback...</div></div></div>';

  // Session viewer feedback (static, from DB snapshot)
  if (viewerFeedback.length > 0) {
    h += '<div style="margin-top:20px"><div class="section-title">Session Viewer Feedback (' + viewerFeedback.length + ')</div>';
    viewerFeedback.forEach(function(f) {
      h += '<div class="feedback-card ' + esc(f.feedbackType) + '">';
      h += '<div class="fb-header">';
      h += '<span class="fb-type ' + esc(f.feedbackType) + '">' + esc(f.feedbackType) + '</span>';
      h += '<span style="font-size:0.75rem;color:var(--text-muted)">#' + f.id + ' -- ' + esc(relTime(f.createdAt)) + '</span>';
      h += '</div>';
      if (f.filePath && f.filePath !== '__general__') {
        var fname = f.filePath.split('/').pop();
        h += '<div class="fb-file">' + esc(fname) + '</div>';
      }
      if (f.sectionContext) h += '<div class="fb-section">Section: ' + esc(f.sectionContext) + '</div>';
      h += '<div class="fb-message">' + esc(f.message) + '</div>';
      h += '<div class="fb-meta"><span>' + esc(f.createdAt) + '</span></div>';
      h += '</div>';
    });
    h += '</div>';
  }

  h += '</div>';

  // FOOTER
  h += '<div class="footer">Mission Control -- nobulai.tools -- Static snapshot exported ' + esc(D.exportedAt) + '</div>';

  document.getElementById('app').innerHTML = h;

  // Tab switching
  document.querySelectorAll('#mainTabs .tab-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      document.querySelectorAll('#mainTabs .tab-btn').forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      document.querySelectorAll('.tab-panel').forEach(function(p) { p.classList.remove('active'); });
      var target = document.getElementById('tab-' + btn.dataset.tab);
      if (target) target.classList.add('active');
    });
  });

  // Message filtering
  var mtf = document.getElementById('msgTypeFilter');
  if (mtf) {
    mtf.querySelectorAll('.filter-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        mtf.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
        var f = btn.dataset.filter;
        document.querySelectorAll('#messageFeed .msg-item').forEach(function(item) {
          item.style.display = (f === 'all' || item.dataset.type === f) ? '' : 'none';
        });
      });
    });
  }

  // Message order toggle
  var mob = document.getElementById('msgOrderBtn');
  if (mob) {
    mob.querySelectorAll('.filter-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        mob.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
        var feed = document.getElementById('messageFeed');
        if (feed) { var items = Array.from(feed.children); items.reverse(); items.forEach(function(i) { feed.appendChild(i); }); }
      });
    });
  }
}

// --- Document viewer functions ---
function toggleDoc(idx) {
  var el = document.getElementById('doc-' + idx);
  if (el) el.classList.toggle('expanded');
}

function scrollToDoc(idx) {
  // Switch to documents tab
  document.querySelectorAll('#mainTabs .tab-btn').forEach(function(b) { b.classList.remove('active'); });
  var docTab = document.querySelector('[data-tab="documents"]');
  if (docTab) docTab.classList.add('active');
  document.querySelectorAll('.tab-panel').forEach(function(p) { p.classList.remove('active'); });
  var tp = document.getElementById('tab-documents');
  if (tp) tp.classList.add('active');
  // Expand and scroll
  var el = document.getElementById('doc-' + idx);
  if (el) {
    el.classList.add('expanded');
    el.scrollIntoView({behavior:'smooth',block:'start'});
  }
}

function findReferencedDoc(text, documents) {
  if (!text || !documents || documents.length === 0) return null;
  for (var i = 0; i < documents.length; i++) {
    var fn = documents[i].filename;
    if (text.indexOf(fn) >= 0 || text.indexOf(fn.replace('.md','')) >= 0) return i;
  }
  return null;
}

function openDocFeedback(filename) {
  var modal = document.getElementById('feedbackModal');
  document.getElementById('qf-target').value = filename;
  document.getElementById('qf-type').value = 'observation';
  modal.classList.add('visible');
  document.getElementById('qf-message').focus();
}

function submitDocFeedback(idx, filename) {
  var msg = document.getElementById('docfb-msg-' + idx).value;
  if (!msg || !msg.trim()) { showToast('Message cannot be empty', true); return; }
  submitFeedback('observation', msg.trim(), filename);
  document.getElementById('docfb-msg-' + idx).value = '';
  document.getElementById('docfb-' + idx).style.display = 'none';
}

// --- Document category filter ---
function setupDocFilter() {
  var dcf = document.getElementById('docCatFilter');
  if (!dcf) return;
  dcf.querySelectorAll('.filter-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      dcf.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      var f = btn.dataset.filter;
      document.querySelectorAll('#docList .doc-item').forEach(function(item) {
        item.style.display = (f === 'all' || item.dataset.cat === f) ? '' : 'none';
      });
    });
  });
}

renderDashboard(SESSION_DATA);
setupDocFilter();
// Load live feedback from API on initial render
refreshFeedback();
</script>
</body>
</html>"""


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export session DB to static HTML for Vercel deployment."
    )
    parser.add_argument(
        "--db",
        type=Path,
        help="Path to session DB file.",
    )
    parser.add_argument(
        "--session",
        type=str,
        help="Session prefix (e.g., c0dc2ddc-f).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("dist"),
        help="Output directory (default: dist/).",
    )
    parser.add_argument(
        "--scratch",
        type=Path,
        help="Path to scratch directory with .md files to embed.",
    )
    args = parser.parse_args()

    # Find repo root
    repo_root = Path.cwd()
    for parent in [repo_root, *repo_root.parents]:
        if (parent / ".git").exists():
            repo_root = parent
            break

    if args.db:
        db_path = args.db.resolve()
    elif args.session:
        db_path = repo_root / ".aitools" / "sessions" / f"{args.session}.db"
    else:
        print("Error: provide --db or --session", file=sys.stderr)
        sys.exit(1)

    if not db_path.exists():
        print(f"Error: DB not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    # Resolve scratch dir
    scratch_dir = args.scratch.resolve() if args.scratch else None
    if scratch_dir and not scratch_dir.is_dir():
        print(f"Warning: scratch dir not found: {scratch_dir}", file=sys.stderr)
        scratch_dir = None

    print(f"Reading session DB: {db_path}")
    data = extract_session_data(db_path)

    if "error" in data:
        print(f"Error: {data['error']}", file=sys.stderr)
        sys.exit(1)

    counts = data.get("counts", {})
    print(
        f"  Messages: {counts.get('messages', 0)}, "
        f"Decisions: {counts.get('decisions', 0)}, "
        f"Observations: {counts.get('observations', 0)}, "
        f"Feedback: {counts.get('viewerFeedback', 0)}"
    )

    html = build_static_html(data, scratch_dir=scratch_dir, repo_root=repo_root)

    if scratch_dir:
        doc_count = len(data.get("documents", []))
        diff_count = len(data.get("gitDiffs", []))
        print(f"  Documents embedded: {doc_count}, Git diffs: {diff_count}")

    out_dir = args.out.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    index_path = out_dir / "index.html"
    index_path.write_text(html, encoding="utf-8")
    print(f"Wrote: {index_path} ({len(html)} bytes)")


if __name__ == "__main__":
    main()
