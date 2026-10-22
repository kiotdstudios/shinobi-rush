class_name KunaiPoseActor
extends Node2D
## Body/weapon/hand layers shared by live art previews; never owns movement or damage.
var body: Sprite2D
var grip: Node2D
var weapon: Sprite2D
var hand: Sprite2D
var swipe: Sprite2D
var current_pose: Dictionary = {}
var _cache: Dictionary = {}

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body = Sprite2D.new()
	body.centered = false
	body.position = Vector2(-64, -116)
	add_child(body)
	grip = Node2D.new()
	add_child(grip)
	weapon = Sprite2D.new()
	weapon.centered = false
	weapon.position = Vector2(-25, -31)
	weapon.texture = load("res://assets/weapons/kunai/black_kunai.png")
	grip.add_child(weapon)
	hand = Sprite2D.new()
	hand.centered = false
	hand.z_index = 2
	add_child(hand)
	swipe = Sprite2D.new()
	swipe.z_index = 3
	add_child(swipe)

func show_pose(pose: Dictionary) -> void:
	current_pose = pose.duplicate(true)
	var path := str(pose.body_frame)
	if not _cache.has(path):
		_cache[path] = load(path)
	body.texture = _cache[path]
	var socket := Vector2(float(pose.right_hand_px[0]), float(pose.right_hand_px[1]))
	grip.position = socket - Vector2(64, 116)
	grip.rotation = deg_to_rad(float(pose.weapon_angle_deg))
	grip.z_index = -1 if str(pose.weapon_layer) == "behind" else 1
	var patch := AtlasTexture.new()
	patch.atlas = body.texture
	patch.region = Rect2(socket - Vector2(2, 2), Vector2(5, 5))
	hand.texture = patch
	hand.position = socket - Vector2(66, 118)

	var index := int(pose.get("swipe_frame", -1))
	swipe.visible = index >= 0
	if swipe.visible:
		var fx_path := "res://assets/vfx/kunai_contact/swipe_%03d.png" % index
		if not _cache.has(fx_path):
			_cache[fx_path] = load(fx_path)
		swipe.texture = _cache[fx_path]
		swipe.position = grip.position + Vector2(10, 5)
