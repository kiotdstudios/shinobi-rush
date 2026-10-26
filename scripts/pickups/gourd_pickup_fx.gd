class_name GourdPickupFx
extends Node2D
## The Health Gourd absorb sequence (about 0.55 s, then the +HP number floats on a little longer):
##   contact 0-80 ms     squash + flash + glow x2.5 + first chakra ring
##   burst 80-180 ms     the gourd lifts, tilts and shakes, stretches up then collapses; sparks, two rings, a pulse
##   warp 180-350 ms     it curves into the player's CURRENT chest, ease-in, shrinking, stretched along its heading,
##                       with a particle trail and two afterimages; a tiny implosion where it lands
##   absorb 350-450 ms   flash at the chest, shockwave, healing sparks spiral up, a glowing outline on the character
##   heal 450-550 ms     the HUD bar fills smoothly with a green sweep; the +HP number floats up
## All drawing is procedural (additive circles / rings / the gourd's own sprite), so it needs no extra art.
## The gourd keeps all its logic (healing is instant and exact, see HealthGourd.collect); this node only performs
## the take-it animation, drives the gourd's visual, and asks the HUD bar to show the fill late and smoothly.

const T_CONTACT := 0.08
const T_BURST := 0.18
const T_WARP := 0.35
const T_ABSORB := 0.45
const T_HEAL := 0.55
const T_END := 1.25  ## the floating number is the last thing alive
const CHEST := Vector2(0.0, -56.0)  ## the player's origin is at their feet
const HEAD := Vector2(0.0, -126.0)
const SOUND_RATE := 32000

static var _sound: AudioStreamWAV

var gourd: HealthGourd
## Effect colours: green for a health gourd, blue for a chakra gourd (set in start()).
var _green := Color(0.35, 1.0, 0.55)
var _white_green := Color(0.85, 1.0, 0.9)
var _label := "HEALTH GOURD"
var player: Node2D
var amount := 0.0
var t := 0.0
var auto := true  ## false: the owner (a test) advances time by hand
var finished := false
var particles: Array[Dictionary] = []
var _history: Array[Dictionary] = []  ## recent (t, pos, rot, scale) of the flying gourd, for the afterimages
var _start_pos := Vector2.ZERO
var _warp_started := false
var _absorbed := false
var _glow_layer: Node2D
var _audio: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _body_tex: Texture2D


static func start(p_gourd: HealthGourd, p_player: Node2D, p_amount: float, hp_before_fraction: float) -> GourdPickupFx:
	var fx := GourdPickupFx.new()
	fx.gourd = p_gourd
	fx.player = p_player
	fx.amount = p_amount
	if p_gourd.kind == "kunai":
		fx._green = Color.WHITE
		fx._white_green = Color.WHITE
	elif p_gourd.kind == "chakra":
		fx._green = Color(0.3, 0.65, 1.0)
		fx._white_green = Color(0.85, 0.95, 1.0)
	elif p_gourd.kind in ["paper_tag", "tag_bomb", "smoke_tag_bomb"]:
		fx._green = Color(1.0, 0.55, 0.12)
		fx._white_green = Color(1.0, 0.92, 0.7)
	p_gourd.add_child(fx)
	# The gourd goes into the bag now (healing happens later, from its D-pad slot), so there is no HUD fill to schedule.
	fx._label = {"kunai": "KUNAI", "chakra": "CHAKRA GOURD", "paper_tag": "PAPER TAG", "tag_bomb": "TAG BOMB", "smoke_tag_bomb": "SMOKE TAG BOMB"}.get(p_gourd.kind, "HEALTH GOURD")
	return fx


