"""Export approved-size native PixelLab frames without resampling or per-pose reanchoring."""
from pathlib import Path
import json, hashlib, shutil
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
DOC=Path(__file__).parent
DIRS=['S','SE','E','NE','N','NW','W','SW']
COUNTS={'hit_react':8,'knockback':12,'death':16}
jobs=json.loads((DOC/'state.json').read_text())
assert len(jobs)==48 and all(j['state']=='completed' for j in jobs),'Generation remains incomplete'
results=[]
for who,manifest_name in [('player','player_128.manifest.json'),('bandit','bandit_128.art.json')]:
    base=ROOT/f'assets/characters/{who}'
    manifest=json.loads((base/manifest_name).read_text())
    metadata={'schema':1,'character':who,'frame_size':[128,128],'foot_anchor':[64,116],
        'direction_semantics':'Actor facing; gameplay knockback vector is independent.',
        'gameplay_bound':False,'hide_weapon_layer':True,'shadow_baked':False,'animations':{}}
    for action,count in COUNTS.items():
        paths={};directions={}
        contact=Image.new('RGB',(128*5,152*8),'#263944')
        draw=ImageDraw.Draw(contact)
        for row,direction in enumerate(DIRS):
            job=next(j for j in jobs if j['character']==who and j['animation']==action and j['direction']==direction)
            source=base/'damage/source'/job['source_dir']
            original=Image.open(base/manifest['animations']['idle']['frames'][direction][0]).convert('RGBA')
            assert Image.open(source/'000.png').convert('RGBA').tobytes()==original.tobytes(),('Input identity mismatch',who,direction)
            out=base/'damage/frames'/action
            out.mkdir(parents=True,exist_ok=True)
            frame_paths=[];hashes=[];boxes=[]
            for i in range(count):
                src=source/f'{i+1:03}.png'  # index0 is the unchanged input; omit the redundant lead-in.
                image=Image.open(src)
                assert image.size==(128,128) and image.mode=='RGBA',(src,image.size,image.mode)
                box=image.getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<128 and box[3]<128,('Empty/clipped',src,box)
                assert set(image.getchannel('A').tobytes())<={0,255},('Soft/interpolated alpha',src)
                digest=hashlib.sha256(image.tobytes()).hexdigest()
                hashes.append(digest);boxes.append(box)
                target=out/f'{direction}_{i:03}.png'
                shutil.copy2(src,target)
                frame_paths.append(str(target.relative_to(base)).replace('\\','/'))
            assert len(set(hashes))==count,('Duplicate frames need review',who,action,direction)
            paths[direction]=frame_paths
            directions[direction]={'frame_count':count,'fps':24,'duration_s':count/24,'foot_anchor':[64,116],
                'impact_frame':0,'recoil_peak_frame':count//2 if action!='death' else None,
                'hitbox_active_frames':[],
                'transition_ready_frames':list(range(count-2,count)) if action!='death' else [],
                'hold_frame':count-1 if action=='death' else None,'job_id':job['job_id'],
                'source_frame_indices':list(range(1,count+1)),'frame_hashes':hashes,'alpha_bounds':boxes}
            for col,index in enumerate([0,count//4,count//2,3*count//4,count-1]):
                image=Image.open(base/frame_paths[index])
                contact.paste(image,(128*col,152*row+20),image)
                draw.text((128*col+4,152*row+3),f'{direction} / frame{index+1}',fill='white')
            results.append({'character':who,'action':action,'direction':direction,'frames':count,'unique':len(set(hashes)),'native_rgba':True,'transparent_border':True})
        manifest['animations'][action]={'fps':24,'authored_fps':24,'loop':False,'status':'owner_requested_art_review',
            'shadow_baked':False,'frames':paths}
        metadata['animations'][action]={'loop':False,'root_motion':'none; world displacement belongs to gameplay',
            'nominal_duration_s':count/24,'timing_integration':'Sample normalized progress from the existing gameplay timer; nominal art FPS does not replace hitstop/stun/respawn rules.',
            'directions':directions}
        contact.save(DOC/f'{who}-{action}-all-directions.png')
    (base/manifest_name).write_text(json.dumps(manifest,indent=2)+'\n')
    (base/'damage/damage.art.json').write_text(json.dumps(metadata,indent=2)+'\n')
(DOC/'validation.json').write_text(json.dumps({'clips':len(results),'production_frames':sum(r['frames'] for r in results),'native_frame_size':[128,128],'no_resampling':True,'results':results},indent=2)+'\n')
print(f"PASS {len(results)} clips / {sum(r['frames'] for r in results)} native frames")
