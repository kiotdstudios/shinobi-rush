class_name BodyFlickerDemo
extends Node
## Visual-only Body Flicker (Shunshin) demo for the Animation Lab.
## Plays the Orcha SE-direction VFX proof on the player ninja without touching
## combat, cooldowns, input maps, camera code, Aki's controller, or Codex art.
##
## Usage (Animation Lab calls this):
##   BodyFlickerDemo.trigger(player, speed_scale)
##   speed_scale: 1.0 = normal (417 ms), 0.5 = half speed (834 ms)
##
## Architecture:
##   Three AnimatedSprite2D nodes are created on demand (once) and reused on
##   every trigger. They are parented to the arena (player.get_parent()) so
##   they stay in world space and Y-sort correctly.
##   The player's PlayerVisual node is hidden between frame 1 and frame 7 of
##   the 10-frame sequence. Position is NOT moved (visual-only safe prototype;
##   the lab note labels this limitation clearly).
##
## Cleanup: if the lab closes or the tree exits mid-effect, _cleanup() restores
## player visibility and removes the sprite nodes safely.

const MANIFEST_PATH := "res://assets/vfx/body_flicker/body_flicker_SE.art.json"
const VFX_DIR := "res://assets/vfx/body_flicker/"
const FPS := 24
const CANVAS_SIZE := 192
const ANCHOR_Y := 141  ## matches player foot anchor + 25px canvas offset
const ANCHOR_X := 96

## SE travel offset (visual only -- no CharacterBody2D movement)
const TRAVEL_OFFSET := Vector2(56, 40)

## Frame lists per phase
const DEPART_FRAMES := ["depart_000.png", "depart_001.png", "depart_002.png"]
const TRAVEL_FRAMES := ["travel_000.png", "travel_001.png", "travel_002.png", "travel_003.png"]
const ARRIVE_FRAMES := ["arrive_000.png", "arrive_001.png", "arrive_002.png"]

## hide_player fires at end of departure frame 1 (index 1); reappear fires at arrival start (index 7)
const HIDE_AFTER_PHASE := "depart"   ## hide player visual after departure plays
const REAPPEAR_AT_PHASE := "arrive"  ## restore player visual when arrival starts

static var _instance: BodyFlickerDemo = null

var _player: PlayerController = null
var _arena: Node2D = null
var _depart_sprite: AnimatedSprite2D = null
var _travel_sprite: AnimatedSprite2D = null
var _arrive_sprite: AnimatedSprite2D = null
var _active: bool = false
var _player_hidden: bool = false
var _phase: String = ""
var _speed: float = 1.0
var _spawn_pos: Vector2 = Vector2.ZERO
var _textures_loaded: bool = false


static func trigger(player: PlayerController, speed_scale: float = 1.0) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	if _instance._active:
		return  ## already playing; ignore re-trigger
	_instance._start(player, speed_scale)


## Called by AnimationLab._set_lab(false) or on tree exit to ensure player stays visible.
static func safe_cleanup() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance._cleanup()


func _ready() -> void:
	_instance = self


func _exit_tree() -> void:
	_cleanup()
	if _instance == self:
		_instance = null


# ---------------------------------------------------------------- internal

func _start(player: PlayerController, speed_scale: float) -> void:
	_player = player
	_arena = player.get_parent() as Node2D
	_speed = clampf(speed_scale, 0.1, 4.0)
	_spawn_pos = player.global_position

	_ensure_sprites()
	if not _textures_loaded:
		push_warning("BodyFlickerDemo: textures not loaded, aborting")
		return

	_active = true
	_player_hidden = false
	_phase = "depart"

	## Position departure sprite at player feet
	_depart_sprite.global_position = _spawn_pos + Vector2(0, ANCHOR_Y - CANVAS_SIZE / 2)
	_depart_sprite.visible = true
	_depart_sprite.speed_scale = _speed
	_depart_sprite.play("depart")
	_travel_sprite.visible = false
	_arrive_sprite.visible = false

	## Connect signal if not already connected
	if not _depart_sprite.animation_finished.is_connected(_on_depart_done):
		_depart_sprite.animation_finished.connect(_on_depart_done)
	if not _travel_sprite.animation_finished.is_connected(_on_travel_done):
		_travel_sprite.animation_finished.connect(_on_travel_done)
	if not _arrive_sprite.animation_finished.is_connected(_on_arrive_done):
		_arrive_sprite.animation_finished.connect(_on_arrive_done)


