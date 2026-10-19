extends Node
## Autoload DebugTelemetry: gameplay-side event producer (contract: docs/development/DEBUG_LOG_INTERFACE.md).
## Owner: Aki. Captures keyboard, gamepad, movement/state, interaction, combat, warning and error events.
## Reuses Kiro's DebugStore (scripts/web/debug_store.gd, class_name DebugStore) for the actual buffer so
## both sides share one throttle/coalesce/eviction implementation and merge cleanly by t_ms. This file
## only READS that class (instantiates it); it never edits scripts/web/**, per the interface contract.
##
## OFF by default (enabled = false). BrowserDebug flips this with `t.set("enabled", on)` when the user
## opts in (?debug=1 web query param, --debug-log native arg, or the F9 toggle) -- see browser_debug.gd.
## Recording a frame while disabled does nothing (DebugStore.record returns false immediately).
##
## WHAT THIS DOES NOT DO:
## - There is no global GDScript exception/error hook in Godot 4. Engine-internal errors that never
##   reach an explicit record_error()/record_warning() call, or a browser console line (BrowserDebug's
##   job), are not captured. This file never claims a complete crash dump.
## - Interaction and combat gameplay do not exist yet in this prototype (movement only; see
##   player_controller.gd: "Combat, jump, dodge etc. are reserved actions with no behavior yet.").
##   record_interaction() / record_combat() are implemented and tested end-to-end, ready for whoever
##   builds those systems (Orcha, per docs/development/DEBUG_LOG_INTERFACE.md Aki/Orcha split implied
##   by the order) to call. No gameplay behavior was invented here to produce fake traffic.
## - Mouse/pointer tracking is Kiro's (BrowserDebug.record_motion / browser UI); this file does not
##   duplicate it. The game itself has no mouse-driven mechanic yet.

signal event_recorded(event: Dictionary)

## Known axis bindings (project.godot [input], 2026-10-18). Used only to label raw axis motion with the
## resulting action name for readability; update this table if an axis is rebound. Falls back to "" (no
## guess) rather than ever being silently wrong, and nothing gameplay-relevant depends on it being right.
const AXIS_ACTION_MAP := {
	0: {"neg": "move_left", "pos": "move_right"},
	1: {"neg": "move_up", "pos": "move_down"},
	2: {"neg": "aim_left", "pos": "aim_right"},
	3: {"neg": "aim_up", "pos": "aim_down"},
	4: {"neg": "", "pos": "substitution"},
	5: {"neg": "", "pos": "jutsu_modifier"},
}
const DBG_ACTION_PREFIX := "dbg_"
const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var enabled: bool = false:
	set(value):
		if value == enabled:
			return
		enabled = value
		store.enabled = value
		if value:
			_sync_session()
			record("state", {"event": "telemetry_on"})
			_ensure_overlay()
		elif _overlay != null:
			_overlay.visible = false

var store: DebugStore = DebugStore.new()
var error_count: int = 0

## Test hook: replaces the session clock (milliseconds since session start).
var clock: Callable = Callable()
## Test hook: overlay scene path override.
var overlay_scene_path: String = "res://scenes/debug/debug_telemetry_overlay.tscn"

var _start_ticks: int = 0
var _overlay: CanvasLayer = null
var _player: PlayerController = null
var _action_names: Array = []


func _ready() -> void:
	_start_ticks = Time.get_ticks_msec()
	store.configure("", _local_build_info(), {}, Time.get_unix_time_from_system())
	_action_names = InputMap.get_actions().filter(func(a: String) -> bool: return not String(a).begins_with("ui_"))
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	set_process_input(true)
	set_process(true)


func now_ms() -> int:
	if clock.is_valid():
		return int(clock.call())
	return Time.get_ticks_msec() - _start_ticks


