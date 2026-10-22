class_name CameraPreset
extends RefCounted
## ONE place for the gameplay camera BASELINE zoom (pure static functions plus one "active preset" slot).
##
## Presets only set the baseline. Anything dynamic (a combat camera director, shake, look-ahead) must add
## RELATIVE offsets/zoom on top of the baseline and never write an absolute zoom.
##
##   wide   zoom 0.5000: the prototype arena view. DEFAULT, unchanged.
##   close  PROVISIONAL close-combat target from the owner-approved reference (PR #19): the standing figure
##          fills CLOSE_FIGURE_FRACTION of the viewport height. The zoom is COMPUTED from the figure height,
##          not a magic number. Opt-in until the owner approves a numeric zoom in the engine.
##   <n>    a plain number (clamped to MIN_ZOOM..MAX_ZOOM), for owner experiments (?camera=1.5).
##
## Select with the page URL `?camera=wide|close|<number>` (web only, see WebBridge) or the lab key N.

const WIDE := "wide"
const CLOSE := "close"
const CUSTOM := "custom"  ## id reported for a numeric preset
const DEFAULT_ID := WIDE
## Table of named presets in lab cycling order. `wide` is a fixed zoom; `close` is computed (see close_zoom).
const IDS: Array[String] = [WIDE, CLOSE]
const TABLE: Dictionary = {
	WIDE: {"label": "wide", "zoom": WorldScale.CAMERA_BASE_ZOOM},
	CLOSE: {"label": "close", "zoom": null},
}

## PROVISIONAL: middle of the 16-19 % band from docs/visuals/CAMERA_AND_ART_DIRECTION.md (head to feet).
const CLOSE_FIGURE_FRACTION := 0.175
## PROVISIONAL band the standing figure should occupy at normal gameplay zoom (fraction of viewport height).
const BAND_MIN_FRACTION := 0.16
const BAND_MAX_FRACTION := 0.19
## Pixel-exact zoom for nearest-neighbour art; used by `close` when it already lands inside the band.
const SNAP_ZOOM := 1.0
const SNAP_EPSILON := 1e-9
## Sane range for any zoom coming from a URL or a figure height.
const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0
const QUERY_KEY := "camera"
const FALLBACK_VIEWPORT_HEIGHT := 720.0

## The single active preset: a String id ("wide"/"close") or a float zoom. null = not chosen yet (default).
static var _active: Variant = null


# ---------------------------------------------------------------- active preset

static func active() -> Variant:
	return DEFAULT_ID if _active == null else _active


## Accepts an id or a number; anything else becomes the default. Returns the normalised value.
static func set_active(spec: Variant) -> Variant:
	_active = normalize(spec)
	return _active


## "wide", "close", or "custom" for a numeric preset (the exact number is in the published zoom).
static func active_id() -> String:
	return id_of(active())


# ---------------------------------------------------------------- pure functions

## id string stays an id; a number becomes a clamped float; unknown/garbage/non-positive -> DEFAULT_ID.
static func normalize(spec: Variant) -> Variant:
	if typeof(spec) == TYPE_STRING or typeof(spec) == TYPE_STRING_NAME:
		var s := String(spec).strip_edges().to_lower()
		return s if IDS.has(s) else DEFAULT_ID
	if typeof(spec) == TYPE_FLOAT or typeof(spec) == TYPE_INT:
		var f := float(spec)
		if is_finite(f) and f > 0.0:
			return clampf(f, MIN_ZOOM, MAX_ZOOM)
	return DEFAULT_ID


static func id_of(spec: Variant) -> String:
	var n: Variant = normalize(spec)
	return String(n) if typeof(n) == TYPE_STRING else CUSTOM


## Base viewport height from the project settings (720), the reference for the close fraction.
static func base_viewport_height() -> float:
	return float(ProjectSettings.get_setting("display/window/size/viewport_height", FALLBACK_VIEWPORT_HEIGHT))


## Figure height in world px: the loaded sprite set's manifest `body_height_px`, else the placeholder.
static func figure_height_px(set_ref: SpriteSet) -> float:
	if set_ref != null and set_ref.is_valid() and set_ref.body_height_px > 0.0:
		return set_ref.body_height_px
	return WorldScale.BODY_HEIGHT


