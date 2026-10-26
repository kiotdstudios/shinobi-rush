extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var ground := WindGrassTileset.build_ground()
	var tall := WindGrassTileset.build_tall()
	ck.call("grass: nine terrain roles",ground.get_source_count()==9)
	ck.call("grass: same grid as Aki floor",ground.tile_size==KosenFloorTileset.TILE_SIZE and ground.tile_shape==TileSet.TILE_SHAPE_ISOMETRIC)
	ck.call("grass: no collision/nav layers",ground.get_physics_layers_count()==0 and ground.get_navigation_layers_count()==0 and tall.get_physics_layers_count()==0)
	for y in 3:
		for x in 3:
			ck.call("grass: canonical nine-slice %d/%d" % [x,y],WindGrassTileset.role_at(x,y,3,3)==y*3+x)
	ck.call("grass: expanded center/edges",WindGrassTileset.role_at(2,2,6,5)==4 and WindGrassTileset.role_at(3,0,6,5)==1 and WindGrassTileset.role_at(0,2,6,5)==3 and WindGrassTileset.role_at(5,2,6,5)==5 and WindGrassTileset.role_at(3,4,6,5)==7)
	for i in 9:
		var source := ground.get_source(i) as TileSetAtlasSource
		var data := source.get_tile_data(Vector2i.ZERO,0)
		ck.call("grass: ground source anchor%d" % i,source.texture.get_size()==Vector2(112,112) and Vector2i(source.texture.get_size()*0.5)+data.texture_origin==Vector2i(56,84))
	for i in 4:
		var source := tall.get_source(i) as TileSetAtlasSource
		var data := source.get_tile_data(Vector2i.ZERO,0)
		ck.call("grass: tall source anchor%d" % i,source.texture.get_size()==Vector2(112,160) and Vector2i(source.texture.get_size()*0.5)+data.texture_origin==Vector2i(56,136))
	var field := WindGrassField.new()
	root.add_child(field)
	field.set_process(false)
	await root.get_tree().process_frame
	ck.call("grass: placed meadow terrain",field.ground.get_used_cells().size()==247)
	ck.call("grass: bounded tall accents",field.tall.get_used_cells().size()>50 and field.tall.get_used_cells().size()<160)
	ck.call("grass: ground and blades Y sorted",field.y_sort_enabled and field.ground.y_sort_enabled and field.tall.y_sort_enabled)
	field.advance(1.0/24.0)
	ck.call("grass: frame step exact",field.phase()==1 and float(field.tall_wind.get_shader_parameter("phase_index"))==1.0)
	field.advance(6.0)
	ck.call("grass: six-second loop exact",field.phase()==1)
	var cells := field.ground.get_used_cells()
	field.wind_on=false
	field.advance(100.0)
	ck.call("grass: wind toggle leaves terrain fixed",not bool(field.tall_wind.get_shader_parameter("enabled")) and field.ground.get_used_cells()==cells)
	field.wind_on=true
	field.strength=1.6
	field.advance(0)
	ck.call("grass: gust strength independent",float(field.tall_wind.get_shader_parameter("strength"))==1.6 and bool(field.tall_wind.get_shader_parameter("enabled")))
	var other := WindGrassField.new()
	root.add_child(other)
	other.set_process(false)
	await root.get_tree().process_frame
	var deterministic := other.tall.get_used_cells()==field.tall.get_used_cells()
	for cell: Vector2i in field.ground.get_used_cells():
		deterministic=deterministic and other.ground.get_cell_source_id(cell)==field.ground.get_cell_source_id(cell)
	ck.call("grass: repeatable terrain/art variation",deterministic)
	field.queue_free()
	other.queue_free()
	await root.get_tree().process_frame
