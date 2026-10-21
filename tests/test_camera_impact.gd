extends RefCounted
## Camera impact module (CameraImpact). Called from tests/run_tests.gd.
## (a) pure: envelope, stacking and cap, unit conversion, edge clamp, URL mode, and the deterministic trace table (CFX_TRACE rows),
## (b) scene: the REAL player and camera driven with a fixed 1/60 s step (helper.auto_advance = false, advance(1/60) per tick):
##     no hit, light, heavy, three rapid hits, one 200 ms frame, the edge clamp at all four limits and with a little room left,
##     a lab zoom step, a preset switch mid-effect, disabled / reduced / freed, bad inputs, telemetry, the lab keys and buttons,
##     and one run on real frames during local hitstop.
## (c) moving camera, real frames: the player WALKS into the east wall at close and at wide with the helper in its normal
##     automatic mode and a heavy hit every 7th frame; the rendered view must stay inside the limits on every single frame.
## After every case in (b) the camera is exactly where it was: offset ZERO, zoom == baseline, position, smoothing, limits and
## get_screen_center_position() unchanged; after (c) the offset is ZERO, the zoom is on the baseline, limits and smoothing are
## unchanged. Every scene test restores the preset and the module's static state.
## NOTE: the manual advance(TICK) cases in (b) do not reproduce the engine's frame order (a coroutine resumed at process_frame
## runs BEFORE the camera's own update, and a still camera has no smoothing step), so the moving-camera case (c) is the one that
## guards the edge clamp.

const TICK := 1.0 / 60.0
const WALK_PX := 5.0  ## world px the scripted player walks per frame (a brisk walk)
const WALK_HIT_EVERY := 7  ## frames between two heavy hits while walking
const WALK_MAX_FRAMES := 800  ## safety stop of the walk
const WALK_PINNED_FRAMES := 40  ## the walk ends this many frames after the view first sits on the east limit

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	CameraImpact.reset_all()
	test_envelope()
	test_stacking()
	test_trace_table()
	test_units_clamp_and_modes()
	await test_scene(tree_root)
	await test_walking_into_wall(tree_root, CameraPreset.CLOSE)
	await test_walking_into_wall(tree_root, CameraPreset.WIDE)
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)
	CameraImpact.reset_all()


func _near(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) < eps


## An impulse record as the helper stores it.
func _imp(dir: Vector2, peak: float, dur: float, t0: float) -> Dictionary:
	return {"dir": dir.normalized(), "peak": peak, "dur": dur, "t0": t0}


## Largest envelope value on a 0.25 ms grid.
func _peak_of(peak: float, dur_s: float) -> float:
	var best := CameraImpact.offset_at(CameraImpact.RISE_S, peak, dur_s)  # the exact end of the rise is not on the grid
	var t := 0.0
	while t <= dur_s + 0.02:
		best = maxf(best, CameraImpact.offset_at(t, peak, dur_s))
		t += 0.00025
	return best


