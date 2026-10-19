class_name CameraScaleValidation
extends Node
## P0 camera/scale validation scene (orders/Aki/2026-10-18-camera-scale-validation.md).
##
## ISOLATED from the live gameplay scene (scenes/main.tscn / scenes/arena/training_arena.gd): this script
## does not modify either file. It composes the existing, untouched TrainingArena + Player scenes (same
## composition scenes/main.tscn uses) as children, then layers a validation-only ground texture, a Kosen
## gate section, and a bandit placeholder on top, and overrides the camera to WorldScale.VALIDATION_CAMERA_ZOOM
## instead of the shared gameplay WorldScale.CAMERA_BASE_ZOOM. Per the owner-locked 2026-10-19 doc
## (docs/visuals/CAMERA_AND_ART_DIRECTION.md, "Camera conflict resolution"): a configurable camera preset /
## isolated comparison scene, not a change to the shared baseline or to Kiro's active camera/occlusion work.

const STONE_TILE_PATH := "res://assets/environment/kosen_courtyard/stone_tile_64.png"

const GATE_PILLAR_SIZE := Vector2(108, 108)
const GATE_PILLAR_HEIGHT := 252.0
## Positions sized for the WIDER visible-world rect at the validation zoom (1280/1.1667 x 720/1.1667
## ~= 1097x617, half-extent ~549x309 around the player spawn at (0,135); view y range ~[-174, 444]).
const GATE_PILLARS: Array = [
	Vector2(-200, -60),
	Vector2(200, -60),
]
const GATE_FRONT := Color("#5b5f68")
const GATE_SIDE := Color("#3f434b")
const GATE_TOP := Color("#8d93a0")

const BANDIT_POS := Vector2(430, 320)

## Ground overlay: draws the stone texture over the arena's default flat ground fill (no edit to
## TrainingArena.Ground). z_index placed just above the default ground (-1) but still below every
## y-sorted actor/block (which sit at z_index 0), so it never occludes anything that should be in front.
class GroundOverlay extends Node2D:
	var bounds: Rect2
	var tile_size: Vector2
	var tile: Texture2D
	func _init(b: Rect2, ts: Vector2, tex: Texture2D) -> void:
		bounds = b
		tile_size = ts
		tile = tex
		z_index = -1
		name = "GroundOverlay"
	func _draw() -> void:
		if tile == null:
			return
		var half := tile_size * 0.5
		var cols := int(ceil(bounds.size.x / tile_size.x)) + 2
		var rows := int(ceil(bounds.size.y / tile_size.y)) + 2
		for row in range(-rows, rows):
			for col in range(-cols, cols):
				var pos := Vector2(col * half.x, row * half.y)
				if bounds.has_point(pos):
					draw_texture_rect(tile, Rect2(pos - half, tile_size), false)




## Local copies of TrainingArena's Block/BlockRear occlusion-pair drawing (scripts/arena/training_arena.gd),
## duplicated here rather than referenced cross-file: GDScript loses custom _init() overloads on inner
## classes when called via OuterClassName.InnerClassName from a different script. Kept functionally
## identical to Kiro's/the live arena's pattern so this stays a faithful preview of the same occlusion
## approach, without touching training_arena.gd.
class Block extends StaticBody2D:
	var footprint: Vector2
	var height: float
	var label: String = "PLACEHOLDER"
	var front_color: Color = Color("#6b5b4a")

	func _init(size: Vector2, h: float, text: String = "PLACEHOLDER", front: Color = Color("#6b5b4a")) -> void:
		footprint = size
		height = h
		label = text
		front_color = front
		var shape := RectangleShape2D.new()
		shape.size = size
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0, -size.y * 0.5)
		add_child(col)

	func _camera_zoom() -> float:
		var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
		return cam.zoom.x if cam != null else 1.0

	func _draw() -> void:
		var w := footprint.x * 0.5
		var h := height
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, 0), Vector2(-w, 0)]), front_color)
		var font := ThemeDB.fallback_font
		var zoom := _camera_zoom()
		var floor_size := 5 if zoom >= 1.0 else WorldScale.caption_font_size(5, zoom)
		var fsize := maxi(12, floor_size)
		while fsize > floor_size and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > footprint.x - 6.0:
			fsize -= 1
		draw_string(font, Vector2(-w + 3, -h * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.6))


