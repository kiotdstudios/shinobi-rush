class_name BodyFlickerFx
extends Node2D
## One-shot Body Flicker (Shunshin) effect used by the player's dodge. Plays Orcha's depart / travel /
## arrive sprites (assets/vfx/body_flicker/, authored for the SE direction only) at the right world
## points and frees itself. The art is turned for the other 7 directions by mirroring (west side) and
## rotating about the foot anchor: that is a stand-in until real per-direction art exists.

const VFX_DIR := "res://assets/vfx/body_flicker/"
const FPS := 24.0
const CANVAS := 192
const ANCHOR := Vector2(96, 141)
const SE_ANGLE := PI * 0.25
const Z := 20
const DEPART := ["depart_000", "depart_001", "depart_002"]
const TRAVEL := ["travel_000", "travel_001", "travel_002", "travel_003"]
const ARRIVE := ["arrive_000", "arrive_001", "arrive_002"]

static var _frames: Dictionary = {}

var _live: int = 0


## Spawns the effect under `parent`. `from`/`to` are world foot positions, `arrive_delay` is how long
## after the start the reappearance burst plays. Returns the effect node (it frees itself).
static func spawn(parent: Node, from: Vector2, to: Vector2, dir: Vector2, arrive_delay: float) -> BodyFlickerFx:
	if parent == null:
		return null
	var fx := BodyFlickerFx.new()
	fx.name = "BodyFlickerFx"
	parent.add_child(fx)
	fx.z_index = Z
	fx._run(from, to, dir, arrive_delay)
	return fx


static func frames_for(anim: String) -> SpriteFrames:
	if _frames.has(anim):
		return _frames[anim]
	var sf := SpriteFrames.new()
	sf.add_animation("default")
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", FPS)
	var names: Array = DEPART if anim == "depart" else (TRAVEL if anim == "travel" else ARRIVE)
	for n in names:
		var tex := load(VFX_DIR + str(n) + ".png") as Texture2D
		if tex != null:
			sf.add_frame("default", tex)
	_frames[anim] = sf
	return sf


## (rotation, mirror) that turns the SE art to point along `dir`.
static func orientation(dir: Vector2) -> Dictionary:
	var d := dir if dir.length() > 0.001 else Vector2(1, 1)
	var mirror := d.x < -0.001
	var rot := Vector2(absf(d.x), d.y).angle() - SE_ANGLE
	return {"rotation": -rot if mirror else rot, "mirror": mirror}


func _run(from: Vector2, to: Vector2, dir: Vector2, arrive_delay: float) -> void:
	_add(frames_for("depart"), from, dir, 0.0)
	_add(frames_for("travel"), from.lerp(to, 0.5), dir, 0.04)
	_add(frames_for("arrive"), to, dir, maxf(arrive_delay, 0.0))


func _add(sf: SpriteFrames, pos: Vector2, dir: Vector2, delay: float) -> void:
	if sf.get_frame_count("default") == 0:
		return
	_live += 1
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = sf
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.offset = Vector2(-ANCHOR.x, -ANCHOR.y)
	sp.global_position = pos
	var o := orientation(dir)
	sp.rotation = o["rotation"]
	if o["mirror"]:
		sp.scale.x = -1.0
	sp.visible = false
	add_child(sp)
	sp.global_position = pos
	var go := func() -> void:
		if not is_instance_valid(sp):
			return
		sp.visible = true
		sp.frame = 0
		sp.play("default")
	sp.animation_finished.connect(func() -> void:
		sp.queue_free()
		_live -= 1
		if _live <= 0:
			queue_free())
	if delay <= 0.0:
		go.call()
	else:
		get_tree().create_timer(delay).timeout.connect(go)
