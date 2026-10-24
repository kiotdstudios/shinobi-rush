extends RefCounted
## Level 1 Bandit robber behaviour (order 2026-10-21-bandit-level1-robber-arena).
## Runs against the real main scene (real walls, real navigation, real physics rays). The player is
## held still (no input) and repositioned by the test; everything the Bandit decides is its own.

var ck: Callable
var tree: SceneTree
var arena: TrainingArena
var player: PlayerController
var bandit: Bandit


func run(check: Callable, root: Node) -> void:
	ck = check
	tree = root.get_tree()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 6:
		await tree.physics_frame
	arena = main.get_node_or_null("TrainingArena") as TrainingArena
	player = main.get_node_or_null("TrainingArena/Player") as PlayerController
	bandit = tree.get_first_node_in_group("enemy") as Bandit
	ck.call("robber: arena, player and Bandit exist", arena != null and player != null and bandit != null)
	if arena == null or player == null or bandit == null:
		main.queue_free()
		return

	await _test_arena_layout()
	await _test_navigation_data()
	await _test_patrol()
	await _test_sight_and_walls()
	await _test_acquisition_delay()
	await _test_wall_navigation()
	await _test_threaten_and_attack()
	await _test_attack_evadable_and_walls()
	await _test_double_flicker()
	await _test_search_and_return()
	await _test_leash_and_profile()
	await _test_leash_survives_a_stale_prior_home()
	ck.call("robber: no stuck states anywhere in the suite", bandit.stuck_events == 0, str(bandit.stuck_events))
	main.queue_free()
	await tree.process_frame


# ------------------------------------------------------------------------------------ helpers
func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _put(bandit_pos: Vector2, player_pos: Vector2, state: Bandit.State = Bandit.State.PATROL) -> void:
	bandit.global_position = bandit_pos
	bandit.velocity = Vector2.ZERO
	bandit._player = player
	bandit.patrol_points = PackedVector2Array()
	bandit.atk_phase = Bandit.AtkPhase.NONE
	bandit.retreat_phase = Bandit.RetreatPhase.NONE
	bandit.flicker_hopping = false
	bandit._atk_cooldown = 0.0
	bandit._threaten_timer = 0.0
	bandit._evade_cooldown = 0.0
	bandit._turn_pause = 0.0
	bandit._wait_timer = 0.0
	bandit._lose_timer = 0.0
	bandit._has_lost_player = false
	bandit._first_contact_pending = true
	bandit.taunt_timer = 0.0
	bandit.set_intelligence_level(1)
	bandit.seed_rng(7)
	bandit.set_home(bandit_pos)
	bandit._chase_origin = bandit_pos  ## leash measures from here now, not `home` (see bandit.gd doc comment)
	bandit.state = state
	bandit._state_time = 0.0
	player.global_position = player_pos
	player.velocity = Vector2.ZERO


func _inside_any_block(p: Vector2, margin: float = 0.0) -> bool:
	for b: Array in WorldScale.live_blocks():
		var pos: Vector2 = b[0]
		var fp: Vector2 = b[1]
		if Rect2(pos.x - fp.x * 0.5, pos.y - fp.y, fp.x, fp.y).grow(margin).has_point(p):
			return true
	return false


# ------------------------------------------------------------------------------------ tests
func _test_arena_layout() -> void:
	var spawn := arena.spawn.global_position
	ck.call("robber layout: player spawn unchanged at (0,135)", spawn.is_equal_approx(Vector2(0, 135)), str(spawn))
	var dist := WorldScale.BANDIT_HOME.distance_to(spawn)
	ck.call("robber layout: Bandit lives far from the player spawn (> 1000 px)", dist > 1000.0, "%.0f px" % dist)
	ck.call("robber layout: the two long walls are still there (placeholder rocks removed)", WorldScale.live_blocks().size() >= 4, str(WorldScale.live_blocks().size()))
	for i in range(5, 7):
		ck.call("robber layout: blocker %d exists as a real collider" % i, arena.get_node_or_null(NodePath("Block%d" % i)) is StaticBody2D)
	ck.call("robber layout: the spawn is not inside or hugging a blocker", not _inside_any_block(spawn, 80.0))
	ck.call("robber layout: Bandit home is not inside a blocker", not _inside_any_block(WorldScale.BANDIT_HOME, 60.0))
	var patrol_ok := true
	for p in WorldScale.BANDIT_PATROL:
		if _inside_any_block(p, 50.0) or not arena.bounds.grow(-100.0).has_point(p):
			patrol_ok = false
	ck.call("robber layout: every patrol point is clear of blockers and inside the arena", patrol_ok)
	ck.call("robber layout: Bandit starts in PATROL on the far side", bandit.state == Bandit.State.PATROL and bandit.global_position.distance_to(spawn) > 1000.0, bandit.get_state_name())


