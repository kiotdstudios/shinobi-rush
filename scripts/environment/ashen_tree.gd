class_name AshenTree
extends Node2D
## Standalone art component. Caller owns clock; no map, AI or camera dependencies.
const MAX_ASH := 24
var data: Dictionary
var sprite: Sprite2D
var material_wind: ShaderMaterial
var flakes: Array[Sprite2D] = []
var ash_clock_offset := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.position = -Vector2(float(data.anchor[0]), float(data.anchor[1]))
	sprite.texture = load(str(data.texture)) as Texture2D
	material_wind = ShaderMaterial.new()
	material_wind.shader = load("res://scripts/environment/ashen_wind.gdshader") as Shader
	material_wind.set_shader_parameter("phase", float(data.wind_phase))
	material_wind.set_shader_parameter("strength", float(data.wind_strength))
	sprite.material = material_wind
	add_child(sprite)
	var ash := load("res://assets/vfx/ashen_foliage/ash_tumble.png") as Texture2D
	for i in MAX_ASH:
		var flake := Sprite2D.new()
		flake.texture = ash
		flake.hframes = 4
		flake.vframes = 4
		flake.scale = Vector2.ONE * (0.50 + float(i % 5) * 0.035)
		add_child(flake)
		flakes.append(flake)
	advance(0.0)

func advance(time: float, wind_on := true, ash_on := true, heat_on := true) -> void:
	material_wind.set_shader_parameter("clock", time)
	material_wind.set_shader_parameter("wind_on", wind_on)
	material_wind.set_shader_parameter("heat_on", heat_on)
	for i in flakes.size():
		var flake := flakes[i]
		flake.visible = ash_on
		var phase := float(i) * 2.39996 + float(data.wind_phase)
		var age := fposmod(time + float(i) * 8.0 / MAX_ASH + float(data.wind_phase), 8.0)
		var t := age / 8.0
		var point: Array = data.ash_emission[i % data.ash_emission.size()]
		var origin := Vector2(float(point[0]), float(point[1]))
		var curl := (sin(age * 1.7 + phase) - sin(phase)) * (9.0 + float(i % 5) * 2.0)
		flake.position = origin + Vector2(age * (2.0 + float(i % 4)) + curl, -origin.y * (t * 0.82 + t * t * 0.18))
		flake.frame = (int(age * 6.0) + i) % 16
		flake.rotation = 0.0 # Authored tumble poses retain sharp native clusters.
		flake.modulate.a = minf(clampf(t / 0.10, 0.0, 1.0), clampf((1.0-t) / 0.14, 0.0, 1.0))
