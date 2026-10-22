extends RefCounted
func run(ck: Callable, root: Node) -> void:
 var art: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ChakraChargeVisual.PACK))
 ck.call("chakra: all eight directions delivered",art.body.size()==8)
 for direction: String in SpriteSet.DIRS8:
  var frames: Array=art.body[direction]
  ck.call("chakra: eight body keys "+direction,frames.size()==8)
  for path: String in frames:
   var tex:=load("res://"+path) as Texture2D
   ck.call("chakra: native transparent body "+path,tex!=null and tex.get_size()==Vector2(128,128) and tex.get_image().get_format()==Image.FORMAT_RGBA8)
 var v:=ChakraChargeVisual.new()
 root.add_child(v)
 v.auto_advance=false
 ck.call("chakra: three separate FX layers",v.layers.size()==3 and int(art.layers.aura.frames)==48 and int(art.layers.wisps.frames)==32 and int(art.layers.ground.frames)==16)
 ck.call("chakra: body foot anchor preserved",v.body.position==Vector2(-64,-116))
 ck.call("chakra: aura/ground/body/front stack",v.get_child(0)==v.layers.ground and v.get_child(1)==v.layers.aura and v.get_child(2)==v.body and v.get_child(3)==v.layers.wisps)
 var body_texture:=v.body.texture
 v.set_chakra_color(Color(1,0,0))
 ck.call("chakra: tint leaves body texture/modulation intact",v.body.texture==body_texture and v.body.modulate==Color.WHITE)
 var other:=ChakraChargeVisual.new()
 root.add_child(other)
 other.auto_advance=false
 ck.call("chakra: per-instance palette",other.chakra_color==ChakraChargeVisual.BLUE and other.materials[0]!=v.materials[0] and v.materials[0].get_shader_parameter("chakra_color")==Color(1,0,0))
 v.advance(1.0/24)
 ck.call("chakra: exact phase step",v.phase()==1 and v.body_frame()==0)
 v.advance(1.0/24)
 ck.call("chakra: body cadence independent",v.phase()==2 and v.body_frame()==1)
 v.advance(4)
 ck.call("chakra: joint96phase loop exact",v.phase()==2 and v.body_frame()==1)
 for di: String in SpriteSet.DIRS8:
  v.direction=di
  for i in 8:v.advance(1.0/12)
 ck.call("chakra: bounded body texture cache",v.textures.size()<=64)
 var set:=SpriteSet.parse(FileAccess.get_file_as_string("res://assets/characters/player/player_128.manifest.json"),"res://assets/characters/player/player_128.manifest.json")
 ck.call("chakra: updated production manifest valid",set.is_valid() and set.animations.has("chakra_charge"))
 for di: String in SpriteSet.DIRS8:
  ck.call("chakra: no nearest-direction fallback "+di,not bool(set.resolve("chakra_charge",di).fallback))
 v.queue_free()
 other.queue_free()
 await root.get_tree().process_frame
