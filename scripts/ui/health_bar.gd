class_name HealthBar
extends CanvasLayer
## Player status HUD (top-left): a gold diamond portrait frame holding the player's own face, a HP bar, a Chakra bar and
## three substitution pips. Every piece is pixel art (assets/ui/hud/, generated with PixelLab; the bar frame is hand-built);
## only the fill width, numbers and pip states are drawn here. Pure presentation: it listens to the player's
## health_changed / chakra_changed / substitution_changed signals and holds no gameplay state of its own.
## (Class name kept as HealthBar: it started as the HP bar and PlayerController/tests still address it by that name.)

const DIR := "res://assets/ui/hud/"
const ORIGIN := Vector2(8.0, 6.0)  ## top-left of the portrait frame
const PORTRAIT_SIZE := Vector2(96.0, 96.0)
const AVATAR_POS := Vector2(8.0, -4.0)  ## avatar (80x80) over the frame; the head pops out above the diamond
const BAR_X := 94.0  ## both bars start just right of the diamond's tip (x 96 at the chakra row), so their left ends line up and neither is clipped
const BAR_TUCK := 4.0  ## rounded left cap of each bar: the label centres on the rest
const HP_Y := 15.0
const CHAKRA_Y := 41.0
const BAR_SIZE := Vector2(196.0, 22.0)
const FILL_INSET := Vector2(3.0, 3.0)
const FILL_SIZE := Vector2(190.0, 16.0)
const PIP_POS := Vector2(124.0, 92.0)
const PIP_SIZE := Vector2(38.0, 26.0)  ## the substitution pips are the log art (LogPip), drawn 1:1
const PIP_STEP := 44.0
const PIP_FLASH := 0.7  ## seconds a pip glows after it refills
const SLOT_SIZE := 56.0  ## ability bar (bottom centre): Substitution (L2, square gold frame) + four gold circles for R2 + a face button
const SLOT_GAP := 8.0
const SLOT_COUNT := 5
const SLOT_Y := 616.0
const COL_TEXT := Color(1.0, 1.0, 1.0, 0.95)
const COL_FILL := Color(1.0, 1.0, 1.0, 1.0)  ## fill textures are already red / blue: white = unmodulated
const COL_LOW := Color(1.0, 0.72, 0.72, 1.0)  ## HP at or below LOW_FRACTION: brighter flush
const COL_TRAIL := Color(1.0, 1.0, 1.0, 0.55)
## Every piece of the HUD the builder can pick up and move. Order = draw order (hit-testing walks it backwards).
const ELEMENTS: Array[String] = ["hp_bar", "chakra_bar", "portrait", "pips", "ability_0", "ability_1", "ability_2", "ability_3", "ability_4", "dpad"]
const ELEMENT_NAMES := {
	"hp_bar": "HP bar", "chakra_bar": "Chakra bar", "portrait": "Avatar", "pips": "Sub pips",
	"ability_0": "Substitution", "ability_1": "R2 + Sq", "ability_2": "R2 + Tri", "ability_3": "R2 + O", "ability_4": "R2 + X", "dpad": "D-pad items",
}
const ABILITY_LABELS: Array[String] = ["L2", "R2+Sq", "R2+Tri", "R2+O", "R2+X"]
const DPAD_CELL := 44.0  ## D-pad item cross (bottom-left): four 40px cells around a 3x3 grid, one per direction
const DPAD_ORIGIN := Vector2(28.0, 560.0)
const DPAD_CELLS := {"up": Vector2(1, 0), "left": Vector2(0, 1), "right": Vector2(2, 1), "down": Vector2(1, 2)}
const LAYOUT_PATH := "user://hud_layout.json"
const LOW_FRACTION := 0.3
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.9  ## fraction per second

