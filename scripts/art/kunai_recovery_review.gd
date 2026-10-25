extends Node2D
var nav: ArenaNav
var player: PlayerController
var target: Bandit
var clock := 0.0
var speed := 1.0
var paused := false
var last_result := ""
var projectiles: Array[Node2D] = []
var state: JavaScriptObject
var buttons: Dictionary = {}
var status: Label
var authored: HealthGourd
func get_bounds() -> Rect2: return Rect2(0,0,1280,720)
func _ready() -> void:
	var floor_layer := Node2D.new()
	floor_layer.z_index=-20
	floor_layer.draw.connect(_draw_floor.bind(floor_layer))
	add_child(floor_layer)
	var camera := Camera2D.new()
	camera.position=Vector2(640,360)
	add_child(camera)
	player=(load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.position=Vector2(700,590)
	player.set_physics_process(false)
	player.camera.enabled=false
	player.get_node("HealthBar").hide()
	player.inventory.counts["kunai"]=0
	camera.make_current()
	_make_target()
	var wall := StaticBody2D.new()
	wall.position=Vector2(1020,450)
	var shape := RectangleShape2D.new()
	shape.size=Vector2(40,170)
	var collider := CollisionShape2D.new()
	collider.shape=shape
	wall.add_child(collider)
	add_child(wall)
	authored=HealthGourd.new()
	authored.kind="kunai"
	authored.position=Vector2(110,225)
	add_child(authored)
	authored.set_process(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text="KUNAI — white pickup / physical recovery"
	title.position=Vector2(25,16)
	title.add_theme_font_size_override("font_size",28)
	layer.add_child(title)
	var note := Label.new()
	note.text="Character: damage, no drop   •   Surface: stick, fall, recover   •   Miss: tumble, two bounces, clink, collect"
	note.position=Vector2(25,57)
	layer.add_child(note)
	status=Label.new()
	status.position=Vector2(25,100)
	layer.add_child(status)
	var actions := ["Character", "Miss", "Surface", "Bandit miss", "Collect", "Normal", "Half", "Pause", "Reset"]
	for i in actions.size():
		var text: String=actions[i]
		var button := Button.new()
		button.text=text
		button.position=Vector2(20+i*139,652)
		button.size=Vector2(131,44)
		button.pressed.connect(_action.bind(text))
		layer.add_child(button)
		buttons[text]={"x":button.position.x+65,"y":674}
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__KUNAI_RECOVERY__=state
	queue_redraw()
func _make_target() -> void:
	if is_instance_valid(target): target.queue_free()
	target=(load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate()
	add_child(target)
	target.position=Vector2(350,300)
	target.set_physics_process(false)
func _action(action: String) -> void:
	match action:
		"Normal": speed=1.0
		"Half": speed=0.5
		"Pause": paused=not paused
		"Reset": get_tree().reload_current_scene()
		"Collect":
			for node in get_tree().get_nodes_in_group("spent_kunai_pickup"):
				if node.available:
					player.position=node.global_position
					node.collect(player)
		"Character", "Miss", "Surface", "Bandit miss":
			last_result=""
			if action=="Character": _make_target()
			var from := Vector2(100,300) if action=="Character" else Vector2(760,450) if action=="Surface" else Vector2(100,530) if action=="Bandit miss" else Vector2(100,450)
			var projectile: Node2D=BanditKunai.spawn(self,from,Vector2.RIGHT,null,null) if action=="Bandit miss" else PlayerKunai.spawn(self,from,Vector2.RIGHT,player)
			projectile.set_physics_process(false)
			projectiles.append(projectile)
func _process(delta: float) -> void:
	var dt := 0.0 if paused else delta*speed
	clock+=dt
	# Tick presentation timers only; the isolated target does not run AI/movement.
	target._hit_flash_timer=maxf(target._hit_flash_timer-dt,0.0)
	if target.state==Bandit.State.HIT_REACT:
		target._hit_react_timer=maxf(target._hit_react_timer-dt,0.0)
		if target._hit_react_timer<=0.0:
			target.state=Bandit.State.IDLE
			target.velocity=Vector2.ZERO
	for projectile in projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.step(dt)
			if projectile.hit_result!="":
				last_result=projectile.hit_result
	var recovery: Array=[]
	for node in get_tree().get_nodes_in_group("kunai_recovery"):
		node.set_physics_process(false)
		node.advance(dt)
		if not node.is_queued_for_deletion(): recovery.append({"surface":node.surface,"age":node.age,"clinks":node.clinks,"recoverable":node.recoverable})
	for node in get_tree().get_nodes_in_group("spent_kunai_pickup"):
		node.set_process(false)
		node._process(dt)
	authored._process(dt)
	var drops := 0
	for node in get_tree().get_nodes_in_group("spent_kunai_pickup"):
		if node.available: drops+=1
	status.text="Clock %.2fs   %.1f×   •   Result: %s   •   Resting kunai: %d   •   Inventory: %d" % [clock,speed,last_result,drops,player.inventory.count_of("kunai")]
	if state!=null:
		state.ready=true
		state.clock=clock
		state.speed=speed
		state.paused=paused
		state.result=last_result
		state.drops=drops
		state.inventory=player.inventory.count_of("kunai")
		state.recovery_json=JSON.stringify(recovery)
		state.buttons_json=JSON.stringify(buttons)
func _draw_floor(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(0,0,1280,720),Color("101d22"))
	for x in range(-700,1800,72):
		canvas.draw_line(Vector2(x,150),Vector2(x+1000,630),Color("263438"))
		canvas.draw_line(Vector2(x,630),Vector2(x+1000,150),Color("263438"))
func _draw() -> void:
	draw_rect(Rect2(1000,365,40,170),Color("54636a"))
	draw_rect(Rect2(1000,365,40,170),Color("9aa5a8"),false,2)
