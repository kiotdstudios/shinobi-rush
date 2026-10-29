class_name CliffKit
extends Node2D
## Native modules share the floor lattice and ShrineElevation's existing height system.
const DIR := "res://assets/environment/blightwood/cliff_kit/"
const HEIGHT := 66.0
const VERTICES := [Vector2(0,-18),Vector2(36,0),Vector2(0,18),Vector2(-36,0)]
const NEIGHBORS := [Vector2(36,-18),Vector2(36,18),Vector2(-36,18),Vector2(-36,-18)]
const IDS := ["cliff_ground","cliff_grass","cliff_path","cliff_straight_se","cliff_straight_sw","cliff_outer_s","cliff_inner_s","cliff_outer_w","cliff_inner_w","cliff_outer_n","cliff_inner_n","cliff_outer_e","cliff_inner_e","cliff_end_se","cliff_end_sw","cliff_stair_join_se","cliff_stair_join_sw","cliff_upper_river","cliff_waterfall_lip","cliff_stairs_se","cliff_stairs_sw","cliff_cascade"]
static var _definitions := {}
static func definition(id: String) -> Dictionary:
	if _definitions.is_empty():
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"cliffs.art.json"))
		for m: Dictionary in manifest.modules:
			var cells: Array[Vector2]=[]
			for p: Array in m.cells:cells.append(Vector2(p[0],p[1]))
			var points:=PackedVector2Array()
			for p in cells:
				for v: Vector2 in VERTICES:points.append(p+v)
			_definitions[m.id]={"kind":"wall","cliff_kit":true,"landmark":true,"walkable":true,"label":m.label,"dir":DIR,"art":m.id,"size":Vector2(m.size[0],m.size[1]),"anchor":Vector2(m.anchor[0],m.anchor[1]),"col":Vector2.ZERO,"poly":Geometry2D.convex_hull(points),"cells":cells,"water":m.get("water",false),"role":m.role,"surface":m.get("surface","")}
	return _definitions.get(id,{})

var definition_id := "cliff_ground"
var cells: Array[Vector2]=[]
var pictures: Array[Node2D]=[]
func _ready() -> void:
	visibility_changed.connect(_sync_visibility)
func _sync_visibility() -> void:
	for picture in pictures:
		if is_instance_valid(picture):picture.visible=visible
func setup(id: String) -> void:
	definition_id=id
	cells.assign(definition(id).cells)
func set_pose(at: Vector2) -> void:
	var delta:=at-position
	position=at
	for picture in pictures:
		if is_instance_valid(picture) and picture.get_parent()!=self:picture.position+=delta
func rebuild(occupied: Dictionary, openings: Array) -> void:
	for n in pictures:
		if is_instance_valid(n):n.free()
	pictures.clear()
	var info:=definition(definition_id)
	for cell in cells:
		var p:=position+cell
		if occupied.get(p)!=self:continue
		for edge in 4:
			if edge in [0,3]:continue # Rear vertical faces are occluded by the solid terrace, not raised parapets.
			if occupied.has(p+NEIGHBORS[edge]):continue
			var a: Vector2=p+VERTICES[edge]
			var b: Vector2=p+VERTICES[(edge+1)%4]
			if _opening(a,b,openings):continue
			_picture("face_%d.png"%edge,cell-Vector2(37,84),((a+b)*.5).y-position.y)
		if bool(info.water):
			var water:=BlightwoodWater.new()
			water.surface_lift=HEIGHT
			water.surface_sort_bias=-18.0
			water.position=position+cell
			get_parent().add_child(water)
			pictures.append(water)
		else:
			_picture("cap"+("_"+str(info.surface) if str(info.surface)!="" else "")+".png",cell-Vector2(36,84),cell.y-18)
			if str(info.surface)=="grass":
				_grass_fringe(cell,occupied)
	if str(info.role)=="waterfall_lip":
		_picture("lip_left.png",Vector2(-37,-84),1)
		_picture("lip_right.png",Vector2(-37,-84),1)
	_sync_visibility()
func _grass_fringe(cell: Vector2, occupied: Dictionary) -> void:
	# Keep the ground-plane anchor/save format; only the native vegetation pixels rise.
	var field:=get_parent().get_node_or_null("WindGrassField") as WindGrassField
	if field==null:return
	var sprite:=Sprite2D.new()
	sprite.texture=load(WindGrassTileset.DIR+"grass9_center.png")
	sprite.centered=false
	sprite.material=field.ground_wind
	var depth:=cell.y-18
	sprite.position=Vector2(position.x,position.y+depth)
	sprite.offset=cell-Vector2(56,150)-Vector2(0,depth)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().add_child(sprite)
	pictures.append(sprite)
	# Sparse tall edge clusters rather than a uniform hedge around every cell.
	var p:=position+cell
	var exposed:=not occupied.has(p+NEIGHBORS[1]) or not occupied.has(p+NEIGHBORS[2])
	if not exposed or posmod(int(p.x/36)+int(p.y/18),3)!=0:return
	for d: Vector2 in NEIGHBORS:
		var neighbor: CliffKit=occupied.get(p+d)
		if neighbor!=null and bool(definition(neighbor.definition_id).water):return
	var blades:=Sprite2D.new()
	blades.texture=load(WindGrassTileset.DIR+"grass_tall_%02d.png"%posmod(int(p.x/36),4))
	blades.centered=false
	blades.material=field.tall_wind
	blades.position=sprite.position
	blades.offset=cell-Vector2(56,202)-Vector2(0,depth)
	blades.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().add_child(blades)
	pictures.append(blades)
func _picture(file: String, origin: Vector2, depth: float) -> void:
	var sprite:=Sprite2D.new()
	sprite.texture=load(DIR+file)
	sprite.centered=false
	# Sibling sort keys must participate in the arena's y-sort.
	sprite.position=Vector2(position.x,position.y+depth)
	sprite.offset=origin-Vector2(0,depth)
	get_parent().add_child(sprite)
	pictures.append(sprite)
static func _opening(a: Vector2,b: Vector2,openings: Array) -> bool:
	for polygon: PackedVector2Array in openings:
		if Geometry2D.is_point_in_polygon((a+b)*.5,polygon):return true
	return false
func _exit_tree() -> void:
	for n in pictures:
		if is_instance_valid(n) and n.get_parent()!=self:n.queue_free()
