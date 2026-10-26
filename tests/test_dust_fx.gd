extends RefCounted
## Frame-based dust effects: every event kind has several PixelLab variants, spawns randomise, and puffs clean up.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 5:
		await main.get_tree().process_frame
	var p := main.get_node("TrainingArena/Player") as PlayerController
	var dust := p.get_node("DustPuff") as DustPuff
	ck.call("dust: the player has a DustPuff node", dust != null)
	for kind in ["step", "sprint", "jump", "land"]:
		var n: int = DustPuff.variants_for(kind).size()
		ck.call("dust: kind '%s' has at least 2 variants" % kind, n >= 2, str(n))
	for v in ["step_a", "trail_a", "skid_a", "plume_a", "ring_a"]:
		ck.call("dust: variant %s has 6+ frames" % v, DustPuff.frames_for(v).size() >= 6)
	var seen := {}
	var rots := {}
	for i in 30:
		var spr := dust.play("step", Vector2(100, 100), Vector2.RIGHT)
		if spr != null:
			seen[dust.last_variant] = true
			rots[snappedf(spr.rotation, 0.001)] = true
	ck.call("dust: 30 footsteps use at least 2 different variants", seen.size() >= 2, str(seen.keys()))
	ck.call("dust: per-spawn rotation/scale is randomised", rots.size() >= 5, str(rots.size()))
	ck.call("dust: live puffs are capped", dust.get_child_count() <= DustPuff.MAX_LIVE)
	await main.get_tree().create_timer(1.5).timeout
	ck.call("dust: puffs free themselves after their animation", dust.get_child_count() == 0, str(dust.get_child_count()))
	dust.burst(Vector2.ZERO, 1.5)
	ck.call("dust: legacy burst() still spawns a puff", dust.get_child_count() == 1)
	main.queue_free()
	await main.get_tree().process_frame
