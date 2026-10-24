extends Node2D
## Isolated visual review; deliberately not connected to gameplay startup.
const MANIFEST := "res://assets/environment/ashen_trees/ashen-trees.art.json"
var trees: Array[AshenTree] = []
var clock := 0.0
var speed := 0.5
var paused := false
var wind_on := true
var ash_on := true
var heat_on := true
var compare := false
var blossom: Sprite2D
var label: Label
var state: JavaScriptObject
var frame_locked := false
var player: Sprite2D
var player_anchor: Node2D
var game_zoom := false
var review_buttons: Dictionary = {}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#17212c"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var floor_tex := load("res://assets/environment/kosen_courtyard/floor_tiles/floor9_center.png") as Texture2D
	var ground := Node2D.new()
	ground.z_index = -1
	add_child(ground)
	for row in range(20, 42):
		for col in range(-1, 37):
			if posmod(row-col, 2) != 0:
				continue
			var slab := Sprite2D.new()
			slab.texture = floor_tex
			slab.position = Vector2(col*36, row*18)
			slab.modulate = Color(0.32, 0.36, 0.42, 1.0)
			ground.add_child(slab)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for i in manifest.trees.size():
		var tree := AshenTree.new()
		tree.data = manifest.trees[i]
		tree.position = Vector2(240+i*400, 600)
		add_child(tree)
		trees.append(tree)
	blossom = Sprite2D.new()
	blossom.centered = false
	blossom.texture = load("res://assets/environment/blossom_trees/textures/tree_01_tiered.png") as Texture2D
	blossom.position = Vector2(1040,600)-Vector2(155,387)
	blossom.visible = false
	add_child(blossom)
	player_anchor = Node2D.new()
	player_anchor.position = Vector2(634,640)
	add_child(player_anchor)
	player = Sprite2D.new()
	player.texture = load("res://assets/characters/player/sprites/production/idle/S_000.png") as Texture2D
	player.centered = false
	player.position = -Vector2(64,116)
	player_anchor.add_child(player)
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20,16)
	layer.add_child(box)
	var title := Label.new()
	title.text = "ASHEN RUINS | Volcanic trees | native scale"
	box.add_child(title)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_button(buttons,"Normal",func(): speed=1.0)
	_button(buttons,"Half speed",func(): speed=0.5)
	_button(buttons,"Pause",func(): paused=not paused)
	_button(buttons,"Step",func(): paused=true; clock+=1.0/24.0; _apply())
	_button(buttons,"Wind",func(): wind_on=not wind_on)
	_button(buttons,"Ash",func(): ash_on=not ash_on)
	_button(buttons,"Root glow",func(): heat_on=not heat_on)
	_button(buttons,"Compare Blightwood",func(): compare=not compare; blossom.visible=compare; trees[2].visible=not compare)
	_button(buttons,"Game zoom",func(): game_zoom=not game_zoom; _scale_view())
	label = Label.new()
	box.add_child(label)
	var caption := Label.new()
	caption.position = Vector2(24,690)
	caption.text = "96 wind phases /24 FPS | molten pulse |16 separate ash poses |128px player for scale"
	layer.add_child(caption)
	for i in 3:
		var name_label := Label.new()
		name_label.position = Vector2(180+i*400,650)
		name_label.text = ["SENTINEL","WIND-BENT","SPLIT ELDER"][i]
		layer.add_child(name_label)
	if OS.has_feature("web"):
		state = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("window").__ASHEN_REVIEW__ = state
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		if "frame=" in query:
			clock = float(query.get_slice("frame=",1).get_slice("&",0)) / 24.0
			paused = true
			frame_locked = true
	_apply()

func _scale_view() -> void:
	var zoom := 0.665 if game_zoom else 1.0
	for tree in trees:
		tree.scale = Vector2.ONE * zoom
	blossom.scale = Vector2.ONE * zoom
	blossom.position = Vector2(1040,600)-Vector2(155,387)*zoom
	player.scale = Vector2.ONE * zoom
	player.position = -Vector2(64,116)*zoom

func _button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	review_buttons[text] = button

func _process(delta: float) -> void:
	if not paused:
		clock += delta * speed
	_apply()

func _apply() -> void:
	for tree in trees:
		tree.advance(clock,wind_on,ash_on,heat_on)
	if label != null:
		label.text = "%.2fs | phase %02d/96 |%.2fx |%s | wind:%s ash:%s heat:%s" % [clock,int(clock*24)%96,speed,"PAUSED" if paused else "PLAY",wind_on,ash_on,heat_on]
	if state != null:
		state.ready = true
		state.clock = clock
		state.speed = speed
		state.paused = paused
		state.wind = wind_on
		state.ash = ash_on
		state.heat = heat_on
		state.compare = compare
		state.game_zoom = game_zoom
		state.phase = int(clock*24)%96
		state.pool_size = trees.size()*AshenTree.MAX_ASH
		var bounds := {}
		for text: String in review_buttons:
			var rect := (review_buttons[text] as Button).get_global_rect()
			bounds[text] = {"x":rect.get_center().x,"y":rect.get_center().y}
		state.buttons_json = JSON.stringify(bounds)
