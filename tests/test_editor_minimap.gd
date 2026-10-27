extends RefCounted
## Map editor minimap and view controls: the minimap is drawn from the real placed objects, click moves the view,
## the wheel zooms at the cursor (clamped), middle-drag pans, and M / F1 / the View menu items all do something.

var ck: Callable


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _mouse(btn: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = pressed
	e.position = pos
	return e


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
	placed.save_path = "user://test_minimap_layout.json"
	placed.autosave = false
	var ed := arena.editor
	ed.void_check = false
	var sh := ed.shell
	var mm := sh.minimap

	ck.call("minimap: the shell builds a minimap", mm != null and mm is EditorMinimap and sh.is_ancestor_of(mm))
	ck.call("minimap: shaped like the arena", absf(mm.size.x - EditorMinimap.W) < 0.5 and mm.bounds == arena.bounds, str(mm.size))
	var c := mm.to_map(arena.bounds.get_center())
	ck.call("minimap: world centre maps to the middle", c.distance_to(mm.size * 0.5) < 1.0, str(c))
	ck.call("minimap: to_world inverts to_map", mm.to_world(mm.to_map(Vector2(100, -200))).distance_to(Vector2(100, -200)) < 0.5)
	var cr := sh.canvas_rect()
	ck.call("minimap: sits inside the free canvas", cr.encloses(Rect2(mm.position, mm.size)), "%s vs %s" % [Rect2(mm.position, mm.size), cr])

	# drawn from real objects
	var lit := 0
	for y in int(mm.size.y):
		for x in int(mm.size.x):
			if mm._img.get_pixel(x, y).is_equal_approx(EditorMinimap.BG_COLOR) == false:
				lit += 1
	ck.call("minimap: the placed map is painted on it", lit > 200, str(lit))
	var cols: Dictionary = {}
	for o: Dictionary in placed.objects:
		cols[EditorMinimap.color_for(o.id)] = true
	ck.call("minimap: kinds get distinct colours", cols.size() >= 2, str(cols.size()))

	# hiding every layer empties it
	var before: PackedByteArray = mm._img.get_data()
	var all_types: Array = []
	for o: Dictionary in placed.objects:
		var t := PlacedObjects.type_of(o.id)
		if not all_types.has(t):
			all_types.append(t)
	for t in all_types:
		placed.hidden_types[t] = true
	mm.rebuild()
	ck.call("minimap: hidden layers drop off it", mm._img.get_data() != before)
	placed.hidden_types.clear()
	mm.rebuild()
	ck.call("minimap: showing them again brings them back", mm._img.get_data() == before)

	# click to move the view
	var target := arena.bounds.get_center() + Vector2(arena.bounds.size.x * 0.2, -arena.bounds.size.y * 0.15)
	var click := mm.to_map(target)
	mm._gui_input(_mouse(MOUSE_BUTTON_LEFT, true, click))
	mm._gui_input(_mouse(MOUSE_BUTTON_LEFT, false, click))
	await tree.process_frame
	var vc := ed.view_center()
	var free_mid := sh.canvas_rect().get_center()
	var shifted := (ed.get_viewport().get_visible_rect().get_center() - free_mid) / ed._camera().zoom.x
	ck.call("minimap: clicking moves the view there", (vc - shifted).distance_to(target) < 6.0, "%s want %s" % [vc - shifted, target])

	# zoom
	var cam := ed._camera()
	var z0 := cam.zoom.x
	var pt := sh.canvas_rect().get_center() + Vector2(80, 40)
	var vp := ed.get_viewport()
	var world_before: Vector2 = vp.get_canvas_transform().affine_inverse() * pt
	ed.zoom_by(1.25, pt)
	cam.force_update_scroll()
	var world_after: Vector2 = vp.get_canvas_transform().affine_inverse() * pt
	ck.call("zoom: zooming in changes the zoom", cam.zoom.x > z0)
	ck.call("zoom: the point under the cursor stays put", world_before.distance_to(world_after) < 2.0, "%s -> %s" % [world_before, world_after])
	for i in 30:
		ed.zoom_by(1.5)
	ck.call("zoom: clamped at the maximum", is_equal_approx(cam.zoom.x, WorldEditor.VIEW_ZOOM_MAX))
	for i in 30:
		ed.zoom_by(0.5)
	ck.call("zoom: clamped at the minimum", is_equal_approx(cam.zoom.x, WorldEditor.VIEW_ZOOM_MIN))
	ed.set_view_zoom(1.0)
	ck.call("zoom: 100% is the base zoom", is_equal_approx(cam.zoom.x, WorldScale.CAMERA_BASE_ZOOM), str(cam.zoom.x))

	# the wheel
	var z1 := cam.zoom.x
	ed._unhandled_input(_mouse(MOUSE_BUTTON_WHEEL_UP, true, pt))
	ck.call("wheel: up zooms in", cam.zoom.x > z1)
	var z2 := cam.zoom.x
	ed._unhandled_input(_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, pt))
	ck.call("wheel: down zooms out", cam.zoom.x < z2)

	# fit the whole map
	ed.fit_map()
	cam.force_update_scroll()
	var vr := mm.view_world_rect()
	ck.call("fit: the whole arena is visible", vr.grow(4.0).encloses(arena.bounds), "%s vs %s" % [vr, arena.bounds])

	# middle-drag pans
	ed.set_view_zoom(1.0)
	var c0 := ed.view_center()
	ed._unhandled_input(_mouse(MOUSE_BUTTON_MIDDLE, true, pt))
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(60, 0)
	mv.position = pt + mv.relative
	ed._unhandled_input(mv)
	ed._unhandled_input(_mouse(MOUSE_BUTTON_MIDDLE, false, pt))
	ck.call("pan: middle-drag moves the view", ed.view_center().distance_to(c0) > 20.0, str(ed.view_center() - c0))

	# keys and menu
	var open0 := sh.minimap_open
	ed._unhandled_input(_key(KEY_M))
	ck.call("keys: M toggles the minimap", sh.minimap_open != open0 and mm.visible == sh.minimap_open)
	ed._unhandled_input(_key(KEY_M))
	ck.call("keys: M toggles it back", sh.minimap_open == open0)
	ck.call("shortcuts: hidden at first", not sh.shortcuts_panel.visible)
	ed._unhandled_input(_key(KEY_F1))
	await tree.process_frame
	await tree.process_frame
	ck.call("keys: F1 opens the shortcuts list", sh.shortcuts_panel.visible and sh.canvas_rect().encloses(Rect2(sh.shortcuts_panel.position, sh.shortcuts_panel.size)), str(sh.shortcuts_panel.position))
	sh._on_view_item(9)
	ck.call("menu: Keyboard shortcuts closes it again", not sh.shortcuts_panel.visible)
	var zz := cam.zoom.x
	sh._on_view_item(5)
	ck.call("menu: Zoom in", cam.zoom.x > zz)
	sh._on_view_item(6)
	ck.call("menu: Zoom out", is_equal_approx(cam.zoom.x, zz))
	sh._on_view_item(8)
	ck.call("menu: Zoom 100%", is_equal_approx(cam.zoom.x, WorldScale.CAMERA_BASE_ZOOM))
	sh._on_view_item(4)
	ck.call("menu: Minimap item toggles it", sh.minimap_open != open0)

	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
	WorldEditor.use_palette(false)
