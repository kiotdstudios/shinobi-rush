extends Node
## Autoload BrowserDebug: opt-in browser-side debug layer (contract: docs/development/DEBUG_LOG_INTERFACE.md).
##
## HOW THE FLAG IS DECIDED (OFF by default, in debug AND release builds):
##   - Web: ON only when the page URL has the query parameter debug=1 (e.g. /index.html?debug=1).
##   - Native/editor: ON only when the user argument --debug-log is passed (godot ... -- --debug-log).
##   - At runtime the action dbg_toggle_debug (F9) toggles it. dbg_download_log (F7) and dbg_copy_report (F8)
##     export / copy, and only work while enabled. Nothing else enables it; there is no build-type switch.
##
## While OFF: no JS listeners, no console wrapping, nothing recorded.
## While ON: window "error" / "unhandledrejection" listeners and console.error / console.warn wrappers
## (the original console behavior is kept) forward through JavaScriptBridge callbacks as event type
## "browser_error". Not captured: engine errors that never reach the console or window.
##
## PRIVACY: no network calls, no persistence (no localStorage / IndexedDB / cookies). Data stays in memory
## until the user explicitly downloads or copies it. build-info.json is NOT fetched (that would be a request);
## build info comes from res://build-info.json if shipped, or window.__SHINOBI_BUILD_INFO__ if the page defines it.

signal debug_toggled(on: bool)
## Emitted by copy_bug_report so a panel can show a read-only fallback if the clipboard is refused.
signal report_ready(text: String)

const REPORT_EVENTS := 100
const NOTE_MAX := 500
const ACT_TOGGLE := "dbg_toggle_debug"
const ACT_DOWNLOAD := "dbg_download_log"
const ACT_COPY := "dbg_copy_report"

const _JS_INSTALL := """
(function () {
  if (window.__SHINOBI_DEBUG_HOOKS__) { return; }
  var busy = false;
  function send(kind, msg, src, line, col, stack) {
    if (busy) { return; }
    var f = window.__SHINOBI_DEBUG_CB__;
    if (!f) { return; }
    busy = true;
    try { f(kind, String(msg), String(src || ''), Number(line) || 0, Number(col) || 0, String(stack || '')); } catch (e) {}
    busy = false;
  }
  function onError(ev) {
    var e = ev && ev.error;
    send('error', (ev && ev.message) || (e && e.message) || 'error', ev && ev.filename, ev && ev.lineno, ev && ev.colno, e && e.stack);
  }
  function onRejection(ev) {
    var r = ev && ev.reason;
    send('unhandledrejection', (r && r.message) || r || 'unhandled rejection', '', 0, 0, r && r.stack);
  }
  window.addEventListener('error', onError);
  window.addEventListener('unhandledrejection', onRejection);
  var oe = console.error, ow = console.warn;
  console.error = function () { try { send('console.error', Array.prototype.map.call(arguments, String).join(' ')); } catch (e) {} return oe.apply(console, arguments); };
  console.warn = function () { try { send('console.warn', Array.prototype.map.call(arguments, String).join(' ')); } catch (e) {} return ow.apply(console, arguments); };
  window.__SHINOBI_DEBUG_HOOKS__ = { off: function () {
    window.removeEventListener('error', onError);
    window.removeEventListener('unhandledrejection', onRejection);
    console.error = oe; console.warn = ow;
    delete window.__SHINOBI_DEBUG_HOOKS__;
  } };
})();
"""
const _JS_UNINSTALL := "if (window.__SHINOBI_DEBUG_HOOKS__) { window.__SHINOBI_DEBUG_HOOKS__.off(); }"
const _JS_META := """
JSON.stringify({
  userAgent: navigator.userAgent, platform: navigator.platform, language: navigator.language,
  screen: { width: screen.width, height: screen.height }, devicePixelRatio: window.devicePixelRatio,
  hardwareConcurrency: navigator.hardwareConcurrency || 0,
  gamepads: (navigator.getGamepads ? Array.prototype.filter.call(navigator.getGamepads(), Boolean).map(function (g) { return g.id; }) : []),
  page_url: location.href, search: location.search,
  build: (window.__SHINOBI_BUILD_INFO__ || null)
})
"""

var enabled: bool = false
var session_id: String = ""
var store: DebugStore = DebugStore.new()
## Test hook: when set, used instead of /root/DebugTelemetry.
var telemetry_override: Node = null
## Test hook: replaces the session clock (milliseconds since session start).
var clock: Callable = Callable()

var _start_ticks: int = 0
var _is_web: bool = false
var _window: JavaScriptObject
var _cb: JavaScriptObject  ## keep a reference or the callback is freed
var _in_cb: bool = false


func _ready() -> void:
	_is_web = OS.has_feature("web")
	var env := {}
	var build := _local_build_info()
	var search := ""
	if _is_web:
		_window = JavaScriptBridge.get_interface("window")
		var meta: Variant = JSON.parse_string(str(JavaScriptBridge.eval(_JS_META, true)))
		if meta is Dictionary:
			env = collect_env(meta)
			search = String(meta.get("search", ""))
			if meta.get("build") is Dictionary:
				build.merge(meta["build"], true)
			build["page_url"] = DebugSanitizer.sanitize_url(String(meta.get("page_url", "")))
	init_session(env, build)
	if decide_enabled(_is_web, search, OS.get_cmdline_user_args()):
		set_enabled(true)


## Pure decision of the opt-in flag. Anything but an explicit opt-in is OFF.
static func decide_enabled(is_web: bool, query: String, user_args: PackedStringArray) -> bool:
	if is_web:
		var q := query.trim_prefix("?")
		for part in q.split("&", false):
			if part == "debug=1":
				return true
		return false
	return "--debug-log" in user_args


