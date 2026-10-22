extends Node2D
var visual: ChakraChargeVisual
var status: Label
var camera: Camera2D
var state: JavaScriptObject
var color_name := "Blue"
var controls: Array[BaseButton] = []

func _ready() -> void:
	var bridge := get_node_or_null("/root/WebBridge")
	if bridge != null:
		bridge.set_process(false)
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = KosenFloorTileset.build()
	add_child(floor_layer)
	for x in range(-20,21):
		for y in range(-20,21):
			floor_layer.set_cell(Vector2i(x,y), KosenFloorTileset.pick_interior_source_id(x,y), Vector2i.ZERO)
	visual = ChakraChargeVisual.new()
	add_child(visual)
	camera = Camera2D.new()
	camera.position = Vector2(0,-40)
	camera.zoom = Vector2.ONE * 1.5
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, get_viewport_rect().size.y-170)
	layer.add_child(panel)
	get_viewport().size_changed.connect(func(): panel.position.y = get_viewport_rect().size.y-170)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status = Label.new()
	column.add_child(status)
	var timing := HBoxContainer.new()
	column.add_child(timing)
	button(timing,"Normal",func(): visual.speed=1.0; visual.paused=false)
	button(timing,"Half speed",func(): visual.speed=0.5; visual.paused=false)
	button(timing,"Pause",func(): visual.paused=not visual.paused)
	button(timing,"Step",func(): visual.paused=true; visual.advance(1.0/24.0))
	button(timing,"Charge on/off",func(): visual.set_charging(not visual.charging))
	button(timing,"Gameplay zoom",func(): camera.zoom=Vector2.ONE*WorldScale.CAMERA_BASE_ZOOM)
	button(timing,"Inspect 2x",func(): camera.zoom=Vector2.ONE*2)
	var dirs := HBoxContainer.new()
	column.add_child(dirs)
	for dir: String in SpriteSet.DIRS8:
		button(dirs,dir,func(): visual.direction=dir; visual.advance(0))
	var colors := HBoxContainer.new()
	column.add_child(colors)
	var palettes := {"Blue": ChakraChargeVisual.BLUE, "Violet": Color(0.65,0.2,1.0), "Amber": Color(1.0,0.65,0.05), "Crimson": Color(1.0,0.12,0.18), "Jade": Color(0.1,1.0,0.5)}
	for name: String in palettes:
		button(colors,name,func(): color_name=name; visual.set_chakra_color(palettes[name]))
	for id: String in ["aura", "wisps", "ground"]:
		var check := CheckBox.new()
		check.text = {"aura":"Flame", "wisps":"Spirals", "ground":"Ground"}[id]
		check.button_pressed=true
		check.focus_mode=Control.FOCUS_NONE
		check.toggled.connect(func(value: bool): (visual.layers[id] as Sprite2D).visible=value)
		colors.add_child(check)
		controls.append(check)
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__CHAKRA_STATE__=state

func button(row: HBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text=text
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size.y=40
	b.pressed.connect(action)
	row.add_child(b)
	controls.append(b)

func _process(_delta: float) -> void:
	if visual==null:
		return
	status.text="CHAKRA | %s | phase %03d/96 | %.2fx | %s | %.2fs | 48 flame + 32 wisp + 16 ground frames" % [visual.direction,visual.phase(),visual.speed,color_name,visual.clock]
	if state!=null:
		state.ready=true
		state.phase=visual.phase()
		state.body_frame=visual.body_frame()
		state.time=visual.clock
		state.speed=visual.speed
		state.paused=visual.paused
		state.direction=visual.direction
		state.color=color_name
		state.charging=visual.charging
		state.opacity=visual.opacity
		state.directions=visual.data.body.size()
		state.zoom=camera.zoom.x
		state.texture_cache=visual.textures.size()
		state.layers_json=JSON.stringify({"aura":(visual.layers.aura as Sprite2D).visible,"wisps":(visual.layers.wisps as Sprite2D).visible,"ground":(visual.layers.ground as Sprite2D).visible})
		var rects: Dictionary = {}
		for control in controls:
			var rect := control.get_global_rect()
			rects[control.text]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		state.controls_json=JSON.stringify(rects)
