extends RefCounted
## Proximity "power level" sense debug overlay (SenseVisionOverlay/SenseVisionToggle). Owner 2026-10-22:
## "make sure the intelligence vision have a toggle on and off like the bandit vision" -- this mirrors
## tests/test_bandit_vision_overlay.gd's lifecycle coverage (default off, key, button, URL option, no
## ghost nodes, telemetry) but is much shorter: the sense circle has no cone/LOS/mismatch machinery to
## verify, only its own on/off lifecycle and that it draws a view per live actor while on.

var ck: Callable
var tree: SceneTree
var main: Node
var player: PlayerController
var bandit: Bandit
var lab: AnimationLab
var tog: SenseVisionToggle


func run(check: Callable, root: Node) -> void:
	ck = check
	tree = root.get_tree()
	SenseVisionToggle.reset_all()
	_test_queries()
	if not await _boot(root):
		return
	await _test_off_by_default()
	await _test_key_and_button(root)
	await _test_draws_views_while_on()
	await _test_coexists_with_bandit_vision()
	await _test_lifecycle(root)
	await _shutdown(root)


# ------------------------------------------------------------------------------------------------ helpers
func _boot(root: Node) -> bool:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await tree.physics_frame
	var arena := main.get_node_or_null("TrainingArena")
	player = main.get_node_or_null("TrainingArena/Player") as PlayerController
	bandit = arena.get_node_or_null("Bandit") as Bandit if arena != null else null
	lab = main.get_node_or_null("AnimationLab") as AnimationLab
	tog = lab.sense_vision if lab != null else null
	var ok := arena != null and player != null and bandit != null and lab != null and tog != null
	ck.call("sense vision: the real arena boots with the Bandit, the player, the lab and the sense-vision switch", ok)
	if not ok:
		main.queue_free()
		await tree.process_frame
	return ok


