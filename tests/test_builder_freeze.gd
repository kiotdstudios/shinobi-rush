extends RefCounted
## While the builder is open the world is frozen, the game HUD is hidden, the panel fills the screen height, the
## filters fold away, and the wheel zooms out three extra steps below the gameplay baseline.

var ck: Callable


func run(p_ck: Callable, root: Node) -> void:
	ck = p_ck
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var tree := root.get_tree()
	for i in 4:
		await tree.process_frame
	var editor := tree.get_first_node_in_group("world_editor") as WorldEditor
	var player := tree.get_first_node_in_group("player") as PlayerController
	var hud := player.get_node("HealthBar") as HealthBar
	ck.call("freeze: the editor registers in the world_editor group", editor != null)
	if editor == null:
		main.queue_free()
		return
	var base := player.camera_baseline
	player.camera.zoom = Vector2.ONE * base
	ck.call("freeze: the game runs and shows its HUD before building", not tree.paused and hud.visible)

	editor.set_open(true)
	await tree.process_frame
	ck.call("freeze: opening the builder pauses the world", tree.paused)
	ck.call("freeze: the game HUD is hidden in the editor", not hud.visible)
	var before := player.global_position
	Input.action_press("move_right")
	for i in 20:
		await tree.physics_frame
	Input.action_release("move_right")
	ck.call("freeze: the player cannot walk while building", player.global_position.is_equal_approx(before))
	ck.call("layout: the panel fills the screen top to bottom", editor.panel.offset_top == 0.0 and editor.panel.offset_bottom == 0.0)
	ck.call("layout: the type filters are folded away by default", not editor.filters_box.visible and not editor.filters_toggle.button_pressed)
	editor.filters_toggle.button_pressed = true
	ck.call("layout: the filters toggle opens the checkboxes", editor.filters_box.visible)
	editor.filters_toggle.button_pressed = false
	ck.call("layout: the filters fold away again", not editor.filters_box.visible)

	for i in 3:
		editor.wheel_zoom(-1)
	ck.call("zoom: three wheel steps out go below the baseline (%.3f < %.3f)" % [player.camera.zoom.x, base], player.camera.zoom.x < base * 0.8 - 0.0001)
	var lowest := player.camera.zoom.x
	editor.wheel_zoom(-1)
	ck.call("zoom: it stops at the third extra step", is_equal_approx(player.camera.zoom.x, lowest) and is_equal_approx(lowest, base * 0.5))
	editor.wheel_zoom(1)
	ck.call("zoom: the wheel steps back in", player.camera.zoom.x > lowest)
	var ticks := 0
	while player.camera.zoom.x < base - 0.0001 and ticks < 10:
		editor.wheel_zoom(1)
		ticks += 1
	editor.wheel_zoom(1)
	ck.call("zoom: in the builder the wheel still zooms in past the baseline", player.camera.zoom.x > base)

	editor.set_type_filter("HUD layout", true)
	ck.call("freeze: ticking HUD layout brings the HUD back for editing", hud.visible)
	editor.set_type_filter("HUD layout", false)
	ck.call("freeze: unticking hides it again", not hud.visible)

	editor.set_open(false)
	await tree.process_frame
	ck.call("freeze: closing the builder resumes the game", not tree.paused)
	ck.call("freeze: the HUD returns", hud.visible)
	ck.call("zoom: the gameplay zoom is restored", is_equal_approx(player.camera.zoom.x, base))
	main.queue_free()
	await tree.process_frame