func _test_navigation_data() -> void:
	var nav := arena.nav
	ck.call("robber nav: arena built a navigation grid", nav != null)
	if nav == null:
		return
	var spawn := arena.spawn.global_position
	var to_home := nav.find_path(spawn, WorldScale.BANDIT_HOME)
	ck.call("robber nav: a path exists spawn -> Bandit home", not to_home.is_empty())
	var back := nav.find_path(WorldScale.BANDIT_HOME, spawn)
	ck.call("robber nav: a path exists Bandit home -> spawn (nobody is trapped)", not back.is_empty())
	# Three distinct routes past the wall line at x=900: north of it, through the choke, south of it.
	ck.call("robber nav: choke route (y=60) is a straight walkable line through the gap", nav.line_clear(Vector2(800, 60), Vector2(1020, 60)))
	ck.call("robber nav: the north wall blocks a straight crossing (y=-300)", not nav.line_clear(Vector2(780, -300), Vector2(1100, -300)))
	ck.call("robber nav: the south wall blocks a straight crossing (y=450)", not nav.line_clear(Vector2(700, 450), Vector2(1100, 450)))
	ck.call("robber nav: north route above the wall is walkable (y=-800)", nav.line_clear(Vector2(700, -800), Vector2(1100, -800)))
	ck.call("robber nav: south route below the wall is walkable (y=950)", nav.line_clear(Vector2(700, 950), Vector2(1100, 950)))
	var detour := nav.find_path(Vector2(780, -300), Vector2(1100, -300))
	var len := 0.0
	var prev := Vector2(780, -300)
	for p in detour:
		len += prev.distance_to(p)
		prev = p
	ck.call("robber nav: a path across the north wall exists and detours (longer than straight)", not detour.is_empty() and len > 460.0, "%.0f px" % len)
	var choke_w := 0.0
	var gap_top: float = (WorldScale.BLOCKS[5][0] as Vector2).y
	var gap_bot: float = (WorldScale.BLOCKS[6][0] as Vector2).y - (WorldScale.BLOCKS[6][1] as Vector2).y
	choke_w = gap_bot - gap_top
	ck.call("robber nav: choke point is narrow (< 400 px) but wider than a body (> 100 px)", choke_w < 400.0 and choke_w > 100.0, "%.0f px" % choke_w)


func _test_patrol() -> void:
	_put(WorldScale.BANDIT_HOME, arena.spawn.global_position)
	bandit.patrol_points = PackedVector2Array(WorldScale.BANDIT_PATROL)
	bandit._patrol_idx = 0
	var start := bandit.global_position
	var moved := 0.0
	var max_speed := 0.0
	var states := {}
	var anims := {}
	var visited := {}
	var facings := {}
	var visual := bandit.visual as BanditVisual
	for i in 600:
		await tree.physics_frame
		moved = maxf(moved, bandit.global_position.distance_to(start))
		max_speed = maxf(max_speed, bandit.velocity.length())
		states[bandit.get_state_name()] = true
		anims[visual.actor.anim_id] = true
		facings[bandit.facing8] = true
		for k in WorldScale.BANDIT_PATROL.size():
			if bandit.global_position.distance_to(WorldScale.BANDIT_PATROL[k]) < 40.0:
				visited[k] = true
	ck.call("robber patrol: walks its loop (moved far from home)", moved > 150.0, "%.0f px" % moved)
	ck.call("robber patrol: reaches more than one patrol point in 10 s", visited.size() >= 2, str(visited.keys()))
	ck.call("robber patrol: stays PATROL while the player is far away", states.keys() == ["PATROL"], str(states.keys()))
	# Owner 2026-10-22 ("bandits are in the woods running around looking for players, naruto running")
	# supersedes the original "patrol speed is a walk" criterion from the Level 1 robber arena order --
	# an authored patrol loop is now walked at chase_speed (sprint), not profile.patrol_speed (walk).
	ck.call("robber patrol: naruto-running between waypoints is a sprint, not a walk (owner 2026-10-22)", max_speed <= bandit.chase_speed + 1.0 and max_speed > float(bandit.profile.patrol_speed) * 1.5, "%.0f" % max_speed)
	ck.call("robber patrol: uses both moving and standing animations (no mannequin idle)", anims.has("sprint") and anims.has("idle"), str(anims.keys()))
	ck.call("robber patrol: faces several directions (look-around + travel), never a fixed pose", facings.size() >= 3, str(facings.size()))
	ck.call("robber patrol: big direction changes cost a stop-to-turn beat", bandit.turn_pauses >= 1, str(bandit.turn_pauses))
	ck.call("robber patrol: does not see a player 1300 px away", not bandit.sees_player)


