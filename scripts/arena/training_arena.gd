class_name TrainingArena
extends Node2D
## PLACEHOLDER training courtyard: faux-isometric-LOOKING ground, drawn in code.
## Collision is conventional planar 2D on each block's base footprint.
## Children are y-sorted (feet = sort anchor), so actors pass in front of / behind blocks.

## Provisional diamond tile size (ratio 2:1), tunable. Scaled for the 108 px figure (see WorldScale).
@export var tile_size: Vector2 = WorldScale.TILE_SIZE
## Playable world rectangle; the camera limits come from this.
@export var bounds: Rect2 = WorldScale.ARENA_BOUNDS

const GROUND_A := Color("#4b5d44")
const GROUND_B := Color("#556a4c")
const GRID_LINE := Color(0, 0, 0, 0.18)
const BORDER := Color("#d9c27a")
## P0 camera/scale validation (2026-10-18, orders/Aki/2026-10-18-camera-scale-validation.md): Kosen courtyard
## stone tile, PixelLab-generated (64x64 px), drawn per diamond cell in place of the flat placeholder fill.
## Falls back to the flat color fill if the texture fails to load, so this never hard-breaks the arena.
const STONE_TILE_PATH := "res://assets/environment/kosen_courtyard/stone_tile_64.png"
static var _stone_tile: Texture2D = load(STONE_TILE_PATH) if ResourceLoader.exists(STONE_TILE_PATH) else null

## Each block: [bottom-centre position, footprint size (w, depth), height in px].
## Provisional prototype values scaled by WorldScale.SCALE; not balance.
const BLOCKS: Array = WorldScale.BLOCKS

## P0 camera/scale validation (2026-10-18): a Kosen gate section, two pillars flanking a walkway north of
## spawn, built with the same Block/BlockRear occlusion pair as everything else in this arena.
const GATE_PILLAR_SIZE := Vector2(108, 108)
const GATE_PILLAR_HEIGHT := 252.0
const GATE_PILLARS: Array = [
	Vector2(-180, -30),
	Vector2(180, -30),
]
const GATE_FRONT := Color("#5b5f68")
const GATE_SIDE := Color("#3f434b")
const GATE_TOP := Color("#8d93a0")

## Bandit placeholder position, south-east of spawn, inside the visible camera framing at the new
## zoom (half-extent ~480x270 around the player) so it appears in the validation screenshot alongside
## the player and the gate.
const BANDIT_POS := Vector2(380, 300)

@onready var spawn: Marker2D = $Spawn
## Ground layer. The arena y-sorts its children; drawing the ground in the arena's own _draw()
## would sort it at y=0 and hide every actor/block with y < 0 beneath it. A child on a lower z_index avoids that.
class Ground extends Node2D:
	var arena: TrainingArena
	func _init(a: TrainingArena) -> void:
		arena = a
		z_index = -1
		name = "Ground"
	func _draw() -> void:
		arena.draw_ground(self)


## PLACEHOLDER block, front piece: the front face and its caption, y-sorted at the front edge (the node position).
## The east face and roof are drawn by the sibling BlockRear (see ArenaSort for the draw-order rule).
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

	var _drawn_zoom: float = -1.0

	func _camera_zoom() -> float:
		var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
		return cam.zoom.x if cam != null else 1.0

	func _process(_d: float) -> void:
		var z := _camera_zoom()
		if not is_equal_approx(z, _drawn_zoom):
			queue_redraw()

	func _draw() -> void:
		_drawn_zoom = _camera_zoom()
		var w := footprint.x * 0.5
		var h := height
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, 0), Vector2(-w, 0)]), front_color)
		# Fit the label to the front face: shrink the font until it is not wider than the face.
		var font := ThemeDB.fallback_font
		# Zoomed out (zoom < 1) the font floor rises so the caption stays >= 8 screen px.
		var zoom := _camera_zoom()
		var floor_size := 5 if zoom >= 1.0 else WorldScale.caption_font_size(5, zoom)
		var fsize := maxi(12, floor_size)
		while fsize > floor_size and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > footprint.x - 6.0:
			fsize -= 1
		draw_string(font, Vector2(-w + 3, -h * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.6))


