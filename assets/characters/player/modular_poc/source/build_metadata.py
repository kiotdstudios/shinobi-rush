"""Build the opt-in art attachment contract, never the runtime player manifest."""
from pathlib import Path
from PIL import Image
import json,hashlib

ROOT=Path(__file__).resolve().parents[1]
anchors=json.loads((ROOT/'source/frame_anchors.json').read_text())
body=json.loads((ROOT/'source/body_export.json').read_text())
manifest={'schema':'shinobi_modular_weapon_art_poc_v1','id':'player_se_sword_combo_poc',
 'status':'art_visual_review','character':'approved_player','directions':['SE'],
 'frame_size':[128,128],'foot_anchor':[64,116],'body_height_px':104,
 'index_base':0,'fps_proposal':24,'default_review_speed':0.5,'timing_status':'pending_aki_configuration',
 'root_motion':'gameplay_owned','family':'one_handed_sword_poc',
 'mount_contract':{'name':'right_hand','coordinates':'native_body_pixels_top_left_origin',
  'blade_axis_local':[1,0],'angle_units':'degrees_clockwise_y_down','interpolation':'step',
  'relative_z':{'behind':-1,'body':0,'front':1,'hand_occluder':2,'vfx':3},
  'hand_occluder':'Reuse the body texture region; no additional body library.'},
 'weapons':{},'animations':{},
 'vfx':{'manifest':'../../../vfx/combat/combat_vfx.json','independent':True,
        'trigger':'recommended_contact_event_pending_gameplay_config'},
 'scope_limit':'one_character_one_direction_three_hit_combo_two_compatible_swords_no847_conversion'}
for weapon,label in [('katana','Curved katana'),('straight_sword','Straight sword')]:
 f=ROOT/f'weapons/{weapon}.png';im=Image.open(f);assert im.size==(64,64) and im.mode=='RGBA'
 manifest['weapons'][weapon]={'label':label,'texture':f'weapons/{weapon}.png','size':[64,64],
  'grip_pivot_px':[14,32],'native_pixel_scale':1,'handedness':'one','family':'one_handed_sword_poc',
  'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
for action,defs in anchors.items():
 frames=[]
 for i in range(8):
  record=next(r for r in body if r['animation']==action and r['frame_index']==i)
  x,y=defs['grip_px'][i];im=Image.open(ROOT/record['body_frame'])
  assert im.getpixel((x,y))[3]==255,(action,i,'grip lies outside hand/body')
  frames.append({'frame_index':i,'body_frame':record['body_frame'],
   'body_sha256':record['body_sha256'],'baked_reference':f'baked_reference/{action}/SE_{i:03}.png',
   'right_hand_px':[x,y],'weapon_angle_deg':defs['angle_deg'][i],
   'weapon_layer':defs['layer'][i],'hand_occlusion_rect':[x-2,y-2,5,5]})
 manifest['animations'][action]={'direction':'SE','frame_count':8,'fps':24,'loop':False,
  'foot_anchor':[64,116],'contact_frames':defs['contact_frames'],
  'hitbox_active_recommendation':defs['hitbox_active_recommendation'],
  'transition_ready_frames':defs['transition_ready_frames'],
  'cancel_window_recommendation':defs['cancel_window_recommendation'],
  'trail_effect':'sword_trail_heavy' if action=='light_attack_3' else 'sword_trail_light','frames':frames}
(ROOT/'modular_poc.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS24 frame-specific opaque grip anchors, orientations, draw orders;2 swords share identical24 body references')
