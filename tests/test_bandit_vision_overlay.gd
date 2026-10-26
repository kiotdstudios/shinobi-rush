extends RefCounted
## Bandit vision debug overlay (order 2026-10-22-bandit-vision-debug-overlay). Runs against the real main scene: Aki's
## walls and rocks, the real Bandit, the real physics rays. The core is the ORACLE: for thousands of sampled player
## positions the drawn polygon (overlay.region_contains) must answer exactly what the AI's own Bandit.can_see answers,
## except inside a stated 1 px band at the very boundary, which is counted and printed. Everything else (state mapping,
## lifecycle, OFF = nothing, input untouched, cost) is checked around it. Called from tests/run_tests.gd.

const OKABE_ITO := ["#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7"]
const TOL := 1.0  ## px: the stated boundary band (BanditVisionRegion.BOUNDARY_TOL)
const CHASING := ["NOTICE", "APPROACH", "THREATEN", "ATTACK", "REPOSITION", "RETREAT"]  ## written here independently of the overlay
const PAUSED := ["EVADE", "HIT_REACT"]
const Cat := BanditVisionOverlay.Cat


## Runs after every other node's _process of the frame (priority 1000), i.e. right before the frame is drawn.
class LateProbe extends Node:
	var callback: Callable

	func _init() -> void:
		process_priority = 1000

	func _process(_delta: float) -> void:
		callback.call()


var ck: Callable
var tree: SceneTree
var rng := RandomNumberGenerator.new()
var main: Node
var arena: TrainingArena
var player: PlayerController
var bandit: Bandit
var lab: AnimationLab
var tog: BanditVisionToggle


func run(check: Callable, root: Node) -> void:
	ck = check
	tree = root.get_tree()
	rng.seed = 20261022
	BanditVisionToggle.reset_all()
	_test_state_mapping()
	_test_source_guards()
	_test_queries_and_dashes()
	if not await _boot(root):
		return
	await _test_off_by_default(root)
	await _test_key_and_button(root)
	await _test_geometry_box()
	await _test_oracle()
	await _test_ai_flag()
	await _test_sync_probe()
	await _test_moving()
	await _test_toggle_stress(root)
	await _test_isolation(root)
	await _test_cost()
	await _test_telemetry_and_web()
	await _test_lifecycle(root)
	await _shutdown(root)


# ------------------------------------------------------------------------------------------------ helpers
func _boot(root: Node) -> bool:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await tree.physics_frame
	arena = main.get_node_or_null("TrainingArena") as TrainingArena
	player = main.get_node_or_null("TrainingArena/Player") as PlayerController
	bandit = arena.get_node_or_null("Bandit") as Bandit if arena != null else null
	lab = main.get_node_or_null("AnimationLab") as AnimationLab
	tog = lab.vision if lab != null else null
	var ok := arena != null and player != null and bandit != null and lab != null and tog != null
	ck.call("vision: the real arena boots with the Bandit, the player, the lab and the vision switch", ok)
	if ok:
		bandit.profile["loot_sight"] = 0.0  # scavenging the layout gourds would walk him off the scripted vision scenarios
	if not ok:
		main.queue_free()
		await tree.process_frame
	return ok


