extends Node2D
## Real player controller and real bandit patrol. Comparison changes presentation only.
var player: PlayerController
var bandit: Bandit
var state: JavaScriptObject
var clock := 0.0
var before := false
var events := {"player":{}, "bandit":{}}
var previous := {"player":"", "bandit":""}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var query := str(JavaScriptBridge.eval("window.location.search",true)) if OS.has_feature("web") else ""
	before = "before=1" in query
	RenderingServer.set_default_clear_color(Color("1a2d2f"))
	var texture := load("res://assets/environment/blightwood/ground_path/ground9_center.png") as Texture2D
	for u in range(-18,19):
		for v in range(-18,19):
			var tile := Sprite2D.new()
			tile.texture = texture
			tile.position = Vector2(640+(u-v)*36,360+(u+v)*18)
			tile.z_index = -2
			add_child(tile)
	player = load("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(420,520)
	add_child(player)
	player.camera.enabled = false
	player.visual.locomotion.enabled = not before
	bandit = load("res://scenes/enemy/bandit.tscn").instantiate() as Bandit
	bandit.position = Vector2(850,460)
	bandit.patrol_points = PackedVector2Array([Vector2(1050,460),Vector2(1050,640),Vector2(850,640),Vector2(850,460)])
	add_child(bandit)
	# This fixture isolates patrol from combat; regular game perception stays untouched.
	player.remove_from_group("player")  # no combat target in this traversal-only fixture
	bandit.visual.locomotion.enabled = not before
	var camera := Camera2D.new()
	camera.position = Vector2(640,360)
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(340,18)
	layer.add_child(box)
	var label := Label.new()
	label.text = "MOVEMENT | %s | WASD / R1 sprint / dodge / attack\nReal player + bandit controllers; same movement and combat timing" % ("BEFORE" if before else "AFTER")
	box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	for title in ["Normal", "Half speed"]:
		var button := Button.new()
		button.text = title
		button.focus_mode = Control.FOCUS_NONE
		var speed := 1.0 if title == "Normal" else 0.5
		button.pressed.connect(func():Engine.time_scale=speed)
		row.add_child(button)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__MOVEMENT_REVIEW__ = state

func _process(delta: float) -> void:
	clock += delta
	for who in ["player","bandit"]:
		var visual: Node2D = player.visual if who == "player" else bandit.visual
		var kind: String = visual.locomotion.kind
		if kind != "" and previous[who] != kind:
			events[who][kind] = int(events[who].get(kind,0))+1
		previous[who] = kind
	if state == null:return
	state.ready = true
	state.before = before
	state.clock = clock
	state.events_json = JSON.stringify(events)
	state.player_animation = player.visual.actor.anim_id
	state.player_x = player.position.x
	state.player_y = player.position.y
	state.player_state = player.get_state_name()
	state.bandit_animation = bandit.visual.actor.anim_id
	state.bandit_x = bandit.position.x
	state.bandit_y = bandit.position.y
	state.player_transition = player.visual.locomotion.kind
	state.bandit_transition = bandit.visual.locomotion.kind
	state.player_frame = player.visual.actor.current_frame()
	state.bandit_frame = bandit.visual.actor.current_frame()

func _exit_tree() -> void:
	Engine.time_scale = 1.0


