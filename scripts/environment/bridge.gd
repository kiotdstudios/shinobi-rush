class_name Bridge
extends Node2D
## Walkable Blightwood bridge (Codex art kit `assets/environment/blightwood_bridges/`, Aki gameplay).
##
## `position` is the START SOCKET: the centre of the bridge's entry edge on the floor grid. The deck then runs
## `length_tiles` along the axis (`u` = south-east, `v` = south-west) and is 2 tiles wide. Everything here comes from
## the manifest geometry, never from the art's alpha ("damaged gap is visual only").
##
##  * Deck:  anyone can walk onto and along it through the two open ends.
##  * Rails: solid collision along both long edges, so the deck cannot be entered or left sideways.
##  * Broken (`*_damaged_*`): a gap across the middle of the deck. Walking into it drops the player: a small
##    fall hit and they are put back at the nearer end. A JUMP (or air attack) clears it. Striking the broken
##    planks from beside the gap (light attack) repairs the bridge: the intact art replaces the damaged art
##    and the gap closes.

signal repaired
signal fell

const DIR := "res://assets/environment/blightwood_bridges/"
const U := Vector2(36.0, 18.0)
const V := Vector2(-36.0, 18.0)
const RAIL_THICKNESS := 8.0
## Rail centre line sits this far OUTSIDE the deck edge, so its inner face is the edge itself. The player's
## footprint is 50 x 27 and the deck is only ~64 px across along the diagonal, so any inset would pinch it.
const RAIL_INSET := -4.0
const GAP_TILES := 1.5  ## length of the broken section along the bridge
const FALL_DAMAGE := 8.0
const FALL_COOLDOWN := 0.6
const REPAIR_RANGE := 110.0  ## player must be this close to the middle of the gap to repair it
const ENTRY_PUSH := 28.0  ## where a fallen player is put back, beyond the deck end

static var _assemblies: Dictionary = {}

var assembly_id := "short_wood_u"
var state := "intact"  ## intact | broken | repaired
var _rails: StaticBody2D
var _sprites: Dictionary = {}
var _cooldown := 0.0


static func assemblies() -> Dictionary:
	if _assemblies.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "bridges.art.json"))
		if parsed is Dictionary:
			for a: Dictionary in (parsed as Dictionary).get("assemblies", []):
				_assemblies[str(a.id)] = a
	return _assemblies


static func assembly(id: String) -> Dictionary:
	return assemblies().get(id, {})


## Catalogue id for an assembly: "short_wood_u" -> "bridge_short_wood_u".
static func catalog_id(assembly_id_: String) -> String:
	return "bridge_" + assembly_id_


## Bounding box of an assembly's deck relative to its start socket (editor footprint).
static func deck_bounds(a: Dictionary) -> Rect2:
	var step := U if str(a.get("axis", "u")) == "u" else V
	var wv: Array = a.get("deck_width_vector", [0, 0])
	var w := Vector2(float(wv[0]), float(wv[1])) * 0.5
	var l := step * float(a.get("length_tiles", 0))
	var r := Rect2(-w, Vector2.ZERO)
	for p in [w, l + w, l - w]:
		r = r.expand(p)
	return r


static func make(id: String) -> Bridge:
	var b := Bridge.new()
	b.assembly_id = id
	return b


func data() -> Dictionary:
	return assembly(assembly_id)


func is_damaged() -> bool:
	return str(data().get("style", "")) == "damaged"


func length_tiles() -> int:
	return int(data().get("length_tiles", 0))


func axis_step() -> Vector2:
	return U if str(data().get("axis", "u")) == "u" else V


## Full cross-deck vector (2 tiles) and the along-deck vector, in local space.
func width_vec() -> Vector2:
	var w: Array = data().get("deck_width_vector", [0, 0])
	return Vector2(float(w[0]), float(w[1]))


func length_vec() -> Vector2:
	return axis_step() * float(length_tiles())


func _ready() -> void:
	if data().is_empty():
		push_warning("Bridge: unknown assembly '%s'" % assembly_id)
		return
	state = "broken" if is_damaged() else "intact"
	name = "Bridge_" + assembly_id
	_build_sprites(data())
	_build_rails()
	set_physics_process(true)


