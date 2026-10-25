class_name HealthGourd
extends Node2D
## Gourd pickup: floats and glows above the floor. kind "health" (red) restores 25% of max HP, kind "chakra" (blue)
## restores 25% of max chakra, each only when the player is actually missing some.
##
## Art is PixelLab-generated (assets/pickups/health_gourd/): `gourd_NN.png` is the looping float/sway
## sequence of the gourd itself, `glow_NN.png` the looping red aura (drawn additively behind it) and
## `ember_NN.png` rising sparks (additive, in front). All frames of a set share one canvas size, centred on
## the same point, so the loop never jitters. The node sits on the FLOOR (its position is where it
## casts its pool of red light) and the art hovers FLOAT_HEIGHT above that.
##
## A taken gourd fades out and comes back after RESPAWN_SECONDS. It is only taken when the player is
## actually hurt, so walking past at full health wastes nothing.

signal collected(amount: float)

const DIR := "res://assets/pickups/health_gourd/"
const HEAL := 25.0
const GROUP := "health_pickup"
const CHAKRA_GROUP := "chakra_pickup"
## Share of the player's maximum a gourd gives back.
const FRACTION := 0.25
const KINDS := {
	"kunai": {"dir": "res://assets/weapons/kunai/", "group": "kunai_pickup", "color": Color.WHITE, "aura": Color.WHITE},
	"tag_bomb": {"dir": "res://assets/pickups/tag_bomb/", "group": "bomb_pickup", "color": Color(1.0, 0.25, 0.08), "aura": Color(1.0, 0.65, 0.3)},
	"smoke_tag_bomb": {"dir": "res://assets/pickups/smoke_tag_bomb/", "group": "smoke_bomb_pickup", "color": Color(0.9, 0.12, 0.16), "aura": Color(1.0, 0.5, 0.45)},
	"health": {"dir": "res://assets/pickups/health_gourd/", "group": "health_pickup", "color": Color(1.0, 0.18, 0.1), "aura": Color(1.0, 0.5, 0.4)},
	"chakra": {"dir": "res://assets/pickups/chakra_gourd/", "group": "chakra_pickup", "color": Color(0.15, 0.55, 1.0), "aura": Color(0.45, 0.8, 1.0)},
	"paper_tag": {"dir": "res://assets/pickups/paper_tag/", "group": "tag_pickup", "color": Color(1.0, 0.45, 0.08), "aura": Color(1.0, 0.7, 0.3)},
}
## Floor-plane pick-up radius (the iso floor is squashed 2:1, so y is doubled before measuring).
const PICKUP_RADIUS := 40.0
const RESPAWN_SECONDS := 30.0
const FLOAT_HEIGHT := 56.0
const GOURD_FPS := 14.0
const BOB := 4.0
const BEAM_HEIGHT := 170.0
const BOB_SPEED := 2.3
const GLOW_FPS := 12.0
const EMBER_FPS := 12.0
const GLOW_COLOR := Color(1.0, 0.18, 0.1)

static var _cache: Dictionary = {}

## "health" or "chakra"; set before the node enters the tree.
var kind := "health"
var available := true
var grounded := false  ## recovered kunai rests on the floor; authored pickups hover
var respawns := true
var resting_rotation := 0.35
var respawn_left := 0.0

var _clock := 0.0
var _visual: Node2D
var _pool: Node2D
var _glow: Sprite2D
var _body: Sprite2D
var _embers: Sprite2D
var _tween: Tween
var fx: GourdPickupFx  ## the take-it animation while it plays


## Frames of one layer ("gourd", "glow", "ember"), loaded once and shared by every gourd.
static func frames(layer: String, p_kind := "health") -> Array:
	if p_kind == "kunai":
		return [load("res://assets/weapons/kunai/black_kunai.png")] if layer == "gourd" else []
	if p_kind in ["tag_bomb", "smoke_tag_bomb"]:
		if layer == "gourd":
			return TagBombArt.frames(p_kind, "idle")
		# Reuse the established orange pickup aura and embers, tinted by KINDS.
		return frames(layer, "paper_tag")
	var key := p_kind + "/" + layer
	if _cache.has(key):
		return _cache[key]
	var dir: String = KINDS[p_kind].dir
	var list: Array = []
	var i := 0
	while ResourceLoader.exists(dir + "%s_%02d.png" % [layer, i]):
		list.append(load(dir + "%s_%02d.png" % [layer, i]))
		i += 1
	_cache[key] = list
	return list