func _test_sight_and_walls() -> void:
	# Open-air sight: bandit facing left, player 300 px ahead, nothing between.
	_put(Vector2(1100, 60), Vector2(800, 60))
	bandit.facing8 = Vector2.LEFT
	ck.call("robber sight: sees a player in its cone with clear line of sight", bandit.can_see(player.global_position, true))
	# Behind it: outside the narrow cone, beyond close-sense.
	_put(Vector2(1500, 300), Vector2(1900, 300))
	bandit.facing8 = Vector2.LEFT
	ck.call("robber sight: does NOT see a player behind it beyond close-sense (narrow awareness)", not bandit.can_see(player.global_position, true))
	_put(Vector2(1500, 300), Vector2(1560, 300))
	bandit.facing8 = Vector2.LEFT
	ck.call("robber sight: still senses a player right behind it at 60 px", bandit.can_see(player.global_position, true))
	# The north wall (x 855..945, y -600..-80) sits between these two.
	_put(Vector2(1100, -300), Vector2(780, -300))
	bandit.facing8 = Vector2.LEFT
	ck.call("robber sight: a wall between them blocks detection (in range, in cone)", not bandit.can_see(player.global_position, true))
	await _frames(90)
	ck.call("robber sight: stays PATROL, never NOTICEs through the wall", bandit.state == Bandit.State.PATROL and not bandit.sees_player, bandit.get_state_name())
	# Through the gap the same distance is visible.
	_put(Vector2(1100, 60), Vector2(800, 60))
	bandit.facing8 = Vector2.LEFT
	await _frames(3)
	ck.call("robber sight: the same distance through the choke gap IS visible", bandit.sees_player)


func _test_acquisition_delay() -> void:
	_put(Vector2(1500, 300), Vector2(1200, 300))
	bandit.facing8 = Vector2.LEFT
	await _frames(12)
	ck.call("robber acquire: first sees -> NOTICE (suspicion beat), not an instant chase", bandit.state == Bandit.State.NOTICE, bandit.get_state_name())
	ck.call("robber acquire: NOTICE stands still", bandit.velocity.length() < 1.0)
	await _frames(int(float(bandit.profile.notice_delay) * 60.0) + 12)
	ck.call("robber acquire: after the notice delay it commits (APPROACH)", bandit.state == Bandit.State.APPROACH or bandit.state == Bandit.State.THREATEN, bandit.get_state_name())
	# Slow re-acquisition after losing the player.
	_put(Vector2(1500, 300), Vector2(1200, 300), Bandit.State.SEARCH)
	bandit.facing8 = Vector2.LEFT
	bandit._has_lost_player = true
	bandit.last_seen = Vector2(1500, 300)
	await _frames(int(float(bandit.profile.notice_delay) * 60.0) + 6)
	ck.call("robber acquire: re-acquisition after losing it is slower (still NOTICE after the base delay)", bandit.state == Bandit.State.NOTICE, bandit.get_state_name())


