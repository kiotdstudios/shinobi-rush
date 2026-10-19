class_name TrainingArena
extends Node2D
## PLACEHOLDER training courtyard: faux-isometric-LOOKING ground, drawn in code.
## Collision is conventional planar 2D on each block's base footprint.
## Children are y-sorted (feet = sort anchor), so actors pass in front of / behind blocks.

## Legacy diamond unit (ratio 2:1), scaled for the 108 px figure (see WorldScale). No longer used
## by draw_ground() itself (the floor is a real TileMapLayer now, see KosenFloorTileset, which
## uses its own finer 72x36 tile size to match the "fine paving" reference) -- kept as a public
## export in case other systems still read it as "the arenas nominal diamond unit".
@export var tile_size: Vector2 = WorldScale.TILE_SIZE
## Playable world rectangle; the camera limits come from this.
@export var bounds: Rect2 = WorldScale.ARENA_BOUNDS

const BORDER := Color("#d9c27a")
## Perimeter ring thickness (world px) around ground_rect that gets the worn edge/corner tile
## variants instead of the regular interior mix -- roughly one floor tile deep.
const EDGE_RING_PX := 72.0

## Each block: [bottom-centre position, footprint size (w, depth), height in px].
## Provisional prototype values scaled by WorldScale.SCALE; not balance.
const BLOCKS: Array = WorldScale.BLOCKS

@onready var spawn: Marker2D = $Spawn
## Ground layer: a real TileMapLayer (KosenFloorTileset) painted once in _ready(), plus the
## arena-bounds border line. The arena y-sorts its children; drawing the ground in the arena's
## own _draw() would sort it at y=0 and hide every actor/block with y < 0 beneath it. A child on
## a lower z_index avoids that, and the TileMapLayer (as a CHILD of Ground, not a sibling)
## inherits that same effective z_index, so floor tiles and the border line stay on one sort key.
class Ground extends Node2D:
	var arena: TrainingArena
	var tile_map: TileMapLayer
	func _init(a: TrainingArena) -> void:
		arena = a
		z_index = -1
		name = "Ground"
		tile_map = TileMapLayer.new()
		tile_map.name = "FloorTiles"
		tile_map.tile_set = KosenFloorTileset.build()
		add_child(tile_map)
	func _ready() -> void:
		arena.paint_floor(tile_map)
	func _draw() -> void:
		arena.draw_ground_border(self)


## PLACEHOLDER block, front piece: the front face and its caption, y-sorted at the front edge (the node position).
## The east face and roof are drawn by the sibling BlockRear (see ArenaSort for the draw-order rule).
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
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, 0), Vector2(-w, 0)]), Color("#6b5b4a"))
		# Fit the label to the front face: shrink the font until "PLACEHOLDER" is not wider than the face.
		var font := ThemeDB.fallback_font
		# Zoomed out (zoom < 1) the font floor rises so the caption stays >= 8 screen px.
		var zoom := _camera_zoom()
		var floor_size := 5 if zoom >= 1.0 else WorldScale.caption_font_size(5, zoom)
		var fsize := maxi(12, floor_size)
		while fsize > floor_size and font.get_string_size("PLACEHOLDER", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > footprint.x - 6.0:
			fsize -= 1
		draw_string(font, Vector2(-w + 3, -h * 0.5), "PLACEHOLDER", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.6))


## PLACEHOLDER block, rear piece: the east face and the roof (three-quarter look). It is a SIBLING of Block, not a
## child, so it gets its own y-sort key at the back edge (ArenaSort.rear_position); no collider. The polygons keep
## the coordinates they had when Block drew them, shifted down by the depth to undo the node offset.
class BlockRear extends Node2D:
	var footprint: Vector2
	var height: float

	func _init(size: Vector2, h: float) -> void:
		footprint = size
		height = h

	func _draw() -> void:
		var w := footprint.x * 0.5
		var d := footprint.y
		var h := height
		var s := d * 0.5
		draw_set_transform(Vector2(0.0, d))
		draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w + s, -d), Vector2(w + s, -d - h), Vector2(w, -h)]), Color("#4e4237"))
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w + s, -h - d), Vector2(-w + s, -h - d)]), Color("#9a8670"))


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
	_build_bounds_walls()
	_spawn_bandit()
	for p in get_tree().get_nodes_in_group("player"):
		p.global_position = spawn.global_position
		if p.has_method("reset_camera"):
			p.reset_camera()


