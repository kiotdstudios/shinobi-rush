class_name RyoPouch
extends Node2D
## A purse of ryo dropped where a fighter went down. The first living fighter to reach it, player or bandit, takes
## all of it; bandits go out of their way for one (see Bandit loot), so a fallen ninja's purse is worth a race.

const GROUP := "ryo_pouch"
const PICKUP_RADIUS := 40.0  ## floor-plane radius, y doubled like HealthGourd's
const LIFETIME := 120.0
const GRACE := 0.8  ## the one who dropped it cannot scoop it straight back up off his own body
const BAG := Color("#6b4426")
const BAG_DARK := Color("#3e2615")
const CORD := Color("#c9a24a")
const COIN := Color("#ffd23f")

var amount := 0
var level := 0.0  ## elevation it lies at (dropped on a cliff landing it stays up there)
var dropped_by: Node = null
var taken_by: Node = null
var age := 0.0


static func drop(parent: Node, at: Vector2, amt: int, who: Node = null) -> RyoPouch:
	if parent == null or amt <= 0:
		return null
	var p := RyoPouch.new()
	p.name = "RyoPouch"
	p.amount = amt
	p.dropped_by = who
	p.level = Combatants.level_of(who)
	parent.add_child(p)
	p.global_position = at
	return p


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	for c in Combatants.all(get_tree()):
		if can_take(c):
			take(c)
			return
	queue_redraw()


func can_take(c: Node2D) -> bool:
	if amount <= 0 or taken_by != null or not Combatants.alive(c) or not c.is_visible_in_tree():
		return false
	if c == dropped_by and age < GRACE:
		return false
	if absf(Combatants.level_of(c) - level) >= Combatants.MELEE_LEVEL_GAP:
		return false
	var d := c.global_position - global_position
	return Vector2(d.x, d.y * 2.0).length() <= PICKUP_RADIUS


func take(c: Node2D) -> int:
	var got := amount
	amount = 0
	taken_by = c
	Combatants.give_ryo(c, got)
	queue_free()
	return got


func _draw() -> void:
	var lift := Vector2(0, -level)
	var bob := sin(age * 3.0) * 1.5
	var shadow := PackedVector2Array()
	for i in 16:
		var t := TAU * float(i) / 16.0
		shadow.append(lift + Vector2(cos(t) * 12.0, sin(t) * 5.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	var c := lift + Vector2(0, -9.0 + bob)
	draw_circle(c, 9.0, BAG_DARK)
	draw_circle(c + Vector2(-1, -1), 8.0, BAG)
	draw_line(c + Vector2(-5, -7), c + Vector2(5, -7), CORD, 2.0)
	draw_circle(c + Vector2(0, -10), 3.0, BAG)
	draw_circle(c + Vector2(3, 1), 2.5, COIN)
	var pulse := 0.5 + 0.5 * sin(age * 5.0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-12, -18), "%d ryo" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(COIN, 0.6 + 0.4 * pulse))
