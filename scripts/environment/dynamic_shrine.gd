class_name DynamicShrine
extends Node2D
## PixelLab-authored landmark. Stone stays fixed; foliage and light are independent.
const DIR := "res://assets/environment/blightwood_dynamic_shrine/"
const FOOT := Vector2(272, 448)
## Depth layers of the stone (see docs/visuals/shrine-elevation/make_layers.py): a pixel partition of stone.png that
## recomposites to the original. Order = draw order between layers that share a sort key.
const LAYERS: Array[String] = ["base", "fore_l", "fore_r", "mon", "arch_l", "arch_r"]
const COLUMN := 34  ## width of a depth slice: the mound's front edge slopes, so one key per layer would be wrong
## Sort key (ground y, art px) of each layer for an actor standing on the stairs or the platform. The base (mound,
## stairs, platform floor) is always behind them; the standing pieces hide an actor only while it is north of them.
const UPPER_KEY := {"base": -100000.0, "fore_l": 321.0, "fore_r": 346.0, "mon": 312.0, "arch_l": 284.0, "arch_r": 304.0}
## Which arch each hanging vine band belongs to (it sorts with that arch).
const VINE_LAYER := ["arch_l", "arch_l", "arch_r", "arch_r"]
const VINE_X := [216.0, 183.0, 366.0, 422.0]

## Draw-order wrapper: a Node2D whose position.y is the sort key, holding content that keeps its drawn position.
class Slice extends Node2D:
	var key_ground := 0.0  ## key while the player is on the ground (relative to the shrine origin)
	var key_upper := 0.0  ## key while the player is on the stairs or the platform
	var homes: Array[Vector2] = []
	func add_content(node: Node2D, home: Vector2) -> void:
		homes.append(home)
		node.position = home - Vector2(0.0, position.y)
		add_child(node)
	func apply(upper: bool) -> void:
		position.y = key_upper if upper else key_ground
		for i in get_child_count():
			(get_child(i) as Node2D).position = homes[i] - Vector2(0.0, position.y)

var solid := true  ## blocks like a building and can be climbed; the review/preview scenes turn it off
var auto_advance := true
var clock := 0.0
var lighting_on := true
var vines_on := true
var fireflies_on := true
var rays_on := true
var pulse := 1.0
var body: Sprite2D
var emission: Sprite2D  ## the monument's glow layer; every glow layer shares its modulate/visibility
var emission_layers: Array[Sprite2D] = []
var slices: Array[Slice] = []
var ground_body: StaticBody2D  ## blocks everything at ground level; the player ignores it while on the upper level
var edge_body: StaticBody2D  ## platform rim and stair sides: only the player collides (layer EDGE_LAYER)
var sort_upper := false
var _upper_actors := {}
var foliage: Array[Sprite2D] = []
var swarms: Array[ForestFireflies] = []
var halo: Sprite2D
var rays: Polygon2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true  # the depth slices below sort against the player in the arena's y-sort
	# Full-art reference: kept (hidden) so tools and tests can read the canvas size and anchor; the visible stone is
	# the depth layers below, which recomposite to exactly this image.
	body = _sprite("stone.png")
	body.visible = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_build_stone_slices()
	for layer in LAYERS:
		var path := DIR + "emission_%s.png" % layer
		if not ResourceLoader.exists(path):
			continue
		var glow := _layer_sprite(load(path) as Texture2D, null)
		glow.material = add
		_slice(layer, ShrineElevation.front_edge_y(FOOT.x) - FOOT.y).add_content(glow, -FOOT)
		emission_layers.append(glow)
		if layer == "mon":
			emission = glow
	for i in 4:
		var vine := _layer_sprite(load(DIR + "vine_%02d.png" % i) as Texture2D, null)
		var sway := ShaderMaterial.new()
		sway.shader = load("res://scripts/environment/shrine_vines.gdshader") as Shader
		sway.set_shader_parameter("phase",i*1.7)
		sway.set_shader_parameter("top",float([67,105,114,145][i])/480.0)
		sway.set_shader_parameter("bottom",float([121,153,176,179][i])/480.0)
		vine.material = sway
		_slice(VINE_LAYER[i], ShrineElevation.front_edge_y(VINE_X[i]) - FOOT.y).add_content(vine, -FOOT)
		foliage.append(vine)
	var glow_tex := FirePillar._make_glow_texture()
	halo = Sprite2D.new()
	halo.texture = glow_tex
	halo.material = add
	halo.scale = Vector2(3.6, 2.8)
	_slice("mon", ShrineElevation.front_edge_y(FOOT.x) - FOOT.y).add_content(halo, Vector2(9, -272))
	rays = Polygon2D.new()
	rays.polygon = PackedVector2Array([Vector2(-125,-425), Vector2(-85,-425), Vector2(130,-20), Vector2(-20,-20)])
	rays.uv = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	var ray_material := ShaderMaterial.new()
	ray_material.shader = load("res://scripts/environment/shrine_rays.gdshader") as Shader
	rays.material = ray_material
	rays.z_index = 1
	add_child(rays)
	for i in 3:
		var swarm := ForestFireflies.new()
		swarm.name = "ShrineFireflies%d" % (i+1)
		swarm.auto_advance = false
		swarm.count = 14
		swarm.seed_value = 241240 + i*101
		swarm.radius = Vector2(74,62)
		swarm.position = [Vector2(-135,-190),Vector2(125,-180),Vector2(5,-62)][i]
		add_child(swarm)
		swarms.append(swarm)
	for sl in slices:
		sl.apply(false)
	if solid:
		_build_colliders()
		ShrineElevation.zones.append(self)
	set_process(auto_advance)
	advance(0.0)