## One Basic Bandit for combat validation (see the combat order): spawned a short walk from the
## player's own spawn point so a fresh run can immediately test movement-to-attack chaining, dodging
## and combos against a live target. Offset diagonally (not purely +x) on purpose: the CI controls
## probe (scripts/ci/smoke/controls-probe.mjs) walks the player due right from this same spawn point
## to measure plain movement, and due up to find the arena wall -- a bandit sitting directly on
## either of those two axes would physically block the probe's player, not a gameplay bug but a
## false "movement broken" CI failure. The 200px y-offset clears the probe's lane with a wide
## margin (FOOTPRINT half-height is ~13.5px) while keeping the enemy a comparable short walk away.
func _spawn_bandit() -> void:
	var packed := load("res://scenes/enemy/bandit.tscn") as PackedScene
	var bandit := packed.instantiate()
	bandit.name = "Bandit"
	bandit.position = spawn.position + Vector2(230, 200)
	add_child(bandit)


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


func ground_rect() -> Rect2:
	# Ground continues above the top wall (head room) and below the bottom wall (foot room) so the camera never shows void.
	return bounds.grow_individual(0, WorldScale.CAMERA_HEADROOM, 0, WorldScale.CAMERA_FOOTROOM)


## Paints the floor TileMapLayer once: a continuous, flat stone surface (no texture-rect
## tiling, no raised-block look) covering ground_rect, with the worn edge/corner variants
## forming a one-tile-deep ring around the outside and a deterministic weighted mix of
## base/alt/cracked/dirt/decorative variants filling the interior.
func paint_floor(tile_map: TileMapLayer) -> void:
	var rect := ground_rect()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]
	var min_cell := Vector2i(1 << 30, 1 << 30)
	var max_cell := Vector2i(-(1 << 30), -(1 << 30))
	for c in corners:
		var cell: Vector2i = tile_map.local_to_map(c)
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	# A couple of cells of slack: the rectangle's corners don't bound every cell whose diamond
	# footprint still overlaps rect once the isometric grid skew is taken into account.
	min_cell -= Vector2i(2, 2)
	max_cell += Vector2i(2, 2)
	for i in range(min_cell.x, max_cell.x + 1):
		for j in range(min_cell.y, max_cell.y + 1):
			var pos: Vector2 = tile_map.map_to_local(Vector2i(i, j))
			if not rect.has_point(pos):
				continue
			var near_left := pos.x <= rect.position.x + EDGE_RING_PX
			var near_right := pos.x >= rect.end.x - EDGE_RING_PX
			var near_top := pos.y <= rect.position.y + EDGE_RING_PX
			var near_bottom := pos.y >= rect.end.y - EDGE_RING_PX
			var on_x_edge := near_left or near_right
			var on_y_edge := near_top or near_bottom
			var source_id: int
			if on_x_edge and on_y_edge:
				source_id = KosenFloorTileset.CORNER_SOURCE_ID
			elif on_x_edge or on_y_edge:
				source_id = KosenFloorTileset.EDGE_SOURCE_ID
			else:
				source_id = KosenFloorTileset.pick_interior_source_id(i, j)
			tile_map.set_cell(Vector2i(i, j), source_id, Vector2i.ZERO)


func draw_ground_border(ci: CanvasItem) -> void:
	ci.draw_rect(bounds, BORDER, false, 3.0)
