"""Deterministic source cleanup, fixed-scale atlas extraction and layer separation only."""
from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'assets/vfx/premium_damage';DOC=ROOT/'docs/visuals/impact-vortex'
DOC.mkdir(parents=True,exist_ok=True)
qa={}
for name,rows in [('impact',3),('vortex',4)]:
    raw=Image.open(ART/'source'/(name+'-raw.png')).convert('RGBA')
    a=np.array(raw);rgb=a[:,:,:3].astype(int)
    key=(rgb[:,:,0]>rgb[:,:,1]+40)&(rgb[:,:,2]>rgb[:,:,1]+50)
    a[:,:,3][key]=0;a[:,:,:3][key]=0
    raw=Image.fromarray(a);frames=[]
    for row in range(rows):
        for col in range(4):
            cell=raw.crop((round(col*raw.width/4),round(row*raw.height/rows),round((col+1)*raw.width/4),round((row+1)*raw.height/rows)))
            scale=0.28 if name=='impact' else 0.34
            cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
            out=Image.new('RGBA',(128,128))
            pivot_y=round(cell.height*(0.5 if name=='impact' else 0.85))
            out.paste(cell,(64-cell.width//2,(64 if name=='impact' else 104)-pivot_y))
            frames.append(out)
    atlas=Image.new('RGBA',(512,128*rows))
    for i,f in enumerate(frames):atlas.paste(f,((i%4)*128,(i//4)*128))
    atlas.save(ART/(name+'.png'))
    bg=Image.new('RGBA',atlas.size,(27,42,47,255));bg.alpha_composite(atlas);bg.convert('RGB').save(DOC/(name+'-contact.png'))
    edge=[]
    for i,f in enumerate(frames):
        alpha=np.array(f)[:,:,3]
        if alpha[0].any() or alpha[-1].any() or alpha[:,0].any() or alpha[:,-1].any():edge.append(i)
    hashes=[hashlib.sha256(f.tobytes()).hexdigest() for f in frames]
    assert len(set(hashes))==len(frames),(name,'duplicate')
    assert not edge,(name,'edge',edge)
    qa[name]={'frames':len(frames),'unique':len(set(hashes)),'edge_touch_frames':edge,'size':[128,128]}
    if name=='vortex':
        a=np.array(atlas)
        # Complementary masks: lower foreground curl overlaps the log; upper volume stays behind.
        front=a.copy();back=a.copy()
        yy=np.arange(atlas.height)[:,None]%128
        front[:,:,3]=np.where(yy>=70,a[:,:,3],0)
        back[:,:,3]=np.where(yy<70,a[:,:,3],0)
        assert np.array_equal(np.maximum(front[:,:,3],back[:,:,3]),a[:,:,3])
        Image.fromarray(front).save(ART/'vortex-front.png');Image.fromarray(back).save(ART/'vortex-back.png')
        qa[name]['front_back_union_pixel_exact']=True
manifest={'schema':'shinobi_premium_damage_v1','raw_generator':'built-in image_gen','texture_filter':'nearest','shadow_baked':False,'impact':{'path':'impact.png','grid':[4,3],'frame_size':[128,128],'anchor':[64,64],'frame_duration_ms':[20,20,30,30,35,35,40,40,45,45,50,50],'impact_frames':[0,1],'damage_driven':False,'direction':'source faces E; rotate effect only to actual accepted damage velocity'},'vortex':{'path':'vortex.png','front':'vortex-front.png','back':'vortex-back.png','grid':[4,4],'frame_size':[128,128],'anchor':[64,104],'pass_delays_s':[0,.42,.84,1.26,1.88],'pass_durations_s':[.72,.72,.72,.72,1.07],'layering':'upper smoke behind existing log; lower smoke foreground; complementary masks preserve every source pixel','log_gameplay_timing':'unchanged LOG_FALL_START .48 / LOG_IMPACT 1.02 / LOG_POOF 1.88 / LOG_SMOKE_END2.95'}}
(ART/'premium-damage.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(DOC/'asset-qa.json').write_text(json.dumps(qa,indent=2)+'\n',encoding='utf-8')
print(json.dumps(qa))
