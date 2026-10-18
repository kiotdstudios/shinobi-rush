extends RefCounted
## Unit tests for the BrowserDebug autoload logic (no browser needed). Called from tests/run_tests.gd.

var ck: Callable
var _t: int = 0


class FakeTelemetry:
	extends Node
	var enabled: bool = false
	var events: Array = []

	func recent(n: int) -> Array:
		return events.slice(maxi(0, events.size() - n))


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_decide_enabled()
	test_collect_env()
	test_input_actions(tree_root)
	test_autoload_registered(tree_root)
	test_disabled_records_nothing()
	test_enabled_browser_error()
	test_session_metadata()
	test_without_telemetry()
	test_merge_with_fake_telemetry()
	test_toggle_propagates_to_telemetry()
	test_report_and_filename()
	test_no_network_or_storage_in_source()


func _bd() -> Node:
	var bd: Node = load("res://scripts/web/browser_debug.gd").new()
	_t = 0
	bd.clock = func() -> int: return _t
	bd.init_session({"userAgent": "UA", "platform": "P"}, {"commit_sha": "abcdef1234567", "run_id": "9"})
	return bd


func test_decide_enabled() -> void:
	var B := load("res://scripts/web/browser_debug.gd")
	ck.call("bd: web default OFF", not B.decide_enabled(true, "", PackedStringArray()))
	ck.call("bd: web ?debug=1 ON", B.decide_enabled(true, "?debug=1", PackedStringArray()))
	ck.call("bd: web ?a=b&debug=1 ON", B.decide_enabled(true, "?a=b&debug=1", PackedStringArray()))
	ck.call("bd: web ?debug=0 OFF", not B.decide_enabled(true, "?debug=0", PackedStringArray()))
	ck.call("bd: web ?debug=10 OFF", not B.decide_enabled(true, "?debug=10", PackedStringArray()))
	ck.call("bd: native default OFF", not B.decide_enabled(false, "", PackedStringArray()))
	ck.call("bd: native --debug-log ON", B.decide_enabled(false, "", PackedStringArray(["--debug-log"])))
	ck.call("bd: native ignores URL flag", not B.decide_enabled(false, "?debug=1", PackedStringArray()))


func test_collect_env() -> void:
	var B := load("res://scripts/web/browser_debug.gd")
	var env: Dictionary = B.collect_env({"userAgent": "U", "platform": "W", "language": "en", "screen": {"width": 1}, "devicePixelRatio": 2, "gamepads": ["pad"], "hardwareConcurrency": 8, "secret": "x", "search": "?token=1"})
	ck.call("bd: env keeps documented keys", env.size() == 7 and env["gamepads"] == ["pad"] and env["hardwareConcurrency"] == 8)
	ck.call("bd: env drops other keys", not env.has("secret") and not env.has("search"))


func test_input_actions(_root: Node) -> void:
	for a: String in ["dbg_toggle_debug", "dbg_download_log", "dbg_copy_report"]:
		ck.call("bd: input %s exists" % a, InputMap.has_action(a))
	var used := {}
	var collide := false
	for a: String in InputMap.get_actions():
		if not a.begins_with("dbg_"):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				var k: int = e.physical_keycode
				if used.has(k) and used[k] != a:
					collide = true
				used[k] = a
	ck.call("bd: dbg_* keys do not collide with each other", not collide)
	var ours := ["dbg_toggle_debug", "dbg_download_log", "dbg_copy_report"]
	var clash := false
	for a: String in InputMap.get_actions():
		if a in ours:
			continue
		for e in InputMap.action_get_events(a):
			for o: String in ours:
				for oe in InputMap.action_get_events(o):
					if e is InputEventKey and oe is InputEventKey and e.physical_keycode == oe.physical_keycode:
						clash = true
	ck.call("bd: new actions do not reuse any existing key", not clash)


func test_autoload_registered(root: Node) -> void:
	var bd := root.get_node_or_null("BrowserDebug")
	ck.call("bd: autoload present", bd != null)
	ck.call("bd: autoload OFF by default (headless)", bd != null and bd.enabled == false)


func test_disabled_records_nothing() -> void:
	var bd := _bd()
	bd.record("state", {"x": 1})
	bd.record_browser_error("error", "boom", "a.js", 1, 2, "")
	bd._on_js_event(["error", "boom", "a.js", 1, 2, ""])
	ck.call("bd: disabled records nothing", bd.store.size() == 0 and bd.recent(10).is_empty())
	ck.call("bd: disabled download/copy are no-ops", not bd.download_log() and bd.copy_bug_report() == "")
	bd.free()


func test_enabled_browser_error() -> void:
	var bd := _bd()
	bd.set_enabled(true)
	_t = 50
	bd._on_js_event(["error", "Uncaught TypeError at ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2", "https://x.io/dir/game.js?v=1#h", 12, 7, "at f (https://x.io/game.js?q=1:12:7)\nat g (file:///C:/Users/bob/g.js:1:1)"])
	var evs: Array = bd.recent(10)
	ck.call("bd: enabled logs debug_on then browser_error", evs.size() == 2 and evs[0]["type"] == "state" and evs[1]["type"] == "browser_error")
	var e: Dictionary = evs[1]
	ck.call("bd: browser_error fields", e["kind"] == "error" and e["source"] == "game.js" and e["line"] == 12 and e["col"] == 7 and e["t_ms"] == 50)
	ck.call("bd: browser_error message sanitized", not String(e["message"]).contains("ghp_") and String(e["message"]).contains("<redacted>"))
	ck.call("bd: browser_error stack sanitized", not String(e["stack"]).contains("?q=1") and not String(e["stack"]).contains("bob") and String(e["stack"]).contains("<local>"))
	bd._on_js_event(["unhandledrejection", "nope", "", 0, 0, ""])
	ck.call("bd: unhandledrejection recorded", bd.recent(1)[0]["kind"] == "unhandledrejection")
	bd._on_js_event(["error", "short"])
	ck.call("bd: malformed js args ignored", bd.recent(1)[0]["kind"] == "unhandledrejection")
	bd._on_js_event(["error", "dup", "a.js", 1, 1, ""])
	bd._on_js_event(["error", "dup", "a.js", 1, 1, ""])
	ck.call("bd: duplicate errors coalesced with count", bd.recent(1)[0].get("count", 1) == 2)
	bd.free()


