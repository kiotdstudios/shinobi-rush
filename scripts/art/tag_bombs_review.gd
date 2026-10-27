extends Node2D
## Real pickup/projectile review; same classes and inventory used by gameplay.
var player: PlayerController
var pickups: Array[HealthGourd] = []
var projectiles: Array[PaperTagBomb] = []
var speed := 1.0
var clock := 0.0
var paused := false
var state: JavaScriptObject
var buttons: Dictionary = {}
var status: Label

func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(640,360)
	add_child(cam)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	# Actor is a real player with inventory. Keep controls disabled only in this isolated review.
	add_child(player)
	player.position = Vector2(640,560)
	player.set_physics_process(false)
	player.camera.enabled = false
	player.get_node("HealthBar").hide()
	cam.make_current()
	for i in 2:
		var pickup := HealthGourd.new()
		pickup.kind = "tag_bomb" if i == 0 else "smoke_tag_bomb"
		pickup.position = Vector2(350 + i * 580,330)
		add_child(pickup)
		pickup.set_process(false)
		pickups.append(pickup)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "TAG BOMBS — pickup / throw / detonation"
	title.position = Vector2(30,18)
	title.add_theme_font_size_override("font_size",28)
	layer.add_child(title)
	var note := Label.new()
	note.text = "Ivory explosive • Black smoke bomb / white ink / red seams     |     Smoke blocks sight both ways while it stands"
	note.position = Vector2(30,58)
	layer.add_child(note)
	for i in 2:
		var label := Label.new()
		label.text = "EXPLOSIVE TAG BOMB" if i == 0 else "SMOKE TAG BOMB"
		label.position = Vector2(235+i*580,210)
		layer.add_child(label)
	var actions := ["Collect both", "Throw explosive", "Throw smoke", "Normal", "Half speed", "Pause", "Reset"]
	for i in actions.size():
		var button := Button.new()
		var text: String = actions[i]
		button.text = text
		button.position = Vector2(30+i*175,650)
		button.size = Vector2(165,44)
		button.pressed.connect(_action.bind(text))
		layer.add_child(button)
		buttons[text] = {"x":button.position.x+82,"y":672}
	status = Label.new()
	status.position = Vector2(30,103)
	layer.add_child(status)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__BOMB_REVIEW__ = state
	queue_redraw()

func _action(action: String) -> void:
	match action:
		"Collect both":
			for pickup in pickups:
				if pickup.available:
					pickup.collect(player)
		"Throw explosive", "Throw smoke":
			var kind := "tag_bomb" if action == "Throw explosive" else "smoke_tag_bomb"
			var index := 0 if kind == "tag_bomb" else 1
			player.inventory.add(kind)
			player.inventory.assign_item("down",kind)
			player._throw_t = 0.0
			player.state = PlayerController.State.IDLE
			player.global_position = Vector2(140+index*580,520)
			player.facing8 = Vector2.RIGHT
			if player.use_slot("down"):
				player._tick_throw(player.THROW_TIME*0.9)
			for node in get_children():
				if node is PaperTagBomb and not projectiles.has(node):
					node.set_physics_process(false)
					projectiles.append(node)
		"Normal": speed = 1.0
		"Half speed": speed = 0.5
		"Pause": paused = not paused
		"Reset": get_tree().reload_current_scene()

func _process(delta: float) -> void:
	var dt := 0.0 if paused else delta*speed
	clock += dt
	for pickup in pickups:
		pickup._process(dt)
	for bomb in projectiles:
		if is_instance_valid(bomb) and not bomb.is_queued_for_deletion():
			bomb.advance(dt)
	status.text = "Clock %.2fs   •   %.1f×   •   Explosive bag: %d   Smoke bag: %d" % [clock,speed,player.inventory.count_of("tag_bomb"),player.inventory.count_of("smoke_tag_bomb")]
	if state != null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.explosive_count = player.inventory.count_of("tag_bomb")
		state.smoke_count = player.inventory.count_of("smoke_tag_bomb")
		state.collected = not pickups[0].available and not pickups[1].available
		state.buttons_json = JSON.stringify(buttons)
		var live: Array = []
		for bomb in projectiles:
			if is_instance_valid(bomb):
				live.append({"kind":bomb.art_kind,"phase":int(bomb.phase),"detonated":bomb.detonated,"damaged":bomb.damaged.size(),"x":bomb.position.x,"age":bomb.age,"cover_radius":bomb.cover_radius() if bomb is SmokeTagBomb else 0.0,"banks":bomb.clouds.size() if bomb is SmokeTagBomb else 0})
		state.bombs_json = JSON.stringify(live)

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("101d22"))
	for x in range(-700,1800,72):
		draw_line(Vector2(x,150),Vector2(x+1000,650),Color("263438"))
		draw_line(Vector2(x,650),Vector2(x+1000,150),Color("263438"))
