class_name AssetBrowser
extends VBoxContainer
## Map editor asset browser: TILES / OBJECTS / ENTITIES tabs, a search box and category chips sitting on top of the
## editor's real build palette. It never builds its own asset list; it only decides which of the palette's cards and
## sections are visible, so every card still places exactly what it always did.

const TABS: Array[Array] = [["tiles", "TILES"], ["objects", "OBJECTS"], ["entities", "ENTITIES"]]
const TILE_CATEGORIES: Array[String] = ["Grass", "Path to dirt", "Ground / paths", "Temple ground", "River water", "Grass banks", "Dirt banks", "Rocky banks"]
const ENTITY_CATEGORIES: Array[String] = ["Player spawn", "Enemies", "Pickups"]
const SIZES: Array[int] = [1, 3, 5]

var editor: WorldEditor
var tab := "tiles"
var query := ""
var category := ""  ## "" = every category of the tab
var search: LineEdit
var _tab_buttons: Dictionary = {}
var _chip_box: HBoxContainer
var _chip_scroll: ScrollContainer
var _shown := 0
var _chips: Dictionary = {}
var _tile_tools: VBoxContainer
var _size_buttons: Dictionary = {}
var _shape_buttons: Dictionary = {}


static func tab_of(category_name: String) -> String:
	if TILE_CATEGORIES.has(category_name):
		return "tiles"
	if ENTITY_CATEGORIES.has(category_name):
		return "entities"
	# Newly registered terrain families belong with tiles without maintaining a
	# second list of every art-kit category (including exact junction families).
	for category_entry: Array in PlacedObjects.CATEGORIES:
		if str(category_entry[0]) != category_name or category_entry[1].is_empty():
			continue
		var first_id: String = category_entry[1][0]
		if PlacedObjects.is_floor_tile(first_id):
			return "tiles"
	return "objects"


static func categories_of(tab_id: String) -> Array[String]:
	var out: Array[String] = []
	for cat: Array in PlacedObjects.CATEGORIES:
		if tab_of(str(cat[0])) == tab_id:
			out.append(str(cat[0]))
	return out


## True when an asset (by catalog id) should show for a search text. Matches the label, the id and the category.
static func matches(id: String, text: String) -> bool:
	var q := text.strip_edges().to_lower()
	if q == "":
		return true
	var def: Dictionary = PlacedObjects.def_of(id)
	var hay := "%s %s %s" % [str(def.get("label", "")), id.replace("_", " "), PlacedObjects.type_of(id)]
	for word in q.split(" ", false):
		if hay.to_lower().find(word) < 0:
			return false
	return true


func setup(ed: WorldEditor) -> void:
	editor = ed
	name = "AssetBrowser"
	add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var group := ButtonGroup.new()
	for t: Array in TABS:
		var id: String = t[0]
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30)
		ed._skin(b, "tool")
		b.pressed.connect(set_tab.bind(id))
		row.add_child(b)
		_tab_buttons[id] = b
	(_tab_buttons[tab] as Button).button_pressed = true

	search = LineEdit.new()
	search.placeholder_text = "Search assets"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(0, 30)
	search.text_changed.connect(set_query)
	add_child(search)

	_chip_scroll = ScrollContainer.new()  # one row of chips that scrolls sideways, so the panel stays short
	_chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chip_scroll.custom_minimum_size = Vector2(0, 28)
	add_child(_chip_scroll)
	_chip_box = HBoxContainer.new()
	_chip_box.add_theme_constant_override("separation", 4)
	_chip_scroll.add_child(_chip_box)

	_build_tile_tools()
	_tighten_cards()
	_rebuild_chips()
	apply()


func _small(parent: Node, text: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.tooltip_text = tip
	editor._skin(b, "tool")
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	return f


func _build_tile_tools() -> void:
	_tile_tools = VBoxContainer.new()
	_tile_tools.add_theme_constant_override("separation", 4)
	add_child(_tile_tools)
	var r1 := _flow()
	_tile_tools.add_child(r1)
	for n: int in SIZES:
		_size_buttons[n] = _small(r1, "%dx%d" % [n, n], set_brush_size.bind(n), "Paint a %d x %d block of floor cells per click" % [n, n])
	for sh: String in WorldEditor.SHAPES:
		_shape_buttons[sh] = _small(r1, "DRAG" if sh == "brush" else sh.to_upper(), editor.set_shape.bind(sh), "Brush shape: " + sh)


func set_tab(id: String) -> void:
	if not _tab_buttons.has(id):
		return
	tab = id
	category = ""
	(_tab_buttons[id] as Button).set_pressed_no_signal(true)
	_rebuild_chips()
	apply()


func set_query(text: String) -> void:
	query = text
	if search != null and search.text != text:
		search.text = text
	apply()


func set_category(cat: String) -> void:
	category = cat
	for k: String in _chips:
		(_chips[k] as Button).set_pressed_no_signal(k == cat)
	apply()


func set_brush_size(n: int) -> void:
	editor.brush = n
	editor._refresh()


func _rebuild_chips() -> void:
	for c in _chip_box.get_children():
		c.queue_free()
	_chips.clear()
	var cats := categories_of(tab)
	if cats.size() > 1:
		_chips[""] = _small(_chip_box, "ALL", set_category.bind(""))
		for cat in cats:
			_chips[cat] = _small(_chip_box, ("Walls" if cat == "Walls & blocks" else cat).to_upper(), set_category.bind(cat))
		(_chips[""] as Button).set_pressed_no_signal(true)
	_chip_scroll.visible = cats.size() > 1
	_tile_tools.visible = tab == "tiles"


## Decide which sections and cards show. A section shows when its editor filter is ticked, it belongs to the open tab and
## category, and at least one of its cards matches the search.
func apply() -> void:
	if editor == null:
		return
	var shown := 0
	for cat: Array in PlacedObjects.CATEGORIES:
		var name := str(cat[0])
		var section := editor._category_sections.get(name) as Control
		if section == null:
			continue
		var in_tab := tab_of(name) == tab and (category == "" or category == name)
		var filter_on := true
		if editor._filter_buttons.has(name):
			filter_on = (editor._filter_buttons[name] as CheckBox).button_pressed
		var any := false
		for id: String in cat[1]:
			var b := editor._palette_buttons.get(id) as Button
			if b == null:
				continue
			var ok := matches(id, query)
			b.visible = ok
			if ok:
				any = true
				if in_tab and filter_on:
					shown += 1
		section.visible = in_tab and filter_on and any
	_shown = shown
	if search != null:
		search.placeholder_text = "Search %d asset%s" % [shown, "" if shown == 1 else "s"]
	sync()


## Highlights the active brush size and shape.
func sync() -> void:
	if editor == null:
		return
	for n: int in _size_buttons:
		(_size_buttons[n] as Button).set_pressed_no_signal(editor.brush == n)
	for sh: String in _shape_buttons:
		(_shape_buttons[sh] as Button).set_pressed_no_signal(editor.shape == sh)


## Three cards per row and shorter cards, so more of the palette fits above the pinned SAVE dock.
func _tighten_cards() -> void:
	for cat: Array in PlacedObjects.CATEGORIES:
		var section := editor._category_sections.get(str(cat[0])) as Control
		if section == null:
			continue
		for c in section.get_children():
			if c is GridContainer:
				(c as GridContainer).columns = 3
		for id: String in cat[1]:
			var b := editor._palette_buttons.get(id) as Button
			if b != null:
				b.custom_minimum_size.y = minf(b.custom_minimum_size.y, 84.0)
				b.add_theme_constant_override("icon_max_width", 52)
				b.add_theme_font_size_override("font_size", 10)
