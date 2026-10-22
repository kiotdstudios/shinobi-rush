class_name SenseVisionOverlay
extends Node2D
## Debug only, default OFF. World-space drawing of the proximity "power level" sense circle
## (ProximitySense) for the live Player and every live (non-DEAD) Bandit. Owner 2026-10-22: "make sure
## the intelligence vision have a toggle on and off like the bandit vision" -- this is that toggle's
## overlay, built the same way BanditVisionOverlay is (SenseVisionToggle creates/frees this node), but
## far simpler: ProximitySense is PURE distance (no facing cone, no line-of-sight, not blocked by
## walls -- see scripts/combat/proximity_sense.gd), so the circle drawn here IS the exact detection
## boundary. No ray-sampling, no polygon, no AI-disagreement/mismatch detection is needed or drawn.
##
## Per live actor it draws: a faint fill + circle outline at its ProximitySense radius, brighter/solid
## while actively sensing (SPRINTing AND something is inside the circle right now) versus a dim dashed
## circle while idle (SPRINTing or not, nothing currently caught), plus a small label with the actor
## kind, its `intelligence` stat and the radius in world px. A caught target gets a short marker line to
## the sensing actor's centre so "who is inside whose circle" reads at a glance with more than one actor.

const Z_INDEX := 109  ## just under BanditVisionOverlay's 110, still above the y-sorted actors
const SEGMENTS := 56
const ACTIVE_COLOR := Color("#D55E00")  ## vermillion (Okabe-Ito), matches BanditVisionOverlay's DETECTED
const IDLE_COLOR := Color("#009E73")  ## bluish green, matches BanditVisionOverlay's NOT_ALERT
const FILL_ALPHA := 0.10
const ACTIVE_FILL_ALPHA := 0.18
const DASH := [16.0, 10.0]

var views: Array[Dictionary] = []  ## one per drawn actor: origin, radius, active, kind, intelligence, caught
var draw_items := 0


func _init() -> void:
	name = "SenseVisionOverlay"
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX


func _process(_delta: float) -> void:
	var had := not views.is_empty()
	refresh()
	if had or not views.is_empty():
		queue_redraw()


## Rebuild the views from the live Player and Bandits (groups "player"/"enemy"). DEAD Bandits draw
## nothing, matching BanditVisionOverlay's HIDDEN rule.
func refresh() -> void:
	var tree := get_tree()
	if tree == null:
		views = []
		return
	var out: Array[Dictionary] = []
	var player := tree.get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("sense_radius"):
		out.append(_view_for(player, "player", bool(player.get("kunai_drawn"))))
	for n in tree.get_nodes_in_group("enemy"):
		var b := n as Bandit
		if b == null or not b.is_inside_tree() or b.state == Bandit.State.DEAD:
			continue
		out.append(_view_for(b, "bandit L%d" % b.intelligence_level, b.senses_player))
	views = out


func _view_for(actor: Node2D, kind: String, active: bool) -> Dictionary:
	return {
		"origin": actor.global_position, "radius": actor.call("sense_radius"), "active": active,
		"kind": kind, "intelligence": int(actor.get("intelligence")) if actor.get("intelligence") != null else 0,
	}


func _draw() -> void:
	draw_items = 0
	for v in views:
		_draw_view(v)


func _draw_view(v: Dictionary) -> void:
	var origin: Vector2 = v["origin"]
	var radius: float = v["radius"]
	var active: bool = v["active"]
	var col := ACTIVE_COLOR if active else IDLE_COLOR
	draw_circle(origin, radius, Color(col, ACTIVE_FILL_ALPHA if active else FILL_ALPHA))
	draw_items += 1
	if active:
		draw_arc(origin, radius, 0.0, TAU, SEGMENTS, col, 3.0)
	else:
		_dashed_circle(origin, radius, col)
	draw_items += 1
	var label := "%s  sense %d px  int %d%s" % [v["kind"], int(roundf(radius)), int(v["intelligence"]), "  ACTIVE" if active else ""]
	_text(origin + Vector2(0, -radius - 18.0), label, col)


## A dashed ring (idle state), screen-space-independent dash lengths in world px.
func _dashed_circle(center: Vector2, radius: float, col: Color) -> void:
	var circumference := TAU * radius
	var pattern_len: float = DASH[0] + DASH[1]
	var steps := maxi(8, int(circumference / pattern_len))
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := a0 + (DASH[0] / circumference) * TAU
		draw_arc(center, radius, a0, a1, 3, col, 2.5)
		draw_items += 1


func _text(center: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := center + Vector2(-w * 0.5, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_items += 2