## Combined offset of `list` at k * TICK for k in 0..n-1.
func _trace(list: Array, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in n:
		out.append(CameraImpact.sample(list, k * TICK))
	return out


func _max_len(trace: Array[Vector2]) -> float:
	var m := 0.0
	for v in trace:
		m = maxf(m, v.length())
	return m


# ------------------------------------------------------------------ (a) pure functions
func test_envelope() -> void:
	var s := CameraImpact.settings
	var lp := CameraImpact.LIGHT_PEAK_PX
	var ld := CameraImpact.LIGHT_MS / 1000.0
	var hp := CameraImpact.HEAVY_PEAK_PX
	var hd := CameraImpact.HEAVY_MS / 1000.0
	ck.call("impact: defaults are enabled, scale 1, and the tunables sit inside the order's bands", s.enabled and s.scale == 1.0 and lp >= 2.0 and lp <= 3.0 and ld >= 0.06 and ld <= 0.1 and hp >= 4.0 and hp <= 6.0 and hd >= 0.1 and hd <= 0.14 and CameraImpact.MAX_TOTAL_PX == 6.0)
	ck.call("impact: no hit is zero (no impulses, before the start, at the start)", CameraImpact.sample([], 1.0) == Vector2.ZERO and CameraImpact.combine([]) == Vector2.ZERO and CameraImpact.offset_at(-0.01, lp, ld) == 0.0 and CameraImpact.offset_at(0.0, lp, ld) == 0.0)
	var l_best := _peak_of(lp, ld)
	ck.call("impact: light peak is inside 2-3 px and the envelope is exactly zero at 80 ms and by 100 ms", l_best >= 2.0 and l_best <= 3.0 and CameraImpact.offset_at(ld, lp, ld) == 0.0 and CameraImpact.offset_at(0.1, lp, ld) == 0.0, str(l_best))
	var h_best := _peak_of(hp, hd)
	ck.call("impact: heavy peak is inside 4-6 px and the envelope is exactly zero at 120 ms and by 140 ms", h_best >= 4.0 and h_best <= 6.0 and CameraImpact.offset_at(hd, hp, hd) == 0.0 and CameraImpact.offset_at(0.14, hp, hd) == 0.0, str(h_best))
	ck.call("impact: the kick reaches EXACTLY its peak within one 60 Hz tick (light and heavy) and never exceeds it", _near(CameraImpact.offset_at(CameraImpact.RISE_S, lp, ld), lp, 1e-12) and _near(CameraImpact.offset_at(CameraImpact.RISE_S, hp, hd), hp, 1e-12) and CameraImpact.RISE_S <= 1.0 / 60.0 + 1e-12 and _near(l_best, lp, 1e-9) and _near(h_best, hp, 1e-9))
	ck.call("impact: the rise is a ramp over that tick (half way = half the peak)", _near(CameraImpact.offset_at(CameraImpact.RISE_S * 0.5, hp, hd), hp * 0.5, 1e-9))
	var mono := true
	var prev := hp
	var t := CameraImpact.RISE_S
	while t < hd:
		var v := CameraImpact.offset_at(t, hp, hd)
		if v > prev + 1e-12 or v < 0.0:
			mono = false
		prev = v
		t += 0.001
	ck.call("impact: after the peak the offset only decays (never negative) and lands softly (tiny 0.1 ms before the end)", mono and CameraImpact.offset_at(hd - 0.0001, hp, hd) < 1e-3)
	var a: Array[float] = []
	var b: Array[float] = []
	for k in 40:
		a.append(CameraImpact.offset_at(k * TICK, hp, hd))
		b.append(CameraImpact.offset_at(k * TICK, hp, hd))
	ck.call("impact: the same input gives the same trace (a pure function of time)", a == b)
	ck.call("impact: nan, inf, zero and negative inputs give zero, never nan", CameraImpact.offset_at(NAN, hp, hd) == 0.0 and CameraImpact.offset_at(0.05, NAN, hd) == 0.0 and CameraImpact.offset_at(0.05, hp, INF) == 0.0 and CameraImpact.offset_at(0.05, -5.0, hd) == 0.0 and CameraImpact.offset_at(0.05, hp, 0.0) == 0.0 and CameraImpact.offset_at(0.05, hp, -1.0) == 0.0)
	ck.call("impact: a very short impulse (under two ticks) still rises, then ends at exactly zero", CameraImpact.offset_at(0.004, 5.0, 0.01) > 0.0 and CameraImpact.offset_at(0.01, 5.0, 0.01) == 0.0)


func test_stacking() -> void:
	var lp := CameraImpact.LIGHT_PEAK_PX
	var hp := CameraImpact.HEAVY_PEAK_PX
	var cap := CameraImpact.MAX_TOTAL_PX
	var one := CameraImpact.combine([Vector2(lp, 0.0)])
	ck.call("impact stack: one impulse comes out exact", one.is_equal_approx(Vector2(lp, 0.0)), str(one))
	var two := CameraImpact.combine([Vector2(lp, 0.0), Vector2(lp, 0.0)])
	var three := CameraImpact.combine([Vector2(lp, 0.0), Vector2(lp, 0.0), Vector2(lp, 0.0)])
	ck.call("impact stack: same-direction hits do not add linearly (2 x 2.5 -> 3.54, 3 x 2.5 -> 4.33)", _near(two.length(), lp * sqrt(2.0)) and two.length() < 2.0 * lp - 1.0 and _near(three.length(), lp * sqrt(3.0)) and three.length() < 3.0 * lp - 2.0, "%s %s" % [two, three])
	var heavy3 := CameraImpact.combine([Vector2(hp, 0.0), Vector2(hp, 0.0), Vector2(hp, 0.0)])
	ck.call("impact stack: three heavy hits at once are capped at MAX_TOTAL_PX along the hit direction", _near(heavy3.length(), cap, 1e-9) and heavy3.x > 0.0 and absf(heavy3.y) < 1e-12, str(heavy3))
	var big := CameraImpact.combine([Vector2(100.0, 0.0), Vector2(0.0, 100.0), Vector2(-50.0, 50.0)])
	ck.call("impact stack: no combination is ever longer than the cap", big.length() <= cap + 1e-4, str(big))
	ck.call("impact stack: opposite hits cancel", CameraImpact.combine([Vector2(lp, 0.0), Vector2(-lp, 0.0)]).length() < 1e-9)
	var perp := CameraImpact.combine([Vector2(lp, 0.0), Vector2(0.0, lp)])
	ck.call("impact stack: perpendicular hits blend into the diagonal at the strength of ONE hit", _near(perp.length(), lp) and _near(perp.x, perp.y), str(perp))
	var weighted := CameraImpact.combine([Vector2(4.0, 0.0), Vector2(0.0, 1.0)])
	ck.call("impact stack: the direction blends by weight (the stronger hit dominates)", weighted.x > 3.0 * weighted.y and weighted.y > 0.0, str(weighted))
	var dirs_ok := true
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(37.0, -5.0)]:
		var o := CameraImpact.sample([_imp(d, lp, 0.08, 0.0)], CameraImpact.RISE_S)
		if not (_near(o.length(), lp, 1e-5) and o.normalized().distance_to(d.normalized() * CameraImpact.KICK_SIGN) < 1e-5):
			dirs_ok = false
	ck.call("impact stack: the kick points along the hit direction for 8 headings and any vector length", dirs_ok and CameraImpact.KICK_SIGN == 1.0)
	ck.call("impact stack: a zero direction is accepted and moves nothing", CameraImpact.sample([_imp(Vector2.ZERO, lp, 0.08, 0.0)], CameraImpact.RISE_S) == Vector2.ZERO)
	# three heavy hits 50 ms apart in the same direction: the worst case
	var worst := [_imp(Vector2.RIGHT, hp, 0.12, 0.0), _imp(Vector2.RIGHT, hp, 0.12, 0.05), _imp(Vector2.RIGHT, hp, 0.12, 0.10)]
	var wt := _trace(worst, 30)
	var wmax := _max_len(wt)
	ck.call("impact stack: three heavy hits inside 150 ms stay under the cap, stack above one hit, and end at exactly zero", wmax <= cap + 1e-4 and wmax > hp and wt[14] == Vector2.ZERO and wt[29] == Vector2.ZERO, str(wmax))
	# the lab burst: three light hits 40 ms apart
	var burst := [_imp(Vector2.RIGHT, lp, 0.08, 0.0), _imp(Vector2.RIGHT, lp, 0.08, 0.04), _imp(Vector2.RIGHT, lp, 0.08, 0.08)]
	var bt := _trace(burst, 30)
	var bmax := _max_len(bt)
	ck.call("impact stack: the burst (3 light hits 40 ms apart) peaks below sqrt(3) x light, above one hit, and ends at exactly zero", bmax <= lp * sqrt(3.0) + 1e-4 and bmax >= lp - 1e-4 and bt[10] == Vector2.ZERO and bt[29] == Vector2.ZERO, str(bmax))
	var again := _trace(worst, 30)
	ck.call("impact stack: the same impulses give the same trace", again == wt)


func test_trace_table() -> void:
	var light := [_imp(Vector2.RIGHT, CameraImpact.LIGHT_PEAK_PX, CameraImpact.LIGHT_MS / 1000.0, 0.0)]
	var heavy := [_imp(Vector2.RIGHT, CameraImpact.HEAVY_PEAK_PX, CameraImpact.HEAVY_MS / 1000.0, 0.0)]
	var burst := [_imp(Vector2.RIGHT, 2.5, 0.08, 0.0), _imp(Vector2.RIGHT, 2.5, 0.08, 0.04), _imp(Vector2.RIGHT, 2.5, 0.08, 0.08)]
	var rapid := [_imp(Vector2.RIGHT, 5.0, 0.12, 0.0), _imp(Vector2.RIGHT, 5.0, 0.12, 0.05), _imp(Vector2.RIGHT, 5.0, 0.12, 0.10)]
	var tl := _trace(light, 15)
	var th := _trace(heavy, 15)
	var tb := _trace(burst, 15)
	var trp := _trace(rapid, 15)
	print("CFX_TRACE t_ms | light 2.5px/80ms | heavy 5px/120ms | burst 3 light 40 ms apart | rapid 3 heavy 50 ms apart (screen px along the hit direction, 60 Hz steps, pure core)")
	for k in 15:
		print("CFX_TRACE %6.1f | %6.3f | %6.3f | %6.3f | %6.3f" % [k * TICK * 1000.0, tl[k].x, th[k].x, tb[k].x, trp[k].x])
	ck.call("impact trace: tick 0 is zero, tick 1 is the peak, light is zero from tick 5, heavy from tick 8", tl[0] == Vector2.ZERO and th[0] == Vector2.ZERO and _near(tl[1].x, 2.5, 1e-9) and _near(th[1].x, 5.0, 1e-9) and tl[5] == Vector2.ZERO and th[8] == Vector2.ZERO and tl[4].x > 0.0 and th[7].x > 0.0)
	ck.call("impact trace: burst is zero from tick 10 and the rapid heavy triple from tick 14", tb[10] == Vector2.ZERO and trp[14] == Vector2.ZERO and tb[9].x > 0.0 and trp[13].x > 0.0)