var fraction: float = 1.0  ## shown HP fill, 0..1
var trail: float = 1.0
const HEAL_FILL_TIME := 0.25
const HEAL_FLASH_TIME := 0.22
var _heal_from := 0.0
var _heal_wait := 0.0  ## time until the fill starts (the gourd is still flying in)
var _heal_t := -1.0  ## 0..1 fill progress, -1 = idle
var _heal_flash := 0.0
var label_text: String = "HP 100 / 100"
var chakra_fraction: float = 1.0
var chakra_text: String = "Chakra 100 / 100"
var pips: int = 3
var max_pips: int = 3
var _hold: float = 0.0
var sub_progress: float = 1.0  ## 0..1: how far the soonest-recharging substitution charge has refilled (1 = nothing recharging)
var _player: PlayerController
var _flash: Array[float] = [0.0, 0.0, 0.0]
var use_age: Array[float] = [-1.0, -1.0, -1.0]  ## seconds since each pip's charge was spent (log wiggle + smoke); -1 = idle
var _canvas: Control
var _tex: Dictionary = {}
var offsets: Dictionary = {}  ## element id -> Vector2 shift from its default spot (saved to LAYOUT_PATH)
var edit_mode := false  ## true while the builder is open: pieces get outlines and can be picked and dragged
var selected_element := ""
var layout_path := LAYOUT_PATH  ## where drags are saved (tests point this elsewhere)
var _drag_grab := Vector2.ZERO
var dragging_element := false
const SNAPS: Array[int] = [8, 16, 32, 0]
var hud_snap: int = 8  ## builder drag grid in screen px (0 = free); hold Shift while dragging to bypass


func _ready() -> void:
	layer = 20
	for n: String in ["portrait_frame", "portrait_avatar", "bar_frame", "hp_fill", "chakra_fill", "pip_full", "pip_empty", "slot_frame", "slot_frame_gold", "slot_circle_gold", "chidori_icon", "log_icon", "log_icon_gray"]:
		_tex[n] = load(DIR + n + ".png") as Texture2D
	_canvas = Control.new()
	_canvas.name = "Bar"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_canvas.draw.connect(_draw_hud)
	_canvas.resized.connect(_redraw)
	load_layout()


func bind(player: PlayerController) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.chakra_changed.connect(_on_chakra_changed)
	player.substitution_changed.connect(_on_substitution_changed)
	player.inventory.changed.connect(_redraw)
	_on_health_changed(player.health, player.max_health)
	_on_chakra_changed(player.chakra, player.max_chakra)
	_on_substitution_changed(player.substitution_charges, player.max_substitution_charges)
	trail = fraction


func _on_health_changed(current: float, maximum: float) -> void:
	var f := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if f < fraction:
		_hold = TRAIL_DELAY
	fraction = f
	trail = maxf(trail, fraction) if f < trail else f
	label_text = "HP %d / %d" % [ceili(current), int(maximum)]
	_redraw()


## Gourd pickup: the true `fraction` is already restored; the drawn bar stays at `from_fraction`
## for `delay` seconds, then fills smoothly over HEAL_FILL_TIME with a green sweep and one flash.
func begin_heal_anim(from_fraction: float, delay: float) -> void:
	_heal_from = clampf(from_fraction, 0.0, 1.0)
	_heal_wait = maxf(delay, 0.0)
	_heal_t = 0.0
	_heal_flash = 0.0
	_redraw()


func heal_animating() -> bool:
	return _heal_t >= 0.0


