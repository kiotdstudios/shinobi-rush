extends Node
## Autoload. Inert outside Web builds. In Web: sets window.__SHINOBI_READY__ after the first
## rendered frames and publishes window.__SHINOBI_STATE__ ~10 Hz for the browser smoke test.
## Read-only: never affects gameplay.

const PUBLISH_INTERVAL := 0.1

var active: bool = false
var _window: JavaScriptObject
var _state: JavaScriptObject
var _timer: float = 0.0
var _player: PlayerController


func _ready() -> void:
	active = OS.has_feature("web")
	set_process(active)
	if not active:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ?camera=wide|close|<number>: autoloads are ready before the main scene, so the player already sees it.
	apply_camera_query(str(JavaScriptBridge.eval("window.location.search", true)))
	_window = JavaScriptBridge.get_interface("window")
	_state = JavaScriptBridge.create_object("Object")
	_window.__SHINOBI_STATE__ = _state
	await get_tree().process_frame
	await get_tree().process_frame
	_window.__SHINOBI_READY__ = true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PUBLISH_INTERVAL
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return
	_state.frame = Engine.get_process_frames()
	_state.physics_frame = Engine.get_physics_frames()
	_state.x = _player.global_position.x
	_state.y = _player.global_position.y
	_state.state = _player.get_state_name()
	_state.sprinting = _player.state == PlayerController.State.SPRINT
	_state.fps = Engine.get_frames_per_second()
	var framing := camera_framing(_player.camera.zoom.x, _player.get_viewport().get_visible_rect().size)
	_state.zoom = framing.zoom
	_state.view_w = framing.view_w
	_state.view_h = framing.view_h
	_state.camera_preset = CameraPreset.active_id()
	_state.figure_height_px = _player.figure_height_px()
	_state.sprite_set_id = _player.visual.sprite_set.id if _player.visual.sprite_set != null else "placeholder"
	var scene := get_tree().current_scene
	var lab := scene.get_node_or_null("AnimationLab") as AnimationLab if scene != null else null
	if lab != null:
		_state.lab_open = lab.lab_on
		_state.lab_animation = lab.anim_id


## Select the camera preset from the page's query string (web only caller). Invalid or missing -> default.
static func apply_camera_query(query: String) -> void:
	CameraPreset.set_active(CameraPreset.parse_query(query))


## Camera framing published in __SHINOBI_STATE__: zoom and the visible world size (viewport / zoom).
static func camera_framing(zoom: float, viewport_size: Vector2) -> Dictionary:
	return {"zoom": zoom, "view_w": viewport_size.x / zoom, "view_h": viewport_size.y / zoom}
