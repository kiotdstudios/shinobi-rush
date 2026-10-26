"""Extract generated pickup art, retain shared scale and export data-only Godot resources."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json, hashlib

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'assets/pickups/ryo_pouch'
DOC = ROOT/'docs/visuals/ryo-pouch'
DOC.mkdir(parents=True, exist_ok=True)
font_path = next((p for p in [Path('C:/Windows/Fonts/segoeui.ttf'),Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')] if p.exists()),None)
font = ImageFont.truetype(str(font_path),13) if font_path else ImageFont.load_default()
qa = {}; groups = {}; scales = {}

def source_cells(name, rows):
    raw = Image.open(ART/'source'/(name+'-raw.png')).convert('RGBA')
    a = np.array(raw); rgb = a[:,:,:3].astype(int)
    key = (rgb[:,:,0] > rgb[:,:,1]+40) & (rgb[:,:,2] > rgb[:,:,1]+40)
    a[key] = 0
    if name in ['glow','ember']:
        # Unmix magenta matte from gold FX fringes only; white/gold cores and all leather colors stay intact.
        r,g,b = [rgb[:,:,i].astype(float) for i in range(3)]
        spill=(a[:,:,3]>0)&(r>g+12)&(b>g*.55)&(g<235)
        opacity=np.clip((255-b)/255,0,1)
        a[:,:,0][spill]=255
        a[:,:,1][spill]=np.clip(g[spill]/np.maximum(opacity[spill],.01),0,255).astype('uint8')
        a[:,:,2][spill]=0
        a[:,:,3][spill]=np.round(opacity[spill]*255).astype('uint8')
        a[a[:,:,3]==0]=0
    clean = Image.fromarray(a)
    return [clean.crop((round(x*raw.width/4),round(y*raw.height/rows),round((x+1)*raw.width/4),round((y+1)*raw.height/rows))) for y in range(rows) for x in range(4)]

for name, rows, size, prefix in [('idle',4,128,'gourd'),('glow',3,96,'glow'),('ember',3,96,'ember'),('collect',2,128,'collect')]:
    cells = source_cells(name,rows)
    boxes = [im.getbbox() for im in cells]
    if name == 'idle':
        scale = 80/max(b[3]-b[1] for b in boxes)
        pivot = None
    elif name == 'collect':
        b=boxes[0]; scale=80/(b[3]-b[1]); pivot=((b[0]+b[2])/2,(b[1]+b[3])/2)
    else:
        extent=max(max(abs(b[0]-im.width/2),abs(b[2]-im.width/2),abs(b[1]-im.height/2),abs(b[3]-im.height/2)) for im,b in zip(cells,boxes) if b)
        scale=40/extent; pivot=None
    frames=[]; edge=[]; empty=[]; hashes=[]; bounds=[]
    for i,(im,b) in enumerate(zip(cells,boxes)):
        out=Image.new('RGBA',(size,size))
        if b:
            patch=im.crop(b)
            patch=patch.resize((max(1,round(patch.width*scale)),max(1,round(patch.height*scale))),Image.Resampling.NEAREST)
            if name=='idle':xy=(64-patch.width//2,104-patch.height)
            else:
                p=pivot or (im.width/2,im.height/2)
                xy=(round(size/2+(b[0]-p[0])*scale),round(size/2+(b[1]-p[1])*scale))
            assert xy[0]>=0 and xy[1]>=0 and xy[0]+patch.width<=size and xy[1]+patch.height<=size,(name,i,'clamp')
            out.paste(patch,xy)
        else:empty.append(i)
        alpha=np.array(out)[:,:,3]
        if alpha[0].any() or alpha[-1].any() or alpha[:,0].any() or alpha[:,-1].any():edge.append(i)
        hashes.append(hashlib.sha256(out.tobytes()).hexdigest());bounds.append(out.getbbox())
        out.save(ART/f'{prefix}_{i:02d}.png');frames.append(out)
    assert empty == ([7] if name=='collect' else []),(name,'unexpected empty',empty)
    assert not edge,(name,'edge',edge)
    assert len(set(hashes))==len(frames),(name,'duplicate')
    atlas=Image.new('RGBA',(size*4,size*rows))
    for i,im in enumerate(frames):atlas.paste(im,((i%4)*size,(i//4)*size))
    atlas.save(ART/(name+'-sheet.png'))
    contact=Image.new('RGB',(size*4,(size+22)*rows),(23,36,41));d=ImageDraw.Draw(contact)
    for i,im in enumerate(frames):
        at=((i%4)*size,(i//4)*(size+22));contact.paste(im,at,im)
        d.text((at[0]+5,at[1]+size+2),f'{i:02d}'+(' CLEAR' if i in empty else ''),font=font,fill=(235,216,165))
    contact.save(DOC/(name+'-contact.png'))
    groups[name]=frames;scales[name]=scale
    qa[name]={'count':len(frames),'unique':len(set(hashes)),'size':[size,size],'bounds':bounds,'empty_frames':empty,'edge_touch':edge,'uniform_source_scale':scale}

# Ground light derives only from the generated aura, projected to the existing 46x12 floor-light footprint.
groups['floor_glow']=[]
for i,im in enumerate(groups['glow']):
    out=Image.new('RGBA',(96,96));out.paste(im.resize((92,24),Image.Resampling.NEAREST),(2,36))
    out.save(ART/f'floor_glow_{i:02d}.png');groups['floor_glow'].append(out)
groups['idle'][0].save(ART/'icon.png')
floor_hashes=[hashlib.sha256(im.tobytes()).hexdigest() for im in groups['floor_glow']]
assert len(set(floor_hashes))==12
qa['floor_glow']={'count':12,'unique':12,'size':[96,96],'derived_from':'glow, nearest projection to 92x24 floor light','empty_frames':[],'edge_touch':[]}

duration=[40,40,50,50,50,50,70,50]
manifest={'schema':1,'id':'ryo_pouch','status':'art_handoff','production_bound':False,
 'generator':'built-in image_gen','pixellab_generation_used':False,
 'camera':'elevated three-quarter front/SE, same nondirectional pickup presentation as gourds',
 'texture_filter':'nearest','baked_floor_or_shadow':False,'layers':{},
 'presentation_reference':{'float_height':56,'bob_px':4,'bob_radians_per_second':2.3,'pulse_radians_per_second':3.1,'glow_scale':[1.25,1.55],'glow_rotation_radians_per_second':0.35,'body_scale':1.0,'floor_radii':[46,12]},
 'collection_reference':{'contact_end_s':0.08,'burst_end_s':0.18,'warp_end_s':0.35,'absorb_end_s':0.45,'heal_visual_end_s':0.55,'label_end_s':1.25,'visible_body_end_s':0.35,'frame_duration_ms':duration,'terminal_clear_frame':7,'body_squash_and_shrink_baked':True,'world_travel_baked':False,'integration':'Use authored collect body with position-only travel toward live chest; suppress duplicate procedural body scaling. Alternatively existing GourdPickupFx may keep using idle body with its own transforms. Aki owns integration and currency amount.'}}
for name,frames in groups.items():
    prefix='gourd' if name=='idle' else name
    seq=list(range(len(frames)))
    if name=='ember':seq+=list(range(len(frames)-2,0,-1))
    manifest['layers'][name]={'frames':[f'{prefix}_{i:02d}.png' for i in range(len(frames))],'playback_order':seq,'frame_size':list(frames[0].size),'anchor':[frames[0].width//2,frames[0].height//2],'fps':14 if name=='idle' else 12 if name!='collect' else 20,'loop':name!='collect','blend':'normal' if name in ['idle','collect'] else 'add'}
    if name=='collect':manifest['layers'][name]['frame_duration_ms']=duration
manifest['sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ART.glob('*.png'))}
(ART/'ryo_pouch.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(DOC/'asset-qa.json').write_text(json.dumps(qa,indent=2)+'\n',encoding='utf-8')

# Data only: no nodes, scripts, pickup registration or currency behavior.
paths=[]
for layer in manifest['layers'].values():paths.extend(layer['frames'])
paths=list(dict.fromkeys(paths));ids={p:str(i+1) for i,p in enumerate(paths)}
tres=f'[gd_resource type="SpriteFrames" load_steps={len(paths)+1} format=3]\n\n'
for p in paths:tres+=f'[ext_resource type="Texture2D" path="res://assets/pickups/ryo_pouch/{p}" id="{ids[p]}"]\n'
tres+='\n[resource]\nanimations = [\n'
tracks=[]
for name,layer in manifest['layers'].items():
    items=[]
    for i in layer['playback_order']:
        unit=duration[i]/50.0 if name=='collect' else 1.0
        items.append('{"duration": '+str(unit)+', "texture": ExtResource("'+ids[layer['frames'][i]]+'")}')
    tracks.append('{"frames": ['+', '.join(items)+'], "loop": '+str(layer['loop']).lower()+', "name": &"'+name+'", "speed": '+str(layer['fps'])+'}')
tres+=',\n'.join(tracks)+'\n]\n'
(ART/'animations.tres').write_text(tres,encoding='utf-8')
(ART/'additive.tres').write_text('[gd_resource type="CanvasItemMaterial" format=3]\n\n[resource]\nblend_mode = 1\nlight_mode = 1\n',encoding='utf-8')
print(json.dumps({k:{'count':v['count'],'unique':v['unique'],'empty':v['empty_frames']} for k,v in qa.items()}))
