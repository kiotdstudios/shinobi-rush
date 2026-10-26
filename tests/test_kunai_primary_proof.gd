extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var proof := (load("res://scenes/art/kunai_primary_proof.tscn") as PackedScene).instantiate() as KunaiPrimaryProof
	root.add_child(proof)
	proof.set_process(false)
	proof.paused = true
	ck.call("kunai proof: half-speed default and complete sequence", is_equal_approx(proof.playback_speed, 0.5) and proof.timeline.size() == 53 and is_equal_approx(proof.total_ms, 4220.0))
	var table := AttackDef.build_table()
	for id: String in ["light1", "light2", "light3", "dash_attack"]:
		var action: Dictionary = proof.data.animations[id]
		var attack := table[id] as AttackDef
		ck.call("kunai proof: %s duration matches gameplay" % id, absf(float(action.duration_ms) - attack.total_duration() * 1000.0) < 0.01)
		var contact: Dictionary = action.frames[action.contact_frames[0]]
		ck.call("kunai proof: %s contact matches active start" % id, absf(float(contact.start_ms) - attack.startup * 1000.0) < 0.01)
	var weapon_instance := proof.blade
	for i in proof.timeline.size():
		proof.elapsed_ms = float(proof.timeline[i].timeline_start) + 0.001
		proof._process(0)
		ck.call("kunai proof: shared weapon persists frame%d" % i, proof.blade == weapon_instance and proof.blade.texture != null and proof.blade.visible and proof.body.texture.get_size() == Vector2(128, 128))
	proof.elapsed_ms = 2500.0
	proof._process(0)
	proof.select_action("light3")
	ck.call("kunai proof: shorter selection resets source clock", proof.elapsed_ms == 0.0 and proof.scrub.value == 0.0)
	proof.elapsed_ms = float(proof.timeline[1].timeline_start)
	proof._process(0)
	ck.call("kunai proof: rear-hand turn changes draw order", proof.grip.z_index == -1)
	proof.step()
	ck.call("kunai proof: step reaches contact and front layer", proof.last_frame == 2 and proof.grip.z_index == 1 and proof.swipe.visible and proof.paused)
	var library := SpriteLibrary.new()
	library.scan()
	ck.call("kunai proof: review metadata cannot replace player set", library.first_valid().id == "player_128")
	proof.queue_free()
	await root.get_tree().process_frame
