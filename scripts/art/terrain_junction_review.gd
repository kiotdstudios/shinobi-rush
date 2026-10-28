extends Node
## Opt-in real-game floor demo; never writes the owner's map.
var arena: TrainingArena
var player: PlayerController
var state: JavaScriptObject
var selected := 0
var before := false
var demo: Array[Dictionary] = []
var groups: Array = []
var buttons: Array[Button] = []
var compare: Button
var pieces := 0
var junctions := 0
var camera: Camera2D
var pair_families: Array = []
var controls: VBoxContainer

func _ready() -> void:
	arena = get_parent().get_node("TrainingArena") as TrainingArena
	player = arena.get_node("Player") as PlayerController
	arena.placed.autosave = false
	arena.editor.void_check = false
	arena.editor.void_sheet.modulate = Color("#1a2d2f")
	player.position = Vector2(-100,220)
	player.camera.enabled = false
	camera = Camera2D.new()
	camera.position = Vector2(0,190)
	camera.zoom = Vector2(.85,.85)
	arena.add_child(camera)
	camera.make_current()
	groups = TerrainJunctionArt.data().pairs + TerrainJunctionArt.data().junctions
	pair_families = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/blightwood/terrain_transitions/transitions.art.json")).families
	pair_families.append({"id":"path_dirt","zero":"ground","one":"dirt"})
	groups.append({"id":"PR245 exact fixture","tiles":[]})
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	controls = panel
	panel.position = Vector2(330,25)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "PR247 | WASD move | H hide controls | auto-placement remains with Aki"
	panel.add_child(label)
	for row_index in 4:
		var row := HBoxContainer.new()
		panel.add_child(row)
		for i in range(row_index*4,mini(row_index*4+4,groups.size())):
			var button := Button.new()
			button.text = str(groups[i].get("id"," / ".join(groups[i].get("materials",[]))))
			button.pressed.connect(_show.bind(i))
			row.add_child(button)
			buttons.append(button)
	compare = Button.new()
	compare.text = "Compare pair-only approximation / exact art"
	compare.pressed.connect(_toggle)
	panel.add_child(compare)
	_show(0)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__JUNCTION_REVIEW__ = state

func _toggle() -> void:
	before = not before
	_show(selected)

func _field(p: Vector2, materials: Array) -> String:
	# Connected T, diagonals, a tiny island and a crossing, all sharing global vertices.
	if materials.size()==2:
		return materials[1] if absf(p.y-p.x-.6*sin(p.x))<.8 or p.length()<1.6 else materials[0]
	if (p-Vector2(-2,2)).length()<.8:
		return materials[2]
	if absf(p.y-p.x)<.65 or (p.x>0 and absf(p.y)<.65):
		return materials[1]
	return materials[2] if p.x>1 and p.y>0 else materials[0]

func _show(index: int) -> void:
	selected = index
	# Isolated in-memory test floor. Clearing the loaded copy removes occluding
	# props and old colliders; autosave stays off and no authored file is changed.
	arena.placed.clear_all(false)
	demo.clear()
	for u in range(-9,10):
		for v in range(-9,10):
			arena.placed.add("grass_path_15_a",Vector2((u-v)*36,180+(u+v)*18),false)
	pieces = 0
	junctions = 0
	if index==12:
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/blightwood/terrain_junctions/pr245-fixture.json"))
		for record: Dictionary in fixture.cells:
			var id: String = record.before_id if before else record.after_id
			var pos := Vector2(float(record.cell[0])-216,float(record.cell[1])+180)
			arena.placed.paint_cell(id,pos)
			if not arena.placed.ground_at(pos).is_empty():pieces+=1
			if String(record.after_id).begins_with("junction_"):junctions+=1
			demo.append(arena.placed.ground_at(pos))
		arena.placed._changed(false)
		return
	var group: Dictionary = groups[index]
	var materials: Array = group.get("materials",[group.get("zero",""),group.get("one","")])
	for u in range(-5,6):
		for v in range(-5,6):
			var sig: Array = []
			for offset: Vector2 in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(-.5,.5),Vector2(.5,.5)]:
				sig.append(_field(Vector2(u,v)+offset,materials))
			var id := _resolve(sig)
			if id.begins_with("junction_"):
				junctions+=1
			if before and id.begins_with("junction_"):
				# Explicit visual approximation only, NOT PR245's vertex-voting algorithm.
				for i in 4:
					if sig[i]==materials[2]:sig[i]=materials[0]
				id=_resolve(sig)
			var pos := Vector2((u-v)*36,180+(u+v)*18)
			arena.placed.paint_cell(id,pos)
			if not arena.placed.ground_at(pos).is_empty():pieces+=1
	# Every actual export, including all A/B/C variants, rendered on native cells.
	var n := 0
	for tile: Dictionary in group.tiles:
		arena.placed.paint_cell(tile.id,Vector2((n%12-5)*72,-180+(n/12)*36))
		n+=1
	for obj: Dictionary in arena.placed.objects:
		if String(obj.id).begins_with("junction_") or String(obj.id).begins_with("path_temple_") or String(obj.id).begins_with("path_rock_") or String(obj.id).begins_with("grass_") or String(obj.id).begins_with("dirt_") or String(obj.id).begins_with("temple_rock_") or String(obj.id).begins_with("path_dirt_"):
			# Track only cells in our demo area, not original map content outside it.
			if absf(obj.pos.x)<=432 and obj.pos.y>=-180 and obj.pos.y<=370:
				demo.append(obj)
	arena.placed._changed(false)

func _resolve(sig: Array) -> String:
	var id := TerrainJunctionArt.tile_id(sig)
	if id!="":return id
	for f: Dictionary in pair_families:
		var zero: String = "ground" if f.zero=="path" else String(f.zero)
		var one: String = "ground" if f.one=="path" else String(f.one)
		var valid := true
		var mask := 0
		for i in 4:
			valid = valid and sig[i] in [zero,one]
			if sig[i]==one:mask|=[8,4,2,1][i]
		if valid:return "%s_%02d_a" % [f.id,mask]
	return "ground9_center"

func _process(_delta: float) -> void:
	if state==null:return
	state.ready=true
	state.group=selected
	state.before=before
	state.pieces=pieces
	state.junctions=junctions
	state.player_x=player.position.x
	state.player_y=player.position.y
	state.autosave=arena.placed.autosave
	state.controls_visible=controls.visible
	var rects := []
	for button in buttons:
		var r := button.get_global_rect()
		rects.append({"x":r.get_center().x,"y":r.get_center().y})
	state.buttons_json=JSON.stringify(rects)
	var c := compare.get_global_rect()
	state.compare_x=c.get_center().x
	state.compare_y=c.get_center().y

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_H:
		controls.visible=not controls.visible
		get_viewport().set_input_as_handled()