func _ready() -> void:
	top_level = true  # world coordinates, whatever the gourd does
	global_position = Vector2.ZERO
	z_as_relative = false
	z_index = 120
	name = "GourdPickupFx"
	_rng.randomize()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer = Node2D.new()
	_glow_layer.name = "Additive"
	_glow_layer.material = add_mat
	_glow_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_glow_layer)
	_glow_layer.draw.connect(_draw_additive)
	var list := HealthGourd.frames("gourd", gourd.kind)
	_body_tex = list[0] if not list.is_empty() else null
	_start_pos = gourd._visual.global_position
	_audio = AudioStreamPlayer.new()
	_audio.name = "PickupSound"
	_audio.stream = pickup_sound()
	_audio.volume_db = -5.0
	add_child(_audio)
	if not DisplayServer.get_name() == "headless":
		_audio.play()
	_spawn_sparks(10, _start_pos, 90.0, 0.0)


func _process(delta: float) -> void:
	if auto:
		advance(delta)


func chest() -> Vector2:
	return player.global_position + CHEST if is_instance_valid(player) else _start_pos


## Move the animation on by `dt` seconds (the engine calls this every frame; tests call it directly).
func advance(dt: float) -> void:
	if finished:
		return
	t += dt
	_age_particles(dt)
	if is_instance_valid(gourd):
		_drive_gourd()
	if t >= T_WARP and not _absorbed:
		_absorbed = true
		_on_absorb()
	if t >= T_END:
		finish()
		return
	queue_redraw()
	_glow_layer.queue_redraw()


func finish() -> void:
	finished = true
	if is_instance_valid(gourd):
		gourd._visual.visible = false
	queue_free()


# ---------------------------------------------------------------- the gourd itself
func _drive_gourd() -> void:
	var v: Node2D = gourd._visual
	var rest := Vector2(0.0, -3.0 if gourd.grounded else -HealthGourd.FLOAT_HEIGHT)
	if t < T_CONTACT:
		var k := t / T_CONTACT
		var sq := 0.38 * (1.0 - 0.3 * k)
		v.position = rest
		v.rotation = 0.0
		v.scale = Vector2(1.0 + sq, 1.0 - sq)
		_set_glow(lerpf(2.5, 2.2, k))
	elif t < T_BURST:
		var k := (t - T_CONTACT) / (T_BURST - T_CONTACT)
		var lift := sin(k * PI * 0.5) * 16.0
		var shake := Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-1.5, 1.5)) * (1.0 - k * 0.3)
		v.position = rest + Vector2(0.0, -lift) + shake
		v.rotation = deg_to_rad(lerpf(8.0, 22.0, k)) + _rng.randf_range(-0.05, 0.05)
		# stretch upward first, then collapse inward
		var s := Vector2(0.88, 1.28) if k < 0.6 else Vector2(0.82, 0.82).lerp(Vector2(0.88, 1.28), (1.0 - k) / 0.4)
		v.scale = s
		_set_glow(2.2)
		_burst_emit(k)
	elif t < T_WARP:
		var u := (t - T_BURST) / (T_WARP - T_BURST)
		if not _warp_started:
			_warp_started = true
			_start_pos = v.global_position
		var p := u * u * u  # ease-in: starts slow, snaps into the chest
		var target := chest()
		var ctrl := (_start_pos + target) * 0.5 + Vector2(0.0, -70.0)
		var pos := _start_pos.lerp(ctrl, p).lerp(ctrl.lerp(target, p), p)
		var prev := v.global_position
		v.global_position = pos
		var dir := (pos - prev)
		var heading := dir.angle() - PI * 0.5 if dir.length() > 0.5 else v.rotation
		v.rotation = lerp_angle(v.rotation, heading, 0.6)
		var shrink := 1.0 - p
		v.scale = Vector2(0.8, 0.8 + 1.1 * p) * shrink  # stretched along its heading, shrinking to nothing
		_set_glow(2.0 * shrink + 0.3)
		_history.append({"t": t, "pos": pos, "rot": v.rotation, "scale": v.scale})
		_spawn_trail(pos, dir)
	else:
		v.visible = false
		_set_glow(0.0)
	while _history.size() > 0 and t - float(_history[0].t) > 0.12:
		_history.remove_at(0)


