extends Node2D
var water_nodes: Array[BlightwoodWater] = []
var clock := 0.0
var speed := 0.5
var paused := false
var spray := true
var status: Label
var buttons: Dictionary = {}
var state: JavaScriptObject

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#1a2d2f"))
	var stage := Node2D.new()
	stage.position = Vector2(335,35)
	stage.scale = Vector2(2,2)
	add_child(stage)
	# Joined irregular river/pool; no banks, rocks, plants or decorations baked into water.
	for u in range(-2,6):
		for v in range(-1,3):
			if u < 0 and v == 2:continue
			if u > 5 and v == -1:continue
			var w := BlightwoodWater.new()
			w.auto_advance = false
			w.position = Vector2((u-v)*36,205+(u+v)*18)
			stage.add_child(w)
			water_nodes.append(w)
	var fall := BlightwoodWater.new()
	fall.auto_advance = false
	fall.waterfall = true
	fall.position = Vector2(0,192)
	stage.add_child(fall)
	water_nodes.append(fall)
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20,14)
	layer.add_child(box)
	var title := Label.new()
	title.text = "BLIGHTWOOD | clear river + small waterfall | water-only PixelLab art"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half speed",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;_advance(1.0/24.0))
	_button(row,"Spray / foam",func():spray=not spray)
	status = Label.new()
	box.add_child(status)
	var label := Label.new()
	label.position = Vector2(20,690)
	label.text = "16-frame surface + 16-frame cascade + 16-frame foam | shared current across tile seams | separate spray"
	layer.add_child(label)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__WATER_REVIEW__ = state
		if "paused=1" in str(JavaScriptBridge.eval("window.location.search",true)):paused=true
	_advance(0.0)

func _button(row: HBoxContainer,text: String,action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	row.add_child(b)
	buttons[text] = b

func _process(delta: float) -> void:
	_advance(0.0 if paused else delta*speed)

func _advance(delta: float) -> void:
	clock += delta
	for water in water_nodes:
		water.spray_on = spray
		water.advance(delta)
	status.text = "%.2fs | %.2fx | %s | independent flow, foam and droplets" % [clock,speed,"PAUSED" if paused else "PLAY"]
	if state != null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.spray = spray
		state.fall_frame = water_nodes[-1].fall.frame
		state.foam_frame = water_nodes[-1].foam.frame
		state.drops = water_nodes[-1].drops.size()
		state.drop_x = water_nodes[-1].drops[0].position.x
		var rects := {}
		for key: String in buttons:
			var r: Rect2 = buttons[key].get_global_rect()
			rects[key] = {"x":r.get_center().x,"y":r.get_center().y}
		state.buttons_json = JSON.stringify(rects)
