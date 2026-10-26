class_name HeldItems
extends RefCounted
## The player's 4 D-pad quick-use item slots (owner 2026-10-25: "10x kunai, health gourd, chakra
## gourd, and paper tags" -- the only 4 item-like things that exist in this game). Slot order
## matches the diamond HUD (HeldItemsHud) and the four `use_item_N` input actions: UP/RIGHT/DOWN/LEFT.
##
## Kunai is ammo-limited (10 starting, thrown on use); gourds start at 0 and are filled by world
## pickups (see HealthGourd.collect, changed by this order to add to inventory instead of healing
## instantly); paper tags start at 0 (no world source yet -- flagged in the order's handoff notes).

const SLOT_UP := "kunai"
const SLOT_RIGHT := "health_gourd"
const SLOT_DOWN := "chakra_gourd"
const SLOT_LEFT := "paper_tag"
## Default D-pad assignment, UP/RIGHT/DOWN/LEFT. rearrange() permutes this at runtime (see
## HeldItemsHud's inventory screen); use_item_N always reads whatever is CURRENTLY in ORDER[N-1].
var order: Array[String] = [SLOT_UP, SLOT_RIGHT, SLOT_DOWN, SLOT_LEFT]

## label + HUD icon colour. Every icon is drawn procedurally (HeldItemsHud) -- no art exists for a
## throwable kunai or for paper tags, and "high quality procedural inventory UI" was the explicit ask.
const DEFS := {
	"kunai": {"label": "Kunai", "color": Color(0.80, 0.82, 0.86)},
	"health_gourd": {"label": "Health Gourd", "color": Color(1.0, 0.18, 0.1)},
	"chakra_gourd": {"label": "Chakra Gourd", "color": Color(0.15, 0.55, 1.0)},
	"paper_tag": {"label": "Paper Tag", "color": Color(0.95, 0.85, 0.55)},
}

var counts: Dictionary = {"kunai": 10, "health_gourd": 0, "chakra_gourd": 0, "paper_tag": 0}


func count(item_id: String) -> int:
	return int(counts.get(item_id, 0))


func label(item_id: String) -> String:
	return str(DEFS.get(item_id, {}).get("label", item_id))


func color(item_id: String) -> Color:
	return DEFS.get(item_id, {}).get("color", Color.WHITE)


## Grants `n` of `item_id` (world pickups, future drops). Does nothing for an unknown id.
func add(item_id: String, n: int = 1) -> void:
	if DEFS.has(item_id):
		counts[item_id] = count(item_id) + n


## Consumes one of `item_id` if any are carried. Returns true if one was actually spent.
func spend(item_id: String) -> bool:
	if count(item_id) <= 0:
		return false
	counts[item_id] = count(item_id) - 1
	return true


## Discards `n` of `item_id` with no effect (the inventory screen's "drop"). Clamped to what is held;
## returns the amount actually discarded.
func drop(item_id: String, n: int = 1) -> int:
	var taken := clampi(n, 0, count(item_id))
	counts[item_id] = count(item_id) - taken
	return taken


## Swaps the items in D-pad slots `a` and `b` (0=up,1=right,2=down,3=left). The inventory screen's
## "rearrange" -- counts are untouched, only which physical direction throws/uses which item.
func swap_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= order.size() or b >= order.size():
		return
	var tmp := order[a]
	order[a] = order[b]
	order[b] = tmp
