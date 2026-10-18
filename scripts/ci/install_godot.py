#!/usr/bin/env python3
"""Install the pinned Godot editor + Web export templates (stdlib only; runs on Linux CI and Windows dev machines).

  python3 scripts/ci/install_godot.py install --platform linux --dest ~/.cache/shinobi-rush/godot --github-env
  python3 scripts/ci/install_godot.py verify  --platform linux --dest ~/.cache/shinobi-rush/godot
  python3 scripts/ci/install_godot.py print-bin --platform windows --dest %LOCALAPPDATA%\\shinobi-rush-ci\\godot

Everything is checked against the SHA512 pins in scripts/ci/godot-version.env while downloading. The editor is run in
Godot's "self-contained" mode (an empty `_sc_` file next to the binary), so templates and editor data live inside
--dest and nothing is written to the user's real Godot folders. Only the templates the pipeline needs are extracted:
web_nothreads_debug.zip (always) and web_debug.zip (only with --with-threaded-templates, used by a negative self-test).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pins as pinlib  # noqa: E402
from ci_common import UnsafePath, annotate, refuse_unsafe_delete, run_logged, set_env  # noqa: E402

MANIFEST = ".shinobi-godot-install.json"
RELEASES = "https://github.com/godotengine/godot-builds/releases/download"


class InstallError(RuntimeError):
    pass


def asset_names(version: str, platform: str) -> Dict[str, object]:
    tag = f"Godot_v{version}-stable"
    if platform == "linux":
        return {"zip": f"{tag}_linux.x86_64.zip", "members": [f"{tag}_linux.x86_64"], "bin": f"{tag}_linux.x86_64", "pin": "GODOT_EDITOR_LINUX_X86_64_SHA512"}
    if platform == "windows":
        return {"zip": f"{tag}_win64.exe.zip", "members": [f"{tag}_win64.exe", f"{tag}_win64_console.exe"], "bin": f"{tag}_win64_console.exe", "pin": "GODOT_EDITOR_WIN64_SHA512"}
    raise InstallError(f"unsupported platform {platform!r} (use linux or windows)")


def template_members(threaded: bool) -> List[str]:
    names = ["version.txt", "web_nothreads_debug.zip"] + (["web_debug.zip"] if threaded else [])
    return [f"templates/{n}" for n in names]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, target: Path, expected_sha512: str, label: str, attempts: int = 3) -> None:
    """Stream url to target while hashing; the pin must match or the file is deleted and the install fails."""
    last: Optional[Exception] = None
    for attempt in range(1, attempts + 1):
        try:
            digest = hashlib.sha512()
            req = urllib.request.Request(url, headers={"User-Agent": "shinobi-rush-ci/1"})
            with urllib.request.urlopen(req, timeout=60) as resp, target.open("wb") as out:
                total = int(resp.headers.get("Content-Length") or 0)
                done, next_mark, started = 0, 0.1, time.monotonic()
                while True:
                    chunk = resp.read(1024 * 1024)
                    if not chunk:
                        break
                    digest.update(chunk)
                    out.write(chunk)
                    done += len(chunk)
                    if total and done / total >= next_mark:
                        print(f"  {label}: {int(done / total * 100)}% ({done // 1048576} MiB, {time.monotonic() - started:.0f}s)", flush=True)
                        next_mark += 0.2
            actual = digest.hexdigest()
            if actual != expected_sha512.lower():
                target.unlink(missing_ok=True)
                raise InstallError(f"SHA512 mismatch for {label}: expected {expected_sha512.lower()} but downloaded file has {actual}. Refusing to use it. Check the pin in scripts/ci/godot-version.env.")
            return
        except InstallError:
            raise
        except urllib.error.HTTPError as e:
            last = e
            if 400 <= e.code < 500:
                break  # not transient
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as e:
            last = e
        target.unlink(missing_ok=True)
        if attempt < attempts:
            wait = 2 ** attempt
            annotate("warning", f"download of {label} failed ({last}); retry {attempt}/{attempts - 1} in {wait}s", title="Godot download")
            time.sleep(wait)
    raise InstallError(f"could not download {label} from {url}: {last}")


def extract(zip_path: Path, wanted: Dict[str, Path]) -> None:
    """Extract exactly the listed members (never extractall: no path traversal, no surprises)."""
    with zipfile.ZipFile(zip_path) as z:
        present = set(z.namelist())
        for member, target in wanted.items():
            if member not in present:
                raise InstallError(f"{zip_path.name} does not contain the expected member {member!r}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(member) as src, target.open("wb") as out:
                shutil.copyfileobj(src, out, 1024 * 1024)


def binary_path(dest: Path, platform: str, version: str) -> Path:
    return dest / str(asset_names(version, platform)["bin"])


def verify_install(dest: Path, platform: str, pins: Dict[str, str], threaded: bool) -> List[str]:
    """Return a list of problems; an empty list means the existing install is exactly what the pins describe."""
    manifest_path = dest / MANIFEST
    if not manifest_path.is_file():
        return ["no install manifest"]
    try:
        m = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return [f"unreadable manifest: {e}"]
    names = asset_names(pins["GODOT_VERSION"], platform)
    problems = []
    expect = {
        "layout": pinlib.INSTALL_LAYOUT_VERSION, "godot_version": pins["GODOT_VERSION"], "platform": platform,
        "editor_sha512": pins[str(names["pin"])], "templates_sha512": pins["GODOT_EXPORT_TEMPLATES_SHA512"], "threaded_templates": threaded,
    }
    for key, value in expect.items():
        if m.get(key) != value:
            problems.append(f"manifest {key}={m.get(key)!r}, expected {value!r}")
    for rel, digest in (m.get("files") or {}).items():
        p = dest / rel
        if not p.is_file() or sha256_file(p) != digest:
            problems.append(f"{rel}: missing or modified")
    if not binary_path(dest, platform, pins["GODOT_VERSION"]).is_file():
        problems.append("editor binary missing")
    return problems


def install(dest: Path, platform: str, pins: Dict[str, str], threaded: bool, base_url: Optional[str], skip_version_check: bool) -> Dict[str, str]:
    version = pins["GODOT_VERSION"]
    problems = verify_install(dest, platform, pins, threaded)
    if not problems:
        print(f"cache hit: Godot {version} already installed and verified in {dest}")
    else:
        if dest.exists() and any(dest.iterdir()):
            if not (dest / MANIFEST).exists():
                raise InstallError(f"refusing to wipe {dest}: it is not empty and is not a previous Godot install")
            try:  # even a directory with our manifest is never wiped if it is a root, home, working or checkout directory
                refuse_unsafe_delete(dest)
            except UnsafePath as e:
                raise InstallError(str(e)) from e
            print(f"existing install is not usable ({'; '.join(problems[:3])}); reinstalling")
            shutil.rmtree(dest)
        dest.mkdir(parents=True, exist_ok=True)
        base = (base_url or f"{RELEASES}/{version}-stable").rstrip("/")
        names = asset_names(version, platform)
        tmp = dest / ".download"
        tmp.mkdir()
        try:
            editor_zip = tmp / str(names["zip"])
            download(f"{base}/{names['zip']}", editor_zip, pins[str(names["pin"])], str(names["zip"]))
            extract(editor_zip, {m: dest / m for m in names["members"]})  # type: ignore[union-attr]
            (dest / "_sc_").write_bytes(b"")  # self-contained mode
            binary = binary_path(dest, platform, version)
            if platform == "linux":
                binary.chmod(binary.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            tpz = tmp / f"Godot_v{version}-stable_export_templates.tpz"
            download(f"{base}/{tpz.name}", tpz, pins["GODOT_EXPORT_TEMPLATES_SHA512"], tpz.name)
            tpl_dir = dest / "editor_data" / "export_templates" / f"{version}.stable"
            extract(tpz, {m: tpl_dir / Path(m).name for m in template_members(threaded)})
            if (tpl_dir / "version.txt").read_text(encoding="utf-8").strip() != f"{version}.stable":
                raise InstallError(f"templates version.txt does not say {version}.stable")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        files = {p.relative_to(dest).as_posix(): sha256_file(p) for p in sorted(dest.rglob("*")) if p.is_file()}
        (dest / MANIFEST).write_text(json.dumps({
            "layout": pinlib.INSTALL_LAYOUT_VERSION, "godot_version": version, "platform": platform,
            "editor_sha512": pins[str(names["pin"])], "templates_sha512": pins["GODOT_EXPORT_TEMPLATES_SHA512"],
            "threaded_templates": threaded, "files": files, "installed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }, indent=2, sort_keys=True), encoding="utf-8", newline="\n")
    binary = binary_path(dest, platform, version)
    version_string = "unchecked"
    if not skip_version_check:
        res = run_logged([str(binary), "--version"], timeout=60)
        lines = [ln.strip() for ln in res.text.splitlines() if ln.strip()]
        version_string = lines[-1] if lines else ""
        if res.returncode != 0 or not re.fullmatch(rf"{re.escape(version)}\.stable\.official\.[0-9a-f]{{7,40}}", version_string):
            raise InstallError(f"`{binary.name} --version` printed {version_string!r} (exit {res.returncode}); expected {version}.stable.official.<hash>")
    return {"GODOT_BIN": str(binary), "GODOT_VERSION_STRING": version_string}


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["install", "verify", "print-bin"])
    ap.add_argument("--platform", choices=["linux", "windows"], required=True)
    ap.add_argument("--dest", type=Path, required=True)
    ap.add_argument("--with-threaded-templates", action="store_true")
    ap.add_argument("--github-env", action="store_true", help="append GODOT_BIN and GODOT_VERSION_STRING to $GITHUB_ENV")
    ap.add_argument("--base-url", help="mirror of the release asset folder (tests only; default: GitHub release of the pinned tag)")
    ap.add_argument("--pins", type=Path, default=pinlib.PIN_FILE)
    ap.add_argument("--skip-version-check", action="store_true", help="tests only")
    args = ap.parse_args(argv)
    try:
        pins = pinlib.load(args.pins)
        dest = args.dest.expanduser().resolve()
        if args.command == "print-bin":
            print(binary_path(dest, args.platform, pins["GODOT_VERSION"]))
            return 0
        if args.command == "verify":
            problems = verify_install(dest, args.platform, pins, args.with_threaded_templates)
            for p in problems:
                print(f"PROBLEM: {p}")
            print("verify:", "OK" if not problems else "FAILED")
            return 1 if problems else 0
        out = install(dest, args.platform, pins, args.with_threaded_templates, args.base_url, args.skip_version_check)
    except (InstallError, pinlib.PinError) as e:
        annotate("error", str(e), title="Godot install")
        return 1
    print(f"GODOT_BIN={out['GODOT_BIN']}")
    print(f"GODOT_VERSION_STRING={out['GODOT_VERSION_STRING']}")
    if args.github_env:
        for k, v in out.items():
            set_env(k, v)
    return 0


if __name__ == "__main__":
    sys.exit(main())