## Fraction of the viewport height a figure of `figure_px` world px covers at `zoom`.
static func figure_fraction(figure_px: float, zoom: float, viewport_h: float = -1.0) -> float:
	var vh := viewport_h if viewport_h > 0.0 else base_viewport_height()
	return figure_px * zoom / vh


static func in_band(fraction: float) -> bool:
	return fraction >= BAND_MIN_FRACTION - SNAP_EPSILON and fraction <= BAND_MAX_FRACTION + SNAP_EPSILON


## PROVISIONAL close zoom: CLOSE_FIGURE_FRACTION x viewport height / figure height, except that exactly
## SNAP_ZOOM (1.0, pixel-exact) wins when it already keeps the figure inside the band. Clamped to MIN..MAX.
static func close_zoom(figure_px: float, viewport_h: float = -1.0) -> float:
	var fig := figure_px if figure_px > 0.0 else WorldScale.BODY_HEIGHT
	var vh := viewport_h if viewport_h > 0.0 else base_viewport_height()
	if in_band(figure_fraction(fig, SNAP_ZOOM, vh)):
		return SNAP_ZOOM
	return clampf(CLOSE_FIGURE_FRACTION * vh / fig, MIN_ZOOM, MAX_ZOOM)


## Baseline zoom for an id or a number. `figure_px` only matters for `close`.
static func zoom_for(spec: Variant, figure_px: float = WorldScale.BODY_HEIGHT, viewport_h: float = -1.0) -> float:
	var n: Variant = normalize(spec)
	if typeof(n) == TYPE_FLOAT:
		return n
	if n == CLOSE:
		return close_zoom(figure_px, viewport_h)
	return float(TABLE[WIDE]["zoom"])


## Label used by the lab and reports: "wide 0.50x", "close 1.17x", "custom 2.00x".
static func label_for(spec: Variant, zoom: float) -> String:
	return "%s %.2fx" % [id_of(spec), zoom]


## Next named preset after `spec` (a numeric preset continues with the first named one).
static func next_id(spec: Variant) -> String:
	var n: Variant = normalize(spec)
	var i := IDS.find(n) if typeof(n) == TYPE_STRING else -1
	return IDS[(i + 1) % IDS.size()]


## Query string ("?a=1&camera=close") -> an id or a clamped float. First `camera=` wins (like URLSearchParams.get).
## Missing, empty, unknown, non-numeric, non-finite, zero or negative values -> DEFAULT_ID.
static func parse_query(query: String) -> Variant:
	for part in query.trim_prefix("?").split("&", false):
		var eq := part.find("=")
		var key := part if eq < 0 else part.substr(0, eq)
		if key.uri_decode() != QUERY_KEY:
			continue
		var value := "" if eq < 0 else part.substr(eq + 1).uri_decode().strip_edges().to_lower()
		if IDS.has(value):
			return value
		# Plain decimals only: no exponent form (1e999 would make the engine print "Exponent too high").
		if value.is_valid_float() and not value.contains("e"):
			return normalize(value.to_float())
		return DEFAULT_ID
	return DEFAULT_ID


## Numbers for reports: figure px on screen, fraction of the viewport height, whether it is inside the
## PROVISIONAL band, and the visible world size at this zoom.
static func metrics(zoom: float, figure_px: float, viewport: Vector2 = Vector2(-1, -1)) -> Dictionary:
	var vp := viewport if viewport.x > 0.0 and viewport.y > 0.0 else Vector2(1280.0, base_viewport_height())
	var fraction := figure_px * zoom / vp.y
	return {
		"zoom": zoom, "figure_world_px": figure_px, "figure_screen_px": figure_px * zoom,
		"fraction": fraction, "in_band": in_band(fraction),
		"view_w": vp.x / zoom, "view_h": vp.y / zoom,
	}


## World rectangle visible at `zoom` when the camera centre is `center`.
static func visible_world_rect(zoom: float, center: Vector2 = Vector2.ZERO, viewport: Vector2 = Vector2(-1, -1)) -> Rect2:
	var m := metrics(zoom, WorldScale.BODY_HEIGHT, viewport)
	var size := Vector2(m["view_w"], m["view_h"])
	return Rect2(center - size * 0.5, size)
