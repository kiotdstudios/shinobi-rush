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
const LEGEND := "Keyboard: WASD move | Shift sprint | Space dodge | F jump | Esc pause\nGamepad: left stick/D-pad move | R1 sprint | Options pause\nReserved (no behavior yet): arrows aim, J light, K heavy, Q substitution, E heal\nLab (art): Tab panel | [ ] set | , . anim | ; ' dir | V follow/spin | - = speed | P pause | O step | C compare | Z/wheel zoom | 1-6 overlays\nF1: toggle technical diagnostics (camera/sprite/FPS/texture mem)"

const DIAG_ACTION := "dbg_toggle_diagnostics"
const DIAG_KEY := KEY_F1
const PANEL_BG := Color(0, 0, 0, 0.45)

var _player_info: Label
var _diag_panel: PanelContainer
var _diag_camera_sprite: Label
var _diag_perf: Label
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
	var essential := _panel(stack)
	var essential_box := VBoxContainer.new()
	essential.add_child(essential_box)
	var title := _make_label(essential_box, 20)
	title.text = "SHINOBI RUSH\nBOOTSTRAP BUILD - PLACEHOLDER ART"
	_player_info = _make_label(essential_box, 14)

	# ---- Diagnostics panel: collapsed by default; F1 toggles. ----
	_diag_panel = _panel(stack)
	_diag_panel.visible = _diagnostics_on
	var diag_box := VBoxContainer.new()
	diag_box.add_theme_constant_override("separation", 4)
	_diag_panel.add_child(diag_box)
	var diag_header := _make_label(diag_box, 13)
	diag_header.text = "TECHNICAL DIAGNOSTICS (F1 to hide)"
	diag_header.add_theme_color_override("font_color", Color("#ffd27a"))
	_diag_camera_sprite = _make_label(diag_box, 13)
	_diag_perf = _make_label(diag_box, 13)

	# ---- Controls legend: bottom-left, anchored (stays bottom-left at any resolution). ----
	var legend_panel := PanelContainer.new()
	legend_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend_panel.position += Vector2(6, -6)
	legend_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(legend_panel)
	add_child(legend_panel)
	var legend := _make_label(legend_panel, 12)
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
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", style)


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
		_diagnostics_on = not _diagnostics_on
		_diag_panel.visible = _diagnostics_on


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
	_player_info.text = "State: %s\nSpeed: %d px/s\nPos: (%d, %d)\nDirection: %s" % [
		_player.get_state_name(), int(_player.velocity.length()),
		int(_player.global_position.x), int(_player.global_position.y),
		SpriteSet.dir_name(_player.facing8)]
	if _diag_perf != null and _diag_panel.visible:
		_diag_perf.text = "FPS: %d\nTexture mem: %.2f MB" % [
			int(Engine.get_frames_per_second()),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0]
