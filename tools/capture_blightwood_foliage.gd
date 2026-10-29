extends SceneTree
## Native GPU art capture; run without --headless. Does not instantiate gameplay.
var plants: Array[BlightwoodFoliage]=[]
func _initialize() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size=Vector2i(768,160)
	RenderingServer.set_default_clear_color(Color("1a2d2f"))
	call_deferred("capture")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/vines-ferns/render")
	for i in BlightwoodFoliage.IDS.size():
		var id: String=BlightwoodFoliage.IDS[i]
		var info:=BlightwoodFoliage.definition(id)
		var plant:=BlightwoodFoliage.new()
		plant.auto_advance=false
		plant.setup(id,Vector2(i*128+64,info.anchor.y+info.lift))
		root.add_child(plant)
		plants.append(plant)
		var label:=Label.new()
		label.text=str(info.label)
		label.position=Vector2(i*128+8,136)
		label.add_theme_font_size_override("font_size",12)
		root.add_child(label)
	for phase in 96:
		for plant in plants:
			plant.clock=float(phase)/24.0
			plant.advance(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/vines-ferns/render/phase-%03d.png"%phase)
	quit()
