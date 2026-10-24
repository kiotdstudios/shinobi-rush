extends SceneTree
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
func check(label: String, passed: bool, _extra := "") -> void:
	print("PASS " if passed else "FAIL ",label)
	if not passed:
		failed+=1
func _run() -> void:
	await load("res://tests/test_builder_fire.gd").new().run(check,root)
	quit(0 if failed==0 else 1)
