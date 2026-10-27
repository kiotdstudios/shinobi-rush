class_name ChidoriFx
extends Node2D
## The hand-held Chidori, charging and rushing. A child of the player; it only DRAWS (no damage, no input), so it can be
## tested and previewed on its own. Layers: A jagged unstable core (Codex's 12 hand-core frames sit on top of a
## procedural blob), B 8-14 lightning arcs of which a handful flicker at once, C pooled pixel sparks, D ground strikes,
## dust at the feet and a cheap additive glow (no shader, no screen-wide light).

enum Mode { OFF, CHARGE, RUSH }

const CORE_PATH := "res://assets/vfx/chidori/core/core_%02d.png"
const CORE_FRAMES := 12
const MAX_SPARKS := 72
const MAX_AFTER := 7
const ARC_POOL := 12  ## directions the arcs may use; ARC_ACTIVE_* of them are lit at any instant
const ARC_ACTIVE_MIN := 4
const ARC_ACTIVE_MAX := 7
const ARC_REFRESH := 0.045
const AFTER_EVERY := 0.035
const AFTER_LIFE := 0.24
const DUST := Color("#c8b98f")

var mode: Mode = Mode.OFF
var t := 0.0
var power := 0.0  ## 0..1 charge fill (grows the core and the arc reach)
var dir8 := Vector2.DOWN
var rush_dir := Vector2.DOWN
var rush_accel := 0.0  ## 1 right at launch, easing to 0: the flare is biggest while accelerating
var spark_count := 0
var arc_count_lit := 0

var _rng := RandomNumberGenerator.new()
var _arcs: Array = []  ## [{"bolts": Array, "ground": bool}]
var _arc_clock := 0.0
var _blob := PackedVector2Array()
var _sparks: Array = []
var _spark_i := 0
var _core_tex: Array[Texture2D] = []
var _core_sprite: Sprite2D
var _core_clock := 0.0
var _glow: Node2D
var _after: Array[Sprite2D] = []
var _after_age: Array[float] = []
var _after_i := 0
var _after_clock := 0.0
var _dust_clock := 0.0


## Where the striking hand is, relative to the feet, for each of the 8 facings (iso: y is squashed, the hand sits ahead
## of the body and a little to its right).
static func hand_local(d: Vector2) -> Vector2:
	var f := d.normalized() if d != Vector2.ZERO else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	return Vector2(f.x * 16.0 + side.x * 9.0, -50.0 + f.y * 7.0 + side.y * 4.0)


func _ready() -> void:
	_rng.randomize()
	for i in CORE_FRAMES:
		_core_tex.append(load(CORE_PATH % i) as Texture2D)
	_core_sprite = Sprite2D.new()
	_core_sprite.name = "HandCore"
	_core_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_core_sprite.z_index = 1
	add_child(_core_sprite)
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.z_index = -1
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	for i in MAX_AFTER:
		var s := Sprite2D.new()
		s.name = "After%d" % i
		s.top_level = true
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.visible = false
		s.z_index = -1
		add_child(s)
		_after.append(s)
		_after_age.append(-1.0)
	_set_mode(Mode.OFF)


func begin_charge(facing: Vector2) -> void:
	dir8 = facing
	power = 0.0
	t = 0.0
	_set_mode(Mode.CHARGE)
	_rebuild_arcs()


func begin_rush(heading: Vector2) -> void:
	rush_dir = heading.normalized()
	rush_accel = 1.0
	power = 1.0
	_set_mode(Mode.RUSH)
	_after_clock = 0.0
	for i in 14:
		_emit_spark(hand_local(dir8), true)


func stop() -> void:
	_set_mode(Mode.OFF)


func is_active() -> bool:
	return mode != Mode.OFF


func _set_mode(m: Mode) -> void:
	mode = m
	visible = m != Mode.OFF or _after_visible()
	if m == Mode.OFF:
		spark_count = 0
		_sparks.clear()
		_arcs.clear()
		arc_count_lit = 0
		if _core_sprite != null:
			_core_sprite.visible = false
	queue_redraw()


func _after_visible() -> bool:
	for a in _after_age:
		if a >= 0.0:
			return true
	return false


func _process(delta: float) -> void:
	advance(delta)


