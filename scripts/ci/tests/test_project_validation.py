import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import REPO_ROOT

import ci_common
import godot_cfg as cfg
import godot_walker as gw
import selftest_project as sp
import validate_godot_project as v

ENGINE = (4, 7)
REAL_PROJECT_GODOT = (
    "; Engine configuration file.\n"
    "config_version=5\n"
    "[application]\n"
    'config/name="X"\n'
    'config/description="line one\nline \\"two\\" = x; y"\n'
    'run/main_scene="uid://b2s4t6u8v0w1x"\n'
    'config/features=PackedStringArray("4.7", "GL Compatibility")\n'
    "[input]\n"
    "move_left={\n"
    '"deadzone": 0.2,\n'
    '"events": [Object(InputEventKey,"resource_local_to_scene":false,"physical_keycode":65,"script":null)\n'
    ', Object(InputEventJoypadMotion,"axis":0,"axis_value":-1.0,"script":null)\n'
    "]\n"
    "}\n"
    "[rendering]\n"
    'renderer/rendering_method="gl_compatibility"\n'
)


class ConfigParserTests(unittest.TestCase):
    def test_multiline_strings_and_dictionaries(self):
        c = cfg.parse_config(REAL_PROJECT_GODOT)
        self.assertEqual(cfg.as_int(c[""]["config_version"]), 5)
        self.assertEqual(cfg.as_string(c["application"]["config/description"]), 'line one\nline "two" = x; y')
        self.assertEqual(cfg.as_string_list(c["application"]["config/features"]), ["4.7", "GL Compatibility"])
        self.assertIn("InputEventJoypadMotion", c["input"]["move_left"])
        self.assertEqual(cfg.as_string(c["rendering"]["renderer/rendering_method"]), "gl_compatibility")

    def test_crlf_and_bom(self):
        a = cfg.parse_config(REAL_PROJECT_GODOT)
        b = cfg.parse_config("\ufeff" + REAL_PROJECT_GODOT.replace("\n", "\r\n"))
        self.assertEqual({k: list(x) for k, x in a.items()}, {k: list(x) for k, x in b.items()})

    def test_unterminated_value_is_an_error(self):
        with self.assertRaises(cfg.ConfigError):
            cfg.parse_config('[a]\nkey=PackedStringArray("x"\n')


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="vgp-"))
        env = mock.patch.dict(os.environ, {ci_common.ALLOW_SELFTEST_ENV: "1"})  # generated fixtures carry the self-test name (PRJ014)
        env.start()
        self.addCleanup(env.stop)
        self.base = sp.write_project(self.tmp / "base", "good")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def codes(self, project):
        return sorted((f.level, f.code) for f in v.validate(project, ENGINE).findings)

    def edit(self, name, rel, fn):
        d = self.tmp / name
        shutil.copytree(self.base, d)
        p = d / rel
        p.write_bytes(fn(p.read_text(encoding="utf-8")).encode("utf-8"))
        return d

    def test_good_fixture_is_clean(self):
        self.assertEqual(self.codes(self.base), [])

    def test_every_generated_negative_variant_is_caught_by_its_rule(self):
        for variant, code in (("threads_enabled", "EXP005"), ("missing_main_scene", "PRJ004"), ("no_main_scene", "PRJ003"), ("web_renderer_override", "PRJ006"), ("gdignore_scripts", "PRJ013")):
            with self.subTest(variant=variant):
                d = sp.write_project(self.tmp / variant, variant)
                self.assertTrue(v.validate(d, ENGINE).has_code(code))

    def test_uid_main_scene_is_resolved_from_the_scene_header(self):
        d = self.edit("uid", "project.godot", lambda t: t.replace('run/main_scene="res://main.tscn"', 'run/main_scene="uid://b2s4t6u8v0w1x"'))
        scene = d / "main.tscn"
        scene.write_bytes(b'[gd_scene load_steps=2 format=3 uid="uid://b2s4t6u8v0w1x"]\n' + scene.read_bytes().split(b"\n", 1)[1])
        self.assertEqual(self.codes(d), [])
        bad = self.edit("uid_bad", "project.godot", lambda t: t.replace('run/main_scene="res://main.tscn"', 'run/main_scene="uid://<invalid>"'))
        self.assertEqual(self.codes(bad), [("error", "PRJ004")])

    def test_engine_version_comparison(self):
        for feature, expect in (("4.8", [("error", "PRJ008")]), ("4.5", [("notice", "PRJ008")]), ("5.0", [("error", "PRJ008")]), ("3.5", [("error", "PRJ008")]), ("4.7", [])):
            with self.subTest(feature=feature):
                d = self.edit(f"v{feature}", "project.godot", lambda t, f=feature: t.replace('PackedStringArray("4.7"', f'PackedStringArray("{f}"'))
                self.assertEqual(self.codes(d), expect)

    def test_csharp_autoload_and_secret_rules(self):
        self.assertEqual(self.codes(self.edit("cs", "project.godot", lambda t: t.replace('"GL Compatibility")', '"C#", "GL Compatibility")'))), [("error", "PRJ009")])
        self.assertEqual(self.codes(self.edit("al", "project.godot", lambda t: t + '\n[autoload]\n\nGone="*res://gone.gd"\n')), [("error", "PRJ010")])
        secret = self.edit("sec", "export_presets.cfg", lambda t: t + '\n[preset.1]\n\nname="Android"\nplatform="Android"\n\n[preset.1.options]\n\nkeystore/release_password="hunter2"\n')
        self.assertEqual(self.codes(secret), [("error", "EXP010")])

    def test_export_preset_rules(self):
        cases = {
            "missing file": (None, "EXP001"),
            "not web": (lambda t: t.replace('platform="Web"', 'platform="Windows Desktop"'), "EXP002"),
            "renamed": (lambda t: t.replace('name="Web"', 'name="Browser"'), "EXP003"),
            "threads implicit": (lambda t: t.replace("variant/thread_support=false\n", ""), "EXP005"),
            "extensions on": (lambda t: t.replace("variant/extensions_support=false", "variant/extensions_support=true"), "EXP006"),
            "absolute path": (lambda t: t.replace('export_path="exports/web/index.html"', 'export_path="C:/out/index.html"'), "EXP007"),
            "not html": (lambda t: t.replace("index.html", "index.zip"), "EXP007"),
            "scenes filter": (lambda t: t.replace('export_filter="all_resources"', 'export_filter="scenes"\nexport_files=PackedStringArray("res://other.tscn")'), "EXP008"),
            "exclude main": (lambda t: t.replace('exclude_filter=""', 'exclude_filter="*.tscn"'), "EXP008"),
            "encrypted": (lambda t: t.replace("encrypt_pck=false", "encrypt_pck=true"), "EXP009"),
            "custom template": (lambda t: t.replace('custom_template/debug=""', 'custom_template/debug="C:/x.zip"'), "EXP015"),
            "no options (placeholder)": (lambda t: t.split("[preset.0.options]")[0], "EXP014"),
        }
        for name, (fn, code) in cases.items():
            with self.subTest(name=name):
                if fn is None:
                    d = self.tmp / "nopresets"
                    shutil.copytree(self.base, d)
                    (d / "export_presets.cfg").unlink()
                else:
                    d = self.edit(name.replace(" ", "_"), "export_presets.cfg", fn)
                self.assertTrue(v.validate(d, ENGINE).has_code(code), v.validate(d, ENGINE).findings)

    def test_pwa_is_only_a_warning(self):
        d = self.edit("pwa", "export_presets.cfg", lambda t: t.replace("progressive_web_app/enabled=false", "progressive_web_app/enabled=true"))
        self.assertEqual(self.codes(d), [("warning", "EXP012")])

    def test_root_project_without_gdignore_warns_only_for_non_game_folders(self):
        (self.base / "docs").mkdir()
        (self.base / "scripts" / "player").mkdir(parents=True)
        (self.base / "scripts" / "player" / "player_controller.gd").write_text("extends Node\n")
        (self.base / "scripts" / "ci").mkdir(parents=True)
        (self.base / "assets" / "characters" / "player" / "references").mkdir(parents=True)
        (self.base / "assets" / "characters" / "player" / "placeholder").mkdir(parents=True)
        rep = v.validate(self.base, ENGINE, repo_root=self.base)
        warned = [f.message for f in rep.findings if f.code == "PRJ012"]
        self.assertEqual(len(warned), 1)
        listed = warned[0].split("Add an empty .gdignore file to: ")[1].split(". (")[0]
        self.assertEqual(listed, "docs, scripts/ci, assets/characters/player/references",
                         "never advises ignoring scripts/ or assets/ as a whole: game code lives in scripts/player, scripts/combat, ... and game art in assets/characters/player/placeholder")
        (self.base / "docs" / ".gdignore").write_text("")
        (self.base / "scripts" / "ci" / ".gdignore").write_text("")
        (self.base / "assets" / "characters" / "player" / "references" / ".gdignore").write_text("")
        rep = v.validate(self.base, ENGINE, repo_root=self.base)
        self.assertEqual([f.code for f in rep.findings], [], "game code in scripts/player and game art in assets/.../placeholder need no .gdignore")

    def test_the_non_game_folder_list_is_the_same_in_the_validator_and_the_generator(self):
        """Stage 2 adds these .gdignore files (the handoff document lists them; test_workflow_lint checks the document)."""
        self.assertEqual(v.NON_GAME_DIRS, ("docs", "orders", "skills", "world", "scripts/ci", "assets/characters/player/references"))
        self.assertEqual(set(sp.NON_GAME_FOLDERS) | {"scripts/ci", sp.REFERENCES_FOLDER}, set(v.NON_GAME_DIRS))

    def test_a_gdignore_next_to_game_art_is_an_error_but_the_references_folder_may_have_one(self):
        placeholder = self.base / "assets" / "characters" / "player" / "placeholder"
        placeholder.mkdir(parents=True)
        (placeholder / "player.tres").write_text("[gd_resource type=\"Resource\" format=3]\n")
        (placeholder / ".gdignore").write_text("")
        refs = self.base / "assets" / "characters" / "player" / "references"
        refs.mkdir(parents=True)
        (refs / ".gdignore").write_text("")
        rep = v.validate(self.base, ENGINE)
        self.assertEqual([(f.level, f.code) for f in rep.findings], [("error", "PRJ013")])
        self.assertIn("assets/characters/player/placeholder", rep.findings[0].file)

    def test_gdignore_that_hides_game_code_is_an_error(self):
        scripts = self.base / "scripts" / "player"
        scripts.mkdir(parents=True)
        (scripts / "player_controller.gd").write_text("extends Node\n")
        (self.base / "scripts" / ".gdignore").write_text("")
        rep = v.validate(self.base, ENGINE)
        self.assertEqual([(f.level, f.code) for f in rep.findings], [("error", "PRJ013")])
        self.assertIn("scripts/player/player_controller.gd", rep.findings[0].message)

    def test_gdignore_is_fine_in_non_game_folders_and_in_empty_folders(self):
        for folder in ("docs", "orders", "skills", "world", "scripts/ci", "scripts/ci/smoke", "assets/characters/player/references", "art_sources"):
            d = self.base / folder
            d.mkdir(parents=True, exist_ok=True)
            (d / ".gdignore").write_text("")
        (self.base / "docs" / "snippet.gd").write_text("extends Node\n")  # documentation, not a game file
        (self.base / "scripts" / "ci" / "tool.gd").write_text("extends SceneTree\n")  # CI tooling, not a game file
        self.assertEqual(self.codes(self.base), [])

    def test_gdignore_in_the_project_root_hides_everything(self):
        (self.base / ".gdignore").write_text("")
        rep = v.validate(self.base, ENGINE)
        self.assertEqual([f.code for f in rep.findings], ["PRJ013"])

    def test_desktop_renderer_is_a_warning_not_an_error_because_web_forces_compatibility(self):
        fp = sp.write_project(self.tmp / "fp", "forward_plus_base")
        self.assertEqual(self.codes(fp), [("warning", "PRJ005")])
        unset = self.edit("unset", "project.godot", lambda t: t.replace('renderer/rendering_method="gl_compatibility"\n', ""))
        self.assertEqual(self.codes(unset), [("notice", "PRJ007")])
        mobile = self.edit("mobile", "project.godot", lambda t: t.replace('renderer/rendering_method="gl_compatibility"\n', 'renderer/rendering_method="mobile"\n'))
        self.assertEqual(self.codes(mobile), [("warning", "PRJ005")])

    def test_web_renderer_override_other_than_compatibility_is_an_error(self):
        d = sp.write_project(self.tmp / "ovr", "web_renderer_override")
        self.assertEqual(self.codes(d), [("error", "PRJ006")])

    def test_self_test_fixture_is_refused_unless_the_self_test_allows_it(self):
        with mock.patch.dict(os.environ, {ci_common.ALLOW_SELFTEST_ENV: ""}):
            rep = v.validate(self.base, ENGINE)
        self.assertEqual([f.code for f in rep.errors], ["PRJ014"])
        renamed = self.edit("renamed", "project.godot", lambda t: t.replace("Pipeline Self-Test (not the game)", "Shinobi Rush"))
        with mock.patch.dict(os.environ, {ci_common.ALLOW_SELFTEST_ENV: ""}):
            self.assertEqual(v.validate(renamed, ENGINE).errors, [])