func _build_sprites(d: Dictionary) -> void:
	var sock: Array = d.start_socket
	var origin := -Vector2(float(sock[0]), float(sock[1]))
	# supports + rear rail sit on the floor under everything; deck is the floor you walk on; the near
	# (front) rail draws over actors. z -1 is the Ground layer, which this node is added after.
	for layer in ["supports", "rear", "deck", "front"]:
		var s := Sprite2D.new()
		s.name = layer.capitalize()
		s.centered = false
		s.position = origin
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_index = 1 if layer == "front" else -1
		add_child(s)
		_sprites[layer] = s
	_apply_textures(d)


func _apply_textures(d: Dictionary) -> void:
	for layer: String in _sprites:
		(_sprites[layer] as Sprite2D).texture = load(str(d.layers[layer])) as Texture2D


func _build_rails() -> void:
	_rails = StaticBody2D.new()
	_rails.name = "Rails"
	add_child(_rails)
	var w := width_vec()
	var along := length_vec()
	var wn := w.normalized()
	for side in [-1.0, 1.0]:
		var a: Vector2 = w * 0.5 * side - wn * side * RAIL_INSET
		var b: Vector2 = a + along
		var half := wn * RAIL_THICKNESS * 0.5
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([a - half, b - half, b + half, a + half])
		var cs := CollisionShape2D.new()
		cs.shape = shape
		_rails.add_child(cs)


## The deck as a world-space quad (start edge, then end edge).
func deck_polygon() -> PackedVector2Array:
	var w := width_vec() * 0.5
	var a := length_vec()
	return PackedVector2Array([global_position - w, global_position + w, global_position + a + w, global_position + a - w])


func deck_contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, deck_polygon())


## The broken section across the middle of the deck (world space), or an empty array when nothing is broken.
func gap_polygon() -> PackedVector2Array:
	if state != "broken":
		return PackedVector2Array()
	var step := axis_step()
	var mid := float(length_tiles()) * 0.5
	var w := width_vec() * 0.5
	var a := global_position + step * (mid - GAP_TILES * 0.5)
	var b := global_position + step * (mid + GAP_TILES * 0.5)
	return PackedVector2Array([a - w, a + w, b + w, b - w])


func gap_center() -> Vector2:
	return global_position + length_vec() * 0.5


func gap_contains(p: Vector2) -> bool:
	var g := gap_polygon()
	return not g.is_empty() and Geometry2D.is_point_in_polygon(p, g)


## True when p is on the bridge and not over the gap, i.e. solid footing.
func walkable_at(p: Vector2) -> bool:
	return deck_contains(p) and not gap_contains(p)


## Where a fallen player is put back: just outside whichever end is nearer.
func entry_point(from: Vector2) -> Vector2:
	var step := axis_step().normalized()
	var s := global_position - step * ENTRY_PUSH
	var e := global_position + length_vec() + step * ENTRY_PUSH
	return s if from.distance_squared_to(s) <= from.distance_squared_to(e) else e


static func airborne(player: Node) -> bool:
	var st: Variant = player.get("state")
	return st == PlayerController.State.JUMP or st == PlayerController.State.AIR_ATTACK


func can_repair(player: Node2D) -> bool:
	return state == "broken" and not airborne(player) and player.global_position.distance_to(gap_center()) <= REPAIR_RANGE


func repair() -> bool:
	if state != "broken":
		return false
	state = "repaired"
	var d := data()
	var intact := assembly("%s_wood_%s" % [assembly_id.get_slice("_", 0), str(d.axis)])
	if not intact.is_empty():
		_apply_textures(intact)
	repaired.emit()
	return true


## Pure rule used by the physics tick (and the tests): does this player drop into the gap?
func drops(player: Node2D) -> bool:
	return state == "broken" and not airborne(player) and not bool(player.get("dying")) and gap_contains(player.global_position)


func fall(player: Node2D) -> void:
	_cooldown = FALL_COOLDOWN
	player.global_position = entry_point(player.global_position)
	if "velocity" in player:
		player.set("velocity", Vector2.ZERO)
	if player.has_method("take_hit"):
		player.take_hit(FALL_DAMAGE, Vector2.ZERO, 0.0)
	fell.emit()


func _physics_process(delta: float) -> void:
	if state != "broken":
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _cooldown <= 0.0 and drops(player):
		fall(player)
	elif Input.is_action_just_pressed("attack_light") and can_repair(player):
		repair()
