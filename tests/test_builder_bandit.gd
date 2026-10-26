extends RefCounted
## Builder: the Bandit is a placeable enemy (catalog, add/move/remove, save/load, frozen while editing, respawn), the
## tag bomb rides on the enemy it sticks to, and every combat pickup is in the palette.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var tree := root.get_tree()
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_builder_bandit.json"
	placed.autosave = false
	placed.load_dict({"version": 7, "items": []})

	ck.call("bandit builder: catalog entry under Enemies", PlacedObjects.CATALOG.has("bandit_l1") and PlacedObjects.type_of("bandit_l1") == "Enemies")
	for id in ["kunai", "paper_tag", "tag_bomb", "smoke_tag_bomb"]:
		ck.call("pickups: %s is in the palette" % id, PlacedObjects.CATEGORIES.any(func(c): return c[0] == "Pickups" and id in c[1]))
	ck.call("bandit builder: it has art for the palette and selection box", PlacedObjects.art_texture("bandit_l1", Vector2(500, 500))[0] != null and PlacedObjects.art_rect("bandit_l1", Vector2(500, 500)).size.x > 0.0)

	var pos := arena.bounds.get_center() + Vector2(300, 200)
	var obj := placed.add("bandit_l1", pos)
	ck.call("bandit builder: add creates a Bandit at the spot with that home", not obj.is_empty() and obj.nodes[0] is Bandit and (obj.nodes[0] as Bandit).global_position.is_equal_approx(pos) and (obj.nodes[0] as Bandit).home.is_equal_approx(pos))
	ck.call("bandit builder: it is an enemy that can be hurt", (obj.nodes[0] as Bandit).is_in_group("enemy") and (obj.nodes[0] as Bandit).is_alive())
	ck.call("bandit builder: frozen while building (map mode)", (obj.nodes[0] as Bandit).process_mode == Node.PROCESS_MODE_DISABLED or placed.bandits_frozen)

	var pos2 := pos + Vector2(120, 0)
	placed.move(obj, pos2)
	ck.call("bandit builder: move drags the bandit and its home", (obj.nodes[0] as Bandit).position.is_equal_approx(pos2) and (obj.nodes[0] as Bandit).home.is_equal_approx(pos2))

	var saved := placed.to_dict()
	placed.load_dict({"version": 7, "items": []})
	await tree.process_frame
	ck.call("bandit builder: clearing removes it", placed.objects.is_empty())
	ck.call("bandit builder: save/load round trips", placed.load_dict(saved) == 1 and placed.has_bandits())
	await tree.process_frame
	var o2: Dictionary = placed.objects[0]
	ck.call("bandit builder: loaded bandit is a live Bandit again", o2.id == "bandit_l1" and o2.nodes[0] is Bandit and (o2.nodes[0] as Bandit).position.is_equal_approx(pos2))

	placed.set_bandits_frozen(false)
	ck.call("bandit builder: playing wakes it up", (o2.nodes[0] as Bandit).process_mode == Node.PROCESS_MODE_INHERIT)
	placed.set_bandits_frozen(true)
	ck.call("bandit builder: editing freezes it again", (o2.nodes[0] as Bandit).process_mode == Node.PROCESS_MODE_DISABLED)

	# respawn after defeat
	placed.set_bandits_frozen(false)
	var first: Bandit = o2.nodes[0]
	first.take_damage(9999.0, Vector2.RIGHT, 100.0, 0.0)
	await tree.create_timer(TrainingArena.BANDIT_RESPAWN_DELAY + 0.6).timeout
	ck.call("bandit builder: a defeated placed bandit is replaced at its home", o2.nodes[0] != first and (o2.nodes[0] as Bandit).is_alive() and (o2.nodes[0] as Bandit).position.is_equal_approx(pos2))

	placed.remove(o2)
	await tree.process_frame
	ck.call("bandit builder: remove deletes it", placed.objects.is_empty())

	# the tag bomb rides on the enemy it stuck to
	var player := arena.get_node("Player") as PlayerController
	var Dummy := GDScript.new()
	Dummy.source_code = "extends Node2D\nvar hits := 0\nfunc take_damage(a, d, k, h):\n\thits += 1\n"
	Dummy.reload()
	var victim := Dummy.new() as Node2D
	victim.add_to_group("enemy")
	arena.add_child(victim)
	var origin := arena.bounds.get_center()
	victim.global_position = origin + Vector2(100, 0)
	var bomb := PaperTagBomb.spawn(arena, origin, Vector2.RIGHT, player)
	var step := 1.0 / 60.0
	while bomb.phase == PaperTagBomb.Phase.FLY and bomb.age < 2.0:
		bomb.advance(step)
	ck.call("tag bomb: sticks to the enemy it hits", bomb.stuck_to == victim)
	while bomb.age < PaperTagBomb.FUSE - 0.2:
		victim.global_position += Vector2(2.0, 0)
		bomb.advance(step)
	for i in 30:
		victim.global_position += Vector2(2.0, 0)
		bomb.advance(step)
	ck.call("tag bomb: an enemy that walks away with the tag on it still takes the blast", int(victim.get("hits")) == 1, str(victim.get("hits")))
	victim.queue_free()
	bomb.queue_free()
	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
