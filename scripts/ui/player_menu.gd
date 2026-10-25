class_name PlayerMenu
extends CanvasLayer
## The Player Menu: opened with the controller's large black button (PlayStation touchpad; keyboard I), pauses the game.
## Two tabs for now:
##   Inventory -- pick an item (Cross), then press the D-pad direction you want it on (arrow keys on a keyboard).
##   Jutsu     -- pick a jutsu (Cross), then press the face button of the R2 slot you want it on (R2 + that button in play).
## It only edits `player.inventory` (PlayerInventory); the HUD and the D-pad / R2 inputs read from there.
## Everything is polled in _process (works while the tree is paused) so analog sticks and held buttons never double-fire.

const TABS: Array[String] = ["Inventory", "Jutsu"]
const COL_GOLD := Color(0.86, 0.68, 0.25, 1.0)
const COL_TEXT := Color(1, 1, 1, 0.95)
const COL_DIM := Color(1, 1, 1, 0.5)
const PANEL := Rect2(260, 120, 760, 480)
const JUTSU_FACE := {"square": "Square", "triangle": "Triangle", "circle": "Circle", "cross": "Cross"}
## Face-button joypad indices (Godot layout): 0 Cross, 1 Circle, 2 Square, 3 Triangle. Keyboard 1-4 mirror them.
const FACE_BUTTONS := {2: "square", 3: "triangle", 1: "circle", 0: "cross"}
const FACE_KEYS := {KEY_1: "square", KEY_2: "triangle", KEY_3: "circle", KEY_4: "cross"}

static var any_open := false  ## true while some menu is open (the debug HUD's Esc pause steps aside)

var is_open := false
var tab := 0
var cursor := 0
var placing := false  ## an entry is picked and waits for a D-pad direction / face button
var _player: PlayerController
var _canvas: Control
var _held: Dictionary = {}  ## polled input name -> was down last frame


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.name = "Menu"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_canvas.draw.connect(_draw_menu)


func bind(player: PlayerController) -> void:
	_player = player
	player.inventory.changed.connect(_redraw)


func _exit_tree() -> void:
	if is_open:
		any_open = false


func entries() -> Array[String]:
	var list: Array[String] = []
	if tab == 0:
		list.append_array(["health_gourd", "chakra_gourd", "kunai", "paper_tag", "tag_bomb", "smoke_tag_bomb", ""])
	else:
		list.append_array(["chidori", ""])
	return list


func open() -> void:
	if is_open or _player == null or get_tree().paused:
		return
	is_open = true
	any_open = true
	tab = 0
	cursor = 0
	placing = false
	visible = true
	get_tree().paused = true
	_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	any_open = false
	placing = false
	visible = false
	get_tree().paused = false
	if _player != null:
		_player.inventory.save()


func switch_tab(step: int) -> void:
	tab = posmod(tab + step, TABS.size())
	cursor = 0
	placing = false
	_redraw()


func move_cursor(step: int) -> void:
	var n := entries().size()
	cursor = posmod(cursor + step, n)
	_redraw()


## Cross / Enter: pick the highlighted entry so the next slot press places it.
func accept() -> void:
	placing = true
	_redraw()


## Circle / Esc: drop a picked entry; with nothing picked, close the menu.
func cancel() -> void:
	if placing:
		placing = false
		_redraw()
	else:
		close()


func place_item_on(slot: String) -> void:
	if tab == 0 and placing:
		_player.inventory.assign_item(slot, entries()[cursor])
		placing = false
		_redraw()


func place_jutsu_on(slot: String) -> void:
	if tab == 1 and placing:
		_player.inventory.assign_jutsu(slot, entries()[cursor])
		placing = false
		_redraw()


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


# ------------------------------------------------------------------ input (polled)
func _edge(name: String, down: bool) -> bool:
	var was: bool = _held.get(name, false)
	_held[name] = down
	return down and not was


func _pad_down(idx: int) -> bool:
	for d: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d, idx as JoyButton):
			return true
	return false


