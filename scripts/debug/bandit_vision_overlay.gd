class_name BanditVisionOverlay
extends Node2D
## Debug only, default OFF. World-space drawing of what the Level 1 Bandit's AI can see (owner request for play-testing).
## BanditVisionToggle creates this node when the overlay is switched ON and frees it when it is switched OFF, so while it
## is OFF there is no node, no _process and nothing drawn. It shares the AI's coordinates and the camera by being a
## world-space Node2D (top_level, so the arena's transform is irrelevant; the arena is the identity anyway): every
## polygon vertex is a position in which the AI would accept the player (BanditVisionRegion), nothing is re-projected.
##
## Per live Bandit it draws: the sight region (translucent fill + outline in the state's colour and line style), the faint
## sample rays the polygon was built from, the facing, a label (level, the real State name, category, range / cone numbers,
## whether the AI sees the player), the last-seen marker while the AI is using it, and a player marker with a gaze line ONLY
## while `Bandit.sees_player` is true. Palette: Okabe-Ito (colour-blind safe), plus a different outline style and text per
## category. DEAD Bandits are not drawn. It consumes and generates no input (no _input callbacks, no Controls).
##
## Truth over prettiness: each rebuild also asks the AI's own can_see about the player's position and about two probe points
## on the facing ray; a disagreement beyond the stated 1 px band is counted in `mismatches`, drawn in red and logged once.

const Z_INDEX := 110  ## above the y-sorted actors and the lab overlay (100); the HUD canvas layers are above everything
const FILL_ALPHA := 0.2
const SPOKE_ALPHA := 0.14
const TOLERANCE := 1.0  ## px: the stated boundary band of the oracle (BanditVisionRegion.BOUNDARY_TOL)

enum Cat { NOT_ALERT, SUSPICIOUS, DETECTED, LOST, SEARCHING, RETURNING }

## Machine-readable name, human text, Okabe-Ito colour, outline pattern (screen px on / off / on / off ...; empty = solid)
## and outline width (screen px) per category.
const KEYS: Array = ["not_alert", "suspicious", "detected", "lost_sight", "searching", "returning"]
const TEXTS: Array = ["not alert", "suspicious: acquiring", "PLAYER DETECTED", "lost sight", "lost target: searching", "returning to patrol"]
const COLORS: Array = [
	Color("#009E73"),  # bluish green
	Color("#F0E442"),  # yellow
	Color("#D55E00"),  # vermillion
	Color("#CC79A7"),  # reddish purple
	Color("#CC79A7"),  # reddish purple
	Color("#0072B2"),  # blue
]
const PATTERNS: Array = [[], [22.0, 14.0], [], [20.0, 8.0, 4.0, 8.0], [4.0, 9.0], [46.0, 10.0]]
const WIDTHS: Array = [2.0, 2.5, 4.0, 2.5, 3.0, 2.5]

const HIDDEN := -1  ## category of a Bandit that is not drawn (DEAD)
const BY_SIGHT := 99  ## category that depends on `sees_player`: DETECTED if the AI sees the player, else LOST
## EVERY Bandit.State, explicitly (a test fails if the enum gets a state that is not listed here).
const STATE_MAP: Dictionary = {
	Bandit.State.IDLE: Cat.NOT_ALERT,
	Bandit.State.PATROL: Cat.NOT_ALERT,
	Bandit.State.NOTICE: Cat.SUSPICIOUS,
	Bandit.State.APPROACH: BY_SIGHT,
	Bandit.State.THREATEN: BY_SIGHT,
	Bandit.State.ATTACK: BY_SIGHT,
	Bandit.State.REPOSITION: BY_SIGHT,
	Bandit.State.RETREAT: BY_SIGHT,
	Bandit.State.EVADE: BY_SIGHT,
	Bandit.State.HIT_REACT: BY_SIGHT,
	Bandit.State.SEARCH: Cat.SEARCHING,
	Bandit.State.RETURN: Cat.RETURNING,
	Bandit.State.DEAD: HIDDEN,
}

