extends Node
## Opt-in real gameplay/editor integration fixture. No authored map is saved.
var arena: TrainingArena
var player: PlayerController
var state: JavaScriptObject
var groups: Array = []
var selected := 0
var buttons: Array[Button] = []
var cells: Array = []
var bad := 0
var missing := 0
var junctions := 0
var operations := 0
var panel: VBoxContainer
var paint_mode := false
var paint_before := ""
var paint_target := ""
var last_shortcut := ""
const PAINT_CELL := Vector2(-144,252)

func _ready() -> void:
	arena=get_parent().get_node("TrainingArena") as TrainingArena
	player=arena.get_node("Player") as PlayerController
	arena.placed.autosave=false
	arena.editor.void_check=false
	arena.editor.set_open(false)
	arena.editor.void_sheet.modulate=Color("#1a2d2f")
	player.position=Vector2(-100,210)
	player.camera.enabled=false
	var cam := Camera2D.new()
	cam.position=Vector2(0,180)
	cam.zoom=Vector2(.9,.9)
	arena.add_child(cam)
	cam.make_current()
	for pair: Array in TerrainBlend.FAMILIES.values():groups.append(pair)
	for a in range(5):
		for b in range(a+1,5):
			for c in range(b+1,5):groups.append([TerrainBlend.MATERIALS[a],TerrainBlend.MATERIALS[b],TerrainBlend.MATERIALS[c]])
	var layer := CanvasLayer.new()
	layer.layer=100
	add_child(layer)
	panel=VBoxContainer.new()
	panel.position=Vector2(320,15)
	layer.add_child(panel)
	var label := Label.new()
	label.text="AUTO BLEND | real editor brushes | H hide controls | WASD move"
	panel.add_child(label)
	for row_index in 5:
		var row := HBoxContainer.new()
		panel.add_child(row)
		for i in range(row_index*4,row_index*4+4):
			var button := Button.new()
			button.focus_mode=Control.FOCUS_NONE
			button.text=" / ".join(groups[i])
			button.pressed.connect(_show.bind(i))
			row.add_child(button)
			buttons.append(button)
	var undo := Button.new()
	undo.focus_mode=Control.FOCUS_NONE
	undo.text="Undo / redo / save-reload check"
	undo.pressed.connect(_operations)
	panel.add_child(undo)
	buttons.append(undo)
	var brush_button := Button.new()
	brush_button.focus_mode=Control.FOCUS_NONE
	brush_button.text="Test real pointer brush"
	brush_button.pressed.connect(_brush)
	panel.add_child(brush_button)
	buttons.append(brush_button)
	var smart := Button.new()
	smart.text="Smart brush: mixed tile"
	smart.focus_mode=Control.FOCUS_NONE
	smart.pressed.connect(func():
		_brush()
		arena.editor.smart_terrain=true
		arena.editor.set_tool("paint","grass_dirt_06_b"))
	panel.add_child(smart)
	buttons.append(smart)
	var review := Button.new()
	review.text="Review selected tile family"
	review.focus_mode=Control.FOCUS_NONE
	review.pressed.connect(arena.editor.review_tile_family)
	panel.add_child(review)
	buttons.append(review)
	var fill := Button.new()
	fill.text="Connected fill with selected tile"
	fill.focus_mode=Control.FOCUS_NONE
	fill.pressed.connect(func():arena.editor.set_shape("fill"))
	panel.add_child(fill)
	buttons.append(fill)
	var erase := Button.new()
	erase.text="Erase pointer test"
	erase.focus_mode=Control.FOCUS_NONE
	erase.pressed.connect(func():arena.editor.set_tool("erase"))
	panel.add_child(erase)
	buttons.append(erase)
	_show(0)
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__AUTO_BLEND_REVIEW__=state

func _show(index: int) -> void:
	selected=index
	arena.placed.clear_all(false)
	arena.placed.clear_history()
	arena.editor._auto=null
	arena.editor.auto_blend=true
	cells.clear()
	var stripe: Array=[]
	var patch: Array=[]
	for u in range(-5,6):
		for v in range(-5,6):
			var pos := Vector2((u-v)*36,180+(u+v)*18)
			cells.append(pos)
			if absf(v-u-.5*sin(u))<.8 or Vector2(u+1,v+1).length()<1.7:stripe.append(pos)
			if u>1 and v>0:patch.append(pos)
	var mats: Array=groups[index]
	for step in mats.size():
		arena.editor.set_terrain(mats[step])
		arena.editor._apply_cells(cells if step==0 else stripe if step==1 else patch)
		arena.placed._changed(false)
	_audit()

