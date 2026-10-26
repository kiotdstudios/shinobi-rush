class_name WeaponRig
extends RefCounted
## Shared native-pixel attachment data; no facing fallback and no hard-coded SE-only table.
const WEAPON_TEXTURE := "res://assets/weapons/kunai/black_kunai.png"
const GRIP_PIVOT_PX := Vector2(25,31)
## Owner 2026-10-25: "make kunai bigger they are hard to see and small" -- the 64px kunai texture
## (36px blade) was drawn at native scale (1.0) against a 108px-tall character, reading as a sliver.
## Single shared knob for both the held kunai (KunaiPoseActor, player+bandit) and the thrown
## projectile (BanditKunai): both must scale together so the weapon doesn't visibly resize when it
## leaves the hand. Visual only -- does not touch BanditKunai.HIT_RADIUS or any AttackDef reach/damage.
const VISUAL_SCALE := 1.6
const ATTACKS := ["light1","light2","light3","dash_attack"]

static func supports(anim_id: String) -> bool:
	return anim_id in ATTACKS

static func pose(anim_id: String, frame: int, direction: String = "SE", character: String = "player") -> Dictionary:
	if not supports(anim_id):return {}
	var poses := KunaiCombatData.frames(character,direction,anim_id)
	if poses.is_empty():return {}
	var source: Dictionary=poses[clampi(frame,0,poses.size()-1)]
	return {"hand":Vector2(source.right_hand_px[0],source.right_hand_px[1]),"angle_deg":float(source.weapon_angle_deg),"layer":str(source.weapon_layer)}
