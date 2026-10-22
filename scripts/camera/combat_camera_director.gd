class_name CombatCameraDirector
extends Node
## Event-driven dynamic combat camera director for Shinobi Rush.
## Sits between the CameraPreset baseline and any pure-impulse effects (CameraImpact).
## Writes Camera2D.zoom ONLY via additive delta from the baseline; never touches position, offset,
## limits, or smoothing (those belong to PlayerController and CameraImpact).
##
## Contract:
##   1. Instantiate once under the player node (or any persistent node with camera access).
##      Call CombatCameraDirector.notify(event, payload) from gameplay code to trigger an effect.
##   2. Supported events (see EventKind enum):
##        LIGHT_HIT    - confirmed light-attack contact; payload: {"dir": Vector2, "target_pos": Vector2}
##        HEAVY_HIT    - confirmed heavy-attack contact; payload: {"dir": Vector2, "target_pos": Vector2}
##        DODGE        - perfect/any dodge initiated;   payload: {"dir": Vector2}
##        JUTSU        - jutsu effect triggered;         payload: {"target_pos": Vector2}
##        FINISHER     - standard finisher;              payload: {"attacker_pos": Vector2, "target_pos": Vector2}
##        TAKE_DAMAGE  - player takes a hit;             payload: {"dir": Vector2} (attacker -> player)
##        RESET        - explicit camera reset request;  payload: {}
##   3. Priority stack (highest wins): FINISHER > JUTSU > HEAVY_HIT > LIGHT_HIT > DODGE > TAKE_DAMAGE > baseline.
##      A higher-priority event interrupts a lower-priority effect immediately and cleans up.
##   4. Zoom is additive: the director holds a `zoom_delta` relative to the camera's current baseline.
##      It never stores the absolute baseline zoom itself; it reads it from CameraPreset each frame.
##   5. Accessibility: settings.zoom_scale (0-1) and settings.shake_scale (0-1) gate every effect.
##      A reduced-motion URL param (?camera_director=reduced) halves both. off disables entirely.
##   6. Telemetry: every event accepted is published to DebugTelemetry (cam_dir_event, cam_dir_priority,
##      cam_dir_zoom_delta, cam_dir_active, cam_dir_event_count).

## -------------------------------------------------------------------------  enums / constants

enum EventKind {
	NONE       = 0,
	TAKE_DAMAGE = 1,
	DODGE      = 2,
	LIGHT_HIT  = 3,
	HEAVY_HIT  = 4,
	JUTSU      = 5,
	FINISHER   = 6,
}

## Priority: higher number = higher priority, always wins.
const PRIORITY: Dictionary = {
	EventKind.NONE:        0,
	EventKind.TAKE_DAMAGE: 1,
	EventKind.DODGE:       2,
	EventKind.LIGHT_HIT:   3,
	EventKind.HEAVY_HIT:   4,
	EventKind.JUTSU:       5,
	EventKind.FINISHER:    6,
}

## Provisional tunable values (DESIGN INTENT band noted per constant; tune in playtest).
## Zoom deltas are ADDITIVE to the CameraPreset baseline (positive = punch in, negative = pull back).
const LIGHT_ZOOM_DELTA   := 0.04   ## punch 2-5% in on a confirmed light hit
const LIGHT_DURATION_S   := 0.10   ## 80-130 ms
const HEAVY_ZOOM_DELTA   := 0.08   ## punch 5-10% in on a confirmed heavy hit
const HEAVY_DURATION_S   := 0.18   ## 140-220 ms
const DODGE_ZOOM_DELTA   := 0.03   ## slight emphasis on a dodge
const DODGE_DURATION_S   := 0.14   ## 100-180 ms
const JUTSU_ZOOM_DELTA   := 0.10   ## lead framing bias on jutsu
const JUTSU_DURATION_S   := 0.55   ## 400-700 ms
const FINISHER_ZOOM_DELTA := 0.18  ## punch-in for a finisher; 0.8-1.1 x on top of baseline
const FINISHER_HOLD_S    := 0.30   ## time held at peak before easing out (0.3-0.5 s)
const FINISHER_TOTAL_S   := 0.75   ## full finisher effect duration (0.5-1.0 s)
const DAMAGE_ZOOM_DELTA  := 0.025  ## very mild pull-back on taking damage
const DAMAGE_DURATION_S  := 0.22

const REDUCED_SCALE := 0.5
const QUERY_KEY := "camera_director"
const MODES: Array[String] = ["off", "reduced", "on"]

## Maximum additive zoom delta any event may produce (guard against compounding or extreme values).
const MAX_ZOOM_DELTA := 0.30
## Blend speed (fraction per second, exponential) for returning to baseline after an effect ends.
const BLEND_RETURN_SPEED := 8.0

## -------------------------------------------------------------------------  settings

class Settings extends RefCounted:
	var enabled: bool = true
	var zoom_scale: float  = 1.0  ## 0 = no zoom effects, 1 = full
	var shake_scale: float = 1.0  ## passed to CameraImpact.settings.scale when applied

	func effective_zoom() -> float:
		if not enabled:
			return 0.0
		return clampf(zoom_scale, 0.0, 1.0)

	func effective_shake() -> float:
		if not enabled:
			return 0.0
		return clampf(shake_scale, 0.0, 1.0)

