class_name AnimationLab
extends Node
## Animation / size lab for the art owner. Tab (or the on-screen button) toggles the panel, the
## turntable stand(s) and the overlays. Every function has a dbg_* key AND a clickable button.
## The status line and metrics stay on screen even when the lab is hidden.

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]
## Lab zoom steps. The zoom list is [active preset baseline] + these (see zoom_list); a baseline that already equals
## one of them is not repeated. The whole steps (1x 2x 3x 4x) are native 1:1 pixels; the half steps (1.5x 2.5x 3.5x)
## are NOT pixel-exact with the nearest-neighbour filter (a source pixel covers an uneven number of screen pixels).
const NATIVE_ZOOMS: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
## Camera preset switch (wide <-> close). The action is registered at runtime so project.godot stays untouched.
const PRESET_ACTION := "dbg_camera_preset"
const PRESET_KEY := KEY_N
## Camera-impact demo (CameraImpact): 7 light, 8 heavy, 9 burst of three, 0 the heavy kick stretched to CameraImpact.SLOW_MS so
## it can be watched. Registered at runtime like N (project.godot stays untouched) and only active while the lab is open. They
## kick along the player's facing, as a real hit would along attacker -> target. Digits, because H/G/B share their physical key
## with the telemetry HUD's Ctrl+Alt+H/G/B (the repo's key-collision tests compare physical keys only).
const IMPACT_ACTIONS: Dictionary = {
	"dbg_camera_impact_light": KEY_7, "dbg_camera_impact_heavy": KEY_8,
	"dbg_camera_impact_burst": KEY_9, "dbg_camera_impact_slow": KEY_0,
}
const BURST_GAP_S := 0.04  ## the burst: three light hits this far apart
## Stands sit LEFT of the spawn so they stay clear of the lab panel (screen right) at 1x-2x zoom.
## Provisional prototype values scaled by WorldScale.SCALE (stands far enough apart for the 128 px frames).
const STAND_OFFSETS: Array[Vector2] = WorldScale.STAND_OFFSETS
const SPIN_SECONDS := 1.5
const FOOTPRINT := WorldScale.FOOTPRINT  ## shared with the player's collision rectangle
const OVERLAYS: Array = [
	["iso", "1 iso grid"], ["square", "2 square grid"], ["anchor", "3 anchor"],
	["footprint", "4 footprint"], ["ruler", "5 height ruler"], ["bbox", "6 frame box"],
]
const KEYS_HELP := "Tab lab | [ ] set | , . anim | ; ' dir | V follow/spin | - = speed | P pause | O step | C compare | Z or wheel zoom (half steps are not pixel-exact) | N camera preset | 1-6 overlays | 7 8 9 0 camera kick: light heavy burst slow"

enum DirMode { FOLLOW, FIXED, SPIN }

var lib: SpriteLibrary
var sel_index: int = -1  ## -1 = placeholder
var anim_id: String = ""
var dir_mode: DirMode = DirMode.FOLLOW
var dir_index: int = 0
var speed_index: int = 2
var anim_paused: bool = false
var compare: bool = false
var zoom_index: int = 0
var lab_on: bool = false
var overlay_on: Dictionary = {"iso": false, "square": false, "anchor": true, "footprint": true, "ruler": false, "bbox": false}

var player: PlayerController
var arena: Node2D
var stands: Array[Stand] = []
var overlay: LabOverlay
var _spin_timer: float = 0.0
var _spin_dir: int = 0
var _hud: Node  ## sibling DebugHud; sprite status/metrics feed into its diagnostics panel instead of drawing our own overlapping labels.
var _panel: PanelContainer
var _value_labels: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _lab_button: Button
var vision: BanditVisionToggle  ## Bandit vision debug overlay switch (key F2 + the always-visible button), default OFF
var _timer: float = 0.0
var _actions: Dictionary = {}


