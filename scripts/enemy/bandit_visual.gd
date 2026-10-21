class_name BanditVisual
extends Node2D
## Explicit enemy-only binding of Codex's 128px red-scarf bandit art.
## Missing art/death retain the procedural fallback until dedicated action art is available.

const ART_PATH := "res://assets/characters/bandit/bandit_128.art.json"
static var _art_set: SpriteSet
static var _art_checked := false

@export_enum("run", "sprint") var approach_animation: String = "run"
var actor: SpriteActor

const CLOTH := Color("#5a3a2a")
const LIMB := Color("#3a2a1a")
const SKIN := Color("#8a4a3a")
const DEAD_TINT := Color("#555555")

var bandit: Bandit


func _ready() -> void:
	bandit = get_parent() as Bandit
	actor = SpriteActor.new()
	actor.name = "BanditSprite"
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(actor)
	if not _art_checked:
		_art_checked = true
		_art_set = SpriteSet.parse(FileAccess.get_file_as_string(ART_PATH), ART_PATH)
		if not _art_set.is_valid():
			push_warning("Bandit art unavailable: " + _art_set.first_error())
	_process(0.0)


func _process(_delta: float) -> void:
	if bandit == null or actor == null:
		return
	actor.visible = _art_set != null and _art_set.is_valid() and bandit.state != Bandit.State.DEAD
	if actor.visible:
		var moving := bandit.state == Bandit.State.APPROACH and bandit.velocity.length_squared() > 1.0
		# Knockback is not a running cycle. Keep the struck pose through hurt/hitstop.
		if bandit.state != Bandit.State.HIT_REACT or actor.set_ref == null:
			actor.show_animation(_art_set, approach_animation if moving else "idle", SpriteSet.dir_name(bandit.facing8))
		actor.set_playback(1.0, bandit._hitstop_timer > 0.0 or bandit.state == Bandit.State.HIT_REACT)
		actor.modulate = Bandit.HIT_FLASH if bandit._hit_flash_timer > 0.0 else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if bandit == null:
		return
	if actor != null and actor.visible:
		_draw_hp_and_label(-122.0)
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


func _draw_hp_and_label(top_y: float = -78.0) -> void:
	var font := ThemeDB.fallback_font
	var top := Vector2(-30, top_y)
	draw_string(font, top + Vector2(0, -6), "BANDIT (" + bandit.get_state_name() + ")", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.75))
	if bandit.state == Bandit.State.DEAD:
		return
	var w := 60.0
	var h := 6.0
	draw_rect(Rect2(top, Vector2(w, h)), Color(0, 0, 0, 0.5), true)
	var frac := clampf(bandit.hp / bandit.max_hp, 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(w * frac, h)), Color("#c0392b"), true)
	draw_rect(Rect2(top, Vector2(w, h)), Color(1, 1, 1, 0.6), false, 1.0)
