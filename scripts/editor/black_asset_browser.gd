class_name BlackAssetBrowser
extends VBoxContainer
## Tabbed asset browser for the black map editor. It adopts the WorldEditor's own palette buttons
## (thumbnails, ButtonGroup, pressed-state refresh) and pro-tools block, and drives everything through
## the editor's existing methods: the editor stays the single owner of tool / place_id / brush / shape.

const TABS: Array[String] = ["Tiles", "Objects", "Entities", "Rules"]
const TOOLS: Array[String] = ["select", "box", "erase", "paint", "pan"]
const TOOL_LABELS := {"select": "SELECT", "box": "BOX", "erase": "ERASE", "paint": "PAINT", "pan": "PAN"}
const PAINT_KINDS: Array[String] = ["ground", "grass"]
const ENTITY_KINDS: Array[String] = ["spawn", "bandit", "pickup"]
const CARD_HEIGHT := 96.0
## Interior temple-floor fills that read as one surface, so the paint tool may scatter between them.
const RANDOM_VARIATION_IDS: Array[String] = ["temple_floor_center", "temple_floor_center_b", "temple_floor_cracked_a", "temple_floor_cracked_b", "temple_floor_moss_a"]
const ROTATION_INFIXES := [["_se_", "_sw_"], ["_sw_", "_se_"]]
const ROTATION_SUFFIXES := [["_se", "_sw"], ["_sw", "_se"], ["_u", "_v"], ["_v", "_u"]]

var editor: WorldEditor
var active_tab := "Tiles"
var search := ""
var category := ""  ## "" = every category in the active tab
var cards: Dictionary = {}  ## id -> the editor's own palette Button
var tab_buttons: Dictionary = {}
var tool_buttons: Dictionary = {}
var shape_buttons: Dictionary = {}
var brush_button: Button
var rotate_button: Button
var random_check: CheckBox
var search_edit: LineEdit
var category_option: OptionButton
var palette_scroll: ScrollContainer
var grid: GridContainer
var empty_label: Label
var rules_page: VBoxContainer
var legacy_button: Button
var _original_callbacks: Dictionary = {}  ## id -> Array[Callable] detached from the card (map mode only)


func setup(e: WorldEditor) -> void:
	editor = e
	name = "BlackAssetBrowser"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build_toolbar()
	_build_tabs()
	_build_filters()
	_build_palette()
	_build_variant_row()
	_build_rules()
	_rebuild_categories()
	_apply_filters()
	update_state()


static func category_of(id: String) -> String:
	for cat: Array in PlacedObjects.CATEGORIES:
		if id in cat[1]:
			return str(cat[0])
	return ""


static func tab_of(id: String) -> String:
	var def := PlacedObjects.def_of(id)
	var kind := str(def.get("kind", ""))
	if kind in ENTITY_KINDS:
		return "Entities"
	if kind == "ground" or kind == "water_fx" or (kind == "grass" and not bool(def.get("tall", false))):
		return "Tiles"
	return "Objects"


## The facing partner of an object id (`fence_se_1` <-> `fence_sw_1`, `earth_stairs_se` <-> `earth_stairs_sw`, `bridge_long_rope_u` <-> `_v`),
## only when that partner is a real palette entry. Tiles never rotate: their edges are auto-tile roles, not facings.
static func rotate_partner(id: String) -> String:
	if id == "" or category_of(id) == "" or tab_of(id) != "Objects":
		return ""
	var cand := ""
	for pair: Array in ROTATION_INFIXES:
		if str(pair[0]) in id:
			cand = id.replace(str(pair[0]), str(pair[1]))
			break
	if cand == "":
		for pair: Array in ROTATION_SUFFIXES:
			var from := str(pair[0])
			if id.ends_with(from):
				cand = id.left(id.length() - from.length()) + str(pair[1])
				break
	return cand if cand != "" and category_of(cand) != "" else ""


static func supports_random(id: String) -> bool:
	return id in RANDOM_VARIATION_IDS and category_of(id) != ""