func _on_depart_done() -> void:
	if not _active:
		return
	## Hide player visual (visual-only: body stays at original position)
	if is_instance_valid(_player):
		_player.visual.visible = false
		_player_hidden = true
	_depart_sprite.visible = false
	_phase = "travel"
	var travel_pos := _spawn_pos + Vector2(0, ANCHOR_Y - CANVAS_SIZE / 2)
	_travel_sprite.global_position = travel_pos
	_travel_sprite.visible = true
	_travel_sprite.speed_scale = _speed
	_travel_sprite.play("travel")


func _on_travel_done() -> void:
	if not _active:
		return
	_travel_sprite.visible = false
	_phase = "arrive"
	## Arrive at visual offset position (body stays at origin -- visual-only prototype)
	var arrive_pos := _spawn_pos + TRAVEL_OFFSET + Vector2(0, ANCHOR_Y - CANVAS_SIZE / 2)
	_arrive_sprite.global_position = arrive_pos
	_arrive_sprite.visible = true
	_arrive_sprite.speed_scale = _speed
	## Restore player visual at arrival position (visual offset only)
	if is_instance_valid(_player) and _player_hidden:
		_player.visual.global_position = _spawn_pos + TRAVEL_OFFSET
		_player.visual.visible = true
		_player_hidden = false
	_arrive_sprite.play("arrive")


func _on_arrive_done() -> void:
	_cleanup()


func _cleanup() -> void:
	_active = false
	_phase = ""
	## Always restore player visual and position
	if is_instance_valid(_player) and _player_hidden:
		_player.visual.visible = true
		_player.visual.position = Vector2.ZERO  ## reset local offset
		_player_hidden = false
	if is_instance_valid(_player):
		_player.visual.position = Vector2.ZERO
	## Hide VFX sprites (keep nodes for reuse)
	if is_instance_valid(_depart_sprite):
		_depart_sprite.visible = false
	if is_instance_valid(_travel_sprite):
		_travel_sprite.visible = false
	if is_instance_valid(_arrive_sprite):
		_arrive_sprite.visible = false


# ---------------------------------------------------------------- sprite setup

func _ensure_sprites() -> void:
	if _textures_loaded:
		return
	if _arena == null:
		return

	_depart_sprite = _make_sprite("_bf_depart")
	_travel_sprite = _make_sprite("_bf_travel")
	_arrive_sprite = _make_sprite("_bf_arrive")

	_add_anim(_depart_sprite, "depart", DEPART_FRAMES)
	_add_anim(_travel_sprite, "travel", TRAVEL_FRAMES)
	_add_anim(_arrive_sprite, "arrive", ARRIVE_FRAMES)

	_textures_loaded = true


func _make_sprite(node_name: String) -> AnimatedSprite2D:
	## Remove stale node if it still exists in the tree
	var existing := _arena.get_node_or_null(node_name) if is_instance_valid(_arena) else null
	if existing != null:
		existing.queue_free()

	var sp := AnimatedSprite2D.new()
	sp.name = node_name
	sp.sprite_frames = SpriteFrames.new()
	sp.visible = false
	sp.z_index = 20
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Anchor: canvas centre horizontally, foot at ANCHOR_Y from top
	sp.offset = Vector2(-ANCHOR_X, -(CANVAS_SIZE - ANCHOR_Y))
	if is_instance_valid(_arena):
		_arena.add_child(sp)
	return sp


func _add_anim(sp: AnimatedSprite2D, anim_name: String, file_names: Array) -> void:
	sp.sprite_frames.add_animation(anim_name)
	sp.sprite_frames.set_animation_loop(anim_name, false)
	sp.sprite_frames.set_animation_speed(anim_name, FPS)
	for fname in file_names:
		var path: String = VFX_DIR + str(fname)
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("BodyFlickerDemo: could not load %s" % path)
			_textures_loaded = false
			return
		sp.sprite_frames.add_frame(anim_name, tex)
