extends CanvasLayer
## Minimal debug HUD (PLACEHOLDER). Labels are built in code; text refreshes at ~10 Hz.
## No fake gameplay stats. Also owns the tiny pause toggle (runs while paused).

const REFRESH := 0.1
const LEGEND := "Keyboard: WASD move | Shift sprint | Space dodge | F jump | Esc pause\nGamepad: left stick/D-pad move | R1 sprint | Options pause\nReserved (no behavior yet): arrows aim, J light, K heavy, Q substitution, E heal\nLab (art): Tab panel | [ ] set | , . anim | ; ' dir | V follow/spin | - = speed | P pause | O step | C compare | Z/wheel zoom | 1-6 overlays"

var _info: Label
var _paused: Label
var _timer: float = 0.0
var _player: PlayerController


func _ready() -> void:
	# Translucent backing so HUD text stays readable over bright blocks (the lab status lines sit inside it).
	var back := ColorRect.new()
	back.position = Vector2(6, 4)
	back.size = Vector2(530, 282)  ## +2 lines (Direction, Zoom) vs the original 4-line info block
	back.color = Color(0, 0, 0, 0.45)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var title := _make_label(Vector2(12, 8), 20)
	title.text = "SHINOBI RUSH\nBOOTSTRAP BUILD - PLACEHOLDER ART"
	_info = _make_label(Vector2(12, 70), 14)
	var legend := _make_label(Vector2(12, 660), 12)
	legend.text = LEGEND
	legend.position.y = 720.0 - 12.0 - 4.0 * 17.0
	_paused = _make_label(Vector2(560, 330), 36)
	_paused.text = "PAUSED"
	_paused.visible = false


func _make_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_paused.visible = get_tree().paused


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return
	_info.text = "State: %s\nSpeed: %d px/s\nPos: (%d, %d)\nDirection: %s\nZoom: %.2fx\nFPS: %d" % [
		_player.get_state_name(), int(_player.velocity.length()),
		int(_player.global_position.x), int(_player.global_position.y),
		SpriteSet.dir_name(_player.facing8), _player.camera.zoom.x,
		int(Engine.get_frames_per_second())]
