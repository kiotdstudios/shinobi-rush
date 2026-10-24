const root=new URL('../../premium_combat_poc/',location.href),el=id=>document.getElementById(id);
async function json(url){const r=await fetch(url);if(!r.ok)throw Error(`${url}: ${r.status}`);return r.json();}
const manifest=await json(new URL('premium_combat.art.json',root));
const vmurl=new URL(manifest.vfx.manifest,root),vm=await json(vmurl),images=new Map();
async function load(url){const k=String(url);if(!images.has(k))images.set(k,new Promise((ok,fail)=>{const im=new Image();im.onload=()=>ok(im);im.onerror=()=>fail(Error('Missing '+k));im.src=k;}));return images.get(k);}
const runtimeManifest=await json(new URL('runtime-chain.art.json',root)),profiles={};
for(const [profile,data] of Object.entries({authored:manifest,runtime:runtimeManifest})){
 const loaded={};for(const [name,a] of Object.entries(data.animations))loaded[name]={...a,name,frames:await Promise.all(a.frames.map(async f=>({...f,image:await load(new URL(f.body_frame,root))})))};
 profiles[profile]=loaded;
}
let clips=profiles.runtime;
for(const name of Object.keys(clips)){const o=document.createElement('option');o.value=name;o.textContent=name;el('action').append(o);}
const weapons={},effects={};
for(const [id,s] of Object.entries(manifest.weapons))weapons[id]={...s,image:await load(new URL(s.texture,root))};
for(const [id,s] of Object.entries(vm.effects))effects[id]={...s,images:await Promise.all(s.frames.map(p=>load(new URL(p,vmurl))))};
let selected=Object.values(clips),time=0,last=performance.now(),playing=true,current=null;
const duration=()=>selected.reduce((sum,a)=>sum+a.duration_ms,0);
function setPlay(on){playing=on;el('pause').textContent=on?'Pause':'Play';}
el('pause').onclick=()=>setPlay(!playing);el('restart').onclick=()=>{time=0;};
el('action').onchange=()=>{selected=el('action').value==='sequence'?Object.values(clips):[clips[el('action').value]];time=0;el('scrub').max=duration();};
el('profile').onchange=()=>{clips=profiles[el('profile').value];el('action').onchange();};
el('scrub').oninput=()=>{setPlay(false);time=Number(el('scrub').value);};
el('step').onclick=()=>{setPlay(false);if(current)time=(current.globalStart+current.frame.start_ms+current.frame.duration_ms+0.001)%duration();};
function zoom(){for(const id of Object.keys(weapons))el(id).style.width=`${256*Number(el('zoom').value)}px`;}
el('zoom').onchange=zoom;zoom();el('scrub').max=duration();
function locate(t){let local=t,globalStart=0;for(const a of selected){if(local<a.duration_ms){const frame=a.frames.find(f=>local<f.start_ms+f.duration_ms)||a.frames.at(-1);return {a,frame,local,globalStart};}local-=a.duration_ms;globalStart+=a.duration_ms;}return locate(0);}
function mount(ctx,im,point,pivot,angle){ctx.save();ctx.translate(64+point[0],48+point[1]);ctx.rotate(angle*Math.PI/180);ctx.drawImage(im,-pivot[0],-pivot[1]);ctx.restore();}
function fx(ctx,t){let start=0;for(const a of selected){if(a.contact_ms!==undefined){const age=t-start-a.contact_ms,index=Math.floor(age*24/1000),contact=a.frames.find(f=>f.contact);
 if(age>=0&&index<effects[a.trail_effect].images.length){mount(ctx,effects[a.trail_effect].images[index],contact.right_hand_px,[64,64],contact.weapon_angle_deg);
 if(index<effects.hit_spark.images.length){const rad=contact.weapon_angle_deg*Math.PI/180;const p=[contact.right_hand_px[0]+32*Math.cos(rad),contact.right_hand_px[1]+32*Math.sin(rad)];mount(ctx,effects.hit_spark.images[index],p,[64,64],0);}}
 }start+=a.duration_ms;}}
function draw(id,state,t){const ctx=el(id).getContext('2d'),f=state.frame,w=weapons[id];ctx.clearRect(0,0,256,224);ctx.imageSmoothingEnabled=false;
 const sword=()=>mount(ctx,w.image,f.right_hand_px,w.grip_pivot_px,f.weapon_angle_deg);
 if(el('weapon').checked&&f.weapon_layer==='behind')sword();
 if(el('body').checked)ctx.drawImage(f.image,64,48);
 if(el('weapon').checked&&f.weapon_layer==='front'){sword();if(el('body').checked){const [x,y,w,h]=f.hand_occlusion_rect;ctx.drawImage(f.image,x,y,w,h,64+x,48+y,w,h);}}
 if(el('vfx').checked)fx(ctx,t);
 if(el('anchors').checked){ctx.fillStyle='#61e1ff';ctx.fillRect(124,164,9,1);ctx.fillRect(128,160,1,9);ctx.fillStyle='#ff6c89';ctx.fillRect(63+f.right_hand_px[0],47+f.right_hand_px[1],3,3);}
}
window.premiumCombatSeek=(ms)=>{setPlay(false);time=Math.max(0,ms)%duration();};
Object.defineProperty(window,'premiumCombatState',{get:()=>current?{ready:true,profile:el('profile').value,animation:current.a.name,frame:current.frame.frame_index,phase:current.frame.phase,local_ms:current.local,time_ms:time%duration(),playing,speed:Number(el('speed').value),loaded_images:images.size,body_by_weapon:Object.fromEntries(Object.keys(weapons).map(id=>[id,current.frame.body_frame])),duration_ms:duration(),events:current.a.events,close_scale:manifest.close_camera.screen_scale}:null});
el('status').textContent=`Loaded ${images.size} unique transparent assets · two timing profiles · SE · independent 24FPS effects. Runtime-chain profile follows merged Aki baseline; gameplay adapter pending.`;
function tick(now){if(playing)time+=Math.min(now-last,100)*Number(el('speed').value);last=now;const t=time%duration();current=locate(t);const {a,frame:f,local}=current;el('scrub').value=t;
 const events=a.events.filter(e=>e.time_ms<=local).map(e=>e.name).join(' · ');
 el('readout').textContent=`${(t/1000).toFixed(3)}s / ${(duration()/1000).toFixed(3)}s · ${a.name} · ${f.phase} · pose ${f.frame_index+1}/${a.frame_count} · hold ${f.duration_ms.toFixed(1)}ms · ${Number(el('speed').value)}×\n${events}`;
 for(const id of Object.keys(weapons))draw(id,current,t);requestAnimationFrame(tick);}
requestAnimationFrame(tick);
