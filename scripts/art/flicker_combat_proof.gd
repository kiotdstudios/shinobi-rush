class_name FlickerCombatProof
extends Node2D
## Interactive SE animation harness, not Aki's gameplay/combo controller.
const PACK := "res://assets/characters/player/kunai_primary_se/kunai-primary.art.json"
var arena: TrainingArena
var actor: CharacterBody2D
var visual: PlayerFlickerVisual
var camera: Camera2D
var status: Label
var inspection := false
var playback_speed := 1.0
var combo_hits := 0
var attack_index := 0
var attack_ms := 0.0
var queued_hit := false
var queued_escape := false
var queued_single := false
var queued_reengage := false
var traversal_count := 0
var vanish_count := 0
var reappear_count := 0
var blocked_count := 0
var double_count := 0
var _move_at_start := Vector2.ZERO
var _clock := 0.0
var _data: Dictionary
var _state: JavaScriptObject
var _events: Array[Dictionary] = []

func _ready() -> void:
	var bridge := get_node_or_null("/root/WebBridge")
	if bridge != null:
		bridge.set_process(false)
	_data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	arena = (load("res://scenes/arena/training_arena.tscn") as PackedScene).instantiate() as TrainingArena
	add_child(arena)
	actor = CharacterBody2D.new()
	actor.name = "ProofActor"
	actor.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = WorldScale.FOOTPRINT
	collider.shape = shape
	collider.position = Vector2(0, -WorldScale.FOOTPRINT.y * 0.5)
	actor.add_child(collider)
	visual = PlayerFlickerVisual.new()
	actor.add_child(visual)
	arena.add_child(actor)
	actor.global_position = arena.spawn.global_position
	visual.traverse_requested.connect(_traverse)
	visual.event_marker.connect(_marker)
	visual.finished.connect(_flicker_done)
	camera = Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.zoom = Vector2.ONE * (720.0 * 0.175 / 104.0)
	actor.add_child(camera)
	_build_ui()
	if OS.has_feature("web"):
		_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__FLICKER_PROOF__ = _state

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("attack_light"):
		attack()
	elif event.is_action_pressed("dodge"):
		single_flicker()
	elif event.is_action_pressed("dbg_toggle_lab"):
		toggle_inspection()

func attack() -> void:
	if inspection:
		return
	if visual.active:
		queued_reengage = true
	elif attack_index > 0:
		queued_hit = attack_index == 1
	else:
		_start_attack(1)

func _start_attack(index: int) -> void:
	attack_index = index
	attack_ms = 0
	combo_hits = index
	_move_at_start = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_marker("kunai_%d_start" % index)

func single_flicker() -> void:
	if inspection:
		return
	if attack_index > 0:
		queued_single = true
	else:
		_begin_flicker(1)

func double_back() -> void:
	if inspection or combo_hits < 2:
		return
	queued_escape = true
	if attack_index == 0 and not visual.active:
		_begin_flicker(2)

func _away_from_target() -> Vector2:
	var target := arena.get_node_or_null("Bandit") as Node2D
	return (actor.global_position - target.global_position).normalized() if target != null else Vector2(-1, -1).normalized()

func _begin_flicker(beats: int) -> void:
	attack_index = 0
	queued_hit = false
	queued_single = false
	queued_escape = false
	if beats == 2:
		double_count += 1
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_move_at_start = input_dir
	var travel_dir := input_dir if beats == 1 and input_dir.length_squared() > 0.01 else _away_from_target()
	visual.speed = playback_speed
	visual.begin(travel_dir, beats)

