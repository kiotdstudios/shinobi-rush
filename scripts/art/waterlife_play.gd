extends Node2D
## Real player/controller, real water costs, keyboard/gamepad. No movement automation or refill.
var player: PlayerController
var fx: Waterlife
var state: JavaScriptObject
var label: Label
func get_bounds() -> Rect2:return Rect2(0,0,1280,720)
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("15262c"))
	y_sort_enabled = true
	for u in range(-4,5):
		for v in range(-4,5):
			var water := BlightwoodWater.new()
			water.position = Vector2(700+(u-v)*36,410+(u+v)*18)
			water.z_index = -1
			add_child(water)
	player = load("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(300,410)
	add_child(player)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(640,360)
	add_child(camera)
	camera.make_current()
	fx = Waterlife.new()
	fx.actor = player
	add_child(fx)
	# Deterministic inspection row; production still uses populate_plants().
	for i in 6:fx.add_plant(Vector2(500+i*64,410),i,float(i)*0.37)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(24,24)
	ui.add_child(label)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__WATERLIFE_PLAY__ = state
func _process(_delta: float) -> void:
	label.text = "REAL WATER TEST | WASD / gamepad move • run right onto water • normal chakra cost\nChakra %.1f | water %s | contacts %d | no forced frog" % [player.chakra,player.over_water,fx.emissions]
	if state != null:
		state.ready = true
		state.clock = fx.clock
		state.x = player.global_position.x
		state.y = player.global_position.y
		state.wet = player.over_water
		state.chakra = player.chakra
		state.emissions = fx.emissions
		state.aura = fx.aura[0].visible
		state.pool = fx.pool.size()
		state.rolls = fx.rolls
		state.frogs = fx.frog_spawns
		var pads:=[]
		for plant in fx.plants:
			var push: Vector2=plant.get_meta("push")
			var ground: Vector2=plant.get_meta("ground_foot")
			pads.append({"variant":plant.frame,"x":ground.x,"y":ground.y,"draw_y":plant.global_position.y,"push":push.length(),"dip":push.y,"rate":float(plant.get_meta("return_speed")),"touches":int(plant.get_meta("touches")),"depth":plant.z_index})
		state.pads_json=JSON.stringify(pads)
