extends Node
## Temporary floor-only demonstration inside the actual game. Never autosaves.
var arena: TrainingArena
var player: PlayerController
var state: JavaScriptObject
var pieces := 0
func _ready() -> void:
	arena = get_parent().get_node("TrainingArena") as TrainingArena
	player = arena.get_node("Player") as PlayerController
	arena.placed.autosave = false
	for u in range(-5,6):
		for v in range(-5,6):
			var mask := 0
			var corners := [Vector2(.5,.5),Vector2(-.5,.5),Vector2(.5,-.5),Vector2(-.5,-.5)]
			for i in 4:
				if _soil(Vector2(u,v)+corners[i]):mask |= [1,2,4,8][i]
			var id := "path_dirt_%02d_%s" % [mask,["a","b","c"][posmod(u+2*v,3)]]
			if arena.placed.paint_cell(id,Vector2((u-v)*36,180+(u+v)*18)):pieces+=1
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(0,150)
	camera.zoom = Vector2(1.2,1.2)
	arena.add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(330,75)
	label.text = "GROUND / PATH TO DIRT | 3 variations\nActual game floor demo; WASD to walk; builder: Path to dirt"
	layer.add_child(label)
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__PATH_DIRT_REVIEW__=state
func _soil(p: Vector2) -> bool:
	if pow((p.x+1)/2.6,2)+pow((p.y+1)/2.2,2)<1:return true
	for i in 30:
		var t := i/29.0
		if p.distance_to(Vector2(t*3,t*3-.4*sin(t*PI)))<.6+.12*cos(t*6):return true
	return false
func _process(_delta: float) -> void:
	if state==null:return
	state.ready = true
	state.pieces = pieces
	state.player_x = player.position.x
	state.player_y = player.position.y
	state.filter = arena.editor._filter_buttons.has("Path to dirt")
