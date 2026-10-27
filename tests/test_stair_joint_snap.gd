extends RefCounted
## Builder: a cliff ledge dropped near the earth stairs joins flush at the stair head, and the stair art draws
## over the ledge face behind it instead of the ledge's end covering the top steps.


func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	var editor := arena.editor
	placed.save_path = "user://test_stair_joint_snap.json"
	placed.autosave = false
	var at := PlacedObjects.iso_vertex(Vector2(-900, 900))
	var stair := placed.add("earth_stairs_se", at)
	var sdef := PlacedObjects.def_of("earth_stairs_se")
	var head: Vector2 = at + (sdef.ramp_top as Vector2)
	var left_corner: Vector2 = head - (sdef.ramp_half as Vector2)
	var right_corner: Vector2 = head + (sdef.ramp_half as Vector2)
	var run: Vector2 = PlacedObjects.def_of("cliff_ledge_se").col
	var lattice_left := PlacedObjects.iso_vertex(left_corner - run + Vector2(8, -6))
	ck.call("ledge snap: the floor lattice alone cannot end a ledge on the stair head", lattice_left + run != left_corner, str(lattice_left))
	ck.call("ledge snap: left ledge end pulled onto the stair's left head corner", placed.snap_joint("cliff_ledge_se", lattice_left) + run == left_corner)
	ck.call("ledge snap: right ledge start pulled onto the stair's right head corner", placed.snap_joint("cliff_ledge_se", right_corner + Vector2(14, 6)) == right_corner)
	var far := left_corner + Vector2(400, 300)
	ck.call("ledge snap: a ledge far from any joint stays where it was dropped", placed.snap_joint("cliff_ledge_se", far) == far)
	editor.set_open(true)
	editor.snap = 30
	editor.set_tool("place", "cliff_ledge_se")
	var placed_at := editor.placement_pos("cliff_ledge_se", left_corner - run + Vector2(10, -4))
	ck.call("ledge snap: the builder's place tool uses the joint", placed_at + run == left_corner, str(placed_at))
	var left := placed.add("cliff_ledge_se", placed_at)
	var right := placed.add("cliff_ledge_se", editor.placement_pos("cliff_ledge_se", right_corner + Vector2(-9, 12)))
	placed._changed(false)
	ck.call("ledge snap: right ledge starts at the stair head", right.pos == right_corner, str(right.pos))
	ck.call("ledge snap: dragging a joined ledge ignores its own ends", placed.snap_joint("cliff_ledge_se", (left.pos as Vector2) + Vector2(6, 9), left) == left.pos)
	var zone := stair.nodes[stair.nodes.size() - 1] as CliffElevation
	ck.call("ledge snap: builder-placed ledges link to the stair zone", zone.ground_bodies.size() == 2 and not zone.occluders.is_empty())
	var art := stair.nodes[0] as Sprite2D
	ck.call("ledge snap: stair art is the zone's own art, normal depth when idle", zone.art.has(art) and art.z_index == 0)
	var stair_rect := Rect2(art.position + art.offset, art.texture.get_size())
	var behind := true
	var overlapping := 0
	for n: Node in left.nodes:
		var s := n as Sprite2D
		if s == null:
			continue
		if Rect2(s.position + s.offset, s.texture.get_size()).intersects(stair_rect):
			overlapping += 1
			behind = behind and s.z_index == art.z_index and s.position.y < art.position.y
	ck.call("ledge snap: stair draws over every left-ledge slice it overlaps", overlapping > 0 and behind, "%d slices" % overlapping)
	main.queue_free()
	await root.get_tree().process_frame
