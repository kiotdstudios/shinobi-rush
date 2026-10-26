extends Node2D
var water_nodes: Array[BlightwoodWater] = []
var stages: Array[Node2D] = []
var family_labels: Array[Label] = []
var clock := 0.0
var speed := 0.5
var paused := false
var focus := "All"
var status: Label
var buttons: Dictionary = {}
var state: JavaScriptObject

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#1a2d2f"))
	var families := ["grass","dirt","rock"]
	for k in 3:
		var stage := Node2D.new()
		add_child(stage)
		stages.append(stage)
		# Corner terrain is sampled from the same vertex field by adjacent diamonds.
		for i in range(-2,3):
			for j in range(-2,3):
				var mask := _land(i,j)*8 + _land(i+1,j)*4 + _land(i,j+1)*2 + _land(i+1,j+1)
				var water := BlightwoodWater.new()
				water.auto_advance = false
				water.shore_family = families[k]
				water.shore_mask = mask
				water.position = Vector2((i-j)*36,(i+j)*18)
				stage.add_child(water)
				water_nodes.append(water)
		# Plain live river cells extend from the pond and meet the shoreline's shared UV/current.
		for i in range(3,5):
			for j in range(-1,2):
				var water := BlightwoodWater.new()
				water.auto_advance = false
				if j != 0:
					water.shore_family = families[k]
					water.shore_mask = _land(i,j)*8 + _land(i+1,j)*4 + _land(i,j+1)*2 + _land(i+1,j+1)
				water.position = Vector2((i-j)*36,(i+j)*18)
				stage.add_child(water)
				water_nodes.append(water)
	_set_focus("All")
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20,15)
	layer.add_child(box)
	var title := Label.new()
	title.text = "BLIGHTWOOD SHORELINES | grass / dirt / rocky | 48 connected pieces"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half speed",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;_advance(1.0/24.0))
	for name: String in ["All","Grass","Dirt","Rock"]:
		_button(row,name,_set_focus.bind(name))
	status = Label.new()
	box.add_child(status)
	for k in 3:
		var label := Label.new()
		label.text = ["GRASS BANKS","DIRT BANKS","ROCKY BANKS"][k]
		label.position = Vector2(150+k*420,600)
		layer.add_child(label)
		family_labels.append(label)
	var caption := Label.new()
	caption.position = Vector2(20,680)
	caption.text = "72x36 native diamonds | separate shore layers | existing flowing water | inner/outer corners + diagonal joins"
	layer.add_child(caption)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__SHORE_REVIEW__ = state
		if "paused=1" in str(JavaScriptBridge.eval("window.location.search",true)):paused=true
	_advance(0.0)

func _land(i: int,j: int) -> int:
	# A pond with a short river outlet; all endpoint samples remain deterministic.
	return 0 if (i*i+j*j <= 2) or (i>=1 and j in [0,1]) else 1

func _set_focus(name: String) -> void:
	focus = name
	for k in stages.size():
		stages[k].visible = name=="All" or name==["Grass","Dirt","Rock"][k]
		stages[k].scale = Vector2.ONE if name=="All" else Vector2(2,2)
		stages[k].position = Vector2(220+k*420,380) if name=="All" else Vector2(640,380)
		if family_labels.size()==3:
			family_labels[k].visible = stages[k].visible
			family_labels[k].position = Vector2(150+k*420,600) if name=="All" else Vector2(560,640)

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
	for water in water_nodes:water.advance(delta)
	if status!=null:status.text = "%.2fs | %.2fx | %s | %s | shared river current, rooted shore" % [clock,speed,"PAUSED" if paused else "PLAY",focus]
	if state != null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.focus = focus
		state.tiles = water_nodes.size()
		state.current_time = (water_nodes[0].surface.material as ShaderMaterial).get_shader_parameter("motion_time")
		state.root_x = water_nodes[0].position.x
		state.root_y = water_nodes[0].position.y
		var rects := {}
		for key: String in buttons:
			var r: Rect2 = buttons[key].get_global_rect()
			rects[key] = {"x":r.get_center().x,"y":r.get_center().y}
		state.buttons_json = JSON.stringify(rects)
