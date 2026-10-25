extends RefCounted
class Ground extends Node2D:
	var nav: ArenaNav
	func get_bounds() -> Rect2: return Rect2(0,0,1280,720)
class Carrier extends Node2D:
	var inventory := PlayerInventory.new()
class Target extends Node2D:
	var hits := 0
	var accepts := true
	func take_damage(_a,_d,_k,_h) -> void: hits+=1
	func take_hit(_a,_d,_k,_who) -> bool:
		if accepts: hits+=1
		return accepts
func run(ck: Callable, root: Node) -> void:
	var starter := PlayerInventory.new()
	starter.consume("kunai")
	ck.call("kunai capacity: starter throw can be recovered",starter.has_room("kunai") and starter.add("kunai")==1 and starter.count_of("kunai")==10 and not starter.has_room("kunai"))
	var ground := Ground.new()
	root.add_child(ground)
	var carrier := Carrier.new()
	carrier.inventory.counts["kunai"]=0
	carrier.add_to_group("player")
	carrier.position=Vector2(100,600)
	ground.add_child(carrier)
	var authored := HealthGourd.new()
	authored.kind="kunai"
	authored.position=Vector2(200,200)
	ground.add_child(authored)
	authored.set_process(false)
	ck.call("kunai pickup: registered white-light inventory item",authored.item_id()=="kunai" and HealthGourd.KINDS.kunai.color==Color.WHITE and authored._body.texture!=null)
	ck.call("kunai pickup: builder catalog",PlacedObjects.CATALOG.has("kunai") and PlacedObjects.type_of("kunai")=="Pickups")
	carrier.position=authored.position
	ck.call("kunai pickup: collect into inventory",authored.can_collect(carrier) and authored.collect(carrier)==1 and carrier.inventory.count_of("kunai")==1)
	ck.call("kunai pickup: cannot duplicate collection",authored.collect(carrier)==0 and carrier.inventory.count_of("kunai")==1)
	ck.call("kunai pickup: authored pickup retains respawn",authored.respawns and authored.respawn_left==HealthGourd.RESPAWN_SECONDS)
	authored.queue_free()
	carrier.position=Vector2(100,600)
	var target := Target.new()
	target.position=Vector2(350,250)
	target.add_to_group("enemy")
	ground.add_child(target)
	var kn := PlayerKunai.spawn(ground,Vector2(200,250),Vector2.RIGHT,carrier)
	kn.set_physics_process(false)
	kn.step(0.4)
	ck.call("kunai hit: damage once and consumed",target.hits==1 and kn.hit_result=="hit" and kn.is_queued_for_deletion())
	ck.call("kunai hit: no recovery spawned",root.get_tree().get_nodes_in_group("kunai_recovery").is_empty())
	target.position=Vector2(1000,100)
	var miss := PlayerKunai.spawn(ground,Vector2(100,350),Vector2.RIGHT,carrier)
	miss.set_physics_process(false)
	miss.step(2.0)
	ck.call("kunai miss: exact range, no overshoot",miss.hit_result=="range" and is_equal_approx(miss.travelled,PlayerKunai.MAX_RANGE) and is_equal_approx(miss.position.x,620))
	var recovery := root.get_tree().get_first_node_in_group("kunai_recovery") as KunaiRecovery
	recovery.set_physics_process(false)
	ck.call("kunai miss: falls with approved black sprite",recovery!=null and not recovery.surface and recovery.body.position.y<0)
	recovery.advance(0.32)
	ck.call("kunai miss: first bounce clinks",recovery.clinks==1 and recovery.body.rotation!=0)
	recovery.advance(0.31)
	ck.call("kunai miss: second bounce clinks",recovery.clinks==2)
	recovery.advance(0.3)
	var drop := recovery.pickup
	drop.set_process(false)
	ck.call("kunai miss: becomes grounded one-use pickup",drop!=null and drop.grounded and not drop.respawns and drop.item_id()=="kunai")
	carrier.position=drop.position
	carrier.inventory.counts["kunai"]=PlayerInventory.KUNAI_MAX_STACK
	ck.call("kunai drop: full bag leaves item available",not drop.can_collect(carrier) and drop.collect(carrier)==0 and drop.available)
	carrier.inventory.counts["kunai"]=0
	ck.call("kunai drop: refunds precisely one",drop.collect(carrier)==1 and carrier.inventory.count_of("kunai")==1 and drop.collect(carrier)==0)
	ck.call("kunai drop: no respawn timer",not drop.respawns and drop.respawn_left==0)
	carrier.position=Vector2(100,600)
	await root.get_tree().process_frame
	var wall := StaticBody2D.new()
	wall.position=Vector2(500,450)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(40,200)
	collider.shape=shape
	wall.add_child(collider)
	ground.add_child(wall)
	await root.get_tree().physics_frame
	target.position=Vector2(600,450)
	var behind := PlayerKunai.spawn(ground,Vector2(200,450),Vector2.RIGHT,carrier)
	behind.set_physics_process(false)
	behind.step(1.0)
	ck.call("kunai wall: intercepts before character behind it",behind.hit_result=="wall" and target.hits==1)
	var stuck := root.get_tree().get_first_node_in_group("kunai_recovery") as KunaiRecovery
	stuck.set_physics_process(false)
	stuck.advance(0.2)
	ck.call("kunai wall: briefly embeds",stuck.surface and not stuck.finished and is_equal_approx(stuck.body.position.y,PlayerKunai.DRAW_LIFT.y))
	ck.call("kunai wall: recovery stays on impact side",stuck.recoverable and stuck.landing.x<480 and KunaiRecovery.clear_ground(ground,stuck.landing))
	stuck.advance(1.2)
	ck.call("kunai wall: settles to recoverable pickup",stuck.pickup!=null and stuck.pickup.grounded)
	stuck.pickup.queue_free()
	await root.get_tree().process_frame
	var bandit_wall := BanditKunai.spawn(ground,Vector2(200,450),Vector2.RIGHT,null,target)
	bandit_wall.set_physics_process(false)
	bandit_wall.step(1.0)
	ck.call("bandit kunai: wall intercepts target and starts recovery",bandit_wall.hit_result=="wall" and target.hits==1 and root.get_tree().get_nodes_in_group("kunai_recovery").size()==1)
	for node in root.get_tree().get_nodes_in_group("kunai_recovery"): node.queue_free()
	wall.queue_free()
	await root.get_tree().process_frame
	target.remove_from_group("enemy")
	target.position=Vector2(350,250)
	var bandit := BanditKunai.spawn(ground,Vector2(200,250),Vector2.RIGHT,null,target)
	bandit.set_physics_process(false)
	bandit.step(0.4)
	ck.call("bandit kunai: character hit consumes without pickup",bandit.hit_result=="hit" and target.hits==2 and root.get_tree().get_nodes_in_group("kunai_recovery").is_empty())
	target.accepts=false
	var evade := BanditKunai.spawn(ground,Vector2(200,250),Vector2.RIGHT,null,target)
	evade.set_physics_process(false)
	evade.step(0.35)
	ck.call("bandit kunai: evade continues without damage",evade.hit_result=="evaded" and not evade.is_queued_for_deletion() and target.hits==2)
	evade.step(2.0)
	ck.call("bandit kunai: evaded blade eventually drops",evade.hit_result=="range" and root.get_tree().get_nodes_in_group("kunai_recovery").size()==1)
	ground.nav=ArenaNav.build(ground.get_bounds(),[[Vector2(640,720),Vector2(80,720),100]],30,25)
	carrier.position=Vector2(100,300)
	ck.call("kunai inaccessible: disconnected region rejected",not KunaiRecovery.clear_ground(ground,Vector2(900,300)))
	ck.call("kunai inaccessible: solid footprint rejected",not KunaiRecovery.clear_ground(ground,Vector2(640,300)))
	var inaccessible := KunaiRecovery.start(ground,Vector2(900,300),Vector2.RIGHT,-30.0,Vector2.LEFT)
	inaccessible.set_physics_process(false)
	inaccessible.advance(2.0)
	ck.call("kunai inaccessible: no unreachable pickup created",not inaccessible.recoverable and inaccessible.pickup==null and inaccessible.finished)
	ck.call("kunai sound: metallic clip generated",KunaiRecovery.clink_sound().data.size()==4410)
	ground.queue_free()
	await root.get_tree().process_frame
