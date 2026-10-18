extends RefCounted
## Unit tests for DebugSanitizer and DebugStore. Called from tests/run_tests.gd with its ck callable.

var ck: Callable


func run(p_ck: Callable) -> void:
	ck = p_ck
	test_sanitizer()
	test_header_and_shape()
	test_buffer_limits()
	test_coalescing()
	test_rate_limits()
	test_throttles()
	test_enabled_disabled()
	test_merge_and_privacy()


func _store(enabled: bool = true) -> DebugStore:
	var s := DebugStore.new()
	s.configure("sess-1", {"commit_sha": "abc1234", "run_id": "42"}, {"userAgent": "UA"}, 1760000000.0)
	s.enabled = enabled
	return s


func test_sanitizer() -> void:
	var S := DebugSanitizer
	ck.call("san: url strips query and hash", S.sanitize_url("https://x.io/a/b.js?token=1&y=2#frag") == "https://x.io/a/b.js")
	ck.call("san: file:///C:/Users/<name> -> <local>", S.sanitize_url("file:///C:/Users/bob/game/x.js") == "<local>/game/x.js", S.sanitize_url("file:///C:/Users/bob/game/x.js"))
	ck.call("san: windows path in text", S.sanitize_text("at C:\\Users\\alice\\proj\\a.js:3") == "at <local>\\proj\\a.js:3", S.sanitize_text("at C:\\Users\\alice\\proj\\a.js:3"))
	ck.call("san: unix home path", S.sanitize_text("/home/carol/x.js and /Users/dave/y.js") == "<local>/x.js and <local>/y.js")
	ck.call("san: url inside text loses query", S.sanitize_text("fail https://a.b/c.js?k=secret#h now") == "fail https://a.b/c.js now")
	ck.call("san: basename", S.basename("https://x.io/dir/main.js?v=1") == "main.js")
	var gh := "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2"
	ck.call("san: ghp_ redacted", S.sanitize_text("token " + gh + " end") == "token <redacted> end", S.sanitize_text("token " + gh + " end"))
	ck.call("san: gho_ redacted", not S.sanitize_text("gho_" + "abcdefghij1234567890").contains("abcdefghij"))
	ck.call("san: github_pat_ redacted", not S.sanitize_text("github_pat_" + "11ABCDEFG0abcdefghij_klmnop").contains("11ABCDEFG0"))
	ck.call("san: AKIA redacted", not S.sanitize_text("key AKIA" + "IOSFODNN7EXAMPLE").contains("IOSFODNN7"))
	ck.call("san: Bearer redacted", S.sanitize_text("Authorization: Bearer abc.def-123_xyz") == "Authorization: Bearer <redacted>", S.sanitize_text("Authorization: Bearer abc.def-123_xyz"))
	ck.call("san: long hex redacted", S.sanitize_text("h=" + "0123456789abcdef".repeat(3)) == "h=<redacted>")
	ck.call("san: base64-like redacted", S.sanitize_text("d " + "QWxhZGRpbjpPcGVuU2VzYW1lMTIzNDU2Nzg5MEFCQ0RFRg==") == "d <redacted>")
	ck.call("san: ordinary long path not redacted", S.sanitize_text("assets/characters/ninja/idle/south/frame").contains("assets/characters"))
	ck.call("san: length cap", S.sanitize_text("x".repeat(2000)).length() < 600)
	var stack := "\n".join(PackedStringArray(range(30).map(func(i: int) -> String: return "at f%d (https://x.io/a.js?q=1:%d:2)" % [i, i])))
	var ss := S.sanitize_stack(stack)
	ck.call("san: stack frame cap + more marker", ss.split("\n").size() == DebugSanitizer.MAX_STACK_FRAMES + 1 and ss.contains("more frames"), str(ss.split("\n").size()))
	ck.call("san: stack urls stripped", not ss.contains("?q=1"))
	ck.call("san: stack total cap", S.sanitize_stack("a".repeat(5000), 5, 100).length() <= 100 + 20)


