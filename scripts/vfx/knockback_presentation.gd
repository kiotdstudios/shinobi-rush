class_name KnockbackPresentation
extends Node2D
## Observe accepted damage and existing hurt clips. No health, velocity, timer, input or camera writes.
const MAX_GHOSTS := 12
const MAX_IMPACTS := 32
var auto_advance := true
var impacts := 0
var snapshots := 0
var seen: Dictionary = {}
var ghosts: Array[Dictionary] = []
var dust: DustPuff
func _ready() -> void:
	y_sort_enabled = true
	dust = DustPuff.new()
	add_child(dust)
	for i in MAX_GHOSTS:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.offset = Vector2(-64,-116)
		sprite.visible = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		ghosts.append({"sprite":sprite,"age":1.0})
func _process(delta: float) -> void:
	if auto_advance and not MapEditorMode.active():advance(delta)
func advance(delta: float) -> void:
	for entry in ghosts:
		entry.age += delta
		var sprite: Sprite2D = entry.sprite
		sprite.visible = entry.age<0.14
		if sprite.visible:sprite.modulate = Color(0.78,0.87,0.96,(1.0-entry.age/0.14)*0.23)
	var actors: Array[Node] = get_tree().get_nodes_in_group("enemy")
	var player := get_tree().get_first_node_in_group("player")
	if player != null:actors.append(player)
	var live_ids: Array[int] = []
	for actor in actors:
		if not actor is PlayerController and not actor is Bandit:continue
		var key := actor.get_instance_id()
		live_ids.append(key)
		var is_player := actor is PlayerController
		var hp: float = actor.health if is_player else actor.hp
		var hits: int = actor.hits_taken if is_player else 0
		var hurt: bool = actor._hurt_t>0.0 if is_player else actor.state==Bandit.State.HIT_REACT
		var kind: String = actor.hurt_kind if is_player else actor.react_kind
		var foot: Vector2 = actor.global_position
		var stride := 0.0
		if seen.has(key):
			var previous: Dictionary = seen[key]
			var damage: bool = hits>int(previous.hits) if is_player else hp<float(previous.hp)
			var motion: Vector2 = foot-Vector2(previous.foot)
			if damage and get_child_count()<MAX_GHOSTS+1+MAX_IMPACTS:
				PremiumImpact.spawn(self,foot+Vector2(0,-44),actor.velocity.normalized(),kind=="knockback" or kind=="death")
				impacts += 1
			if hurt and kind=="knockback" and motion.length()>0.2 and motion.length()<65.0:
				stride = float(previous.get("stride",0.0))+motion.length()
				if stride >= 12.0:
					stride = fmod(stride,12.0)
					_snapshot(actor,actor.visual.actor.global_position)
					if not is_player or not actor.over_water:dust.play("step",foot,-motion.normalized())
		seen[key]={"hp":hp,"hits":hits,"foot":foot,"stride":stride}
	for key in seen.keys():
		if not live_ids.has(key):seen.erase(key)
func _snapshot(actor: Node2D, foot: Vector2) -> void:
	var source: SpriteActor = actor.visual.actor
	if source == null or source.sprite.sprite_frames == null:return
	var entry: Dictionary = ghosts[snapshots%MAX_GHOSTS]
	snapshots += 1
	entry.age = 0.0
	var sprite: Sprite2D = entry.sprite
	sprite.texture = source.sprite.sprite_frames.get_frame_texture(source.sprite.animation,source.sprite.frame)
	sprite.flip_h = source.flip
	sprite.global_position = foot.round()
	sprite.global_scale = source.global_scale
	sprite.visible = true
	sprite.modulate = Color(0.78,0.87,0.96,0.23)
