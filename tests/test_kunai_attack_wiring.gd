extends RefCounted
## Kunai weapon-overlay wiring (owner 2026-10-22: "check and see if codex made kunai attack that can
## commit and be syncd to square key on controller" -> "wire it to the controller"). Called from
## tests/run_tests.gd.
##
## Covers: (1) the real production SpriteSet stays valid and now carries Codex's SE kunai strike art
## (light1/light2/light3/dash_attack) without weakening the cardinal-direction guard for any
## pre-existing animation; (2) pressing attack_light while facing SE actually shows the kunai weapon
## overlay in the real player scene, synced to the body frame; (3) facing any other direction during
## the same attack never shows the weapon or snaps the body to the wrong-facing SE pose -- the art is
## proof-stage/SE-only per Codex's order and must not silently cover the other 7 directions.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	_test_manifest_regression()
	_test_weapon_rig_data()
	await _test_se_attack_shows_weapon(tree_root)
	await _test_other_facing_hides_weapon(tree_root)


# ------------------------------------------------------------------ helpers (mirrors tests/test_combat.gd)
func _boot(tree_root: Node) -> Array:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var arena := main.get_node_or_null("TrainingArena") as TrainingArena
	var player := main.get_node_or_null("TrainingArena/Player") as PlayerController
	return [main, arena, player]


func _reset(player: PlayerController, pos: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dodge", "jump", "attack_light"]:
		Input.action_release(a)
	player._dodge_buffer = 0.0
	player._jump_buffer = 0.0
	player._attack_buffer = 0.0
	player._dash_grace_timer = 0.0
	player._action_timer = 0.0
	player._attack_timer = 0.0
	player._hitstop_timer = 0.0
	player._combo_index = 0
	player.state = PlayerController.State.IDLE
	player.global_position = pos
	player.velocity = Vector2.ZERO


## Hold for a few frames before releasing -- same reasoning as test_combat.gd's own _tap().
func _tap(action: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Input.action_press(action)
	for i in 3:
		await tree.physics_frame
	Input.action_release(action)


# ------------------------------------------------------------------ 1. manifest / SpriteSet regression
func _test_manifest_regression() -> void:
	var s := SpriteLibrary.get_instance().first_valid()
	ck.call("kunai wiring: the production player SpriteSet is still valid (allow_partial_directions did not weaken any existing animation)", s != null and s.is_valid(), "" if s == null else "; ".join(s.errors))
	if s == null:
		return
	for aid in ["idle", "walk", "run", "sprint", "jump", "dodge"]:
		ck.call("kunai wiring: pre-existing animation \"%s\" is unaffected" % aid, s.animations.has(aid))
	for aid in ["light1", "light2", "light3", "dash_attack"]:
		ck.call("kunai wiring: \"%s\" is now a real animation in the production manifest" % aid, s.animations.has(aid))
		if s.animations.has(aid):
			var dirs: Array = s.animations[aid]["dirs"]
			ck.call("kunai wiring: \"%s\" is SE-only in the manifest (matches the approved proof scope)" % aid, dirs == ["SE"], str(dirs))


# ------------------------------------------------------------------ 2. WeaponRig data sanity
func _test_weapon_rig_data() -> void:
	for aid in ["light1", "light2", "light3", "dash_attack"]:
		ck.call("kunai wiring: WeaponRig supports \"%s\"" % aid, WeaponRig.supports(aid))
	ck.call("kunai wiring: WeaponRig does not claim support for an unrelated id", not WeaponRig.supports("idle"))
	var p := WeaponRig.pose("light1", 0)
	ck.call("kunai wiring: WeaponRig.pose returns hand/angle/layer", p.has("hand") and p.has("angle_deg") and p.has("layer"), str(p))
	var clamped := WeaponRig.pose("light1", 999)
	ck.call("kunai wiring: WeaponRig.pose clamps an out-of-range frame instead of erroring", not clamped.is_empty())
	ck.call("kunai wiring: WeaponRig.pose({}) for an unsupported id", WeaponRig.pose("idle", 0).is_empty())


# ------------------------------------------------------------------ 3. SE facing: weapon actually shows
func _test_se_attack_shows_weapon(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	if player == null:
		ck.call("kunai wiring: scene has player (SE attack)", false)
		main.queue_free()
		return
	_reset(player, Vector2(-900, 100))
	player.facing8 = Vector2(1, 1).normalized()  ## SE
	var saw_weapon := false
	var saw_light1_body := false
	await _tap("attack_light")
	for i in 60:
		await main.get_tree().physics_frame
		if player.state == PlayerController.State.LIGHT1:
			if player.visual.last_anim == "light1" and player.visual.has_action("light1"):
				saw_light1_body = true
			if player.visual.weapon_visible():
				saw_weapon = true
		if player.state == PlayerController.State.MOVE or player.state == PlayerController.State.IDLE:
			break
	ck.call("kunai wiring: facing SE, light1 actually plays the real kunai body art (not frozen/placeholder)", saw_light1_body)
	ck.call("kunai wiring: facing SE, the kunai weapon overlay becomes visible during light1", saw_weapon)
	ck.call("kunai wiring: the weapon overlay is hidden again once the attack ends", not player.visual.weapon_visible())
	main.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ 4. any other facing: never shows the
# SE-only art or weapon (the proof is not approved for the other 7 directions yet)
func _test_other_facing_hides_weapon(tree_root: Node) -> void:
	var r := await _boot(tree_root)
	var main: Node = r[0]
	var player: PlayerController = r[2]
	if player == null:
		ck.call("kunai wiring: scene has player (non-SE attack)", false)
		main.queue_free()
		return
	_reset(player, Vector2(-900, 100))
	player.facing8 = Vector2(0, -1)  ## N -- not the approved SE direction
	var saw_weapon := false
	var saw_wrong_facing_body := false
	await _tap("attack_light")
	for i in 60:
		await main.get_tree().physics_frame
		if player.state == PlayerController.State.LIGHT1:
			if player.visual.weapon_visible():
				saw_weapon = true
			if player.visual.last_anim == "light1" and player.visual.actor.dir == "SE":
				saw_wrong_facing_body = true
		if player.state == PlayerController.State.MOVE or player.state == PlayerController.State.IDLE:
			break
	ck.call("kunai wiring: facing N, the kunai weapon overlay never shows (SE-only art, no direction fallback)", not saw_weapon)
	ck.call("kunai wiring: facing N, the body never snaps to the SE pose either", not saw_wrong_facing_body)
	main.queue_free()
	await main.get_tree().process_frame
