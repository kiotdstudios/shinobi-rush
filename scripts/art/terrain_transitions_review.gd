extends Node
## Opt-in actual-map demo. No saved layout is written or automatically repainted.
const FAMILIES := ["grass_path", "grass_temple", "dirt_temple", "grass_rock", "dirt_rock", "temple_rock", "grass_dirt"]
var arena: TrainingArena
var player: PlayerController
var state: JavaScriptObject
var selected := 0
var pieces := 0
var demo: Array[Dictionary] = []
var camera: Camera2D
var buttons: Array[Button] = []

func _ready() -> void:
	arena = get_parent().get_node("TrainingArena") as TrainingArena
	player = arena.get_node("Player") as PlayerController
	arena.placed.autosave = false
	player.camera.enabled = false
	camera = Camera2D.new()
	camera.position = Vector2(0, 190)
	camera.zoom = Vector2(.85, .85)
	arena.add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(330, 30)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "TERRAIN TRANSITIONS | actual game / WASD | flat surfaces only"
	panel.add_child(label)
	var row := HBoxContainer.new()
	panel.add_child(row)
	for i in FAMILIES.size():
		var button := Button.new()
		button.text = FAMILIES[i].replace("_", " / ")
		button.pressed.connect(_show.bind(i))
		row.add_child(button)
		buttons.append(button)
	_show(0)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__TERRAIN_REVIEW__ = state

func _show(index: int) -> void:
	selected = index
	for obj: Dictionary in demo:
		arena.placed.remove(obj, false)
	demo.clear()
	pieces = 0
	for u in range(-5, 6):
		for v in range(-5, 6):
			var mask := 0
			var corners := [Vector2(.5,.5),Vector2(-.5,.5),Vector2(.5,-.5),Vector2(-.5,-.5)]
			for i in 4:
				var p: Vector2 = Vector2(u,v)+corners[i]
				if pow((p.x+1)/2.7,2)+pow((p.y+1)/2.1,2)<1 or absf(p.y-p.x-.5*sin(p.x))<.7:
					mask |= [1,2,4,8][i]
			var variation: String = "a" if mask in [0,15] else ["a","b","c"][posmod(u+2*v,3)]
			var id := "%s_%02d_%s" % [FAMILIES[selected],mask,variation]
			if arena.placed.paint_cell(id,Vector2((u-v)*36,180+(u+v)*18)):pieces+=1
	# Separate all-mask swatch row on the actual floor, above connected sample.
	for mask in 16:
		arena.placed.paint_cell("%s_%02d_a" % [FAMILIES[selected],mask],Vector2((mask%8-4)*72,-72+(mask/8)*36))
	for mask in 16:
		arena.placed.paint_cell("shore_brown_%02d" % mask,Vector2((mask%8-4)*72,432+(mask/8)*36))
	for obj: Dictionary in arena.placed.objects:
		if String(obj.id).begins_with(FAMILIES[selected]+"_") or String(obj.id).begins_with("shore_brown_"):
			demo.append(obj)

func _process(_delta: float) -> void:
	if state == null:return
	state.ready = true
	state.family = FAMILIES[selected]
	state.pieces = pieces
	state.player_x = player.position.x
	state.player_y = player.position.y
	state.categories = arena.editor._filter_buttons.size()
	state.brown_filter = arena.editor._filter_buttons.has("Brown banks")
	var rects := {}
	for i in buttons.size():
		var rect := buttons[i].get_global_rect()
		rects[FAMILIES[i]] = {"x": rect.get_center().x, "y": rect.get_center().y}
	state.buttons_json = JSON.stringify(rects)