func _set_glow(mult: float) -> void:
	var g: Sprite2D = gourd._glow
	g.modulate = Color(1.0, 0.5, 0.4, 1.0) * mult if mult > 0.0 else Color(0, 0, 0, 0)
	g.modulate.a = clampf(mult, 0.0, 1.0)


func _on_absorb() -> void:
	var c := chest()
	# tiny implosion at the absorption point
	for i in 8:
		var a := TAU * float(i) / 8.0
		particles.append({"p": c + Vector2(cos(a), sin(a)) * 22.0, "v": -Vector2(cos(a), sin(a)) * 190.0, "life": 0.12, "age": 0.0, "size": 3.0, "kind": "dot", "follow": false})
	# healing sparks that spiral up around the character
	for i in 9:
		var a := TAU * float(i) / 9.0
		particles.append({"a": a, "r": 22.0, "h": -10.0 - float(i) * 3.0, "life": 0.5 + 0.03 * float(i), "age": 0.0, "size": 3.0, "kind": "spiral", "follow": true})


func _burst_emit(k: float) -> void:
	if int(k * 10.0) != int((k - 0.12) * 10.0) and _rng.randf() < 0.9:
		_spawn_sparks(2, gourd._visual.global_position, 70.0, 0.0)


func _spawn_sparks(n: int, at: Vector2, speed: float, _unused: float) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var s := speed * _rng.randf_range(0.5, 1.0)
		particles.append({"p": at + Vector2(cos(a), sin(a)) * 8.0, "v": Vector2(cos(a), sin(a) * 0.8) * s, "life": _rng.randf_range(0.18, 0.34), "age": 0.0, "size": _rng.randf_range(2.0, 3.5), "kind": "dot", "follow": false})


func _spawn_trail(pos: Vector2, dir: Vector2) -> void:
	for i in 2:
		particles.append({"p": pos + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)), "v": -dir * 4.0 + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20)), "life": 0.26, "age": 0.0, "size": _rng.randf_range(2.5, 4.0), "kind": "trail", "follow": false})


