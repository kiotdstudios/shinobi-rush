class_name SettingsPanel
extends Control
## One "Settings" dock tab on the bottom edge (where the Bandit / Sense vision tabs used to be). Click it to open a small panel of
## click-to-toggle switches for the debug visions (Bandit vision, Sense vision). Owner 2026-10-22: "all these f# buttons are
## confusing me, make one settings tab at the bottom for all visions, remove the hot keys, I wanna be able to just click
## them on and off". There are no hotkeys for any of these switches any more.
##
## Added by AnimationLab._build_ui into its CanvasLayer. The panel is closed by default; the toggle buttons exist (and keep
## their state) while it is closed, so a feature that is ON stays ON when the panel is hidden.
const TAB_POS_X := 942.0  ## the slot the Bandit vision tab had on the bottom row (Lab is at 1120)
const TAB_W := 170.0
const MARGIN := 8.0
const COLOR := Color("#9AA0A6")

var tab: Button
var panel: PanelContainer
var rows: VBoxContainer
var open := false
var bandit_button: Button = null
var sense_button: Button = null
static var _instance: SettingsPanel = null


func _enter_tree() -> void:
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func build(_layer: Node) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab = Button.new()
	tab.name = "SettingsTab"
	tab.text = "Settings"
	tab.toggle_mode = true
	tab.focus_mode = Control.FOCUS_NONE
	tab.position = Vector2(TAB_POS_X, DockTab.REST_Y)
	tab.custom_minimum_size = Vector2(TAB_W, DockTab.TAB_H)
	tab.add_theme_font_size_override("font_size", 12)
	tab.tooltip_text = "Click to open: switch Bandit vision and Sense vision on or off."
	DockTab.style(tab, COLOR)
	tab.toggled.connect(set_open)
	add_child(tab)
	panel = PanelContainer.new()
	panel.name = "SettingsList"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -(1280.0 - (TAB_POS_X + TAB_W))  ## right edge lines up with the tab (base canvas 1280x720)
	panel.offset_bottom = -(DockTab.TAB_H + MARGIN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.04, 0.92)
	sb.border_color = COLOR
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	panel.add_child(rows)
	var head := HBoxContainer.new()
	rows.add_child(head)
	var title := Label.new()
	title.text = "SETTINGS  (click to switch on / off)"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.name = "SettingsClose"
	close.text = "HIDE"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(func() -> void: set_open(false))
	head.add_child(close)


## A toggle_mode button used as a settings row: flat grey when off, filled with its colour when on.
static func style_toggle(b: Button, color: Color) -> void:
	b.toggle_mode = true
	var off := _box(color.darkened(0.7), color.darkened(0.2))
	var on := _box(color, color.lightened(0.35))
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", _box(color.darkened(0.55), color))
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", _box(color.lightened(0.08), color.lightened(0.35)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("#0a0a0a"))
	b.add_theme_color_override("font_hover_pressed_color", Color("#0a0a0a"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _box(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


func add_row(b: Button) -> void:
	if b != null and b.get_parent() == null:
		rows.add_child(b)
	if b != null and b.name == "BanditVisionButton":
		bandit_button = b
	elif b != null and b.name == "SenseVisionButton":
		sense_button = b


## Centres (screen px) of the tab and the two vision buttons, so a browser probe can click them for real. Additive.
static func telemetry() -> Dictionary:
	var d := {"settings_open": false, "settings_tab_x": 0.0, "settings_tab_y": 0.0, "settings_bandit_x": 0.0, "settings_bandit_y": 0.0, "settings_sense_x": 0.0, "settings_sense_y": 0.0}
	var s := _instance
	if s == null or not is_instance_valid(s) or s.tab == null:
		return d
	d["settings_open"] = s.open
	var t := s.tab.get_global_rect().get_center()
	d["settings_tab_x"] = t.x
	d["settings_tab_y"] = t.y
	if s.bandit_button != null:
		var b := s.bandit_button.get_global_rect().get_center()
		d["settings_bandit_x"] = b.x
		d["settings_bandit_y"] = b.y
	if s.sense_button != null:
		var v := s.sense_button.get_global_rect().get_center()
		d["settings_sense_x"] = v.x
		d["settings_sense_y"] = v.y
	return d


func set_open(v: bool) -> void:
	open = v
	if panel != null:
		panel.visible = v
	if tab != null:
		if tab.button_pressed != v:
			tab.set_pressed_no_signal(v)
		DockTab.set_active(tab, v)
