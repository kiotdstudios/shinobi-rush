extends RefCounted
## Codex's ryo pouch art wired as a pickup: 16 idle / 12 glow / 12 ember frames, +50 ryo on touch, never respawns.


func run(ck: Callable, root: Node) -> void:
	Bandit.substitution_enabled = false
	AncientShrineSection.enabled = false
	MapEditorMode.forced = false
	ck.call("ryo: idle art loads (16 frames)", HealthGourd.frames("gourd", "ryo").size() == 16)
	ck.call("ryo: aura art loads (12 frames)", HealthGourd.frames("glow", "ryo").size() == 12)
	ck.call("ryo: sparkle art loads (12 frames)", HealthGourd.frames("ember", "ryo").size() == 12)
	ck.call("ryo: the builder has a palette entry with an icon", PlacedObjects.def_of("ryo_pouch").gourd == "ryo" and HealthGourd.icon("ryo") != null)
	var inv := PlayerInventory.new()
	inv.save_path = "user://test_ryo_inventory.json"
	ck.call("ryo: starts at zero", inv.ryo == 0)
	var tree := root.get_tree()
	var holder := Node2D.new()
	root.add_child(holder)
	var pouch := HealthGourd.new()
	pouch.kind = "ryo"
	holder.add_child(pouch)
	await tree.process_frame
	ck.call("ryo: pouches never respawn", not pouch.respawns)
	var fake := FakePlayer.new()
	fake.inventory = inv
	fake.add_to_group("player")
	holder.add_child(fake)
	ck.call("ryo: collectible with a full bag", pouch.can_collect(fake))
	var got := pouch.collect(fake)
	ck.call("ryo: touching it gives 50 ryo", int(got) == HealthGourd.RYO_AMOUNT and inv.ryo == 50)
	ck.call("ryo: the pouch is spent", not pouch.available)
	ck.call("ryo: a spent pouch gives nothing twice", pouch.collect(fake) == 0.0 and inv.ryo == 50)
	ck.call("ryo: the take-it animation runs with a gold RYO label", pouch.fx != null and pouch.fx._label == "RYO")
	holder.queue_free()
	await tree.process_frame


class FakePlayer extends Node2D:
	var inventory: PlayerInventory