## PLACEHOLDER block, rear piece: the east face and the roof (three-quarter look). It is a SIBLING of Block, not a
## child, so it gets its own y-sort key at the back edge (ArenaSort.rear_position); no collider. The polygons keep
## the coordinates they had when Block drew them, shifted down by the depth to undo the node offset.
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


## P0 camera/scale validation bandit placeholder: same silhouette language as PlaceholderVisual
## (scripts/player/placeholder_visual.gd), recolored and labeled, no AI/combat behavior yet.
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


func _ready() -> void:
	y_sort_enabled = true
	add_child(Ground.new(self))
	for i in BLOCKS.size():
		var b: Array = BLOCKS[i]
		var block := Block.new(b[1], b[2])
		block.name = "Block%d" % i
		block.position = b[0]
		add_child(block)
		# Rear piece right after its Block: its own key (back edge), same parent and z_index as the player.
		var rear := BlockRear.new(b[1], b[2])
		rear.name = "BlockRear%d" % i
		rear.position = ArenaSort.rear_position(b[0], b[1])
		add_child(rear)
	for i in GATE_PILLARS.size():
		var pos: Vector2 = GATE_PILLARS[i]
		var pillar := Block.new(GATE_PILLAR_SIZE, GATE_PILLAR_HEIGHT, "KOSEN GATE", GATE_FRONT)
		pillar.name = "GatePillar%d" % i
		pillar.position = pos
		add_child(pillar)
		var pillar_rear := BlockRear.new(GATE_PILLAR_SIZE, GATE_PILLAR_HEIGHT, GATE_SIDE, GATE_TOP)
		pillar_rear.name = "GatePillarRear%d" % i
		pillar_rear.position = ArenaSort.rear_position(pos, GATE_PILLAR_SIZE)
		add_child(pillar_rear)
	var bandit := BanditFigure.new()
	bandit.name = "Bandit"
	bandit.position = BANDIT_POS
	add_child(bandit)
	_build_bounds_walls()
	for p in get_tree().get_nodes_in_group("player"):
		p.global_position = spawn.global_position
		if p.has_method("reset_camera"):
			p.reset_camera()


func get_bounds() -> Rect2:
	return bounds


func _build_bounds_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "BoundsWalls"
	var t := WorldScale.BOUNDS_WALL_THICKNESS
	var r := bounds
	var rects: Array[Rect2] = [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2.0 * t, t),
		Rect2(r.position.x - t, r.end.y, r.size.x + 2.0 * t, t),
		Rect2(r.position.x - t, r.position.y, t, r.size.y),
		Rect2(r.end.x, r.position.y, t, r.size.y),
	]
	for rect in rects:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = rect.get_center()
		body.add_child(col)
	add_child(body)


func draw_ground(ci: CanvasItem) -> void:
	# Ground continues above the top wall (head room) and below the bottom wall (foot room) so the camera never shows void.
	ci.draw_rect(bounds.grow_individual(0, WorldScale.CAMERA_HEADROOM, 0, WorldScale.CAMERA_FOOTROOM), GROUND_A)
	var hx := tile_size.x * 0.5
	var hy := tile_size.y * 0.5
	var lines := PackedVector2Array()
	var n := int(maxf(bounds.size.x / hx, bounds.size.y / hy)) + 2
	var inner := bounds.grow_individual(-hx, -hy, -hx, -hy)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var c := Vector2((i - j) * hx, (i + j) * hy)
			if not inner.has_point(c):
				continue
			var pts := PackedVector2Array([c + Vector2(0, -hy), c + Vector2(hx, 0), c + Vector2(0, hy), c + Vector2(-hx, 0)])
			if _stone_tile != null:
				ci.draw_texture_rect(_stone_tile, Rect2(c - tile_size * 0.5, tile_size), false)
			elif (i + j) % 2 == 0:
				ci.draw_colored_polygon(pts, GROUND_B)
			for k in 4:
				lines.append(pts[k])
				lines.append(pts[(k + 1) % 4])
	if _stone_tile == null:
		ci.draw_multiline(lines, GRID_LINE, 1.0)
	ci.draw_rect(bounds, BORDER, false, 3.0)
