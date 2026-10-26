import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(source)?null:await startStaticServer(source,{port:0});const base=server?.url??source;
const browser=await chromium.launch({headless:true});const errors=[],recordings=[];
try{
 for(const mode of ['before','after']){
  const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.goto(base+'?camera=close&kunai_inspect=1'+(mode==='before'?'&flicker_before=1':''));
  await page.waitForFunction(()=>window.__SHINOBI_READY__&&window.__KUNAI_GAME__?.ready,null,{timeout:90000});await page.mouse.click(640,400);await page.waitForTimeout(300);
  const states=[];const keys=[['d','s'],['d'],['w','d'],['w'],['a','w'],['a'],['s','a'],['s']];
  for(const direction of keys){
   for(const k of direction)await page.keyboard.down(k);
   await page.keyboard.down('Space');await page.waitForTimeout(35);await page.keyboard.up('Space');
   for(let i=0;i<6;i++){states.push(await page.evaluate(()=>({...window.__SHINOBI_STATE__,...window.__KUNAI_GAME__})));await page.waitForTimeout(40)}
   for(const k of direction)await page.keyboard.up(k);await page.waitForTimeout(120);
  }
  await page.screenshot({path:out+'/main-'+mode+'.png'});
  const video=page.video();await context.close();await video.saveAs(out+'/gameplay-'+mode+'.webm');
  recordings.push({mode,states});
 }
 const after=recordings.find(r=>r.mode==='after').states;
 const checks={actual_game_input:after.some(s=>s.state==='DODGE'),all_eight_directions:new Set(after.map(s=>s.direction)).size===8,new_presentation:after.some(s=>{try{return JSON.parse(s.flicker_json).pool===3}catch{return false}}),no_errors:errors.length===0};
 const build=server?null:await(await(await browser.newContext()).request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/gameplay-validation.json',JSON.stringify({url:base,tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,recordings,errors},null,2));
 console.log(JSON.stringify({checks,errors}));if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close();if(server)await server.close();}
