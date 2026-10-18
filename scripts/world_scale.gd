class_name WorldScale
extends RefCounted
## ONE place for the world/placeholder scale pass (128x128 art standard, ~108 px standing figure).
## Every number below is a PROVISIONAL PROTOTYPE value derived from the old 64-era values times SCALE.
## They exist so the arena is a representative reference for a ~108 px character. They are NOT
## balance: gameplay owners (Aki/Orcha) re-tune them.

## 108 / 48: new standing height over the old 48 px placeholder height.
const SCALE := 2.25

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
]
