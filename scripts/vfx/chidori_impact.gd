class_name ChidoriImpact
extends Node2D
## The Chidori impact: a violent electrical burst built from layers that peak almost at once and then die fast.
##   0.00-0.05  white-hot contact flash (blocky diamond + cross)
##   0.05-0.12  primary lightning eruption: thick jagged bolts strike outward and keep re-jittering
##   0.12-0.22  irregular cyan shock ring + secondary branching arcs
##   0.22-0.40  ground discharge races along the floor, spark shower
##   0.40-0.60  a few weak residual arcs crackle, then it is gone
## Pure visuals: damage is applied by whoever spawns it. Scale `k` shrinks it for a fizzle.

const DURATION := 0.6
const FLASH_END := 0.05
const ERUPT_END := 0.12
const RING_END := 0.22
const SPARK_END := 0.40
const PRIMARY := 9
const GROUND := 8
const SPARKS := 56
const RING_PTS := 28
const RING_RADIUS := 150.0  ## the paper bomb's blast radius, the scale reference
const ISO_Y := 0.58

static var crackle_stream: AudioStreamWAV

var k := 1.0
var dir := Vector2.RIGHT
var age := 0.0
var finished := false
var spark_count := 0
var bolt_count := 0

var _rng := RandomNumberGenerator.new()
var _angles: Array[float] = []
var _lens: Array[float] = []
var _primary: Array = []
var _ground: Array = []
var _resid: Array = []
var _pillar: Array = []
var _spikes := PackedFloat32Array()
var _ring := PackedFloat32Array()
var _geo_clock := 0.0
var _sparks: Array = []
var _second_burst := false
var _glow: Node2D


static func spawn(parent: Node, pos: Vector2, heading: Vector2, scale_k := 1.0) -> ChidoriImpact:
	var fx := ChidoriImpact.new()
	fx.k = scale_k
	fx.dir = heading.normalized() if heading != Vector2.ZERO else Vector2.RIGHT
	fx.name = "ChidoriImpact"
	fx.z_index = 12
	parent.add_child(fx)
	fx.global_position = pos
	return fx


func _ready() -> void:
	_rng.randomize()
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	for i in PRIMARY:
		_angles.append(TAU * float(i) / float(PRIMARY) + _rng.randf_range(-0.25, 0.25))
		_lens.append(_rng.randf_range(95.0, 165.0) * k)
	_regen()
	for i in 18:
		_spikes.append(_rng.randf_range(0.55, 1.0))
	for i in RING_PTS:
		_ring.append(_rng.randf_range(0.9, 1.1))
	if is_inside_tree():
		CameraImpact.impulse(dir, 11.0 * k, 380.0)
		var audio := AudioStreamPlayer.new()
		audio.name = "CrackleSound"
		audio.stream = crackle()
		audio.volume_db = -2.0
		add_child(audio)
		if not DisplayServer.get_name() == "headless":
			audio.play()
	_spawn_scorch()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if finished:
		return
	age += delta
	_geo_clock -= delta
	if _geo_clock <= 0.0 and age < SPARK_END:
		_geo_clock = 0.045
		_regen()
	elif _geo_clock <= 0.0 and age >= 0.4:
		_geo_clock = 0.05
		_regen_residual()
	if age >= FLASH_END and _sparks.is_empty() and not _second_burst:
		_spawn_sparks(SPARKS, 220.0, 460.0)
	if age >= RING_END and not _second_burst:
		_second_burst = true
		_spawn_sparks(24, 90.0, 260.0)
	_tick_sparks(delta)
	if age >= DURATION:
		finished = true
		queue_free()
		return
	queue_redraw()
	_glow.queue_redraw()


## Re-roll the lightning geometry (same angles, new kinks) so the bolts visibly crawl and flicker.
func _regen() -> void:
	_primary.clear()
	_ground.clear()
	var n := 0
	for i in PRIMARY:
		var a := _angles[i]
		var up := 1.2 if sin(a) < 0.0 else 0.9
		var end := Vector2(cos(a), sin(a) * ISO_Y * 1.25) * _lens[i] * up - Vector2(0, 8.0 * k)
		var tr := LightningFx.tree(_rng, Vector2.ZERO, end, 12.0 * k, 4.0 * clampf(k, 0.5, 1.0), 2, 0.5)
		n += tr.size()
		_primary.append(tr)
	for i in GROUND:
		var a := TAU * float(i) / float(GROUND) + _rng.randf_range(-0.3, 0.3)
		var end := Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(130.0, 185.0) * k
		var tr := LightningFx.tree(_rng, Vector2.ZERO, end, 9.0 * k, 3.0, 1, 0.35)
		n += tr.size()
		_ground.append(tr)
	_pillar.clear()
	for i in 3:
		var top := Vector2(_rng.randf_range(-26.0, 26.0), -_rng.randf_range(170.0, 240.0)) * k
		var tp := LightningFx.tree(_rng, Vector2(_rng.randf_range(-6.0, 6.0), -4.0), top, 14.0 * k, 7.0 * k, 2, 0.5)
		n += tp.size()
		_pillar.append(tp)
	bolt_count = n


