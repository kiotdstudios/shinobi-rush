extends Node2D
## Deliberately staged art loop; normal gameplay uses the real controller's water predicate.
var fx: Waterlife
var body: SpriteActor
var clock := 0.0
var speed := 0.5
var paused := false
var frog_at := -8.0
var buttons: Dictionary = {}
var state: JavaScriptObject
var status: Label
var waters: Array[BlightwoodWater] = []
var stage: Node2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("15262c"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage = Node2D.new()
	stage.position = Vector2(620,365)
	stage.scale = Vector2(2,2)
	add_child(stage)
	for u in range(-4,5):
		for v in range(-4,5):
			var water := BlightwoodWater.new()
			water.auto_advance = false
			water.position = Vector2((u-v)*36,(u+v)*18)
			stage.add_child(water)
			waters.append(water)
	fx = Waterlife.new()
	fx.auto_advance = false
	stage.add_child(fx)
	for i in 6:fx.add_plant(stage.to_global(Vector2(-150+i*58,60)),i,float(i))
	body = SpriteActor.new()
	stage.add_child(body)
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "BLIGHTWOOD | water-running • foot chakra • lilies / lotus • purple frog"
	title.position = Vector2(24,16)
	title.add_theme_font_size_override("font_size",23)
	ui.add_child(title)
	var row := HBoxContainer.new()
	row.position = Vector2(24,55)
	ui.add_child(row)
	for text in ["Normal","Half","Pause","Step","Frog again","Play water test"]:
		var button := Button.new()
		button.text = text
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_click.bind(text))
		row.add_child(button)
		buttons[text] = button
	status = Label.new()
	status.position = Vector2(24,104)
	ui.add_child(status)
	var note := Label.new()
	note.position = Vector2(24,660)
	note.text = "Staged art loop • Frog forced here for inspection only • Gameplay: 1 in 1,000,000 per eligible water visit"
	ui.add_child(note)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__WATERLIFE__ = state
	advance(0.0)

func _click(text: String) -> void:
	match text:
		"Normal":speed = 1.0
		"Half":speed = 0.5
		"Pause":paused = not paused
		"Step":paused = true;advance(1.0/24.0)
		"Frog again":frog_at = clock-8.0
		"Play water test":get_tree().change_scene_to_file("res://scenes/art/waterlife_play.tscn")

func _process(delta: float) -> void:
	advance(0.0 if paused else delta*speed)

func advance(delta: float) -> void:
	clock += delta
	for water in waters:water.advance(delta)
	fx.advance(delta)
	var phase := fposmod(clock,4.0)/4.0
	var p := Vector2(-100+200*phase*2.0,0) if phase<0.5 else Vector2(100-200*(phase-0.5)*2.0,0)
	body.position = p
	body.show_animation(SpriteLibrary.get_instance().get_set("player_128"),"run","E" if phase<0.5 else "W")
	body.sprite.speed_scale = speed if not paused else 0.0
	fx.observe(body.global_position,true,delta)
	if clock-frog_at >= 7.0:
		frog_at = clock
		fx.spawn_frog(fx.plants[2].global_position)
	status.text = "%.2fs | %.2fx | %s | %d foot contacts | 16-frame water + 16-frame chakra + 16 frog poses" % [clock,speed,"PAUSED" if paused else "PLAY",fx.emissions]
	if state != null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.emissions = fx.emissions
		state.plants = fx.plants.size()
		state.frog_spawns = fx.frog_spawns
		state.phase = fx.frogs[-1].phase if not fx.frogs.is_empty() else "none"
		state.frog_age = fx.frogs[-1].age if not fx.frogs.is_empty() else 0.0
		state.pool = fx.pool.size()
		var rects := {}
		for key: String in buttons:
			var rect: Rect2 = buttons[key].get_global_rect()
			rects[key] = {"x":rect.get_center().x,"y":rect.get_center().y}
		state.buttons_json = JSON.stringify(rects)
