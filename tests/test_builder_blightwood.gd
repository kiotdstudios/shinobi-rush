extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	var editor := arena.editor
	editor.set_open(true)
	ck.call("blightwood: dedicated six-card category",editor._filter_buttons.has("Blightwood lights") and PlacedObjects.CATEGORIES.filter(func(c): return c[0]=="Blightwood lights")[0][1].size()==6)
	var ids := ["blight_wooden_post","blight_stone_pagoda","blight_branch_lantern","blight_stone_brazier","blight_spirit_totem"]
	var baseline := placed.obstacles().size()
	var owned: Array[BlightwoodLight] = []
	for i in ids.size():
		var obj := placed.add(ids[i],Vector2(1050+i*145,1050),false)
		var fixture := obj.nodes[0] as BlightwoodLight
		owned.append(fixture)
		fixture.set_process(false)
		fixture.sound_on = false
		ck.call("blightwood: native body and collision "+ids[i],fixture.body.texture!=null and obj.nodes[1] is StaticBody2D and PlacedObjects.type_of(ids[i])=="Blightwood lights")
		ck.call("blightwood: bounded twelve-insect layer "+ids[i],fixture.swarm.flies.size()==12 and not fixture.swarm.auto_advance)
		var point := (fixture.swarm.flies[0].sprite as Sprite2D).position
		var origin := fixture.position
		fixture.advance(1.25)
		ck.call("blightwood: insect flight while fixture root stays fixed "+ids[i],(fixture.swarm.flies[0].sprite as Sprite2D).position.distance_to(point)>1 and fixture.position==origin)
		fixture.lighting_on = false
		fixture.fireflies_on = false
		fixture.advance(0.0)
		ck.call("blightwood: independent effect toggles "+ids[i],not fixture.light.visible and not fixture.source_light.visible and not fixture.halo.visible and not (fixture.swarm.flies[0].sprite as Sprite2D).visible)
		if fixture.pendant != null:
			ck.call("blightwood: separate swinging pendant "+ids[i],absf(fixture.pendant.rotation)>0.0001 and fixture.glass.get_parent()==fixture.pendant)
			fixture.sway_on = false
			fixture.advance(0.0)
			ck.call("blightwood: pendulum can return to registered rest pose "+ids[i],fixture.pendant.rotation==0)
		else:
			ck.call("blightwood: lantern glass or twelve-frame spirit fire "+ids[i],fixture.flame==null if i==1 else fixture.flame.hframes*fixture.flame.vframes==12)
	ck.call("blightwood: five physical footprints in navigation",placed.obstacles().size()==baseline+5)
	var swarm_obj := placed.add("blight_fireflies",Vector2(1600,990),false)
	var swarm := swarm_obj.nodes[0] as ForestFireflies
	swarm.set_process(false)
	ck.call("blightwood: separately placeable32-insect swarm",swarm.count==32 and swarm.flies.size()==32 and swarm_obj.nodes.size()==1)
	ck.call("blightwood: swarm never adds collision/nav obstacles",placed.obstacles().size()==baseline+5 and placed.can_place("blight_fireflies",Vector2(0,135)))
	var first: Sprite2D = swarm.flies[0].sprite
	swarm.advance(500.0)
	ck.call("blightwood: long-running swarm stays bounded",absf(first.position.x)<=110 and absf(first.position.y)<=90 and swarm.flies.size()==32)
	placed.move(swarm_obj,Vector2(1630,1000),false)
	ck.call("blightwood: standalone swarm moves as one emitter",swarm.position==Vector2(1630,1000))
	editor.set_tool("place","blight_wooden_post")
	editor.set_type_filter("Blightwood lights",false)
	ck.call("blightwood: hiding filter stops painting",editor.tool=="select" and editor.place_id=="")
	var old_path := placed.save_path
	placed.save_path = "user://test_blightwood_lights.json"
	var saved := placed.save()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(placed.save_path))
	ck.call("blightwood: all six objects serialize",saved and data.items.filter(func(o):return str(o.id).begins_with("blight_")).size()==6)
	DirAccess.remove_absolute(placed.save_path)
	placed.save_path = old_path
	placed.load_dict(data)
	var count := 0
	for obj in placed.objects.duplicate():
		if str(obj.id).begins_with("blight_"):
			count += 1
			placed.remove(obj,false)
	ck.call("blightwood: save/reload/delete all six",count==6 and placed.obstacles().size()==baseline)
	await root.get_tree().process_frame
	ck.call("blightwood: deleting props frees their fireflies",not is_instance_valid(owned[0]))
	main.queue_free()
	await root.get_tree().process_frame