func _process(_delta: float) -> void:
	if _player == null:
		return
	if _edge("menu", Input.is_action_pressed("player_menu")):
		if is_open:
			close()
		else:
			open()
		return
	if not is_open:
		# keep edge state fresh so a button held while opening does not fire the moment it opens
		for n: String in ["up", "down", "left", "right", "accept", "cancel", "pause", "l1", "r1", "q", "e"]:
			_held[n] = true
		for k: Variant in FACE_BUTTONS.keys():
			_held["pad%d" % int(k)] = true
		for k: Variant in FACE_KEYS.keys():
			_held["key%d" % int(k)] = true
		return
	var up := _edge("up", Input.is_action_pressed("ui_up"))
	var down := _edge("down", Input.is_action_pressed("ui_down"))
	var left := _edge("left", Input.is_action_pressed("ui_left"))
	var right := _edge("right", Input.is_action_pressed("ui_right"))
	var accept := _edge("accept", Input.is_action_pressed("ui_accept"))
	var cancel_pressed := _edge("cancel", Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("pause"))
	var l1 := _edge("l1", _pad_down(JOY_BUTTON_LEFT_SHOULDER) or Input.is_physical_key_pressed(KEY_Q))
	var r1 := _edge("r1", _pad_down(JOY_BUTTON_RIGHT_SHOULDER) or Input.is_physical_key_pressed(KEY_E))
	var face: Array[String] = []
	for k: Variant in FACE_BUTTONS.keys():
		if _edge("pad%d" % int(k), _pad_down(int(k))):
			face.append(String(FACE_BUTTONS[k]))
	for k: Variant in FACE_KEYS.keys():
		if _edge("key%d" % int(k), Input.is_physical_key_pressed(int(k) as Key)):
			face.append(String(FACE_KEYS[k]))
	if l1:
		switch_tab(-1)
		return
	if r1:
		switch_tab(1)
		return
	if placing:
		if tab == 0:
			for s: String in PlayerInventory.DPAD_SLOTS:
				if _edge("slot_" + s, Input.is_action_pressed("slot_" + s)):
					place_item_on(s)
					return
		else:
			for s: String in face:
				place_jutsu_on(s)
				return
		if cancel_pressed:
			cancel()
		return
	for s: String in PlayerInventory.DPAD_SLOTS:
		_edge("slot_" + s, true)  # swallow: the arrows only navigate until an entry is picked
	if cancel_pressed:
		cancel()
	elif up:
		move_cursor(-1)
	elif down:
		move_cursor(1)
	elif left:
		switch_tab(-1)
	elif right:
		switch_tab(1)
	elif accept:
		accept()


# ------------------------------------------------------------------ drawing
func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_canvas.draw_string_outline(font, pos, s, align, w, size, 3, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, pos, s, align, w, size, col)


