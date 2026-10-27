extends RefCounted
## Asset/socket contracts and real player/enemy visual bindings across every heading and attack phase.
func run(ck: Callable, root: Node) -> void:
	var pack := KunaiCombatData.data()
	ck.call("kunai eight: native shared anchor",pack.frame_size==[128.0,128.0] and pack.foot_anchor==[64.0,116.0])
	var defs := AttackDef.build_table()
	for aid: String in WeaponRig.ATTACKS:
		ck.call("kunai eight: existing gameplay duration "+aid,is_equal_approx(float(KunaiCombatData.profile(aid).duration_ms),defs[aid].total_duration()*1000))
	for character: String in ["player","bandit"]:
		for dir: String in SpriteSet.DIRS8:
			var intact := true
			for aid: String in ["light1","light2","light3","dash_attack","guard"]:
				var poses := KunaiCombatData.frames(character,dir,aid)
				intact=intact and poses.size()==(1 if aid=="guard" else 5 if aid=="dash_attack" else 6)
				for pose: Dictionary in poses:
					var texture := load(str(pose.body_frame)) as Texture2D
					intact=intact and texture!=null and texture.get_size()==Vector2(128,128)
					if texture!=null:
						var hand := Vector2i(int(pose.right_hand_px[0]),int(pose.right_hand_px[1]))
						intact=intact and texture.get_image().get_pixelv(hand).a==1.0
			ck.call("kunai eight: complete native assets and attached hand "+character+" "+dir,intact)
	ck.call("kunai eight: no invented facing fallback",KunaiCombatData.frames("player","bad","light1").is_empty() and WeaponRig.pose("light1",0,"bad").is_empty())
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:await root.get_tree().process_frame
	var player := main.get_node("TrainingArena/Player") as PlayerController
	var enemy := main.get_tree().get_first_node_in_group("enemy") as Bandit
	ck.call("kunai eight: live actors available",player!=null and enemy!=null)
	if player==null or enemy==null:
		main.queue_free()
		return
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	var visual := enemy.visual as BanditVisual
	visual.set_process(false)
	var vectors := [Vector2.DOWN,Vector2(1,1),Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1)]
	for i in 8:
		var dir: String=SpriteSet.DIRS8[i]
		player.facing8=vectors[i].normalized()
		enemy.facing8=player.facing8
		for aid: String in WeaponRig.ATTACKS:
			player._attack_def=defs[aid]
			for phase in [PlayerController.AttackPhase.STARTUP,PlayerController.AttackPhase.ACTIVE,PlayerController.AttackPhase.RECOVERY]:
				player._attack_phase=phase
				var label: String=["startup","active","recovery"][phase]
				var duration: float=[defs[aid].startup,defs[aid].active,defs[aid].recovery][phase]
				player._attack_timer=duration*.5
				var expected := 1 if phase==0 else (2 if aid=="dash_attack" else 3) if phase==1 else (4 if aid=="dash_attack" else 5)
				player.visual.play_action(aid,player.facing8)
				ck.call("kunai eight: player "+dir+" "+aid+" "+label,player.visual.weapon_visible() and player.visual.actor.dir==dir and not player.visual.actor.fallback and player.visual.actor.current_frame()==expected and not player.visual.actor.sprite.is_playing())
				var shown := visual.show_attack_pose(aid,dir,label,.5)
				var pose := KunaiCombatData.frames("bandit",dir,aid)[expected] as Dictionary
				var socket := Vector2(pose.right_hand_px[0],pose.right_hand_px[1])-Vector2(64,116)
				ck.call("kunai eight: bandit same attack/profile "+dir+" "+aid+" "+label,shown and visual.actor.dir==dir and not visual.actor.fallback and visual.actor.current_frame()==expected and visual.weapon_layer.grip.position==socket and visual.weapon_visible())
				ck.call("kunai eight: actor-plane ordering "+dir+" "+aid+" "+label,visual.weapon_layer.z_index==0 and visual.weapon_layer.grip.z_index==0 and ((visual.weapon_layer.get_index()<visual.actor.get_index())==(str(pose.weapon_layer)=="behind")))
		enemy.state=Bandit.State.ATTACK
		enemy.atk_phase=Bandit.AtkPhase.ACTIVE1
		enemy._atk_timer=float(enemy.profile.attack_active)*.5
		visual._process(0)
		ck.call("kunai eight: real bandit phase binding "+dir,visual.actor.anim_id=="light1" and visual.actor.current_frame()==3 and visual.weapon_visible())
		enemy.atk_phase=Bandit.AtkPhase.ACTIVE2
		visual._process(0)
		ck.call("kunai eight: bandit second swing binding "+dir,visual.actor.anim_id=="light2" and visual.actor.current_frame()==3)
	ck.call("kunai eight: same renderer and black kunai, distinct bodies",player.visual.weapon_layer.get_script()==visual.weapon_layer.get_script() and player.visual.weapon_layer.weapon.texture==visual.weapon_layer.weapon.texture and player.visual.actor.set_ref.id!=visual.actor.set_ref.id)
	enemy.state=Bandit.State.ATTACK
	enemy.atk_phase=Bandit.AtkPhase.THROW_WINDUP
	enemy._atk_timer=float(enemy.profile.get("throw_windup",0.42))*.5
	visual._process(0)
	ck.call("kunai eight: incoming throw keeps its own art and clears melee weapon",visual.actor.anim_id=="throw" and not visual.weapon_visible() and not visual.actor.fallback)
	visual.show_attack_pose("light2","SW","active",.5)
	enemy.state=Bandit.State.HIT_REACT
	var held_frame := visual.actor.current_frame()
	var held_grip := visual.weapon_layer.grip.position
	visual._process(0)
	ck.call("kunai eight: struck plays the unarmed hit_react art, weapon layer hidden",not visual.weapon_visible() and visual.actor.anim_id=="hit_react")
	enemy.state=Bandit.State.PATROL
	enemy.velocity=Vector2.RIGHT*enemy.move_speed
	visual._process(0)
	ck.call("kunai eight: patrol clears full weapon/trail layer",not visual.weapon_visible() and visual.actor.anim_id in ["move_start","move_start_sprint"],str([visual.weapon_visible(),visual.actor.anim_id]))
	enemy.state=Bandit.State.THREATEN
	visual._process(0)
	ck.call("kunai eight: threaten has authored guard",visual.weapon_visible() and visual.actor.anim_id=="kunai_guard")
	enemy.state=Bandit.State.DEAD
	visual._process(0)
	ck.call("kunai eight: death clears weapon and plays the death art",not visual.weapon_visible() and visual.actor.visible and visual.actor.anim_id=="death")
	player.visual.set_pose(Vector2.DOWN,false,false)
	ck.call("kunai eight: player locomotion clears all attachments",not player.visual.weapon_visible())
	main.queue_free()
	await root.get_tree().process_frame
