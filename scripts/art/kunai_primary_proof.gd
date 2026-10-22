class_name KunaiPrimaryProof
extends Node2D
## Opt-in art player; independent of the gameplay combat controller and camera impact.
const PACK := "res://assets/characters/player/kunai_primary_se/kunai-primary.art.json"
var data: Dictionary
var timeline: Array[Dictionary] = []
var elapsed_ms := 0.0
var total_ms := 0.0
var playback_speed := 0.5
var paused := false
var last_frame := -1
var body: Sprite2D
var blade: Sprite2D
var grip: Node2D
var hand: Sprite2D
var swipe: Sprite2D
var camera: Camera2D
var status: Label
var scrub: HSlider
var _textures: Dictionary = {}
var _web_state: JavaScriptObject

func _ready() -> void:
	var bridge := get_node_or_null("/root/WebBridge")
	if bridge != null:
		bridge.set_process(false)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = KosenFloorTileset.build()
	add_child(floor_layer)
	for x in range(-24, 25):
		for y in range(-24, 25):
			floor_layer.set_cell(Vector2i(x, y), KosenFloorTileset.pick_interior_source_id(x, y), Vector2i.ZERO)
	camera = Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.zoom = Vector2.ONE * (720.0 * 0.175 / 104.0)
	add_child(camera)
	body = Sprite2D.new()
	body.centered = false
	body.position = Vector2(-64, -116)
	add_child(body)
	grip = Node2D.new()
	add_child(grip)
	blade = Sprite2D.new()
	blade.centered = false
	blade.texture = _texture(str(data.weapon.texture))
	blade.position = Vector2(-25, -31)
	grip.add_child(blade)
	hand = Sprite2D.new()
	hand.centered = false
	hand.z_index = 2
	add_child(hand)
	swipe = Sprite2D.new()
	swipe.z_index = 3
	add_child(swipe)
	_build_ui()
	select_action("sequence")
	if OS.has_feature("web"):
		_web_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__KUNAI_PROOF__ = _web_state
	_process(0)

func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path] as Texture2D

func select_action(id: String) -> void:
	timeline.clear()
	total_ms = 0
	var steps: Array = data.sequence if id == "sequence" else [{"animation": id}]
	for step_data: Dictionary in steps:
		var action: Dictionary = data.animations[step_data.animation]
		for frame: Dictionary in action.frames:
			if float(frame.start_ms) >= float(step_data.get("end_ms", action.duration_ms)) - 0.001:
				break
			var entry: Dictionary = frame.duplicate(true)
			entry["duration_ms"] = minf(float(entry.duration_ms), float(step_data.get("end_ms", action.duration_ms)) - float(frame.start_ms))
			entry["animation"] = step_data.animation
			entry["timeline_start"] = total_ms
			timeline.append(entry)
			total_ms += float(entry.duration_ms)
	elapsed_ms = 0
	last_frame = -1
	if scrub != null:
		scrub.set_block_signals(true)
		scrub.max_value = total_ms
		scrub.set_value_no_signal(0.0)
		scrub.set_block_signals(false)

func _process(delta: float) -> void:
	if timeline.is_empty():
		return
	if not paused:
		elapsed_ms = fmod(elapsed_ms + delta * 1000.0 * playback_speed, total_ms)
	var index := frame_at(elapsed_ms)
	var frame: Dictionary = timeline[index]
	if index != last_frame:
		last_frame = index
		body.texture = _texture(str(frame.body_frame))
		var socket := Vector2(float(frame.right_hand_px[0]), float(frame.right_hand_px[1]))
		grip.position = socket - Vector2(64, 116)
		grip.rotation = deg_to_rad(float(frame.weapon_angle_deg))
		grip.z_index = -1 if frame.weapon_layer == "behind" else 1
		var patch := AtlasTexture.new()
		patch.atlas = body.texture
		patch.region = Rect2(socket - Vector2(2, 2), Vector2(5, 5))
		hand.texture = patch
		hand.position = socket - Vector2(66, 118)
	var effect_index := int(frame.get("swipe_frame", -1))
	swipe.visible = effect_index >= 0
	if swipe.visible:
		swipe.texture = _texture(str(data.vfx.frames[effect_index]))
		swipe.position = grip.position + Vector2(10, 5)
		swipe.rotation = deg_to_rad(float(frame.get("swipe_rotation_deg", 0)))
	status.text = "%s  |  frame %d  |  %.0f / %.0f ms  |  %.2fx%s" % [str(frame.animation).to_upper(), int(frame.frame_index) + 1, elapsed_ms, total_ms, playback_speed, "  CONTACT" if frame.get("contact", false) else ""]
	if not scrub.has_focus():
		scrub.set_value_no_signal(elapsed_ms)
	if _web_state != null:
		_web_state.ready = true
		_web_state.animation = str(frame.animation)
		_web_state.frame = int(frame.frame_index)
		_web_state.time_ms = elapsed_ms
		_web_state.duration_ms = total_ms
		_web_state.speed = playback_speed
		_web_state.paused = paused
		_web_state.weapon_visible = blade.visible
		_web_state.weapon_layer = str(frame.weapon_layer)
		_web_state.socket_x = grip.position.x + 64
		_web_state.socket_y = grip.position.y + 116
		_web_state.swipe_visible = swipe.visible

func frame_at(ms: float) -> int:
	for i in range(timeline.size() - 1, -1, -1):
		if ms >= float(timeline[i].timeline_start):
			return i
	return 0

func step() -> void:
	paused = true
	elapsed_ms = float(timeline[(frame_at(elapsed_ms) + 1) % timeline.size()].timeline_start)
	_process(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	for text: String in ["KUNAI — SOUTHEAST ART PROOF", "Guard > combo > dodge > dash strike > run\nArt review only. Gameplay hit logic is unchanged."]:
		var label := Label.new()
		label.text = text
		column.add_child(label)
	status = Label.new()
	column.add_child(status)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_button(buttons, "Half speed", func(): playback_speed = 0.5)
	_button(buttons, "Normal", func(): playback_speed = 1.0)
	_button(buttons, "Pause / Play", func(): paused = not paused)
	_button(buttons, "Step", step)
	_button(buttons, "Restart", func(): elapsed_ms = 0.0)
	var second := HBoxContainer.new()
	column.add_child(second)
	var action_select := OptionButton.new()
	action_select.add_item("Complete sequence")
	action_select.set_item_metadata(0, "sequence")
	for id: String in data.animations:
		action_select.add_item(id)
		action_select.set_item_metadata(action_select.item_count - 1, id)
	action_select.item_selected.connect(func(i: int): select_action(str(action_select.get_item_metadata(i))))
	second.add_child(action_select)
	_button(second, "Game zoom", func(): camera.zoom = Vector2.ONE * (720.0 * 0.175 / 104.0))
	_button(second, "2x inspect", func(): camera.zoom = Vector2.ONE * 2.0)
	scrub = HSlider.new()
	scrub.custom_minimum_size = Vector2(580, 32)
	scrub.step = 1
	scrub.value_changed.connect(func(value: float): paused = true; elapsed_ms = value)
	column.add_child(scrub)

func _button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	row.add_child(button)
