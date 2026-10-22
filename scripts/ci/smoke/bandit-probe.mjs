import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
// Level 1 Bandit robber smoke: the Bandit starts far away and patrolling; the player walks to it through
// the choke gap with real key presses; it must notice, chase, threaten (robber line) and attack.
const arg=n=>process.argv[process.argv.indexOf('--'+n)+1];
const dir=arg('out-dir');mkdirSync(dir,{recursive:true});
const remote=process.argv.includes('--base-url');
const server=remote?null:await startStaticServer(arg('serve-dir'),{port:0});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const samples=[];const state=()=>page.evaluate(()=>({...window.__SHINOBI_STATE__}));
const wait=ms=>new Promise(r=>setTimeout(r,ms));
let code=1;
try{
 await page.goto((remote?arg('base-url'):server.url)+'?camera=close');
 await page.waitForFunction(()=>window.__SHINOBI_READY__===true,{timeout:90000});
 const first=await state();
 samples.push(first);
 const startDist=Math.hypot(first.bandit_x-first.x,first.bandit_y-first.y);
 for(let i=0;i<25;i++){samples.push(await state());await wait(120)}
 const patrolling=await state();
 await page.screenshot({path:dir+'/01-far-patrol.png'});
 const waypoints=[[800,60],[1020,40],[1040,-130]];
 let wp=0,shot={notice:false,approach:false,threaten:false,attack:false};
 await page.keyboard.down('ShiftLeft');
 const held=new Set();
 const hold=async keys=>{for(const k of [...held])if(!keys.includes(k)){await page.keyboard.up(k);held.delete(k)}for(const k of keys)if(!held.has(k)){await page.keyboard.down(k);held.add(k)}};
 const t0=Date.now();
 while(Date.now()-t0<90000){
  const s=await state();samples.push(s);
  const st=s.bandit_state;
  if(st==='NOTICE'&&!shot.notice){shot.notice=true;await page.screenshot({path:dir+'/02-notice.png'})}
  if(st==='APPROACH'&&!shot.approach){shot.approach=true;await page.screenshot({path:dir+'/03-approach.png'})}
  if(st==='THREATEN'&&!shot.threaten){shot.threaten=true;await page.screenshot({path:dir+'/04-threaten.png'})}
  if(st==='ATTACK'&&!shot.attack){shot.attack=true;await page.screenshot({path:dir+'/05-attack.png'})}
  if(['NOTICE','APPROACH','THREATEN','ATTACK','REPOSITION','RETREAT'].includes(st)){await hold([]);}
  else if(wp<waypoints.length){
   const [tx,ty]=waypoints[wp];const dx=tx-s.x,dy=ty-s.y;
   if(Math.hypot(dx,dy)<45){wp++;continue}
   const keys=[];if(Math.abs(dx)>20)keys.push(dx>0?'KeyD':'KeyA');if(Math.abs(dy)>20)keys.push(dy>0?'KeyS':'KeyW');
   await hold(keys);
  } else await hold([]);
  if(shot.attack&&samples.some(x=>x.bandit_swings>=1)&&Date.now()-t0>20000&&samples[samples.length-1].bandit_swings>=2)break;
  if(shot.attack&&Date.now()-t0>60000)break;
  await wait(100);
 }
 await hold([]);await page.keyboard.up('ShiftLeft');
 const last=await state();
 await page.screenshot({path:dir+'/06-end.png'});
 const seen=n=>samples.some(s=>s.bandit_state===n);
 const checks={
  far_at_start:startDist>1000,
  level_1:last.bandit_level===1,
  patrolling_at_start:patrolling.bandit_state==='PATROL'&&seen('PATROL'),
  patrol_moves:Math.hypot(patrolling.bandit_x-first.bandit_x,patrolling.bandit_y-first.bandit_y)>5||samples.some(s=>s.bandit_animation==='run'),
  noticed:seen('NOTICE'),
  chased:seen('APPROACH'),
  threatened:seen('THREATEN'),
  robber_line:samples.some(s=>s.bandit_taunt===true),
  attacked:samples.some(s=>s.bandit_swings>=1),
  intent_exposed:samples.some(s=>typeof s.bandit_intent==='string'&&s.bandit_intent.length>0),
  run_seen:samples.some(s=>s.bandit_animation==='run'),
  idle_seen:samples.some(s=>s.bandit_animation==='idle'),
  never_stuck:last.bandit_stuck===0,
  no_errors:errors.length===0};
 const extra={hits_landed:last.bandit_hits_landed,player_hits_taken:last.player_hits_taken,flickers:last.bandit_flickers,swings:last.bandit_swings,log:last.bandit_log,statesSeen:[...new Set(samples.map(s=>s.bandit_state))]};
 writeFileSync(dir+'/bandit-probe.json',JSON.stringify({checks,extra,errors,samples},null,2));console.log(JSON.stringify(checks));console.log(JSON.stringify(extra));
 code=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
process.exitCode=code;
