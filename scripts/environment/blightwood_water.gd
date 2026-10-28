class_name BlightwoodWater
extends Node2D
## Decorative water only. No terrain collision/swimming changes.
const DIR := "res://assets/environment/blightwood_water/"
const SHORE_DIR := "res://assets/environment/blightwood_shorelines/"
const BROWN_SHORE_DIR := "res://assets/environment/blightwood/brown_shorelines/"
const CLIFF_SORT_BIAS := 9.5 # After both 36px half-face sort keys at a vertex; before lower walking feet.
static var shared_clock := 0.0
static var shared_frame := -1
var role := "center"
var waterfall := false
var surface_lift := 0.0
var surface_sort_bias := 0.0
var cascade_height := 0 # 0 preserves the legacy 128x192 cascade exactly.
var _cascade_atlas: AtlasTexture
var shore_family := ""
var shore_mask := 0
var auto_advance := true
var clock := 0.0
var spray_on := true
var surface: Sprite2D
var bank: Sprite2D
var fall: Sprite2D
var foam: Sprite2D
var drops: Array[Sprite2D] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_open_water():
		add_to_group("open_water")  # ninjas can run on it, at a chakra cost (see PlayerController)
	if auto_advance:
		clock = shared_clock  # placement while paused must join the existing frozen flow field
	if waterfall:
		fall = _atlas("waterfall-atlas.png", 4, 4)
		fall.position = Vector2(0, -73)
		if cascade_height>0:
			fall.hframes=1
			fall.vframes=1
			_cascade_atlas=AtlasTexture.new()
			_cascade_atlas.atlas=load("res://assets/environment/blightwood/cliff_kit/cascade-atlas.png")
			fall.texture=_cascade_atlas
			fall.position=Vector2(6,-26)
		foam = _atlas("foam-atlas.png", 4, 4)
		foam.position = Vector2(0, -1)
		for i in 18:
			var drop := Sprite2D.new()
			drop.texture = load(DIR + "droplet.png") as Texture2D
			add_child(drop)
			drops.append(drop)
		if cascade_height>0:
			position.y+=CLIFF_SORT_BIAS
			fall.position.y-=CLIFF_SORT_BIAS
			foam.position.y-=CLIFF_SORT_BIAS
	else:
		surface = Sprite2D.new()
		var stem := "%s_%02d" % [shore_family, shore_mask]
		var mask_stem := "dirt_%02d" % shore_mask if shore_family == "brown" else stem
		surface.texture = load(DIR + "tiles/water9_" + role + ".png" if shore_family.is_empty() else SHORE_DIR + "water_masks/" + mask_stem + ".png") as Texture2D
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/blightwood_water.gdshader") as Shader
		mat.set_shader_parameter("current_atlas", load(DIR + "surface-atlas.png"))
		surface.material = mat
		add_child(surface)
		surface.position.y=-surface_lift-surface_sort_bias
		if not shore_family.is_empty():
			bank = Sprite2D.new()
			bank.texture = load((BROWN_SHORE_DIR if shore_family == "brown" else SHORE_DIR) + "land/" + stem + ".png") as Texture2D
			add_child(bank)
			bank.position.y=-surface_lift-surface_sort_bias
	if not waterfall:position.y+=surface_sort_bias
	advance(0.0)

func ground_position() -> Vector2:
	return global_position-Vector2(0,CLIFF_SORT_BIAS if cascade_height>0 else surface_sort_bias)

func set_placement(at: Vector2) -> void:
	position=at+Vector2(0,CLIFF_SORT_BIAS if cascade_height>0 else surface_sort_bias)

## A full water tile: no bank, no waterfall. Partly-land shore tiles are treated as ground.
func is_open_water() -> bool:
	return not waterfall and (shore_family.is_empty() and role == "center" or shore_family != "" and shore_mask == 0)


## True when world point p is over an open-water tile (72 x 36 diamond), and not on a bridge deck.
static func over_water(tree: SceneTree, p: Vector2) -> bool:
	var hit := false
	var level := modular_level_at(p)
	for n: Node in tree.get_nodes_in_group("open_water"):
		if not is_equal_approx((n as BlightwoodWater).surface_lift,level):continue
		var d := (n as BlightwoodWater).ground_position() - p
		if absf(d.x) / 36.0 + absf(d.y) / 18.0 <= 1.0:
			hit = true
			break
	if not hit:
		return false
	if level>0.0:return true
	for b: Node in tree.get_nodes_in_group("bridge"):
		if (b as Bridge).deck_contains(p):
			return false
	return true

## Only the new modular level participates; legacy shrine and ordinary water behavior stays intact.
static func modular_level_at(p: Vector2) -> float:
	var level:=0.0
	for zone in ShrineElevation.terrain_zones:
		if is_instance_valid(zone) and zone.is_inside_tree() and zone.modular:
			level=maxf(level,zone.elevation_at(zone.to_local(p)))
	return level


func _atlas(path: String, cols: int, rows: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DIR + path) as Texture2D
	sprite.hframes = cols
	sprite.vframes = rows
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	if not auto_advance:
		return
	var frame := Engine.get_process_frames()
	if shared_frame != frame:
		shared_clock += delta
		shared_frame = frame
	clock = shared_clock
	advance(0.0)

func advance(delta: float) -> void:
	clock += delta
	if surface != null:
		(surface.material as ShaderMaterial).set_shader_parameter("motion_time", clock)
		(surface.material as ShaderMaterial).set_shader_parameter("native_scale", maxf(absf(global_scale.x),0.001))
	if fall != null:
		var index:=int(floor(clock * 18.0)) % 16
		if _cascade_atlas!=null:
			_cascade_atlas.region=Rect2((index%4)*56,(index/4)*96,56,96)
		else:fall.frame = index
		foam.frame = int(floor(clock * 13.0)) % 16
		foam.visible = spray_on
		for i in drops.size():
			var t := fposmod(clock * (0.65 + float(i % 5) * 0.057) + float(i) * 0.618, 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var extent := 15.0 + float(i % 7) * 4.0
			drops[i].position = Vector2(side * (5.0 + extent * t), -2.0 - sin(t * PI) * (9.0 + float(i % 6) * 3.0) + t * 5.0 - (CLIFF_SORT_BIAS if cascade_height>0 else 0.0)).round()
			drops[i].modulate.a = (1.0 - t) * 0.8
			drops[i].visible = spray_on
