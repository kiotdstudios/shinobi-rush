class_name BanditInventory
extends RefCounted
## A bandit's belt: the player's four D-pad slots (PlayerInventory.DPAD_SLOTS), one kind of item per slot and at most
## `per_item` of it. There is no bag behind the slots, so four kinds is all he can hold. Pure data, like PlayerInventory.

signal changed

## How much he wants a kind when choosing what to keep: gourds he can drink beat things he only carries.
const VALUE := {"health_gourd": 6, "chakra_gourd": 5, "tag_bomb": 4, "paper_tag": 3, "smoke_tag_bomb": 2, "kunai": 1}

var per_item := 2
var dpad: Dictionary = {}
var counts: Dictionary = {}


func _init(p_per_item := 2) -> void:
	per_item = p_per_item
	for s: String in PlayerInventory.DPAD_SLOTS:
		dpad[s] = ""


func count_of(id: String) -> int:
	return int(counts.get(id, 0))


func slot_item(slot: String) -> String:
	return String(dpad.get(slot, ""))


func slot_of(id: String) -> String:
	for s: String in PlayerInventory.DPAD_SLOTS:
		if dpad[s] == id:
			return s
	return ""


## The slot the player keeps this kind on when it is free, else the first free one, else "".
func free_slot_for(id: String) -> String:
	var preferred := String(PlayerInventory.DEFAULT_DPAD.get(id, ""))
	if preferred != "" and dpad[preferred] == "":
		return preferred
	for s: String in PlayerInventory.DPAD_SLOTS:
		if dpad[s] == "":
			return s
	return ""


func total() -> int:
	var n := 0
	for id: String in counts:
		n += int(counts[id])
	return n


func room_for(id: String) -> bool:
	if not VALUE.has(id):
		return false
	if slot_of(id) != "":
		return count_of(id) < per_item
	return free_slot_for(id) != ""


## The slot he would empty to make room for `id`: the least wanted kind on the belt, and only if `id` is worth more.
## "" when there is room anyway, when he already carries `id`, or when nothing he holds is worth less.
func swap_slot_for(id: String) -> String:
	if not VALUE.has(id) or slot_of(id) != "" or free_slot_for(id) != "":
		return ""
	var worst := ""
	for s: String in PlayerInventory.DPAD_SLOTS:
		if worst == "" or int(VALUE[dpad[s]]) < int(VALUE[dpad[worst]]):
			worst = s
	return worst if int(VALUE[dpad[worst]]) < int(VALUE[id]) else ""


func wants(id: String) -> bool:
	return room_for(id) or swap_slot_for(id) != ""


## Adds up to `n` of `id`. Returns how many fit.
func add(id: String, n: int = 1) -> int:
	if not room_for(id):
		return 0
	if slot_of(id) == "":
		dpad[free_slot_for(id)] = id
	var put := clampi(n, 0, per_item - count_of(id))
	counts[id] = count_of(id) + put
	changed.emit()
	return put


func consume(id: String) -> bool:
	if count_of(id) <= 0:
		return false
	set_count(id, count_of(id) - 1)
	return true


## Sets the carried count directly (clamped to `per_item`); 0 frees the slot, more than 0 puts it on one if it can.
func set_count(id: String, n: int) -> void:
	var slot := slot_of(id)
	n = clampi(n, 0, per_item)
	if n > 0 and slot == "":
		slot = free_slot_for(id)
		if slot == "":
			return
		dpad[slot] = id
	if n == 0:
		counts.erase(id)
		if slot != "":
			dpad[slot] = ""
	else:
		counts[id] = n
	changed.emit()


## Empties a slot. Returns what was on it: {"id", "count"} (count 0 for an empty slot).
func drop_slot(slot: String) -> Dictionary:
	var id := slot_item(slot)
	var n := count_of(id) if id != "" else 0
	if id != "":
		set_count(id, 0)
	return {"id": id, "count": n}


## Same rule as PlayerInventory.assign_item: two slots trade places.
func swap_slots(a: String, b: String) -> void:
	if not dpad.has(a) or not dpad.has(b):
		return
	var held := String(dpad[a])
	dpad[a] = dpad[b]
	dpad[b] = held
	changed.emit()


## The pickup kind (HealthGourd.kind) an inventory item lies on the ground as.
static func pickup_kind(id: String) -> String:
	match id:
		"health_gourd":
			return "health"
		"chakra_gourd":
			return "chakra"
	return id
