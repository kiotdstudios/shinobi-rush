class_name KunaiWeaponVisual
extends KunaiPoseActor
## Same weapon/hand/trail renderer for player and bandit. The sibling SpriteActor owns the body.
func show_for(actor: SpriteActor, pose: Dictionary) -> void:
	show_pose(pose)
	body.visible=false
	visible=true
	var parent := get_parent()
	if parent!=null and actor.get_parent()==parent:
		var index := 0 if str(pose.weapon_layer)=="behind" else parent.get_child_count()-1
		if get_index()!=index:parent.move_child(self,index)
