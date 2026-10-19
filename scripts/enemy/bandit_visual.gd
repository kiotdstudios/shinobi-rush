class_name BanditVisual
extends Node2D
## PLACEHOLDER procedural silhouette for Bandit, mirroring PlaceholderVisual's style (same limb/torso
## construction) so the arena reads consistently until Codex delivers enemy art (see the Codex
## animation request filed alongside this order). Flashes red briefly on a hit, grays out on death.

const CLOTH := Color("#5a3a2a")
const LIMB := Color("#3a2a1a")
const SKIN := Color("#8a4a3a")
const DEAD_TINT := Color("#555555")

var bandit: Bandit


func _ready() -> void:
	bandit = get_parent() as Bandit


func _draw() -> void:
	if bandit == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * WorldScale.FIGURE_SCALE)
	var dead := bandit.state == Bandit.State.DEAD
	var flashing := bandit._hit_flash_timer > 0.0
	var cloth := DEAD_TINT if dead else (Bandit.HIT_FLASH if flashing else CLOTH)
	var limb := DEAD_TINT if dead else LIMB
	var skin := DEAD_TINT if dead else SKIN
	var hip := Vector2(0, -20) if not dead else Vector2(0, -6)
	var neck := hip + Vector2(0, -22)
	var head := neck + Vector2(0, -8)
	if dead:
		# Collapsed silhouette: a low horizontal shape instead of a standing figure.
		draw_line(Vector2(-14, -4), Vector2(14, -2), cloth, 10.0)
		draw_circle(Vector2(18, -3), 6.0, skin)
		_draw_hp_and_label()
		return
	var stride := 4.0 if bandit.state == Bandit.State.APPROACH else 0.0
	draw_line(hip, Vector2(-5 - stride, 0), limb, 4.0)
	draw_line(hip, Vector2(5 + stride, 0), limb, 4.0)
	draw_line(hip, neck, cloth, 9.0)
	var shoulder := neck + Vector2(0, 3)
	draw_line(shoulder + Vector2(-5, 0), shoulder + Vector2(-8, 14), limb, 3.0)
	draw_line(shoulder + Vector2(5, 0), shoulder + Vector2(8, 14), limb, 3.0)
	draw_circle(head, 7.0, skin)
	draw_circle(head + Vector2(bandit.facing8.x * 4.0, bandit.facing8.y * 2.0), 2.0, Color("#ffd23f"))
	_draw_hp_and_label()


func _draw_hp_and_label() -> void:
	var font := ThemeDB.fallback_font
	var top := Vector2(-30, -78)
	draw_string(font, top + Vector2(0, -6), "BANDIT (" + bandit.get_state_name() + ")", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.75))
	if bandit.state == Bandit.State.DEAD:
		return
	var w := 60.0
	var h := 6.0
	draw_rect(Rect2(top, Vector2(w, h)), Color(0, 0, 0, 0.5), true)
	var frac := clampf(bandit.hp / bandit.max_hp, 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(w * frac, h)), Color("#c0392b"), true)
	draw_rect(Rect2(top, Vector2(w, h)), Color(1, 1, 1, 0.6), false, 1.0)
