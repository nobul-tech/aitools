#!/usr/bin/env python3
"""generate-dashboard.py -- Mission Control Dashboard Generator

Purpose: Read a running estimate JSON file and produce a self-contained HTML
dashboard that visualizes session state: header, summary stats, agent tracker,
governance (decisions + assumptions), findings, open threads, and session state.

Supports two modes:
  Static (default): Embeds JSON into HTML at generation time. Works from
      file:/// on any platform. No runtime dependencies.
  Live (--serve): Starts a local HTTP server. Dashboard polls the estimate
      file via fetch() and re-renders on change without page reload.
      Uses --watch internally to detect file changes and refresh the data
      endpoint. Zero external dependencies (stdlib http.server).

This is the first S1 (Administration) capability in the harness --
administration-as-code. The generator codifies the pattern proven in 4
manually-produced dashboards from sessions 5HyCwPtSDH and Z1IhGrcgGO.

Architecture: Embedded JSON + generator script (Option G from the feasibility
study). Static mode embeds data; live mode serves it via HTTP -- both use the
same HTML template with progressive enhancement.

Usage:
    python3 scripts/generate-dashboard.py --estimate path/to/running-estimate.json
    python3 scripts/generate-dashboard.py --estimate est.json --output dashboard.html
    python3 scripts/generate-dashboard.py --estimate est.json --open
    python3 scripts/generate-dashboard.py --estimate est.json --serve
    python3 scripts/generate-dashboard.py --estimate est.json --serve --port 9000

Safe to re-run. Overwrites output if it already exists.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import sys
import threading
import time
import webbrowser
from datetime import datetime, timezone
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from typing import Any


def validate_estimate_fields(data: dict[str, Any]) -> list[str]:
    """Check for expected dashboard fields and return list of missing ones.

    The dashboard renders from these fields. Missing fields produce silent zeros
    in the UI -- this function makes schema mismatches visible to operators.
    """
    missing: list[str] = []

    # Top-level arrays
    for field in ("delegationLog", "findings", "openThreads"):
        if field not in data:
            missing.append(field)

    # Nested under situation
    situation = data.get("situation")
    if situation is None:
        missing.append("situation")
    elif isinstance(situation, dict):
        for field in ("decisions", "assumptions", "deviations", "facts"):
            if field not in situation:
                missing.append(f"situation.{field}")

    return missing


def load_estimate(path: Path) -> dict[str, Any]:
    """Load and validate a running estimate JSON file."""
    if not path.exists():
        print(f"Error: estimate file not found: {path}", file=sys.stderr)
        sys.exit(1)
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in {path}: {e}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(data, dict):
        print(f"Error: estimate must be a JSON object, got {type(data).__name__}", file=sys.stderr)
        sys.exit(1)

    # Warn about missing fields -- dashboard still works (defaults to [])
    # but operators see the schema mismatch instead of silent zeros
    missing = validate_estimate_fields(data)
    if missing:
        print(
            f"[dashboard] WARNING: Running estimate missing fields: "
            f"{', '.join(missing)}. Dashboard will show zeros for these.",
            file=sys.stderr,
        )

    return data


def derive_output_path(estimate_path: Path, session_id: str | None) -> Path:
    """Derive output path per D-DASHBOARD-GOVERNANCE naming convention."""
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    if session_id:
        name = f"{date_str}_session-{session_id}-dashboard.html"
    else:
        name = f"{date_str}_dashboard.html"
    return estimate_path.parent / name


def get_nested(data: dict, *keys: str, default: Any = None) -> Any:
    """Safely traverse nested dict keys."""
    current = data
    for key in keys:
        if isinstance(current, dict):
            current = current.get(key, default)
        else:
            return default
    return current


def build_html(
    estimate: dict[str, Any],
    generated_at: str,
    *,
    live_mode: bool = False,
    poll_url: str = "",
    poll_interval: int = 3,
) -> str:
    """Build the complete self-contained HTML dashboard.

    In static mode: embeds estimate JSON directly. Works from file:///.
    In live mode: embeds initial data AND enables fetch-based polling
    from poll_url. Dashboard re-renders on new data without page reload.
    """
    estimate_json = json.dumps(estimate, ensure_ascii=False, indent=None)
    html = HTML_TEMPLATE.replace("/*__ESTIMATE_DATA__*/null", estimate_json).replace(
        "/*__GENERATED_AT__*/", generated_at
    )
    live_flag = "true" if live_mode else "false"
    html = html.replace("/*__LIVE_MODE__*/false", live_flag)
    html = html.replace("/*__POLL_URL__*/", poll_url)
    html = html.replace("/*__POLL_INTERVAL__*/3", str(poll_interval))
    return html


# ---------------------------------------------------------------------------
# Live server
# ---------------------------------------------------------------------------

class DashboardHandler(SimpleHTTPRequestHandler):
    """HTTP handler that serves the dashboard and a live data endpoint."""

    estimate_path: Path
    dashboard_html: str

    def do_GET(self) -> None:
        if self.path == "/" or self.path == "/index.html":
            content = self.server.dashboard_html.encode("utf-8")  # type: ignore[attr-defined]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(content)
        elif self.path == "/api/estimate":
            try:
                data = self.server.estimate_path.read_text(encoding="utf-8")  # type: ignore[attr-defined]
                content = data.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.send_header("Cache-Control", "no-cache")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(content)
            except Exception as e:
                self.send_error(500, str(e))
        else:
            self.send_error(404, "Not found")

    def log_message(self, format: str, *args: Any) -> None:
        """Suppress routine request logging; only log errors."""
        if args and isinstance(args[0], str) and args[0].startswith("2"):
            return  # suppress 2xx logs
        super().log_message(format, *args)


def watch_and_regenerate(
    estimate_path: Path,
    server: HTTPServer,
    poll_url: str,
    poll_interval: int,
) -> None:
    """Watch estimate file for changes and regenerate the served HTML.

    Uses os.stat polling (cross-platform, no dependencies).
    """
    last_mtime = estimate_path.stat().st_mtime
    while True:
        time.sleep(1)
        try:
            current_mtime = estimate_path.stat().st_mtime
        except OSError:
            continue
        if current_mtime != last_mtime:
            last_mtime = current_mtime
            try:
                estimate = load_estimate(estimate_path)
                generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                server.dashboard_html = build_html(  # type: ignore[attr-defined]
                    estimate,
                    generated_at,
                    live_mode=True,
                    poll_url=poll_url,
                    poll_interval=poll_interval,
                )
                session_id = get_nested(estimate, "meta", "sessionId") or "unknown"
                version = get_nested(estimate, "meta", "version", default="?")
                print(f"[{generated_at}] Regenerated: v{version} session={session_id}")
            except Exception as e:
                print(f"[watch] Error regenerating: {e}", file=sys.stderr)


def run_server(
    estimate_path: Path,
    port: int,
    open_browser: bool,
    poll_interval: int = 3,
) -> None:
    """Start the live dashboard server."""
    estimate = load_estimate(estimate_path)
    session_id = get_nested(estimate, "meta", "sessionId") or "unknown"
    poll_url = f"http://localhost:{port}/api/estimate"
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    html = build_html(
        estimate,
        generated_at,
        live_mode=True,
        poll_url=poll_url,
        poll_interval=poll_interval,
    )

    server = HTTPServer(("localhost", port), DashboardHandler)
    server.estimate_path = estimate_path  # type: ignore[attr-defined]
    server.dashboard_html = html  # type: ignore[attr-defined]

    # Start file watcher thread
    watcher = threading.Thread(
        target=watch_and_regenerate,
        args=(estimate_path, server, poll_url, poll_interval),
        daemon=True,
    )
    watcher.start()

    url = f"http://localhost:{port}/"
    print(f"Live dashboard serving at: {url}")
    print(f"Watching: {estimate_path}")
    print(f"Session: {session_id}")
    print(f"Poll interval: {poll_interval}s")
    print("Press Ctrl+C to stop.")

    if open_browser:
        webbrowser.open(url)

    # Handle Ctrl+C gracefully
    def shutdown(signum: int, frame: Any) -> None:
        print("\nShutting down...")
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    server.serve_forever()


# ---------------------------------------------------------------------------
# HTML Template
# ---------------------------------------------------------------------------
# The template below contains the full CSS design language from the v2 session
# activity dashboard (dark theme, GitHub-inspired), adapted to render from the
# running estimate schema. Client-side JS reads DASHBOARD_DATA and renders all
# panels dynamically.

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mission Control Dashboard</title>
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

/* Header */
.header { position: sticky; top: 0; z-index: 100; background: var(--bg-secondary); border-bottom: 1px solid var(--border); padding: 12px 24px; box-shadow: var(--shadow); }
.header-top { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 8px; }
.header-title { font-size: 1.3rem; font-weight: 600; }
.header-title span { color: var(--text-secondary); font-weight: 400; font-size: 0.9rem; }
.session-id { font-family: var(--font-mono); color: var(--accent-blue); font-size: 0.85rem; }
.schwerpunkt { font-size: 0.82rem; color: var(--text-secondary); line-height: 1.5; margin-top: 4px; padding: 6px 10px; background: var(--bg-tertiary); border-left: 3px solid var(--accent-blue); border-radius: 0 var(--radius) var(--radius) 0; }

/* Stats bar */
.stats-bar { display: flex; gap: 12px; flex-wrap: wrap; align-items: center; margin-top: 10px; }
.stat-card { background: var(--bg-tertiary); border: 1px solid var(--border); border-radius: var(--radius); padding: 6px 14px; display: flex; align-items: center; gap: 8px; }
.stat-value { font-size: 1.2rem; font-weight: 700; font-family: var(--font-mono); }
.stat-label { font-size: 0.7rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; }
.stat-value.green { color: var(--accent-green); }
.stat-value.yellow { color: var(--accent-yellow); }
.stat-value.red { color: var(--accent-red); }
.stat-value.blue { color: var(--accent-blue); }
.stat-value.purple { color: var(--accent-purple); }
.stat-value.orange { color: var(--accent-orange); }
.stat-value.cyan { color: var(--accent-cyan); }

/* Controls */
.controls { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; padding: 10px 24px; background: var(--bg-secondary); border-bottom: 1px solid var(--border); }
.filter-group { display: flex; gap: 4px; }
.filter-btn { background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-secondary); padding: 4px 12px; border-radius: var(--radius); cursor: pointer; font-size: 0.78rem; font-family: var(--font-sans); transition: all 0.15s; }
.filter-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
.filter-btn.active { background: var(--accent-blue); color: #fff; border-color: var(--accent-blue); }
.search-box { background: var(--bg-tertiary); border: 1px solid var(--border); color: var(--text-primary); padding: 5px 12px; border-radius: var(--radius); font-size: 0.82rem; font-family: var(--font-sans); width: 260px; outline: none; transition: border-color 0.15s; }
.search-box:focus { border-color: var(--accent-blue); }
.search-box::placeholder { color: var(--text-muted); }

/* Tabs */
.tab-nav { display: flex; gap: 0; border-bottom: 1px solid var(--border); background: var(--bg-secondary); }
.tab-btn { background: none; border: none; border-bottom: 2px solid transparent; color: var(--text-secondary); padding: 10px 18px; cursor: pointer; font-size: 0.82rem; font-family: var(--font-sans); font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; transition: all 0.15s; }
.tab-btn:hover { color: var(--text-primary); }
.tab-btn.active { color: var(--accent-blue); border-bottom-color: var(--accent-blue); }
.tab-panel { display: none; padding: 16px 24px; }
.tab-panel.active { display: block; }

/* Section titles */
.section-title { font-size: 0.8rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 10px; font-weight: 600; }

/* Agent cards */
.agent-card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; transition: border-color 0.15s; margin-bottom: 6px; }
.agent-card:hover { border-color: var(--border-light); }
.agent-card-header { display: grid; grid-template-columns: 42px 1fr auto; gap: 12px; padding: 10px 14px; cursor: pointer; align-items: center; }
.agent-card-header:hover { background: var(--bg-tertiary); }
.agent-number { width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.8rem; font-family: var(--font-mono); flex-shrink: 0; }
.agent-number.role-s2 { background: #1f3a5f; color: var(--accent-blue); }
.agent-number.role-s3 { background: #1a3d2a; color: var(--accent-green); }
.agent-number.role-s1 { background: #3d1a3d; color: var(--accent-purple); }
.agent-number.role-verifier { background: #3d2e1a; color: var(--accent-orange); }
.agent-info { min-width: 0; }
.agent-title-row { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.agent-mission { font-weight: 600; font-size: 0.9rem; }
.agent-role-badge { font-size: 0.65rem; padding: 1px 8px; border-radius: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; flex-shrink: 0; }
.agent-role-badge.role-s2 { background: #1f3a5f; color: var(--accent-blue); }
.agent-role-badge.role-s3 { background: #1a3d2a; color: var(--accent-green); }
.agent-role-badge.role-s1 { background: #3d1a3d; color: var(--accent-purple); }
.agent-role-badge.role-verifier { background: #3d2e1a; color: var(--accent-orange); }
.status-badge { font-size: 0.65rem; padding: 2px 10px; border-radius: 10px; font-weight: 600; text-transform: uppercase; }
.status-badge.complete { background: #1a3d2a; color: var(--accent-green); }
.status-badge.completed { background: #1a3d2a; color: var(--accent-green); }
.status-badge.running { background: #1a2a3d; color: var(--accent-blue); }
.status-badge.blocked { background: #3d351a; color: var(--accent-yellow); }
.status-badge.partial { background: #3d2a1a; color: var(--accent-orange); }
.status-badge.inline { background: #2a1a3d; color: var(--accent-purple); }
.status-badge.failed { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.expand-icon { color: var(--text-muted); transition: transform 0.2s; font-size: 1rem; flex-shrink: 0; }
.agent-card.expanded .expand-icon { transform: rotate(90deg); }
.agent-detail { display: none; border-top: 1px solid var(--border); padding: 14px; background: var(--bg-primary); }
.agent-card.expanded .agent-detail { display: block; }
.detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
@media (max-width: 768px) { .detail-grid { grid-template-columns: 1fr; } }
.detail-section { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 10px; }
.detail-section-title { font-size: 0.7rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; font-weight: 600; }
.detail-section-content { font-size: 0.82rem; color: var(--text-secondary); line-height: 1.6; }
.duty-checklist { display: grid; grid-template-columns: 1fr 1fr; gap: 3px 10px; }
.duty-item { display: flex; align-items: center; gap: 5px; font-size: 0.78rem; }
.duty-check { width: 14px; height: 14px; border-radius: 3px; display: flex; align-items: center; justify-content: center; font-size: 0.65rem; font-weight: 700; flex-shrink: 0; }
.duty-check.pass { background: rgba(63,185,80,0.2); color: var(--accent-green); border: 1px solid rgba(63,185,80,0.4); }
.duty-check.fail { background: rgba(248,81,73,0.2); color: var(--accent-red); border: 1px solid rgba(248,81,73,0.4); }
.duty-label { color: var(--text-secondary); }
.finding-text { font-size: 0.82rem; color: var(--text-primary); line-height: 1.5; padding: 6px 10px; background: var(--bg-tertiary); border-left: 3px solid var(--accent-blue); border-radius: 0 var(--radius) var(--radius) 0; }

/* Governance cards */
.gov-card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 8px; overflow: hidden; transition: border-color 0.15s; }
.gov-card:hover { border-color: var(--border-light); }
.gov-card-header { padding: 10px 14px; cursor: pointer; display: flex; align-items: center; gap: 10px; }
.gov-card-header:hover { background: var(--bg-tertiary); }
.gov-card.expanded .gov-card-body { display: block; }
.gov-card-body { display: none; padding: 10px 14px; border-top: 1px solid var(--border); background: var(--bg-primary); font-size: 0.82rem; color: var(--text-secondary); line-height: 1.6; }
.gov-card .collapse-icon { color: var(--text-muted); transition: transform 0.2s; font-size: 0.75rem; }
.gov-card.expanded .collapse-icon { transform: rotate(90deg); }
.gov-id { font-family: var(--font-mono); color: var(--accent-cyan); font-size: 0.8rem; font-weight: 600; white-space: nowrap; min-width: 160px; }
.gov-title { font-weight: 600; font-size: 0.88rem; flex: 1; }
.gov-badges { display: flex; gap: 6px; }

/* Assumption/finding/thread styling */
.status-tag { font-size: 0.65rem; padding: 1px 7px; border-radius: 4px; font-weight: 600; font-family: var(--font-mono); white-space: nowrap; }
.status-tag.verified { background: rgba(63,185,80,0.2); color: var(--accent-green); border: 1px solid rgba(63,185,80,0.4); }
.status-tag.unverified { background: rgba(210,153,34,0.2); color: var(--accent-yellow); border: 1px solid rgba(210,153,34,0.3); }
.status-tag.falsified { background: rgba(248,81,73,0.2); color: var(--accent-red); border: 1px solid rgba(248,81,73,0.4); }
.status-tag.open { background: rgba(210,153,34,0.2); color: var(--accent-yellow); border: 1px solid rgba(210,153,34,0.3); }
.status-tag.resolved { background: rgba(63,185,80,0.2); color: var(--accent-green); border: 1px solid rgba(63,185,80,0.4); }
.status-tag.proposed { background: rgba(188,140,255,0.2); color: var(--accent-purple); border: 1px solid rgba(188,140,255,0.3); }
.status-tag.decided { background: rgba(63,185,80,0.2); color: var(--accent-green); border: 1px solid rgba(63,185,80,0.4); }
.status-tag.partial { background: rgba(240,136,62,0.2); color: var(--accent-orange); border: 1px solid rgba(240,136,62,0.3); }

.category-tag { font-size: 0.6rem; padding: 1px 6px; border-radius: 4px; font-weight: 600; text-transform: uppercase; }
.cat-environmental { background: rgba(88,166,255,0.15); color: var(--accent-blue); }
.cat-architectural { background: rgba(188,140,255,0.15); color: var(--accent-purple); }
.cat-behavioral { background: rgba(240,136,62,0.15); color: var(--accent-orange); }
.cat-temporal { background: rgba(210,153,34,0.15); color: var(--accent-yellow); }

/* Finding type tags */
.type-tag { font-size: 0.6rem; padding: 1px 6px; border-radius: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; }
.type-spec-deviation { background: rgba(248,81,73,0.15); color: var(--accent-red); }
.type-observation { background: rgba(88,166,255,0.15); color: var(--accent-blue); }
.type-terminology-gap { background: rgba(188,140,255,0.15); color: var(--accent-purple); }
.type-inconsistency { background: rgba(210,153,34,0.15); color: var(--accent-yellow); }
.type-design-gap { background: rgba(240,136,62,0.15); color: var(--accent-orange); }
.type-governance-gap { background: rgba(240,136,62,0.15); color: var(--accent-orange); }
.type-operational-incident { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.type-false-claim { background: rgba(248,81,73,0.15); color: var(--accent-red); }
.type-empirical-finding { background: rgba(63,185,80,0.15); color: var(--accent-green); }
.type-process-learning { background: rgba(86,212,221,0.15); color: var(--accent-cyan); }

/* State section */
.state-block { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px; margin-bottom: 10px; }
.state-block-title { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; font-weight: 600; }
.state-block-content { font-size: 0.82rem; color: var(--text-secondary); line-height: 1.6; }
.state-item { padding: 3px 0; border-bottom: 1px solid rgba(48,54,61,0.4); }
.state-item:last-child { border-bottom: none; }
.deviation-item { display: flex; gap: 6px; padding: 4px 0; border-bottom: 1px solid rgba(48,54,61,0.4); font-size: 0.82rem; color: var(--accent-orange); }
.deviation-item:last-child { border-bottom: none; }
.deviation-bullet { color: var(--accent-red); flex-shrink: 0; }

/* Thread cards */
.thread-card { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 10px 14px; margin-bottom: 6px; }
.thread-title { font-weight: 600; font-size: 0.88rem; color: var(--text-primary); }
.thread-desc { font-size: 0.8rem; color: var(--text-secondary); margin-top: 4px; }

/* Conclusion section */
.conclusion-box { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px; margin-bottom: 10px; }
.recommendation-item { padding: 8px 0; border-bottom: 1px solid rgba(48,54,61,0.4); }
.recommendation-item:last-child { border-bottom: none; }
.rec-text { font-weight: 600; font-size: 0.88rem; color: var(--text-primary); }
.rec-rationale { font-size: 0.8rem; color: var(--text-secondary); margin-top: 2px; }
.rec-urgency { font-size: 0.6rem; padding: 1px 6px; border-radius: 4px; font-weight: 600; text-transform: uppercase; }
.urgency-immediate { background: rgba(248,81,73,0.2); color: var(--accent-red); }
.urgency-next-session { background: rgba(210,153,34,0.2); color: var(--accent-yellow); }

.risk-item { padding: 8px 0; border-bottom: 1px solid rgba(48,54,61,0.4); }
.risk-item:last-child { border-bottom: none; }
.risk-type { font-size: 0.65rem; padding: 1px 6px; border-radius: 4px; font-weight: 600; text-transform: uppercase; }
.risk-type.risk { background: rgba(248,81,73,0.15); color: var(--accent-red); }
.risk-type.opportunity { background: rgba(63,185,80,0.15); color: var(--accent-green); }

/* Footer */
.footer { padding: 12px 24px; border-top: 1px solid var(--border); color: var(--text-muted); font-size: 0.75rem; text-align: center; background: var(--bg-secondary); }
.footer a { color: var(--accent-blue); text-decoration: none; }

/* No results */
.no-results { text-align: center; padding: 30px; color: var(--text-muted); font-size: 0.9rem; }
.hidden { display: none !important; }

/* Scrollbars */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: var(--bg-primary); }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: var(--border-light); }

/* Responsive */
@media (max-width: 900px) { .stats-bar { gap: 8px; } .stat-card { padding: 4px 10px; } }
</style>
</head>
<body>

<div id="app"></div>

<script>
// Data injected by generate-dashboard.py at build time.
var DASHBOARD_DATA = /*__ESTIMATE_DATA__*/null;
const GENERATED_AT = "/*__GENERATED_AT__*/";
const LIVE_MODE = /*__LIVE_MODE__*/false;
const POLL_URL = "/*__POLL_URL__*/";
const POLL_INTERVAL = /*__POLL_INTERVAL__*/3;

function renderDashboard(D, generatedAt) {
  if (!D) { document.getElementById('app').innerHTML = '<div class="no-results">No data. Generate with: python3 scripts/generate-dashboard.py --estimate &lt;path&gt;</div>'; return; }

  const app = document.getElementById('app');
  const meta = D.meta || {};
  const situation = D.situation || {};
  const schwerpunkt = D.schwerpunkt || '';
  const findings = D.findings || [];
  const openThreads = D.openThreads || [];
  const delegationLog = D.delegationLog || [];
  const conclusions = D.conclusions || {};
  const decisions = (situation.decisions || []);
  const assumptions = (situation.assumptions || []);
  const m12 = D.m12AssumptionVerification || {};
  const deviations = situation.deviations || [];
  const facts = situation.facts || [];
  const completedWork = situation.completedWork || [];

  // Combine assumptions from both sources
  const allAssumptions = [];
  assumptions.forEach(a => allAssumptions.push(a));
  const ua = (m12.unflaggedAssumptions || []);
  ua.forEach(a => { if (!allAssumptions.find(x => x.id === a.id)) allAssumptions.push(a); });
  const amb = (m12.unflaggedAmbiguities || []);

  // Stats
  const totalDelegations = delegationLog.length;
  const completeDelegations = delegationLog.filter(d => (d.status||'').toLowerCase().includes('complete')).length;
  const s2Count = delegationLog.filter(d => (d.type||'') === 's2').length;
  const s3Count = delegationLog.filter(d => (d.type||'') === 's3').length;
  const findingsCount = findings.length;
  const threadsCount = openThreads.length;
  const decisionsCount = decisions.length;
  const deviationsCount = deviations.length;
  const assumptionVerified = allAssumptions.filter(a => (a.status||a.classification||'').toLowerCase().includes('verified') && !(a.status||a.classification||'').toLowerCase().includes('unverif')).length;
  const assumptionTotal = allAssumptions.length;
  const factsCount = facts.length;

  // Determine session info
  const sessionId = meta.sessionId || meta.estimateId || 'unknown';
  const created = meta.created || '';
  const version = meta.version || '?';

  function esc(s) { if (!s) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

  function statusClass(s) {
    if (!s) return '';
    const sl = s.toLowerCase();
    if (sl.includes('verified') && !sl.includes('unverif') && !sl.includes('partial')) return 'verified';
    if (sl.includes('partial')) return 'partial';
    if (sl.includes('falsif') || sl.includes('incorrect')) return 'falsified';
    if (sl.includes('resolved') || sl.includes('done') || sl.includes('executed')) return 'resolved';
    if (sl.includes('decided')) return 'decided';
    if (sl.includes('proposed') || sl.includes('proposal')) return 'proposed';
    if (sl.includes('open') || sl.includes('ready') || sl.includes('unverif') || sl.includes('untestable')) return 'unverified';
    return 'open';
  }

  function typeClass(t) {
    if (!t) return '';
    return 'type-' + t.replace(/[\s_]+/g, '-').toLowerCase();
  }

  function categoryClass(c) {
    if (!c) return '';
    return 'cat-' + c.toLowerCase();
  }

  function roleClass(type) {
    if (!type) return 'role-s2';
    const t = type.toLowerCase();
    if (t === 's1') return 'role-s1';
    if (t === 's2') return 'role-s2';
    if (t === 's3') return 'role-s3';
    if (t.includes('verif')) return 'role-verifier';
    return 'role-s2';
  }

  // ----- Build HTML -----
  let html = '';

  // HEADER
  html += '<div class="header"><div class="header-top"><div>';
  html += '<div class="header-title">Mission Control Dashboard <span>v' + esc(String(version)) + '</span></div>';
  html += '<div class="session-id">' + esc(sessionId) + (created ? ' &middot; ' + esc(created.substring(0,10)) : '') + '</div>';
  html += '</div><div style="font-size:0.75rem;color:var(--text-muted)">' + (LIVE_MODE ? '<span id="liveIndicator" style="color:var(--accent-green);font-weight:700;margin-right:6px">&#9679; LIVE</span>' : '') + 'Generated: ' + esc(generatedAt) + '</div></div>';
  if (schwerpunkt) {
    html += '<div class="schwerpunkt">' + esc(schwerpunkt) + '</div>';
  }
  html += '<div class="stats-bar">';
  html += '<div class="stat-card"><div class="stat-value blue">' + totalDelegations + '</div><div class="stat-label">Delegations</div></div>';
  html += '<div class="stat-card"><div class="stat-value green">' + completeDelegations + '/' + totalDelegations + '</div><div class="stat-label">Complete</div></div>';
  html += '<div class="stat-card"><div class="stat-value blue">' + s2Count + '</div><div class="stat-label">S2</div></div>';
  html += '<div class="stat-card"><div class="stat-value green">' + s3Count + '</div><div class="stat-label">S3</div></div>';
  html += '<div class="stat-card"><div class="stat-value purple">' + decisionsCount + '</div><div class="stat-label">Decisions</div></div>';
  html += '<div class="stat-card"><div class="stat-value cyan">' + findingsCount + '</div><div class="stat-label">Findings</div></div>';
  html += '<div class="stat-card"><div class="stat-value yellow">' + threadsCount + '</div><div class="stat-label">Open Threads</div></div>';
  html += '<div class="stat-card"><div class="stat-value orange">' + deviationsCount + '</div><div class="stat-label">Deviations</div></div>';
  html += '<div class="stat-card"><div class="stat-value green">' + assumptionVerified + '/' + assumptionTotal + '</div><div class="stat-label">Assumptions Verified</div></div>';
  html += '</div></div>';

  // TAB NAV
  html += '<div class="tab-nav" id="mainTabs">';
  html += '<button class="tab-btn active" data-tab="agents">Agents (' + totalDelegations + ')</button>';
  html += '<button class="tab-btn" data-tab="governance">Governance (' + decisionsCount + 'D / ' + assumptionTotal + 'A)</button>';
  html += '<button class="tab-btn" data-tab="findings">Findings (' + findingsCount + ')</button>';
  html += '<button class="tab-btn" data-tab="state">Session State</button>';
  html += '<button class="tab-btn" data-tab="threads">Open Threads (' + threadsCount + ')</button>';
  if (conclusions.assessment) html += '<button class="tab-btn" data-tab="conclusions">Conclusions</button>';
  html += '</div>';

  // ===== AGENTS TAB =====
  html += '<div class="tab-panel active" id="tab-agents">';
  html += '<div class="controls"><div class="filter-group" id="roleFilters">';
  html += '<button class="filter-btn active" data-role="all">All</button>';
  html += '<button class="filter-btn" data-role="s2">S2</button>';
  html += '<button class="filter-btn" data-role="s3">S3</button>';
  html += '</div>';
  html += '<input type="text" class="search-box" id="agentSearch" placeholder="Search agents... (/ to focus)" />';
  html += '<div class="filter-group"><button class="filter-btn" id="expandAllBtn">Expand All</button><button class="filter-btn" id="collapseAllBtn">Collapse All</button></div>';
  html += '</div>';
  html += '<div style="padding:12px 24px" id="agentsList">';

  delegationLog.forEach(function(agent, idx) {
    const rc = roleClass(agent.type);
    const duty = agent.dutyFulfilled || {};
    const dutyKeys = Object.keys(duty);
    const dutyPass = dutyKeys.filter(k => duty[k] === true).length;
    const statusLbl = esc(agent.status || 'unknown');
    const sc = statusClass(agent.status);

    html += '<div class="agent-card" data-role="' + esc(agent.type) + '" data-search="' + esc(JSON.stringify(agent).toLowerCase()) + '">';
    html += '<div class="agent-card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
    html += '<div class="agent-number ' + rc + '">' + esc(agent.id) + '</div>';
    html += '<div class="agent-info"><div class="agent-title-row">';
    html += '<span class="agent-mission">' + esc(agent.mission) + '</span>';
    html += '<span class="agent-role-badge ' + rc + '">' + esc(agent.type || '').toUpperCase() + '</span>';
    if (agent.agentType) html += '<span style="font-size:0.65rem;color:var(--text-muted);font-family:var(--font-mono)">' + esc(agent.agentType) + '</span>';
    html += '</div></div>';
    html += '<div style="display:flex;align-items:center;gap:8px"><span class="status-badge ' + sc + '">' + statusLbl + '</span><span class="expand-icon">&#9654;</span></div>';
    html += '</div>';

    // Detail
    html += '<div class="agent-detail"><div class="detail-grid">';
    if (dutyKeys.length > 0) {
      html += '<div class="detail-section"><div class="detail-section-title">Delegation Duty (' + dutyPass + '/' + dutyKeys.length + ')</div><div class="duty-checklist">';
      dutyKeys.forEach(function(k) {
        const v = duty[k];
        const cls = v === true ? 'pass' : 'fail';
        const icon = v === true ? '&#10003;' : (typeof v === 'string' ? '&#8212;' : '&#10007;');
        html += '<div class="duty-item"><div class="duty-check ' + cls + '">' + icon + '</div><span class="duty-label">' + esc(k) + '</span></div>';
      });
      html += '</div></div>';
    }
    if (agent.deviation) {
      html += '<div class="detail-section"><div class="detail-section-title">Deviation</div><div class="detail-section-content" style="color:var(--accent-orange)">' + esc(agent.deviation) + '</div></div>';
    }
    html += '</div></div></div>';
  });

  html += '</div>';
  html += '<div class="no-results hidden" id="agentNoResults">No agents match filters.</div>';
  html += '</div>';

  // ===== GOVERNANCE TAB =====
  html += '<div class="tab-panel" id="tab-governance">';

  // Decisions sub-section
  html += '<div class="section-title" style="padding:0 0 8px">Decisions (' + decisionsCount + ')</div>';
  decisions.forEach(function(d) {
    const sc = statusClass(d.status);
    html += '<div class="gov-card" data-search="' + esc(JSON.stringify(d).toLowerCase()) + '">';
    html += '<div class="gov-card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
    html += '<span class="collapse-icon">&#9654;</span>';
    html += '<span class="gov-id">' + esc(d.id) + '</span>';
    html += '<span class="gov-title">' + esc(d.decision) + '</span>';
    html += '<div class="gov-badges"><span class="status-tag ' + sc + '">' + esc(d.status) + '</span></div>';
    html += '</div>';
    html += '<div class="gov-card-body">';
    if (d.decidedBy) html += '<div><strong>Decided by:</strong> ' + esc(d.decidedBy) + '</div>';
    if (d.executedBy) html += '<div><strong>Executed by:</strong> ' + esc(d.executedBy) + '</div>';
    if (d.verificationEvidence) html += '<div style="margin-top:6px"><strong>Verification:</strong> ' + esc(d.verificationEvidence) + '</div>';
    if (d.relatedBriefDecisions && d.relatedBriefDecisions.length) {
      html += '<div style="margin-top:6px"><strong>Brief decisions:</strong> ' + d.relatedBriefDecisions.map(function(n) { return '#' + n; }).join(', ') + '</div>';
    }
    html += '</div></div>';
  });

  // Assumptions sub-section
  html += '<div class="section-title" style="padding:16px 0 8px">Assumptions (' + assumptionTotal + ')</div>';
  allAssumptions.forEach(function(a) {
    const st = a.status || a.classification || 'unknown';
    const sc = statusClass(st);
    const cat = a.taxonomy || '';
    html += '<div class="gov-card" data-search="' + esc(JSON.stringify(a).toLowerCase()) + '">';
    html += '<div class="gov-card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
    html += '<span class="collapse-icon">&#9654;</span>';
    html += '<span class="gov-id">' + esc(a.id) + '</span>';
    html += '<span class="gov-title">' + esc(a.assumption) + '</span>';
    html += '<div class="gov-badges"><span class="status-tag ' + sc + '">' + esc(st) + '</span>';
    if (cat) html += '<span class="category-tag ' + categoryClass(cat) + '">' + esc(cat) + '</span>';
    html += '</div></div>';
    html += '<div class="gov-card-body">';
    if (a.evidence) html += '<div><strong>Evidence:</strong> ' + esc(a.evidence) + '</div>';
    if (a.rationale) html += '<div><strong>Rationale:</strong> ' + esc(a.rationale) + '</div>';
    if (a.verifiedBy) html += '<div><strong>Verified by:</strong> ' + esc(a.verifiedBy) + '</div>';
    if (a.m22Result) html += '<div style="margin-top:4px"><strong>M22 result:</strong> ' + esc(a.m22Result) + '</div>';
    if (a.severity) html += '<div><strong>Severity:</strong> ' + esc(a.severity) + '</div>';
    html += '</div></div>';
  });

  // Ambiguities sub-section (if any)
  if (amb.length > 0) {
    html += '<div class="section-title" style="padding:16px 0 8px">Ambiguities (' + amb.length + ')</div>';
    amb.forEach(function(a) {
      const st = a.classification || 'unresolved';
      const sc = statusClass(st);
      html += '<div class="gov-card" data-search="' + esc(JSON.stringify(a).toLowerCase()) + '">';
      html += '<div class="gov-card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
      html += '<span class="collapse-icon">&#9654;</span>';
      html += '<span class="gov-id">' + esc(a.id) + '</span>';
      html += '<span class="gov-title">' + esc(a.ambiguity) + '</span>';
      html += '<div class="gov-badges"><span class="status-tag ' + sc + '">' + esc(st) + '</span></div>';
      html += '</div>';
      html += '<div class="gov-card-body">';
      if (a.rationale) html += '<div>' + esc(a.rationale) + '</div>';
      if (a.severity) html += '<div><strong>Severity:</strong> ' + esc(a.severity) + '</div>';
      html += '</div></div>';
    });
  }
  html += '</div>';

  // ===== FINDINGS TAB =====
  html += '<div class="tab-panel" id="tab-findings">';
  html += '<div style="padding:0 0 12px"><div class="section-title">Findings (' + findingsCount + ')</div></div>';
  findings.forEach(function(f) {
    const fsc = statusClass(f.status);
    const ftc = typeClass(f.type);
    html += '<div class="gov-card" data-search="' + esc(JSON.stringify(f).toLowerCase()) + '">';
    html += '<div class="gov-card-header" onclick="this.parentElement.classList.toggle(\'expanded\')">';
    html += '<span class="collapse-icon">&#9654;</span>';
    html += '<span class="gov-id">' + esc(f.id) + '</span>';
    html += '<span class="gov-title">' + esc(f.summary) + '</span>';
    html += '<div class="gov-badges">';
    if (f.type) html += '<span class="type-tag ' + ftc + '">' + esc(f.type) + '</span>';
    html += '<span class="status-tag ' + fsc + '">' + esc(f.status) + '</span>';
    html += '</div></div>';
    html += '<div class="gov-card-body">';
    if (f.action) html += '<div><strong>Action:</strong> ' + esc(f.action) + '</div>';
    html += '</div></div>';
  });
  html += '</div>';

  // ===== STATE TAB =====
  html += '<div class="tab-panel" id="tab-state">';

  // Current state
  if (situation.currentState) {
    html += '<div class="state-block"><div class="state-block-title">Current State</div>';
    html += '<div class="state-block-content">' + esc(situation.currentState) + '</div></div>';
  }

  // Deviations
  if (deviations.length > 0) {
    html += '<div class="state-block"><div class="state-block-title">Deviations (' + deviations.length + ')</div>';
    deviations.forEach(function(d) {
      html += '<div class="deviation-item"><span class="deviation-bullet">&#9679;</span><div>';
      html += '<div>' + esc(d.description) + '</div>';
      if (d.impact) html += '<div style="font-size:0.78rem;color:var(--text-muted);margin-top:2px">Impact: ' + esc(d.impact) + '</div>';
      html += '</div></div>';
    });
    html += '</div>';
  }

  // Facts
  if (facts.length > 0) {
    html += '<div class="state-block"><div class="state-block-title">Verified Facts (' + facts.length + ')</div>';
    html += '<div class="state-block-content">';
    facts.forEach(function(f) {
      const text = typeof f === 'string' ? f : (f.fact || f.description || JSON.stringify(f));
      html += '<div class="state-item">' + esc(text) + '</div>';
    });
    html += '</div></div>';
  }

  // Completed work (last 20)
  if (completedWork.length > 0) {
    const showCount = Math.min(completedWork.length, 20);
    html += '<div class="state-block"><div class="state-block-title">Completed Work (last ' + showCount + ' of ' + completedWork.length + ')</div>';
    html += '<div class="state-block-content">';
    completedWork.slice(-showCount).reverse().forEach(function(w) {
      const text = typeof w === 'string' ? w : (w.description || JSON.stringify(w));
      html += '<div class="state-item">' + esc(text) + '</div>';
    });
    html += '</div></div>';
  }
  html += '</div>';

  // ===== OPEN THREADS TAB =====
  html += '<div class="tab-panel" id="tab-threads">';
  html += '<div class="section-title">Open Threads (' + threadsCount + ')</div>';
  openThreads.forEach(function(t) {
    const tsc = statusClass(t.status);
    html += '<div class="thread-card">';
    html += '<div style="display:flex;align-items:center;gap:8px"><span class="thread-title">' + esc(t.thread) + '</span>';
    html += '<span class="status-tag ' + tsc + '">' + esc(t.status) + '</span></div>';
    if (t.description) html += '<div class="thread-desc">' + esc(t.description) + '</div>';
    html += '</div>';
  });
  html += '</div>';

  // ===== CONCLUSIONS TAB =====
  if (conclusions.assessment) {
    html += '<div class="tab-panel" id="tab-conclusions">';
    html += '<div class="conclusion-box"><div class="state-block-title">Assessment</div>';
    html += '<div class="state-block-content">' + esc(conclusions.assessment) + '</div></div>';

    if (conclusions.recommendations && conclusions.recommendations.length > 0) {
      html += '<div class="conclusion-box"><div class="state-block-title">Recommendations</div>';
      conclusions.recommendations.forEach(function(r) {
        const ucls = (r.urgency||'').includes('immediate') ? 'urgency-immediate' : 'urgency-next-session';
        html += '<div class="recommendation-item">';
        html += '<div style="display:flex;align-items:center;gap:8px"><span class="rec-text">' + esc(r.recommendation) + '</span>';
        if (r.urgency) html += '<span class="rec-urgency ' + ucls + '">' + esc(r.urgency) + '</span>';
        html += '</div>';
        if (r.rationale) html += '<div class="rec-rationale">' + esc(r.rationale) + '</div>';
        html += '</div>';
      });
      html += '</div>';
    }

    if (conclusions.risksAndOpportunities && conclusions.risksAndOpportunities.length > 0) {
      html += '<div class="conclusion-box"><div class="state-block-title">Risks &amp; Opportunities</div>';
      conclusions.risksAndOpportunities.forEach(function(r) {
        html += '<div class="risk-item">';
        html += '<div style="display:flex;align-items:center;gap:8px"><span class="risk-type ' + esc(r.type) + '">' + esc(r.type) + '</span>';
        html += '<span style="font-size:0.85rem">' + esc(r.description) + '</span></div>';
        if (r.mitigation) html += '<div style="font-size:0.8rem;color:var(--text-secondary);margin-top:3px"><strong>Mitigation:</strong> ' + esc(r.mitigation) + '</div>';
        html += '</div>';
      });
      html += '</div>';
    }
    html += '</div>';
  }

  // FOOTER
  html += '<div class="footer">Generated by <a href="https://github.com/nobul-jose/aitools">aitools</a> generate-dashboard.py from running estimate v' + esc(String(version)) + ' &middot; ' + esc(generatedAt) + (LIVE_MODE ? ' &middot; polling every ' + POLL_INTERVAL + 's' : '') + '</div>';

  app.innerHTML = html;

  // ===== Interactivity =====

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

  // Agent filtering
  var activeRole = 'all';
  var agentSearchTerm = '';
  var searchBox = document.getElementById('agentSearch');
  var roleFilters = document.getElementById('roleFilters');
  var agentsList = document.getElementById('agentsList');
  var noResults = document.getElementById('agentNoResults');

  function filterAgents() {
    if (!agentsList) return;
    var cards = agentsList.querySelectorAll('.agent-card');
    var visible = 0;
    cards.forEach(function(card) {
      var role = card.getAttribute('data-role') || '';
      var search = card.getAttribute('data-search') || '';
      var matchRole = activeRole === 'all' || role === activeRole;
      var matchSearch = !agentSearchTerm || search.includes(agentSearchTerm.toLowerCase());
      if (matchRole && matchSearch) { card.classList.remove('hidden'); visible++; }
      else { card.classList.add('hidden'); }
    });
    if (noResults) noResults.classList.toggle('hidden', visible > 0);
  }

  if (roleFilters) {
    roleFilters.querySelectorAll('.filter-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        roleFilters.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
        activeRole = btn.dataset.role;
        filterAgents();
      });
    });
  }

  if (searchBox) {
    searchBox.addEventListener('input', function() { agentSearchTerm = searchBox.value; filterAgents(); });
  }

  // Keyboard shortcuts
  document.addEventListener('keydown', function(e) {
    if (e.key === '/' && document.activeElement !== searchBox) { e.preventDefault(); if (searchBox) searchBox.focus(); }
    if (e.key === 'Escape' && searchBox) { searchBox.value = ''; agentSearchTerm = ''; searchBox.blur(); filterAgents(); }
  });

  // Expand/collapse all agents
  var expandBtn = document.getElementById('expandAllBtn');
  var collapseBtn = document.getElementById('collapseAllBtn');
  if (expandBtn) expandBtn.addEventListener('click', function() { agentsList.querySelectorAll('.agent-card').forEach(function(c) { c.classList.add('expanded'); }); });
  if (collapseBtn) collapseBtn.addEventListener('click', function() { agentsList.querySelectorAll('.agent-card').forEach(function(c) { c.classList.remove('expanded'); }); });
}

// Initial render
renderDashboard(DASHBOARD_DATA, GENERATED_AT);

// Live polling: fetch new data and re-render without page reload
if (LIVE_MODE && POLL_URL) {
  var lastDataHash = JSON.stringify(DASHBOARD_DATA);
  setInterval(function() {
    fetch(POLL_URL, { cache: 'no-store' })
      .then(function(r) { return r.json(); })
      .then(function(newData) {
        var newHash = JSON.stringify(newData);
        if (newHash !== lastDataHash) {
          lastDataHash = newHash;
          DASHBOARD_DATA = newData;
          var now = new Date().toISOString().replace(/\.\d{3}/, '').replace('T', 'T');
          renderDashboard(newData, now);
          var indicator = document.getElementById('liveIndicator');
          if (indicator) {
            indicator.style.color = 'var(--accent-cyan)';
            setTimeout(function() { indicator.style.color = 'var(--accent-green)'; }, 500);
          }
        }
      })
      .catch(function() {
        var indicator = document.getElementById('liveIndicator');
        if (indicator) { indicator.innerHTML = '&#9679; OFFLINE'; indicator.style.color = 'var(--accent-red)'; }
      });
  }, POLL_INTERVAL * 1000);
}
</script>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a self-contained HTML Mission Control Dashboard from a running estimate JSON.",
        epilog="Examples:\n"
        "  # Static (embedded data, works from file:///)\n"
        "  python3 scripts/generate-dashboard.py --estimate .scratch/session-XYZ/running-estimate.json\n"
        "  python3 scripts/generate-dashboard.py --estimate est.json --output /tmp/dashboard.html --open\n"
        "\n"
        "  # Live (HTTP server, auto-updates on file change)\n"
        "  python3 scripts/generate-dashboard.py --estimate est.json --serve\n"
        "  python3 scripts/generate-dashboard.py --estimate est.json --serve --port 9000\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--estimate",
        required=True,
        type=Path,
        help="Path to the running estimate JSON file (required)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output HTML path (default: same directory as estimate, named per D-DASHBOARD-GOVERNANCE)",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Open the generated dashboard in the default browser",
    )
    parser.add_argument(
        "--serve",
        action="store_true",
        help="Start a live dashboard server (auto-updates when estimate file changes)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8411,
        help="Port for the live server (default: 8411)",
    )
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Watch estimate file and regenerate HTML on change (static mode only; --serve implies --watch)",
    )
    parser.add_argument(
        "--poll-interval",
        type=int,
        default=3,
        dest="poll_interval",
        help="Seconds between live polls in the browser (default: 3)",
    )
    args = parser.parse_args()

    estimate_path = args.estimate.resolve()

    # Live server mode
    if args.serve:
        run_server(
            estimate_path,
            port=args.port,
            open_browser=args.open,
            poll_interval=args.poll_interval,
        )
        return  # run_server blocks until Ctrl+C

    # Static generation mode
    estimate = load_estimate(estimate_path)

    # Derive output path
    session_id = get_nested(estimate, "meta", "sessionId")
    if args.output:
        output_path = args.output.resolve()
    else:
        output_path = derive_output_path(estimate_path, session_id)

    # Generate
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    html = build_html(estimate, generated_at)

    # Write
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html, encoding="utf-8")
    print(f"Dashboard written to: {output_path}")
    print(f"Estimate version: {get_nested(estimate, 'meta', 'version', default='?')}")
    print(f"Session: {session_id or 'unknown'}")
    print(f"Delegations: {len(get_nested(estimate, 'delegationLog', default=[]))}")
    print(f"Decisions: {len(get_nested(estimate, 'situation', 'decisions', default=[]))}")
    print(f"Findings: {len(get_nested(estimate, 'findings', default=[]))}")

    if args.open:
        url = output_path.as_uri()
        print(f"Opening: {url}")
        webbrowser.open(url)

    # Watch mode (static): regenerate on file change
    if args.watch:
        print(f"Watching: {estimate_path}")
        print("Press Ctrl+C to stop.")
        last_mtime = estimate_path.stat().st_mtime
        try:
            while True:
                time.sleep(1)
                try:
                    current_mtime = estimate_path.stat().st_mtime
                except OSError:
                    continue
                if current_mtime != last_mtime:
                    last_mtime = current_mtime
                    try:
                        estimate = load_estimate(estimate_path)
                        generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                        html = build_html(estimate, generated_at)
                        output_path.write_text(html, encoding="utf-8")
                        version = get_nested(estimate, "meta", "version", default="?")
                        print(f"[{generated_at}] Regenerated: v{version}")
                    except Exception as e:
                        print(f"[watch] Error: {e}", file=sys.stderr)
        except KeyboardInterrupt:
            print("\nStopped watching.")


if __name__ == "__main__":
    main()
