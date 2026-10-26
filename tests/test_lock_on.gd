extends RefCounted
## R3 / L toggles the enemy lock-on; the reticle animation walks ACQUIRE -> LOCKED -> RELEASE.


class FakeEnemy extends Node2D:
	var alive := true
	func is_alive() -> bool:
		return alive


func run(ck: Callable, root: Node) -> void:
	var tree := root.get_tree()
	# The action is added by PlayerLockOn._ready, so build one first.
	var player := Node2D.new()
	root.add_child(player)
	var lock := PlayerLockOn.new()
	lock.name = "LockOn"
	player.add_child(lock)
	await tree.process_frame
	var has_r3 := false
	var other_r3 := ""
	for a in InputMap.get_actions():
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK:
				if a == "lock_on":
					has_r3 = true
				else:
					other_r3 = String(a)
	ck.call("lock-on: R3 (right stick click) is bound to lock_on", has_r3)
	ck.call("lock-on: no other action uses R3", other_r3 == "", other_r3)

	var enemy := FakeEnemy.new()
	enemy.add_to_group("enemy")
	enemy.position = Vector2(200, 0)
	root.add_child(enemy)
	var far := FakeEnemy.new()
	far.add_to_group("enemy")
	far.position = Vector2(RANGE_FAR(), 0)
	root.add_child(far)

	ck.call("lock-on: nothing is shown before locking", lock.phase == PlayerLockOn.Phase.NONE and not lock.valid_target())
	lock.toggle()
	ck.call("lock-on: R3 locks the nearest enemy", lock.target == enemy and lock.is_targeted(enemy))
	ck.call("lock-on: an enemy out of range is never picked", lock.target != far)
	lock.advance(0.05)
	ck.call("lock-on: the acquire animation starts", lock.phase == PlayerLockOn.Phase.ACQUIRE)
	lock.advance(PlayerLockOn.ACQUIRE_T)
	ck.call("lock-on: the brackets land and the reticle settles", lock.phase == PlayerLockOn.Phase.LOCKED)
	ck.call("lock-on: back-ease overshoots then lands on 1", PlayerLockOn.ease_out_back(0.0) < 0.001 and PlayerLockOn.ease_out_back(0.7) > 1.0 and absf(PlayerLockOn.ease_out_back(1.0) - 1.0) < 0.001)
	lock.queue_redraw()
	await tree.process_frame
	ck.call("lock-on: the locked reticle draws without error", lock.phase == PlayerLockOn.Phase.LOCKED)

	lock.toggle()
	lock.advance(0.01)
	ck.call("lock-on: R3 again unlocks and the release animation plays", lock.target == null and lock.phase == PlayerLockOn.Phase.RELEASE)
	lock.advance(PlayerLockOn.RELEASE_T + 0.01)
	ck.call("lock-on: the reticle is gone after the release", lock.phase == PlayerLockOn.Phase.NONE)

	lock.toggle()
	lock.advance(PlayerLockOn.ACQUIRE_T + 0.05)
	ck.call("lock-on: locked again", lock.phase == PlayerLockOn.Phase.LOCKED)
	enemy.alive = false
	lock.advance(0.01)
	ck.call("lock-on: a dead target releases the lock with the burst", lock.target == null and lock.phase == PlayerLockOn.Phase.RELEASE)
	lock.advance(1.0)
	ck.call("lock-on: and then the reticle clears", lock.phase == PlayerLockOn.Phase.NONE)

	enemy.alive = true
	lock.toggle()
	lock.advance(PlayerLockOn.ACQUIRE_T + 0.05)
	player.position = Vector2(-2000, 0)
	lock.advance(0.01)
	ck.call("lock-on: walking out of range releases the lock", not lock.valid_target() and lock.phase == PlayerLockOn.Phase.RELEASE)
	for n: Node in [enemy, far]:
		n.remove_from_group("enemy")
		n.free()
	player.free()


static func RANGE_FAR() -> float:
	return PlayerLockOn.RANGE + 300.0