var views: Array[Dictionary] = []  ## one per drawn Bandit, rebuilt by refresh() (see _view_for for the keys)
var draw_items := 0  ## draw primitives issued by the last _draw
var rays_last := 0  ## ray queries of the last refresh (all Bandits)
var usec_last := 0  ## wall time of the last refresh in microseconds
var mismatches := 0  ## rebuilds in which the polygon disagreed with the AI beyond TOLERANCE
var log_mismatches := true  ## log the first disagreement of each kind (push_warning, or log_sink if set)
var log_sink: Callable = Callable()  ## test hook: receives the log line instead of push_warning
var show_rays := true
var refresh_count := 0
## Test hook: the chase reach multiplier the polygons are built with. Tests set a wrong one to prove the runtime sync
## check notices an overlay that no longer matches the AI.
var reach_mult := BanditVisionRegion.CHASE_REACH_MULT

var _logged := {}


func _init() -> void:
	name = "BanditVisionOverlay"
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX


func _process(_delta: float) -> void:
	var had := not views.is_empty()
	refresh()
	if had or not views.is_empty():
		queue_redraw()


## Category of a Bandit in state `st` that does / does not see the player: a Cat, or HIDDEN.
static func category(st: int, sees: bool) -> int:
	var c: int = STATE_MAP.get(st, BY_SIGHT)
	if c == BY_SIGHT:
		return Cat.DETECTED if sees else Cat.LOST
	return c


## Rebuild the views from the live Bandits (group "enemy"), the AI's current numbers and the physics world as it is now.
func refresh() -> void:
	var t0 := Time.get_ticks_usec()
	refresh_count += 1
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D
	var out: Array[Dictionary] = []
	var rays := 0
	for n in tree.get_nodes_in_group("enemy"):
		var b := n as Bandit
		if b == null or not b.is_inside_tree():
			continue
		var v := _view_for(b, player)
		if v.is_empty():
			continue  # HIDDEN: a DEAD Bandit draws nothing
		rays += (v["region"] as BanditVisionRegion).rays_cast
		out.append(v)
	views = out
	rays_last = rays
	usec_last = Time.get_ticks_usec() - t0


## Is `point` inside the region drawn for Bandit number `index` (the same polygon that is on screen)?
func region_contains(point: Vector2, index: int = 0) -> bool:
	if index < 0 or index >= views.size():
		return false
	return (views[index]["region"] as BanditVisionRegion).contains(point)


## Keys: id, region, state, state_name, level, cat, cat_key, cat_text, sees, notice, last_seen, show_last_seen,
## has_player, player, player_in (polygon contains the player), can_see_now (the AI's can_see at the same instant), sync.
func _view_for(b: Bandit, player: Node2D) -> Dictionary:
	var cat := category(b.state, b.sees_player)
	if cat == HIDDEN:
		return {}
	var reg := BanditVisionRegion.compute(b, player, reach_mult)
	var v := {
		"id": b.get_instance_id(), "region": reg, "state": b.state, "state_name": b.get_state_name(),
		"level": int(b.profile.get("level", b.intelligence_level)),
		"cat": cat, "cat_key": KEYS[cat], "cat_text": TEXTS[cat],
		"sees": b.sees_player, "notice": b.get_notice_progress(),
		"last_seen": b.last_seen,
		"show_last_seen": cat == Cat.SEARCHING or cat == Cat.LOST or (b.state == Bandit.State.NOTICE and not b.sees_player),
		"has_player": player != null, "player": player.global_position if player != null else Vector2.ZERO,
		"player_in": false, "can_see_now": false, "sync": "",
	}
	var msg := reg.sync_probe(b)
	if player != null:
		var pp := player.global_position
		var inside := reg.contains(pp)
		var ai := b.can_see(pp, reg.use_cone)
		v["player_in"] = inside
		v["can_see_now"] = ai
		if msg == "" and inside != ai and not BanditVisionRegion.near_ai_boundary(b, pp, reg.use_cone, TOLERANCE):
			msg = "player at (%.1f, %.1f): polygon says %s, can_see says %s" % [pp.x, pp.y, "seen" if inside else "not seen", "seen" if ai else "not seen"]
	if msg != "":
		v["sync"] = msg
		mismatches += 1
		var kind := "probe" if msg.begins_with("facing ray") else "player"  # log each kind once, not once per frame
		if log_mismatches and not _logged.has(kind):
			_logged[kind] = true
			var line := "[BanditVisionOverlay] OUT OF SYNC with Bandit.can_see (bandit.gd:236): %s | state=%s facing=%s pos=%s level=%d" % [
				msg, b.get_state_name(), str(b.facing8), str(b.global_position), int(v["level"])]
			if log_sink.is_valid():
				log_sink.call(line)
			else:
				push_warning(line)
	return v


