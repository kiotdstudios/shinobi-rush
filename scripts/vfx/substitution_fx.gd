class_name SubstitutionFx
extends Node2D
## One-shot Substitution Jutsu effect (Codex art pack, assets/vfx/substitution/substitution.json).
## Departure smoke + ribbons + the replacement log play at the OUTGOING foot origin; the arrival
## burst plays at the NEW foot origin after `ARRIVAL_DELAY`. Image top-left = foot origin - pivot.
## The log stays on the ground for `LOG_LIFETIME` seconds, then fades and frees. Plays in _process
## so it freezes with the tree pause.

const DIR := "res://assets/vfx/substitution/"
const JSON_PATH := "res://assets/vfx/substitution/substitution.json"
const ARRIVAL_DELAY := 0.08
const LOG_LIFETIME := 2.95
const LOG_FALL_START := 0.48
const LOG_IMPACT := 1.02
const LOG_POOF := 1.88
const LOG_SMOKE_END := 2.95
const FADE := 0.4
const Z := 20

static var _clips: Dictionary = {}

var _tracks: Array = []
var _age: float = 0.0
var _log_foot := Vector2.ZERO
var _log_sprite: Sprite2D
var _log_body: StaticBody2D
var _smoke_seed := 0


## Spawns the effect under `parent`; `old_foot`/`new_foot` are world foot origins.
static func spawn(parent: Node, old_foot: Vector2, new_foot: Vector2) -> SubstitutionFx:
	if parent == null:
		return null
	var fx := SubstitutionFx.new()
	fx.name = "SubstitutionFx"
	parent.add_child(fx)
	fx.z_index = Z
	fx._run(old_foot, new_foot)
	return fx


static func clip(name: String) -> Dictionary:
	if _clips.is_empty():
		var f := FileAccess.open(JSON_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in (parsed as Dictionary).get("clips", {}):
					var c: Dictionary = parsed["clips"][k]
					var tex: Array = []
					for p in c.get("frames", []):
						tex.append(load(DIR + str(k) + "/" + str(p).get_file()) as Texture2D)
					_clips[k] = {
						"tex": tex,
						"pivot": Vector2(c["pivot"][0], c["pivot"][1]),
						"dur": c.get("duration_ms", []),
						"hold_last": bool(c.get("hold_last", false)),
					}
	return _clips.get(name, {})


func _run(old_foot: Vector2, new_foot: Vector2) -> void:
	_log_foot = old_foot
	_smoke_seed = int(absf(old_foot.x * 17.0 + old_foot.y * 31.0)) % 997
	_add_track("log", old_foot, 0.04, LOG_LIFETIME)
	_create_log_collider()
	_add_track("departure", old_foot, 0.0, 0.0)
	_add_track("ribbons", old_foot, 0.0, 0.0)
	_add_track("arrival", new_foot, ARRIVAL_DELAY, 0.0)


func _add_track(name: String, foot: Vector2, delay: float, hold_for: float) -> void:
	var c := clip(name)
	if c.is_empty() or (c["tex"] as Array).is_empty():
		return
	var s := Sprite2D.new()
	s.centered = false
	s.visible = false
	s.global_position = foot - (c["pivot"] as Vector2)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	s.global_position = foot - (c["pivot"] as Vector2)
	_tracks.append({"sprite": s, "clip": c, "delay": delay, "hold_for": hold_for, "name": name})
	if name == "log":
		_log_sprite = s


## The discarded log is a physical object until it dissolves. It is deliberately
## placed at the departure point, not the teleport destination.
func _create_log_collider() -> void:
	_log_body = StaticBody2D.new()
	_log_body.name = "SubstitutionLogCollision"
	_log_body.collision_layer = 1
	_log_body.collision_mask = 0
	add_child(_log_body)
	_log_body.global_position = _log_foot
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 17)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	_log_body.add_child(shape)


func live_tracks() -> int:
	return _tracks.size()


func _process(delta: float) -> void:
	_age += delta
	_update_log_motion()
	queue_redraw()
	var alive: Array = []
	for t in _tracks:
		var s: Sprite2D = t["sprite"]
		var c: Dictionary = t["clip"]
		var local: float = _age - float(t["delay"])
		if t["name"] == "log" and _age >= LOG_POOF:
			s.visible = false
			if _age < LOG_SMOKE_END:
				alive.append(t)
			else:
				s.queue_free()
			continue
		if local < 0.0:
			alive.append(t)
			continue
		var tex: Array = c["tex"]
		var dur: Array = c["dur"]
		var acc := 0.0
		var idx := -1
		for i in tex.size():
			acc += float(dur[i] if i < dur.size() else 40) / 1000.0
			if local < acc:
				idx = i
				break
		if idx == -1:
			if c["hold_last"] and local < float(t["hold_for"]):
				idx = tex.size() - 1
			else:
				s.queue_free()
				continue
		s.visible = true
		s.texture = tex[idx]
		var hold: float = float(t["hold_for"])
		if hold > 0.0 and local > hold - FADE:
			s.modulate.a = clampf((hold - local) / FADE, 0.0, 1.0)
		alive.append(t)
	_tracks = alive
	if _tracks.is_empty() and _age >= LOG_SMOKE_END:
		queue_free()