## The fraction actually drawn for HP (equals `fraction` unless a heal animation is running).
func shown_fraction() -> float:
	if _heal_t < 0.0 or _heal_wait > 0.0:
		return _heal_from if _heal_t >= 0.0 else fraction
	var k := clampf(_heal_t, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	return lerpf(_heal_from, fraction, k)


func _on_chakra_changed(current: float, maximum: float) -> void:
	chakra_fraction = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	chakra_text = "Chakra %d / %d" % [ceili(current), int(maximum)]
	_redraw()


func _on_substitution_changed(charges: int, maximum: int) -> void:
	if charges > pips and charges >= 1 and charges <= _flash.size():
		_flash[charges - 1] = PIP_FLASH  ## a charge just refilled: its pip lights up
	if charges < pips:
		for i in range(maxi(charges, 0), mini(pips, use_age.size())):
			use_age[i] = 0.0  ## a charge was just spent: the log wiggles and pops in smoke
	pips = clampi(charges, 0, maximum)
	max_pips = maximum
	_redraw()


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	if _player != null:
		var p := _player.substitution_progress()
		if not is_equal_approx(p, sub_progress):
			sub_progress = p
			_redraw()
	for i in _flash.size():
		if _flash[i] > 0.0:
			_flash[i] = maxf(_flash[i] - delta, 0.0)
	for i in use_age.size():
		if use_age[i] >= 0.0:
			use_age[i] += delta
			if use_age[i] > LogPip.DURATION:
				use_age[i] = -1.0
			_redraw()
			_redraw()
	if _heal_t >= 0.0:
		if _heal_wait > 0.0:
			_heal_wait -= delta
		else:
			_heal_t += delta / HEAL_FILL_TIME
			if _heal_t >= 1.0:
				_heal_t = -1.0
				_heal_flash = HEAL_FLASH_TIME
		_redraw()
	elif _heal_flash > 0.0:
		_heal_flash = maxf(_heal_flash - delta, 0.0)
		_redraw()
	if trail > fraction:
		_hold -= delta
		if _hold <= 0.0:
			trail = maxf(fraction, trail - TRAIL_SPEED * delta)
			_redraw()


func fill_color() -> Color:
	return COL_LOW if fraction <= LOW_FRACTION else COL_FILL


func _draw_hud() -> void:
	# bars first: the portrait is drawn over their left ends
	var shown := shown_fraction()
	_bar("hp_bar", trail, shown, "hp_fill", fill_color(), label_text)
	_draw_heal_fx(shown)
	_bar("chakra_bar", chakra_fraction, chakra_fraction, "chakra_fill", COL_FILL, chakra_text)
	# portrait: dark backing diamond, the player's face clipped to the diamond opening, then the gold frame on top
	var o := pos_of("portrait")
	var back := PackedVector2Array([o + Vector2(48, 8), o + Vector2(88, 48), o + Vector2(48, 88), o + Vector2(8, 48)])
	_canvas.draw_colored_polygon(back, Color(0.09, 0.07, 0.06, 1.0))
	_canvas.draw_texture(_tex["portrait_frame"], o)
	# the avatar is drawn over the frame: free above the diamond's middle (head breaks out of the frame), clipped to the opening below
	var av_origin := o + AVATAR_POS
	var clip := PackedVector2Array([Vector2(8, -4), Vector2(88, -4), Vector2(88, 48), Vector2(80, 48), Vector2(52, 76), Vector2(44, 76), Vector2(16, 48), Vector2(8, 48)])
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in clip:
		pts.append(o + p)
		uvs.append((o + p - av_origin) / 80.0)
	_canvas.draw_colored_polygon(pts, Color.WHITE, uvs, _tex["portrait_avatar"])
	# substitution pips: the log art; spending a charge wiggles the log and pops it in smoke
	var pp := pos_of("pips")
	for i in max_pips:
		var at := pp + Vector2(PIP_STEP * i, 0.0)
		if i < _flash.size() and _flash[i] > 0.0:
			var k: float = _flash[i] / PIP_FLASH
			_canvas.draw_circle(at + PIP_SIZE * 0.5, PIP_SIZE.y * 0.5 + 3.0 + 6.0 * (1.0 - k), Color(0.45, 0.85, 1.0, 0.55 * k))
		LogPip.draw(_canvas, at, 1.0, i < pips, use_age[i] if i < use_age.size() else -1.0)
	_draw_abilities()
	_draw_dpad()
	if edit_mode:
		_draw_edit_outlines()


## Ability bar: slot 0 is Substitution Jutsu (log art). While a charge recharges the icon is grey and refills bottom to top.
## Slots 1-4 are gold circles for R2 + Square / Triangle / Circle / Cross; slot 1 carries the Chidori icon (art only, no gameplay yet).
func _draw_abilities() -> void:
	var font := ThemeDB.fallback_font
	for i in SLOT_COUNT:
		var pos := slot_pos(i)
		_canvas.draw_texture(_tex["slot_frame_gold" if i == 0 else "slot_circle_gold"], pos)
		var lab := pos + Vector2(0.0, SLOT_SIZE + 15.0)
		_canvas.draw_string_outline(font, lab, ABILITY_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE, 13, 3, Color(0, 0, 0, 0.9))
		_canvas.draw_string(font, lab, ABILITY_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE, 13, COL_TEXT)
	var chi: Texture2D = _tex["chidori_icon"]
	for k in PlayerInventory.JUTSU_SLOTS.size():
		# The R2 slots show whichever jutsu the Player Menu put on them (Chidori is the only one so far).
		if _player != null and _player.inventory.jutsu[PlayerInventory.JUTSU_SLOTS[k]] == "chidori":
			_canvas.draw_texture(chi, slot_pos(k + 1) + (Vector2(SLOT_SIZE, SLOT_SIZE) - chi.get_size()) * 0.5)
	var first := slot_pos(0)
	var icon: Texture2D = _tex["log_icon"]
	var isz := icon.get_size()
	var ipos := first + (Vector2(SLOT_SIZE, SLOT_SIZE) - isz) * 0.5
	if pips < max_pips:
		_canvas.draw_texture(_tex["log_icon_gray"], ipos)
		var top := roundf(isz.y * (1.0 - sub_progress))
		if sub_progress > 0.0 and top < isz.y:
			_canvas.draw_texture_rect_region(icon, Rect2(ipos + Vector2(0.0, top), Vector2(isz.x, isz.y - top)), Rect2(0.0, top, isz.x, isz.y - top))
	else:
		_canvas.draw_texture(icon, ipos)


## D-pad item cross: one cell per direction showing the item on that slot and how many are left.
func _draw_dpad() -> void:
	if _player == null:
		return
	var o := pos_of("dpad")
	var font := ThemeDB.fallback_font
	for slot: String in PlayerInventory.DPAD_SLOTS:
		var at := o + (DPAD_CELLS[slot] as Vector2) * DPAD_CELL
		var r := Rect2(at, Vector2(DPAD_CELL - 4.0, DPAD_CELL - 4.0))
		_canvas.draw_rect(r, Color(0.36, 0.31, 0.24, 0.9))
		_canvas.draw_rect(r, Color(0.86, 0.68, 0.25, 0.95), false, 2.0)
		var id := _player.inventory.slot_item(slot)
		var n := _player.inventory.count_of(id) if id != "" else 0
		var tex := PlayerInventory.icon(id) if id != "" else null
		if tex != null:
			var sz := tex.get_size()
			var k := minf(30.0 / maxf(sz.x, 1.0), 30.0 / maxf(sz.y, 1.0))
			var tint := Color.WHITE if n > 0 else Color(1, 1, 1, 0.3)
			_canvas.draw_texture_rect(tex, Rect2(r.position + (r.size - sz * k) * 0.5, sz * k), false, tint)
		if id != "":
			var txt := "x%d" % n
			var tp := r.position + Vector2(0.0, r.size.y - 2.0)
			_canvas.draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2.0, 12, 3, Color(0, 0, 0, 0.9))
			_canvas.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2.0, 12, COL_TEXT if n > 0 else Color(1, 0.5, 0.5, 0.9))
	_canvas.draw_circle(o + Vector2(1.5, 1.5) * DPAD_CELL - Vector2(2, 2), 5.0, Color(0.86, 0.68, 0.25, 0.8))


