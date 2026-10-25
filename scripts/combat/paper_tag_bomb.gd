class_name PaperTagBomb
extends Node2D
## The player's thrown paper tag (explosive note). Life of one tag, all measured from the moment it leaves the hand:
##   FLY     the tag spins along an arc (fly_NN frames) for up to FLIGHT_TIME, over at most MAX_RANGE. It lands early
##           on a wall or the first "enemy" it touches, so it sticks where it hits.
##   ARMED   it lies on the floor (armed_NN frames, ink pulsing orange, blinking faster as the fuse runs out).
##   BLAST   at FUSE seconds it explodes: 60-frame 30 fps pixel-art blast (assets/effects/paper_tag_blast/) with an
##           additive light layer, a scorch mark that fades, a camera kick and a synthesized boom. Everything inside
##           BLAST_RADIUS (floor distance, y doubled for the 2:1 iso floor) takes damage that fades toward the edge.
## FUSE is the one number to tweak for the "explodes after N seconds" feel.

const FUSE := 1.66  ## seconds from release to detonation
const FLIGHT_TIME := 0.46
const MAX_RANGE := 300.0
const ARC_HEIGHT := 70.0
const HAND_LIFT := 44.0  ## hand height the tag leaves from
const TOUCH_RADIUS := 26.0
const FLY_FPS := 40.0
const BLAST_FPS := 30.0
const BLAST_FRAMES := 60
const GLOW_BOOST := 1.0
const BLAST_ORIGIN := Vector2(192, 282)  ## ground centre of the blast canvas (384 x 384)
const BLAST_RADIUS := 150.0
const DAMAGE := 45.0
const KNOCKBACK := 420.0
const HITSTOP_MS := 90.0
const DAMAGE_FRAME := 3  ## blast frame (the white-hot flash) at which the damage lands
const SCORCH_SECONDS := 6.0
const DIR := "res://assets/pickups/paper_tag/"
const BLAST_DIR := "res://assets/effects/paper_tag_blast/"
const SOUND_RATE := 22050

enum Phase { FLY, ARMED, BLAST, DONE }

static var _cache: Dictionary = {}
static var _sound: AudioStreamWAV = null

var art_kind := ""  ## empty preserves the original flat paper tag
var dir: Vector2 = Vector2.RIGHT
var thrower: Node2D = null
var phase: Phase = Phase.FLY
var age := 0.0  ## seconds since release
var travelled := 0.0
var landed_on := ""  ## "", "range", "wall", "enemy" (read by tests)
var damaged: Array[Node2D] = []  ## enemies the blast hurt (read by tests)
var blast_t := 0.0
var detonated := false

var _body: Sprite2D
var _shadow: Node2D
var _halo: Node2D
var _blast: Sprite2D
var _glow: Sprite2D
var _audio: AudioStreamPlayer
var _start := Vector2.ZERO
var _hit_done := false
var _flight_len := MAX_RANGE


static func spawn(parent: Node, from: Vector2, aim: Vector2, who: Node2D, item_art := "") -> PaperTagBomb:
	if parent == null:
		return null
	warm()
	var b := PaperTagBomb.new()
	b.dir = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	b.thrower = who
	b.art_kind = item_art
	parent.add_child(b)
	b.global_position = from
	b._start = from
	return b


## Every frame of a layer ("fly", "armed", "blast", "glow"), loaded once and shared.
static func frames(layer: String) -> Array:
	if _cache.has(layer):
		return _cache[layer]
	var base := BLAST_DIR if layer == "blast" or layer == "glow" else DIR
	var list: Array = []
	var i := 0
	while ResourceLoader.exists(base + "%s_%02d.png" % [layer, i]):
		list.append(load(base + "%s_%02d.png" % [layer, i]))
		i += 1
	_cache[layer] = list
	return list


## Ask the loader to read the 120 blast frames on a worker thread while the tag is still in the air.
static func warm() -> void:
	if _cache.has("blast"):
		return
	for layer: String in ["blast", "glow"]:
		for i in BLAST_FRAMES:
			var p := BLAST_DIR + "%s_%02d.png" % [layer, i]
			if ResourceLoader.exists(p):
				ResourceLoader.load_threaded_request(p)


func body_frames(layer: String) -> Array:
	return frames(layer) if art_kind.is_empty() else TagBombArt.frames(art_kind, layer)


