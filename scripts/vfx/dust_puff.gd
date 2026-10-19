class_name DustPuff
extends CPUParticles2D
## Small reusable dirt-puff burst used for footsteps and jump takeoff/landing.
## One node, repositioned and restarted per burst rather than instanced per use -- cheap, and avoids
## scene-tree churn for a purely cosmetic effect. Texture is generated procedurally (a soft circle) so
## this has no external asset dependency.

## Lightened/desaturated highlight version of the courtyard floor tileset's dominant color (see
## assets/environment/kosen_courtyard/floor_tiles/*.png, ~(0.6, 0.54, 0.56)): kicked-up dirt catches
## light and reads brighter than the floor it came from, so this is NOT the floor's own color --
## matching it exactly made the first pass of this effect invisible against the ground.
const DUST_COLOR := Color(0.88, 0.8, 0.68, 0.9)
const BASE_AMOUNT := 8


func _ready() -> void:
	texture = _make_circle_texture()
	emitting = false
	one_shot = true
	amount = BASE_AMOUNT
	lifetime = 0.35
	explosiveness = 0.9
	randomness = 0.3
	direction = Vector2.UP
	spread = 60.0
	initial_velocity_min = 18.0
	initial_velocity_max = 40.0
	gravity = Vector2(0, 90)
	scale_amount_min = 0.5
	scale_amount_max = 1.0
	color = DUST_COLOR
	z_index = 10


## Fire a one-shot burst at `pos` (world space). `strength` scales both particle count and speed, so a
## jump takeoff (bigger kick) can read as more forceful than a single footstep.
func burst(pos: Vector2, strength: float = 1.0) -> void:
	global_position = pos
	amount = maxi(1, int(roundf(BASE_AMOUNT * strength)))
	initial_velocity_min = 18.0 * strength
	initial_velocity_max = 40.0 * strength
	restart()
	emitting = true


## Tiny soft-edged circle, generated once at runtime: a radial alpha falloff so puffs look like soft
## dust clumps rather than hard-edged dots, with no external art dependency.
static func _make_circle_texture() -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
