extends Node
## R is a visual-only charge preview; gameplay owners can call the visual API for progression.
var player: PlayerController
var visual: ChakraChargeVisual
var state: JavaScriptObject
var was_presenting := false

func _ready() -> void:
	var query := str(JavaScriptBridge.eval("window.location.search",true)) if OS.has_feature("web") else ""
	if "chakra=review" in query or "--chakra-review" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/art/chakra_charge_review.tscn")
		set_process(false)
		return
	call_deferred("attach_player")

func attach_player() -> void:
	player=get_tree().get_first_node_in_group("player") as PlayerController
	if player==null:
		return
	visual=ChakraChargeVisual.new()
	visual.charging=false
	visual.opacity=0.0
	visual.process_priority=100
	player.add_child(visual)
	visual.body.visible=false
	if OS.has_feature("web"):
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__CHAKRA_GAME__=state

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(visual):
		return
	if player.get_parent()==null or get_tree().current_scene==null:
		return
	var editor := player.get_parent().get_node_or_null("WorldEditor") as WorldEditor
	var allowed := not get_tree().paused and (editor==null or not editor.open)
	var lab := get_tree().current_scene.get_node_or_null("AnimationLab") as AnimationLab
	allowed = allowed and (lab==null or not lab.lab_on)
	var active: bool = allowed and Input.is_physical_key_pressed(KEY_R) and player.state==PlayerController.State.IDLE and player.health>0
	visual.set_charging(active)
	visual.direction=SpriteSet.dir_name(player.facing8)
	visual.body.visible=active
	visual.modulate=player.visual.modulate
	if active:
		player.visual.actor.visible=false
		player.visual.placeholder.visible=false
	elif was_presenting:
		player.visual.actor.visible=player.visual.sprite_set!=null
		player.visual.placeholder.visible=player.visual.sprite_set==null
	was_presenting=active
	if state!=null:
		state.ready=true
		state.presenting=active
		state.direction=visual.direction
		state.opacity=visual.opacity
		state.phase=visual.phase()
		state.body_frame=visual.body_frame()
		state.body_visible=visual.body.visible
		state.base_visible=player.visual.actor.visible
