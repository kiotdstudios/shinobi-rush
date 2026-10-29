class_name BlightwoodFoliage
extends Sprite2D
## Decorative native-pixel foliage: no body, navigation or gameplay changes.
const DIR := "res://assets/environment/blightwood_foliage/"
const IDS := ["blight_vine_01","blight_vine_02","blight_vine_03","blight_fern_01","blight_fern_02","blight_fern_03"]
static var _definitions: Dictionary={}
var clock:=0.0
var auto_advance:=true
var definition_id:=""
var sort_bias:=0.0
static func definition(id: String) -> Dictionary:
	if id not in IDS:return {}
	if _definitions.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"foliage.art.json"))
		for item: Dictionary in data.items:
			_definitions[item.id]={"kind":"foliage","label":item.label,"file":item.file,"size":Vector2(item.size[0],item.size[1]),"anchor":Vector2(item.anchor[0],item.anchor[1]),"pick":Vector2(item.pick_pixel[0],item.pick_pixel[1]),"lift":float(item.lift),"sort_dy":float(item.sort_dy),"hang":bool(item.hang),"tint":Color(str(item.get("render_tint","#ffffff"))),"sway_length":float(item.content_bounds[3]-item.content_bounds[1]),"footprint":Vector2(12,6)}
	return _definitions.get(id,{})
static func tint(id: String) -> Color:
	return definition(id).get("tint",Color.WHITE)
static func art(id: String) -> Texture2D:
	return load(DIR+str(definition(id).file)) as Texture2D
func setup(id: String, at: Vector2) -> void:
	definition_id=id
	var info:=definition(id)
	texture=art(id)
	self_modulate=tint(id)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	centered=false
	sort_bias=float(info.sort_dy)
	offset=-(info.anchor as Vector2)-Vector2(0,float(info.lift)+sort_bias)
	set_pose(at)
	var wind:=ShaderMaterial.new()
	wind.shader=load("res://shaders/blightwood_foliage.gdshader")
	wind.set_shader_parameter("root_y",float(info.anchor.y))
	wind.set_shader_parameter("hanging",bool(info.hang))
	wind.set_shader_parameter("sway_length",float(info.sway_length))
	wind.set_shader_parameter("amplitude",2.0 if bool(info.hang) else 1.3)
	material=wind
	advance(0.0)
func set_pose(at: Vector2) -> void:
	position=at+Vector2(0,sort_bias)
func advance(delta: float) -> void:
	clock=fposmod(clock+delta,4.0)
	if material!=null:
		(material as ShaderMaterial).set_shader_parameter("phase_index",int(floor(clock*24.0))%96)
func _process(delta: float) -> void:
	if auto_advance:advance(delta)
