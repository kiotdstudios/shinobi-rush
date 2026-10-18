"""Unit tests for validate_sprite_manifests.py. Fixtures are generated in temp dirs at test time.

Run: python -m unittest scripts/ci/test_validate_sprite_manifests.py   (from the repo root)
  or: python scripts/ci/test_validate_sprite_manifests.py
"""
import io
import json
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_sprite_manifests as v  # noqa: E402


def make_png(path: Path, w: int, h: int) -> None:
    def chunk(t: bytes, d: bytes) -> bytes:
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + b"\x00\x00\x00\xff" * w for _ in range(h))
    data = v.PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def good_manifest() -> dict:
    return {
        "schema": 1, "id": "t", "frame_size": [128, 128], "foot_anchor": [64, 120], "body_height_px": 108,
        "directions": ["S", "E", "N"], "mirror": {"W": "E"},
        "animations": {
            "idle": {"fps": 12, "loop": True, "frames": {"S": ["i/S.png"], "E": ["i/E.png"], "N": ["i/N.png"]}},
            "run": {"fps": 24, "sheet": "run.png", "columns": 3, "rows": ["S", "E", "N"]},
        },
    }


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name)

    def write(self, rel: str, data, name: str = "t.manifest.json") -> Path:
        d = self.root / rel
        d.mkdir(parents=True, exist_ok=True)
        for f in ("i/S.png", "i/E.png", "i/N.png"):
            make_png(d / f, 128, 128)
        make_png(d / "run.png", 384, 384)
        p = d / name
        p.write_text(data if isinstance(data, str) else json.dumps(data), encoding="utf-8")
        return p

    def check(self, mutate):
        m = good_manifest()
        mutate(m)
        _, errs = v.validate_manifest(self.write("s", m))
        return errs

    def test_png_size_reads_ihdr(self):
        make_png(self.root / "a.png", 7, 11)
        self.assertEqual(v.png_size(self.root / "a.png"), (7, 11))

    def test_png_size_rejects_non_png(self):
        (self.root / "b.png").write_bytes(b"hello world, definitely not a png at all")
        with self.assertRaises(ValueError):
            v.png_size(self.root / "b.png")

    def test_good_manifest_passes(self):
        sid, errs = v.validate_manifest(self.write("s", good_manifest()))
        self.assertEqual((sid, errs), ("t", []))

    def test_invalid_json(self):
        _, errs = v.validate_manifest(self.write("s", "{nope"))
        self.assertTrue(errs[0].startswith("invalid JSON"))

    def test_root_not_object(self):
        _, errs = v.validate_manifest(self.write("s", "[1]"))
        self.assertEqual(errs, ["manifest root must be a JSON object"])

    def test_wrong_schema_and_missing_id(self):
        errs = self.check(lambda m: (m.update(schema=2), m.pop("id")))
        self.assertTrue(any('"schema"' in e for e in errs))
        self.assertTrue(any('"id"' in e for e in errs))

    def test_bad_frame_size(self):
        errs = self.check(lambda m: m.update(frame_size=[0, 128]))
        self.assertTrue(any('"frame_size"' in e for e in errs))

    def test_unknown_direction(self):
        errs = self.check(lambda m: m.update(directions=["S", "UP"]))
        self.assertTrue(any('"UP"' in e for e in errs))

    def test_fps_must_be_positive(self):
        errs = self.check(lambda m: m["animations"]["idle"].update(fps=0))
        self.assertTrue(any("fps must be > 0" in e for e in errs))

    def test_missing_referenced_file(self):
        errs = self.check(lambda m: m["animations"]["idle"]["frames"]["S"].append("i/gone.png"))
        self.assertTrue(any("missing file i/gone.png" in e for e in errs))

    def test_png_size_must_equal_frame_size(self):
        m = good_manifest()
        p = self.write("s", m)
        make_png(p.parent / "i" / "E.png", 129, 128)
        _, errs = v.validate_manifest(p)
        self.assertTrue(any("i/E.png is 129x128, expected 128x128" in e for e in errs), errs)

    def test_sheet_dimensions(self):
        m = good_manifest()
        p = self.write("s", m)
        make_png(p.parent / "run.png", 384, 256)
        _, errs = v.validate_manifest(p)
        self.assertTrue(any("run.png is 384x256, expected 384x384" in e for e in errs), errs)

    def test_per_animation_frame_size_override(self):
        m = good_manifest()
        m["animations"]["run"]["frame_size"] = [192, 192]
        p = self.write("s", m)
        make_png(p.parent / "run.png", 576, 576)
        self.assertEqual(v.validate_manifest(p)[1], [])

    def test_production_base_frame_must_be_128(self):
        m = good_manifest()
        m["frame_size"] = [64, 64]
        m["foot_anchor"] = [32, 60]
        m["animations"]["run"]["columns"] = 3
        p = self.write("s", m)
        for f in ("i/S.png", "i/E.png", "i/N.png"):
            make_png(p.parent / f, 64, 64)
        make_png(p.parent / "run.png", 192, 192)
        _, errs = v.validate_manifest(p)
        self.assertEqual(len(errs), 1, errs)
        self.assertIn("rule FRAME128", errs[0])
        self.assertIn("[128, 128]", errs[0])

    def test_per_animation_frame_size_below_128_is_error(self):
        m = good_manifest()
        m["animations"]["run"]["frame_size"] = [128, 96]
        p = self.write("s", m)
        make_png(p.parent / "run.png", 384, 288)
        _, errs = v.validate_manifest(p)
        self.assertEqual(len(errs), 1, errs)
        self.assertIn("rule FRAME128_OVERFLOW", errs[0])

    def test_foot_anchor_outside_base_frame_is_error(self):
        errs = self.check(lambda m: m.update(foot_anchor=[64, 129]))
        self.assertTrue(any("rule FOOT_ANCHOR" in e for e in errs), errs)
        errs = self.check(lambda m: m.update(foot_anchor=[-1, 100]))
        self.assertTrue(any("rule FOOT_ANCHOR" in e for e in errs), errs)

    def test_foot_anchor_outside_animation_frame_is_error(self):
        def f(m):
            m["animations"]["idle"]["foot_anchor"] = [200, 120]
        errs = self.check(f)
        self.assertTrue(any('animation "idle": rule FOOT_ANCHOR' in e for e in errs), errs)

    def test_overflow_canvas_with_inside_anchor_passes(self):
        m = good_manifest()
        m["animations"]["run"].update(frame_size=[256, 256], foot_anchor=[128, 200])
        p = self.write("s", m)
        make_png(p.parent / "run.png", 768, 768)
        self.assertEqual(v.validate_manifest(p)[1], [])

    def test_body_height_outside_range_is_warning_only(self):
        for bh in (90, 120):
            m = good_manifest()
            m["body_height_px"] = bh
            warns = []
            _, errs = v.validate_manifest(self.write("s", m), warnings=warns)
            self.assertEqual(errs, [])
            self.assertEqual(len(warns), 1, warns)
            self.assertIn("rule BODY_HEIGHT", warns[0])
        warns = []
        v.validate_manifest(self.write("s", good_manifest()), warnings=warns)
        self.assertEqual(warns, [])

    def test_run_prints_warning_and_still_passes(self):
        m = good_manifest()
        m["body_height_px"] = 90
        self.write("a", m)
        buf = io.StringIO()
        self.assertEqual(v.run(self.root, self.root, out=buf), 0)
        self.assertIn("::warning file=a/t.manifest.json::rule BODY_HEIGHT", buf.getvalue())

    def test_exempt_folders_get_schema_checks_only(self):
        legacy = good_manifest()
        legacy["frame_size"] = [64, 64]
        legacy["foot_anchor"] = [500, 500]
        legacy["body_height_px"] = 48
        legacy["animations"]["run"]["frame_size"] = [32, 32]
        for i, seg in enumerate(v.EXEMPT_DIRS):
            d = self.root / "assets" / "characters" / "p" / seg
            d.mkdir(parents=True)
            legacy["id"] = f"legacy{i}"
            (d / "x.manifest.json").write_text(json.dumps(legacy), encoding="utf-8")  # no PNGs on purpose
        buf = io.StringIO()
        self.assertEqual(v.run(self.root / "assets" / "characters", self.root, out=buf), 0, buf.getvalue())
        self.assertNotIn("::error", buf.getvalue())
        self.assertNotIn("::warning", buf.getvalue())

    def test_exempt_folder_still_checks_schema(self):
        d = self.root / "assets" / "characters" / "p" / "references"
        d.mkdir(parents=True)
        (d / "x.manifest.json").write_text('{"schema": 2}', encoding="utf-8")
        buf = io.StringIO()
        self.assertEqual(v.run(self.root / "assets" / "characters", self.root, out=buf), 1)
        self.assertIn('"schema" must be 1', buf.getvalue())

    def test_exempt_is_by_whole_path_segment(self):
        self.assertTrue(v.is_exempt(Path("assets/characters/p/previews/a.manifest.json")))
        self.assertTrue(v.is_exempt(Path("assets/characters/p/study/a.manifest.json")))
        self.assertFalse(v.is_exempt(Path("assets/characters/p/sources_v2/a.manifest.json")))
        self.assertFalse(v.is_exempt(Path("assets/characters/p/sprites/source.manifest.json")))

    def test_missing_cardinal_needs_mirror(self):
        def f(m):
            m.pop("mirror")
        errs = self.check(f)
        self.assertTrue(any("cardinal direction W missing" in e for e in errs))

    def test_needs_frames_or_sheet(self):
        errs = self.check(lambda m: m["animations"].update(idle={"fps": 12}))
        self.assertTrue(any('needs either "frames" or "sheet"' in e for e in errs))

    def test_empty_animations(self):
        errs = self.check(lambda m: m.update(animations={}))
        self.assertTrue(any('"animations"' in e for e in errs))

    def test_unknown_keys_are_ignored(self):
        errs = self.check(lambda m: (m.update(extra=1), m["animations"]["idle"].update(extra=2)))
        self.assertEqual(errs, [])

    def test_duplicate_ids_across_manifests(self):
        self.write("a", good_manifest(), "one.manifest.json")
        self.write("b", good_manifest(), "two.manifest.json")
        buf = io.StringIO()
        code = v.run(self.root, self.root, out=buf)
        self.assertEqual(code, 1)
        self.assertIn('duplicate set id "t"', buf.getvalue())

    def test_run_ok_and_error_format(self):
        self.write("a", good_manifest())
        buf = io.StringIO()
        self.assertEqual(v.run(self.root, self.root, out=buf), 0)
        self.assertIn("OK a/t.manifest.json (t)", buf.getvalue())
        bad = good_manifest()
        bad["id"] = "bad"
        bad["animations"]["run"]["fps"] = -1
        self.write("b", bad, "bad.manifest.json")
        buf = io.StringIO()
        self.assertEqual(v.run(self.root, self.root, out=buf), 1)
        self.assertIn("::error file=b/bad.manifest.json::animation \"run\": fps must be > 0", buf.getvalue())

    def test_no_manifests_or_missing_root_is_ok(self):
        buf = io.StringIO()
        self.assertEqual(v.run(self.root, self.root, out=buf), 0)
        self.assertEqual(v.run(self.root / "nope", self.root, out=buf), 0)

    def test_main_cli_exit_codes(self):
        self.write("a", good_manifest())
        self.assertEqual(v.main(["--repo-root", str(self.root), "--root", str(self.root)]), 0)
        self.write("b", "{nope", "z.manifest.json")
        self.assertEqual(v.main(["--repo-root", str(self.root), "--root", str(self.root)]), 1)

    def test_default_repo_root_is_script_location(self):
        self.assertEqual(v.DEFAULT_REPO_ROOT, Path(v.__file__).resolve().parents[2])

    def test_foreign_cwd_does_not_change_resolution(self):
        # A fake repo with a broken manifest, plus a foreign cwd that has no assets at all: the script must
        # follow --repo-root (or its own location), never the cwd, so a wrong cwd cannot become a silent pass.
        fake = self.root / "repo"
        self.write("repo/assets/characters/hero", {"schema": 2})
        foreign = self.root / "elsewhere"
        foreign.mkdir()
        script = Path(v.__file__).resolve()
        r = subprocess.run([sys.executable, str(script), "--repo-root", str(fake)], cwd=foreign,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("::error file=assets/characters/hero/t.manifest.json::", r.stdout)
        # Without --repo-root it must use the script's own repo, not the (empty) foreign cwd.
        r = subprocess.run([sys.executable, str(script)], cwd=foreign, capture_output=True, text=True)
        repo_chars = v.DEFAULT_REPO_ROOT / "assets" / "characters"
        self.assertTrue(str(repo_chars) in r.stdout or "manifest(s) checked" in r.stdout, r.stdout)
        self.assertNotIn(str(foreign), r.stdout)


if __name__ == "__main__":
    unittest.main()
