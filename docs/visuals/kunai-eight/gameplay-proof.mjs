import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const out=process.env.KUNAI_OUT||'build/kunai-eight-gameplay';mkdirSync(out,{recursive:true});
const server=process.env.KUNAI_URL?null:await startStaticServer(process.env.KUNAI_DIR||'../kunai-eight-final-web',{port:0});
const browser=await chromium.launch({headless:true}),errors=[],samples=[],attacks=[];
try {
 const p=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
 p.on('pageerror',e=>errors.push(String(e)));p.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
 await p.goto((process.env.KUNAI_URL||server.url)+'?kunai_inspect=1');
 await p.waitForFunction(()=>window.__KUNAI_GAME__?.ready&&window.__SHINOBI_READY__,null,{timeout:120000});
 const state=()=>p.evaluate(()=>({visual:{...window.__KUNAI_GAME__},game:{...window.__SHINOBI_STATE__}}));
 await p.locator('canvas').click({position:{x:640,y:350}});
 for(const [direction,keys] of [['S',['KeyS']],['SE',['KeyS','KeyD']],['E',['KeyD']],['NE',['KeyW','KeyD']],['N',['KeyW']],['NW',['KeyW','KeyA']],['W',['KeyA']],['SW',['KeyS','KeyA']]]) {
  for(const k of keys)await p.keyboard.down(k);await p.waitForTimeout(140);await p.keyboard.down('KeyJ');
  const handle=await p.waitForFunction(()=>{const v=window.__KUNAI_GAME__;return v.weapon&&v.animation==='light1'?{visual:{...v},game:{...window.__SHINOBI_STATE__}}:false},null,{timeout:3000,polling:10});
  const s=await handle.jsonValue();attacks.push(s);assert.equal(s.visual.direction,direction);assert.equal(s.visual.animation,'light1');assert.equal(s.visual.fallback,false);
  await p.screenshot({path:`${out}/player-${direction}.png`});await p.keyboard.up('KeyJ');for(const k of keys)await p.keyboard.up(k);
  await p.waitForFunction(()=>window.__KUNAI_GAME__.weapon===false,null,{timeout:4000});
 }
 // Traverse the existing collision gap with real movement; no teleport or hidden state writes.
 const held=new Set();
 const hold=async keys=>{for(const k of [...held])if(!keys.includes(k)){await p.keyboard.up(k);held.delete(k)}for(const k of keys)if(!held.has(k)){await p.keyboard.down(k);held.add(k)}};
 const waypoints=[[800,60],[1020,40],[1040,-130]];let wp=0;const seen=new Set();
 await p.keyboard.down('ShiftLeft');const start=Date.now();
 while(Date.now()-start<90000) {
  const s=await state();samples.push(s);const st=s.game.bandit_state;
  if(s.visual.bandit_weapon&&['light1','light2'].includes(s.visual.bandit_animation)) {
   const a=s.visual.bandit_animation;if(!seen.has(a)){seen.add(a);await p.screenshot({path:`${out}/bandit-${a}.png`})}
  }
  if(seen.size===2)break;
  if(['NOTICE','APPROACH','THREATEN','ATTACK','REPOSITION','RETREAT'].includes(st))await hold([]);
  else if(wp<waypoints.length) {
   const [x,y]=waypoints[wp],dx=x-s.game.x,dy=y-s.game.y;
   if(Math.hypot(dx,dy)<45){wp++;continue}
   const keys=[];if(Math.abs(dx)>20)keys.push(dx>0?'KeyD':'KeyA');if(Math.abs(dy)>20)keys.push(dy>0?'KeyS':'KeyW');await hold(keys);
  } else await hold([]);
  await p.waitForTimeout(60);
 }
 await hold([]);await p.keyboard.up('ShiftLeft');
 writeFileSync(`${out}/gameplay.json`,JSON.stringify({attacks,banditSeen:[...seen],samples,errors},null,2));
 assert.equal(seen.size,2,'bandit AI displays both actual kunai swings');assert.deepEqual(errors,[]);
 console.log('PASS: real-input player attacks in all 8 headings, weapon cleanup, actual bandit AI two-swing kunai attacks; no browser errors');
} finally {await browser.close();if(server)await server.close()}