class FixtureGeneratorTests(unittest.TestCase):
    def test_generated_gdscript_uses_tabs_lf_and_no_bom(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            for variant in sp.VARIANTS:
                d = sp.write_project(tmp / variant, variant)
                for f in d.rglob("*"):
                    if f.is_file() and f.suffix != ".png":  # a PNG signature legitimately contains CR LF
                        raw = f.read_bytes()
                        self.assertNotIn(b"\r", raw, f)
                        self.assertFalse(raw.startswith(b"\xef\xbb\xbf"), f)
                        if f.suffix == ".gd":
                            for line in raw.decode("utf-8").split("\n"):
                                self.assertFalse(line.startswith(" "), f"{variant}/{f.name}: space indentation: {line!r}")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_every_fixture_says_it_is_not_the_game(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            d = sp.write_project(tmp / "good", "good")
            self.assertIn("NOT THE GAME", (d / "main.gd").read_text(encoding="utf-8"))
            self.assertIn("not the game", (d / "project.godot").read_text(encoding="utf-8"))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_unknown_variant_is_rejected(self):
        with self.assertRaises(ValueError):
            sp.write_project(Path(tempfile.gettempdir()) / "never-created", "bogus")

    def test_writer_refuses_the_repository_and_its_ancestors(self):
        for dest in (REPO_ROOT / "fixture", REPO_ROOT, REPO_ROOT.parent):
            with self.subTest(dest=str(dest)), self.assertRaises(ValueError):
                sp.write_project(dest, "good")
        self.assertFalse((REPO_ROOT / "fixture").exists())

    def test_writer_never_wipes_a_directory_it_did_not_create(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            foreign = tmp / "my-documents"
            foreign.mkdir()
            (foreign / "thesis.txt").write_text("irreplaceable")
            with self.assertRaises(ci_common.UnsafePath):
                sp.write_project(foreign, "good")
            self.assertEqual((foreign / "thesis.txt").read_text(), "irreplaceable")
            mine = sp.write_project(tmp / "mine", "good")  # marked as owned, so a rewrite may replace it
            (mine / "stale.txt").write_text("old")
            sp.write_project(tmp / "mine", "good")
            self.assertFalse((mine / "stale.txt").exists())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_repo_shaped_fixture_has_game_code_under_scripts_and_ignores_only_tooling(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            d = sp.write_project(tmp / "rs", "repo_shaped")
            self.assertTrue((d / "scripts" / "player" / "helper.gd").is_file())
            self.assertTrue((d / "scripts" / "ci" / ".gdignore").is_file())
            self.assertFalse((d / "scripts" / ".gdignore").exists())
            self.assertTrue(all((d / f / ".gdignore").is_file() for f in ("docs", "orders", "skills", "world")))
            bad = sp.write_project(tmp / "bad", "gdignore_scripts")
            self.assertTrue((bad / "scripts" / ".gdignore").is_file())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_png_helper_writes_valid_pngs(self):
        import struct
        import zlib
        data = sp.png_bytes((1, 2, 3), 4)
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        pos, chunks = 8, {}
        while pos < len(data):
            (length,) = struct.unpack(">I", data[pos:pos + 4])
            tag, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
            (crc,) = struct.unpack(">I", data[pos + 8 + length:pos + 12 + length])
            self.assertEqual(crc, zlib.crc32(tag + body) & 0xFFFFFFFF, tag)
            chunks[tag] = body
            pos += 12 + length
        self.assertEqual(struct.unpack(">IIBBBBB", chunks[b"IHDR"]), (4, 4, 8, 2, 0, 0, 0))
        self.assertEqual(len(zlib.decompress(chunks[b"IDAT"])), 4 * (1 + 4 * 3))
        self.assertIn(b"IEND", chunks)

    def test_repo_shaped_fixture_models_the_repository_root_layout_with_images(self):
        """Project.godot at the root of the checkout, next to non-game folders full of images (each behind a .gdignore), game art
        without one, a control folder that is not ignored, and decoy scripts for the resource walker's skip rules."""
        tmp = Path(tempfile.mkdtemp())
        try:
            d = sp.write_project(tmp / "rs", "repo_shaped")
            self.assertTrue((d / "project.godot").is_file())
            for folder in (*sp.NON_GAME_FOLDERS, sp.REFERENCES_FOLDER, "scripts/ci"):
                self.assertTrue((d / folder / ".gdignore").is_file(), folder)
            for image in sp.IGNORED_IMAGES:
                self.assertTrue((d / image).is_file(), image)
                folder = next(f for f in (*sp.NON_GAME_FOLDERS, sp.REFERENCES_FOLDER) if image.startswith(f + "/"))
                self.assertTrue((d / folder / ".gdignore").is_file(), f"{image} must sit behind a .gdignore")
            for image in (sp.GAME_ART, sp.CONTROL_IMAGE):
                self.assertTrue((d / image).read_bytes().startswith(b"\x89PNG"), image)
                self.assertFalse(any((a / ".gdignore").exists() for a in (d / image).parents if d in a.parents), f"{image} must NOT be ignored")
            self.assertFalse((d / "scripts" / ".gdignore").exists())
            self.assertEqual(sorted(p.relative_to(d).as_posix() for p in (d / "scripts" / "player").glob("*.gd")), ["scripts/player/helper.gd", "scripts/player/player_controller.gd"])
            for decoy in (*sp.BROKEN_DECOYS, *sp.VALID_DECOYS):
                self.assertTrue((d / decoy).is_file(), decoy)
            self.assertEqual(sp.GAME_SCRIPT_COUNT, 3, "main.gd plus the two scripts under scripts/player")
            # the same layout, without the extra content, is what the other variants build: no images or decoys elsewhere
            good = sp.write_project(tmp / "good", "good")
            self.assertFalse((good / sp.GAME_ART).exists())
            self.assertFalse((good / "node_modules").exists())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_validator_accepts_the_repository_root_layout_and_names_a_missing_references_gdignore(self):
        """Statically: project == repo root, images everywhere, every .gdignore in place -> clean; remove the one next to the
        approved turnaround -> exactly one PRJ012 warning that names it (never an error)."""
        tmp = Path(tempfile.mkdtemp())
        try:
            with mock.patch.dict(os.environ, {ci_common.ALLOW_SELFTEST_ENV: "1"}):
                d = sp.write_project(tmp / "rs", "repo_shaped")
                self.assertEqual([(f.level, f.code) for f in v.validate(d, ENGINE, repo_root=d).findings], [])
                (d / sp.REFERENCES_FOLDER / ".gdignore").unlink()
                findings = v.validate(d, ENGINE, repo_root=d).findings
            self.assertEqual([(f.level, f.code) for f in findings], [("warning", "PRJ012")])
            self.assertIn("assets/characters/player/references", findings[0].message)
            self.assertNotIn("Add an empty .gdignore file to: docs", findings[0].message, "only the missing folder is listed")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_no_fixture_project_is_ever_committed_under_scripts_ci(self):
        """Design invariant: fixtures exist only at run time. (A real game project elsewhere in the repo is fine.)"""
        ci_dir = REPO_ROOT / "scripts" / "ci"
        offenders = [p for name in ("project.godot", "export_presets.cfg") for p in ci_dir.rglob(name) if "node_modules" not in p.parts]
        self.assertEqual(offenders, [], "a Godot project fixture was committed; fixtures must be generated at run time")


class WalkerTests(unittest.TestCase):
    """The headless resource walker is kept as text in godot_walker.py and written outside the project at run time.
    The behaviour itself is proven against the real engine by the self-test case `repo_shaped_layout`; these tests pin
    the text, the output contract that godot_ci.py parses and the skip rules named in the owner's repo-root decision."""

    def test_the_script_is_lf_tab_indented_without_bom(self):
        raw = gw.walker_source().encode("utf-8")
        self.assertNotIn(b"\r", raw)
        self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
        self.assertTrue(raw.endswith(b"\n"))
        for line in raw.decode("utf-8").split("\n"):
            self.assertFalse(line.startswith(" "), f"space indentation: {line!r}")
        self.assertTrue(any(line.startswith("\t") for line in gw.WALKER_LINES))

    def test_the_skip_rules_are_in_the_script(self):
        src = gw.walker_source()
        self.assertIn('const SKIP_DIR_NAMES := ["node_modules"]', src)
        self.assertIn('const SKIP_DIR_PATHS := ["res://exports", "res://build/web", "res://scripts/ci"]', src)
        self.assertEqual(gw.SKIP_DIR_PATHS, ("res://exports", "res://build/web", "res://scripts/ci"))
        self.assertIn('entry.begins_with(".")', src, "dot folders (.git, .godot, .github, .agents, ...)")
        self.assertIn('full.path_join(".gdignore")', src, "a folder with a .gdignore is not walked")
        self.assertIn('full.path_join("project.godot")', src, "a nested project is not walked")
        self.assertIn("dir.include_hidden = true", src, "hidden folders are listed on every platform, so the rule is deterministic")
        self.assertNotIn('"res://scripts"]', src, "scripts/ as a whole is game code and must be walked")

    def test_the_output_contract_is_what_godot_ci_parses(self):
        src = gw.walker_source()
        self.assertIn('print("VALIDATE_RESOURCES: scripts=%d scenes=%d resources=%d failures=%d" % [', src)
        self.assertIn('print("VALIDATE_RESOURCES_SKIPPED: " + ", ".join(_skipped))', src)
        self.assertIn('printerr("VALIDATE_RESOURCES_FAIL: " + failure)', src)
        self.assertIn("quit(1 if _failures.size() > 0 else 0)", src)

    def test_write_walker_writes_outside_the_project_and_refuses_inside(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            project = tmp / "project"
            project.mkdir()
            path = gw.write_walker(tmp / "elsewhere" / "walker", project)
            self.assertEqual(path.name, gw.WALKER_FILE_NAME)
            self.assertEqual(path.read_bytes(), gw.walker_source().encode("utf-8"))
            for inside in (project, project / "sub", project / "exports" / "web"):
                with self.subTest(dest=str(inside)), self.assertRaises(ValueError):
                    gw.write_walker(inside, project)
            self.assertEqual(list(project.iterdir()), [], "nothing was written into the project")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
