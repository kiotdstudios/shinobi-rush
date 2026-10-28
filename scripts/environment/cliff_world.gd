class_name CliffWorld
extends Node2D
## Rebuildable topology for placed kit cells. No save-schema or authored-map migration.
var placed: PlacedObjects
var occupied := {}
var rim: StaticBody2D
var zones: Array[CliffElevation]=[]
var boundary_edges := 0
var nav_surfaces: Array=[]
var nav_axes: Array[PackedVector2Array]=[]
var nav_rims: Array=[]
func rebuild() -> void:
	for child in get_children():
		if child is StaticBody2D:child.collision_layer=0
		child.free()
	zones.clear()
	occupied.clear()
	boundary_edges=0
	nav_surfaces.clear()
	nav_axes.clear()
	nav_rims.clear()
	var stairs: Array[CliffElevation]=[]
	var openings: Array=[]
	for o in placed.objects:
		if not o.nodes.is_empty() and o.nodes[0] is CliffKit:
			for cell: Vector2 in (o.nodes[0] as CliffKit).cells:occupied[o.pos+cell]=o.nodes[0]
	for o in placed.objects:
		var stair: CliffElevation=(o.nodes.back() as CliffElevation) if not o.nodes.is_empty() else null
		if stair==null:continue
		var is_kit:=bool(PlacedObjects.def_of(o.id).get("cliff_kit",false))
		var connected:=false
		var head:=stair.position+stair.top+(stair.top-stair.mouth).normalized()*4.0
		for p: Vector2 in occupied:
			if Geometry2D.is_point_in_polygon(head,_diamond(p)):
				connected=true
				break
		if not is_kit and not connected:
			if stair.has_meta("cliff_kit_adopted"):
				stair.remove_meta("cliff_kit_adopted")
				stair.modular=false
				stair.surfaces.clear()
				stair.landing=PackedVector2Array(PlacedObjects.def_of(o.id).landing)
				stair._build_edges()
			continue
		if not is_kit:
			stair.set_meta("cliff_kit_adopted",true)
			stair.landing=PackedVector2Array()
			if is_instance_valid(stair.edge_body):
				stair.edge_body.collision_layer=0
				stair.edge_body.free()
				stair.edge_body=null
		stairs.append(stair)
		stair.surfaces.clear()
		var polygon:=PackedVector2Array()
		for p in stair.stair_polygon():polygon.append(p+stair.position)
		nav_surfaces.append(polygon)
		var run:=stair.top-stair.mouth
		nav_axes.append(PackedVector2Array([stair.position+stair.mouth-run,stair.position+stair.top,stair.position+stair.top+run*.4]))
		var expanded:=Geometry2D.offset_polygon(polygon,2.0)
		if not expanded.is_empty():openings.append(expanded[0])
	for o in placed.objects:
		if not o.nodes.is_empty() and o.nodes[0] is CliffKit:
			(o.nodes[0] as CliffKit).rebuild(occupied,openings)
	rim=StaticBody2D.new()
	rim.name="ModularCliffBoundaries"
	rim.collision_layer=ShrineElevation.EDGE_LAYER
	rim.collision_mask=0
	rim.position=Vector2(0,-WorldScale.FOOTPRINT.y*.5)
	add_child(rim)
	for cell: Vector2 in occupied:
		for edge in 4:
			if occupied.has(cell+CliffKit.NEIGHBORS[edge]):continue
			var a: Vector2=cell+CliffKit.VERTICES[edge]
			var b: Vector2=cell+CliffKit.VERTICES[(edge+1)%4]
			if not CliffKit._opening(a,b,openings):_segment(a,b)
	for stair in stairs:
		for side in [-1.0,1.0]:_segment(stair.position+stair.mouth+stair.half_width*side,stair.position+stair.top+stair.half_width*side)
	# Flood-fill each island: both stair directions share that island's complete walkable surface.
	var remaining:=occupied.duplicate()
	while not remaining.is_empty():
		var component: Array[Vector2]=[]
		var pending: Array[Vector2]=[remaining.keys()[0]]
		while not pending.is_empty():
			var p: Vector2=pending.pop_back()
			if not remaining.has(p):continue
			remaining.erase(p)
			component.append(p)
			for d: Vector2 in CliffKit.NEIGHBORS:
				if remaining.has(p+d):pending.append(p+d)
		var surface:=CliffElevation.new()
		surface.surface_only=true
		surface.build_edges=false
		surface.modular=true
		surface.height=CliffKit.HEIGHT
		for p in component:
			surface.surfaces.append(_diamond(p))
			nav_surfaces.append(_diamond(p))
		add_child(surface)
		zones.append(surface)
		for stair in stairs:
			var head: Vector2=stair.position+stair.top+(stair.top-stair.mouth).normalized()*4.0
			if not surface.contains_surface(head):continue
			stair.surfaces.clear()
			for p in component:stair.surfaces.append(_diamond(p-stair.position))
			stair.modular=true
func _diamond(p: Vector2) -> PackedVector2Array:
	var poly:=PackedVector2Array()
	for v: Vector2 in CliffKit.VERTICES:poly.append(p+v)
	return poly
func _segment(a: Vector2,b: Vector2) -> void:
	var n: Vector2=(b-a).orthogonal().normalized()*3.0
	var shape:=CollisionPolygon2D.new()
	shape.polygon=PackedVector2Array([a-n,b-n,b+n,a+n])
	rim.add_child(shape)
	boundary_edges+=1
	nav_rims.append([a,b])
