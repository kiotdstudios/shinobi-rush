extends Node
## Opt-in actual arena fixture. Never writes an authored/user layout.
var arena: TrainingArena
var player: PlayerController
var bridge: JavaScriptObject
var camera: Camera2D
var buttons: Array[Button]=[]
var operations:=0
var demo:=false
func _ready() -> void:
	arena=get_parent().get_node("TrainingArena") as TrainingArena
	player=arena.get_node("Player") as PlayerController
	arena.placed.autosave=false
	arena.placed.save_path="user://cliff-kit-demo-review.json"
	arena.editor.void_check=false
	arena.editor.void_sheet.modulate=Color("#1a2d2f")
	arena.editor.set_open(false)
	arena.placed.clear_all(false)
	for enemy in get_tree().get_nodes_in_group("enemy"):enemy.queue_free()
	var query:=str(JavaScriptBridge.eval("window.location.search",true)) if OS.has_feature("web") else ""
	demo="cliffs=review" in query or "cliffs=play" in query or "--cliffs-review" in OS.get_cmdline_user_args()
	if demo:
		var source:=FileAccess.get_file_as_string("res://assets/environment/blightwood/cliff_kit/demo-layout.json")
		if "cliffs=play" in query and OS.has_feature("web"):
			var saved: Variant=JavaScriptBridge.eval("localStorage.getItem('shinobi-rush:cliff-demo-review:v1')",true)
			if saved!=null and JSON.parse_string(str(saved)) is Dictionary:source=str(saved)
		arena.placed.load_dict(JSON.parse_string(source))
		arena.placed.clear_history()
	else:
		for u in range(-9,10):
			for v in range(-9,10):arena.placed.add("ground9_center",Vector2(36*(u-v),18*(u+v)),false)
		arena.placed.add("cliff_ledge_se",Vector2(-164,-154),false)
		arena.placed.add("earth_stairs_se",Vector2.ZERO,false)
		arena.placed.add("cliff_ledge_se",Vector2(108,-18),false)
		arena.placed.add("waterfall_small",Vector2(250,53),false)
		for p in [Vector2(252,54),Vector2(288,72),Vector2(216,72)]:arena.placed.add("water9_center",p,false)
		arena.placed._changed(false)
	player.position=Vector2(-90,80)
	player.camera.enabled=false
	camera=Camera2D.new()
	camera.position=Vector2(0,-20) if demo else Vector2(50,-30)
	camera.zoom=Vector2(.9,.9) if demo else Vector2(1.4,1.4)
	arena.add_child(camera)
	camera.make_current()
	if demo:
		player.position=arena.placed.spawn_point() if "cliffs=play" in query else Vector2(-340,90)
		var layer:=CanvasLayer.new()
		layer.layer=100
		add_child(layer)
		var row:=HBoxContainer.new()
		row.position=Vector2(310,48)
		layer.add_child(row)
		for caption in ["SE approach","SW approach","Overview","Editor","Undo / redo / reload","Wall test","Waterfall"]:
			var button:=Button.new()
			button.text=caption
			button.focus_mode=Control.FOCUS_NONE
			button.pressed.connect(_action.bind(buttons.size()))
			row.add_child(button)
			buttons.append(button)
		var caption:=Label.new()
		caption.text="CLIFF DEMO — saves separately from your world"
		caption.position=Vector2(310,83)
		layer.add_child(caption)
		if arena.editor.shell!=null:
			var play:=arena.editor.shell.btn_play
			play.pressed.disconnect(Callable(arena.editor.shell,"_on_playtest"))
			play.pressed.connect(_play_demo)
			play.tooltip_text="Play the current cliff demo; your saved world stays unchanged"
	if OS.has_feature("web"):
		bridge=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__CLIFF_REVIEW__=bridge
