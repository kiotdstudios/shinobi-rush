class_name AshenFireProp
extends Node2D
## Separate PixelLab fixture/flame/coals/smoke; bounded particles and event-synced sound.
const MANIFEST := "res://assets/environment/ashen_fire/ashen-fire.art.json"
static var pack: Dictionary = {}
static var spark_texture: ImageTexture
var data: Dictionary
var auto_advance := true
var sound_on := true
var smoke_on := true
var sparks_on := true
var light_on := true
var clock := 0.0
var pop_count := 0
var sound_events := 0
var flash := 0.0
var rng := RandomNumberGenerator.new()
var body: Sprite2D
var flame: Sprite2D
var coals: Sprite2D
var light: PointLight2D
var bed: AudioStreamPlayer2D
var pop_audio: AudioStreamPlayer2D
var spark_pool: Array[Dictionary] = []
var smoke_pool: Array[Dictionary] = []
var bowl := Vector2.ZERO
var next_pop := 1.0
var spark_credit := 0.0
var smoke_credit := 0.0
var phase := 0.0

func _ready() -> void:
	if pack.is_empty():
		pack = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.seed = int(position.x*37+position.y*17+str(data.id).hash())
	phase = rng.randf_range(0,TAU)
	next_pop = rng.randf_range(0.4,1.5)
	var foot := Vector2(float(data.foot_anchor[0]),float(data.foot_anchor[1]))
	bowl = Vector2(float(data.bowl_anchor[0]),float(data.bowl_anchor[1]))-foot
	body = Sprite2D.new()
	body.centered = false
	body.position = -foot
	body.texture = load(str(data.path)) as Texture2D
	add_child(body)
	coals = Sprite2D.new()
	coals.texture = load("res://assets/vfx/ashen_fire/coals.png") as Texture2D
	coals.position = bowl
	coals.scale = Vector2.ONE * float(data.flame_scale)*1.5
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	coals.material = emissive
	add_child(coals)
	light = PointLight2D.new()
	light.texture = FirePillar._make_glow_texture()
	light.color = Color(1.0,0.36,0.07)
	light.texture_scale = 4.5
	light.scale = Vector2(1.0,0.55)
	light.position = Vector2(0,-8)
	light.range_z_min = -10
	light.range_z_max = 0
	add_child(light)
	for i in 18:
		var puff := Sprite2D.new()
		puff.texture = load("res://assets/vfx/ashen_fire/smoke.png") as Texture2D
		puff.visible = false
		add_child(puff)
		smoke_pool.append({"sprite":puff,"age":99.0,"life":3.2,"origin":bowl,"drift":0.0,"phase":0.0})
	flame = Sprite2D.new()
	flame.centered = false
	flame.texture = load(str(pack.flame.path)) as Texture2D
	flame.hframes = 4
	flame.vframes = 3
	flame.scale = Vector2.ONE*float(data.flame_scale)
	flame.position = bowl-Vector2(64,144)*float(data.flame_scale)
	flame.material = emissive
	add_child(flame)
	if spark_texture == null:
		var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		spark_texture = ImageTexture.create_from_image(image)
	for i in 24:
		var spark := Sprite2D.new()
		spark.texture = spark_texture
		spark.material = emissive
		spark.visible = false
		add_child(spark)
		spark_pool.append({"sprite":spark,"age":99.0,"life":1.0,"velocity":Vector2.ZERO})
	bed = AudioStreamPlayer2D.new()
	var ambient := (load(str(pack.audio.ambient)) as AudioStreamWAV).duplicate() as AudioStreamWAV
	ambient.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambient.loop_begin = 0
	ambient.loop_end = int(ambient.get_length()*ambient.mix_rate)
	bed.stream = ambient
	bed.volume_db = -30.0
	bed.max_distance = 850.0
	bed.position = bowl
	add_child(bed)
	pop_audio = AudioStreamPlayer2D.new()
	pop_audio.max_polyphony = 3
	pop_audio.volume_db = -22.0
	pop_audio.max_distance = 850.0
	pop_audio.position = bowl
	add_child(pop_audio)
	for i in 8:
		_birth_smoke(smoke_pool[i])
		smoke_pool[i].age = float(i)*0.4
	set_process(auto_advance)
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

