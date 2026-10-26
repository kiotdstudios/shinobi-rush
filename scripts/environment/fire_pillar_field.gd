class_name FirePillarField
extends Node2D
## Scene integration for FirePillar: loads the manifest once, spawns one instance per
## WorldScale.FIRE_PILLAR_POSITIONS entry (mirrors BlossomGrove's split from BlossomTree). Purely
## additive decoration -- no collision/nav/gameplay changes, same precedent as WindGrassField and
## BlossomGrove ("existing ground, tree collision, navigation, player and camera controllers" are
## preserved, per the grass order's own constraint, carried over here).
const MANIFEST := "res://assets/environment/fire_pillar/fire_pillar.art.json"
const PLACEMENTS: Array[Vector2] = WorldScale.FIRE_PILLAR_POSITIONS
var pillars: Array[FirePillar] = []
var _manifest: Dictionary = {}


func _ready() -> void:
	y_sort_enabled = true
	var manifest: Dictionary = _load_manifest()
	for i in PLACEMENTS.size():
		var pillar := FirePillar.new()
		pillar.name = "FirePillar%d" % i
		pillar.data = manifest
		pillar.position = PLACEMENTS[i]
		add_child(pillar)
		pillars.append(pillar)


func _process(delta: float) -> void:
	for p: FirePillar in pillars:
		p.advance(delta)


func _load_manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest
