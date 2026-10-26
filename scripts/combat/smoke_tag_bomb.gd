class_name SmokeTagBomb
extends PaperTagBomb
## Shares tested ballistic flight and wall landing. Detonation is smoke only: no damage, hitstop or scorch.
## AI visibility/stealth integration is intentionally left to the gameplay owner.
const SMOKE_SECONDS := 5.0
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

func explode() -> void:
	if detonated:
		return
	detonated = true
	phase = Phase.BLAST
	blast_t = 0.0
	_body.visible = false
	_shadow.visible = false
	_halo.visible = false
	for i in 5:
		var cloud := Sprite2D.new()
		cloud.name = "SmokeCloud%d" % i
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.z_index = 10 + i
		cloud.offset = Vector2(0, -80)
		cloud.position = Vector2((i % 3 - 1) * 48, (i / 3) * 18 - 24)
		add_child(cloud)
		clouds.append(cloud)
	_refresh_smoke()

func _step_blast(delta: float) -> void:
	blast_t += delta
	if blast_t >= SMOKE_SECONDS:
		phase = Phase.DONE
		queue_free()

func apply_damage() -> void:
	pass

func _refresh_visual() -> void:
	if phase == Phase.BLAST:
		_refresh_smoke()
	else:
		super._refresh_visual()

func _refresh_smoke() -> void:
	var list := TagBombArt.frames("smoke_tag_bomb", "smoke")
	var billow := TagBombArt.frames("smoke_tag_bomb", "billow")
	if list.is_empty():
		return
	for i in clouds.size():
		var t := maxf(blast_t - float(i) * 0.09, 0.0)
		var u := clampf(t / SMOKE_SECONDS, 0.0, 1.0)
		var cloud := clouds[i]
		cloud.texture = list[mini(int(t * 18.0), list.size() - 1)] if t < float(list.size())/18.0 or billow.is_empty() else billow[int((t-float(list.size())/18.0)*14.0) % billow.size()]
		cloud.flip_h = i % 2 == 1
		cloud.position.x = roundf((i % 3 - 1) * 48 + sin(t * 1.6 + i) * 10 + t * (i - 2) * 4)
		cloud.position.y = roundf((i / 3) * 18 - 24 - t * 12)
		cloud.modulate = Color(0.88 + i * 0.025, 0.88 + i * 0.025, 0.88 + i * 0.025, smoothstep(0.0, 0.13, t) * (1.0 - smoothstep(0.45, 1.0, u)) * 0.72)