func _physics_process(delta: float) -> void:
	if visual == null:
		return
	_clock += delta * 1000.0
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if inspection:
		return
	if (visual.active or attack_index > 0) and input_dir.length_squared() > 0.01 and input_dir.distance_to(_move_at_start) > 0.2:
		interrupt()
	if visual.active:
		visual.advance(delta)
		return
	visual.advance(delta)
	if attack_index > 0:
		var before := attack_ms
		attack_ms += delta * 1000.0 * playback_speed
		var action := "light%d" % attack_index
		var clip: Dictionary = _data.animations[action]
		var contact_ms := 250.0 / 3.0 if attack_index == 1 else 100.0
		if before < contact_ms and attack_ms >= contact_ms:
			_marker("kunai_%d_contact" % attack_index)
		var pose := _pose_at(clip, attack_ms).duplicate(true)
		# Reverse grip: blade trails the punching fist instead of becoming a long forward sword.
		if attack_index == 1 and int(pose.frame_index) in [2, 3]:
			pose.weapon_angle_deg = 140.0
		visual.actor.show_pose(pose)
		if attack_index == 1 and queued_hit and attack_ms >= 150.0:
			queued_hit = false
			_start_attack(2)
		elif (queued_escape or queued_single) and attack_ms >= (200.0 if attack_index == 1 else 700.0 / 3.0):
			_begin_flicker(2 if queued_escape else 1)
		elif attack_ms + 0.001 >= float(clip.duration_ms):
			attack_index = 0
		return
	actor.velocity = input_dir * WorldScale.WALK_SPEED
	actor.move_and_slide()
	if input_dir.length_squared() > 0.01:
		var run: Dictionary = _data.animations.run
		visual.actor.show_pose(_pose_at(run, fmod(_clock, float(run.duration_ms))))
	else:
		visual.actor.show_pose(_data.animations.guard.frames[0])

func _pose_at(clip: Dictionary, ms: float) -> Dictionary:
	var result: Dictionary = clip.frames[0]
	for frame: Dictionary in clip.frames:
		if ms >= float(frame.start_ms):
			result = frame
	return result

func _traverse(direction: Vector2, distance: float) -> void:
	# Swept collision is only for this proof actor; production movement remains Aki-owned.
	var collision := actor.move_and_collide(direction * distance)
	traversal_count += 1
	if collision != null:
		blocked_count += 1

func _marker(event: String) -> void:
	if event == "vanish":
		vanish_count += 1
	elif event == "reappear":
		reappear_count += 1
	_events.append({"event": event, "proof_ms": _clock})
	if _events.size() > 64:
		_events.pop_front()

func _flicker_done() -> void:
	combo_hits = 0
	if queued_reengage:
		queued_reengage = false
		_start_attack(1)

func interrupt() -> void:
	visual.cancel()
	attack_index = 0
	combo_hits = 0
	queued_hit = false
	queued_escape = false
	queued_single = false
	queued_reengage = false

func toggle_inspection() -> void:
	interrupt()
	inspection = not inspection

func reset() -> void:
	interrupt()
	inspection = false
	actor.global_position = arena.spawn.global_position

func _process(_delta: float) -> void:
	if visual == null or status == null:
		return
	var mode := "INSPECTION / visible" if inspection else "FLICKER %d/ %d" % [visual.beat_index + 1, visual.beat_count] if visual.active else "KUNAI %d" % attack_index if attack_index > 0 else "READY"
	status.text = "%s | %.0f ms | %.2fx | escapes %d | wall stops %d" % [mode, visual.elapsed_ms if visual.active else attack_ms, playback_speed, double_count, blocked_count]
	if _state != null:
		_state.ready = true
		_state.mode = mode
		_state.attack = attack_index
		_state.combo_hits = combo_hits
		_state.flicker_active = visual.active
		_state.body_visible = visual.actor.visible
		_state.ghost_visible = visual.ghost.visible
		_state.effect_visible = visual.effect.visible
		_state.inspection = inspection
		_state.traversals = traversal_count
		_state.vanishes = vanish_count
		_state.reappears = reappear_count
		_state.double_count = double_count
		_state.x = actor.position.x
		_state.y = actor.position.y
		_state.speed = playback_speed
		_state.binding = "double escape uses preview button; final binding pending owner/Aki"

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	for text: String in ["SE KUNAI + BODY FLICKER — INTERACTIVE ART PROOF", "WASD move | J hit twice | Space single flicker | Tab inspect\nChoose Double back after hit 2; it never fires automatically.\nPractice a single dodge or two hits followed by a double retreat."]:
		var label := Label.new()
		label.text = text
		column.add_child(label)
	status = Label.new()
	column.add_child(status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_button(actions, "Kunai hit (J)", attack)
	_button(actions, "Single flicker", single_flicker)
	_button(actions, "Double back", double_back)
	_button(actions, "Re-engage", attack)
	_button(actions, "Reset", reset)
	var review := HBoxContainer.new()
	column.add_child(review)
	_button(review, "Normal", func(): playback_speed = 1.0; visual.speed = 1.0)
	_button(review, "Half speed", func(): playback_speed = 0.5; visual.speed = 0.5)
	_button(review, "Inspect (Tab)", toggle_inspection)
	_button(review, "2x zoom", func(): camera.zoom = Vector2.ONE * 2)

func _button(row: HBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	row.add_child(button)
