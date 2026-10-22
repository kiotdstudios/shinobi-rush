class_name BanditVisionToggle
extends Node
## Debug only, default OFF. Switch for the Bandit vision overlay (BanditVisionOverlay): a runtime-registered key, an
## always-visible button next to the lab's "Lab (Tab)" button, the boot URL option `?vision=1`, and the additive
## `vision_*` telemetry that WebBridge copies into `window.__SHINOBI_STATE__`.
##
## Added by AnimationLab._build_ui (no scene is edited). While the overlay is OFF this node does nothing per frame (it has no
## _process; it only reacts to its key and its button) and no overlay node exists. Switching ON creates the overlay as a
## child of the Bandit's parent (the arena) so it shares the AI's coordinates; switching OFF frees it at once.
##
## Key: F2, registered at runtime so project.godot stays untouched. NOT F6 (the order's suggestion): F6 is the address-bar /
## pane-focus key of Chrome, Edge and Firefox and a headed browser cannot be tested here. F2 is unbound in the input map, in
## every key-collision test and in the major desktop browsers. The button always works.

const ACTION := "dbg_bandit_vision"
const KEY := KEY_F2
const QUERY_KEY := "vision"
const BUTTON_POS := Vector2(942, 8)  ## left of the lab button (1120, 8), same row, clear of the lab panel (y >= 40)
const BUTTON_SIZE := Vector2(170, 26)
const TIP := "Debug: draw what the Level 1 Bandit's AI can see (its real detection region). Default off. F2 toggles it; ?vision=1 in the URL starts it on."

## The wanted state. It is what `?vision=1` sets before the scene exists and it survives a scene reload inside one page session
## (an arena restart keeps the overlay on). Tests reset it with reset_all().
static var boot_on := false
static var _instance: BanditVisionToggle = null

var on := false
var overlay: BanditVisionOverlay = null
var button: Button = null


func _ready() -> void:
	_ensure_action()
	_instance = self
	if boot_on:
		set_on(true)


func _exit_tree() -> void:
	_drop_overlay(true)  # deferred: a parent that is busy exiting cannot take remove_child() right now
	if _instance == self:
		_instance = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):  # no echo; the event is NOT consumed, so no other input path changes
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


## Always-visible button in the lab's CanvasLayer (works with the lab closed; focus_mode NONE keeps Space/Enter for the game).
func build_button(layer: Node) -> Button:
	button = Button.new()
	button.name = "BanditVisionButton"
	button.toggle_mode = true
	button.position = BUTTON_POS
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.tooltip_text = TIP
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
	button.text = "Bandit vision: ON (F2)" if on else "Bandit vision: off (F2)"


func _attach_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	var parent := _overlay_parent()
	if parent == null:
		return
	overlay = BanditVisionOverlay.new()
	overlay.tree_exited.connect(_on_overlay_exited, CONNECT_ONE_SHOT)
	parent.add_child(overlay)


## Freed without us (its parent left the tree, e.g. an arena restart): forget it and, if it is still wanted, attach a new one
## under whatever parent exists next frame. Our own frees disconnect first, so this never fires for them.
func _on_overlay_exited() -> void:
	overlay = null
	if on and is_inside_tree():
		call_deferred("_attach_overlay")


## Switching OFF removes and frees the overlay immediately (not at the end of the frame), so not even one frame of ghost
## geometry can remain. `deferred` is for _exit_tree, where the parent may be busy exiting.
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


## The Bandit's parent (the arena), else the player's, else our own parent.
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
## Registered once, plain F2 without modifiers, unless the action already exists.
static func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY
	InputMap.action_add_event(ACTION, ev)


## "?a=1&vision=1" -> true. Only an explicit `vision=1` turns it on (like ?debug=1); first occurrence wins.
static func parse_query(query: String) -> bool:
	for part in query.trim_prefix("?").split("&", false):
		var eq := part.find("=")
		var key := part if eq < 0 else part.substr(0, eq)
		if key.uri_decode() != QUERY_KEY:
			continue
		var value := "" if eq < 0 else part.substr(eq + 1).uri_decode().strip_edges()
		return value == "1"
	return false


## Boot-time URL option (WebBridge calls it before the main scene exists).
static func apply_query(query: String) -> void:
	boot_on = parse_query(query)


static func reset_all() -> void:
	boot_on = false


## Additive fields for `window.__SHINOBI_STATE__` (WebBridge copies them). All keys are always present; the numbers are
## zero and the strings empty while the overlay is OFF or there is no Bandit. The Bandit fields describe the FIRST drawn
## Bandit, taken in the same rebuild as the polygon: vision_ai_state is the AI's own State name, vision_sees its own
## `sees_player`, vision_can_see its `can_see(player, vision_cone)` at that instant, vision_player_in whether the drawn polygon
## contains the player, vision_state the overlay's category (not_alert, suspicious, detected, lost_sight, searching, returning).
static func telemetry() -> Dictionary:
	var d := {
		"vision_on": false, "vision_bandits": 0, "vision_points": 0, "vision_rays": 0, "vision_ms": 0.0,
		"vision_state": "", "vision_ai_state": "", "vision_sees": false, "vision_can_see": false,
		"vision_player_in": false, "vision_cone": false, "vision_range": 0.0, "vision_close": 0.0,
		"vision_fov_deg": 0.0, "vision_facing_x": 0.0, "vision_facing_y": 0.0, "vision_mismatch": 0,
		"vision_capped": false,
	}
	var t := _instance
	if t == null or not is_instance_valid(t):
		return d
	d["vision_on"] = t.on
	var ov := t.overlay
	if not t.on or ov == null or not is_instance_valid(ov):
		return d
	d["vision_bandits"] = ov.views.size()
	d["vision_rays"] = ov.rays_last
	d["vision_ms"] = float(ov.usec_last) / 1000.0
	d["vision_mismatch"] = ov.mismatches
	if ov.views.is_empty():
		return d
	var v: Dictionary = ov.views[0]
	var reg: BanditVisionRegion = v["region"]
	d["vision_points"] = reg.points.size()
	d["vision_capped"] = reg.capped
	d["vision_state"] = v["cat_key"]
	d["vision_ai_state"] = v["state_name"]
	d["vision_sees"] = v["sees"]
	d["vision_can_see"] = v["can_see_now"]
	d["vision_player_in"] = v["player_in"]
	d["vision_cone"] = reg.use_cone
	d["vision_range"] = reg.reach
	d["vision_close"] = reg.close_sense
	d["vision_fov_deg"] = reg.fov_deg
	d["vision_facing_x"] = reg.facing.x
	d["vision_facing_y"] = reg.facing.y
	return d
