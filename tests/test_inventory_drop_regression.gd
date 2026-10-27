extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	stage.add_child(player)
	player.camera.enabled=false
	player.position=Vector2(700,600)
	player.facing8=Vector2.RIGHT
	player.inventory.counts["health_gourd"]=1
	ck.call("drop regression: invalid item is rejected safely",not player.drop_item("unknown_item"))
	ck.call("drop regression: actual item drops",player.drop_item("health_gourd"))
	var pickup: HealthGourd
	for child in stage.get_children():
		if child is HealthGourd:pickup=child
	for i in 6:await root.get_tree().physics_frame
	ck.call("drop regression: drop survives overlapping pickup radius",pickup!=null and pickup.available and player.inventory.count_of("health_gourd")==0)
	player.position-=Vector2(120,0)
	for i in 3:await root.get_tree().physics_frame
	player.position+=Vector2(120,0)
	for i in 6:await root.get_tree().physics_frame
	ck.call("drop regression: leave and return recovers item",player.inventory.count_of("health_gourd")==1 and not pickup.available)
	var pouch := RyoPouch.drop(stage,Vector2(1000,700),23,player)
	ck.call("ryo loot: uses approved animated pouch art",pouch.art!=null and pouch.art.kind=="ryo" and pouch.art.get_node("Visual/Body") is Sprite2D)
	ck.call("ryo loot: presentation is not a second pickup",not pouch.art.is_in_group("ryo_pickup") and pouch.amount==23)
	stage.queue_free()
	await root.get_tree().process_frame
