"""Reproducible SE timing/layer proof from existing art; no generation or body repaint."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, math, shutil, hashlib, argparse

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / 'assets/characters/player/premium_combat_poc'
PREVIEW = REPO / 'assets/characters/player/previews/premium-combat-poc'
SIZE = (256, 224)
OFFSET = (64, 48)

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write_json(p, v): p.parent.mkdir(parents=True, exist_ok=True); p.write_text(json.dumps(v, indent=2)+'\n')
def copy(src, dst): dst.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(src,dst)

def assemble(source):
    old = source / 'assets/characters/player/modular_poc'
    source_m = json.loads((old/'modular_poc.json').read_text())
    weapons = source_m['weapons']
    for spec in weapons.values(): copy(old/spec['texture'],OUT/spec['texture'])
    vroot = source/'assets/vfx/combat'
    vm = json.loads((vroot/'combat_vfx.json').read_text())
    for effect in vm['effects'].values():
        for p in effect['frames']: copy(vroot/p,OUT/'vfx'/p)
    write_json(OUT/'vfx/combat_vfx.json',vm)
    m = dict(schema='shinobi_premium_combat_art_poc_v1',status='owner_visual_review',
        directions=['SE'],frame_size=[128,128],foot_anchor=[64,116],body_height_px=104,
        authored_fps=24,default_review_speed=0.5,index_base=0,
        timing_status='proposal_from_main_21324afb_pending_aki',root_motion='gameplay_owned_no_baked_translation',
        close_camera=dict(viewport=[1280,720],world_body_height=104,texture_body_height=104,
            camera_zoom=126/104,texture_scale=1,screen_scale=126/104,
            note='Source formula: CameraPreset.close_zoom(104) with loaded player manifest. SpriteActor uses native pixels, no body rescaling. Numerical camera approval remains provisional.'),
        mount_contract=source_m['mount_contract'],weapons=weapons,
        provenance=dict(modular_commit='2e5717d6e844de0a94c954a520aad131f3162873',
            gameplay_snapshot='21324afb02b639d13a5fe575bde776ab3faa0b6f',method='existing PNG reuse and timing/compositing only; no paid API calls'),
        animations={},sequence=['run','light1','light2','light3','dodge','dash_attack'])
    # Anatomical right-hand points inspected on the existing SE locomotion PNGs.
    run_hand=[(43,77),(43,78),(44,63),(43,55),(44,64),(47,71),(50,66),(56,60),
              (46,75),(44,67),(44,63),(43,55),(44,64),(47,71),(50,66),(56,60),
              (46,75),(44,67),(44,63),(43,55)]
    dodge_hand=[(47,76),(47,77),(49,76),(69,79),(68,79),(68,79),(68,79),
                (54,77),(47,70),(45,68),(44,76),(43,77)]
    def locomotion(name,indices,holds,hands):
        frames=[]
        for j,(i,hold) in enumerate(zip(indices,holds)):
            src=REPO/f'assets/characters/player/sprites/production/{name}/SE_{i:03}.png'
            hand=hands[i];body=Image.open(src).convert('RGBA')
            # Reject a socket outside opaque pixels; never silently infer a hand from a bbox.
            assert body.getpixel(hand)[3] == 255, (name,i,hand)
            frames.append(dict(frame_index=j,body_frame=f'../sprites/production/{name}/SE_{i:03}.png',
                body_sha256=sha(src),source_pose=i,right_hand_px=list(hand),weapon_angle_deg=25,
                weapon_layer='front',hand_occlusion_rect=[hand[0]-2,hand[1]-2,5,5],
                duration_ms=hold,phase='approach' if name=='run' else 'reposition',pose_role='locomotion'))
        return dict(direction='SE',frame_count=len(frames),fps=24,loop=False,frames=frames,events=[],
            duration_ms=sum(holds),source='existing approved unarmed locomotion; new proposed socket track')
    m['animations']['run']=locomotion('run',list(range(2,20)),[1000/24]*18,run_hand)
    m['animations']['dodge']=locomotion('dodge',list(range(11)),[300/11]*11,dodge_hand)
    specs=[('light1','light_attack_1',[2,3,4,5,6,7],[125/3,125/3,100/3,100/3,75,75],5,4,9,7,3),
           ('light2','light_attack_2',list(range(8)),[100,100/3,100/3]+[110/3]*5,6,4,11,8,4),
           ('light3','light_attack_3',list(range(8)),[75,75,125/3,125/3]+[62.5]*4,9,5,15,9,6)]
    for name,srcname,indices,holds,start,active,recovery,combo,cancel in specs:
        frames=[]
        for j,(i,hold) in enumerate(zip(indices,holds)):
            f=dict(source_m['animations'][srcname]['frames'][i]);f.pop('baked_reference',None)
            copy(old/f['body_frame'],OUT/f['body_frame'])
            f.update(frame_index=j,source_pose=i,duration_ms=hold)
            frames.append(f)
        m['animations'][name]=dict(direction='SE',frame_count=len(frames),fps=24,loop=False,frames=frames,
            source=f'PR33 {srcname}; retimed body/weapon pairs',trail_effect='sword_trail_heavy' if name=='light3' else 'sword_trail_light')
        attack_timing(m['animations'][name],start,active,recovery,combo,cancel)
    # Low driving silhouette from the approved dodge, then a non-neutral slash exit.
    # Deliberately labelled hybrid prototype, not a newly generated production dash.
    frames=[]
    for name,i,hold,angle in [('dodge',2,50,10),('dodge',3,50,10),('dodge',4,125/3,12),
                             ('light1',2,125/3,None),('light1',3,65,None),
                             ('light1',4,75,None),('light1',5,230/3,None)]:
        f=dict(m['animations'][name]['frames'][i]);f.update(frame_index=len(frames),duration_ms=hold,source_action=name)
        if angle is not None:f['weapon_angle_deg']=angle
        frames.append(f)
    m['animations']['dash_attack']=dict(direction='SE',frame_count=7,fps=24,loop=False,frames=frames,
        source='hybrid proof: existing SE dodge lean plus light1 cut; dedicated dash body remains production follow-up',
        trail_effect='sword_trail_light',prototype_reuse=True)
    attack_timing(m['animations']['dash_attack'],6,5,13,0,4)
    m['animations']={k:m['animations'][k] for k in m['sequence']}
    # Only safe legal transition recommendations; preview shows full recoveries for inspection.
    m['sequence_policy']='Full action durations, no idle bridge. Aki may use legal combo/cancel windows; no gameplay callbacks are installed.'
    m['vfx']=dict(manifest='vfx/combat_vfx.json',fps=24,independent=True,
        trigger='proposed hit_contact; illustrative world contact is socket + sword-axis 32px',
        event_api='adapter proposal only; Aki must confirm event names and dispatch semantics')
    write_json(OUT/'premium_combat.art.json',m)
    return m

def attack_timing(a,start,active,recovery,combo,cancel):
    start*=1000/60;active*=1000/60;recovery*=1000/60
    a.update(duration_ms=start+active+recovery,phases_ms=dict(startup=[0,start],active=[start,start+active],recovery=[start+active,start+active+recovery]),
        hitbox_active_ms=[start,start+active],contact_ms=start,
        combo_window_ms=[start+active,start+active+combo*1000/60] if combo else None,
        dodge_cancel_ms=[start+active+cancel*1000/60,start+active+recovery],
        transition_ready_ms=start+active)
    a['events']=[dict(name=n,time_ms=t) for n,t in [('attack_start',0),('hit_active',start),('hit_contact',start),
        ('recovery',start+active),('cancel_open',start+active+cancel*1000/60)]]
    t=0
    for f in a['frames']:
        f['phase']='startup' if t<start-0.001 else 'active' if t<start+active-0.001 else 'recovery'
        f['pose_role']='anticipation' if f['phase']=='startup' else 'impact extreme / omitted transition' if f['phase']=='active' else 'overshoot / transition'
        f['contact']=abs(t-start)<0.001;t+=f['duration_ms']
    assert abs(t-a['duration_ms'])<0.001,(t,a['duration_ms'])
    a['contact_frames']=[f['frame_index'] for f in a['frames'] if f['contact']]
    a['hitbox_active_frames']=[f['frame_index'] for f in a['frames'] if f['phase']=='active']
    a['transition_ready_frames']=[f['frame_index'] for f in a['frames'] if f['phase']=='recovery']
    a['cancel_window_recommendation']='Use exact dodge_cancel_ms; opening can fall inside a held image. Do not dispatch solely from frame changes.'

def transformed(im,anchor,pivot,angle):
    c=math.cos(math.radians(angle));s=math.sin(math.radians(angle));hx,hy=anchor;px,py=pivot
    return im.transform(SIZE,Image.Transform.AFFINE,(c,s,px-c*hx-s*hy,-s,c,py+s*hx-c*hy),Image.Resampling.NEAREST)

def render(m,f,weapon='katana',a=None,age=None,vfx=True):
    body=Image.open(OUT/f['body_frame']).convert('RGBA');spec=m['weapons'][weapon]
    hand=[f['right_hand_px'][j]+OFFSET[j] for j in range(2)]
    blade=transformed(Image.open(OUT/spec['texture']).convert('RGBA'),hand,spec['grip_pivot_px'],f['weapon_angle_deg'])
    im=Image.new('RGBA',SIZE)
    if f['weapon_layer']=='behind':im.alpha_composite(blade)
    im.alpha_composite(body,OFFSET)
    if f['weapon_layer']=='front':
        im.alpha_composite(blade);x,y,w,h=f['hand_occlusion_rect'];im.alpha_composite(body.crop((x,y,x+w,y+h)),(OFFSET[0]+x,OFFSET[1]+y))
    if a and vfx and age is not None:
        apply_effects(im,a,age)
    return im

def apply_effects(im,a,age):
    if 0<=age<1000/24*8:
        contact=next(f for f in a['frames'] if f.get('contact'))
        anchor=[contact['right_hand_px'][j]+OFFSET[j] for j in range(2)];angle=contact['weapon_angle_deg'];index=int(age*24/1000)
        fx=Image.open(OUT/f'vfx/frames/{a["trail_effect"]}/{index:03}.png').convert('RGBA')
        im.alpha_composite(transformed(fx,anchor,[64,64],angle))
        if index<4:
            r=math.radians(angle);p=[round(anchor[0]+32*math.cos(r)),round(anchor[1]+32*math.sin(r))]
            spark=Image.open(OUT/f'vfx/frames/hit_spark/{index:03}.png').convert('RGBA')
            im.alpha_composite(transformed(spark,p,[64,64],0))

def matte(im):
    base=Image.new('RGB',SIZE,(37,46,56));d=ImageDraw.Draw(base)
    for y in range(0,SIZE[1],8):
        for x in range(0,SIZE[0],8):
            if (x//8+y//8)%2:d.rectangle((x,y,x+7,y+7),fill=(42,53,63))
    base.paste(im,(0,0),im);return base

def export(m):
    PREVIEW.mkdir(parents=True,exist_ok=True)
    rows=[];timeline=[]
    for name,a in m['animations'].items():
        t=0;selected=[]
        for f in a['frames']:
            f['start_ms']=t
            im=render(m,f,a=a,age=t-a.get('contact_ms',1e9))
            # Every composite is an optional preview, never a replacement for the layered source.
            p=PREVIEW/f'transparent/{name}/SE_{f["frame_index"]:03}.png';p.parent.mkdir(parents=True,exist_ok=True);im.save(p)
            timeline.append((name,a,f,t));t+=f['duration_ms']
        roles=[0,1,*[i for i,f in enumerate(a['frames']) if f.get('contact')],len(a['frames'])-2,len(a['frames'])-1]
        for i in dict.fromkeys(roles):selected.append(a['frames'][i])
        rows.append((name,a,selected))
    sheet=Image.new('RGB',(5*256,len(rows)*260),(22,29,37));d=ImageDraw.Draw(sheet)
    for row,(name,a,frames) in enumerate(rows):
        for col,f in enumerate(frames):
            im=matte(render(m,f,a=a,age=f['start_ms']-a.get('contact_ms',1e9)));x=col*256;y=row*260
            sheet.paste(im,(x,y+34));d.text((x+6,y+3),f'{name} / pose {f["frame_index"]} / {f["duration_ms"]:.1f}ms',fill='white')
            d.text((x+6,y+18),f'{f["phase"]}'+(' CONTACT' if f.get('contact') else ''),fill='#ffcf70')
    sheet.save(PREVIEW/'contact-sheet.png')
    # Export samples at 100Hz so independent 24FPS VFX continue through long body holds.
    # GIF timing uses its native 10ms units; JSON remains exact in milliseconds.
    total=sum(a['duration_ms'] for a in m['animations'].values());ticks=round(total/10)
    seq=[]
    for tick in range(ticks):
        t=tick*10;local=t
        for name,a in m['animations'].items():
            if local<a['duration_ms']:break
            local-=a['duration_ms']
        f=next((f for f in a['frames'] if local<f['start_ms']+f['duration_ms']),a['frames'][-1])
        composite=render(m,f,vfx=False)
        # Effect clocks survive action transitions, exactly as in the browser harness.
        action_start=0
        for effect_action in m['animations'].values():
            if 'contact_ms' in effect_action:apply_effects(composite,effect_action,t-action_start-effect_action['contact_ms'])
            action_start+=effect_action['duration_ms']
        im=matte(composite)
        panel=Image.new('RGB',(256,256),(22,29,37));panel.paste(im,(0,30));d=ImageDraw.Draw(panel)
        d.text((7,4),f'{name} / {f["phase"]}',fill='white');d.text((7,17),f'{t/1000:.2f}s / pose {f["frame_index"]}',fill='#ffcf70');seq.append(panel)
    for speed,label in [(1,'normal'),(.5,'half')]:
        seq[0].save(PREVIEW/f'sequence-{label}.gif',save_all=True,append_images=seq[1:],duration=round(10/speed),loop=0,optimize=False)
    close=[im.resize((310,310),Image.Resampling.NEAREST) for im in seq]
    close[0].save(PREVIEW/'sequence-close-half.gif',save_all=True,append_images=close[1:],duration=20,loop=0,optimize=False)
    write_json(OUT/'premium_combat.art.json',m)
    print(f'Exported {len(timeline)} poses, {ticks} 10ms preview samples, total {total:.3f}ms')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path);args=p.parse_args()
    m=assemble(args.source.resolve()) if args.source else json.loads((OUT/'premium_combat.art.json').read_text())
    export(m)