func _exit_tree() -> void:
	ShrineElevation.zones.erase(self)


func _sprite(file: String) -> Sprite2D:
	var sprite := _layer_sprite(load(DIR + file) as Texture2D, null)
	sprite.position = -FOOT
	add_child(sprite)
	return sprite


func _layer_sprite(tex: Texture2D, region: Variant) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	if region is Rect2:
		sprite.region_enabled = true
		sprite.region_rect = region
	return sprite


## A depth slice for `layer` with the given ground-level sort key (relative to the shrine origin); its upper-level
## key comes from UPPER_KEY. Slices are direct children so they y-sort against the arena's actors.
func _slice(layer: String, key_ground: float) -> Slice:
	var sl := Slice.new()
	sl.name = "Slice%d_%s" % [slices.size(), layer]
	sl.key_ground = key_ground
	sl.key_upper = float(UPPER_KEY[layer]) - FOOT.y
	sl.position.y = key_ground
	add_child(sl)
	slices.append(sl)
	return sl


## The stone as vertical strips per layer. Strip keys follow the mound's sloped front edge, so an actor standing
## beside or behind a corner is compared against the edge nearest to it rather than one key for the whole mound.
func _build_stone_slices() -> void:
	var size := Vector2i(544, 480)
	for layer in LAYERS:
		var tex := load(DIR + "stone_%s.png" % layer) as Texture2D
		var used := tex.get_image().get_used_rect()
		var x := (used.position.x / COLUMN) * COLUMN
		while x < used.end.x:
			var w := mini(COLUMN, size.x - x)
			var sp := _layer_sprite(tex, Rect2(x, 0, w, size.y))
			var key := ShrineElevation.front_edge_y(float(x) + w * 0.5) - FOOT.y
			_slice(layer, key).add_content(sp, Vector2(x, 0) - FOOT)
			x += COLUMN


func set_sort_upper(upper: bool) -> void:
	if upper == sort_upper:
		return
	sort_upper = upper
	for sl in slices:
		sl.apply(upper)


## Called by ShrineElevation.update_actor each physics tick. `upper`: the actor is on the stairs' top half or the
## platform (it then ignores the ground-level mound and walks on the surface); `sorting_upper`: draw it over the
## mound art instead of comparing it with the mound's front edge.
func set_actor_level(actor: Node, upper: bool, sorting_upper: bool) -> void:
	var id := actor.get_instance_id()
	if bool(_upper_actors.get(id, false)) != upper:
		_upper_actors[id] = upper
		if ground_body != null and actor is PhysicsBody2D:
			if upper:
				(actor as PhysicsBody2D).add_collision_exception_with(ground_body)
			else:
				(actor as PhysicsBody2D).remove_collision_exception_with(ground_body)
	set_sort_upper(sorting_upper)


