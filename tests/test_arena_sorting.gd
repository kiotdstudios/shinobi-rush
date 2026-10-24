extends RefCounted
## Draw order of the arena blocks (wall-occlusion fix). Called from tests/run_tests.gd.
## (a) the pure rule (ArenaSort) around a box and for every WorldScale BLOCKS entry,
## (b) scene-level: each block's two sort pieces (Block = front face, BlockRear = east face + roof),
## (c) the decisive regression: the draw order Godot derives from the real node values equals the rule's expectation,
##     including the east side, where the player used to be hidden behind the east face.
## Godot's documented rule: with y_sort_enabled a node with a higher global y draws later; equal keys draw in tree order.

const HALF_W := 25.0  # player collider half width (50 px)
const GAP := 1.0
const FOOT_H := 27.0  # player collider height

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_rule_directions()
	test_rule_every_block()
	await test_scene(tree_root)


## Sample feet positions around the block at `pos` with `fp` (width, depth) at collider contact (1 px gap).
## Each entry: [name, feet, expect_over_front, expect_over_rear]. The expectations are written out by hand from the
## geometry of the three-quarter drawing, not computed with ArenaSort.
static func samples(pos: Vector2, fp: Vector2) -> Array:
	var ex := pos.x + fp.x * 0.5 + HALF_W + GAP  # east contact column
	var wx := pos.x - fp.x * 0.5 - HALF_W - GAP  # west contact column
	var back := pos.y - fp.y
	var mid := pos.y - fp.y * 0.5 + FOOT_H * 0.5  # row where the collider centre is level with the block's depth centre
	return [
		# N: behind both pieces; NE: behind both (the roof and east face cover him: geometry-correct);
		["N", Vector2(pos.x, back - GAP), false, false],
		["NE", Vector2(ex, back - GAP), false, false],
		# East side: the east face is nearer than the actor, so he is drawn over the east face and roof.
		# The front face (a different plane) still covers nothing of him, so he is behind it by key.
		["E", Vector2(ex, mid), false, true],
		["E back end", Vector2(ex, back + 2.0), false, true],
		["E 2px north of front edge", Vector2(ex, pos.y - 2.0), false, true],
		["E 2px south of front edge", Vector2(ex, pos.y + 2.0), true, true],
		["E lowest blocked row", Vector2(ex, pos.y + FOOT_H - 1.0), true, true],
		["SE", Vector2(ex, pos.y + FOOT_H + GAP), true, true],
		["S", Vector2(pos.x, pos.y + FOOT_H + GAP), true, true],
		["SW", Vector2(wx, pos.y + FOOT_H + GAP), true, true],
		# West side: nothing of the actor overlaps the faces; the keys are the same as on the east side.
		["W", Vector2(wx, mid), false, true],
		["NW", Vector2(wx, back - GAP), false, false],
	]


func test_rule_directions() -> void:
	var pos := Vector2(100, 200)
	var fp := Vector2(120, 80)
	ck.call("sort rule: front key is the front-edge y", ArenaSort.front_key(pos) == 200.0)
	ck.call("sort rule: rear key is the back-edge y (pos.y - depth)", ArenaSort.rear_key(pos, fp) == 120.0)
	ck.call("sort rule: rear position is pos shifted up by the depth", ArenaSort.rear_position(pos, fp) == Vector2(100, 120))
	ck.call("sort rule: rear position y equals the rear key", ArenaSort.rear_position(pos, fp).y == ArenaSort.rear_key(pos, fp))
	for s: Array in samples(pos, fp):
		ck.call("sort rule: box 120x80, %s -> over front %s, over east face and roof %s" % [s[0], s[2], s[3]],
			ArenaSort.actor_over_front(s[1], pos) == s[2] and ArenaSort.actor_over_rear(s[1], pos, fp) == s[3])


func test_rule_every_block() -> void:
	for i in WorldScale.BLOCKS.size():
		var pos: Vector2 = WorldScale.BLOCKS[i][0]
		var fp: Vector2 = WorldScale.BLOCKS[i][1]
		var bad: Array[String] = []
		for s: Array in samples(pos, fp):
			if ArenaSort.actor_over_front(s[1], pos) != s[2] or ArenaSort.actor_over_rear(s[1], pos, fp) != s[3]:
				bad.append(s[0])
		ck.call("sort rule: BLOCKS[%d] all %d sampled positions match the expectation" % [i, samples(pos, fp).size()], bad.is_empty(), str(bad))
		ck.call("sort rule: BLOCKS[%d] the east side is drawn over the roof and east face from the back end to the front edge" % i,
			ArenaSort.actor_over_rear(Vector2(pos.x + fp.x * 0.5 + 26.0, pos.y - fp.y + 2.0), pos, fp) and not ArenaSort.actor_over_front(Vector2(pos.x + fp.x * 0.5 + 26.0, pos.y - 2.0), pos))


## Does the actor node draw after (over) the piece node? Godot's rule: higher global y later; equal y -> tree order.
static func draws_after(actor: Node2D, piece: Node2D) -> bool:
	var ay := actor.global_position.y
	var py := piece.global_position.y
	if not is_equal_approx(ay, py):
		return ay > py
	return actor.get_index() > piece.get_index()


