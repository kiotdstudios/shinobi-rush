class_name KunaiCombatData
extends RefCounted
## Shared choreography, separate character skins and per-frame hand tracks.
const PATH := "res://assets/combat/kunai/kunai-combat.art.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data

static func frames(character: String, direction: String, action: String) -> Array:
	return data().characters.get(character,{}).get(direction,{}).get(action,[])

static func pose_at(character: String, direction: String, action: String, time_ms: float) -> Dictionary:
	var poses := frames(character,direction,action)
	if poses.is_empty(): return {}
	for pose: Dictionary in poses:
		if time_ms < float(pose.start_ms)+float(pose.duration_ms): return pose
	return poses.back()

static func profile(action: String) -> Dictionary:
	return data().profiles.get(action,{})

static func pose_for_phase(character: String, direction: String, action: String, phase: String, progress: float) -> Dictionary:
	var keys: Array = []
	for pose: Dictionary in frames(character,direction,action):
		if str(pose.phase)==phase:keys.append(pose)
	if keys.is_empty():return {}
	return keys[clampi(int(clampf(progress,0.0,1.0)*keys.size()),0,keys.size()-1)]
