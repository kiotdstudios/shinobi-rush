import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
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
 for(let i=0;i<60;i++){samples.push(await state());await wait(100)}
 await page.screenshot({path:dir+'/01-pursuit.png'});
 await page.keyboard.press('KeyL');
 let streak=false;
 for(let i=0;i<120;i++){
  const s=await state();samples.push(s);
  if(!streak&&s.bandit_state==='EVADE'){await page.screenshot({path:dir+'/02-evade.png'});streak=true;}
  await wait(100);
 }
 const locked=await state();
 await page.keyboard.press('KeyL');await wait(700);const unlocked=await state();
 // Real movement approaches the bandit; select the dominant axis each short interval.
 const before=unlocked.bandit_evades;
 for(let i=0;i<35;i++){
  const s=await state();samples.push(s);let key;
  if(Math.abs(s.bandit_x-s.x)>Math.abs(s.bandit_y-s.y))key=s.bandit_x>s.x?'KeyD':'KeyA';else key=s.bandit_y>s.y?'KeyS':'KeyW';
  await page.keyboard.down(key);await wait(150);await page.keyboard.up(key);
 }
 await wait(500);const approached=await state();
 await page.screenshot({path:dir+'/03-approach.png'});
 const checks={locked:locked.target_locked===true,unlocked:unlocked.target_locked===false,evades_on_lock:locked.bandit_evades>=1,evades_on_approach:approached.bandit_evades>before,streak_seen:streak,sprint_seen:samples.some(s=>s.bandit_animation==='sprint'),run_seen:samples.some(s=>s.bandit_animation==='run'),idle_seen:samples.some(s=>s.bandit_animation==='idle'),no_errors:errors.length===0};
 writeFileSync(dir+'/bandit-probe.json',JSON.stringify({checks,errors,locked,unlocked,approached,samples},null,2));console.log(JSON.stringify(checks));code=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
process.exitCode=code;