func _shutdown(root: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	await tree.process_frame
	await tree.process_frame
	SenseVisionToggle.reset_all()
	ck.call("sense vision: the suite leaves no overlay node and the switch is back to its default OFF", _count_overlays(root) == 0 and not SenseVisionToggle.boot_on and not SenseVisionToggle.telemetry()["sense_vision_on"])


func _count_overlays(n: Node) -> int:
	var c := 1 if n is SenseVisionOverlay else 0
	for ch in n.get_children():
		c += _count_overlays(ch)
	return c


# ------------------------------------------------------------------------------------------------ tests
func _test_queries() -> void:
	ck.call("sense vision query: '?sense_vision=1' -> true", SenseVisionToggle.parse_query("?sense_vision=1"))
	ck.call("sense vision query: '?sense_vision=0' -> false", not SenseVisionToggle.parse_query("?sense_vision=0"))
	ck.call("sense vision query: missing key -> false", not SenseVisionToggle.parse_query("?camera=close"))
	ck.call("sense vision query: first occurrence wins", SenseVisionToggle.parse_query("?sense_vision=1&sense_vision=0"))
	SenseVisionToggle.apply_query("?sense_vision=1")
	ck.call("sense vision query: apply_query sets boot_on", SenseVisionToggle.boot_on)
	SenseVisionToggle.apply_query("?sense_vision=0")
	ck.call("sense vision query: apply_query(0) clears boot_on", not SenseVisionToggle.boot_on)


func _test_off_by_default() -> void:
	ck.call("sense vision: default OFF with no URL option and nothing pressed", not tog.on and tog.overlay == null and not SenseVisionToggle.boot_on)
	var t := SenseVisionToggle.telemetry()
	ck.call("sense vision: telemetry while OFF is all zero/false", t["sense_vision_on"] == false and t["sense_vision_views"] == 0 and int(t["sense_vision_nodes"]) > 0)


func _test_key_and_button(root: Node) -> void:
	ck.call("sense vision hotkey: none - no action dbg_sense_vision exists and the toggle has no key handler", not InputMap.has_action("dbg_sense_vision") and not tog.is_processing_unhandled_input())

	ck.call("sense vision button: exists, unpressed, labelled off, in the Settings panel", tog.button != null and not tog.button.button_pressed and tog.button.text == "Sense vision: off" and tog.button.get_parent() == lab.settings.rows)

	tog.toggle()
	await tree.process_frame
	ck.call("sense vision toggle(): ON creates exactly one overlay as a child of the arena", tog.on and tog.overlay != null and is_instance_valid(tog.overlay) and tog.overlay.get_parent() == bandit.get_parent() and _count_overlays(root) == 1)
	ck.call("sense vision button: synced to ON", tog.button.button_pressed and tog.button.text == "Sense vision: ON")

	tog.button.button_pressed = false
	tog.button.toggled.emit(false)
	ck.call("sense vision button toggled OFF: drops the overlay immediately (no ghost node)", not tog.on and tog.overlay == null and _count_overlays(root) == 0)

	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F3
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
	ck.call("sense vision hotkey: pressing F3 does nothing", not tog.on and tog.overlay == null and _count_overlays(root) == 0)
	ev.pressed = false
	Input.parse_input_event(ev)
	tog.set_on(false)  # back to a known OFF state for the following tests, regardless of the key's own state


func _test_draws_views_while_on() -> void:
	tog.set_on(true)
	await tree.process_frame
	tog.overlay.refresh()
	ck.call("sense vision: with a live Player and a live (non-DEAD) Bandit, draws one view each", tog.overlay.views.size() == 2, str(tog.overlay.views.size()))
	var kinds := {}
	for v in tog.overlay.views:
		kinds[String(v["kind"]).split(" ")[0]] = true
	ck.call("sense vision: one view is the player, one is the bandit", kinds.has("player") and kinds.has("bandit"), str(kinds.keys()))
	bandit.state = Bandit.State.DEAD
	tog.overlay.refresh()
	ck.call("sense vision: a DEAD Bandit draws no view (matches BanditVisionOverlay's HIDDEN rule)", tog.overlay.views.size() == 1)
	bandit.state = Bandit.State.PATROL
	tog.set_on(false)


func _test_coexists_with_bandit_vision() -> void:
	tog.set_on(true)
	lab.vision.set_on(true)
	await tree.process_frame
	ck.call("sense vision: turning both debug overlays on at once creates exactly one of each, no interference", tog.overlay != null and lab.vision.overlay != null and is_instance_valid(tog.overlay) and is_instance_valid(lab.vision.overlay))
	var t := SenseVisionToggle.telemetry()
	var bt := BanditVisionToggle.telemetry()
	ck.call("sense vision: both toggles report ON independently in telemetry", t["sense_vision_on"] == true and bt["vision_on"] == true)
	lab.vision.set_on(false)
	tog.set_on(false)
	ck.call("sense vision: turning both off again leaves neither overlay behind", tog.overlay == null and lab.vision.overlay == null)


func _test_lifecycle(root: Node) -> void:
	tog.set_on(true)
	await tree.process_frame
	ck.call("sense vision lifecycle: ON before shutdown", tog.on and tog.overlay != null)
	# _shutdown() (called by run()) frees the scene with the overlay still ON and checks no node survives,
	# but SenseVisionToggle.boot_on should still remember ON was wanted until reset_all() runs.
	main.queue_free()
	await tree.process_frame
	await tree.process_frame
	ck.call("sense vision lifecycle: the scene is freed while ON -> no overlay node survives anywhere", _count_overlays(root) == 0)
	ck.call("sense vision lifecycle: ...but the wanted state (ON) is remembered for the next arena", SenseVisionToggle.boot_on)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await tree.physics_frame
	var arena := main.get_node_or_null("TrainingArena")
	player = main.get_node_or_null("TrainingArena/Player") as PlayerController
	bandit = arena.get_node_or_null("Bandit") as Bandit if arena != null else null
	lab = main.get_node_or_null("AnimationLab") as AnimationLab
	tog = lab.sense_vision if lab != null else null
	ck.call("sense vision lifecycle: a fresh arena honours the remembered ON state", tog != null and tog.on and tog.overlay != null)