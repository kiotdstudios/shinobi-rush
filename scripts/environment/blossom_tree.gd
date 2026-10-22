class_name BlossomTree
extends Node2D
var data: Dictionary
var sprite: Sprite2D
var foliage: FallingFoliage
var wind: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var anchor := Vector2(float(data.anchor[0]), float(data.anchor[1]))
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.position = -anchor
	sprite.texture = load(str(data.texture)) as Texture2D
	wind = ShaderMaterial.new()
	wind.shader = load("res://scripts/environment/blossom_wind.gdshader") as Shader
	wind.set_shader_parameter("phase_offset", float(data.wind_phase))
	wind.set_shader_parameter("strength", float(data.wind_strength))
	wind.set_shader_parameter("anchor_y", anchor.y)
	sprite.material = wind
	add_child(sprite)
	foliage = FallingFoliage.new()
	foliage.configure(data.canopy_emission, int(position.x * 13 + position.y * 7) + 4519)
	add_child(foliage)

func advance(clock: float, delta: float, wind_on: bool, leaves_on: bool) -> void:
	wind.set_shader_parameter("wind_clock", clock)
	wind.set_shader_parameter("wind_enabled", wind_on)
	foliage.visible = leaves_on
	foliage.emitting = leaves_on
	# Existing particles keep a valid bounded lifecycle even when hidden.
	foliage.advance(delta)
