"""Compare the authored pose study with legal transitions in Aki's merged baseline."""
from pathlib import Path
from PIL import Image,ImageDraw
from copy import deepcopy
import json,subprocess
from build_proof import REPO,OUT,PREVIEW,render,matte,apply_effects,sha,write_json

def build():
    m=json.loads((OUT/'premium_combat.art.json').read_text())
    revision=subprocess.check_output(['git','rev-parse','origin/main'],cwd=REPO,text=True).strip()
    attack_source=subprocess.check_output(['git','show',revision+':scripts/combat/attack_def.gd'],cwd=REPO,text=True)
    controller=subprocess.check_output(['git','show',revision+':scripts/player/player_controller.gd'],cwd=REPO,text=True)
    # Fail if source tuning changed; don't silently present stale assumptions as current.
    for needle in ['"light1", 5, 4, 9','"light2", 6, 4, 11','"light3", 9, 5, 15','"dash_attack", 6, 5, 13']:
        assert needle in attack_source,needle
    assert 'dash_attack_late_window: float = 0.08' in controller
    assert 'elapsed <= _attack_def.combo_window' in controller
    assert 'elapsed >= _attack_def.dodge_cancel_from' in controller
    player=json.loads((REPO/'assets/characters/player/player_128.manifest.json').read_text())
    assert player['animations']['run']['fps']==12 and player['animations']['dodge']['fps']==12
    assert len(player['animations']['dodge']['frames']['SE'])==12
    p=deepcopy(m);p['id']='se_runtime_snapshot_chain';p['status']='art_review_not_runtime_integration'
    p['provenance']['gameplay_snapshot']=revision
    p['timing_status']='snapshot_compatible_review_no_hitstop_pending_aki_adapter'
    p['profile_notes']={
        'run':'Nine existing approach poses at approved12FPS:750ms.',
        'light1':'Chain at200ms, inside current150–266.667ms combo interval.',
        'light2':'Chain at216.667ms, inside current166.667–300ms combo interval.',
        'light3':'Dodge at350ms, after current333.333ms dodge-cancel boundary.',
        'dodge':'Use approved12-frame/12FPS1000ms action; dash at920ms when80ms remains.',
        'dash_attack':'Full400ms; no combo continuation.',
        'scope':'Pose/timing preview only. No enemy, collision, hitstop, movement, damage or event adapter installed.'}
    # Endpoints are elapsed milliseconds, not physics/image frame equivalences.
    cuts=dict(run=750,light1=200,light2=650/3,light3=350,dodge=920,dash_attack=400)
    for name,a in p['animations'].items():
        frames=deepcopy(a['frames'])
        if name=='run':
            frames=frames[:9]
            for f in frames:f['duration_ms']=1000/12
        if name=='dodge':
            # The approved exit pose is preserved; late-dodge branching displays it for3.333ms.
            src=REPO/'assets/characters/player/sprites/production/dodge/SE_011.png'
            f=deepcopy(frames[-1]);f.update(body_frame='../sprites/production/dodge/SE_011.png',body_sha256=sha(src),
                source_pose=11,right_hand_px=[49,80],hand_occlusion_rect=[47,78,5,5]);frames.append(f)
            for f in frames:f['duration_ms']=1000/12
        played=[];t=0
        for f in frames:
            if t>=cuts[name]-1e-6:break
            f['duration_ms']=min(f['duration_ms'],cuts[name]-t);f['start_ms']=t
            f['frame_index']=len(played);played.append(f);t+=f['duration_ms']
        assert abs(t-cuts[name])<1e-6
        a['source_action_duration_ms']=1000 if name=='dodge' else a['duration_ms']
        a['frames']=played;a['frame_count']=len(played);a['duration_ms']=t
        if 'phases_ms' in a:
            keys=['phases_ms','hitbox_active_ms','combo_window_ms','dodge_cancel_ms','transition_ready_ms']
            a['source_timing']={k:deepcopy(a[k]) for k in keys}
            a['phases_ms']={k:[v[0],min(v[1],t)] for k,v in a['phases_ms'].items() if v[0]<t}
            for key in ['combo_window_ms','dodge_cancel_ms']:
                interval=a[key];a[key]=[interval[0],min(interval[1],t)] if interval and interval[0]<t else None
            for key in ['contact_frames','hitbox_active_frames','transition_ready_frames']:
                a[key]=[i for i in a[key] if i<len(played)]
        a['events']=[e for e in a['events'] if e['time_ms']<t-1e-6]
        a['playback_exit']='combo' if name in ['light1','light2'] else 'dodge_cancel' if name=='light3' else 'late_dodge_dash' if name=='dodge' else 'complete'
        if name in ['run','dodge']:a['fps']=12
    p['sequence_policy']='Runtime snapshot legal branch demonstration; action timers and movement remain Aki-owned. Attack source phase/window endpoints describe full definitions even when playback branches early.'
    write_json(OUT/'runtime-chain.art.json',p)
    export(p)
    return p

def export(m):
    total=sum(a['duration_ms'] for a in m['animations'].values());seq=[]
    for i in range(round(total/10)):
        t=i*10;local=t
        for name,a in m['animations'].items():
            if local<a['duration_ms']:break
            local-=a['duration_ms']
        f=next((f for f in a['frames'] if local<f['start_ms']+f['duration_ms']),a['frames'][-1])
        im=render(m,f,vfx=False);start=0
        for fx in m['animations'].values():
            if 'contact_ms' in fx:apply_effects(im,fx,t-start-fx['contact_ms'])
            start+=fx['duration_ms']
        panel=Image.new('RGB',(310,310),(22,29,37));d=ImageDraw.Draw(panel)
        panel.paste(matte(im).resize((310,271),Image.Resampling.NEAREST),(0,39))
        d.text((8,4),'RUNTIME CHAIN / no hitstop or root motion',fill='#a7dafa')
        d.text((8,17),f'{name} / {f["phase"]} / pose {f["frame_index"]}',fill='white')
        d.text((8,29),f'{t/1000:.2f}s / next: {a["playback_exit"]}',fill='#ffcf70');seq.append(panel)
    for speed,label in [(1,'normal'),(.5,'half')]:
        seq[0].save(PREVIEW/f'runtime-chain-{label}.gif',save_all=True,append_images=seq[1:],duration=round(10/speed),loop=0,optimize=False)
    print(f'Runtime chain PASS: {sum(a["frame_count"] for a in m["animations"].values())} played poses, exact {total:.3f}ms; source {m["provenance"]["gameplay_snapshot"]}')

if __name__=='__main__':build()
