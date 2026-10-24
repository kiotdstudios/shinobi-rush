extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var grove := BlossomGrove.new()
	root.add_child(grove)
	grove.set_process(false)
	await root.get_tree().process_frame
	ck.call("trees: all five distinct references placed", grove.trees.size() == 5)
	ck.call("trees: nested Y sort follows ground anchors", grove.y_sort_enabled)
	var paths: Array[String] = []
	for tree: BlossomTree in grove.trees:
		paths.append(str(tree.data.texture))
		var anchor := Vector2(float(tree.data.anchor[0]), float(tree.data.anchor[1]))
		ck.call("tree root: " + tree.name, tree.sprite.position == -anchor and tree.sprite.texture.get_size() == Vector2(320,448))
		var image := tree.sprite.texture.get_image()
		var emitters_opaque := true
		for point: Array in tree.data.canopy_emission:
			var pixel := Vector2i(Vector2(float(point[0]),float(point[1])) + anchor)
			emitters_opaque = emitters_opaque and image.get_pixelv(pixel).a > 0.85
		ck.call("tree emission comes from actual canopy: " + tree.name, emitters_opaque)
		ck.call("tree: independent bounded leaf pool: " + tree.name, tree.foliage.particles.size() == 24 and tree.foliage.active_count() == 12)
	ck.call("trees: five unique textures", paths.size() == 5 and paths[0] != paths[1] and paths[2] != paths[3] and paths[3] != paths[4])
	var root_positions: Array[Vector2] = []
	for tree: BlossomTree in grove.trees:
		root_positions.append(tree.sprite.position)
	grove.advance(1.0 / 24.0)
	ck.call("trees: first of 96 wind phases", grove.phase() == 1)
	grove.advance(4.0)
	ck.call("trees: exact four-second loop wraps", grove.phase() == 1)
	var steady := true
	for i in grove.trees.size():
		steady = steady and grove.trees[i].sprite.position == root_positions[i]
	ck.call("trees: roots never translate through wind", steady)
	for i in 600:
		grove.advance(0.1)
	ck.call("trees: one-minute particle budget bounded", grove.particle_count() <= 120 and grove.particle_count() > 0)
	grove.wind_on = false
	var foliage := grove.trees[0].foliage
	var previous_spawns := foliage.spawned
	grove.advance(2.0)
	ck.call("trees: leaves emit independently while wind off", foliage.spawned > previous_spawns and not bool(grove.trees[0].wind.get_shader_parameter("wind_enabled")))
	grove.leaves_on = false
	grove.advance(12.0)
	ck.call("trees: disabled emitter drains all leaves", grove.particle_count() == 0)
	ck.call("trees: leaf sprites not baked into tree", not grove.trees[0].foliage.visible and grove.trees[0].sprite.visible)
	grove.leaves_on = true
	grove.advance(1.0)
	ck.call("trees: independent emitter restarts", grove.particle_count() > 0)
	grove.queue_free()
	await root.get_tree().process_frame
