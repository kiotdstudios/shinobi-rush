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
## Wall-aware navigation over BLOCKS (built once; the Level 1 Bandit paths around walls with it).
var nav: ArenaNav
## Player-built objects (trees/walls/...) and the World Builder panel that edits them.
var placed: PlacedObjects
var editor: WorldEditor
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


## Temple wall face art (owner 2026-10-23: "delete all placeholder walls and replace them with new
## temple wall assets"). Lazily loaded once and shared by every Block/BlockRear instance; see
## assets/environment/kosen_courtyard/walls/walls.art.json for provenance (one AI-generated study
## image, made seamless, palette-matched to the already-shipped wall_kit_v2 so both wall styles read
## as the same world) and docs/visuals/walls/ for the contact sheet and processing script.
class WallArt:
	const DIR := "res://assets/environment/kosen_courtyard/walls/"
	const TILE_W := 64.0  ## world px per horizontal repeat; matches the source tile's native width
	static var _front: Texture2D
	static var _side: Texture2D
	static var _roof: Texture2D

	static func front() -> Texture2D:
		if _front == null:
			_front = load(DIR + "wall_front.png") as Texture2D
		return _front

	static func side() -> Texture2D:
		if _side == null:
			_side = load(DIR + "wall_side.png") as Texture2D
		return _side

	static func roof() -> Texture2D:
		if _roof == null:
			_roof = load(DIR + "wall_roof.png") as Texture2D
		return _roof

## Pure math, no drawing: segment widths (each <= tile_w, summing to `total`) for tiling `total` world
## px of repeat. Split out from draw_tiled_rect/draw_tiled_quad so the tiling math itself (boundary
## cases: zero, sub-tile, exact multiple, partial remainder) can be unit-tested without a live
## CanvasItem draw context -- calling draw_texture_rect_region/draw_polygon outside an active _draw()
## is an engine error, not something a plain unit test can safely exercise directly.
static func tile_segments(total: float, tile_w: float) -> Array[float]:
	var out: Array[float] = []
	if tile_w <= 0.0:
		return out
	var remaining := total
	while remaining > 0.5:
		var seg := minf(tile_w, remaining)
		out.append(seg)
		remaining -= seg
	return out


## Tiles `tex` horizontally across an axis-aligned `rect`, each repeat stretched to `rect`'s full
## height (the source tile is a native ~128px-tall study image; walls range 90-162px, a mild and
## visually acceptable stretch). The final partial repeat crops the SOURCE width proportionally
## instead of stretching a short strip across the full texture, so bricks never squish at the seam.
static func draw_tiled_rect(ci: CanvasItem, tex: Texture2D, rect: Rect2, tile_w: float = WallArt.TILE_W) -> void:
	if tex == null:
		return
	var tsize := tex.get_size()
	var x := rect.position.x
	for seg: float in tile_segments(rect.size.x, tile_w):
		var src_w := tsize.x * (seg / tile_w)
		ci.draw_texture_rect_region(tex, Rect2(x, rect.position.y, seg, rect.size.y), Rect2(0, 0, src_w, tsize.y))
		x += seg


## Tiles `tex` along the p0->p1 edge of a (possibly sheared) quad, stretching the p0->p3 edge over
## the full texture height -- the parallelogram equivalent of draw_tiled_rect, used for the east
## face and roof (which are sheared, not axis-aligned, so draw_texture_rect_region cannot be used).
static func draw_tiled_quad(ci: CanvasItem, tex: Texture2D, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, tile_w: float = WallArt.TILE_W) -> void:
	if tex == null:
		return
	var total_w := p0.distance_to(p1)
	var white := Color.WHITE
	var x := 0.0
	for seg: float in tile_segments(total_w, tile_w):
		var t0 := x / total_w
		var t1 := (x + seg) / total_w
		var a := p0.lerp(p1, t0)
		var b := p0.lerp(p1, t1)
		var d := p3.lerp(p2, t0)
		var c := p3.lerp(p2, t1)
		var u1 := seg / tile_w
		ci.draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([white, white, white, white]),
			PackedVector2Array([Vector2(0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(0, 1)]), tex)
		x += seg