func test_scene(tree_root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await tree_root.get_tree().process_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var player := main.get_node_or_null("TrainingArena/Player") as PlayerController
	ck.call("arena sorting: main scene has arena and player", arena != null and player != null)
	if arena == null or player == null:
		main.queue_free()
		return
	ck.call("arena sorting: the arena y-sorts its children", arena.y_sort_enabled)
	ck.call("arena sorting: player is a direct arena child and does not y-sort its own children", player.get_parent() == arena and not player.y_sort_enabled)
	var n := WorldScale.BLOCKS.size()
	var pieces_ok := true
	var structure: Array[String] = []
	var pairs: Array = []
	for i in n:
		if WorldScale.is_placeholder_block(i):
			continue  # placeholder boxes were removed from the level
		var block := arena.get_node_or_null(NodePath("Block%d" % i)) as Node2D
		var rear := arena.get_node_or_null(NodePath("BlockRear%d" % i)) as Node2D
		if block == null or rear == null:
			structure.append("block %d: Block=%s BlockRear=%s" % [i, block, rear])
			pieces_ok = false
			# Without a separate rear piece the east face and roof sort at the front edge: the east-side defect.
			ck.call("arena sorting: block %d east face and roof have their own sort key (draw order over the player)" % i, false, "missing piece")
			continue
		pairs.append([i, block, rear])
	ck.call("arena sorting: every block has a Block (front) and a BlockRear (east face and roof) piece", pieces_ok, str(structure))
	for p: Array in pairs:
		var i: int = p[0]
		var block: Node2D = p[1]
		var rear: Node2D = p[2]
		var pos: Vector2 = WorldScale.BLOCKS[i][0]
		var fp: Vector2 = WorldScale.BLOCKS[i][1]
		ck.call("arena sorting: block %d pieces share the arena parent and the player's z_index" % i,
			block.get_parent() == arena and rear.get_parent() == arena and block.z_index == player.z_index and rear.z_index == player.z_index,
			"z block=%d rear=%d player=%d" % [block.z_index, rear.z_index, player.z_index])
		ck.call("arena sorting: block %d pieces do not y-sort their own children (each is one item)" % i, not block.y_sort_enabled and not rear.y_sort_enabled)
		ck.call("arena sorting: block %d front piece sort key is the front edge y" % i, block.global_position == pos and block.global_position.y == ArenaSort.front_key(pos), str(block.global_position))
		ck.call("arena sorting: block %d rear piece sort key is the back edge y (pos.y - depth)" % i,
			rear.global_position == Vector2(pos.x, pos.y - fp.y) and rear.global_position.y == ArenaSort.rear_key(pos, fp), str(rear.global_position))
		ck.call("arena sorting: block %d rear piece sits right after its front piece and after the player in the tree" % i,
			rear.get_index() == block.get_index() + 1 and rear.get_index() > player.get_index() and block.get_index() > player.get_index())
		var has_col := false
		for c in rear.get_children():
			if c is CollisionShape2D or c is CollisionObject2D:
				has_col = true
		ck.call("arena sorting: block %d rear piece has no collider (collision is unchanged)" % i, not has_col)

	# (c) decisive: draw order derived from the real node values vs the rule's expectation
	for p: Array in pairs:
		var i: int = p[0]
		var block: Node2D = p[1]
		var rear: Node2D = p[2]
		var pos: Vector2 = WorldScale.BLOCKS[i][0]
		var fp: Vector2 = WorldScale.BLOCKS[i][1]
		var bad: Array[String] = []
		for s: Array in samples(pos, fp):
			player.global_position = s[1]
			if draws_after(player, block) != s[2]:
				bad.append("%s front" % s[0])
			if draws_after(player, rear) != s[3]:
				bad.append("%s rear" % s[0])
		ck.call("arena sorting: block %d real node draw order matches the rule at all %d sampled positions" % [i, samples(pos, fp).size()], bad.is_empty(), str(bad))
		# the exact east-side sweep from the defect report, spelled out
		var ex := pos.x + fp.x * 0.5 + HALF_W + GAP
		player.global_position = Vector2(ex, pos.y - 2.0)
		ck.call("arena sorting: block %d east side, 2 px north of the front edge: player draws over the east face and roof" % i, draws_after(player, rear))
		player.global_position = Vector2(ex, pos.y - fp.y + 2.0)
		ck.call("arena sorting: block %d east side, back end: player draws over the east face and roof" % i, draws_after(player, rear))
		player.global_position = Vector2(ex, pos.y + FOOT_H - 1.0)
		ck.call("arena sorting: block %d east side, lowest blocked row: player draws over the front piece too" % i, draws_after(player, rear) and draws_after(player, block))
		player.global_position = Vector2(ex, pos.y - fp.y - GAP)
		ck.call("arena sorting: block %d north-east corner: east face and roof still cover the player (not drawn over all walls)" % i, not draws_after(player, rear) and not draws_after(player, block))
		player.global_position = Vector2(pos.x, pos.y - fp.y - GAP)
		ck.call("arena sorting: block %d north of the back edge: player is behind both pieces" % i, not draws_after(player, rear) and not draws_after(player, block))
		player.global_position = Vector2(pos.x, pos.y + FOOT_H + GAP)
		ck.call("arena sorting: block %d south of the front edge: player is over both pieces" % i, draws_after(player, rear) and draws_after(player, block))
		# ties draw in tree order (both pieces come later than the player): behind
		player.global_position = Vector2(ex, pos.y)
		ck.call("arena sorting: block %d feet exactly on the front edge: front piece draws over the player (tie goes to the tree order)" % i, not draws_after(player, block))
		player.global_position = Vector2(ex, pos.y - fp.y)
		ck.call("arena sorting: block %d feet exactly on the back edge: rear piece draws over the player (tie goes to the tree order)" % i, not draws_after(player, rear))
	main.queue_free()
