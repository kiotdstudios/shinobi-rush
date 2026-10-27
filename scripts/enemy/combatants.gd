class_name Combatants
extends RefCounted
## Every fighter in the world, player or bandit, seen through one lens: who is alive, who is an enemy of whom, who
## stands on which level, and how a blow or a purse changes hands. Players share crew -1 (they are on their own
## side); each bandit crew is its own side, so rival crews fight each other on sight while crewmates never do.

const PLAYER_CREW := -1
## Melee reaches someone only when the two stand within this much elevation of each other (half a climb).
const MELEE_LEVEL_GAP := ShrineElevation.HEIGHT * ShrineElevation.BOARD_AT


static func all(tree: SceneTree) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if tree == null:
		return out
	for p in tree.get_nodes_in_group("player"):
		if p is Node2D:
			out.append(p)
	for e in tree.get_nodes_in_group("enemy"):
		if e is Bandit:
			out.append(e)
	return out


static func alive(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	if n is Bandit:
		return (n as Bandit).is_alive()
	return n.get("dying") != true


static func crew_of(n: Node) -> int:
	if n is Bandit:
		return (n as Bandit).crew_id
	return PLAYER_CREW


static func hostile(a: Node, b: Node) -> bool:
	if a == null or b == null or a == b or not is_instance_valid(a) or not is_instance_valid(b):
		return false
	return crew_of(a) != crew_of(b)


static func level_of(n: Node) -> float:
	var e: Variant = n.get("elevation") if n != null else null
	return float(e) if e != null else 0.0


static func same_level(a: Node, b: Node) -> bool:
	return absf(level_of(a) - level_of(b)) < MELEE_LEVEL_GAP


static func give_ryo(n: Node, amount: int) -> void:
	if amount <= 0 or n == null:
		return
	if n.has_method("gain_ryo"):
		n.call("gain_ryo", amount)
	elif n.get("ryo") != null:
		n.set("ryo", int(n.get("ryo")) + amount)
