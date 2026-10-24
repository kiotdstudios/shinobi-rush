class_name EvadeStreakFx
extends AnimatedSprite2D
## One-shot evade streak (assets/vfx/ninja_evade, 6 frames @30 fps, drawn pointing right and rotated to the
## dash vector). The player's dodge ("Body Flicker") uses it; the Bandit's evade uses the same art.

const FRAMES := 6
const FPS := 30.0
const CHEST := Vector2(0, -48)


static func spawn(parent: Node2D, dir: Vector2) -> EvadeStreakFx:
	if parent == null:
		return null
	var fx := EvadeStreakFx.new()
	fx.name = "EvadeStreakFx"
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", FPS)
	for i in FRAMES:
		sf.add_frame("default", load("res://assets/vfx/ninja_evade/streak_%03d.png" % i))
	fx.sprite_frames = sf
	fx.position = CHEST
	fx.rotation = dir.angle()
	fx.z_index = 1
	parent.add_child(fx)
	fx.animation_finished.connect(fx.queue_free)
	fx.play("default")
	return fx
