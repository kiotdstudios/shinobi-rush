#!/usr/bin/env python3
"""Source of the headless resource walker that `godot_ci.py validate-resources` runs inside Godot (stdlib only).

The pipeline commits NO GDScript file. The walker is kept here as text and written to a temporary folder OUTSIDE the
project every time it runs (write_walker refuses a destination inside the project), so it can never become part of
res://, never needs a .gdignore, and never shows up as a game script. The script loads every script, scene and resource
that Godot itself would see and fails (exit code 1) when one cannot be loaded or has a missing dependency.

Folders that are NOT walked (a project at the repository root shares its tree with folders that hold no game resources):
  * a folder that contains a .gdignore file or its own project.godot (Godot itself ignores those subtrees)
  * a folder whose name starts with "." (.git, .github, .godot, .agents, ...) and every node_modules folder
  * generated Web export output: res://exports and res://build/web
  * the CI tooling: res://scripts/ci (also while it has no .gdignore yet)
Output contract (godot_ci.py parses it):
  VALIDATE_RESOURCES: scripts=N scenes=N resources=N failures=N
  VALIDATE_RESOURCES_SKIPPED: <sorted res:// folders that were not walked>
  VALIDATE_RESOURCES_FAIL: <reason>            (stderr, one line per failure)
All GDScript indentation uses explicit "\\t" escapes on purpose (tabs typed in editors and tools get lost).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

WALKER_FILE_NAME = "validate_resources.gd"
SKIP_DIR_NAMES = ("node_modules",)
SKIP_DIR_PATHS = ("res://exports", "res://build/web", "res://scripts/ci")

WALKER_LINES = [
    "extends SceneTree",
    "## CI helper, written to a temporary folder outside the project by scripts/ci/godot_walker.py (no .gd file is committed).",
    "## Loads every script, scene and resource under res:// and fails (exit code 1) when anything cannot be loaded or has",
    "## a missing dependency.",
    "##",
    "## Usage: godot --headless --path <project_dir> --script <path of this generated file>",
    "##",
    "## Not walked: a folder with a .gdignore file or its own project.godot (Godot ignores those subtrees), a folder whose",
    '## name starts with "." and node_modules, generated export output (res://exports, res://build/web) and the CI tooling',
    "## (res://scripts/ci, also while it has no .gdignore).",
    "",
    f"const SKIP_DIR_NAMES := {json.dumps(list(SKIP_DIR_NAMES))}",
    f"const SKIP_DIR_PATHS := {json.dumps(list(SKIP_DIR_PATHS))}",
    'const SCRIPT_EXTS := ["gd"]',
    'const SCENE_EXTS := ["tscn", "scn"]',
    'const RESOURCE_EXTS := ["tres", "res"]',
    "",
    "var _failures: Array[String] = []",
    "var _skipped: Array[String] = []",
    'var _counts := {"scripts": 0, "scenes": 0, "resources": 0}',
    "",
    "",
    "func _initialize() -> void:",
    '\t_scan_dir("res://")',
    "\t_skipped.sort()",
    '\tprint("VALIDATE_RESOURCES: scripts=%d scenes=%d resources=%d failures=%d" % [',
    '\t\t_counts["scripts"], _counts["scenes"], _counts["resources"], _failures.size()])',
    '\tprint("VALIDATE_RESOURCES_SKIPPED: " + ", ".join(_skipped))',
    "\tfor failure in _failures:",
    '\t\tprinterr("VALIDATE_RESOURCES_FAIL: " + failure)',
    "\tquit(1 if _failures.size() > 0 else 0)",
    "",
    "",
    "func _is_skipped(full: String, entry: String) -> bool:",
    '\tif entry.begins_with(".") or entry in SKIP_DIR_NAMES or full in SKIP_DIR_PATHS:',
    "\t\treturn true",
    '\treturn FileAccess.file_exists(full.path_join("project.godot")) or FileAccess.file_exists(full.path_join(".gdignore"))',
    "",
    "",
    "func _scan_dir(dir_path: String) -> void:",
    "\tvar dir := DirAccess.open(dir_path)",
    "\tif dir == null:",
    '\t\t_failures.append("cannot open directory " + dir_path)',
    "\t\treturn",
    "\t# Hidden folders (.git, .godot, .agents, ...) are listed on every platform, so the skip rule below is deterministic.",
    "\tdir.include_hidden = true",
    "\tdir.list_dir_begin()",
    "\tvar entry := dir.get_next()",
    '\twhile entry != "":',
    "\t\tvar full := dir_path.path_join(entry)",
    "\t\tif dir.current_is_dir():",
    "\t\t\tif _is_skipped(full, entry):",
    "\t\t\t\t_skipped.append(full)",
    "\t\t\telse:",
    "\t\t\t\t_scan_dir(full)",
    "\t\telse:",
    "\t\t\t_check_file(full)",
    "\t\tentry = dir.get_next()",
    "\tdir.list_dir_end()",
    "",
    "",
    "func _check_file(path: String) -> void:",
    "\tvar ext := path.get_extension().to_lower()",
    "\tif ext in SCRIPT_EXTS:",
    '\t\t_counts["scripts"] += 1',
    "\t\t_check_script(path)",
    "\telif ext in SCENE_EXTS:",
    '\t\t_counts["scenes"] += 1',
    "\t\t_check_resource(path, true)",
    "\telif ext in RESOURCE_EXTS:",
    '\t\t_counts["resources"] += 1',
    "\t\t_check_resource(path, false)",
    "",
    "",
    "func _check_script(path: String) -> void:",
    '\tvar script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)',
    "\tif script == null:",
    '\t\t_failures.append("script failed to load/compile: " + path)',
    "\t\treturn",
    "\tif script is GDScript and not script.can_instantiate() and not script.is_abstract():",
    "\t\t# Scripts that only contain static members still report can_instantiate() == true.",
    '\t\t_failures.append("script cannot be instantiated (compile problem?): " + path)',
    "",
    "",
    "func _check_resource(path: String, is_scene: bool) -> void:",
    '\tvar res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)',
    "\tif res == null:",
    '\t\t_failures.append("resource failed to load: " + path)',
    "\t\treturn",
    "\tif is_scene and res is PackedScene and not res.can_instantiate():",
    '\t\t_failures.append("scene cannot be instantiated: " + path)',
    "\tfor dep in ResourceLoader.get_dependencies(path):",
    '\t\t# Dependency strings look like "uid://...::Type::res://path" or just "res://path".',
    '\t\tvar parts := String(dep).split("::")',
    "\t\tvar dep_path := parts[parts.size() - 1]",
    '\t\tif dep_path.begins_with("res://") and not ResourceLoader.exists(dep_path):',
    '\t\t\t_failures.append("missing dependency %s referenced by %s" % [dep_path, path])',
]


def walker_source() -> str:
    """The GDScript text: LF line endings, tab indentation, no BOM, trailing newline."""
    return "\n".join(WALKER_LINES) + "\n"


def write_walker(dest_dir: Path, project: Path) -> Path:
    """Write the walker into dest_dir (created if needed) and return its path.

    Refuses a destination inside (or equal to) the project: CI must never write into res://."""
    dest, proj = Path(dest_dir).resolve(), Path(project).resolve()
    if dest == proj or proj in dest.parents:
        raise ValueError(f"refusing to write the walker script inside the project: {dest} is under {proj}")
    dest.mkdir(parents=True, exist_ok=True)
    path = dest / WALKER_FILE_NAME
    path.write_bytes(walker_source().encode("utf-8"))  # bytes => LF, no BOM
    return path


if __name__ == "__main__":
    sys.stdout.write(walker_source())  # debugging aid: show the script that would be written
