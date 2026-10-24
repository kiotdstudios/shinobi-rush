extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/ashen_trees/ashen-trees.art.json"))
	for entry: Dictionary in data.trees:
		var tree := AshenTree.new()
		tree.data = entry
		root.add_child(tree)
		assert(tree.sprite.texture.get_size() == Vector2(320,448))
		assert(tree.flakes.size() == 24)
		assert(tree.sprite.position == Vector2(-160,-416))
		var positions: Array[Vector2] = []
		for flake in tree.flakes:
			positions.append(flake.position)
		tree.advance(8.0)
		for i in tree.flakes.size():
			assert(tree.flakes[i].position.distance_to(positions[i]) < 0.001)
		tree.advance(10000.0,false,false,false)
		assert(tree.flakes.size() == 24)
		for flake in tree.flakes:
			assert(not flake.visible)
		tree.queue_free()
	await process_frame
	print("ASHEN TREES:3 textures, anchors,72 bounded flakes,8s wrap and independent controls PASS")
	quit(0)
