class_name CameraImpact
extends Node
## Procedural camera kick for confirmed hits (combat camera feedback order). CAMERA ONLY: it writes Camera2D.offset and
## nothing else (no position, smoothing, limits, zoom or preset). Nothing calls it in normal play, so by default nothing moves.
##
## Contract:
##  1. Call ONCE per CONFIRMED contact, right after the hit is accepted (never per active frame):
##     CameraImpact.light_hit(dir) / heavy_hit(dir) / impulse(dir, peak_px, duration_ms).
##     dir = world direction attacker -> target (any length; ZERO = no direction = counted but no offset). The camera is
##     pushed along dir (KICK_SIGN) and eases back.
##  2. Peak and duration are SCREEN px and ms. Camera2D.offset is in WORLD px (before zoom), so the module converts with the
##     CURRENT zoom. Godot 4.7.2 adds the offset AFTER smoothing and AFTER the limit clamp (measured), so the module clamps it
##     itself: the view never leaves the camera limits (a kick toward a wall shrinks to the room that is left). The clamp is
##     repeated from the centre the engine reports AFTER the write, because writing the offset advances the camera smoothing once
##     more for the rendered frame; without that a MOVING camera showed void as it glided into a wall.
##  3. Everything is a pure function of the time since each impulse started: no integration, no drift, no randomness, any
##     frame rate. The effect ends at EXACTLY Vector2.ZERO and the zoom is never touched, so it stays on the preset baseline.
##  4. Several impulses combine with a cap (MAX_TOTAL_PX): same-direction hits do not add linearly, opposite hits cancel.
##  5. No player/camera, tree not ready, disabled (settings.enabled = false) or scale 0: the call is a silent no-op.
##
## Runtime: the first call creates ONE small helper Node ("CameraImpact") under the player's Camera2D (found through the
## `player` group), so no scene or controller needs an edit. It runs on frame time, also during pause and local hitstop.
## Tunables are PROVISIONAL starting values (order bands in the comments); tune them in a playtest.

const NODE_NAME := "CameraImpact"
const LIGHT_PEAK_PX := 2.5  ## PROVISIONAL: order band 2-3 screen px
const LIGHT_MS := 80.0  ## PROVISIONAL: order band 60-100 ms
const HEAVY_PEAK_PX := 5.0  ## PROVISIONAL: order band 4-6 screen px
const HEAVY_MS := 120.0  ## PROVISIONAL: order band 100-140 ms
const SLOW_MS := 1500.0  ## demo only (lab key 0): the heavy kick stretched so it can be watched and screenshotted
const MAX_TOTAL_PX := 6.0  ## PROVISIONAL: cap on the combined offset, the top of the heavy band
const KICK_SIGN := 1.0  ## PROVISIONAL: +1 pushes the camera toward the target, -1 recoils away from it
const RISE_S := 1.0 / 60.0  ## the kick reaches its peak within one 60 Hz tick
const MAX_MS := 5000.0  ## longest accepted impulse
const MAX_ACTIVE := 8  ## impulses alive at once; the oldest is dropped
const TICK_S := 1.0 / 60.0  ## telemetry samples the trace at this step, whatever the frame rate
const MAX_FRAME_S := 1.0  ## a longer frame (background tab) advances the clock by at most this
const REDUCED_SCALE := 0.5
const QUERY_KEY := "camera_impact"
const MODES: Array[String] = ["off", "reduced", "on"]


## User-facing switches. `scale` 1 = full, 0.5 = "reduced", 0 = off; it can only soften the effect (clamped to 0..1).
class Settings extends RefCounted:
	var enabled: bool = true
	var scale: float = 1.0

	## The multiplier actually applied: 0 when disabled or not a finite number.
	func effective() -> float:
		if not enabled or not is_finite(scale):
			return 0.0
		return clampf(scale, 0.0, 1.0)


static var settings: Settings = Settings.new()
static var count: int = 0  ## impulses accepted since boot (telemetry cfx_count)
static var peak_px: float = 0.0  ## largest |offset| in screen px of the current or last effect (telemetry cfx_peak_px)
static var _shown: Vector2 = Vector2.ZERO  ## offset last applied, screen px
static var _live: bool = false  ## an impulse is still running

var camera: Camera2D
var auto_advance: bool = true  ## tests set false and call advance() with a fixed step
var _clock: float = 0.0
var _list: Array[Dictionary] = []  ## live impulses: {dir: unit Vector2, peak: px, dur: s, t0: clock}


# ---------------------------------------------------------------- public API (static: one line for the caller)

static func light_hit(dir: Vector2) -> void:
	impulse(dir, LIGHT_PEAK_PX, LIGHT_MS)


static func heavy_hit(dir: Vector2) -> void:
	impulse(dir, HEAVY_PEAK_PX, HEAVY_MS)