# ------------------------------------------------------------------ core record API (DEBUG_LOG_INTERFACE.md)
func record(type: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	store.set_frame(Engine.get_process_frames())
	_after(store.record(type, data, now_ms()), type)


func recent(n: int) -> Array:
	return store.recent(n)


func export_jsonl() -> String:
	return store.export_jsonl(now_ms())


# ------------------------------------------------------------------ typed helpers (Aki producers)
## Axis input only recorded on meaningful change (DebugStore's own deadzone/delta/sign-flip rule).
func record_axis(key: String, value: float, extra: Dictionary = {}) -> void:
	if not enabled:
		return
	store.set_frame(Engine.get_process_frames())
	_after(store.record_axis(key, value, extra, now_ms()), "input")


func record_interaction(target_id: String, target_type: String, accepted: bool, reason: String = "", extra: Dictionary = {}) -> void:
	var d := extra.duplicate()
	d["target_id"] = target_id
	d["target_type"] = target_type
	d["accepted"] = accepted
	d["reason"] = reason
	d["player"] = _player_snapshot()
	record("interaction", d)


func record_combat(action: String, data: Dictionary = {}) -> void:
	var d := data.duplicate()
	d["action"] = action
	d["player"] = _player_snapshot()
	record("combat", d)


func record_warning(category: String, message: String, extra: Dictionary = {}) -> void:
	var d := extra.duplicate()
	d["category"] = category
	d["message"] = message
	record("warning", d)


## category: free text (e.g. "script", "resource", "collision", "animation", "gameplay").
## See the class doc comment: this is explicit-call capture, not a global engine error hook.
func record_error(category: String, message: String, extra: Dictionary = {}) -> void:
	var d := extra.duplicate()
	d["category"] = category
	d["message"] = message
	d["last_action"] = String(d.get("last_action", _last_action))
	record("error", d)


## Deliberately safe, deterministic failure for acceptance testing (Ctrl+Alt+X while telemetry is enabled).
## Divides by zero is caught before it reaches GDScript's own runtime error, so this never actually
## crashes or produces an uncaught engine error -- the whole point is to prove the ERROR record path
## without making the game (or the test run) actually fail. This is the same limitation documented in
## DEBUG_TELEMETRY_SPEC.md: GDScript has no global exception hook, so real unhandled errors are only
## visible to the degree they reach the console (Kiro's browser_error path) or an explicit record_error.
func force_test_error() -> void:
	var zero := 0
	if zero == 0:
		record_error("test", "forced test error (Ctrl+Alt+X): simulated divide-by-zero, caught on purpose", {"scene": _current_scene_name()})
	else:
		record_error("test", str(1 / zero), {})


# ------------------------------------------------------------------ input capture (keyboard + gamepad)
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey:
		_on_key(event as InputEventKey)
	elif event is InputEventJoypadButton:
		_on_joy_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_on_joy_motion(event as InputEventJoypadMotion)


## Press/release only (per contract). physical_keycode/keycode are hardware identifiers, never a typed
## character: `.unicode` / `.as_text()` are intentionally never read here, so no typed text or IME
## composition output can reach the log.
func _on_key(e: InputEventKey) -> void:
	if e.echo:
		return
	var action := _resolve_action(e)
	_last_input_desc = "key %s %s" % [OS.get_keycode_string(e.physical_keycode), "down" if e.pressed else "up"]
	if action != "" and not action.begins_with(DBG_ACTION_PREFIX):
		_last_action = action
	var d := {"device": "keyboard", "action": action, "raw": {"physical_keycode": e.physical_keycode, "keycode": e.keycode, "pressed": e.pressed}}
	if action != "" and not action.begins_with(DBG_ACTION_PREFIX) and e.pressed:
		d["player"] = _player_snapshot()
	record("input", d)


func _on_joy_button(e: InputEventJoypadButton) -> void:
	var action := _resolve_action(e)
	_last_input_desc = "gamepad:%d button %d %s" % [e.device, e.button_index, "down" if e.pressed else "up"]
	if action != "" and not action.begins_with(DBG_ACTION_PREFIX):
		_last_action = action
	var d := {"device": "gamepad:%d" % e.device, "action": action, "raw": {"button_index": e.button_index, "pressure": e.pressure, "pressed": e.pressed}}
	if action != "" and not action.begins_with(DBG_ACTION_PREFIX) and e.pressed:
		d["player"] = _player_snapshot()
	record("input", d)


func _on_joy_motion(e: InputEventJoypadMotion) -> void:
	var key := "gp%d:axis%d" % [e.device, e.axis]
	var action := _axis_action(e.axis, e.axis_value)
	record_axis(key, e.axis_value, {"device": "gamepad:%d" % e.device, "action": action})


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	record("input", {"device": "gamepad:%d" % device, "raw": {"event": "connected" if connected else "disconnected", "name": Input.get_joy_name(device)}})


func _axis_action(axis: int, value: float) -> String:
	var row: Dictionary = AXIS_ACTION_MAP.get(axis, {})
	if row.is_empty():
		return ""
	return String(row.get("pos", "")) if value > 0.0 else String(row.get("neg", ""))


## First action matching this exact event (ignoring Aki's own dbg_* meta actions is NOT done here --
## they are still reported as the resolved action; callers filter DBG_ACTION_PREFIX if they want the
## gameplay-only view). Returns "" when no action binds this event (e.g. an unmapped key).
func _resolve_action(event: InputEvent) -> String:
	for a: String in _action_names:
		if event.is_action(a, true):
			return a
	return ""


# ------------------------------------------------------------------ movement / state
func _process(_delta: float) -> void:
	if _player == null and is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player != null and not _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.connect(_on_player_state_changed)


func _on_player_state_changed(_new_state: PlayerController.State) -> void:
	record("state", {"event": "state_changed", "player": _player_snapshot()})


func player_snapshot() -> Dictionary:
	return _player_snapshot()


func _player_snapshot() -> Dictionary:
	if _player == null and is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		return {}
	return {
		"x": roundf(_player.global_position.x),
		"y": roundf(_player.global_position.y),
		"state": _player.get_state_name(),
		"facing": _compass(_player.facing8),
	}


static func _compass(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return ""
	var idx := int(roundf(wrapf(dir.angle(), 0.0, TAU) / (TAU / 8.0))) % 8
	return COMPASS[idx]


func _current_scene_name() -> String:
	if not is_inside_tree():
		return ""
	var scene := get_tree().current_scene
	return scene.name if scene != null else ""


# ------------------------------------------------------------------ internals
var _last_input_desc: String = ""
var _last_action: String = ""


func _after(ok: bool, type: String) -> void:
	if not ok:
		return
	if type == "error":
		error_count += 1
	var evs := store.recent(1)
	if evs.size() > 0:
		event_recorded.emit(evs[0])


func _sync_session() -> void:
	var bd: Node = get_node_or_null("/root/BrowserDebug") if is_inside_tree() else null
	var build := _local_build_info()
	var session := ""
	if bd != null:
		session = String(bd.get("session_id"))
		var bd_store: DebugStore = bd.get("store")
		if bd_store != null and not bd_store.build.is_empty():
			build = bd_store.build.duplicate(true)
	if session == "":
		session = Crypto.new().generate_random_bytes(6).hex_encode()
	store.configure(session, build, {}, Time.get_unix_time_from_system())


func _local_build_info() -> Dictionary:
	if FileAccess.file_exists("res://build-info.json"):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build-info.json"))
		if j is Dictionary:
			return {"commit_sha": str(j.get("commit_sha", "")), "run_id": str(j.get("run_id", "")), "godot": str(j.get("godot_version", ""))}
	return {"commit_sha": "", "run_id": "", "godot": Engine.get_version_info().get("string", "")}


func _ensure_overlay() -> void:
	if _overlay != null or not is_inside_tree():
		return
	var scene: PackedScene = load(overlay_scene_path)
	if scene == null:
		return
	_overlay = scene.instantiate()
	add_child.call_deferred(_overlay)