static var settings: Settings = Settings.new()

## -------------------------------------------------------------------------  static API

static var _instance: CombatCameraDirector = null
static var event_count: int = 0

## Fire a combat camera event. Callable from any script without a node reference.
## `payload` keys depend on EventKind (see contract above); unknown keys are silently ignored.
static func notify(kind: EventKind, payload: Dictionary = {}) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	if settings.effective_zoom() <= 0.0:
		return
	_instance._handle_event(kind, payload)

## Reset to baseline immediately (e.g. on death, scene change, pause menu).
static func reset() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance._do_reset()

## Telemetry snapshot published each frame to window.__SHINOBI_STATE__.
static func telemetry() -> Dictionary:
	var active_kind := EventKind.NONE
	var zoom_delta := 0.0
	if _instance != null and is_instance_valid(_instance):
		active_kind = _instance._active_kind
		zoom_delta = _instance._zoom_delta
	return {
		"cam_dir_event": EventKind.keys()[active_kind],
		"cam_dir_priority": PRIORITY[active_kind],
		"cam_dir_zoom_delta": zoom_delta,
		"cam_dir_active": active_kind != EventKind.NONE,
		"cam_dir_event_count": event_count,
	}

## Boot-mode from URL query (mirrors CameraImpact pattern so both respect the same ?camera_director= param).
static func parse_query(query: String) -> String:
	for part in query.trim_prefix("?").split("&", false):
		var eq := part.find("=")
		var key := part if eq < 0 else part.substr(0, eq)
		if key.uri_decode() != QUERY_KEY:
			continue
		var value := "" if eq < 0 else part.substr(eq + 1).uri_decode().strip_edges().to_lower()
		return value if MODES.has(value) else "on"
	return ""

static func boot_mode(query: String, prefers_reduced_motion: bool) -> String:
	var url := parse_query(query)
	if url != "":
		return url
	return "reduced" if prefers_reduced_motion else "on"

static func apply_mode(mode: String) -> void:
	settings.enabled = mode != "off"
	var scale := REDUCED_SCALE if mode == "reduced" else 1.0
	settings.zoom_scale  = scale
	settings.shake_scale = scale

## -------------------------------------------------------------------------  instance state

## Active effect.
var _active_kind: EventKind = EventKind.NONE
var _effect_timer: float    = 0.0  ## seconds remaining in the active effect
var _effect_total: float    = 0.0  ## total duration of the active effect (for shape math)
var _zoom_delta: float      = 0.0  ## current additive zoom applied to the camera (world units per frame)
var _target_zoom_delta: float = 0.0  ## what we are easing toward (0 when returning to baseline)
var _peak_delta: float      = 0.0  ## peak delta for the current effect (before scale)

## Reference to the camera (resolved once, re-validated each frame).
var _camera: Camera2D = null

## -------------------------------------------------------------------------  Node lifecycle

func _ready() -> void:
	_instance = self
	set_process(true)

func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	_flush_zoom()

## Immediate reset to baseline -- called by the static reset() API.
func _do_reset() -> void:
	_active_kind = EventKind.NONE
	_target_zoom_delta = 0.0
	_zoom_delta = 0.0
	_flush_zoom()

## -------------------------------------------------------------------------  per-frame

func _process(delta: float) -> void:
	_camera = _resolve_camera()
	if _camera == null:
		return

	if _active_kind != EventKind.NONE:
		_effect_timer = maxf(_effect_timer - delta, 0.0)
		_target_zoom_delta = _compute_shape_delta()
		if _effect_timer <= 0.0:
			_active_kind = EventKind.NONE
			_target_zoom_delta = 0.0

	# Exponential blend toward target (smooth on entry and on return to baseline).
	_zoom_delta = lerpf(_zoom_delta, _target_zoom_delta, clampf(BLEND_RETURN_SPEED * delta, 0.0, 1.0))

	# Snap to zero once close enough to avoid float drift.
	if absf(_zoom_delta) < 0.0005 and _active_kind == EventKind.NONE:
		_zoom_delta = 0.0

	_apply_zoom()

## -------------------------------------------------------------------------  event handling

func _handle_event(kind: EventKind, payload: Dictionary) -> void:
	# Lower/equal-priority events do NOT interrupt an active higher-priority effect.
	if PRIORITY[kind] < PRIORITY[_active_kind]:
		return

	# Route CameraImpact calls (shake/offset) from here so a single notify() triggers both systems.
	_route_camera_impact(kind, payload)

	# Set up the new effect.
	_active_kind  = kind
	var dur       := _duration_for(kind)
	_effect_total = dur
	_effect_timer = dur
	_peak_delta   = _peak_for(kind) * settings.effective_zoom()
	_target_zoom_delta = _peak_delta

	event_count += 1
	_record_telemetry(kind)

## -------------------------------------------------------------------------  shape / duration helpers

