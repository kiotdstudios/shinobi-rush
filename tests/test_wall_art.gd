extends RefCounted
## Temple wall art for the fixed arena's placeholder walls (owner 2026-10-23: "delete all
## placeholder walls and replace them with new temple wall assets"). Called from tests/run_tests.gd.
## Covers: the Wall/Block height classification stays in sync between WorldScale and PlacedObjects,
## every WorldScale.BLOCKS entry gets the correct is_wall flag on its real scene nodes, wall-art
## textures actually load, and the tiling helpers behave at real-world sizes without crashing or
## producing degenerate (zero-size) draw calls.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	_test_threshold_shared()
	_test_textures_load()
	_test_tiling_helpers_do_not_crash()
	await _test_scene_classification(tree_root)


func _test_threshold_shared() -> void:
	ck.call("wall art: WorldScale.WALL_ART_MIN_HEIGHT exists and is positive", WorldScale.WALL_ART_MIN_HEIGHT > 0.0)
	# PlacedObjects.def_of() must label a base_N entry "Wall" using the EXACT same threshold the
	# renderer uses -- otherwise the World Builder UI and the actual drawn art could disagree about
	# which objects are "walls".
	for i in WorldScale.BLOCKS.size():
		var h: float = WorldScale.BLOCKS[i][2]
		var def := PlacedObjects.def_of("base_%d" % i)
		var expect_wall := h >= WorldScale.WALL_ART_MIN_HEIGHT
		if not expect_wall:
			ck.call("wall art: BLOCKS[%d] (height %.0f) is a removed placeholder: no builder entry" % [i, h], def.is_empty())
			continue
		ck.call("wall art: BLOCKS[%d] (height %.0f) PlacedObjects label agrees with the threshold (%s)" % [i, h, "Wall" if expect_wall else "Block"],
			(def.label == "Wall") == expect_wall, def.label)


func _test_textures_load() -> void:
	var front := TrainingArena.WallArt.front()
	var side := TrainingArena.WallArt.side()
	var roof := TrainingArena.WallArt.roof()
	ck.call("wall art: front/side/roof textures all load", front != null and side != null and roof != null)
	if front == null or side == null or roof == null:
		return
	ck.call("wall art: front and side are distinct images (not the same file reused)", front.get_path() != side.get_path())
	ck.call("wall art: front and roof are distinct images (not the same file reused)", front.get_path() != roof.get_path())
	ck.call("wall art: textures have real pixel dimensions", front.get_width() > 0 and front.get_height() > 0)


## Pure math only (TrainingArena.tile_segments) -- draw_tiled_rect/draw_tiled_quad themselves call
## real CanvasItem draw_* methods, which are an ENGINE ERROR (not a safe no-op) outside an active
## _draw() callback, so they cannot be unit-tested by calling them directly outside a real scene.
## The actual draw path is exercised for real by _test_scene_classification() below, which boots
## the real main.tscn and lets the engine's normal render cycle call Block/BlockRear._draw().
func _test_tiling_helpers_do_not_crash() -> void:
	for width: float in [90.0, 144.0, 270.0, 450.0, 1.0, 63.0, 64.0, 65.0, 0.0, 0.4]:
		var segs := TrainingArena.tile_segments(width, 64.0)
		var total := 0.0
		for s: float in segs:
			total += s
			ck.call("wall art: tile_segments(%.1f) every segment is <= tile_w and positive" % width, s > 0.0 and s <= 64.0 + 0.001, str(s))
		ck.call("wall art: tile_segments(%.1f) segments sum back to the requested width" % width, is_equal_approx(total, maxf(width, 0.0)) or width < 0.5, "%.3f vs %.3f" % [total, width])
	ck.call("wall art: tile_segments(0, 64) returns no segments (nothing to draw)", TrainingArena.tile_segments(0.0, 64.0).is_empty())
	ck.call("wall art: tile_segments(64, 64) is exactly one full segment", TrainingArena.tile_segments(64.0, 64.0) == [64.0])
	ck.call("wall art: tile_segments(65, 64) is one full segment plus one 1px remainder (never a squished full-width stretch)", TrainingArena.tile_segments(65.0, 64.0) == [64.0, 1.0])
	ck.call("wall art: tile_segments with a zero tile_w returns nothing instead of dividing by zero", TrainingArena.tile_segments(100.0, 0.0).is_empty())
	# Real BLOCKS depth range (east-face/roof tiling target): 90-540 px, tile_w defaults to 64.
	for depth: float in [90.0, 108.0, 270.0, 520.0, 540.0]:
		var segs := TrainingArena.tile_segments(depth, TrainingArena.WallArt.TILE_W)
		ck.call("wall art: tile_segments covers the real BLOCKS depth %.0f with at least one segment" % depth, not segs.is_empty())


func _test_scene_classification(tree_root: Node) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 6:
		await main.get_tree().physics_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	ck.call("wall art: main scene has TrainingArena", arena != null)
	if arena == null:
		main.queue_free()
		return
	var any_wall := false
	var any_placeholder := false
	for i in WorldScale.BLOCKS.size():
		var h: float = WorldScale.BLOCKS[i][2]
		var expect_wall := h >= WorldScale.WALL_ART_MIN_HEIGHT
		if not expect_wall:
			ck.call("wall art: placeholder Block%d no longer exists in the level" % i, arena.get_node_or_null("Block%d" % i) == null and arena.get_node_or_null("BlockRear%d" % i) == null)
			any_placeholder = true
			continue
		var block := arena.get_node_or_null("Block%d" % i) as TrainingArena.Block
		var rear := arena.get_node_or_null("BlockRear%d" % i) as TrainingArena.BlockRear
		ck.call("wall art: Block%d and BlockRear%d exist" % [i, i], block != null and rear != null)
		if block == null or rear == null:
			continue
		ck.call("wall art: Block%d.is_wall matches height %.0f >= %.0f" % [i, h, WorldScale.WALL_ART_MIN_HEIGHT], block.is_wall == expect_wall)
		ck.call("wall art: BlockRear%d.is_wall matches Block%d.is_wall" % [i, i], rear.is_wall == block.is_wall)
		if expect_wall:
			any_wall = true
		else:
			any_placeholder = true
	ck.call("wall art: at least one real wall in the fixed arena got the new art (the order's whole point)", any_wall)
	ck.call("wall art: the short placeholder blocks (rock/crate) were removed", any_placeholder)
	# Collision must be byte-for-byte unchanged: same footprint, same StaticBody2D with a
	# RectangleShape2D of that exact size, regardless of is_wall -- this order is a visual swap only.
	for i in WorldScale.BLOCKS.size():
		var block := arena.get_node_or_null("Block%d" % i) as TrainingArena.Block
		if block == null:
			continue
		var fp: Vector2 = WorldScale.BLOCKS[i][1]
		var col := block.get_child(0) as CollisionShape2D
		var shape := col.shape as RectangleShape2D
		ck.call("wall art: Block%d collision shape size is untouched by the art change" % i, shape != null and shape.size == fp, str(shape.size if shape else null))
	main.queue_free()
	await main.get_tree().process_frame