## A still of the gourd for the builder's palette card and placement ghost.
static func icon(p_kind := "health") -> Texture2D:
	var list := frames("gourd", p_kind)
	return list[0] if not list.is_empty() else null


func _ready() -> void:
	add_to_group(String(KINDS[kind].group))
	_pool = Node2D.new()
	_pool.name = "LightPool"
	_pool.z_index = -1
	add_child(_pool)
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.position = Vector2(0, -FLOAT_HEIGHT)
	add_child(_visual)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _layer("Glow", add_mat)
	_body = _layer("Body", null)
	if kind in ["tag_bomb", "smoke_tag_bomb"]:
		_body.scale = Vector2.ONE * 0.5
	_embers = _layer("Embers", add_mat)
	_pool.draw.connect(_draw_pool)
	GourdPickupFx.pickup_sound.call_deferred()  # synthesize the layered clip once, not in the middle of a pickup
	_clock = randf() * 10.0  # gourds placed together do not pulse in lockstep
	_apply_frames()


func _layer(layer_name: String, mat: Material) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = layer_name
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = mat
	_visual.add_child(s)
	return s


func _process(delta: float) -> void:
	_clock += delta
	if not available:
		if not respawns:
			return
		respawn_left -= delta
		if respawn_left <= 0.0:
			_return()
		return
	_apply_frames()
	_pool.queue_redraw()
	_try_collect()


func _apply_frames() -> void:
	if kind == "kunai":
		_visual.position.y = -3.0 if grounded else -FLOAT_HEIGHT
		_body.texture = icon("kunai")
		_body.scale = Vector2(0.7,0.45) if grounded else Vector2.ONE
		_body.position.y = 0.0 if grounded else roundf(sin(_clock * BOB_SPEED) * BOB)
		_body.rotation = resting_rotation if grounded else sin(_clock * 1.4) * 0.15 - 0.35
		_glow.visible = false
		_embers.visible = false
		return
	# Whole-pixel bob on top of the painted sway: the gourd rises and falls BOB px, the aura trails it a little.
	_body.position.y = roundf(sin(_clock * BOB_SPEED) * BOB)
	_glow.position.y = roundf(sin(_clock * BOB_SPEED - 0.7) * BOB)
	var breathe := 0.5 + 0.5 * sin(_clock * 3.1)
	_glow.scale = Vector2.ONE * lerpf(1.25, 1.55, breathe)
	_glow.rotation = _clock * 0.35  # the aura's painted sparks orbit the gourd
	var aura: Color = KINDS[kind].aura
	_glow.modulate = Color(aura.r, aura.g, aura.b, lerpf(0.6, 1.0, breathe))  # deeper red: keeps the aura's pale sparks from reading pink
	_set_frame(_body, "gourd", GOURD_FPS)
	_set_frame(_glow, "glow", GLOW_FPS)
	_set_frame(_embers, "ember", EMBER_FPS, true)


func _set_frame(s: Sprite2D, layer: String, fps: float, ping_pong := false) -> void:
	var list := frames(layer, kind)
	s.visible = not list.is_empty()
	if not list.is_empty():
		var n := int(_clock * fps)
		s.texture = list[pingpong(n, list.size() - 1) if ping_pong else n % list.size()]


## Pulsing pool of red light on the floor under the gourd (a squashed disc, bright core to clear edge).
func _draw_pool() -> void:
	if kind == "kunai":
		_draw_kunai_light()
		return
	var glow_color: Color = KINDS[kind].color
	var pulse := 0.5 + 0.5 * sin(_clock * 3.1)
	for i in 7:
		var k := float(i) / 6.0
		var r := lerpf(46.0, 12.0, k) * (0.94 + 0.06 * pulse)
		var a := lerpf(0.05, 0.2, k) * (0.8 + 0.4 * pulse)
		var pts := PackedVector2Array()
		for j in 24:
			var t := TAU * float(j) / 24.0
			pts.append(Vector2(cos(t) * r, sin(t) * r * 0.5))
		_pool.draw_colored_polygon(pts, Color(glow_color, a))
	# Faint vertical beam of red light rising from the floor pool (the gold reference has one).
	var beam_a := 0.16 + 0.07 * pulse
	var bx := PackedVector2Array([Vector2(-17, 0), Vector2(17, 0), Vector2(9, -BEAM_HEIGHT), Vector2(-9, -BEAM_HEIGHT)])
	_pool.draw_polygon(bx, PackedColorArray([Color(glow_color, beam_a), Color(glow_color, beam_a), Color(glow_color, 0.0), Color(glow_color, 0.0)]))


