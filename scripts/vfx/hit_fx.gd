class_name HitFx
extends Node2D
## Swing + contact feedback, driven ONLY by the attacker's reusable events (`attack_event`, `attack_hit`):
##  * slash arc  -- drawn from the SAME reach / half-angle / facing the hit test uses, so what you see is the hitbox;
##  * contact sparks + bright impact silhouette at the HitEvent point;
##  * short synthesized swing / hit audio (no audio assets exist yet; swap for authored clips later).
## The node is top_level so spawned effects stay in the world while the attacker moves on. All effects are
## procedural and free themselves; counters below exist for tests and diagnostics.

const ARC_LIFE := 0.11
const SPARK_LIFE := 0.16
const SILHOUETTE_LIFE := 0.09
const MAX_LIVE := 24
const AUDIO_RATE := 22050

var arcs_spawned: int = 0
var sparks_spawned: int = 0
var silhouettes_spawned: int = 0
var sounds_played: int = 0
var last_arc: Dictionary = {}  ## {"attack_id","reach","half_angle_deg","facing"} of the newest slash arc
var last_hit: HitEvent = null
var audio_enabled: bool = true

var _player: Node2D = null
var _live: int = 0
var _swing_sounds: Array[AudioStreamWAV] = []
var _hit_sounds: Array[AudioStreamWAV] = []
var _audio: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	z_index = 20
	_rng.randomize()


func bind(attacker: Node) -> void:
	_player = attacker as Node2D
	attacker.attack_event.connect(_on_attack_event)
	attacker.attack_hit.connect(_on_attack_hit)


func _on_attack_event(event_name: String, attack_id: String) -> void:
	if event_name == "active":
		spawn_slash_arc(attack_id)
	elif event_name == "startup":
		_play(_get_sound(false, attack_id == "light3" or attack_id == "dash_attack"), -9.0)


func spawn_slash_arc(attack_id: String) -> void:
	if _player == null or _live >= MAX_LIVE:
		return
	var table: Dictionary = _player._attack_table
	if not table.has(attack_id):
		return
	var def: AttackDef = table[attack_id]
	var facing: Vector2 = _player.facing8
	last_arc = {"attack_id": attack_id, "reach": def.reach, "half_angle_deg": def.arc_half_angle_deg, "facing": facing}
	arcs_spawned += 1
	var arc := _SlashArc.new()
	arc.setup(def.reach, deg_to_rad(def.arc_half_angle_deg), facing, def.heavy, ARC_LIFE)
	arc.global_position = _player.global_position
	_add_fx(arc)


func _on_attack_hit(hit: HitEvent) -> void:
	last_hit = hit
	spawn_contact(hit)


func spawn_contact(hit: HitEvent) -> void:
	if _live >= MAX_LIVE:
		return
	var spark := _Sparks.new()
	spark.setup(hit.direction, hit.heavy, SPARK_LIFE, _rng.randi())
	spark.global_position = hit.position
	_add_fx(spark)
	sparks_spawned += 1
	var sil := _Silhouette.new()
	sil.setup(hit.direction, hit.heavy, SILHOUETTE_LIFE)
	sil.global_position = hit.position
	_add_fx(sil)
	silhouettes_spawned += 1
	_play(_get_sound(true, hit.heavy), -3.0 if hit.heavy else -6.0)


func _add_fx(n: Node2D) -> void:
	add_child(n)
	_live += 1
	n.tree_exited.connect(_on_fx_exited)


func _on_fx_exited() -> void:
	_live = maxi(_live - 1, 0)


# ---------------------------------------------------------------- audio (synthesized)
func _play(stream: AudioStreamWAV, volume_db: float) -> void:
	if not audio_enabled or stream == null or not is_inside_tree():
		return
	if _audio == null:
		_audio = AudioStreamPlayer.new()
		_audio.name = "HitAudio"
		add_child(_audio)
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.play()
	sounds_played += 1


func _get_sound(is_hit: bool, heavy: Variant) -> AudioStreamWAV:
	var pool := _hit_sounds if is_hit else _swing_sounds
	if pool.is_empty():
		for i in 2:
			pool.append(_synth(is_hit, i == 1))
	return pool[1 if heavy else 0]


