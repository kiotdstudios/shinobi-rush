extends Node
## Autoload. Inert outside Web builds. In Web: sets window.__SHINOBI_READY__ after the first
## rendered frames and publishes window.__SHINOBI_STATE__ ~10 Hz for the browser smoke test.
## Read-only: never affects gameplay. The only things it applies are the boot-time URL options ?camera= and ?camera_impact=.

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
	# Publish after every default-priority node has processed this frame, so cfx_offset_* is the offset about to be rendered.
	process_priority = 1
	# ?camera=wide|close|<number>: autoloads are ready before the main scene, so the player already sees it.
	var search := str(JavaScriptBridge.eval("window.location.search", true))
	apply_camera_query(search)
	# ?camera_impact=off|reduced|on (hit kick); without it "reduced" when the browser asks for reduced motion.
	apply_camera_impact_query(search, bool(JavaScriptBridge.eval("!!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)", true)))
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
	var cfx := CameraImpact.telemetry()  # camera hit kick (screen px); additive fields
	_state.cfx_enabled = cfx["cfx_enabled"]
	_state.cfx_scale = cfx["cfx_scale"]
	_state.cfx_active = cfx["cfx_active"]
	_state.cfx_offset_x = cfx["cfx_offset_x"]
	_state.cfx_offset_y = cfx["cfx_offset_y"]
	_state.cfx_peak_px = cfx["cfx_peak_px"]
	_state.cfx_count = cfx["cfx_count"]
	var lock := _player.get_node_or_null("LockOn") as PlayerLockOn
	_state.target_locked = lock != null and lock.valid_target()
	var enemy := get_tree().get_first_node_in_group("enemy") as Bandit
	if enemy != null:
		_state.bandit_state = enemy.get_state_name()
		_state.bandit_x = enemy.global_position.x
		_state.bandit_y = enemy.global_position.y
		_state.bandit_evades = enemy.evade_count
		_state.bandit_animation = (enemy.visual as BanditVisual).actor.anim_id
		_state.bandit_frame = (enemy.visual as BanditVisual).actor.sprite.frame
		_state.bandit_level = enemy.intelligence_level
		_state.bandit_intent = enemy.get_intent()
		_state.bandit_sees = enemy.sees_player
		_state.bandit_flickers = enemy.flicker_count
		_state.bandit_swings = enemy.swings_thrown
		_state.bandit_hits_landed = enemy.player_hits_landed
		_state.bandit_stuck = enemy.stuck_events
		_state.bandit_taunt = enemy.taunt_timer > 0.0
		_state.bandit_home_dist = enemy.global_position.distance_to(enemy.home)
		_state.bandit_log = enemy.intent_log.slice(maxi(enemy.intent_log.size() - 8, 0))
		_state.player_hits_taken = _player.hits_taken
	var scene := get_tree().current_scene
	var lab := scene.get_node_or_null("AnimationLab") as AnimationLab if scene != null else null
	if lab != null:
		_state.lab_open = lab.lab_on
		_state.lab_animation = lab.anim_id


## Select the camera preset from the page's query string (web only caller). Invalid or missing -> default.
static func apply_camera_query(query: String) -> void:
	CameraPreset.set_active(CameraPreset.parse_query(query))


## Select the hit-kick mode from the page's query string (web only caller): the URL wins, else the browser's reduced-motion
## preference, else on. Garbage in the URL means "on".
static func apply_camera_impact_query(query: String, prefers_reduced_motion: bool = false) -> void:
	CameraImpact.apply_mode(CameraImpact.boot_mode(query, prefers_reduced_motion))


## Camera framing published in __SHINOBI_STATE__: zoom and the visible world size (viewport / zoom).
static func camera_framing(zoom: float, viewport_size: Vector2) -> Dictionary:
	return {"zoom": zoom, "view_w": viewport_size.x / zoom, "view_h": viewport_size.y / zoom}
