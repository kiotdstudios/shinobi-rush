extends RefCounted

func run(ck: Callable, root: Node) -> void:
	var fx := GroundMist.new()
	fx.auto_advance = false
	root.add_child(fx)
	await root.get_tree().process_frame
	ck.call("mist fixed pool has exactly 48 slots",fx.ribbons.size()==48)
	fx.advance(3.0)
	ck.call("mist has no orphan ribbons without sources",fx.visible_count()==0)
	ck.call("mist clears strongly around player",GroundMist.readability(Vector2.ZERO,Vector2.ZERO)<0.09)
	ck.call("mist preserves full atmosphere away from player",is_equal_approx(GroundMist.readability(Vector2(500,0),Vector2.ZERO),1.0))
	var source := Node2D.new()
	root.add_child(source)
	fx.sources.append(source)
	fx.advance(0.0)
	ck.call("mist emits two ribbons per source",fx.visible_count()==2)
	var original := fx.ribbons[0].global_position
	fx.advance(1.0)
	ck.call("mist drifts over time",fx.ribbons[0].global_position != original)
	var moved := fx.ribbons[0].global_position
	source.position += Vector2(75,20)
	fx.advance(0.0)
	ck.call("mist follows builder-moved source",fx.ribbons[0].global_position.is_equal_approx(moved+Vector2(75,20)))
	var peak := 0.0
	for i in 400:
		fx.advance(0.1)
		for sprite in fx.ribbons:peak=maxf(peak,sprite.modulate.a)
	ck.call("mist opacity remains bounded at 20 percent",peak<=0.20001)
	fx.enabled=false
	fx.advance(0.0)
	ck.call("mist toggle clears all ribbons",fx.visible_count()==0)
	fx.enabled=true
	source.queue_free()
	await root.get_tree().process_frame
	fx.advance(0.1)
	ck.call("deleted source leaves no stale mist",fx.visible_count()==0)
	ck.call("mist never grows its pool",fx.get_child_count()==48)
	var a := Node2D.new()
	var b := Node2D.new()
	root.add_child(a)
	root.add_child(b)
	fx.set_sources([a,b])
	fx.advance(0.0)
	var stable := fx.ribbons[0].global_position
	fx.set_sources([b,a])
	fx.advance(0.0)
	ck.call("nearest-distance reranking cannot teleport surviving ribbons",fx.sources[0]==a and fx.ribbons[0].global_position==stable)
	fx.set_sources([b])
	ck.call("deleting a source preserves other source slots",fx.sources[0]==null and fx.sources[1]==b)
	fx.set_sources([a,b])
	ck.call("new sources reuse vacant fixed slots",fx.sources[0]==a and fx.sources[1]==b)
	var shelter := Sprite2D.new()
	shelter.texture = load("res://assets/environment/blightwood/ancient_shrine/shrine_shelter_01.png") as Texture2D
	root.add_child(shelter)
	fx.scan_sources(root)
	ck.call("mist discovers the authored Ancient Shrine shelter as well as the dynamic monument",fx.sources.has(shelter))
	shelter.queue_free()
	a.queue_free()
	b.queue_free()
	fx.queue_free()
	await root.get_tree().process_frame
