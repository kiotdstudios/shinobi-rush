class_name PlayerInventory
extends RefCounted
## What the player carries and which D-pad slot / R2 jutsu slot each thing sits on. Pure data (no nodes), so it is
## trivial to test and to save. The controller owns one instance as `player.inventory`.
##   D-pad slots  : up / right / down / left, each holds one item id (or "" = empty); pressing that direction uses it.
##   Jutsu slots  : the four R2 + face-button slots (Square, Triangle, Circle, Cross), each holds one jutsu id (or "").
## Assignments are saved to `user://inventory.json`; carried counts are NOT saved (a fresh run starts with START_COUNTS).

signal changed

const MAX_STACK := 9
const DPAD_SLOTS: Array[String] = ["up", "right", "down", "left"]
const JUTSU_SLOTS: Array[String] = ["square", "triangle", "circle", "cross"]
const ITEMS := {
	"tag_bomb": {"name": "Tag Bomb", "short": "TB", "desc": "Throw an explosive paper sphere; detonates after a short fuse."},
	"smoke_tag_bomb": {"name": "Smoke Tag Bomb", "short": "SB", "desc": "Throw a black tag sphere to release a smoke screen. No damage."},
	"health_gourd": {"name": "Health Gourd", "short": "HP", "desc": "Restores 25% of max health."},
	"chakra_gourd": {"name": "Chakra Gourd", "short": "CK", "desc": "Restores 25% of max chakra."},
	"kunai": {"name": "Kunai", "short": "KN", "desc": "Throw one forward for light damage."},
	"paper_tag": {"name": "Paper Tag", "short": "PT", "desc": "Throw it; it lands and explodes after a short fuse."},
}
## Jutsu you can place on an R2 slot. `ready` false = listed and assignable but not playable yet.
const JUTSU := {
	"chidori": {"name": "Chidori", "ready": false},
}
const START_COUNTS := {"health_gourd": 0, "chakra_gourd": 0, "kunai": 10, "paper_tag": 3, "tag_bomb": 0, "smoke_tag_bomb": 0}
const DEFAULT_DPAD := {"up": "health_gourd", "right": "chakra_gourd", "down": "paper_tag", "left": "kunai"}
const DEFAULT_JUTSU := {"square": "chidori", "triangle": "", "circle": "", "cross": ""}
const SAVE_PATH := "user://inventory.json"

var counts: Dictionary = START_COUNTS.duplicate()
var dpad: Dictionary = DEFAULT_DPAD.duplicate()
var jutsu: Dictionary = DEFAULT_JUTSU.duplicate()
var save_path := SAVE_PATH


func count_of(id: String) -> int:
	return int(counts.get(id, 0))


func slot_item(slot: String) -> String:
	return String(dpad.get(slot, ""))


func slot_count(slot: String) -> int:
	var id := slot_item(slot)
	return count_of(id) if id != "" else 0


## Adds up to `n` of `id` (capped at MAX_STACK). Returns how many actually fit.
func add(id: String, n: int = 1) -> int:
	if not ITEMS.has(id):
		return 0
	var room := MAX_STACK - count_of(id)
	var put := clampi(n, 0, maxi(room, 0))
	if put > 0:
		counts[id] = count_of(id) + put
		changed.emit()
	return put


func has_room(id: String) -> bool:
	return ITEMS.has(id) and count_of(id) < MAX_STACK


## Removes one of `id`. Returns false (and changes nothing) when there is none.
func consume(id: String) -> bool:
	if count_of(id) <= 0:
		return false
	counts[id] = count_of(id) - 1
	changed.emit()
	return true


## Puts `id` on `slot`. An item sits on at most one slot: if it is already on another one the two swap.
func assign_item(slot: String, id: String) -> void:
	if not dpad.has(slot) or (id != "" and not ITEMS.has(id)):
		return
	if id != "":
		for other: String in DPAD_SLOTS:
			if other != slot and dpad[other] == id:
				dpad[other] = dpad[slot]
	dpad[slot] = id
	changed.emit()


## Puts jutsu `id` on R2 slot `slot` (same swap rule as items). "" empties the slot.
func assign_jutsu(slot: String, id: String) -> void:
	if not jutsu.has(slot) or (id != "" and not JUTSU.has(id)):
		return
	if id != "":
		for other: String in JUTSU_SLOTS:
			if other != slot and jutsu[other] == id:
				jutsu[other] = jutsu[slot]
	jutsu[slot] = id
	changed.emit()


func jutsu_slot_of(id: String) -> String:
	for s: String in JUTSU_SLOTS:
		if jutsu[s] == id:
			return s
	return ""


func save() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "dpad": dpad, "jutsu": jutsu}))
	return true


func load_saved() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (data is Dictionary):
		return false
	var d: Variant = (data as Dictionary).get("dpad", {})
	if d is Dictionary:
		for s: String in DPAD_SLOTS:
			var id := String((d as Dictionary).get(s, dpad[s]))
			if id == "" or ITEMS.has(id):
				dpad[s] = id
	var j: Variant = (data as Dictionary).get("jutsu", {})
	if j is Dictionary:
		for s: String in JUTSU_SLOTS:
			var id := String((j as Dictionary).get(s, jutsu[s]))
			if id == "" or JUTSU.has(id):
				jutsu[s] = id
	changed.emit()
	return true


## Small picture for an item id (the gourds' own art, the black kunai). Null for an unknown id.
static func icon(id: String) -> Texture2D:
	match id:
		"tag_bomb", "smoke_tag_bomb":
			return HealthGourd.icon(id)
		"health_gourd":
			return HealthGourd.icon("health")
		"chakra_gourd":
			return HealthGourd.icon("chakra")
		"paper_tag":
			return HealthGourd.icon("paper_tag")
		"kunai":
			return load("res://assets/weapons/kunai/black_kunai.png") as Texture2D
	return null