class BlockRear extends Node2D:
	var footprint: Vector2
	var height: float
	var side_color: Color = Color("#4e4237")
	var top_color: Color = Color("#9a8670")

	func _init(size: Vector2, h: float, side: Color = Color("#4e4237"), top: Color = Color("#9a8670")) -> void:
		footprint = size
		height = h
		side_color = side
		top_color = top

	func _draw() -> void:
		var w := footprint.x * 0.5
		var d := footprint.y
		var h := height
		var s := d * 0.5
		draw_set_transform(Vector2(0.0, d))
		draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w + s, -d), Vector2(w + s, -d - h), Vector2(w, -h)]), side_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w + s, -h - d), Vector2(-w + s, -h - d)]), top_color)



func _ready() -> void:
	var arena := $TrainingArena as TrainingArena
	var player := $TrainingArena/Player
	# Arena + player _ready() already ran (bottom-up). Ground overlay, gate, bandit are additive extras.
	var stone_tile: Texture2D = load(STONE_TILE_PATH) if ResourceLoader.exists(STONE_TILE_PATH) else null
	if stone_tile != null:
		arena.add_child(GroundOverlay.new(arena.get_bounds(), WorldScale.TILE_SIZE, stone_tile))

	for i in GATE_PILLARS.size():
		var pos: Vector2 = GATE_PILLARS[i]
		var pillar := Block.new(GATE_PILLAR_SIZE, GATE_PILLAR_HEIGHT, "KOSEN GATE", GATE_FRONT)
		pillar.name = "GatePillar%d" % i
		pillar.position = pos
		arena.add_child(pillar)
		var pillar_rear := BlockRear.new(GATE_PILLAR_SIZE, GATE_PILLAR_HEIGHT, GATE_SIDE, GATE_TOP)
		pillar_rear.name = "GatePillarRear%d" % i
		pillar_rear.position = ArenaSort.rear_position(pos, GATE_PILLAR_SIZE)
		arena.add_child(pillar_rear)

	var bandit := BanditFigure.new()
	bandit.name = "Bandit"
	bandit.position = BANDIT_POS
	arena.add_child(bandit)

	# Validation-only zoom override: NOT WorldScale.CAMERA_BASE_ZOOM (the shared gameplay baseline).
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").zoom = Vector2.ONE * WorldScale.VALIDATION_CAMERA_ZOOM


## Bandit placeholder: same silhouette language as PlaceholderVisual (scripts/player/placeholder_visual.gd),
## recolored and labeled, no AI/combat behavior yet. Defined here (not in training_arena.gd) to keep the
## live shared arena file untouched.
class BanditFigure extends Node2D:
	const CLOTH := Color("#6e2626")
	const LIMB := Color("#3a1414")
	const SKIN := Color("#c98f66")
	const SHADOW := Color(0, 0, 0, 0.35)

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * WorldScale.FIGURE_SCALE)
		var shadow := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			shadow.append(Vector2(cos(a) * 15.0, sin(a) * 6.0))
		draw_colored_polygon(shadow, SHADOW)
		var hip := Vector2(0, -20)
		var neck := hip + Vector2(0, -22)
		var head := neck + Vector2(0, -8)
		draw_line(hip, Vector2(-5, 0), LIMB, 4.0)
		draw_line(hip, Vector2(5, 0), LIMB, 4.0)
		draw_line(hip, neck, CLOTH, 9.0)
		var shoulder := neck + Vector2(0, 3)
		draw_line(shoulder + Vector2(-5, 0), shoulder + Vector2(-8, 14), LIMB, 3.0)
		draw_line(shoulder + Vector2(5, 0), shoulder + Vector2(8, 14), LIMB, 3.0)
		draw_circle(head, 7.0, SKIN)
		var csize := WorldScale.caption_font_size(8, 1.0, WorldScale.FIGURE_SCALE)
		var cw := 60.0 * csize / 8.0
		draw_string(ThemeDB.fallback_font, Vector2(-cw * 0.5, head.y - 14.0), "BANDIT", HORIZONTAL_ALIGNMENT_CENTER, cw, csize, Color(1, 0.8, 0.8, 0.85))
