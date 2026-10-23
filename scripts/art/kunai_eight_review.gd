extends Node2D
## Two skins, one choreography/profile. This scene never runs movement, damage or enemy AI.
var actors: Dictionary = {}
var status: Label
var character := "both"
var direction := "SE"
var action := "combo"
var clock := 0.0
var speed := 0.5
var paused := false
var state: JavaScriptObject
var controls: Array[BaseButton] = []
var bodies_on := true
var weapons_on := true
var trails_on := true

func _ready() -> void:
	var bridge := get_node_or_null("/root/WebBridge")
	if bridge!=null:bridge.set_process(false)
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set=KosenFloorTileset.build()
	add_child(floor_layer)
	for x in range(-20,21):
		for y in range(-20,21):floor_layer.set_cell(Vector2i(x,y),KosenFloorTileset.pick_interior_source_id(x,y),Vector2i.ZERO)
	for id: String in ["player","bandit"]:
		var actor := KunaiPoseActor.new()
		add_child(actor)
		actors[id]=actor
		var label := Label.new()
		label.text=id.to_upper()
		label.position=Vector2(-25,-136)
		label.scale=Vector2.ONE*.5
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		actor.add_child(label)
	var camera := Camera2D.new()
	camera.position=Vector2(0,-42)
	camera.zoom=Vector2.ONE*2
	add_child(camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := VBoxContainer.new()
	panel.position=Vector2(12,get_viewport_rect().size.y-204)
	ui.add_child(panel)
	get_viewport().size_changed.connect(func():panel.position.y=get_viewport_rect().size.y-204)
	status=Label.new()
	panel.add_child(status)
	var timing := HBoxContainer.new()
	panel.add_child(timing)
	button(timing,"Normal",func():speed=1;paused=false)
	button(timing,"Half speed",func():speed=.5;paused=false)
	button(timing,"Pause",func():paused=not paused)
	button(timing,"Step",step_pose)
	for options in [["both","player","bandit"],["S","SE","E","NE","N","NW","W","SW"],["combo","light1","light2","light3","dash_attack","guard"]]:
		var row := HBoxContainer.new()
		panel.add_child(row)
		for id: String in options:
			button(row,id,func():
				if id in ["both","player","bandit"]:character=id
				elif id in SpriteSet.DIRS8:direction=id;clock=0
				else:action=id;clock=0)
	var layers := HBoxContainer.new()
	panel.add_child(layers)
	for id: String in ["Body","Blade","Trails"]:
		var check := CheckBox.new()
		check.text=id
		check.button_pressed=true
		check.focus_mode=Control.FOCUS_NONE
		check.toggled.connect(func(on: bool):
			if id=="Body":bodies_on=on
			elif id=="Blade":weapons_on=on
			else:trails_on=on)
		layers.add_child(check)
		controls.append(check)
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__KUNAI_EIGHT__=state

func button(row: HBoxContainer, label: String, callback: Callable) -> void:
	var b := Button.new()
	b.text=label
	b.custom_minimum_size.y=32
	b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(callback)
	row.add_child(b)
	controls.append(b)

func selection() -> Dictionary:
	var ids: Array = ["light1","light2","light3"] if action=="combo" else [action]
	var total := 0.0
	for id: String in ids:total+=float(KunaiCombatData.profile(id).duration_ms)
	var time := fposmod(clock*1000.0,total)
	var offset := 0.0
	for id: String in ids:
		var duration := float(KunaiCombatData.profile(id).duration_ms)
		if time<duration:return {"action":id,"time":time,"offset":offset,"total":total}
		time-=duration
		offset+=duration
	return {"action":ids.back(),"time":0.0,"offset":0.0,"total":total}

func step_pose() -> void:
	paused=true
	var selected := selection()
	var pose := KunaiCombatData.pose_at("player",direction,selected.action,selected.time)
	if not pose.is_empty():clock=fposmod(float(selected.offset)+float(pose.start_ms)+float(pose.duration_ms)+0.001,float(selected.total))/1000.0

func _process(delta: float) -> void:
	if not paused:clock+=delta*speed
	var selected := selection()
	clock=fposmod(clock,float(selected.total)/1000.0)
	var snapshots: Dictionary = {}
	var phase := ""
	var frame := 0
	var missing := 0
	for id: String in actors:
		var actor: KunaiPoseActor=actors[id]
		actor.visible=character=="both" or character==id
		actor.position.x=(-145.0 if id=="player" else 145.0) if character=="both" else 0.0
		var pose := KunaiCombatData.pose_at(id,direction,selected.action,selected.time)
		if pose.is_empty():
			actor.visible=false
			missing+=1
			continue
		actor.show_pose(pose)
		actor.body.visible=bodies_on
		actor.weapon.visible=weapons_on
		actor.hand.visible=bodies_on and weapons_on
		actor.swipe.visible=trails_on and int(pose.get("swipe_frame",-1))>=0
		phase=str(pose.phase)
		frame=int(pose.frame_index)
		snapshots[id]={"visible":actor.visible,"frame":frame,"body":pose.body_frame,"hand_px":pose.right_hand_px,"grip":[actor.grip.position.x,actor.grip.position.y],"angle":pose.weapon_angle_deg,"layer":pose.weapon_layer,"body_visible":actor.body.visible,"blade_visible":actor.weapon.visible,"trail_visible":actor.swipe.visible,"texture_cache":actor._cache.size()}
	var count := KunaiCombatData.frames("player",direction,selected.action).size()
	status.text="KUNAI | %s | %s | %s %02d/%02d | %s | %.2fx | %.3fs" % [character.to_upper(),direction,selected.action,frame+1,count,phase.to_upper(),speed,clock]
	if state!=null:
		state.ready=true
		state.character=character
		state.direction=direction
		state.action=selected.action
		state.mode=action
		state.frame=frame
		state.speed=speed
		state.paused=paused
		state.time=clock
		state.phase=phase
		state.missing=missing
		state.sprites_json=JSON.stringify(snapshots)
		var rects: Dictionary = {}
		for control in controls:
			var rect := control.get_global_rect()
			rects[control.text]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		state.controls_json=JSON.stringify(rects)
