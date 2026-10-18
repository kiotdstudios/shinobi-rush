class_name DebugStore
extends RefCounted
## Pure-logic debug event store used by BrowserDebug (own buffer, works without DebugTelemetry).
## No network calls, no persistence: everything lives in memory and is gone on refresh.
## Time is injectable (now_ms arguments) so tests are deterministic.

const SCHEMA := 1
## Rolling buffer defaults (all bounds apply at once).
const DEFAULT_MAX_EVENTS := 5000
const DEFAULT_MAX_BYTES := 2 * 1024 * 1024  ## approx: JSON text length + newline per event
const DEFAULT_WINDOW_MS := 10 * 60 * 1000
## Types that are coalesced when identical (message + source + line + col).
const COALESCE_TYPES: Array[String] = ["error", "warning", "browser_error"]
## Token buckets per type: burst capacity and refill per second. "_default" applies to other types.
const RATE_LIMITS := {
	"browser_error": {"burst": 10.0, "per_sec": 2.0},
	"error": {"burst": 20.0, "per_sec": 5.0},
	"warning": {"burst": 20.0, "per_sec": 5.0},
	"_default": {"burst": 200.0, "per_sec": 200.0},
}
## Axis / motion throttles: record only on meaningful change.
const AXIS_MIN_DELTA := 0.1
const AXIS_DEADZONE := 0.05
const MOTION_MIN_DIST := 8.0
const MOTION_MIN_INTERVAL_MS := 50
const CORE_KEYS: Array[String] = ["t_ms", "utc", "session", "build", "frame", "type"]

var enabled: bool = false
var max_events: int = DEFAULT_MAX_EVENTS
var max_bytes: int = DEFAULT_MAX_BYTES
var window_ms: int = DEFAULT_WINDOW_MS

var session: String = ""
var build: Dictionary = {}  ## {commit_sha, run_id, godot, page_url}
var env: Dictionary = {}  ## userAgent, platform, language, screen, ...
var start_unix: float = 0.0

## dropped: counters by reason. Coalesced duplicates are counted separately (they are kept as counts).
var dropped: Dictionary = {"total": 0, "rate_limited": 0, "throttled": 0, "evicted_count": 0, "evicted_bytes": 0, "evicted_window": 0, "oversize": 0, "disabled": 0}
var coalesced: int = 0

var _buf: Array = []  ## entries: {"e": Dictionary, "b": int, "k": String}
var _bytes: int = 0
var _ck: Dictionary = {}  ## coalesce key -> entry in _buf
var _buckets: Dictionary = {}  ## type -> {"tokens": float, "last": int}
var _axis_last: Dictionary = {}  ## key -> float
var _motion_last: Dictionary = {}  ## key -> {"pos": Vector2, "t": int}
var _frame: int = 0


func configure(p_session: String, p_build: Dictionary, p_env: Dictionary, p_start_unix: float) -> void:
	session = p_session
	build = p_build.duplicate(true)
	env = p_env.duplicate(true)
	start_unix = p_start_unix


func set_frame(f: int) -> void:
	_frame = f


func size() -> int:
	return _buf.size()


func bytes() -> int:
	return _bytes


func clear() -> void:
	_buf.clear()
	_ck.clear()
	_bytes = 0


## Record one event. Returns true if it was stored (or coalesced into an existing one).
## data keys that collide with core keys are ignored. Strings are sanitized.
func record(type: String, data: Dictionary = {}, now_ms: int = 0) -> bool:
	if not enabled:
		dropped["disabled"] += 1  # cheap diagnostic only; not part of "total"
		return false
	if not _take_token(type, now_ms):
		_drop("rate_limited")
		return false
	var e := {"t_ms": now_ms, "utc": _utc(now_ms), "session": session, "build": String(build.get("commit_sha", "")), "frame": _frame, "type": type}
	for k: String in data:
		if k in CORE_KEYS:
			continue
		e[k] = _clean(k, data[k])
	var ck := _coalesce_key(type, e)
	if ck != "" and _ck.has(ck):
		var entry: Dictionary = _ck[ck]
		var ex: Dictionary = entry["e"]
		ex["count"] = int(ex.get("count", 1)) + 1
		ex["last_t_ms"] = now_ms
		coalesced += 1
		return true
	var b := JSON.stringify(e).length() + 1
	if b > max_bytes:
		_drop("oversize")
		return false
	var entry2 := {"e": e, "b": b, "k": ck}
	_buf.append(entry2)
	_bytes += b
	if ck != "":
		_ck[ck] = entry2
	prune(now_ms)
	return true


## Axis event only when the value changed meaningfully (delta, deadzone crossing, sign flip).
func record_axis(key: String, value: float, extra: Dictionary = {}, now_ms: int = 0) -> bool:
	var v := 0.0 if absf(value) < AXIS_DEADZONE else value
	var last: float = _axis_last.get(key, 0.0)
	var crossing := (v == 0.0) != (last == 0.0) or (v * last < 0.0)
	if not crossing and absf(v - last) < AXIS_MIN_DELTA:
		_drop("throttled")
		return false
	_axis_last[key] = v
	var d := extra.duplicate()
	d["control"] = key
	d["value"] = snappedf(v, 0.01)
	return record("input", d, now_ms)


