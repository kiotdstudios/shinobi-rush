extends RefCounted
## Flicking the right stick while locked hops the lock to the next enemy in that direction.


class FakeEnemy extends Node2D:
	var alive := true
	func is_alive() -> bool:
		return alive


func _enemy(root: Node, pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemy")
	e.position = pos
	root.add_child(e)
	return e


func run(ck: Callable, root: Node) -> void:
	var tree := root.get_tree()
	var player := Node2D.new()
	root.add_child(player)
	var lock := PlayerLockOn.new()
	lock.name = "LockOn"
	player.add_child(lock)
	await tree.process_frame
	var mid := _enemy(root, Vector2(200, 0))
	var right := _enemy(root, Vector2(400, 20))
	var left := _enemy(root, Vector2(-300, 5))
	var up := _enemy(root, Vector2(200, -250))
	var far := _enemy(root, Vector2(PlayerLockOn.RANGE + 400.0, 0))

	ck.call("lock-switch: a flick with no lock does nothing", not lock.switch_target(Vector2.RIGHT))
	lock.toggle()
	ck.call("lock-switch: starts on the nearest", lock.target == mid)
	ck.call("lock-switch: flick right hops to the enemy on the right", lock.switch_target(Vector2.RIGHT) and lock.target == right)
	ck.call("lock-switch: flick left from there goes back toward the middle", lock.switch_target(Vector2.LEFT) and lock.target == mid)
	ck.call("lock-switch: flick up picks the enemy above", lock.switch_target(Vector2.UP) and lock.target == up)
	lock.target = mid
	ck.call("lock-switch: flick left picks the enemy on the left", lock.switch_target(Vector2.LEFT) and lock.target == left)
	lock.target = right
	ck.call("lock-switch: nothing further right means the lock stays", not lock.switch_target(Vector2.RIGHT) and lock.target == right)
	ck.call("lock-switch: an enemy out of range is never picked", lock.target != far)
	lock.target = mid
	left.alive = false
	ck.call("lock-switch: dead enemies are skipped", not lock.switch_target(Vector2.LEFT) and lock.target == mid)
	for n in [mid, right, left, up, far, player]:
		n.queue_free()
	await tree.process_frame