func _test_wall_navigation() -> void:
	# Chasing a last-seen point on the far side of the north wall: must route AROUND it.
	_put(Vector2(1100, -300), Vector2(-1500, 900), Bandit.State.APPROACH)
	bandit.last_seen = Vector2(780, -300)
	var collisions := 0
	var min_x := 99999.0
	var inside_ticks := 0
	var arrived_at := -1
	for i in 900:
		await tree.physics_frame
		collisions += 1 if bandit.get_slide_collision_count() > 0 else 0
		min_x = minf(min_x, bandit.global_position.x)
		if _inside_any_block(bandit.global_position + Vector2(0, -6.0)):
			inside_ticks += 1
		if arrived_at < 0 and bandit.global_position.distance_to(Vector2(780, -300)) < 60.0:
			arrived_at = i
			break
	ck.call("robber nav: reaches a target behind a wall by walking around it", arrived_at >= 0, "min_x=%.0f" % min_x)
	ck.call("robber nav: never runs into wall geometry on the way (0 slide collisions)", collisions == 0, "%d collisions" % collisions)
	ck.call("robber nav: never inside a blocker", inside_ticks == 0, str(inside_ticks))
	ck.call("robber nav: used planned paths (not a blind straight line)", bandit.path_requests >= 1)
	ck.call("robber nav: no stuck events while navigating", bandit.stuck_events == 0, str(bandit.stuck_events))


func _test_threaten_and_attack() -> void:
	_put(Vector2(1500, 300), Vector2(1380, 300), Bandit.State.APPROACH)
	bandit.facing8 = Vector2.LEFT
	bandit.profile.overcommit_chance = 0.0
	bandit.profile.retreat_chance = 0.0
	player.hits_taken = 0
	bandit.player_hits_landed = 0
	var swings_before := bandit.swings_thrown
	await _frames(4)
	ck.call("robber threaten: reaching combat range -> THREATEN", bandit.state == Bandit.State.THREATEN, bandit.get_state_name())
	ck.call("robber threaten: the robber line appears (non-blocking)", bandit.taunt_timer > 0.0 and Bandit.TAUNT_TEXT == "Hand over your ryo!")
	ck.call("robber threaten: the line does not pause the game or the player", not tree.paused and player.process_mode != Node.PROCESS_MODE_DISABLED)
	await _frames(30)
	ck.call("robber threaten: it holds still and talks before swinging (no attack in the first 0.5 s)", bandit.state == Bandit.State.THREATEN and bandit.swings_thrown == swings_before)
	# Wait for the swing and measure the telegraph.
	var windup_frames := 0
	var progress_seen: Array[float] = []
	for i in 240:
		await tree.physics_frame
		if bandit.state == Bandit.State.ATTACK and bandit.atk_phase == Bandit.AtkPhase.WINDUP1:
			windup_frames += 1
			progress_seen.append(bandit.get_attack_progress())
			ck.call("robber attack: no damage during the telegraph", player.hits_taken == 0)
		if bandit.atk_phase == Bandit.AtkPhase.ACTIVE1:
			break
	ck.call("robber attack: a visible windup precedes the first swing (>= 0.3 s)", windup_frames >= 18, "%d frames" % windup_frames)
	ck.call("robber attack: telegraph progress rises 0 -> ~1", progress_seen.size() > 2 and progress_seen[0] < 0.2 and progress_seen[progress_seen.size() - 1] > 0.8)
	# Run the rest of the combo.
	var phases := {}
	for i in 240:
		await tree.physics_frame
		phases[bandit.atk_phase] = true
		if bandit.state != Bandit.State.ATTACK:
			break
	ck.call("robber attack: two swings (ACTIVE1 + ACTIVE2 both occur)", phases.has(Bandit.AtkPhase.ACTIVE2) and bandit.swings_thrown == swings_before + 1, str(phases.keys()))
	ck.call("robber attack: a stationary player is hit by the combo", player.hits_taken >= 1 and bandit.player_hits_landed >= 1, "hits=%d" % player.hits_taken)
	ck.call("robber attack: after the combo it leaves ATTACK (recovery then re-think)", bandit.state != Bandit.State.ATTACK, bandit.get_state_name())
	ck.call("robber attack: attack cooldown is enforced", bandit._atk_cooldown > 1.0, "%.2f" % bandit._atk_cooldown)


