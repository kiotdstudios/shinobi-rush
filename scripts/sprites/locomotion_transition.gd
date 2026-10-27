class_name LocomotionTransition
extends RefCounted
## Presentation only. No velocity, input, collision, AI or combat writes.
## Timed contact poses reuse approved art; direction changes never rotate the sprite.

const DURATIONS := {"start": 0.10, "stop": 0.13, "pivot": 0.12}
const PIVOT_DOT := 0.20
const PIVOT_COOLDOWN := 0.22
var enabled := true
var kind := ""
var elapsed := 0.0
var cooldown := 0.0
var was_moving := false
var heading := Vector2.ZERO
var candidate_heading := Vector2.ZERO
var heading_hold := 0.0
var from_heading := Vector2.DOWN
var to_heading := Vector2.DOWN
var gait := "run"
var completed := false

func interrupt() -> void:
	kind = ""
	was_moving = false
	heading = Vector2.ZERO
	candidate_heading = Vector2.ZERO
	heading_hold = 0.0
	completed = false
	cooldown = 0.0

func update(delta: float, moving: bool, travel: Vector2, facing: Vector2, sprinting: bool) -> void:
	completed = false
	cooldown = maxf(0.0, cooldown - delta)
	if kind != "":
		elapsed += delta
		if elapsed >= float(DURATIONS[kind]):
			kind = ""
			completed = true
	var direction := travel.normalized() if travel.length_squared() > 0.01 else facing.normalized()
	if not enabled:
		interrupt()
		return
	if moving and not was_moving:
		_begin("start", facing, facing, sprinting)
		heading = direction
	elif not moving and was_moving:
		_begin("stop", facing, facing, gait == "sprint")
	elif moving and cooldown <= 0.0 and heading != Vector2.ZERO and heading.dot(direction) <= PIVOT_DOT:
		_begin("pivot", from_heading if kind == "pivot" else to_heading, facing, sprinting)
		cooldown = PIVOT_COOLDOWN
		heading = direction
	was_moving = moving
	if moving:
		# Keyboard corners commonly pass through one diagonal frame. Keep the last
		# stable travel heading until steering settles, so 45+45 degrees is still a
		# sharp 90-degree turn; deliberate slow steering does not accumulate pivots.
		if candidate_heading.dot(direction) < 0.999:
			candidate_heading = direction
			heading_hold = 0.0
		else:
			heading_hold += delta
		if heading_hold >= 0.12:
			heading = direction
		if kind != "pivot":
			to_heading = facing
		gait = "sprint" if sprinting else "run"

func _begin(next: String, source: Vector2, target: Vector2, sprinting: bool) -> void:
	kind = next
	elapsed = 0.0
	completed = false
	from_heading = source
	to_heading = target
	gait = "sprint" if sprinting else "run"

func show(actor: SpriteActor, art: SpriteSet) -> bool:
	if kind == "" or art == null:
		return false
	var aid := "move_" + kind + ("_sprint" if gait == "sprint" else "")
	if not art.animations.has(aid):
		return false  # Existing loops are the complete graceful fallback.
	var progress := clampf(elapsed / float(DURATIONS[kind]), 0.0, 0.9999)
	var face := to_heading
	if kind == "pivot":
		# Three actual directional silhouettes: old contact, middle planted turn, new push-off.
		var turn_step := minf(floorf(progress * 3.0) / 2.0, 1.0)
		face = from_heading.rotated(from_heading.angle_to(to_heading) * turn_step)
	return actor.show_animation_at(art, aid, SpriteSet.dir_name(face), progress)