func test_units_clamp_and_modes() -> void:
	var wide := 1.0 / WorldScale.SCALE
	var close := CameraPreset.close_zoom(104.0)
	ck.call("impact units: 3 screen px are 6.75 world px at the wide zoom and 2.48 at the close zoom of the 104 px art", _near(CameraImpact.to_world(Vector2(3.0, 0.0), wide).x, 6.75, 1e-9) and _near(CameraImpact.to_world(Vector2(3.0, 0.0), close).x, 3.0 / 1.2115384615, 1e-6) and _near(close, 1.2115384615, 1e-6))
	ck.call("impact units: a zoom that is not a positive finite number gives zero, and screen -> world -> screen round-trips", CameraImpact.to_world(Vector2(3.0, 4.0), 0.0) == Vector2.ZERO and CameraImpact.to_world(Vector2(3.0, 4.0), -1.0) == Vector2.ZERO and CameraImpact.to_world(Vector2(3.0, 4.0), NAN) == Vector2.ZERO and (CameraImpact.to_world(Vector2(3.0, 4.0), close) * close).is_equal_approx(Vector2(3.0, 4.0)))
	# limits x -100..100, y -100..100; the view is 100 x 80 (half 50 x 40)
	var lim := Rect2(-100.0, -100.0, 200.0, 200.0)
	var half := Vector2(50.0, 40.0)
	ck.call("impact clamp: in the middle of the arena the offset passes unchanged", CameraImpact.clamp_to_limits(Vector2(4.0, -3.0), Vector2.ZERO, half, lim) == Vector2(4.0, -3.0))
	ck.call("impact clamp: at the east limit a kick east is 0 and a kick west passes", CameraImpact.clamp_to_limits(Vector2(4.0, 0.0), Vector2(50.0, 0.0), half, lim) == Vector2.ZERO and CameraImpact.clamp_to_limits(Vector2(-4.0, 0.0), Vector2(50.0, 0.0), half, lim) == Vector2(-4.0, 0.0))
	ck.call("impact clamp: at the west, north and south limits likewise", CameraImpact.clamp_to_limits(Vector2(-4.0, 0.0), Vector2(-50.0, 0.0), half, lim) == Vector2.ZERO and CameraImpact.clamp_to_limits(Vector2(0.0, -4.0), Vector2(0.0, -60.0), half, lim) == Vector2.ZERO and CameraImpact.clamp_to_limits(Vector2(0.0, 4.0), Vector2(0.0, 60.0), half, lim) == Vector2.ZERO and CameraImpact.clamp_to_limits(Vector2(0.0, 4.0), Vector2(0.0, -60.0), half, lim) == Vector2(0.0, 4.0))
	ck.call("impact clamp: with 1.5 px of room left a 4 px kick shrinks to exactly 1.5 (the other axis is untouched)", CameraImpact.clamp_to_limits(Vector2(4.0, 2.0), Vector2(48.5, 0.0), half, lim) == Vector2(1.5, 2.0))
	ck.call("impact clamp: in a corner both axes shrink", CameraImpact.clamp_to_limits(Vector2(4.0, 4.0), Vector2(50.0, 60.0), half, lim) == Vector2.ZERO)
	ck.call("impact clamp: a view larger than the limits gets no offset (it is never pushed away from zero)", CameraImpact.clamp_to_limits(Vector2(4.0, -4.0), Vector2.ZERO, Vector2(200.0, 200.0), lim) == Vector2.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shrink_only := true
	for i in 500:
		var o := Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
		var c := Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-60.0, 60.0))  # offset-free view already inside the limits
		var r := CameraImpact.clamp_to_limits(o, c, half, lim)
		var inside := c.x + r.x + half.x <= 100.0 + 1e-4 and c.x + r.x - half.x >= -100.0 - 1e-4 and c.y + r.y + half.y <= 100.0 + 1e-4 and c.y + r.y - half.y >= -100.0 - 1e-4
		if not (inside and absf(r.x) <= absf(o.x) + 1e-5 and absf(r.y) <= absf(o.y) + 1e-5 and r.x * o.x >= 0.0 and r.y * o.y >= 0.0):
			shrink_only = false
	ck.call("impact clamp: 500 random cases: the view stays inside the limits and the offset only shrinks toward 0, never flips", shrink_only)
	# ?camera_impact= and the boot mode
	ck.call("impact mode: parse_query -> off / reduced / on, case and percent-encoding tolerant, '' when absent", CameraImpact.parse_query("?camera_impact=off") == "off" and CameraImpact.parse_query("camera_impact=Reduced") == "reduced" and CameraImpact.parse_query("?debug=1&camera_impact=on&x=2") == "on" and CameraImpact.parse_query("?camera_impact=%6Fff") == "off" and CameraImpact.parse_query("") == "" and CameraImpact.parse_query("?camera=close") == "" and CameraImpact.parse_query("?camera_impacts=off") == "")
	ck.call("impact mode: the first value wins and garbage / empty means on", CameraImpact.parse_query("?camera_impact=off&camera_impact=on") == "off" and CameraImpact.parse_query("?camera_impact=zzz&camera_impact=off") == "on" and CameraImpact.parse_query("?camera_impact=") == "on" and CameraImpact.parse_query("?camera_impact") == "on" and CameraImpact.parse_query("?camera_impact=1e999") == "on" and CameraImpact.parse_query("?&&camera_impact=reduced&&") == "reduced")
	ck.call("impact mode: boot_mode - the URL wins, else reduced-motion gives reduced, else on", CameraImpact.boot_mode("?camera_impact=on", true) == "on" and CameraImpact.boot_mode("?camera_impact=off", false) == "off" and CameraImpact.boot_mode("", true) == "reduced" and CameraImpact.boot_mode("", false) == "on" and CameraImpact.boot_mode("?camera=close", true) == "reduced" and CameraImpact.boot_mode("?camera_impact=zzz", true) == "on")
	CameraImpact.apply_mode("off")
	var off_ok := not CameraImpact.settings.enabled and CameraImpact.settings.effective() == 0.0
	CameraImpact.apply_mode("reduced")
	var red_ok := CameraImpact.settings.enabled and CameraImpact.settings.scale == 0.5 and CameraImpact.settings.effective() == 0.5
	CameraImpact.apply_mode("on")
	ck.call("impact mode: apply_mode off / reduced / on", off_ok and red_ok and CameraImpact.settings.enabled and CameraImpact.settings.scale == 1.0)
	var bridge := load("res://scripts/web/web_bridge.gd")
	bridge.apply_camera_impact_query("?camera_impact=off")
	var q_off := not CameraImpact.settings.enabled
	bridge.apply_camera_impact_query("?camera_impact=reduced")
	var q_red := CameraImpact.settings.enabled and CameraImpact.settings.scale == 0.5
	bridge.apply_camera_impact_query("?camera_impact=zzz", true)
	var q_garbage := CameraImpact.settings.enabled and CameraImpact.settings.scale == 1.0
	bridge.apply_camera_impact_query("", true)
	var q_motion := CameraImpact.settings.scale == 0.5
	bridge.apply_camera_impact_query("")
	ck.call("impact mode: WebBridge.apply_camera_impact_query - off, reduced, garbage -> on, reduced-motion default, empty -> on", q_off and q_red and q_garbage and q_motion and CameraImpact.settings.enabled and CameraImpact.settings.scale == 1.0)
	var src := FileAccess.get_file_as_string("res://scripts/web/web_bridge.gd")
	ck.call("impact state: WebBridge publishes the seven cfx_* fields next to the existing ones and reads ?camera_impact=", src.contains("_state.cfx_enabled = ") and src.contains("_state.cfx_scale = ") and src.contains("_state.cfx_active = ") and src.contains("_state.cfx_offset_x = ") and src.contains("_state.cfx_offset_y = ") and src.contains("_state.cfx_peak_px = ") and src.contains("_state.cfx_count = ") and src.contains("_state.camera_preset = ") and src.contains("apply_camera_impact_query(search"))
	CameraImpact.reset_all()
	var keys := CameraImpact.telemetry().keys()
	keys.sort()
	ck.call("impact state: telemetry() has exactly the seven documented keys at their boot values", keys == ["cfx_active", "cfx_count", "cfx_enabled", "cfx_offset_x", "cfx_offset_y", "cfx_peak_px", "cfx_scale"] and CameraImpact.telemetry()["cfx_enabled"] == true and CameraImpact.telemetry()["cfx_scale"] == 1.0 and CameraImpact.telemetry()["cfx_active"] == false and CameraImpact.telemetry()["cfx_count"] == 0 and CameraImpact.telemetry()["cfx_peak_px"] == 0.0)


