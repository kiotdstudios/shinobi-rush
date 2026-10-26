extends Node
var state: JavaScriptObject
var player: PlayerController
var enemy: Bandit

func _ready() -> void:
	var query := str(JavaScriptBridge.eval("window.location.search",true)) if OS.has_feature("web") else ""
	var enabled := "--kunai-proof" in OS.get_cmdline_user_args() or "kunai=proof" in query or "flicker=proof" in query
	var target := ""
	if "waterlife=review" in query or "--waterlife-review" in OS.get_cmdline_user_args():target="res://scenes/art/waterlife_review.tscn"
	elif "waterlife=play" in query or "--waterlife-play" in OS.get_cmdline_user_args():target="res://scenes/art/waterlife_play.tscn"
	elif "flicker=review" in query or "--body-flicker-review" in OS.get_cmdline_user_args():target="res://scenes/art/body_flicker_review.tscn"
	elif "kunai=recovery" in query or "--kunai-recovery" in OS.get_cmdline_user_args():target="res://scenes/art/kunai_recovery_review.tscn"
	elif "bombs=review" in query or "--bombs-review" in OS.get_cmdline_user_args():target="res://scenes/art/tag_bombs_review.tscn"
	elif "damage=review" in query or "--damage-review" in OS.get_cmdline_user_args():target="res://scenes/art/damage_animation_review.tscn"
	elif "shrine=review" in query or "--shrine-review" in OS.get_cmdline_user_args():target="res://scenes/art/dynamic_shrine_review.tscn"
	elif "shore=review" in query or "--shore-review" in OS.get_cmdline_user_args():target="res://scenes/art/blightwood_shorelines_review.tscn"
	elif "water=review" in query or "--water-review" in OS.get_cmdline_user_args():target="res://scenes/art/blightwood_water_review.tscn"
	elif "kunai=directions" in query or "--kunai-directions" in OS.get_cmdline_user_args():target="res://scenes/art/kunai_eight_review.tscn"
	elif "kunai=legacy" in query:target="res://scenes/art/kunai_primary_proof.tscn"
	elif enabled:target="res://scenes/art/flicker_combat_proof.tscn"
	if not target.is_empty():
		get_tree().change_scene_to_file.call_deferred(target)
		set_process(false)
		return
	if "flicker_before=1" in query:EvadeStreakFx.legacy_preview=true  # explicit comparison only
	# Opt-in READ-ONLY visual inspection, never input/gameplay mutation; no normal-game overhead.
	if OS.has_feature("web") and "kunai_inspect=1" in query:
		state=JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__KUNAI_GAME__=state
	else:set_process(false)

func _process(_delta: float) -> void:
	if state==null:return
	if not is_instance_valid(player):player=get_tree().get_first_node_in_group("player") as PlayerController
	if not is_instance_valid(enemy):enemy=get_tree().get_first_node_in_group("enemy") as Bandit
	if player==null or player.visual==null or player.visual.actor==null:return
	var visual := player.visual
	state.flicker_count=player.flicker_count
	state.flicker_json="{}"
	for node in player.get_children():
		if node is EvadeStreakFx:state.flicker_json=JSON.stringify(node.debug_state())
	state.ready=true
	state.direction=visual.actor.dir
	state.animation=visual.actor.anim_id
	state.frame=visual.actor.current_frame()
	state.weapon=visual.weapon_visible()
	state.fallback=visual.actor.fallback
	state.phase=int(player._attack_phase)
	state.player_state=player.get_state_name()
	if enemy!=null and enemy.visual!=null:
		var bandit_visual := enemy.visual as BanditVisual
		state.bandit_animation=bandit_visual.actor.anim_id
		state.bandit_direction=bandit_visual.actor.dir
		state.bandit_frame=bandit_visual.actor.current_frame()
		state.bandit_weapon=bandit_visual.weapon_visible()
		state.bandit_state=enemy.get_state_name()