func _draw_heal_fx(shown: float) -> void:
	var inner := pos_of("hp_bar") + FILL_INSET
	if _heal_t >= 0.0 and _heal_wait <= 0.0 and fraction > _heal_from:
		# bright band over the newly restored stretch, with a sweeping highlight riding its leading edge
		var x0 := FILL_SIZE.x * _heal_from
		var x1 := FILL_SIZE.x * shown
		_canvas.draw_rect(Rect2(inner + Vector2(x0, 0), Vector2(maxf(x1 - x0, 0.0), FILL_SIZE.y)), Color(0.7, 1.0, 0.75, 0.45))
		_canvas.draw_rect(Rect2(inner + Vector2(maxf(x1 - 14.0, x0), 0), Vector2(14.0, FILL_SIZE.y)), Color(0.9, 1.0, 0.92, 0.8))
	if _heal_flash > 0.0:
		var a := _heal_flash / HEAL_FLASH_TIME
		_canvas.draw_rect(Rect2(inner, Vector2(FILL_SIZE.x * shown, FILL_SIZE.y)), Color(0.8, 1.0, 0.85, 0.55 * a))


func _bar(id: String, trail_f: float, fill_f: float, fill_tex: String, tint: Color, text: String) -> void:
	var pos := pos_of(id)
	_canvas.draw_texture(_tex["bar_frame"], pos)
	var inner := pos + FILL_INSET
	if trail_f > fill_f:
		_canvas.draw_rect(Rect2(inner, Vector2(FILL_SIZE.x * trail_f, FILL_SIZE.y)), COL_TRAIL)
	if fill_f > 0.0:
		var src := Rect2(0.0, 0.0, FILL_SIZE.x * fill_f, FILL_SIZE.y)
		_canvas.draw_texture_rect_region(_tex[fill_tex], Rect2(inner, src.size), src, tint)
	var font := ThemeDB.fallback_font
	var at := pos + Vector2(BAR_TUCK, BAR_SIZE.y * 0.5 + 5.0)
	_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x - BAR_TUCK, 12, 3, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x - BAR_TUCK, 12, COL_TEXT)


