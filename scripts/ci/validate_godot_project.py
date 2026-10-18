#!/usr/bin/env python3
"""Static validation of a Godot 4 project for the Shinobi Rush Web test-build pipeline (stdlib only).

No Godot binary needed. Rules and codes are documented in docs/development/GODOT_PROJECT_HANDOFF.md.
Exit codes: 0 = no errors | 1 = errors found | 2 = usage or internal error.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot_cfg as cfg  # noqa: E402
from ci_common import ALLOW_SELFTEST_ENV, annotate, is_selftest_name, sanitize, write_summary  # noqa: E402

WEB_PRESET_NAME = "Web"  # the export preset CI exports; case-sensitive
IGNORED_DIRS = {".git", ".godot", "node_modules", ".import"}
# Folders that hold no game resources. With a project at the repository root (the convention: section 11 of
# docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md) they need an empty .gdignore (PRJ012), otherwise Godot imports their
# images and exports them with the game. `assets/characters/player/references` holds the approved turnaround, which must
# never ship. `scripts/` as a whole is NOT here: the approved layout puts game code in scripts/player, scripts/combat, ...
# and a .gdignore hides a folder from load()/preload() and from the export (PRJ013). Only the CI tooling folder is ignored.
NON_GAME_DIRS = ("docs", "orders", "skills", "world", "scripts/ci", "assets/characters/player/references")
GAME_FILE_SUFFIXES = (".gd", ".tscn", ".tres", ".scn", ".res", ".gdshader", ".gdextension")
SECRET_KEY_RE = re.compile(r"(password|passphrase|secret|token|api[_-]?key|private[_-]?key|keystore|encryption_key)", re.I)
UID_RE = re.compile(r"^uid://[a-y0-9]+$")


@dataclass
class Finding:
    level: str  # error | warning | notice
    code: str
    message: str
    file: str = ""


class Report:
    def __init__(self) -> None:
        self.findings: List[Finding] = []

    def add(self, level: str, code: str, message: str, file: str = "") -> None:
        self.findings.append(Finding(level, code, message, file))

    @property
    def errors(self) -> List[Finding]:
        return [f for f in self.findings if f.level == "error"]

    def has_code(self, code: str) -> bool:
        return any(f.code == code for f in self.findings)


@dataclass
class ProjectInfo:
    main_res: str = ""  # res:// path of the resolved main scene ("" when unresolved)
    etc2_astc_import: bool = False


def parse_version(text: str) -> Optional[Tuple[int, int]]:
    m = re.match(r"^(\d+)\.(\d+)", text)
    return (int(m.group(1)), int(m.group(2))) if m else None


class UidIndex:
    """Lazy index of uid:// -> file built from .tscn/.tres headers and *.uid sidecar files (Godot 4.4+)."""

    def __init__(self, project: Path) -> None:
        self.project = project
        self._built = False
        self._map: Dict[str, Path] = {}
        self.has_binary_resources = False

    def _build(self) -> None:
        self._built = True
        header_uid = re.compile(r'uid="(uid://[a-y0-9]+)"')
        count = 0
        for root, dirs, files in os.walk(self.project, followlinks=False):
            dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]
            for name in files:
                count += 1
                if count > 50000:  # pathological project: stop indexing, unresolved uids degrade to warnings
                    self.has_binary_resources = True
                    return
                p = Path(root) / name
                lower = name.lower()
                if lower.endswith((".scn", ".res")):
                    self.has_binary_resources = True
                elif lower.endswith((".tscn", ".tres")):
                    try:
                        with p.open("r", encoding="utf-8", errors="replace") as fh:
                            first = fh.readline()
                    except OSError:
                        continue
                    m = header_uid.search(first)
                    if m:
                        self._map.setdefault(m.group(1), p)
                elif lower.endswith(".uid"):
                    try:
                        value = p.read_text(encoding="utf-8", errors="replace").strip()
                    except OSError:
                        continue
                    if UID_RE.match(value):
                        self._map.setdefault(value, p.with_suffix(""))  # foo.gd.uid -> foo.gd

    def resolve(self, uid: str) -> Optional[Path]:
        if not self._built:
            self._build()
        return self._map.get(uid)


def resolve_ref(project: Path, ref: str, uids: UidIndex) -> Tuple[str, Optional[Path]]:
    """Return (status, path); status is ok | missing | malformed | unverifiable."""
    ref = ref.lstrip("*")  # autoload singletons are written "*res://..."
    if ref.startswith("res://"):
        rel = ref[len("res://"):]
        if not rel or ".." in Path(rel).parts:
            return "malformed", None
        p = project / rel
        return ("ok", p) if p.is_file() else ("missing", p)
    if ref.startswith("uid://"):
        if not UID_RE.match(ref):
            return "malformed", None  # includes Godot's own "uid://<invalid>" placeholder
        p = uids.resolve(ref)
        if p is not None:
            return "ok", p
        return ("unverifiable" if uids.has_binary_resources else "missing"), None
    return "malformed", None