# ------------------------------------------------------------------------------------------------ drawing
func _draw() -> void:
	draw_items = 0
	if views.is_empty():
		return
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var inv := 1.0 / maxf(cam.zoom.x if cam != null else 1.0, 0.05)  # world px per screen px
	for v in views:
		_draw_view(v, inv)


func _draw_view(v: Dictionary, inv: float) -> void:
	var reg: BanditVisionRegion = v["region"]
	var cat: int = v["cat"]
	var col: Color = COLORS[cat]
	var o := reg.origin
	var pts := reg.points
	if pts.size() >= 3:
		_fill_fan(o, pts, Color(col, FILL_ALPHA))
		if show_rays:
			var spokes := PackedVector2Array()
			for p in pts:
				spokes.append(o)
				spokes.append(p)
			draw_multiline(spokes, Color(col, SPOKE_ALPHA), maxf(1.0, inv * 0.8))
			draw_items += 1
		_outline(pts, col, PATTERNS[cat], float(WIDTHS[cat]) * inv, inv)
	# facing + origin
	var tip := o + reg.facing.normalized() * 120.0
	var head := reg.facing.normalized().rotated(deg_to_rad(150.0)) * 22.0
	var head2 := reg.facing.normalized().rotated(deg_to_rad(-150.0)) * 22.0
	draw_line(o, tip, Color(0, 0, 0, 0.7), 5.0 * inv)
	draw_line(o, tip, col, 3.0 * inv)
	draw_line(tip, tip + head, col, 3.0 * inv)
	draw_line(tip, tip + head2, col, 3.0 * inv)
	draw_circle(o, 8.0 * inv, Color(0, 0, 0, 0.7))
	draw_circle(o, 5.5 * inv, col)
	draw_items += 6
	# last seen (only while the AI is using it)
	if bool(v["show_last_seen"]):
		var ls: Vector2 = v["last_seen"]
		var s := 10.0 * inv
		draw_line(ls + Vector2(-s, -s), ls + Vector2(s, s), Color(0, 0, 0, 0.8), 5.0 * inv)
		draw_line(ls + Vector2(-s, s), ls + Vector2(s, -s), Color(0, 0, 0, 0.8), 5.0 * inv)
		draw_line(ls + Vector2(-s, -s), ls + Vector2(s, s), col, 2.5 * inv)
		draw_line(ls + Vector2(-s, s), ls + Vector2(s, -s), col, 2.5 * inv)
		draw_items += 4
		_text(ls + Vector2(0, -16.0 * inv), "last seen", col, inv, 12)  # above the cross: the Bandit's label sits below its feet
	# player marker: ONLY while the AI really sees the player
	if bool(v["sees"]) and bool(v["has_player"]):
		var pp: Vector2 = v["player"]
		draw_line(o, pp, Color(col, 0.8), 2.0 * inv)
		draw_arc(pp, 46.0, 0.0, TAU, 40, Color(0, 0, 0, 0.8), 6.0 * inv)
		draw_arc(pp, 46.0, 0.0, TAU, 40, col, 3.5 * inv)
		draw_items += 3
		_text(pp + Vector2(0, 74.0), "SEEN", col, inv, 14)
	_label(v, inv)


