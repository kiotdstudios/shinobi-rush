extends RefCounted
## Unit tests for the DebugTelemetry autoload (Aki's gameplay event producer).
## Contract: docs/development/DEBUG_LOG_INTERFACE.md. Called from tests/run_tests.gd.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_autoload_registered(tree_root)
	test_input_actions_no_collision(tree_root)
	test_disabled_records_nothing()
	test_enabled_basic_record()
	test_enabled_toggle_syncs_session_and_emits_signal()
	test_keyboard_never_records_typed_text()
	test_keyboard_action_resolution()
	test_gamepad_button_and_connection()
	test_gamepad_axis_throttling_matches_debug_store()
	test_interaction_shape()
	test_combat_shape()
	test_warning_and_error_shape()
	test_force_test_error()
	test_export_jsonl_roundtrip()
	test_player_snapshot_without_player()
	test_overlay_instantiates()


func _dt() -> Node:
	var dt: Node = load("res://scripts/debug/debug_telemetry.gd").new()
	var t := 0
	dt.clock = func() -> int: return t
	dt._ready()  # not added to the tree in these unit tests; call it directly so _action_names is built
	return dt


func test_autoload_registered(root: Node) -> void:
	var dt := root.get_node_or_null("DebugTelemetry")
	ck.call("dt: autoload present", dt != null)
	ck.call("dt: autoload OFF by default (headless)", dt != null and dt.enabled == false)


func test_input_actions_no_collision(_root: Node) -> void:
	var ours := ["dbg_toggle_telemetry_hud", "dbg_telemetry_filter_cycle", "dbg_telemetry_verbosity_cycle", "dbg_force_test_error"]
	for a: String in ours:
		ck.call("dt: input %s exists" % a, InputMap.has_action(a))
	var clash := false
	for a: String in InputMap.get_actions():
		if a in ours:
			continue
		for e in InputMap.action_get_events(a):
			for o: String in ours:
				for oe in InputMap.action_get_events(o):
					if e is InputEventKey and oe is InputEventKey and e.physical_keycode == oe.physical_keycode:
						clash = true
	ck.call("dt: new actions do not reuse any existing key", not clash)


func test_disabled_records_nothing() -> void:
	var dt := _dt()
	dt.record("state", {"x": 1})
	dt.record_warning("cat", "msg")
	dt.record_error("cat", "msg")
	ck.call("dt: disabled records nothing", dt.recent(10).is_empty() and dt.error_count == 0)
	dt.free()


func test_enabled_basic_record() -> void:
	var dt := _dt()
	dt.enabled = true
	dt.record("state", {"event": "custom"})
	var evs: Array = dt.recent(5)
	ck.call("dt: enabling itself logs a telemetry_on state event", evs.size() >= 1 and evs[0]["type"] == "state" and evs[0]["event"] == "telemetry_on")
	ck.call("dt: subsequent record is stored", evs.size() == 2 and evs[1]["event"] == "custom")
	dt.free()


func test_enabled_toggle_syncs_session_and_emits_signal() -> void:
	var dt := _dt()
	var got: Array = []
	dt.event_recorded.connect(func(e: Dictionary) -> void: got.append(e))
	dt.enabled = true
	ck.call("dt: event_recorded fires on enable", got.size() == 1 and got[0]["event"] == "telemetry_on")
	dt.record("input", {"device": "keyboard"})
	ck.call("dt: event_recorded fires on record", got.size() == 2 and got[1]["device"] == "keyboard")
	ck.call("dt: session id assigned on enable", String(dt.store.session) != "")
	dt.enabled = false
	dt.enabled = false  # no-op re-set must not duplicate work / emit again
	ck.call("dt: re-setting same value is a no-op (no duplicate telemetry_on)", got.size() == 2)
	dt.free()


func test_keyboard_never_records_typed_text() -> void:
	var dt := _dt()
	dt.enabled = true
	var e := InputEventKey.new()
	e.physical_keycode = KEY_A
	e.keycode = KEY_A
	e.unicode = 97  # 'a' -- must never leak into the recorded event
	e.pressed = true
	dt._on_key(e)
	var last: Dictionary = dt.recent(1)[0]
	var as_text := JSON.stringify(last)
	ck.call("dt: keyboard event has no 'unicode' key", not last.has("unicode") and not (last.get("raw", {}) as Dictionary).has("unicode"))
	ck.call("dt: keyboard event JSON does not contain typed character payload", not as_text.contains("\"text\""))
	dt.free()


func test_keyboard_action_resolution() -> void:
	var dt := _dt()
	dt.enabled = true
	var move_right_events: Array = InputMap.action_get_events("move_right")
	if move_right_events.is_empty():
		ck.call("dt: move_right has a bound key (skipped, none found)", true)
		return
	var bound: InputEventKey = null
	for ev in move_right_events:
		if ev is InputEventKey:
			bound = ev
			break
	if bound == null:
		ck.call("dt: move_right has a bound key (skipped, none found)", true)
		return
	var e := InputEventKey.new()
	e.physical_keycode = bound.physical_keycode
	e.pressed = true
	dt._on_key(e)
	var last: Dictionary = dt.recent(1)[0]
	ck.call("dt: known key resolves to its mapped action", last["action"] == "move_right", str(last))
	ck.call("dt: resolved action press carries a player snapshot key", last.has("player"))
	dt.free()


