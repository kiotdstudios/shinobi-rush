class_name LogPip
extends RefCounted
## The substitution-jutsu charge pip: the real log art (assets/ui/hud/log_icon*.png, 38x26). Full = colour log, spent = grey log.
## When a charge is spent the log wiggles (damped shake) and then pops into a puff of smoke, leaving the grey log behind.
## Pure drawing helper shared by the player HUD and the Bandit's world bars; callers track `age` (seconds since the charge was spent, -1 = idle).

const DIR := "res://assets/ui/hud/"
const ART_SIZE := Vector2(38.0, 26.0)
const DURATION := 0.9  ## whole animation
const WIGGLE_TIME := 0.32  ## colour log shakes this long, then poofs
const PUFFS := 6

static var _tex: Dictionary = {}


static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png") as Texture2D
	return _tex[n]


## Draw one pip with its top-left at `at`, scaled by `s`. `age` < 0 or > DURATION means no animation.
static func draw(ci: CanvasItem, at: Vector2, s: float, full: bool, age: float) -> void:
	var size := ART_SIZE * s
	var centre := at + size * 0.5
	var animating := age >= 0.0 and age <= DURATION
	if animating and age < WIGGLE_TIME:
		# the charge is being spent: colour log wiggles harder and harder, then pops
		var k := age / WIGGLE_TIME
		var ang := sin(age * 70.0) * (0.15 + 0.35 * k)
		var jitter := Vector2(sin(age * 95.0), cos(age * 83.0)) * 1.5 * s * k
		ci.draw_set_transform(centre + jitter, ang, Vector2.ONE)
		ci.draw_texture_rect(tex("log_icon"), Rect2(-size * 0.5, size), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	ci.draw_texture_rect(tex("log_icon" if full else "log_icon_gray"), Rect2(at, size), false)
	if animating:
		_smoke(ci, centre, size, age - WIGGLE_TIME)


static func _smoke(ci: CanvasItem, centre: Vector2, size: Vector2, t: float) -> void:
	var span := DURATION - WIGGLE_TIME
	var k := clampf(t / span, 0.0, 1.0)
	for i in PUFFS:
		var a := TAU * float(i) / PUFFS + 0.6
		var dir := Vector2(cos(a), sin(a) * 0.7)
		var p := centre + dir * size.x * (0.15 + 0.45 * k) + Vector2(0.0, -size.y * 0.7 * k)
		var r := size.y * (0.22 + 0.4 * k) * (0.8 + 0.2 * float(i % 3))
		var grey := 0.82 - 0.25 * k
		ci.draw_circle(p, r, Color(grey, grey, grey + 0.04, 0.8 * (1.0 - k)))
	# a brief white flash at the pop
	if k < 0.25:
		ci.draw_circle(centre, size.y * 0.7, Color(1, 1, 1, 0.5 * (1.0 - k * 4.0)))
