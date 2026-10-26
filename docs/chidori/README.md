# Chidori (R2 + Square)

Audit: Codex's lightning art lived only on `codex/stylized-running-jutsu` (`charge_00..11` hand cores, `dynamic_back/front_00..11` overlays). The 12 core frames are kept as the hand core (`assets/vfx/chidori/core`), the back/front overlays are copied alongside for later use. Everything else is procedural (pixel-snapped, no shaders): `LightningFx` (reusable bolts/trees/strokes), `ChidoriFx` (charge + rush), `ChidoriImpact` (0.6 s burst), wired in `PlayerController` (`use_jutsu`, `_tick_chidori`).

Timings: charge 0.65 s (no damage), rush 720 px/s up to 380 px, damage only on contact (55, splash 22 within 110 px, each enemy once, never through walls), 25 chakra, 1.2 s cooldown. A hit interrupts the charge/rush.

Dev tools: `tools/shot_chidori.gd` (side-by-side vs Paper Bomb + live frames), `tools/shot_chidori_dirs.gd` (8 facings).
Files here: `paper_bomb_vs_chidori.png`, `chidori_in_game.gif` (windowed render of the real game).
