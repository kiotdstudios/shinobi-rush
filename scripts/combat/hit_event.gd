class_name HitEvent
extends RefCounted
## One confirmed melee contact. Emitted ONCE per target per swing by the attacker (`attack_hit`), and
## consumed by everything that reacts to a hit (sparks, impact silhouette, audio, diagnostics) so none
## of them re-derive geometry or each invent their own trigger.

## Height above the target's feet where the contact is drawn (origin = feet, bodies are ~chest high).
const CONTACT_HEIGHT := 44.0

var attack_id: String = ""
var combo_index: int = 0  ## 1/2/3 for the light combo, 0 for dash/air attacks
var heavy: bool = false  ## heavy impact class (finisher / dash attack)
var damage: float = 0.0
var hitstop_ms: float = 0.0
var direction: Vector2 = Vector2.RIGHT  ## attacker -> target, unit length
var position: Vector2 = Vector2.ZERO  ## world-space contact point
var attacker_position: Vector2 = Vector2.ZERO
var target: Object = null


static func make(attacker: Node2D, enemy: Node2D, def: AttackDef, dir: Vector2, combo: int) -> HitEvent:
	var h := HitEvent.new()
	h.attack_id = def.id
	h.combo_index = combo
	h.heavy = def.heavy
	h.damage = def.damage
	h.hitstop_ms = def.hitstop_ms
	h.direction = dir
	h.attacker_position = attacker.global_position
	h.target = enemy
	# Contact sits on the near edge of the target's body, on the line from attacker to target.
	h.position = enemy.global_position - dir * 14.0 + Vector2(0.0, -CONTACT_HEIGHT)
	return h