static func matches(id: String, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q == "":
		return true
	var hay := "%s %s %s" % [id, str(PlacedObjects.def_of(id).get("label", "")), category_of(id)]
	return q in hay.to_lower()


func set_tab(tab_name: String) -> void:
	if tab_name not in TABS:
		return
	active_tab = tab_name
	_rebuild_categories()
	_apply_filters()
	update_state()


func set_search(text: String) -> void:
	search = text
	if search_edit != null and search_edit.text != text:
		search_edit.text = text
	_apply_filters()


func set_category(cat_name: String) -> void:
	category = cat_name
	if category_option != null:
		for i in category_option.item_count:
			if str(category_option.get_item_metadata(i)) == cat_name:
				category_option.select(i)
	_apply_filters()


func visible_ids() -> Array[String]:
	var out: Array[String] = []
	if active_tab == "Rules":
		return out
	for id: String in cards:
		if (cards[id] as Button).visible:
			out.append(id)
	return out


func rotate() -> void:
	var partner := rotate_partner(editor.place_id)
	if partner != "":
		editor.set_tool("place", partner)
	update_state()


func update_state() -> void:
	if editor == null:
		return
	for t: String in tab_buttons:
		(tab_buttons[t] as Button).set_pressed_no_signal(t == active_tab)
	for t: String in tool_buttons:
		(tool_buttons[t] as Button).set_pressed_no_signal(editor.tool == t)
	for sh: String in shape_buttons:
		(shape_buttons[sh] as Button).set_pressed_no_signal(editor.shape == sh)
	brush_button.text = "BRUSH  %d x %d" % [editor.brush, editor.brush]
	var picking := editor.tool in ["place", "paint"]
	rotate_button.visible = picking and rotate_partner(editor.place_id) != ""
	if rotate_button.visible:
		rotate_button.tooltip_text = "Switch to %s" % rotate_partner(editor.place_id)
	random_check.visible = editor.tool == "paint" and supports_random(editor.place_id)
	if random_check.visible:
		random_check.set_pressed_no_signal(editor.random_variation)
	palette_scroll.visible = active_tab != "Rules"
	rules_page.visible = active_tab == "Rules"
	search_edit.get_parent().visible = active_tab != "Rules"
	if legacy_button != null:
		legacy_button.set_pressed_no_signal(legacy_open())


func _build_toolbar() -> void:
	var row := _compact_grid(3)
	for t: String in TOOLS:
		tool_buttons[t] = _compact(editor._mini(row, TOOL_LABELS[t], _on_tool.bind(t)))
	var brow := _compact_grid(4)
	brush_button = _compact(editor._mini(brow, "BRUSH", _on_brush, false))
	brush_button.tooltip_text = "Cycle the paint brush size"
	for sh: String in WorldEditor.SHAPES:
		shape_buttons[sh] = _compact(editor._mini(brow, "DRAG" if sh == "brush" else sh.to_upper(), _on_shape.bind(sh)))


func _compact_grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	add_child(g)
	return g


## editor._mini's 64px minimum crowds a ~300px panel; the grid shares the width instead.
func _compact(b: Button) -> Button:
	b.custom_minimum_size = Vector2(0, 28)
	return b


func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var group := ButtonGroup.new()
	for t: String in TABS:
		var b := _compact(editor._mini(row, t.to_upper(), set_tab.bind(t)))
		b.button_group = group
		tab_buttons[t] = b


func _build_filters() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Search id, name, category"
	search_edit.clear_button_enabled = true
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.add_theme_font_size_override("font_size", 12)
	search_edit.text_changed.connect(set_search)
	row.add_child(search_edit)
	category_option = OptionButton.new()
	category_option.focus_mode = Control.FOCUS_NONE
	category_option.fit_to_longest_item = false
	category_option.custom_minimum_size = Vector2(130, 0)
	category_option.clip_text = true
	category_option.add_theme_font_size_override("font_size", 12)
	category_option.item_selected.connect(func(i: int): set_category(str(category_option.get_item_metadata(i))))
	row.add_child(category_option)


func _build_palette() -> void:
	palette_scroll = ScrollContainer.new()
	palette_scroll.name = "AssetScroll"
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_scroll.custom_minimum_size = Vector2(0, 240)
	add_child(palette_scroll)
	editor._fat_scrollbar(palette_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 26)
	palette_scroll.add_child(gutter)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(col)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	empty_label = Label.new()
	empty_label.text = "No matching assets"
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.add_theme_color_override("font_color", WorldEditor.MUTED)
	col.add_child(empty_label)
	for cat: Array in PlacedObjects.CATEGORIES:
		for id: String in cat[1]:
			if editor._palette_buttons.has(id):
				_adopt_card(id, editor._palette_buttons[id])
	editor.palette_scroll = palette_scroll  # the editor's card / scroll probes now measure the scroll that holds the cards


func _adopt_card(id: String, b: Button) -> void:
	if b.get_parent() != null:
		b.get_parent().remove_child(b)
	grid.add_child(b)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	b.tooltip_text = "%s\n%s  ·  %s" % [str(PlacedObjects.def_of(id).get("label", id)), id, category_of(id)]
	cards[id] = b
	if editor.map_mode:
		_rewire(id, b)


## Map mode: a tile card picks the PAINT tool and an object card PLACE, instead of the legacy
## "paint only if already painting" rule. The editor's own lambda is detached (kept for reference), never edited.
func _rewire(id: String, b: Button) -> void:
	var detached: Array[Callable] = []
	for conn: Dictionary in b.pressed.get_connections():
		var c: Callable = conn.callable
		if c.get_object() == editor and b.pressed.is_connected(c):
			b.pressed.disconnect(c)
			detached.append(c)
	_original_callbacks[id] = detached
	b.pressed.connect(_on_card.bind(id))


func _build_variant_row() -> void:
	var row := editor._flow(self)
	rotate_button = _compact(editor._mini(row, "ROTATE", rotate, false))
	random_check = CheckBox.new()
	random_check.text = "RANDOM VARIATION"
	random_check.tooltip_text = "Scatter the temple floor fills while painting"
	random_check.focus_mode = Control.FOCUS_NONE
	random_check.add_theme_font_size_override("font_size", 11)
	random_check.toggled.connect(_on_random)
	row.add_child(random_check)


func _build_rules() -> void:
	rules_page = VBoxContainer.new()
	rules_page.name = "RulesPage"
	rules_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_page.add_theme_constant_override("separation", 6)
	add_child(rules_page)
	for c: Control in [editor.tools_toggle, editor.tools_body]:
		if c == null:
			continue
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
		rules_page.add_child(c)
	if editor.tools_body != null:
		editor.tools_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		editor.set_pro_tools_open(true)
	legacy_button = editor._mini(rules_page, "LEGACY TOOLS", func(): set_legacy_open(not legacy_open()))
	legacy_button.tooltip_text = "Show original controls (including publish and layout download) in the legacy panel"
	legacy_button.visible = editor.build_page != null


## The old build page stays alive (the editor keeps reading its panel) and is only shown on request.
func set_legacy_open(on: bool) -> void:
	if editor.black_shell != null:
		editor.black_shell.set_legacy_open(on)
	else:
		editor.build_page.visible = on
	update_state()


func legacy_open() -> bool:
	if editor.black_shell != null:
		return editor.black_shell.legacy_open
	return editor.build_page != null and editor.build_page.visible


func _rebuild_categories() -> void:
	category_option.clear()
	category_option.add_item("All")
	category_option.set_item_metadata(0, "")
	var keep := false
	for cat: Array in PlacedObjects.CATEGORIES:
		var cat_name := str(cat[0])
		var in_tab := false
		for id: String in cat[1]:
			if cards.has(id) and tab_of(id) == active_tab:
				in_tab = true
				break
		if not in_tab:
			continue
		category_option.add_item(cat_name)
		category_option.set_item_metadata(category_option.item_count - 1, cat_name)
		if cat_name == category:
			keep = true
			category_option.select(category_option.item_count - 1)
	if not keep:
		category = ""
		category_option.select(0)


func _apply_filters() -> void:
	var shown := 0
	for id: String in cards:
		var legacy_filter := editor._filter_buttons.get(category_of(id)) as CheckBox
		var on := tab_of(id) == active_tab and (category == "" or category_of(id) == category) and matches(id, search) and (legacy_filter == null or legacy_filter.button_pressed)
		(cards[id] as Button).visible = on
		if on:
			shown += 1
	empty_label.visible = shown == 0 and active_tab != "Rules"


func _on_card(id: String) -> void:
	var kind := str(PlacedObjects.def_of(id).get("kind", ""))
	editor.set_tool("paint" if tab_of(id) == "Tiles" and kind in PAINT_KINDS else "place", id)
	update_state()


func _on_tool(t: String) -> void:
	editor.set_tool(t)
	update_state()


func _on_brush() -> void:
	editor.cycle_brush()
	update_state()


func _on_shape(sh: String) -> void:
	editor.set_shape(sh)
	update_state()


func _on_random(on: bool) -> void:
	editor.random_variation = on
	update_state()
