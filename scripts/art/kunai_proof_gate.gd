extends Node
func _ready() -> void:
	var enabled := "--kunai-proof" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		enabled = enabled or "kunai=proof" in str(JavaScriptBridge.eval("window.location.search", true))
	if enabled:
		get_tree().change_scene_to_file.call_deferred("res://scenes/art/kunai_primary_proof.tscn")
