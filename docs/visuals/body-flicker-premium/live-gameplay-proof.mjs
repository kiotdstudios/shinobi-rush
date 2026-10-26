import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [base,mode,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const browser=await chromium.launch({headless:true});const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});
const page=await context.newPage();const errors=[],states=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 const build=await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 await page.goto(base+'?camera=close&kunai_inspect=1&v='+build.commit_sha);await page.waitForFunction(()=>window.__SHINOBI_READY__&&window.__KUNAI_GAME__?.ready,null,{timeout:90000});await page.mouse.click(640,400);await page.waitForTimeout(300);
 for(const keys of [['d','s'],['d'],['w','d'],['w'],['a','w'],['a'],['s','a'],['s']]){
  for(const key of keys)await page.keyboard.down(key);await page.keyboard.down('Space');await page.waitForTimeout(35);await page.keyboard.up('Space');
  for(let i=0;i<6;i++){states.push(await page.evaluate(()=>({...window.__SHINOBI_STATE__,...window.__KUNAI_GAME__})));await page.waitForTimeout(40)}
  for(const key of keys)await page.keyboard.up(key);await page.waitForTimeout(120);
 }
 await page.screenshot({path:out+'/main-'+mode+'.png'});
 const hasFx=states.some(s=>{try{return JSON.parse(s.flicker_json).pool===3}catch{return false}});
 const checks={normal_game_input:states.some(s=>s.state==='DODGE'),eight_directions:new Set(states.map(s=>s.direction)).size===8,expected_presentation:mode==='before'?!hasFx:hasFx,no_errors:errors.length===0};
 writeFileSync(out+'/validation.json',JSON.stringify({mode,url:page.url(),tested_at:new Date().toISOString(),build_sha:build.commit_sha,build,checks,states,errors},null,2));console.log(JSON.stringify({mode,build_sha:build.commit_sha,checks,errors}));
 const video=page.video();await context.close();await video.saveAs(out+'/gameplay-'+mode+'.webm');if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close()}
