# Smoke screen

PixelLab smoke for `smoke_tag_bomb`: `screen_burst` (6) -> `screen_loop` (12, seamless) -> `screen_fade` (11), 256x192 hard-alpha frames, bank base at (128, 166). Three runtime banks (one behind, two in front, mirrored and staggered) replace the first-pass `smoke`/`billow` frames, which stay in the pack unused.

Receipts: `jobs.json` (base image, the three animation jobs, the frame ranges used and the rejected takes). `build_smoke_screen.py` repacks from the raws in `assets/pickups/smoke_tag_bomb/source/screen/` (`--fetch` re-downloads them). `contact.png` shows every frame; `preview.gif` replays the runtime timeline.

Gameplay (`SmokeTagBomb`): while it stands the screen is an iso floor ellipse, `COVER_RADIUS` 165 px wide and half as deep. It grows with the burst and gives way over the first 60 % of the fade.
- Bandits: `can_see` fails into, through or from inside it, so they lose you and fall back on `last_seen` / SEARCH. Their sprint sense cannot feel a player inside it. The debug vision overlay cuts its polygon at the smoke edge.
- Player: lock-on cannot acquire, flick to or hold a bandit inside or behind it. The sprint sense ignores bandits inside it.
- Melee and contact hits are not sight and still land inside it.