## Is this gourd currently able to be taken by a player standing at `feet`?
func can_collect(player: Node) -> bool:
	if not available or not is_visible_in_tree() or not (player is Node2D):
		return false
	if not (player as Node2D).is_visible_in_tree():
		return false  # map editor hides/freezes the actor; placing loot must not collect it
	var inv: Variant = player.get("inventory")
	if not (inv is PlayerInventory) or not (inv as PlayerInventory).has_room(item_id()):
		return false
	var d: Vector2 = (player as Node2D).global_position - global_position
	return Vector2(d.x, d.y * 2.0).length() <= PICKUP_RADIUS


## The inventory item this gourd turns into.
func item_id() -> String:
	match kind:
		"kunai", "tag_bomb", "smoke_tag_bomb":
			return kind
		"chakra":
			return "chakra_gourd"
		"paper_tag":
			return "paper_tag"
	return "health_gourd"


func _try_collect() -> void:
	for p: Node in get_tree().get_nodes_in_group("player"):
		if can_collect(p):
			collect(p)
			return


## Put this gourd in `player`'s inventory (it is eaten later from its D-pad slot, see PlayerController.use_slot), play
## the take-it animation and start the respawn timer. Returns how many items went into the bag (0 when it is full).
func collect(player: Node) -> float:
	if not available:
		return 0.0
	var inv: Variant = player.get("inventory")
	var gained := 0.0
	if inv is PlayerInventory:
		gained = float((inv as PlayerInventory).add(item_id(), 1))
	if gained <= 0.0:
		return 0.0
	var before_fraction := 1.0
	available = false
	respawn_left = RESPAWN_SECONDS if respawns else 0.0
	if not respawns:
		get_tree().create_timer(1.5).timeout.connect(queue_free)
	collected.emit(gained)
	if _tween != null:
		_tween.kill()
	if fx != null and is_instance_valid(fx):
		fx.queue_free()
	_visual.modulate = Color.WHITE
	# The gourd does not just vanish: GourdPickupFx squashes it, bursts it, warps it into the player's chest and
	# drives its visual; only the floor light fades out here.
	_tween = create_tween()
	_tween.tween_property(_pool, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void: _pool.visible = false)
	fx = GourdPickupFx.start(self, player as Node2D, gained, before_fraction) if player is Node2D else null
	if fx == null:
		_visual.visible = false
	return gained


func _return() -> void:
	available = true
	if fx != null and is_instance_valid(fx):
		fx.queue_free()
	fx = null
	_visual.rotation = 0.0
	_glow.modulate = Color.WHITE
	if _tween != null:
		_tween.kill()
	_visual.position = Vector2(0, -FLOAT_HEIGHT)
	_visual.scale = Vector2(0.6, 0.6)
	_visual.modulate.a = 0.0
	_visual.visible = true
	_pool.modulate.a = 0.0
	_pool.visible = true
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_visual, "scale", Vector2.ONE, 0.5)
	_tween.tween_property(_visual, "modulate:a", 1.0, 0.5)
	_tween.tween_property(_pool, "modulate:a", 1.0, 0.5)


## White floor light and independent pin-sharp glints. Ground drops stay grounded; no bob/beam.
func _draw_kunai_light() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 3.1)
	for i in 5:
		var radius := lerpf(28.0 if grounded else 42.0, 6.0, float(i)/4.0)
		var points := PackedVector2Array()
		for j in 24:
			var angle := TAU * j / 24.0
			points.append(Vector2(cos(angle)*radius,sin(angle)*radius*0.5))
		_pool.draw_colored_polygon(points,Color(1,1,1,(0.035+i*0.018)*(0.7+0.3*pulse)))
	var halo_y := -3.0 if grounded else -FLOAT_HEIGHT+_body.position.y
	for i in 3:
		_pool.draw_circle(Vector2(0,halo_y),18.0-i*4,Color(1,1,1,0.025+0.015*pulse))
	for i in 3:
		var angle := _clock*0.7 + i*TAU/3.0
		var height := -3.0 if grounded else -FLOAT_HEIGHT+_body.position.y
		var pos := Vector2(roundf(cos(angle)*22),roundf(sin(angle)*9)+height)
		var alpha := pow(maxf(sin(_clock*3.0+i*2.0),0.0),3.0)
		_pool.draw_line(pos-Vector2(3,0),pos+Vector2(3,0),Color(1,1,1,alpha),1.0)
		_pool.draw_line(pos-Vector2(0,3),pos+Vector2(0,3),Color(1,1,1,alpha),1.0)