## Pointer motion only after moving MOTION_MIN_DIST px and MOTION_MIN_INTERVAL_MS.
func record_motion(key: String, pos: Vector2, extra: Dictionary = {}, now_ms: int = 0) -> bool:
	if _motion_last.has(key):
		var m: Dictionary = _motion_last[key]
		if now_ms - int(m["t"]) < MOTION_MIN_INTERVAL_MS or pos.distance_to(m["pos"]) < MOTION_MIN_DIST:
			_drop("throttled")
			return false
	_motion_last[key] = {"pos": pos, "t": now_ms}
	var d := extra.duplicate()
	d["control"] = key
	d["x"] = snappedf(pos.x, 0.1)
	d["y"] = snappedf(pos.y, 0.1)
	return record("input", d, now_ms)


## Evict by time window, then count, then bytes (oldest first). Dropped counters are updated.
func prune(now_ms: int) -> void:
	while _buf.size() > 0 and now_ms - int(_buf[0]["e"]["t_ms"]) > window_ms:
		_evict("evicted_window")
	while _buf.size() > max_events:
		_evict("evicted_count")
	while _buf.size() > 0 and _bytes > max_bytes:
		_evict("evicted_bytes")


func events() -> Array:
	var out: Array = []
	for en: Dictionary in _buf:
		out.append((en["e"] as Dictionary).duplicate(true))
	return out


func recent(n: int) -> Array:
	var all := events()
	return all.slice(maxi(0, all.size() - n))


func last_of_type(type: String) -> Dictionary:
	for i in range(_buf.size() - 1, -1, -1):
		if _buf[i]["e"]["type"] == type:
			return (_buf[i]["e"] as Dictionary).duplicate(true)
	return {}


## Session header (first JSONL line). Dropped counters are as of now.
func header(now_ms: int = 0) -> Dictionary:
	return {
		"type": "session_header", "schema": SCHEMA, "session": session, "utc_start": _iso(start_unix),
		"t_ms": now_ms, "build": build.duplicate(true), "env": env.duplicate(true),
		"limits": {"max_events": max_events, "max_bytes": max_bytes, "window_ms": window_ms},
		"dropped": dropped.duplicate(), "coalesced": coalesced, "events": _buf.size(), "bytes": _bytes,
	}


## JSONL: header line first, then one event per line (ordered by t_ms), trailing newline.
func export_jsonl(now_ms: int = 0, extra_events: Array = []) -> String:
	var evs := merge_by_time(events(), extra_events) if extra_events.size() > 0 else events()
	var lines: Array[String] = [JSON.stringify(header(now_ms))]
	for e: Dictionary in evs:
		lines.append(JSON.stringify(e))
	return "\n".join(lines) + "\n"


## Stable merge of two t_ms-ordered arrays (ties: a before b).
static func merge_by_time(a: Array, b: Array) -> Array:
	var out: Array = []
	var i := 0
	var j := 0
	while i < a.size() and j < b.size():
		if int(b[j].get("t_ms", 0)) < int(a[i].get("t_ms", 0)):
			out.append(b[j])
			j += 1
		else:
			out.append(a[i])
			i += 1
	out.append_array(a.slice(i))
	out.append_array(b.slice(j))
	return out


# ------------------------------------------------------------------ internals
func _drop(reason: String) -> void:
	dropped[reason] += 1
	dropped["total"] += 1


func _evict(reason: String) -> void:
	var en: Dictionary = _buf.pop_front()
	_bytes -= int(en["b"])
	if String(en["k"]) != "" and _ck.get(en["k"]) == en:
		_ck.erase(en["k"])
	_drop(reason)


func _take_token(type: String, now_ms: int) -> bool:
	var cfg: Dictionary = RATE_LIMITS.get(type, RATE_LIMITS["_default"])
	var bk: Dictionary = _buckets.get(type, {"tokens": float(cfg["burst"]), "last": now_ms})
	var elapsed := maxf(0.0, float(now_ms - int(bk["last"])) / 1000.0)
	bk["tokens"] = minf(float(cfg["burst"]), float(bk["tokens"]) + elapsed * float(cfg["per_sec"]))
	bk["last"] = now_ms
	var ok := float(bk["tokens"]) >= 1.0
	if ok:
		bk["tokens"] = float(bk["tokens"]) - 1.0
	_buckets[type] = bk
	return ok


func _coalesce_key(type: String, e: Dictionary) -> String:
	if not (type in COALESCE_TYPES):
		return ""
	return "%s|%s|%s|%s|%s" % [type, e.get("message", ""), e.get("source", ""), e.get("line", ""), e.get("col", "")]


func _clean(key: String, v: Variant) -> Variant:
	if v is String:
		if key == "stack":
			return DebugSanitizer.sanitize_stack(v)
		if key == "source":
			return DebugSanitizer.basename(v)
		return DebugSanitizer.sanitize_text(v)
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[k] = _clean(str(k), v[k])
		return d
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_clean(key, x))
		return a
	return v


func _utc(now_ms: int) -> String:
	return _iso(start_unix + float(now_ms) / 1000.0)


static func _iso(unix: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(unix)) + "Z"
