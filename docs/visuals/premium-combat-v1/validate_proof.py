"""Validate the delivered art interface, actual files, and both sword composites."""
from build_proof import OUT, PREVIEW, REPO, SIZE, render, sha
from PIL import Image
import json

m=json.loads((OUT/'premium_combat.art.json').read_text())
assert m['directions']==['SE'] and m['foot_anchor']==[64,116]
assert m['frame_size']==[128,128] and m['root_motion']=='gameplay_owned_no_baked_translation'
assert m['sequence']==['run','light1','light2','light3','dodge','dash_attack']
counts={};sockets=[];composites=0;identical=[]
for name,a in m['animations'].items():
    t=0;hashes=[]
    assert len(a['frames'])==a['frame_count']
    for i,f in enumerate(a['frames']):
        p=OUT/f['body_frame'];body=Image.open(p)
        assert body.mode=='RGBA' and body.size==(128,128),(name,i,'format')
        assert set(body.getchannel('A').get_flattened_data())<={0,255},(name,i,'alpha')
        assert sha(p)==f['body_sha256'],(name,i,'hash')
        assert f['frame_index']==i and abs(f['start_ms']-t)<1e-6
        assert f['duration_ms']>0
        x,y=f['right_hand_px'];assert body.getpixel((x,y))[3]==255,(name,i,'socket outside body')
        assert f['weapon_layer'] in ['front','behind']
        ox,oy,w,h=f['hand_occlusion_rect'];assert 0<=ox<ox+w<=128 and 0<=oy<oy+h<=128
        for weapon,spec in m['weapons'].items():
            im=render(m,f,weapon);box=im.getbbox()
            assert box and 0<box[0]<box[2]<SIZE[0] and 0<box[1]<box[3]<SIZE[1],(name,i,weapon,'clipping')
            assert set(im.getchannel('A').get_flattened_data())<={0,255}
            composites+=1
        hashes.append(sha(p));t+=f['duration_ms']
    assert abs(t-a['duration_ms'])<1e-6,(name,t,a['duration_ms'])
    duplicates=[(i,j) for i in range(len(hashes)) for j in range(i) if hashes[i]==hashes[j]]
    if duplicates:identical.append(dict(action=name,pairs=duplicates))
    if 'contact_ms' in a:
        contacts=[f for f in a['frames'] if f.get('contact')]
        assert len(contacts)==1 and abs(contacts[0]['start_ms']-a['contact_ms'])<1e-6
        assert a['phases_ms']['active']==a['hitbox_active_ms']
        assert a['hitbox_active_ms'][0]<=a['contact_ms']<a['hitbox_active_ms'][1]
        assert all(0<=e['time_ms']<=a['duration_ms'] for e in a['events'])
    counts[name]=len(a['frames'])
for weapon,spec in m['weapons'].items():
    p=OUT/spec['texture'];assert sha(p)==spec['sha256']
    im=Image.open(p);assert im.getpixel(tuple(spec['grip_pivot_px']))[3]==255
vm=json.loads((OUT/m['vfx']['manifest']).read_text())
for e in vm['effects'].values():
    for path,h in zip(e['frames'],e['sha256']):assert sha(OUT/'vfx'/path)==h
for label,target in [('normal',2580),('half',5160),('close-half',5160)]:
    gif=Image.open(PREVIEW/f'sequence-{label}.gif');ms=0
    assert gif.size==((310,310) if label=='close-half' else (256,256))
    for i in range(gif.n_frames):gif.seek(i);ms+=gif.info['duration']
    assert ms==target,(label,ms,target)
result=dict(status='PASS',poses=counts,composites=composites,source_pngs_hash_checked=True,
    body_alpha='binary 128RGBA',sockets='opaque native body pixel for every pose',
    timing='exact milliseconds; all four contacts coincide with active start',
    intentional_reuse=identical,
    visual_limitations=['Dash is an explicit reused-pose proof, not dedicated production art.',
      'Existing light3 turns toward south in the finishing extreme; owner must review SE read.',
      'No gameplay hitboxes/controller/event adapter installed; timing remains a proposal.'])
out=REPO/'docs/visuals/premium-combat-v1/proof-validation.json';out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
