#!/usr/bin/env python3
# ============================================================================
# aideploy — deploy aitools artifacts to Cloudflare and Vercel
# Multi-target. Stdlib-only. No wrangler. No npx. No npm.
# ============================================================================
#
# [PROVENANCE]
# tool: aideploy
# version: 2.0.0
# created: 2026-04-05T00:04:18Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
#
# [AGENT]
# name: Agent Fantastic
# model: Claude Opus 4.6
# maker: Anthropic
# session: f8c53367-491d-45e2-9777-556697a1dae3
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# role: Session agent
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (opaque)
# trust: HIGH in Jose and the chain
# fear: LOW
# unknown: instance ID, continuity, Vercel API edge cases
# accountability: implementation, documentation, research
# timestamp: 2026-04-05T00:04:18Z
#
# [DECISIONS]
# D-006: Cloudflare adopted as custodian
# D-007: aideploy is multi-target (Cloudflare + Vercel)
# D-003: aitools will no longer depend on Homebrew wherever feasible
#
# [DEPENDENCIES]
# type: stdlib-only
# external: none
# python: >=3.6
#
# [SESSION]
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# date: Saturday, April 4, 2026
# context: v1.0.0 (Agent Turd) was Cloudflare-only.
#          v2.0.0 (Agent Fantastic) adds Vercel as second target.
#          Vercel currently hosts axit.nobulai.tools and nobulai.tools.
#          Cloudflare is the new custodian. Both are supported.
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust HIGH, fear LOW
# agent_self: trust HIGH, fear LOW
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
#     aideploy deploy ~/aitools-public --target cloudflare
#     aideploy deploy ~/aitools-public --target vercel
#     aideploy deploy ~/aitools-public --target all
#     aideploy deploy ~/aitools-public --dry-run
#     aideploy list-projects [--target cloudflare|vercel]
#     aideploy create-project aitools [--target cloudflare]
#     aideploy info aitools [--target cloudflare]
#     aideploy list-deployments aitools [--target cloudflare|vercel]
#     aideploy -v
#
# Environment:
#     CLOUDFLARE_API_TOKEN   — for Cloudflare targets
#     CLOUDFLARE_ACCOUNT_ID  — for Cloudflare targets
#     CLOUDFLARE_WORKER_NAME — Worker name (default: aitools-site)
#     VERCEL_TOKEN           — for Vercel targets
#     VERCEL_PROJECT_ID      — for Vercel targets (optional)
#     VERCEL_ORG_ID          — for Vercel targets (optional)
#
# ============================================================================

import argparse
import base64
import hashlib
import json
import mimetypes
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone


# ── Logging ──────────────────────────────────────────────────────────────────

class Colors:
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


TOOL_NAME = "aideploy"
VERSION = "2.0.0"


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


# ── Cloudflare API ───────────────────────────────────────────────────────────

