class_name ForestFireflies
extends Node2D
## Independent reusable swarm; no collision or gameplay mutation.
const ATLAS := "res://assets/vfx/blightwood_lights/firefly_atlas.png"
var count := 12
var radius := Vector2(72, 72)
var auto_advance := true
var enabled := true
var clock := 0.0
var seed_value := 0
var flies: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var halo_texture := FirePillar._make_glow_texture()
	for i in count:
		var halo := Sprite2D.new()
		halo.texture = halo_texture
		halo.material = additive
		add_child(halo)
		var insect := Sprite2D.new()
		insect.texture = load(ATLAS) as Texture2D
		insect.hframes = 4
		insect.vframes = 2
		insect.material = emissive
		insect.scale = Vector2.ONE * rng.randf_range(0.30, 0.45)
		add_child(insect)
		flies.append({"sprite": insect, "halo": halo, "phase": rng.randf_range(0, TAU),
			"speed": rng.randf_range(0.22, 0.55), "spread": rng.randf_range(0.45, 1.0),
			"blink": rng.randf_range(0.7, 1.6)})
	set_process(auto_advance)
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta
	for f in flies:
		var phase: float = f.phase
		var t: float = clock * float(f.speed) + phase
		var spread: float = f.spread
		var pos := Vector2((sin(t * 1.13) * 0.64 + sin(t * 2.71 + phase) * 0.30) * radius.x,
			(sin(t * 0.83 + phase) * 0.68 + sin(t * 1.93) * 0.25) * radius.y) * spread
		var pulse := pow(maxf(0.0, sin(clock * float(f.blink) + phase)), 2.0)
		var opacity := 0.16 + 0.84 * pulse
		var insect: Sprite2D = f.sprite
		insect.visible = enabled
		insect.position = pos
		insect.frame = (int(clock * 18.0 + phase * 4.0)) % 8
		insect.rotation = sin(t * 1.13) * 0.32
		insect.modulate = Color(0.75 + pulse * 0.25, 0.88 + pulse * 0.12, 1.0, opacity)
		var halo: Sprite2D = f.halo
		halo.visible = enabled
		halo.position = pos
		halo.scale = Vector2.ONE * (0.11 + pulse * 0.15)
		halo.modulate = Color(0.24, 0.48, 0.85, opacity * 0.48)