func test_gamepad_button_and_connection() -> void:
	var dt := _dt()
	dt.enabled = true
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	dt._on_joy_button(e)
	var last: Dictionary = dt.recent(1)[0]
	ck.call("dt: gamepad button event device-tagged", String(last["device"]) == "gamepad:0")
	ck.call("dt: gamepad button raw has button_index", (last["raw"] as Dictionary)["button_index"] == JOY_BUTTON_A)

	dt._on_joy_connection_changed(0, true)
	var conn: Dictionary = dt.recent(1)[0]
	ck.call("dt: joy connection event recorded", (conn["raw"] as Dictionary)["event"] == "connected")
	dt.free()


func test_gamepad_axis_throttling_matches_debug_store() -> void:
	var dt := _dt()
	dt.enabled = true
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = 0
	e.axis_value = 0.02  # below AXIS_DEADZONE (0.05) -> should not register as a change
	dt._on_joy_motion(e)
	var before: int = dt.recent(10).size()
	e.axis_value = 0.03
	dt._on_joy_motion(e)
	ck.call("dt: sub-deadzone axis jitter produces no new event", dt.recent(10).size() == before)

	e.axis_value = 0.6
	dt._on_joy_motion(e)
	var last: Dictionary = dt.recent(1)[0]
	ck.call("dt: axis motion past deadzone+delta is recorded as input", last["type"] == "input" and last["control"] == "gp0:axis0")
	ck.call("dt: axis action label resolves via AXIS_ACTION_MAP", last["action"] == "move_right")
	dt.free()


func test_interaction_shape() -> void:
	var dt := _dt()
	dt.enabled = true
	dt.record_interaction("npc_42", "npc", true, "", {"zone": "village"})
	var last: Dictionary = dt.recent(1)[0]
	ck.call("dt: interaction type", last["type"] == "interaction")
	ck.call("dt: interaction fields", last["target_id"] == "npc_42" and last["target_type"] == "npc" and last["accepted"] == true)
	ck.call("dt: interaction carries player snapshot key", last.has("player"))
	ck.call("dt: interaction keeps extra data", last["zone"] == "village")
	dt.free()


func test_combat_shape() -> void:
	var dt := _dt()
	dt.enabled = true
	dt.record_combat("attack_light", {"target": "enemy_1", "damage": 5})
	var last: Dictionary = dt.recent(1)[0]
	ck.call("dt: combat type", last["type"] == "combat")
	ck.call("dt: combat fields", last["action"] == "attack_light" and last["target"] == "enemy_1" and last["damage"] == 5)
	ck.call("dt: combat carries player snapshot key", last.has("player"))
	dt.free()


func test_warning_and_error_shape() -> void:
	var dt := _dt()
	dt.enabled = true
	dt.record_warning("resource", "texture missing", {"path": "res://x.png"})
	var w: Dictionary = dt.recent(1)[0]
	ck.call("dt: warning type+fields", w["type"] == "warning" and w["category"] == "resource" and w["message"] == "texture missing")

	dt.record_error("script", "divide by zero")
	var e: Dictionary = dt.recent(1)[0]
	ck.call("dt: error type+fields", e["type"] == "error" and e["category"] == "script" and e["message"] == "divide by zero")
	ck.call("dt: error_count increments on record_error", dt.error_count == 1)
	ck.call("dt: warning does not increment error_count", dt.error_count == 1)
	dt.free()


func test_force_test_error() -> void:
	var dt := _dt()
	dt.enabled = true
	var before: int = dt.error_count
	dt.force_test_error()
	var evs: Array = dt.recent(5)
	var err_events := evs.filter(func(e: Dictionary) -> bool: return e["type"] == "error")
	ck.call("dt: force_test_error produces exactly one error event", err_events.size() == 1)
	ck.call("dt: force_test_error increments error_count by exactly 1", dt.error_count == before + 1)
	ck.call("dt: force_test_error is tagged category test", err_events[0]["category"] == "test")
	dt.free()


func test_export_jsonl_roundtrip() -> void:
	var dt := _dt()
	dt.enabled = true
	dt.record("state", {"event": "x"})
	var jsonl: String = dt.export_jsonl()
	var lines: PackedStringArray = jsonl.strip_edges().split("\n")
	ck.call("dt: export_jsonl header + events", lines.size() >= 3)
	var header: Dictionary = JSON.parse_string(lines[0])
	ck.call("dt: export_jsonl first line is a session_header", header.get("type", "") == "session_header")
	var mid: Dictionary = JSON.parse_string(lines[1])
	ck.call("dt: export_jsonl event lines parse as dictionaries", mid.has("type"))
	dt.free()


func test_player_snapshot_without_player() -> void:
	var dt := _dt()
	ck.call("dt: player_snapshot is empty dict with no player in tree", dt.player_snapshot().is_empty())
	dt.free()


func test_overlay_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/debug/debug_telemetry_overlay.tscn")
	ck.call("dt: overlay scene loads", scene != null)
	var inst: Node = scene.instantiate()
	ck.call("dt: overlay scene instantiates without error", inst != null)
	if inst != null:
		inst.free()
