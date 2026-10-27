extends Node
## Optional comparison inside the ACTUAL main scene, no replacement arena.
var player: PlayerController
var state: JavaScriptObject
var arena: TrainingArena
func _ready() -> void:
	arena = get_parent().get_node("TrainingArena") as TrainingArena
	player = arena.get_node("Player") as PlayerController
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(0,80)
	camera.zoom = Vector2(.72,.72)
	arena.add_child(camera)
	camera.make_current()
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__PATH_REVIEW__=state
func _process(_delta: float) -> void:
	if state == null:return
	state.ready = true
	state.natural = NaturalDirtPath.enabled
	state.player_x = player.position.x
	state.player_y = player.position.y
	state.floor_count = arena.placed.objects.size()
	state.obstacles = arena.placed.obstacles().size()