func _build_colliders() -> void:
	# Ground level: the mound and platform footprint, minus a notch for the stair entrance.
	ground_body = StaticBody2D.new()
	ground_body.name = "ShrineGround"
	add_child(ground_body)
	var footprint := Geometry2D.merge_polygons(ShrineElevation.mound_polygon(), ShrineElevation.platform_polygon())
	var notch := ShrineElevation.stair_polygon(1.12, 0.6)
	for poly in footprint:
		for piece in Geometry2D.clip_polygons(poly, notch):
			_add_poly(ground_body, piece)
	# The monument on the platform (solid for the upper level; unreachable from the ground).
	var solids := StaticBody2D.new()
	solids.name = "ShrineSolids"
	add_child(solids)
	_add_poly(solids, ShrineElevation.ellipse(ShrineElevation.MONUMENT[0], ShrineElevation.MONUMENT[1], 16))
	# Player-only walls: the platform rim (open at the stairs) and the stair sides.
	edge_body = StaticBody2D.new()
	edge_body.name = "ShrineEdge"
	edge_body.collision_layer = ShrineElevation.EDGE_LAYER
	edge_body.collision_mask = 0
	add_child(edge_body)
	var thick := 30.0
	var rim := ShrineElevation.platform_polygon(40)
	var center := ShrineElevation.PLATFORM_CENTER - FOOT
	var radius := ShrineElevation.PLATFORM_RADIUS
	var stairs := ShrineElevation.stair_polygon()
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		if Geometry2D.is_point_in_polygon((a + b) * 0.5, stairs):
			continue
		var na := _ellipse_normal(a - center, radius)
		var nb := _ellipse_normal(b - center, radius)
		_add_poly(edge_body, PackedVector2Array([a - na * 2.0, b - nb * 2.0, b + nb * thick, a + na * thick]))
	var run := ShrineElevation.TOP - ShrineElevation.MOUTH
	for side in [-1.0, 1.0]:
		var p0: Vector2 = ShrineElevation.MOUTH + ShrineElevation.STAIR_HALF * side
		var p1: Vector2 = ShrineElevation.TOP + ShrineElevation.STAIR_HALF * side
		var end := p1
		for step in 81:
			var q := p0.lerp(p1, float(step) / 80.0)
			if ShrineElevation.in_platform(q - FOOT):
				end = q
				break
		var dir := run.normalized()
		var out := Vector2(-dir.y, dir.x)
		if out.dot(ShrineElevation.STAIR_HALF * side) < 0.0:
			out = -out
		var start := p0 - dir * 40.0
		_add_poly(edge_body, PackedVector2Array([start - FOOT, end - FOOT, end + out * thick - FOOT, start + out * thick - FOOT]))


static func _ellipse_normal(rel: Vector2, radius: Vector2) -> Vector2:
	return Vector2(rel.x / (radius.x * radius.x), rel.y / (radius.y * radius.y)).normalized()


func _add_poly(host: StaticBody2D, poly: PackedVector2Array) -> void:
	var cp := CollisionPolygon2D.new()
	cp.polygon = poly
	host.add_child(cp)


func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta
	# Twelve second breath: gentle, no flashing or whole-body modulation.
	pulse = 0.5 + 0.5*sin(TAU*clock/12.0)
	for glow in emission_layers:
		glow.visible = lighting_on
		glow.modulate = Color(1.0,0.75,0.5,0.18+0.30*pulse)
	halo.visible = lighting_on
	halo.modulate = Color(0.6,0.15,0.045,0.10+0.10*pulse)
	for i in foliage.size():
		# Native-pixel bending increases toward the tip, roots stay registered.
		var sway := foliage[i].material as ShaderMaterial
		sway.set_shader_parameter("motion_time",clock if vines_on else -float(i)*1.7/(TAU/8.0))
	for swarm in swarms:
		swarm.enabled = fireflies_on
		swarm.advance(delta)
	rays.visible = rays_on
	(rays.material as ShaderMaterial).set_shader_parameter("motion_time",clock)
