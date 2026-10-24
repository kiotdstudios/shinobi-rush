class_name FallingFoliage
extends Node2D
## Independent, bounded emitter. Tree pixels never contain falling particles.
const MAX_PARTICLES := 24
const TEXTURES := ["res://assets/vfx/falling_foliage/petal_tumble.png", "res://assets/vfx/falling_foliage/leaf_tumble.png"]
var emitting := true
var spawn_rate := 1.8
var sources: Array = []
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var spawned := 0
var _credit := 0.0
var _textures: Array[Texture2D] = []

func configure(points: Array, seed_value: int) -> void:
	sources = points
	rng.seed = seed_value

func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for path: String in TEXTURES:
		_textures.append(load(path) as Texture2D)
	for i in MAX_PARTICLES:
		var sprite := Sprite2D.new()
		sprite.texture = _textures[i % 2]
		sprite.hframes = 4
		sprite.vframes = 4
		sprite.visible = false
		add_child(sprite)
		particles.append({"sprite": sprite, "active": false})
	# Populate ages so the grove already has falling foliage on arrival.
	for i in 12:
		_birth(particles[i])
		particles[i].age = rng.randf_range(0, float(particles[i].life) * 0.9)
	advance(0)

func _birth(p: Dictionary) -> void:
	if sources.is_empty():
		return
	var point: Array = sources[rng.randi_range(0, sources.size() - 1)]
	p.active = true
	p.age = 0.0
	p.life = rng.randf_range(6.0, 10.0)
	p.origin = Vector2(float(point[0]), float(point[1]))
	p.drift = rng.randf_range(3.0, 10.0)
	p.sway = rng.randf_range(9.0, 23.0)
	p.phase = rng.randf_range(0.0, TAU)
	p.turn_fps = rng.randf_range(3.5, 7.0)
	p.ground = rng.randf_range(-6.0, 6.0)
	var sprite: Sprite2D = p.sprite
	sprite.scale = Vector2.ONE * rng.randf_range(0.8, 1.15)
	sprite.visible = true
	spawned += 1

func advance(delta: float) -> void:
	if emitting:
		_credit = minf(_credit + delta * spawn_rate, 3.0)
	for p: Dictionary in particles:
		if not bool(p.active):
			if emitting and _credit >= 1.0:
				_credit -= 1.0
				_birth(p)
			else:
				continue
		p.age = float(p.age) + delta
		var t := float(p.age) / float(p.life)
		var sprite: Sprite2D = p.sprite
		if t >= 1.0:
			p.active = false
			sprite.visible = false
			continue
		var origin: Vector2 = p.origin
		var flutter := sin(float(p.age) * 1.7 + float(p.phase)) - sin(float(p.phase))
		sprite.position = origin + Vector2(float(p.drift) * float(p.age) + flutter * float(p.sway), (float(p.ground) - origin.y) * (t * 0.82 + t * t * 0.18))
		sprite.frame = int(float(p.age) * float(p.turn_fps) + float(p.phase) * 2.0) % 16
		sprite.rotation = sin(float(p.age) * 1.2 + float(p.phase)) * 0.18
		sprite.modulate.a = clampf((1.0 - t) / 0.14, 0.0, 1.0)

func active_count() -> int:
	var count := 0
	for p: Dictionary in particles:
		if bool(p.active):
			count += 1
	return count
