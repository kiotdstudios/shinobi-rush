extends Node2D
## Real-controller visual review. Playback helpers are isolated from the normal game.
var player: PlayerController
var bandit: Bandit
var wall: StaticBody2D
var state: JavaScriptObject
var buttons := {}
var label: Label
var auto := false
var index := 0
var clock := 0.0
var next_at := 0.0
var speed := 1.0
var blocked := false
var legacy := false
var use_bandit := false
var release_ticks := 0
var last_samples: Array = []
var path: Array[Vector2] = []
var last_count := 0
var result := {}
var _ground: Node2D
var DIRS := [Vector2.DOWN,Vector2(1,1).normalized(),Vector2.RIGHT,Vector2(1,-1).normalized(),Vector2.UP,Vector2(-1,-1).normalized(),Vector2.LEFT,Vector2(-1,1).normalized()]
const NAMES := ["S","SE","E","NE","N","NW","W","SW"]
func get_bounds() -> Rect2:return Rect2(-1000,-1000,3000,3000)
func _ready() -> void:
	_ground=Node2D.new();_ground.z_index=-20;_ground.draw.connect(_floor.bind(_ground));add_child(_ground)
	player=(load("res://scenes/player/player.tscn") as PackedScene).instantiate();player.position=Vector2(640,430);add_child(player)
	player.camera.enabled=false
	player.get_node("HealthBar").hide()
	bandit=(load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate();bandit.position=Vector2(100,650);add_child(bandit);bandit.set_physics_process(false);bandit.hide()
	var camera:=Camera2D.new();camera.position=Vector2(640,360);add_child(camera);camera.make_current()
	wall=StaticBody2D.new();var collider:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(28,230);collider.shape=box;wall.add_child(collider);wall.position=Vector2(726,400);add_child(wall)
	collider.disabled=true
	var ui:=CanvasLayer.new();add_child(ui)
	var heading:=Label.new();heading.text="BODY FLICKER | real movement + collision | 8 directions";heading.position=Vector2(24,14);heading.add_theme_font_size_override("font_size",26);ui.add_child(heading)
	label=Label.new();label.position=Vector2(24,63);ui.add_child(label)
	var actions:= ["S","SE","E","NE","N","NW","W","SW","All 8","Player","Bandit","Wall","Before","After","Normal","Half"]
	for i in actions.size():
		var text: String=actions[i];var b:=Button.new();b.text=text;b.position=Vector2(20+(i%8)*157,600+int(i/8.0)*50);b.size=Vector2(149,44);b.pressed.connect(_click.bind(text));ui.add_child(b);buttons[text]={"x":b.position.x+74,"y":b.position.y+22}
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object");JavaScriptBridge.get_interface("window").__BODY_FLICKER__=state
	queue_redraw()
func _exit_tree() -> void:
	Engine.time_scale=1.0
	EvadeStreakFx.legacy_preview=false
	_release()
func _release() -> void:
	for action in ["move_left","move_right","move_up","move_down","dodge"]:Input.action_release(action)
func _click(text: String) -> void:
	if text in NAMES:auto=false;_trigger(NAMES.find(text))
	match text:
		"All 8":auto=true;index=0;next_at=clock
		"Player":use_bandit=false
		"Bandit":use_bandit=true
		"Wall":
			blocked=not blocked
			(wall.get_child(0) as CollisionShape2D).set_deferred("disabled",not blocked)
			queue_redraw()
		"Before":legacy=true
		"After":legacy=false
		"Normal":speed=1.0;Engine.time_scale=speed
		"Half":speed=0.5;Engine.time_scale=speed
func _trigger(direction: int) -> void:
	index=direction
	_release();path.clear();last_samples.clear();result.clear()
	for subject in [player,bandit]:
		for child in subject.get_children():
			if child is EvadeStreakFx:child.finish(true);child.queue_free()
	EvadeStreakFx.legacy_preview=legacy
	player.state=PlayerController.State.IDLE;player.velocity=Vector2.ZERO;player._dodge_buffer=0.0
	player._action_timer=0.0;player._hitstop_timer=0.0
	player.position=Vector2(640,430) if not use_bandit else Vector2(100,650)
	player.visible=not use_bandit;player.set_physics_process(not use_bandit)
	bandit.visible=use_bandit;bandit.position=Vector2(640,430) if use_bandit else Vector2(100,650)
	bandit.set_physics_process(false)
	if use_bandit:
		await get_tree().physics_frame
		await get_tree().process_frame
		bandit._evade_side=1.0;bandit._evade_cooldown=0.0;bandit.atk_phase=Bandit.AtkPhase.NONE
		bandit._begin_evade(DIRS[direction].rotated(PI/2.0+atan(0.35))*200.0)
		bandit.set_physics_process(true)
	else:
		var dir: Vector2=DIRS[direction]
		if dir.x!=0:Input.action_press("move_right" if dir.x>0 else "move_left")
		if dir.y!=0:Input.action_press("move_down" if dir.y>0 else "move_up")
		Input.action_press("dodge");release_ticks=2
func _physics_process(_delta: float) -> void:
	if auto and clock>=next_at:
		_trigger(index);index=(index+1)%8;next_at=clock+0.9
	if release_ticks>0:
		release_ticks-=1
		if release_ticks==0:_release()
	if use_bandit and bandit.state!=Bandit.State.EVADE:bandit.set_physics_process(false)
func _process(delta: float) -> void:
	clock+=delta
	var subject: CharacterBody2D=bandit if use_bandit else player
	var fx: EvadeStreakFx
	for child in subject.get_children():
		if child is EvadeStreakFx and not child.is_queued_for_deletion():fx=child
	if fx!=null:
		last_samples=fx.sample_positions.duplicate()
		result=fx.debug_state()
		path.append(subject.global_position)
		if path.size()>60:path.pop_front()
	label.text="%s | %s | %.1fx | wall %s\nphase: %s | %.3f s | stationary afterimages: %d | samples: %d" % ["BEFORE" if legacy else "AFTER","BANDIT" if use_bandit else "PLAYER",speed,blocked,result.get("phase","ready"),result.get("age",0.0),result.get("ghosts",0),last_samples.size()]
	if state!=null:
		state.ready=true;state.speed=speed;state.clock=clock;state.legacy=legacy;state.bandit=use_bandit;state.wall=blocked;state.auto=auto
		state.buttons_json=JSON.stringify(buttons);state.result_json=JSON.stringify(result);state.samples_json=JSON.stringify(last_samples)
		state.x=subject.global_position.x;state.y=subject.global_position.y
		state.player_count=player.flicker_count;state.bandit_count=bandit.evade_count;state.player_state=player.get_state_name()
	queue_redraw()
func _floor(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(0,0,1280,720),Color("111c22"))
	for x in range(-800,1600,72):
		canvas.draw_line(Vector2(x,120),Vector2(x+1100,670),Color("27383d"))
		canvas.draw_line(Vector2(x,670),Vector2(x+1100,120),Color("27383d"))
func _draw() -> void:
	if blocked:
		draw_rect(Rect2(712,285,28,230),Color("62716b"))
		draw_rect(Rect2(712,285,28,230),Color("a6b29d"),false,2)
