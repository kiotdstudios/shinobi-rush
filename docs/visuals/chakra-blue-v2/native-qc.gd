extends SceneTree
func _initialize() -> void:
 var root := "res://assets/vfx/chakra_charge_blue_v2/"
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root+"manifest.json"))
 var count := 0
 for frame: Dictionary in data.frames:
  var texture := load(root+str(frame.path)) as Texture2D
  assert(texture!=null and texture.get_size()==Vector2(256,256))
  count+=1
 var sheet := load(root+"sheet.png") as Texture2D
 assert(sheet!=null and sheet.get_size()==Vector2(2048,3072))
 print("CHAKRA_NATIVE_QC_PASS: ",count," frames + atlas load correctly")
 quit(0)
