class_name UnitBars
extends RefCounted
## World-space status bars for non-player units (the Bandit): an enemy-specific plate (steel frame, crimson corner
## brackets), segmented HP and Chakra fills and substitution pips. Art lives in assets/ui/enemy_bars/ (tools/gen_enemy_bars.py),
## drawn 1:1 -- about 30% larger than the old half-scale reuse of the player HUD art. Pure drawing helper; callers pass fractions.

const DIR := "res://assets/ui/enemy_bars/"
const BAR_SIZE := Vector2(128.0, 14.0)
const FILL_INSET := Vector2(2.0, 2.0)
const FILL_SIZE := Vector2(124.0, 10.0)
const PIP_SIZE := 12.0
const PIP_STEP := 15.0
const ROW_GAP := 2.0

static var _tex: Dictionary = {}


static func size_for(_pip_count: int) -> Vector2:
	return Vector2(BAR_SIZE.x, BAR_SIZE.y * 2.0 + ROW_GAP * 2.0 + PIP_SIZE)


static func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png") as Texture2D
	return _tex[n]


## `origin` is the top-left of the block. Returns its size.
static func draw(ci: CanvasItem, origin: Vector2, hp_frac: float, chakra_frac: float, pips: int, max_pips: int) -> Vector2:
	_bar(ci, origin, hp_frac, "enemy_hp_fill")
	_bar(ci, origin + Vector2(0.0, BAR_SIZE.y + ROW_GAP), chakra_frac, "enemy_chakra_fill")
	var py := origin.y + (BAR_SIZE.y + ROW_GAP) * 2.0
	for i in max_pips:
		var tex := _t("enemy_pip_full" if i < pips else "enemy_pip_empty")
		ci.draw_texture_rect(tex, Rect2(Vector2(origin.x + PIP_STEP * i, py), Vector2(PIP_SIZE, PIP_SIZE)), false)
	return size_for(max_pips)


static func _bar(ci: CanvasItem, pos: Vector2, frac: float, fill: String) -> void:
	ci.draw_texture_rect(_t("enemy_frame"), Rect2(pos, BAR_SIZE), false)
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var src := Rect2(0.0, 0.0, floorf(FILL_SIZE.x * f), FILL_SIZE.y)
		if src.size.x >= 1.0:
			ci.draw_texture_rect_region(_t(fill), Rect2(pos + FILL_INSET, src.size), src)
