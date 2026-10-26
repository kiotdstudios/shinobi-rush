class_name SpawnMarker
extends Sprite2D
## The builder's "player spawn" icon: an orange ring with a down-arrow, shown only while the builder is open.
## Drag it like any other piece; the player starts (and respawns) where its foot ring sits.

const SIZE := Vector2i(96, 128)
const FOOT := Vector2(48, 118)
const ORANGE := Color("#ff6b00")

## Set by WorldEditor.set_open(): the marker is a builder tool, never part of the played level.
static var shown := true
static var _icon: ImageTexture


static func icon() -> ImageTexture:
	if _icon != null:
		return _icon
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var ring_c := Vector2(48, 112)
	for y in SIZE.y:
		for x in SIZE.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := Vector2((p.x - ring_c.x) / 40.0, (p.y - ring_c.y) / 16.0).length()
			if d <= 1.0 and d >= 0.78:
				img.set_pixel(x, y, ORANGE)
			elif d < 0.78 and d >= 0.70:
				img.set_pixel(x, y, Color(1, 1, 1, 0.9))
			elif d < 0.70:
				img.set_pixel(x, y, Color(1.0, 0.42, 0.0, 0.22))
			# down arrow: shaft + head, tip resting in the ring
			var in_shaft := absf(p.x - 48.0) <= 7.0 and p.y >= 40.0 and p.y <= 72.0
			var head_w := (96.0 - p.y) * 0.55  # widest at y=72, zero at the tip y=96
			var in_head := p.y > 72.0 and p.y <= 96.0 and absf(p.x - 48.0) <= head_w
			if in_shaft or in_head:
				var edge := absf(p.x - 48.0) > (6.0 if in_shaft else head_w - 2.5) or p.y < 41.5 or (in_head and p.y > 94.0)
				img.set_pixel(x, y, Color.WHITE if edge else ORANGE)
	_icon = ImageTexture.create_from_image(img)
	return _icon


func _init() -> void:
	name = "PlayerSpawnMarker"
	texture = icon()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	offset = -FOOT
	z_index = 150


func _process(_d: float) -> void:
	visible = shown
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var bob := sin(Time.get_ticks_msec() / 260.0) * 3.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	draw_string(font, Vector2(-44, -88), "PLAYER SPAWN", HORIZONTAL_ALIGNMENT_CENTER, 88.0, 12, Color.WHITE)
