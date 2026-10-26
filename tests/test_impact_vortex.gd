extends RefCounted
func run(ck: Callable, root: Node) -> void:
	var old_sub := Bandit.substitution_enabled
	Bandit.substitution_enabled = false
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(-8000,-8000)
	root.add_child(player)
	player.set_physics_process(false)
	var bandit := load("res://scenes/enemy/bandit.tscn").instantiate() as Bandit
	bandit.position = Vector2(-7600,-8000)
	root.add_child(bandit)
	bandit.set_physics_process(false)
	var fx := KnockbackPresentation.new()
	fx.auto_advance = false
	root.add_child(fx)
	await root.get_tree().process_frame
	fx.advance(0.0)
	var accepted := player.take_hit(5.0,Vector2.RIGHT,220.0)
	var velocity := player.velocity
	var health := player.health
	var timer := player._hurt_t
	fx.advance(0.01)
	ck.call("premium impact observes one accepted player hit",accepted and fx.impacts==1)
	ck.call("premium impact does not alter movement, health or hurt timing",player.velocity==velocity and player.health==health and player._hurt_t==timer)
	var rejected := not player.take_hit(5.0,Vector2.RIGHT,220.0)
	fx.advance(0.01)
	ck.call("rejected invulnerable hit creates no extra impact",rejected and fx.impacts==1)
	player.position += Vector2(16,0)
	fx.advance(0.01)
	ck.call("knockback samples an actual reached damaged-body pose",fx.snapshots==1 and fx.ghosts.size()==12)
	var frozen: Vector2 = fx.ghosts[0].sprite.global_position
	player.position += Vector2(16,0)
	fx.advance(0.01)
	ck.call("recoil snapshot stays stationary as the body travels",fx.ghosts[0].sprite.global_position==frozen and fx.snapshots==2)
	bandit.take_damage(5.0,Vector2.LEFT,260.0,0.0)
	fx.advance(0.01)
	ck.call("premium impact observes accepted bandit damage too",fx.impacts==2 and bandit.react_kind=="knockback")
	bandit.flicker_hopping=true
	bandit.take_damage(5.0,Vector2.LEFT,260.0,0.0)
	fx.advance(0.01)
	ck.call("bandit evasion produces no false accepted-hit effect",fx.impacts==2)
	fx.advance(0.5)
	var visible := 0
	for entry in fx.ghosts:
		if entry.sprite.visible:visible+=1
	ck.call("recoil snapshots expire without hiding the real character",visible==0 and player.visual.visible)
	var burst := PremiumImpact.new()
	burst.auto_advance=false
	root.add_child(burst)
	burst.advance(0.025)
	ck.call("second authored impact frame is a sharp early beat",burst.frame==1)
	burst.advance(0.10)
	ck.call("impact advances to separate fragment frames",burst.frame>=4)
	burst.queue_free()
	var sub := SubstitutionFx.spawn(root,Vector2(4000,4000),Vector2(4160,4000))
	sub.set_process(false)
	ck.call("vortex uses five bounded front/back pairs",sub._vortex.size()==5)
	var log_index := sub._log_sprite.get_index()
	ck.call("smoke has real draw order around log",sub._vortex[0].back.get_index()<log_index and sub._vortex[0].front.get_index()>log_index)
	sub._process(0.2)
	ck.call("vortex wraps while existing log wobbles",sub._vortex[0].back.visible and sub._vortex[0].front.visible and absf(sub._log_sprite.rotation)>0.01)
	sub._process(0.5)
	ck.call("log drop preserves its existing physical collider",sub._log_body!=null and sub._log_sprite.visible and sub._log_sprite.rotation>0.0)
	sub._process(0.6)
	ck.call("log ground contact creates one authored impact",sub._log_impact_played and sub._log_sprite.visible and sub._log_body!=null)
	sub._process(0.7)
	ck.call("log disappears and releases collision at original poof time",not sub._log_sprite.visible and sub._log_body==null and sub._vortex[-1].front.visible)
	sub._process(1.1)
	ck.call("smoke event cleans itself up after original lifetime",sub.is_queued_for_deletion())
	fx.queue_free();player.queue_free();bandit.queue_free()
	Bandit.substitution_enabled=old_sub
	await root.get_tree().process_frame
