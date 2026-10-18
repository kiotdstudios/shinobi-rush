#!/usr/bin/env python3
"""Godot ConfigFile reader used by scripts/ci/validate_godot_project.py (stdlib only).

Parses project.godot / export_presets.cfg into {section: {key: raw_value_text}}.
Values stay raw (Godot Variant text) and are decoded on demand by the as_* helpers.
The root section (keys before the first [section], e.g. config_version) is "".
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional

_SECTION_RE = re.compile(r"^\[(?P<name>[^\]\r\n]+)\]\s*(?:;.*)?$")
_KEY_RE = re.compile(r"^(?P<key>\"[^\"]+\"|[^=;\[\]\s][^=]*?)\s*=\s*(?P<value>.*)$")


class ConfigError(ValueError):
    pass


def _scan(value_text: str, depth: int, in_string: bool) -> tuple[int, bool]:
    """Advance bracket depth / string state over value_text (Godot Variant syntax)."""
    i = 0
    n = len(value_text)
    while i < n:
        ch = value_text[i]
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            elif ch == ";" and depth == 0:
                break  # trailing comment on a single-line value
        i += 1
    return depth, in_string


def parse_config(text: str) -> Dict[str, Dict[str, str]]:
    if text.startswith("\ufeff"):
        text = text[1:]
    sections: Dict[str, Dict[str, str]] = {"": {}}
    current = ""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        i += 1
        if not line or line.startswith(";"):
            continue
        m = _SECTION_RE.match(line)
        if m:
            current = m.group("name").strip()
            sections.setdefault(current, {})
            continue
        m = _KEY_RE.match(line)
        if not m:
            raise ConfigError(f"line {i}: cannot parse {raw!r}")
        key = m.group("key").strip().strip('"')
        value = m.group("value")
        depth, in_string = _scan(value, 0, False)
        parts = [value]
        while (depth > 0 or in_string) and i < len(lines):
            cont = lines[i]
            i += 1
            parts.append(cont)
            depth, in_string = _scan(cont, depth, in_string)
        if depth > 0 or in_string:
            raise ConfigError(f"unterminated value for key {key!r} in section [{current}]")
        sections[current][key] = "\n".join(parts).strip()
    return sections


# ---- value helpers -------------------------------------------------------------------------

_STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "/": "/"}


def _unescape(s: str) -> str:
    return re.sub(r"\\(.)", lambda m: _ESCAPES.get(m.group(1), m.group(1)), s)


def as_string(raw: Optional[str]) -> Optional[str]:
    """'"abc"' -> 'abc'. Also accepts StringName (&"abc") / NodePath (^"abc"). Returns None if not a string."""
    if raw is None:
        return None
    m = re.fullmatch(r'[&^]?"((?:[^"\\]|\\.)*)"', raw.strip(), flags=re.S)
    return _unescape(m.group(1)) if m else None


def as_bool(raw: Optional[str]) -> Optional[bool]:
    if raw is None:
        return None
    v = raw.strip().lower()
    if v == "true":
        return True
    if v == "false":
        return False
    return None


def as_int(raw: Optional[str]) -> Optional[int]:
    if raw is None:
        return None
    try:
        return int(raw.strip())
    except ValueError:
        return None


def as_string_list(raw: Optional[str]) -> List[str]:
    """PackedStringArray("a", "b") / ["a", "b"] -> ['a', 'b']."""
    if raw is None:
        return []
    return [_unescape(s) for s in _STR_RE.findall(raw)]
