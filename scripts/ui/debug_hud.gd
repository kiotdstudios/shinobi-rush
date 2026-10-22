extends CanvasLayer
## Debug HUD (PLACEHOLDER). Built from real Control containers (not hand-placed Labels) so it
## scales correctly across resolutions and never overlaps itself:
##   - ESSENTIAL block (top-left, always visible): title/build + player state/speed/pos/direction.
##   - DIAGNOSTICS panel (top-left, below essential; collapsed by default, F1 toggles):
##     camera zoom + sprite info, then FPS + texture memory. AnimationLab feeds its sprite-status
##     text in here via set_sprite_status() instead of drawing its own overlapping labels (that
##     was the actual overlap bug: two unrelated CanvasLayers each hand-placing absolute-pixel
##     labels that nobody kept in sync as either one grew).
##   - CONTROLS legend (bottom-left, anchored so it stays bottom-left at any resolution).
##   - PAUSED banner (screen-centre via anchor, not a hardcoded position).
## Also owns the tiny pause toggle (runs while paused).

const REFRESH := 0.1
const LEGEND := "Keyboard: WASD move | Shift sprint | Space dodge | F jump | J light attack | L lock on/off | Esc pause\nGamepad: left stick/D-pad move | R1 sprint | R3 lock on/off | Options pause\nReserved (no behavior yet): arrows aim, K heavy, Q substitution, E heal\nLab (art): Tab panel | [ ] set | , . anim | ; ' dir | V follow/spin | - = speed | P pause | O step | C compare | Z/wheel zoom | 1-6 overlays\nF1: toggle technical diagnostics (camera/sprite/FPS/texture mem)\nF2 / top-right button: Bandit vision (debug, default OFF) shows what the Bandit's AI can see | ?vision=1 starts it on"

const DIAG_ACTION := "dbg_toggle_diagnostics"
const DIAG_KEY := KEY_F1
const PANEL_BG := Color(0.03, 0.03, 0.05, 0.8)
const ACCENT := Color("#FF6B00")
const EDGE := Color("#2b2b35")
const MUTED := Color(1, 1, 1, 0.55)
## Which boxes the player hid (kept for the whole session, survives arena restarts).
static var hidden: Dictionary = {}

var _boxes: Dictionary = {}  ## id -> {"panel": Control, "chip": Button}

var _player_info: Label
var _diag_panel: PanelContainer
var _diag_camera_sprite: Label
var _diag_perf: Label
var _diag_combat: Label
var _paused: Label
var _timer: float = 0.0
var _player: PlayerController
var _diagnostics_on: bool = false


func _ready() -> void:
	_ensure_diag_action()

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_theme_constant_override("margin_left", 6)
	root.add_theme_constant_override("margin_top", 4)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stack)

	# ---- Essential block: always visible, gameplay-relevant only. ----
	var essential_box := _collapsible(stack, "player", "PLAYER")
	var title := _make_label(essential_box, 20)
	title.text = "SHINOBI RUSH\nBOOTSTRAP BUILD - PLACEHOLDER ART"
	_player_info = _make_label(essential_box, 14)

	# ---- Diagnostics panel: collapsed by default; F1 toggles. ----
	_diag_panel = _panel(stack)
	_diag_panel.visible = _diagnostics_on
	var diag_box := VBoxContainer.new()
	diag_box.add_theme_constant_override("separation", 4)
	_diag_panel.add_child(diag_box)
	_header(diag_box, "DIAGNOSTICS  (F1)", func(): _toggle_diagnostics())
	_diag_camera_sprite = _make_label(diag_box, 13)
	_diag_perf = _make_label(diag_box, 13)
	_diag_combat = _make_label(diag_box, 13)

	# ---- Controls legend: bottom-left, anchored (stays bottom-left at any resolution). ----
	var legend_holder := VBoxContainer.new()
	legend_holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend_holder.position += Vector2(6, -6)
	legend_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend_holder)
	var legend_box := _collapsible(legend_holder, "controls", "CONTROLS")
	var legend := _make_label(legend_box, 12)
	legend.text = LEGEND

	# ---- Paused banner: screen-centre via anchor, not a hardcoded resolution-specific position. ----
	_paused = Label.new()
	_paused.set_anchors_preset(Control.PRESET_CENTER)
	_paused.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_paused.grow_vertical = Control.GROW_DIRECTION_BOTH
	_paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paused.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_paused.add_theme_font_size_override("font_size", 36)
	_paused.add_theme_color_override("font_outline_color", Color.BLACK)
	_paused.add_theme_constant_override("outline_size", 4)
	_paused.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paused.text = "PAUSED"
	_paused.visible = false
	add_child(_paused)


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(p)
	parent.add_child(p)
	return p


