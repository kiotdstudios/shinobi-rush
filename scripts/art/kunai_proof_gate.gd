extends Node
func _ready() -> void:
	var query := str(JavaScriptBridge.eval("window.location.search", true)) if OS.has_feature("web") else ""
	var enabled := "--kunai-proof" in OS.get_cmdline_user_args() or "kunai=proof" in query or "flicker=proof" in query
	if "kunai=legacy" in query:
		get_tree().change_scene_to_file.call_deferred("res://scenes/art/kunai_primary_proof.tscn")
	elif enabled:
		get_tree().change_scene_to_file.call_deferred("res://scenes/art/flicker_combat_proof.tscn")
