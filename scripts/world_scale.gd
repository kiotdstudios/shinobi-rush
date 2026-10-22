class_name WorldScale
extends RefCounted
## ONE place for the world/placeholder scale pass (128x128 art standard, ~108 px standing figure).
## Every number below is a PROVISIONAL PROTOTYPE value derived from the old 64-era values times SCALE.
## They exist so the arena is a representative reference for a ~108 px character. They are NOT
## balance: gameplay owners (Aki/Orcha) re-tune them.

## 108 / 48: new standing height over the old 48 px placeholder height.
const SCALE := 2.25

## Zoom of the `wide` camera preset (the default; see CameraPreset, which is what the game reads): the inverse
## of SCALE shows the same amount of arena as before the scale pass (visible world rect = viewport * SCALE).
## Follows SCALE automatically. Prototype baseline, not final.
const CAMERA_BASE_ZOOM := 1.0 / SCALE
## Extra world drawn/visible above the top arena bound so a standing figure at the top wall is not cut off.
const CAMERA_HEADROOM := BODY_HEIGHT
## Extra world drawn/visible below the bottom arena bound so the feet and ground shadow of a figure at the
## bottom wall are not cut off (shadow half-height is 6 * FIGURE_SCALE = ~11.4, plus the 3 px border line).
const CAMERA_FOOTROOM := 24.0
## World-space captions are sized so they stay at least this many SCREEN pixels tall.
const MIN_CAPTION_SCREEN_PX := 8.0


## Snap a direction to one of 8 unit-ish headings (diagonals normalized). Shared by PlayerController
## and enemies so both facing systems agree on the same 8-way grid.
static func snap8(dir: Vector2) -> Vector2:
	var idx := int(roundf(dir.angle() / (PI / 4.0)))
	return Vector2.from_angle(idx * (PI / 4.0)).snapped(Vector2(0.01, 0.01))


## Font size (in the caller's local units) that renders at least MIN_CAPTION_SCREEN_PX on screen.
## `base` is the size wanted at zoom 1; `local_scale` is any extra scale applied while drawing.
static func caption_font_size(base: int, zoom: float, local_scale: float = 1.0) -> int:
	return maxi(base, ceili(MIN_CAPTION_SCREEN_PX / (maxf(zoom, 0.01) * local_scale)))

## Placeholder figure (procedural drawing) and the shared collider / lab footprint.
const BODY_HEIGHT := 108.0
## Height of the unscaled procedural figure (hip 20 + torso 22 + neck-to-head 8 + head radius 7).
const PLACEHOLDER_NATIVE_HEIGHT := 57.0
const FIGURE_SCALE := BODY_HEIGHT / PLACEHOLDER_NATIVE_HEIGHT
## Old 22x12 times SCALE = 49.5x27, rounded. Used by the player collider and the lab overlay.
const FOOTPRINT := Vector2(50, 27)

## Arena (old 64x32 tiles; 144x72 is exactly 2:1).
const TILE_SIZE := Vector2(144, 72)
const ARENA_BOUNDS := Rect2(-2025, -1125, 4050, 2250)
const BOUNDS_WALL_THICKNESS := 144.0
const SPAWN := Vector2(0, 135)

## Player motion (old 175 / 270 px/s, 1400 / 1800 px/s^2).
const WALK_SPEED := 175.0 * SCALE
const SPRINT_SPEED := 270.0 * SCALE
const ACCELERATION := 1400.0 * SCALE
const FRICTION := 1800.0 * SCALE

## Lab turntable stands (old -100 / -230), left of the spawn.
const STAND_OFFSETS: Array[Vector2] = [Vector2(-225, 0), Vector2(-518, 0)]
## Half-extent of the stand's ground diamond (old 64x32 diamond).
const STAND_DIAMOND := Vector2(144, 72)

## Blocks: [bottom-centre position, footprint (w, depth), height]. Old values times SCALE, rounded.
const BLOCKS: Array = [
	[Vector2(-585, -180), Vector2(270, 108), 126.0],
	[Vector2(630, -270), Vector2(144, 144), 144.0],
	[Vector2(-270, 450), Vector2(360, 90), 90.0],
	[Vector2(540, 405), Vector2(108, 108), 108.0],
	[Vector2(0, -585), Vector2(450, 90), 162.0],
	# Level 1 Bandit arena (PLACEHOLDER collision blockers; art pass later). Two long walls at x=900 leave a
	# 280 px choke point at y -80..200, with open routes north (above y -600) and south (below y 740);
	# the two rocks east of them break line of sight and give the Bandit's patrol its far-side territory.
	[Vector2(900, -80), Vector2(90, 520), 150.0],   # 5: north wall
	[Vector2(900, 740), Vector2(90, 540), 150.0],   # 6: south wall
	[Vector2(1180, 40), Vector2(120, 110), 110.0],  # 7: rock covering the choke's east mouth
	[Vector2(1500, -330), Vector2(130, 110), 110.0],  # 8: rock inside the patrol area
]
## Where the Level 1 Bandit lives: far east of the player's spawn, behind the walls above.
const BANDIT_HOME := Vector2(1300, -130)
const BANDIT_PATROL: Array[Vector2] = [Vector2(1250, -200), Vector2(1650, -200), Vector2(1650, 60), Vector2(1380, 60)]