## Tiny procedural clips: swing = band-passed noise whoosh; hit = noise click + falling thump.
func _synth(is_hit: bool, heavy: bool) -> AudioStreamWAV:
	var dur := (0.14 if heavy else 0.10) if is_hit else (0.16 if heavy else 0.11)
	var n := int(dur * AUDIO_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + int(is_hit) * 7 + int(heavy) * 3
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / AUDIO_RATE
		var k := float(i) / float(n)
		var v := 0.0
		if is_hit:
			var env := exp(-k * 7.0)
			phase += TAU * lerpf(190.0 if heavy else 240.0, 70.0, k) / AUDIO_RATE
			v = sin(phase) * env * 0.7 + (rng.randf() * 2.0 - 1.0) * exp(-k * 28.0) * 0.6
		else:
			var env := sin(PI * k) * (1.0 - k * 0.4)
			lp += ((rng.randf() * 2.0 - 1.0) - lp) * lerpf(0.55, 0.18, k)
			v = lp * env * 0.9
		var s := clampi(int(v * 32000.0), -32768, 32767)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = AUDIO_RATE
	w.stereo = false
	w.data = data
	return w


# ---------------------------------------------------------------- effect nodes
class _SlashArc extends Node2D:
	var reach := 100.0
	var half := 0.7
	var heading := 0.0
	var heavy := false
	var life := 0.1
	var age := 0.0

	func setup(p_reach: float, p_half: float, facing: Vector2, p_heavy: bool, p_life: float) -> void:
		reach = p_reach
		half = p_half
		heading = facing.angle()
		heavy = p_heavy
		life = p_life
		top_level = true

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var k := clampf(age / life, 0.0, 1.0)
		var a := 1.0 - k
		# Crescent: an outer edge at the exact hit reach, an inner edge sweeping out with time.
		var inner := reach * lerpf(0.55, 0.86, k)
		var center := Vector2(0.0, -WorldScale.FOOTPRINT.y * 0.5)  # swing happens around the body, not the feet
		var steps := 14
		var pts := PackedVector2Array()
		for i in steps + 1:
			var ang := heading - half + (2.0 * half) * float(i) / steps
			pts.append(center + Vector2.from_angle(ang) * reach)
		for i in steps + 1:
			var ang2 := heading + half - (2.0 * half) * float(i) / steps
			pts.append(center + Vector2.from_angle(ang2) * inner)
		var col := Color(1.0, 0.93, 0.78, 0.85 * a) if heavy else Color(0.9, 0.97, 1.0, 0.75 * a)
		draw_colored_polygon(pts, col)
		var edge := PackedVector2Array()
		for i in steps + 1:
			var ang3 := heading - half + (2.0 * half) * float(i) / steps
			edge.append(center + Vector2.from_angle(ang3) * reach)
		draw_polyline(edge, Color(1, 1, 1, a), 2.0 if not heavy else 3.0)


class _Sparks extends Node2D:
	var dir := Vector2.RIGHT
	var heavy := false
	var life := 0.15
	var age := 0.0
	var rays: Array = []

	func setup(p_dir: Vector2, p_heavy: bool, p_life: float, seed_value: int) -> void:
		dir = p_dir
		heavy = p_heavy
		life = p_life
		top_level = true
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var count := 9 if heavy else 6
		for i in count:
			var ang := dir.angle() + rng.randf_range(-1.1, 1.1)
			rays.append({"a": ang, "s": rng.randf_range(0.6, 1.0) * (1.3 if heavy else 1.0)})

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var k := clampf(age / life, 0.0, 1.0)
		var a := 1.0 - k
		for r: Dictionary in rays:
			var d := Vector2.from_angle(float(r.a))
			var sc: float = r.s
			var start: float = 10.0 + 34.0 * k * sc
			var length: float = 16.0 * (1.0 - k * 0.6) * sc
			draw_line(d * start, d * (start + length), Color(1.0, 0.85, 0.4, a), 2.0)


class _Silhouette extends Node2D:
	var dir := Vector2.RIGHT
	var heavy := false
	var life := 0.09
	var age := 0.0

	func setup(p_dir: Vector2, p_heavy: bool, p_life: float) -> void:
		dir = p_dir
		heavy = p_heavy
		life = p_life
		top_level = true

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var k := clampf(age / life, 0.0, 1.0)
		var a := 1.0 - k * k
		var size := (34.0 if heavy else 24.0) * lerpf(0.7, 1.15, k)
		# Bright 4-point starburst, long axis along the strike direction: a hard white silhouette that reads
		# against any background for the first frames of the hit.
		var along := dir * size
		var across := dir.orthogonal() * size * 0.42
		draw_colored_polygon(PackedVector2Array([along, across * 0.5, -along * 0.3, -across * 0.5]), Color(1, 1, 1, a))
		draw_circle(Vector2.ZERO, size * 0.3, Color(1, 1, 0.9, a))
