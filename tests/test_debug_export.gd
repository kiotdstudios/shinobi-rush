extends RefCounted
## Unit tests for export shaping (JSONL / TXT / filename / bug report) and the debug panel. Called from tests/run_tests.gd.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	test_filename()
	test_jsonl_shape()
	test_txt_shape()
	test_report_note_and_cap()
	test_panel(tree_root)


func _bd() -> Node:
	var bd: Node = load("res://scripts/web/browser_debug.gd").new()
	bd.clock = func() -> int: return 42
	bd.init_session({"userAgent": "UA"}, {"commit_sha": "abcdef1234567", "run_id": "9"})
	bd.store.enabled = true
	bd.enabled = true
	return bd


func test_filename() -> void:
	var f := DebugExport.filename(0.0, "abcdef1234567")
	ck.call("export filename utc + short sha", f == "shinobi-debug-19700101-000000-abcdef1.jsonl", f)
	ck.call("export filename unknown sha + txt", DebugExport.filename(0.0, "", "txt").ends_with("-unknown.txt"))


func test_jsonl_shape() -> void:
	var bd := _bd()
	bd.record("state", {"event": "a"})
	bd.record_browser_error("error", "boom", "game.js", 3, 4, "at x")
	var lines: PackedStringArray = bd.export_jsonl().strip_edges().split("\n")
	var head: Variant = JSON.parse_string(lines[0])
	var ev: Variant = JSON.parse_string(lines[lines.size() - 1])
	ck.call("jsonl first line is session header", head is Dictionary and head.get("type") == "session_header" and head.get("session") == bd.session_id)
	ck.call("jsonl header has build/env/limits/dropped", head.has("build") and head.has("env") and head.has("limits") and head.has("dropped"))
	ck.call("jsonl event has core fields", ev is Dictionary and ev.has("t_ms") and ev.has("utc") and ev.has("session") and ev.has("frame") and ev.get("type") == "browser_error")
	ck.call("jsonl line count header + events", lines.size() == 1 + bd.recent(1000).size())
	bd.free()


func test_txt_shape() -> void:
	var bd := _bd()
	bd.record("state", {"event": "a"})
	var txt: String = bd.export_txt()
	ck.call("txt has title and session", txt.begins_with("SHINOBI RUSH DEBUG LOG") and txt.contains("session: " + bd.session_id))
	ck.call("txt has build sha and event line", txt.contains("build.commit_sha: abcdef1234567") and txt.contains("state"))
	ck.call("txt event count", txt.contains("events: %d" % bd.recent(1000).size()))
	bd.free()


func test_report_note_and_cap() -> void:
	var bd := _bd()
	for i in 150:
		bd.record("state", {"event": "e%d" % i})
	var r: String = bd.bug_report("it broke ghp_" + "a".repeat(30))
	ck.call("report has NOTE line sanitized", r.contains("NOTE: ") and not r.contains("ghp_" + "a".repeat(30)))
	ck.call("report capped to last 100 events", r.contains("LAST 100 EVENTS"))
	ck.call("note is not recorded as an event", not str(bd.recent(1000)).contains("it broke"))
	ck.call("copy_bug_report off returns empty", (load("res://scripts/web/browser_debug.gd").new() as Node).copy_bug_report("x") == "")
	bd.free()


func test_panel(tree_root: Node) -> void:
	var bd := _bd()
	tree_root.add_child(bd)
	var panel: Node = load("res://scenes/ui/debug_panel.tscn").instantiate()
	panel.debug = bd
	tree_root.add_child(panel)
	ck.call("panel visible when debug on", panel.visible)
	ck.call("panel shows DEBUG ON + session id", panel.indicator.text == "DEBUG ON  session " + bd.session_id)
	ck.call("panel has download/copy buttons and note field", panel.download_button.text == "Download Debug Log" and panel.copy_button.text == "Copy Bug Report" and panel.note_field != null)
	ck.call("panel fallback hidden initially", not panel.fallback.visible and not panel.fallback.editable)
	panel.note_field.text = "typed note"
	bd.clipboard_done.emit(false)
	ck.call("fallback shown when clipboard refused", panel.fallback.visible)
	var before: int = bd.recent(1000).size()
	panel.copy_button.pressed.emit()
	ck.call("copy fills fallback text with note", panel.fallback.text.contains("NOTE: typed note"))
	ck.call("copy adds no events", bd.recent(1000).size() == before)
	bd.set_enabled(false)
	ck.call("panel hidden when debug off", not panel.visible)
	panel.queue_free()
	bd.queue_free()
