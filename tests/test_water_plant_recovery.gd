extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var fx:=Waterlife.new()
	fx.auto_advance=false
	fx.armed=false
	root.add_child(fx)
	var water:=BlightwoodWater.new()
	water.position=Vector2(9000,9000)
	root.add_child(water)
	await root.get_tree().process_frame
	var origin:=water.global_position
	var slow:=fx.add_plant(origin-Vector2(8,0),0,0)
	var fast:=fx.add_plant(origin+Vector2(8,0),3,0.2)
	fx.observe(origin-Vector2(30,0),false,.1)
	fx.observe(origin+Vector2(30,0),true,.1)
	ck.call("pads: actual reached segment disturbs both pad and lotus",int(slow.get_meta("touches"))==1 and int(fast.get_meta("touches"))==1)
	ck.call("pads: contact dips into water rather than lifting above it",(slow.get_meta("push") as Vector2).y>0 and (fast.get_meta("push") as Vector2).y>0)
	ck.call("pads: return speeds differ deterministically",float(fast.get_meta("return_speed"))>float(slow.get_meta("return_speed")))
	fx.advance(.2)
	ck.call("pads: faster plant settles first",(fast.get_meta("push") as Vector2).length()<(slow.get_meta("push") as Vector2).length())
	var slow_base: Vector2=slow.get_meta("base")
	ck.call("pads: original water anchors never move",slow.get_meta("ground_foot")==origin-Vector2(8,0) and slow_base==origin-Vector2(8,0))
	fx.observe(origin+Vector2(30,0),false,.1)
	fx.advance(4)
	ck.call("pads: leaving water still allows complete recovery",slow.get_meta("push")==Vector2.ZERO and fast.get_meta("push")==Vector2.ZERO and float(slow.get_meta("lean"))==0.0)
	ck.call("pads: recovered plants bob at water surface",slow.global_position.distance_to(slow_base)<=1.5 and slow.z_index==0)
	var count:=int(slow.get_meta("touches"))
	fx.observe(origin-Vector2(30,0),false,.1)
	fx.observe(origin+Vector2(30,0),false,.1)
	ck.call("pads: dry travel has no contact reaction",int(slow.get_meta("touches"))==count)
	fx.observe(origin,false,.1)
	for i in 20:fx.observe(origin,true,.016)
	ck.call("pads: standing water creates no repeated impulse",int(slow.get_meta("touches"))==count)
	fx.observe(origin-Vector2(100,0),false,.1)
	fx.observe(origin+Vector2(100,0),true,.1)
	ck.call("pads: teleport-sized movement does not disturb crossed pads",int(slow.get_meta("touches"))==count)
	fx.observe(origin-Vector2(30,0),false,.1)
	fx.observe(origin+Vector2(30,0),true,.1,66)
	ck.call("pads: another elevation cannot disturb lower water",int(slow.get_meta("touches"))==count and slow.z_index==0)
	for i in 40:
		fx.observe(origin+Vector2(-30 if i%2==0 else 30,0),true,.016)
		fx.advance(.016)
	ck.call("pads: repeated crossings stay bounded",(slow.get_meta("push") as Vector2).length()<5 and (fast.get_meta("push") as Vector2).length()<5)
	fx.observe(origin-Vector2(30,0),false,.1)
	fx.observe(origin,true,.1)
	count=int(slow.get_meta("touches"))
	fx.observe(origin+Vector2(1,0),true,.016)
	ck.call("pads: continuous contact produces one impulse",int(slow.get_meta("touches"))==count)
	var push: Vector2=slow.get_meta("push")
	fx.advance(.4)
	var one_step: Vector2=slow.get_meta("push")
	slow.set_meta("push",push)
	for i in 24:fx.advance(1.0/60.0)
	ck.call("pads: recovery does not depend on render frame rate",one_step.distance_to(slow.get_meta("push"))<0.0001)
	var tier:=CliffElevation.new()
	tier.modular=true
	tier.surface_only=true
	tier.build_edges=false
	tier.height=66
	tier.position=origin
	tier.surfaces=[PackedVector2Array([Vector2(-100,-100),Vector2(100,-100),Vector2(100,100),Vector2(-100,100)])]
	root.add_child(tier)
	fx.advance(4)
	ck.call("pads: actual water tier controls elevation",slow.get_meta("base")==slow_base-Vector2(0,66) and slow.z_index==1)
	tier.queue_free()
	await root.get_tree().process_frame
	fx.advance(0)
	ck.call("pads: removing a raised tier returns plants to lower water",slow.get_meta("base")==slow_base and slow.z_index==0)
	ck.call("pads: reaction adds no frog rolls or pool slots",fx.rolls==1 and fx.pool.size()==32)
	fx.queue_free()
	water.queue_free()
	await root.get_tree().process_frame