## Four beats: startled wobble -> off-axis topple -> ground bounce -> smoke poof.
## All movement is relative to the same foot pivot; the log never pops through
## the floor, and the collider disappears at the exact poof frame.
func _update_log_motion() -> void:
	if _log_sprite == null or not is_instance_valid(_log_sprite):
		return
	if _age < LOG_FALL_START:
		# Big anticipation: a violent stagger followed by a split-second hang.
		var t := _age / LOG_FALL_START
		var shake := sin(t * TAU * 4.0) * (1.0 - t * 0.3)
		_log_sprite.rotation = shake * 0.23 + sin(t * PI) * -0.15
		_log_sprite.position = Vector2(shake * 6.0, -sin(t * PI) * 9.0)
		_log_sprite.scale = Vector2(1.0 + 0.12 * sin(t * PI), 1.0 - 0.13 * sin(t * PI))
	elif _age < LOG_IMPACT:
		# Quick airborne whip and near-horizontal slam; acceleration increases
		# sharply in the last half rather than gently easing to the floor.
		var t := clampf((_age - LOG_FALL_START) / (LOG_IMPACT - LOG_FALL_START), 0.0, 1.0)
		var drop := t * t
		_log_sprite.rotation = lerpf(-0.12, 1.78, drop) + sin(t * PI) * 0.22
		_log_sprite.position = Vector2(25.0 * drop, -25.0 * sin(t * PI) + 16.0 * drop)
		_log_sprite.scale = Vector2(1.0 + 0.16 * t, 1.0 - 0.12 * t)
	elif _age < LOG_POOF:
		# Crunch on impact, rebound, then two increasingly tiny rattles.
		var t := (_age - LOG_IMPACT) / (LOG_POOF - LOG_IMPACT)
		var bounce := absf(sin(t * PI * 4.0)) * exp(-5.2 * t)
		var impact_compress := exp(-22.0 * t)
		_log_sprite.rotation = 1.78 + bounce * 0.25 - impact_compress * 0.12
		_log_sprite.position = Vector2(25.0 + t * 5.0, 16.0 - bounce * 15.0 + impact_compress * 5.0)
		_log_sprite.scale = Vector2(1.0 + impact_compress * 0.35, 1.0 - impact_compress * 0.35)
		_log_sprite.modulate = Color.WHITE
	else:
		_log_sprite.visible = false
		if _log_body != null and is_instance_valid(_log_body):
			_log_body.queue_free()
			_log_body = null

## Pixel-like smoke puffs, small sparks and ground impact ring. Drawn in
## world coordinates through to_local so FX stays anchored even with a
## transformed parent. No random() per frame: reproducible puff trajectories.
func _draw() -> void:
	var p := to_local(_log_foot)
	if _age >= LOG_IMPACT and _age < LOG_IMPACT + 0.52:
		var t := (_age - LOG_IMPACT) / 0.52
		draw_arc(p + Vector2(25, 3), lerpf(7, 57, t), 0.0, TAU, 22, Color(0.78, 0.82, 0.88, (1.0 - t) * 0.55), 2.0)
		for i in 13:
			var a := TAU * float(i) / 13.0
			var q := p + Vector2(25, 3) + Vector2(cos(a) * 52.0 * t, sin(a) * 22.0 * t - sin(t * PI) * 14.0)
			draw_rect(Rect2(q, Vector2(4, 4)), Color(0.91, 0.87, 0.76, 1.0 - t))
	if _age >= LOG_IMPACT and _age < LOG_IMPACT + 0.14:
		var flash := 1.0 - (_age - LOG_IMPACT) / 0.14
		draw_circle(p + Vector2(25, 3), 17.0 * flash, Color(1.0, 0.95, 0.78, flash * 0.48))
	if _age < LOG_POOF or _age >= LOG_SMOKE_END:
		return
	var t := clampf((_age - LOG_POOF) / (LOG_SMOKE_END - LOG_POOF), 0.0, 1.0)
	var fade := pow(1.0 - t, 1.3)
	for i in 14:
		var a := TAU * float(i) / 14.0 + float(_smoke_seed % 13) * 0.09
		var offset := Vector2(cos(a) * (7.0 + 36.0 * t), sin(a) * (4.0 + 17.0 * t) - 30.0 * t)
		var wobble := sin(t * 11.0 + float(i) * 1.8) * 4.0 * t
		var q := p + Vector2(10, -8) + offset + Vector2(wobble, 0)
		var radius := (9.0 + float(i % 4) * 2.5) * (0.55 + t * 0.65)
		var shade := Color(0.77, 0.83, 0.91, fade * 0.82) if i % 3 else Color(0.98, 0.98, 1.0, fade * 0.9)
		draw_circle(q, radius, shade)
