extends Node
## Opt-in read-only telemetry for real keyboard/controller integration checks.
## Does not grant items, move actors, change camera, or modify gameplay.
var player: PlayerController
var state: JavaScriptObject
var remaining := 0.0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	player=get_tree().get_first_node_in_group("player") as PlayerController
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__INTEGRATION_REVIEW__=state
func _process(delta: float) -> void:
	remaining-=delta
	if remaining>0 or state==null or not is_instance_valid(player):return
	remaining=.1
	var menu := player.get_node("PlayerMenu") as PlayerMenu
	state.ready=true
	state.inventory_json=JSON.stringify(player.inventory.counts)
	state.menu_open=menu.is_open
	state.menu_cursor=menu.cursor
	state.player_x=player.position.x
	state.player_y=player.position.y
	var drops: Array=[]
	for item in get_tree().get_nodes_in_group("kunai_pickup"):
		if item is HealthGourd and item.available:
			drops.append({"x":item.global_position.x,"y":item.global_position.y,"owned":item.collection_owner==player})
	state.kunai_drops_json=JSON.stringify(drops)
	var crews: Array=[]
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Bandit:crews.append(enemy.crew_id)
	state.crews_json=JSON.stringify(crews)
