class_name BlossomGrove
extends Node2D
## Scene integration for the trees. Trunk collision/nav lives in TrainingArena (WorldScale.TREE_POSITIONS).
const MANIFEST := "res://assets/environment/blossom_trees/blossom_trees.art.json"
const PLACEMENTS: Array[Vector2] = WorldScale.TREE_POSITIONS  # single source: trunk colliders use the same list
var trees: Array[BlossomTree] = []
var clock := 0.0
var speed := 1.0
var paused := false
var wind_on := true
var leaves_on := true
var review_mode := false
var selected := -1
var review_camera: Camera2D
var status: Label
var _state: JavaScriptObject
var _manifest: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	var manifest: Dictionary = _load_manifest()
	for i in manifest.trees.size():
		var tree := BlossomTree.new()
		tree.name = str(manifest.trees[i].id)
		tree.data = manifest.trees[i]
		tree.position = PLACEMENTS[i]
		add_child(tree)
		trees.append(tree)
	var query := str(JavaScriptBridge.eval("window.location.search", true)) if OS.has_feature("web") else ""
	review_mode = "trees=review" in query or "--trees-review" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		_state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__BLOSSOM_STATE__ = _state
	if review_mode:
		call_deferred("_start_review")

func _load_manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest

## World Builder hook: one more tree of art variant `index` (0-4) at a ground anchor. Wind/leaves advance with the rest.
func add_tree(index: int, at: Vector2) -> BlossomTree:
	var tree := BlossomTree.new()
	tree.name = "Placed%d_%d" % [index, trees.size()]
	tree.data = _load_manifest().trees[index]
	tree.position = at
	add_child(tree)
	trees.append(tree)
	return tree

func remove_tree(tree: BlossomTree) -> void:
	trees.erase(tree)
	tree.queue_free()

func _process(delta: float) -> void:
	advance(0.0 if paused else delta * speed)
	if status != null:
		status.text = "TREE SWAY | %02d / 96 | %.2fx | %d falling leaves / petals" % [phase(), speed, particle_count()]
	if _state != null:
		_state.ready = true
		_state.trees = trees.size()
		_state.phase = phase()
		_state.time = clock
		_state.speed = speed
		_state.paused = paused
		_state.wind = wind_on
		_state.leaves = leaves_on
		_state.particles = particle_count()
		_state.capacity = trees.size() * FallingFoliage.MAX_PARTICLES
		_state.selected = selected
		_state.review = review_mode

func advance(delta: float) -> void:
	clock += delta
	for tree: BlossomTree in trees:
		tree.advance(clock, delta, wind_on, leaves_on)

func phase() -> int:
	return int(floor(fmod(clock, 4.0) * 24.0)) % 96

func particle_count() -> int:
	var count := 0
	for tree: BlossomTree in trees:
		count += tree.foliage.active_count()
	return count

func _start_review() -> void:
	# Only this optional art view hides the existing diagnostic layers. Normal
	# startup and the real Animation Lab keep their original UI and controls.
	var main := get_tree().current_scene
	if main != null:
		_hide_diagnostic_layers(main)
	review_camera = Camera2D.new()
	review_camera.name = "TreeArtReviewCamera"
	get_parent().add_child(review_camera)
	show_tree(-1)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, get_viewport_rect().size.y - 116)
	layer.add_child(panel)
	get_viewport().size_changed.connect(func(): panel.position.y = get_viewport_rect().size.y - 116)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status = Label.new()
	column.add_child(status)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row, "Normal", func(): speed = 1.0; paused = false)
	_button(row, "Half speed", func(): speed = 0.5; paused = false)
	_button(row, "Pause", func(): paused = not paused)
	_button(row, "Step", func(): paused = true; advance(1.0 / 24.0))
	_button(row, "Wind on/off", func(): wind_on = not wind_on)
	_button(row, "Leaves on/off", func(): leaves_on = not leaves_on)
	var tour := HBoxContainer.new()
	column.add_child(tour)
	_button(tour, "All five", func(): show_tree(-1))
	for i in 5:
		_button(tour, "Tree %d" % (i + 1), func(): show_tree(i))
	_button(tour, "Follow player", _follow_player)

func _hide_diagnostic_layers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_diagnostic_layers(child)

func show_tree(index: int) -> void:
	selected = index
	if index < 0:
		review_camera.position = Vector2(-690, 170)
		review_camera.zoom = Vector2.ONE * 0.44
	else:
		review_camera.position = trees[index].global_position + Vector2(0, -220)
		review_camera.zoom = Vector2.ONE
	review_camera.make_current()

func _follow_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.make_current()
	selected = -2

func _button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	row.add_child(button)
