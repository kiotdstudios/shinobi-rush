extends RefCounted
## Every character climbs: a real bandit (physics body, rim mask) walks up the Ancient Flame Shrine's stairs onto the
## platform at full height and back down, using ShrineElevation.climb_step like any walker.


func run(ck: Callable, root: Node) -> void:
	var tree := root.get_tree()
	var shrine := DynamicShrine.new()
	shrine.position = Vector2(6000, 6000)
	root.add_child(shrine)
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	root.add_child(bandit)
	bandit.set_physics_process(false)
	bandit.nav = null
	ck.call("bandit climb: bandits collide with stair sides and rims", bandit.collision_mask & ShrineElevation.EDGE_LAYER != 0)
	var mouth := shrine.to_global(ShrineElevation._l(ShrineElevation.MOUTH))
	var top := shrine.to_global(ShrineElevation._l(ShrineElevation.TOP))
	var start := mouth - (top - mouth) * 1.6
	bandit.global_position = start
	await tree.physics_frame
	var platform := shrine.to_global(ShrineElevation._l(ShrineElevation.PLATFORM_CENTER) + Vector2(-60, 25))  # clear of the monument
	var up := await _drive(bandit, platform, tree, 8.0)
	ck.call("bandit climb: walks up the shrine stairs onto the platform", up, "at %s goal %s" % [bandit.global_position, platform])
	ck.call("bandit climb: stands at shrine platform height", is_equal_approx(bandit.elevation, ShrineElevation.HEIGHT), str(bandit.elevation))
	var down := await _drive(bandit, start, tree, 8.0)
	ck.call("bandit climb: comes back down the shrine stairs", down and is_zero_approx(bandit.elevation), "at %s e=%.1f" % [bandit.global_position, bandit.elevation])
	var ground := ShrineElevation.climb_step(start + Vector2(-300, 0), start + Vector2(-300, 100))
	ck.call("bandit climb: plain ground travel is left to the nav", ground.is_empty())
	bandit.free()
	shrine.free()


func _drive(bandit: Bandit, goal: Vector2, tree: SceneTree, seconds: float) -> bool:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var t := 0.0
	while t < seconds:
		await tree.physics_frame
		bandit._turn_pause = 0.0
		if bandit._follow(goal, bandit.move_speed, dt, 10.0, false):
			for i in 30:
				ShrineElevation.update_actor(bandit, dt)
			return true
		bandit.move_and_slide()
		ShrineElevation.update_actor(bandit, dt)
		t += dt
	return false
