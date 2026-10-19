# ORDER — Match camera framing / character scale to owner reference + ground-tile validation
- Agent: Aki
- Status: REVIEW
- Priority: P0
- Owner: Aki (camera/scale tuning + validation scene); Codex retains character-art ownership (still pending push)
- Branch/PR: aki/camera-scale-validation
- Dependencies: scripts/world_scale.gd (CAMERA_BASE_ZOOM is the single source of truth, explicitly tunable by
  Aki/Orcha per its own header comment), scripts/arena/training_arena.gd, docs/visuals/CAMERA_AND_ART_DIRECTION.md

## Objective
Owner supplied two reference images: (1) a premium stone ground-tile asset kit (style target for ground
tiles), (2) an isometric combat screenshot (locked target for camera framing/character scale/environment
density). Build a small camera-and-scale validation scene — Kōsen gate section, ground tiles, a bandit, the
player placeholder (Codex's real 128x128 art is still not pushed, see orders/Codex/2026-10-18-idle-128-production-handoff.md,
so the existing placeholder figure stands in for now and will be swapped the moment Codex's push lands) — and
retune the shared camera zoom constant to match the reference's player-to-viewport proportions. Do NOT build
the full MVP map yet; this is the pre-approval test only, per the owner's explicit instruction.

## Scope / Files owned
`scripts/world_scale.gd` (zoom constant), `scripts/arena/training_arena.gd` (ground tiles, gate prop, bandit
placeholder), new tile art assets under `assets/environment/`. Do not touch Kiro's wall-occlusion files
(`orders/Kiro/2026-10-18-deferred-wall-occlusion-investigation.md` and whatever scripts that PR owns).

## Deliverables
1. Reference-derived camera zoom (measured from the owner's screenshot, not guessed).
2. Ground tile texture (Kōsen-themed stone, PixelLab-generated since Codex is occupied) replacing the flat
   placeholder diamond grid in the validation view.
3. Simple gate prop + bandit placeholder in the arena.
4. 1280x720 screenshot next to the reference, player height in px and % of viewport, visible world
   dimensions, Camera2D zoom used.
5. Live browser preview link.

## Acceptance Criteria
Owner approval of camera distance/character prominence/environment proportions before any full MVP build.

## Handoff / Notes
Reversible: zoom constant and arena additions are easily revertible; no MVP-scale content shipped yet.
