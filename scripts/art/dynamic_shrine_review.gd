extends Node2D
var shrine: DynamicShrine
var speed := 0.5
var paused := false
var status: Label
var state: JavaScriptObject
var buttons: Dictionary = {}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#101c22"))
	shrine = DynamicShrine.new()
	shrine.auto_advance = false
	shrine.position = Vector2(640,630)
	shrine.scale = Vector2(1.2,1.2)
	add_child(shrine)
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20,16)
	layer.add_child(box)
	var title := Label.new()
	title.text = "BLIGHTWOOD | ANCIENT FLAME SHRINE | PixelLab reference recreation"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half speed",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;shrine.advance(1.0/24.0))
	_button(row,"Glow",func():shrine.lighting_on=not shrine.lighting_on)
	_button(row,"Vines",func():shrine.vines_on=not shrine.vines_on)
	_button(row,"Fireflies",func():shrine.fireflies_on=not shrine.fireflies_on)
	_button(row,"God rays",func():shrine.rays_on=not shrine.rays_on)
	status = Label.new()
	box.add_child(status)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__SHRINE_REVIEW__ = state
		paused = "paused=1" in str(JavaScriptBridge.eval("window.location.search",true))

func _button(row: HBoxContainer,text: String,action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	row.add_child(b)
	buttons[text] = b

func _process(delta: float) -> void:
	shrine.advance(0.0 if paused else delta*speed)
	status.text = "%.2fs | %.2fx | %s | 3 independent swarms / 42 fireflies | rooted stone" % [shrine.clock,speed,"PAUSED" if paused else "PLAY"]
	if state != null:
		state.ready = true
		state.clock = shrine.clock
		state.speed = speed
		state.paused = paused
		state.swarms = shrine.swarms.size()
		state.pulse = shrine.pulse
		state.glow = shrine.lighting_on
		state.vines = shrine.vines_on
		state.fireflies = shrine.fireflies_on
		state.rays = shrine.rays_on
		state.body_x = shrine.body.position.x
		state.body_y = shrine.body.position.y
		var rects := {}
		for key: String in buttons:
			var r: Rect2 = buttons[key].get_global_rect()
			rects[key] = {"x":r.get_center().x,"y":r.get_center().y}
		state.buttons_json = JSON.stringify(rects)