## Front piece: the front face, y-sorted at the front edge (the node position). Walls (height >=
## WorldScale.WALL_ART_MIN_HEIGHT -- the same threshold PlacedObjects.def_of() already uses to label
## an object "Wall") draw real temple wall face art (WallArt); everything shorter (rocks, crates,
## the lab stand) is genuinely still placeholder and keeps the flat grey polygon + caption, since
## this order only asked for walls. The east face and roof are drawn by the sibling BlockRear (see
## ArenaSort for the draw-order rule).
class Block extends StaticBody2D:
	var footprint: Vector2
	var height: float
	var is_wall: bool

	func _init(size: Vector2, h: float) -> void:
		footprint = size
		height = h
		is_wall = h >= WorldScale.WALL_ART_MIN_HEIGHT
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
		if is_wall:
			TrainingArena.draw_tiled_rect(self, WallArt.front(), Rect2(-w, -h, footprint.x, h))
			return
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


## Rear piece: the east face and the roof (three-quarter look). It is a SIBLING of Block, not a
## child, so it gets its own y-sort key at the back edge (ArenaSort.rear_position); no collider. The
## polygons keep the coordinates they had when Block drew them, shifted down by the depth to undo
## the node offset. Walls texture-map WallArt.side()/roof() onto these same polygons via
## draw_tiled_quad instead of flat colors -- see Block's is_wall comment for the threshold.
class BlockRear extends Node2D:
	var footprint: Vector2
	var height: float
	var is_wall: bool

	func _init(size: Vector2, h: float) -> void:
		footprint = size
		height = h
		is_wall = h >= WorldScale.WALL_ART_MIN_HEIGHT

	func _draw() -> void:
		var w := footprint.x * 0.5
		var d := footprint.y
		var h := height
		var s := d * 0.5
		draw_set_transform(Vector2(0.0, d))
		var east_p0 := Vector2(w, 0)
		var east_p1 := Vector2(w + s, -d)
		var east_p2 := Vector2(w + s, -d - h)
		var east_p3 := Vector2(w, -h)
		var roof_p0 := Vector2(-w, -h)
		var roof_p1 := Vector2(w, -h)
		var roof_p2 := Vector2(w + s, -h - d)
		var roof_p3 := Vector2(-w + s, -h - d)
		if is_wall:
			TrainingArena.draw_tiled_quad(self, WallArt.side(), east_p0, east_p1, east_p2, east_p3)
			TrainingArena.draw_tiled_quad(self, WallArt.roof(), roof_p0, roof_p1, roof_p2, roof_p3)
			return
		draw_colored_polygon(PackedVector2Array([east_p0, east_p1, east_p2, east_p3]), Color("#4e4237"))
		draw_colored_polygon(PackedVector2Array([roof_p0, roof_p1, roof_p2, roof_p3]), Color("#9a8670"))


func _ready() -> void:
	y_sort_enabled = true
	add_child(Ground.new(self))
	for i in BLOCKS.size():
		if WorldScale.is_placeholder_block(i):
			continue  # owner: no placeholder boxes in the level
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
	nav = ArenaNav.build(bounds, WorldScale.live_blocks())
	placed = PlacedObjects.new()
	placed.name = "PlacedObjects"
	placed.arena = self
	add_child(placed)
	placed.adopt_grove()  # the starting trees become editable objects (solid bases + nav come from them)
	placed.adopt_grass()
	if placed.load_saved() == 0:
		placed.load_default_from_repo()  # no per-machine save yet: fall back to the last-published layout
	rebuild_nav()
	_spawn_bandit()
	var layout_version := placed.loaded_version
	if layout_version < 6:
		# first run / an older layout: a few gourds lie around (a v5 layout already has its health gourds)
		placed.scatter_defaults(layout_version >= 5)
	if layout_version < 7:
		placed.ensure_shrine()  # v7 added the Ancient Shrine landmark: every older layout gets one once
	# Add the Ancient Shrine reference section using existing catalog art.
	# The authored layer is rebuilt on boot; it does not overwrite user:// editor saves.
	BlightwoodMap.populate(self)  # the starting map; when it lays itself the old courtyard section stands down
	AncientShrineSection.populate(self)
	editor = WorldEditor.new()
	editor.setup(self, placed)
	add_child(editor)
	for p in get_tree().get_nodes_in_group("player"):
		p.global_position = spawn.global_position
		if p.has_method("reset_camera"):
			p.reset_camera()


