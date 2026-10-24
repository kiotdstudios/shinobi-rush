class_name FirePillar
extends Node2D
## One stone lantern pillar with an animated flame (owner 2026-10-22: "make this little fire pillar
## thingy" from the shrine mockup; "very detailed fire animation as always max frames to get the
## quality matching the grass"). Art: assets/environment/fire_pillar/fire_pillar.art.json.
##
## Node origin = the pillar's ground/foot contact point (same convention as BlossomTree), so a
## FirePillarField can simply set `position` to a WorldScale.FIRE_PILLAR_POSITIONS entry. Draw order
## is plain child order (pillar -> glow -> flame -> embers): this node does NOT set
## y_sort_enabled on itself (that stays correct per-child order); the FIELD sets y_sort_enabled so
## the whole prop sorts against the player/trees/bandit by its own Y, same split as
## BlossomTree/BlossomGrove.

var data: Dictionary  ## fire_pillar.art.json, shared across every instance (read-only, never mutated)
var pillar_sprite: Sprite2D
var flame_sprite: AnimatedSprite2D
var glow: Sprite2D
var embers: CPUParticles2D
var flame_on := true
var glow_on := true
var _glow_clock := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pillar: Dictionary = data.pillar
	var foot := Vector2(float(pillar.foot_anchor[0]), float(pillar.foot_anchor[1]))
	var bowl := Vector2(float(pillar.bowl_anchor[0]), float(pillar.bowl_anchor[1]))

	pillar_sprite = Sprite2D.new()
	pillar_sprite.name = "PillarBase"
	pillar_sprite.centered = false
	pillar_sprite.position = -foot
	pillar_sprite.texture = load(str(pillar.path)) as Texture2D
	add_child(pillar_sprite)

	glow = Sprite2D.new()
	glow.name = "Glow"
	glow.texture = _make_glow_texture()
	glow.centered = true
	glow.position = bowl - foot
	glow.modulate = Color(1.0, 0.62, 0.22, 0.55)
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_mat
	add_child(glow)

	var flame: Dictionary = data.flame
	var flame_foot := Vector2(float(flame.foot_anchor[0]), float(flame.foot_anchor[1]))
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("flicker")
	sf.set_animation_speed("flicker", float(flame.fps))
	sf.set_animation_loop("flicker", bool(flame.loop))
	for fr: Dictionary in (flame.frames as Array):
		var tex := load(str(fr.path)) as Texture2D
		if tex != null:
			sf.add_frame("flicker", tex)
	flame_sprite = AnimatedSprite2D.new()
	flame_sprite.name = "Flame"
	flame_sprite.centered = false
	flame_sprite.position = (bowl - foot) - flame_foot
	flame_sprite.sprite_frames = sf
	flame_sprite.animation = "flicker"
	flame_sprite.play("flicker")
	add_child(flame_sprite)

	embers = CPUParticles2D.new()
	embers.name = "Embers"
	embers.texture = _make_ember_texture()
	embers.position = bowl - foot
	embers.amount = 10
	embers.lifetime = 1.4
	embers.preprocess = 1.4  ## already mid-flight on the very first frame, not a sudden burst at boot
	embers.one_shot = false
	embers.explosiveness = 0.0
	embers.randomness = 0.6
	embers.direction = Vector2.UP
	embers.spread = 24.0
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 34.0
	embers.gravity = Vector2(0, -10.0)  ## gentle upward drift, not falling embers
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.1
	embers.color = Color(1.0, 0.68, 0.22, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	embers.color_ramp = ramp
	add_child(embers)


func set_flame_enabled(on: bool) -> void:
	flame_on = on
	flame_sprite.visible = on
	glow.visible = on and glow_on
	embers.emitting = on


## Soft flicker life beyond the 16 painted frames (owner's "max frames... quality matching the
## grass" bar): the grass reaches its density via a continuous shader phase on top of a handful of
## real tiles, not by painting hundreds of frames. This mirrors that same hybrid -- the glow's
## alpha/scale breathes continuously so the light itself feels alive between frame cuts.
func advance(delta: float) -> void:
	if not flame_on:
		return
	_glow_clock += delta
	var pulse := 0.85 + 0.15 * sin(_glow_clock * 9.0) + 0.05 * sin(_glow_clock * 23.0 + 1.7)
	glow.scale = Vector2.ONE * pulse
	glow.modulate.a = 0.55 * pulse


## Small soft-edged circle for the glow halo -- procedural, no external asset (same pattern as
## scripts/vfx/dust_puff.gd's circle, sized up for a light glow instead of a dust clump).
static func _make_glow_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d * d, 0.0, 1.0)  ## quadratic falloff: soft core, fast-fading edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## Tiny soft dot for rising embers -- same style as the glow texture, much smaller.
static func _make_ember_texture() -> ImageTexture:
	var size := 10
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