func test_session_metadata() -> void:
	var bd := _bd()
	bd.set_enabled(true)
	var h: Dictionary = JSON.parse_string(bd.export_jsonl().split("\n")[0])
	ck.call("bd: header session/build/env", h["type"] == "session_header" and h["session"] == bd.session_id and bd.session_id.length() == 12 and h["build"]["commit_sha"] == "abcdef1234567" and h["env"]["userAgent"] == "UA")
	ck.call("bd: header has UTC start and godot version", String(h["utc_start"]).ends_with("Z") and String(h["build"]["godot"]) != "")
	bd.free()


func test_without_telemetry() -> void:
	var bd := _bd()
	bd.set_enabled(true)
	_t = 10
	bd.record("state", {"scene": "arena"})
	ck.call("bd: works without DebugTelemetry", bd._telemetry() == null and bd.recent(10).size() == 2)
	ck.call("bd: export without DebugTelemetry is JSONL", bd.export_jsonl().strip_edges().split("\n").size() == 3)
	bd.free()


func test_merge_with_fake_telemetry() -> void:
	var bd := _bd()
	var ft := FakeTelemetry.new()
	bd.telemetry_override = ft
	bd.set_enabled(true)  # own debug_on event at t=0
	_t = 20
	bd.record("state", {"event": "own20"})
	_t = 40
	bd.record("state", {"event": "own40"})
	ft.events = [
		{"t_ms": 5, "type": "input", "src": "tel5"},
		{"t_ms": 20, "type": "input", "src": "tel20"},
		{"t_ms": 30, "type": "action", "src": "tel30"},
		{"t_ms": 50, "type": "combat", "src": "tel50"},
	]
	var evs: Array = bd.recent(100)
	var order: Array = evs.map(func(e: Dictionary) -> String: return String(e.get("src", e.get("event", ""))))
	ck.call("bd: merge ordered by t_ms, telemetry first on ties", order == ["debug_on", "tel5", "tel20", "own20", "tel30", "own40", "tel50"], str(order))
	var ts: Array = evs.map(func(e: Dictionary) -> int: return int(e["t_ms"]))
	var sorted := ts.duplicate()
	sorted.sort()
	ck.call("bd: merged t_ms ascending", ts == sorted)
	var lines: PackedStringArray = String(bd.export_jsonl()).strip_edges().split("\n")
	ck.call("bd: export merges header + all events", lines.size() == 8, str(lines.size()))
	ck.call("bd: recent(n) returns newest n", bd.recent(2).size() == 2 and bd.recent(2)[1]["src"] == "tel50")
	ft.free()
	bd.free()


func test_toggle_propagates_to_telemetry() -> void:
	var bd := _bd()
	var ft := FakeTelemetry.new()
	bd.telemetry_override = ft
	var seen: Array = []
	bd.debug_toggled.connect(func(on: bool) -> void: seen.append(on))
	bd.set_enabled(true)
	ck.call("bd: enabling sets DebugTelemetry.enabled", ft.enabled == true)
	bd.set_enabled(false)
	ck.call("bd: disabling clears DebugTelemetry.enabled", ft.enabled == false and seen == [true, false])
	var n: int = bd.store.size()
	bd.record("state", {})
	ck.call("bd: no recording after disable", bd.store.size() == n)
	ft.free()
	bd.free()


func test_report_and_filename() -> void:
	var bd := _bd()
	bd.set_enabled(true)
	bd.record_browser_error("error", "kaboom", "m.js", 3, 4, "")
	var r: String = bd.bug_report("tester says hi")
	ck.call("bd: report has header, note, last error, events", r.contains("session_header") and r.contains("NOTE: tester says hi") and r.contains("kaboom") and r.contains("LAST 2 EVENTS"))
	ck.call("bd: report without error says none", _fresh_report_none())
	var long_note := "n".repeat(2000)
	ck.call("bd: note is capped", bd.bug_report(long_note).length() < r.length() + 700)
	var fn: String = bd.log_filename()
	ck.call("bd: filename has UTC time + short sha", fn.begins_with("shinobi-debug-") and fn.ends_with("-abcdef1.jsonl"), fn)
	bd.free()


func _fresh_report_none() -> bool:
	var bd := _bd()
	bd.set_enabled(true)
	var ok := String(bd.bug_report()).contains("LAST ERROR: none")
	bd.free()
	return ok


func test_no_network_or_storage_in_source() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/web/browser_debug.gd") + FileAccess.get_file_as_string("res://scripts/web/debug_store.gd")
	var code := "\n".join(Array(src.split("\n")).filter(func(l: String) -> bool: return not l.strip_edges().begins_with("##") and not l.strip_edges().begins_with("#")))
	var bad := false
	for needle: String in ["HTTPRequest", "fetch(", "XMLHttpRequest", "sendBeacon", "WebSocket", "localStorage", "sessionStorage", "indexedDB", "document.cookie", "StreamPeerTCP", "HTTPClient"]:
		if code.contains(needle):
			bad = true
			print("  found forbidden: ", needle)
	ck.call("bd: source has no network or storage APIs", not bad)