def validate_project_godot(project: Path, engine: Tuple[int, int], rep: Report) -> Optional[ProjectInfo]:
    try:
        sections = cfg.parse_config((project / "project.godot").read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, cfg.ConfigError) as e:
        rep.add("error", "PRJ001", f"project.godot cannot be read or parsed: {e}", "project.godot")
        return None
    app, rend = sections.get("application", {}), sections.get("rendering", {})
    uids = UidIndex(project)
    info = ProjectInfo(etc2_astc_import=bool(cfg.as_bool(rend.get("textures/vram_compression/import_etc2_astc"))))

    version = cfg.as_int(sections[""].get("config_version"))
    if version != 5:
        rep.add("error", "PRJ002", f"config_version must be 5 (Godot 4.x project format); found {version!r}.", "project.godot")

    main_ref = cfg.as_string(app.get("run/main_scene"))
    if not main_ref:
        rep.add("error", "PRJ003", "application/run/main_scene is not set. Set the main scene in Project Settings > Application > Run.", "project.godot")
    else:
        status, main_path = resolve_ref(project, main_ref, uids)
        if status == "missing":
            rep.add("error", "PRJ004", f"Main scene {main_ref!r} does not exist in the project.", "project.godot")
        elif status == "malformed":
            rep.add("error", "PRJ004", f"Main scene {main_ref!r} is not a valid res:// path or uid:// reference.", "project.godot")
        elif status == "unverifiable":
            rep.add("warning", "PRJ004", f"Main scene {main_ref!r} could not be resolved (the project contains binary .scn/.res files whose UIDs cannot be read statically).", "project.godot")
        elif main_path is not None and main_path.suffix.lower() not in (".tscn", ".scn"):
            rep.add("error", "PRJ004", f"Main scene {main_ref!r} resolves to {main_path.name}, which is not a .tscn/.scn scene.", "project.godot")
        elif main_path is not None:
            info.main_res = "res://" + main_path.relative_to(project).as_posix()

    # Renderer. The Web platform ALWAYS renders with Compatibility: the engine registers
    # rendering/renderer/rendering_method.web = "gl_compatibility" (its only allowed value), whatever the base key says.
    # So the desktop renderer is a product decision CI must not make (the GDD is "Windows PC first"): a different base
    # renderer is a warning, only a broken Web override is an error. The smoke test proves the runtime renderer.
    method = cfg.as_string(rend.get("renderer/rendering_method"))
    if method is None:
        rep.add("notice", "PRJ007", "rendering/renderer/rendering_method is not set: desktop builds use the engine default (forward_plus) while the Web export always uses gl_compatibility. Setting gl_compatibility project-wide is recommended so the browser test build matches what you ship.", "project.godot")
    elif method != "gl_compatibility":
        rep.add("warning", "PRJ005", f'Desktop renderer is {method!r}; the Web export is forced to gl_compatibility, so check 2D content in both renderers (the browser test build is not rendered like the desktop build).', "project.godot")
    web_method = cfg.as_string(rend.get("renderer/rendering_method.web"))
    if web_method is not None and web_method != "gl_compatibility":
        rep.add("error", "PRJ006", f'rendering/renderer/rendering_method.web must be "gl_compatibility" (the only renderer the Web platform supports); found {web_method!r}.', "project.godot")
    if is_selftest_name(cfg.as_string(app.get("config/name"))) and os.environ.get(ALLOW_SELFTEST_ENV) != "1":
        rep.add("error", "PRJ014", f"config/name {cfg.as_string(app.get('config/name'))!r} marks a generated pipeline self-test fixture. It must never be committed, exported as the game or deployed; delete it from the repository.", "project.godot")

    features = cfg.as_string_list(app.get("config/features"))
    ver = next((parse_version(f) for f in features if re.fullmatch(r"\d+\.\d+", f)), None)
    if ver is None:
        rep.add("warning", "PRJ008", 'config/features has no engine version tag (for example "4.7"); cannot compare with the pinned engine.', "project.godot")
    elif ver[0] != engine[0]:
        rep.add("error", "PRJ008", f"Project targets Godot {ver[0]}.{ver[1]} but the pipeline pins Godot {engine[0]}.{engine[1]}.x (the major version must match).", "project.godot")
    elif ver > engine:
        rep.add("error", "PRJ008", f"Project was saved with Godot {ver[0]}.{ver[1]}, newer than the pinned engine {engine[0]}.{engine[1]}.x. Re-save it with the pinned editor, or bump scripts/ci/godot-version.env deliberately.", "project.godot")
    elif ver < engine:
        rep.add("notice", "PRJ008", f"Project was last saved with Godot {ver[0]}.{ver[1]}; the pinned engine {engine[0]}.{engine[1]}.x will upgrade it on import.", "project.godot")
    if "C#" in features or "dotnet" in sections:
        rep.add("error", "PRJ009", "C#/.NET projects cannot be exported to Web in Godot 4, and the pipeline uses the standard (non-.NET) editor.", "project.godot")
    if any(f in features for f in ("Forward Plus", "Mobile")) and method == "gl_compatibility":
        rep.add("warning", "PRJ005", "config/features lists a non-Compatibility renderer tag although rendering_method is gl_compatibility; re-save the project with the Compatibility renderer.", "project.godot")

    for name, raw in sorted(sections.get("autoload", {}).items()):
        ref = cfg.as_string(raw)
        status = "malformed" if not ref else resolve_ref(project, ref, uids)[0]
        if status in ("missing", "malformed"):
            rep.add("error", "PRJ010", f"Autoload {name!r} points to {ref!r}, which does not exist or is malformed.", "project.godot")
        elif status == "unverifiable":
            rep.add("warning", "PRJ010", f"Autoload {name!r} ({ref!r}) could not be verified statically.", "project.godot")

    gdext = [p for p in project.rglob("*.gdextension") if not (set(p.relative_to(project).parts) & IGNORED_DIRS)]
    if gdext:
        rep.add("warning", "PRJ011", f"Found {len(gdext)} .gdextension file(s); the pipeline exports with variant/extensions_support=false, so they are not available in the Web build.", "project.godot")
    return info


