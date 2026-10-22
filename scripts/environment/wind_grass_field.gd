class_name WindGrassField
extends Node2D
const PATCHES: Array[Rect2i] = [Rect2i(0,4,10,9), Rect2i(2,-3,6,5), Rect2i(-2,-14,6,6), Rect2i(-13,-5,7,6), Rect2i(14,14,7,7)]
const FIELD_ORIGIN := Vector2(-800, 100)
var ground: TileMapLayer
var tall: TileMapLayer
var ground_wind: ShaderMaterial
var tall_wind: ShaderMaterial
var clock := 0.0
const MAX_PUSHERS := 8
var pushers := PackedVector2Array()  ## world feet positions currently pushing the grass
var speed := 1.0
var strength := 1.0
var wind_on := true
var paused := false
var review_mode := false
var selected := "meadow"
var camera: Camera2D
var sample_ground: TileMapLayer
var sample_tall: TileMapLayer
var status: Label
var _state: JavaScriptObject
var initial_tiles: Array[Dictionary] = []
var edited_ground := 0
var edited_tall := 0

func _ready() -> void:
	y_sort_enabled = true
	ground_wind = _material(false)
	tall_wind = _material(true)
	ground = _layer("GrassNineGround", WindGrassTileset.build_ground(ground_wind), FIELD_ORIGIN)
	tall = _layer("GrassTallBlades", WindGrassTileset.build_tall(tall_wind), FIELD_ORIGIN)
	for patch: Rect2i in PATCHES:
		_paint(ground, tall, patch)
	for layer: TileMapLayer in [ground, tall]:
		for cell: Vector2i in layer.get_used_cells():
			var index := layer.get_cell_source_id(cell)
			var id := "grass_tall_%02d" % index if layer == tall else "grass9_" + WindGrassTileset.ROLES[index]
			initial_tiles.append({"id": id, "pos": layer.position + layer.map_to_local(cell)})
	var query := str(JavaScriptBridge.eval("window.location.search", true)) if OS.has_feature("web") else ""
	review_mode = "grass=review" in query or "--grass-review" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__GRASS_STATE__ = _state
	if review_mode:
		call_deferred("_start_review")

