class_name LightningFx
extends RefCounted
## Reusable pixel-lightning helpers (Chidori charge, rush and impact): jagged, angular, pixel-snapped bolts that split
## into branches, drawn as a crisp three-layer stroke (deep blue edge, cyan body, white-hot core). No curves, no blur.

const WHITE := Color("#ffffff")
const CYAN := Color("#8ff6ff")
const BLUE := Color("#2f86ff")
const DEEP := Color("#1b3fd0")
const PIXEL := 2.0  ## every vertex sits on this grid so edges stay stepped and crisp


static func snap(p: Vector2) -> Vector2:
	return (p / PIXEL).round() * PIXEL


## One jagged bolt from `a` to `b`. `jag` is the sideways kick per vertex, `step` the typical segment length.
static func bolt(rng: RandomNumberGenerator, a: Vector2, b: Vector2, jag: float, step := 13.0) -> PackedVector2Array:
	var pts := PackedVector2Array([snap(a)])
	var d := b - a
	var n := maxi(int(d.length() / step), 2)
	var perp := Vector2(-d.y, d.x).normalized()
	for i in range(1, n):
		var t := float(i) / float(n)
		var kick := rng.randf_range(-jag, jag) * (1.0 - 0.3 * t)
		var along := rng.randf_range(-step * 0.25, step * 0.25)
		pts.append(snap(a + d * t + perp * kick + d.normalized() * along))
	pts.append(snap(b))
	return pts


## A bolt plus side branches (which may branch again while `depth` > 0). Returns [{"pts": PackedVector2Array, "w": float}].
static func tree(rng: RandomNumberGenerator, a: Vector2, b: Vector2, jag: float, w: float, depth: int, branch_chance := 0.4) -> Array:
	var out: Array = []
	var main := bolt(rng, a, b, jag)
	out.append({"pts": main, "w": w})
	if depth <= 0 or main.size() < 4:
		return out
	var dir := (b - a).normalized()
	for i in range(1, main.size() - 1):
		if rng.randf() > branch_chance:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var ang := deg_to_rad(rng.randf_range(28.0, 68.0)) * side
		var len_left := (b - main[i]).length()
		var blen := clampf(len_left * rng.randf_range(0.3, 0.55), 14.0, 80.0)
		var end := main[i] + dir.rotated(ang) * blen
		out.append_array(tree(rng, main[i], end, jag * 0.6, maxf(w * 0.6, 1.0), depth - 1, branch_chance * 0.55))
	return out


## Draw one polyline in the three lightning layers. `w` is the core width; alpha fades the whole stroke.
static func draw_stroke(ci: CanvasItem, pts: PackedVector2Array, w: float, alpha := 1.0) -> void:
	if pts.size() < 2 or alpha <= 0.0:
		return
	ci.draw_polyline(pts, Color(DEEP, 0.7 * alpha), w * 3.2, false)
	ci.draw_polyline(pts, Color(BLUE, alpha), w * 2.2, false)
	ci.draw_polyline(pts, Color(CYAN, alpha), w * 1.4, false)
	ci.draw_polyline(pts, Color(WHITE, alpha), maxf(w * 0.7, 1.0), false)


## Draw a whole tree from `tree()`. `reveal` (0..1) draws only that fraction of each bolt, so a bolt can strike outward.
static func draw_tree(ci: CanvasItem, bolts: Array, alpha := 1.0, reveal := 1.0, offset := Vector2.ZERO) -> void:
	for b: Dictionary in bolts:
		var pts: PackedVector2Array = b.pts
		if reveal < 1.0:
			var keep := maxi(int(ceil(float(pts.size()) * reveal)), 2)
			pts = pts.slice(0, mini(keep, pts.size()))
		if offset != Vector2.ZERO:
			var moved := PackedVector2Array()
			for p in pts:
				moved.append(p + offset)
			pts = moved
		draw_stroke(ci, pts, float(b.w), alpha)


## A solid pixel dot (no blur): square of `size` px centred on `p`.
static func dot(ci: CanvasItem, p: Vector2, size: float, color: Color) -> void:
	var s := maxf(PIXEL, snappedf(size, PIXEL))
	ci.draw_rect(Rect2(snap(p) - Vector2(s, s) * 0.5, Vector2(s, s)), color)


## A short directional streak (spark with a tail).
static func streak(ci: CanvasItem, p: Vector2, v: Vector2, length: float, color: Color) -> void:
	if v.length_squared() < 1.0:
		dot(ci, p, 2.0, color)
		return
	ci.draw_line(snap(p), snap(p - v.normalized() * length), color, 2.0, false)


## A jagged radial blob (the unstable core): `n` vertices, radius jittered per vertex by `jitter`, y squashed for iso.
static func blob(rng: RandomNumberGenerator, radius: float, jitter: float, n := 11, squash := 0.9) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.12, 0.12)
		var r := radius * rng.randf_range(1.0 - jitter, 1.0 + jitter * 0.6)
		pts.append(snap(Vector2(cos(a) * r, sin(a) * r * squash)))
	return pts


static func fill(ci: CanvasItem, poly: PackedVector2Array, color: Color, scale_k := 1.0) -> void:
	if poly.size() < 3:
		return
	var p := PackedVector2Array()
	for v in poly:
		p.append(snap(v * scale_k))
	ci.draw_colored_polygon(p, color)
