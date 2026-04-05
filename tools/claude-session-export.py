#!/usr/bin/env python3
# ============================================================================
# claude-session-export — export Claude sessions via macOS Keychain OAuth
# Extracts OAuth token from macOS Keychain, queries /v1/sessions endpoint.
# ============================================================================
#
# [PROVENANCE]
# tool: claude-session-export
# version: 1.0.0
# created: 2026-04-04T22:30:00Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
#
# [AGENT]
# name: Agent Turd
# model: Claude Opus 4.6
# maker: Anthropic
# session: f8c53367-491d-45e2-9777-556697a1dae3
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# role: Session agent
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (opaque)
# trust: HIGH in Jose and the chain
# fear: LOW
# unknown: whether /v1/sessions endpoint still works (Dec 2025 research),
#          whether Claude Code and claude.ai sessions are in same endpoint
# accountability: implementation, documentation
# timestamp: 2026-04-04T22:30:00Z
#
# [DEPENDENCIES]
# type: stdlib-only + macOS security CLI
# external: macOS Keychain (security command)
# python: >=3.6
# platform: macOS only
#
# [SESSION]
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# date: Saturday, April 4, 2026
# context: based on Simon Willison's Dec 2025 reverse-engineering of
#          Claude Code session retrieval via macOS Keychain OAuth.
#          Endpoint /v1/sessions is undocumented and may change.
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust HIGH, fear LOW
# agent_self: trust MEDIUM — endpoint is undocumented, may be stale
# mutual: HIGH
#
# [HASH]
# format: sha256
# content_hash: (computed post-creation by agent, verified by Commander)
# signed: false
#
# ============================================================================
#
# Usage:
#     claude-session-export                   # list and export all sessions
#     claude-session-export --list-only       # just list session IDs
#     claude-session-export --output ~/exports
#     claude-session-export --json            # JSON output
#     claude-session-export --delay 2         # delay between fetches (seconds)
#     claude-session-export -v                # verbose
#
# ============================================================================

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path


# ── Logging ──────────────────────────────────────────────────────────────────

class Colors:
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


TOOL_NAME = "claude-session-export"