func test_header_and_shape() -> void:
	var s := _store()
	s.set_frame(77)
	s.record("state", {"scene": "arena", "t_ms": 999, "type": "evil"}, 1500)
	var j := s.export_jsonl(2000)
	ck.call("jsonl: ends with newline", j.ends_with("\n"))
	var lines := j.strip_edges().split("\n")
	ck.call("jsonl: header + 1 event lines", lines.size() == 2, str(lines.size()))
	var h: Variant = JSON.parse_string(lines[0])
	ck.call("jsonl: header fields", h is Dictionary and h["type"] == "session_header" and h["session"] == "sess-1" and h["build"]["commit_sha"] == "abc1234" and h["env"]["userAgent"] == "UA" and h["schema"] == 1)
	ck.call("jsonl: header utc_start ISO", h["utc_start"] == "2025-10-09T08:53:20Z", str(h["utc_start"]))
	ck.call("jsonl: header limits + dropped", h["limits"]["max_events"] == 5000 and h["limits"]["max_bytes"] == 2097152 and h["limits"]["window_ms"] == 600000 and h["dropped"].has("total"))
	var e: Variant = JSON.parse_string(lines[1])
	ck.call("event: core fields", e["t_ms"] == 1500 and e["session"] == "sess-1" and e["build"] == "abc1234" and e["frame"] == 77 and e["type"] == "state" and e["utc"] == "2025-10-09T08:53:21Z", str(e))
	ck.call("event: data merged, core keys not overridable", e["scene"] == "arena")


func test_buffer_limits() -> void:
	var s := _store()
	s.max_events = 10
	for i in 25:
		s.record("state", {"i": i}, i)
	ck.call("buffer: count bound", s.size() == 10 and s.events()[0]["i"] == 15, str(s.size()))
	ck.call("buffer: count evictions counted", s.dropped["evicted_count"] == 15 and s.dropped["total"] == 15)
	var b := _store()
	b.max_bytes = 1000
	for i in 100:
		b.record("state", {"pad": "p".repeat(50)}, i)
	ck.call("buffer: byte bound", b.bytes() <= 1000 and b.size() > 0 and b.dropped["evicted_bytes"] > 0, str(b.bytes()))
	var w := _store()
	w.window_ms = 1000
	w.record("state", {}, 0)
	w.record("state", {}, 700)
	w.record("state", {}, 1600)
	ck.call("buffer: time window", w.size() == 2 and w.dropped["evicted_window"] == 1, str(w.size()))
	var big := _store()
	big.max_bytes = 100
	ck.call("buffer: oversize single event dropped", not big.record("state", {"pad": "x".repeat(400)}, 0) and big.dropped["oversize"] == 1)
	ck.call("defaults documented", DebugStore.DEFAULT_MAX_EVENTS == 5000 and DebugStore.DEFAULT_MAX_BYTES == 2 * 1024 * 1024 and DebugStore.DEFAULT_WINDOW_MS == 600000)
	var soak := _store()
	for i in 20000:
		soak.record("state", {"i": i}, i * 40)  # ~13 min of events at 25/s
	ck.call("soak: stays within all bounds", soak.size() <= 5000 and soak.bytes() <= 2097152 and soak.events()[0]["t_ms"] >= 19999 * 40 - 600000, "%d events %d bytes" % [soak.size(), soak.bytes()])


func test_coalescing() -> void:
	var s := _store()
	for i in 5:
		s.record("browser_error", {"message": "boom", "source": "https://x/a.js?v=1", "line": 3, "col": 4}, 100 * i)
	s.record("browser_error", {"message": "other", "source": "a.js", "line": 3, "col": 4}, 600)
	ck.call("coalesce: duplicates become one event with count", s.size() == 2 and s.events()[0]["count"] == 5 and s.events()[0]["last_t_ms"] == 400 and s.coalesced == 4, str(s.events()))
	ck.call("coalesce: source basename sanitized", s.events()[0]["source"] == "a.js")
	s.record("state", {"message": "boom"}, 700)
	s.record("state", {"message": "boom"}, 710)
	ck.call("coalesce: non-error types not coalesced", s.size() == 4)
	var e := _store()
	e.max_events = 1
	e.record("error", {"message": "m"}, 0)
	e.record("state", {}, 1)  # evicts the error
	e.record("error", {"message": "m"}, 2)  # must be a fresh event, not a count on an evicted one
	ck.call("coalesce: evicted entry is not coalesced into", e.size() == 1 and not e.events()[0].has("count"), str(e.events()))


func test_rate_limits() -> void:
	var s := _store()
	var stored := 0
	for i in 100:
		if s.record("browser_error", {"message": "m%d" % i}, 0):
			stored += 1
	ck.call("rate: browser_error burst capped at bucket size", stored == 10 and s.dropped["rate_limited"] == 90, "stored=%d" % stored)
	ck.call("rate: bucket refills over time", s.record("browser_error", {"message": "later"}, 1000))
	var f := _store()
	for i in 20000:
		f.record("browser_error", {"message": "m%d" % i}, i / 10)  # 20k unique errors over 2 s
	ck.call("rate: flood stays bounded, dropped > 0", f.size() < 100 and f.dropped["rate_limited"] > 19000, "%d stored" % f.size())
	var o := _store()
	for i in 300:
		o.record("input", {"i": i}, 0)
	ck.call("rate: default per-type bucket limits runaway producers", o.size() == 200 and o.dropped["rate_limited"] == 100)


