"""Art-only compositor: preview finished sprites and the existing pickup timing, no gameplay hooks."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import math, json
ROOT=Path(__file__).resolve().parents[2];ART=ROOT/'assets/pickups/ryo_pouch';DOC=ROOT/'docs/visuals/ryo-pouch'
font_path=next((p for p in [Path('C:/Windows/Fonts/segoeui.ttf'),Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')] if p.exists()),None)
font=ImageFont.truetype(str(font_path),15) if font_path else ImageFont.load_default()
small=ImageFont.truetype(str(font_path),12) if font_path else ImageFont.load_default()
manifest=json.loads((ART/'ryo_pouch.art.json').read_text(encoding='utf-8'))
layers={k:[Image.open(ART/p).convert('RGBA') for p in v['frames']] for k,v in manifest['layers'].items()}
timing=np.cumsum(manifest['collection_reference']['frame_duration_ms'])/1000
ground=Image.open(ROOT/'assets/environment/blightwood/ground_path/ground9_center.png').convert('RGBA')

def stamp(canvas,tex,at,scale=1.0,alpha=1.0,angle=0.0,add=False,stretch=(1.0,1.0)):
    im=tex.resize((max(1,round(tex.width*scale*stretch[0])),max(1,round(tex.height*scale*stretch[1]))),Image.Resampling.NEAREST)
    if angle:im=im.rotate(angle,resample=Image.Resampling.NEAREST,expand=True)
    x=round(at[0]-im.width/2);y=round(at[1]-im.height/2)
    if add:
        temp=Image.new('RGBA',canvas.size);temp.paste(im,(x,y))
        a=np.array(temp).astype(float);bg=np.array(canvas).astype(float)
        bg[:,:,:3]=np.minimum(255,bg[:,:,:3]+a[:,:,:3]*(a[:,:,3:4]/255)*alpha)
        canvas.paste(Image.fromarray(bg.astype('uint8')))
    else:
        if alpha<1:im.putalpha(im.getchannel('A').point(lambda p:round(p*alpha)))
        canvas.alpha_composite(im,(x,y))

def render(t):
    im=Image.new('RGBA',(640,360),(23,36,41,255))
    # Existing approved ground pixels, only composited for this art preview.
    for cx in [160,480]:
        for u in range(-3,4):
            for v in range(-2,3):
                tile=ground.copy();tile.putalpha(tile.getchannel('A').point(lambda p:round(p*.34)))
                im.alpha_composite(tile,(cx+(u-v)*36-36,270+(u+v)*18-18))
    d=ImageDraw.Draw(im);d.text((20,12),'RYO POUCH | float / gold glow / collect',font=font,fill=(247,222,164))
    d.text((90,330),'1x native art',font=small,fill=(204,216,207));d.text((420,330),'2x detail',font=small,fill=(204,216,207))
    phase='FLOAT' if t<2.15 else 'COLLECT' if t<2.70 else 'CLEAR' if t<3.60 else 'PREVIEW RESET'
    d.text((20,38),phase,font=small,fill=(164,190,181))
    clock=t
    for x,s in [(160,1.0),(480,2.0)]:
        origin=np.array([x,290-56*s],float)
        at=origin+np.array([0,round(math.sin(clock*2.3)*4)*s])
        body=layers['idle'][int(clock*14)%16]
        glow=layers['glow'][int(clock*12)%12]
        order=manifest['layers']['ember']['playback_order'];sparks=layers['ember'][order[int(clock*12)%len(order)]]
        pulse=.5+.5*math.sin(clock*3.1);opacity=1.0
        floor_alpha=.30;glow_alpha=.38+.18*pulse;glow_scale=(1.25+.30*pulse)*s
        if 2.15<=t<2.70:
            age=t-2.15
            body=layers['collect'][min(7,int(np.searchsorted(timing,age,side='right')))]
            k=max(0,min(1,(age-.18)/.17))
            target=origin+np.array([18*s,-60*s])
            at=origin+(target-origin)*(k*k)+np.array([0,-math.sin(k*math.pi)*14*s])
            floor_alpha*=max(0,1-age/.18)
            if age<.18:glow_scale*=1.3;glow_alpha=.7
            elif age<.35:glow_alpha=.4
            else:
                at=target;glow_scale=s*(.7+(age-.35)*5);glow_alpha=max(0,1-(age-.35)/.20)
            stamp(im,sparks,at,s*1.3,max(0,1-age/.55),add=True)
        elif 2.70<=t<3.60:
            opacity=0;floor_alpha=0;glow_alpha=0
        elif t>=3.60:
            opacity=min(1,(t-3.6)/.4);floor_alpha*=opacity;glow_alpha*=opacity
        stamp(im,layers['floor_glow'][int(clock*12)%12],(x,290),s,floor_alpha,add=True)
        stamp(im,glow,at,glow_scale,glow_alpha,clock*.35*180/math.pi,add=True)
        stamp(im,body,at,s,opacity)
        if opacity:stamp(im,sparks,at,s,.75*opacity,add=True)
    return im.convert('RGB')

results=[]
for name,speed,count in [('normal',1.0,100),('half-speed',.5,200)]:
    frames=[render(i/25*speed) for i in range(count)]
    # One shared palette prevents static background pixels changing colors between frames.
    palette=frames[0].quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    path=DOC/(name+'.gif');indexed[0].save(path,save_all=True,append_images=indexed[1:],duration=40,loop=0,disposal=1,optimize=False)
    gif=Image.open(path);duration=sum(gif.seek(i) or gif.info.get('duration',0) for i in range(gif.n_frames))/1000
    results.append({'name':name,'speed':speed,'frames':gif.n_frames,'duration_s':duration,'size':[640,360],'source':'art-only compositing of generated sprites and existing pickup timing; not a live pickup backend','bytes':path.stat().st_size})
for name,t in [('idle',.4),('rebound',2.27),('warp',2.42),('absorb',2.52)]:render(t).save(DOC/(name+'-preview.png'))
(DOC/'previews.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print(json.dumps(results))