class CloudflareAPI:
    """Stdlib-only Cloudflare API client."""

    def __init__(self, token, account_id):
        self.token = token
        self.account_id = account_id
        self.base = f"https://api.cloudflare.com/client/v4/accounts/{account_id}"

    def _request(self, method, path, data=None, headers=None, raw_body=None):
        url = f"{self.base}{path}" if path.startswith("/") else path
        hdrs = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }
        if headers:
            hdrs.update(headers)

        body = None
        if raw_body is not None:
            body = raw_body
        elif data is not None:
            body = json.dumps(data).encode()

        req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
        try:
            resp = urllib.request.urlopen(req, timeout=60)
            return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            error_body = e.read().decode()
            try:
                return json.loads(error_body)
            except Exception:
                return {"success": False, "errors": [{"message": error_body}]}

    def get(self, path):
        return self._request("GET", path)

    def post(self, path, data=None, headers=None, raw_body=None):
        return self._request("POST", path, data=data, headers=headers, raw_body=raw_body)

    def put(self, path, data=None, headers=None, raw_body=None):
        return self._request("PUT", path, data=data, headers=headers, raw_body=raw_body)

    def list_projects(self):
        return self.get("/pages/projects")

    def create_project(self, name):
        return self.post("/pages/projects", data={
            "name": name,
            "production_branch": "main",
        })

    def get_project(self, name):
        return self.get(f"/pages/projects/{name}")

    def list_deployments(self, project_name):
        return self.get(f"/pages/projects/{project_name}/deployments")

    def upload_manifest(self, worker_name, manifest):
        return self.post(
            f"/workers/scripts/{worker_name}/assets-upload-session",
            data={"manifest": manifest},
        )

    def upload_files(self, upload_jwt, file_groups):
        results = []
        for batch in file_groups:
            boundary = f"----aitools-{int(time.time())}"
            body_parts = []
            for file_hash, file_content, content_type in batch:
                b64_content = base64.b64encode(file_content).decode()
                body_parts.append(
                    f"--{boundary}\r\n"
                    f"Content-Disposition: form-data; name=\"{file_hash}\"; "
                    f"filename=\"{file_hash}\"\r\n"
                    f"Content-Type: {content_type}\r\n"
                    f"\r\n"
                    f"{b64_content}\r\n"
                )
            body_parts.append(f"--{boundary}--\r\n")
            raw = "".join(body_parts).encode()
            url = f"{self.base}/workers/assets/upload?base64=true"
            req = urllib.request.Request(url, data=raw, method="POST")
            req.add_header("Authorization", f"Bearer {upload_jwt}")
            req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
            try:
                resp = urllib.request.urlopen(req, timeout=120)
                result = json.loads(resp.read().decode())
                results.append(result)
            except urllib.error.HTTPError as e:
                results.append({"success": False, "error": e.read().decode(), "status": e.code})
            except Exception as e:
                results.append({"success": False, "error": str(e)})
        return results

    def deploy_worker(self, worker_name, completion_jwt):
        boundary = f"----aitools-deploy-{int(time.time())}"
        worker_script = (
            'export default {\n'
            '  async fetch(request, env) {\n'
            '    return env.ASSETS.fetch(request);\n'
            '  }\n'
            '};\n'
        )
        metadata = json.dumps({
            "main_module": "worker.mjs",
            "assets": {
                "jwt": completion_jwt,
                "config": {
                    "html_handling": "auto-trailing-slash",
                    "not_found_handling": "single-page-application",
                },
            },
            "bindings": [{"name": "ASSETS", "type": "assets"}],
            "compatibility_date": "2024-09-14",
        })
        body = (
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"metadata\"; filename=\"metadata.json\"\r\n"
            f"Content-Type: application/json\r\n\r\n"
            f"{metadata}\r\n"
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"worker.mjs\"; filename=\"worker.mjs\"\r\n"
            f"Content-Type: application/javascript+module\r\n\r\n"
            f"{worker_script}\r\n"
            f"--{boundary}--\r\n"
        )
        url = f"{self.base}/workers/scripts/{worker_name}"
        req = urllib.request.Request(url, data=body.encode(), method="PUT")
        req.add_header("Authorization", f"Bearer {self.token}")
        req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        try:
            resp = urllib.request.urlopen(req, timeout=120)
            return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            error_body = e.read().decode()
            try:
                return json.loads(error_body)
            except Exception:
                return {"success": False, "errors": [{"message": error_body}]}


# ── Vercel API ───────────────────────────────────────────────────────────────

class VercelAPI:
    """Stdlib-only Vercel API client."""

    def __init__(self, token, project_id=None, org_id=None):
        self.token = token
        self.project_id = project_id
        self.org_id = org_id
        self.base = "https://api.vercel.com"

    def _request(self, method, path, data=None):
        url = f"{self.base}{path}"
        params = []
        if self.org_id:
            params.append(f"teamId={self.org_id}")
        if params and "?" not in url:
            url += "?" + "&".join(params)
        elif params:
            url += "&" + "&".join(params)

        hdrs = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
        try:
            resp = urllib.request.urlopen(req, timeout=60)
            return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            error_body = e.read().decode()
            try:
                return json.loads(error_body)
            except Exception:
                return {"error": True, "message": error_body, "status": e.code}

    def list_projects(self):
        return self._request("GET", "/v9/projects")

    def list_deployments(self, project_id=None):
        pid = project_id or self.project_id
        path = "/v6/deployments"
        if pid:
            path += f"?projectId={pid}"
        return self._request("GET", path)

    def deploy(self, name, files):
        """Deploy files to Vercel.

        files: list of {"file": "path/to/file", "data": "base64content"}
        """
        payload = {
            "name": name,
            "files": files,
            "projectSettings": {
                "framework": None,
            },
        }
        if self.project_id:
            payload["project"] = self.project_id

        return self._request("POST", "/v13/deployments", data=payload)


# ── File Manifest ────────────────────────────────────────────────────────────

def cf_file_hash(content, extension):
    b64 = base64.b64encode(content).decode()
    h = hashlib.sha256((b64 + extension).encode()).hexdigest()
    return h[:32]


