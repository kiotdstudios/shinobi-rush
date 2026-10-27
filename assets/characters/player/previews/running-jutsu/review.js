'use strict';
(async()=>{
 const root='../../study/running-jutsu/';
 const meta=await fetch(root+'jutsu_review.json').then(r=>{if(!r.ok)throw Error(r.status);return r.json()});
 const cache=new Map();
 const paths=[...new Set(meta.frames.flatMap(f=>[f.body,f.motion,f.lightning,f.dynamic_back,f.dynamic_front]).filter(Boolean))];
 await Promise.all(paths.map(path=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{cache.set(path,im);resolve()};im.onerror=()=>reject(Error(path));im.src=root+path})));
 const $=id=>document.getElementById(id);
 const state={ready:true,frame:0,playing:true,speed:1,loops:0,loaded:cache.size};window.jutsuReviewState=state;
 const contexts=['full','body'].map(id=>$(id).getContext('2d'));let time=0,last=performance.now();
 function paint(){
  const f=meta.frames[state.frame];
  for(const c of contexts){c.imageSmoothingEnabled=false;c.clearRect(0,0,192,192);c.drawImage(cache.get(f.body),32,32)}
  const c=contexts[0];
  if(f.dynamic_back&&$('lightning').checked){c.clearRect(0,0,192,192);c.drawImage(cache.get(f.dynamic_back),...f.dynamic_offset_px);c.drawImage(cache.get(f.body),32,32)}
  if(f.motion&&$('multiples').checked){const [x,y]=f.upper_registration_px;c.drawImage(cache.get(f.motion),32+x,32+y)}
  if(f.lightning&&$('lightning').checked){const [x,y]=f.lightning_hand_px;c.drawImage(cache.get(f.lightning),x,y)}
  if(f.dynamic_front&&$('lightning').checked)c.drawImage(cache.get(f.dynamic_front),...f.dynamic_offset_px);
  if($('anchors').checked)for(const ctx of contexts){ctx.fillStyle='#58e0bf';ctx.fillRect(94,148,5,1);ctx.fillRect(96,146,1,5)}
  $('clock').textContent=`${(state.frame/30).toFixed(3)}s / 1.667s · ${f.stage.replaceAll('_',' ')} · frame ${state.frame+1}/50 · sprint ${f.sprint_phase+1}/20`;
  $('scrub').value=state.frame;$('play').textContent=state.playing?'Pause':'Play';
 }
 function pause(){state.playing=false;time=state.frame*1000/30;paint()}
 $('play').onclick=()=>{state.playing=!state.playing;last=performance.now();paint()};
 $('restart').onclick=()=>{time=0;state.frame=0;last=performance.now();paint()};
 $('step').onclick=()=>{pause();state.frame=(state.frame+1)%50;time=state.frame*1000/30;paint()};
 $('scrub').oninput=e=>{state.frame=Number(e.target.value);pause()};
 $('speed').onchange=e=>{state.speed=Number(e.target.value);last=performance.now()};
 $('zoom').onchange=e=>document.documentElement.style.setProperty('--size',`${192*Number(e.target.value)}px`);
 for(const id of ['lightning','multiples','anchors'])$(id).onchange=paint;
 $('status').textContent=`Loaded ${cache.size} transparent PNGs. Two hand-sign silhouettes, two brief multiples and separate electrical effects. No idle frames.`;
 function tick(now){const elapsed=Math.min(100,now-last);last=now;if(state.playing){time+=elapsed*state.speed;if(time>=meta.duration_ms){state.loops+=Math.floor(time/meta.duration_ms);time%=meta.duration_ms}const next=Math.min(49,Math.floor(time*30/1000));if(next!==state.frame){state.frame=next;paint()}}requestAnimationFrame(tick)}
 paint();requestAnimationFrame(tick);
})().catch(e=>{document.getElementById('status').textContent='Preview failed: '+e.message;console.error(e)});