# ------------------------------------------------------------------ (b) scene level
func _press(node: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	node._unhandled_input(ev)


func _boot(tree_root: Node, spec: Variant) -> Node:
	CameraPreset.set_active(spec)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await tree_root.get_tree().process_frame
	return main


## Everything the module must not touch (plus the offset and zoom it must give back).
func _snap(player: PlayerController) -> Dictionary:
	var cam := player.camera
	return {
		"pos": cam.position, "smooth": cam.position_smoothing_enabled, "speed": cam.position_smoothing_speed,
		"limits": [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom], "center": cam.get_screen_center_position(),
		"zoom": cam.zoom, "base": player.camera_baseline, "offset": cam.offset, "player": player.global_position,
	}


## Put the player at `pos` and let the camera settle there without smoothing lag.
func _settle(tree_root: Node, player: PlayerController, pos: Vector2) -> Dictionary:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	var cam := player.camera
	cam.reset_smoothing()
	cam.force_update_scroll()
	await tree_root.get_tree().process_frame
	await tree_root.get_tree().process_frame
	cam.reset_smoothing()
	cam.force_update_scroll()
	return _snap(player)


## The world rectangle on screen right now (what the player actually sees), from the viewport canvas transform.
func _view_rect(cam: Camera2D) -> Rect2:
	var vp := cam.get_viewport()
	return vp.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size)


## How far the view sticks out past a camera limit, world px (<= 0 means inside).
func _void_px(cam: Camera2D) -> float:
	var r := _view_rect(cam)
	return maxf(maxf(cam.limit_left - r.position.x, r.end.x - cam.limit_right), maxf(cam.limit_top - r.position.y, r.end.y - cam.limit_bottom))


## The helper under the camera in MANUAL mode: the test drives it with advance(TICK).
func _manual(cam: Camera2D) -> CameraImpact:
	var rn := CameraImpact.runner_for(cam)
	if rn != null:
		rn.auto_advance = false
		rn.set_process(false)
	return rn


