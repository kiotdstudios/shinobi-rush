class_name DustPuff
extends Node2D
## Frame-based dust effects (PixelLab-generated art in assets/vfx/dust/<variant>/frame_NN.png).
## Every event type owns a small pool of variants; each spawn picks a random variant and then
## randomises flip, scale, rotation and tint, so two steps in a row never look identical.
## Spawned puffs live under this node (which is top_level, so they stay put in the world while the
## player moves on) and free themselves when their animation ends.

const DIR := "res://assets/vfx/dust/"
const FPS_MIN := 14.0
const FPS_MAX := 20.0
## Frames are cropped tight to the dust, so the bottom edge of the texture sits on the ground; this
## sinks it a few px below the player's feet so the cloud hugs the floor.
const FOOT_SINK := 3.0
const MAX_LIVE := 24

## Variant folders (frame_00.png ...) per event kind.
const POOLS := {
	"step": ["step_a", "step_d", "skid_a"],
	"sprint": ["trail_a", "trail_b", "step_a", "step_d"],
	"jump": ["plume_a", "skid_a"],
	"land": ["ring_a", "land_b", "skid_a"],
}
## Extra scale for a big variant reused on a small event ("kind|variant").
const PAIR_SCALE := {"step|skid_a": 0.5, "jump|skid_a": 0.8}
## Pixel scale per kind (footsteps are small, impacts are big).
const KIND_SCALE := {"step": 1.0, "sprint": 1.0, "jump": 0.75, "land": 1.0}

static var _frames_cache: Dictionary = {}

var rng := RandomNumberGenerator.new()
var _live: int = 0
var last_variant: String = ""  ## most recent variant played (tests / telemetry)


func _ready() -> void:
	top_level = true
	z_index = 10
	rng.randomize()


## Back-compat entry point: `strength` > 1.2 reads as a jump/land burst, otherwise a footstep.
func burst(pos: Vector2, strength: float = 1.0) -> void:
	play("land" if strength >= 1.2 else ("sprint" if strength >= 0.8 else "step"), pos, Vector2.ZERO)


func footstep(pos: Vector2, sprinting: bool, facing: Vector2) -> void:
	play("sprint" if sprinting else "step", pos, facing)


func takeoff(pos: Vector2) -> void:
	play("jump", pos, Vector2.ZERO)


func landing(pos: Vector2) -> void:
	play("land", pos, Vector2.ZERO)


## Variant names available for `kind` (those whose frames actually exist).
static func variants_for(kind: String) -> Array:
	var out: Array = []
	for v in POOLS.get(kind, []):
		if not frames_for(v).is_empty():
			out.append(v)
	return out


static func frames_for(variant: String) -> Array:
	if _frames_cache.has(variant):
		return _frames_cache[variant]
	var frames: Array = []
	var i := 0
	while true:
		var path := "%s%s/frame_%02d.png" % [DIR, variant, i]
		if not ResourceLoader.exists(path):
			break
		frames.append(load(path))
		i += 1
	_frames_cache[variant] = frames
	return frames


## Plays one random variant of `kind` at world position `pos`. `facing` (optional) orients trail art.
## Returns the spawned sprite, or null if there is nothing to play / the cap is reached.
func play(kind: String, pos: Vector2, facing: Vector2) -> Sprite2D:
	# Waterlife owns water-contact spray; do not layer dry brown dust over it.
	if get_parent() is PlayerController and (get_parent() as PlayerController).over_water:
		return null
	var variants := variants_for(kind)
	if variants.is_empty() or _live >= MAX_LIVE:
		return null
	var variant: String = variants[rng.randi() % variants.size()]
	last_variant = variant
	var frames: Array = frames_for(variant)
	var spr := Sprite2D.new()
	spr.texture = frames[0]
	spr.centered = true
	var s: float = float(KIND_SCALE.get(kind, 1.0)) * float(PAIR_SCALE.get(kind + "|" + variant, 1.0)) * rng.randf_range(0.85, 1.15)
	var tex: Texture2D = frames[0]
	spr.offset = Vector2(0, -tex.get_height() * 0.5 + FOOT_SINK / s)
	spr.global_position = pos
	spr.scale = Vector2(s, s)
	spr.flip_h = rng.randf() < 0.5
	if kind == "sprint" and variant.begins_with("trail") and facing.length() > 0.1:
		# Trail art streaks to the right behind the head: flip so it streams opposite the motion.
		spr.flip_h = facing.x > 0.0
		spr.rotation = 0.0
	else:
		spr.rotation = rng.randf_range(-0.12, 0.12)
	var tint := rng.randf_range(0.9, 1.0)
	spr.modulate = Color(tint, tint * rng.randf_range(0.96, 1.0), tint * rng.randf_range(0.9, 1.0), rng.randf_range(0.8, 0.95))
	add_child(spr)
	_live += 1
	var fps := rng.randf_range(FPS_MIN, FPS_MAX)
	spr.tree_exited.connect(_on_puff_gone)
	var tw := spr.create_tween()  # bound to the sprite: it dies with it
	for i in range(frames.size()):
		tw.tween_callback(spr.set_texture.bind(frames[i]))
		tw.tween_interval(1.0 / fps)
	tw.tween_callback(spr.queue_free)
	return spr


func _on_puff_gone() -> void:
	_live = maxi(_live - 1, 0)