## A turntable stand: neutral ground diamond + label + a SpriteActor.
class Stand extends Node2D:
	var actor: SpriteActor
	var caption: String = ""

	func _init() -> void:
		actor = SpriteActor.new()
		add_child(actor)

	func _draw() -> void:
		var d := WorldScale.STAND_DIAMOND
		draw_colored_polygon(PackedVector2Array([Vector2(0, -d.y), Vector2(d.x, 0), Vector2(0, d.y), Vector2(-d.x, 0)]), Color("#8c8c8c"))
		draw_polyline(PackedVector2Array([Vector2(0, -d.y), Vector2(d.x, 0), Vector2(0, d.y), Vector2(-d.x, 0), Vector2(0, -d.y)]), Color(0, 0, 0, 0.5), 1.0)
		# Unclipped, centred on the stand. Shrink the font so it never exceeds the stand spacing.
		var fsize := 11
		while fsize > 7 and ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > 126.0:
			fsize -= 1
		var tw := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		draw_string(ThemeDB.fallback_font, Vector2(-tw * 0.5, d.y + 14.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)


## World-space overlays: grids, anchor crosshair, footprint ellipse, height ruler, frame box.
class LabOverlay extends Node2D:
	var lab: AnimationLab

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if lab == null or lab.player == null:
			return
		var cam := lab.player.camera
		var zoom := cam.zoom.x
		var c := cam.get_screen_center_position()
		var half := Vector2(640, 360) / zoom + Vector2(80, 80)
		var r := Rect2(c - half, half * 2.0)
		if lab.overlay_on["square"]:
			var x := floorf(r.position.x / 32.0) * 32.0
			while x <= r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.2, 0.8, 1.0, 0.35), 1.0 / zoom)
				x += 32.0
			var y := floorf(r.position.y / 32.0) * 32.0
			while y <= r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.2, 0.8, 1.0, 0.35), 1.0 / zoom)
				y += 32.0
		if lab.overlay_on["iso"]:
			# World tiles projected 2:1 -> TILE_SIZE diamonds (144x72). Lines y = x/2 + ts*j - ts/2 and y = -x/2 + ts*i - ts/2.
			var ts := WorldScale.TILE_SIZE.y
			var j0 := int(floorf((r.position.y - r.end.x * 0.5) / ts)) - 1
			var j1 := int(ceilf((r.end.y - r.position.x * 0.5) / ts)) + 1
			for j in range(j0, j1 + 1):
				var cc := ts * j - ts * 0.5
				draw_line(Vector2(r.position.x, r.position.x * 0.5 + cc), Vector2(r.end.x, r.end.x * 0.5 + cc), Color(1.0, 0.8, 0.2, 0.4), 1.0 / zoom)
			var i0 := int(floorf((r.position.y + r.position.x * 0.5) / ts)) - 1
			var i1 := int(ceilf((r.end.y + r.end.x * 0.5) / ts)) + 1
			for i in range(i0, i1 + 1):
				var cc2 := ts * i - ts * 0.5
				draw_line(Vector2(r.position.x, -r.position.x * 0.5 + cc2), Vector2(r.end.x, -r.end.x * 0.5 + cc2), Color(1.0, 0.8, 0.2, 0.4), 1.0 / zoom)
		for t: Array in lab.targets():
			_draw_target(t[0], t[1], t[2], zoom)

	func _draw_target(origin: Vector2, s: SpriteSet, aid: String, zoom: float) -> void:
		var w := 1.0 / zoom
		if lab.overlay_on["footprint"]:
			var pts := PackedVector2Array()
			for k in 25:
				var a := TAU * k / 24.0
				pts.append(origin + Vector2(cos(a) * FOOTPRINT.x * 0.5, sin(a) * FOOTPRINT.y * 0.5 - FOOTPRINT.y * 0.5))
			draw_polyline(pts, Color(1, 0.3, 0.3, 0.95), w * 1.5)
		var fs := Vector2(s.anim_frame_size(aid)) if s != null else Vector2(128, 128)
		var anchor := s.anim_anchor(aid) if s != null else Vector2(64, 116)
		if lab.overlay_on["bbox"] and s != null:
			draw_rect(Rect2(origin - anchor, fs), Color(0.4, 1, 0.4, 0.9), false, w)
		if lab.overlay_on["ruler"]:
			var bh := s.body_height_px if s != null else SpriteSet.DEFAULT_BODY_HEIGHT
			var hw := maxf(fs.x * 0.5, 24.0)
			draw_line(origin + Vector2(-hw, 0), origin + Vector2(hw, 0), Color(1, 1, 1, 0.8), w)
			draw_line(origin + Vector2(-hw, -bh), origin + Vector2(hw, -bh), Color(1, 0.5, 1, 0.9), w)
			draw_line(origin + Vector2(hw, 0), origin + Vector2(hw, -bh), Color(1, 0.5, 1, 0.9), w)
			draw_string(ThemeDB.fallback_font, origin + Vector2(hw + 3, -bh * 0.5), "%d px" % int(bh), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(10.0 / zoom)), Color(1, 0.5, 1))
		if lab.overlay_on["anchor"]:
			draw_line(origin + Vector2(-8, 0), origin + Vector2(8, 0), Color(1, 1, 0), w * 1.5)
			draw_line(origin + Vector2(0, -8), origin + Vector2(0, 8), Color(1, 1, 0), w * 1.5)


