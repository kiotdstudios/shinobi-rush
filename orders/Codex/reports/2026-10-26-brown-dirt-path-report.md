# Job report — brown/tan earth path matching grass
- Agent: Codex
- Date: 2026-10-26 America/New_York
- Order: `orders/Codex/2026-10-26-brown-dirt-path.md`
- Status: IN_PROGRESS — art complete; final broad regression pending
- Branch / PR: `codex/brown-dirt-path`; implementation `8fe33d5b8c937c1082efacf244f281ff79c14472`; PR https://github.com/kiotdstudios/shinobi-rush/pull/226

## Work completed

Created a separate warm brown/tan compacted-earth path pack, using the actual current grass pixels on exposed borders. Nine grass-compatible named roles plus 16 canonical exposed-edge masks support broad paths, one-cell trails, bends, caps and isolated patches. The nine names are deliberate aliases of corresponding masks. Existing green ground and grass PNGs remain unchanged.

All individual PNGs use the same 112×112 canvas and `(56,84)` origin as grass; logical tile remains a full 72×36 diamond. Every interior pixel is opaque. Grass overhang stays outside only exposed sides, so connected path interiors do not acquire green lattice seams. Material has matching opposite boundary texels and uses nearest sampling; no blurred alpha transition. The preview assembles the exported assets on the actual existing grass lattice, rather than presenting a generated mockup as an in-game screenshot.

Source: built-in image_gen (original preserved), followed by deterministic material sampling, periodic boundary preparation, 24-color reduction and compositing with existing grass. PixelLab official MCP documentation and configured access reviewed; balance available, no PixelLab generation used. Exact source provenance is included. No art was drawn procedurally.

## Files changed

- `assets/environment/blightwood/brown_dirt_path/`: 25 individual PNGs, 112-cell atlas, lossless import settings, JSON manifest, integration README, excluded original source/provenance.
- `scripts/art/build_brown_dirt_path.py`: repeatable extraction/compositing, coverage and periodic-boundary assertions, contact sheet, actual tiled grass comparison and ZIP packaging.
- `tests/test_brown_dirt_path.gd`, UID and one suite registration: imported texture dimensions, source aliases, opaque floor coverage.
- `docs/visuals/brown-dirt-path/`: native/enlarged assembled preview, nine-role contact sheet, QA and downloadable art pack.
- Order and this report.

## Tests before commit

| Command / inspection | Result | Evidence |
| --- | --- | --- |
| `python scripts/art/build_brown_dirt_path.py` | PASS: 16 masks, nine aliases, full opaque diamond, matching soil boundary texels, binary alpha | `docs/visuals/brown-dirt-path/qa.json` |
| Python source-hash / all-PNG / ZIP audit | PASS: all 25 floor tiles covered, dimensions/RGBA correct, source hashes match, ZIP CRC clean, 28 packaged files | QA JSON |
| Pinned Godot `godot_ci.py import` | PASS: all 26 PNG resources imported | `build/dirt-import/import.log` |
| Godot focused art + existing floor coverage suite | **124 passed / 0 failed**; existing 79 catalog floors also pass | `build/dirt-verify-final.log` |
| Full native suite, pinned Godot 4.7.2 | **3498 passed / 0 failed**, no engine/script errors | `build/dirt-full-tests/tests-builtin.log` |
| Visual inspection | PASS: nine role sheet and assembled wide path/narrow bend against original grass; source texture inspected | contact sheet / grass-blend preview |

The first focused run had one fixture assertion comparing JSON floating-point arrays directly to integer arrays. Corrected the assertion to compare numeric Vector2 values; no art changed for that fixture correction. All actual coverage/import assertions passed both runs.

## Issues / limitations

This is the requested art pack for review, not a runtime/builder change. No catalog, terrain controller, gameplay state, saved world or camera file changed. **NOT LIVE — awaiting builder integration.** The default ground renderer must not assume a centered 72×36 texture; use the provided existing-grass anchor and mask convention. It is a different bit convention from shoreline corner masks.

## Questions for owner
None.

## Outstanding work
Art PR #226 is pushed and ready for review. Subsequent approved integration can bind a Brown dirt path category/brush using the 16 side masks; no live deployment is claimed by this art-only delivery.

Live deployment: not applicable to this art-only delivery; **NOT LIVE � awaiting builder integration**. No Web/gameplay test or export is claimed for unbound artwork. Existing floor art was verified unchanged. Source PNGs, binary alpha, all 25 diamonds, 16 distinct masks, source/grass hashes and ZIP CRC were checked directly. Order structure validator passed.

Pre-commit suite was run on main base `ed9eaaa2`; main advanced independently during this art job. No integration or latest-main/live validation is claimed. PR CI performs its normal integration checks.