func _shutdown(root: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	await tree.process_frame
	await tree.process_frame
	BanditVisionToggle.reset_all()
	ck.call("vision: the suite leaves no overlay node and the switch is back to its default OFF", _count_overlays(root) == 0 and not BanditVisionToggle.boot_on and not BanditVisionToggle.telemetry()["vision_on"])


func _snap8(k: int) -> Vector2:
	return WorldScale.snap8(Vector2.from_angle(float(k) * PI / 4.0))


func _put(pos: Vector2, face: Vector2, st: int) -> void:
	bandit.global_position = pos
	bandit.velocity = Vector2.ZERO
	bandit.facing8 = face
	bandit.state = st as Bandit.State
	bandit._player = player


func _count_overlays(n: Node) -> int:
	var c := 1 if n is BanditVisionOverlay else 0
	for ch in n.get_children():
		c += _count_overlays(ch)
	return c


func _name_of(st: int) -> String:
	return Bandit.State.keys()[st]


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _key_event(pressed: bool, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F2
	ev.keycode = KEY_F2
	ev.pressed = pressed
	ev.echo = echo
	return ev


## The test's own use_cone for a state (independent of BanditVisionRegion): cone only when the AI is neither chasing nor paused.
func _expected_cone(st: int) -> bool:
	var n := _name_of(st)
	return not (n in CHASING) and not (n in PAUSED)


# ------------------------------------------------------------------------------------------------ pure checks
func _test_state_mapping() -> void:
	var names: Array = Bandit.State.keys()
	ck.call("vision states: the overlay classifies EVERY Bandit.State explicitly (a new State fails this until it is classified)", BanditVisionOverlay.STATE_MAP.size() == names.size() and names.size() == 13, "%d listed of %d" % [BanditVisionOverlay.STATE_MAP.size(), names.size()])
	# [category when the AI does not see the player, category when it does]
	var expect := {
		"IDLE": [Cat.NOT_ALERT, Cat.NOT_ALERT], "PATROL": [Cat.NOT_ALERT, Cat.NOT_ALERT],
		"NOTICE": [Cat.SUSPICIOUS, Cat.SUSPICIOUS],
		"APPROACH": [Cat.LOST, Cat.DETECTED], "THREATEN": [Cat.LOST, Cat.DETECTED], "ATTACK": [Cat.LOST, Cat.DETECTED],
		"REPOSITION": [Cat.LOST, Cat.DETECTED], "RETREAT": [Cat.LOST, Cat.DETECTED],
		"EVADE": [Cat.LOST, Cat.DETECTED], "HIT_REACT": [Cat.LOST, Cat.DETECTED],
		"SEARCH": [Cat.SEARCHING, Cat.SEARCHING], "RETURN": [Cat.RETURNING, Cat.RETURNING],
		"DEAD": [BanditVisionOverlay.HIDDEN, BanditVisionOverlay.HIDDEN],
	}
	var map_ok := true
	var cone_ok := true
	var bad := ""
	for n: String in names:
		var st: int = Bandit.State[n]
		if not expect.has(n) or BanditVisionOverlay.category(st, false) != expect[n][0] or BanditVisionOverlay.category(st, true) != expect[n][1]:
			map_ok = false
			bad += n + " "
		if n != "DEAD" and BanditVisionRegion.uses_cone(st) != _expected_cone(st):
			cone_ok = false
			bad += n + "(cone) "
	ck.call("vision states: every Bandit.State maps to the brief's category (patrol/not alert, suspicious, detected only while seen, lost, searching, returning, hidden on DEAD)", map_ok, bad)
	ck.call("vision states: the cone is used exactly while the AI is not chasing (no cone in NOTICE APPROACH THREATEN ATTACK REPOSITION RETREAT, and in the sight-paused EVADE / HIT_REACT)", cone_ok, bad)
	# colour-blind safe palette, a different outline style per category, text per category
	var pal_ok := true
	for c: Color in BanditVisionOverlay.COLORS:
		pal_ok = pal_ok and OKABE_ITO.has("#" + c.to_html(false).to_upper())
	ck.call("vision legend: every colour is from the Okabe-Ito colour-blind-safe palette", pal_ok)
	var styles := {}
	var texts := {}
	for i in BanditVisionOverlay.KEYS.size():
		styles[str(BanditVisionOverlay.PATTERNS[i]) + "/" + str(BanditVisionOverlay.WIDTHS[i])] = true
		texts[BanditVisionOverlay.TEXTS[i]] = true
	ck.call("vision legend: the six categories each have their own outline style (pattern + width) and their own text", styles.size() == 6 and texts.size() == 6 and BanditVisionOverlay.KEYS.size() == 6 and BanditVisionOverlay.COLORS.size() == 6)
	var distinct_colors := {}
	for c: Color in BanditVisionOverlay.COLORS:
		distinct_colors[c.to_html(false)] = true
	ck.call("vision legend: five distinct colours (lost sight and searching share one and differ by line style and text)", distinct_colors.size() == 5)


func _test_source_guards() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/enemy/bandit.gd")
	ck.call("vision guard: scripts/enemy/bandit.gd is readable", src != "")
	var key := "var chasing := state in ["
	var i := src.find(key)
	var ai_names: Array[String] = []
	if i >= 0:
		var j := src.find("]", i)
		for part in src.substr(i + key.length(), j - i - key.length()).split(","):
			ai_names.append(part.strip_edges().trim_prefix("State."))
	var mine: Array[String] = []
	for st: int in BanditVisionRegion.CHASING_STATES:
		mine.append(_name_of(st))
	ai_names.sort()
	mine.sort()
	ck.call("vision guard: the chasing state list mirrored by the overlay equals Bandit._update_perception's list", ai_names == mine and mine.size() == 6, "ai=%s overlay=%s" % [str(ai_names), str(mine)])
	var mkey := "(1.0 if use_cone else "
	var mi := src.find(mkey)
	var mult := -1.0
	if mi >= 0:
		mult = src.substr(mi + mkey.length(), src.find(")", mi) - mi - mkey.length()).to_float()
	ck.call("vision guard: the chase reach multiplier mirrored by the overlay equals the literal in Bandit.can_see", is_equal_approx(mult, BanditVisionRegion.CHASE_REACH_MULT), "ai=%s overlay=%s" % [str(mult), str(BanditVisionRegion.CHASE_REACH_MULT)])
	var shape := src.contains("float(profile.sight_range) * (1.0 if use_cone else") and src.contains("if use_cone and d > float(profile.close_sense):") \
		and src.contains("var half := deg_to_rad(float(profile.fov_deg) * 0.5)") and src.contains("if absf(facing8.angle_to(to)) > half:")
	ck.call("vision guard: can_see still has the range / close-sense / half-FOV shape the polygon is built from", shape)
	var ray := src.contains("PhysicsRayQueryParameters2D.create(global_position + EYE_OFFSET, target + EYE_OFFSET)") \
		and src.contains("var excluded: Array[RID] = [get_rid()]") and src.contains("excluded.append((_player as CollisionObject2D).get_rid())") \
		and src.contains("return space.intersect_ray(q).is_empty()") and src.contains("q.exclude = excluded")
	var defaults := not src.contains("q.collision_mask") and not src.contains("q.collide_with_areas") and not src.contains("q.hit_from_inside") and not src.contains("q.collide_with_bodies")
	ck.call("vision guard: line_clear_to still casts eye-to-eye with the same exclusions and the DEFAULT mask / bodies only / no hit-from-inside, like the overlay's rays", ray and defaults)
	ck.call("vision guard: the Bandit still finds the player as the first node of group 'player' (the overlay excludes that one)", src.contains('var players := get_tree().get_nodes_in_group("player")') and src.contains("players[0]"))
	var pp := src.find("_find_player()\n\t_update_perception()")
	var ev := src.find("if state == State.EVADE:")
	var hr := src.find("if state == State.HIT_REACT:")
	ck.call("vision guard: perception still runs AFTER the EVADE / HIT_REACT branches return (sight is paused in those states)", pp > ev and ev >= 0 and pp > hr and hr >= 0)


func _test_queries_and_dashes() -> void:
	var cases := {
		"": false, "?": false, "?vision=1": true, "?a=b&vision=1": true, "?vision=1&a=b": true, "?vision=0": false, "?vision=10": false,
		"?vision=": false, "?vision": false, "?vision=1&vision=0": true, "?vision=0&vision=1": false, "?xvision=1": false,
		"?Vision=1": false, "?vision=%31": true, "?vision=true": false, "?vision=on": false, "?vision= 1": true,
	}
	var bad := ""
	for q: String in cases:
		if BanditVisionToggle.parse_query(q) != cases[q]:
			bad += "'%s' " % q
	ck.call("vision url: ?vision=1 (and only that) turns it on; first occurrence wins; garbage means off", bad == "", bad)
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var segs := BanditVisionOverlay.dash_segments(square, PackedFloat32Array([10.0, 10.0]))
	var on_len := 0.0
	var longest := 0.0
	for k in range(0, segs.size(), 2):
		var l := segs[k].distance_to(segs[k + 1])
		on_len += l
		longest = maxf(longest, l)
	ck.call("vision style: a 10/10 dash pattern covers half of a 400 px loop with dashes no longer than 10 px", absf(on_len - 200.0) < 11.0 and longest <= 10.01 and segs.size() % 2 == 0, "on=%.1f longest=%.2f" % [on_len, longest])
	var dot_dash := BanditVisionOverlay.dash_segments(square, PackedFloat32Array([20.0, 8.0, 4.0, 8.0]))
	var dd_on := 0.0
	for k in range(0, dot_dash.size(), 2):
		dd_on += dot_dash[k].distance_to(dot_dash[k + 1])
	ck.call("vision style: the dash-dot pattern covers 24 of every 40 px (the dot is a real, shorter segment)", absf(dd_on - 240.0) < 25.0, "on=%.1f" % dd_on)
	ck.call("vision style: degenerate inputs give no segments instead of an endless loop", BanditVisionOverlay.dash_segments(PackedVector2Array(), PackedFloat32Array([10.0, 10.0])).is_empty() and BanditVisionOverlay.dash_segments(square, PackedFloat32Array()).is_empty() and BanditVisionOverlay.dash_segments(square, PackedFloat32Array([0.0, 0.0])).is_empty())


# ------------------------------------------------------------------------------------------------ OFF by default
func _test_off_by_default(root: Node) -> void:
	ck.call("vision off: default OFF with no URL option and nothing pressed", not tog.on and tog.overlay == null and not BanditVisionToggle.boot_on)
	ck.call("vision off: no overlay node exists anywhere in the scene tree", _count_overlays(root) == 0)
	ck.call("vision off: the switch has no per-frame callback at all (it only reacts to its key and its button)", not tog.is_processing() and not tog.is_physics_processing())
	var before := BanditVisionRegion.compute_count
	await _frames(30)
	ck.call("vision off: 30 frames compute nothing (zero rebuilds, zero rays)", BanditVisionRegion.compute_count == before)
	var t := BanditVisionToggle.telemetry()
	ck.call("vision off: telemetry says off with every number zero and every string empty", t["vision_on"] == false and t["vision_bandits"] == 0 and t["vision_points"] == 0 and t["vision_rays"] == 0 and t["vision_state"] == "" and t["vision_ai_state"] == "" and t["vision_mismatch"] == 0)
	var b := tog.button
	ck.call("vision button: a toggle button exists in the Settings panel, labelled, OFF by default", b != null and b.is_inside_tree() and b.text == "Bandit vision: off" and not b.button_pressed, b.text if b != null else "null")
	ck.call("vision button: the Settings tab is visible on the bottom edge and the list is closed by default", lab.settings.tab.is_visible_in_tree() and not lab.settings.panel.visible and b.get_parent() == lab.settings.rows)
	lab.settings.tab.button_pressed = true
	ck.call("vision button: clicking the Settings tab opens the list and the button is then visible", lab.settings.panel.visible and b.is_visible_in_tree())
	lab.settings.tab.button_pressed = false
	ck.call("vision button: clicking the Settings tab again closes the list", not lab.settings.panel.visible)
	ck.call("vision button: focus_mode NONE so Space / Enter stay with the game", b.focus_mode == Control.FOCUS_NONE)


# ------------------------------------------------------------------------------------------------ key and button
func _test_key_and_button(root: Node) -> void:
	ck.call("vision hotkey: none - no action dbg_bandit_vision exists and the toggle has no key handler", not InputMap.has_action("dbg_bandit_vision") and not tog.is_processing_unhandled_input())
	var any_f_key := false
	for a: String in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e as InputEventKey).physical_keycode in [KEY_F1, KEY_F2, KEY_F3]:
				any_f_key = true
	ck.call("vision hotkey: no action is bound to F1, F2 or F3 any more", not any_f_key)
	Input.parse_input_event(_key_event(true))
	await _frames(2)
	ck.call("vision hotkey: pressing F2 through the input pipeline does nothing", not tog.on and tog.overlay == null and _count_overlays(root) == 0)
	Input.parse_input_event(_key_event(false))
	await _frames(1)
	# the button
	tog.button.button_pressed = true
	await _frames(2)
	ck.call("vision button: pressing it turns the overlay ON (works without opening the lab)", tog.on and tog.overlay != null and not lab.lab_on and tog.button.text == "Bandit vision: ON")
	tog.button.button_pressed = false
	await _frames(1)
	ck.call("vision button: pressing it again turns it OFF and frees the overlay", not tog.on and tog.overlay == null and _count_overlays(root) == 0)
	# the key and the button stay in step in any order
	tog.toggle()
	ck.call("vision button: a toggle by code is mirrored in the button", tog.button.button_pressed and tog.on)
	tog.set_on(false)
	ck.call("vision key: set_on(false) is idempotent and leaves nothing behind", not tog.on and tog.overlay == null and not tog.button.button_pressed)
	tog.set_on(false)
	ck.call("vision key: switching OFF twice is harmless", tog.overlay == null)


# ------------------------------------------------------------------------------------------------ geometry truth
## A box of known size in the live physics world: the polygon edge must follow its front face exactly, its corners must
## sit on the true shadow edges, and the shadow edge must be right to well under a pixel 500 px away. Expected values are
## computed from the box rectangle, not from the AI.
func _test_geometry_box() -> void:
	var box := StaticBody2D.new()
	box.name = "VisionTestBox"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(1500, 500)
	box.add_child(col)
	arena.add_child(box)
	await tree.physics_frame
	await tree.physics_frame
	var pos := Vector2(1250, 500)
	_put(pos, _snap8(0), Bandit.State.PATROL)
	player.global_position = Vector2(0, 135)
	var reg := BanditVisionRegion.compute(bandit, player)
	var eye := pos + Bandit.EYE_OFFSET
	var top_c := Vector2(1400, 400)
	var bot_c := Vector2(1400, 600)
	var a_top := (top_c - eye).angle()
	var a_bot := (bot_c - eye).angle()
	var face_pts := 0
	var face_ok := true
	var worst_x := 0.0
	for v in reg.points:
		var t := (v - pos).angle()
		if t > a_top + deg_to_rad(0.3) and t < a_bot - deg_to_rad(0.3):
			face_pts += 1
			worst_x = maxf(worst_x, absf(v.x - 1400.0))
			if absf(v.x - 1400.0) > 0.05:
				face_ok = false
	ck.call("vision geometry: every polygon vertex between the box's shadow edges lies exactly on its front face (x = 1400)", face_ok and face_pts >= 5, "%d vertices, worst |dx| %.4f" % [face_pts, worst_x])
	var near_top := 1.0e9
	var near_bot := 1.0e9
	for v in reg.points:
		near_top = minf(near_top, v.distance_to(top_c - Bandit.EYE_OFFSET))
		near_bot = minf(near_bot, v.distance_to(bot_c - Bandit.EYE_OFFSET))
	ck.call("vision geometry: the polygon has a vertex on each front corner of the box (bisection found the silhouette), within 0.2 px", near_top < 0.2 and near_bot < 0.2, "top %.3f bottom %.3f" % [near_top, near_bot])
	ck.call("vision geometry: just in front of the face is seen, just behind it is not (and both equal the AI)",
		reg.contains(Vector2(1397, 500)) and not reg.contains(Vector2(1403, 500)) and bandit.can_see(Vector2(1397, 500), true) and not bandit.can_see(Vector2(1403, 500), true))
	ck.call("vision geometry: the box's shadow is not seen (a point 20 px behind its centre), like the AI", not reg.contains(Vector2(1520, 500)) and not bandit.can_see(Vector2(1520, 500), true))
	# shadow edges 300 px out, 0.5 px either side of the exact edge line
	var edge_ok := true
	var info := ""
	for corner: Vector2 in [top_c, bot_c]:
		var to := corner - eye
		var dist := to.length()
		var dir := to / dist
		var perp := Vector2(-dir.y, dir.x)
		var q := eye + dir * 300.0
		var p_plus := q + perp * 0.5 - Bandit.EYE_OFFSET
		var p_minus := q - perp * 0.5 - Bandit.EYE_OFFSET
		var in_plus := reg.contains(p_plus)
		var in_minus := reg.contains(p_minus)
		var ai_plus := bandit.can_see(p_plus, true)
		var ai_minus := bandit.can_see(p_minus, true)
		info += "[%s: poly %s/%s ai %s/%s] " % [str(corner), str(in_plus), str(in_minus), str(ai_plus), str(ai_minus)]
		if in_plus == in_minus or in_plus != ai_plus or in_minus != ai_minus:
			edge_ok = false
	ck.call("vision geometry: 300 px out, points 0.5 px either side of each exact shadow edge are classified like the AI (one seen, one hidden)", edge_ok, info)
	var uncapped := not reg.capped and reg.rays_cast <= BanditVisionRegion.MAX_RAYS
	ck.call("vision geometry: the whole polygon cost %d rays (refinement budget %d), nothing capped" % [reg.rays_cast, BanditVisionRegion.MAX_RAYS], uncapped)
	box.queue_free()
	await tree.physics_frame
	await tree.physics_frame
	_put(pos, _snap8(0), Bandit.State.PATROL)  # the AI ticked meanwhile: put it back exactly where the box test stood
	var gone := BanditVisionRegion.compute(bandit, player)
	ck.call("vision geometry: with the box gone the same spot is seen again (the polygon follows the world, not a cache)", gone.contains(Vector2(1520, 500)) and bandit.can_see(Vector2(1520, 500), true))
	_put(WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL)


# ------------------------------------------------------------------------------------------------ THE ORACLE
func _oracle_points(pos: Vector2, face: Vector2, reach: float, prof: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var close: float = float(prof.close_sense)
	var half := deg_to_rad(float(prof.fov_deg) * 0.5)
	var eye := pos + Bandit.EYE_OFFSET
	for i in 70:  # inside and outside the range, all around
		out.append(pos + Vector2.from_angle(rng.randf() * TAU) * (rng.randf() * reach * 1.25))
	for k in 24:  # the max-range edge, just inside and just outside
		var d := Vector2.from_angle(TAU * float(k) / 24.0 + 0.05)
		for dr: float in [-3.0, -0.5, 0.5, 3.0]:
			out.append(pos + d * (reach + dr))
		for dr2: float in [-3.0, 3.0]:  # the close-sense circle
			out.append(pos + d * (close + dr2))
	for sgn: float in [-1.0, 1.0]:  # the cone edges, just inside and just outside
		for da: float in [-1.0, -0.2, 0.2, 1.0]:
			for r: float in [close + 25.0, 300.0, 520.0, reach - 15.0]:
				out.append(pos + face.rotated(sgn * (half + deg_to_rad(da))) * r)
	for k in 12:  # behind and beside the facing
		var a := PI + (float(k) - 5.5) * 0.35
		for r2: float in [close - 20.0, close + 20.0, 350.0]:
			out.append(pos + face.rotated(a) * r2)
	for r3: float in [80.0, 250.0, 450.0, reach - 20.0, reach + 20.0]:  # straight ahead
		out.append(pos + face * r3)
	for b: Array in WorldScale.BLOCKS:  # behind every wall: on and around the shadow edge through each corner
		var bp: Vector2 = b[0]
		var fp: Vector2 = b[1]
		var rect := Rect2(bp.x - fp.x * 0.5, bp.y - fp.y, fp.x, fp.y)
		for c: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			var to := c - eye
			var dist := to.length()
			if dist < 1.0 or dist > reach * 1.3:
				continue
			var dir := to / dist
			var perp := Vector2(-dir.y, dir.x)
			for s: float in [20.0, 120.0, 350.0]:
				for o: float in [-40.0, -3.0, -0.4, 0.4, 3.0, 40.0]:
					out.append(eye + dir * (dist + s) + perp * o - Bandit.EYE_OFFSET)
		var tc := rect.get_center() - eye
		if tc.length() > 1.0 and tc.length() < reach * 1.3:
			for s2: float in [60.0, 200.0]:
				out.append(eye + tc.normalized() * (tc.length() + s2) - Bandit.EYE_OFFSET)
	return out


## How far p is from the AI's own decision boundary: the smallest probe radius (px) at which can_see changes somewhere around p.
func _boundary_distance(p: Vector2, cone: bool) -> float:
	for tol: float in [0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1.0]:
		if BanditVisionRegion.near_ai_boundary(bandit, p, cone, tol):
			return tol
	return 99.0


func _test_oracle() -> void:
	tog.set_on(true)
	await _frames(2)
	var ov := tog.overlay
	ov.log_mismatches = false
	var spots: Array = [
		[WorldScale.BANDIT_HOME, [0, 1, 2, 3, 4, 5, 6, 7]],  # the Bandit's home, open ground, rocks 7 and 8 near
		[Vector2(1090, 80), [0, 2, 4, 6]],  # the east mouth of the choke, rock 7 to the north east
		[Vector2(975, -300), [0, 1, 2, 3, 4, 5, 6, 7]],  # hugging the east face of the north wall
		[Vector2(1500, 300), [0, 3, 5]],  # open ground, south east
		[Vector2(1700, 900), [0, 2, 4, 6]],  # near the south east bounds walls
		[Vector2(700, 60), [0, 4]],  # west of the walls, looking through / into them
		[Vector2(0, -400), [2, 6]],  # below block 4, the player's side
		[Vector2(-1850, 950), [1, 5]],  # the far south west corner, bounds walls close
		[Vector2(1380, 60), [4]],  # a patrol point, rock 7 close to the west
	]
	var states: Array = [Bandit.State.PATROL, Bandit.State.APPROACH, Bandit.State.NOTICE, Bandit.State.SEARCH, Bandit.State.RETURN, Bandit.State.EVADE]
	var total := 0
	var seen := 0
	var band := 0
	var bad := 0
	var cone_flag_bad := 0
	var capped := 0
	var max_rays := 0
	var first_bad := ""
	var configs := 0
	var worst_band := 0.0
	var per_state := {}
	for spot: Array in spots:
		for fi: int in spot[1]:
			for st: int in states:
				_put(spot[0], _snap8(fi), st)
				ov.refresh()
				configs += 1
				var cone := _expected_cone(st)
				var v: Dictionary = ov.views[0]
				var reg: BanditVisionRegion = v["region"]
				if reg.use_cone != cone:
					cone_flag_bad += 1
				if reg.capped:
					capped += 1
				max_rays = maxi(max_rays, reg.rays_cast)
				var counts: Array = per_state.get(_name_of(st), [0, 0, 0])
				for p in _oracle_points(spot[0], _snap8(fi), reg.reach, bandit.profile):
					var ai := bandit.can_see(p, cone)
					var drawn := ov.region_contains(p)
					total += 1
					counts[0] += 1
					if ai:
						seen += 1
						counts[1] += 1
					if ai != drawn:
						if BanditVisionRegion.near_ai_boundary(bandit, p, cone, TOL):
							band += 1
							counts[2] += 1
							worst_band = maxf(worst_band, _boundary_distance(p, cone))
						else:
							bad += 1
							if first_bad == "":
								first_bad = "bandit %s facing %s state %s p=%s ai=%s drawn=%s" % [str(spot[0]), str(_snap8(fi)), _name_of(st), str(p), str(ai), str(drawn)]
				per_state[_name_of(st)] = counts
	print("ORACLE configs=%d points=%d seen_by_ai=%d not_seen=%d | exceptions inside the %.1f px band=%d (worst %.2f px from the AI's boundary) | disagreements outside the band=%d | max rays per rebuild=%d capped=%d" % [configs, total, seen, total - seen, TOL, band, worst_band, bad, max_rays, capped])
	for sname: String in per_state:
		print("ORACLE   mode %-9s points=%d seen=%d band_exceptions=%d" % [sname, per_state[sname][0], per_state[sname][1], per_state[sname][2]])
	ck.call("vision oracle: at least 2000 sampled player positions were compared (%d, %d configurations)" % [total, configs], total >= 2000)
	ck.call("vision oracle: overlay.region_contains(p) == bandit.can_see(p, use_cone) for EVERY sample outside the 1 px band (0 disagreements)", bad == 0, "%d of %d: %s" % [bad, total, first_bad])
	ck.call("vision oracle: the exceptions inside the stated 1 px boundary band are at most 0.1%% of the samples (%d of %d, the worst one %.2f px from the AI's own boundary)" % [band, total, worst_band], band * 1000 <= total)
	ck.call("vision oracle: not vacuous - the AI sees and does not see a large share of the samples, in every mode", seen > total / 20 and total - seen > total / 5 and per_state.size() == 6 and per_state.values().all(func(c: Array) -> bool: return c[1] > 100 and c[0] - c[1] > 100))
	ck.call("vision oracle: the overlay picked cone / no-cone exactly as the test's own table for all %d configurations" % configs, cone_flag_bad == 0)
	ck.call("vision oracle: no rebuild in the real arena reached the %d-ray refinement budget (max %d rays used)" % [BanditVisionRegion.MAX_RAYS, max_rays], capped == 0 and max_rays <= BanditVisionRegion.MAX_RAYS)
	ck.call("vision oracle: the overlay's own runtime sync check (polygon vs can_see at the player and on the facing ray) found no disagreement in all those rebuilds", ov.mismatches == 0, str(ov.mismatches))


# ------------------------------------------------------------------------------------------------ the AI's own flag
## For every Bandit.State and several player places: the AI's OWN sees_player (its own _update_perception, in that state)
## must equal "the drawn polygon contains the player". Proves the cone / no-cone switch against the real AI code path.
func _test_ai_flag() -> void:
	var ov := tog.overlay
	var west := _snap8(4)
	var home := Vector2(1500, 100)  # open ground; along y=100 the choke gap and the walls leave a clear line
	var cases: Array = [
		["ahead 500 px: beyond the cone reach 450, inside the chase reach 540", home, Vector2(1000, 100), "chase_only"],
		["ahead 250 px", home, Vector2(1250, 100), "both"],
		["ahead 1000 px: beyond everything", home, Vector2(500, 100), "never"],
		["behind 250 px: outside the cone, beyond close sense", home, Vector2(1750, 100), "chase_only"],
		["behind 60 px: inside close sense", home, Vector2(1560, 100), "both"],
		["north wall between them, 320 px", Vector2(1100, -300), Vector2(780, -300), "never"],
	]
	var mism := 0
	var rows := 0
	var table_bad := ""
	var first := ""
	for c: Array in cases:
		for n: String in Bandit.State.keys():
			var st: int = Bandit.State[n]
			if n == "DEAD":
				continue
			_put(c[1], west, st)
			player.global_position = c[2]
			ov.refresh()
			var drawn := ov.region_contains(c[2])
			# the AI evaluates sight in its own state; EVADE / HIT_REACT never do and always continue as APPROACH
			bandit.state = (Bandit.State.APPROACH if n in PAUSED else st) as Bandit.State
			bandit._update_perception()
			var ai := bandit.sees_player
			bandit.state = st as Bandit.State
			rows += 1
			if ai != drawn:
				mism += 1
				if first == "":
					first = "%s | state %s | ai flag %s drawn %s" % [String(c[0]), n, str(ai), str(drawn)]
			var chasing_mode := (n in CHASING) or (n in PAUSED)
			var want: bool = (c[3] == "both") or (c[3] == "chase_only" and chasing_mode)
			if ai != want:
				table_bad += "%s/%s " % [String(c[0]).substr(0, 12), n]
	ck.call("vision AI flag: the AI's own sees_player equals 'polygon contains the player' for all %d (state x place) rows" % rows, mism == 0 and rows == 6 * 12, "%d mismatches, first: %s" % [mism, first])
	ck.call("vision AI flag: and those AI answers match the documented table (cone-only reach 450 / close sense 70 / chase reach 540 / walls block)", table_bad == "", table_bad)
	_put(WorldScale.BANDIT_HOME, west, Bandit.State.DEAD)
	ov.refresh()
	ck.call("vision AI flag: a DEAD Bandit has no view at all", ov.views.is_empty() and BanditVisionToggle.telemetry()["vision_bandits"] == 0)
	_put(WorldScale.BANDIT_HOME, west, Bandit.State.PATROL)
	ov.refresh()
	ck.call("vision AI flag: ...and it returns when the Bandit is alive again", ov.views.size() == 1)


# ------------------------------------------------------------------------------------------------ sync probe
func _test_sync_probe() -> void:
	var ov := tog.overlay
	# a ray budget too small to refine the silhouettes is reported, never hidden
	_put(Vector2(975, -300), _snap8(4), Bandit.State.APPROACH)  # hugging the north wall: many silhouettes
	var full := BanditVisionRegion.compute(bandit, player)
	var starved := BanditVisionRegion.compute(bandit, player, BanditVisionRegion.CHASE_REACH_MULT, 110)
	_put(Vector2(600, 100), _snap8(4), Bandit.State.PATROL)  # nothing within 700 px ahead (clear of walls and tree trunks): the range arc is all there is
	var open_spot := BanditVisionRegion.compute(bandit, player, BanditVisionRegion.CHASE_REACH_MULT, 140)
	ck.call("vision budget: a starved ray budget (110) sets `capped` where silhouettes need more rays (the label and vision_capped then say so); the full budget does not", starved.capped and not full.capped and full.rays_cast > 110 and starved.rays_cast < full.rays_cast, "full %d rays capped=%s, starved %d rays capped=%s" % [full.rays_cast, str(full.capped), starved.rays_cast, str(starved.capped)])
	ck.call("vision budget: open ground needs no refinement, so even the starved budget is not capped (base fan only)", not open_spot.capped and open_spot.rays_cast <= 90)
	ov.log_mismatches = false
	_put(Vector2(1500, 100), _snap8(4), Bandit.State.APPROACH)
	player.global_position = Vector2(1150, 100)  # 350 px ahead: seen only with the true 1.2 chase reach
	ov.refresh()
	var before := ov.mismatches
	ck.call("vision sync: with the true numbers the probe and the player check agree with the AI", ov.views[0]["sync"] == "" and ov.mismatches == before)
	ov.reach_mult = 1.0  # simulate an overlay whose chase multiplier is wrong
	ov.refresh()
	var msg: String = ov.views[0]["sync"]
	ck.call("vision sync: a wrong chase multiplier is caught at run time, counted and described with exact numbers", msg != "" and ov.mismatches > before and msg.contains("can_see"), msg)
	ck.call("vision sync: ...and published (telemetry vision_mismatch)", int(BanditVisionToggle.telemetry()["vision_mismatch"]) == ov.mismatches)
	# the discrepancy log: one exact line per kind, however many frames the disagreement lasts
	var logged: Array[String] = []
	ov.log_sink = func(line: String) -> void: logged.append(line)
	ov.log_mismatches = true
	ov.reach_mult = 1.0
	for i in 20:
		ov.refresh()
	ov.log_mismatches = false
	ov.log_sink = Callable()
	ck.call("vision sync: 20 rebuilds of a persistent disagreement log it ONCE, with one exact line naming bandit.gd:236, the State, facing and position (no log spam)", logged.size() == 1 and logged[0].contains("bandit.gd:236") and logged[0].contains("state=APPROACH") and logged[0].contains("facing=(-1.0, 0.0)") and logged[0].contains("pos=(1500.0, 100.0)") and ov.mismatches >= 20, str(logged) + " mismatches=" + str(ov.mismatches))
	ov.reach_mult = BanditVisionRegion.CHASE_REACH_MULT
	ov.mismatches = 0
	ov.refresh()
	ck.call("vision sync: restoring the multiplier clears the disagreement", ov.views[0]["sync"] == "" and ov.mismatches == 0)
	var wrong := BanditVisionRegion.compute(bandit, player, 1.0)
	ck.call("vision sync: the region API also reports it (sync_probe returns one exact line)", wrong.sync_probe(bandit) != "" and BanditVisionRegion.compute(bandit, player).sync_probe(bandit) == "")
	_put(WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL)
	player.global_position = Vector2(0, 135)


# ------------------------------------------------------------------------------------------------ real frames, real movement
func _test_moving() -> void:
	var ov := tog.overlay
	ov.log_mismatches = false
	ov.mismatches = 0
	bandit.seed_rng(7)
	bandit.set_intelligence_level(1)
	bandit.state = Bandit.State.PATROL
	bandit.global_position = WorldScale.BANDIT_HOME
	bandit.patrol_points = PackedVector2Array(WorldScale.BANDIT_PATROL)
	bandit.set_home(WorldScale.BANDIT_HOME)
	bandit.sees_player = false
	player.global_position = Vector2(700, 150)  # west of the walls, level with the choke; y=150 clears rock 7 (its south face is y=40)
	player.velocity = Vector2.ZERO
	player.reset_camera()
	var stats := {"frames": 0, "stale": 0, "player_stale": 0, "pre_draw_empty": 0}
	var on_pre_draw := func() -> void:
		stats["frames"] += 1
		if ov.views.is_empty():
			stats["pre_draw_empty"] += 1
			return
		var v: Dictionary = ov.views[0]
		var r: BanditVisionRegion = v["region"]
		# what is about to be drawn must be the Bandit where it is NOW, facing where it faces NOW, in its state NOW
		if not r.origin.is_equal_approx(bandit.global_position) or r.facing != bandit.facing8 or int(v["state"]) != int(bandit.state):
			stats["stale"] += 1
		if bool(v["sees"]) and not (v["player"] as Vector2).is_equal_approx(player.global_position):
			stats["player_stale"] += 1
	# The last _process of every rendered frame (priority 1000): nothing moves between it and the draw, so it sees what is drawn.
	var late := LateProbe.new()
	late.callback = on_pre_draw
	main.add_child(late)
	var cones := {}
	var facings := {}
	var states := {}
	var run := 0
	var max_run := 0
	var disagree := 0
	var flips := 0
	var last_sees := false
	var steps := 0
	var moved_bandit := 0.0
	var start_bandit := bandit.global_position
	var cam_start := player.camera.get_screen_center_position()
	var cam_moved := 0.0
	var trace := ""
	for tick in 420:
		# east through the choke for 170 ticks, then back west, then east again: the player really moves on every tick
		var phase := floori(float(tick) / 170.0) % 2
		Input.action_press("move_right" if phase == 0 else "move_left")
		Input.action_release("move_left" if phase == 0 else "move_right")
		if phase == 1:
			Input.action_press("sprint")  # run away: faster than the Bandit's chase, so it loses the player behind the walls
		else:
			Input.action_release("sprint")
		await tree.physics_frame
		await tree.process_frame
		steps += 1
		if ov.views.is_empty():
			continue
		var v2: Dictionary = ov.views[0]
		var r2: BanditVisionRegion = v2["region"]
		cones[r2.use_cone] = true
		facings[r2.facing] = true
		states[String(v2["state_name"])] = true
		moved_bandit = maxf(moved_bandit, bandit.global_position.distance_to(start_bandit))
		cam_moved = maxf(cam_moved, player.camera.get_screen_center_position().distance_to(cam_start))
		var sees: bool = v2["sees"]
		if tick % 30 == 0:
			trace += "[t%d %s %s bandit(%d,%d) player(%d,%d) sees=%s in=%s] " % [tick, String(v2["state_name"]), "cone" if r2.use_cone else "circle", bandit.global_position.x, bandit.global_position.y, player.global_position.x, player.global_position.y, str(sees), str(v2["player_in"])]
		if sees != last_sees:
			flips += 1
			last_sees = sees
		if sees != bool(v2["player_in"]):
			disagree += 1
			run += 1
			max_run = maxi(max_run, run)
		else:
			run = 0
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("sprint")
	late.free()
	print("MOVING ticks=%d rendered_frames=%d stale_pre_draw=%d player_marker_stale=%d | bandit travelled %.0f px, camera centre travelled %.0f px | states %s | cone modes %s | facings %d | sees flips %d | frames where AI flag and polygon differ=%d (longest run %d ticks) | overlay sync mismatches=%d" % [
		steps, stats["frames"], stats["stale"], stats["player_stale"], moved_bandit, cam_moved, str(states.keys()), str(cones.keys()), facings.size(), flips, disagree, max_run, ov.mismatches])
	print("MOVING trace ", trace)
	ck.call("vision moving: about to be drawn, the polygon is always on the Bandit's CURRENT position, facing and state (0 stale frames of %d rendered)" % stats["frames"], stats["frames"] >= 100 and stats["stale"] == 0 and stats["pre_draw_empty"] == 0, str(stats))
	ck.call("vision moving: the player marker is always on the player's current position while the AI sees them (camera following, 0 stale)", stats["player_stale"] == 0)
	ck.call("vision moving: the scenario really moved things - the Bandit walked, the camera followed the player, the cone turned (>= 3 facings)", moved_bandit > 150.0 and cam_moved > 300.0 and facings.size() >= 3)
	ck.call("vision moving: the scenario crossed the cone / no-cone switch and several AI states (patrol, notice, chase, dodge, threaten) while the AI started to see the player", cones.size() == 2 and states.size() >= 3 and flips >= 1, "cones=%s states=%s flips=%d" % [str(cones.keys()), str(states.keys()), flips])
	ck.call("vision moving: the AI's flag and the polygon differ only for a moment (never more than 3 consecutive ticks: the AI samples once per physics tick before it moves)", max_run <= 3, "max run %d, %d frames" % [max_run, disagree])
	ck.call("vision moving: the runtime sync check found no disagreement with can_see in %d moving ticks" % steps, ov.mismatches == 0, str(ov.mismatches))
	player.global_position = Vector2(0, 135)
	player.velocity = Vector2.ZERO
	_put(WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL)
	bandit.patrol_points = PackedVector2Array(WorldScale.BANDIT_PATROL)
	bandit.set_home(WorldScale.BANDIT_HOME)
	bandit.sees_player = false


# ------------------------------------------------------------------------------------------------ rapid toggles
## Footstep dust puffs (and their tweens) from player activity come and go mid-test; they are not what this
## test measures, so drop them before each node/object-count reading.
func _clear_dust(root: Node) -> void:
	for d in root.find_children("DustPuff", "", true, false):
		for c in d.get_children():
			c.free()


func _test_toggle_stress(root: Node) -> void:
	tog.set_on(false)
	_clear_dust(root)
	await _frames(3)
	var base_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var base_objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:  # 100 ON / OFF pairs inside ONE frame
		tog.set_on(true)
		tog.set_on(false)
	ck.call("vision toggles: 100 ON/OFF pairs in a single frame leave no node behind (not even pending a free)", not tog.on and tog.overlay == null and _count_overlays(root) == 0 and Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == base_nodes)
	tog.set_on(true)
	await _frames(2)
	var on_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var items_on := tog.overlay.draw_items
	for i in 100:  # 100 ON / OFF pairs with real frames in between
		tog.toggle()
		await tree.process_frame
		tog.toggle()
		await tree.process_frame
	await _frames(2)
	ck.call("vision toggles: after 100 real-frame ON/OFF cycles ending ON there is still exactly one overlay and the same node count (+-2 for unrelated engine nodes; a leak would add 100)", tog.on and _count_overlays(root) == 1 and absf(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - on_nodes) <= 2.0)
	ck.call("vision toggles: ...and the same number of draw items as before (%d)" % items_on, tog.overlay.draw_items == items_on and items_on > 0, "%d vs %d" % [tog.overlay.draw_items, items_on])
	tog.set_on(false)
	_clear_dust(root)
	await _frames(2)
	ck.call("vision toggles: OFF again - node count and object count are back to the baseline within +-2 / +-8 (no leaked regions or overlays: a leak would add 100)", _count_overlays(root) == 0 and absf(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - base_nodes) <= 2.0 and absf(Performance.get_monitor(Performance.OBJECT_COUNT) - base_objs) <= 8.0, "nodes %s vs %s, objects %s vs %s" % [str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), str(base_nodes), str(Performance.get_monitor(Performance.OBJECT_COUNT)), str(base_objs)])
	var before := BanditVisionRegion.compute_count
	await _frames(30)
	ck.call("vision toggles: OFF computes nothing in 30 frames", BanditVisionRegion.compute_count == before)


# ------------------------------------------------------------------------------------------------ input / camera / panels
func _walk_x(frames: int) -> float:
	player.global_position = Vector2(-600, 200)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	for i in frames:
		await tree.physics_frame
	Input.action_release("move_right")
	var x := player.global_position.x
	await tree.physics_frame
	return x


func _cam_snap() -> Dictionary:
	var cam := player.camera
	return {"pos": cam.position, "smooth": cam.position_smoothing_enabled, "speed": cam.position_smoothing_speed, "zoom": cam.zoom,
		"limits": [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom], "offset": cam.offset, "base": player.camera_baseline}


func _test_isolation(root: Node) -> void:
	tog.set_on(false)
	await _frames(2)
	var x_off := await _walk_x(30)
	var cam_off := _cam_snap()
	tog.set_on(true)
	await _frames(2)
	var x_on := await _walk_x(30)
	var cam_on := _cam_snap()
	ck.call("vision isolation: the player walks exactly the same distance with the overlay ON as OFF (movement, input and collision untouched: %.3f vs %.3f)" % [x_off, x_on], absf(x_off - x_on) < 0.001 and x_on > -600.0)
	ck.call("vision isolation: camera zoom, smoothing, limits and offset are identical ON and OFF (camera tracking untouched)", cam_off["zoom"] == cam_on["zoom"] and cam_off["smooth"] == cam_on["smooth"] and cam_off["speed"] == cam_on["speed"] and cam_off["limits"] == cam_on["limits"] and cam_off["offset"] == cam_on["offset"] and cam_off["base"] == cam_on["base"])
	var ov := tog.overlay
	ck.call("vision isolation: the overlay is a plain Node2D with no children, no collider and no Control (it cannot block clicks or physics)", ov.get_child_count() == 0 and ov.get_class() == "Node2D" and not ((ov as Node) is CollisionObject2D) and not ((ov as Node) is Control))
	ck.call("vision isolation: the overlay listens to no input at all", not ov.is_processing_input() and not ov.is_processing_unhandled_input() and not ov.is_processing_unhandled_key_input() and not ov.is_processing_shortcut_input())
	var ov_src := FileAccess.get_file_as_string("res://scripts/debug/bandit_vision_overlay.gd")
	var tg_src := FileAccess.get_file_as_string("res://scripts/debug/bandit_vision_toggle.gd")
	var rg_src := FileAccess.get_file_as_string("res://scripts/debug/bandit_vision_region.gd")
	var no_input := true
	for cb in ["func _input(", "func _unhandled_input(", "func _gui_input(", "func _unhandled_key_input(", "func _shortcut_input(", "set_input_as_handled", "accept_event", "Input.parse_input_event", "Input.action_press"]:
		if ov_src.contains(cb) or rg_src.contains(cb):
			no_input = false
	ck.call("vision isolation: the overlay and region sources neither consume nor generate input", no_input)
	ck.call("vision isolation: the switch does not consume the key (no set_input_as_handled) and has no _process", not tg_src.contains("set_input_as_handled") and not tg_src.contains("accept_event") and not tg_src.contains("func _process(") and not tg_src.contains("func _physics_process("))
	# other debug panels opened and closed while ON: the drawn region is unchanged and there is still exactly one overlay
	_put(Vector2(1500, 100), _snap8(4), Bandit.State.PATROL)
	ov.refresh()
	var pts_before: PackedVector2Array = (ov.views[0]["region"] as BanditVisionRegion).points.duplicate()
	var items_before := ov.draw_items
	var hud := main.get_node("DebugHud")
	for i in 4:
		var a := InputEventAction.new()
		a.action = "dbg_toggle_lab"
		a.pressed = true
		lab._unhandled_input(a)  # the lab panel opens / closes
		hud._toggle_diagnostics()  # the diagnostics panel opens / closes
		await _frames(2)
	await _frames(2)
	_put(Vector2(1500, 100), _snap8(4), Bandit.State.PATROL)  # the AI walked meanwhile: same place, same facing, same state, no frame in between
	ov.refresh()
	var pts_after: PackedVector2Array = (ov.views[0]["region"] as BanditVisionRegion).points
	ck.call("vision isolation: opening and closing the lab and the diagnostics (4 times each) leaves exactly one overlay and the same polygon", _count_overlays(root) == 1 and pts_before == pts_after and tog.on and not lab.lab_on, "overlays=%d same_polygon=%s on=%s lab_open=%s points %d vs %d" % [_count_overlays(root), str(pts_before == pts_after), str(tog.on), str(lab.lab_on), pts_before.size(), pts_after.size()])
	ck.call("vision isolation: ...and the lab opening does not move or hide the vision button", tog.button.get_parent() == lab.settings.rows and items_before > 0)
	_put(WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL)
	player.global_position = Vector2(0, 135)
	tog.set_on(false)
	await _frames(2)


# ------------------------------------------------------------------------------------------------ cost
func _test_cost() -> void:
	var spots: Array = [
		["patrol cone in the open", WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL],
		["chase circle in the open", WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.APPROACH],
		["chase circle hugging the wall line", Vector2(975, -300), _snap8(4), Bandit.State.APPROACH],
		["patrol cone at the choke", Vector2(1090, 80), _snap8(4), Bandit.State.PATROL],
		["chase circle in a corner of the bounds", Vector2(1850, 950), _snap8(1), Bandit.State.APPROACH],
	]
	var worst_us := 0.0
	var worst_rays := 0
	var rows := ""
	for s: Array in spots:
		_put(s[1], s[2], s[3])
		BanditVisionRegion.compute(bandit, player)  # warm up
		var t0 := Time.get_ticks_usec()
		var rays := 0
		var n := 100
		for i in n:
			var r := BanditVisionRegion.compute(bandit, player)
			rays = r.rays_cast
		var per := float(Time.get_ticks_usec() - t0) / float(n)
		worst_us = maxf(worst_us, per)
		worst_rays = maxi(worst_rays, rays)
		rows += "[%s: %d rays, %.0f us/rebuild, %.1f us/ray] " % [s[0], rays, per, per / float(maxi(rays, 1))]
	print("COST per-frame polygon rebuild (native headless; the browser build reports vision_ms in telemetry): ", rows)
	ck.call("vision cost: a rebuild never exceeds %d rays in total, base fan included (worst here %d)" % [BanditVisionRegion.MAX_TOTAL_RAYS, worst_rays], worst_rays <= BanditVisionRegion.MAX_TOTAL_RAYS)
	ck.call("vision cost: a rebuild of up to %d rays stays under 20 ms even on a slow CI machine - worst %.0f us here (about 1-2 ms natively)" % [worst_rays, worst_us], worst_us < 20000.0)
	_put(WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL)
	# with the overlay ON, one full refresh (polygon + sync probes + player check) per frame
	tog.set_on(true)
	await _frames(5)
	var ov := tog.overlay
	var total_us := 0
	for i in 60:
		await tree.process_frame
		total_us += ov.usec_last
	var avg := float(total_us) / 60.0
	print("COST overlay refresh while ON (polygon + sync probes + player check): avg %.0f us over 60 frames, rays last frame %d" % [avg, ov.rays_last])
	ck.call("vision cost: the whole per-frame refresh while ON (polygon + sync probes + player check) averages %.0f us here (bound: 20000 us)" % avg, avg < 20000.0)
	tog.set_on(false)
	await _frames(2)


# ------------------------------------------------------------------------------------------------ telemetry and web
func _test_telemetry_and_web() -> void:
	var keys: Array = BanditVisionToggle.telemetry().keys()
	keys.sort()
	var want: Array = ["vision_ai_state", "vision_bandits", "vision_can_see", "vision_capped", "vision_close", "vision_cone", "vision_facing_x", "vision_facing_y", "vision_fov_deg", "vision_mismatch", "vision_ms", "vision_nodes", "vision_on", "vision_origin_x", "vision_origin_y", "vision_player_in", "vision_points", "vision_range", "vision_rays", "vision_sees", "vision_state"]
	want.sort()
	ck.call("vision state: telemetry() has exactly the 21 documented vision_* keys, always", keys == want, str(keys))
	# vision_nodes = the live scene-tree node count (the browser run uses it to prove OFF leaves nothing behind). Same frame, so nothing else can change.
	tog.set_on(false)
	var n_off: int = BanditVisionToggle.telemetry()["vision_nodes"]
	tog.set_on(true)
	var n_on: int = BanditVisionToggle.telemetry()["vision_nodes"]
	tog.set_on(false)
	var n_off2: int = BanditVisionToggle.telemetry()["vision_nodes"]
	ck.call("vision state: vision_nodes is the live node count; ON adds exactly the one overlay node and OFF takes it away again", n_off > 10 and n_on == n_off + 1 and n_off2 == n_off and n_off == int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "off %d, on %d, off again %d" % [n_off, n_on, n_off2])
	var src := FileAccess.get_file_as_string("res://scripts/web/web_bridge.gd")
	var all_pub := true
	for k: String in want:
		if not src.contains("_state.%s = vis[\"%s\"]" % [k, k]):
			all_pub = false
	ck.call("vision state: WebBridge publishes every one of them next to the existing fields and reads ?vision= at boot", all_pub and src.contains("BanditVisionToggle.apply_query(search)") and src.contains("BanditVisionToggle.telemetry()"))
	ck.call("vision state: existing __SHINOBI_STATE__ names are untouched (additive only)", src.contains("_state.bandit_state = ") and src.contains("_state.bandit_sees = ") and src.contains("_state.cfx_enabled = ") and src.contains("_state.camera_preset = ") and src.contains("_state.lab_open = ") and src.contains("_state.x = _player.global_position.x"))
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/debug_hud.gd")
	ck.call("vision state: the HUD legend mentions the Settings button and ?vision=1", hud_src.contains("Bottom tabs: Settings") and hud_src.contains("?vision=1"))
	# live values, one sample: no frame between the rebuild and the comparison, so the AI cannot have ticked in between
	_put(Vector2(1500, 100), _snap8(4), Bandit.State.APPROACH)
	player.global_position = Vector2(1000, 100)
	tog.set_on(true)
	await _frames(2)
	_put(Vector2(1500, 100), _snap8(4), Bandit.State.APPROACH)
	player.global_position = Vector2(1000, 100)
	bandit.sees_player = true
	var ov := tog.overlay
	ov.refresh()
	var t := BanditVisionToggle.telemetry()
	var reg: BanditVisionRegion = ov.views[0]["region"]
	ck.call("vision state: ON publishes the live numbers (bandit count, polygon size, rays, mode, range, fov, close sense)", t["vision_on"] == true and t["vision_bandits"] == 1 and t["vision_points"] == reg.points.size() and reg.points.size() > 20 and t["vision_rays"] > 20 and t["vision_cone"] == reg.use_cone and is_equal_approx(float(t["vision_range"]), reg.reach) and is_equal_approx(float(t["vision_fov_deg"]), 90.0) and is_equal_approx(float(t["vision_close"]), 70.0) and float(t["vision_ms"]) >= 0.0)
	ck.call("vision state: ...the AI's own State name, facing and sees flag come from the same rebuild", t["vision_ai_state"] == bandit.get_state_name() and is_equal_approx(float(t["vision_facing_x"]), bandit.facing8.x) and is_equal_approx(float(t["vision_facing_y"]), bandit.facing8.y) and t["vision_sees"] == bandit.sees_player)
	ck.call("vision state: ...and the polygon's apex (vision_origin_x/y) is the Bandit's position at that rebuild, which the browser run compares with bandit_x/y", is_equal_approx(float(t["vision_origin_x"]), bandit.global_position.x) and is_equal_approx(float(t["vision_origin_y"]), bandit.global_position.y) and reg.origin == bandit.global_position)
	ck.call("vision state: ...and the overlay's category text and the polygon / can_see answers about the player", t["vision_state"] in BanditVisionOverlay.KEYS and t["vision_player_in"] == reg.contains(player.global_position) and t["vision_can_see"] == bandit.can_see(player.global_position, reg.use_cone))
	ck.call("vision state: the view carries what the label shows - intelligence level, the real State name, category text, notice progress", int(ov.views[0]["level"]) == bandit.intelligence_level and ov.views[0]["state_name"] == "APPROACH" and ov.views[0]["cat_text"] == "PLAYER DETECTED" and float(ov.views[0]["notice"]) == 0.0 and t["vision_capped"] == false)
	tog.set_on(false)
	await _frames(2)
	ck.call("vision state: switching OFF zeroes the geometry numbers again (vision_points 0)", BanditVisionToggle.telemetry()["vision_points"] == 0 and BanditVisionToggle.telemetry()["vision_on"] == false)
	_put(WorldScale.BANDIT_HOME, _snap8(4), Bandit.State.PATROL)
	player.global_position = Vector2(0, 135)


# ------------------------------------------------------------------------------------------------ lifecycle
func _test_lifecycle(root: Node) -> void:
	tog.set_on(true)
	await _frames(3)
	var ov := tog.overlay
	ov.log_mismatches = false
	_put(Vector2(1500, 100), _snap8(4), Bandit.State.PATROL)
	await _frames(2)
	ck.call("vision lifecycle: one live Bandit -> one view, something is drawn", ov.views.size() == 1 and ov.draw_items > 0)
	var one_items := ov.draw_items
	# the Bandit dies: no ghost polygon
	bandit.substitutions = 0  # no log swap: this test needs the kill to land
	bandit.take_damage(100000.0, Vector2.RIGHT, 0.0, 0.0)
	await _frames(2)
	ck.call("vision lifecycle: the Bandit dies -> no view, nothing drawn, telemetry empty (no ghost polygon)", bandit.state == Bandit.State.DEAD and ov.views.is_empty() and ov.draw_items == 0 and BanditVisionToggle.telemetry()["vision_points"] == 0 and BanditVisionToggle.telemetry()["vision_bandits"] == 0)
	# a replacement Bandit appears
	var packed := load("res://scenes/enemy/bandit.tscn") as PackedScene
	var second := packed.instantiate() as Bandit
	second.name = "Bandit2"
	second.position = Vector2(1500, 300)
	arena.add_child(second)
	await _frames(3)
	ck.call("vision lifecycle: a new Bandit while the old one lies dead -> exactly one view (the new one), the dead one stays hidden", ov.views.size() == 1 and int(ov.views[0]["id"]) == second.get_instance_id())
	# two Bandits side by side: both drawn
	bandit.hp = bandit.max_hp
	_put(Vector2(1300, -130), _snap8(4), Bandit.State.PATROL)
	second.global_position = Vector2(1500, 300)
	second.facing8 = _snap8(4)
	ov.refresh()
	ck.call("vision lifecycle: two live Bandits -> two views", ov.views.size() == 2, str(ov.views.size()))
	ck.call("vision lifecycle: ...each view belongs to its own Bandit (different ids, different origins)", ov.views.size() == 2 and int(ov.views[0]["id"]) != int(ov.views[1]["id"]) and not (ov.views[0]["region"] as BanditVisionRegion).origin.is_equal_approx((ov.views[1]["region"] as BanditVisionRegion).origin))
	await _frames(2)
	ck.call("vision lifecycle: ...and two sets of draw items are issued (more than one Bandit's %d)" % one_items, ov.draw_items > one_items, "%d vs %d" % [ov.draw_items, one_items])
	# a Bandit in the line of sight blocks the other one like any body (same query as the AI)
	second.set_physics_process(false)  # no AI, but its body stays in the physics space (PROCESS_MODE_DISABLED would remove it)
	second.global_position = Vector2(1200, -130)
	await tree.physics_frame  # a moved CharacterBody2D reaches the physics broadphase at the next physics step
	await tree.physics_frame
	_put(Vector2(1500, -130), _snap8(4), Bandit.State.PATROL)  # no frame between this and the check below
	ov.refresh()
	var blocked: BanditVisionRegion = null
	for vw: Dictionary in ov.views:
		if int(vw["id"]) == bandit.get_instance_id():
			blocked = vw["region"]
	ck.call("vision lifecycle: another Bandit standing in the way blocks the sight region exactly like it blocks the AI (cannot see through a body)", blocked != null and not blocked.contains(Vector2(1000, -130)) and not bandit.can_see(Vector2(1000, -130), true) and blocked.contains(Vector2(1400, -130)) and bandit.can_see(Vector2(1400, -130), true))
	# the second Bandit is freed: its view is gone the same frame it leaves the group
	second.free()
	await _frames(2)
	ck.call("vision lifecycle: a freed Bandit leaves no view behind", ov.views.size() == 1 and int(ov.views[0]["id"]) == bandit.get_instance_id())
	# zero Bandits
	bandit.free()
	await _frames(3)
	ck.call("vision lifecycle: zero Bandits -> zero views, nothing drawn, no error, telemetry still answers", ov.views.is_empty() and ov.draw_items == 0 and BanditVisionToggle.telemetry()["vision_on"] == true and BanditVisionToggle.telemetry()["vision_bandits"] == 0)
	# arena restart: the whole scene is replaced while the overlay is ON; the wanted state survives
	main.queue_free()
	await _frames(3)
	ck.call("vision lifecycle: the scene is freed while ON -> no overlay node survives anywhere, the switch is gone", _count_overlays(root) == 0 and BanditVisionToggle.telemetry()["vision_on"] == false)
	ck.call("vision lifecycle: ...but the wanted state (ON) is remembered for the next arena", BanditVisionToggle.boot_on)
	var ok := await _boot(root)
	if not ok:
		return
	await _frames(3)
	ck.call("vision lifecycle: arena restart with ON remembered -> a fresh overlay is attached to the NEW arena and shows the NEW Bandit (no ghost of the old one)", tog.on and tog.overlay != null and tog.overlay.get_parent() == arena and _count_overlays(root) == 1 and tog.overlay.views.size() == 1 and int(tog.overlay.views[0]["id"]) == bandit.get_instance_id())
	# the overlay is taken out of the tree behind the switch's back (as when its parent is freed): it is replaced, once
	var old_parent := tog.overlay.get_parent()
	var orphan := tog.overlay
	old_parent.remove_child(orphan)
	await _frames(3)
	ck.call("vision lifecycle: an overlay that leaves the tree while the switch is ON is replaced by one fresh overlay under the arena", tog.on and tog.overlay != null and tog.overlay != orphan and tog.overlay.is_inside_tree() and tog.overlay.get_parent() == old_parent and _count_overlays(root) == 1)
	orphan.free()
	# URL option ?vision=1 starts ON
	main.queue_free()
	await _frames(3)
	BanditVisionToggle.reset_all()
	ck.call("vision url: after a reset the default is OFF again", not BanditVisionToggle.boot_on)
	BanditVisionToggle.apply_query("?camera=close&vision=1")
	ok = await _boot(root)
	if not ok:
		return
	await _frames(3)
	ck.call("vision url: ?vision=1 at boot -> the next scene starts with the overlay ON (and the button shows it)", tog.on and tog.overlay != null and tog.button.button_pressed and tog.button.text == "Bandit vision: ON" and _count_overlays(root) == 1)
	ck.call("vision url: ...and it is already drawing the Bandit", tog.overlay.views.size() == 1 and tog.overlay.views[0]["region"].points.size() > 20)
	main.queue_free()
	await _frames(3)
	BanditVisionToggle.apply_query("?vision=0")
	ok = await _boot(root)
	if not ok:
		return
	await _frames(2)
	ck.call("vision url: ?vision=0 (or nothing) -> OFF at boot, no overlay node", not tog.on and tog.overlay == null and _count_overlays(root) == 0)
