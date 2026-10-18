#!/usr/bin/env python3
"""Reader/validator for scripts/ci/godot-version.env, the single source of truth for CI tool pins (stdlib only).

  python3 scripts/ci/pins.py check                       validate the pin file (exit 1 on problems)
  python3 scripts/ci/pins.py github-env >> "$GITHUB_ENV"  print validated KEY=value lines for later workflow steps
  python3 scripts/ci/pins.py markdown                    print the pin table used in the docs
  python3 scripts/ci/pins.py bump-godot --sums-file F    rewrite the three Godot SHA512 values from a SHA512-SUMS.txt
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional

PIN_FILE = Path(__file__).resolve().with_name("godot-version.env")
INSTALL_LAYOUT_VERSION = 1  # bump when install_godot.py changes the on-disk layout (invalidates caches)

SHA512 = re.compile(r"[0-9a-f]{128}")
SHA256 = re.compile(r"[0-9a-f]{64}")
SEMVER = re.compile(r"\d+\.\d+\.\d+")
REQUIRED: Dict[str, re.Pattern[str]] = {
    "GODOT_VERSION": re.compile(r"\d+\.\d+(\.\d+)?"),
    "GODOT_EDITOR_LINUX_X86_64_SHA512": SHA512,
    "GODOT_EDITOR_WIN64_SHA512": SHA512,
    "GODOT_EXPORT_TEMPLATES_SHA512": SHA512,
    "NODE_VERSION": SEMVER,
    "PLAYWRIGHT_VERSION": SEMVER,
    "ACTIONLINT_VERSION": SEMVER,
    "ACTIONLINT_LINUX_AMD64_SHA256": SHA256,
    "ACTIONLINT_WINDOWS_AMD64_SHA256": SHA256,
    "RUNNER_IMAGE": re.compile(r"ubuntu-\d\d\.\d\d"),
}
LINE_RE = re.compile(r"^([A-Z][A-Z0-9_]*)=([^\s\"'#]+)$")


class PinError(ValueError):
    pass


def parse(text: str) -> Dict[str, str]:
    """Strict parser: KEY=value lines, '#' comment lines, blank lines. Anything else is an error."""
    pins: Dict[str, str] = {}
    problems: List[str] = []
    for n, raw in enumerate(text.replace("\r\n", "\n").split("\n"), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = LINE_RE.match(line)
        if not m:
            problems.append(f"line {n}: not KEY=value without quotes/spaces: {raw!r}")
            continue
        key, value = m.groups()
        if key in pins:
            problems.append(f"line {n}: duplicate key {key}")
        pins[key] = value
    for key, pattern in REQUIRED.items():
        if key not in pins:
            problems.append(f"missing key {key}")
        elif not pattern.fullmatch(pins[key]):
            problems.append(f"{key}: invalid value {pins[key]!r} (expected /{pattern.pattern}/)")
    problems += [f"unknown key {k}" for k in pins if k not in REQUIRED]
    if "RUNNER_IMAGE" in pins and pins["RUNNER_IMAGE"].endswith("latest"):
        problems.append("RUNNER_IMAGE must be a pinned image, not *-latest")
    if problems:
        raise PinError("; ".join(problems))
    return pins


def load(path: Optional[Path] = None) -> Dict[str, str]:
    path = path or PIN_FILE
    try:
        return parse(path.read_text(encoding="utf-8"))
    except OSError as e:
        raise PinError(f"cannot read {path}: {e}") from e


def derived(pins: Dict[str, str]) -> Dict[str, str]:
    v = pins["GODOT_VERSION"]
    return {
        "GODOT_TAG": f"{v}-stable",
        "GODOT_TEMPLATES_VERSION": f"{v}.stable",
        "GODOT_CACHE_KEY": f"godot-{v}-e{pins['GODOT_EDITOR_LINUX_X86_64_SHA512'][:12]}-t{pins['GODOT_EXPORT_TEMPLATES_SHA512'][:12]}-v{INSTALL_LAYOUT_VERSION}",
    }


def markdown_table(pins: Dict[str, str]) -> str:
    rows = {**pins, **derived(pins)}
    shown = ["GODOT_VERSION", "GODOT_TAG", "GODOT_TEMPLATES_VERSION", "NODE_VERSION", "PLAYWRIGHT_VERSION", "ACTIONLINT_VERSION", "RUNNER_IMAGE"]
    out = ["| Pin | Value |", "| --- | --- |"]
    out += [f"| `{k}` | <!--pin:{k}-->`{rows[k]}`<!--/pin--> |" for k in shown]
    return "\n".join(out) + "\n"


def bump_godot(pin_path: Path, sums_text: str, version: str) -> Dict[str, str]:
    """Rewrite GODOT_VERSION and the three Godot SHA512 values from the text of a SHA512-SUMS.txt."""
    sums = {}
    for line in sums_text.splitlines():
        parts = line.split(None, 1)
        if len(parts) == 2:
            sums[parts[1].strip().lstrip("*")] = parts[0].lower()
    names = {
        "GODOT_EDITOR_LINUX_X86_64_SHA512": f"Godot_v{version}-stable_linux.x86_64.zip",
        "GODOT_EDITOR_WIN64_SHA512": f"Godot_v{version}-stable_win64.exe.zip",
        "GODOT_EXPORT_TEMPLATES_SHA512": f"Godot_v{version}-stable_export_templates.tpz",
    }
    new = {"GODOT_VERSION": version}
    for key, name in names.items():
        if name not in sums:
            raise PinError(f"{name} not found in the SHA512 sums file")
        new[key] = sums[name]
    text = pin_path.read_text(encoding="utf-8")
    for key, value in new.items():
        text, n = re.subn(rf"^{key}=.*$", f"{key}={value}", text, flags=re.M)
        if n != 1:
            raise PinError(f"{key} not found exactly once in {pin_path}")
    parse(text)  # validate before writing
    pin_path.write_text(text, encoding="utf-8", newline="\n")
    return new


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["check", "github-env", "markdown", "bump-godot"])
    ap.add_argument("--pins", type=Path, default=PIN_FILE)
    ap.add_argument("--sums-file", type=Path)
    ap.add_argument("--version")
    args = ap.parse_args(argv)
    try:
        if args.command == "bump-godot":
            if not args.sums_file or not args.version:
                ap.error("bump-godot needs --version and --sums-file")
            new = bump_godot(args.pins, args.sums_file.read_text(encoding="utf-8"), args.version)
            print("updated:", ", ".join(new))
            return 0
        pins = load(args.pins)
    except PinError as e:
        print(f"ERROR: pin file problem: {e}", file=sys.stderr)
        return 1
    if args.command == "check":
        print(f"pins OK ({len(pins)} keys, Godot {pins['GODOT_VERSION']})")
    elif args.command == "github-env":
        for key, value in {**pins, **derived(pins)}.items():
            print(f"{key}={value}")
    else:
        sys.stdout.write(markdown_table(pins))
    return 0


if __name__ == "__main__":
    sys.exit(main())
