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
	_state.x = _player.global_position.x
	_state.y = _player.global_position.y
	_state.state = _player.get_state_name()
	_state.sprinting = _player.state == PlayerController.State.SPRINT
	_state.fps = Engine.get_frames_per_second()
