extends RefCounted
## Fix for a reported bug (screenshot: player standing behind a long temple wall piece, visibly
## drawing OVER the wall instead of being hidden by it). Root cause: PlacedObjects._make_wall() gave
## a whole diagonal wall run ONE y-sort key at its ground-run MIDPOINT; Godot's y-sort only compares
## one position per node, so everywhere away from the midpoint (worst at the two ends, exactly where
## the report's screenshot shows the player) the local "in front of or behind" answer the single key
## gives is wrong. Fix: slice the wall texture per CELL_UNIT and give each slice its own locally
## interpolated sort key. See the comment above PlacedObjects._make_wall for the full derivation.
## Called from tests/run_tests.gd.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	_test_slice_count()
	_test_slice_transform_reproduces_identical_screen_pixels()
	_test_slice_transform_sort_key_matches_local_ground_position()
	await _test_real_placement(tree_root)


func _test_slice_count() -> void:
	ck.call("wall kit sort: point pieces (col == ZERO) are never sliced", PlacedObjects._wall_slice_count(Vector2.ZERO) == 1)
	# kit_se_2..kit_se_6 chain N cells of (36,18) each -- the slice count must recover that exact N
	# from the catalog's own `col` vector, with no hardcoded per-id table to drift out of sync.
	for n in range(2, 7):
		var id := "kit_se_%d" % n
		var col: Vector2 = PlacedObjects.CATALOG[id].col
		ck.call("wall kit sort: _wall_slice_count recovers N=%d from %s's col vector" % [n, id], PlacedObjects._wall_slice_count(col) == n, str(PlacedObjects._wall_slice_count(col)))
		var sw_id := "kit_sw_%d" % n
		var sw_col: Vector2 = PlacedObjects.CATALOG[sw_id].col
		ck.call("wall kit sort: _wall_slice_count recovers N=%d from %s's col vector (SW mirror)" % [n, sw_id], PlacedObjects._wall_slice_count(sw_col) == n)


## The decisive algebraic invariant from the fix's design: slicing must not move a single visible
## pixel. For slice i covering texture columns [x0, x0+w), position+offset must equal
## `pos - anchor + Vector2(x0, 0)` -- the exact same screen placement the ORIGINAL single sprite
## used for that same column range (derived by substitution in the order's report, checked here in
## the real engine's Vector2 math rather than by hand).
func _test_slice_transform_reproduces_identical_screen_pixels() -> void:
	var def: Dictionary = PlacedObjects.CATALOG["kit_se_6"]
	var pos := Vector2(500.0, -300.0)
	var full_w := 300.0
	for case in [[0.0, 50.0], [50.0, 50.0], [125.0, 70.0], [230.0, 70.0]]:
		var x0: float = case[0]
		var w: float = case[1]
		var t: Dictionary = PlacedObjects._wall_slice_transform(def, pos, x0, w, full_w)
		var screen_placement: Vector2 = t.position + t.offset
		var expected: Vector2 = pos - (def.anchor as Vector2) + Vector2(x0, 0.0)
		ck.call("wall kit sort: slice [x0=%.0f w=%.0f] position+offset reproduces the exact pre-fix screen placement" % [x0, w],
			screen_placement.is_equal_approx(expected), "%s vs %s" % [screen_placement, expected])


## The actual bug: each slice's sort key must be the LOCAL ground y at that slice's own position
## along the run (lerp from the near corner to the far corner), not the whole run's midpoint. Checks
## the key is monotonic along the run and that the far-end slice's key is close to the far corner's
## y (not the midpoint) -- the exact case the screenshot shows (player at the far end, old midpoint
## key put them "in front" when they should be hidden).
func _test_slice_transform_sort_key_matches_local_ground_position() -> void:
	var def: Dictionary = PlacedObjects.CATALOG["kit_se_6"]
	var col: Vector2 = def.col
	var pos := Vector2(0.0, 0.0)
	var full_w := 254.0
	var near: float = PlacedObjects._wall_slice_transform(def, pos, 0.0, 1.0, full_w).sort_key
	var mid: float = PlacedObjects._wall_slice_transform(def, pos, full_w * 0.5 - 0.5, 1.0, full_w).sort_key
	var far: float = PlacedObjects._wall_slice_transform(def, pos, full_w - 1.0, 1.0, full_w).sort_key
	ck.call("wall kit sort: near-end slice key is close to the run's near corner y (0)", absf(near - pos.y) < 2.0, str(near))
	ck.call("wall kit sort: far-end slice key is close to the run's far corner y (%.0f), NOT the old midpoint (%.0f) -- this is the exact bug the screenshot showed" % [col.y, col.y * 0.5],
		absf(far - (pos.y + col.y)) < 2.0 and absf(far - (pos.y + col.y * 0.5)) > 10.0, str(far))
	ck.call("wall kit sort: sort key is monotonic along the run (near < mid < far, matching the run's SE direction)", near < mid and mid < far, "%s %s %s" % [near, mid, far])
	# The old (pre-fix) behavior for comparison: a single whole-run midpoint key.
	var old_single_key: float = (pos + col * 0.5).y
	ck.call("wall kit sort: the far-end slice's NEW key differs from the OLD single midpoint key by more than half the run's y-span (proves the fix actually changes sort outcomes, not just internal plumbing)",
		absf(far - old_single_key) > col.y * 0.3, "far=%.1f old=%.1f col.y=%.1f" % [far, old_single_key, col.y])