## Moves the effect's clock forward (tests and the preview tool call this with a fixed step).
func advance(delta: float) -> void:
	_tick_afterimages(delta)
	if mode == Mode.OFF:
		visible = _after_visible()
		return
	visible = true
	t += delta
	if mode == Mode.CHARGE:
		power = clampf(t / 0.65, 0.0, 1.0)
	else:
		rush_accel = maxf(rush_accel - delta * 3.2, 0.0)
	_arc_clock -= delta
	if _arc_clock <= 0.0:
		_arc_clock = ARC_REFRESH
		_rebuild_arcs()
	_tick_core(delta)
	_tick_sparks(delta)
	if mode == Mode.CHARGE:
		_dust_clock -= delta
		if _dust_clock <= 0.0:
			_dust_clock = lerpf(0.09, 0.03, power)
			_emit_dust()
		if _rng.randf() < lerpf(1.0, 4.0, power) * delta * 60.0 * 0.5 and spark_count < MAX_SPARKS:
			_emit_spark(hand_local(dir8), false)
	else:
		_after_clock -= delta
		if _after_clock <= 0.0:
			_after_clock = AFTER_EVERY
			_spawn_afterimage()
		if _rng.randf() < 0.6:
			_emit_spark(hand_local(dir8) + Vector2(0, 44), false)  # ground-level sparks along the run
		_dust_clock -= delta
		if _dust_clock <= 0.0:
			_dust_clock = 0.05
			_emit_dust()
	queue_redraw()
	_glow.queue_redraw()


func _tick_core(delta: float) -> void:
	_core_clock -= delta
	if _core_clock > 0.0:
		return
	_core_clock = 0.04
	_core_sprite.visible = true
	_core_sprite.texture = _core_tex[_rng.randi() % CORE_FRAMES]
	_core_sprite.position = hand_local(dir8)
	_core_sprite.flip_h = _rng.randf() < 0.5
	_core_sprite.flip_v = _rng.randf() < 0.5
	_core_sprite.modulate.a = lerpf(0.55, 1.0, power)
	_blob = LightningFx.blob(_rng, lerpf(7.0, 14.0, power) * (1.0 + 0.45 * rush_accel + (0.2 if mode == Mode.RUSH else 0.0)), 0.38)


## 8-14 arc slots; a random 4-7 of them are lit. Some reach down to the ground.
func _rebuild_arcs() -> void:
	_arcs.clear()
	var n := ARC_POOL + (_rng.randi() % 3 - 1)
	var lit := _rng.randi_range(ARC_ACTIVE_MIN, ARC_ACTIVE_MAX)
	var h := hand_local(dir8)
	var reach := lerpf(26.0, 62.0, power) * (1.25 if mode == Mode.RUSH else 1.0)
	var seen := 0
	for i in n:
		if seen >= lit:
			break
		if _rng.randf() > float(lit) / float(n) * 1.4 and n - i > lit - seen:  # may skip a slot only while the lit count can still be reached
			continue
		seen += 1
		var ground := _rng.randf() < 0.22
		var a := _rng.randf() * TAU
		var end := h + Vector2(cos(a), sin(a) * 0.8) * reach * _rng.randf_range(0.5, 1.15)
		if ground:
			end = Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-2.0, 10.0))
		if mode == Mode.RUSH:
			end = h - rush_dir * reach * _rng.randf_range(0.8, 2.2) + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-14.0, 14.0))
		_arcs.append({"bolts": LightningFx.tree(_rng, h, end, 7.0 if not ground else 9.0, 2.0 if not ground else 2.0, 1, 0.45), "ground": ground})
	arc_count_lit = _arcs.size()


func _emit_spark(local_from: Vector2, burst: bool) -> void:
	var ang := _rng.randf() * TAU
	var spd := _rng.randf_range(60.0, 220.0) * (1.6 if burst else 1.0)
	var v := Vector2(cos(ang), sin(ang) * 0.7) * spd
	if mode == Mode.RUSH:
		v -= rush_dir * 140.0
	_push_spark({"p": to_global(local_from), "v": v, "life": _rng.randf_range(0.12, 0.34), "max": 0.34, "size": 2.0 if _rng.randf() < 0.7 else 4.0, "col": LightningFx.WHITE if _rng.randf() < 0.45 else LightningFx.CYAN, "grav": 0.0})


func _emit_dust() -> void:
	var o := Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-2.0, 6.0))
	_push_spark({"p": to_global(o), "v": Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-40.0, -14.0)), "life": _rng.randf_range(0.25, 0.5), "max": 0.5, "size": 2.0, "col": DUST, "grav": 40.0, "dust": true})


