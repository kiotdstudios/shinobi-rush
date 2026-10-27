extends RefCounted
## Map editor asset browser: tabs, search, category chips, brush row and the picked-asset card, all over the real palette.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	# pure helpers
	ck.call("browser: every catalog category lands in exactly one tab", _all_categories_covered())
	ck.call("browser: grass, water and banks are tiles", AssetBrowser.tab_of("Grass") == "tiles" and AssetBrowser.tab_of("River water") == "tiles" and AssetBrowser.tab_of("Rocky banks") == "tiles")
	ck.call("browser: trees and fences are objects", AssetBrowser.tab_of("Trees") == "objects" and AssetBrowser.tab_of("Fences") == "objects")
	ck.call("browser: spawn, enemies and pickups are entities", AssetBrowser.tab_of("Player spawn") == "entities" and AssetBrowser.tab_of("Enemies") == "entities" and AssetBrowser.tab_of("Pickups") == "entities")
	ck.call("search: empty text matches everything", AssetBrowser.matches("tree_1", "") and AssetBrowser.matches("tree_1", "   "))
	ck.call("search: matches the label, any case", AssetBrowser.matches("tree_1", "TREE") and AssetBrowser.matches("health_gourd", "gourd"))
	ck.call("search: matches the category name", AssetBrowser.matches("tree_1", "trees"))
	ck.call("search: every word must match", AssetBrowser.matches("health_gourd", "health gourd") and not AssetBrowser.matches("health_gourd", "health zzz"))
	ck.call("search: nonsense matches nothing", not AssetBrowser.matches("tree_1", "qqzzxx"))

	AncientShrineSection.enabled = false
	MapEditorMode.forced = true
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 14:
		await tree.process_frame
	var arena := main.get_node("TrainingArena") as TrainingArena
	arena.placed.save_path = "user://test_asset_browser_layout.json"
	arena.placed.autosave = false
	var ed := arena.editor
	ed.void_check = false
	var br := ed.browser

	ck.call("browser: the map editor builds the asset browser inside the build page", br != null and ed.build_page.is_ancestor_of(br))
	ck.call("browser: it opens on the TILES tab", br.tab == "tiles")
	ck.call("tabs: tiles shows grass but not trees", _section_visible(ed, "Grass") and not _section_visible(ed, "Trees"))
	br.set_tab("objects")
	await tree.process_frame
	ck.call("tabs: objects shows trees but not grass", _section_visible(ed, "Trees") and not _section_visible(ed, "Grass"))
	ck.call("tabs: the brush row belongs to tiles only", not br._tile_tools.visible)
	br.set_tab("entities")
	ck.call("tabs: entities shows spawn, enemies and pickups only", _section_visible(ed, "Player spawn") and _section_visible(ed, "Enemies") and _section_visible(ed, "Pickups") and not _section_visible(ed, "Trees"))
	br.set_tab("tiles")
	ck.call("tabs: back to tiles shows the brush row", br._tile_tools.visible)

	br.set_tab("objects")
	br.set_category("Trees")
	ck.call("chips: choosing a category shows only that section", _section_visible(ed, "Trees") and not _section_visible(ed, "Fences"))
	br.set_category("")
	ck.call("chips: ALL shows every section of the tab again", _section_visible(ed, "Trees") and _section_visible(ed, "Fences"))

	br.set_query("fence")
	ck.call("search: typing narrows the cards to fences", _section_visible(ed, "Fences") and not _section_visible(ed, "Trees"))
	ck.call("search: matching cards stay, others hide", ed._palette_buttons["fence_se_1"].visible and not ed._palette_buttons["tree_1"].visible)
	br.set_query("qqzzxx")
	ck.call("search: no match hides every section and says 0", not _section_visible(ed, "Fences") and br._shown == 0, str(br._shown))
	br.set_query("")
	ck.call("search: clearing the box brings everything back", _section_visible(ed, "Trees") and ed._palette_buttons["tree_1"].visible)

	# the old filter still works underneath
	ed.set_type_filter("Trees", false)
	ck.call("filter: an unticked category stays hidden under the browser", not _section_visible(ed, "Trees"))
	ed.set_type_filter("Trees", true)
	ck.call("filter: ticking it again shows it", _section_visible(ed, "Trees"))

	# picking an asset
	br.set_tab("tiles")
	var tile_id := "ground9_center"
	ck.call("cards: a tile card is in the palette", ed._palette_buttons.has(tile_id))
	(ed._palette_buttons[tile_id] as Button).pressed.emit()
	await tree.process_frame
	ck.call("cards: clicking a card places that asset", ed.tool in ["place", "paint"] and ed.place_id == tile_id)

	# brush row
	(br._size_buttons[3] as Button).pressed.emit()
	ck.call("brush: the 3x3 button sets the real brush", ed.brush == 3 and (br._size_buttons[3] as Button).button_pressed and not (br._size_buttons[1] as Button).button_pressed)
	(br._shape_buttons["rect"] as Button).pressed.emit()
	ck.call("brush: the RECT button sets the real shape", ed.shape == "rect" and (br._shape_buttons["rect"] as Button).button_pressed)
	ed.brush = 1
	ed.set_shape("brush")
	ck.call("brush: the browser highlight follows the editor", (br._size_buttons[1] as Button).button_pressed and (br._shape_buttons["brush"] as Button).button_pressed)
	ck.call("cards: three per row", (ed._category_sections["Grass"].get_child(1) as GridContainer).columns == 3)
	ck.call("search box shows the count", br.search.placeholder_text.begins_with("Search ") and "asset" in br.search.placeholder_text, br.search.placeholder_text)

	MapEditorMode.forced = false
	main.queue_free()
	await tree.process_frame
	WorldEditor.use_palette(false)


func _section_visible(ed: WorldEditor, cat: String) -> bool:
	return (ed._category_sections[cat] as Control).visible


func _all_categories_covered() -> bool:
	var seen := 0
	for t: Array in AssetBrowser.TABS:
		seen += AssetBrowser.categories_of(t[0]).size()
	return seen == PlacedObjects.CATEGORIES.size()