func _test_attack_evadable_and_walls() -> void:
	# (a) Sidestep after the aim freezes: the swing whiffs.
	_put(Vector2(1500, 300), Vector2(1380, 300), Bandit.State.THREATEN)
	bandit.facing8 = Vector2.LEFT
	bandit.profile.overcommit_chance = 0.0
	bandit.profile.retreat_chance = 0.0
	player.hits_taken = 0
	bandit.player_hits_landed = 0
	bandit._begin_attack()
	var guard := 0
	while bandit._atk_timer > float(bandit.profile.attack_windup) * 0.4 and guard < 120:
		await tree.physics_frame
		guard += 1
	player.global_position = Vector2(1380, 520)  # the player slips out of the frozen arc
	await _frames(60)
	ck.call("robber fair: moving out of the frozen swing arc evades the hit", player.hits_taken == 0, "hits=%d" % player.hits_taken)
	# (b) A dodging / airborne player takes no hit.
	var prev_state := player.state
	player.state = PlayerController.State.DODGE
	ck.call("robber fair: a dodging player cannot be hit", not player.take_hit(8.0, Vector2.LEFT))
	player.state = PlayerController.State.JUMP
	ck.call("robber fair: an airborne player cannot be hit", not player.take_hit(8.0, Vector2.LEFT))
	player.state = prev_state
	# (c) No hits through walls: bandit and player 140 px apart with the north wall between them.
	_put(Vector2(975, -300), Vector2(830, -300), Bandit.State.THREATEN)
	bandit.facing8 = Vector2.LEFT
	bandit.profile.overcommit_chance = 0.0
	bandit.profile.retreat_chance = 0.0
	player.hits_taken = 0
	bandit.player_hits_landed = 0
	var dist := bandit.global_position.distance_to(player.global_position)
	var walled := not bandit.line_clear_to(player.global_position)
	bandit._begin_attack()
	await _frames(90)
	ck.call("robber fair: setup is inside attack reach (%.0f px) with a wall between" % dist, dist < float(bandit.profile.attack_reach) and walled)
	ck.call("robber fair: no hit lands through a wall", player.hits_taken == 0 and bandit.player_hits_landed == 0, "hits=%d" % player.hits_taken)
	ck.call("robber fair: it did throw the swing (whiffed on the wall)", bandit.swings_thrown >= 1)


func _test_double_flicker() -> void:
	_put(Vector2(1300, 420), Vector2(1190, 420), Bandit.State.THREATEN)
	bandit.facing8 = Vector2.LEFT
	bandit.profile.overcommit_chance = 0.0
	bandit.profile.retreat_chance = 1.0
	bandit.flicker_count = 0
	var start_x := bandit.global_position.x
	var phases: Array[int] = []
	var tele_frames := 0
	var inside := 0
	var hop_frames := 0
	bandit._begin_attack()
	for i in 480:
		await tree.physics_frame
		if bandit.state == Bandit.State.RETREAT:
			if phases.is_empty() or phases[phases.size() - 1] != bandit.retreat_phase:
				phases.append(bandit.retreat_phase)
			if bandit.retreat_phase == Bandit.RetreatPhase.TELEGRAPH:
				tele_frames += 1
			if bandit.flicker_hopping:
				hop_frames += 1
		if _inside_any_block(bandit.global_position + Vector2(0, -6.0)):
			inside += 1
		if bandit.retreat_phase == Bandit.RetreatPhase.NONE and not phases.is_empty() and bandit.state != Bandit.State.RETREAT:
			break
	ck.call("robber retreat: telegraph, hop, pause, hop, recover in order",
		phases == [Bandit.RetreatPhase.TELEGRAPH, Bandit.RetreatPhase.HOP1, Bandit.RetreatPhase.PAUSE, Bandit.RetreatPhase.HOP2, Bandit.RetreatPhase.RECOVER], str(phases))
	ck.call("robber retreat: exactly two flicker hops", bandit.flicker_count == 2, str(bandit.flicker_count))
	ck.call("robber retreat: the retreat is telegraphed (>= 0.3 s tell)", tele_frames >= 18, "%d frames" % tele_frames)
	ck.call("robber retreat: each hop is brief (< 0.25 s total in hops)", hop_frames > 0 and hop_frames <= 15, "%d frames" % hop_frames)
	var back := bandit.global_position.x - start_x
	ck.call("robber retreat: both hops travel BACKWARD, away from the player (> 250 px)", back > 250.0, "%.0f px" % back)
	ck.call("robber retreat: never ends inside a blocker", inside == 0, str(inside))
	# A hop into a wall is shortened or skipped, never through it.
	_put(Vector2(2025 - 90, 420), Vector2(1790, 420), Bandit.State.THREATEN)
	bandit.profile.retreat_chance = 1.0
	bandit.profile.overcommit_chance = 0.0
	bandit.flicker_count = 0
	bandit._begin_attack()
	await _frames(480)
	ck.call("robber retreat: with a wall behind it the hop stays inside the arena", arena.bounds.has_point(bandit.global_position), str(bandit.global_position))
	# Player damage interrupts the retreat state cleanly.
	_put(Vector2(1300, 420), Vector2(1190, 420), Bandit.State.THREATEN)
	bandit._begin_retreat()
	bandit.take_damage(1.0, Vector2.RIGHT, 0.0, 0.0)
	ck.call("robber retreat: a hit during the telegraph cancels it", bandit.state == Bandit.State.HIT_REACT and bandit.retreat_phase == Bandit.RetreatPhase.NONE)
	bandit.profile.retreat_chance = 0.25
	await _frames(20)