## n fixed steps; the camera offset in screen px after each one.
func _ticks(rn: CameraImpact, cam: Camera2D, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		rn.advance(TICK)
		out.append(cam.offset * cam.zoom.x)
	return out


func _print_trace(name: String, trace: Array[Vector2]) -> void:
	for k in trace.size():
		print("CFX_SCENE_TRACE %s t_ms=%6.1f offset_px=(%7.3f, %7.3f)" % [name, (k + 1) * TICK * 1000.0, trace[k].x, trace[k].y])


func _free_runner(cam: Camera2D) -> void:
	var rn := CameraImpact.runner_for(cam)
	if rn != null:
		rn.free()


func test_scene(tree_root: Node) -> void:
	var tree := tree_root.get_tree()
	CameraImpact.reset_all()
	# ---- nothing to kick yet: every call is a silent no-op
	var no_player := tree.get_first_node_in_group("player") == null
	CameraImpact.light_hit(Vector2.RIGHT)
	CameraImpact.heavy_hit(Vector2.LEFT)
	CameraImpact.impulse(Vector2.UP, 3.0, 90.0)
	ck.call("impact scene: with no player or camera in the tree every call is a silent no-op (nothing counted, no state change)", no_player and CameraImpact.count == 0 and CameraImpact.peak_px == 0.0 and CameraImpact.telemetry()["cfx_active"] == false)
	var main := await _boot(tree_root, CameraPreset.DEFAULT_ID)
	var player := main.get_node("TrainingArena/Player") as PlayerController
	var arena := main.get_node("TrainingArena") as TrainingArena
	var lab := main.get_node("AnimationLab") as AnimationLab
	var cam := player.camera
	var b := arena.get_bounds()
	var wide := 1.0 / WorldScale.SCALE
	var pre := await _settle(tree_root, player, Vector2(0.0, 135.0))
	ck.call("impact scene: boots on the wide preset with zoom == baseline and a zero offset", absf(cam.zoom.x - wide) < 1e-6 and absf(cam.zoom.x - player.camera_baseline) < 1e-6 and cam.offset == Vector2.ZERO)

	# ---- no hit
	for i in 10:
		await tree.process_frame
	ck.call("impact scene: no hit - 10 normal frames create no helper and change nothing", cam.get_node_or_null(CameraImpact.NODE_NAME) == null and CameraImpact.count == 0 and CameraImpact.peak_px == 0.0 and _snap(player) == pre)

	# ---- light hit, east
	CameraImpact.light_hit(Vector2.RIGHT)
	var rn := _manual(cam)
	ck.call("impact scene: the first call creates ONE helper under the camera; nothing has moved before time passes", rn != null and rn.get_parent() == cam and cam.get_node_or_null(CameraImpact.NODE_NAME) == rn and cam.offset == Vector2.ZERO and CameraImpact.count == 1 and CameraImpact.telemetry()["cfx_active"] == true)
	var light := _ticks(rn, cam, 12)
	_print_trace("light", light)
	var lmax := 0.0
	for v in light:
		lmax = maxf(lmax, v.length())
	ck.call("impact scene: light kick - peak 2-3 screen px, already reached on the first tick, along +x only", lmax >= 2.0 and lmax <= 3.0 and _near(light[0].x, 2.5, 1e-4) and absf(light[0].y) < 1e-9, str(light[0]))
	ck.call("impact scene: light kick - zero from tick 5 (83 ms), offset == ZERO, no longer active, zoom == baseline", light[3].x > 0.0 and light[4] == Vector2.ZERO and light[11] == Vector2.ZERO and cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false and absf(cam.zoom.x - player.camera_baseline) < 1e-6)
	ck.call("impact scene: after the light kick the camera is exactly where it was (position, smoothing, limits, centre, zoom, baseline)", _snap(player) == pre)
	var pk := CameraImpact.peak_px
	ck.call("impact scene: telemetry peak is the light peak and the settled flag is set", pk >= 2.0 and pk <= 3.0 and CameraImpact.telemetry()["cfx_offset_x"] == 0.0 and CameraImpact.telemetry()["cfx_offset_y"] == 0.0, str(pk))

	# ---- heavy hit, north-west diagonal
	CameraImpact.heavy_hit(Vector2(-1.0, -1.0))
	var heavy := _ticks(rn, cam, 12)
	_print_trace("heavy", heavy)
	var hmax := 0.0
	for v in heavy:
		hmax = maxf(hmax, v.length())
	ck.call("impact scene: heavy kick - peak 4-6 screen px on the first tick, along the diagonal (-,-)", hmax >= 4.0 and hmax <= 6.0 and heavy[0].x < 0.0 and heavy[0].y < 0.0 and _near(heavy[0].x, heavy[0].y, 1e-4), str(heavy[0]))
	ck.call("impact scene: heavy kick - zero from tick 8 (133 ms), offset == ZERO, camera state identical", heavy[6].length() > 0.0 and heavy[7] == Vector2.ZERO and cam.offset == Vector2.ZERO and _snap(player) == pre and CameraImpact.count == 2)
	ck.call("impact scene: telemetry peak is per effect - the heavy peak replaced the light one", CameraImpact.peak_px >= 4.0 and CameraImpact.peak_px <= 6.0 and CameraImpact.peak_px > pk)

	# ---- three rapid heavy hits (50 ms apart, same direction)
	var rapid: Array[Vector2] = []
	for tick in 30:
		if tick == 0 or tick == 3 or tick == 6:
			CameraImpact.heavy_hit(Vector2.RIGHT)
		rn.advance(TICK)
		rapid.append(cam.offset * cam.zoom.x)
	var rmax := 0.0
	for v in rapid:
		rmax = maxf(rmax, v.length())
	ck.call("impact scene: three rapid heavy hits stay under MAX_TOTAL_PX, stack above a single hit, and end at exactly zero", rmax <= CameraImpact.MAX_TOTAL_PX + 1e-4 and rmax > CameraImpact.HEAVY_PEAK_PX and rapid[29] == Vector2.ZERO and cam.offset == Vector2.ZERO and _snap(player) == pre and CameraImpact.count == 5, str(rmax))
	# ---- 100 hits in one frame
	for i in 100:
		CameraImpact.heavy_hit(Vector2(cos(i), sin(i)))
	var alive := rn._list.size()
	var smax := 0.0
	for v in _ticks(rn, cam, 40):
		smax = maxf(smax, v.length())
	ck.call("impact scene: 100 hits in one frame keep at most MAX_ACTIVE impulses, stay under the cap and settle at exactly zero", alive <= CameraImpact.MAX_ACTIVE and smax <= CameraImpact.MAX_TOTAL_PX + 1e-4 and cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false and _snap(player) == pre and CameraImpact.count == 105, "%d %s" % [alive, smax])

	# ---- one 200 ms frame (a 5 FPS browser): the camera shows the end of the frame, the telemetry still records the peak
	CameraImpact.light_hit(Vector2.RIGHT)
	rn.advance(0.2)
	ck.call("impact scene: a single 200 ms frame - the effect is over (offset ZERO, settled) but the telemetry peak is the real light peak", cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false and CameraImpact.peak_px >= 2.0 and CameraImpact.peak_px <= 3.0 and _snap(player) == pre, str(CameraImpact.peak_px))
	rn.advance(1000.0)
	ck.call("impact scene: advancing with nonsense deltas (1000 s, NAN, negative) is harmless", cam.offset == Vector2.ZERO)
	rn.advance(NAN)
	rn.advance(-5.0)
	ck.call("impact scene: nan and negative deltas change nothing", cam.offset == Vector2.ZERO and _snap(player) == pre)

	# ---- bad inputs
	var c0 := CameraImpact.count
	CameraImpact.impulse(Vector2.RIGHT, 5.0, 0.0)
	CameraImpact.impulse(Vector2.RIGHT, 5.0, -10.0)
	CameraImpact.impulse(Vector2.RIGHT, -5.0, 100.0)
	CameraImpact.impulse(Vector2.RIGHT, 0.0, 100.0)
	CameraImpact.impulse(Vector2.RIGHT, NAN, 100.0)
	CameraImpact.impulse(Vector2.RIGHT, 5.0, INF)
	ck.call("impact scene: zero, negative and non-finite peak or duration are ignored (nothing counted, nothing moves)", CameraImpact.count == c0 and rn._list.is_empty() and cam.offset == Vector2.ZERO)
	CameraImpact.impulse(Vector2.ZERO, 5.0, 100.0)
	var zmax := 0.0
	for v in _ticks(rn, cam, 10):
		zmax = maxf(zmax, v.length())
	ck.call("impact scene: a zero direction is an accepted impulse (counted) with zero offset", CameraImpact.count == c0 + 1 and zmax == 0.0 and cam.offset == Vector2.ZERO)
	CameraImpact.impulse(Vector2(INF, 0.0), 5.0, 100.0)
	var imax := 0.0
	for v in _ticks(rn, cam, 10):
		imax = maxf(imax, v.length())
	ck.call("impact scene: a non-finite direction is treated as zero", imax == 0.0 and cam.offset == Vector2.ZERO)
	CameraImpact.impulse(Vector2.RIGHT, 5.0, 1.0e9)
	ck.call("impact scene: a huge duration is clamped to MAX_MS", _near(float(rn._list[0]["dur"]), CameraImpact.MAX_MS / 1000.0, 1e-9))
	for i in 6:
		rn.advance(1.0)
	ck.call("impact scene: ...and ends at exactly zero", cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false and _snap(player) == pre)

	# ---- freed mid-effect, disabled mid-effect
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn.advance(TICK)
	rn.advance(TICK)
	var moved := cam.offset != Vector2.ZERO
	rn.free()
	ck.call("impact scene: freeing the helper mid-effect puts the offset back to exactly ZERO at once", moved and cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false and cam.get_node_or_null(CameraImpact.NODE_NAME) == null and _snap(player) == pre)
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn = _manual(cam)
	rn.advance(TICK)
	rn.advance(TICK)
	var moved2 := cam.offset != Vector2.ZERO
	CameraImpact.settings.enabled = false
	rn.advance(TICK)
	ck.call("impact scene: disabling mid-effect zeroes the offset on the next step and stops the effect", moved2 and cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false and rn._list.is_empty())
	rn.free()

	# ---- disabled / scale 0 / reduced / scale above 1
	var c1 := CameraImpact.count
	CameraImpact.light_hit(Vector2.RIGHT)
	CameraImpact.heavy_hit(Vector2.RIGHT)
	ck.call("impact scene: disabled - no helper node is created, nothing is counted, the camera state is unchanged", cam.get_node_or_null(CameraImpact.NODE_NAME) == null and CameraImpact.count == c1 and _snap(player) == pre)
	CameraImpact.settings.enabled = true
	CameraImpact.settings.scale = 0.0
	CameraImpact.heavy_hit(Vector2.RIGHT)
	ck.call("impact scene: scale 0 is off - same as disabled", cam.get_node_or_null(CameraImpact.NODE_NAME) == null and CameraImpact.count == c1 and _snap(player) == pre)
	CameraImpact.settings.scale = 0.5
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn = _manual(cam)
	var half_trace := _ticks(rn, cam, 12)
	ck.call("impact scene: scale 0.5 (reduced) halves the heavy kick and still ends at exactly zero", _near(half_trace[0].x, CameraImpact.HEAVY_PEAK_PX * 0.5, 1e-4) and cam.offset == Vector2.ZERO and _snap(player) == pre)
	CameraImpact.settings.scale = 3.0
	CameraImpact.heavy_hit(Vector2.RIGHT)
	var over_trace := _ticks(rn, cam, 12)
	ck.call("impact scene: a scale above 1 is clamped to 1 (the setting can only soften the effect)", _near(over_trace[0].x, CameraImpact.HEAVY_PEAK_PX, 1e-4))
	CameraImpact.settings.scale = 1.0
	rn.free()

	# ---- edge clamp: all four limits (wide), kick toward the wall and away from it
	var spots: Array = [
		["east", Vector2(b.end.x - 30.0, 135.0), Vector2.RIGHT, Vector2.LEFT],
		["west", Vector2(b.position.x + 30.0, 135.0), Vector2.LEFT, Vector2.RIGHT],
		["north", Vector2(0.0, b.position.y + 30.0), Vector2.UP, Vector2.DOWN],
		["south", Vector2(0.0, b.end.y - 5.0), Vector2.DOWN, Vector2.UP],
	]
	for sp: Array in spots:
		var snap := await _settle(tree_root, player, sp[1])
		var toward: Vector2 = sp[2]
		CameraImpact.heavy_hit(toward)
		rn = _manual(cam)
		var worst_void := -INF
		var along := 0.0
		for i in 12:
			rn.advance(TICK)
			worst_void = maxf(worst_void, _void_px(cam))
			along = maxf(along, absf(cam.offset.dot(toward)))
		ck.call("impact edge (%s limit, wide): a heavy kick toward the wall never shows void and shrinks to 0 at the wall" % sp[0], worst_void <= 1e-3 and along < 1e-6, "void=%s along=%s" % [worst_void, along])
		CameraImpact.heavy_hit(sp[3])
		var away := 0.0
		worst_void = -INF
		for i in 12:
			rn.advance(TICK)
			worst_void = maxf(worst_void, _void_px(cam))
			away = maxf(away, (cam.offset * cam.zoom.x).length())
		ck.call("impact edge (%s limit, wide): a kick away from the wall still plays at full strength, inside the limits, and the camera comes back exactly" % sp[0], _near(away, 5.0, 1e-4) and worst_void <= 1e-3 and cam.offset == Vector2.ZERO and _snap(player) == snap, "away=%s void=%s" % [away, worst_void])
		rn.free()

	# ---- a little room left: 3 world px east of the view
	var room_x := cam.limit_right - 640.0 / cam.zoom.x - 3.0
	var snap_room := await _settle(tree_root, player, Vector2(room_x, 135.0))
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn = _manual(cam)
	var max_world_x := 0.0
	var room_void := -INF
	for i in 12:
		rn.advance(TICK)
		max_world_x = maxf(max_world_x, cam.offset.x)
		room_void = maxf(room_void, _void_px(cam))
	ck.call("impact edge: with 3 world px of room left a 5 px kick east shrinks to exactly 3 world px and never shows void", _near(max_world_x, 3.0, 1e-4) and room_void <= 1e-3 and cam.offset == Vector2.ZERO and _snap(player) == snap_room, "max=%s void=%s" % [max_world_x, room_void])
	rn.free()

	# ---- lab zoom step (native 1x): screen px stay screen px, the zoom is never touched
	pre = await _settle(tree_root, player, Vector2(0.0, 135.0))
	_press(lab, "dbg_toggle_lab")
	lab.set_zoom_index(1)
	var z1 := cam.zoom.x
	var pre_zoom := _snap(player)
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn = _manual(cam)
	rn.advance(TICK)
	ck.call("impact scene: at the lab's native step the kick is the same 5 SCREEN px (offset in world px = 5 / zoom), zoom untouched", z1 != wide and _near(cam.offset.x * z1, 5.0, 1e-4) and cam.zoom.x == z1, "zoom=%s offset=%s" % [z1, cam.offset])
	for i in 12:
		rn.advance(TICK)
	ck.call("impact scene: ...and after it the lab zoom step is exactly as it was", cam.zoom.x == z1 and cam.offset == Vector2.ZERO and _snap(player) == pre_zoom)
	rn.free()
	lab.set_zoom_index(0)
	ck.call("impact scene: the lab restores the baseline zoom as before", absf(cam.zoom.x - player.camera_baseline) < 1e-6 and absf(cam.zoom.x - wide) < 1e-6)

	# ---- preset switch (N) in the middle of an effect
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn = _manual(cam)
	rn.advance(TICK)
	rn.advance(TICK)
	_press(lab, AnimationLab.PRESET_ACTION)
	var close_zoom := cam.zoom.x
	rn.advance(TICK)
	var expect_px := CameraImpact.sample(rn._list, rn._clock).x
	ck.call("impact scene: a preset switch mid-effect - zoom follows the new baseline and the kick stays the same SCREEN px", CameraPreset.active_id() == "close" and absf(close_zoom - player.camera_baseline) < 1e-6 and close_zoom > wide and _near(cam.offset.x * close_zoom, expect_px, 1e-4), "px=%s expected=%s" % [cam.offset.x * close_zoom, expect_px])
	for i in 12:
		rn.advance(TICK)
	ck.call("impact scene: ...and it ends at exactly zero offset with the zoom on the new baseline", cam.offset == Vector2.ZERO and absf(cam.zoom.x - player.camera_baseline) < 1e-6 and CameraImpact.telemetry()["cfx_active"] == false)
	rn.free()
	_press(lab, AnimationLab.PRESET_ACTION)
	ck.call("impact scene: back on the wide preset", CameraPreset.active_id() == "wide" and absf(cam.zoom.x - wide) < 1e-6)
	_press(lab, "dbg_toggle_lab")  # close the lab again

	# ---- telemetry during the effect
	pre = await _settle(tree_root, player, Vector2(0.0, 135.0))
	var n0 := CameraImpact.count
	CameraImpact.heavy_hit(Vector2.RIGHT)
	rn = _manual(cam)
	rn.advance(TICK)
	var mid := CameraImpact.telemetry()
	ck.call("impact state: during the effect the telemetry says active, with the offset in screen px", mid["cfx_active"] == true and _near(mid["cfx_offset_x"], 5.0, 1e-4) and mid["cfx_offset_y"] == 0.0 and mid["cfx_enabled"] == true and mid["cfx_scale"] == 1.0 and mid["cfx_count"] == n0 + 1)
	for i in 12:
		rn.advance(TICK)
	var end := CameraImpact.telemetry()
	ck.call("impact state: afterwards it says settled, offset 0, and keeps the peak", end["cfx_active"] == false and end["cfx_offset_x"] == 0.0 and end["cfx_offset_y"] == 0.0 and _near(end["cfx_peak_px"], 5.0, 1e-4))
	rn.free()

	# ---- real frames, during LOCAL hitstop (the player's own timer; the helper runs on frame time)
	player._hitstop_timer = 3.0
	CameraImpact.heavy_hit(Vector2.UP)
	var saw_move := false
	var give_up := Time.get_ticks_msec() + 5000
	while CameraImpact.telemetry()["cfx_active"] and Time.get_ticks_msec() < give_up:
		await tree.process_frame
		saw_move = saw_move or cam.offset != Vector2.ZERO
	ck.call("impact real frames: during local hitstop the effect still runs on its own, moves the camera, and ends at exactly ZERO", saw_move and CameraImpact.telemetry()["cfx_active"] == false and cam.offset == Vector2.ZERO and player._hitstop_timer > 0.0 and CameraImpact.peak_px >= 4.0, "saw_move=%s hitstop=%s" % [saw_move, player._hitstop_timer])
	player._hitstop_timer = 0.0
	_free_runner(cam)
	ck.call("impact real frames: the camera is back exactly where it was", _snap(player) == pre)

	# ---- lab keys (7 light, 8 heavy, 9 burst, 0 slow) and the "Cam kick" buttons
	var key_ok := true
	var codes := {"dbg_camera_impact_light": KEY_7, "dbg_camera_impact_heavy": KEY_8, "dbg_camera_impact_burst": KEY_9, "dbg_camera_impact_slow": KEY_0}
	for a: String in codes:
		var seen := false
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == codes[a]:
				seen = true
		key_ok = key_ok and InputMap.has_action(a) and seen and AnimationLab.IMPACT_ACTIONS[a] == codes[a]
	var clash := false
	for a: String in InputMap.get_actions():
		if codes.has(a):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e as InputEventKey).physical_keycode in codes.values():
				clash = true
	ck.call("impact lab: the four demo actions exist on the digit keys 7 8 9 0 and no other action uses those physical keys", key_ok and not clash)
	var c2 := CameraImpact.count
	_press(lab, "dbg_camera_impact_light")
	ck.call("impact lab: with the lab CLOSED the demo keys do nothing", not lab.lab_on and CameraImpact.count == c2 and cam.get_node_or_null(CameraImpact.NODE_NAME) == null)
	_press(lab, "dbg_toggle_lab")
	_press(lab, "dbg_camera_impact_light")
	rn = _manual(cam)
	var item_l: Dictionary = rn._list[0]
	ck.call("impact lab: key 7 fires one light hit along the player's facing", CameraImpact.count == c2 + 1 and _near(item_l["peak"], CameraImpact.LIGHT_PEAK_PX) and _near(item_l["dur"], 0.08) and item_l["dir"] == player.facing8.normalized())
	rn.free()
	_press(lab, "dbg_camera_impact_heavy")
	rn = _manual(cam)
	var item_h: Dictionary = rn._list[0]
	ck.call("impact lab: key 8 fires one heavy hit", CameraImpact.count == c2 + 2 and _near(item_h["peak"], CameraImpact.HEAVY_PEAK_PX) and _near(item_h["dur"], 0.12))
	rn.free()
	_press(lab, "dbg_camera_impact_slow")
	rn = _manual(cam)
	var item_s: Dictionary = rn._list[0]
	ck.call("impact lab: key 0 fires the heavy kick stretched to 1500 ms (same peak, only the duration changes)", CameraImpact.count == c2 + 3 and _near(item_s["peak"], CameraImpact.HEAVY_PEAK_PX) and _near(item_s["dur"], 1.5))
	rn.advance(TICK)
	var slow_px := (cam.offset * cam.zoom.x).length()
	ck.call("impact lab: ...its first tick is the same 5 px peak as the heavy hit", _near(slow_px, 5.0, 1e-4))
	rn.free()
	ck.call("impact lab: the slow kick is gone when its helper is freed", cam.offset == Vector2.ZERO and _snap(player) == pre)
	var rows: Array = lab._panel.get_child(0).get_children()
	var kick_row: Node = rows[10]
	var btn_ok: bool = (rows[9].get_child(0) as Label).text == "Cam preset  N" and kick_row.get_child_count() == 5 and (kick_row.get_child(0) as Label).text.begins_with("Cam kick")
	var c3 := CameraImpact.count
	(kick_row.get_child(2) as Button).pressed.emit()
	ck.call("impact lab: the 'Cam kick' row sits after the preset row (rows 0-9 keep their places) and its heavy button fires a hit", btn_ok and CameraImpact.count == c3 + 1)
	_free_runner(cam)
	# burst: the first hit at once, two more 40 ms apart on real frames
	var c4 := CameraImpact.count
	_press(lab, "dbg_camera_impact_burst")
	var immediate := CameraImpact.count == c4 + 1
	give_up = Time.get_ticks_msec() + 5000
	while (CameraImpact.count < c4 + 3 or CameraImpact.telemetry()["cfx_active"]) and Time.get_ticks_msec() < give_up:
		await tree.process_frame
	ck.call("impact lab: key 9 starts a burst - one hit at once, three in total, peak under the cap, settled at exactly zero", immediate and CameraImpact.count == c4 + 3 and CameraImpact.peak_px <= CameraImpact.MAX_TOTAL_PX + 1e-4 and CameraImpact.peak_px >= 2.0 and cam.offset == Vector2.ZERO and CameraImpact.telemetry()["cfx_active"] == false, "count=%d peak=%s" % [CameraImpact.count, CameraImpact.peak_px])
	_free_runner(cam)
	ck.call("impact lab: opening and using the lab left the camera where it was", _snap(player) == pre)

	# ---- clean up
	main.queue_free()
	await tree.process_frame
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)
	CameraImpact.reset_all()


