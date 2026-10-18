"""Shared test setup: make the scripts in scripts/ci importable and expose repository paths."""
import sys
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = CI_DIR.parents[1]
if str(CI_DIR) not in sys.path:
    sys.path.insert(0, str(CI_DIR))

# Real Godot 4.7.2 output captured while designing the pipeline (do not "tidy": these are test data).
GODOT_PARSE_ERROR_IMPORT = (
    "Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org\n"
    "[ DONE ] reimport\n"
    "SCRIPT ERROR: Parse Error: Expected indented block after function declaration.\n"
    "   at: GDScript::reload (res://main.gd:3)\n"
    'ERROR: Failed to load script "res://main.gd" with error "Parse error".\n'
    "   at: load (modules/gdscript/gdscript_resource_format.cpp:46)\n"
)
GODOT_MISSING_TEMPLATES = (
    'ERROR: Cannot export project with preset "Web" due to configuration errors:\n'
    "No export template found at the expected path:\n"
    "c:/x/editor_data/export_templates/4.7.2.stable/web_nothreads_debug.zip\n"
    "   at: _fs_changed (editor/editor_node.cpp:1401)\n"
    'ERROR: Project export for preset "Web" failed.\n'
    "   at: _fs_changed (editor/editor_node.cpp:1417)\n"
)
GODOT_CLEAN_IMPORT = (
    "Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org\n\n"
    "[   0% ] first_scan_filesystem | Started Project initialization (5 steps)\n"
    "[ DONE ] first_scan_filesystem\n"
    "[ DONE ] reimport\n"
)