## dbg_* action -> callable. Built once (not per input event).
func _build_actions() -> void:
	_actions = {
		"dbg_toggle_lab": toggle_lab,
		"dbg_set_prev": func() -> void: _select_set(sel_index - 1),
		"dbg_set_next": func() -> void: _select_set(sel_index + 1),
		"dbg_anim_prev": func() -> void: _step_anim(-1),
		"dbg_anim_next": func() -> void: _step_anim(1),
		"dbg_dir_prev": func() -> void: _step_dir(-1),
		"dbg_dir_next": func() -> void: _step_dir(1),
		"dbg_dir_follow": cycle_dir_mode,
		"dbg_speed_down": func() -> void: _step_speed(-1),
		"dbg_speed_up": func() -> void: _step_speed(1),
		"dbg_anim_pause": toggle_pause,
		"dbg_anim_step": step_once,
		"dbg_compare": toggle_compare,
		"dbg_zoom_cycle": cycle_zoom,
		PRESET_ACTION: cycle_preset,
		"dbg_camera_impact_light": func() -> void: impact_demo("light"),
		"dbg_camera_impact_heavy": func() -> void: impact_demo("heavy"),
		"dbg_camera_impact_burst": func() -> void: impact_demo("burst"),
		"dbg_camera_impact_slow": func() -> void: impact_demo("slow"),
		"dbg_overlay_iso_grid": func() -> void: toggle_overlay("iso"),
		"dbg_overlay_square_grid": func() -> void: toggle_overlay("square"),
		"dbg_overlay_anchor": func() -> void: toggle_overlay("anchor"),
		"dbg_overlay_footprint": func() -> void: toggle_overlay("footprint"),
		"dbg_overlay_ruler": func() -> void: toggle_overlay("ruler"),
		"dbg_overlay_bbox": func() -> void: toggle_overlay("bbox"),
	}