func _regen_residual() -> void:
	_resid.clear()
	for i in 3:
		var a := _rng.randf() * TAU
		var end := Vector2(cos(a), sin(a) * 0.7) * _rng.randf_range(34.0, 72.0) * k
		_resid.append(LightningFx.tree(_rng, Vector2(_rng.randf_range(-8.0, 8.0), 0), end, 6.0, 2.0, 1, 0.3))


func _spawn_sparks(n: int, vmin: float, vmax: float) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.8) * _rng.randf_range(vmin, vmax) * k
		v.y -= _rng.randf_range(40.0, 200.0)
		_sparks.append({"p": Vector2(0, -6), "v": v, "life": _rng.randf_range(0.2, 0.45), "max": 0.45, "size": [2.0, 2.0, 4.0][_rng.randi() % 3], "col": LightningFx.WHITE if _rng.randf() < 0.5 else (LightningFx.CYAN if _rng.randf() < 0.6 else LightningFx.BLUE)})
	spark_count = _sparks.size()


func _tick_sparks(delta: float) -> void:
	var i := _sparks.size() - 1
	while i >= 0:
		var s: Dictionary = _sparks[i]
		s.life = float(s.life) - delta
		if float(s.life) <= 0.0:
			_sparks.remove_at(i)
		else:
			s.v = Vector2(s.v) + Vector2(0, 620.0) * delta
			s.p = Vector2(s.p) + Vector2(s.v) * delta
		i -= 1
	spark_count = _sparks.size()


func _draw() -> void:
	var fade := 1.0
	# 0.05-0.12 eruption: bolts strike outward; hold bright until the ring is out, then collapse quickly
	var reveal := clampf((age - 0.02) / 0.06, 0.0, 1.0)
	if age > RING_END:
		fade = clampf(1.0 - (age - RING_END) / (SPARK_END - RING_END), 0.0, 1.0)
	if age >= FLASH_END * 0.5 and fade > 0.0:
		for tr: Array in _primary:
			LightningFx.draw_tree(self, tr, fade, reveal)
	# vertical strike pillar + starburst: the big silhouette that peaks with the flash
	if age >= 0.02 and age < 0.3:
		var pf := clampf(1.0 - (age - 0.14) / 0.16, 0.0, 1.0)
		var pr := clampf((age - 0.02) / 0.05, 0.0, 1.0)
		for tp: Array in _pillar:
			LightningFx.draw_tree(self, tp, pf, pr)
		if age < 0.18:
			var sa := clampf(1.0 - (age - 0.06) / 0.12, 0.0, 1.0)
			var n2 := _spikes.size()
			for i in n2:
				var a2 := TAU * float(i) / float(n2)
				var ln: float = float(_spikes[i]) * 200.0 * k * minf((age + 0.01) / 0.05, 1.0)
				var tip := LightningFx.snap(Vector2(cos(a2), sin(a2) * ISO_Y * 1.3) * ln - Vector2(0, 8))
				var bw := 0.12
				var l := LightningFx.snap(Vector2(cos(a2 - bw), sin(a2 - bw) * ISO_Y) * 18.0 * k - Vector2(0, 8))
				var rr := LightningFx.snap(Vector2(cos(a2 + bw), sin(a2 + bw) * ISO_Y) * 18.0 * k - Vector2(0, 8))
				LightningFx.fill(self, PackedVector2Array([l, tip, rr]), Color(LightningFx.BLUE, 0.9 * sa))
				var tip2 := tip * 0.62
				LightningFx.fill(self, PackedVector2Array([l * 0.6, tip2, rr * 0.6]), Color(LightningFx.CYAN, sa))
	# ground discharge: races outward along the floor 0.22 - 0.40, gone by 0.5
	if age >= 0.18:
		var gr := clampf((age - 0.18) / 0.2, 0.0, 1.0)
		var gfade := 1.0 if age < SPARK_END else clampf(1.0 - (age - SPARK_END) / 0.12, 0.0, 1.0)
		for tr: Array in _ground:
			LightningFx.draw_tree(self, tr, gfade, gr)
	# shock ring: irregular, cyan, thick at first then thin
	if age >= FLASH_END and age <= 0.38:
		var u := clampf((age - FLASH_END) / (0.30 - FLASH_END), 0.0, 1.0)
		var r := RING_RADIUS * k * (1.0 - pow(1.0 - u, 3.0))
		var ring := PackedVector2Array()
		var ring_in := PackedVector2Array()
		for i in RING_PTS + 1:
			var a := TAU * float(i % RING_PTS) / float(RING_PTS)
			var m := _ring[i % RING_PTS]
			ring.append(LightningFx.snap(Vector2(cos(a), sin(a) * ISO_Y) * r * m - Vector2(0, 6)))
			ring_in.append(LightningFx.snap(Vector2(cos(a), sin(a) * ISO_Y) * r * m * 0.9 - Vector2(0, 6)))
		var ra := clampf(1.0 - (age - 0.22) / 0.16, 0.0, 1.0)
		var wd := lerpf(9.0, 2.0, u)
		draw_polyline(ring, Color(LightningFx.BLUE, 0.9 * ra), wd * 1.6, false)
		draw_polyline(ring, Color(LightningFx.CYAN, ra), wd, false)
		draw_polyline(ring_in, Color(LightningFx.WHITE, 0.8 * ra), maxf(wd * 0.35, 2.0), false)
	# residual crackle
	if age >= SPARK_END:
		var rf := clampf(1.0 - (age - SPARK_END) / (DURATION - SPARK_END), 0.0, 1.0)
		for tr: Array in _resid:
			LightningFx.draw_tree(self, tr, rf * 0.8, 1.0)
	# sparks
	for s: Dictionary in _sparks:
		var c := Color(s.col)
		c.a = clampf(float(s.life) / float(s.max) * 2.0, 0.0, 1.0)
		if float(s.size) > 2.0:
			LightningFx.dot(self, Vector2(s.p), float(s.size), c)
		else:
			LightningFx.streak(self, Vector2(s.p), Vector2(s.v), 9.0, c)
	# the white-hot flash is drawn last, on top
	if age < FLASH_END:
		var r := 90.0 * k
		LightningFx.fill(self, PackedVector2Array([Vector2(0, -r * 1.25), Vector2(r * 1.2, 0), Vector2(0, r * ISO_Y * 1.3), Vector2(-r * 1.2, 0)]), Color(LightningFx.BLUE, 0.9))
		var white := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.9, 0), Vector2(0, r * ISO_Y), Vector2(-r * 0.9, 0)])
		LightningFx.fill(self, white, LightningFx.WHITE)
		draw_line(Vector2(-r * 1.9, 0), Vector2(r * 1.9, 0), LightningFx.WHITE, 4.0, false)
		draw_line(Vector2(0, -r * 1.7), Vector2(0, r), LightningFx.WHITE, 4.0, false)
	elif age < ERUPT_END:
		var u2 := (age - FLASH_END) / (ERUPT_END - FLASH_END)
		var r2 := lerpf(60.0, 22.0, u2) * k
		LightningFx.fill(self, LightningFx.blob(_rng, r2, 0.3), Color(LightningFx.CYAN, 1.0 - u2 * 0.5))
		LightningFx.fill(self, LightningFx.blob(_rng, r2 * 0.5, 0.3), LightningFx.WHITE)