## Keep only the documented browser metadata keys.
static func collect_env(meta: Dictionary) -> Dictionary:
	var out := {}
	for k: String in ["userAgent", "platform", "language", "screen", "devicePixelRatio", "gamepads", "hardwareConcurrency"]:
		if meta.has(k):
			out[k] = meta[k]
	return out


func init_session(env: Dictionary, build: Dictionary) -> void:
	_start_ticks = Time.get_ticks_msec()
	session_id = Crypto.new().generate_random_bytes(6).hex_encode()
	var b := build.duplicate(true)
	for k: String in ["commit_sha", "run_id", "godot", "page_url"]:
		if not b.has(k):
			b[k] = ""
	if String(b["godot"]) == "":
		b["godot"] = Engine.get_version_info().get("string", "")
	store.configure(session_id, b, env, Time.get_unix_time_from_system())


func now_ms() -> int:
	if clock.is_valid():
		return int(clock.call())
	return Time.get_ticks_msec() - _start_ticks


func set_enabled(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	store.enabled = on
	var t := _telemetry()
	if t != null:
		t.set("enabled", on)
	if _is_web:
		if on:
			_install_js()
		else:
			JavaScriptBridge.eval(_JS_UNINSTALL, true)
	if on:
		record("state", {"event": "debug_on"})
	debug_toggled.emit(on)


## Kiro-owned events (go to DebugStore). Producers use DebugTelemetry.record instead.
func record(type: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	store.set_frame(Engine.get_process_frames())
	store.record(type, data, now_ms())


## Merged view (DebugTelemetry first on ties, then own events), ordered by t_ms.
func recent(n: int = REPORT_EVENTS) -> Array:
	var all := _merged()
	return all.slice(maxi(0, all.size() - n))


func export_jsonl() -> String:
	var lines: Array[String] = [JSON.stringify(store.header(now_ms()))]
	for e: Dictionary in _merged():
		lines.append(JSON.stringify(e))
	return "\n".join(lines) + "\n"


func bug_report(note: String = "") -> String:
	var evs := recent(REPORT_EVENTS)
	var last_err: Dictionary = {}
	for i in range(evs.size() - 1, -1, -1):
		if evs[i].get("type", "") in ["browser_error", "error"]:
			last_err = evs[i]
			break
	var lines: Array[String] = ["SHINOBI RUSH BUG REPORT", JSON.stringify(store.header(now_ms()))]
	if note.strip_edges() != "":
		lines.append("NOTE: " + DebugSanitizer.sanitize_text(note.substr(0, NOTE_MAX)))
	lines.append("LAST ERROR: " + (JSON.stringify(last_err) if not last_err.is_empty() else "none"))
	lines.append("LAST %d EVENTS:" % evs.size())
	for e: Dictionary in evs:
		lines.append(JSON.stringify(e))
	return "\n".join(lines) + "\n"


## Explicit user action only (called from the dbg_download_log action or a panel button).
func download_log() -> bool:
	if not enabled or not _is_web:
		return false
	var buf := export_jsonl().to_utf8_buffer()
	JavaScriptBridge.download_buffer(buf, log_filename(), "application/x-ndjson")
	return true


## Explicit user action only. Returns the text so a panel can show a fallback if the clipboard is refused.
func copy_bug_report(note: String = "") -> String:
	if not enabled:
		return ""
	var text := bug_report(note)
	DisplayServer.clipboard_set(text)
	report_ready.emit(text)
	return text


func log_filename() -> String:
	var ts := Time.get_datetime_string_from_unix_time(int(store.start_unix)).replace("-", "").replace(":", "").replace("T", "-")
	var sha := String(store.build.get("commit_sha", "")).substr(0, 7)
	return "shinobi-debug-%s-%s.jsonl" % [ts, sha if sha != "" else "unknown"]


## args from JS: [kind, message, source, line, col, stack]
func _on_js_event(args: Array) -> void:
	if _in_cb or not enabled or args.size() < 6:
		return
	_in_cb = true
	record_browser_error(String(args[0]), String(args[1]), String(args[2]), int(args[3]), int(args[4]), String(args[5]))
	_in_cb = false


func record_browser_error(kind: String, message: String, source: String, line: int, col: int, stack: String) -> void:
	record("browser_error", {"kind": kind, "message": message, "source": source, "line": line, "col": col, "stack": stack})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACT_TOGGLE):
		set_enabled(not enabled)
	elif enabled and event.is_action_pressed(ACT_DOWNLOAD):
		download_log()
	elif enabled and event.is_action_pressed(ACT_COPY):
		copy_bug_report()


func _install_js() -> void:
	_cb = JavaScriptBridge.create_callback(_on_js_event)
	_window.__SHINOBI_DEBUG_CB__ = _cb
	JavaScriptBridge.eval(_JS_INSTALL, true)


func _telemetry() -> Node:
	if telemetry_override != null:
		return telemetry_override
	if is_inside_tree():
		return get_node_or_null("/root/DebugTelemetry")
	return null


func _merged() -> Array:
	var own := store.events()
	var t := _telemetry()
	if t == null or not t.has_method("recent"):
		return own
	var theirs: Array = t.call("recent", store.max_events)
	return DebugStore.merge_by_time(theirs, own)


func _local_build_info() -> Dictionary:
	if FileAccess.file_exists("res://build-info.json"):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build-info.json"))
		if j is Dictionary:
			return {"commit_sha": str(j.get("commit_sha", "")), "run_id": str(j.get("run_id", "")), "godot": str(j.get("godot_version", ""))}
	return {}
