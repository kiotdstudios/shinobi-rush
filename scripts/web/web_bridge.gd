extends Node
## Autoload. Inert outside Web builds. In Web: sets window.__SHINOBI_READY__ after the first
## rendered frames and publishes window.__SHINOBI_STATE__ ~10 Hz for the browser smoke test.
## Read-only: never affects gameplay. The only things it applies are the boot-time URL options ?camera=, ?camera_impact= and ?vision=.

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
	# ?vision=1 starts the Bandit vision debug overlay ON (default OFF); the switch itself lives in BanditVisionToggle.
	BanditVisionToggle.apply_query(search)
	# ?sense_vision=1 starts the proximity sense debug overlay ON (default OFF); switch in SenseVisionToggle.
	SenseVisionToggle.apply_query(search)
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
	var vis := BanditVisionToggle.telemetry()  # Bandit vision debug overlay (additive; zeros / empty while OFF)
	_state.vision_on = vis["vision_on"]
	_state.vision_bandits = vis["vision_bandits"]
	_state.vision_points = vis["vision_points"]
	_state.vision_rays = vis["vision_rays"]
	_state.vision_ms = vis["vision_ms"]
	_state.vision_state = vis["vision_state"]
	_state.vision_ai_state = vis["vision_ai_state"]
	_state.vision_sees = vis["vision_sees"]
	_state.vision_can_see = vis["vision_can_see"]
	_state.vision_player_in = vis["vision_player_in"]
	_state.vision_cone = vis["vision_cone"]
	_state.vision_range = vis["vision_range"]
	_state.vision_close = vis["vision_close"]
	_state.vision_fov_deg = vis["vision_fov_deg"]
	_state.vision_facing_x = vis["vision_facing_x"]
	_state.vision_facing_y = vis["vision_facing_y"]
	_state.vision_mismatch = vis["vision_mismatch"]
	_state.vision_capped = vis["vision_capped"]
	_state.vision_nodes = vis["vision_nodes"]
	_state.vision_origin_x = vis["vision_origin_x"]
	_state.vision_origin_y = vis["vision_origin_y"]
	var lock := _player.get_node_or_null("LockOn") as PlayerLockOn
	_state.target_locked = lock != null and lock.valid_target()
	_state.player_kunai_drawn = _player.kunai_drawn
	_state.player_attack_anim = _player.visual.last_anim
	_state.player_weapon_visible = _player.visual.weapon_visible()  ## owner 2026-10-22: "wire it to the controller"
	_state.player_sense_radius = _player.sense_radius()
	_state.player_ryo = _player.ryo
	var sv := SenseVisionToggle.telemetry()  # proximity sense debug overlay (additive; zeros/false while OFF)
	_state.sense_vision_on = sv["sense_vision_on"]
	_state.sense_vision_views = sv["sense_vision_views"]
	_state.sense_vision_nodes = sv["sense_vision_nodes"]
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
		_state.bandit_senses_player = enemy.senses_player
		_state.bandit_sense_radius = enemy.sense_radius()
		_state.bandit_locked_on = enemy.is_locked_on()
		_state.bandit_stolen_ryo = enemy.stolen_ryo
		_state.bandit_flickers = enemy.flicker_count
		_state.bandit_swings = enemy.swings_thrown
		_state.bandit_hits_landed = enemy.player_hits_landed
		_state.bandit_stuck = enemy.stuck_events
		_state.bandit_taunt = enemy.taunt_timer > 0.0
		_state.bandit_home_dist = enemy.global_position.distance_to(enemy.home)
		_state.bandit_log = enemy.intent_log.slice(maxi(enemy.intent_log.size() - 8, 0))
		_state.player_hits_taken = _player.hits_taken
		_state.player_health = _player.health
		_state.player_max_health = _player.max_health
	var scene := get_tree().current_scene
	var lab := scene.get_node_or_null("AnimationLab") as AnimationLab if scene != null else null
	if lab != null:
		_state.lab_open = lab.lab_on
		_state.lab_animation = lab.anim_id


## Select the camera preset from the page's query string (web only caller). Invalid or missing -> default.
static func apply_camera_query(_query: String) -> void:
	# Owner: the camera is permanently locked to the wide baseline; `?camera=` is ignored.
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)


## Select the hit-kick mode from the page's query string (web only caller): the URL wins, else the browser's reduced-motion
## preference, else on. Garbage in the URL means "on".
static func apply_camera_impact_query(query: String, prefers_reduced_motion: bool = false) -> void:
	CameraImpact.apply_mode(CameraImpact.boot_mode(query, prefers_reduced_motion))


## Camera framing published in __SHINOBI_STATE__: zoom and the visible world size (viewport / zoom).
static func camera_framing(zoom: float, viewport_size: Vector2) -> Dictionary:
	return {"zoom": zoom, "view_w": viewport_size.x / zoom, "view_h": viewport_size.y / zoom}
