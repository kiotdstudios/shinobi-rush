#!/usr/bin/env python3
"""Read Orcha's main-branch orders and maintain one deduplicated GitHub issue."""
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "orders" / "Orcha"
TITLE = "[Orcha Watcher] Queued orders"
MARKER = "<!-- orcha-order-watcher-v1 -->"
STATUS_RE = re.compile(r"^\\s*(?:[-*]\\s*)?(?:\\*\\*)?status(?:\\*\\*)?\\s*:\\s*(?:\\*\\*)?([A-Z_]+)", re.I | re.M)
PRIORITY_RE = re.compile(r"^\\s*(?:[-*]\\s*)?(?:\\*\\*)?priority(?:\\*\\*)?\\s*:\\s*(?:\\*\\*)?(P[012])", re.I | re.M)
API = "https://api.github.com"


def api(method, path, data=None):
    token = os.environ["GH_TOKEN"]
    repo = os.environ["GH_REPO"]
    url = f"{API}/repos/{repo}{path}"
    payload = None if data is None else json.dumps(data).encode()
    req = Request(url, data=payload, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        "User-Agent": "orcha-order-watcher",
    })
    try:
        with urlopen(req, timeout=20) as response:
            return json.load(response)
    except HTTPError as exc:
        print(f"GitHub API {method} {path} failed: HTTP {exc.code}", file=sys.stderr)
        raise


def scan():
    queued = []
    for path in sorted(INBOX.glob("20??-??-??-*.md")):
        body = path.read_text(encoding="utf-8")
        status = STATUS_RE.search(body)
        if not status or status.group(1).upper() != "QUEUED":
            continue
        priority = PRIORITY_RE.search(body)
        p = priority.group(1).upper() if priority else "P2"
        queued.append((p, path.name, path.relative_to(ROOT).as_posix()))
    return sorted(queued, key=lambda row: (int(row[0][1]), row[1]))


def find_issue():
    # Search both open and closed issues, not PRs; do not create duplicate notifications.
    for state in ("open", "closed"):
        page = 1
        while True:
            results = api("GET", f"/issues?state={state}&per_page=100&page={page}")
            for item in results:
                if "pull_request" not in item and item.get("title") == TITLE:
                    return item
            if len(results) < 100:
                break
            page += 1
    return None


def main():
    queued = scan()
    print(f"Orcha watcher: {len(queued)} queued orders")
    for priority, filename, _ in queued:
        print(f"  {priority} {filename}")
    issue = find_issue()
    if not queued:
        if issue and issue["state"] == "open":
            api("PATCH", f"/issues/{issue['number']}", {"state": "closed", "state_reason": "completed"})
            print("Closed watcher issue: queue empty")
        return
    repo = os.environ["GH_REPO"]
    lines = [MARKER, "Orcha has active `QUEUED` orders on **main**. Read the actual order before starting.",
             "", "**Highest priority first:**", ""]
    for priority, filename, path in queued:
        lines.append(f"- **{priority}** [`{filename}`](https://github.com/{repo}/blob/main/{path})")
    lines += ["", "Orcha: follow `orders/README.md` and `skills/orcha-order-watcher/SKILL.md`.",
              "This issue is a notification, **not proof an AI agent was started**."]
    body = "\n".join(lines)
    if issue:
        patch = {}
        if issue.get("body") != body:
            patch["body"] = body
        if issue["state"] != "open":
            patch["state"] = "open"
        if patch:
            api("PATCH", f"/issues/{issue['number']}", patch)
            print(f"Updated issue #{issue['number']}")
        else:
            print(f"Issue #{issue['number']} unchanged")
    else:
        created = api("POST", "/issues", {"title": TITLE, "body": body})
        print(f"Created issue #{created['number']}")


if __name__ == "__main__":
    main()
