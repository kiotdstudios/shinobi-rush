extends RefCounted
## Substitution pips use the real log art, wiggle + smoke when a charge is spent; Bandit charges chakra when low.

func run(ck: Callable, root: Node) -> void:
	ck.call("log pip: uses the real 38x26 log art", LogPip.tex("log_icon").get_size() == LogPip.ART_SIZE and LogPip.tex("log_icon_gray").get_size() == LogPip.ART_SIZE)
	ck.call("log pip: bandit bar pips are the log art at half size", UnitBars.PIP_SCALE == 0.5 and UnitBars.PIP_SIZE == LogPip.ART_SIZE.y * 0.5)

	var hud := HealthBar.new()
	root.add_child(hud)
	hud._on_substitution_changed(3, 3)
	ck.call("log pip: full HUD has no animation running", hud.use_age.all(func(a: float) -> bool: return a < 0.0))
	hud._on_substitution_changed(2, 3)
	ck.call("log pip: spending a charge starts the wiggle/smoke on that pip only", hud.use_age[2] == 0.0 and hud.use_age[1] < 0.0 and hud.use_age[0] < 0.0)
	hud._process(LogPip.DURATION + 0.1)
	ck.call("log pip: the animation ends on its own", hud.use_age[2] < 0.0)
	hud._on_substitution_changed(0, 3)
	ck.call("log pip: spending two at once animates both", hud.use_age[0] == 0.0 and hud.use_age[1] == 0.0)
	hud._process(LogPip.DURATION + 0.1)
	hud._on_substitution_changed(1, 3)
	ck.call("log pip: a refill does not restart the spend animation", hud.use_age[0] < 0.0 and hud.use_age[1] < 0.0)
	hud.queue_free()

	Bandit.substitution_enabled = true
	var b := (load("res://scenes/enemy/bandit.tscn") as PackedScene).instantiate() as Bandit
	root.add_child(b)
	b.set_physics_process(false)
	b.visual.set_process(false)
	b.global_position = Vector2.ZERO
	# chakra-charge behaviour (no chakra moves exist yet; this is the mechanism)
	ck.call("bandit chakra: full pool does not charge", not b.needs_chakra_charge() and not b._tick_chakra_charge(0.1))
	ck.call("bandit chakra: spend_chakra pays when affordable", b.spend_chakra(30.0) and is_equal_approx(b.chakra, 70.0))
	b.profile["chakra_regen"] = 0.0
	b.chakra = 20.0
	ck.call("bandit chakra: low pool wants a charge", b.needs_chakra_charge())
	ck.call("bandit chakra: he starts charging when it is safe", b._tick_chakra_charge(0.1) and b.is_charging_chakra)
	var before := b.chakra
	b._tick_chakra_charge(1.0)
	ck.call("bandit chakra: charging refills much faster than passive regen", b.chakra - before >= 20.0)
	var t := 0.0
	while b.is_charging_chakra and t < 10.0:
		b._tick_chakra_charge(0.1)
		t += 0.1
	ck.call("bandit chakra: he stops charging once the pool is back up", not b.is_charging_chakra and b.chakra >= 0.9 * b.max_chakra)
	b.chakra = 5.0
	ck.call("bandit chakra: an unaffordable move is refused and flags a charge", not b.spend_chakra(50.0) and b._chakra_wanted and is_equal_approx(b.chakra, 5.0))
	b._tick_chakra_charge(0.1)
	ck.call("bandit chakra: charging again", b.is_charging_chakra)
	b.state = Bandit.State.HIT_REACT
	ck.call("bandit chakra: a hit interrupts the charge", not b._tick_chakra_charge(0.1) and not b.is_charging_chakra)
	b.state = Bandit.State.IDLE

	# substitution animation on the bandit bar
	b.is_charging_chakra = false
	b.chakra = 100.0
	b._chakra_wanted = false
	ck.call("bandit pips: idle by default", b.sub_use_age.is_empty() or b.sub_use_age.all(func(a: float) -> bool: return a < 0.0))
	b.sub_use_age = [-1.0, -1.0] as Array[float]
	b._tick_substitution(0.1)
	b.sub_use_age[1] = 0.0
	b._tick_substitution(0.5)
	ck.call("bandit pips: spent-pip animation ages with time", b.sub_use_age[1] > 0.4)
	b._tick_substitution(1.0)
	ck.call("bandit pips: and ends", b.sub_use_age[1] < 0.0)
	Bandit.substitution_enabled = false
	b.queue_free()
	await root.get_tree().process_frame
