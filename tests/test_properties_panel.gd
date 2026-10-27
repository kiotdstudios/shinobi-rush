extends RefCounted
## Map editor Properties card and layer panel: typed X / Y really move the object (one undo step), duplicate and delete work,
## locked layers refuse, and the layer rows show real counts.

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
	placed.save_path = "user://test_properties_layout.json"
	placed.autosave = false
	var ed := arena.editor
	ed.void_check = false
	var sh := ed.shell
	var pp := ed.properties

	ck.call("properties: the black shell builds the Properties card", pp != null and ed.inspector.is_ancestor_of(pp) and sh.right.is_ancestor_of(pp))
	ck.call("properties: the old one-line inspector row is hidden", not ed.inspector.get_child(0).visible)

	var pick: Dictionary = {}
	for o: Dictionary in placed.objects:
		if PlacedObjects.def_of(o.id).kind == "tree":
			pick = o
			break
	ck.call("properties: the map has a tree to test with", not pick.is_empty())
	ed.selected = pick
	ed._refresh()
	await tree.process_frame
	var def: Dictionary = PlacedObjects.def_of(pick.id)
	ck.call("properties: shows the name and layer", pp.title.text == str(def.label) and pp.layer_label.text == "Layer: " + PlacedObjects.type_of(pick.id), pp.title.text + " | " + pp.layer_label.text)
	ck.call("properties: shows the real X and Y", is_equal_approx(pp.x_field.value, roundf(pick.pos.x)) and is_equal_approx(pp.y_field.value, roundf(pick.pos.y)))
	ck.call("properties: shows the footprint", pp.size_label.text.begins_with("Footprint"), pp.size_label.text)

	# typed position moves the real object, one undo step
	placed.clear_history()
	var from: Vector2 = pick.pos
	var target := from
	var moved := false
	for off in [Vector2(90, 0), Vector2(-90, 0), Vector2(0, 90), Vector2(0, -90)]:
		if placed.can_place(pick.id, from + off):
			target = from + off
			moved = true
			break
	ck.call("properties: found a free spot to move to", moved)
	pp.x_field.value = target.x
	pp.y_field.value = target.y
	await tree.process_frame
	ck.call("properties: typing X / Y moves the object", pick.pos.distance_to(target) < 1.5, "%s -> %s (want %s)" % [from, pick.pos, target])
	ck.call("properties: the move is a real undo step", placed.can_undo())
	placed.undo()
	await tree.process_frame
	ck.call("properties: undo puts it back", pick.pos.distance_to(from) < 1.5, str(pick.pos))
	await tree.process_frame
	ck.call("properties: the fields follow the undo", is_equal_approx(pp.x_field.value, roundf(pick.pos.x)))

	# a blocked move is refused and the numbers return
	var before: Vector2 = pick.pos
	ck.call("properties: a spot outside the map is refused", not ed.move_selected_to(Vector2(-90000, -90000)))
	ck.call("properties: a refused move leaves the object alone", pick.pos.distance_to(before) < 0.5)

	# a locked layer: locking deselects (as before), and the move / duplicate calls refuse even if called directly
	var layer := PlacedObjects.type_of(pick.id)
	ed.set_layer_locked(layer, true)
	await tree.process_frame
	ck.call("layers: locking the layer drops the selection and hides the card", ed.selected.is_empty() and not ed.inspector.visible)
	ed.selected = pick  # forced, to prove the guard itself
	ck.call("properties: a locked layer refuses a move", not ed.move_selected_to(before + Vector2(90, 0)) and pick.pos.distance_to(before) < 0.5)
	ck.call("properties: a locked layer refuses duplicate", not ed.duplicate_selected())
	ed._refresh()
	await tree.process_frame
	ck.call("properties: a locked object's fields are disabled", not pp.x_field.editable and pp.btn_dup.disabled and pp.btn_del.disabled)
	sh.unlock_all_layers()
	await tree.process_frame
	ck.call("layers: UNLOCK ALL unlocks the layer", not bool(placed.locked_types.get(layer, false)))
	ed._refresh()
	ck.call("properties: unlocking re-enables the fields", pp.x_field.editable and not pp.btn_dup.disabled)

	# duplicate
	var n0 := placed.objects.size()
	pp.btn_dup.pressed.emit()
	await tree.process_frame
	ck.call("properties: DUPLICATE adds one object of the same kind", placed.objects.size() == n0 + 1 and ed.selected.id == pick.id and ed.selected != pick)
	ck.call("properties: the copy is selected and sits beside the original", ed.selected.pos.distance_to(pick.pos) > 10.0)
	placed.undo()
	await tree.process_frame
	ck.call("properties: undo removes the duplicate", placed.objects.size() == n0)

	# delete
	ed.selected = pick
	ed._refresh()
	await tree.process_frame
	pp.btn_del.pressed.emit()
	await tree.process_frame
	ck.call("properties: DELETE removes the object", not placed.objects.has(pick) and placed.objects.size() == n0 - 1)
	ck.call("properties: nothing selected hides the card, shows the empty note", not ed.inspector.visible and sh.props_empty.visible)
	placed.undo()
	await tree.process_frame

	# group selection
	var two: Array = []
	for o: Dictionary in placed.objects:
		if PlacedObjects.def_of(o.id).kind == "tree":
			two.append(o)
			if two.size() == 2:
				break
	ed.selected = {}
	ed.selection = two
	ed._refresh()
	await tree.process_frame
	ck.call("properties: a group shows how many are selected", ed.inspector.visible and pp.title.text == "2 objects selected" and not pp.pos_row.visible, pp.title.text)
	ed.selection = []
	ed._refresh()

	# layers: counts, bulk buttons
	sh._recount_layers()
	var trees := 0
	for o: Dictionary in placed.objects:
		if PlacedObjects.type_of(str(o.id)) == "Trees":
			trees += 1
	ck.call("layers: each row shows the real object count", (sh.layer_rows["Trees"].count as Label).text == str(trees), (sh.layer_rows["Trees"].count as Label).text + " vs " + str(trees))
	ed.set_layer_hidden("Trees", true)
	ed.set_layer_hidden("Fences", true)
	sh.show_all_layers()
	await tree.process_frame
	ck.call("layers: SHOW ALL un-hides every layer", not bool(placed.hidden_types.get("Trees", false)) and not bool(placed.hidden_types.get("Fences", false)))
	ed.selected = pick
	ed._refresh()
	await tree.process_frame
	ck.call("layers: the selected object's layer row is highlighted", (sh.layer_rows[layer].name as Label).get_theme_font_size("font_size") == 13)

	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
	WorldEditor.use_palette(false)
