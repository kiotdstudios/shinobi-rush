"""Deterministic cleanup/extraction only. Raw art comes from built-in image_gen.
No generated in-betweens, painted sprites, or per-frame body resizing.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
import hashlib, json

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/environment/blightwood_waterlife'
DOC = ROOT / 'docs/visuals/waterlife'
DOC.mkdir(parents=True, exist_ok=True)
NEAREST = Image.Resampling.NEAREST

def clean(path):
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    rgb = a[:,:,:3].astype(int)
    key = (rgb[:,:,0]>185)&(rgb[:,:,2]>185)&(rgb[:,:,1]<125)&(abs(rgb[:,:,0]-rgb[:,:,2])<65)
    if "splash" in str(path) or "feet-chakra" in str(path):
        key |= (rgb[:,:,0]>rgb[:,:,1]+30)&(rgb[:,:,2]>rgb[:,:,1]+35)
    a[:,:,3][key]=0
    a[:,:,:3][key]=0
    return Image.fromarray(a)

def grid(im, cols, rows, border=0):
    return [im.crop((round(c*im.width/cols)+border,round(r*im.height/rows)+border,
                     round((c+1)*im.width/cols)-border,round((r+1)*im.height/rows)-border))
            for r in range(rows) for c in range(cols)]

def sheet(frames, cols, rows, name):
    out=Image.new('RGBA',(frames[0].width*cols,frames[0].height*rows))
    for i,f in enumerate(frames):out.paste(f,((i%cols)*f.width,(i//cols)*f.height))
    out.save(ART/(name+'.png'))
    check=Image.new('RGBA',out.size,(21,38,44,255));check.alpha_composite(out)
    check.convert('RGB').save(DOC/(name+'-contact.png'))
    return out

records={}
for name in ['splash','feet-chakra']:
    raw=clean(ART/'source'/(name+'-raw.png'))
    frames=[]
    for i,cell in enumerate(grid(raw,4,4,7 if name=='feet-chakra' else 0)):
        # Remove only white divider lines at raw grid borders; never repaint the asset.
        box=cell.getbbox(); assert box
        # Fixed shared scale, preserving relative size and animation; registration is translation only.
        scale=0.34
        scaled=cell.resize((round(cell.width*scale),round(cell.height*scale)),NEAREST)
        alpha=np.array(scaled)[:,:,3]
        if name=='splash':
            widths=(alpha>0).sum(axis=1)
            candidates=np.arange(len(widths)//2,len(widths))
            widest=candidates[np.argmax(widths[candidates])]
            ys=np.where((widths>=widths[widest]*0.8)&(np.arange(len(widths))>len(widths)//2))[0]
            anchor_y=round(float(np.median(ys)))
        else:anchor_y=scaled.getbbox()[3]-5
        frame=Image.new('RGBA',(128,128))
        frame.paste(scaled,(64-scaled.width//2,96-anchor_y))
        frames.append(frame)
    sheet(frames,4,4,name)
    records[name]={'frames':16,'frame_size':[128,128],'anchor':[64,96],'fps':24,'loop':name=='feet-chakra'}

raw=clean(ART/'source/plants-raw.png')
plants=[]
for cell in grid(raw,3,2):
    cell=cell.resize((72,72),NEAREST)
    plants.append(cell)
sheet(plants,3,2,'plants')
records['plants']={'frames':6,'frame_size':[72,72],'anchor':[36,36],'variants':['single_pad','double_pad','triple_pad','white_lotus','lilac_lotus','lotus_bud'],'motion':'subpixel accumulation, rounded bob; 0.7px sway / 0.65px heave, +/-0.018rad roll'}

raw=clean(ART/'source/frog-raw.png')
frog=[]
for i in range(16):
    row=i//4;col=i%4
    y0=round(row*raw.height/4); y1=round((row+1)*raw.height/4)
    strip=raw.crop((0,y0,raw.width,y1))
    alpha=np.array(strip)[:,:,3]
    # Extract the connected frog, including a tongue extending past the nominal cell.
    # Neighboring frogs stay separate. Shared fixed raw scale preserves body size.
    target=np.array([(col+0.5)*raw.width/4,strip.height*0.60])
    ys,xs=np.where(alpha>0)
    near=(abs(xs-target[0])<raw.width/8)&(abs(ys-target[1])<strip.height/3)
    xs=xs[near];ys=ys[near]
    at=np.argmin((xs-target[0])**2+(ys-target[1])**2)
    mask=Image.fromarray((alpha>0).astype('uint8')).copy()
    ImageDraw.floodfill(mask,(int(xs[at]),int(ys[at])),2,thresh=0)
    keep=np.array(mask)==2
    a=np.array(strip);a[:,:,3][~keep]=0
    isolated=Image.fromarray(a)
    # The anchor is under the body, not under the extended tongue.
    original_cell=isolated.crop((round(col*raw.width/4),0,round((col+1)*raw.width/4),strip.height))
    bbox=original_cell.getbbox();assert bbox, (i, int(xs[at]), int(ys[at]), isolated.getbbox())
    anchor=np.array([(col+0.5)*raw.width/4,bbox[3]-4])
    box=isolated.getbbox();assert box
    subject=isolated.crop(box)
    scale=0.24
    subject=subject.resize((round(subject.width*scale),round(subject.height*scale)),NEAREST)
    frame=Image.new('RGBA',(128,128))
    frame.paste(subject,(round(64+(box[0]-anchor[0])*scale),round(104+(box[1]-anchor[1])*scale)))
    frog.append(frame)
sheet(frog,4,4,'frog')
records['frog']={'frames':16,'frame_size':[128,128],'anchor':[64,104],'runtime_scale':0.5,'beats':{'arrival':[0,3],'settle':[4,5],'tongue':[6,10],'recovery':[11,11],'departure':[12,15]},'runtime_duration_seconds':4.8}

fly_path=ART/'source/fly-raw.png'
if fly_path.exists():
    fly=clean(fly_path);fly=fly.crop(fly.getbbox()).resize((9,7),NEAREST);fly.save(ART/'fly.png')
    records['fly']={'size':[9,7],'independent':True}

qa={}
for name,rec in records.items():
    im=Image.open(ART/(name+'.png')).convert('RGBA')
    cols,rows=(3,2) if name=='plants' else (4,4) if name!='fly' else (1,1)
    fs=grid(im,cols,rows)
    hashes=[hashlib.sha256(f.tobytes()).hexdigest() for f in fs]
    edge=[]
    for i,f in enumerate(fs):
        a=np.array(f)[:,:,3]
        if a[0].any() or a[-1].any() or a[:,0].any() or a[:,-1].any():edge.append(i)
    qa[name]={'unique_frames':len(set(hashes)),'frames':len(fs),'edge_touch_frames':edge,'alpha':True,'sha256':hashlib.sha256((ART/(name+'.png')).read_bytes()).hexdigest()}
    assert len(set(hashes))==len(fs), (name,'duplicate')
    if name!='fly':assert not edge,(name,'edge touch',edge)
manifest={'schema':'shinobi_waterlife_v1','generator':'built-in image_gen; deterministic chroma cleanup, connected component extraction, shared nearest scaling and translation','texture_filter':'nearest','grid':[72,36],'clips':records,'frog_rarity':{'denominator':1000000,'winning_integer':0,'roll_unit':'one continuous eligible water visit with a nearby lily; rearm after >=10 uninterrupted seconds dry','preview':'forced only inside isolated waterlife=review scene'}}
(ART/'waterlife.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(DOC/'asset-qa.json').write_text(json.dumps(qa,indent=2)+'\n',encoding='utf-8')
print(json.dumps(qa))
