class_name HealthBar
extends CanvasLayer
## Player health bar, KIOTD style: near-black plate, white frame, fire-orange fill that turns red when low,
## and a pale "damage trail" that drains behind the fill. Pure presentation: it listens to
## PlayerController.health_changed and holds no health state of its own.

const BAR_SIZE := Vector2(360.0, 18.0)
const TOP_MARGIN := 14.0
const COL_PLATE := Color(0.039, 0.039, 0.039, 0.88)
const COL_FRAME := Color(1.0, 1.0, 1.0, 0.9)
const COL_FILL := Color(1.0, 0.42, 0.0, 1.0)  ## #FF6B00
const COL_LOW := Color(0.9, 0.12, 0.1, 1.0)
const COL_TRAIL := Color(1.0, 1.0, 1.0, 0.55)
const LOW_FRACTION := 0.3
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.9  ## fraction per second

var fraction: float = 1.0  ## shown fill, 0..1
var trail: float = 1.0
var label_text: String = "HP 100/100"
var _hold: float = 0.0
var _canvas: Control


func _ready() -> void:
	layer = 20
	_canvas = Control.new()
	_canvas.name = "Bar"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_canvas.draw.connect(_draw_bar)


func bind(player: PlayerController) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)
	trail = fraction


func _on_health_changed(current: float, maximum: float) -> void:
	var f := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if f < fraction:
		_hold = TRAIL_DELAY
	fraction = f
	trail = maxf(trail, fraction) if f < trail else f
	label_text = "HP %d/%d" % [ceili(current), int(maximum)]
	if _canvas != null:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	if trail > fraction:
		_hold -= delta
		if _hold <= 0.0:
			trail = maxf(fraction, trail - TRAIL_SPEED * delta)
			if _canvas != null:
				_canvas.queue_redraw()


func fill_color() -> Color:
	return COL_LOW if fraction <= LOW_FRACTION else COL_FILL


func _draw_bar() -> void:
	var vw := _canvas.size.x
	var r := Rect2(Vector2((vw - BAR_SIZE.x) * 0.5, TOP_MARGIN), BAR_SIZE)
	_canvas.draw_rect(r.grow(2.0), COL_PLATE)
	_canvas.draw_rect(Rect2(r.position, Vector2(BAR_SIZE.x * trail, BAR_SIZE.y)), COL_TRAIL)
	_canvas.draw_rect(Rect2(r.position, Vector2(BAR_SIZE.x * fraction, BAR_SIZE.y)), fill_color())
	_canvas.draw_rect(r.grow(2.0), COL_FRAME, false, 2.0)
	var font := ThemeDB.fallback_font
	_canvas.draw_string(font, r.position + Vector2(0, BAR_SIZE.y + 16.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x, 13, COL_FRAME)
