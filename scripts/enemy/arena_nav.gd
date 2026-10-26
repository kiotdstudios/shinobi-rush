class_name ArenaNav
extends RefCounted
## Deterministic wall-aware navigation for ground enemies on the training arena.
## An AStarGrid2D over the arena bounds where every Block footprint (and the bounds ring) is solid,
## inflated by `pad` so a path keeps a body-width of clearance. No NavigationServer involved, so it is
## synchronous and identical in headless tests and the Web build.

var bounds: Rect2
var cell: float = 45.0
var pad: float = 42.0
var grid: AStarGrid2D
var cols := 0
var rows := 0
var _rects: Array[Rect2] = []


## `blocks` uses the WorldScale.BLOCKS layout: [bottom-centre pos, footprint (w, depth), height].
static func build(arena_bounds: Rect2, blocks: Array, cell_size: float = 45.0, clearance: float = 42.0) -> ArenaNav:
	var n := ArenaNav.new()
	n.bounds = arena_bounds
	n.cell = cell_size
	n.pad = clearance
	n.cols = int(ceil(arena_bounds.size.x / cell_size))
	n.rows = int(ceil(arena_bounds.size.y / cell_size))
	n.grid = AStarGrid2D.new()
	n.grid.region = Rect2i(0, 0, n.cols, n.rows)
	n.grid.cell_size = Vector2(cell_size, cell_size)
	n.grid.offset = arena_bounds.position
	n.grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	n.grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.grid.update()
	for b: Array in blocks:
		var pos: Vector2 = b[0]
		var fp: Vector2 = b[1]
		# Block collider: centred horizontally on pos.x, extends `depth` upward from pos.y.
		n._rects.append(Rect2(pos.x - fp.x * 0.5, pos.y - fp.y, fp.x, fp.y))
	for r in n._rects:
		var g := r.grow(clearance)
		for cy in range(maxi(0, n._row(g.position.y)), mini(n.rows, n._row(g.end.y) + 1)):
			for cx in range(maxi(0, n._col(g.position.x)), mini(n.cols, n._col(g.end.x) + 1)):
				if g.has_point(n.cell_center(Vector2i(cx, cy))):
					n.grid.set_point_solid(Vector2i(cx, cy), true)
	# Keep a clearance ring off the perimeter walls.
	for cx in n.cols:
		for cy in n.rows:
			var c := n._cell_rect(cx, cy)
			if c.position.x < arena_bounds.position.x + clearance or c.end.x > arena_bounds.end.x - clearance \
					or c.position.y < arena_bounds.position.y + clearance or c.end.y > arena_bounds.end.y - clearance:
				n.grid.set_point_solid(Vector2i(cx, cy), true)
	return n


## Opens a climb the clearance padding sealed (a stair run squeezed between two cliff faces, and its landing) while
## keeping its rims solid. Cells along `axis` (in front of the mouth -> top step -> into the landing) and cells centred
## inside any of `surfaces` (the stair run, the landing) become walkable unless a real obstacle stands there; any other
## cell next to an opened one across a `rims` segment [a, b] turns solid, so a path can only get on or off through the
## stair mouth.
func open_climb(axis: PackedVector2Array, surfaces: Array, rims: Array) -> void:
	var opened := {}
	for i in axis.size() - 1:
		var steps := maxi(1, int(ceil(axis[i].distance_to(axis[i + 1]) / (cell / 3.0))))
		for k in steps + 1:
			opened[cell_of(axis[i].lerp(axis[i + 1], float(k) / steps))] = true
	for surface: PackedVector2Array in surfaces:
		if surface.size() < 3:
			continue
		var box := Rect2(surface[0], Vector2.ZERO)
		for p in surface:
			box = box.expand(p)
		for cy in range(_row(box.position.y), _row(box.end.y) + 1):
			for cx in range(_col(box.position.x), _col(box.end.x) + 1):
				var c := Vector2i(cx, cy)
				if _in_grid(c) and Geometry2D.is_point_in_polygon(cell_center(c), surface):
					opened[c] = true
	for c: Vector2i in opened.keys():
		if not _in_grid(c) or _in_obstacle(cell_center(c)):
			opened.erase(c)
		else:
			grid.set_point_solid(c, false)
	for c: Vector2i in opened.keys():
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dy)
				if opened.has(n) or not _in_grid(n):
					continue
				for r: Array in rims:
					if Geometry2D.segment_intersects_segment(cell_center(c), cell_center(n), r[0], r[1]) != null:
						grid.set_point_solid(n, true)
						break


## Seals every cell any part of `poly` covers (sampled at a third of a cell), e.g. a broken bridge's gap that a
## bandit cannot jump.
func close_area(poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var step := cell / 3.0
	var y := box.position.y
	while y <= box.end.y:
		var x := box.position.x
		while x <= box.end.x:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
				grid.set_point_solid(cell_of(Vector2(x, y)), true)
			x += step
		y += step


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func _in_obstacle(p: Vector2) -> bool:
	for r in _rects:
		if r.grow(8.0).has_point(p):
			return true
	return false


func _col(x: float) -> int:
	return int(floor((x - bounds.position.x) / cell))


func _row(y: float) -> int:
	return int(floor((y - bounds.position.y) / cell))


func _cell_rect(cx: int, cy: int) -> Rect2:
	return Rect2(bounds.position + Vector2(cx, cy) * cell, Vector2(cell, cell))


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(_col(p.x), 0, cols - 1), clampi(_row(p.y), 0, rows - 1))


func cell_center(c: Vector2i) -> Vector2:
	return bounds.position + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func is_walkable(p: Vector2) -> bool:
	var c := cell_of(p)
	return not grid.is_point_solid(c)


## Nearest walkable cell to `c` (ring search), or `c` itself if already walkable.
func nearest_walkable(c: Vector2i) -> Vector2i:
	if not grid.is_point_solid(c):
		return c
	for ring in range(1, 40):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var q := c + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= cols or q.y >= rows or grid.is_point_solid(q):
					continue
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = q
		if best.x >= 0:
			return best
	return c


## True if the straight segment a->b stays on walkable cells (sampled at a third of a cell).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := maxi(1, int(ceil(dist / (cell / 3.0))))
	for i in range(steps + 1):
		if not is_walkable(a.lerp(b, float(i) / steps)):
			return false
	return true


## Waypoints from `from` to `to` (world px), string-pulled; empty if unreachable. The last point is
## `to` itself when `to` is walkable, otherwise the nearest walkable cell centre.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a := nearest_walkable(cell_of(from))
	var b := nearest_walkable(cell_of(to))
	if line_clear(from, to):
		out.append(to)
		return out
	var ids := grid.get_id_path(a, b)
	if ids.is_empty():
		return out
	var pts: Array[Vector2] = []
	for id in ids:
		pts.append(cell_center(id))
	var goal := to if is_walkable(to) else pts[pts.size() - 1]
	pts[pts.size() - 1] = goal
	# Greedy string pulling: from each anchor jump to the furthest point still in clear line.
	var anchor := from
	var i := 0
	while i < pts.size():
		var far := i
		for j in range(pts.size() - 1, i - 1, -1):
			if line_clear(anchor, pts[j]):
				far = j
				break
		out.append(pts[far])
		anchor = pts[far]
		i = far + 1
	return out
