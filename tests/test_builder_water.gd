extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var placed := (main.get_node("TrainingArena") as TrainingArena).placed
	placed.autosave = false
	var count := placed.objects.size()
	var obstacles := placed.obstacles().size()
	var water_ids := ["water9_center","water9_edge_ne","water9_corner_top","waterfall_small"]
	var objects: Array[Dictionary] = []
	for i in water_ids.size():
		var obj := placed.add(water_ids[i],Vector2(1100+i*72,950),false)
		objects.append(obj)
		var water := obj.nodes[0] as BlightwoodWater
		water.auto_advance = false
		ck.call("water: native renderer and category "+water_ids[i],water!=null and PlacedObjects.type_of(water_ids[i])=="River water")
		ck.call("water: no decorative physics bodies "+water_ids[i],obj.nodes.size()==1 and placed.obstacles().size()==obstacles)
		if water.waterfall:
			var pos := water.position
			water.clock=0
			water.advance(0.2)
			ck.call("water: independently timed sixteen-frame layers",water.fall.frame==3 and water.foam.frame==2 and water.fall.hframes*water.fall.vframes==16)
			ck.call("water: fixed registered root and bounded spray",water.position==pos and water.drops.size()==18)
			var total := water.get_child_count()
			for j in 500:water.advance(1.0)
			ck.call("water: no node growth after long playback",water.get_child_count()==total and water.drops.size()==18)
			water.spray_on=false
			water.advance(0)
			ck.call("water: separate foam and spray toggle",not water.foam.visible and not water.drops[0].visible and water.fall.visible)
		else:
			ck.call("water: ground layer and exact tile size",water.get_parent().name=="Ground" and water.surface.texture.get_size()==Vector2(72,36))
			water.advance(0.5)
			ck.call("water: shared current atlas",(water.surface.material as ShaderMaterial).get_shader_parameter("current_atlas").get_size()==Vector2(512,512))
	var moved := Vector2(1400,990)
	placed.move(objects[-1],moved,false)
	ck.call("water: move cascade preserves anchor",objects[-1].pos==moved and (objects[-1].nodes[0] as Node2D).position==moved)
	var cell := Vector2(1584,900)
	ck.call("water: brush places water on floor",placed.paint_cell("water9_center",cell))
	ck.call("water: replacement avoids stacked floor tiles",placed.paint_cell("ground9_center",cell) and placed.ground_at(cell).id=="ground9_center")
	placed.set_type_visible("River water",false)
	ck.call("water: category visibility affects all water art",not (objects[0].nodes[0] as CanvasItem).visible and not (objects[-1].nodes[0] as CanvasItem).visible)
	placed.set_type_visible("River water",true)
	ck.call("water: restores independently of other categories",(objects[0].nodes[0] as CanvasItem).visible and (objects[-1].nodes[0] as CanvasItem).visible)
	for obj in objects:placed.remove(obj,false)
	placed.remove(placed.ground_at(cell),false)
	await root.get_tree().process_frame
	ck.call("water: deleting frees all owned layers",placed.objects.size()==count and placed.obstacles().size()==obstacles)
	main.queue_free()
	await root.get_tree().process_frame
