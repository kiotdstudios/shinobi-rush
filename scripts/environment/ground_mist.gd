class_name GroundMist
extends Node2D
## Presentation only: low ribbons at real tree / shrine anchors. No collision or actor writes.
const ART := "res://assets/environment/blightwood_mist/wisps.png"
const CAPACITY := 48
var auto_advance := true
var enabled := true
var clock := 0.0
var actor: Node2D
var sources: Array[Node2D] = []
var ribbons: Array[Sprite2D] = []
var _scan := 0.0
var _state: JavaScriptObject

func _ready() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in CAPACITY:
		var sprite := Sprite2D.new()
		sprite.texture = load(ART) as Texture2D
		sprite.hframes = 4
		sprite.vframes = 4
		sprite.frame = (i * 7) % 16
		var wind := ShaderMaterial.new()
		wind.shader = load("res://scripts/environment/ground_mist.gdshader") as Shader
		wind.set_shader_parameter("phase", float(i) * 2.39996)
		sprite.material = wind
		sprite.scale = Vector2(1.45 + float(i % 3) * 0.2, 1.0)
		sprite.offset = Vector2(0, -10)
		sprite.visible = false
		sprite.modulate = Color(1, 1, 1, 0)
		add_child(sprite)
		ribbons.append(sprite)
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		if "mist=inspect" in query:
			_state = JavaScriptBridge.create_object("Object")
			JavaScriptBridge.get_interface("window").__GROUND_MIST__ = _state

func _process(delta: float) -> void:
	if not auto_advance:return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 2.0
		actor = get_tree().get_first_node_in_group("player") as Node2D
		scan_sources(get_parent())
	advance(delta)
	if _state != null:
		_state.ready = true
		_state.clock = clock
		_state.sources = sources.size()
		_state.visible = visible_count()
		_state.capacity = ribbons.size()

func scan_sources(host: Node) -> void:
	var found: Array[Node2D] = []
	_collect(host, found)
	if is_instance_valid(actor):
		found.sort_custom(func(a: Node2D, b: Node2D): return a.global_position.distance_squared_to(actor.global_position) < b.global_position.distance_squared_to(actor.global_position))
	if found.size() > CAPACITY / 2:found.resize(CAPACITY / 2)
	set_sources(found)

func set_sources(found: Array[Node2D]) -> void:
	# Keep each surviving tree in its original slot: nearest-distance rank changes must not teleport ribbons.
	for i in sources.size():
		if not is_instance_valid(sources[i]) or not found.has(sources[i]):sources[i] = null
	for source in found:
		if sources.has(source):continue
		var vacant := sources.find(null)
		if vacant >= 0:sources[vacant] = source
		elif sources.size() < CAPACITY / 2:sources.append(source)
	while not sources.is_empty() and sources.back() == null:sources.pop_back()

func _collect(host: Node, found: Array[Node2D]) -> void:
	if host == self or host.is_queued_for_deletion():return
	if host is BlossomTree or host is DynamicShrine or is_shelter(host):
		found.append(host as Node2D)
		return
	for child in host.get_children():_collect(child, found)

static func is_shelter(node: Node) -> bool:
	return node is Sprite2D and (node as Sprite2D).texture != null and (node as Sprite2D).texture.resource_path.begins_with("res://assets/environment/blightwood/ancient_shrine/")

static func readability(at: Vector2, player_at: Vector2) -> float:
	# Elliptical, eased clearing extends around the whole standing silhouette.
	var d := ((at - (player_at + Vector2(0, -32))) / Vector2(150, 100)).length()
	return lerpf(0.08, 1.0, smoothstep(0.35, 1.4, d))

func advance(delta: float) -> void:
	clock += maxf(delta, 0.0)
	for i in ribbons.size():
		var sprite := ribbons[i]
		(sprite.material as ShaderMaterial).set_shader_parameter("motion_clock", clock)
		var index := i / 2
		if not enabled or index >= sources.size() or not is_instance_valid(sources[index]) or not sources[index].is_visible_in_tree():
			sprite.visible = false
			continue
		var source := sources[index]
		var phase := float(i) * 2.39996
		var period := 23.0 + float(i % 7) * 1.9
		var t := fposmod(clock / period + float(i) * 0.381966, 1.0)
		var shrine := source is DynamicShrine
		var spread := 245.0 if shrine else 150.0
		var offset := Vector2((t - 0.5) * spread * 2.0, sin(t * TAU + phase) * 13.0 + (28.0 if i % 2 == 0 else -36.0))
		# Shrine ribbons stay around the stair mouth / sides, never over its elevated monolith.
		sprite.global_position = source.global_position + offset
		sprite.rotation = sin(clock * 0.16 + phase) * 0.035
		var fade := pow(sin(PI * t), 2.0)
		var clear := readability(sprite.global_position, actor.global_position) if is_instance_valid(actor) else 1.0
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.20 * fade * clear)
		sprite.visible = sprite.modulate.a > 0.001

func visible_count() -> int:
	var count := 0
	for sprite in ribbons:
		if sprite.visible:count += 1
	return count
