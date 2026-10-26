extends RefCounted
class Ground extends Node2D:
	func get_bounds() -> Rect2:return Rect2(-2000,-2000,4000,4000)
var DIRS := [Vector2.DOWN,Vector2(1,1).normalized(),Vector2.RIGHT,Vector2(1,-1).normalized(),Vector2.UP,Vector2(-1,-1).normalized(),Vector2.LEFT,Vector2(-1,1).normalized()]
func run(ck: Callable, root: Node) -> void:
	# One physics tick per awaited frame: on a slow machine the engine catch-up ticks finish a dodge before the
	# per-frame sampling below ever sees it.
	var steps_was:=Engine.max_physics_steps_per_frame;Engine.max_physics_steps_per_frame=1
	var ground:=Ground.new();root.add_child(ground)
	var p: PlayerController=(load("res://scenes/player/player.tscn") as PackedScene).instantiate();ground.add_child(p);p.camera.enabled=false
	for action in ["move_left","move_right","move_up","move_down","dodge","attack_light"]:Input.action_release(action)
	var timing:=[p.flicker_duration,p.flicker_burst_time,p.dash_attack_late_window,p.dash_attack_post_grace]
	for duration in [0.2,0.3,0.5]:
		p.flicker_duration=duration;p.flicker_burst_time=duration*2.0/3.0
		for dir: Vector2 in DIRS:
			p.position=Vector2.ZERO;p.velocity=Vector2.ZERO;p.state=PlayerController.State.IDLE
			p._begin_dodge(dir)
			var fx:=p.get_node("EvadeStreakFx") as EvadeStreakFx
			ck.call("premium flicker: octant %s %.2fs has literal body and three ghosts" % [SpriteSet.dir_name(dir),duration],fx.actor.dir==SpriteSet.dir_name(dir) and not fx.actor.fallback and fx.ghosts.size()==3 and fx.actor.anim_id=="dodge")
			ck.call("premium flicker: duplicate presentation returns same node",EvadeStreakFx.spawn(p,dir)==fx)
			fx.set_process(false)
			var stable:=true
			var last_sample:=Vector2.INF
			var last_transform:=Transform2D.IDENTITY
			for step in range(1,int(ceil(duration*60))+2):
				await root.get_tree().physics_frame
				await root.get_tree().process_frame
				fx._process(1.0/60.0)
				if not fx.sample_positions.is_empty():
					var sample: Vector2=fx.sample_positions.back()
					if last_sample==sample:
						# Newest ghost remains at its sampled sprite transform while the body moves onward.
						stable=stable and fx.ghosts[(fx._next_ghost+2)%3].global_transform==last_transform
					last_sample=sample;last_transform=fx.ghosts[(fx._next_ghost+2)%3].global_transform
			ck.call("premium flicker: stationary samples follow actual octant",stable and fx.sample_positions.size()>=2 and fx.sample_positions.all(func(v: Vector2)->bool:return absf(v.cross(dir))<0.02 and v.dot(dir)>=0.0 and v.length()<=p.flicker_distance+1.0),"stable=%s samples=%s body=%s" % [stable,fx.sample_positions,p.position])
			ck.call("premium flicker: body scale/anchor and gameplay timings preserved",fx.actor.scale==Vector2.ONE and fx.actor.sprite.position==Vector2(-64,-116) and p.dash_attack_late_window==timing[2] and p.dash_attack_post_grace==timing[3])
			fx.queue_free();await root.get_tree().process_frame
	p.flicker_duration=timing[0];p.flicker_burst_time=timing[1]
	# Actual static body, not a fabricated clamp, stops both body and emission.
	var wall:=StaticBody2D.new();wall.position=Vector2(80,-20);var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(16,300);shape.shape=box;wall.add_child(shape);ground.add_child(wall)
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	p.position=Vector2.ZERO;p.state=PlayerController.State.IDLE;p._begin_dodge(Vector2.RIGHT)
	var blocked:=p.get_node("EvadeStreakFx") as EvadeStreakFx;blocked.set_process(false)
	for step in 20:
		await root.get_tree().physics_frame
		await root.get_tree().process_frame
		blocked._process(1.0/60.0)
	ck.call("premium flicker: collision stops body before wall",p.position.x<=47.1 and p.position.x>1.0,str(p.position))
	ck.call("premium flicker: no afterimage center through wall",blocked.sample_positions.all(func(v: Vector2)->bool:return v.x<=47.1) and blocked.arrived)
	wall.queue_free();blocked.queue_free()
	await root.get_tree().physics_frame
	await root.get_tree().process_frame
	var tree_obstacle:=StaticBody2D.new();tree_obstacle.position=Vector2(80,-13.5)
	var tree_shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=35;tree_shape.shape=circle;tree_obstacle.add_child(tree_shape);ground.add_child(tree_obstacle)
	await root.get_tree().physics_frame
	p.position=Vector2.ZERO;p.state=PlayerController.State.IDLE;p._begin_dodge(Vector2.RIGHT)
	var round_fx:=p.get_node("EvadeStreakFx") as EvadeStreakFx;round_fx.set_process(false)
	for step in 20:
		await root.get_tree().physics_frame
		await root.get_tree().process_frame
		round_fx._process(1.0/60.0)
	ck.call("premium flicker: rounded tree footprint stops body and samples",p.position.x<=20.1 and p.position.x>1.0 and round_fx.sample_positions.all(func(v: Vector2)->bool:return v.x<=20.1))
	round_fx.queue_free();await root.get_tree().process_frame
	# Cancellation never restores an obsolete dodge pose over a combat action.
	await root.get_tree().process_frame
	p.position=Vector2.ZERO;p.state=PlayerController.State.IDLE;p._begin_dodge(Vector2.LEFT)
	var cancel:=p.get_node("EvadeStreakFx") as EvadeStreakFx;cancel.set_process(false)
	p._begin_attack("dash_attack",Vector2.LEFT);cancel._process(1.0/60.0)
	ck.call("premium flicker: dash attack interrupts visual only",cancel.cancelled and not cancel.active and p.state==PlayerController.State.DASH_ATTACK and p.visual.actor.anim_id=="dash_attack" and p.visual.actor.visible)
	p.position=Vector2(-1000,0)
	var b: Bandit=(load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate();b.position=Vector2(-500,500);ground.add_child(b);b.set_physics_process(false)
	b.state=Bandit.State.EVADE;b._evade_timer=b.evade_duration;b.evade_count=1;b.velocity=Vector2.RIGHT*b.evade_speed
	var first:=EvadeStreakFx.spawn(b,Vector2.RIGHT)
	ck.call("premium flicker: bandit snapshots own sprite identity",first.actor.set_ref.id=="bandit_128" and first.actor.modulate.a==1.0)
	b.state=Bandit.State.RETREAT;b.flicker_hopping=true;b.flicker_count=1;b._retreat_timer=float(b.profile.flicker_hop_time)
	var hop:=EvadeStreakFx.spawn(b,Vector2.LEFT)
	ck.call("premium flicker: equal evade/hop counters cannot reuse stale action",hop!=first and first.cancelled and hop.heading==Vector2.LEFT)
	b.flicker_count=2
	var second:=EvadeStreakFx.spawn(b,Vector2.UP)
	ck.call("premium flicker: second retreat hop restarts presentation once",second!=hop and hop.cancelled and EvadeStreakFx.spawn(b,Vector2.UP)==second)
	second._process(1.0/60.0)
	ck.call("premium flicker: retreat body remains opaque",second.actor.visible and second.actor.modulate.a==1.0)
	b.position+=Vector2(600,0);second._process(1.0/60.0)
	ck.call("premium flicker: teleport-sized discontinuity cancels without bridging",second.cancelled and second.sample_positions.is_empty() and not second._smear.visible)
	ground.queue_free();await root.get_tree().process_frame
	EvadeStreakFx.legacy_preview=true
	var baseline: Node2D=(load("res://scenes/art/body_flicker_review.tscn") as PackedScene).instantiate();root.add_child(baseline)
	baseline.player._begin_dodge(Vector2.RIGHT)
	var old:=baseline.player.get_node("EvadeStreakFx") as EvadeStreakFx
	old.finish(true)
	ck.call("premium flicker: interrupting baseline comparison needs no new-effect children",old.cancelled and old.is_queued_for_deletion())
	baseline.queue_free();await root.get_tree().process_frame
	EvadeStreakFx.legacy_preview=false
	var review: Node2D=(load("res://scenes/art/body_flicker_review.tscn") as PackedScene).instantiate();root.add_child(review)
	review._click("All 8")
	await root.get_tree().create_timer(2.05).timeout
	ck.call("premium flicker: review autoplay drives repeated actual dodge input",review.player.flicker_count>=3 and review.auto)
	review.queue_free();await root.get_tree().process_frame
	Engine.max_physics_steps_per_frame=steps_was
