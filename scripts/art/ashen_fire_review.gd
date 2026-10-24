extends Node2D
var fires: Array[AshenFireProp] = []
var speed := 0.5
var paused := false
var sound := false
var smoke := true
var sparks := true
var lighting := true
var clock := 0.0
var status: Label
var buttons: Dictionary = {}
var state: JavaScriptObject

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	RenderingServer.set_default_clear_color(Color("#151b24"))
	var tint := CanvasModulate.new()
	tint.color = Color(0.65,0.65,0.70,1)
	add_child(tint)
	var ground := Node2D.new()
	ground.z_index = -1
	add_child(ground)
	var floor_tex := load("res://assets/environment/kosen_courtyard/floor_tiles/floor9_center.png") as Texture2D
	for row in range(14,42):
		for col in range(-1,37):
			if posmod(row-col,2)!=0:
				continue
			var slab := Sprite2D.new()
			slab.texture = floor_tex
			slab.position = Vector2(col*36,row*18)
			ground.add_child(slab)
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AshenFireProp.MANIFEST))
	for i in pack.fixtures.size():
		var fire := AshenFireProp.new()
		fire.data = pack.fixtures[i]
		fire.auto_advance = false
		fire.sound_on = false
		fire.position = Vector2(140+i*250,590)
		add_child(fire)
		fires.append(fire)
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20,16)
	layer.add_child(box)
	var title := Label.new()
	title.text = "ASHEN RUINS | five PixelLab fire fixtures"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half speed",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;_advance(1.0/24.0))
	_button(row,"Sound",_toggle_sound)
	_button(row,"Smoke",_toggle_smoke)
	_button(row,"Sparks",_toggle_sparks)
	_button(row,"Lighting",_toggle_lighting)
	status = Label.new()
	box.add_child(status)
	for i in 5:
		var label := Label.new()
		label.position = Vector2(65+i*250,635)
		label.text = str(pack.fixtures[i].id).replace("_"," ").to_upper()
		layer.add_child(label)
	var caption := Label.new()
	caption.position = Vector2(20,688)
	caption.text = "12 unique flame poses /12 FPS | independent smoke and embers | pop-synchronized flash + crackle | Sound button enables audio"
	layer.add_child(caption)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__FIRE_REVIEW__ = state
		var query := str(JavaScriptBridge.eval("window.location.search",true))
		if "paused=1" in query:
			paused = true
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
	clock+=delta
	var pops := 0
	var sounds := 0
	for fire in fires:
		fire.advance(delta)
		pops+=fire.pop_count
		sounds+=fire.sound_events
	if status!=null:
		status.text = "%.2fs |%.2fx |%s | pops:%d | audio pops:%d | sound:%s" % [clock,speed,"PAUSED" if paused else "PLAY",pops,sounds,sound]
	if state!=null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.sound = sound
		state.smoke = smoke
		state.sparks = sparks
		state.lighting = lighting
		state.pops = pops
		state.audio_pops = sounds
		state.capacity = fires.size()*(24+18)
		var rects := {}
		for name: String in buttons:
			var p := (buttons[name] as Button).get_global_rect().get_center()
			rects[name] = {"x":p.x,"y":p.y}
		state.buttons_json = JSON.stringify(rects)

func _toggle_sound() -> void:
	sound = not sound
	for fire in fires:
		fire.set_sound_enabled(sound)

func _toggle_smoke() -> void:
	smoke = not smoke
	for fire in fires:
		fire.smoke_on = smoke

func _toggle_sparks() -> void:
	sparks = not sparks
	for fire in fires:
		fire.sparks_on = sparks

func _toggle_lighting() -> void:
	lighting = not lighting
	for fire in fires:
		fire.light_on = lighting