func _style_panel(p: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.border_blend = false
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", style)
	# the accent stripe is the left border colour; StyleBoxFlat has one border colour, so tint the whole frame subtly
	style.border_color = Color(ACCENT, 0.8)


static func _small_button(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", ACCENT)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 1, 1, 0.06)
	n.border_color = EDGE
	n.set_border_width_all(1)
	n.set_corner_radius_all(5)
	n.content_margin_left = 8
	n.content_margin_right = 8
	n.content_margin_top = 2
	n.content_margin_bottom = 2
	var h := n.duplicate() as StyleBoxFlat
	h.border_color = ACCENT
	h.bg_color = Color(ACCENT, 0.15)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Title row with a HIDE button on the right.
func _header(parent: Node, text: String, on_hide: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", ACCENT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var b := Button.new()
	b.text = "HIDE"
	_small_button(b)
	b.pressed.connect(on_hide)
	row.add_child(b)
	return row


## A HUD box the player can hide: styled panel with a title row + HIDE; hidden, it collapses to a small SHOW chip.
## Returns the VBox to put the content in.
func _collapsible(parent: Node, id: String, title: String) -> VBoxContainer:
	var panel := _panel(parent)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	var chip := Button.new()
	chip.text = "SHOW  " + title
	_small_button(chip)
	parent.add_child(chip)
	_boxes[id] = {"panel": panel, "chip": chip}
	_header(body, title, func(): set_box_hidden(id, true))
	chip.pressed.connect(func(): set_box_hidden(id, false))
	set_box_hidden(id, bool(hidden.get(id, false)))
	return body


func set_box_hidden(id: String, v: bool) -> void:
	hidden[id] = v
	if _boxes.has(id):
		(_boxes[id].panel as Control).visible = not v
		(_boxes[id].chip as Control).visible = v


func _toggle_diagnostics() -> void:
	_diagnostics_on = not _diagnostics_on
	_diag_panel.visible = _diagnostics_on


func _make_label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Registered at runtime (like AnimationLab's camera-preset key) so project.godot stays untouched.
static func _ensure_diag_action() -> void:
	if InputMap.has_action(DIAG_ACTION):
		return
	InputMap.add_action(DIAG_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = DIAG_KEY
	InputMap.action_add_event(DIAG_ACTION, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_paused.visible = get_tree().paused
	elif event.is_action_pressed(DIAG_ACTION):
		_toggle_diagnostics()


## Called by AnimationLab: camera zoom + sprite-set status/metrics, all one "Camera & sprite"
## diagnostics section. Shown only while the panel is open; FPS/texture-mem (the other distinct
## section) is computed locally in _process() below, not by AnimationLab.
func set_sprite_status(zoom_text: String, status_text: String, metrics_text: String, color: Color) -> void:
	if _diag_camera_sprite == null:
		return
	var lines: Array[String] = [zoom_text]
	if status_text != "":
		lines.append(status_text)
	if metrics_text != "":
		lines.append(metrics_text)
	_diag_camera_sprite.text = "\n".join(lines)
	_diag_camera_sprite.add_theme_color_override("font_color", color)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return
	# Live camera zoom (exact value, 4 decimals) so a zoom worth locking can be read off the screen.
	var cam := get_viewport().get_camera_2d()
	var zoom_text := "n/a" if cam == null else "%.4f (%s)" % [cam.zoom.x, CameraPreset.active_id()]
	_player_info.text = "State: %s\nSpeed: %d px/s\nPos: (%d, %d)\nZoom: %s\nDirection: %s" % [
		_player.get_state_name(), int(_player.velocity.length()),
		int(_player.global_position.x), int(_player.global_position.y),
		zoom_text, SpriteSet.dir_name(_player.facing8)]
	if _diag_combat != null and _diag_panel.visible:
		var d := _player.debug_snapshot()
		var c: Dictionary = d.cancel
		_diag_combat.text = "Combat: %s/%s combo %d\nBuf atk %.2f dodge %.2f jump %.2f\nCancel: combo %s dodge %s dash %s air %s\nHitstop %.3f" % [
			d.state, d.phase, d.combo, d.attack_buffer, d.dodge_buffer, d.jump_buffer,
			c.combo, c.dodge_cancel, c.dash_attack, c.air_attack, d.hitstop]
	if _diag_perf != null and _diag_panel.visible:
		_diag_perf.text = "FPS: %d\nTexture mem: %.2f MB" % [
			int(Engine.get_frames_per_second()),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0]
