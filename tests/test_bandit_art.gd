extends RefCounted
## Enemy-only art binding, state mapping and player-selection regression coverage.

func run(ck: Callable, tree_root: Node) -> void:
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	tree_root.add_child(bandit)
	bandit.set_physics_process(false)
	var visual := bandit.visual as BanditVisual
	visual.set_process(false)
	var actor := visual.actor
	ck.call("bandit art: real 128px set explicitly bound", actor.set_ref != null and actor.set_ref.id == "bandit_128")
	var library := SpriteLibrary.new()
	library.scan()
	ck.call("bandit art: enemy does not replace player default", library.get_set("bandit_128") == null and library.first_valid().id != "bandit_128")
	ck.call("bandit hud: starts with full chakra and 2 substitution pips", bandit.chakra == bandit.max_chakra and bandit.max_chakra == 100.0 and bandit.substitutions == 2 and bandit.max_substitutions == 2)
	ck.call("bandit hud: the shared bar block is half-scale art with two bars and a pip row", UnitBars.size_for(2).x == 98.0 and UnitBars.size_for(2).y > 22.0)
	var vectors := [Vector2.DOWN, Vector2(1, 1), Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1)]
	for i in 8:
		bandit.facing8 = vectors[i].normalized()
		for action: String in ["idle", "run", "sprint"]:
			visual.approach_animation = "sprint" if action == "sprint" else "run"
			bandit.state = Bandit.State.IDLE if action == "idle" else Bandit.State.APPROACH
			bandit.velocity = Vector2.ZERO if action == "idle" else bandit.facing8 * bandit.move_speed
			visual._process(0.0)
			ck.call("bandit art: %s %s" % [action, SpriteSet.DIRS8[i]], actor.anim_id == action and actor.dir == SpriteSet.DIRS8[i] and actor.visible)
			ck.call("bandit art: stable foot anchor", actor.sprite.position == Vector2(-64, -116) and actor.scale == Vector2.ONE)
	bandit.velocity = Vector2.ZERO
	visual._process(0.0)
	ck.call("bandit art: stopped approach uses idle", actor.anim_id == "idle")
	bandit.state = Bandit.State.HIT_REACT
	bandit._hit_flash_timer = 0.1
	visual._process(0.0)
	ck.call("bandit art: hurt freezes and flashes authored pose", not actor.sprite.is_playing() and actor.modulate == Bandit.HIT_FLASH and actor.visible)
	bandit.state = Bandit.State.APPROACH
	bandit._hit_flash_timer = 0.0
	bandit._hitstop_timer = 0.1
	visual._process(0.0)
	ck.call("bandit art: hitstop pauses sprite", not actor.sprite.is_playing() and actor.modulate == Color.WHITE)
	bandit._hitstop_timer = 0.0
	visual._process(0.0)
	ck.call("bandit art: animation resumes after hitstop", actor.sprite.is_playing())
	bandit.state = Bandit.State.DEAD
	visual._process(0.0)
	ck.call("bandit art: missing death clip uses existing fallback", not actor.visible)
	bandit.queue_free()
	await tree_root.get_tree().process_frame