## Register the preset action once (plain N, no modifier) unless project.godot already defines it.
static func _ensure_preset_action() -> void:
	if InputMap.has_action(PRESET_ACTION):
		return
	InputMap.add_action(PRESET_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = PRESET_KEY
	InputMap.action_add_event(PRESET_ACTION, ev)


## Register the camera-impact demo actions once unless they already exist.
static func _ensure_impact_actions() -> void:
	for action: String in IMPACT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = IMPACT_ACTIONS[action]
		InputMap.action_add_event(action, ev)


func _ready() -> void:
	_ensure_preset_action()
	_ensure_impact_actions()
	_build_actions()
	lib = SpriteLibrary.get_instance()
	player = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		push_warning("AnimationLab: no player found")
		return
	player.camera_baseline_changed.connect(_on_baseline_changed)
	arena = player.get_parent() as Node2D
	_build_world()
	_build_ui()
	_hud = get_parent().get_node_or_null("DebugHud")
	var first := lib.first_valid()
	if first != null:
		sel_index = lib.sets.find(first)
	elif not lib.sets.is_empty():
		sel_index = 0
	_select_set(sel_index)
	_set_lab(false)  # Loading real art must not auto-open the lab or change Tab toggle semantics.
	_refresh_ui()


# ---------------------------------------------------------------- state helpers

func current_set() -> SpriteSet:
	return lib.sets[sel_index] if (sel_index >= 0 and sel_index < lib.sets.size()) else null


func current_dir_name() -> String:
	match dir_mode:
		DirMode.FOLLOW:
			return SpriteSet.dir_name(player.facing8) if player != null else "S"
		DirMode.SPIN:
			return SpriteSet.DIRS8[_spin_dir]
	return SpriteSet.DIRS8[dir_index]


## [origin (arena-local), set, anim id] for the player and each visible stand, for the overlays.
func targets() -> Array:
	var out: Array = []
	if player == null:
		return out
	var pv_set: SpriteSet = player.visual.sprite_set
	out.append([player.position, pv_set, player.visual.last_anim if pv_set != null else ""])
	for st in stands:
		if st.visible and st.actor.visible:
			out.append([st.position, st.actor.set_ref, st.actor.anim_id])
	return out


func _select_set(idx: int) -> void:
	var count := lib.sets.size()
	sel_index = clampi(idx, -1, count - 1)
	var s := current_set()
	if player != null:
		player.visual.set_sprite_set(s)
	if s != null and not s.anim_order.is_empty():
		if not s.animations.has(anim_id):
			anim_id = s.anim_order[0]
	else:
		anim_id = ""
	_refresh_ui()


func _anim_list() -> Array[String]:
	var s := current_set()
	return s.anim_order if s != null else ([] as Array[String])


# ---------------------------------------------------------------- world (stands, overlay)

func _build_world() -> void:
	var spawn := arena.get_node_or_null("Spawn") as Node2D
	var base := spawn.position if spawn != null else Vector2(0, 60)
	for off in STAND_OFFSETS:
		var st := Stand.new()
		st.position = base + off
		st.visible = false
		arena.add_child(st)
		stands.append(st)
	overlay = LabOverlay.new()
	overlay.lab = self
	overlay.z_index = 100
	overlay.visible = false
	arena.add_child(overlay)


func _update_stands() -> void:
	var s := current_set()
	var shown: Array = [s, null]
	if compare:
		shown = [lib.sets[0] if lib.sets.size() > 0 else null, lib.sets[1] if lib.sets.size() > 1 else null]
	for i in stands.size():
		var st := stands[i]
		var ss: SpriteSet = shown[i]
		st.visible = lab_on and (i == 0 or compare)
		if not st.visible:
			continue
		var cap := ""
		var ok := false
		if ss == null:
			cap = "(no set)" if compare else "placeholder"
		elif not ss.is_valid():
			cap = "%s: ERROR" % ss.id
		else:
			var aid := anim_id if ss.animations.has(anim_id) else ""
			if aid.is_empty():
				cap = "%s: no '%s'" % [ss.id, anim_id]
			else:
				ok = st.actor.show_animation(ss, aid, current_dir_name())
				cap = "%s %dx%d | %s %s" % [ss.id, ss.frame_size.x, ss.frame_size.y, aid, st.actor.dir + ("*" if st.actor.flip else "")]
		st.actor.visible = ok
		st.actor.set_playback(SPEEDS[speed_index], anim_paused)
		if st.caption != cap:
			st.caption = cap
			st.queue_redraw()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_lab_button = _button(layer, "Lab (Tab)", Vector2(1120, 8), Vector2(150, 26), toggle_lab)
	# Bandit vision overlay (debug, default OFF): its key and its always-visible button next to the Lab button.
	vision = BanditVisionToggle.new()
	vision.name = "BanditVisionToggle"
	add_child(vision)
	vision.build_button(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(930, 40)
	_panel.custom_minimum_size = Vector2(340, 0)
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)
	_row(box, "set", "Set  [ ]", func() -> void: _select_set(sel_index - 1), func() -> void: _select_set(sel_index + 1))
	_row(box, "anim", "Anim  , .", func() -> void: _step_anim(-1), func() -> void: _step_anim(1))
	_row(box, "dir", "Dir  ; '", func() -> void: _step_dir(-1), func() -> void: _step_dir(1))
	_row(box, "mode", "Dir mode  V", func() -> void: cycle_dir_mode(), func() -> void: cycle_dir_mode())
	_row(box, "speed", "Speed  - =", func() -> void: _step_speed(-1), func() -> void: _step_speed(1))
	_row(box, "pause", "Pause P / Step O", func() -> void: toggle_pause(), func() -> void: step_once())
	_row(box, "compare", "Compare  C", func() -> void: toggle_compare(), func() -> void: toggle_compare())
	_row(box, "zoom", "Zoom  Z / wheel", func() -> void: cycle_zoom(), func() -> void: cycle_zoom())
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for o: Array in OVERLAYS:
		var key: String = o[0]
		var b := _button(grid, o[1], Vector2.ZERO, Vector2(160, 24), func() -> void: toggle_overlay(key))
		b.toggle_mode = true
		_toggle_buttons[key] = b
	# After the overlay grid so the existing rows keep their indices (tests address them by position).
	_row(box, "preset", "Cam preset  N", func() -> void: cycle_preset(), func() -> void: cycle_preset())
	_impact_row(box)
	var help := Label.new()
	help.text = KEYS_HELP
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(320, 0)
	help.add_theme_font_size_override("font_size", 10)
	box.add_child(help)


## "Cam kick  7 8 9 0": light, heavy, burst of three, slow heavy (the buttons do what the keys do).
func _impact_row(box: Node) -> void:
	var h := HBoxContainer.new()
	box.add_child(h)
	var t := Label.new()
	t.text = "Cam kick  7 8 9 0"
	t.custom_minimum_size = Vector2(112, 0)
	t.add_theme_font_size_override("font_size", 11)
	h.add_child(t)
	for k: Array in [["light", "L"], ["heavy", "H"], ["burst", "x3"], ["slow", "S"]]:
		var kind: String = k[0]
		_button(h, k[1], Vector2.ZERO, Vector2(34, 24), func() -> void: impact_demo(kind))


func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, pos: Vector2, min_size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE  # keep Space/Enter for gameplay
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _row(box: Node, key: String, title: String, prev_cb: Callable, next_cb: Callable) -> void:
	var h := HBoxContainer.new()
	box.add_child(h)
	var t := Label.new()
	t.text = title
	t.custom_minimum_size = Vector2(112, 0)
	t.add_theme_font_size_override("font_size", 11)
	h.add_child(t)
	_button(h, "<", Vector2.ZERO, Vector2(26, 24), prev_cb)
	_button(h, ">", Vector2.ZERO, Vector2(26, 24), next_cb)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", 11)
	v.custom_minimum_size = Vector2(130, 0)
	h.add_child(v)
	_value_labels[key] = v


func _refresh_ui() -> void:
	if _value_labels.is_empty():
		return
	var s := current_set()
	if _hud != null:
		var status_text := SpriteLibrary.status_line(s)
		var color := Color("#ff6b6b") if (s != null and not s.is_valid()) else Color.WHITE
		var parts: Array[String] = []
		if s != null:
			parts.append("%s | frame %dx%d | anchor (%d,%d) | anims %d/%d | frames %d | load %.1f ms" % [
				s.id, s.frame_size.x, s.frame_size.y, int(s.foot_anchor.x), int(s.foot_anchor.y),
				s.anims_loaded, s.anim_order.size(), s.frames_loaded, s.load_ms])
		if s != null and not s.is_valid():
			for i in mini(s.errors.size(), 3):
				parts.append("! " + s.errors[i])
		var zoom_text := "Zoom: %s" % zoom_label(zoom_index, _baseline())
		_hud.set_sprite_status(zoom_text, status_text, "\n".join(parts), color)
	_value_labels["set"].text = s.id if s != null else "none (placeholder)"
	_value_labels["anim"].text = anim_id if anim_id != "" else "-"
	_value_labels["dir"].text = current_dir_name() + (" (auto)" if dir_mode != DirMode.FIXED else "")
	_value_labels["mode"].text = DirMode.keys()[dir_mode]
	_value_labels["speed"].text = "%sx" % str(SPEEDS[speed_index])
	_value_labels["pause"].text = "PAUSED" if anim_paused else "playing"
	_value_labels["compare"].text = "ON (first two sets)" if compare else "off"
	_value_labels["zoom"].text = zoom_label(zoom_index, _baseline())
	_value_labels["preset"].text = CameraPreset.active_id()
	for k: String in _toggle_buttons:
		_toggle_buttons[k].button_pressed = overlay_on[k]
	_lab_button.text = "Lab: ON (Tab)" if lab_on else "Lab: off (Tab)"


# ---------------------------------------------------------------- actions (keys + buttons)

func toggle_lab() -> void:
	_set_lab(not lab_on)


func _set_lab(on: bool) -> void:
	lab_on = on
	if not on and zoom_index != 0:
		set_zoom_index(0)  # closing the lab restores the gameplay baseline
	if _panel != null:
		_panel.visible = on
		overlay.visible = on
	_update_stands()
	_refresh_ui()


func _step_anim(d: int) -> void:
	var lst := _anim_list()
	if lst.is_empty():
		return
	anim_id = lst[posmod(lst.find(anim_id) + d, lst.size())]
	_refresh_ui()


func _step_dir(d: int) -> void:
	if dir_mode != DirMode.FIXED:
		dir_index = SpriteSet.DIRS8.find(current_dir_name())
		dir_mode = DirMode.FIXED
	dir_index = posmod(dir_index + d, 8)
	_refresh_ui()


func cycle_dir_mode() -> void:
	dir_mode = ((dir_mode + 1) % 3) as DirMode
	_refresh_ui()


func _step_speed(d: int) -> void:
	speed_index = clampi(speed_index + d, 0, SPEEDS.size() - 1)
	_refresh_ui()


func toggle_pause() -> void:
	anim_paused = not anim_paused
	_refresh_ui()


func step_once() -> void:
	anim_paused = true
	for st in stands:
		if st.visible:
			st.actor.step_frame()
	_refresh_ui()


func toggle_compare() -> void:
	compare = not compare
	_refresh_ui()


## Baseline of the active preset for the current figure (the wide default before a player exists).
func _baseline() -> float:
	return player.camera_baseline if player != null else CameraPreset.zoom_for(CameraPreset.active())


## Index 0 is the gameplay baseline (active preset); the rest are NATIVE_ZOOMS in ascending order. A baseline that
## already equals one of them (close preset snapped to pixel-exact 1.0, or ?camera=1.5) is not listed twice.
static func zoom_list(baseline: float) -> Array[float]:
	var out: Array[float] = [baseline]
	for z in NATIVE_ZOOMS:
		if not is_equal_approx(z, baseline):
			out.append(z)
	return out


## "wide 0.44x" / "close 1.17x" for the baseline, "1x" "1.5x" "2x" ... "4x" for the rest (a whole step has no decimals).
static func zoom_label(i: int, baseline: float, spec: Variant = null) -> String:
	var zl := zoom_list(baseline)
	if i == 0:
		return CameraPreset.label_for(CameraPreset.active() if spec == null else spec, baseline)
	var z := zl[clampi(i, 0, zl.size() - 1)]
	if is_equal_approx(z, roundf(z)):
		return "%dx" % int(roundf(z))
	return "%sx" % String.num(z, 2)


func cycle_zoom() -> void:
	set_zoom_index((zoom_index + 1) % zoom_list(_baseline()).size())


func set_zoom_index(i: int) -> void:
	var zl := zoom_list(_baseline())
	zoom_index = clampi(i, 0, zl.size() - 1)
	if player != null:
		player.camera.zoom = Vector2.ONE * zl[zoom_index]
	_refresh_ui()


## Switch the active camera preset (wide -> close -> wide). Back to the baseline, like closing the lab.
func cycle_preset() -> void:
	CameraPreset.set_active(CameraPreset.next_id(CameraPreset.active()))
	if player != null:
		player.refresh_camera_baseline()
	set_zoom_index(0)


## The baseline changed under us (sprite set with another body height): keep the camera where it is and
## re-point the index at it; if the current zoom is no longer in the list, fall back to the baseline.
func _on_baseline_changed(_zoom: float) -> void:
	if player == null:
		return
	var zl := zoom_list(_baseline())
	var cur := player.camera.zoom.x
	var idx := 0
	for i in zl.size():
		if is_equal_approx(zl[i], cur):
			idx = i
			break
	set_zoom_index(idx)


func toggle_overlay(key: String) -> void:
	overlay_on[key] = not overlay_on[key]
	_refresh_ui()


## Camera-impact demo (keys 7 8 9 0 and the "Cam kick" buttons): "light", "heavy", "burst" (three light hits BURST_GAP_S apart)
## or "slow" (the heavy kick stretched to CameraImpact.SLOW_MS: same peak, only the duration changes).
func impact_demo(kind: String) -> void:
	var dir := player.facing8 if player != null else Vector2.DOWN
	match kind:
		"light":
			CameraImpact.light_hit(dir)
		"heavy":
			CameraImpact.heavy_hit(dir)
		"slow":
			CameraImpact.impulse(dir, CameraImpact.HEAVY_PEAK_PX, CameraImpact.SLOW_MS)
		"burst":
			CameraImpact.light_hit(dir)
			for i in [1, 2]:
				get_tree().create_timer(i * BURST_GAP_S).timeout.connect(func() -> void: CameraImpact.light_hit(dir))


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom_index(zoom_index + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_index(zoom_index - 1)
		return
	for a: String in _actions:
		if event.is_action_pressed(a):
			if IMPACT_ACTIONS.has(a) and not lab_on:
				continue  # the camera-kick demo keys only work while the lab is open
			(_actions[a] as Callable).call()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if player == null:
		return
	if dir_mode == DirMode.SPIN and not anim_paused:
		_spin_timer += delta
		if _spin_timer >= SPIN_SECONDS:
			_spin_timer = 0.0
			_spin_dir = (_spin_dir + 1) % 8
	_update_stands()
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.1
		_refresh_ui()
