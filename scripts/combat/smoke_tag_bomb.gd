class_name SmokeTagBomb
extends PaperTagBomb
## Shares tested ballistic flight and wall landing. Detonation is smoke only: no damage, hitstop or scorch.
## While it stands the screen blocks sight both ways: Bandits cannot see into or through it (Bandit.can_see,
## the vision overlay), the player cannot lock on to or sense anything inside or behind it (PlayerLockOn,
## ProximitySense). Melee and contact hits are not sight and still land inside it.
const SMOKE_SECONDS := 5.0
const BURST_FPS := 14.0
const LOOP_FPS := 10.0
const FADE_FPS := 11.0
## Floor ellipse of the screen (iso 2:1: half as deep as it is wide), sized to the drawn banks.
const COVER_RADIUS := 165.0
const ISO_Y := 2.0
## Sight comes back over the first part of the fade, while the puffs break apart.
const CLEAR_SHARE := 0.6
## Three PixelLab banks: one behind, two in front (mirrored), each with its own timing so the screen never pulses as one.
const BANKS := [
	{"pos": Vector2(0, 4), "delay": 0.0, "shade": 0.8, "flip": false},
	{"pos": Vector2(-80, 60), "delay": 0.07, "shade": 1.0, "flip": false},
	{"pos": Vector2(82, 68), "delay": 0.13, "shade": 0.93, "flip": true},
]
const BANK_FOOT := Vector2(0, -70)  ## 256 x 192 frames: the bank's base sits 70 px below the frame centre

static var screens: Array[SmokeTagBomb] = []

var clouds: Array[Sprite2D] = []


static func spawn_smoke(parent: Node, from: Vector2, aim: Vector2, who: Node2D) -> SmokeTagBomb:
	if parent == null:
		return null
	var bomb := SmokeTagBomb.new()
	bomb.art_kind = "smoke_tag_bomb"
	bomb.dir = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	bomb.thrower = who
	parent.add_child(bomb)
	bomb.global_position = from
	bomb._start = from
	return bomb


## The first standing screen the floor segment a -> b runs into: {"t": 0..1 along the segment, "screen", "normal"}
## ({} when the line is clear). A segment starting inside a screen is cut at t = 0, so a point inside one is hidden.
static func first_cover(a: Vector2, b: Vector2) -> Dictionary:
	var best := {}
	for s in screens:
		if not is_instance_valid(s) or not s.is_inside_tree():
			continue
		var r := s.cover_radius()
		if r <= 0.0:
			continue
		var c := s.global_position
		var f := Vector2(a.x - c.x, (a.y - c.y) * ISO_Y)
		var d := Vector2(b.x - a.x, (b.y - a.y) * ISO_Y)
		var t := -1.0
		if f.length_squared() <= r * r:
			t = 0.0
		else:
			var qa := d.length_squared()
			if qa < 1.0e-9:
				continue
			var qb := 2.0 * f.dot(d)
			var disc := qb * qb - 4.0 * qa * (f.length_squared() - r * r)
			if disc < 0.0:
				continue
			t = (-qb - sqrt(disc)) / (2.0 * qa)
			if t < 0.0 or t > 1.0:
				continue
		if best.is_empty() or t < float(best.t):
			var h := f + d * t
			best = {"t": t, "screen": s, "normal": Vector2(h.x, h.y * ISO_Y).normalized()}
	return best


static func blocks_sight(a: Vector2, b: Vector2) -> bool:
	return not first_cover(a, b).is_empty()


static func hides(p: Vector2) -> bool:
	return blocks_sight(p, p)


## Floor radius the screen covers right now: grows with the burst, gives way as the fade breaks it up, 0 when not standing.
func cover_radius() -> float:
	if phase != Phase.BLAST:
		return 0.0
	var grow := clampf(blast_t / _burst_seconds(), 0.0, 1.0)
	var fade_t := _fade_seconds()
	var clear := clampf((blast_t - (SMOKE_SECONDS - fade_t)) / (fade_t * CLEAR_SHARE), 0.0, 1.0)
	return COVER_RADIUS * minf(grow, 1.0 - clear)


func explode() -> void:
	if detonated:
		return
	detonated = true
	phase = Phase.BLAST
	blast_t = 0.0
	_body.visible = false
	_shadow.visible = false
	_halo.visible = false
	for i in BANKS.size():
		var bank: Dictionary = BANKS[i]
		var cloud := Sprite2D.new()
		cloud.name = "SmokeCloud%d" % i
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.z_index = 10 + i
		cloud.offset = BANK_FOOT
		cloud.position = bank.pos
		cloud.flip_h = bank.flip
		add_child(cloud)
		clouds.append(cloud)
	screens.append(self)
	_refresh_smoke()


func _exit_tree() -> void:
	screens.erase(self)


func _step_blast(delta: float) -> void:
	blast_t += delta
	if blast_t >= SMOKE_SECONDS:
		phase = Phase.DONE
		screens.erase(self)
		queue_free()


func apply_damage() -> void:
	pass


func _refresh_visual() -> void:
	if phase == Phase.BLAST:
		_refresh_smoke()
	else:
		super._refresh_visual()


static func _burst_seconds() -> float:
	return maxf(float(TagBombArt.frames("smoke_tag_bomb", "screen_burst").size()) / BURST_FPS, 0.1)


static func _fade_seconds() -> float:
	return maxf(float(TagBombArt.frames("smoke_tag_bomb", "screen_fade").size()) / FADE_FPS, 0.1)


## burst once, loop while the screen stands, then the fade plays out to the last frame exactly at SMOKE_SECONDS.
func _refresh_smoke() -> void:
	var burst := TagBombArt.frames("smoke_tag_bomb", "screen_burst")
	var loop := TagBombArt.frames("smoke_tag_bomb", "screen_loop")
	var fade := TagBombArt.frames("smoke_tag_bomb", "screen_fade")
	if burst.is_empty() or loop.is_empty() or fade.is_empty():
		return
	var fade_start := SMOKE_SECONDS - _fade_seconds()
	for i in clouds.size():
		var bank: Dictionary = BANKS[i]
		var t := blast_t - float(bank.delay)
		var cloud := clouds[i]
		cloud.visible = t >= 0.0
		if t < 0.0:
			continue
		var tex: Texture2D
		if blast_t >= fade_start:
			tex = fade[mini(int((blast_t - fade_start) * FADE_FPS), fade.size() - 1)]
		elif t < float(burst.size()) / BURST_FPS:
			tex = burst[mini(int(t * BURST_FPS), burst.size() - 1)]
		else:
			var k := int((t - float(burst.size()) / BURST_FPS) * LOOP_FPS) + i * 5
			tex = loop[k % loop.size()]
		cloud.texture = tex
		var drift := minf(blast_t, fade_start) * 3.0
		var home: Vector2 = bank.pos
		cloud.position = home + Vector2(roundf(sin(t * 0.9 + float(i) * 2.1) * 4.0 + home.x * drift * 0.004), -roundf(drift))
		var shade: float = bank.shade
		cloud.modulate = Color(shade, shade, shade, 1.0)
