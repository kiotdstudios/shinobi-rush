extends RefCounted
## Paper tag: art sets, inventory item + pickup, the throw (costs one), flight/landing, the 1.66 s fuse, the blast's damage
## radius, and the bomb freeing itself after its animation.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var tree := root.get_tree()
	ck.call("tag art: tag float, fly, armed, glow and ember frame sets exist", HealthGourd.frames("gourd", "paper_tag").size() >= 12 and PaperTagBomb.frames("fly").size() >= 16 and PaperTagBomb.frames("armed").size() >= 12 and HealthGourd.frames("glow", "paper_tag").size() >= 1 and HealthGourd.frames("ember", "paper_tag").size() >= 6)
	ck.call("tag art: the blast has 60 frames plus a matching light layer and a scorch decal", PaperTagBomb.frames("blast").size() == PaperTagBomb.BLAST_FRAMES and PaperTagBomb.frames("glow").size() == PaperTagBomb.BLAST_FRAMES and ResourceLoader.exists(PaperTagBomb.BLAST_DIR + "scorch.png"))
	ck.call("tag: fuse is 1.66 s", is_equal_approx(PaperTagBomb.FUSE, 1.66))
	ck.call("tag: boom sound is generated", PaperTagBomb.boom_sound() != null and PaperTagBomb.boom_sound().data.size() > 10000)

	var inv := PlayerInventory.new()
	ck.call("tag inventory: it is an item with an icon and starts in the bag on the down slot", PlayerInventory.ITEMS.has("paper_tag") and PlayerInventory.icon("paper_tag") != null and inv.count_of("paper_tag") == 3 and inv.slot_item("down") == "paper_tag")

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_paper_tag_layout.json"
	placed.autosave = false
	var player := arena.get_node("Player") as PlayerController
	player.inventory.save_path = "user://test_paper_tag_inv.json"

	# pickup
	ck.call("tag builder: in the catalog under Pickups", PlacedObjects.CATALOG.has("paper_tag") and PlacedObjects.type_of("paper_tag") == "Pickups")
	var pk := HealthGourd.new()
	pk.kind = "paper_tag"
	pk.position = player.global_position + Vector2(0, 400)
	arena.add_child(pk)
	await tree.process_frame
	player.inventory.counts["paper_tag"] = 0
	player.global_position = pk.global_position
	ck.call("tag pickup: it grants a paper tag item and is in its own group", pk.item_id() == "paper_tag" and pk.is_in_group("tag_pickup") and pk.can_collect(player), "%s %s %s" % [pk.item_id(), pk.is_in_group("tag_pickup"), pk.can_collect(player)])
	pk.collect(player)
	ck.call("tag pickup: taking it puts one in the bag", player.inventory.count_of("paper_tag") == 1 and not pk.available)
	pk.queue_free()

	# throw
	player.global_position = arena.bounds.get_center()
	player.inventory.counts["paper_tag"] = 2
	player.inventory.assign_item("down", "paper_tag")
	var thrown0 := player.tags_thrown_count
	ck.call("tag throw: down starts a throw and costs one tag", player.use_slot("down") and player.inventory.count_of("paper_tag") == 1)
	for i in 40:
		await tree.physics_frame
	ck.call("tag throw: the tag is released mid-throw", player.tags_thrown_count == thrown0 + 1)
	var live := tree.get_nodes_in_group("enemy").size()
	player.inventory.counts["paper_tag"] = 0
	ck.call("tag throw: no tag, no throw", not player.use_slot("down"))

	# bomb on its own
	for n: Node in arena.get_children():
		if n is PaperTagBomb:
			n.queue_free()
	await tree.process_frame
	var Dummy := GDScript.new()
	Dummy.source_code = "extends Node2D\nvar hits := 0\nvar last := 0.0\nfunc take_damage(a, d, k, h):\n\thits += 1\n\tlast = a\n"
	Dummy.reload()
	var near := Dummy.new() as Node2D
	near.add_to_group("enemy")
	arena.add_child(near)
	var far := Dummy.new() as Node2D
	far.add_to_group("enemy")
	arena.add_child(far)
	var origin := arena.bounds.get_center()
	var b := PaperTagBomb.spawn(arena, origin, Vector2.RIGHT, player)
	near.global_position = origin + Vector2(PaperTagBomb.MAX_RANGE, 0) + Vector2(40, 10)
	far.global_position = origin + Vector2(PaperTagBomb.MAX_RANGE + 900, 0)
	var step := 1.0 / 60.0
	while b.phase == PaperTagBomb.Phase.FLY and b.age < 2.0:
		b.advance(step)
	ck.call("tag bomb: it lands after its flight, short of its max range", b.phase == PaperTagBomb.Phase.ARMED and b.travelled <= PaperTagBomb.MAX_RANGE + 10.0, "%s %s" % [b.landed_on, b.travelled])
	ck.call("tag bomb: it flies roughly one second less than the fuse", b.age <= PaperTagBomb.FLIGHT_TIME + 0.05)
	near.global_position = b.global_position + Vector2(60, 0)
	while b.age < PaperTagBomb.FUSE - 0.05:
		b.advance(step)
	ck.call("tag bomb: still armed just before the fuse runs out", b.phase == PaperTagBomb.Phase.ARMED and not b.detonated)
	for i in 6:
		b.advance(step)
	ck.call("tag bomb: it detonates at the fuse time", b.detonated and b.phase == PaperTagBomb.Phase.BLAST)
	ck.call("tag bomb: the damage waits for the flash frame", near.get("hits") == 0)
	for i in 12:
		b.advance(step)
	ck.call("tag bomb: an enemy inside the radius is hurt once", near.get("hits") == 1 and float(near.get("last")) > 0.0)
	ck.call("tag bomb: an enemy outside the radius is not", far.get("hits") == 0)
	var scorch := arena.get_node_or_null("TagScorch")
	ck.call("tag bomb: it leaves a scorch mark", scorch != null)
	for i in 130:
		b.advance(step)
	ck.call("tag bomb: it is finished once the 60-frame blast has played", b.phase == PaperTagBomb.Phase.DONE and b.is_queued_for_deletion())

	# sticks to an enemy / stops at max range without one
	far.global_position = origin + Vector2(120, 0)
	var b2 := PaperTagBomb.spawn(arena, origin, Vector2.RIGHT, player)
	while b2.phase == PaperTagBomb.Phase.FLY and b2.age < 2.0:
		b2.advance(step)
	ck.call("tag bomb: it lands on the first enemy it touches", b2.landed_on == "enemy" and b2.global_position.x < origin.x + 160.0, "%s %s" % [b2.landed_on, b2.global_position.x - origin.x])
	b2.queue_free()
	near.queue_free()
	far.queue_free()
	await tree.process_frame
	main.queue_free()
	await tree.process_frame
