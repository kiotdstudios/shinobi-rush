const root = new URL('../../modular_poc/', location.href);
const manifest = await fetch(new URL('modular_poc.json', root)).then(r => { if (!r.ok) throw Error('Art manifest '+r.status); return r.json(); });
const vfxManifestUrl = new URL(manifest.vfx.manifest, root);
const vfx = await fetch(vfxManifestUrl).then(r => { if (!r.ok) throw Error('VFX manifest '+r.status); return r.json(); });
const images = new Map();
function load(url) {
  const key = String(url);
  if (!images.has(key)) images.set(key, new Promise((resolve, reject) => {
    const im = new Image(); im.onload = () => resolve(im); im.onerror = () => reject(Error('Missing art '+key)); im.src = key;
  }));
  return images.get(key);
}
const clips = {};
for (const [name, clip] of Object.entries(manifest.animations)) {
  clips[name] = await Promise.all(clip.frames.map(async frame => ({...frame, name, clip,
    body: await load(new URL(frame.body_frame, root)), baked: await load(new URL(frame.baked_reference, root))})));
}
const weapons = {};
for (const [id, spec] of Object.entries(manifest.weapons)) weapons[id] = {...spec, image: await load(new URL(spec.texture, root))};
const effects = {};
for (const [id, spec] of Object.entries(vfx.effects)) effects[id] = {...spec, images: await Promise.all(spec.frames.map(f => load(new URL(f, vfxManifestUrl))))};
const el = id => document.getElementById(id);
let sequence = Object.values(clips).flat(), time = 0, last = performance.now(), playing = true, current = 0;
const ids = ['baked','body','katana','straight_sword'];
const contexts = Object.fromEntries(ids.map(id => [id,el(id).getContext('2d')]));
el('status').textContent = `Loaded24 shared body frames,24 baked reference frames,2 sword textures and20 independent effect frames. All native PNG assets loaded.`;
function setPlaying(value) { playing = value; el('pause').textContent = playing ? 'Pause' : 'Play'; }
el('pause').onclick = () => setPlaying(!playing);
el('restart').onclick = () => { time = 0; };
el('step').onclick = () => { setPlaying(false); time = ((current+1)%sequence.length)/24; };
el('scrub').oninput = () => { setPlaying(false); time = Number(el('scrub').value)/24; };
el('action').onchange = () => { sequence = el('action').value === 'combo' ? Object.values(clips).flat() : clips[el('action').value]; el('scrub').max = sequence.length-1; time = 0; };
el('zoom').onchange = () => document.documentElement.style.setProperty('--preview-size', `${192*Number(el('zoom').value)}px`);
function drawWeapon(ctx, frame, spec) {
  const [x,y] = frame.right_hand_px;
  ctx.save(); ctx.translate(32+x,32+y); ctx.rotate(frame.weapon_angle_deg*Math.PI/180);
  ctx.drawImage(spec.image,-spec.grip_pivot_px[0],-spec.grip_pivot_px[1]); ctx.restore();
}
function drawEffects(ctx, index) {
  for (let i=0; i<=index; i++) {
    const event = sequence[i]; if (!event.clip.contact_frames.includes(event.frame_index)) continue;
    const effect = effects[event.clip.trail_effect], age = index-i; if (age >= effect.images.length) continue;
    ctx.save(); ctx.translate(32+event.right_hand_px[0],32+event.right_hand_px[1]); ctx.rotate(event.weapon_angle_deg*Math.PI/180);
    ctx.drawImage(effect.images[age],-64,-64); ctx.restore();
  }
}
function render(id, frame) {
  const ctx = contexts[id]; ctx.clearRect(0,0,192,192); ctx.imageSmoothingEnabled = false;
  const spec = weapons[id];
  if (spec && frame.weapon_layer === 'behind') drawWeapon(ctx,frame,spec);
  ctx.drawImage(id === 'baked' ? frame.baked : frame.body,32,32);
  if (spec && frame.weapon_layer === 'front') {
    drawWeapon(ctx,frame,spec); const [x,y,w,h] = frame.hand_occlusion_rect; ctx.drawImage(frame.body,x,y,w,h,32+x,32+y,w,h);
  }
  if (spec && el('trails').checked) drawEffects(ctx,current);
  if (el('anchors').checked) {
    ctx.fillStyle='#4fd4ef';ctx.fillRect(93,148,7,1);ctx.fillRect(96,145,1,7);
    ctx.fillStyle='#ff6f86';ctx.fillRect(frame.right_hand_px[0]+31,frame.right_hand_px[1]+31,3,3);
  }
}
Object.defineProperty(window,'modularPocState',{get:() => {
  const frame = sequence[current]; return {ready:true, current, animation:frame.name, frame:frame.frame_index, body:frame.body_frame,
    body_by_weapon:Object.fromEntries(Object.keys(weapons).map(id=>[id,frame.body_frame])), right_hand_px:frame.right_hand_px,
    angle:frame.weapon_angle_deg, layer:frame.weapon_layer, playing, speed:Number(el('speed').value), loaded_images:images.size,
    weapon_ids:Object.keys(weapons), directions:manifest.directions, timing_status:manifest.timing_status};
}});
function tick(now) {
  if (playing) time += Math.min((now-last)/1000,0.1)*Number(el('speed').value); last = now;
  current = Math.floor(time*24+1e-7)%sequence.length; const frame = sequence[current];
  el('scrub').value = current; el('rate').textContent = el('speed').value+'×';
  el('frame-readout').textContent = `${(time%(sequence.length/24)).toFixed(3)}s · ${frame.name} · frame${frame.frame_index+1}/8 · SE`;
  el('mount').textContent = `Grip[${frame.right_hand_px.join(', ')}] · ${frame.weapon_angle_deg}° · weapon ${frame.weapon_layer} body · proposed24FPS`;
  for (const id of ids) render(id,frame); requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