func _test_search_and_return() -> void:
	var patrol := PackedVector2Array(WorldScale.BANDIT_PATROL)
	_put(Vector2(1500, 300), arena.spawn.global_position, Bandit.State.APPROACH)
	bandit.patrol_points = patrol
	bandit.set_home(WorldScale.BANDIT_HOME)
	bandit.last_seen = Vector2(1400, 300)
	var seq: Array[String] = []
	for i in 1200:
		await tree.physics_frame
		var s := bandit.get_state_name()
		if seq.is_empty() or seq[seq.size() - 1] != s:
			seq.append(s)
		if s == "PATROL":
			break
	ck.call("robber search: loses the player -> SEARCH -> RETURN -> PATROL", seq == ["APPROACH", "SEARCH", "RETURN", "PATROL"], str(seq))
	# Owner 2026-10-22 ("I want the logic for all enemies to stay in their new area") supersedes the
	# original "once back on patrol it is near its patrol loop" criterion -- RETURN no longer marches
	# the Bandit back to WorldScale.BANDIT_HOME; it adopts wherever it gave up (near last_seen) as its
	# new home instead, so it should now be FAR from the original authored home and sitting on top of it.
	ck.call("robber search: home updates to the new area instead of the original spawn", bandit.home.distance_to(WorldScale.BANDIT_HOME) > 200.0 and bandit.global_position.distance_to(bandit.home) < 10.0, "home=%s pos=%s orig=%s" % [bandit.home, bandit.global_position, WorldScale.BANDIT_HOME])
	ck.call("robber search: the intent log recorded the transitions", bandit.intent_log.size() >= 3 and "SEARCH" in "".join(bandit.intent_log))
	# Owner follow-up 2026-10-22, same day: "I do not want there to be a home position; bandit's new
	# home is the last seen location and he continues his search." The PATROL that follows RETURN must
	# free-roam near the settle point, NEVER walk back toward the original authored patrol loop (which
	# sits 200+ px away, per the assertion above) -- that is the exact bug this instruction corrected.
	var settle_point := bandit.global_position
	var saw_sprint := false
	var farthest_from_settle := 0.0
	var closest_to_old_loop := INF
	for i in 180:
		await tree.physics_frame
		if bandit.is_sprinting:
			saw_sprint = true
		farthest_from_settle = max(farthest_from_settle, bandit.global_position.distance_to(settle_point))
		closest_to_old_loop = min(closest_to_old_loop, bandit.global_position.distance_to(WorldScale.BANDIT_HOME))
	ck.call("robber search: never walks back toward the original authored patrol loop once settled", closest_to_old_loop > 150.0, "closest to old home over 3s of roaming: %.0f px" % closest_to_old_loop)
	ck.call("robber search: free-roams near the new settle point (bounded by roam_radius), not standing frozen", saw_sprint and farthest_from_settle > 5.0 and farthest_from_settle < bandit.roam_radius * 2.5, "farthest from settle point: %.0f px (roam_radius=%.0f)" % [farthest_from_settle, bandit.roam_radius])
	ck.call("robber search: _ever_disengaged is permanently set after the first RETURN", bandit._ever_disengaged)


