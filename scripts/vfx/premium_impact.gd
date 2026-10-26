class_name PremiumImpact
extends Sprite2D
## Authored local impact frames; never a screen flash, hitbox or hitstop timer.
const DURATIONS := [0.02,0.02,0.03,0.03,0.035,0.035,0.04,0.04,0.045,0.045,0.05,0.05]
var age := 0.0
var auto_advance := true
func _ready() -> void:
	texture = load("res://assets/vfx/premium_damage/impact.png")
	hframes = 4
	vframes = 3
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	if auto_advance:advance(delta)
func advance(delta: float) -> void:
	age += delta
	var total := 0.0
	for i in DURATIONS.size():
		total += DURATIONS[i]
		if age < total:
			frame = i
			return
	queue_free()
static func spawn(parent: Node, point: Vector2, direction: Vector2, heavy: bool = true) -> PremiumImpact:
	var impact := PremiumImpact.new()
	parent.add_child(impact)
	impact.global_position = point.round()
	impact.global_rotation = direction.angle()
	impact.global_scale = Vector2.ONE*(0.95 if heavy else 0.65)
	return impact
