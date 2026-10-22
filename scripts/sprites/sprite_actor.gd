class_name SpriteActor
extends Node2D
## Draws one SpriteSet animation with the foot anchor on this node's origin (the ground-contact
## point). The sprite sits in a pivot at the origin; horizontal mirroring scales the pivot by -1, so
## the anchor never moves when frames, animations or flips change.

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


## Show `aid` with the frame DRIVEN by `progress` (0..1) instead of free-running: the animation can
## then be stretched/compressed to any gameplay duration and survives interruptions (an air attack
## mid-jump) without restarting from frame 0.
func show_animation_at(s: SpriteSet, aid: String, want_dir: String, progress: float) -> bool:
	if not show_animation(s, aid, want_dir, false):
		return false
	var n := sprite.sprite_frames.get_frame_count(sprite.animation)
	sprite.pause()
	sprite.frame = clampi(int(clampf(progress, 0.0, 1.0) * n), 0, maxi(n - 1, 0))
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


## Raw current frame index (0-based) of the currently playing animation. 0 if nothing is loaded yet.
## Used by weapon/prop overlays that must track the body's exact frame (see WeaponRig).
func current_frame() -> int:
	return sprite.frame if sprite.sprite_frames != null else 0