func set_sound_enabled(on: bool) -> void:
	sound_on = on
	if not on:
		bed.stop()
		pop_audio.stop()

func _birth_smoke(puff: Dictionary) -> void:
	puff.age = 0.0
	puff.origin = bowl+Vector2(rng.randf_range(-5,5),-80*float(data.flame_scale))
	puff.drift = rng.randf_range(-5,10)
	puff.phase = rng.randf_range(0,TAU)

func _birth_spark(burst := false) -> void:
	for p in spark_pool:
		if float(p.age)>=float(p.life):
			p.age = 0.0
			p.life = rng.randf_range(0.5,1.4)
			p.velocity = Vector2(rng.randf_range(-28,28),rng.randf_range(-105,-55) if burst else rng.randf_range(-65,-30))
			var sprite: Sprite2D = p.sprite
			sprite.position = bowl+Vector2(rng.randf_range(-10,10),-5)
			sprite.visible = true
			return

func _pop() -> void:
	pop_count += 1
	flash = 1.0
	if sparks_on:
		for i in 6:
			_birth_spark(true)
	if sound_on:
		pop_audio.stream = load(str(pack.audio.crackles[rng.randi_range(0,2)])) as AudioStream
		pop_audio.pitch_scale = rng.randf_range(0.87,1.13)
		pop_audio.play()
		sound_events += 1

func advance(delta: float) -> void:
	clock += delta
	flash = maxf(0,flash-delta*8.0)
	next_pop -= delta
	if next_pop<=0:
		_pop()
		next_pop = rng.randf_range(0.7,2.4)
	flame.frame = (int(clock*12.0)+int(phase*2.0))%12
	var pulse := 0.80+0.10*sin(clock*8.23+phase)+0.06*sin(clock*17.71+phase*2.0)+0.035*sin(clock*31.7)
	light.visible = light_on
	light.energy = pulse+flash*1.35
	coals.modulate = Color(0.8+flash*0.2,0.7+0.3*sin(clock*3.73+phase),0.6,1)
	flame.modulate = Color(1.0+flash*0.25,1.0+flash*0.25,1.0,1.0)
	if sound_on and not bed.playing:
		bed.play(fposmod(phase,3.8))
	spark_credit = minf(3.0,spark_credit+delta*3.0)
	if sparks_on and spark_credit>=1:
		spark_credit -= 1
		_birth_spark()
	smoke_credit = minf(3.0,smoke_credit+delta*2.4)
	for p in smoke_pool:
		if float(p.age)>=float(p.life) and smoke_on and smoke_credit>=1:
			smoke_credit -= 1
			_birth_smoke(p)
		p.age = float(p.age)+delta
		var sprite: Sprite2D = p.sprite
		var t := float(p.age)/float(p.life)
		sprite.visible = smoke_on and t<1.0
		if not sprite.visible:
			continue
		var age: float = p.age
		sprite.position = (p.origin as Vector2)+Vector2(float(p.drift)*age+(sin(age*2.2+float(p.phase))-sin(float(p.phase)))*9,-age*34)
		sprite.scale = Vector2.ONE*(0.25+t*0.65)*float(data.flame_scale)
		sprite.modulate = Color(0.85,0.85,0.85,minf(1.0,minf(t/0.1,(1-t)/0.35))*0.65)
	for p in spark_pool:
		p.age = float(p.age)+delta
		var sprite: Sprite2D = p.sprite
		var t := float(p.age)/float(p.life)
		sprite.visible = sparks_on and t<1.0
		if sprite.visible:
			p.velocity += Vector2(9,-8)*delta
			sprite.position += (p.velocity as Vector2)*delta
			sprite.modulate = Color(1.0,lerpf(0.95,0.18,t),0.05,(1.0-t)*0.9)