func _process(_delta: float) -> void:
	if bridge!=null:
		bridge.ready=true
		bridge.x=player.position.x
		bridge.y=player.position.y
		bridge.elevation=player.elevation
		bridge.depth=player.visual.z_index
		bridge.over_water=player.over_water
		bridge.chakra=player.chakra
		bridge.operations=operations
		bridge.editor_open=arena.editor.open
		bridge.cells=arena.placed.cliff_world.occupied.size() if is_instance_valid(arena.placed.cliff_world) else 0
		var rects:=[]
		for button in buttons:rects.append({"x":button.get_global_rect().get_center().x,"y":button.get_global_rect().get_center().y})
		bridge.buttons_json=JSON.stringify(rects)
		var cards:={}
		if arena.editor.open:
			for id in CliffKit.IDS:
				var button: Button=arena.editor._palette_buttons.get(id)
				if button!=null:
					var r:=button.get_global_rect()
					cards[id]={"x":r.get_center().x,"y":r.get_center().y,"visible":button.is_visible_in_tree()}
		bridge.cards_json=JSON.stringify(cards)
		bridge.tool=arena.editor.tool
		bridge.place_id=arena.editor.place_id
		var pointer:=arena.get_global_transform_with_canvas()*Vector2(-288,-180)
		bridge.paint_x=pointer.x
		bridge.paint_y=pointer.y
		bridge.placed_count=arena.placed.objects.size()
		bridge.probe_a=is_instance_valid(arena.placed.cliff_world) and arena.placed.cliff_world.occupied.has(Vector2(-288,-180))
		bridge.probe_b=is_instance_valid(arena.placed.cliff_world) and arena.placed.cliff_world.occupied.has(Vector2(-216,-144))
		var tools:={}
		for key in arena.editor._tool_buttons:
			var r: Rect2=arena.editor._tool_buttons[key].get_global_rect()
			tools[key]={"x":r.get_center().x,"y":r.get_center().y}
		bridge.tools_json=JSON.stringify(tools)
		if arena.editor.shell!=null:
			var r:=arena.editor.shell.btn_play.get_global_rect()
			bridge.play_x=r.get_center().x
			bridge.play_y=r.get_center().y
			var row: Dictionary=arena.editor.shell.layer_rows.get("Blightwood Cliffs",{})
			if not row.is_empty():
				var eye: Rect2=row.eye.get_global_rect()
				bridge.layer_x=eye.get_center().x
				bridge.layer_y=eye.get_center().y
		bridge.cliffs_visible=not bool(arena.placed.hidden_types.get("Blightwood Cliffs",false))
		for o in arena.placed.objects:
			if o.id=="cliff_cascade":
				var water:=o.nodes[0] as BlightwoodWater
				bridge.fall_frame=water._cascade_atlas.region.position.x
				bridge.foam_frame=water.foam.frame
				bridge.lip_y=water.fall.global_position.y-48+8
				bridge.basin_y=water.fall.global_position.y-48+74
				bridge.foam_y=water.foam.global_position.y

func _action(index: int) -> void:
	if index in [0,1]:
		var mouth:=Vector2(-288,54) if index==0 else Vector2(396,144)
		var run:=Vector2(72,-36) if index==0 else Vector2(-72,-36)
		player.position=mouth-run*.35
		player.elevation=0.0
		camera.position=mouth+run
		camera.zoom=Vector2(1.4,1.4)
	elif index==2:
		camera.position=Vector2(0,-20)
		camera.zoom=Vector2(.9,.9)
	elif index==3:
		arena.editor.set_open(not arena.editor.open)
		if arena.editor.browser!=null:
			arena.editor.browser.set_tab("objects")
			arena.editor.browser.set_category("Blightwood Cliffs")
	elif index==6:
		camera.position=Vector2(-18,60)
		camera.zoom=Vector2(2,2)
	elif index==5:
		player.position=Vector2(-162,81)
		player.elevation=0.0
		camera.position=Vector2(-108,18)
		camera.zoom=Vector2(1.4,1.4)
	else:
		var snapshot:=arena.placed.to_json_string()
		var module:=arena.placed.add("cliff_ground",Vector2(-648,0),true)
		arena.placed.move(module,Vector2(-612,18),true)
		var moved:=arena.placed.undo() and arena.placed.redo()
		arena.placed.remove(module,true)
		var deleted:=arena.placed.undo() and arena.placed.redo()
		var previous_path:=arena.placed.save_path
		arena.placed.save_path="user://cliff-kit-review.json"
		var saved:=arena.placed.save()
		var disk:=FileAccess.get_file_as_string(arena.placed.save_path)
		arena.placed.load_dict(JSON.parse_string(disk))
		DirAccess.remove_absolute(arena.placed.save_path)
		arena.placed.save_path=previous_path
		if moved and deleted and saved and arena.placed.to_json_string()==snapshot:operations+=1


func _play_demo() -> void:
	var snapshot:=arena.placed.to_json_string()
	JavaScriptBridge.eval("localStorage.setItem('shinobi-rush:cliff-demo-review:v1',"+JSON.stringify(snapshot)+")",true)
	MapEditorMode.open_page("index.html?cliffs=play&editor=1")