# ------------------------------------------------------------------ movable layout (builder)
## Default top-left of an element before any saved offset is applied.
func base_pos(id: String) -> Vector2:
	match id:
		"hp_bar":
			return Vector2(BAR_X, HP_Y)
		"chakra_bar":
			return Vector2(BAR_X, CHAKRA_Y)
		"portrait":
			return ORIGIN
		"pips":
			return PIP_POS
		"dpad":
			return DPAD_ORIGIN
	var i := int(id.trim_prefix("ability_"))
	var total := SLOT_SIZE * SLOT_COUNT + SLOT_GAP * (SLOT_COUNT - 1)
	var w := _canvas.size.x if _canvas != null and _canvas.size.x > 0.0 else 1280.0
	return Vector2((w - total) * 0.5 + (SLOT_SIZE + SLOT_GAP) * i, SLOT_Y)


func pos_of(id: String) -> Vector2:
	return base_pos(id) + (offsets.get(id, Vector2.ZERO) as Vector2)


func slot_pos(i: int) -> Vector2:
	return pos_of("ability_%d" % i)


## Screen-space box of an element (what you click to pick it up).
func element_rect(id: String) -> Rect2:
	var p := pos_of(id)
	match id:
		"hp_bar", "chakra_bar":
			return Rect2(p, BAR_SIZE)
		"portrait":
			return Rect2(p + Vector2(0.0, AVATAR_POS.y), Vector2(PORTRAIT_SIZE.x, PORTRAIT_SIZE.y - AVATAR_POS.y))
		"pips":
			return Rect2(p, Vector2(PIP_STEP * (max_pips - 1) + PIP_SIZE.x, PIP_SIZE.y))
		"dpad":
			return Rect2(p, Vector2(DPAD_CELL * 3.0 - 4.0, DPAD_CELL * 3.0 - 4.0))
	return Rect2(p, Vector2(SLOT_SIZE, SLOT_SIZE + 20.0))


## The topmost element under a screen point ("" when none).
func element_at(point: Vector2) -> String:
	for k in range(ELEMENTS.size() - 1, -1, -1):
		if element_rect(ELEMENTS[k]).has_point(point):
			return ELEMENTS[k]
	return ""


func select_element(id: String) -> void:
	selected_element = id
	_redraw()


func set_edit_mode(on: bool) -> void:
	edit_mode = on
	if not on:
		selected_element = ""
		dragging_element = false
	_redraw()


func move_element(id: String, delta: Vector2) -> void:
	set_piece_offset(id, (offsets.get(id, Vector2.ZERO) as Vector2) + delta)


