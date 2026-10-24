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
	ck.call("ashen fire: dedicated filter",editor._filter_buttons.has("Ashen fire"))
	var ids := ["fire_tall_pillar","fire_short_brazier","fire_tripod_brazier","fire_wall_brazier","fire_fire_pit"]
	var baseline := placed.obstacles().size()
	for i in ids.size():
		var obj := placed.add(ids[i],Vector2(1000+i*130,950),false)
		var fire := obj.nodes[0] as AshenFireProp
		fire.set_process(false)
		ck.call("ashen fire: layers and twelve frames "+ids[i],fire.body.texture!=null and fire.flame.hframes*fire.flame.vframes==12 and fire.coals.texture!=null and fire.light!=null)
		ck.call("ashen fire: bounded independent pools "+ids[i],fire.spark_pool.size()==24 and fire.smoke_pool.size()==18)
		ck.call("ashen fire: category and collision "+ids[i],PlacedObjects.type_of(ids[i])=="Ashen fire" and obj.nodes[1] is StaticBody2D)
		var sounds := fire.sound_events
		fire._pop()
		ck.call("ashen fire: one event synchronizes flash/audio/sparks "+ids[i],fire.flash==1.0 and fire.sound_events==sounds+1 and fire.pop_audio.stream!=null)
		fire.set_sound_enabled(false)
		fire._pop()
		ck.call("ashen fire: mute preserves visual pops "+ids[i],fire.sound_events==sounds+1 and fire.flash==1.0 and not fire.bed.playing)
	ck.call("ashen fire: nav includes fixture footprints",placed.obstacles().size()==baseline+5)
	editor.set_tool("place","fire_tall_pillar")
	editor.set_type_filter("Ashen fire",false)
	ck.call("ashen fire: filter stops painting",editor.tool=="select" and editor.place_id=="")
	var old_path := placed.save_path
	placed.save_path = "user://test_ashen_fire_save.json"
	var saved := placed.save()
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(placed.save_path))
	ck.call("ashen fire: closed file contains all five fixtures",saved and on_disk.items.filter(func(o):return str(o.id).begins_with("fire_")).size()==5)
	DirAccess.remove_absolute(placed.save_path)
	placed.save_path = old_path
	var data := placed.to_dict()
	placed.load_dict(data)
	var count := 0
	var moved := false
	for obj in placed.objects.duplicate():
		if PlacedObjects.def_of(obj.id).kind=="ashen_fire":
			count+=1
			placed.move(obj,Vector2(1100,1000),false)
			moved = (obj.nodes[0] as Node2D).position==(obj.nodes[1] as Node2D).position
			placed.remove(obj,false)
	ck.call("ashen fire: save reload five variants",count==5)
	ck.call("ashen fire: move/delete updates fixture and collider",moved and placed.obstacles().size()==baseline)
	main.queue_free()
	await root.get_tree().process_frame
