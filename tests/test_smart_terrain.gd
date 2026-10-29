extends RefCounted

func run(ck: Callable, root: Node) -> void:
	ck.call("smart: registry groups pure materials",TerrainFamilyMatcher.material("grass9_center",{})=="grass" and TerrainFamilyMatcher.material("path_dirt_15_a",{})=="dirt")
	ck.call("smart: pure bank metadata keeps brown dirt distinct from path",TerrainFamilyMatcher.material("shore_dirt_15",{})=="ground" and TerrainFamilyMatcher.material("shore_brown_15",{})=="dirt" and TerrainFamilyMatcher.material("shore_grass_15",{})=="grass")
	ck.call("smart: water registry remains water",TerrainFamilyMatcher.material("shore_rock_03",{})=="water")
	ck.call("smart: mixed corners require approval",TerrainFamilyMatcher.material("grass_dirt_06_b",{})=="" and TerrainFamilyMatcher.metadata("grass_dirt_06_b").materials.size()==2)
	ck.call("smart: explicit override precedes metadata",TerrainFamilyMatcher.material("grass9_center",{"grass9_center":"rock"})=="rock")
	ck.call("smart: rejection preserves manual mode",TerrainFamilyMatcher.material("grass9_center",{"grass9_center":"manual"})=="")
	ck.call("smart: objects never become terrain",TerrainFamilyMatcher.material("tree_1",{"tree_1":"grass"})=="")
	var img := Image.create(72,36,false,Image.FORMAT_RGBA8)
	img.fill(Color(.2,.5,.1,1))
	var feature := TerrainFamilyMatcher.features(img)
	ck.call("smart: native diamond features match exactly",not feature.is_empty() and is_equal_approx(TerrainFamilyMatcher.similarity(feature,feature),1.0))
	img.fill(Color(.9,.1,.8,1))
	ck.call("smart: different colors rank lower",TerrainFamilyMatcher.similarity(feature,TerrainFamilyMatcher.features(img))<.5)
	img.fill(Color(.2,.2,.2,1))
	for y in 36:
		for x in 72:
			img.set_pixel(x,y,Color.WHITE if x<36 else Color.BLACK)
	var edges := TerrainFamilyMatcher.features(img)
	img.flip_x()
	ck.call("smart: edge bands distinguish mirrored equal-average tiles",TerrainFamilyMatcher.similarity(edges,TerrainFamilyMatcher.features(img))<.5)
	var invalid := Image.create(128,128,false,Image.FORMAT_RGBA8)
	invalid.fill(Color.WHITE)
	ck.call("smart: incompatible canvas rejected",TerrainFamilyMatcher.features(invalid).is_empty())
	img.fill(Color.TRANSPARENT)
	ck.call("smart: transparent images rejected",TerrainFamilyMatcher.features(img).is_empty())
	for mat: String in TerrainBlend.MATERIALS:
		var ranks := TerrainFamilyMatcher.suggestions(TerrainBlend.PURE_ID[mat])
		ck.call("smart: actual pixel self match "+mat,not ranks.is_empty() and ranks[0].material==mat and is_equal_approx(ranks[0].score,1.0))
	var original_map := MapEditorMode.forced
	MapEditorMode.forced = true
	AncientShrineSection.enabled = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 14: await root.get_tree().process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	var p := arena.placed
	var e := arena.editor
	p.autosave=false
	p.save_path="user://smart-terrain-test.json"
	e.void_check=false
	for enabled in [false,true]:
		e.smart_terrain=enabled
		e.set_tool("paint","grass9_center")
		(e._palette_buttons["grass_tall_00"] as Button).pressed.emit()
		ck.call("smart: tall-grass palette keeps existing paint behavior (enabled=%s)"%enabled,e.tool=="paint" and e.place_id=="grass_tall_00")
	p.load_dict({"version":7,"items":[]})
	p.clear_history()
	ck.call("smart: validate override inputs",not p.set_terrain_family("tree_1","grass") and not p.set_terrain_family("grass9_center","unknown"))
	p.set_terrain_family("grass9_center","dirt")
	ck.call("smart: approval undo",p.undo() and p.terrain_families.is_empty())
	ck.call("smart: approval redo",p.redo() and p.terrain_families.get("grass9_center")=="dirt")
	p.set_terrain_family("grass9_center","")
	e.smart_terrain=true
	e.set_tool("paint","grass9_center")
	var c := Vector2(720,360)
	var cells: Array = []
	for u in 4:
		for v in 4: cells.append(c+AutoTile.SE*u+AutoTile.NE*v)
	ck.call("smart: paint from selected tile",e._apply_cells(cells))
	p._changed(false)
	ck.call("smart: selected tile creates managed ownership",p.cell_mat.get(c)=="grass")
	e.set_tool("paint","path_dirt_15_a")
	ck.call("smart: finite connected fill",e.flood_at(c)==16 and p.cell_mat.get(c)=="dirt")
	var snapshot := p.to_json_string()
	ck.call("smart: fill one undo",p.undo() and p.cell_mat.get(c)=="grass")
	ck.call("smart: fill exact redo",p.redo() and p.to_json_string()==snapshot)
	var eraser := AutoTile.new(p)
	eraser.blend=true
	eraser.erase(p.floor_tiles_in_cell(c)[0])
	p._changed(false)
	var erased := p.floor_tiles_in_cell(c).is_empty()
	var undone := p.undo()
	var expected: Dictionary = JSON.parse_string(snapshot)
	var actual: Dictionary = JSON.parse_string(p.to_json_string())
	var sort_items := func(a: Dictionary,b: Dictionary) -> bool:
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.id < b.id
	expected.items.sort_custom(sort_items)
	actual.items.sort_custom(sort_items)
	ck.call("smart: erase and undo restore exact tile positions and ownership",erased and undone and actual==expected)
	p.set_terrain_family("grass9_center","rock")
	p.published_rev="smart-terrain-published-fixture"
	snapshot=p.to_json_string()
	ck.call("smart: save",p.save())
	p.load_dict(JSON.parse_string(FileAccess.get_file_as_string(p.save_path)))
	ck.call("smart: exact reload preserves approval and published revision",p.to_json_string()==snapshot and p.terrain_families.get("grass9_center")=="rock" and p.published_rev=="smart-terrain-published-fixture")
	e._auto=null
	e.set_tool("paint","grass9_center")
	e._apply_cells([c])
	p._changed(false)
	ck.call("smart: reloaded approval drives auto tiler",p.cell_mat.get(c)=="rock")
	p.set_terrain_family("grass9_center","manual")
	e._auto=null
	e._apply_cells([c])
	p._changed(false)
	ck.call("smart: manual choice preserves raw tile and pins it",p.floor_tiles_in_cell(c)[0].id=="grass9_center" and p.cell_mat.get(c)=="lock")
	ck.call("smart: flood respects manual lock",e.flood_at(c)==0)
	var before := p.to_json_string()
	ck.call("smart: empty fill is bounded no-op",e.flood_at(Vector2(-720,-360))==0 and p.to_json_string()==before)
	e.review_tile_family()
	ck.call("smart: review dialog does not approve automatically",e.family_dialog.visible and p.to_json_string()==before)
	e.family_dialog.hide()
	main.queue_free()
	await root.get_tree().process_frame
	MapEditorMode.forced=original_map
