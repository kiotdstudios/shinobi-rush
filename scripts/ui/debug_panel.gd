extends CanvasLayer
## Opt-in debug panel: DEBUG ON indicator + session id, Download Debug Log, Copy Bug Report, tester note.
## Shown only while BrowserDebug is enabled. Buttons are the explicit user gesture for export / clipboard.
## The note is read from the field ONLY when Copy is pressed; typed content is never recorded as events.

var debug: Node  ## BrowserDebug (injected for tests; defaults to /root/BrowserDebug)

var indicator: Label
var download_button: Button
var txt_button: Button
var copy_button: Button
var note_field: LineEdit
var status: Label
var fallback: TextEdit


func _ready() -> void:
	layer = 100
	if debug == null:
		debug = get_node_or_null("/root/BrowserDebug")
	_build()
	if debug == null:
		visible = false
		return
	debug.debug_toggled.connect(_on_toggled)
	debug.clipboard_done.connect(_on_clipboard_done)
	debug.report_ready.connect(_on_report_ready)
	_on_toggled(debug.enabled)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	indicator = Label.new()
	indicator.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	box.add_child(indicator)
	var row := HBoxContainer.new()
	box.add_child(row)
	download_button = _button("Download Debug Log", row, _on_download)
	txt_button = _button("TXT", row, _on_download_txt)
	copy_button = _button("Copy Bug Report", row, _on_copy)
	note_field = LineEdit.new()
	note_field.placeholder_text = "Optional tester note"
	note_field.max_length = 500
	note_field.custom_minimum_size = Vector2(320, 0)
	box.add_child(note_field)
	status = Label.new()
	box.add_child(status)
	fallback = TextEdit.new()
	fallback.editable = false
	fallback.custom_minimum_size = Vector2(320, 120)
	fallback.visible = false
	box.add_child(fallback)


func _button(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func indicator_text(session_id: String) -> String:
	return "DEBUG ON  session %s" % session_id


func _on_toggled(on: bool) -> void:
	visible = on
	if on:
		indicator.text = indicator_text(String(debug.session_id))
	else:
		fallback.visible = false
		status.text = ""


func _on_download() -> void:
	status.text = "Log downloaded." if debug.download_log() else "Download is only available in the browser build."


func _on_download_txt() -> void:
	status.text = "TXT downloaded." if debug.download_txt() else "Download is only available in the browser build."


func _on_copy() -> void:
	status.text = "Copying..."
	debug.copy_bug_report(note_field.text)


func _on_report_ready(text: String) -> void:
	fallback.text = text


func _on_clipboard_done(ok: bool) -> void:
	fallback.visible = not ok
	status.text = "Bug report copied." if ok else "Copy was refused. Select the text below and copy it manually."
