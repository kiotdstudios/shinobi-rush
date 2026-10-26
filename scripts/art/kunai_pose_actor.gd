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
var _pose_key := ""

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
	weapon.scale = Vector2.ONE * WeaponRig.VISUAL_SCALE
	# Non-centered sprite: content coords get scaled around the node origin, so the grip pivot
	# (WeaponRig.GRIP_PIVOT_PX) must be negated and scaled the same way to stay anchored at the
	# hand socket (grip's local origin) regardless of VISUAL_SCALE. See WeaponRig.VISUAL_SCALE.
	weapon.position = -WeaponRig.GRIP_PIVOT_PX * WeaponRig.VISUAL_SCALE
	weapon.texture = load("res://assets/weapons/kunai/black_kunai.png")
	grip.add_child(weapon)
	hand = Sprite2D.new()
	hand.centered = false
	add_child(hand)
	swipe = Sprite2D.new()
	add_child(swipe)

func show_pose(pose: Dictionary) -> void:
	current_pose = pose
	var path := str(pose.body_frame)
	var key := path+str(pose.right_hand_px)+str(pose.weapon_angle_deg)+str(pose.weapon_layer)+str(pose.get("swipe_frame",-1))+str(pose.get("swipe_rotation_deg",0))+str(pose.get("swipe_offset_px",[10,5]))
	if key==_pose_key:return
	_pose_key=key
	if not _cache.has(path):
		_cache[path] = load(path)
	body.texture = _cache[path]
	var socket := Vector2(float(pose.right_hand_px[0]), float(pose.right_hand_px[1]))
	grip.position = socket - Vector2(64, 116)
	grip.rotation = deg_to_rad(float(pose.weapon_angle_deg))
	# Sibling order keeps the weapon on the actor's Y-sort plane, above the floor.
	move_child(grip,0 if str(pose.weapon_layer)=="behind" else 1)
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
		var offset: Array=pose.get("swipe_offset_px",[10,5])
		swipe.position = grip.position + Vector2(offset[0],offset[1])
		swipe.rotation=deg_to_rad(float(pose.get("swipe_rotation_deg",0)))