## Custom kick: `peak_px` screen px, `duration_ms` ms (clamped to MAX_MS). Non-finite, zero or negative values are ignored.
static func impulse(dir: Vector2, peak: float, duration_ms: float) -> void:
	if settings.effective() <= 0.0 or not (is_finite(peak) and is_finite(duration_ms)):
		return
	var dur := minf(duration_ms, MAX_MS) / 1000.0
	if peak <= 0.0 or dur <= 0.0:
		return
	var cam := _player_camera()
	if cam == null:
		return
	var runner := runner_for(cam, true)
	if runner != null:
		runner.push(dir, peak, dur)


## The helper under `cam` (created on demand when `create`).
static func runner_for(cam: Camera2D, create: bool = false) -> CameraImpact:
	var runner := cam.get_node_or_null(NODE_NAME) as CameraImpact
	if runner == null and create and cam.is_inside_tree():
		runner = CameraImpact.new()
		runner.name = NODE_NAME
		runner.camera = cam
		cam.add_child(runner)
	return runner


## Numbers published in window.__SHINOBI_STATE__ (offset in screen px).
static func telemetry() -> Dictionary:
	return {
		"cfx_enabled": settings.enabled, "cfx_scale": settings.scale, "cfx_active": _live,
		"cfx_offset_x": _shown.x, "cfx_offset_y": _shown.y, "cfx_peak_px": peak_px, "cfx_count": count,
	}


## Back to the boot state: default settings, counters and mirrors cleared (tests).
static func reset_all() -> void:
	settings = Settings.new()
	count = 0
	peak_px = 0.0
	_shown = Vector2.ZERO
	_live = false


# ---------------------------------------------------------------- pure functions

## Offset magnitude (screen px) `t` seconds after an impulse started: a linear rise to EXACTLY `peak` within one tick, then a
## quadratic ease-out that is EXACTLY 0 at `duration_s` (zero slope there). 0 before the start and from the end on.
static func offset_at(t: float, peak: float, duration_s: float) -> float:
	if not (is_finite(t) and is_finite(peak) and is_finite(duration_s)):
		return 0.0
	if peak <= 0.0 or duration_s <= 0.0 or t <= 0.0 or t >= duration_s:
		return 0.0
	var rise := minf(RISE_S, duration_s * 0.5)
	if t < rise:
		return peak * t / rise
	var u := (t - rise) / (duration_s - rise)
	return peak * (1.0 - u) * (1.0 - u)


## Several impulse vectors (unit direction x current magnitude, screen px) -> one offset: the magnitude-weighted mean direction
## times the root-sum-square of the magnitudes (sub-linear: same-direction hits do not add up, opposite hits cancel, one hit
## is exact), never longer than MAX_TOTAL_PX.
static func combine(vectors: Array) -> Vector2:
	var sum := Vector2.ZERO
	var total := 0.0
	var squares := 0.0
	for v: Vector2 in vectors:
		var m := v.length()
		sum += v
		total += m
		squares += m * m
	if total <= 0.0:
		return Vector2.ZERO
	return (sum * (sqrt(squares) / total)).limit_length(MAX_TOTAL_PX)


## Combined offset (screen px, before `scale` and the edge clamp) of `list` at time `clock`. Items: dir, peak, dur, t0.
static func sample(list: Array, clock: float) -> Vector2:
	var parts: Array = []
	for item: Dictionary in list:
		var d: Vector2 = item["dir"]
		parts.append(d * offset_at(clock - float(item["t0"]), float(item["peak"]), float(item["dur"])))
	return combine(parts)


## Screen px -> world px at `zoom` (Camera2D.offset is world px). ZERO for a zoom that is not a positive finite number.
static func to_world(screen: Vector2, zoom: float) -> Vector2:
	if not is_finite(zoom) or zoom <= 0.0:
		return Vector2.ZERO
	return screen / zoom


## Keep the view inside the camera limits. All in world px: `center` and `half` are the OFFSET-FREE view centre and half size,
## `lim` the limit rect. Each axis is clamped into [limit_min - view_min, limit_max - view_max], but the range always contains 0:
## the offset is only ever shrunk toward 0, never pushed away from it (a view larger than the limits gets no offset).
static func clamp_to_limits(offset: Vector2, center: Vector2, half: Vector2, lim: Rect2) -> Vector2:
	var lo := Vector2(minf(lim.position.x - (center.x - half.x), 0.0), minf(lim.position.y - (center.y - half.y), 0.0))
	var hi := Vector2(maxf(lim.end.x - (center.x + half.x), 0.0), maxf(lim.end.y - (center.y + half.y), 0.0))
	return offset.clamp(lo, hi)