## Triangle fan from the Bandit over the polygon (the region is star-shaped around it, so this is exact). No polygon
## triangulation, so nothing can fail on collinear wall points.
func _fill_fan(o: Vector2, pts: PackedVector2Array, color: Color) -> void:
	var n := pts.size()
	var verts := PackedVector2Array()
	verts.resize(n + 1)
	verts[0] = o
	var idx := PackedInt32Array()
	idx.resize(n * 3)
	for i in n:
		verts[i + 1] = pts[i]
		idx[i * 3] = 0
		idx[i * 3 + 1] = i + 1
		idx[i * 3 + 2] = 1 + ((i + 1) % n)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, PackedColorArray([color]))
	draw_items += 1


func _outline(pts: PackedVector2Array, col: Color, pattern: Array, width: float, inv: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(0, 0, 0, 0.55), width + 2.5 * inv)
	draw_items += 1
	if pattern.is_empty():
		draw_polyline(closed, col, width)
	else:
		var scaled := PackedFloat32Array()
		for x in pattern:
			scaled.append(float(x) * inv)
		draw_multiline(dash_segments(pts, scaled), col, width)
	draw_items += 1


## Segments of a closed polyline drawn as a dash pattern (on, off, on, off ... lengths in world px, repeating).
static func dash_segments(pts: PackedVector2Array, pattern: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	var total := 0.0
	for x in pattern:
		total += x
	if n < 2 or pattern.size() < 2 or total < 1.0:
		return out
	var idx := 0  # index into the pattern; even = on, odd = off
	var left: float = pattern[0]  # what remains of the current pattern element
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var dir := (b - a) / seg
		var pos := 0.0
		while pos < seg:
			var run := minf(left, seg - pos)
			if idx % 2 == 0 and run > 0.0:
				out.append(a + dir * pos)
				out.append(a + dir * (pos + run))
			pos += run
			left -= run
			if left <= 1.0e-6:
				idx = (idx + 1) % pattern.size()
				left = maxf(pattern[idx], 0.01)
	return out


func _label(v: Dictionary, inv: float) -> void:
	var reg: BanditVisionRegion = v["region"]
	var cat: int = v["cat"]
	var col: Color = COLORS[cat]
	var lines: Array[String] = []
	var cols: Array[Color] = []
	var l1 := "L%d %s: %s" % [int(v["level"]), String(v["state_name"]), String(v["cat_text"])]
	if int(v["state"]) == Bandit.State.NOTICE:
		l1 += " %d%%" % int(roundf(float(v["notice"]) * 100.0))
	lines.append(l1)
	cols.append(col)
	if reg.use_cone:
		lines.append("CONE %d deg  range %d px  close %d px" % [int(roundf(reg.fov_deg)), int(roundf(reg.reach)), int(roundf(reg.close_sense))])
	elif reg.paused:
		lines.append("NO CONE (AI sight paused, next look is chasing)  range %d px" % int(roundf(reg.reach)))
	else:
		lines.append("NO CONE (chasing)  range %d px" % int(roundf(reg.reach)))
	cols.append(Color.WHITE)
	lines.append("AI sees player: %s" % ("YES" if bool(v["sees"]) else "no"))
	cols.append(Color.WHITE)
	if reg.capped:
		lines.append("RAY BUDGET REACHED: some edges are approximate")
		cols.append(Color("#E69F00"))
	if String(v["sync"]) != "":
		lines.append("OVERLAY OUT OF SYNC WITH AI (see log)")
		cols.append(Color("#FF4040"))
	var fs := maxi(12, ceili(13.0 * inv))
	var font := ThemeDB.fallback_font
	var width := 0.0
	for s in lines:
		width = maxf(width, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var lh := float(fs) * 1.2
	var top := reg.origin + Vector2(-width * 0.5, 34.0)
	draw_rect(Rect2(top + Vector2(-6.0 * inv, 0.0), Vector2(width + 12.0 * inv, lh * lines.size() + 6.0 * inv)), Color(0, 0, 0, 0.6))
	draw_items += 1
	for i in lines.size():
		var pos := top + Vector2(0.0, lh * (i + 1))
		draw_string_outline(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cols[i])
		draw_items += 2


func _text(center: Vector2, text: String, col: Color, inv: float, base_size: int) -> void:
	var fs := maxi(base_size - 1, ceili(float(base_size) * inv))
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := center + Vector2(-w * 0.5, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_items += 2
