class_name PlayerFlickerVisual
extends Node2D
## Art-only component. Aki receives traversal requests; this node never moves/disables a collider.
signal traverse_requested(direction: Vector2, distance: float)
signal event_marker(event: String)
signal finished
const POSES := "res://assets/characters/player/animations/body_flicker_SE.art.json"
const VFX := "res://assets/vfx/body_flicker/"
const FX_FILES := ["depart_000.png", "depart_001.png", "depart_002.png", "travel_000.png", "travel_001.png", "travel_002.png", "travel_003.png", "arrive_000.png", "arrive_001.png", "arrive_002.png"]
var actor: KunaiPoseActor
var ghost: KunaiPoseActor
var effect: Sprite2D
var active := false
var body_hidden := false
var elapsed_ms := 0.0
var speed := 1.0
var beat_count := 1
var beat_index := -1
var direction := Vector2(-1, -1).normalized()
var distance := Vector2(56, 40).length()
var _moved := false
var _shown := false
var _origin := Vector2.ZERO
var _ghost_age := 1000.0
var _data: Dictionary
var _textures: Array[Texture2D] = []

func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	for file: String in FX_FILES:
		_textures.append(load(VFX + file) as Texture2D)
	actor = KunaiPoseActor.new()
	add_child(actor)
	ghost = KunaiPoseActor.new()
	ghost.visible = false
	get_parent().get_parent().add_child.call_deferred(ghost)
	effect = Sprite2D.new()
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.centered = false
	effect.visible = false
	effect.z_index = 3
	get_parent().get_parent().add_child.call_deferred(effect)
	actor.show_pose(_data.frames[0])

func begin(travel_direction: Vector2, beats: int = 1) -> void:
	cancel()
	active = true
	direction = travel_direction.normalized() if travel_direction.length_squared() > 0.01 else Vector2(-1, -1).normalized()
	beat_count = clampi(beats, 1, 2)
	beat_index = -1
	elapsed_ms = 0
	advance(0)

func advance(delta: float) -> void:
	var delta_ms := delta * 1000.0 * speed
	_ghost_age += delta_ms
	if is_instance_valid(ghost):
		ghost.visible = _ghost_age < 100.0
		ghost.modulate = Color(0.6, 0.65, 0.75, 0.65 * maxf(0, 1.0 - _ghost_age / 100.0))
	if not active:
		return
	# Catch every event even across a slow render frame; do not lose beat2 or visibility recovery.
	var target_ms := elapsed_ms + delta_ms
	var total := 120.0 if beat_count == 1 else 280.0
	while active:
		var current := 0 if elapsed_ms < 160.0 else 1
		if current != beat_index:
			_start_beat(current)
		var local := elapsed_ms - float(current) * 160.0
		var next := minf(target_ms, float(current) * 160.0 + 120.0)
		_update_beat(next - float(current) * 160.0)
		elapsed_ms = next
		if elapsed_ms >= total:
			_complete()
			break
		if local >= 120.0 or next >= float(current) * 160.0 + 120.0:
			if target_ms >= 160.0:
				elapsed_ms = 160.0
				continue
			elapsed_ms = target_ms
			break
		break

func _start_beat(index: int) -> void:
	beat_index = index
	_origin = global_position
	_moved = false
	_shown = false
	_ghost_age = 0
	actor.visible = true
	body_hidden = false
	actor.show_pose(_data.frames[0])
	ghost.show_pose(actor.current_pose)
	ghost.global_position = _origin
	ghost.visible = true
	ghost.modulate = Color(0.6, 0.65, 0.75, 0.65)
	event_marker.emit("beat_%d_start" % (index + 1))

func _update_beat(local_ms: float) -> void:
	if local_ms >= 12.0 and not _moved:
		_moved = true
		body_hidden = true
		actor.visible = false
		event_marker.emit("vanish")
		traverse_requested.emit(direction, distance)
	if local_ms >= 84.0 and not _shown:
		_shown = true
		body_hidden = false
		actor.visible = true
		event_marker.emit("reappear")
	var pose_index := 0 if local_ms < 12 else 1 if local_ms < 84 else 2 if local_ms < 108 else 3
	actor.show_pose(_data.frames[pose_index])
	var frame := clampi(int(local_ms / 12.0), 0, 9)
	effect.texture = _textures[frame]
	effect.modulate = Color(0.45, 0.45, 0.45, 0.45)
	effect.global_position = (_origin if frame < 7 else global_position) - Vector2(96, 141)
	effect.visible = local_ms < 120.0

func _complete() -> void:
	active = false
	_ghost_age = 1000.0
	body_hidden = false
	actor.visible = true
	actor.show_pose(_data.frames[3])
	ghost.visible = false
	effect.visible = false
	event_marker.emit("complete")
	finished.emit()

func cancel() -> void:
	active = false
	body_hidden = false
	if actor != null:
		actor.visible = true
	if is_instance_valid(ghost):
		ghost.visible = false
	if is_instance_valid(effect):
		effect.visible = false
	_ghost_age = 1000

func _exit_tree() -> void:
	cancel()
	if is_instance_valid(ghost):
		ghost.queue_free()
	if is_instance_valid(effect):
		effect.queue_free()