def validate_presets(project: Path, info: ProjectInfo, rep: Report) -> None:
    path = project / "export_presets.cfg"
    if not path.is_file():
        rep.add("error", "EXP001", 'export_presets.cfg not found in the project directory. Create a Web preset named "Web" (docs/development/GODOT_PROJECT_HANDOFF.md).', "export_presets.cfg")
        return
    try:
        sections = cfg.parse_config(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, cfg.ConfigError) as e:
        rep.add("error", "EXP001", f"export_presets.cfg cannot be read or parsed: {e}", "export_presets.cfg")
        return

    for sec, kv in sections.items():  # secrets in ANY preset, any key
        for key, raw in kv.items():
            if SECRET_KEY_RE.search(key) and cfg.as_string(raw):
                rep.add("error", "EXP010", f"Possible secret committed in export_presets.cfg [{sec}] key {key!r}. Never commit credentials; use CI secrets or environment variables.", "export_presets.cfg")

    presets = {m.group(1): kv for sec, kv in sections.items() if (m := re.fullmatch(r"preset\.(\d+)", sec))}
    web = {idx: kv for idx, kv in presets.items() if cfg.as_string(kv.get("platform")) == "Web"}
    if not web:
        rep.add("error", "EXP002", 'No export preset with platform "Web" exists.', "export_presets.cfg")
        return
    named = {idx: kv for idx, kv in web.items() if cfg.as_string(kv.get("name")) == WEB_PRESET_NAME}
    if not named:
        names = ", ".join(repr(cfg.as_string(kv.get("name"))) for kv in web.values())
        rep.add("error", "EXP003", f'CI exports the Web preset named "{WEB_PRESET_NAME}" (case-sensitive); found Web presets: {names}. Rename one.', "export_presets.cfg")
        return
    if len(named) > 1:
        rep.add("error", "EXP004", f'More than one Web preset is named "{WEB_PRESET_NAME}".', "export_presets.cfg")
        return
    idx, kv = next(iter(named.items()))
    opts = sections.get(f"preset.{idx}.options", {})
    where = f"[preset.{idx}]"
    if not opts:
        rep.add("error", "EXP014", f"Preset {where} has no [preset.{idx}.options] section, so it looks like a placeholder. Re-create it with Project > Export > Add > Web.", "export_presets.cfg")
        return

    threads = cfg.as_bool(opts.get("variant/thread_support"))
    if threads is None:
        rep.add("error", "EXP005", f"variant/thread_support is not set explicitly in {where}; set it to false so a future engine default change cannot enable threads.", "export_presets.cfg")
    elif threads:
        rep.add("error", "EXP005", "variant/thread_support is true. Threaded Web exports need cross-origin isolation headers (COOP/COEP), which GitHub Pages cannot send. Set Thread Support = Off.", "export_presets.cfg")
    ext = cfg.as_bool(opts.get("variant/extensions_support"))
    if ext is None or ext:
        rep.add("error", "EXP006", f"variant/extensions_support must be explicitly false in {where} (GDExtension needs the dlink templates, which the pipeline does not install).", "export_presets.cfg")

    export_path = cfg.as_string(kv.get("export_path")) or ""
    if not export_path:
        rep.add("error", "EXP007", f'export_path is empty in {where}; use for example "exports/web/index.html" (the layout of docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md; the repository .gitignore covers it).', "export_presets.cfg")
    else:
        bad = export_path.startswith(("/", "\\", "res://", "user://")) or re.match(r"^[A-Za-z]:", export_path) or ".." in Path(export_path.replace("\\", "/")).parts
        if bad:
            rep.add("error", "EXP007", f"export_path {export_path!r} must be a relative path inside the project (no drive letter, no '..').", "export_presets.cfg")
        elif not export_path.lower().endswith(".html"):
            rep.add("error", "EXP007", f"export_path {export_path!r} must end with .html.", "export_presets.cfg")

    flt = cfg.as_string(kv.get("export_filter"))
    files = cfg.as_string_list(kv.get("export_files"))
    if flt not in ("all_resources", "scenes", "resources", "exclude", "customized"):
        rep.add("warning", "EXP008", f"Unknown export_filter {flt!r}.", "export_presets.cfg")
    elif flt == "scenes" and (not files or (info.main_res and info.main_res not in files)):
        rep.add("error", "EXP008", f'export_filter is "scenes" but export_files does not include the main scene {info.main_res!r}.', "export_presets.cfg")
    elif flt == "exclude" and info.main_res and info.main_res in files:
        rep.add("error", "EXP008", f'export_filter is "exclude" and the main scene {info.main_res!r} is excluded.', "export_presets.cfg")
    elif flt == "customized":
        rep.add("warning", "EXP008", 'export_filter "customized" is not validated by the pipeline.', "export_presets.cfg")
    for pat in [p.strip() for p in (cfg.as_string(kv.get("exclude_filter")) or "").split(",") if p.strip()]:
        if info.main_res and (fnmatch.fnmatchcase(info.main_res, pat) or fnmatch.fnmatchcase(info.main_res, "res://" + pat.lstrip("/"))):
            rep.add("error", "EXP008", f"exclude_filter pattern {pat!r} excludes the main scene {info.main_res!r}.", "export_presets.cfg")

    if cfg.as_bool(kv.get("encrypt_pck")) or cfg.as_bool(kv.get("encrypt_directory")):
        rep.add("error", "EXP009", "PCK encryption is enabled; the pipeline publishes a public test build and must not need an encryption key.", "export_presets.cfg")
    if cfg.as_string(kv.get("script_encryption_key")):
        rep.add("error", "EXP009", "script_encryption_key is set in export_presets.cfg; never commit encryption keys.", "export_presets.cfg")
    if cfg.as_bool(opts.get("progressive_web_app/enabled")):
        rep.add("warning", "EXP012", "PWA is enabled: the service worker caches builds aggressively, so testers may see stale versions. The smoke test blocks service workers and does not test PWA behaviour.", "export_presets.cfg")
    if cfg.as_bool(opts.get("vram_texture_compression/for_mobile")) and not info.etc2_astc_import:
        rep.add("error", "EXP013", "vram_texture_compression/for_mobile is true but rendering/textures/vram_compression/import_etc2_astc is not true in project.godot.", "export_presets.cfg")
    shell = cfg.as_string(opts.get("html/custom_html_shell")) or ""
    if shell:
        if resolve_ref(project, shell, UidIndex(project))[0] != "ok":
            rep.add("error", "EXP014", f"html/custom_html_shell {shell!r} does not exist.", "export_presets.cfg")
        else:
            rep.add("notice", "EXP014", 'A custom HTML shell is used; keep <canvas id="canvas"> and the #status overlay, or set canvas_selector in scripts/ci/smoke/smoke-config.json.', "export_presets.cfg")
    for key in ("custom_template/debug", "custom_template/release"):
        if cfg.as_string(opts.get(key)):
            rep.add("error", "EXP015", f"{key} is set; custom export templates bypass the pinned, checksum-verified templates.", "export_presets.cfg")


