extends RefCounted

func run(ck: Callable, root: Node) -> void:
	var fx := Waterlife.new()
	fx.auto_advance = false
	root.add_child(fx)
	await root.get_tree().process_frame
	ck.call("waterlife has a fixed 32-slot world-space pool",fx.pool.size()==32)
	fx.observe(Vector2.ZERO,false,0.1)
	fx.observe(Vector2(30,0),false,0.1)
	ck.call("dry movement does not emit water or chakra",fx.emissions==0 and not fx.aura[0].visible)
	fx.observe(Vector2(30,0),true,0.1)
	ck.call("water channels chakra at feet",fx.aura[0].visible and fx.aura[1].visible)
	for i in 100:fx.observe(Vector2(30,0),true,0.02)
	ck.call("stationary water contact creates no running spray",fx.emissions==0)
	fx.observe(Vector2(65,0),true,0.1)
	ck.call("real reached displacement emits a foot contact",fx.emissions==1)
	var first: Sprite2D = fx.pool[0].sprite
	var planted := first.global_position
	fx.observe(Vector2(105,0),true,0.1)
	ck.call("old ripples stay at their reached world point",first.global_position==planted)
	var before := fx.emissions
	fx.observe(Vector2(600,0),true,0.1)
	ck.call("teleports create no invented wake points",fx.emissions==before)
	for i in 100:fx.emit_splash(Vector2(i,0))
	ck.call("heavy travel cannot grow the pool",fx.pool.size()==32 and fx.get_child_count()==34)
	fx.advance(2.0)
	var visible := 0
	for slot in fx.pool:
		if slot.sprite.visible:visible+=1
	ck.call("all old water events expire",visible==0)
	var water := BlightwoodWater.new()
	water.position=Vector2(9000,9000)
	root.add_child(water)
	await root.get_tree().process_frame
	fx.add_plant(water.global_position,0)
	fx.armed=true
	fx.observe(water.global_position,true,0.1)
	var rolls := fx.rolls
	for i in 60:fx.observe(water.global_position,true,0.02)
	ck.call("one roll per eligible visit, never per rendered frame",rolls==1 and fx.rolls==rolls)
	fx.observe(water.global_position,false,9.0)
	fx.observe(water.global_position,true,0.1)
	ck.call("brief dry crossing does not reroll",fx.rolls==rolls)
	fx.observe(water.global_position,false,10.0)
	fx.observe(water.global_position,true,0.1)
	ck.call("ten continuous dry seconds permits one new eligible visit",fx.rolls==rolls+1)
	var winners := 0
	for value in Waterlife.RARITY:
		if Waterlife.wins_roll(value):winners+=1
	ck.call("exactly one winning outcome in a million integers",winners==1 and Waterlife.RARITY==1000000)
	var frog := fx.spawn_frog(water.global_position)
	frog.advance(1.9)
	ck.call("frog has separate visible fly and tongue phase",frog.phase=="tongue" and frog.fly.visible)
	frog.advance(1.9)
	ck.call("frog dive hides body and emits one independent splash",frog.splash_done and not frog.body.visible)
	var emitted := fx.emissions
	frog.advance(0.1)
	ck.call("frog splash is emitted only once",fx.emissions==emitted)
	fx.observe(Vector2.ZERO,false,0.1)
	ck.call("leaving water hides both chakra feet",not fx.aura[0].visible and not fx.aura[1].visible)
	fx.queue_free()
	water.queue_free()
	await root.get_tree().process_frame
