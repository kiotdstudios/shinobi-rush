import io
import os
import re
import sys
import unittest
from contextlib import redirect_stdout
from unittest import mock

from helpers import GODOT_CLEAN_IMPORT, GODOT_MISSING_TEMPLATES, GODOT_PARSE_ERROR_IMPORT

import ci_common
import godot_log


class SanitizeTests(unittest.TestCase):
    def test_defuses_workflow_commands(self):
        self.assertEqual(ci_common.sanitize("::stop-commands::x"), ":\u200b:stop-commands::x")
        self.assertEqual(ci_common.sanitize("ok\n  ::error::x"), "ok\n  :\u200b:error::x")
        for ws in ("\u00a0", "\u2003", "\u3000", "\u0085"):  # any Unicode whitespace before the leading ::
            self.assertEqual(ci_common.sanitize(f"ok\n{ws}::error::x"), f"ok\n{ws}:\u200b:error::x", repr(ws))
        self.assertEqual(ci_common.sanitize("\u00a0::stop-commands::x"), "\u00a0:\u200b:stop-commands::x")

    def test_strips_control_characters_and_ansi(self):
        self.assertEqual(ci_common.sanitize("a\x00b\r\x1b[31mred\x1b[0m"), "abred")

    def test_escaping_rules(self):
        self.assertEqual(ci_common.escape_data("a\nb%"), "a%0Ab%25")
        self.assertEqual(ci_common.escape_property("a,b:c"), "a%2Cb%3Ac")


class AnnotateTests(unittest.TestCase):
    def test_workflow_command_format_in_actions(self):
        with mock.patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), redirect_stdout(io.StringIO()) as out:
            ci_common.annotate("error", "bad\nthing", title="T,1", file="a.py", line=3)
        self.assertEqual(out.getvalue().strip(), "::error title=T%2C1,file=a.py,line=3::bad%0Athing")

    def test_plain_text_outside_actions(self):
        with mock.patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}), redirect_stdout(io.StringIO()) as out:
            ci_common.annotate("warning", "careful", title="T")
        self.assertEqual(out.getvalue().strip(), "WARNING: [T] careful")

    def test_output_and_env_files_reject_multiline_values(self):
        with self.assertRaises(ValueError):
            ci_common._append_kv("GITHUB_OUTPUT", "name", "a\nb")
        with self.assertRaises(ValueError):
            ci_common._append_kv("GITHUB_OUTPUT", "bad name", "x")


class RunLoggedTests(unittest.TestCase):
    def test_merges_streams_and_reports_exit_code(self):
        r = ci_common.run_logged([sys.executable, "-c", "import sys; print('out'); print('err', file=sys.stderr); sys.exit(3)"], timeout=30)
        self.assertEqual(r.returncode, 3)
        self.assertIn("out", r.text)
        self.assertIn("err", r.text)
        self.assertFalse(r.timed_out)

    def test_hard_timeout_kills_the_process(self):
        r = ci_common.run_logged([sys.executable, "-c", "import time; time.sleep(60)"], timeout=1)
        self.assertTrue(r.timed_out)
        self.assertEqual(r.returncode, -1)


class GodotLogTests(unittest.TestCase):
    def test_parse_error_is_fatal_even_though_godot_exits_zero(self):
        s = godot_log.scan(GODOT_PARSE_ERROR_IMPORT)
        self.assertFalse(s.ok)
        self.assertTrue(any("Parse Error" in e for e in s.errors))
        self.assertTrue(any("Failed to load script" in e for e in s.errors))

    def test_missing_templates_is_fatal(self):
        self.assertEqual(len(godot_log.scan(GODOT_MISSING_TEMPLATES).errors), 2)

    def test_clean_output_passes(self):
        self.assertTrue(godot_log.scan(GODOT_CLEAN_IMPORT).ok)

    def test_ansi_colours_do_not_hide_errors(self):
        self.assertFalse(godot_log.scan("\x1b[31mERROR: boom\x1b[0m\n").ok)

    def test_warnings_are_counted_not_fatal(self):
        s = godot_log.scan("WARNING: foo\n   at: bar\n")
        self.assertTrue(s.ok)
        self.assertEqual(s.warnings, ["WARNING: foo"])

    def test_allowlist_skips_header_and_its_continuation_lines_only(self):
        text = "ERROR: known benign thing\n   at: x (y.cpp:1)\nERROR: real problem\n"
        s = godot_log.scan(text, [re.compile(r"^ERROR: known benign thing")])
        self.assertEqual(s.errors, ["ERROR: real problem"])
        self.assertEqual(s.allowlisted, 1)

    def test_gut_output_does_not_trip_the_scanner(self):
        self.assertTrue(godot_log.scan("---  GUT  ---\n[INFO]:  using x\n* test_math\n1/1 passed.\n---- All tests passed! ----\n").ok)


if __name__ == "__main__":
    unittest.main()