func _test_leash_and_profile() -> void:
	# in view beyond the leash radius: the chase must NOT be abandoned
	_put(Vector2(1500, 300), Vector2(1250, 300), Bandit.State.APPROACH)
	bandit.set_home(Vector2(1500, 300) - Vector2(1700, 0))
	await _frames(3)
	ck.call("robber leash: a chase past the leash radius continues while the player is in view", bandit.state != Bandit.State.RETURN and bandit.sees_player, "%s sees=%s" % [bandit.get_state_name(), str(bandit.sees_player)])
	_put(Vector2(1500, 300), Vector2(-1500, 900), Bandit.State.APPROACH)
	bandit.last_seen = Vector2(1400, 300)
	# Owner 2026-10-22 (second follow-up, same day): the leash now measures from where THIS chase
	# started (_chase_origin), never the stale `home` left over from a previous disengage -- setting
	# `home` far away here would no longer do anything; `_chase_origin` is the actual mechanism.
	bandit._chase_origin = Vector2(1500, 300) - Vector2(1700, 0)
	await _frames(3)
	ck.call("robber leash: a chase beyond the leash radius is abandoned (RETURN)", bandit.state == Bandit.State.RETURN, bandit.get_state_name())
	bandit.set_intelligence_level(99)
	ck.call("robber profile: unknown levels clamp to the highest defined", bandit.profile.level == 1 and bandit.intelligence_level == 99)
	bandit.set_intelligence_level(1)
	var p := bandit.profile
	ck.call("robber profile: Level 1 has narrow awareness (cone < 180 deg)", float(p.fov_deg) < 180.0)
	ck.call("robber profile: Level 1 has slow reactions (notice delay >= 0.5 s)", float(p.notice_delay) >= 0.5)
	ck.call("robber profile: Level 1 attacks are readable (windup >= 0.3 s) with real recovery", float(p.attack_windup) >= 0.3 and float(p.attack_recovery) >= 0.3)
	ck.call("robber profile: Level 1 retreats rarely (< 50%) and overcommits sometimes", float(p.retreat_chance) < 0.5 and float(p.overcommit_chance) > 0.0)
	ck.call("robber profile: chase is bounded", float(p.chase_leash) > 0.0 and float(p.chase_leash) < 4000.0)
	ck.call("robber profile: intent is observable (get_intent + state name)", bandit.get_intent() != "" and bandit.get_state_name() != "")

# ------------------------------------------------------------------ owner 2026-10-22 (second follow-up,
# same day): "bandit now moves to another ... home ... instead of that being his now home area" -- a
# fresh chase must give up based on where THIS chase started, not a stale `home` left by a PREVIOUS
# disengage that the Bandit has since roamed away from. Kept physically on the SAME proven-safe spot
# ((1500, 300), the same anchor _test_leash_and_profile already uses) the whole time -- this test is
# about which REFERENCE POINT (`home` vs `_chase_origin`) gates the leash, not about real movement
# across unknown level geometry.
func _test_leash_survives_a_stale_prior_home() -> void:
	var anchor := Vector2(1500, 300)  ## same proven-safe spot _test_leash_and_profile uses
	var old_home := anchor - Vector2(1700, 0)  ## stale: left over from a disengage long before now
	# Player beyond Level 1's sight_range (500, post Aki's "smaller vision" tune) so sees_player stays
	# false throughout -- otherwise RETURN immediately re-triggers NOTICE ("spotted while returning")
	# and the leash transition never gets a chance to be observed.
	_put(anchor, anchor + Vector2(0, 700), Bandit.State.PATROL)
	# NOT equal to `anchor` itself: _tick_approach's "reached last seen" check fires the instant the
	# Bandit arrives within 20px of `last_seen` while not seeing the player -- setting it to the
	# Bandit's own current position would trigger that on frame one, before the leash can be observed.
	bandit.last_seen = anchor + Vector2(0, 300)
	bandit._ever_disengaged = true
	bandit.home = old_home
	bandit._enter(Bandit.State.APPROACH, "test: a brand new engagement begins right here")
	ck.call("robber leash: a fresh engagement sets _chase_origin to where it currently is, not the stale home", bandit._chase_origin.distance_to(anchor) < 1.0, str(bandit._chase_origin))
	await _frames(3)
	ck.call("robber leash: despite `home` being 1700px away (stale, > leash), the chase continues because _chase_origin is right here", bandit.state == Bandit.State.APPROACH, bandit.get_state_name())
	bandit._chase_origin = old_home  ## simulate THIS chase having actually started back at the old spot
	await _frames(3)
	ck.call("robber leash: once _chase_origin itself is far enough away, the SAME distance now correctly gives up (RETURN)", bandit.state == Bandit.State.RETURN, bandit.get_state_name())
	ck.call("robber leash: the new home settles at THIS chase's actual giving-up point, not the old stale home or chase_origin", bandit.home.distance_to(anchor) < 60.0 and bandit.home.distance_to(old_home) > 1000.0, "home=%s anchor=%s old_home=%s" % [bandit.home, anchor, old_home])