func _draw_glow() -> void:
	var a := clampf(1.0 - age / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	for i in 4:
		var rr := (150.0 - 30.0 * float(i)) * k * (0.6 + 0.4 * minf(age / 0.12, 1.0))
		_glow.draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, ISO_Y))
		_glow.draw_circle(Vector2.ZERO, rr, Color(0.25, 0.55, 1.0, 0.07 * a + 0.03 * a * float(i)))
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _spawn_scorch() -> void:
	var p := get_parent()
	if p == null or not is_inside_tree():
		return
	var s := Node2D.new()
	s.name = "ChidoriScorch"
	s.z_index = -1
	var rr := _rng.randi()
	s.draw.connect(func():
		var r2 := RandomNumberGenerator.new()
		r2.seed = rr
		var pts := LightningFx.blob(r2, 46.0 * k, 0.3, 14, ISO_Y)
		LightningFx.fill(s, pts, Color(0.04, 0.05, 0.1, 0.55))
		for i in 6:
			var a := r2.randf() * TAU
			s.draw_polyline(LightningFx.bolt(r2, Vector2.ZERO, Vector2(cos(a), sin(a) * ISO_Y) * 52.0 * k, 5.0), Color(LightningFx.BLUE, 0.5), 2.0, false))
	p.add_child(s)
	s.global_position = global_position
	var tw := s.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(s, "modulate:a", 0.0, 1.6)
	tw.tween_callback(s.queue_free)


## Synthesised electrical crackle (no audio asset): a hard noise crack with a low thump that dies fast.
static func crackle() -> AudioStreamWAV:
	if crackle_stream != null:
		return crackle_stream
	var rate := 22050
	var n := int(rate * 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 9.0)
		var crack := rng.randf_range(-1.0, 1.0) * (1.0 if int(t * 90.0) % 3 != 0 else 0.35)
		var thump := sin(TAU * 62.0 * t) * exp(-t * 16.0)
		var v := clampf((crack * 0.7 + thump * 0.9) * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	crackle_stream = w
	return w
