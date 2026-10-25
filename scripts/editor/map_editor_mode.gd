class_name MapEditorMode
extends RefCounted
## The "Shinobi Rush Map Editor" page: the same game build, opened with the builder up front.
## It is switched on by (any of): the exported editor.html (it sets window.SHINOBI_MAP_EDITOR before the engine
## starts), a `?map_editor=1` query on any page, a `--map-editor` command-line flag, or `forced` (tests).

static var forced := false


static func active() -> bool:
	if forced or "--map-editor" in OS.get_cmdline_args() or "--map-editor" in OS.get_cmdline_user_args():
		return true
	if OS.has_feature("web"):
		var hit: Variant = JavaScriptBridge.eval("(function(){try{return !!window.SHINOBI_MAP_EDITOR||/[?&]map_editor=1/.test(window.location.search)}catch(e){return false}})()", true)
		return bool(hit)
	return false


## Opens `url` (relative to the current page) in a new browser tab. Web only; returns whether it tried.
static func open_page(url: String) -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval("window.open(" + JSON.stringify(url) + ",'_blank')", true)
	return true


## The public game page: no World Builder and no Settings (owner 2026-10-25). Web only; the editor page, `?editor=1` and `?settings=1` show them.
static func public_game() -> bool:
	if not OS.has_feature("web") or active():
		return false
	var q := str(JavaScriptBridge.eval("window.location.search", true))
	return not ("editor=1" in q or "settings=1" in q)
