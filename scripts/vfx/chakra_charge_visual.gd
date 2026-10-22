class_name ChakraChargeVisual
extends Node2D
## Art-only layered playback. Progression/combat code can call set_charging/set_chakra_color.
const PACK := "res://assets/characters/player/chakra_charge/chakra-charge.art.json"
const BLUE := Color(0.08, 0.5, 1.0)
var data: Dictionary
var body: Sprite2D
var layers: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var textures: Dictionary = {}
var direction := "S"
var clock := 0.0
var speed := 0.5
var paused := false
var charging := true
var opacity := 1.0
var chakra_color := BLUE
var auto_advance := true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	for id: String in data.layers:
		var def: Dictionary = data.layers[id]
		var sprite := Sprite2D.new()
		sprite.texture = load(str(def.texture)) as Texture2D
		sprite.centered = false
		sprite.position = -Vector2(def.anchor[0], def.anchor[1])
		sprite.region_enabled = true
		sprite.region_filter_clip_enabled = true
		# Keep all layers on the actor's Y-sort plane; negative Z would put them below the floor.
		sprite.z_index = 0
		sprite.modulate.a = layer_opacity(id) * opacity
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scripts/vfx/chakra_palette.gdshader")
		sprite.material = mat
		materials.append(mat)
		layers[id] = sprite
		add_child(sprite)
	body = Sprite2D.new()
	body.centered = false
	body.position = Vector2(-64, -116)
	add_child(body)
	move_child(layers.ground, 0)
	move_child(layers.aura, 1)
	move_child(body, 2)
	move_child(layers.wisps, 3)
	set_chakra_color(chakra_color)
	advance(0)

func set_charging(value: bool) -> void:
	charging = value

func set_chakra_color(value: Color) -> void:
	chakra_color = value
	for mat in materials:
		mat.set_shader_parameter("chakra_color", value)

func phase() -> int:
	return posmod(int(floor(clock * 24.0 + 0.00001)), 96)

func body_frame() -> int:
	return posmod(int(floor(clock * 12.0 + 0.00001)), 8)

func advance(delta: float) -> void:
	clock = fposmod(clock + maxf(delta, 0.0), 4.0)
	if body == null:
		return
	var dir := direction if data.body.has(direction) else "S"
	var path := "res://" + str(data.body[dir][body_frame()])
	if not textures.has(path):
		textures[path] = load(path)
	body.texture = textures[path]
	for id: String in layers:
		var def: Dictionary = data.layers[id]
		var frame := phase() % int(def.frames)
		(layers[id] as Sprite2D).region_rect = Rect2((frame % int(def.columns)) * 256, (frame / int(def.columns)) * 256, 256, 256)

func _process(delta: float) -> void:
	if auto_advance:
		advance(0.0 if paused else delta * speed)
		opacity = move_toward(opacity, 1.0 if charging else 0.0, delta * 3.0)
		for id: String in layers:
			(layers[id] as Sprite2D).modulate.a = layer_opacity(id) * opacity

func layer_opacity(id: String) -> float:
	return 0.7 if id == "ground" else 0.8 if id == "aura" else 0.42
