from build_proof import OUT,PREVIEW,REPO,sha,render,SIZE
from PIL import Image
import json

m=json.loads((OUT/'runtime-chain.art.json').read_text());base=json.loads((OUT/'premium_combat.art.json').read_text())
count=0;total=0;timeline=[]
for name,a in m['animations'].items():
    t=0
    for i,f in enumerate(a['frames']):
        assert f['frame_index']==i and abs(f['start_ms']-t)<1e-6
        p=OUT/f['body_frame'];im=Image.open(p)
        assert im.mode=='RGBA' and im.size==(128,128) and sha(p)==f['body_sha256']
        assert im.getpixel(tuple(f['right_hand_px']))[3]==255
        assert set(im.getchannel('A').get_flattened_data())<={0,255}
        assert f['duration_ms']>0
        for weapon in m['weapons']:
            b=render(m,f,weapon).getbbox();assert 0<b[0]<b[2]<SIZE[0] and 0<b[1]<b[3]<SIZE[1]
        t+=f['duration_ms'];count+=1
    assert len(a['frames'])==a['frame_count'] and abs(t-a['duration_ms'])<1e-6
    for key in ['contact_frames','hitbox_active_frames','transition_ready_frames']:
        assert all(0<=i<a['frame_count'] for i in a.get(key,[]))
    if name in ['light1','light2']:
        lo,hi=base['animations'][name]['combo_window_ms'];assert lo<=t<=hi
    if name=='light3':assert t>=base['animations'][name]['dodge_cancel_ms'][0]
    if name=='dodge':assert abs(a['source_action_duration_ms']-t-80)<1e-6 and a['fps']==12
    if name=='run':assert a['fps']==12
    if 'contact_ms' in a:
        f=next(f for f in a['frames'] if f.get('contact'));assert abs(f['start_ms']-a['contact_ms'])<1e-6
        assert a['hitbox_active_ms'][0]<=a['contact_ms']<a['hitbox_active_ms'][1]
    timeline.append(dict(action=name,start_ms=total,played_ms=t,exit=a['playback_exit']));total+=t
assert count==44 and abs(total-2836.6666666667)<1e-6
for label,target in [('normal',2840),('half',5680)]:
    gif=Image.open(PREVIEW/f'runtime-chain-{label}.gif');ms=0
    assert gif.size==(310,310)
    for i in range(gif.n_frames):gif.seek(i);ms+=gif.info['duration']
    assert ms==target,(label,ms)
result=dict(status='PASS',source=m['provenance']['gameplay_snapshot'],played_poses=count,composites=88,
    total_ms=total,timeline=timeline,meaning='Legal branch timing in art preview; no runtime adapter, movement or hitstop simulation.')
(REPO/'docs/visuals/premium-combat-v1/runtime-chain-validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
