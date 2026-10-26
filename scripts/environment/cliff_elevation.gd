class_name CliffElevation
extends Node2D
## Ground-plane geometry, independent of the stair picture. Visual feet = ground feet - height.
var mouth := Vector2(-50, 0)
var top := Vector2(30, -40)
var half_width := Vector2(72, 36)
var height := 64.0
var landing := PackedVector2Array()
var build_edges := true
var edge_body: StaticBody2D
var occluders: Array[Node2D] = []
var ground_bodies: Array[StaticBody2D] = []
var _occluder_depths := {}
var _on_surface := {}

func configure(def: Dictionary) -> void:
	mouth = def.get("ramp_mouth", mouth)
	top = def.get("ramp_top", top)
	half_width = def.get("ramp_half", half_width)
	height = float(def.get("rise", height))
	landing = PackedVector2Array(def.get("landing", []))

func _ready() -> void:
	ShrineElevation.terrain_zones.append(self)
	if build_edges:
		_build_edges()

func _exit_tree() -> void:
	ShrineElevation.terrain_zones.erase(self)

func stair_polygon() -> PackedVector2Array:
	return PackedVector2Array([mouth - half_width, mouth + half_width, top + half_width, top - half_width])

func stair_t(local: Vector2) -> float:
	return (local - mouth).cross(half_width) / (top - mouth).cross(half_width)

func in_stairs(local: Vector2) -> bool:
	var ext := (top - mouth).normalized() * 1.5
	return Geometry2D.is_point_in_polygon(local, PackedVector2Array([mouth - half_width, mouth + half_width, top + half_width + ext, top - half_width + ext]))

func elevation_at(local: Vector2) -> float:
	if in_stairs(local):
		return height * clampf(stair_t(local), 0.0, 1.0)
	if landing.size() >= 3 and Geometry2D.is_point_in_polygon(local, landing):
		return height
	# Subpixel seam tolerance connects a catalog landing whose head edge was rounded.
	if landing.size() >= 3 and stair_t(local) >= 0.98:
		var expanded := Geometry2D.offset_polygon(landing, 1.5)
		if not expanded.is_empty() and Geometry2D.is_point_in_polygon(local, expanded[0]):
			return height
	return 0.0

func set_actor_level(actor: Node, _upper: bool, on_ramp: bool) -> void:
	var id := actor.get_instance_id()
	if actor is PhysicsBody2D:
		for body in ground_bodies:
			if not is_instance_valid(body):
				continue
			if on_ramp:
				(actor as PhysicsBody2D).add_collision_exception_with(body)
			else:
				(actor as PhysicsBody2D).remove_collision_exception_with(body)
	if on_ramp:
		_on_surface[id] = weakref(actor)
	else:
		_on_surface.erase(id)
	for key in _on_surface.keys():
		if _on_surface[key].get_ref() == null:
			_on_surface.erase(key)
	for sprite in occluders:
		if not is_instance_valid(sprite):
			continue
		var sid := sprite.get_instance_id()
		if not _occluder_depths.has(sid):
			_occluder_depths[sid] = sprite.z_index
		sprite.z_index = -1 if not _on_surface.is_empty() else int(_occluder_depths[sid])

func _segment(a: Vector2, b: Vector2) -> void:
	if a.distance_squared_to(b) < 0.01:
		return
	var normal := (b - a).orthogonal().normalized() * 3.0
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([a - normal, b - normal, b + normal, a + normal])
	edge_body.add_child(shape)

func _build_edges() -> void:
	edge_body = StaticBody2D.new()
	edge_body.name = "CliffRimAndStairSides"
	edge_body.collision_layer = ShrineElevation.EDGE_LAYER
	edge_body.collision_mask = 0
	edge_body.position = Vector2(0, -WorldScale.FOOTPRINT.y * 0.5)
	add_child(edge_body)
	for side in [-1.0, 1.0]:
		_segment(mouth + half_width * side, top + half_width * side)
	# Clip against a slightly expanded entrance so touching/float-jittered seams stay open.
	var openings := Geometry2D.offset_polygon(stair_polygon(), 1.5)
	if openings.is_empty():
		return
	var opening: PackedVector2Array = openings[0]
	var padded_landing := Geometry2D.offset_polygon(landing, 1.5)
	if padded_landing.is_empty():
		return
	var rim: PackedVector2Array = padded_landing[0]
	for i in rim.size():
		var edge := PackedVector2Array([rim[i], rim[(i + 1) % rim.size()]])
		for piece in Geometry2D.clip_polyline_with_polygon(edge, opening):
			for k in piece.size() - 1:
				_segment(piece[k], piece[k + 1])
