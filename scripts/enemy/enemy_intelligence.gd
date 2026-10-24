class_name EnemyIntelligence
extends RefCounted
## Small reusable "intelligence level" profile for enemies (Level 1 Bandit order). Everything the AI
## decides by feel -- how far/wide it sees, how slowly it reacts, how long it chases, how often it
## retreats or overcommits -- lives here as one Dictionary per level, so a future Level 2 is a new row
## and not a rewrite. Only Level 1 exists today; unknown levels clamp to the nearest defined one.
##
## All times are seconds, distances world px (WorldScale: a standing figure is 108 px tall).

const LEVELS := {
	1: {
		"name": "Level 1 robber",
		"sight_range": 450.0,        # how far it can see in its facing cone
		"fov_deg": 90.0,             # NARROW awareness: only what is in front of it
		"close_sense": 70.0,         # it still notices someone right behind/next to it
		"notice_delay": 0.65,        # suspicion pause before it commits to a hunt (slow reaction)
		"repath_interval": 0.7,      # slow re-acquisition / re-planning
		"lose_sight_time": 2.2,      # chasing without seeing the player this long -> go search
		"search_duration": 3.2,      # looking around at the last seen spot
		"chase_leash": 1500.0,       # bounded chase: gives up this far from its patrol home
		"threaten_time": 0.95,       # first-contact "hand over your ryo" pause
		"rethreaten_time": 0.45,     # later pauses between attack rounds
		"attack_windup": 0.42,       # readable tell before every swing
		"attack_active": 0.10,
		"attack_recovery": 0.38,
		"combo_gap": 0.20,           # gap before the second swing's tell
		"overcommit_chance": 0.40,   # swing 2 lunges on a frozen aim and ends in final_recovery
		"final_recovery": 0.85,      # long punish window after an overcommitted combo
		"lunge_speed": 260.0,        # forward step during an active swing
		"overcommit_lunge_speed": 420.0,
		"attack_cooldown": 2.2,
		"retreat_chance": 0.25,      # rare double flicker after a combo
		"retreat_telegraph": 0.35,
		"retreat_recovery": 0.7,
		"flicker_distance": 230.0,   # per hop, straight back from the player
		"flicker_hop_time": 0.09,
		"flicker_pause": 0.16,
		"reposition_time": 0.55,     # the common "step back and re-think" after a combo
		"reposition_speed": 210.0,
		"patrol_wait": 1.6,
		"patrol_speed": 130.0,
		"attack_reach": 150.0,
		"attack_arc_deg": 100.0,
		# kunai throw (three-kunai combo): a fan of throw_burst_count kunai released throw_burst_gap apart
		"throw_first_delay": 2.0,    # no kunai for this long after first spotting the player
		"throw_min": 190.0,          # closer than this he melees instead
		"throw_range": 420.0,        # farther than this he keeps chasing
		"throw_windup": 0.42,        # tell; aim tracks the first half, then freezes
		"throw_recovery": 0.3,       # punish window after the LAST kunai
		"throw_cooldown": 3.5,       # between throw combos
		"throw_damage": 6.0,         # per kunai
		"throw_speed": 520.0,
		"throw_burst_count": 3,      # kunai per throw combo
		"throw_burst_gap": 0.14,     # seconds between kunai in the combo
		"throw_spread_deg": 9.0,     # angle between neighbouring kunai in the fan
		# substitution jutsu: when a hit would land he may swap with a log and reappear behind the player
		"sub_chance": 0.6,           # chance he uses a charge when hit and able
		"sub_recharge": 15.0,        # seconds for a spent charge to come back
		"sub_behind_dist": 72.0,     # how far behind the player he reappears
		"sub_invuln": 0.5,           # grace after a swap
		"sub_min_gap": 1.0,          # minimum seconds between two swaps
		"chakra_regen": 4.0,         # chakra per second
	},
}


static func profile(level: int) -> Dictionary:
	var keys: Array = LEVELS.keys()
	keys.sort()
	var chosen: int = keys[0]
	for k: int in keys:
		if k <= level:
			chosen = k
	var d: Dictionary = (LEVELS[chosen] as Dictionary).duplicate()
	d["level"] = chosen
	return d
