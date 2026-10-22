extends RefCounted
## World Builder: placing, solidity (physics + bandit nav), removal, moving, save/load and the panel toggle.
func _solid_at(arena: Node2D, p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collide_with_bodies = true
	return not arena.get_world_2d().direct_space_state.intersect_point(q).is_empty()


func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	var editor := arena.editor
	placed.save_path = "user://test_world_builder_layout.json"
	placed.autosave = false
	var grove := arena.get_node("BlossomGrove") as BlossomGrove
	ck.call("builder: panel and tab exist on the right, collapsed at start", editor != null and editor.panel != null and not editor.panel.visible and editor.tab.visible and not editor.open)
	editor.set_open(true)
	ck.call("builder: opening shows the panel and hides the tab", editor.panel.visible and not editor.tab.visible)
	ck.call("builder: panel is anchored to the right edge", editor.panel.anchor_left == 1.0 and editor.panel.anchor_right == 1.0)
	editor.set_open(false)
	ck.call("builder: hiding collapses it again", not editor.panel.visible and editor.tab.visible)
	var every := true
	for id: String in PlacedObjects.CATALOG:
		every = every and (PlacedObjects.footprint_of(id).x > 0.0)
	var listed := 0
	for cat: Array in PlacedObjects.CATEGORIES:
		listed += (cat[1] as Array).size()
	ck.call("builder: every catalog entry is listed in a palette section", every and listed == PlacedObjects.CATALOG.size() and PlacedObjects.CATALOG.size() >= 9)

	var base_trees := grove.trees.size()
	var base_objs := placed.objects.size()
	var nb := WorldScale.BLOCKS.size()
	ck.call("builder: the five starting trees and every placeholder wall are editable objects", base_trees == 5 and base_objs == 5 + nb)
	# a placeholder wall: pick, move (collision + nav follow), delete
	var wb: Array = WorldScale.BLOCKS[1]
	var wb_mid: Vector2 = (wb[0] as Vector2) + Vector2(0, -float((wb[1] as Vector2).y) * 0.5)
	editor.set_open(true)
	editor.set_tool("select")
	editor.press(wb_mid)
	ck.call("builder: clicking a placeholder wall selects it", not editor.selected.is_empty() and editor.selected.id == "base_1" and editor.dragging)
	editor.drag_to(wb_mid + Vector2(0, 450))
	editor.release()
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	var wmoved: Vector2 = editor.selected.pos
	ck.call("builder: a placeholder wall moves with collision and nav", wmoved != (wb[0] as Vector2) and _solid_at(arena, wmoved + Vector2(0, -float((wb[1] as Vector2).y) * 0.5)) and not _solid_at(arena, wb_mid) and not arena.nav.is_walkable(wmoved + Vector2(0, -20)))
	editor.delete_selected()
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: a placeholder wall can be deleted", placed.objects.size() == base_objs - 1 and not _solid_at(arena, wmoved + Vector2(0, -float((wb[1] as Vector2).y) * 0.5)))
	editor.set_open(false)
	editor._reset_armed = true
	editor._reset_pressed()
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	# an ORIGINAL tree can be picked, moved and deleted like any placed one
	var orig_pos: Vector2 = WorldScale.TREE_POSITIONS[0]
	editor.set_open(true)
	editor.set_tool("select")
	editor.press(orig_pos + Vector2(0, -120))
	ck.call("builder: clicking an original tree selects it", not editor.selected.is_empty() and editor.selected.id == "tree_1" and editor.dragging)
	editor.drag_to(orig_pos + Vector2(0, -120) + Vector2(240, 60))
	editor.release()
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	var moved_to: Vector2 = editor.selected.pos
	ck.call("builder: an original tree moves with its art and its solid base", moved_to != orig_pos and _solid_at(arena, moved_to + Vector2(0, -20)) and not _solid_at(arena, orig_pos + Vector2(0, -20)) and arena.nav.is_walkable(orig_pos + Vector2(0, -20)))
	editor.delete_selected()
	await root.get_tree().process_frame
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: an original tree can be deleted (art, collision and nav)", placed.objects.size() == base_objs - 1 and grove.trees.size() == base_trees - 1 and not _solid_at(arena, moved_to + Vector2(0, -20)) and arena.nav.is_walkable(moved_to + Vector2(0, -20)))
	editor._reset_armed = true
	editor._reset_pressed()
	await root.get_tree().process_frame
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: reset brings the five starting trees back in place", placed.objects.size() == 5 + nb and grove.trees.size() == 5 and _solid_at(arena, orig_pos + Vector2(0, -20)) and not arena.nav.is_walkable(orig_pos + Vector2(0, -20)))
	editor.set_open(false)
	base_trees = grove.trees.size()
	base_objs = placed.objects.size()
	var wall_pos := Vector2(-390, 600)
	var tree_pos := Vector2(-200, 700)
	ck.call("builder: nothing solid at the empty test spots yet", not _solid_at(arena, wall_pos + Vector2(0, -40)) and not _solid_at(arena, tree_pos + Vector2(0, -20)))
	var w := placed.add("wall_h", wall_pos)
	var t := placed.add("tree_3", tree_pos)
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: wall and tree were created", not w.is_empty() and not t.is_empty() and placed.objects.size() == base_objs + 2 and grove.trees.size() == base_trees + 1)
	ck.call("builder: a placed wall is solid", _solid_at(arena, wall_pos + Vector2(0, -40)))
	ck.call("builder: a placed tree trunk is solid", _solid_at(arena, tree_pos + Vector2(0, -20)))
	ck.call("builder: the tree canopy is NOT solid", not _solid_at(arena, tree_pos + Vector2(0, -250)))
	ck.call("builder: bandit nav treats placed objects as solid", not arena.nav.is_walkable(wall_pos + Vector2(0, -40)) and not arena.nav.is_walkable(tree_pos + Vector2(0, -20)))
	var bandit := arena.get_node_or_null("Bandit")
	ck.call("builder: live bandit gets the rebuilt nav", bandit != null and bandit.nav == arena.nav)

	ck.call("builder: hit-test picks the object under a click", placed.hit_test(wall_pos + Vector2(10, -40)) == w and placed.hit_test(tree_pos + Vector2(0, -120)) == t and placed.hit_test(Vector2(1000, 1000)).is_empty())

	var player := root.get_tree().get_first_node_in_group("player") as Node2D
	ck.call("builder: cannot place on top of the player", not placed.can_place("rock", player.global_position))
	ck.call("builder: cannot place outside the arena", not placed.can_place("rock", Vector2(arena.bounds.end.x + 500.0, 0)))
	ck.call("builder: can place on open ground", placed.can_place("rock", Vector2(-600, 560)))

	# move by dragging with the select tool
	editor.set_open(true)
	editor.snap = 30
	editor.set_tool("select")
	editor.press(wall_pos + Vector2(10, -40))
	ck.call("builder: select tool picks and starts a drag", editor.selected == w and editor.dragging)
	editor.drag_to(wall_pos + Vector2(10, -40) + Vector2(300, 0))
	editor.release()
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: dragged wall moved 300 px (snapped) and keeps its collision", (w.pos as Vector2).is_equal_approx(wall_pos + Vector2(300, 0)) and _solid_at(arena, wall_pos + Vector2(300, -40)) and not _solid_at(arena, wall_pos + Vector2(0, -40)))
	editor.press(w.pos + Vector2(0, -40))
	editor.drag_to(player.global_position)
	editor.release()
	ck.call("builder: dropping onto the player snaps back", (w.pos as Vector2).is_equal_approx(wall_pos + Vector2(300, 0)))

	# place and erase through the editor tools
	editor.set_tool("place", "crate")
	var before := placed.objects.size()
	editor.press(Vector2(-500, 480))
	ck.call("builder: place tool adds the picked item at the snapped click", placed.objects.size() == before + 1 and (placed.objects.back().pos as Vector2) == Vector2(-510, 480))
	editor.set_tool("erase")
	editor.press(Vector2(-510, 480 - 40))
	ck.call("builder: erase tool removes the clicked object", placed.objects.size() == before)
	editor.set_tool("select")
	editor.press(tree_pos + Vector2(0, -20))
	editor.release()
	editor.delete_selected()
	await root.get_tree().process_frame
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: delete removes the tree, its collision and its art node", placed.objects.size() == base_objs + 1 and grove.trees.size() == base_trees and not _solid_at(arena, tree_pos + Vector2(0, -20)) and arena.nav.is_walkable(tree_pos + Vector2(0, -20)))

	# explicit save button
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	ck.call("builder: save button exists and Save writes the layout file", editor.save_button != null and editor.save_now() and FileAccess.file_exists(placed.save_path) and "SAVED" in editor.status.text)
	# save / load round trip
	placed.add("rock", Vector2(-600, 560))
	placed.add("tree_1", Vector2(-300, 800))
	var snapshot := placed.to_dict()
	ck.call("builder: save writes a file", placed.save() and FileAccess.file_exists(placed.save_path))
	placed.clear_all()
	ck.call("builder: clear removes everything", placed.objects.is_empty() and grove.trees.is_empty())
	var made := placed.load_saved()
	ck.call("builder: load restores the same layout", made == (snapshot.items as Array).size() and JSON.stringify(placed.to_dict()) == JSON.stringify(snapshot))
	made = placed.load_dict({"version": 1, "items": [{"id": "nope", "x": 0, "y": 0}, {"id": "rock", "x": "a", "y": 1}, {"id": "rock", "x": 0, "y": 135}, {"id": "rock", "x": -600, "y": 560}]})
	ck.call("builder: load skips unknown ids, bad numbers and objects on the spawn (v1 save also gets the starting trees)", made == 1 and placed.objects.size() == 6 + nb)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	placed.clear_all()
	editor.set_open(false)
	main.queue_free()
	await root.get_tree().process_frame