func _push_spark(s: Dictionary) -> void:
	if _sparks.size() < MAX_SPARKS:
		_sparks.append(s)
	else:
		_sparks[_spark_i % MAX_SPARKS] = s  # pooled: the oldest slot is reused, never more than MAX_SPARKS alive
		_spark_i += 1
	spark_count = _sparks.size()


func _tick_sparks(delta: float) -> void:
	var i := _sparks.size() - 1
	while i >= 0:
		var s: Dictionary = _sparks[i]
		s.life = float(s.life) - delta
		if float(s.life) <= 0.0:
			_sparks.remove_at(i)
		else:
			s.v = Vector2(s.v) + Vector2(0, float(s.grav)) * delta
			s.p = Vector2(s.p) + Vector2(s.v) * delta
		i -= 1
	spark_count = _sparks.size()


func _spawn_afterimage() -> void:
	var pl := get_parent()
	if pl == null or not ("visual" in pl):
		return
	var vis: PlayerVisual = pl.get("visual")
	if vis == null or vis.actor == null or vis.actor.sprite == null or vis.actor.sprite.sprite_frames == null:
		return
	var spr := vis.actor.sprite
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var s := _after[_after_i % MAX_AFTER]
	_after_i += 1
	s.texture = tex
	s.offset = spr.offset
	s.global_transform = spr.global_transform
	s.modulate = Color(0.45, 0.92, 1.0, 0.6)
	s.visible = true
	_after_age[_after.find(s)] = 0.0


func _tick_afterimages(delta: float) -> void:
	for i in _after.size():
		if _after_age[i] < 0.0:
			continue
		_after_age[i] += delta
		var k := _after_age[i] / AFTER_LIFE
		if k >= 1.0:
			_after_age[i] = -1.0
			_after[i].visible = false
		else:
			_after[i].modulate = Color(0.45, 0.92, 1.0, 0.6 * (1.0 - k))


func afterimages_live() -> int:
	var n := 0
	for a in _after_age:
		if a >= 0.0:
			n += 1
	return n


func _draw() -> void:
	if mode == Mode.OFF:
		return
	var h := hand_local(dir8)
	for a: Dictionary in _arcs:
		LightningFx.draw_tree(self, a.bolts, 1.0)
	# the unstable core: deep blue edge, blue, cyan, white-hot centre; each layer a smaller jagged blob
	if _blob.size() >= 3:
		var off := Transform2D(0.0, h)
		var layers := [[1.55, Color(LightningFx.DEEP, 0.75)], [1.2, LightningFx.BLUE], [0.82, LightningFx.CYAN], [0.45, LightningFx.WHITE]]
		for l in layers:
			var poly := PackedVector2Array()
			for v in _blob:
				poly.append(LightningFx.snap(h + v * float(l[0])))
			draw_colored_polygon(poly, l[1] as Color)
	for s: Dictionary in _sparks:
		var p := to_local(s.p)
		var fade := clampf(float(s.life) / float(s.max), 0.0, 1.0)
		var c := Color(s.col)
		c.a = clampf(fade * 2.0, 0.0, 1.0)
		if s.has("dust") or float(s.size) > 2.0:
			LightningFx.dot(self, p, float(s.size), c)
		else:
			LightningFx.streak(self, p, Vector2(s.v), 7.0, c)


func _draw_glow() -> void:
	if mode == Mode.OFF:
		return
	var h := hand_local(dir8)
	var pulse := 0.75 + 0.25 * sin(t * 47.0) * (1.0 if int(t * 30.0) % 2 == 0 else 0.6)
	var r := lerpf(26.0, 52.0, power) * pulse * (1.3 if mode == Mode.RUSH else 1.0)
	# stepped rings instead of a smooth gradient: crisp, cheap, no shader
	for i in 3:
		var k := 1.0 - float(i) * 0.3
		_glow.draw_set_transform(h, 0.0, Vector2(1.0, 0.85))
		_glow.draw_circle(Vector2.ZERO, r * k, Color(0.25, 0.55, 1.0, 0.08 + 0.05 * float(i)))
	# blue-white flash on the ground around the feet
	_glow.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	_glow.draw_circle(Vector2.ZERO, lerpf(30.0, 66.0, power) * pulse, Color(0.35, 0.7, 1.0, 0.10 + 0.08 * power))
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
