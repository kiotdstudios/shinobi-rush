extends RefCounted
func run(ck: Callable, root: Node) -> void:
	for who: String in ["player","bandit"]:
		var path := "res://assets/characters/%s/%s" % [who,"player_128.manifest.json" if who=="player" else "bandit_128.art.json"]
		var s := SpriteSet.parse(FileAccess.get_file_as_string(path),path)
		ck.call("damage art: valid manifest "+who,s.is_valid())
		var actor := SpriteActor.new()
		root.add_child(actor)
		for action: String in ["hit_react","knockback","death"]:
			var count: int = {"hit_react":8,"knockback":12,"death":16}[action]
			var frames := s.get_frames(action)
			ck.call("damage art: clip exists "+who+action,frames!=null)
			if frames==null:continue
			for direction: String in ["S","SE","E","NE","N","NW","W","SW"]:
				var label := who+" "+action+" "+direction
				ck.call("damage art: native eight-way clip "+label,frames.has_animation(direction) and frames.get_frame_count(direction)==count and not frames.get_animation_loop(direction))
				var shown := actor.show_animation_at(s,action,direction,0.0)
				ck.call("damage art: exact heading and anchor "+label,shown and not actor.flip and not actor.fallback and actor.sprite.position==Vector2(-64,-116) and actor.sprite.sprite_frames.get_frame_texture(direction,0).get_size()==Vector2(128,128))
				actor.show_animation_at(s,action,direction,1.0)
				ck.call("damage art: final pose holds "+label,actor.sprite.frame==count-1 and not actor.sprite.is_playing())
				actor.show_animation_at(s,action,direction,5.0)
				ck.call("damage art: overshoot never wraps "+label,actor.sprite.frame==count-1)
		# Free-running non-loop playback must hold too; the review's progress override isn't hiding a loop.
		actor.show_animation(s,"death","SE")
		actor.sprite.speed_scale=100.0
		actor.sprite.play("SE")
		await root.get_tree().create_timer(0.08).timeout
		ck.call("damage art: native nonloop death "+who,actor.sprite.frame==15 and not actor.sprite.is_playing())
		actor.queue_free()
		await root.get_tree().process_frame
	var review := (load("res://scenes/art/damage_animation_review.tscn") as PackedScene).instantiate()
	root.add_child(review)
	await root.get_tree().process_frame
	review.set_process(false)
	ck.call("damage review:16 actors across8headings",review.actors.size()==16)
	review._focus("SE")
	await root.get_tree().process_frame
	var visible_count := 0
	for actor: SpriteActor in review.actors:
		if actor.visible:visible_count+=1
	ck.call("damage review: enlarged paired heading",visible_count==2 and review.actors[1].scale==Vector2(3,3))
	review._select("death")
	review.clock=5.0
	review._display()
	var held := true
	for actor: SpriteActor in review.actors:
		held=held and actor.sprite.frame==15 and not actor.sprite.is_playing()
	ck.call("damage review: all death poses hold",held)
	review._focus("All headings")
	await root.get_tree().process_frame
	ck.call("damage review: restores overview scale",review.actors[0].scale==Vector2.ONE and review.actors[0].visible)
	review.queue_free()
	await root.get_tree().process_frame
