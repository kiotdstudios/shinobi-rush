class_name SpriteActor
extends Node2D
## Draws one SpriteSet animation with the foot anchor on this node's origin (the ground-contact
## point). The sprite sits in a pivot at the origin; horizontal mirroring scales the pivot by -1, so
## the anchor never moves when frames, animations or flips change. The shadow stays fixed.

const SHADOW := Color(0, 0, 0, 0.35)

var sprite: AnimatedSprite2D
var set_ref: SpriteSet
var anim_id: String = ""
var dir: String = ""
var flip: bool = false
var fallback: bool = false
var _pivot: Node2D
var _k_set: SpriteSet
var _k_anim: String = ""
var _k_dir: String = ""
var _k_freeze: bool = false
var _k_valid: bool = false
var _freeze: bool = false


func _init() -> void:
	_pivot = Node2D.new()
	add_child(_pivot)
	sprite = AnimatedSprite2D.new()
	sprite.centered = false
	_pivot.add_child(sprite)


## Local position of the sprite's top-left so that `anchor` lies on the origin.
static func sprite_position(anchor: Vector2) -> Vector2:
	return -anchor


func _draw() -> void:
	if sprite.sprite_frames == null:
		return
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(Vector2(cos(a) * 15.0 * WorldScale.SCALE, sin(a) * 6.0 * WorldScale.SCALE))
	draw_colored_polygon(pts, SHADOW)


## Show (set, anim, desired direction). `freeze` shows frame 0 without advancing (static idle).
## Returns false (and hides the sprite) if the animation cannot be shown. Cheap when unchanged.
func show_animation(s: SpriteSet, aid: String, want_dir: String, freeze: bool = false) -> bool:
	if _k_valid and s == _k_set and aid == _k_anim and want_dir == _k_dir and freeze == _k_freeze:
		return sprite.visible
	_k_valid = true
	_k_set = s
	_k_anim = aid
	_k_dir = want_dir
	_k_freeze = freeze
	_freeze = freeze
	var res: Dictionary = s.resolve(aid, want_dir) if s != null else {}
	var frames: SpriteFrames = s.get_frames(aid) if (s != null and not res.is_empty()) else null
	if frames == null or not frames.has_animation(res["dir"]):
		sprite.visible = false
		sprite.sprite_frames = null
		set_ref = s
		anim_id = aid
		queue_redraw()
		return false
	var switching: bool = set_ref != s or anim_id != aid or dir != res["dir"]
	set_ref = s
	anim_id = aid
	dir = res["dir"]
	flip = res["flip"]
	fallback = res["fallback"]
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		queue_redraw()
	sprite.visible = true
	sprite.position = sprite_position(s.anim_anchor(aid))
	_pivot.scale.x = -1.0 if flip else 1.0
	if switching or sprite.animation != StringName(dir):
		sprite.animation = StringName(dir)
		sprite.frame = 0
	if freeze:
		sprite.stop()
		sprite.frame = 0
	elif not sprite.is_playing():
		sprite.play(StringName(dir))
	return true


func set_playback(speed: float, paused: bool) -> void:
	sprite.speed_scale = speed
	if paused and sprite.is_playing():
		sprite.pause()
	elif not paused and not sprite.is_playing() and sprite.sprite_frames != null and not _freeze:
		sprite.play(sprite.animation)


## Advance one frame (used while paused).
func step_frame() -> void:
	var n := sprite.sprite_frames.get_frame_count(sprite.animation) if sprite.sprite_frames != null else 0
	if n > 0:
		sprite.frame = (sprite.frame + 1) % n


func current_frame_text() -> String:
	if sprite.sprite_frames == null or not sprite.visible:
		return "-"
	return "%d/%d" % [sprite.frame + 1, sprite.sprite_frames.get_frame_count(sprite.animation)]
