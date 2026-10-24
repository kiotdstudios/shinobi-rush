extends Node2D
var fixtures: Array[BlightwoodLight] = []
var loose_flies: ForestFireflies
var speed := 0.5
var paused := false
var fireflies := true
var lighting := true
var sway := true
var sound := false
var clock := 0.0
var status: Label
var buttons: Dictionary = {}
var state: JavaScriptObject

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	RenderingServer.set_default_clear_color(Color("#17232c"))
	var tint := CanvasModulate.new()
	tint.color = Color(0.62,0.67,0.74,1)
	add_child(tint)
	var ground := Node2D.new()
	ground.z_index = -1
	add_child(ground)
	var floor_tex := load("res://assets/environment/kosen_courtyard/floor_tiles/floor9_center.png") as Texture2D
	for row in range(11,42):
		for col in range(-1,37):
			if posmod(row-col,2)!=0:continue
			var slab := Sprite2D.new()
			slab.texture = floor_tex
			slab.position = Vector2(col*36,row*18)
			ground.add_child(slab)
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BlightwoodLight.MANIFEST))
	var positions := [125,365,605,875,1110]
	for i in pack.fixtures.size():
		for j in range(-1,2):
			var grass := Sprite2D.new()
			grass.texture = load("res://assets/environment/kosen_courtyard/grass/tiles/grass9_center.png") as Texture2D
			grass.position = Vector2(positions[i]+j*36,590+j*5)
			ground.add_child(grass)
		var fixture := BlightwoodLight.new()
		fixture.data = pack.fixtures[i]
		fixture.auto_advance = false
		fixture.sound_on = false
		fixture.position = Vector2(positions[i],585)
		add_child(fixture)
		fixtures.append(fixture)
	loose_flies = ForestFireflies.new()
	loose_flies.count = 32
	loose_flies.radius = Vector2(180,60)
	loose_flies.position = Vector2(640,185)
	loose_flies.seed_value = 62450
	loose_flies.auto_advance = false
	add_child(loose_flies)
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20,16)
	layer.add_child(box)
	var title := Label.new()
	title.text = "BLIGHTWOOD FOREST | five PixelLab light fixtures + separate fireflies"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half speed",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;_advance(1.0/24.0))
	_button(row,"Fireflies",func():fireflies=not fireflies)
	_button(row,"Lighting",func():lighting=not lighting)
	_button(row,"Sway",func():sway=not sway)
	_button(row,"Sound",func():sound=not sound)
	status = Label.new()
	box.add_child(status)
	for i in 5:
		var label := Label.new()
		label.position = Vector2(positions[i]-70,640)
		label.text = str(pack.fixtures[i].id).replace("_"," ").to_upper()
		layer.add_child(label)
	var flying := Label.new()
	flying.position = Vector2(450,117)
	flying.text = "Separate placeable forest firefly swarm"
	layer.add_child(flying)
	var caption := Label.new()
	caption.position = Vector2(20,688)
	caption.text = "12 FPS spirit fire | 8 wingbeat poses | independent flight + glow | rooted props + hanging-lantern sway"
	layer.add_child(caption)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__BLIGHT_REVIEW__ = state
		var query := str(JavaScriptBridge.eval("window.location.search",true))
		if "paused=1" in query:paused=true
	_advance(0.0)

func _button(row: HBoxContainer,text: String,action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	buttons[text] = button

func _process(delta: float) -> void:
	_advance(0.0 if paused else delta*speed)

func _advance(delta: float) -> void:
	clock += delta
	for fixture in fixtures:
		fixture.fireflies_on = fireflies
		fixture.lighting_on = lighting
		fixture.sway_on = sway
		fixture.sound_on = sound
		fixture.advance(delta)
	loose_flies.enabled = fireflies
	loose_flies.advance(delta)
	if status != null:
		status.text = "%.2fs | %.2fx | %s | 92 bounded fireflies | lighting:%s | sway:%s" % [clock,speed,"PAUSED" if paused else "PLAY",lighting,sway]
	if state != null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.fireflies = fireflies
		state.lighting = lighting
		state.sway = sway
		state.sound = sound
		state.capacity = 92
		state.pendant_angle = fixtures[0].pendant.rotation
		state.pulse = fixtures[0].pulse
		state.fly_x = (loose_flies.flies[0].sprite as Sprite2D).position.x
		state.fly_y = (loose_flies.flies[0].sprite as Sprite2D).position.y
		var rects := {}
		for name: String in buttons:
			var p := (buttons[name] as Button).get_global_rect().get_center()
			rects[name] = {"x":p.x,"y":p.y}
		state.buttons_json = JSON.stringify(rects)