func _duration_for(kind: EventKind) -> float:
	match kind:
		EventKind.LIGHT_HIT:  return LIGHT_DURATION_S
		EventKind.HEAVY_HIT:  return HEAVY_DURATION_S
		EventKind.DODGE:      return DODGE_DURATION_S
		EventKind.JUTSU:      return JUTSU_DURATION_S
		EventKind.FINISHER:   return FINISHER_TOTAL_S
		EventKind.TAKE_DAMAGE: return DAMAGE_DURATION_S
	return 0.0


func _peak_for(kind: EventKind) -> float:
	match kind:
		EventKind.LIGHT_HIT:   return LIGHT_ZOOM_DELTA
		EventKind.HEAVY_HIT:   return HEAVY_ZOOM_DELTA
		EventKind.DODGE:       return DODGE_ZOOM_DELTA
		EventKind.JUTSU:       return JUTSU_ZOOM_DELTA
		EventKind.FINISHER:    return FINISHER_ZOOM_DELTA
		EventKind.TAKE_DAMAGE: return DAMAGE_ZOOM_DELTA
	return 0.0


## Zoom-delta envelope for the active effect at the current timer state.
## Finisher: quick rise, hold at peak, ease out. Others: immediate peak, quadratic ease to zero.
func _compute_shape_delta() -> float:
	if _effect_total <= 0.0 or _peak_delta == 0.0:
		return 0.0
	var elapsed := _effect_total - _effect_timer
	var t := clampf(elapsed / _effect_total, 0.0, 1.0)  # 0 = just started, 1 = done

	if _active_kind == EventKind.FINISHER:
		# Rise in first tick, hold through HOLD fraction, then ease out.
		var hold_end := FINISHER_HOLD_S / _effect_total
		if t < (1.0 / 60.0) / _effect_total:
			return _peak_delta
		if t <= hold_end:
			return _peak_delta
		var out_t := (t - hold_end) / maxf(1.0 - hold_end, 0.001)
		return _peak_delta * (1.0 - out_t) * (1.0 - out_t)

	# Default: immediate peak, quadratic ease-out.
	var u := t  # 0..1
	return _peak_delta * (1.0 - u) * (1.0 - u)


## -------------------------------------------------------------------------  camera write

func _apply_zoom() -> void:
	if _camera == null:
		return
	# Read the current CameraPreset baseline each frame so we stay relative (user may cycle presets).
	var player := _get_player()
	var figure_px := WorldScale.BODY_HEIGHT
	if player != null and player.has_method("get") and "visual" in player:
		var vis = player.get("visual")
		if vis != null and vis.has_method("get") and "sprite_set" in vis:
			var ss = vis.get("sprite_set")
			if ss is SpriteSet and ss.is_valid() and ss.body_height_px > 0.0:
				figure_px = ss.body_height_px
	var baseline := CameraPreset.zoom_for(CameraPreset.active(), figure_px)
	var new_zoom := baseline + clampf(_zoom_delta, -MAX_ZOOM_DELTA, MAX_ZOOM_DELTA)
	new_zoom = clampf(new_zoom, CameraPreset.MIN_ZOOM, CameraPreset.MAX_ZOOM)
	_camera.zoom = Vector2.ONE * new_zoom


func _flush_zoom() -> void:
	## Return the camera immediately to its baseline (no animation) - used on exit/reset.
	var cam := _resolve_camera()
	if cam == null:
		return
	var baseline := CameraPreset.zoom_for(CameraPreset.active())
	cam.zoom = Vector2.ONE * baseline


## -------------------------------------------------------------------------  CameraImpact routing

func _route_camera_impact(kind: EventKind, payload: Dictionary) -> void:
	## For hit/damage events, also fire the existing CameraImpact shake/offset impulse so the two
	## systems work together (zoom from this director + positional shake from CameraImpact).
	var dir: Vector2 = payload.get("dir", Vector2.ZERO)
	match kind:
		EventKind.LIGHT_HIT:
			CameraImpact.settings.scale = settings.effective_shake()
			CameraImpact.light_hit(dir)
		EventKind.HEAVY_HIT:
			CameraImpact.settings.scale = settings.effective_shake()
			CameraImpact.heavy_hit(dir)
		EventKind.TAKE_DAMAGE:
			CameraImpact.settings.scale = settings.effective_shake()
			CameraImpact.light_hit(-dir)  ## recoil away from attacker


## -------------------------------------------------------------------------  camera / player resolution

func _resolve_camera() -> Camera2D:
	var player := _get_player()
	if player == null:
		return null
	if not ("camera" in player):
		return null
	var cam = player.get("camera")
	if not (cam is Camera2D) or not cam.is_inside_tree():
		return null
	return cam


func _get_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")


## -------------------------------------------------------------------------  telemetry

func _record_telemetry(kind: EventKind) -> void:
	## Publish a cam_dir event to DebugTelemetry if it is active.
	var dt := Engine.get_singleton("DebugTelemetry") if Engine.has_singleton("DebugTelemetry") else null
	if dt == null:
		return
	if not dt.get("enabled"):
		return
	var tele: Dictionary = telemetry()
	tele["event"] = "cam_dir_trigger"
	tele["kind"] = EventKind.keys()[kind]
	dt.record("camera", tele)