func _audit() -> void:
	bad=0
	missing=0
	junctions=0
	var votes := {}
	for cell: Vector2 in cells:
		var floors := arena.placed.floor_tiles_in_cell(cell)
		if floors.size()!=1:
			missing+=1
			continue
		var obj: Dictionary=floors[0]
		if String(obj.id).begins_with("junction_"):junctions+=1
		var sig := TerrainBlend.signature_of(obj.id)
		if sig.size()!=4:
			missing+=1
			continue
		var offsets := [Vector2(0,-18),Vector2(36,0),Vector2(-36,0),Vector2(0,18)]
		for i in 4:
			var vertex: Vector2=cell+offsets[i]
			if not votes.has(vertex):votes[vertex]={}
			votes[vertex][sig[i]]=true
	for vote: Dictionary in votes.values():
		if vote.size()>1:bad+=1

func _operations() -> void:
	var snapshot := arena.placed.to_json_string()
	var undo_ok := arena.placed.undo()
	var redo_ok := arena.placed.redo()
	var restored := arena.placed.to_json_string()==snapshot
	arena.placed.load_dict(JSON.parse_string(snapshot))
	arena.editor._auto=null
	if undo_ok and redo_ok and restored and arena.placed.to_json_string()==snapshot:operations+=1
	_audit()

func _brush() -> void:
	paint_mode=true
	paint_before=String(arena.placed.cell_mat.get(PAINT_CELL,""))
	paint_target="ground" if paint_before!="ground" else "temple"
	arena.editor.set_open(true)
	arena.editor.set_terrain(paint_target)
	arena.editor.brush=1
	arena.editor.shape="brush"

func _process(_delta: float) -> void:
	if state==null:return
	state.ready=true
	state.group=selected
	state.bad=bad
	state.missing=missing
	state.junctions=junctions
	state.cells=cells.size()
	state.operations=operations
	state.autosave=arena.placed.autosave
	state.controls_visible=panel.visible
	state.x=player.position.x
	state.y=player.position.y
	state.paint_mode=paint_mode
	state.black_editor=arena.editor.shell!=null
	state.paint_before=paint_before
	state.paint_target=paint_target
	state.paint_mat=String(arena.placed.cell_mat.get(PAINT_CELL,""))
	state.family_json=JSON.stringify(arena.placed.terrain_families)
	state.paint_id=arena.editor.place_id
	state.smart=arena.editor.smart_terrain
	state.shape=arena.editor.shape
	state.tool=arena.editor.tool
	state.tile_count=arena.placed.floor_tiles_in_cell(PAINT_CELL).size()
	var options := []
	var dialog := arena.editor.family_dialog
	state.family_open=is_instance_valid(dialog) and dialog.visible
	if state.family_open:
		var choice := arena.editor.family_choice
		state.family_selected=str(choice.get_item_metadata(choice.selected))
		state.family_popup=choice.get_popup().visible
		state.family_focus=choice.get_popup().get_focused_item()
		for i in choice.item_count: options.append(str(choice.get_item_metadata(i)))
		var r := choice.get_global_rect()
		state.family_x=r.get_center().x+dialog.position.x
		state.family_y=r.get_center().y+dialog.position.y
		var ok := dialog.get_ok_button().get_global_rect()
		state.approve_x=ok.get_center().x+dialog.position.x
		state.approve_y=ok.get_center().y+dialog.position.y
	state.family_options=JSON.stringify(options)
	state.materials_json=JSON.stringify(arena.placed.cell_mat.values())
	state.last_shortcut=last_shortcut
	state.editor_open=arena.editor.open
	state.undo_count=arena.placed._undo.size()
	state.redo_count=arena.placed._redo.size()
	state.pending=arena.placed._pending.size()
	state.editor_note=arena.editor._note
	var pointer := arena.get_global_transform_with_canvas()*PAINT_CELL
	state.paint_x=pointer.x
	state.paint_y=pointer.y
	var fill_pointer := arena.get_global_transform_with_canvas()*(PAINT_CELL+AutoTile.NE)
	state.fill_x=fill_pointer.x
	state.fill_y=fill_pointer.y
	state.fill_mat=String(arena.placed.cell_mat.get(PAINT_CELL+AutoTile.NE,""))
	var rects := []
	for button in buttons:
		var r := button.get_global_rect()
		rects.append({"x":r.get_center().x,"y":r.get_center().y})
	state.buttons_json=JSON.stringify(rects)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_Z,KEY_Y]:
		last_shortcut="%s:%s" % [event.keycode,event.ctrl_pressed]
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_H:
		panel.visible=not panel.visible
		get_viewport().set_input_as_handled()
