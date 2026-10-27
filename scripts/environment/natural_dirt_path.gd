class_name NaturalDirtPath
extends RefCounted
## Presentation only: keep authored floor IDs, navigation and editor save format.
## Apply only to matching authored material/position; custom painting wins.
const DIR := "res://assets/environment/blightwood/brown_dirt_path/"
static var enabled := true
static var _entries: Dictionary = {}
static var _atlas: Texture2D
static var _loaded := false
static var _cache: Dictionary = {}
static var _configured := false

static func texture_for(id: String, pos: Vector2) -> Texture2D:
	if not _configured:
		var query := str(JavaScriptBridge.eval("window.location.search",true)) if OS.has_feature("web") else ""
		enabled = not ("path_before=1" in query or "--path-before" in OS.get_cmdline_user_args())
		_configured = true
	if not enabled:return null
	var terrain := "d" if id.begins_with("ground9_") else "g" if id.begins_with("grass9_") else ""
	if terrain.is_empty():return null
	if not _loaded:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"natural-path.json"))
		for entry: Dictionary in data.entries:
			_entries[Vector2(entry.x,entry.y)] = entry
		_atlas = load(DIR+"natural-path-atlas.png") as Texture2D
		_loaded = true
	if not _entries.has(pos):return null
	var entry: Dictionary = _entries[pos]
	if entry.terrain != terrain:return null
	var index := int(entry.index)
	if not _cache.has(index):
		var tile := AtlasTexture.new()
		tile.atlas = _atlas
		tile.region = Rect2((index%32)*112,(index/32)*112,112,112)
		_cache[index] = tile
	return _cache[index]

static func apply(sprite: Sprite2D, id: String, pos: Vector2) -> void:
	var texture := texture_for(id,pos)
	if texture == null:return
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -Vector2(56,84)
	# The cut diamonds must stay registered; tall grass keeps its normal wind.
	sprite.material = null

