#!/usr/bin/env python3
"""Find the Godot project at RUNTIME (no hard-coded path) and say loudly when there is none (stdlib only).

Used by the required check `validate-orders-and-project` and by the `detect` job of godot-ci.yml.
  * GODOT_PROJECT_DIR (env, normally the repository variable of the same name) selects the project explicitly.
  * Otherwise the repository is searched for project.godot, ignoring .git, .godot, node_modules and .import.
  * Projects nested inside another project's folder are ignored (Godot itself ignores them).
Exit codes: 0 = none or exactly one project (none is reported as NOT VALIDATED, never as success of the game)
            1 = ambiguous (several projects, no override) or invalid GODOT_PROJECT_DIR | 2 = internal error
Outputs (GITHUB_OUTPUT): project_found=true|false, project_dir=<posix path relative to the repo root, "." = root>,
export_presets_present=true|false
"""
from __future__ import annotations

import os
import sys
from pathlib import Path, PurePosixPath
from typing import List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ci_common import annotate, sanitize, set_output, write_summary  # noqa: E402

IGNORED_DIRS = {".git", ".godot", "node_modules", ".import"}
HANDOFF = "docs/development/GODOT_PROJECT_HANDOFF.md"


def find_projects(root: Path) -> List[Path]:
    """Directories containing project.godot, relative to root, nested ones removed, sorted."""
    found: List[Path] = []
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = sorted(d for d in dirnames if d not in IGNORED_DIRS)
        if "project.godot" in filenames:
            found.append(Path(dirpath).relative_to(root))
    top = [p for p in found if not any(q != p and (q == Path(".") or q in p.parents) for q in found)]
    return sorted(top)


def resolve_override(root: Path, value: str) -> Path:
    value = value.strip()
    if not value or "\\" in value or "\n" in value or value.startswith("/") or (len(value) > 1 and value[1] == ":"):
        raise ValueError(f"GODOT_PROJECT_DIR={value!r} must be a relative POSIX path inside the repository ('.' is the repository root, the convention of this repository)")
    candidate = (root / value).resolve()
    if root.resolve() != candidate and root.resolve() not in candidate.parents:
        raise ValueError(f"GODOT_PROJECT_DIR={value!r} points outside the repository")
    if not (candidate / "project.godot").is_file():
        raise ValueError(f"GODOT_PROJECT_DIR={value!r} does not contain project.godot")
    return candidate.relative_to(root.resolve())


def discover(root: Path, override: str = "") -> Tuple[str, Optional[Path], List[Path]]:
    """Returns (status, project_dir, candidates); status is none | one | ambiguous."""
    if override.strip():
        return "one", resolve_override(root, override), []
    found = find_projects(root)
    if not found:
        return "none", None, []
    if len(found) == 1:
        return "one", found[0], found
    return "ambiguous", None, found


def posix(p: Path) -> str:
    return PurePosixPath(*p.parts).as_posix() if p.parts else "."


def main() -> int:
    root = Path(os.environ.get("GITHUB_WORKSPACE") or Path(__file__).resolve().parents[2])
    try:
        status, project, candidates = discover(root, os.environ.get("GODOT_PROJECT_DIR", ""))
    except ValueError as e:
        annotate("error", str(e), title="Invalid GODOT_PROJECT_DIR")
        write_summary(f"## Godot project discovery: FAILED\n\n{sanitize(str(e))}\n")
        return 1
    if status == "ambiguous":
        listing = ", ".join(posix(c) for c in candidates)
        annotate("error", f"Found {len(candidates)} Godot projects ({listing}). Set the repository variable GODOT_PROJECT_DIR to the one to build.", title="Multiple Godot projects")
        write_summary(f"## Godot project discovery: FAILED\n\nMultiple `project.godot` files: {sanitize(listing)}. Set `GODOT_PROJECT_DIR`.\n")
        return 1
    if status == "none":
        set_output("project_found", "false")
        set_output("project_dir", "")
        set_output("export_presets_present", "false")
        annotate("warning", f"No project.godot exists in this repository. Godot import, scene/script validation, Web export, deployment and the live browser smoke test were NOT run. A green check here does NOT mean the game builds or is deployed. The project (at the repository root) is delivered by stage 2 of Order 01; conventions and checklist: {HANDOFF}", title="Godot project NOT FOUND - NOT VALIDATED - NOT DEPLOYED")
        write_summary("## :warning: Godot project NOT FOUND\n\n**NOT VALIDATED. NOT DEPLOYED.** There is no `project.godot` in this repository, so nothing Godot-related was run. "
                      f"This check is green only because there is nothing to validate; it is not evidence that the game works.\n\nThe project is delivered by stage 2 of Order 01 (at the repository root). Conventions and checklist: [{HANDOFF}]({'../../' + HANDOFF}).\n")
        return 0
    assert project is not None
    presets = (root / project / "export_presets.cfg").is_file()
    set_output("project_found", "true")
    set_output("project_dir", posix(project))
    set_output("export_presets_present", "true" if presets else "false")
    print(f"Found Godot project: {posix(project)}")
    annotate("notice", f"Godot project at '{posix(project)}'. Import, validation, Web export and deployment are checked by the 'Godot CI' workflow (job godot-ci-gate).", title="Godot project found")
    if not presets:
        annotate("warning", "Godot project exists but export_presets.cfg is missing. Live Web export is NOT ready.", title="export_presets.cfg missing")
    write_summary(f"## Godot project discovery\n\nProject: `{sanitize(posix(project))}`; export_presets.cfg: {'present' if presets else '**MISSING (Web export not ready)**'}.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