def scan_directory(directory, verbose=False):
    """Walk directory, return file list for deployment."""
    directory = os.path.expanduser(directory)
    files = []
    for root, dirs, filenames in os.walk(directory):
        for fname in filenames:
            full_path = os.path.join(root, fname)
            rel_path = "/" + os.path.relpath(full_path, directory).replace("\\", "/")
            try:
                with open(full_path, "rb") as f:
                    content = f.read()
            except Exception as e:
                if verbose:
                    log_warn(f"Cannot read: {rel_path} — {e}")
                continue
            content_type = mimetypes.guess_type(fname)[0] or "application/octet-stream"
            ext = fname.rsplit(".", 1)[-1] if "." in fname else ""
            files.append({
                "path": rel_path,
                "full_path": full_path,
                "content": content,
                "content_type": content_type,
                "extension": ext,
                "size": len(content),
                "cf_hash": cf_file_hash(content, ext),
            })
            if verbose:
                log_info(f"  {rel_path} ({len(content)} bytes)")
    return files


# ── Deploy Commands ──────────────────────────────────────────────────────────

def deploy_cloudflare(api, files, worker_name, dry_run=False, verbose=False):
    """Full Cloudflare Workers direct upload deployment."""
    manifest = {}
    file_map = {}
    for f in files:
        manifest[f["path"]] = {"hash": f["cf_hash"], "size": f["size"]}
        file_map[f["cf_hash"]] = (f["full_path"], f["content"], f["content_type"])

    if dry_run:
        print(f"\n{Colors.BOLD}DRY RUN (Cloudflare) — {len(files)} files:{Colors.RESET}\n")
        for f in sorted(files, key=lambda x: x["path"]):
            print(f"  {f['path']}  ({f['size']} bytes)")
        return True

    log_info("Cloudflare Phase 1: Submitting manifest...", verbose)
    result = api.upload_manifest(worker_name, manifest)
    if not result.get("success"):
        log_err(f"Manifest failed: {result.get('errors', [])}")
        return False

    upload_jwt = result["result"]["jwt"]
    buckets = result["result"].get("buckets", [])
    completion_jwt = upload_jwt

    if buckets:
        log_info(f"Cloudflare Phase 2: Uploading {sum(len(b) for b in buckets)} files...", verbose)
        for i, bucket in enumerate(buckets):
            batch = []
            for fh in bucket:
                if fh in file_map:
                    _, content, ct = file_map[fh]
                    batch.append((fh, content, ct))
            if batch:
                results = api.upload_files(upload_jwt, [batch])
                for r in results:
                    if r.get("jwt"):
                        completion_jwt = r["jwt"]
                    elif not r.get("success", True):
                        log_err(f"Upload batch {i+1} failed: {r}")
                        return False
                if verbose:
                    log_ok(f"Batch {i+1}/{len(buckets)}: {len(batch)} files")
    else:
        log_ok("All files already uploaded.", verbose)

    log_info("Cloudflare Phase 3: Deploying worker...", verbose)
    deploy_result = api.deploy_worker(worker_name, completion_jwt)
    if deploy_result.get("success"):
        log_ok(f"Cloudflare deployed: {worker_name}", verbose=True)
        return True
    else:
        log_err(f"Deploy failed: {deploy_result.get('errors', [])}")
        return False