def validate(project: Path, engine: Tuple[int, int], repo_root: Optional[Path] = None) -> Report:
    rep = Report()
    if not (project / "project.godot").is_file():
        rep.add("error", "PRJ001", f"{project} does not contain project.godot.", "project.godot")
        return rep
    info = validate_project_godot(project, engine, rep)
    if info is not None:
        validate_presets(project, info, rep)
    check_gdignore(project, rep)
    if repo_root is not None and project.resolve() == repo_root.resolve():  # PRJ012: root project scans the whole repo
        missing = [d for d in NON_GAME_DIRS if (project / d).is_dir() and not (project / d / ".gdignore").exists()]
        if missing:
            rep.add("warning", "PRJ012", "The Godot project is the repository root, so Godot will import-scan folders that hold no game resources and may export their images (the approved turnaround in assets/characters/player/references must never ship). Add an empty .gdignore file to: " + ", ".join(missing) + ". (Do NOT add one to scripts/ itself: game code lives in scripts/player, scripts/combat, ... and a .gdignore hides it from load(), preload() and the export.)", "project.godot")
    return rep


def check_gdignore(project: Path, rep: Report) -> None:
    """PRJ013: a .gdignore hides its whole folder from the editor scan, load()/preload() and the export. Outside the
    known non-game folders that silently removes game code from the build while the validators still pass."""
    scanned = 0
    for root, dirs, files in os.walk(project, followlinks=False):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not d.startswith(".")]
        scanned += len(files)
        if scanned > 100_000:
            return  # pathological tree: stop rather than hang CI
        if ".gdignore" not in files:
            continue
        here = Path(root)
        rel = "." if here == project else here.relative_to(project).as_posix()
        if any(rel == d or rel.startswith(d + "/") for d in NON_GAME_DIRS):
            continue
        hidden = [p.relative_to(project).as_posix() for p in sorted(here.rglob("*")) if p.is_file() and p.suffix.lower() in GAME_FILE_SUFFIXES
                  and not (set(p.relative_to(project).parts) & IGNORED_DIRS)]
        if hidden:
            where = "the project root" if rel == "." else f"{rel}/"
            rep.add("error", "PRJ013", f".gdignore in {where} hides {len(hidden)} game file(s) from the import scan, load()/preload() and the export, for example res://{hidden[0]}. Remove the .gdignore or move the files. (Only {', '.join(NON_GAME_DIRS)} should be ignored.)", rel + "/.gdignore" if rel != "." else ".gdignore")


