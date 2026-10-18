#!/usr/bin/env python3
"""Check mandatory agent documentation and work-order shape without requiring Godot."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
agents = ("Aki", "Orcha", "Kiro", "Codex")
errors = []

for agent in agents:
    readme = root / "orders" / agent / "README.md"
    if not readme.is_file():
        errors.append(f"Missing {readme.relative_to(root)}")
        continue
    text = readme.read_text(encoding="utf-8").lower()
    for phrase in ("test", "report", "live", "immediately"):
        if phrase not in text:
            errors.append(f"{readme.relative_to(root)} missing instruction: {phrase}")
    for order in (root / "orders" / agent).glob("order_*.md"):
        content = order.read_text(encoding="utf-8")
        for heading in ("Objective", "Acceptance", "Test"):
            if heading.lower() not in content.lower():
                errors.append(f"{order.relative_to(root)} missing section: {heading}")
        if not re.search(r"Status\s*:", content, re.I):
            errors.append(f"{order.relative_to(root)} missing status")
if errors:
    print("\n".join(f"ERROR: {x}" for x in errors), file=sys.stderr)
    sys.exit(1)
print("Agent READMEs and order structure validated.")