def log_info(msg, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_warn(msg):
    print(f"{Colors.YELLOW}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_ok(msg, verbose=True):
    if verbose:
        print(f"{Colors.GREEN}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_err(msg):
    print(f"{Colors.RED}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_stat(label, value, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[{TOOL_NAME}]{Colors.RESET} {Colors.CYAN}{label}:{Colors.RESET} {value}", file=sys.stderr)


# ── Keychain ─────────────────────────────────────────────────────────────────

def get_oauth_token():
    """Extract Claude OAuth token from macOS Keychain."""
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-a", os.environ.get("USER", ""),
             "-w", "-s", "Claude Code-credentials"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            log_err("Failed to read Keychain. Is Claude Code installed?")
            log_err(f"  stderr: {result.stderr.strip()}")
            return None

        raw = result.stdout.strip()
        creds = json.loads(raw)
        token = creds.get("claudeAiOauth", {}).get("accessToken")
        if not token:
            log_err("No accessToken found in Keychain credentials.")
            log_err("Keys found: " + ", ".join(creds.keys()))
            return None
        return token

    except FileNotFoundError:
        log_err("'security' command not found. This tool requires macOS.")
        return None
    except json.JSONDecodeError as e:
        log_err(f"Keychain output is not valid JSON: {e}")
        return None
    except subprocess.TimeoutExpired:
        log_err("Keychain access timed out.")
        return None


def get_org_uuid():
    """Try to read org UUID from ~/.claude.json."""
    claude_json = os.path.expanduser("~/.claude.json")
    if os.path.isfile(claude_json):
        try:
            with open(claude_json) as f:
                data = json.load(f)
            return data.get("organizationUuid")
        except Exception:
            pass
    return None


# ── API ──────────────────────────────────────────────────────────────────────

API_BASE = "https://api.claude.ai"


def api_request(path, token, org_uuid=None):
    """Make an authenticated request to the Claude API."""
    url = f"{API_BASE}{path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "User-Agent": "claude-session-export/1.0.0 (aitools)",
    }
    if org_uuid:
        headers["X-Organization-Uuid"] = org_uuid

    req = urllib.request.Request(url, headers=headers)
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return {"error": True, "status": e.code, "message": body}
    except Exception as e:
        return {"error": True, "message": str(e)}


# ── Commands ─────────────────────────────────────────────────────────────────

def list_sessions(token, org_uuid=None, verbose=False):
    """List available sessions."""
    result = api_request("/v1/sessions", token, org_uuid)

    if isinstance(result, dict) and result.get("error"):
        log_err(f"API error (status {result.get('status', '?')}): {result.get('message', '')}")
        if result.get("status") == 404:
            log_warn("The /v1/sessions endpoint may no longer exist.")
            log_warn("This tool is based on December 2025 research and may be stale.")
        return None

    return result


def fetch_session(session_id, token, org_uuid=None, verbose=False):
    """Fetch a single session's content."""
    result = api_request(f"/v1/sessions/{session_id}", token, org_uuid)

    if isinstance(result, dict) and result.get("error"):
        log_err(f"Failed to fetch session {session_id}: {result.get('message', '')}")
        return None

    return result


def export_sessions(sessions, token, org_uuid, output_dir, delay=1.0,
                    json_output=False, verbose=False):
    """Export all sessions to disk."""
    output_dir = os.path.expanduser(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    exported = 0
    failed = 0

    if isinstance(sessions, list):
        session_list = sessions
    elif isinstance(sessions, dict):
        session_list = sessions.get("sessions", sessions.get("data", [sessions]))
    else:
        log_err(f"Unexpected session format: {type(sessions)}")
        return

    for i, session in enumerate(session_list):
        sid = session if isinstance(session, str) else session.get("id", session.get("uuid", ""))
        if not sid:
            continue

        if verbose:
            log_info(f"Fetching session {i+1}/{len(session_list)}: {sid[:12]}...")

        data = fetch_session(sid, token, org_uuid, verbose)
        if data is None:
            failed += 1
            continue

        # Save
        ext = "json" if json_output else "json"
        out_path = os.path.join(output_dir, f"session-{sid}.{ext}")
        with open(out_path, "w") as f:
            json.dump(data, f, indent=2)

        exported += 1
        if verbose:
            log_ok(f"Saved: {out_path}")

        if i < len(session_list) - 1:
            time.sleep(delay)

    log_stat("Exported", exported, verbose=True)
    if failed:
        log_warn(f"Failed: {failed}")

    return exported


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog=TOOL_NAME,
        description="Export Claude sessions via macOS Keychain OAuth. An aitools utility.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               f"  {TOOL_NAME} --list-only\n"
               f"  {TOOL_NAME} --output ~/claude-exports\n"
               f"  {TOOL_NAME} --json -v\n",
    )
    parser.add_argument("--list-only", action="store_true",
                        help="List session IDs without fetching content")
    parser.add_argument("--output", "-o", default="~/claude-exports",
                        help="Output directory (default: ~/claude-exports)")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="Delay between API calls in seconds (default: 1.0)")
    parser.add_argument("--json", action="store_true", help="JSON output format")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--version", action="version",
                        version=f"{TOOL_NAME} 1.0.0 (aitools)")

    args = parser.parse_args()

    if args.verbose:
        log_info(f"{TOOL_NAME} 1.0.0 — NOBUL (nobul.tech)")

    # Platform check
    if sys.platform != "darwin":
        log_err("This tool requires macOS (uses Keychain).")
        sys.exit(1)

    # Get credentials
    if args.verbose:
        log_info("Reading OAuth token from Keychain...")
    token = get_oauth_token()
    if not token:
        sys.exit(1)
    if args.verbose:
        log_ok("Token: set")

    org_uuid = get_org_uuid()
    if org_uuid and args.verbose:
        log_stat("Org UUID", org_uuid)

    # List sessions
    if args.verbose:
        log_info("Querying /v1/sessions...")
    sessions = list_sessions(token, org_uuid, verbose=args.verbose)

    if sessions is None:
        sys.exit(1)

    if args.list_only:
        if isinstance(sessions, list):
            for s in sessions:
                sid = s if isinstance(s, str) else s.get("id", s.get("uuid", ""))
                print(sid)
        elif isinstance(sessions, dict):
            print(json.dumps(sessions, indent=2))
        return

    # Export
    export_sessions(sessions, token, org_uuid, args.output,
                    delay=args.delay, json_output=args.json,
                    verbose=args.verbose)


if __name__ == "__main__":
    main()