const BANDIT_RESPAWN_DELAY := 4.0


## The Level 1 robber Bandit: spawned on the FAR (east) side of the arena, behind the two long walls,
## so the player starts alone near the spawn and has to travel through the choke point or around the
## walls to reach it. It stays off the CI controls probe's lanes (due right / due up from the spawn):
## its patrol keeps y <= 60 east of x=1250 and the probe only walks a few hundred px.
func _spawn_bandit() -> void:
	var packed := load("res://scenes/enemy/bandit.tscn") as PackedScene
	var bandit := packed.instantiate()
	bandit.name = "Bandit"
	bandit.position = WorldScale.BANDIT_HOME
	bandit.patrol_points = PackedVector2Array(WorldScale.BANDIT_PATROL)
	add_child(bandit)
	if "nav" in bandit:
		bandit.nav = nav
	bandit.defeated.connect(_on_bandit_defeated.bind(bandit))


## A defeated Bandit is replaced: after a short beat the body is removed and a fresh one starts again at the far-side home.
func _on_bandit_defeated(bandit: Bandit) -> void:
	await get_tree().create_timer(BANDIT_RESPAWN_DELAY).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(bandit):
		bandit.name = "BanditDown"
		bandit.queue_free()
	_spawn_bandit()


## Rebuild the bandit nav after the player-built layout changed; live enemies get the new grid at once.
func rebuild_nav() -> void:
	# placed adopts every live Block as a "base_N" object, so its obstacles already cover the ones still
	# standing -- adding live_blocks() again kept deleted walls (e.g. cleared by the map) solid in the nav.
	nav = ArenaNav.build(bounds, placed.obstacles() if placed != null else WorldScale.live_blocks())
	for e in get_tree().get_nodes_in_group("enemy"):
		if "nav" in e:
			e.nav = nav


## Trunk bases as BLOCKS-style entries [anchor, footprint, height] (height unused by collision/nav).
static func tree_trunk_blocks() -> Array:
	var out: Array = []
	for p in WorldScale.TREE_POSITIONS:
		out.append([p, WorldScale.TREE_TRUNK_FOOTPRINT, 0.0])
	return out


## Invisible solid bases for the blossom trees (canopy stays walk-behind scenery).
func _build_tree_trunks() -> void:
	var body := StaticBody2D.new()
	body.name = "TreeTrunks"
	for p in WorldScale.TREE_POSITIONS:
		var shape := RectangleShape2D.new()
		shape.size = WorldScale.TREE_TRUNK_FOOTPRINT
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = p + Vector2(0, -WorldScale.TREE_TRUNK_FOOTPRINT.y * 0.5)
		body.add_child(col)
	add_child(body)


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
			var source_id: int
			if near_left or near_right or near_top or near_bottom:
				source_id = KosenFloorTileset.ring_source_id(near_left, near_right, near_top, near_bottom)
			else:
				source_id = KosenFloorTileset.pick_interior_source_id(i, j)
			tile_map.set_cell(Vector2i(i, j), source_id, Vector2i.ZERO)


func draw_ground_border(ci: CanvasItem) -> void:
	ci.draw_rect(bounds, BORDER, false, 3.0)
