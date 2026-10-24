class_name BlightwoodLight
extends Node2D
## PixelLab fixture, separate pendulum/glass/flame layers, blue light and fireflies.
const MANIFEST := "res://assets/environment/blightwood_lights/blightwood-lights.art.json"
var data: Dictionary
var auto_advance := true
var lighting_on := true
var fireflies_on := true
var sway_on := true
var sound_on := true
var clock := 0.0
var phase := 0.0
var pulse := 1.0
var body: Sprite2D
var glass: Sprite2D
var pendant: Node2D
var flame: Sprite2D
var halo: Sprite2D
var source_light: PointLight2D
var light: PointLight2D
var swarm: ForestFireflies
var audio: AudioStreamPlayer2D
var foot := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foot = Vector2(float(data.foot_anchor[0]), float(data.foot_anchor[1]))
	phase = fposmod(position.x * 0.017 + position.y * 0.031 + float(str(data.id).hash() % 100), TAU)
	body = Sprite2D.new()
	body.centered = false
	body.position = -foot
	body.texture = load(str(data.path)) as Texture2D
	add_child(body)
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var source := Vector2(float(data.light_anchor[0]), float(data.light_anchor[1])) - foot
	if data.has("pendant"):
		pendant = Node2D.new()
		pendant.position = Vector2(float(data.pendant.pivot[0]), float(data.pendant.pivot[1])) - foot
		add_child(pendant)
		var fixture := Sprite2D.new()
		fixture.centered = false
		fixture.position = Vector2(float(data.pendant.offset[0]), float(data.pendant.offset[1]))
		fixture.texture = load(str(data.pendant.path)) as Texture2D
		pendant.add_child(fixture)
		glass = Sprite2D.new()
		glass.centered = false
		glass.position = fixture.position
		glass.texture = load(str(data.pendant.glass)) as Texture2D
		glass.material = emissive
		pendant.add_child(glass)
	else:
		glass = Sprite2D.new()
		glass.centered = false
		glass.position = -foot
		glass.texture = load(str(data.glass)) as Texture2D
		glass.material = emissive
		add_child(glass)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	halo = Sprite2D.new()
	halo.texture = FirePillar._make_glow_texture()
	halo.position = source
	halo.scale = Vector2.ONE * float(data.halo_scale)
	halo.material = additive
	add_child(halo)
	if float(data.flame_scale) > 0:
		flame = Sprite2D.new()
		flame.centered = false
		flame.texture = load("res://assets/vfx/blightwood_lights/spirit_flame_atlas.png") as Texture2D
		flame.hframes = 4
		flame.vframes = 3
		flame.material = emissive
		flame.scale = Vector2.ONE * float(data.flame_scale)
		flame.position = source - Vector2(64, 144) * float(data.flame_scale)
		add_child(flame)
		audio = AudioStreamPlayer2D.new()
		audio.stream = (load("res://assets/audio/ashen_fire/fire-bed.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
		(audio.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(audio.stream as AudioStreamWAV).loop_end = int(audio.stream.get_length() * 44100)
		audio.position = source
		audio.volume_db = -35.0
		audio.max_distance = 700.0
		add_child(audio)
	light = PointLight2D.new()
	light.texture = FirePillar._make_glow_texture()
	light.color = Color("#80baff")
	light.position = Vector2(source.x, -8)
	light.texture_scale = float(data.light_radius) / 32.0
	light.scale = Vector2(1.0, 0.55)
	light.range_z_min = -10
	light.range_z_max = 0
	add_child(light)
	source_light = PointLight2D.new()
	source_light.texture = light.texture
	source_light.color = Color("#9bc9ff")
	source_light.position = source
	source_light.texture_scale = 2.4
	source_light.range_z_min = 0
	source_light.range_z_max = 0
	add_child(source_light)
	swarm = ForestFireflies.new()
	swarm.position = source + Vector2(-12, 22)
	swarm.count = 12
	swarm.radius = Vector2(float(data.fly_radius[0]), float(data.fly_radius[1]))
	swarm.seed_value = int(position.x * 37 + position.y * 17 + str(data.id).hash())
	swarm.auto_advance = false
	add_child(swarm)
	set_process(auto_advance)
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta
	pulse = 0.82 + 0.10 * sin(clock * 7.31 + phase) + 0.045 * sin(clock * 19.83) + 0.035 * sin(clock * 29.17 + phase * 2.0)
	light.visible = lighting_on
	light.energy = float(data.light_energy) * pulse
	source_light.visible = lighting_on
	source_light.energy = 0.38 * pulse
	glass.modulate = Color(1, 1, 1, 0.65 + pulse * 0.35)
	halo.visible = lighting_on
	halo.modulate = Color(0.32, 0.60, 1.0, 0.27 * pulse)
	if pendant != null:
		pendant.rotation = (sin(clock * 1.67 + phase) * 0.025 + sin(clock * 3.19 + phase) * 0.008) if sway_on else 0.0
		var local_source := Vector2(float(data.light_anchor[0]), float(data.light_anchor[1])) - foot - pendant.position
		halo.position = pendant.position + local_source.rotated(pendant.rotation)
	source_light.position = halo.position
	if flame != null:
		flame.frame = (int(clock * 12.0) + int(phase * 2.0)) % 12
		flame.modulate = Color(1, 1, 1, 0.88 + pulse * 0.12)
	if audio != null:
		if sound_on and not audio.playing:
			audio.play(fposmod(phase, 3.8))
		elif not sound_on and audio.playing:
			audio.stop()
	swarm.enabled = fireflies_on
	swarm.advance(delta)
