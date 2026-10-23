class_name UnitBars
extends RefCounted
## Compact world-space status bars for non-player units (the Bandit): HP bar, Chakra bar and substitution pips, drawn with the
## same pixel art as the player HUD (assets/ui/hud/) at half scale. Pure drawing helper; callers pass the fractions.

const DIR := "res://assets/ui/hud/"
const SCALE := 0.5
const BAR_SIZE := Vector2(196.0, 22.0)
const FILL_INSET := Vector2(3.0, 3.0)
const FILL_SIZE := Vector2(190.0, 16.0)
const PIP_SIZE := 20.0
const PIP_STEP := 24.0
const ROW_GAP := 1.0

static var _tex: Dictionary = {}


static func size_for(pip_count: int) -> Vector2:
	var bar := BAR_SIZE * SCALE
	return Vector2(bar.x, bar.y * 2.0 + ROW_GAP * 2.0 + PIP_SIZE * SCALE)


static func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png") as Texture2D
	return _tex[n]


## `origin` is the top-left of the block. Returns its size.
static func draw(ci: CanvasItem, origin: Vector2, hp_frac: float, chakra_frac: float, pips: int, max_pips: int) -> Vector2:
	var bar := BAR_SIZE * SCALE
	_bar(ci, origin, hp_frac, "hp_fill")
	_bar(ci, origin + Vector2(0.0, bar.y + ROW_GAP), chakra_frac, "chakra_fill")
	var py := origin.y + (bar.y + ROW_GAP) * 2.0
	for i in max_pips:
		var tex := _t("pip_full" if i < pips else "pip_empty")
		ci.draw_texture_rect(tex, Rect2(Vector2(origin.x + PIP_STEP * SCALE * i, py), Vector2(PIP_SIZE, PIP_SIZE) * SCALE), false)
	return size_for(max_pips)


static func _bar(ci: CanvasItem, pos: Vector2, frac: float, fill: String) -> void:
	ci.draw_texture_rect(_t("bar_frame"), Rect2(pos, BAR_SIZE * SCALE), false)
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var src := Rect2(0.0, 0.0, FILL_SIZE.x * f, FILL_SIZE.y)
		ci.draw_texture_rect_region(_t(fill), Rect2(pos + FILL_INSET * SCALE, src.size * SCALE), src)