## "?a=1&camera_impact=reduced" -> "off" | "reduced" | "on". "" when the parameter is absent. The first occurrence wins
## (like URLSearchParams.get); an unknown or empty value is "on".
static func parse_query(query: String) -> String:
	for part in query.trim_prefix("?").split("&", false):
		var eq := part.find("=")
		var key := part if eq < 0 else part.substr(0, eq)
		if key.uri_decode() != QUERY_KEY:
			continue
		var value := "" if eq < 0 else part.substr(eq + 1).uri_decode().strip_edges().to_lower()
		return value if MODES.has(value) else "on"
	return ""


## The mode to start in: the URL wins; without the parameter "reduced" when the browser asks for reduced motion, else "on".
static func boot_mode(query: String, prefers_reduced_motion: bool) -> String:
	var url := parse_query(query)
	if url != "":
		return url
	return "reduced" if prefers_reduced_motion else "on"


static func apply_mode(mode: String) -> void:
	settings.enabled = mode != "off"
	settings.scale = REDUCED_SCALE if mode == "reduced" else 1.0


static func _player_camera() -> Camera2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var player := tree.get_first_node_in_group("player") as PlayerController
	if player == null or not is_instance_valid(player.camera) or not player.camera.is_inside_tree():
		return null
	return player.camera


# ---------------------------------------------------------------- helper node

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # a pause must not freeze a kick half way
	set_process(false)  # only runs while an impulse is alive


func _exit_tree() -> void:
	_list.clear()
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
	_shown = Vector2.ZERO
	_live = false


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


## Start one impulse now (dir is normalised here; a zero direction is accepted and moves nothing).
func push(dir: Vector2, peak: float, dur: float) -> void:
	if _list.is_empty():
		peak_px = 0.0  # a new effect starts: the telemetry peak is per effect
	var unit := dir.normalized() * KICK_SIGN if dir.is_finite() else Vector2.ZERO
	_list.append({"dir": unit, "peak": peak, "dur": dur, "t0": _clock})
	if _list.size() > MAX_ACTIVE:
		_list.pop_front()
	count += 1
	_live = true
	set_process(auto_advance)


## Advance the effect clock by `delta` seconds and apply the result. Long frames are evaluated in TICK_S sub-steps, so the
## telemetry peak is the same at 5 FPS in a browser as at 60 FPS (the camera shows the value at the end of the frame).
func advance(delta: float) -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not (camera.zoom.x > 0.0):
		return
	if settings.effective() <= 0.0:
		_list.clear()  # disabled or scale 0 mid-effect: stop at once
	var zoom := camera.zoom.x
	var half := camera.get_viewport().get_visible_rect().size / zoom * 0.5
	var center := camera.get_screen_center_position() - camera.offset  # the view centre without our offset
	var lim := Rect2(-1.0e9, -1.0e9, 2.0e9, 2.0e9)
	if camera.limit_enabled:
		lim = Rect2(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	var left := clampf(delta, 0.0, MAX_FRAME_S) if is_finite(delta) else 0.0
	var raw := Vector2.ZERO  # offset of the last sub-step before the edge clamp, world px
	var world := Vector2.ZERO  # the same after the clamp: what is written to the camera
	var peak_before := peak_px  # telemetry peak up to the sub-step before the last one
	while true:
		var step := minf(left, TICK_S)
		_clock += step
		left -= step
		raw = sample(_list, _clock) * settings.effective() / zoom
		world = clamp_to_limits(raw, center, half, lim)
		peak_before = peak_px
		peak_px = maxf(peak_px, (world * zoom).length())
		_drop_finished()
		if left <= 1.0e-6:
			break
	camera.offset = world  # exactly ZERO once the last impulse is over
	if camera.limit_enabled:
		# Writing the offset makes Camera2D run its camera update once more (set_offset -> _update_scroll -> get_camera_transform,
		# which advances the position smoothing one extra step for the rendered view and then restores the smoothing state; the
		# engine has a FIXME about it). On a MOVING camera the view is thus one frame of travel closer to a wall than the centre
		# read above and the first clamp over-estimates the room. Clamp again from the centre the engine reports now; writing the
		# corrected value repeats the same update, so this second pass is exact.
		var fixed := clamp_to_limits(raw, camera.get_screen_center_position() - camera.offset, half, lim)
		if fixed != world:
			world = fixed
			camera.offset = world
			peak_px = maxf(peak_before, (world * zoom).length())  # the peak of what was finally written, not of the first pass
	_shown = world * zoom
	_live = not _list.is_empty()
	if not _live:
		set_process(false)


func _drop_finished() -> void:
	var kept: Array[Dictionary] = []
	for item in _list:
		if _clock - float(item["t0"]) < float(item["dur"]):
			kept.append(item)
	_list = kept
