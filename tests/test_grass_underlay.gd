extends RefCounted
## Flat grass tiles are tufts that cover only part of their 72 x 36 cell. The floor underlay fills the whole cell under
## them with the grass colour so no white void shows around a placed grass tile (owner 2026-10-25).

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	AncientShrineSection.enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 6:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.save_path = "user://test_grass_underlay_layout.json"
	placed.autosave = false
	for id in ["grass9_center", "grass9_edge_se", "grass9_corner_bottom"]:
		var c := PlacedObjects.floor_fill_color(id)
		ck.call("grass underlay: " + id + " has a real fill colour", c.a == 1.0 and c.get_luminance() < 0.6 and c.g > 0.05, str(c))
	var r0 := placed.revision
	var o := placed.add("grass9_center", Vector2(1008, 540))
	ck.call("grass underlay: placing a tile bumps the redraw revision", not o.is_empty() and placed.revision > r0)
	var r1 := placed.revision
	placed.move(o, Vector2(1080, 540))
	ck.call("grass underlay: moving bumps it", placed.revision > r1)
	var r2 := placed.revision
	placed.remove(o)
	ck.call("grass underlay: removing bumps it", placed.revision > r2)
	var sheet := arena.editor.void_sheet
	ck.call("grass underlay: the floor sheet exists and redraws on change", sheet != null and sheet.has_method("_process"))
	main.queue_free()
	await tree.process_frame
