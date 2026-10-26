extends Node2D
## Real damage controllers and substitution presentation, isolated from combat AI.
const NAMES := ["S","SE","E","NE","N","NW","W","SW"]
const DIRS := [Vector2.DOWN,Vector2(1,1),Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1)]
var player: PlayerController
var bandit: Bandit
var fx: KnockbackPresentation
var log_fx: SubstitutionFx
var clock := 0.0
var next_at := 0.2
var index := 1
var auto := false
var triggers := 0
var speed := 0.5
var buttons: Dictionary = {}
var state: JavaScriptObject
var label: Label
var old_substitution := true
func get_bounds() -> Rect2:return Rect2(-2000,-2000,6000,6000)
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1b2a2f"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	old_substitution = Bandit.substitution_enabled
	Bandit.substitution_enabled = false
	player = load("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(250,420)
	add_child(player)
	player.camera.enabled = false
	player.get_node("HealthBar").hide()
	bandit = load("res://scenes/enemy/bandit.tscn").instantiate() as Bandit
	bandit.position = Vector2(610,420)
	add_child(bandit)
	bandit.set_physics_process(false)
	var camera := Camera2D.new()
	camera.position = Vector2(640,360)
	camera.zoom = Vector2.ONE*1.2
	add_child(camera)
	camera.make_current()
	fx = KnockbackPresentation.new()
	add_child(fx)
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "KNOCKBACK + IMPACT FRAMES | PLAYER / BANDIT | SUBSTITUTION VORTEX"
	title.position = Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	ui.add_child(title)
	var actions := NAMES+["All 8","Replay","Normal","Half"]
	for i in actions.size():
		var text: String = actions[i]
		var button := Button.new()
		button.text = text
		button.position = Vector2(24+(i%8)*150,65+int(i/8.0)*43)
		button.size = Vector2(140,36)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_click.bind(text))
		ui.add_child(button)
		buttons[text]={"x":button.position.x+70,"y":button.position.y+18}
	label = Label.new()
	label.position = Vector2(24,163)
	ui.add_child(label)
	for i in 3:
		var caption := Label.new()
		caption.position = Vector2([170,540,880][i],550)
		caption.text = ["PLAYER | accepted heavy hit","BANDIT | accepted heavy hit","LOG | wrap / wobble / drop / bounce / dissolve"][i]
		ui.add_child(caption)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__IMPACT_VORTEX__ = state
	Engine.time_scale = speed
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Bandit.substitution_enabled = old_substitution
func _click(text: String) -> void:
	if text in NAMES:
		index = NAMES.find(text)
		auto = false
		next_at = clock
	match text:
		"All 8":auto=true;index=0;next_at=clock
		"Replay":next_at=clock
		"Normal":speed=1.0;Engine.time_scale=speed
		"Half":speed=0.5;Engine.time_scale=speed
func _physics_process(delta: float) -> void:
	clock += delta
	if bandit.state != Bandit.State.HIT_REACT:bandit.set_physics_process(false)
	if clock>=next_at:
		_trigger()
		next_at = clock+3.4 if auto else INF
		if auto:index=(index+1)%8
func _trigger() -> void:
	var direction: Vector2 = DIRS[index].normalized()
	player.global_position = Vector2(250,420)
	player._hurt_t=0.0
	player.health=player.max_health
	player._hit_invuln=0.0
	player.state=PlayerController.State.IDLE
	player.facing8=direction
	player.velocity=Vector2.ZERO
	bandit.global_position=Vector2(610,420)
	bandit.hp=bandit.max_hp
	bandit.state=Bandit.State.IDLE
	bandit._sub_invuln=0.0
	bandit.flicker_hopping=false
	bandit.facing8=direction
	bandit.velocity=Vector2.ZERO
	# Establish fixture reset as the observer baseline, so healing/repositioning is not a hit.
	fx.advance(0.0)
	player.take_hit(5.0,direction,220.0)
	bandit.take_damage(5.0,direction,260.0,0.0)
	bandit.set_physics_process(true)
	if is_instance_valid(log_fx):log_fx.queue_free()
	log_fx=SubstitutionFx.spawn(self,Vector2(980,440),Vector2(1140,440))
	triggers += 1
func _process(_delta: float) -> void:
	label.text = "%.2fs | %.2fx | %d real hits shown | %d impact bursts | %d stationary recoil snapshots" % [clock,speed,triggers,fx.impacts,fx.snapshots]
	if state != null:
		state.ready=true
		state.clock=clock
		state.speed=speed
		state.triggers=triggers
		state.impacts=fx.impacts
		state.snapshots=fx.snapshots
		state.pool=fx.ghosts.size()
		state.player_kind=player.hurt_kind
		state.bandit_kind=bandit.react_kind
		state.player_x=player.global_position.x
		state.bandit_x=bandit.global_position.x
		state.log_age=log_fx._age if is_instance_valid(log_fx) else -1.0
		state.log_visible=log_fx._log_sprite.visible if is_instance_valid(log_fx) else false
		state.log_rotation=log_fx._log_sprite.rotation if is_instance_valid(log_fx) else 0.0
		state.log_collision=is_instance_valid(log_fx._log_body) if is_instance_valid(log_fx) else false
		state.vortex_pairs=log_fx._vortex.size() if is_instance_valid(log_fx) else 0
		state.buttons_json=JSON.stringify(buttons)