func set_piece_offset(id: String, v: Vector2) -> void:
	if v.round() == Vector2.ZERO:
		offsets.erase(id)
	else:
		offsets[id] = v.round()
	_redraw()


## Mouse press in edit mode: picks the element under the cursor and starts a drag. Returns true when it grabbed one.
func press_at(point: Vector2) -> bool:
	var id := element_at(point)
	if id == "":
		return false
	selected_element = id
	dragging_element = true
	_drag_grab = point - pos_of(id)
	_redraw()
	return true


func drag_at(point: Vector2, snap_on: bool = true) -> void:
	if dragging_element and selected_element != "":
		var target := point - _drag_grab
		if snap_on and hud_snap > 0:
			target = (target / float(hud_snap)).round() * float(hud_snap)
		# keep the piece on screen so it can never be lost off an edge
		if _canvas != null and _canvas.size.x > 0.0:
			var r := element_rect(selected_element)
			target.x = clampf(target.x, 0.0, maxf(_canvas.size.x - r.size.x, 0.0))
			target.y = clampf(target.y, 0.0, maxf(_canvas.size.y - r.size.y, 0.0))
		set_piece_offset(selected_element, target - base_pos(selected_element))


func cycle_snap() -> void:
	hud_snap = SNAPS[(SNAPS.find(hud_snap) + 1) % SNAPS.size()]
	_redraw()


## The four R2 pieces (ability_1..4) as one group.
func r2_ids() -> Array[String]:
	return ["ability_1", "ability_2", "ability_3", "ability_4"]


func r2_bounds() -> Rect2:
	var r := element_rect("ability_1")
	for id in r2_ids():
		r = r.merge(element_rect(id))
	return r


## Slide the whole R2 cluster (shape kept) to the right edge of the screen.
func r2_to_right_edge(margin: float = 24.0) -> void:
	var w := _canvas.size.x if _canvas != null and _canvas.size.x > 0.0 else 1280.0
	var dx := (w - margin) - r2_bounds().end.x
	for id in r2_ids():
		move_element(id, Vector2(dx, 0.0))
	save_layout()


## Put the Substitution slot on the same horizontal line as the R2 cluster (centres level), same slot size.
func align_substitution_with_r2() -> void:
	var cy := r2_bounds().get_center().y
	var sub := element_rect("ability_0")
	move_element("ability_0", Vector2(0.0, cy - sub.get_center().y))
	save_layout()


func release_drag() -> void:
	if dragging_element:
		dragging_element = false
		save_layout()


func reset_layout() -> void:
	offsets.clear()
	save_layout()
	_redraw()


func layout_json() -> String:
	var d := {}
	for id: String in offsets:
		var v: Vector2 = offsets[id]
		d[id] = [v.x, v.y]
	return JSON.stringify(d)


func apply_layout_json(text: String) -> void:
	offsets.clear()
	var d: Variant = JSON.parse_string(text)
	if d is Dictionary:
		for id: String in d:
			var a: Variant = d[id]
			if id in ELEMENTS and a is Array and a.size() == 2:
				offsets[id] = Vector2(float(a[0]), float(a[1]))
	_redraw()


func save_layout(path := "") -> bool:
	if path == "":
		path = layout_path
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(layout_json())
	return true


func load_layout(path := "") -> void:
	if path == "":
		path = layout_path
	if FileAccess.file_exists(path):
		apply_layout_json(FileAccess.get_file_as_string(path))


func _draw_edit_outlines() -> void:
	# No screen-wide snap grid and no boxes around idle pieces (builder opens clean); only the picked piece is outlined.
	for id in ELEMENTS:
		var r := element_rect(id).grow(2.0)
		var sel := id == selected_element
		if not sel:
			continue
		_canvas.draw_rect(r, Color(1.0, 0.42, 0.0, 0.9), false, 2.0)
		if sel:
			_canvas.draw_string_outline(ThemeDB.fallback_font, r.position + Vector2(2.0, -4.0), ELEMENT_NAMES[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.9))
			_canvas.draw_string(ThemeDB.fallback_font, r.position + Vector2(2.0, -4.0), ELEMENT_NAMES[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.6, 0.2))
