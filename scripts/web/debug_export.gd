class_name DebugExport
extends RefCounted
## Pure shaping of debug exports (JSONL is built by DebugStore/BrowserDebug; this adds the readable TXT
## and the filename). No I/O, no network, no persistence.


## UTC filename stamp + short SHA, e.g. shinobi-debug-20261018-120000-abcdef1.jsonl
static func filename(start_unix: float, sha: String, ext: String = "jsonl") -> String:
	var ts := Time.get_datetime_string_from_unix_time(int(start_unix)).replace("-", "").replace(":", "").replace("T", "-")
	var short := sha.substr(0, 7)
	return "shinobi-debug-%s-%s.%s" % [ts, short if short != "" else "unknown", ext]


## Human readable companion to the JSONL: header block, then one line per event.
static func to_txt(header: Dictionary, events: Array) -> String:
	var lines: Array[String] = ["SHINOBI RUSH DEBUG LOG", "======================"]
	lines.append("session: %s" % header.get("session", ""))
	lines.append("started: %s" % header.get("utc_start", header.get("utc", "")))
	var build: Variant = header.get("build", {})
	if build is Dictionary:
		for k: String in build:
			lines.append("build.%s: %s" % [k, build[k]])
	var env: Variant = header.get("env", {})
	if env is Dictionary:
		for k: String in env:
			lines.append("env.%s: %s" % [k, JSON.stringify(env[k])])
	var dropped: Variant = header.get("dropped", {})
	if dropped is Dictionary:
		lines.append("dropped: %s" % JSON.stringify(dropped))
	lines.append("events: %d" % events.size())
	lines.append("")
	for e: Dictionary in events:
		var rest := e.duplicate()
		for k: String in DebugStore.CORE_KEYS:
			rest.erase(k)
		lines.append("[%8d ms] f%-6d %-16s %s" % [int(e.get("t_ms", 0)), int(e.get("frame", 0)), String(e.get("type", "")), JSON.stringify(rest) if not rest.is_empty() else ""])
	return "\n".join(lines) + "\n"