# ------------------------------------------------------------------ (c) a MOVING camera on real frames
## (void past the limits in world px, |offset| the camera really has in screen px, gap between the published and the written
## offset in screen px) of the frame that was just rendered.
func _frame_stats(cam: Camera2D) -> Vector3:
	var written := cam.offset * cam.zoom.x
	var shown := CameraImpact.telemetry()
	return Vector3(_void_px(cam), written.length(), (written - Vector2(shown["cfx_offset_x"], shown["cfx_offset_y"])).length())


## The player walks east at WALK_PX per frame, starting 400 world px before the point where the view reaches the east limit,
## with a heavy hit toward the wall every WALK_HIT_EVERY frames. The helper runs in its normal AUTOMATIC mode (nobody calls
## advance()). Camera2D.set_offset() runs the engine's camera update once more, which advances the position smoothing one extra
## step for the rendered view, so a clamp computed from the centre read BEFORE the write over-estimates the room while the
## camera glides into its pin and shows void at the screen edge. After EVERY frame the rendered view must be inside the limits.
func test_walking_into_wall(tree_root: Node, preset: String) -> void:
	var tree := tree_root.get_tree()
	CameraImpact.reset_all()
	var main := await _boot(tree_root, preset)
	var player := main.get_node("TrainingArena/Player") as PlayerController
	var arena := main.get_node("TrainingArena") as TrainingArena
	var cam := player.camera
	player.collision_mask = 0  # nothing may block or push the scripted walk
	for e in tree.get_nodes_in_group("enemy"):
		e.queue_free()
	await tree.process_frame
	var half_x := cam.get_viewport().get_visible_rect().size.x / cam.zoom.x * 0.5
	var x_stop := arena.get_bounds().end.x - 24.0  # the walk stays inside the arena: the camera is pinned long before this
	var pre := await _settle(tree_root, player, Vector2(cam.limit_right - half_x - 400.0, 135.0))
	var worst_void := -INF
	var max_written := 0.0
	var mismatch := 0.0
	var hits := 0
	var frames := 0
	var pin_frame := -1
	var pinned := 0
	while frames < WALK_MAX_FRAMES and pinned < WALK_PINNED_FRAMES:
		if frames % WALK_HIT_EVERY == 0:
			CameraImpact.heavy_hit(Vector2.RIGHT)
			hits += 1
		var at := player.global_position
		at.x = minf(at.x + WALK_PX, x_stop)
		player.global_position = at
		await tree.process_frame
		var s := _frame_stats(cam)
		worst_void = maxf(worst_void, s.x)
		max_written = maxf(max_written, s.y)
		mismatch = maxf(mismatch, s.z)
		if cam.limit_right - _view_rect(cam).end.x <= 0.001:
			pinned += 1
			if pin_frame < 0:
				pin_frame = frames
		frames += 1
	var give_up := Time.get_ticks_msec() + 5000
	while CameraImpact.telemetry()["cfx_active"] and Time.get_ticks_msec() < give_up:
		await tree.process_frame
		var s := _frame_stats(cam)
		worst_void = maxf(worst_void, s.x)
		max_written = maxf(max_written, s.y)
		mismatch = maxf(mismatch, s.z)
	var post := _snap(player)
	print("CFX_MOVING preset=%s zoom=%.4f frames=%d hits=%d pin_frame=%d worst_void=%.5f max_offset_px=%.3f peak_px=%.3f" % [preset, cam.zoom.x, frames, hits, pin_frame, worst_void, max_written, CameraImpact.peak_px])
	var info := "worst void=%s world px, pinned from frame %d of %d, %d hits, peak %s px" % [worst_void, pin_frame, frames, hits, CameraImpact.peak_px]
	ck.call("impact moving camera (%s): a heavy hit every 7th frame while the player walks into the east wall never shows void on any frame" % preset, worst_void <= 0.01 and pin_frame >= 0 and hits >= 10 and CameraImpact.peak_px >= 3.0, info)
	var settled: bool = cam.offset == Vector2.ZERO and not CameraImpact.telemetry()["cfx_active"] and absf(cam.zoom.x - player.camera_baseline) < 1e-6
	var untouched: bool = post["limits"] == pre["limits"] and post["smooth"] == pre["smooth"] and post["speed"] == pre["speed"] and post["base"] == pre["base"]
	ck.call("impact moving camera (%s): afterwards the offset is exactly ZERO, zoom == baseline, limits and smoothing untouched, and the published offset was the written one on every frame" % preset, settled and untouched and mismatch <= 1e-4 and CameraImpact.peak_px >= max_written - 1e-4, "offset=%s zoom=%s baseline=%s mismatch=%s peak=%s written=%s" % [cam.offset, cam.zoom.x, player.camera_baseline, mismatch, CameraImpact.peak_px, max_written])

	# ---- clean up
	main.queue_free()
	await tree.process_frame
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)
	CameraImpact.reset_all()
