extends SceneTree
## Manual benchmark / soak for DebugStore (NOT run by CI; run_tests.gd does not load it).
##   godot --headless --path . --script tests/bench_debug.gd -- bench
##   godot --headless --path . --script tests/bench_debug.gd -- soak [virtual_minutes]
## "soak" drives the store with a synthetic event mix on a VIRTUAL clock (now_ms is injected), so 10+ minutes of
## game time run in seconds. It samples size / bytes / memory every virtual minute and fails if any bound is broken.
## Frame rate is not measured here (headless, no renderer).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "bench"
	var code := 0
	if mode == "soak":
		code = _soak(int(args[1]) if args.size() > 1 else 10)
	else:
		_bench()
	quit(code)


func _store() -> DebugStore:
	var s := DebugStore.new()
	s.configure("bench", {"commit_sha": "abc1234", "run_id": "1"}, {"userAgent": "UA"}, 1760000000.0)
	s.enabled = true
	return s


func _bench() -> void:
	var n := 200000
	var s := _store()
	var t0 := Time.get_ticks_usec()
	for i in n:
		s.record("state", {"event": "e%d" % (i % 50), "x": i % 100, "state": "MOVE"}, i * 5)
	var dt := (Time.get_ticks_usec() - t0) / 1e6
	print("BENCH record(): %d calls in %.3f s = %.0f calls/s (%.2f us/call); kept=%d bytes=%d dropped=%s" % [n, dt, n / dt, dt / n * 1e6, s.size(), s.bytes(), str(s.dropped)])
	var s2 := _store()
	s2.max_events = 1000000
	s2.max_bytes = 1 << 30
	var m := 20000
	for i in m:
		s2.record("state", {"event": "e%d" % (i % 50), "x": i % 100, "state": "MOVE"}, i * 5)
	var line_bytes := float(s2.bytes()) / float(s2.size())
	print("BENCH bytes/event: %.1f (avg JSON line incl. newline, %d events)" % [line_bytes, s2.size()])
	var t1 := Time.get_ticks_usec()
	var out := s2.export_jsonl(m * 5)
	var d1 := (Time.get_ticks_usec() - t1) / 1e6
	print("BENCH export_jsonl(): %d events -> %d bytes in %.3f s" % [s2.size(), out.length(), d1])
	var s3 := _store()
	var off := DebugStore.new()
	off.configure("bench", {}, {}, 1760000000.0)
	var t2 := Time.get_ticks_usec()
	for i in n:
		off.record("state", {"event": "e"}, i)
	var d2 := (Time.get_ticks_usec() - t2) / 1e6
	print("BENCH disabled record(): %d calls in %.3f s = %.0f calls/s (%.3f us/call), kept=%d" % [n, d2, n / d2, d2 / n * 1e6, off.size()])
	print("BENCH note: absolute numbers are from this Windows dev box (headless GDScript); relative cost only. No frame-rate claim.")


func _soak(minutes: int) -> int:
	var s := _store()
	var total_ms := minutes * 60 * 1000
	var step := 4  ## virtual ms per tick (~250 ticks/s, an aggressive event rate)
	var failures := 0
	var mem0 := 0
	var max_size := 0
	var max_bytes := 0
	var max_mem := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var emitted := 0
	var t := 0
	while t <= total_ms:
		s.set_frame(t / 16)
		s.record("state", {"event": "tick", "n": t % 1000}, t)
		s.record_axis("move_x", sin(t / 300.0), {}, t)
		s.record_motion("mouse", Vector2(t % 1280, (t / 7) % 720), {}, t)
		emitted += 3
		if t % 20 == 0:
			s.record("browser_error", {"kind": "error", "message": "flood-%d" % rng.randi(), "source": "a.js", "line": 1, "col": 1}, t)
			s.record("warning", {"message": "warn %d" % (t % 7)}, t)
			emitted += 2
		if t % 60000 == 0:
			var sz := s.size()
			var by := s.bytes()
			var mem := OS.get_static_memory_usage()
			if t == 2 * 60000:
				mem0 = mem
			max_size = maxi(max_size, sz)
			max_bytes = maxi(max_bytes, by)
			max_mem = maxi(max_mem, mem)
			print("SOAK t=%2d min size=%d bytes=%d static_mem=%d dropped_total=%d coalesced=%d" % [t / 60000, sz, by, mem, s.dropped["total"], s.coalesced])
			if sz > s.max_events or by > s.max_bytes:
				failures += 1
		t += step
	var out := s.export_jsonl(total_ms)
	print("SOAK done: %d virtual min, %d record calls, kept=%d, max_size=%d (limit %d), max_bytes=%d (limit %d), export=%d bytes, dropped=%s" % [minutes, emitted, s.size(), max_size, s.max_events, max_bytes, s.max_bytes, out.length(), str(s.dropped)])
	print("SOAK static memory: at 2 min=%d, max=%d (growth after warm-up: %d bytes)" % [mem0, max_mem, max_mem - mem0])
	# Memory must plateau: the store is capped at max_bytes of JSON text, so allow a generous 1.5x cap-sized headroom
	# over the 2-minute reading but fail on runaway growth.
	if mem0 > 0 and max_mem - mem0 > s.max_bytes * 3:
		print("SOAK FAIL: static memory grew by more than 3x the byte cap after warm-up")
		failures += 1
	print("SOAK RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	return failures
