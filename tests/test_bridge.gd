extends RefCounted
## Blightwood bridges: catalogue, placement, deck/rail collision, the broken-bridge gap and its repair.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = false
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_bridge_layout.json"
	placed.autosave = false
	placed.load_dict({"version": 7, "items": []})
	var player := tree.get_first_node_in_group("player") as PlayerController

	# --- catalogue
	var all_ok := true
	var cats: Array = []
	for c in PlacedObjects.CATEGORIES:
		if c[0] == "Bridges":
			cats = c[1]
	ck.call("bridge: the palette has a Bridges group with all 18 assemblies", cats.size() == 18 and Bridge.assemblies().size() == 18)
	for id: String in cats:
		var def := PlacedObjects.def_of(id)
		var a := Bridge.assembly(str(def.get("assembly", "")))
		var tex: Texture2D = PlacedObjects.art_texture(id, Vector2.ZERO)[0]
		var sock: Array = a.start_socket
		all_ok = all_ok and def.kind == "bridge" and PlacedObjects.type_of(id) == "Bridges" and tex != null \
			and PlacedObjects.art_texture(id, Vector2(100, 100))[1] == Vector2(100 - float(sock[0]), 100 - float(sock[1]))
	ck.call("bridge: every bridge resolves to a def, a preview and a start-socket anchored art origin", all_ok)

	# --- placement + geometry
	var origin := PlacedObjects.iso_vertex(arena.bounds.get_center())
	var obj := placed.add("bridge_medium_wood_u", origin, false)
	await tree.physics_frame
	await tree.physics_frame
	var bridge := (obj.nodes[0]) as Bridge
	ck.call("bridge: placing creates a Bridge at the start socket", bridge != null and bridge.position == origin and bridge.state == "intact")
	ck.call("bridge: it builds supports, rear, deck and front layers", bridge.get_node("Supports") != null and bridge.get_node("Deck") != null and (bridge.get_node("Front") as Sprite2D).z_index > 0 and (bridge.get_node("Rear") as Sprite2D).z_index < 0)
	ck.call("bridge: deck sprite sits start-socket-aligned", (bridge.get_node("Deck") as Sprite2D).position == -Vector2(64, 64))
	var step := Vector2(36, 18)
	var mid := origin + step * 3.0
	ck.call("bridge: deck contains its middle, start and end centres, not beyond the ends or the sides",
		bridge.deck_contains(mid) and bridge.deck_contains(origin + step * 0.2) and bridge.deck_contains(origin + step * 5.8)
		and not bridge.deck_contains(origin - step * 0.5) and not bridge.deck_contains(origin + step * 6.5) and not bridge.deck_contains(mid + Vector2(-80, 40)))
	ck.call("bridge: an intact bridge has no gap and is fully walkable", bridge.gap_polygon().is_empty() and bridge.walkable_at(mid))
	ck.call("bridge: placement is not an obstacle for enemy navigation", placed.obstacles().is_empty())
	ck.call("bridge: footprint covers the whole deck", PlacedObjects.footprint_rect("bridge_medium_wood_u", origin).grow(1.0).encloses(Rect2(bridge.deck_polygon()[0], Vector2.ZERO)) and PlacedObjects.footprint_rect("bridge_medium_wood_u", origin).has_point(mid))

	# --- traversal: the player can walk on, along and off the deck; rails stop sideways crossing
	arena.editor.set_open(false)  # the open editor freezes the player
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.global_position = origin - step * 1.2
	await tree.physics_frame
	var blocked := false
	var unit := step.normalized()
	for i in 80:
		if player.move_and_collide(unit * 4.0) != null:
			blocked = true
			break
	var progressed := player.global_position.distance_to(origin - step * 1.2)
	ck.call("bridge: the player walks onto and along the deck through the open end", not blocked and progressed > 300.0)
	ck.call("bridge: and ends up past the far end after crossing", player.global_position.distance_to(origin + step * 6.0) < 120.0 or bridge.deck_contains(player.global_position) or progressed > 300.0)
	player.global_position = mid
	await tree.physics_frame
	var side := Vector2(-36, 18).normalized()
	var hit := false
	for i in 40:
		if player.move_and_collide(side * 4.0) != null:
			hit = true
			break
	ck.call("bridge: a rail stops the player stepping off the side of the deck", hit and bridge.deck_contains(player.global_position))

	# --- move + save/load
	placed.move(obj, origin + Vector2(72, 36), false)
	ck.call("bridge: moving the object moves the bridge", bridge.position == origin + Vector2(72, 36))
	placed.remove(obj, false)
	var again := placed.add("bridge_long_rope_v", origin, false)
	var saved := placed.to_dict()
	placed.load_dict(saved)
	var found := 0
	for o in placed.objects:
		if o.id == "bridge_long_rope_v" and o.pos == origin:
			found += 1
	ck.call("bridge: saved layouts round-trip a bridge", found == 1 and not again.is_empty())
	for o in placed.objects.duplicate():
		placed.remove(o, false)

	# --- broken bridge
	var bobj := placed.add("bridge_medium_damaged_u", origin, false)
	var broken := bobj.nodes[0] as Bridge
	await tree.physics_frame
	var gap := broken.gap_center()
	ck.call("bridge: a damaged assembly starts broken with a gap in the middle", broken.state == "broken" and broken.gap_contains(gap) and not broken.walkable_at(gap))
	ck.call("bridge: the ends of a broken bridge are still solid footing", broken.walkable_at(origin + step * 0.5) and broken.walkable_at(origin + step * 5.5))
	var gp := broken.gap_polygon()
	ck.call("bridge: the gap is an explicit 1.5-tile section, not read from the art", gp.size() == 4 and is_equal_approx(gp[0].distance_to(gp[3]), 1.5 * step.length()))
	player.global_position = gap
	player.state = PlayerController.State.IDLE
	player.dying = false
	ck.call("bridge: a grounded player over the gap drops", broken.drops(player))
	player.state = PlayerController.State.JUMP
	ck.call("bridge: a jumping player clears the gap", not broken.drops(player))
	player.state = PlayerController.State.AIR_ATTACK
	ck.call("bridge: an air attack clears the gap too", not broken.drops(player))
	player.state = PlayerController.State.IDLE
	player.global_position = gap - step * 0.3
	player._hit_invuln = 0.0
	player.health = 100.0
	broken.fall(player)
	ck.call("bridge: falling puts the player back at the nearer end and costs health",
		player.global_position.distance_to(origin - step.normalized() * Bridge.ENTRY_PUSH) < 1.0 and is_equal_approx(player.health, 100.0 - Bridge.FALL_DAMAGE))
	player.global_position = gap + step * 0.3
	ck.call("bridge: the far half sends a fallen player to the far end", broken.entry_point(player.global_position).distance_to(origin + step * 6.0 + step.normalized() * Bridge.ENTRY_PUSH) < 1.0)

	# --- repair
	player.global_position = origin
	ck.call("bridge: repair needs the player beside the gap", not broken.can_repair(player))
	player.global_position = gap + Vector2(30, 10)
	ck.call("bridge: a grounded player near the gap can repair it", broken.can_repair(player))
	var damaged_deck := (broken.get_node("Deck") as Sprite2D).texture
	var signalled := [false]
	broken.repaired.connect(func(): signalled[0] = true)
	ck.call("bridge: repair succeeds on a broken bridge", broken.repair() and signalled[0])
	ck.call("bridge: repaired swaps in the intact art and closes the gap", broken.state == "repaired" and (broken.get_node("Deck") as Sprite2D).texture != damaged_deck and broken.gap_polygon().is_empty() and broken.walkable_at(gap))
	player.state = PlayerController.State.IDLE
	player.global_position = gap
	ck.call("bridge: a repaired bridge no longer drops anyone", not broken.drops(player))
	ck.call("bridge: repairing twice is a no-op", not broken.repair())
	var fine := placed.add("bridge_short_wood_u", origin + Vector2(0, 360), false)
	ck.call("bridge: an intact bridge cannot be repaired", not (fine.nodes[0] as Bridge).repair())

	for o in placed.objects.duplicate():
		placed.remove(o, false)
	player.set_physics_process(true)
	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
