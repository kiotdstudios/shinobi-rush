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

## Each block: [bottom-centre position, footprint size (w, depth), height in px].
## Provisional prototype values scaled by WorldScale.SCALE; not balance.
const BLOCKS: Array = WorldScale.BLOCKS

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


## PLACEHOLDER block: top face plus front and right side faces (three-quarter look).
class Block extends StaticBody2D:
	var footprint: Vector2
	var height: float

	func _init(size: Vector2, h: float) -> void:
		footprint = size
		height = h
		var shape := RectangleShape2D.new()
		shape.size = size
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0, -size.y * 0.5)
		add_child(col)

	func _draw() -> void:
		var w := footprint.x * 0.5
		var d := footprint.y
		var h := height
		var s := d * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, 0), Vector2(-w, 0)]), Color("#6b5b4a"))
		draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w + s, -d), Vector2(w + s, -d - h), Vector2(w, -h)]), Color("#4e4237"))
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w + s, -h - d), Vector2(-w + s, -h - d)]), Color("#9a8670"))
		# Fit the label to the front face: shrink the font until "PLACEHOLDER" is not wider than the face.
		var font := ThemeDB.fallback_font
		var fsize := 12
		while fsize > 5 and font.get_string_size("PLACEHOLDER", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > footprint.x - 6.0:
			fsize -= 1
		draw_string(font, Vector2(-w + 3, -h * 0.5), "PLACEHOLDER", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.6))


func _ready() -> void:
	y_sort_enabled = true
	add_child(Ground.new(self))
	for b: Array in BLOCKS:
		var block := Block.new(b[1], b[2])
		block.position = b[0]
		add_child(block)
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
	ci.draw_rect(bounds, GROUND_A)
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
			if (i + j) % 2 == 0:
				ci.draw_colored_polygon(pts, GROUND_B)
			for k in 4:
				lines.append(pts[k])
				lines.append(pts[(k + 1) % 4])
	ci.draw_multiline(lines, GRID_LINE, 1.0)
	ci.draw_rect(bounds, BORDER, false, 3.0)