func _draw_menu() -> void:
	if not is_open or _player == null:
		return
	var inv := _player.inventory
	var font := ThemeDB.fallback_font
	var vp := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.62))
	var off := ((vp - Vector2(1280, 720)) * 0.5).floor()
	var panel := Rect2(PANEL.position + off, PANEL.size)
	_canvas.draw_rect(panel, Color(0.06, 0.05, 0.04, 0.96))
	_canvas.draw_rect(panel, COL_GOLD, false, 3.0)
	# tabs
	for i in TABS.size():
		var tr := Rect2(panel.position + Vector2(24 + i * 190, 18), Vector2(176, 38))
		var sel := i == tab
		_canvas.draw_rect(tr, Color(0.86, 0.68, 0.25, 0.28) if sel else Color(1, 1, 1, 0.05))
		_canvas.draw_rect(tr, COL_GOLD if sel else Color(1, 1, 1, 0.2), false, 2.0)
		_text(font, tr.position + Vector2(0, 26), TABS[i], 20, COL_TEXT if sel else COL_DIM, tr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, panel.position + Vector2(panel.size.x - 150, 44), "L1 / R1 tabs", 13, COL_DIM, 130.0, HORIZONTAL_ALIGNMENT_RIGHT)
	# list
	var list := entries()
	var list_pos := panel.position + Vector2(24, 84)
	var row_height := 46.0 if list.size() > 5 else 62.0
	for i in list.size():
		var id := list[i]
		var row := Rect2(list_pos + Vector2(0, i * row_height), Vector2(330, row_height - 6))
		var on := i == cursor
		_canvas.draw_rect(row, Color(0.86, 0.68, 0.25, 0.22) if on else Color(1, 1, 1, 0.04))
		_canvas.draw_rect(row, (COL_TEXT if placing and on else COL_GOLD) if on else Color(1, 1, 1, 0.15), false, 2.0)
		if tab == 0:
			var tex := PlayerInventory.icon(id) if id != "" else null
			if tex != null:
				var k := minf(minf(40.0,row_height-14) / tex.get_width(), minf(40.0,row_height-14) / tex.get_height())
				_canvas.draw_texture_rect(tex, Rect2(row.position + Vector2(8, 8) + (Vector2(minf(40,row_height-14), minf(40,row_height-14)) - tex.get_size() * k) * 0.5, tex.get_size() * k), false)
			var nm: String = String(PlayerInventory.ITEMS[id].name) if id != "" else "(empty slot)"
			_text(font, row.position + Vector2(60, minf(34,row_height-14)), nm, 18, COL_TEXT if id == "" or inv.count_of(id) > 0 else COL_DIM)
			if id != "":
				_text(font, row.position + Vector2(0, minf(34,row_height-14)), "x%d" % inv.count_of(id), 18, COL_TEXT, row.size.x - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			var nm2: String = String(PlayerInventory.JUTSU[id].name) if id != "" else "(empty slot)"
			_text(font, row.position + Vector2(16, 34), nm2, 18, COL_TEXT)
			if id != "" and not bool(PlayerInventory.JUTSU[id].ready):
				_text(font, row.position + Vector2(0, minf(34,row_height-14)), "not playable yet", 13, COL_DIM, row.size.x - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
	# description
	var cur := list[cursor] if cursor < list.size() else ""
	var desc := ""
	if tab == 0 and cur != "":
		desc = String(PlayerInventory.ITEMS[cur].desc)
	elif tab == 1 and cur == "chidori":
		desc = "Lightning fist strike (coming soon)."
	elif cur == "":
		desc = "Empties the slot you place it on."
	_text(font, list_pos + Vector2(0, list.size() * row_height + 8), desc, 14, COL_DIM, 340.0)
	# slots
	var cx := panel.position + Vector2(panel.size.x * 0.72, 270)
	var cell := 96.0
	if tab == 0:
		_text(font, cx + Vector2(-110, -160), "D-pad slots", 18, COL_GOLD, 220.0, HORIZONTAL_ALIGNMENT_CENTER)
		var offs := {"up": Vector2(0, -1), "right": Vector2(1, 0), "down": Vector2(0, 1), "left": Vector2(-1, 0)}
		for s: String in PlayerInventory.DPAD_SLOTS:
			_slot_cell(font, cx + (offs[s] as Vector2) * (cell + 8.0) - Vector2(cell, cell) * 0.5, cell, inv.slot_item(s), s.capitalize(), inv.slot_count(s), placing)
	else:
		_text(font, cx + Vector2(-110, -160), "R2 + button slots", 18, COL_GOLD, 220.0, HORIZONTAL_ALIGNMENT_CENTER)
		var offs2 := {"triangle": Vector2(0, -1), "circle": Vector2(1, 0), "cross": Vector2(0, 1), "square": Vector2(-1, 0)}
		for s: String in PlayerInventory.JUTSU_SLOTS:
			var jid: String = inv.jutsu[s]
			_slot_cell(font, cx + (offs2[s] as Vector2) * (cell + 8.0) - Vector2(cell, cell) * 0.5, cell, "", String(JUTSU_FACE[s]), 0, placing, String(PlayerInventory.JUTSU[jid].name) if jid != "" else "")
	# footer
	var hint := "Up / Down choose   Cross pick   Circle / Menu button close"
	if placing:
		hint = ("Press the D-pad direction to put it on   Circle cancel" if tab == 0 else "Press Square / Triangle / Circle / Cross to put it on   Menu button cancels")
	_text(font, panel.position + Vector2(0, panel.size.y - 18), hint, 14, COL_DIM, panel.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _slot_cell(font: Font, at: Vector2, size: float, item_id: String, label: String, count: int, hot: bool, text: String = "") -> void:
	var r := Rect2(at, Vector2(size, size))
	_canvas.draw_rect(r, Color(0.36, 0.31, 0.24, 0.95))
	_canvas.draw_rect(r, COL_TEXT if hot else COL_GOLD, false, 3.0 if hot else 2.0)
	_text(font, at + Vector2(0, 16), label, 13, COL_DIM, size, HORIZONTAL_ALIGNMENT_CENTER)
	if item_id != "":
		var tex := PlayerInventory.icon(item_id)
		if tex != null:
			var k := minf(46.0 / tex.get_width(), 46.0 / tex.get_height())
			_canvas.draw_texture_rect(tex, Rect2(at + (r.size - tex.get_size() * k) * 0.5 + Vector2(0, 4), tex.get_size() * k), false)
		_text(font, at + Vector2(0, size - 6), "x%d" % count, 13, COL_TEXT, size - 6.0, HORIZONTAL_ALIGNMENT_RIGHT)
	elif text != "":
		_text(font, at + Vector2(0, size * 0.58), text, 16, COL_TEXT, size, HORIZONTAL_ALIGNMENT_CENTER)
