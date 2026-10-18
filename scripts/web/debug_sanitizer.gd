class_name DebugSanitizer
extends RefCounted
## Pure string sanitizer for debug-log text (messages, URLs, stacks).
## No network, no persistence. Strips query/hash from URLs, maps local user paths to <local>,
## redacts token-like strings and caps length / frame count.

const MAX_TEXT := 500
const MAX_STACK_FRAMES := 12
const MAX_STACK_LINE := 300
const MAX_STACK_TOTAL := 2000
const REDACTED := "<redacted>"
const LOCAL := "<local>"

static var _re_url: RegEx
static var _re_file_user: RegEx
static var _re_path_win: RegEx
static var _re_path_unix: RegEx
static var _re_prefixed: RegEx
static var _re_bearer: RegEx
static var _re_hex: RegEx
static var _re_b64: RegEx


static func _init_regex() -> void:
	if _re_url != null:
		return
	_re_url = _rx("(?:https?|file)://[^\\s)'\"\\]>]+")
	_re_file_user = _rx("(?i)file:///[A-Za-z]:/Users/[^/\\s]+")
	_re_path_win = _rx("(?i)[A-Za-z]:[\\\\/]+Users[\\\\/]+[^\\\\/\\s]+")
	_re_path_unix = _rx("(?:/Users|/home)/[^/\\s]+")
	_re_prefixed = _rx("(?:ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{10,}|AKIA[0-9A-Z]{12,}")
	_re_bearer = _rx("(?i)\\bBearer\\s+[A-Za-z0-9._~+/=-]+")
	_re_hex = _rx("\\b[0-9a-fA-F]{32,}\\b")
	_re_b64 = _rx("[A-Za-z0-9+/_-]{40,}={0,2}")


static func _rx(p: String) -> RegEx:
	var r := RegEx.new()
	r.compile(p)
	return r


## Truncate to n characters, marking the cut.
static func cap(s: String, n: int) -> String:
	if s.length() <= n:
		return s
	return s.substr(0, n) + "...[truncated]"


## Drop ?query and #hash and map file:///C:/Users/<name> to <local>.
static func sanitize_url(url: String) -> String:
	_init_regex()
	var s := url
	var cut := s.find("#")
	if cut >= 0:
		s = s.substr(0, cut)
	cut = s.find("?")
	if cut >= 0:
		s = s.substr(0, cut)
	return _re_file_user.sub(s, LOCAL, true)


## Basename of a (sanitized) source URL or path.
static func basename(url: String) -> String:
	var s := sanitize_url(url)
	var i := maxi(s.rfind("/"), s.rfind("\\"))
	return s.substr(i + 1) if i >= 0 else s


static func _looks_like_secret_b64(m: String) -> bool:
	# Avoid redacting ordinary long paths/identifiers: need upper, lower and a digit.
	var up := false
	var lo := false
	var dg := false
	for i in m.length():
		var c := m.unicode_at(i)
		if c >= 65 and c <= 90:
			up = true
		elif c >= 97 and c <= 122:
			lo = true
		elif c >= 48 and c <= 57:
			dg = true
	return up and lo and dg


static func _sub_matches(re: RegEx, s: String, fn: Callable) -> String:
	var out := ""
	var pos := 0
	for m: RegExMatch in re.search_all(s):
		out += s.substr(pos, m.get_start() - pos) + String(fn.call(m.get_string()))
		pos = m.get_end()
	return out + s.substr(pos)


## Redact token-like strings only (no URL/path handling).
static func redact_tokens(s: String) -> String:
	_init_regex()
	var out := _re_prefixed.sub(s, REDACTED, true)
	out = _re_bearer.sub(out, "Bearer " + REDACTED, true)
	out = _re_hex.sub(out, REDACTED, true)
	out = _sub_matches(_re_b64, out, func(m: String) -> String: return REDACTED if _looks_like_secret_b64(m) else m)
	return out


## Full text sanitizer: URLs, local paths, tokens, then length cap.
static func sanitize_text(s: String, max_len: int = MAX_TEXT) -> String:
	_init_regex()
	var out := _sub_matches(_re_url, s, func(m: String) -> String: return sanitize_url(m))
	out = _re_path_win.sub(out, LOCAL, true)
	out = _re_path_unix.sub(out, LOCAL, true)
	out = redact_tokens(out)
	return cap(out, max_len)


## Sanitize a stack trace: first max_frames lines, each sanitized and capped, total capped.
static func sanitize_stack(stack: String, max_frames: int = MAX_STACK_FRAMES, max_total: int = MAX_STACK_TOTAL) -> String:
	var lines := stack.replace("\r", "").split("\n", false)
	var out: Array[String] = []
	for i in mini(lines.size(), max_frames):
		out.append(sanitize_text(String(lines[i]).strip_edges(), MAX_STACK_LINE))
	var res := "\n".join(out)
	if lines.size() > max_frames:
		res += "\n...[%d more frames]" % (lines.size() - max_frames)
	return cap(res, max_total)
