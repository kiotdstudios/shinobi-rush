extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var placed := arena.placed
	placed.autosave = false
	var count := placed.objects.size()
	var obj := placed.add("dynamic_shrine",Vector2(1000,800),false)
	var shrine := obj.nodes[0] as DynamicShrine
	shrine.set_process(false)
	ck.call("shrine: three independently seeded groups",shrine.swarms.size()==3 and shrine.swarms[0].seed_value!=shrine.swarms[1].seed_value)
	ck.call("shrine:42 fireflies",shrine.swarms[0].flies.size()+shrine.swarms[1].flies.size()+shrine.swarms[2].flies.size()==42)
	ck.call("shrine: four independent foliage bands",shrine.foliage.size()==4)
	ck.call("shrine: native padded canvas",shrine.body.texture.get_size()==Vector2(544,480))
	ck.call("shrine: builder filter",arena.editor._filter_buttons.has("Dynamic shrine") and PlacedObjects.type_of("dynamic_shrine")=="Dynamic shrine")
	var body_position := shrine.body.position
	var body_texture := shrine.body.texture
	shrine.clock=0.0
	shrine.advance(0.0)
	var start := shrine.swarms[0].flies[0].sprite.position as Vector2
	var pulse := shrine.pulse
	shrine.advance(2.0)
	ck.call("shrine: stone geometry fixed",shrine.body.position==body_position and shrine.body.texture==body_texture and shrine.body.rotation==0.0)
	ck.call("shrine: subtle independent pulse",shrine.pulse!=pulse and shrine.emission.modulate.a<=0.48)
	ck.call("shrine: insects actually move",shrine.swarms[0].flies[0].sprite.position!=start)
	shrine.fireflies_on=false
	shrine.lighting_on=false
	shrine.rays_on=false
	shrine.advance(0.0)
	ck.call("shrine: effect toggles",not shrine.emission.visible and not shrine.rays.visible and not shrine.swarms[0].flies[0].sprite.visible)
	placed.move(obj,Vector2(1100,850),false)
	ck.call("shrine: move preserves all children",shrine.position==Vector2(1100,850) and shrine.body.position==body_position)
	placed.set_type_visible("Dynamic shrine",false)
	ck.call("shrine: filter hides whole effect",not shrine.visible)
	placed.set_type_visible("Dynamic shrine",true)
	var snapshot := placed.to_dict()
	placed.load_dict(snapshot)
	await root.get_tree().process_frame
	var restored: Dictionary = {}
	for item in placed.objects:
		if item.id=="dynamic_shrine":restored=item
	ck.call("shrine: serialization restores landmark",not restored.is_empty() and restored.pos==Vector2(1100,850) and restored.nodes[0] is DynamicShrine)
	placed.remove(restored,false)
	await root.get_tree().process_frame
	ck.call("shrine: delete frees all layers",placed.objects.size()==count and not is_instance_valid(shrine))
	main.queue_free()
	await root.get_tree().process_frame
