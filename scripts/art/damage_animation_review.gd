extends Node2D
## Isolated art review. Does not run HP, combat, respawn or enemy AI.
const DIRS := ["S","SE","E","NE","N","NW","W","SW"]
var sets: Dictionary = {}
var actors: Array[SpriteActor] = []
var origins: Array[Vector2] = []
var clock := 0.0
var speed := 0.5
var paused := false
var action := "hit_react"
var travel := false
var status: Label
var state: JavaScriptObject
var buttons: Dictionary = {}
var focus := "All headings"
var heading_labels: Array[Label] = []
var character_labels: Array[Label] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#24323a"))
	sets.player = SpriteSet.parse(FileAccess.get_file_as_string("res://assets/characters/player/player_128.manifest.json"),"res://assets/characters/player/player_128.manifest.json")
	sets.bandit = SpriteSet.parse(FileAccess.get_file_as_string(BanditVisual.ART_PATH),BanditVisual.ART_PATH)
	for row in 2:
		for col in 8:
			var actor := SpriteActor.new()
			actor.set_process(false)
			actor.position = Vector2(88+158*col,300+245*row)
			add_child(actor)
			actors.append(actor)
			origins.append(actor.position)
			var heading := Label.new()
			heading.text = DIRS[col]
			heading.position = actor.position+Vector2(-10,28)
			add_child(heading)
			heading_labels.append(heading)
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(16,12)
	ui.add_child(box)
	var title := Label.new()
	title.text = "DAMAGE ANIMATIONS | PLAYER + BANDIT | 128x128 / 8 directions"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"Hit reaction",_select.bind("hit_react"))
	_button(row,"Knockback",_select.bind("knockback"))
	_button(row,"Death",_select.bind("death"))
	_button(row,"Replay",func():clock=0.0;paused=false)
	_button(row,"Normal",func():speed=1.0)
	_button(row,"Half speed",func():speed=0.5)
	_button(row,"Pause",func():paused=not paused)
	_button(row,"Step",func():paused=true;clock+=1.0/24.0;_display())
	_button(row,"Travel",func():travel=not travel)
	var heading_row := HBoxContainer.new()
	box.add_child(heading_row)
	for heading: String in ["All headings","S","SE","E","NE","N","NW","W","SW"]:
		_button(heading_row,heading,_focus.bind(heading))
	status = Label.new()
	box.add_child(status)
	for i in 2:
		var label := Label.new()
		label.text = ["PLAYER","BANDIT"][i]
		label.position = Vector2(16,140+i*245)
		ui.add_child(label)
		character_labels.append(label)
	var note := Label.new()
	note.position = Vector2(16,670)
	note.text = "One-shot playback: final pose holds. Replay restarts. Travel demonstrates knockback separately from body art."
	ui.add_child(note)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__DAMAGE_REVIEW__ = state
		paused = "paused=1" in str(JavaScriptBridge.eval("window.location.search",true))
	_display()
	queue_redraw()

func _button(row: HBoxContainer,text: String,action_fn: Callable) -> void:
	var b := Button.new()
	b.text=text
	b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(action_fn)
	row.add_child(b)
	buttons[text]=b

func _select(id: String) -> void:
	action=id
	clock=0.0
	_display()

func _focus(heading: String) -> void:
	focus=heading
	_display()
	queue_redraw()

func _process(delta: float) -> void:
	if not paused:clock+=delta*speed
	_display()

func _display() -> void:
	var duration: float = (sets.player as SpriteSet).anim_duration(action)
	var progress := clampf(clock/maxf(duration,0.001)+0.00000001,0.0,1.0)
	var all_valid := true
	var frames: Array[int] = []
	for i in actors.size():
		var actor := actors[i]
		var s: SpriteSet = sets.player if i<8 else sets.bandit
		var success := actor.show_animation_at(s,action,DIRS[i%8],progress)
		all_valid = all_valid and success and not actor.fallback and not actor.flip
		actor.visible = focus=="All headings" or DIRS[i%8]==focus
		actor.scale = Vector2.ONE if focus=="All headings" else Vector2(3,3)
		actor.position = origins[i] if focus=="All headings" else Vector2(380 if i<8 else 880,560)
		heading_labels[i].visible = focus=="All headings"
		if travel and action=="knockback":
			var heading := Vector2.from_angle(deg_to_rad(float([90,45,0,-45,-90,-135,180,135][i%8])))
			actor.position -= heading*24.0*actor.scale.x*smoothstep(0.0,0.65,progress)
		frames.append(actor.sprite.frame)
	for i in character_labels.size():
		character_labels[i].position = Vector2(16,140+i*245) if focus=="All headings" else Vector2(280+i*500,170)
		character_labels[i].text = ["PLAYER","BANDIT"][i]+(" / "+focus if focus!="All headings" else "")
	if status!=null:status.text="%.2fs / %.2fs | %.2fx | %s | %s | frame %d | %s" % [clock,duration,speed,action,"PAUSED" if paused else "PLAY",frames[0]+1,"FINAL POSE" if progress>=1.0 else "ACTION"]
	if state!=null:
		state.ready=all_valid
		state.action=action
		state.clock=clock
		state.duration=duration
		state.speed=speed
		state.paused=paused
		state.travel=travel
		state.focus=focus
		state.count=actors.size()
		state.finished=progress>=1.0
		state.frames_json=JSON.stringify(frames)
		var rects := {}
		for key: String in buttons:
			var r: Rect2 = buttons[key].get_global_rect()
			rects[key]={"x":r.get_center().x,"y":r.get_center().y}
		state.buttons_json=JSON.stringify(rects)

func _draw() -> void:
	var markers: Array = origins if focus=="All headings" else [Vector2(380,560),Vector2(880,560)]
	for origin: Vector2 in markers:
		draw_line(origin-Vector2(8,0),origin+Vector2(8,0),Color("#687980"),1.0)
		draw_line(origin-Vector2(0,4),origin+Vector2(0,4),Color("#687980"),1.0)
