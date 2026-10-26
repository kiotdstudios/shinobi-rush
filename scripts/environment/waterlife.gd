class_name Waterlife
extends Node2D
## Presentation only. Reads real displacement and existing water eligibility; never drives the player.
const ART := "res://assets/environment/blightwood_waterlife/"
const POOL_SIZE := 32
const RARITY := 1000000
const REARM_DRY_SECONDS := 10.0
var actor: PlayerController
var auto_advance := true
var clock := 0.0
var emissions := 0
var rolls := 0
var visits := 0
var frog_spawns := 0
var armed := true
var dry_time := REARM_DRY_SECONDS
var pool: Array[Dictionary] = []
var plants: Array[Node2D] = []
var frogs: Array[Node2D] = []
var aura: Array[Sprite2D] = []
var rng := RandomNumberGenerator.new()
var _last := Vector2.ZERO
var _have_last := false
var _stride := 0.0
var _foot := 0
var _plant_scan := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	rng.randomize()
	for i in POOL_SIZE:
		var sprite := atlas("splash.png", 4, 4)
		sprite.visible = false
		sprite.z_index = 0
		pool.append({"sprite":sprite,"age":99.0,"life":0.8,"scale":0.42})
	for i in 2:
		var sprite := atlas("feet-chakra.png", 4, 4)
		sprite.visible = false
		sprite.z_index = 3
		sprite.scale = Vector2.ONE * 0.22
		aura.append(sprite)

func atlas(file: String, cols: int, rows: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + file) as Texture2D
	sprite.hframes = cols
	sprite.vframes = rows
	sprite.offset = Vector2(0,-32)
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	if not auto_advance or MapEditorMode.active():return
	if not is_instance_valid(actor):
		actor = get_tree().get_first_node_in_group("player") as PlayerController
	advance(delta)
	if actor == null:return
	# Water rule includes bridges. Suppress emissions in the air and during death/teleports.
	var wet := actor.over_water and not actor.dying and actor.chakra > 0.0 and actor.get_state_name() not in ["JUMP","AIR_ATTACK"]
	observe(actor.global_position, wet, delta)
	_plant_scan += delta
	if _plant_scan >= 1.0:
		_plant_scan = 0.0
		populate_plants()

func observe(foot: Vector2, wet: bool, delta: float) -> void:
	var movement := foot - _last if _have_last else Vector2.ZERO
	_last = foot
	_have_last = true
	var moving := movement.length() > 0.2 and movement.length() < 70.0
	for i in aura.size():
		aura[i].visible = wet
		var across := Vector2(6,1) if absf(movement.x) < absf(movement.y) else Vector2(3,3)
		var offset := across * (-1.0 if i == 0 else 1.0)
		aura[i].global_position = (foot + offset + Vector2(0,-2)).round()
		aura[i].frame = (int(clock * 24.0) + i * 7) % 16
		aura[i].modulate.a = 0.85 if moving else 0.5
	if not wet:
		dry_time += delta
		if dry_time >= REARM_DRY_SECONDS:armed = true
		_stride = 0.0
		return
	if armed:
		# One eligible continuous water visit; dry land must last ten seconds to rearm.
		var destination := nearby_lily(foot)
		if destination != null:
			armed = false
			visits += 1
			rolls += 1
			if wins_roll(rng.randi_range(0,RARITY-1)):
				spawn_frog(destination.global_position)
	dry_time = 0.0
	if not moving:
		_stride = 0.0
		return
	_stride += movement.length()
	if _stride >= 32.0:
		_stride = fmod(_stride,32.0)
		_foot = 1 - _foot
		var side := Vector2(-movement.y,movement.x).normalized() * (4.0 if _foot == 0 else -4.0)
		emit_splash((foot + side).round(),0.32,0.72)

static func wins_roll(value: int) -> bool:
	return value == 0

func emit_splash(foot: Vector2, effect_scale: float = 0.42, life: float = 0.72) -> void:
	var slot := emissions % POOL_SIZE
	emissions += 1
	pool[slot]["age"] = 0.0
	pool[slot]["life"] = life
	pool[slot]["scale"] = effect_scale
	var sprite: Sprite2D = pool[slot]["sprite"]
	sprite.global_position = foot
	sprite.scale = Vector2.ONE * effect_scale
	sprite.frame = 0
	sprite.visible = true
	sprite.modulate.a = 1.0

func advance(delta: float) -> void:
	clock += delta
	for entry in pool:
		entry["age"] += delta
		var t: float = entry["age"] / entry["life"]
		var sprite: Sprite2D = entry["sprite"]
		sprite.visible = t < 1.0
		if sprite.visible:
			sprite.frame = mini(int(t * 16.0),15)
			sprite.modulate.a = 1.0 - smoothstep(0.65,1.0,t)
	for plant in plants:
		var phase: float = plant.get_meta("phase")
		var base: Vector2 = plant.get_meta("base")
		plant.global_position = (base + Vector2(sin(clock*0.7+phase)*0.7,sin(clock*1.1+phase)*0.65)).round()
		plant.rotation = sin(clock*0.8+phase)*0.018
	for i in range(frogs.size()-1,-1,-1):
		var frog := frogs[i]
		if not is_instance_valid(frog):frogs.remove_at(i);continue
		frog.advance(delta)
		if frog.age >= 4.8:
			frogs.remove_at(i)
			frog.queue_free()

func add_plant(foot: Vector2, variant: int, phase: float = 0.0) -> Node2D:
	var plant := Sprite2D.new()
	plant.texture = load(ART + "plants.png")
	plant.hframes = 3
	plant.vframes = 2
	plant.frame = clampi(variant,0,5)
	plant.z_index = 0
	add_child(plant)
	plant.global_position = foot.round()
	plant.set_meta("base",foot.round())
	plant.set_meta("phase",phase)
	plants.append(plant)
	return plant

func populate_plants() -> void:
	for i in range(plants.size()-1,-1,-1):
		if not BlightwoodWater.over_water(get_tree(),plants[i].global_position):
			plants[i].queue_free()
			plants.remove_at(i)
	if actor == null or plants.size() >= 12:return
	for tile: Node in get_tree().get_nodes_in_group("open_water"):
		var foot := (tile as Node2D).global_position
		if foot.distance_to(actor.global_position) > 450.0:continue
		if not BlightwoodWater.over_water(get_tree(),foot):continue
		var seed_value := absi(int(foot.x)*73856093 ^ int(foot.y)*19349663)
		if seed_value % 7 != 0:continue
		var exists := false
		for plant in plants:
			if (plant.get_meta("base") as Vector2).distance_to(foot)<65.0:exists=true;break
		if exists:continue
		add_plant(foot,seed_value%6,float(seed_value%100)*0.1)
		if plants.size()>=12:break

func nearby_lily(foot: Vector2) -> Node2D:
	for plant in plants:
		if plant.frame < 3 and plant.global_position.distance_to(foot) <= 240.0 and BlightwoodWater.over_water(get_tree(),plant.global_position):return plant
	return null

func spawn_frog(foot: Vector2) -> Node2D:
	var frog := load("res://scripts/environment/waterlife_frog.gd").new() as Node2D
	frog.set("host",self)
	add_child(frog)
	frog.global_position = foot.round()
	frogs.append(frog)
	frog_spawns += 1
	return frog
