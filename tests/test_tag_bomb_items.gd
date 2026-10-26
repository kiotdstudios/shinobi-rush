extends RefCounted
## Verify real item dispatch/pickup, legacy tag preservation and harmless smoke lifecycle.
func run(ck: Callable, root: Node) -> void:
	for kind: String in ["tag_bomb", "smoke_tag_bomb"]:
		for layer: String in ["idle", "fly", "armed"]:
			ck.call(kind+" "+layer+": sixteen frames",TagBombArt.frames(kind,layer).size()==16)
		ck.call(kind+": inventory icon", PlayerInventory.icon(kind)!=null)
		ck.call(kind+": builder pickup",PlacedObjects.CATALOG.has(kind) and PlacedObjects.type_of(kind)=="Pickups")
	ck.call("smoke: separate effect frames",TagBombArt.frames("smoke_tag_bomb","smoke").size()>=8)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5: await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena")
	var player := arena.get_node("Player") as PlayerController
	player.set_physics_process(false)
	var menu := PlayerMenu.new()
	ck.call("bombs: both menu entries",menu.entries().has("tag_bomb") and menu.entries().has("smoke_tag_bomb"))
	menu.free()
	for kind: String in ["tag_bomb","smoke_tag_bomb"]:
		var placed := arena.placed as PlacedObjects
		placed.autosave=false
		var object := placed.add(kind,Vector2(10000,10000),false)
		ck.call(kind+": builder creates real pickup",not object.is_empty() and object.nodes[0] is HealthGourd)
		placed.move(object,Vector2(10020,10020),false)
		ck.call(kind+": builder moves pickup",object.nodes[0].position==Vector2(10020,10020))
		placed.remove(object,false)
		ck.call(kind+": builder removes pickup",not placed.objects.has(object))
		player.inventory.counts[kind]=0
		var pickup := HealthGourd.new()
		pickup.kind=kind
		pickup.position=Vector2(10000,10000)
		arena.add_child(pickup)
		pickup.set_process(false)
		player.global_position=pickup.global_position
		ck.call(kind+": obtainable",pickup.can_collect(player) and pickup.item_id()==kind)
		ck.call(kind+": collected once",pickup.collect(player)==1 and player.inventory.count_of(kind)==1 and not pickup.available)
		ck.call(kind+": unavailable blocks auto collect",not pickup.can_collect(player))
		player.inventory.assign_item("down",kind)
		player.state=PlayerController.State.IDLE
		player._throw_t=0.0
		player.facing8=Vector2.RIGHT
		ck.call(kind+": slot throws and consumes",player.use_slot("down") and player.inventory.count_of(kind)==0)
		player._tick_throw(player.THROW_TIME*0.9)
		var found: PaperTagBomb
		for node in arena.get_children():
			if node is PaperTagBomb and node.art_kind==kind: found=node
		ck.call(kind+": correct projectile dispatch",found!=null and (found is SmokeTagBomb)==(kind=="smoke_tag_bomb"))
		if found!=null:
			found.set_physics_process(false)
			found.advance(0.5)
			ck.call(kind+": lands before fuse",found.phase==PaperTagBomb.Phase.ARMED and not found.detonated)
			found.advance(1.3)
			ck.call(kind+": detonates on fuse",found.detonated and found.phase==PaperTagBomb.Phase.BLAST)
			if found is SmokeTagBomb:
				ck.call("smoke: five independent clouds",found.clouds.size()==5)
				ck.call("smoke: no explosion or scorch",found._blast==null and found._glow==null and found.damaged.is_empty())
				found.apply_damage()
				ck.call("smoke: damage is inert",found.damaged.is_empty())
				found.advance(SmokeTagBomb.SMOKE_SECONDS+0.1)
				ck.call("smoke: cleanup after cloud duration",found.phase==PaperTagBomb.Phase.DONE and found.is_queued_for_deletion())
			else:
				ck.call("explosive: reuses existing blast",found._blast!=null and PaperTagBomb.DAMAGE==45.0)
			found.queue_free()
		pickup.queue_free()
	player._throw_t=0
	main.queue_free()
	await root.get_tree().process_frame
