extends RefCounted
func run(ck: Callable, root: Node) -> void:
	for id: String in CliffKit.IDS:
		var def:=PlacedObjects.def_of(id)
		ck.call("modular cliff: registered "+id,not def.is_empty() and not PlacedObjects.art_texture(id,Vector2.ZERO).is_empty())
	var old_map:=BlightwoodMap.enabled
	var old_shrine:=AncientShrineSection.enabled
	var old_mode:=MapEditorMode.forced
	BlightwoodMap.enabled=false
	AncientShrineSection.enabled=false
	MapEditorMode.forced=false
	var main: Node=(load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree:=root.get_tree()
	for i in 5:await tree.process_frame
	var arena:=main.get_node("TrainingArena") as TrainingArena
	var placed:=arena.placed
	placed.autosave=false
	for enemy in tree.get_nodes_in_group("enemy"):enemy.queue_free()
	var demo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/blightwood/cliff_kit/demo-layout.json"))
	var count:=placed.load_dict(demo)
	ck.call("modular cliff: entire saved demonstration loads",count==demo.items.size(),str(count))
	ck.call("modular cliff: continuous island contains all 134 native cells",placed.cliff_world.occupied.size()==134,str(placed.cliff_world.occupied.size()))
	ck.call("modular cliff: boundary collision built, internal faces removed",placed.cliff_world.boundary_edges>35 and placed.cliff_world.boundary_edges<100,str(placed.cliff_world.boundary_edges))
	ck.call("modular cliff: nav opens upper surfaces but blocks crossing the cliff rim",arena.nav.is_walkable(Vector2(-144,-72)) and not arena.nav.line_clear(Vector2(0,-360),Vector2(0,-180)))
	var sw_route:=ShrineElevation.climb_step(Vector2(421.2,156.6),Vector2(288,90))
	ck.call("modular cliff: AI chooses the nearby SW stairs",bool(sw_route.get("direct",false)),str(sw_route))
	var wet_point:=Vector2(0,0)
	for o in placed.objects:
		if o.id=="cliff_upper_river":wet_point=o.pos;break
	ck.call("modular cliff: upper river retains water-running eligibility",BlightwoodWater.over_water(tree,wet_point) and is_equal_approx(BlightwoodWater.modular_level_at(wet_point),66))
	var effects:=Waterlife.new()
	effects.auto_advance=false
	arena.add_child(effects)
	effects.observe(wet_point,true,.1,66)
	ck.call("modular cliff: chakra foot aura follows elevated water",absf(effects.aura[0].global_position.y-(wet_point.y-68))<=3)
	var plant:=effects.add_plant(wet_point,0)
	ck.call("modular cliff: floating plants use elevated visual feet",plant.global_position==wet_point-Vector2(0,66) and plant.z_index==1 and plant.get_meta("ground_foot")==wet_point)
	effects.free()
	var snapshot:=placed.to_json_string()
	var player:=arena.get_node("Player") as PlayerController
	player.set_physics_process(false)
	await tree.physics_frame
	await tree.physics_frame
	for id in ["cliff_stairs_se","cliff_stairs_sw"]:
		var zone: CliffElevation
		for o in placed.objects:
			if o.id==id:zone=o.nodes.back() as CliffElevation
		ck.call(id+": connects to entire island",zone!=null and zone.surfaces.size()==134)
		if zone==null:continue
		var run:=zone.top-zone.mouth
		var start:=zone.position+zone.mouth-run*.2
		player.position=start
		player.elevation=0.0
		var rise:=0.0
		for i in 80:
			var before:=player.elevation
			player.velocity=run*1.125
			player.move_and_slide()
			player._follow_elevation(1.0/60.0)
			rise=maxf(rise,absf(player.elevation-before))
			await tree.physics_frame
		var expected:=start+run*1.5
		ck.call(id+": actual player climbs onto full plateau",player.position.distance_to(expected)<5.0 and player.elevation>65,str(player.position)+" expected "+str(expected)+" height "+str(player.elevation))
		ck.call(id+": rise and figure depth stay correct",rise<=8.01 and player.visual.z_index==1 and is_equal_approx(player.visual.position.y,-66.0) and is_equal_approx(player.camera.position.y,-66.0),str(rise))
		for i in 80:
			player.velocity=-run*1.125
			player.move_and_slide()
			player._follow_elevation(1.0/60.0)
			await tree.physics_frame
		ck.call(id+": player descends to lower ground",player.position.distance_to(start)<5.0 and player.elevation<1.0 and player.visual.z_index==0,str(player.position)+" height "+str(player.elevation))
	# A side with no stairs blocks the real actor footprint from BOTH sides.
	ck.call("modular cliff: player cannot leave the upper rim",player.test_move(Transform2D(0,Vector2(0,-216)),Vector2(0,-180)))
	player.position=Vector2(-900,0)
	player.elevation=0.0
	var enemy:=placed.make_bandit(Vector2(0,-360),1,"CliffTestBandit")
	enemy.set_physics_process(false)
	await tree.physics_frame
	await tree.physics_frame
	ck.call("modular cliff: lower bandit cannot pass through cliff",enemy.test_move(enemy.global_transform,Vector2(0,200)))
	for id in ["cliff_stairs_se","cliff_stairs_sw"]:
		var def:=PlacedObjects.def_of(id)
		var mouth:=Vector2(-288,54) if id=="cliff_stairs_se" else Vector2(396,144)
		var run: Vector2=def.ramp_top
		enemy.position=mouth-run*.2
		enemy.elevation=0.0
		for i in 80:
			enemy.velocity=run*1.125
			enemy.move_and_slide()
			ShrineElevation.update_actor(enemy,1.0/60.0)
			await tree.physics_frame
		ck.call(id+": actual bandit traverses same staircase",enemy.position.distance_to(mouth+run*1.3)<5 and enemy.elevation>65 and enemy.visual.z_index==1,str(enemy.position)+" height "+str(enemy.elevation))
	enemy.free()
	placed.set_type_visible("Blightwood Cliffs",false)
	var hidden:=true
	for o in placed.objects:
		if o.nodes[0] is CliffKit:
			for picture in (o.nodes[0] as CliffKit).pictures:hidden=hidden and not picture.is_visible_in_tree()
	ck.call("modular cliff: category filter hides all native surface and face layers",hidden)
	placed.set_type_visible("Blightwood Cliffs",true)
	for i in 12:placed.add("cliff_straight_se",Vector2(-108,-378)+Vector2(72,36)*i,false)
	placed._changed(false)
	ck.call("modular cliff: twelve exact repeated wall modules form 24 connected cells",placed.cliff_world.occupied.size()==158,str(placed.cliff_world.occupied.size()))
	var moved:=placed.add("cliff_ground",Vector2(-648,0),true)
	placed.move(moved,Vector2(-612,18),true)
	ck.call("modular cliff: move rebuilds live surface",placed.cliff_world.occupied.has(Vector2(-612,18)) and not placed.cliff_world.occupied.has(Vector2(-648,0)))
	placed.undo()
	ck.call("modular cliff: undo restores original surface",placed.cliff_world.occupied.has(Vector2(-648,0)))
	placed.redo()
	placed.remove(moved,true)
	ck.call("modular cliff: erase removes surface and collider topology",not placed.cliff_world.occupied.has(Vector2(-612,18)))
	placed.undo()
	ck.call("modular cliff: undo erase restores topology",placed.cliff_world.occupied.has(Vector2(-612,18)))
	placed.redo()
	placed.load_dict(JSON.parse_string(snapshot))
	ck.call("modular cliff: save reload preserves exact full layout",placed.to_json_string()==snapshot)
	var cascade: BlightwoodWater
	for o in placed.objects:
		if o.id=="cliff_cascade":cascade=o.nodes[0] as BlightwoodWater
	ck.call("modular cliff: waterfall uses native 66px crop",cascade!=null and cascade._cascade_atlas.region.size==Vector2(56,96) and cascade.fall.global_position==Vector2(-30,82))
	if cascade!=null:
		var before:=cascade._cascade_atlas.region
		cascade.advance(.2)
		ck.call("modular cliff: cascade and foam animate independently",cascade._cascade_atlas.region!=before and cascade.foam.frame==int(floor(cascade.clock*13))%16 and cascade.drops.size()==18)
	var legacy:=BlightwoodWater.new()
	legacy.waterfall=true
	arena.add_child(legacy)
	ck.call("modular cliff: legacy waterfall unchanged",legacy.cascade_height==0 and legacy.fall.position==Vector2(0,-73) and legacy.fall.hframes==4 and legacy.fall.vframes==4)
	legacy.free()
	var snap:=arena.editor.placement_pos("cliff_cascade",Vector2(-34,110))
	ck.call("modular cliff: waterfall snaps exactly to upper lip socket",snap==Vector2(-36,108),str(snap))
	ck.call("modular cliff: dedicated builder category searchable",AssetBrowser.categories_of("objects").has("Blightwood Cliffs") and AssetBrowser.matches("cliff_inner_e","blightwood cliffs"))
	ck.call("modular cliff: actual editor lists its hide/lock layer",WorldEditor.layer_names().has("Blightwood Cliffs"))
	var legacy_demo:=demo.duplicate(true)
	for item: Dictionary in legacy_demo.items:
		if item.id=="cliff_stairs_se":item.id="earth_stairs_se"
		elif item.id=="cliff_stairs_sw":item.id="earth_stairs_sw"
	placed.load_dict(legacy_demo)
	var adopted:=0
	for o in placed.objects:
		if o.id in ["earth_stairs_se","earth_stairs_sw"]:
			var stair:=o.nodes.back() as CliffElevation
			if stair.modular and stair.surfaces.size()==134 and stair.edge_body==null:adopted+=1
	ck.call("modular cliff: BOTH legacy stair ids attach to the full plateau",adopted==2,str(adopted))
	for o in placed.objects.duplicate():
		if o.nodes[0] is CliffKit:placed.remove(o,false)
	placed._changed(false)
	var restored:=0
	for o in placed.objects:
		if o.id in ["earth_stairs_se","earth_stairs_sw"]:
			var stair:=o.nodes.back() as CliffElevation
			if not stair.modular and stair.landing.size()==4 and is_instance_valid(stair.edge_body):restored+=1
	ck.call("modular cliff: removing kit restores legacy stairs without migration",restored==2,str(restored))
	var river_demo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/blightwood/cliff_kit/river-section.json"))
	var river_count:=placed.load_dict(river_demo)
	var missing:=[]
	for item: Dictionary in river_demo.items:
		var found:=false
		for o in placed.objects:
			if o.id==item.id and o.pos==Vector2(item.x,item.y):found=true;break
		if not found:missing.append(item)
	ck.call("riverbank starter: every catalog item loads",river_count==river_demo.items.size(),str(missing))
	ck.call("riverbank starter: original connected stair topology preserved",placed.cliff_world.occupied.size()==134 and placed.cliff_world.zones.size()==1)
	var lush:=0
	for o in placed.objects:
		if o.id=="cliff_grass":
			var module:=o.nodes[0] as CliffKit
			for picture in module.pictures:
				if picture is Sprite2D and picture.material!=null: lush+=1
	ck.call("riverbank starter: native wind grass dresses the elevated banks",lush>50,str(lush))
	var river_snapshot:=placed.to_json_string()
	placed.load_dict(JSON.parse_string(river_snapshot))
	ck.call("riverbank starter: exact editable map survives save reload",placed.to_json_string()==river_snapshot)
	ck.call("riverbank starter: upper stream and lower catch pool are real water",BlightwoodWater.over_water(tree,Vector2(108,18)) and BlightwoodWater.over_water(tree,Vector2(36,198)))
	main.queue_free()
	for i in 4:await tree.process_frame
	BlightwoodMap.enabled=old_map
	AncientShrineSection.enabled=old_shrine
	MapEditorMode.forced=old_mode