def engine_from_pins() -> Tuple[int, int]:
    pins = Path(__file__).resolve().with_name("godot-version.env")
    for line in pins.read_text(encoding="utf-8").splitlines():
        if line.startswith("GODOT_VERSION="):
            parsed = parse_version(line.split("=", 1)[1].strip())
            if parsed:
                return parsed
    raise SystemExit("GODOT_VERSION not found in scripts/ci/godot-version.env")


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--project", required=True, help="directory containing project.godot")
    ap.add_argument("--engine-version", help="override the pinned engine version (default: GODOT_VERSION from scripts/ci/godot-version.env)")
    ap.add_argument("--repo-root", help="repository root (enables the PRJ012 .gdignore check); default: two levels above this script")
    ap.add_argument("--json-out")
    ap.add_argument("--github", action="store_true", help="emit workflow annotations and a step summary")
    args = ap.parse_args(argv)
    engine = parse_version(args.engine_version) if args.engine_version else engine_from_pins()
    if engine is None:
        print(f"invalid --engine-version {args.engine_version!r}", file=sys.stderr)
        return 2
    repo_root = Path(args.repo_root) if args.repo_root else Path(__file__).resolve().parents[2]
    rep = validate(Path(args.project).resolve(), engine, repo_root)
    for f in rep.findings:
        if args.github:
            annotate({"error": "error", "warning": "warning", "notice": "notice"}[f.level], f.message, title=f.code, file=f.file)
        else:
            print(f"{f.level.upper():7} {f.code} {f.file}: {sanitize(f.message, 800)}")
    warnings = sum(f.level == "warning" for f in rep.findings)
    verdict = "FAIL" if rep.errors else "PASS"
    print(f"validate_godot_project: {verdict} - {len(rep.errors)} error(s), {warnings} warning(s) (engine {engine[0]}.{engine[1]}.x)")
    if args.json_out:
        Path(args.json_out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json_out).write_text(json.dumps([asdict(f) for f in rep.findings], indent=2), encoding="utf-8", newline="\n")
    if args.github:
        rows = "".join(f"| {f.level} | {f.code} | {sanitize(f.message, 300).replace('|', '/')} |\n" for f in rep.findings) or "| - | - | no findings |\n"
        write_summary(f"## Godot project validation: {verdict}\n\n| Level | Code | Message |\n| --- | --- | --- |\n{rows}")
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
