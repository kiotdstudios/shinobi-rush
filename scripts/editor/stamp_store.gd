class_name StampStore
extends RefCounted
## Builder clipboard + saved stamps. A stamp is a list of {id, x, y} with positions relative to an anchor floor cell,
## so a whole courtyard can be dropped anywhere on the floor grid.

const PATH := "user://builder_stamps.json"


## Relative items for `objs` (the player spawn is never copied). Anchor = floor cell nearest the group's centre.
static func capture(objs: Array) -> Array:
	var pts: Array = []
	for o in objs:
		if PlacedObjects.def_of(o.id).kind != "spawn":
			pts.append(o)
	if pts.is_empty():
		return []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for o in pts:
		lo = lo.min(o.pos)
		hi = hi.max(o.pos)
	var anchor := PlacedObjects.lattice_center((lo + hi) * 0.5)
	var items: Array = []
	for o in pts:
		var rel: Vector2 = (o.pos as Vector2) - anchor
		items.append({"id": String(o.id), "x": rel.x, "y": rel.y})
	return items


static func load_all(path := PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary and (data as Dictionary).get("stamps") is Array:
		return (data as Dictionary).stamps
	return []


static func save_all(stamps: Array, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "stamps": stamps}))
	return true


static func add(name: String, items: Array, path := PATH) -> bool:
	if items.is_empty():
		return false
	var all := load_all(path)
	all.append({"name": name, "items": items})
	return save_all(all, path)


static func remove(index: int, path := PATH) -> bool:
	var all := load_all(path)
	if index < 0 or index >= all.size():
		return false
	all.remove_at(index)
	return save_all(all, path)
