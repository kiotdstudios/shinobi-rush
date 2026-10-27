extends RefCounted
## Smoke screens block sight both ways (owner 2026-10-26: "bandits lose you in the smoke and the other way round").
## Bandits cannot see into or through a standing screen, the vision overlay draws the same cut, and the player can
## neither lock on to nor sense anything inside (or, for the lock, behind) one. Runs far from the arena geometry.

class FakeEnemy extends Node2D:
	func is_alive() -> bool:
		return true


var ck: Callable
var tree: SceneTree
const AT := Vector2(9000, 9000)


func run(check: Callable, root: Node) -> void:
	ck = check
	tree = root.get_tree()
	var smoke := SmokeTagBomb.new()
	smoke.art_kind = "smoke_tag_bomb"
	root.add_child(smoke)
	smoke.set_physics_process(false)
	smoke.global_position = AT
	await tree.process_frame
	var r := SmokeTagBomb.COVER_RADIUS
	var across := [AT - Vector2(400, 0), AT + Vector2(400, 0)]
	ck.call("smoke screen: an unexploded bomb blocks nothing", smoke.cover_radius() == 0.0 and not SmokeTagBomb.blocks_sight(across[0], across[1]))

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(player)
	var bandit := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	root.add_child(bandit)
	bandit.set_physics_process(false)
	bandit._player = player
	bandit.global_position = AT + Vector2(230, 0)
	bandit.set_home(bandit.global_position)
	bandit.facing8 = Vector2.LEFT
	player.global_position = AT - Vector2(190, 0)
	await tree.physics_frame
	ck.call("smoke screen: control, the bandit sees the player across open ground", bandit.can_see(player.global_position, false) and bandit.can_see(player.global_position, true))

	smoke.explode()
	ck.call("smoke screen: a burst registers a standing screen, still thin at t=0", SmokeTagBomb.screens.has(smoke) and smoke.cover_radius() == 0.0)
	smoke.advance(SmokeTagBomb._burst_seconds() * 0.5)
	var half := smoke.cover_radius()
	ck.call("smoke screen: it spreads with the burst", half > 0.0 and half < r, str(half))
	smoke.advance(SmokeTagBomb._burst_seconds())
	ck.call("smoke screen: full cover once the burst has played", is_equal_approx(smoke.cover_radius(), r), str(smoke.cover_radius()))
	ck.call("smoke screen: three PixelLab banks are drawn", smoke.clouds.size() == 3 and smoke.clouds.all(func(c: Sprite2D) -> bool: return c.texture != null))

	_geometry(r)
	_bandit_sight(bandit, player)
	_overlay(bandit, player)
	await _lock_and_sense(root)

	# The screen gives way during the fade and is gone at SMOKE_SECONDS.
	var fade_start := SmokeTagBomb.SMOKE_SECONDS - SmokeTagBomb._fade_seconds()
	smoke.advance(fade_start - smoke.blast_t + SmokeTagBomb._fade_seconds() * SmokeTagBomb.CLEAR_SHARE * 0.5)
	var thinning := smoke.cover_radius()
	ck.call("smoke screen: sight starts coming back while the puffs break apart", thinning > 0.0 and thinning < r, str(thinning))
	smoke.advance(SmokeTagBomb._fade_seconds() * SmokeTagBomb.CLEAR_SHARE)
	ck.call("smoke screen: once broken up it no longer blocks, though the last wisps still draw", smoke.cover_radius() == 0.0 and smoke.phase == PaperTagBomb.Phase.BLAST and not SmokeTagBomb.blocks_sight(across[0], across[1]))
	bandit.state = Bandit.State.PATROL
	ck.call("smoke screen: the bandit sees the player again", bandit.can_see(player.global_position, false))
	smoke.advance(SmokeTagBomb.SMOKE_SECONDS)
	ck.call("smoke screen: gone after SMOKE_SECONDS", not SmokeTagBomb.screens.has(smoke) and smoke.is_queued_for_deletion())
	bandit.queue_free()
	player.queue_free()
	await tree.process_frame


func _geometry(r: float) -> void:
	var cut := SmokeTagBomb.first_cover(AT - Vector2(400, 0), AT + Vector2(400, 0))
	ck.call("smoke screen: a line through the cloud is cut where it enters", not cut.is_empty() and absf(float(cut.t) * 800.0 - (400.0 - r)) < 0.5, str(cut.get("t")))
	ck.call("smoke screen: a line passing beside it is clear", not SmokeTagBomb.blocks_sight(AT + Vector2(-400, r / SmokeTagBomb.ISO_Y + 12.0), AT + Vector2(400, r / SmokeTagBomb.ISO_Y + 12.0)))
	ck.call("smoke screen: a line stopping short of it is clear", not SmokeTagBomb.blocks_sight(AT - Vector2(400, 0), AT - Vector2(r + 8.0, 0)))
	ck.call("smoke screen: iso floor ellipse, as wide as COVER_RADIUS and half as deep", SmokeTagBomb.hides(AT + Vector2(r - 4.0, 0)) and SmokeTagBomb.hides(AT + Vector2(0, r * 0.45)) and not SmokeTagBomb.hides(AT + Vector2(0, r * 0.55)) and not SmokeTagBomb.hides(AT + Vector2(r + 4.0, 0)))
	ck.call("smoke screen: from inside nothing is visible outward, and the inside is hidden from out", SmokeTagBomb.blocks_sight(AT, AT + Vector2(400, 0)) and SmokeTagBomb.blocks_sight(AT + Vector2(400, 0), AT))


