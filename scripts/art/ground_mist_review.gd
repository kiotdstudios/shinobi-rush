extends Node2D
## Isolated presentation review; keyboard movement uses the unchanged real player controller.
var mist: GroundMist
var player: PlayerController
var shrine: DynamicShrine
var trees: Array[BlossomTree] = []
var speed := 1.0
var paused := false
var state: JavaScriptObject
var buttons: Dictionary = {}
var status: Label

func get_bounds() -> Rect2:return Rect2(0, 0, 1280, 720)

func _ready() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("1a2d2f"))
	var tex := load("res://assets/environment/blightwood/ground_path/ground9_center.png") as Texture2D
	for u in range(-14, 15):
		for v in range(-14, 15):
			var tile := Sprite2D.new()
			tile.texture = tex
			tile.position = Vector2(640 + (u-v)*36, 380 + (u+v)*18)
			tile.z_index = -2
			add_child(tile)
	shrine = DynamicShrine.new()
	shrine.solid = false
	shrine.auto_advance = false
	shrine.position = Vector2(705,580)
	add_child(shrine)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BlossomGrove.MANIFEST))
	for i in 3:
		var tree := BlossomTree.new()
		tree.data = data.trees[i]
		tree.position = [Vector2(220,410),Vector2(1110,460),Vector2(300,690)][i]
		add_child(tree)
		trees.append(tree)
	player = load("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(560,590)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(640,360)
	add_child(camera)
	camera.make_current()
	mist = GroundMist.new()
	mist.auto_advance = false
	mist.actor = player
	add_child(mist)
	mist.scan_sources(self)
	mist.advance(5.0)
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(340,16)
	ui.add_child(box)
	var title := Label.new()
	title.text = "BLIGHTWOOD | GROUND MIST | WASD move through the wisps"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Mist",func():mist.enabled=not mist.enabled)
	status = Label.new()
	box.add_child(status)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__MIST_REVIEW__ = state

func _button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	buttons[text] = button

func _process(delta: float) -> void:
	if mist == null:return
	var dt := 0.0 if paused else delta * speed
	mist.advance(dt)
	shrine.advance(dt)
	for tree in trees:tree.advance(mist.clock, dt, true, true)
	status.text = "%.2fs | %.1fx | %d wisps | low ground ribbons; automatic clearing around player" % [mist.clock,speed,mist.visible_count()]
	if state != null:
		state.ready = true
		state.clock = mist.clock
		state.speed = speed
		state.paused = paused
		state.enabled = mist.enabled
		state.visible = mist.visible_count()
		state.sources = mist.sources.size()
		state.capacity = mist.ribbons.size()
		state.x = player.global_position.x
		state.y = player.global_position.y
		state.clearing = GroundMist.readability(player.global_position,player.global_position)
		state.ribbon_x = mist.ribbons[0].global_position.x
		var rects := {}
		for key: String in buttons:
			var r: Rect2 = buttons[key].get_global_rect()
			rects[key] = {"x":r.get_center().x,"y":r.get_center().y}
		state.buttons_json = JSON.stringify(rects)
