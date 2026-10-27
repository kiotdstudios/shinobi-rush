extends RefCounted
## BanditInventory: the bandit's D-pad belt (4 slots, 2 of each kind, swap / drop like the player's D-pad).

var ck: Callable


func run(check: Callable, _root: Node) -> void:
	ck = check
	var inv := BanditInventory.new(2)
	ck.call("bandit belt: four D-pad slots like the player's, all empty", inv.dpad.keys() == PlayerInventory.DPAD_SLOTS and inv.total() == 0)
	ck.call("bandit belt: a health gourd goes on the player's health slot", inv.add("health_gourd") == 1 and inv.slot_of("health_gourd") == "up")
	ck.call("bandit belt: at most two of a kind", inv.add("health_gourd", 5) == 1 and inv.count_of("health_gourd") == 2 and not inv.room_for("health_gourd"))
	ck.call("bandit belt: a full stack of a kind he holds is not wanted again", not inv.wants("health_gourd"))
	inv.add("chakra_gourd")
	inv.add("kunai")
	inv.add("paper_tag")
	ck.call("bandit belt: four kinds fill the four slots", inv.free_slot_for("tag_bomb") == "" and inv.total() == 5 and not inv.room_for("tag_bomb"))
	ck.call("bandit belt: a fifth kind worth more than his worst swaps that one out", inv.swap_slot_for("tag_bomb") == inv.slot_of("kunai") and inv.wants("tag_bomb"))
	var kslot := inv.slot_of("kunai")
	var dropped := inv.drop_slot(kslot)
	ck.call("bandit belt: dropping a slot empties it and hands back what was on it", dropped == {"id": "kunai", "count": 1} and inv.slot_item(kslot) == "" and inv.count_of("kunai") == 0)
	ck.call("bandit belt: the freed slot takes the new kind", inv.add("tag_bomb") == 1 and inv.slot_of("tag_bomb") == kslot)
	ck.call("bandit belt: a fifth kind worth less than everything he holds is left lying", not inv.wants("smoke_tag_bomb") and inv.swap_slot_for("smoke_tag_bomb") == "")
	var up := inv.slot_item("up")
	var down := inv.slot_item("down")
	inv.swap_slots("up", "down")
	ck.call("bandit belt: two slots trade places, counts unchanged", inv.slot_item("up") == down and inv.slot_item("down") == up and inv.total() == 5)
	ck.call("bandit belt: using the last of a kind frees its slot", inv.consume("chakra_gourd") and inv.slot_of("chakra_gourd") == "" and inv.free_slot_for("smoke_tag_bomb") != "")
	ck.call("bandit belt: unknown ids are never carried", not inv.room_for("ryo") and inv.add("ryo") == 0)
	ck.call("bandit belt: items lie on the ground as their pickup kind", BanditInventory.pickup_kind("health_gourd") == "health" and BanditInventory.pickup_kind("chakra_gourd") == "chakra" and BanditInventory.pickup_kind("tag_bomb") == "tag_bomb")
	var lvl1 := EnemyIntelligence.profile(1)
	ck.call("bandit belt: the level 1 bandit carries two of each kind and loots", int(lvl1.get("item_carry", 0)) == 2 and float(lvl1.get("loot_sight", 0.0)) > 0.0)
