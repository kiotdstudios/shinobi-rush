class_name PlayerLockOn
extends Node2D
## Target selection only. Does not steer movement, camera, combat or attack hitboxes.
const RANGE := 650.0
var target: Node2D

func _ready() -> void:
	if not InputMap.has_action("lock_on"):
		InputMap.add_action("lock_on")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_L
		InputMap.action_add_event("lock_on", key)
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_RIGHT_STICK
		InputMap.action_add_event("lock_on", button)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if valid_target():
		target = null
		return
	target = null
	var nearest := RANGE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			target = enemy

func valid_target() -> bool:
	return is_instance_valid(target) and target.has_method("is_alive") and target.is_alive() and global_position.distance_to(target.global_position) <= RANGE

func is_targeted(enemy: Node2D) -> bool:
	return valid_target() and target == enemy

func _process(_delta: float) -> void:
	if not valid_target():
		target = null
	queue_redraw()

func _draw() -> void:
	if not valid_target():
		return
	var center := to_local(target.global_position) + Vector2(0, -60)
	for i in 4:
		var angle := PI * 0.5 * i + PI * 0.25
		draw_arc(center, 46.0, angle - 0.16, angle + 0.16, 5, Color("ffd87a"), 2.0)
