extends RefCounted
## Settings tab: every dock tab lives under Settings (bottom-edge tabs hidden), and the camera zoom is locked
## at 0.665 by default and changeable from a Settings slider.

var ck: Callable


func run(p_ck: Callable, tree_root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(main)
	for i in 6:
		await main.get_tree().process_frame
	var s := SettingsPanel._instance
	ck.call("settings: panel exists", s != null)
	if s == null:
		main.queue_free()
		return
	ck.call("zoom lock: the default camera zoom is 0.665", is_equal_approx(WorldScale.CAMERA_BASE_ZOOM, 0.665) and is_equal_approx(CameraPreset.zoom_for(CameraPreset.DEFAULT_ID, 108.0), 0.665))
	var p := main.get_node("TrainingArena/Player") as PlayerController
	ck.call("zoom lock: the player camera starts at 0.665", is_equal_approx(p.camera.zoom.x, 0.665), str(p.camera.zoom.x))
	ck.call("settings: a zoom slider exists, starts at 0.665", s.zoom_slider != null and is_equal_approx(s.zoom_slider.value, 0.665))
	var names := {}
	for b in s.tab_rows.keys():
		names[str(b.name)] = true
		ck.call("settings: dock tab %s is hidden from the bottom edge" % b.name, not b.visible)
	ck.call("settings: Player, Controls and Diagnostics tabs moved under Settings", names.has("Tab_player") and names.has("Tab_controls") and names.has("Tab_diag"))
	ck.call("settings: the Lab tab moved under Settings", s.tab_rows.size() >= 4)
	var before := {}
	for b in s.tab_rows.keys():
		before[b] = bool(b.get_meta("dock_active", false))
	var pb: Button = null
	for b in s.tab_rows.keys():
		if str(b.name) == "Tab_controls":
			pb = b
	if pb != null:
		var was := bool(pb.get_meta("dock_active", false))
		(s.tab_rows[pb] as Button).pressed.emit()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		ck.call("settings: pressing a Settings row toggles that panel", bool(pb.get_meta("dock_active", false)) != was)
		ck.call("settings: the row mirrors the panel state", (s.tab_rows[pb] as Button).button_pressed == bool(pb.get_meta("dock_active", false)))
		(s.tab_rows[pb] as Button).pressed.emit()
	s.set_zoom(0.9)
	ck.call("zoom setting: the slider value changes the player camera baseline and zoom", is_equal_approx(p.camera_baseline, 0.9) and is_equal_approx(p.camera.zoom.x, 0.9), str(p.camera.zoom.x))
	s.set_zoom(5.0)
	ck.call("zoom setting: out-of-range values are clamped", is_equal_approx(p.camera_baseline, SettingsPanel.ZOOM_MAX))
	s.set_zoom(WorldScale.CAMERA_BASE_ZOOM)
	ck.call("zoom setting: reset returns to 0.665", is_equal_approx(p.camera_baseline, 0.665) and is_equal_approx(s.zoom_slider.value, 0.665))
	CameraPreset.set_active(CameraPreset.DEFAULT_ID)
	main.queue_free()
	await tree_root.get_tree().process_frame
