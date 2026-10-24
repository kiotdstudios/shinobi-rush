"""Technical registration/palette export of PixelLab assets; original audio synthesis."""
from pathlib import Path
import hashlib,json,wave
import numpy as np
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'assets/environment/ashen_fire'
FX=ROOT/'assets/vfx/ashen_fire'
DOC=Path(__file__).parent
NAMES=['tall_pillar','short_brazier','tripod_brazier','wall_brazier','fire_pit']
BOWLS=[[64,35],[80,50],[88,61],[47,91],[96,66]]
SCALES=[.65,.75,1.,.45,1.15]
FOOTPRINTS=[[42,22],[92,38],[100,44],[64,34],[130,50]]

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def wav(path,data,rate=44100):
    assert np.max(np.abs(data))<1
    with wave.open(str(path),'wb') as stream:
        stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(rate)
        stream.writeframes((data*32767).astype('<i2').tobytes())

def main():
    palette=json.loads((BASE/'source/stone-palette.json').read_text())['palette']
    pal=np.array([tuple(bytes.fromhex(c[1:])) for c in palette],dtype=np.int32)
    records=[];contact=Image.new('RGB',(1100,440),'#202833')
    for i,name in enumerate(NAMES):
        source=BASE/f'source/{name}-raw.png' if name!='wall_brazier' else BASE/'source/wall_brazier-clean.png'
        image=Image.open(source).convert('RGBA');a=np.array(image)
        visible=a[:,:,3]>127
        rgb=a[:,:,:3].astype(np.int32)
        nearest=((rgb[:,:,None,:]-pal)**2).sum(3).argmin(2)
        a[:,:,:3]=pal[nearest];a[:,:,3]=np.where(visible,255,0)
        a[~visible,:3]=0
        image=Image.fromarray(a);assert image.getbbox()
        foot=[image.width//2,image.getbbox()[3]-1]
        path=BASE/f'props/{name}.png';image.save(path)
        contact.paste(image,(i*220+(220-image.width)//2,315-image.height),image)
        ImageDraw.Draw(contact).text((i*220+10,330),name,fill='#c2c6d0')
        records.append({'id':name,'path':'res://'+path.relative_to(ROOT).as_posix(),'size':list(image.size),
                        'foot_anchor':foot,'bowl_anchor':BOWLS[i],'flame_scale':SCALES[i],
                        'footprint':FOOTPRINTS[i],'sha256':sha(path)})
    contact.save(DOC/'fixture-contact.png')
    atlas=Image.new('RGBA',(512,480));frames=[]
    for i in range(12):
        source=Image.open(BASE/f'source/flame-{i:02d}.png').convert('RGBA')
        a=np.array(source);a[:,:,3]=np.where(a[:,:,3]>127,255,0);source=Image.fromarray(a)
        bbox=source.getbbox();assert bbox
        ys,xs=np.where(a[:,:,3]>0)
        base_x=int(np.median(xs[ys>=bbox[3]-3]))
        frame=Image.new('RGBA',(128,160))
        frame.alpha_composite(source,(64-base_x,144-(bbox[3]-1)))
        assert frame.getbbox()[0]>=1 and frame.getbbox()[2]<=127 and frame.getbbox()[1]>=1
        atlas.alpha_composite(frame,(i%4*128,i//4*160))
        frames.append(hashlib.sha256(frame.tobytes()).hexdigest())
    assert len(set(frames))==12,'Need12unique flame poses'
    atlas.save(FX/'flame_atlas.png')
    atlas.save(DOC/'flame-contact.png')
    Image.open(BASE/'source/coals-raw.png').convert('RGBA').save(FX/'coals.png')
    # Smoke is selected explicitly after PixelLab candidate review.
    smoke=Image.open(BASE/'source/smoke-selected.png').convert('RGBA')
    smoke.save(FX/'smoke.png')
    audio=ROOT/'assets/audio/ashen_fire';audio.mkdir(parents=True,exist_ok=True)
    rate=44100;n=rate*4;t=np.arange(n)/rate;rng=np.random.default_rng(4813)
    f=np.fft.rfftfreq(n,1/rate)
    spectrum=(rng.normal(size=len(f))+1j*rng.normal(size=len(f)))/np.maximum(f,50)**.55
    spectrum[(f<45)|(f>7000)]=0
    bed=np.fft.irfft(spectrum,n=n);bed=bed/np.max(np.abs(bed))*.30
    bed*=.8+.12*np.sin(2*np.pi*.5*t)+.06*np.sin(2*np.pi*1.25*t)
    wav(audio/'fire-bed.wav',bed)
    for i in range(3):
        tt=np.arange(int(rate*.16))/rate
        noise=rng.normal(size=len(tt));noise=np.convolve(noise,[1.,-.65],mode='same')
        envelope=np.exp(-tt/(.013+i*.007))*(1-np.exp(-tt/.0007))
        pop=noise*envelope
        pop+=np.sin(2*np.pi*(650+i*210)*tt)*np.exp(-tt/.008)*.15
        pop=pop/np.max(np.abs(pop))*.75
        wav(audio/f'crackle-{i}.wav',pop)
    manifest={'schema':'shinobi_ashen_fire_v1','status':'technical_validation','source_tool':'PixelLab Pixflux/Pixen; transparent wall cleanup via free PixelLab pixel tools',
              'stone_palette':palette,'palette_sources':json.loads((BASE/'source/stone-palette.json').read_text())['sources'],
              'fixtures':records,'flame':{'path':'res://assets/vfx/ashen_fire/flame_atlas.png','frames':12,'columns':4,'rows':3,
                                       'frame_size':[128,160],'foot_anchor':[64,144],'fps':12,'unique_hashes':frames,
                                       'source_generated_frames':13,'endpoint_policy':'omit final pinned closure key'},
              'smoke':{'path':'res://assets/vfx/ashen_fire/smoke.png','max_particles':18,'lifetime_seconds':3.2},
              'embers':{'max_particles':24,'pop_burst':6,'lifetime_seconds':[.5,1.4]},
              'audio':{'ambient':'res://assets/audio/ashen_fire/fire-bed.wav','crackles':[f'res://assets/audio/ashen_fire/crackle-{i}.wav' for i in range(3)],
                       'provenance':'Original deterministic NumPy synthesis, not stock audio or PixelLab audio',
                       'synchronization':'one pop event triggers light flash, spark burst and one crackle player together'}}
    (BASE/'ashen-fire.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS five transparent fixtures in15sampled stone colors;12unique registered flames;4original PCM audio clips')

if __name__=='__main__':main()
