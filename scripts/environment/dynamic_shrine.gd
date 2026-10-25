class_name DynamicShrine
extends Node2D
## PixelLab-authored landmark. Stone stays fixed; foliage and light are independent.
const DIR := "res://assets/environment/blightwood_dynamic_shrine/"
const FOOT := Vector2(272, 448)
var auto_advance := true
var clock := 0.0
var lighting_on := true
var vines_on := true
var fireflies_on := true
var rays_on := true
var pulse := 1.0
var body: Sprite2D
var emission: Sprite2D
var foliage: Array[Sprite2D] = []
var swarms: Array[ForestFireflies] = []
var halo: Sprite2D
var rays: Polygon2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body = _sprite("stone.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	emission = _sprite("emission.png")
	emission.material = add
	for i in 4:
		var vine := _sprite("vine_%02d.png" % i)
		var sway := ShaderMaterial.new()
		sway.shader = load("res://scripts/environment/shrine_vines.gdshader") as Shader
		sway.set_shader_parameter("phase",i*1.7)
		sway.set_shader_parameter("top",float([67,105,114,145][i])/480.0)
		sway.set_shader_parameter("bottom",float([121,153,176,179][i])/480.0)
		vine.material = sway
		foliage.append(vine)
	var glow := FirePillar._make_glow_texture()
	halo = Sprite2D.new()
	halo.texture = glow
	halo.material = add
	halo.position = Vector2(9, -272)
	halo.scale = Vector2(3.6, 2.8)
	add_child(halo)
	rays = Polygon2D.new()
	rays.polygon = PackedVector2Array([Vector2(-125,-425), Vector2(-85,-425), Vector2(130,-20), Vector2(-20,-20)])
	rays.uv = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	var ray_material := ShaderMaterial.new()
	ray_material.shader = load("res://scripts/environment/shrine_rays.gdshader") as Shader
	rays.material = ray_material
	rays.z_index = 1
	add_child(rays)
	for i in 3:
		var swarm := ForestFireflies.new()
		swarm.name = "ShrineFireflies%d" % (i+1)
		swarm.auto_advance = false
		swarm.count = 14
		swarm.seed_value = 241240 + i*101
		swarm.radius = Vector2(74,62)
		swarm.position = [Vector2(-135,-190),Vector2(125,-180),Vector2(5,-62)][i]
		add_child(swarm)
		swarms.append(swarm)
	set_process(auto_advance)
	advance(0.0)

func _sprite(file: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DIR + file) as Texture2D
	sprite.centered = false
	sprite.position = -FOOT
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta
	# Twelve second breath: gentle, no flashing or whole-body modulation.
	pulse = 0.5 + 0.5*sin(TAU*clock/12.0)
	emission.visible = lighting_on
	emission.modulate = Color(1.0,0.75,0.5,0.18+0.30*pulse)
	halo.visible = lighting_on
	halo.modulate = Color(0.6,0.15,0.045,0.10+0.10*pulse)
	for i in foliage.size():
		# Native-pixel bending increases toward the tip, roots stay registered.
		var sway := foliage[i].material as ShaderMaterial
		sway.set_shader_parameter("motion_time",clock if vines_on else -float(i)*1.7/(TAU/8.0))
	for swarm in swarms:
		swarm.enabled = fireflies_on
		swarm.advance(delta)
	rays.visible = rays_on
	(rays.material as ShaderMaterial).set_shader_parameter("motion_time",clock)