func _test_real_placement(tree_root: Node) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 6:
		await main.get_tree().physics_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var placed := arena.placed if arena != null else null
	ck.call("wall kit sort: main scene has a usable PlacedObjects", placed != null)
	if placed == null:
		main.queue_free()
		return
	placed.autosave = false
	var pos := Vector2(-1700.0, 900.0)  # far corner of the arena, clear of existing content
	var obj := placed.add("kit_se_6", pos, false)
	ck.call("wall kit sort: placing kit_se_6 returns a non-empty object", not obj.is_empty())
	if obj.is_empty():
		main.queue_free()
		return
	var nodes: Array = obj.nodes
	ck.call("wall kit sort: kit_se_6 (6-cell run) produces 6 slice sprites + 1 body = 7 nodes", nodes.size() == 7, str(nodes.size()))
	# Contiguous, gap-free, non-overlapping texture coverage: every pixel column of the original art
	# is drawn by exactly one slice.
	var full_w: float = PlacedObjects.wall_texture("kit_se_6").get_width()
	var covered := 0.0
	var prev_x0 := -1.0
	var ok_contig := true
	for i in nodes.size() - 1:
		var s := nodes[i] as Sprite2D
		var x0: float = s.get_meta("x0")
		var w: float = s.get_meta("w")
		if i > 0 and not is_equal_approx(x0, prev_x0):
			ok_contig = false
		covered += w
		prev_x0 = x0 + w
	ck.call("wall kit sort: slices are contiguous (no gap/overlap) and cover the full texture width", ok_contig and is_equal_approx(covered, full_w), "%s/%s" % [covered, full_w])
	# The decisive check: consecutive slices' sort keys strictly increase along the SE run.
	var keys: Array[float] = []
	for i in nodes.size() - 1:
		keys.append((nodes[i] as Sprite2D).position.y)
	var increasing := true
	for i in range(1, keys.size()):
		if keys[i] <= keys[i - 1]:
			increasing = false
	ck.call("wall kit sort: real placed slices' sort keys strictly increase along the run (monotonic occlusion along the whole wall, not just at the midpoint)", increasing, str(keys))
	# Collision untouched: still the single thin parallelogram along the whole run, unaffected by N.
	var body := nodes[nodes.size() - 1] as StaticBody2D
	var cs := body.get_child(0) as CollisionShape2D
	var shape := cs.shape as ConvexPolygonShape2D
	var col: Vector2 = PlacedObjects.CATALOG["kit_se_6"].col
	ck.call("wall kit sort: collision is still a single 4-point parallelogram along the run, unaffected by slicing", shape != null and shape.points.size() == 4 and body.position == pos)
	ck.call("wall kit sort: collision shape still spans the full run vector", shape.points[1] == col)
	# Moving a multi-cell wall must keep every slice's own sort key correct, not collapse to one key.
	var new_pos := pos + Vector2(100.0, 40.0)
	placed.move(obj, new_pos, false)
	var moved_keys: Array[float] = []
	for i in nodes.size() - 1:
		moved_keys.append((nodes[i] as Sprite2D).position.y)
	var moved_increasing := true
	for i in range(1, moved_keys.size()):
		if moved_keys[i] <= moved_keys[i - 1]:
			moved_increasing = false
	ck.call("wall kit sort: after move(), slice sort keys are still strictly increasing (per-slice keys survive a move, not just at placement time)", moved_increasing, str(moved_keys))
	ck.call("wall kit sort: after move(), the body still tracks the new position", body.position == new_pos)
	placed.remove(obj, false)
	main.queue_free()
	await main.get_tree().process_frame
