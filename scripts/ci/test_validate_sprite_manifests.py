"""Unit tests for validate_sprite_manifests.py. Fixtures are generated in temp dirs at test time.

Run: python -m unittest scripts/ci/test_validate_sprite_manifests.py   (from the repo root)
  or: python scripts/ci/test_validate_sprite_manifests.py
"""
import io
import json
import struct
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
        "schema": 1, "id": "t", "frame_size": [32, 32], "foot_anchor": [16, 28], "body_height_px": 24,
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
            make_png(d / f, 32, 32)
        make_png(d / "run.png", 96, 96)
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
        errs = self.check(lambda m: m.update(frame_size=[0, 32]))
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
        make_png(p.parent / "i" / "E.png", 33, 32)
        _, errs = v.validate_manifest(p)
        self.assertTrue(any("i/E.png is 33x32, expected 32x32" in e for e in errs), errs)

    def test_sheet_dimensions(self):
        m = good_manifest()
        p = self.write("s", m)
        make_png(p.parent / "run.png", 96, 64)
        _, errs = v.validate_manifest(p)
        self.assertTrue(any("run.png is 96x64, expected 96x96" in e for e in errs), errs)

    def test_per_animation_frame_size_override(self):
        m = good_manifest()
        m["animations"]["run"]["frame_size"] = [48, 48]
        p = self.write("s", m)
        make_png(p.parent / "run.png", 144, 144)
        self.assertEqual(v.validate_manifest(p)[1], [])

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


if __name__ == "__main__":
    unittest.main()