func _age_particles(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for q in particles:
		q.age = float(q.age) + dt
		if float(q.age) < float(q.life):
			if q.kind != "spiral":
				q.p = (q.p as Vector2) + (q.v as Vector2) * dt
			keep.append(q)
	particles = keep


func _spiral_pos(q: Dictionary) -> Vector2:
	var k := float(q.age) / float(q.life)
	var a := float(q.a) + k * 5.0
	var r := lerpf(float(q.r), 6.0, k)
	var base := player.global_position if is_instance_valid(player) else _start_pos
	return base + Vector2(cos(a) * r, sin(a) * r * 0.5 + float(q.h) - k * 70.0)


# ---------------------------------------------------------------- drawing
static func _blob(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for i in 6:
		var k := float(i) / 5.0
		ci.draw_circle(c, lerpf(r, r * 0.18, k), Color(col, col.a * lerpf(0.12, 0.55, k)))


func _ring(ci: CanvasItem, c: Vector2, r: float, width: float, col: Color) -> void:
	if r > 0.5 and col.a > 0.01:
		ci.draw_arc(c, r, 0.0, TAU, 40, col, width)


func _draw_additive() -> void:
	var ci: CanvasItem = _glow_layer
	var g_pos: Vector2 = gourd._visual.global_position if is_instance_valid(gourd) else _start_pos
	var c := chest()
	# 1 contact: flash + first ring + soft ping ring
	if t < 0.2:
		var f := 1.0 - t / 0.2
		_blob(ci, g_pos, 34.0 * (0.7 + 0.5 * f), Color(_white_green, 0.9 * f))
	if t < 0.3:
		var k := t / 0.3
		_ring(ci, g_pos, lerpf(10.0, 62.0, k), 2.0, Color(_green, 0.9 * (1.0 - k)))
	# 2 burst: two concentric rings at different speeds, then a faint wide pulse
	if t >= T_CONTACT and t < 0.5:
		var k := (t - T_CONTACT) / 0.42
		_ring(ci, g_pos, lerpf(8.0, 90.0, k), 2.0, Color(_green, 0.8 * (1.0 - k)))
		_ring(ci, g_pos, lerpf(8.0, 48.0, minf(k * 1.6, 1.0)), 1.5, Color(_white_green, 0.7 * (1.0 - minf(k * 1.6, 1.0))))
		_ring(ci, g_pos, lerpf(20.0, 140.0, k), 7.0, Color(_green, 0.14 * (1.0 - k)))  # distortion-style pulse
	# the player's rim light during the burst
	if t >= T_CONTACT and t < T_WARP and is_instance_valid(player):
		var k := (t - T_CONTACT) / (T_WARP - T_CONTACT)
		_aura(ci, 0.35 * sin(k * PI))
	# warp: afterimages
	if _body_tex != null:
		for i in 2:
			var lag := 0.045 * float(i + 1)
			var h := _history_at(t - lag)
			if not h.is_empty():
				ci.draw_set_transform(h.pos, h.rot, h.scale)
				ci.draw_texture(_body_tex, -_body_tex.get_size() * 0.5, Color(_green, 0.5 - 0.2 * float(i)))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 3 absorb: chest flash, shockwave, outline
	if t >= T_WARP:
		var k := (t - T_WARP) / 0.28
		if k < 1.0:
			_blob(ci, c, lerpf(46.0, 20.0, k), Color(_white_green, 0.95 * (1.0 - k)))
			_ring(ci, c, lerpf(10.0, 96.0, k), 3.0, Color(_green, 0.9 * (1.0 - k)))
			_ring(ci, c, lerpf(6.0, 60.0, k), 2.0, Color(_white_green, 0.7 * (1.0 - k)))
		var ko := clampf((t - T_WARP) / 0.35, 0.0, 1.0)
		if ko < 1.0:
			_aura(ci, 0.9 * (1.0 - ko))
	# particles
	for q in particles:
		var life_k := float(q.age) / float(q.life)
		var col := Color(_white_green if life_k < 0.4 else _green, 1.0 - life_k)
		var p: Vector2 = _spiral_pos(q) if q.kind == "spiral" else q.p
		if q.kind == "trail":
			_blob(ci, p, float(q.size) * (1.0 - life_k * 0.5) + 2.0, Color(_green, 0.9 * (1.0 - life_k)))
		else:
			ci.draw_circle(p, float(q.size) * (1.0 - life_k * 0.4), col)


## Glowing outline around the character (an ellipse hugging the body).
func _aura(ci: CanvasItem, a: float) -> void:
	if not is_instance_valid(player) or a <= 0.01:
		return
	var b := player.global_position + Vector2(0.0, -54.0)
	for i in 3:
		var w := 2.0 + float(i) * 3.0
		var pts := PackedVector2Array()
		for j in 33:
			var ang := TAU * float(j) / 32.0
			pts.append(b + Vector2(cos(ang) * (26.0 + float(i) * 2.0), sin(ang) * (62.0 + float(i) * 2.0)))
		ci.draw_polyline(pts, Color(_green, a * (0.55 - 0.15 * float(i))), w)


func _history_at(when: float) -> Dictionary:
	var best := {}
	for h in _history:
		if float(h.t) <= when:
			best = h
	return best


func _draw() -> void:
	# floating +HP number (normal blend so the outline reads on any floor)
	if t < T_HEAL or not is_instance_valid(player) or amount <= 0.0:
		return
	var k := clampf((t - T_ABSORB) / (T_END - T_ABSORB), 0.0, 1.0)
	var pos := player.global_position + HEAD + Vector2(0.0, -46.0 * (1.0 - pow(1.0 - k, 2.0)))
	var a := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var txt := "+%d %s" % [int(roundf(amount)), _label]
	draw_string_outline(font, pos - Vector2(90.0, 0.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 20, 5, _label_outline(a))
	draw_string(font, pos - Vector2(90.0, 0.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 20, _label_fill(a))


func _label_outline(a: float) -> Color:
	match _label:
		"HEALTH GOURD":
			return Color(0.02, 0.15, 0.06, 0.9 * a)
		"PAPER TAG":
			return Color(0.2, 0.06, 0.0, 0.9 * a)
	return Color(0.02, 0.06, 0.2, 0.9 * a)


func _label_fill(a: float) -> Color:
	match _label:
		"HEALTH GOURD":
			return Color(0.6, 1.0, 0.7, a)
		"PAPER TAG":
			return Color(1.0, 0.8, 0.45, a)
	return Color(0.65, 0.85, 1.0, a)


# ---------------------------------------------------------------- sound
## One cohesive 0.95 s clip: crystal click (0) + low swell (20-400 ms) + reverse whoosh (170-360 ms) +
## soft bass impact and shimmer (350 ms) + bright two-note chime (450 / 510 ms), mixed and softly limited together.
static func pickup_sound() -> AudioStreamWAV:
	if _sound != null:
		return _sound
	var dur := 0.95
	var n := int(dur * SOUND_RATE)
	var mix := PackedFloat32Array()
	mix.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var lp_w := 0.0
	var lp_b := 0.0
	var ph_sw := 0.0
	var ph_b := 0.0
	for i in n:
		var s := float(i) / SOUND_RATE
		var v := 0.0
		# crystal click
		if s < 0.12:
			v += sin(TAU * 2600.0 * s) * exp(-s * 70.0) * 0.45 + sin(TAU * 3900.0 * s) * exp(-s * 90.0) * 0.22 + (rng.randf() * 2.0 - 1.0) * exp(-s * 300.0) * 0.18
		# low magical swell
		if s > 0.02 and s < 0.42:
			var k := (s - 0.02) / 0.4
			var env := pow(sin(PI * k), 1.6) * 0.34
			ph_sw += TAU * lerpf(110.0, 196.0, k) / SOUND_RATE
			v += (sin(ph_sw) + 0.4 * sin(ph_sw * 2.0) + 0.25 * sin(ph_sw * 3.0)) * env
		# reverse whoosh: filtered noise whose cutoff and volume climb, then cut off at the pull-in
		if s > 0.17 and s < 0.36:
			var k := (s - 0.17) / 0.19
			lp_w += ((rng.randf() * 2.0 - 1.0) - lp_w) * lerpf(0.05, 0.7, k)
			v += lp_w * k * k * 1.1
		# soft bass impact + shimmer as the energy enters
		if s >= 0.35:
			var d := s - 0.35
			ph_b += TAU * lerpf(95.0, 46.0, minf(d * 6.0, 1.0)) / SOUND_RATE
			var thump_noise := (rng.randf() * 2.0 - 1.0)
			lp_b += (thump_noise - lp_b) * 0.08
			v += sin(ph_b) * exp(-d * 13.0) * 0.8 + lp_b * exp(-d * 30.0) * 0.5
			var trem := 0.6 + 0.4 * sin(TAU * 18.0 * d)
			v += (sin(TAU * 3100.0 * d) + sin(TAU * 4700.0 * d) * 0.7 + sin(TAU * 6200.0 * d) * 0.4) * exp(-d * 9.0) * trem * 0.09
		# bright two-note chime
		for note: Array in [[0.45, 880.0], [0.51, 1318.5]]:
			if s >= float(note[0]):
				var d := s - float(note[0])
				var att := minf(d / 0.004, 1.0)
				v += (sin(TAU * float(note[1]) * d) + 0.3 * sin(TAU * float(note[1]) * 2.0 * d)) * exp(-d * 6.5) * att * 0.3
		mix[i] = v
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(mix[i]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var fade := minf(float(n - i) / (0.03 * SOUND_RATE), 1.0)  # no click at the very end
		var x := tanh(mix[i] / peak * 1.25) * 0.82 * fade
		data.encode_s16(i * 2, clampi(int(x * 32000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SOUND_RATE
	w.stereo = false
	w.data = data
	_sound = w
	return w
