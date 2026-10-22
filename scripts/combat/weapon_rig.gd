class_name WeaponRig
extends RefCounted
## Per-frame kunai hand placement for the SE-only player attack art Codex delivered (order
## orders/Codex/2026-10-21-player-kunai-flicker-combat-rework.md, PR #67/#76). Values are copied
## verbatim from the authored assets/characters/player/kunai_primary_se/kunai-primary.art.json frame
## data -- the exact numbers Codex's own verified proof scene (scripts/art/kunai_primary_proof.gd)
## already renders correctly. This file brings that placement into the real player; it does not
## invent new positions or angles.
##
## SE direction only: Codex's art order explicitly gates expansion to the other seven directions
## behind separate owner approval of this proof. player_visual.gd only ever calls pose() after
## confirming the body actually resolved to a literal "SE" (no mirror, no nearest-neighbor
## fallback) -- showing this SE pose's weapon transform for another facing would point the kunai
## the wrong way relative to the body.
##
## Placement math (identical to scripts/art/kunai_primary_proof.gd): the grip node sits at
## `hand_px - foot_anchor` in the same space as the body's SpriteActor (both share the player's
## origin as the foot anchor point), rotated by `angle_deg`. The blade sprite itself is offset by
## `-GRIP_PIVOT_PX` so the texture's authored grip point lands exactly on that rotation origin.

const WEAPON_TEXTURE := "res://assets/weapons/kunai/black_kunai.png"
const GRIP_PIVOT_PX := Vector2(25, 31)  ## assets/weapons/kunai/kunai.art.json "grip_pivot_px"

## anim_id -> Array of {hand: Vector2, angle_deg: float, layer: String}, indexed by frame_index, SE
## only. Source: assets/characters/player/kunai_primary_se/kunai-primary.art.json "animations".
const FRAMES := {
	"light1": [
		{"hand": Vector2(64, 72), "angle_deg": 135.0, "layer": "front"},
		{"hand": Vector2(45, 62), "angle_deg": -150.0, "layer": "front"},
		{"hand": Vector2(96, 70), "angle_deg": 15.0, "layer": "front"},
		{"hand": Vector2(108, 70), "angle_deg": 25.0, "layer": "front"},
		{"hand": Vector2(57, 67), "angle_deg": 115.0, "layer": "front"},
		{"hand": Vector2(65, 73), "angle_deg": 135.0, "layer": "front"},
	],
	"light2": [
		{"hand": Vector2(71, 62), "angle_deg": 145.0, "layer": "front"},
		{"hand": Vector2(59, 63), "angle_deg": 155.0, "layer": "front"},
		{"hand": Vector2(92, 90), "angle_deg": 110.0, "layer": "front"},
		{"hand": Vector2(89, 80), "angle_deg": 125.0, "layer": "front"},
		{"hand": Vector2(62, 79), "angle_deg": 145.0, "layer": "front"},
		{"hand": Vector2(64, 79), "angle_deg": 145.0, "layer": "front"},
	],
	"light3": [
		{"hand": Vector2(52, 67), "angle_deg": 145.0, "layer": "front"},
		{"hand": Vector2(38, 73), "angle_deg": 155.0, "layer": "behind"},
		{"hand": Vector2(78, 67), "angle_deg": 100.0, "layer": "front"},
		{"hand": Vector2(107, 85), "angle_deg": 70.0, "layer": "front"},
		{"hand": Vector2(85, 83), "angle_deg": 100.0, "layer": "front"},
		{"hand": Vector2(53, 89), "angle_deg": 110.0, "layer": "front"},
	],
	"dash_attack": [
		{"hand": Vector2(38, 77), "angle_deg": 150.0, "layer": "front"},
		{"hand": Vector2(58, 72), "angle_deg": 20.0, "layer": "front"},
		{"hand": Vector2(118, 77), "angle_deg": 20.0, "layer": "front"},
		{"hand": Vector2(52, 71), "angle_deg": 120.0, "layer": "front"},
		{"hand": Vector2(67, 64), "angle_deg": 130.0, "layer": "front"},
	],
}


## True if this attack id has an authored weapon rig (currently SE-only kunai strikes).
static func supports(anim_id: String) -> bool:
	return FRAMES.has(anim_id)


## Weapon pose for (anim_id, frame), clamped to the authored frame range. {} if anim_id is unknown.
static func pose(anim_id: String, frame: int) -> Dictionary:
	if not FRAMES.has(anim_id):
		return {}
	var frames: Array = FRAMES[anim_id]
	return frames[clampi(frame, 0, frames.size() - 1)]
