extends RefCounted

func run(ck: Callable, root: Node) -> void:
	for fps in [30,60]:
		var transition := LocomotionTransition.new()
		transition.update(0.0, true, Vector2.RIGHT, Vector2.RIGHT, false)
		ck.call("movement %d: start on first movement tick" % fps, transition.kind == "start")
		for tick in fps / 5:
			transition.update(1.0/fps, true, Vector2.RIGHT, Vector2.RIGHT, false)
		ck.call("movement %d: launch bounded, no looping" % fps, transition.kind == "")
		transition.update(0.0, true, Vector2.UP, Vector2.UP, false)
		ck.call("movement %d: 90 degree turn pivots" % fps, transition.kind == "pivot")
		transition.update(0.01, true, Vector2.DOWN, Vector2.DOWN, false)
		ck.call("movement %d: steering cannot restart pivot" % fps, transition.elapsed > 0.0)
		transition.update(0.3, true, Vector2.DOWN, Vector2.DOWN, false)
		transition.update(0.0, true, Vector2.UP, Vector2.UP, false)
		ck.call("movement %d: reversal pivots after cooldown" % fps, transition.kind == "pivot")
		transition.update(0.0, false, Vector2.ZERO, Vector2.UP, false)
		ck.call("movement %d: stop interrupts pivot" % fps, transition.kind == "stop")
		transition.update(0.0, true, Vector2.RIGHT, Vector2.RIGHT, true)
		ck.call("movement %d: new input cancels brake immediately" % fps, transition.kind == "start" and transition.gait == "sprint")
		transition.interrupt()
		ck.call("movement %d: action cancels every transition" % fps, transition.kind == "" and not transition.was_moving)
		transition.update(0.0, true, Vector2.RIGHT, Vector2.RIGHT, false)
		transition.update(0.2, true, Vector2(1,0.1), Vector2.RIGHT, false)
		ck.call("movement %d: minor steering does not pivot" % fps, transition.kind == "")
		transition.interrupt()
		transition.update(0.0,true,Vector2.RIGHT,Vector2.RIGHT,false)
		transition.update(0.3,true,Vector2.RIGHT,Vector2.RIGHT,false)
		transition.update(1.0/fps,true,Vector2(1,-1),Vector2(1,-1),false)
		transition.update(1.0/fps,true,Vector2.UP,Vector2.UP,false)
		ck.call("movement %d: diagonal intermediary preserves sharp keyboard corner" % fps, transition.kind == "pivot")
	var actor := SpriteActor.new()
	root.add_child(actor)
	for path in ["res://assets/characters/player/player_128.manifest.json", BanditVisual.ART_PATH]:
		var art := SpriteSet.parse(FileAccess.get_file_as_string(path), path)
		ck.call("movement art parses " + art.id, art.is_valid())
		for direction in SpriteSet.DIRS8:
			for sprint in [false,true]:
				for kind in ["start","stop","pivot"]:
					var transition := LocomotionTransition.new()
					transition.kind = kind
					transition.gait = "sprint" if sprint else "run"
					transition.to_heading = Vector2.RIGHT.rotated(SpriteSet.OCTANT_DIRS.find(direction)*PI/4)
					transition.from_heading = transition.to_heading.rotated(-PI/2)
					ck.call("movement %s %s %s %s" % [art.id,direction,kind,transition.gait], transition.show(actor,art) and not actor.fallback and not actor.flip and actor.sprite.position == -art.foot_anchor)
	var absent := LocomotionTransition.new()
	absent.kind = "start"
	ck.call("movement missing art returns to caller fallback", not absent.show(actor, SpriteSet.new()))
	actor.queue_free()
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(600,600)
	for fps in [30,60]:
		player.visual.locomotion.interrupt()
		player.velocity = Vector2.ZERO
		player.state = PlayerController.State.IDLE
		var start := player.position
		Input.action_press("move_right")
		player._physics_process(1.0/fps)
		ck.call("movement real player %d: movement starts immediately during launch" % fps, player.position.x > start.x and player.velocity.x > 0.0 and player.visual.last_anim == "move_start")
		var before := player.velocity
		player.visual.set_locomotion(0.02,Vector2.RIGHT,false,true,Vector2.RIGHT)
		ck.call("movement real player %d: visual cannot mutate velocity" % fps, player.velocity == before)
		Input.action_release("move_right")
		player._physics_process(1.0/fps)
		ck.call("movement real player %d: release brakes without recovery lock" % fps, player.visual.last_anim == "move_stop")
		for action in ["dodge","jump","charge","hit_react","death","light1"]:
			player.visual.set_locomotion(0.0,Vector2.RIGHT,false,true,Vector2.RIGHT)
			var shown := player.visual.play_action(action,Vector2.RIGHT)
			ck.call("movement real player %d: %s immediately wins priority" % [fps,action],shown and player.visual.last_anim == action and player.visual.locomotion.kind == "")
	player.visual.set_locomotion(0.0,Vector2.RIGHT,false,true,Vector2.RIGHT)
	player.visual.play_action("missing_optional_pose",Vector2.RIGHT)
	ck.call("movement absent cosmetic pose cannot restart launch",player.visual.locomotion.kind == "start")
	var enemy := load("res://scenes/enemy/bandit.tscn").instantiate() as Bandit
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.visual.set_process(false)
	enemy.state = Bandit.State.PATROL
	enemy.velocity = Vector2.RIGHT*enemy.move_speed
	enemy.facing8 = Vector2.RIGHT
	enemy.visual._process(0.0)
	enemy.visual._process(0.25)
	enemy._face_for_travel(Vector2.UP)
	enemy.velocity = Vector2.ZERO
	enemy.visual._process(0.0)
	ck.call("movement real bandit: existing AI turn beat shows planted pivot",enemy.visual.actor.anim_id == "move_pivot" and enemy._turn_pause > 0.0)
	ck.call("movement real bandit: visual preserves AI pause and velocity",is_equal_approx(enemy._turn_pause,0.14) and enemy.velocity == Vector2.ZERO)
	enemy.queue_free()
	player.visual.set_sprite_set(null)
	player.visual.set_locomotion(0.02,Vector2.UP,true,true,Vector2.UP)
	ck.call("movement absent sprite set keeps placeholder movement/facing",player.visual.placeholder._moving and player.visual.placeholder._sprinting and player.visual.placeholder._dir == Vector2.UP)
	player.queue_free()
	await root.get_tree().process_frame
