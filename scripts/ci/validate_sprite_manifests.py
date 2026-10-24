#!/usr/bin/env python3
"""Validate every sprite manifest (schema v1) under assets/characters/.

Python stdlib only (no Pillow). PNG sizes are read from the IHDR chunk with struct.
Usage: python scripts/ci/validate_sprite_manifests.py [--root assets/characters] [--repo-root <dir>]
The repo root defaults to this script's own repository (parents[2]), not the current directory.
128x128 standard (LOCKED): a production manifest (not under a references/, previews/, source/ or study/ path
segment) must have base frame_size [128,128], per-animation frame_size >= 128 in both dimensions and foot_anchor
inside its frame; body_height_px outside 100-112 is a warning. Exempt folders get JSON/schema checks only.
Exit code: 0 = ok (or no manifests), 1 = at least one error (warnings never fail).
Messages use GitHub Actions annotation syntax: ::error file=<path>::<message>
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

SUFFIX = ".manifest.json"
DIRS8 = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
CARDINALS = ("N", "E", "S", "W")
EXEMPT_DIRS = ("references", "previews", "source", "study")
STANDARD_FRAME = 128
BODY_HEIGHT_RANGE = (100, 112)
PNG_SIG = b"\x89PNG\r\n\x1a\n"
# scripts/ci/validate_sprite_manifests.py -> parents[2] is the repository root, independent of the cwd.
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[2]


def png_size(path: Path):
    """Return (width, height) from the PNG IHDR, or raise ValueError."""
    with open(path, "rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != PNG_SIG:
        raise ValueError("not a PNG file")
    length, ctype = struct.unpack(">I4s", head[8:16])
    if ctype != b"IHDR" or length != 13:
        raise ValueError("first PNG chunk is not IHDR")
    return struct.unpack(">II", head[16:24])


def _pair(v, positive=False):
    if not (isinstance(v, list) and len(v) == 2):
        return None
    if not all(isinstance(n, (int, float)) and not isinstance(n, bool) for n in v):
        return None
    if positive and not all(n >= 1 for n in v):
        return None
    return v


def _dir(v):
    t = str(v).strip().upper()
    return t if t in DIRS8 else None


def is_exempt(path: Path) -> bool:
    """True when any directory segment of the path is references/, previews/, source/ or study/."""
    return any(part.lower() in EXEMPT_DIRS for part in path.parent.parts)


def _anchor_outside(anchor, w: int, h: int) -> bool:
    return not (0 <= anchor[0] <= w and 0 <= anchor[1] <= h)


def validate_manifest(path: Path, exempt: bool | None = None, warnings: list | None = None):
    """Return (set_id_or_None, [error strings]) for one manifest file.

    exempt: True = JSON/schema checks only (no 128 standard, no PNG file checks); default derived from the path.
    warnings: optional list that receives non-fatal messages.
    """
    if exempt is None:
        exempt = is_exempt(path)
    warn = warnings if warnings is not None else []
    errors: list[str] = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError) as e:
        return None, [f"cannot read manifest: {e}"]
    except json.JSONDecodeError as e:
        return None, [f"invalid JSON (line {e.lineno}): {e.msg}"]
    if not isinstance(data, dict):
        return None, ["manifest root must be a JSON object"]

    set_id = data.get("id")
    if not isinstance(set_id, str) or not set_id.strip():
        errors.append('"id" must be a non-empty string')
        set_id = None
    if data.get("schema") != 1:
        errors.append('"schema" must be 1')
    fs = _pair(data.get("frame_size"), positive=True)
    if fs is None:
        errors.append('"frame_size" must be [width, height] with positive numbers')
        return set_id, errors
    fw, fh = int(fs[0]), int(fs[1])
    if not exempt and [fs[0], fs[1]] != [STANDARD_FRAME, STANDARD_FRAME]:
        errors.append(f"rule FRAME128: production base frame_size is [{fs[0]}, {fs[1]}], must be [128, 128]; "
                      "re-author the frames at 128x128 or move legacy art under references/, previews/, source/ or study/")
    if "foot_anchor" in data:
        fa = _pair(data["foot_anchor"])
        if fa is None:
            errors.append('"foot_anchor" must be [x, y]')
        elif not exempt and _anchor_outside(fa, fw, fh):
            errors.append(f"rule FOOT_ANCHOR: foot_anchor {fa} lies outside the {fw}x{fh} frame; "
                          "use pixel coordinates inside the frame")
    if "body_height_px" in data:
        bh = data["body_height_px"]
        if isinstance(bh, bool) or not isinstance(bh, (int, float)) or bh <= 0:
            errors.append('"body_height_px" must be a number > 0')
        elif not exempt and not BODY_HEIGHT_RANGE[0] <= bh <= BODY_HEIGHT_RANGE[1]:
            warn.append(f"rule BODY_HEIGHT: body_height_px {bh} is outside {BODY_HEIGHT_RANGE[0]}-{BODY_HEIGHT_RANGE[1]}; "
                        "aim for about 108 on the 128 frame")
    declared = data.get("directions")
    if declared is not None:
        if not isinstance(declared, list):
            errors.append('"directions" must be a list')
        else:
            for d in declared:
                if _dir(d) is None:
                    errors.append(f'unknown direction "{d}" in "directions" (use {", ".join(DIRS8)})')
    mirror = {}
    if "mirror" in data:
        if not isinstance(data["mirror"], dict):
            errors.append('"mirror" must be an object (target direction -> source direction)')
        else:
            for k, v in data["mirror"].items():
                if _dir(k) is None or _dir(v) is None:
                    errors.append(f'bad "mirror" entry {k} -> {v}')
                else:
                    mirror[_dir(k)] = _dir(v)

    anims = data.get("animations")
    if not isinstance(anims, dict) or not anims:
        errors.append('"animations" must be an object with at least one animation')
        return set_id, errors

    base = path.parent
    for aid, a in anims.items():
        pre = f'animation "{aid}"'
        if not isinstance(a, dict):
            errors.append(f"{pre} must be an object")
            continue
        fps = a.get("fps", 24)
        if isinstance(fps, bool) or not isinstance(fps, (int, float)) or fps <= 0:
            errors.append(f"{pre}: fps must be > 0")
        cw, ch = fw, fh
        if "frame_size" in a:
            ofs = _pair(a["frame_size"], positive=True)
            if ofs is None:
                errors.append(f'{pre}: bad "frame_size"')
                continue
            cw, ch = int(ofs[0]), int(ofs[1])
            if not exempt and (ofs[0] < STANDARD_FRAME or ofs[1] < STANDARD_FRAME):
                errors.append(f"{pre}: rule FRAME128_OVERFLOW: frame_size [{ofs[0]}, {ofs[1]}] is smaller than 128 in a "
                              "dimension; overflow canvases must be >= 128x128 with the same body scale")
        if "foot_anchor" in a:
            afa = _pair(a["foot_anchor"])
            if afa is None:
                errors.append(f'{pre}: bad "foot_anchor"')
            elif not exempt and _anchor_outside(afa, cw, ch):
                errors.append(f"{pre}: rule FOOT_ANCHOR: foot_anchor {afa} lies outside the {cw}x{ch} frame; "
                              "use pixel coordinates inside the frame")
        dirs: list[str] = []
        if isinstance(a.get("frames"), dict):
            for k, lst in a["frames"].items():
                dn = _dir(k)
                if dn is None:
                    errors.append(f'{pre}: unknown direction "{k}"')
                    continue
                if not isinstance(lst, list) or not lst:
                    errors.append(f"{pre} direction {dn}: needs a non-empty list of PNG paths")
                    continue
                dirs.append(dn)
                for p in lst:
                    if not exempt:
                        errors.extend(_check_png(base, p, (cw, ch), f"{pre} direction {dn}"))
        elif "sheet" in a:
            cols = a.get("columns")
            rows = a.get("rows")
            if isinstance(cols, bool) or not isinstance(cols, int) or cols < 1:
                errors.append(f'{pre}: sheet needs "columns" >= 1')
                continue
            if not isinstance(rows, list) or not rows:
                errors.append(f'{pre}: sheet needs "rows" (one direction name per row)')
                continue
            bad_row = False
            for r in rows:
                rn = _dir(r)
                if rn is None:
                    errors.append(f'{pre}: unknown row direction "{r}"')
                    bad_row = True
                elif rn not in dirs:
                    dirs.append(rn)
            if bad_row:
                continue
            if not exempt:
                errors.extend(_check_png(base, a["sheet"], (cols * cw, len(rows) * ch), f"{pre} sheet"))
        else:
            errors.append(f'{pre} needs either "frames" or "sheet"')
            continue
        # Owner 2026-10-22 ("wire it to the controller"): mirrors scripts/sprites/sprite_set.gd's
        # allow_partial_directions opt-out -- proof-stage combat art that is deliberately SE-only
        # (Codex's kunai order gates expansion to the other 7 directions behind separate owner
        # approval) can skip the cardinal check for that one animation. Default false, so every
        # pre-existing production animation keeps the strict full-coverage requirement unchanged.
        if not a.get("allow_partial_directions", False):
            for c in CARDINALS:
                if c not in dirs and mirror.get(c) not in dirs:
                    errors.append(f'{pre}: cardinal direction {c} missing (provide it or a "mirror" entry)')
    return set_id, errors


def _check_png(base: Path, rel, expect, where: str):
    if not isinstance(rel, str) or not rel:
        return [f"{where}: file path must be a non-empty string"]
    p = base / rel
    if not p.is_file():
        return [f"{where}: missing file {rel}"]
    try:
        w, h = png_size(p)
    except (OSError, ValueError, struct.error) as e:
        return [f"{where}: {rel}: {e}"]
    if (w, h) != tuple(expect):
        return [f"{where}: {rel} is {w}x{h}, expected {expect[0]}x{expect[1]}"]
    return []


def find_manifests(root: Path):
    return sorted(p for p in root.rglob("*" + SUFFIX) if p.is_file())


def run(root: Path, repo_root: Path, out=None) -> int:
    out = out or sys.stdout
    if not root.is_dir():
        print(f"No sprite manifests: {root} does not exist (nothing to validate).", file=out)
        return 0
    manifests = find_manifests(root)
    if not manifests:
        print(f"No sprite manifests under {root} (nothing to validate).", file=out)
        return 0
    n_err = 0
    seen: dict[str, Path] = {}
    for m in manifests:
        try:
            shown = m.relative_to(repo_root).as_posix()
        except ValueError:
            shown = m.as_posix()
        warns: list[str] = []
        rel = m.relative_to(repo_root) if m.is_relative_to(repo_root) else m
        set_id, errs = validate_manifest(m, exempt=is_exempt(rel), warnings=warns)
        if set_id is not None:
            if set_id in seen:
                errs.append(f'duplicate set id "{set_id}" (also used by {seen[set_id].name})')
            else:
                seen[set_id] = m
        for w in warns:
            print(f"::warning file={shown}::{w}", file=out)
        for e in errs:
            print(f"::error file={shown}::{e}", file=out)
        n_err += len(errs)
        if not errs:
            print(f"OK {shown} ({set_id})", file=out)
    print(f"{len(manifests)} manifest(s) checked, {n_err} error(s)", file=out)
    return 1 if n_err else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--repo-root", default=None,
                    help="repository root (default: derived from this script's location, never the current directory)")
    ap.add_argument("--root", default=None, help="folder to scan (default: <repo-root>/assets/characters)")
    args = ap.parse_args(argv)
    repo_root = Path(args.repo_root).resolve() if args.repo_root else DEFAULT_REPO_ROOT
    root = Path(args.root).resolve() if args.root else repo_root / "assets" / "characters"
    return run(root, repo_root)


if __name__ == "__main__":
    sys.exit(main())
