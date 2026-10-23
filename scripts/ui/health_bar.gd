class_name HealthBar
extends CanvasLayer
## Player status HUD (top-left): a gold diamond portrait frame holding the player's own face, a HP bar, a Chakra bar and
## three substitution pips. Every piece is pixel art (assets/ui/hud/, generated with PixelLab; the bar frame is hand-built);
## only the fill width, numbers and pip states are drawn here. Pure presentation: it listens to the player's
## health_changed / chakra_changed / substitution_changed signals and holds no gameplay state of its own.
## (Class name kept as HealthBar: it started as the HP bar and PlayerController/tests still address it by that name.)

const DIR := "res://assets/ui/hud/"
const ORIGIN := Vector2(8.0, 6.0)  ## top-left of the portrait frame
const PORTRAIT_SIZE := Vector2(96.0, 96.0)
const AVATAR_POS := Vector2(16.0, 16.0)  ## avatar (64x64) inside the frame
const BAR_X := 104.0
const HP_Y := 12.0
const CHAKRA_Y := 40.0
const BAR_SIZE := Vector2(224.0, 22.0)
const FILL_INSET := Vector2(3.0, 3.0)
const FILL_SIZE := Vector2(218.0, 16.0)
const PIP_POS := Vector2(122.0, 72.0)
const PIP_STEP := 26.0
const COL_TEXT := Color(1.0, 1.0, 1.0, 0.95)
const COL_FILL := Color(1.0, 1.0, 1.0, 1.0)  ## fill textures are already red / blue: white = unmodulated
const COL_LOW := Color(1.0, 0.72, 0.72, 1.0)  ## HP at or below LOW_FRACTION: brighter flush
const COL_TRAIL := Color(1.0, 1.0, 1.0, 0.55)
const LOW_FRACTION := 0.3
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.9  ## fraction per second

var fraction: float = 1.0  ## shown HP fill, 0..1
var trail: float = 1.0
var label_text: String = "HP 100 / 100"
var chakra_fraction: float = 1.0
var chakra_text: String = "Chakra 100 / 100"
var pips: int = 3
var max_pips: int = 3
var _hold: float = 0.0
var _canvas: Control
var _tex: Dictionary = {}


func _ready() -> void:
	layer = 20
	for n: String in ["portrait_frame", "portrait_avatar", "bar_frame", "hp_fill", "chakra_fill", "pip_full", "pip_empty"]:
		_tex[n] = load(DIR + n + ".png") as Texture2D
	_canvas = Control.new()
	_canvas.name = "Bar"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_canvas.draw.connect(_draw_hud)


func bind(player: PlayerController) -> void:
	player.health_changed.connect(_on_health_changed)
	player.chakra_changed.connect(_on_chakra_changed)
	player.substitution_changed.connect(_on_substitution_changed)
	_on_health_changed(player.health, player.max_health)
	_on_chakra_changed(player.chakra, player.max_chakra)
	_on_substitution_changed(player.substitution_charges, player.max_substitution_charges)
	trail = fraction


func _on_health_changed(current: float, maximum: float) -> void:
	var f := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if f < fraction:
		_hold = TRAIL_DELAY
	fraction = f
	trail = maxf(trail, fraction) if f < trail else f
	label_text = "HP %d / %d" % [ceili(current), int(maximum)]
	_redraw()


func _on_chakra_changed(current: float, maximum: float) -> void:
	chakra_fraction = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	chakra_text = "Chakra %d / %d" % [ceili(current), int(maximum)]
	_redraw()


func _on_substitution_changed(charges: int, maximum: int) -> void:
	pips = clampi(charges, 0, maximum)
	max_pips = maximum
	_redraw()


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	if trail > fraction:
		_hold -= delta
		if _hold <= 0.0:
			trail = maxf(fraction, trail - TRAIL_SPEED * delta)
			_redraw()


func fill_color() -> Color:
	return COL_LOW if fraction <= LOW_FRACTION else COL_FILL


func _draw_hud() -> void:
	# portrait: dark backing diamond, the player's face clipped to the diamond opening, then the gold frame on top
	var o := ORIGIN
	var back := PackedVector2Array([o + Vector2(48, 8), o + Vector2(88, 48), o + Vector2(48, 88), o + Vector2(8, 48)])
	_canvas.draw_colored_polygon(back, Color(0.09, 0.07, 0.06, 1.0))
	var av_origin := o + AVATAR_POS
	var diamond := PackedVector2Array([o + Vector2(48, 16), o + Vector2(80, 48), o + Vector2(48, 80), o + Vector2(16, 48)])
	var uvs := PackedVector2Array()
	for p in diamond:
		uvs.append((p - av_origin) / 64.0)
	_canvas.draw_colored_polygon(diamond, Color.WHITE, uvs, _tex["portrait_avatar"])
	_canvas.draw_texture(_tex["portrait_frame"], o)
	# bars
	_bar(HP_Y, trail, fraction, "hp_fill", fill_color(), label_text)
	_bar(CHAKRA_Y, chakra_fraction, chakra_fraction, "chakra_fill", COL_FILL, chakra_text)
	# substitution pips
	for i in max_pips:
		var tex: Texture2D = _tex["pip_full"] if i < pips else _tex["pip_empty"]
		_canvas.draw_texture(tex, PIP_POS + Vector2(PIP_STEP * i, 0.0))


func _bar(y: float, trail_f: float, fill_f: float, fill_tex: String, tint: Color, text: String) -> void:
	var pos := Vector2(BAR_X, y)
	_canvas.draw_texture(_tex["bar_frame"], pos)
	var inner := pos + FILL_INSET
	if trail_f > fill_f:
		_canvas.draw_rect(Rect2(inner, Vector2(FILL_SIZE.x * trail_f, FILL_SIZE.y)), COL_TRAIL)
	if fill_f > 0.0:
		var src := Rect2(0.0, 0.0, FILL_SIZE.x * fill_f, FILL_SIZE.y)
		_canvas.draw_texture_rect_region(_tex[fill_tex], Rect2(inner, src.size), src, tint)
	var font := ThemeDB.fallback_font
	var at := pos + Vector2(0.0, BAR_SIZE.y * 0.5 + 5.0)
	_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x, 12, 3, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x, 12, COL_TEXT)
