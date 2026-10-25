extends RefCounted
## Hit reactions, knockback and death for the player and the Bandit (Codex damage animation pack).

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	PlayerController.death_sequence_enabled = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 6:
		await tree.physics_frame
	var player := main.get_node("TrainingArena/Player") as PlayerController
	var bandit := tree.get_first_node_in_group("enemy") as Bandit
	player.set_physics_process(true)

	# --- player: light hit
	player.health = player.max_health
	var start := player.global_position
	ck.call("damage: player light hit lands", player.take_hit(5.0, Vector2.LEFT, 120.0))
	ck.call("damage: light hit plays hit_react", player.hurt_kind == "hit_react", player.hurt_kind)
	for i in 8:
		await tree.physics_frame
	ck.call("damage: hurt body is thrown away from the hit", player.global_position.x < start.x - 4.0, str(player.global_position - start))
	ck.call("damage: hit_react clip shown", player.visual.last_anim == "hit_react", player.visual.last_anim)
	ck.call("damage: weapon layer hidden during hit_react", not player.visual.weapon_visible())
	for i in 40:
		await tree.physics_frame
	ck.call("damage: hurt state ends and control returns", player.hurt_kind == "" and not player.dying)

	# --- player: strong melee shove -> knockback
	player._hit_invuln = 0.0
	player.take_hit(5.0, Vector2.LEFT, 180.0)
	ck.call("damage: strong shove plays knockback", player.hurt_kind == "knockback", player.hurt_kind)
	for i in 6:
		await tree.physics_frame
	ck.call("damage: knockback clip shown", player.visual.last_anim == "knockback", player.visual.last_anim)
	for i in 50:
		await tree.physics_frame

	# --- player: death sequence
	player._hit_invuln = 0.0
	player.health = 1.0
	var downs := player.times_downed
	var respawns := player.respawn_count
	player.take_hit(5.0, Vector2.LEFT, 180.0)
	ck.call("damage: fatal hit counts a down immediately", player.times_downed == downs + 1)
	ck.call("damage: fatal hit starts dying instead of teleporting", player.dying and player.respawn_count == respawns)
	for i in 20:
		await tree.physics_frame
	ck.call("damage: death clip shown", player.visual.last_anim == "death", player.visual.last_anim)
	ck.call("damage: cannot be hit again while dying", not player.take_hit(5.0, Vector2.LEFT, 180.0))
	for i in 120:
		await tree.physics_frame
	ck.call("damage: respawns after the death sequence", not player.dying and player.respawn_count == respawns + 1 and player.health > 0.0)

	# --- bandit
	bandit.hp = bandit.max_hp
	bandit.take_damage(10.0, Vector2.RIGHT, 140.0, 0.0)
	ck.call("damage: bandit light hit plays hit_react", bandit.react_kind == "hit_react" and bandit.state == Bandit.State.HIT_REACT, bandit.react_kind)
	for i in 4:
		await tree.physics_frame
	bandit.visual._process(0.0)
	ck.call("damage: bandit shows hit_react art", bandit.visual.actor.anim_id == "hit_react", str(bandit.visual.actor.anim_id))
	ck.call("damage: bandit weapon hidden during hit_react", not bandit.visual.weapon_visible())
	for i in 40:
		await tree.physics_frame
	bandit.take_damage(20.0, Vector2.RIGHT, 260.0, 0.0)
	ck.call("damage: heavy hit plays knockback", bandit.react_kind == "knockback", bandit.react_kind)
	bandit.visual._process(0.0)
	ck.call("damage: bandit shows knockback art", bandit.visual.actor.anim_id == "knockback", str(bandit.visual.actor.anim_id))
	for i in 60:
		await tree.physics_frame
	bandit.take_damage(999.0, Vector2.RIGHT, 260.0, 0.0)
	ck.call("damage: bandit dies", bandit.state == Bandit.State.DEAD)
	for i in 60:
		await tree.physics_frame
	bandit.visual._process(0.0)
	ck.call("damage: corpse stays visible with the death clip", bandit.visual.actor.visible and bandit.visual.actor.anim_id == "death", str(bandit.visual.actor.anim_id))
	ck.call("damage: corpse holds the prone last frame", bandit.visual.actor.sprite.frame == bandit.visual.actor.sprite.sprite_frames.get_frame_count(bandit.visual.actor.sprite.animation) - 1)

	PlayerController.death_sequence_enabled = false
	main.queue_free()
	await tree.process_frame
