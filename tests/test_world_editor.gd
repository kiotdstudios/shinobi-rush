extends RefCounted
## World Builder: placing, solidity (physics + bandit nav), removal, moving, save/load and the panel toggle.
func _solid_at(arena: Node2D, p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collide_with_bodies = true
	return not arena.get_world_2d().direct_space_state.intersect_point(q).is_empty()


## Builder objects other than floating pickups (random health gourds are scattered on top of the fixed starting world).
func _non_pickups(placed: PlacedObjects) -> int:
	var n := 0
	for o in placed.objects:
		if PlacedObjects.def_of(o.id).kind != "pickup":
			n += 1
	return n


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
	# HUD pieces are movable from the builder
	var hud := editor.hud_bar() as HealthBar
	if hud != null:
		hud.layout_path = "user://test_hud_layout_drag.json"
		hud.offsets.clear()
	ck.call("hud layout: the player's HUD is found by the builder and starts unedited", hud != null and not hud.edit_mode and hud.offsets.is_empty())
	editor.set_open(true)
	await root.get_tree().process_frame
	ck.call("hud layout: opening the builder turns HUD edit mode on", hud.edit_mode)
	var hp0 := hud.element_rect("hp_bar")
	var ch0 := hud.element_rect("chakra_bar")
	ck.call("hud layout: a click on the HP bar picks the HP bar, and the chakra bar independently", hud.element_at(hp0.get_center()) == "hp_bar" and hud.element_at(ch0.get_center()) == "chakra_bar")
	ck.call("hud layout: the avatar sits over the bars' tucked ends (topmost wins)", hud.element_at(hud.element_rect("portrait").get_center()) == "portrait")
	ck.call("hud layout: empty screen picks nothing", hud.element_at(Vector2(640, 300)) == "")
	hud.hud_snap = 0  # free drag for the exact-offset checks below; grid behaviour is tested after
	var grabbed := editor.press_hud(hp0.get_center())
	hud.drag_at(hp0.get_center() + Vector2(40, 25))
	editor.release_hud()
	ck.call("hud layout: dragging the HP bar moves only the HP bar", grabbed and hud.offsets.get("hp_bar") == Vector2(40, 25) and not hud.offsets.has("chakra_bar") and hud.element_rect("hp_bar").position == hp0.position + Vector2(40, 25))
	editor.set_tool("erase")
	ck.call("hud layout: only the select tool picks HUD pieces", not editor.press_hud(hud.element_rect("chakra_bar").get_center()))
	editor.set_tool("select")
	editor.select_hud("pips")
	hud.move_element("pips", Vector2(-6, 3))
	ck.call("hud layout: a piece picked from the panel list nudges", hud.selected_element == "pips" and hud.offsets.get("pips") == Vector2(-6, 3))
	var layout_path := "user://test_hud_layout.json"
	ck.call("hud layout: saves", hud.save_layout(layout_path))
	hud.offsets.clear()
	hud.load_layout(layout_path)
	ck.call("hud layout: reloads the same offsets", hud.offsets.get("hp_bar") == Vector2(40, 25) and hud.offsets.get("pips") == Vector2(-6, 3), hud.layout_json())
	hud.apply_layout_json("{\"bogus\":[1,2],\"portrait\":[3,4]}")
	ck.call("hud layout: unknown ids in a saved file are ignored", hud.offsets.size() == 1 and hud.offsets.get("portrait") == Vector2(3, 4))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(layout_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hud.layout_path))
	hud.offsets.clear()
	ck.call("hud layout: the ability bar has Substitution plus four circle slots, each its own piece", HealthBar.ELEMENTS.has("ability_0") and HealthBar.ELEMENTS.has("ability_4") and HealthBar.ABILITY_LABELS.size() == HealthBar.SLOT_COUNT and HealthBar.SLOT_COUNT == 5)
	editor.select_hud("pips")
	editor.set_open(false)
	await root.get_tree().process_frame
	ck.call("hud layout: closing the builder ends HUD edit mode and clears the pick", not hud.edit_mode and hud.selected_element == "")
	hud.hud_snap = 8
	hud.offsets.clear()
	hud.layout_path = "user://test_hud_layout_align.json"
	editor.set_open(true)
	editor.press_hud(hud.element_rect("hp_bar").get_center())
	hud.drag_at(hud.element_rect("hp_bar").get_center() + Vector2(13, 11))
	editor.release_hud()
	var hp_p := hud.pos_of("hp_bar")
	ck.call("hud grid: a snapped drag lands on the 8px grid", int(hp_p.x) % 8 == 0 and int(hp_p.y) % 8 == 0, str(hp_p))
	hud.dragging_element = true
	hud.selected_element = "hp_bar"
	hud.drag_at(Vector2(99999, 99999))
	hud.dragging_element = false
	ck.call("hud grid: a piece can never be dragged off screen", hud.element_rect("hp_bar").end.x <= hud._canvas.size.x + 0.5 and hud.element_rect("hp_bar").end.y <= hud._canvas.size.y + 0.5)
	hud.offsets.clear()
	hud.r2_to_right_edge(24.0)
	var wcanvas: float = hud._canvas.size.x if hud._canvas.size.x > 0.0 else 1280.0
	ck.call("hud align: the R2 cluster right edge sits at the screen edge minus margin", absf(hud.r2_bounds().end.x - (wcanvas - 24.0)) < 0.6, str(hud.r2_bounds()))
	hud.move_element("ability_0", Vector2(0, -90))
	hud.align_substitution_with_r2()
	ck.call("hud align: Substitution centre is level with the R2 cluster centre", absf(hud.element_rect("ability_0").get_center().y - hud.r2_bounds().get_center().y) < 0.6)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hud.layout_path))
	hud.offsets.clear()
	var hud_check := editor._filter_buttons.get("HUD layout") as CheckBox
	ck.call("builder: a HUD layout filter checkbox exists and starts unticked (HUD controls hidden)", hud_check != null and not hud_check.button_pressed and not (editor._category_sections["HUD layout"] as Control).visible)
	editor.set_type_filter("HUD layout", true)
	ck.call("builder: ticking it reveals the HUD controls", (editor._category_sections["HUD layout"] as Control).visible)
	editor.set_type_filter("HUD layout", false)
	ck.call("builder: the palette keeps a minimum height", editor.palette_scroll.custom_minimum_size.y >= 200.0)
	editor.set_open(false)
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
	var grass_total := (arena.get_node("WindGrassField") as WindGrassField).initial_tiles.size()
	ck.call("builder: the five starting trees and every placeholder wall are editable objects", base_trees == 5 and base_objs == 5 + nb + 1 + grass_total + PlacedObjects.DEFAULT_GOURDS + PlacedObjects.DEFAULT_CHAKRA_GOURDS)
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
	ck.call("builder: an original tree can be deleted (art, collision and nav)", _non_pickups(placed) == 5 + nb + 1 + grass_total - 1 and grove.trees.size() == base_trees - 1 and not _solid_at(arena, moved_to + Vector2(0, -20)) and arena.nav.is_walkable(moved_to + Vector2(0, -20)))
	editor._reset_armed = true
	editor._reset_pressed()
	await root.get_tree().process_frame
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	ck.call("builder: reset brings the five starting trees back in place", _non_pickups(placed) == 5 + nb + 1 + grass_total and grove.trees.size() == 5 and _solid_at(arena, orig_pos + Vector2(0, -20)) and not arena.nav.is_walkable(orig_pos + Vector2(0, -20)))
	ck.call("builder: reset also scatters a fresh set of health and chakra gourds", placed.objects.size() - _non_pickups(placed) == PlacedObjects.DEFAULT_GOURDS + PlacedObjects.DEFAULT_CHAKRA_GOURDS, str(placed.objects.size() - _non_pickups(placed)))
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

	# Decorative grass uses shared wind but never becomes a physics/nav obstacle.
	var field := arena.get_node("WindGrassField") as WindGrassField
	ck.call("builder grass: all original terrain and tall accents are editable", grass_total == 358 and field.ground_count() == 247 and field.tall_count() == 111 and field.ground.get_used_cells().is_empty())
	var nav_before := placed.obstacles().size()
	var g := placed.add("grass9_center", Vector2(-420, 850))
	var tall := placed.add("grass_tall_00", Vector2(-540, 850))
	await root.get_tree().physics_frame
	ck.call("builder grass: uses original wind material and ground anchors", (g.nodes[0] as Sprite2D).material == field.ground_wind and (g.nodes[0] as Sprite2D).offset == Vector2(-56, -84) and (tall.nodes[0] as Sprite2D).offset == Vector2(-56, -136))
	ck.call("builder grass: no collision or nav obstacle added", placed.obstacles().size() == nav_before and not _solid_at(arena, Vector2(-420, 830)) and placed.can_place("grass9_center", player.global_position))
	field.advance(0.0)
	ck.call("grass bends: the player and bandits are fed to both grass materials as pushers (visual only, no blocking)", field.pushers.size() >= 1 and int(field.ground_wind.get_shader_parameter("push_count")) == field.pushers.size() and int(field.tall_wind.get_shader_parameter("push_count")) == field.pushers.size() and field.pushers.has(player.global_position))
	editor.set_tool("select")
	editor.press(g.pos)
	editor.drag_to(Vector2(-360, 900))
	editor.release()
	ck.call("builder grass: select and drag moves art on the floor grid", editor.selected == g and g.pos == editor.snapped_pos(Vector2(-360, 900)) and (g.nodes[0] as Node2D).position == g.pos)
	editor.snap = 0
	ck.call("builder grass: snap off allows free positioning", editor.snapped_pos(Vector2(123, 456)) == Vector2(123, 456))
	editor.snap = 30
	var layout_before := placed.to_json_string()
	editor.set_type_filter("Grass", false)
	ck.call("builder filters: hide the palette options only; the world art stays visible and pickable, layout untouched", (g.nodes[0] as CanvasItem).visible and not (editor._category_sections["Grass"] as Control).visible and placed.hit_test(g.pos) == g and placed.to_json_string() == layout_before and editor.selected == g)
	editor.set_type_filter("Trees", false)
	ck.call("builder filters: hidden palette options leave world collision/nav alone", placed.type_visible("tree_1") and not arena.nav.is_walkable(WorldScale.TREE_POSITIONS[0] + Vector2(0, -20)))
	editor.set_type_filter("Grass", true)
	editor.set_type_filter("Trees", true)
	ck.call("builder filters: reveal restores art and picking", (g.nodes[0] as CanvasItem).visible and placed.hit_test(g.pos) == g)
	editor.press(g.pos)
	editor.release()
	editor.delete_selected()
	ck.call("builder grass: delete removes only the picked tile", field.ground_count() == 247 and field.tall_count() == 112 and placed.objects.has(tall))
	placed.remove(tall)
	# A v4 save records starting-grass deletion instead of reseeding it on reload.
	var original_grass: Dictionary = {}
	for obj in placed.objects:
		if obj.id == "grass9_center":
			original_grass = obj
			break
	placed.remove(original_grass)
	var edited_layout := placed.to_dict()
	placed.load_dict(edited_layout)
	ck.call("builder grass: v4 reload preserves deletions and counts", field.ground_count() == 246 and field.tall_count() == 111 and placed.objects.size() == (edited_layout.items as Array).size())
	# Existing checks below start from the full original meadow again.
	placed.add(original_grass.id, original_grass.pos)

	# explicit save button
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	ck.call("builder: save button exists and Save writes the layout file", editor.save_button != null and editor.save_now() and FileAccess.file_exists(placed.save_path) and "SAVED" in editor.status.text)
	# save / load round trip
	placed.add("rock", Vector2(-600, 560))
	placed.add("tree_1", Vector2(-300, 800))
	var snapshot := placed.to_dict()
	ck.call("builder: save writes a file", placed.save() and FileAccess.file_exists(placed.save_path))
	placed.clear_all(false)
	ck.call("builder: clear removes everything", placed.objects.is_empty() and grove.trees.is_empty())
	var made := placed.load_saved()
	ck.call("builder: load restores the same layout", made == (snapshot.items as Array).size() and JSON.stringify(placed.to_dict()) == JSON.stringify(snapshot))
	made = placed.load_dict({"version": 1, "items": [{"id": "nope", "x": 0, "y": 0}, {"id": "rock", "x": "a", "y": 1}, {"id": "rock", "x": 0, "y": 135}, {"id": "rock", "x": -600, "y": 560}]})
	ck.call("builder: load skips unknown ids, bad numbers and objects on the spawn (v1 save also gets the starting trees)", made == 1 and placed.objects.size() == 6 + nb + grass_total)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	var floor_map := arena.find_child("FloorTiles", true, false) as TileMapLayer
	var snap_ok := floor_map != null
	for cell in [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-7, 5), Vector2i(12, 9)]:
		var centre := floor_map.position + floor_map.map_to_local(cell)
		snap_ok = snap_ok and WorldEditor.iso_cell_center(centre + Vector2(9, -5)).is_equal_approx(centre)
	ck.call("builder: grass snaps to the floor tile grid (cell centres match the floor TileMapLayer)", snap_ok)
	var grass_field := arena.get_node("WindGrassField") as WindGrassField
	var origin_ok := true
	for tile in grass_field.initial_tiles:
		var gp: Vector2 = tile.pos
		origin_ok = origin_ok and WorldEditor.iso_cell_center(gp).is_equal_approx(gp)
	ck.call("builder: the original grass field already sits on the floor grid", origin_ok)
	ck.call("builder: grass footprint is centred on its cell", PlacedObjects.footprint_rect("grass9_center", Vector2(72, 36)).get_center().is_equal_approx(Vector2(72, 36)))
	var player_node := root.get_tree().get_first_node_in_group("player") as PlayerController
	editor.set_open(true)
	root.get_tree().paused = true
	editor.set_tool("pan")
	editor.pan_by(Vector2(40, 20))
	var panned := player_node.camera.offset
	ck.call("builder: pan moves the camera while the game is paused, and the camera keeps processing", panned.x < 0.0 and panned.y < 0.0 and player_node.camera.process_mode == Node.PROCESS_MODE_ALWAYS and editor.overlay.process_mode == Node.PROCESS_MODE_ALWAYS)
	var before_n: int = placed.objects.size()
	editor.set_tool("place", "rock")
	editor.press(Vector2(400, 300))
	editor.release()
	ck.call("builder: placing works while the game is paused (Esc)", placed.objects.size() == before_n + 1)
	root.get_tree().paused = false
	editor.set_open(false)
	ck.call("builder: closing the builder re-centres the camera and restores its pause behaviour", player_node.camera.offset == Vector2.ZERO and player_node.camera.process_mode == Node.PROCESS_MODE_INHERIT)
	# wall kit: chained pieces join exactly, collide, feed the nav, save/load and delete cleanly
	var v0 := PlacedObjects.iso_vertex(arena.bounds.get_center() + Vector2(300, 200))
	ck.call("wall kit: iso_vertex lands on a floor-diamond vertex (36a, 18b, a+b odd)", posmod(int(round(v0.x / 36.0)) - int(round(v0.y / 18.0)), 2) == 1 and PlacedObjects.iso_vertex(v0 + Vector2(5, 3)) == v0)
	var wall_n := placed.objects.size()
	var nav_n := placed.obstacles().size()
	var run_a: Vector2 = PlacedObjects.CATALOG["kit_se_3"].col
	var run_b: Vector2 = PlacedObjects.CATALOG["kit_se_2"].col
	var a_obj := placed.add("kit_se_3", v0, false)
	var b_obj := placed.add("kit_se_2", v0 + run_a, false)
	var c_obj := placed.add("kit_pillar", v0 + run_a + run_b, false)
	var d_obj := placed.add("kit_sw_4", v0 + run_a + run_b, false)
	# Bug fix (2026-10-23): a long wall run now draws as multiple y-sort slices (one per kit cell,
	# see PlacedObjects._wall_slice_count) instead of one sprite with a single whole-run-midpoint
	# sort key -- that single key was the reported bug (player standing near either end of a long
	# wall visibly drew OVER it instead of being hidden). nodes is now [slice..., body], size
	# slice_count+1, not always exactly 2; the first node is still the piece's first (nearest) slice
	# and the LAST node is still the body, regardless of how many slices a given run has.
	var a_n := PlacedObjects._wall_slice_count(run_a)
	ck.call("wall kit: pieces are added as N slices (one per kit cell) + collider, listed under Temple walls",
		placed.objects.size() == wall_n + 4 and a_obj.nodes.size() == a_n + 1 and a_obj.nodes[0] is Sprite2D and a_obj.nodes[a_obj.nodes.size() - 1] is StaticBody2D and PlacedObjects.type_of("kit_se_3") == "Temple walls")
	var sa := a_obj.nodes[0] as Sprite2D
	var sb := b_obj.nodes[0] as Sprite2D
	var start_a := sa.global_position + sa.offset + (PlacedObjects.CATALOG["kit_se_3"].anchor as Vector2)
	var start_b := sb.global_position + sb.offset + (PlacedObjects.CATALOG["kit_se_2"].anchor as Vector2)
	ck.call("wall kit: a piece placed at the previous piece's pos + run starts exactly where it ends", start_a.is_equal_approx(v0) and start_b.is_equal_approx(v0 + run_a))
	ck.call("wall kit: nav gets one 36x36 box per crossed cell (3 + 2 + 1 pillar + 4)", placed.obstacles().size() == nav_n + 3 + 2 + 1 + 4)
	var body_a := a_obj.nodes[a_obj.nodes.size() - 1] as StaticBody2D
	ck.call("wall kit: the collider is a parallelogram along the run", body_a.get_child_count() == 1 and ((body_a.get_child(0) as CollisionShape2D).shape as ConvexPolygonShape2D).points.size() == 4 and body_a.global_position == a_obj.pos)
	ck.call("wall kit: clicking the picture selects the piece", placed.hit_test(a_obj.pos + Vector2(20, -60)).get("id", "") == "kit_se_3")
	placed.move(a_obj, a_obj.pos + Vector2(72, 36), false)
	# sa is the first (nearest) slice; per-slice correctness (monotonic keys, exact screen-pixel
	# identity) is covered exhaustively in tests/test_wall_kit_sort.gd -- this just checks move()
	# actually re-derives sa's position from the NEW pos via the shared helper, not a stale value.
	var expect_sa: Vector2 = PlacedObjects._wall_slice_transform(PlacedObjects.CATALOG["kit_se_3"], a_obj.pos, sa.get_meta("x0"), sa.get_meta("w"), PlacedObjects.wall_texture("kit_se_3").get_width()).position
	ck.call("wall kit: moving carries sprite and collider", body_a.position == a_obj.pos and sa.position.is_equal_approx(expect_sa))
	var saved := placed.to_dict()
	placed.remove(c_obj, false)
	placed.remove(d_obj, false)
	placed.remove(b_obj, false)
	placed.remove(a_obj, false)
	await root.get_tree().process_frame
	ck.call("wall kit: removing frees every node", placed.objects.size() == wall_n and not is_instance_valid(sa) and not is_instance_valid(body_a))
	var ids_saved := 0
	for it: Dictionary in saved.items:
		if str(it.id).begins_with("kit_"):
			ids_saved += 1
	ck.call("wall kit: the four pieces are in the save data by id", ids_saved == 4)

	editor.set_open(true)
	placed.clear_all()
	placed.save()
	ck.call("builder: Clear all never persists an empty world (file removed, next boot keeps defaults)", not FileAccess.file_exists(placed.save_path) and placed.load_saved() == 0)
	var f := FileAccess.open(placed.save_path, FileAccess.WRITE)
	f.store_string('{"version":3,"items":[]}')
	f.close()
	ck.call("builder: an old empty v3 save is ignored on boot", placed.load_saved() == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(placed.save_path))
	editor.set_open(false)
	var old_b := arena.get_node("Bandit") as Bandit
	old_b.take_damage(old_b.max_hp + 1.0, Vector2.RIGHT, 0.0, 0.0)
	ck.call("bandit respawn: defeated bandit is down and still present until the delay passes", not old_b.is_alive() and is_instance_valid(old_b))
	await root.get_tree().create_timer(TrainingArena.BANDIT_RESPAWN_DELAY + 0.6).timeout
	var new_b := arena.get_node_or_null("Bandit") as Bandit
	ck.call("bandit respawn: a fresh living Bandit stands at home with full hp and the nav; the dead one is gone", new_b != null and new_b != old_b and new_b.is_alive() and new_b.hp == new_b.max_hp and new_b.position.distance_to(WorldScale.BANDIT_HOME) < 150.0 and new_b.nav == arena.nav and (not is_instance_valid(old_b) or old_b.is_queued_for_deletion()))
	var alive := 0
	for e in root.get_tree().get_nodes_in_group("enemy"):
		if e is Bandit and (e as Bandit).is_alive() and not e.is_queued_for_deletion():
			alive += 1
	ck.call("bandit respawn: exactly one living Bandit", alive == 1)
	main.queue_free()
	await root.get_tree().process_frame
