extends RefCounted
## Starting area (AncientShrineSection): the spawn stands inside a fenced stone courtyard with the shrine at its back.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 6:
		await tree.process_frame
	AncientShrineSection.enabled = false
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_starting_area_layout.json"
	placed.autosave = false
	var spawn := (arena.get_node("Spawn") as Node2D).position

	ck.call("start area: the spawn is inside the courtyard", AncientShrineSection.covers(spawn, 0.0), str(spawn))
	var shrine := {}
	var floors := 0
	var fences := 0
	var braziers := 0
	for o in placed.objects:
		if o.id == "ancient_shrine":
			shrine = o
		elif str(o.id).begins_with("temple_floor_"):
			floors += 1
		elif str(o.id).begins_with("fence_"):
			fences += 1
		elif o.id == "blight_stone_brazier":
			braziers += 1
	ck.call("start area: exactly one shrine, inside the courtyard", not shrine.is_empty() and AncientShrineSection.covers(shrine.pos, 0.0))
	ck.call("start area: the shrine stands behind the spawn (further back on screen)", not shrine.is_empty() and shrine.pos.y < spawn.y)
	ck.call("start area: the whole N x N stone floor is laid", floors == AncientShrineSection.N * AncientShrineSection.N, str(floors))
	var lay := AncientShrineSection.layout()
	ck.call("start area: fenced all round with exits (14 of 16 pieces)", lay.fences.size() == 14 and fences >= 12, "%d/%d" % [fences, lay.fences.size()])
	ck.call("start area: three corner braziers", braziers == 3, str(braziers))
	var players := tree.get_nodes_in_group("player")
	ck.call("start area: the player starts inside the courtyard", players.size() > 0 and AncientShrineSection.covers((players[0] as Node2D).global_position, 0.0))
	var shrine_count := 0
	for o in placed.objects:
		if o.id == "ancient_shrine":
			shrine_count += 1
	ck.call("start area: still exactly one shrine after populate", shrine_count == 1)

	main.queue_free()
	await tree.process_frame
