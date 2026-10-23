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
const AVATAR_POS := Vector2(8.0, -4.0)  ## avatar (80x80) over the frame; the head pops out above the diamond
const BAR_X := 84.0  ## bars tuck 12px behind the diamond's right tip, as in the mockup
const BAR_TUCK := 14.0  ## hidden left part of each bar: the label centres on the visible part
const HP_Y := 15.0
const CHAKRA_Y := 41.0
const BAR_SIZE := Vector2(196.0, 22.0)
const FILL_INSET := Vector2(3.0, 3.0)
const FILL_SIZE := Vector2(190.0, 16.0)
const PIP_POS := Vector2(116.0, 70.0)
const PIP_STEP := 28.0
const PIP_FLASH := 0.7  ## seconds a pip glows after it refills
const SLOT_SIZE := 56.0  ## ability bar (bottom centre): five slots, only the first (Substitution, L2) has art
const SLOT_GAP := 8.0
const SLOT_COUNT := 5
const SLOT_Y := 616.0
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
var sub_progress: float = 1.0  ## 0..1: how far the soonest-recharging substitution charge has refilled (1 = nothing recharging)
var _player: PlayerController
var _flash: Array[float] = [0.0, 0.0, 0.0]
var _canvas: Control
var _tex: Dictionary = {}


func _ready() -> void:
	layer = 20
	for n: String in ["portrait_frame", "portrait_avatar", "bar_frame", "hp_fill", "chakra_fill", "pip_full", "pip_empty", "slot_frame", "slot_frame_gold", "log_icon", "log_icon_gray"]:
		_tex[n] = load(DIR + n + ".png") as Texture2D
	_canvas = Control.new()
	_canvas.name = "Bar"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_canvas.draw.connect(_draw_hud)
	_canvas.resized.connect(_redraw)


func bind(player: PlayerController) -> void:
	_player = player
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
	if charges > pips and charges >= 1 and charges <= _flash.size():
		_flash[charges - 1] = PIP_FLASH  ## a charge just refilled: its pip lights up
	pips = clampi(charges, 0, maximum)
	max_pips = maximum
	_redraw()


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	if _player != null:
		var p := _player.substitution_progress()
		if not is_equal_approx(p, sub_progress):
			sub_progress = p
			_redraw()
	for i in _flash.size():
		if _flash[i] > 0.0:
			_flash[i] = maxf(_flash[i] - delta, 0.0)
			_redraw()
	if trail > fraction:
		_hold -= delta
		if _hold <= 0.0:
			trail = maxf(fraction, trail - TRAIL_SPEED * delta)
			_redraw()


func fill_color() -> Color:
	return COL_LOW if fraction <= LOW_FRACTION else COL_FILL


func _draw_hud() -> void:
	# bars first: the portrait is drawn over their left ends
	_bar(HP_Y, trail, fraction, "hp_fill", fill_color(), label_text)
	_bar(CHAKRA_Y, chakra_fraction, chakra_fraction, "chakra_fill", COL_FILL, chakra_text)
	# portrait: dark backing diamond, the player's face clipped to the diamond opening, then the gold frame on top
	var o := ORIGIN
	var back := PackedVector2Array([o + Vector2(48, 8), o + Vector2(88, 48), o + Vector2(48, 88), o + Vector2(8, 48)])
	_canvas.draw_colored_polygon(back, Color(0.09, 0.07, 0.06, 1.0))
	_canvas.draw_texture(_tex["portrait_frame"], o)
	# the avatar is drawn over the frame: free above the diamond's middle (head breaks out of the frame), clipped to the opening below
	var av_origin := o + AVATAR_POS
	var clip := PackedVector2Array([Vector2(8, -4), Vector2(88, -4), Vector2(88, 48), Vector2(80, 48), Vector2(52, 76), Vector2(44, 76), Vector2(16, 48), Vector2(8, 48)])
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in clip:
		pts.append(o + p)
		uvs.append((o + p - av_origin) / 80.0)
	_canvas.draw_colored_polygon(pts, Color.WHITE, uvs, _tex["portrait_avatar"])
	# substitution pips
	for i in max_pips:
		var tex: Texture2D = _tex["pip_full"] if i < pips else _tex["pip_empty"]
		var at := PIP_POS + Vector2(PIP_STEP * i, 0.0)
		if i < _flash.size() and _flash[i] > 0.0:
			var k: float = _flash[i] / PIP_FLASH
			_canvas.draw_circle(at + Vector2(10, 10), 11.0 + 6.0 * (1.0 - k), Color(1.0, 0.86, 0.45, 0.55 * k))
		_canvas.draw_texture(tex, at)
	_draw_abilities()


## Ability bar: slot 0 is Substitution Jutsu (log art). While a charge recharges the icon is grey and refills bottom to top.
func _draw_abilities() -> void:
	var total := SLOT_SIZE * SLOT_COUNT + SLOT_GAP * (SLOT_COUNT - 1)
	var x0 := (_canvas.size.x - total) * 0.5
	for i in SLOT_COUNT:
		var pos := Vector2(x0 + (SLOT_SIZE + SLOT_GAP) * i, SLOT_Y)
		_canvas.draw_texture(_tex["slot_frame_gold" if i == 0 else "slot_frame"], pos)
	var first := Vector2(x0, SLOT_Y)
	var icon: Texture2D = _tex["log_icon"]
	var isz := icon.get_size()
	var ipos := first + (Vector2(SLOT_SIZE, SLOT_SIZE) - isz) * 0.5
	if pips < max_pips:
		_canvas.draw_texture(_tex["log_icon_gray"], ipos)
		var top := roundf(isz.y * (1.0 - sub_progress))
		if sub_progress > 0.0 and top < isz.y:
			_canvas.draw_texture_rect_region(icon, Rect2(ipos + Vector2(0.0, top), Vector2(isz.x, isz.y - top)), Rect2(0.0, top, isz.x, isz.y - top))
	else:
		_canvas.draw_texture(icon, ipos)
	var font := ThemeDB.fallback_font
	var lab := first + Vector2(0.0, SLOT_SIZE + 15.0)
	_canvas.draw_string_outline(font, lab, "L2", HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE, 13, 3, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, lab, "L2", HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE, 13, COL_TEXT)


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
	var at := pos + Vector2(BAR_TUCK, BAR_SIZE.y * 0.5 + 5.0)
	_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x - BAR_TUCK, 12, 3, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x - BAR_TUCK, 12, COL_TEXT)
