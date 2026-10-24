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
const LOG_LIFETIME := 3.0
const FADE := 0.4
const Z := 20

static var _clips: Dictionary = {}

var _tracks: Array = []
var _age: float = 0.0


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
	_add_track("log", old_foot, 0.04, LOG_LIFETIME)
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
	_tracks.append({"sprite": s, "clip": c, "delay": delay, "hold_for": hold_for})


func live_tracks() -> int:
	return _tracks.size()


func _process(delta: float) -> void:
	_age += delta
	var alive: Array = []
	for t in _tracks:
		var s: Sprite2D = t["sprite"]
		var c: Dictionary = t["clip"]
		var local: float = _age - float(t["delay"])
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
	if _tracks.is_empty():
		queue_free()