func _material(is_tall: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/environment/grass_wind.gdshader") as Shader
	material.set_shader_parameter("frame_size", Vector2(112,160) if is_tall else Vector2(112,112))
	material.set_shader_parameter("root_line", 116.0 if is_tall else 67.0)
	material.set_shader_parameter("blade_height", 62.0 if is_tall else 30.0)
	material.set_shader_parameter("amplitude", 4.5 if is_tall else 0.6)
	material.set_shader_parameter("push_amount", 18.0 if is_tall else 9.0)
	return material

func _layer(label: String, tiles: TileSet, origin: Vector2) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = label
	layer.tile_set = tiles
	layer.position = origin
	layer.y_sort_enabled = true
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	return layer

func _paint(low: TileMapLayer, blades: TileMapLayer, patch: Rect2i) -> void:
	for y in patch.size.y:
		for x in patch.size.x:
			var cell := patch.position + Vector2i(x,y)
			var role := WindGrassTileset.role_at(x,y,patch.size.x,patch.size.y)
			low.set_cell(cell, role, Vector2i.ZERO)
			var hash_value := KosenFloorTileset._mix_hash(cell.x,cell.y)
			var world := low.position + low.map_to_local(cell)
			if hash_value % 100 < (68 if role == 4 else 40) and _clear_of_tree(world):
				blades.set_cell(cell, hash_value % 4, Vector2i.ZERO)

func _clear_of_tree(point: Vector2) -> bool:
	for root: Vector2 in WorldScale.TREE_POSITIONS:
		var footprint := WorldScale.TREE_TRUNK_FOOTPRINT
		if Rect2(root - Vector2(footprint.x * 0.5, footprint.y), footprint).grow(20).has_point(point):
			return false
	return true

## Feet of the player and every bandit; the grass bends away from them (visual only, grass never blocks movement).
func pusher_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not is_inside_tree():
		return pts
	for group: String in ["player", "enemy"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			if n is Node2D and pts.size() < MAX_PUSHERS:
				pts.append((n as Node2D).global_position)
	return pts

func advance(delta: float) -> void:
	clock += delta
	var pts := pusher_points()
	var padded := pts.duplicate()
	padded.resize(MAX_PUSHERS)
	pushers = pts
	for material: ShaderMaterial in [ground_wind,tall_wind]:
		material.set_shader_parameter("pushers", padded)
		material.set_shader_parameter("push_count", pts.size())
		material.set_shader_parameter("phase_index", float(phase()))
		material.set_shader_parameter("strength", strength)
		material.set_shader_parameter("enabled", wind_on)

func phase() -> int:
	return int(floor(fmod(clock,6.0) * 24.0 + 0.00001)) % 144

func ground_count() -> int:
	return ground.get_used_cells().size() + edited_ground

func tall_count() -> int:
	return tall.get_used_cells().size() + edited_tall

## Shared animated material keeps editable sprites synchronized with the original field.
func make_editable_sprite(id: String, pos: Vector2) -> Sprite2D:
	var is_tall := id.begins_with("grass_tall_")
	var sprite := Sprite2D.new()
	sprite.texture = load(WindGrassTileset.DIR + id + ".png") as Texture2D
	sprite.centered = false
	sprite.offset = -Vector2(56, 136 if is_tall else 84)
	sprite.position = pos
	sprite.material = tall_wind if is_tall else ground_wind
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_tall:
		edited_tall += 1
	else:
		edited_ground += 1
	return sprite

func removed_editable(id: String) -> void:
	if id.begins_with("grass_tall_"):
		edited_tall -= 1
	else:
		edited_ground -= 1

func _process(delta: float) -> void:
	advance(0.0 if paused else delta * speed)
	if status != null:
		status.text = "GRASS | %03d/144 | %.2fx | wind %.1f | %d terrain / %d tall tiles" % [phase(),speed,strength,ground_count(),tall_count()]
	if _state != null:
		_state.ready = true
		_state.phase = phase()
		_state.time = clock
		_state.speed = speed
		_state.strength = strength
		_state.wind = wind_on
		_state.paused = paused
		_state.review = review_mode
		_state.selected = selected
		_state.ground_cells = ground_count()
		_state.tall_cells = tall_count()
		_state.roles = ground.tile_set.get_source_count()
		_state.sample_cells = sample_ground.get_used_cells().size() if sample_ground != null else 0

func _start_review() -> void:
	var main := get_tree().current_scene
	if main != null:
		_hide_diagnostics(main)
	sample_ground = _layer("NineTileAssembly", ground.tile_set, Vector2(-1500,820))
	sample_tall = _layer("NineTileTall", tall.tile_set, Vector2(-1500,820))
	_paint(sample_ground,sample_tall,Rect2i(0,0,3,3))
	# One isolated rooted stand lets the viewer inspect the actual bend envelope.
	sample_tall.set_cell(Vector2i(5,-5),0,Vector2i.ZERO)
	camera = Camera2D.new()
	get_parent().add_child(camera)
	show_view("meadow")
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12,get_viewport_rect().size.y-116)
	layer.add_child(panel)
	get_viewport().size_changed.connect(func():panel.position.y=get_viewport_rect().size.y-116)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status = Label.new()
	column.add_child(status)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row,"Normal",func():speed=1.0;paused=false)
	_button(row,"Half speed",func():speed=0.5;paused=false)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;advance(1.0/24.0))
	_button(row,"Wind on/off",func():wind_on=not wind_on)
	_button(row,"Gust",func():strength=1.6 if strength<1.5 else 1.0)
	var views := HBoxContainer.new()
	column.add_child(views)
	for view: String in ["nine","meadow","close","blade","player"]:
		_button(views,view.capitalize(),func():show_view(view))

func show_view(view: String) -> void:
	selected = view
	if view=="player":
		var actor := get_tree().get_first_node_in_group("player")
		if actor!=null:
			(actor.get_node("Camera2D") as Camera2D).make_current()
		return
	camera.position = sample_ground.position + sample_ground.map_to_local(Vector2i(1,1)) + Vector2(0,-26) if view=="nine" else Vector2(-950,250) if view=="meadow" else Vector2(-960,390) if view=="close" else sample_tall.position + sample_tall.map_to_local(Vector2i(5,-5)) + Vector2(0,-50)
	camera.zoom = Vector2.ONE * (2.0 if view=="nine" else 0.7 if view=="meadow" else 1.4 if view=="close" else 3.0)
	camera.make_current()

func _hide_diagnostics(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible=false
		_hide_diagnostics(child)

func _button(row: HBoxContainer,text: String,action: Callable) -> void:
	var button := Button.new()
	button.text=text
	button.focus_mode=Control.FOCUS_NONE
	button.custom_minimum_size.y=36
	button.pressed.connect(action)
	row.add_child(button)
