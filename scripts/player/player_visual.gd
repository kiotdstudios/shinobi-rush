class_name PlayerVisual
extends Node2D
## Swaps between the labeled PLACEHOLDER visual (default) and a SpriteSet from the SpriteLibrary.
## Uses the first valid set unless the lab picks another. The foot anchor sits on the player origin;
## the collision footprint and shadow never move when animations change.

const CHAIN_IDLE: Array[String] = ["idle", "run", "walk"]
const CHAIN_RUN: Array[String] = ["run", "walk"]
const CHAIN_SPRINT: Array[String] = ["sprint", "run", "walk"]

signal sprite_set_changed(new_set: SpriteSet)

@onready var placeholder: PlaceholderVisual = $PlaceholderVisual

var actor: SpriteActor
var sprite_set: SpriteSet
var last_anim: String = ""
var last_dir: String = ""
var _pose: Array = [Vector2.DOWN, false, false]


func _ready() -> void:
	actor = SpriteActor.new()
	actor.name = "SpriteActor"
	actor.visible = false
	add_child(actor)
	set_sprite_set(SpriteLibrary.get_instance().first_valid())


## Animation id for the gameplay state. no input -> idle; moving -> run (else walk); sprint -> sprint.
## Missing ids fall back (sprint -> run -> walk, idle -> idle/walk/run frame 0). "" = none usable.
static func pick_animation(s: SpriteSet, moving: bool, sprinting: bool) -> String:
	var chain: Array[String] = CHAIN_IDLE
	if moving:
		chain = CHAIN_SPRINT if sprinting else CHAIN_RUN
	for aid: String in chain:
		if s.animations.has(aid):
			return aid
	return ""


func set_sprite_set(s: SpriteSet) -> void:
	if s != null and not s.is_valid():
		s = null
	sprite_set = s
	last_anim = ""
	last_dir = ""
	actor.visible = s != null
	placeholder.visible = s == null
	if s == null:
		actor.queue_redraw()
	sprite_set_changed.emit(s)
	_apply()


func set_pose(dir8: Vector2, sprinting: bool, moving: bool) -> void:
	_pose = [dir8, sprinting, moving]
	if sprite_set == null:
		placeholder.set_pose(dir8, sprinting, moving)
		return
	_apply()


func _apply() -> void:
	if sprite_set == null:
		return
	var moving: bool = _pose[2]
	var aid := pick_animation(sprite_set, moving, _pose[1])
	if aid.is_empty():
		actor.visible = false
		placeholder.visible = true
		placeholder.set_pose(_pose[0], _pose[1], moving)
		return
	var shown := actor.show_animation(sprite_set, aid, SpriteSet.dir_name(_pose[0]), not moving and aid != "idle")
	actor.visible = shown
	placeholder.visible = not shown
	if shown:
		last_anim = aid
		last_dir = actor.dir + (" (flip)" if actor.flip else "")
	else:
		placeholder.set_pose(_pose[0], _pose[1], moving)
