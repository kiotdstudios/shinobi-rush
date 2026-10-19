extends CanvasLayer
## Compact on-screen debug HUD for DebugTelemetry (Aki). Spawned by DebugTelemetry itself once enabled
## is true (mirrors how Kiro's debug_panel.gd is spawned by BrowserDebug). Shows recent events, last
## input / mapped action, player state and the error count, with a type filter and a verbosity toggle.
##
## Placement: bottom band (y 260-640) so it never overlaps Kiro's panel (top-right, y>=40) or the
## existing DebugHud / legend (top-left block + bottom legend strip, see scripts/ui/debug_hud.gd).
##
## Keys (telemetry already ON via F9 / ?debug=1):
##   Ctrl+Alt+H  toggle this HUD's visibility
##   Ctrl+Alt+G  cycle the type filter: ALL -> input -> interaction -> combat -> error -> ALL
##   Ctrl+Alt+B  cycle verbosity: COMPACT (last line per field) <-> VERBOSE (last N raw JSON lines)

const REFRESH := 0.1
const VERBOSE_LINES := 8
const FILTERS: Array[String] = ["ALL", "input", "interaction", "combat", "error"]

var telemetry: Node  ## DebugTelemetry (injected for tests; defaults to /root/DebugTelemetry)

var _filter_index: int = 0
var _verbose: bool = false
var _timer: float = 0.0
var _title: Label
var _status: Label
var _events: Label
var _back: ColorRect


func _ready() -> void:
	layer = 90
	if telemetry == null:
		telemetry = get_node_or_null("/root/DebugTelemetry")
	_build()
	visible = telemetry != null and bool(telemetry.get("enabled"))


func _build() -> void:
	_back = ColorRect.new()
	_back.position = Vector2(6, 262)
	_back.size = Vector2(500, 360)
	_back.color = Color(0, 0, 0, 0.5)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_title = _label(Vector2(12, 266), 13)
	_status = _label(Vector2(12, 284), 12)
	_events = _label(Vector2(12, 302), 11)


func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


var _user_hidden: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dbg_toggle_telemetry_hud"):
		visible = not visible
		_user_hidden = not visible
	elif event.is_action_pressed("dbg_telemetry_filter_cycle"):
		_filter_index = (_filter_index + 1) % FILTERS.size()
	elif event.is_action_pressed("dbg_telemetry_verbosity_cycle"):
		_verbose = not _verbose
	elif event.is_action_pressed("dbg_force_test_error") and telemetry != null and telemetry.has_method("force_test_error"):
		telemetry.call("force_test_error")


func _process(delta: float) -> void:
	if telemetry == null:
		telemetry = get_node_or_null("/root/DebugTelemetry")
		if telemetry == null:
			return
	var on := bool(telemetry.get("enabled"))
	if not on:
		visible = false
		return
	if not visible and not _user_hidden:
		visible = true
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_refresh()


func _refresh() -> void:
	var filt: String = FILTERS[_filter_index]
	_title.text = "TELEMETRY HUD  filter=%s  verbosity=%s  (Ctrl+Alt+H hide, Ctrl+Alt+G filter, Ctrl+Alt+B verbosity, Ctrl+Alt+X test error)" % [filt, "VERBOSE" if _verbose else "COMPACT"]
	var evs: Array = telemetry.call("recent", 200)
	if filt != "ALL":
		evs = evs.filter(func(e: Dictionary) -> bool: return String(e.get("type", "")) == filt)
	var err_count: int = int(telemetry.get("error_count"))
	var last_input := ""
	var last_action := ""
	for i in range(evs.size() - 1, -1, -1):
		var e: Dictionary = evs[i]
		if last_input == "" and String(e.get("type", "")) == "input":
			last_input = "%s raw=%s" % [e.get("device", ""), JSON.stringify(e.get("raw", {}))]
		if last_action == "" and String(e.get("action", "")) != "":
			last_action = String(e.get("action", ""))
		if last_input != "" and last_action != "":
			break
	var player: Dictionary = telemetry.call("player_snapshot") if telemetry.has_method("player_snapshot") else {}
	_status.text = "last input: %s\nlast action: %s\nplayer: %s\nerrors: %d  events(%s): %d" % [
		last_input if last_input != "" else "none", last_action if last_action != "" else "none",
		(JSON.stringify(player) if not player.is_empty() else "unknown"), err_count, filt, evs.size(),
	]
	var tail := evs.slice(maxi(0, evs.size() - VERBOSE_LINES))
	if _verbose:
		var lines: Array[String] = []
		for e: Dictionary in tail:
			lines.append(JSON.stringify(e))
		_events.text = "\n".join(lines)
	else:
		var lines2: Array[String] = []
		for e: Dictionary in tail:
			lines2.append("[%6d] %-11s %s" % [int(e.get("t_ms", 0)), String(e.get("type", "")), String(e.get("action", e.get("category", "")))])
		_events.text = "\n".join(lines2)