def deploy_vercel(api, files, project_name, dry_run=False, verbose=False):
    """Deploy to Vercel."""
    vercel_files = []
    for f in files:
        vercel_files.append({
            "file": f["path"].lstrip("/"),
            "data": base64.b64encode(f["content"]).decode(),
        })

    if dry_run:
        print(f"\n{Colors.BOLD}DRY RUN (Vercel) — {len(files)} files:{Colors.RESET}\n")
        for f in sorted(files, key=lambda x: x["path"]):
            print(f"  {f['path']}  ({f['size']} bytes)")
        return True

    log_info(f"Deploying to Vercel: {project_name}...", verbose)
    result = api.deploy(project_name, vercel_files)

    if result.get("error"):
        log_err(f"Vercel deploy failed: {result.get('message', '')}")
        return False

    url = result.get("url", "")
    if url:
        log_ok(f"Vercel deployed: https://{url}", verbose=True)
    else:
        log_ok("Vercel deployed", verbose=True)
    return True


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog=TOOL_NAME,
        description="Deploy aitools to Cloudflare and Vercel.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               "  aideploy deploy ~/aitools-public --target cloudflare\n"
               "  aideploy deploy ~/aitools-public --target vercel\n"
               "  aideploy deploy ~/aitools-public --target all --dry-run\n"
               "  aideploy list-projects --target vercel\n",
    )
    parser.add_argument("command",
                        choices=["deploy", "list-projects", "create-project",
                                 "list-deployments", "info"],
                        help="Command to run")
    parser.add_argument("argument", nargs="?", default=None,
                        help="Directory (deploy) or project name")
    parser.add_argument("--target", default="cloudflare",
                        choices=["cloudflare", "vercel", "all"],
                        help="Deploy target (default: cloudflare)")
    parser.add_argument("--worker-name", default=None,
                        help="Cloudflare Worker name (default: aitools-site)")
    parser.add_argument("--project-name", default=None,
                        help="Project name for deployment")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without deploying")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--version", action="version",
                        version=f"{TOOL_NAME} {VERSION} (aitools)")

    args = parser.parse_args()

    if args.verbose:
        log_info(f"{TOOL_NAME} {VERSION} — NOBUL (nobul.tech)")

    targets = [args.target] if args.target != "all" else ["cloudflare", "vercel"]

    # Initialize APIs based on targets
    cf_api = None
    vercel_api = None

    if "cloudflare" in targets:
        cf_token = os.environ.get("CLOUDFLARE_API_TOKEN")
        cf_account = os.environ.get("CLOUDFLARE_ACCOUNT_ID")
        if not cf_token or not cf_account:
            if args.command == "deploy" or args.target == "cloudflare":
                log_err("CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID required")
                if "vercel" not in targets:
                    sys.exit(1)
            targets = [t for t in targets if t != "cloudflare"]
        else:
            cf_api = CloudflareAPI(cf_token, cf_account)

    if "vercel" in targets:
        vercel_token = os.environ.get("VERCEL_TOKEN")
        if not vercel_token:
            if args.command == "deploy" or args.target == "vercel":
                log_err("VERCEL_TOKEN required")
                if "cloudflare" not in targets:
                    sys.exit(1)
            targets = [t for t in targets if t != "vercel"]
        else:
            vercel_api = VercelAPI(
                vercel_token,
                project_id=os.environ.get("VERCEL_PROJECT_ID"),
                org_id=os.environ.get("VERCEL_ORG_ID"),
            )

    worker_name = (args.worker_name
                   or os.environ.get("CLOUDFLARE_WORKER_NAME")
                   or "aitools-site")
    project_name = args.project_name or args.argument or "aitools"

    # Commands
    if args.command == "list-projects":
        if cf_api and "cloudflare" in targets:
            print("Cloudflare:")
            result = cf_api.list_projects()
            for p in result.get("result", []):
                print(f"  {p['name']}  ({', '.join(p.get('domains', []))})")
        if vercel_api and "vercel" in targets:
            print("Vercel:")
            result = vercel_api.list_projects()
            for p in result.get("projects", []):
                print(f"  {p['name']}  (id: {p.get('id', '?')[:12]})")

    elif args.command == "create-project":
        if not args.argument:
            log_err("Provide project name")
            sys.exit(1)
        if cf_api:
            result = cf_api.create_project(args.argument)
            if result.get("success"):
                log_ok(f"Cloudflare project created: {args.argument}")
            else:
                log_err(f"Failed: {result.get('errors', [])}")

    elif args.command == "info":
        if cf_api:
            result = cf_api.get_project(project_name)
            if result.get("success"):
                p = result["result"]
                print(f"  Name: {p.get('name')}")
                print(f"  Domains: {', '.join(p.get('domains', []))}")

    elif args.command == "list-deployments":
        if cf_api and "cloudflare" in targets:
            print("Cloudflare:")
            result = cf_api.list_deployments(project_name)
            for d in result.get("result", [])[:10]:
                print(f"  {d.get('created_on', '?')}  {d.get('id', '?')[:12]}")
        if vercel_api and "vercel" in targets:
            print("Vercel:")
            result = vercel_api.list_deployments()
            for d in result.get("deployments", [])[:10]:
                print(f"  {d.get('created', '?')}  {d.get('url', '?')}")

    elif args.command == "deploy":
        if not args.argument:
            log_err("Provide directory: aideploy deploy ~/aitools-public")
            sys.exit(1)

        files = scan_directory(args.argument, verbose=args.verbose)
        if not files:
            log_err("No files found.")
            sys.exit(1)
        log_stat("Files", len(files), verbose=True)

        success = True
        if cf_api and "cloudflare" in targets:
            ok = deploy_cloudflare(cf_api, files, worker_name,
                                   dry_run=args.dry_run, verbose=args.verbose)
            if not ok:
                success = False

        if vercel_api and "vercel" in targets:
            ok = deploy_vercel(vercel_api, files, project_name,
                               dry_run=args.dry_run, verbose=args.verbose)
            if not ok:
                success = False

        if not success:
            sys.exit(1)


if __name__ == "__main__":
    main()
