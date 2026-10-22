class_name SenseVisionToggle
extends Node
## Debug only, default OFF. Switch for the proximity "power level" sense overlay (SenseVisionOverlay):
## a runtime-registered key, an always-visible button next to the Bandit vision button, the boot URL
## option `?sense_vision=1`, and the additive `sense_vision_*` telemetry WebBridge copies into
## `window.__SHINOBI_STATE__`. Owner 2026-10-22: "make sure the intelligence vision have a toggle on and
## off like the bandit vision" -- mirrors BanditVisionToggle's exact lifecycle (added by
## AnimationLab._build_ui, no scene edited; while OFF this node does nothing per frame and no overlay
## node exists; switching ON creates the overlay as a child of the Bandit's parent (the arena) so it
## shares the AI's coordinates, same as BanditVisionOverlay).
##
## Key: F3. NOT F1 (DebugHud's diagnostics key) and NOT F2 (BanditVisionToggle's key); NOT F6 (Chrome/
## Edge/Firefox's address-bar/pane-focus key, per BanditVisionToggle's own note -- a headed browser
## cannot be tested here). F3 is unbound in the input map, in every key-collision test and in the major
## desktop browsers.

const ACTION := "dbg_sense_vision"
const KEY := KEY_F3
const QUERY_KEY := "sense_vision"
## Left of the Bandit vision button (942,8 w170), 8 px gap, same row, clear of the lab panel (y >= 40).
const BUTTON_POS := Vector2(764, DockTab.REST_Y)
const BUTTON_SIZE := Vector2(170, 26)
const TIP := "Debug: draw the invisible proximity 'power level' sense circle (intelligence stat) for the Player and every Bandit. Default off. F3 toggles it; ?sense_vision=1 in the URL starts it on."

## The wanted state. Mirrors BanditVisionToggle.boot_on exactly (see its doc comment). Tests reset it
## with reset_all().
static var boot_on := false
static var _instance: SenseVisionToggle = null

var on := false
var overlay: SenseVisionOverlay = null
var button: Button = null


func _ready() -> void:
	_ensure_action()
	_instance = self
	if boot_on:
		set_on(true)


func _exit_tree() -> void:
	_drop_overlay(true)
	if _instance == self:
		_instance = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		toggle()


func toggle() -> void:
	set_on(not on)


func set_on(value: bool) -> void:
	on = value
	boot_on = value
	if on:
		_attach_overlay()
	else:
		_drop_overlay()
	_sync_button()


## Always-visible button in the lab's CanvasLayer (works with the lab closed; focus_mode NONE keeps
## Space/Enter for the game), placed left of the Bandit vision button by the caller (AnimationLab).
func build_button(layer: Node) -> Button:
	button = Button.new()
	button.name = "SenseVisionButton"
	button.toggle_mode = true
	button.position = BUTTON_POS
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.tooltip_text = TIP
	DockTab.style(button, Color("#4DA3FF"))
	button.toggled.connect(_on_button_toggled)
	layer.add_child(button)
	_sync_button()
	return button


func _on_button_toggled(pressed: bool) -> void:
	if pressed != on:
		set_on(pressed)


func _sync_button() -> void:
	if button == null or not is_instance_valid(button):
		return
	button.set_pressed_no_signal(on)
	button.text = "Sense vision: ON (F3)" if on else "Sense vision: off (F3)"
	DockTab.set_active(button, on)


func _attach_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	var parent := _overlay_parent()
	if parent == null:
		return
	overlay = SenseVisionOverlay.new()
	overlay.tree_exited.connect(_on_overlay_exited, CONNECT_ONE_SHOT)
	parent.add_child(overlay)


func _on_overlay_exited() -> void:
	overlay = null
	if on and is_inside_tree():
		call_deferred("_attach_overlay")


func _drop_overlay(deferred: bool = false) -> void:
	if overlay == null:
		return
	var o := overlay
	overlay = null
	if not is_instance_valid(o):
		return
	if o.tree_exited.is_connected(_on_overlay_exited):
		o.tree_exited.disconnect(_on_overlay_exited)
	if deferred:
		o.queue_free()
		return
	if o.get_parent() != null:
		o.get_parent().remove_child(o)
	o.free()


## The Bandit's parent (the arena), else the player's, else our own parent. Same search order as
## BanditVisionToggle._overlay_parent() (same single-arena topology).
func _overlay_parent() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	for n in tree.get_nodes_in_group("enemy"):
		if n is Bandit and n.get_parent() != null:
			return n.get_parent()
	var p := tree.get_first_node_in_group("player")
	if p != null and p.get_parent() != null:
		return p.get_parent()
	return get_parent()


# ------------------------------------------------------------------------------------------------ statics
static func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY
	InputMap.action_add_event(ACTION, ev)


## "?a=1&sense_vision=1" -> true. Only an explicit `sense_vision=1` turns it on; first occurrence wins.
static func parse_query(query: String) -> bool:
	for part in query.trim_prefix("?").split("&", false):
		var eq := part.find("=")
		var key := part if eq < 0 else part.substr(0, eq)
		if key.uri_decode() != QUERY_KEY:
			continue
		var value := "" if eq < 0 else part.substr(eq + 1).uri_decode().strip_edges()
		return value == "1"
	return false


static func apply_query(query: String) -> void:
	boot_on = parse_query(query)


static func reset_all() -> void:
	boot_on = false


## Additive fields for `window.__SHINOBI_STATE__`: lifecycle only (on/off, view count, live node count
## for a ghost-node check), mirroring BanditVisionToggle.telemetry()'s pattern. The actual sense numbers
## (radius, active) are already published per-actor (player_sense_radius/player_kunai_drawn,
## bandit_sense_radius/bandit_senses_player) -- this does not duplicate them.
static func telemetry() -> Dictionary:
	var d := {
		"sense_vision_on": false, "sense_vision_views": 0,
		"sense_vision_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	var t := _instance
	if t == null or not is_instance_valid(t):
		return d
	d["sense_vision_on"] = t.on
	if t.overlay != null and is_instance_valid(t.overlay):
		d["sense_vision_views"] = t.overlay.views.size()
	return d