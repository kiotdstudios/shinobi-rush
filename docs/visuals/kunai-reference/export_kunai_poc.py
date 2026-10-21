"""Deterministic export/compositing of generated art; does not draw body or weapon art."""
from pathlib import Path
from PIL import Image,ImageDraw
import math,json,hashlib

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'assets/characters/player/kunai_poc'
OUT=Path(__file__).resolve().parent
RAW=ROOT/'assets/characters/player/source/kunai-thrust-se-v1/raw.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def build():
    reference=Image.open(ROOT/'assets/characters/player/sprites/production/idle/SE_000.png').convert('RGBA')
    colors=sorted(set((r,g,b) for r,g,b,a in reference.get_flattened_data() if a==255))
    palette=Image.new('RGB',(len(colors),1));palette.putdata(colors)
    palette=palette.quantize(colors=min(64,len(colors)),dither=Image.Dither.NONE)
    raw=Image.open(RAW).convert('RGBA');assert raw.size==(1536,1024)
    old_hands=[(65,70),(45,59),(98,68),(110,68),(57,65),(66,71)]
    hands=[]
    for n,hand in enumerate(old_hands):
        x=n%3*512;y=n//3*512
        cell=raw.crop((x,y,x+512,y+512)).resize((128,128),Image.Resampling.NEAREST)
        alpha=cell.getchannel('A').point(lambda v:255 if v>=128 else 0)
        rgb=cell.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');rgb.putalpha(alpha)
        registered=Image.new('RGBA',(128,128));registered.alpha_composite(rgb,(0,-3 if n<3 else -1))
        # One shared clip scale matches the104px approved standing figure; no per-frame bbox fit.
        body=Image.new('RGBA',(128,128));body.alpha_composite(registered.resize((123,123),Image.Resampling.NEAREST),(2,5))
        p=BASE/f'body/SE_{n:03}.png';p.parent.mkdir(parents=True,exist_ok=True);body.save(p)
        hands.append([round(hand[0]*123/128+2),round(hand[1]*123/128+5)])
    spec=json.loads((ROOT/'assets/weapons/kunai/kunai.art.json').read_text())
    weapon=Image.open(ROOT/'assets/weapons/kunai'/spec['texture']).convert('RGBA')
    angles=[135,-150,15,25,115,135];holds=[125/3,125/3,100/3,100/3,75,75]
    frames=[];previews=[];close=[];contact=Image.new('RGB',(1152,816),(35,46,58));t=0
    for n,(hand,angle,hold) in enumerate(zip(hands,angles,holds)):
        p=BASE/f'body/SE_{n:03}.png';body=Image.open(p).convert('RGBA')
        assert body.getpixel(tuple(hand))[3]==255,(n,hand)
        assert body.size==(128,128) and set(body.getchannel('A').get_flattened_data())<={0,255}
        stage=Image.new('RGBA',(192,192));stage.alpha_composite(body,(32,32))
        rad=math.radians(angle);c,s=math.cos(rad),math.sin(rad);hx,hy=[a+32 for a in hand];px,py=spec['grip_pivot_px']
        blade=weapon.transform((192,192),Image.Transform.AFFINE,(c,s,px-c*hx-s*hy,-s,c,py+s*hx-c*hy),Image.Resampling.NEAREST)
        stage.alpha_composite(blade);x,y=hand;stage.alpha_composite(body.crop((x-2,y-2,x+3,y+3)),(x+30,y+30))
        box=stage.getbbox();assert 0<box[0]<box[2]<192 and 0<box[1]<box[3]<192
        frame=dict(frame_index=n,body_frame=f'body/SE_{n:03}.png',body_sha256=sha(p),right_hand_px=hand,
            weapon_angle_deg=angle,weapon_layer='front',hand_occlusion_rect=[x-2,y-2,5,5],start_ms=t,duration_ms=hold,
            phase='startup' if n<2 else 'active' if n<4 else 'recovery',contact=n==2)
        frames.append(frame);t+=hold
        panel=Image.new('RGB',(384,408),(35,46,58));display=stage.resize((384,384),Image.Resampling.NEAREST)
        panel.paste(display,(0,24),display);d=ImageDraw.Draw(panel)
        d.text((8,6),f'{n} / {frame["phase"]} / {hold:.1f}ms'+(' CONTACT' if n==2 else ''),fill='#ffd17b')
        previews.append(panel);contact.paste(panel,(n%3*384,n//3*408))
        close_panel=Image.new('RGB',(233,265),(35,46,58));small=stage.resize((233,233),Image.Resampling.NEAREST)
        close_panel.paste(small,(0,32),small);cd=ImageDraw.Draw(close_panel)
        cd.text((6,3),f'{n} / {frame["phase"]} / source {frame["start_ms"]:.1f}ms',fill='#ffd17b')
        cd.text((6,17),'Close1.212x / HALF speed',fill='white');close.append(close_panel)
    meta=dict(schema='shinobi_kunai_body_poc_v1',id='player_se_kunai_light1_poc',status='owner_visual_review',runtime_integrated=False,
        directions=['SE'],frame_size=[128,128],body_height_px=104,foot_anchor=[64,116],fps=24,duration_ms=t,loop=False,
        default_review_speed=.5,contact_frames=[2],hitbox_active_frames=[2,3],transition_ready_frames=[4,5],
        timing_status='300ms proposal matches current light1 windows; not runtime bound',
        weapon=dict(manifest='../../../weapons/kunai/kunai.art.json',independent=True),
        source=dict(tool='built_in_image_gen',raw='../source/kunai-thrust-se-v1/raw.png',raw_sha256=sha(RAW),
            palette_reference='../sprites/production/idle/SE_000.png',
            processing='fixed nearest512-to128 extraction; binary alpha; shared approved-SE palette; row registration y-3/-1; shared123/128 clip scale and offset2,5; no per-frame bbox fit'),frames=frames)
    assert abs(t-300)<1e-6 and len({f['body_sha256'] for f in frames})==6
    assert (BASE/meta['source']['raw']).is_file() and (BASE/meta['weapon']['manifest']).is_file()
    (BASE/'kunai-light1.art.json').write_text(json.dumps(meta,indent=2)+'\n')
    contact.save(OUT/'kunai-thrust-contact.png')
    for label,durations in [('normal',[40,40,40,30,80,70]),('half',[80,90,60,70,150,150])]:
        previews[0].save(OUT/f'kunai-thrust-{label}.gif',save_all=True,append_images=previews[1:],duration=durations,loop=0,optimize=False)
    close[0].save(OUT/'kunai-thrust-close-half.gif',save_all=True,append_images=close[1:],duration=[80,90,60,70,150,150],loop=0,optimize=False)
    print('PASS6 distinct128RGBA bodies, shared104px scale, opaque sockets, separate kunai, no stage clipping,300ms action; review GIFs300/600ms')

if __name__=='__main__':build()
