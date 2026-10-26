import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(source)?null:await startStaticServer(source,{port:0});const base=server?.url??source;
const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const errors=[],checks={};page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__BODY_FLICKER__}));
const click=async n=>{const b=JSON.parse((await state()).buttons_json)[n];await page.mouse.click(b.x,b.y);};
const sleep=ms=>page.waitForTimeout(ms);
try{
 await page.goto(base+'?flicker=review');await page.waitForFunction(()=>window.__BODY_FLICKER__?.ready,null,{timeout:30000});checks.ready=true;
 await click('Half');checks.half=(await state()).speed===.5;
 const dirs=['S','SE','E','NE','N','NW','W','SW'];const cases=[];
 for(const dir of dirs){await click(dir);await sleep(180);const s=await state();const r=JSON.parse(s.result_json);cases.push({dir,x:s.x,y:s.y,...r});checks['direction_'+dir]=r.pool===3&&r.body_source==='dodge'&&r.direction===dir;
  if(dir==='SE'){await page.screenshot({path:out+'/travel.png'});}
  await sleep(600);
 }
 await click('Wall');await click('E');await sleep(240);const wall=await state();checks.wall_stops=wall.x<=687.1&&wall.x>640;
 const samples=JSON.parse(wall.samples_json).map(v=>typeof v==='string'?Number(v.match(/-?\d+(?:\.\d+)?/)[0]):v.x);checks.wall_samples=samples.every(x=>x<=687.1)&&wall.x<712;await page.screenshot({path:out+'/wall.png'});await sleep(600);await click('Wall');await sleep(130);
 await click('Bandit');await click('SE');await sleep(130);const bandit=await state();const br=JSON.parse(bandit.result_json);checks.bandit_reuse=bandit.bandit&&br.pool===3&&br.body_source==='sprint'&&br.direction==='SE';await page.screenshot({path:out+'/bandit.png'});await sleep(650);
 for(const dir of dirs.filter(d=>d!=='SE')){await click(dir);await sleep(130);const s=await state();const r=JSON.parse(s.result_json);checks['bandit_'+dir]=r.pool===3&&r.direction===dir;await sleep(550);}
 await click('Player');await click('Before');await click('SE');await sleep(40);await click('E');await sleep(90);checks.baseline_rapid_interrupt=true;checks.before=(await state()).legacy;await page.screenshot({path:out+'/before.png'});await sleep(650);await click('After');
 await click('Normal');checks.normal=(await state()).speed===1;const startCount=(await state()).player_count;await click('All 8');await sleep(1950);checks.autoplay_real_triggers=(await state()).player_count>=startCount+3;await click('E');await sleep(70);await page.screenshot({path:out+'/normal.png'});await sleep(400);
 checks.no_errors=errors.length===0;
 const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,cases,wall,bandit,errors},null,2));console.log(JSON.stringify({checks,errors}));
 if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close();if(server)await server.close();}