func _ready() -> void:
	_shadow = Node2D.new()
	_shadow.name = "Shadow"
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_halo = Node2D.new()
	_halo.name = "Halo"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = add
	_halo.draw.connect(_draw_halo)
	add_child(_halo)
	_body = Sprite2D.new()
	_body.name = "Tag"
	if not art_kind.is_empty():
		_body.scale = Vector2.ONE * 0.5
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)
	if not body_frames("fly").is_empty():
		_body.texture = body_frames("fly")[0]
	_body.position = Vector2(0, -HAND_LIFT)
	z_index = 5


func _physics_process(delta: float) -> void:
	advance(delta)


## Moves the tag's clock forward (tests call this with a fixed step).
func advance(delta: float) -> void:
	if phase == Phase.DONE:
		return
	age += delta
	match phase:
		Phase.FLY:
			_step_fly(delta)
		Phase.ARMED:
			pass
		Phase.BLAST:
			_step_blast(delta)
	if phase != Phase.BLAST and phase != Phase.DONE and age >= FUSE:
		explode()
	_refresh_visual()


func _step_fly(delta: float) -> void:
	var speed := _flight_len / FLIGHT_TIME
	var a := global_position
	var b := a + dir * speed * delta
	var seg := b - a
	if is_inside_tree():
		for e: Node in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D) or e == thrower:
				continue
			var t := 0.0
			if seg.length_squared() > 0.0001:
				t = clampf(((e as Node2D).global_position - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
			if (a + seg * t).distance_to((e as Node2D).global_position) <= TOUCH_RADIUS:
				global_position = a + seg * t
				_land("enemy")
				return
		var q := PhysicsRayQueryParameters2D.create(a + Vector2(0, -14), b + Vector2(0, -14))
		var ex: Array[RID] = []
		if is_instance_valid(thrower) and thrower is CollisionObject2D:
			ex.append((thrower as CollisionObject2D).get_rid())
		q.exclude = ex
		if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			_land("wall")
			return
	global_position = b
	travelled += seg.length()
	if age >= FLIGHT_TIME or travelled >= _flight_len:
		_land("range")


func _land(how: String) -> void:
	landed_on = how
	phase = Phase.ARMED


## Detonate now (the fuse calls this; tests may too).
func explode() -> void:
	if detonated:
		return
	detonated = true
	phase = Phase.BLAST
	blast_t = 0.0
	_body.visible = false
	_halo.visible = false
	_shadow.visible = false
	var bl := frames("blast")
	var gl := frames("glow")
	_glow = Sprite2D.new()
	_glow.name = "BlastGlow"
	_glow.centered = false
	_glow.offset = -BLAST_ORIGIN
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.z_index = 9
	if not gl.is_empty():
		_glow.texture = gl[0]
	add_child(_glow)
	_blast = Sprite2D.new()
	_blast.name = "Blast"
	_blast.centered = false
	_blast.offset = -BLAST_ORIGIN
	_blast.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blast.z_index = 10
	if not bl.is_empty():
		_blast.texture = bl[0]
	add_child(_blast)
	_spawn_scorch()
	if is_inside_tree():
		CameraImpact.impulse(Vector2.DOWN, 9.0, 420.0)
		_audio = AudioStreamPlayer.new()
		_audio.name = "BoomSound"
		_audio.stream = boom_sound()
		_audio.volume_db = -3.0
		add_child(_audio)
		if not DisplayServer.get_name() == "headless":
			_audio.play()


func _spawn_scorch() -> void:
	var p := get_parent()
	if p == null:
		return
	var tex: Texture2D = load(BLAST_DIR + "scorch.png") if ResourceLoader.exists(BLAST_DIR + "scorch.png") else null
	if tex == null:
		return
	var s := Sprite2D.new()
	s.name = "TagScorch"
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = -1
	p.add_child(s)
	s.global_position = global_position
	var tw := s.create_tween()
	tw.tween_interval(SCORCH_SECONDS * 0.4)
	tw.tween_property(s, "modulate:a", 0.0, SCORCH_SECONDS * 0.6)
	tw.tween_callback(s.queue_free)


func _step_blast(delta: float) -> void:
	blast_t += delta
	var frame := int(blast_t * BLAST_FPS)
	if not _hit_done and frame >= DAMAGE_FRAME:
		_hit_done = true
		apply_damage()
	if frame >= BLAST_FRAMES:
		phase = Phase.DONE
		queue_free()


## Hurt every enemy inside the blast; damage and knockback fade toward the edge (never below 40%).
func apply_damage() -> void:
	if not is_inside_tree():
		return
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or e == thrower or not e.has_method("take_damage"):
			continue
		var d: Vector2 = (e as Node2D).global_position - global_position
		var r := Vector2(d.x, d.y * 2.0).length()
		if r > BLAST_RADIUS:
			continue
		var k := lerpf(1.0, 0.4, r / BLAST_RADIUS)
		var away := d.normalized() if d.length() > 1.0 else dir
		e.call("take_damage", DAMAGE * k, away, KNOCKBACK * k, HITSTOP_MS)
		damaged.append(e as Node2D)


func _refresh_visual() -> void:
	if _body == null:
		return
	match phase:
		Phase.FLY:
			var fl := body_frames("fly")
			var u := clampf(age / FLIGHT_TIME, 0.0, 1.0)
			if not fl.is_empty():
				_body.texture = fl[int(age * FLY_FPS) % fl.size()]
			_body.position = Vector2(0, -HAND_LIFT - sin(u * PI) * ARC_HEIGHT)
			_shadow.queue_redraw()
		Phase.ARMED:
			var ar := body_frames("armed")
			var left := maxf(FUSE - age, 0.0)
			var rate := lerpf(8.0, 30.0, 1.0 - clampf(left / maxf(FUSE - FLIGHT_TIME, 0.1), 0.0, 1.0))
			if not ar.is_empty():
				_body.texture = ar[int(age * rate) % ar.size()]
			_body.position = Vector2(0, -24 if not art_kind.is_empty() else -4)
			_shadow.queue_redraw()
			_halo.queue_redraw()
		Phase.BLAST:
			var f := clampi(int(blast_t * BLAST_FPS), 0, BLAST_FRAMES - 1)
			var bl := frames("blast")
			var gl := frames("glow")
			if f < bl.size():
				_blast.texture = bl[f]
			if f < gl.size():
				_glow.texture = gl[f]
				_glow.modulate = Color(GLOW_BOOST, GLOW_BOOST, GLOW_BOOST, 1.0)


func _draw_shadow() -> void:
	var u := clampf(age / FLIGHT_TIME, 0.0, 1.0)
	var lift := sin(u * PI) if phase == Phase.FLY else 0.0
	var w := lerpf(15.0, 9.0, lift)
	_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	_shadow.draw_circle(Vector2.ZERO, w, Color(0, 0, 0, lerpf(0.4, 0.2, lift)))


func _draw_halo() -> void:
	var left := maxf(FUSE - age, 0.0)
	var urgency := 1.0 - clampf(left / maxf(FUSE - FLIGHT_TIME, 0.1), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(age * lerpf(10.0, 38.0, urgency))
	_halo.draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, 0.5))
	for i in 4:
		var r := lerpf(14.0, 46.0, float(i) / 3.0) * (0.85 + 0.25 * pulse + 0.3 * urgency)
		_halo.draw_circle(Vector2.ZERO, r, Color(1.0, 0.45, 0.08, (0.14 + 0.1 * pulse + 0.12 * urgency) * (1.0 - float(i) * 0.2)))


# ---------------------------------------------------------------- sound
## 1.5 s boom: a hard noise crack, a low sine sweeping 110 to 38 Hz, a rumbling low-passed noise tail and debris crackle.
static func boom_sound() -> AudioStreamWAV:
	if _sound != null:
		return _sound
	var secs := 1.5
	var n := int(SOUND_RATE * secs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1666
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	var phase_acc := 0.0
	var mix := PackedFloat32Array()
	mix.resize(n)
	var peak := 0.001
	for i in n:
		var s := float(i) / SOUND_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.16
		lp2 += (lp - lp2) * 0.05
		var crack := noise * exp(-s * 38.0) * 0.9
		var f := lerpf(110.0, 38.0, 1.0 - exp(-s * 5.0))
		phase_acc += TAU * f / SOUND_RATE
		var sub := sin(phase_acc) * exp(-s * 2.6) * 1.1
		var rumble := lp2 * 5.0 * exp(-s * 3.0)
		var crackle := 0.0
		if rng.randf() < 0.012 * exp(-s * 2.5):
			crackle = rng.randf_range(-1.0, 1.0) * 0.8
		var v := crack + sub + rumble + crackle
		mix[i] = v
		peak = maxf(peak, absf(v))
	for i in n:
		var fade := minf(float(n - i) / (0.05 * SOUND_RATE), 1.0)
		var x := tanh(mix[i] / peak * 1.6) * 0.85 * fade
		data.encode_s16(i * 2, clampi(int(x * 32000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SOUND_RATE
	w.stereo = false
	w.data = data
	_sound = w
	return w