func _bandit_sight(bandit: Bandit, player: CharacterBody2D) -> void:
	var r := r_edge()
	ck.call("smoke screen: the bandit cannot see the player through it", not bandit.can_see(player.global_position, false) and not bandit.can_see(player.global_position, true))
	bandit.state = Bandit.State.APPROACH
	bandit._update_perception()
	ck.call("smoke screen: chasing, the bandit loses sight (sees_player false)", not bandit.sees_player)
	var home := player.global_position
	player.global_position = AT + Vector2(20, 10)
	ck.call("smoke screen: a player standing inside it is hidden even right next to the bandit", not bandit.can_see(player.global_position, false))
	bandit.state = Bandit.State.PATROL
	bandit.is_sprinting = true
	bandit.global_position = AT + Vector2(r + 30.0, 0)
	bandit._update_perception()
	ck.call("smoke screen: a naruto-running bandit cannot sense a player hidden in it", not bandit.senses_player and bandit.state == Bandit.State.PATROL, bandit.get_state_name())
	player.global_position = AT + Vector2(r + 30.0, 120)
	bandit._update_perception()
	ck.call("smoke screen: control, the same sense finds a player out in the open", bandit.senses_player)
	bandit.is_sprinting = false
	bandit.global_position = AT + Vector2(10, 0)
	ck.call("smoke screen: a bandit inside it is blind", not bandit.can_see(player.global_position, false) and not bandit.can_see(AT + Vector2(r + 60.0, -20.0), false))
	bandit.global_position = AT + Vector2(230, 0)
	bandit.state = Bandit.State.PATROL
	player.global_position = home


func _overlay(bandit: Bandit, player: CharacterBody2D) -> void:
	bandit.state = Bandit.State.APPROACH
	var reg := BanditVisionRegion.compute(bandit, player)
	var before := AT + Vector2(r_edge() + 25.0, 0)
	var behind := AT - Vector2(r_edge() + 25.0, 0)
	ck.call("smoke screen overlay: the polygon stops at the smoke, like can_see", reg.contains(before) and bandit.can_see(before, false) and not reg.contains(behind) and not bandit.can_see(behind, false))
	var wrong := 0
	var n := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 26102026
	for k in 600:
		var p := bandit.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, reg.reach)
		if BanditVisionRegion.near_ai_boundary(bandit, p, false):
			continue
		n += 1
		if reg.contains(p) != bandit.can_see(p, false):
			wrong += 1
	ck.call("smoke screen overlay: polygon and can_see agree off the 1 px boundary band", wrong == 0 and n > 400, "%d of %d disagree" % [wrong, n])
	bandit.global_position = AT + Vector2(10, 0)
	ck.call("smoke screen overlay: a bandit inside the smoke shows no region", BanditVisionRegion.compute(bandit, player).points.is_empty())
	bandit.global_position = AT + Vector2(230, 0)
	bandit.state = Bandit.State.PATROL


func r_edge() -> float:
	return SmokeTagBomb.COVER_RADIUS


func _lock_and_sense(root: Node) -> void:
	var me := Node2D.new()
	root.add_child(me)
	me.global_position = AT - Vector2(r_edge() + 120.0, 0)
	var lock := PlayerLockOn.new()
	me.add_child(lock)
	var hidden := FakeEnemy.new()
	hidden.add_to_group("enemy")
	root.add_child(hidden)
	hidden.global_position = AT + Vector2(15, 0)
	var behind := FakeEnemy.new()
	behind.add_to_group("enemy")
	root.add_child(behind)
	behind.global_position = AT + Vector2(r_edge() + 60.0, 0)
	await tree.process_frame
	lock.toggle()
	ck.call("smoke screen: the player cannot lock on to a bandit inside or behind the smoke", lock.target == null, str(lock.target))
	var open := FakeEnemy.new()
	open.add_to_group("enemy")
	root.add_child(open)
	open.global_position = me.global_position + Vector2(0, 260)
	lock.toggle()
	ck.call("smoke screen: control, a bandit in the open is locked", lock.target == open)
	lock.advance(PlayerLockOn.ACQUIRE_T + 0.01)
	ck.call("smoke screen: a flick cannot hop into the smoke", not lock.switch_target(Vector2.RIGHT) and lock.target == open)
	open.global_position = AT + Vector2(0, 20)
	lock.advance(0.01)
	ck.call("smoke screen: a locked bandit stepping into the smoke breaks the lock", lock.target == null and lock.phase == PlayerLockOn.Phase.RELEASE)
	ck.call("smoke screen: the player's sprint sense cannot feel a bandit hidden in it", ProximitySense.nearest_in_radius(AT + Vector2(-r_edge() - 20.0, 0), 400.0, "enemy", tree, me) == null)
	behind.global_position = AT + Vector2(-r_edge() - 20.0, 150)
	ck.call("smoke screen: the sense still feels one out in the open (it ignores walls, not smoke cover)", ProximitySense.nearest_in_radius(AT + Vector2(-r_edge() - 20.0, 0), 400.0, "enemy", tree, me) == behind)
	for n: Node in [me, hidden, behind, open]:
		n.queue_free()
	await tree.process_frame
