extends Node2D
## One visitor: arrival -> settle -> hunt/tongue -> departure -> independent water splash.
var host: Waterlife
var age := 0.0
var body: Sprite2D
var fly: Sprite2D
var phase := "arrival"
var splash_done := false

func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body = Sprite2D.new()
	body.texture = load(Waterlife.ART + "frog.png")
	body.hframes = 4
	body.vframes = 4
	body.offset = Vector2(0,-40)
	body.scale = Vector2.ONE * 0.5
	add_child(body)
	fly = Sprite2D.new()
	fly.texture = load(Waterlife.ART + "fly.png")
	add_child(fly)

func advance(delta: float) -> void:
	age += delta
	if age < 0.55:
		phase = "arrival"
		var t := age/0.55
		body.frame = mini(int(t*4.0),3)
		body.position = Vector2(lerpf(-42.0,0.0,t),-sin(t*PI)*25.0).round()
	elif age < 1.7:
		phase = "settle"
		body.frame = 4 + int(age*6.0)%2
		body.position = Vector2.ZERO
	elif age < 2.35:
		phase = "tongue"
		body.frame = 6 + mini(int((age-1.7)/0.65*5.0),4)
	elif age < 3.1:
		phase = "recovery"
		body.frame = 11
	else:
		phase = "departure"
		var t := clampf((age-3.1)/0.55,0.0,1.0)
		body.frame = 12 + mini(int(t*4.0),3)
		body.position = Vector2(t*48.0,-sin(t*PI)*28.0+t*8.0).round()
		if t>=1.0:
			body.visible = false
			if not splash_done:
				splash_done = true
				host.emit_splash(global_position+Vector2(48,8),0.8,1.0,0.0,z_index)
	fly.visible = age < 2.15
	fly.position = Vector2(28+sin(age*9.0)*3,-17+sin(age*13.0)*2).round()
	fly.scale.y = 0.7 if int(age*30.0)%2==0 else 1.0