func test_throttles() -> void:
	var s := _store()
	ck.call("axis: first non-zero value recorded", s.record_axis("axis_left_x", 0.8, {}, 0))
	ck.call("axis: tiny change dropped", not s.record_axis("axis_left_x", 0.83, {}, 16))
	ck.call("axis: meaningful change recorded", s.record_axis("axis_left_x", 0.5, {}, 32))
	ck.call("axis: return into deadzone (crossing to 0) recorded", s.record_axis("axis_left_x", 0.02, {}, 48))
	ck.call("axis: deadzone noise at rest dropped", not s.record_axis("axis_left_x", 0.04, {}, 56))
	var n := s.size()
	ck.call("axis: sign flip recorded", s.record_axis("axis_left_x", -0.5, {}, 64) and s.size() == n + 1)
	var m := _store()
	ck.call("motion: first recorded", m.record_motion("mouse", Vector2(10, 10), {}, 0))
	ck.call("motion: small move dropped", not m.record_motion("mouse", Vector2(12, 10), {}, 100))
	ck.call("motion: too soon dropped", not m.record_motion("mouse", Vector2(100, 10), {}, 20))
	ck.call("motion: far and late recorded", m.record_motion("mouse", Vector2(100, 10), {}, 100))
	ck.call("throttle: counted as dropped", m.dropped["throttled"] == 2 and s.dropped["throttled"] >= 2)


func test_enabled_disabled() -> void:
	var s := _store(false)
	ck.call("disabled by default", DebugStore.new().enabled == false)
	var r1 := s.record("state", {}, 0)
	var r2 := s.record_axis("a", 1.0, {}, 0)
	ck.call("disabled: record stores nothing", not r1 and not r2 and s.size() == 0)
	s.enabled = true
	ck.call("enabled: record stores", s.record("state", {}, 0) and s.size() == 1)
	s.enabled = false
	s.record("state", {}, 1)
	ck.call("disabled again: no growth, export still works", s.size() == 1 and s.export_jsonl(2).strip_edges().split("\n").size() == 2)


func test_merge_and_privacy() -> void:
	var a: Array = [{"t_ms": 1, "who": "a"}, {"t_ms": 5, "who": "a"}]
	var b: Array = [{"t_ms": 1, "who": "b"}, {"t_ms": 3, "who": "b"}, {"t_ms": 9, "who": "b"}]
	var m := DebugStore.merge_by_time(a, b)
	var order := m.map(func(e: Dictionary) -> String: return "%s%d" % [e["who"], e["t_ms"]])
	ck.call("merge: ordered by t_ms, stable on ties", order == ["a1", "b1", "b3", "a5", "b9"], str(order))
	var s := _store()
	s.record("state", {"x": 1}, 4)
	var lines := s.export_jsonl(10, [{"t_ms": 2, "type": "input"}, {"t_ms": 6, "type": "action"}]).strip_edges().split("\n")
	var ts: Array = []
	for i in range(1, lines.size()):
		ts.append(int(JSON.parse_string(lines[i])["t_ms"]))
	ck.call("export: merges extra (DebugTelemetry) events by t_ms", ts == [2, 4, 6], str(ts))
	var p := _store()
	p.record("browser_error", {"message": "x https://a/b.js?tok=1 ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2", "stack": "at f (file:///C:/Users/bob/a.js?z=1:1:1)"}, 0)
	var j := p.export_jsonl(1)
	ck.call("privacy: exported log has no query, token or user name", not j.contains("tok=1") and not j.contains("ghp_") and not j.contains("bob") and j.contains("<local>"), j)
	var src := FileAccess.get_file_as_string("res://scripts/web/debug_store.gd") + FileAccess.get_file_as_string("res://scripts/web/debug_sanitizer.gd")
	var bad := false
	for tok: String in ["HTTPRequest", "HTTPClient", "StreamPeer", "WebSocket", "FileAccess.open", "ConfigFile", "JavaScriptBridge", "localStorage"]:
		if src.contains(tok):
			bad = true
	ck.call("privacy: core has no network, file, storage or JS access", not bad)
