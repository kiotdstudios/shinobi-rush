import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {startStaticServer} from './lib/serve.mjs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir')):null;
const base=arg('url')||server.url;
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const checks=[],errors=[];
const check=(name,ok,detail)=>{checks.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name}`)};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
try{
 if(arg('expected-sha')){
  const build=await(await fetch(new URL('build-info.json?v='+Date.now(),base))).json();
  check('exact deployed build',build.commit_sha===arg('expected-sha'),build);
 }
 await page.goto(base+'?junctions=review');
 await page.waitForFunction(()=>window.__JUNCTION_REVIEW__?.ready&&window.__JUNCTION_REVIEW__.buttons_json,null,{timeout:180000});
 const state=()=>page.evaluate(()=>({...window.__JUNCTION_REVIEW__}));
 for(let group=0;group<13;group++){
  const b=JSON.parse((await state()).buttons_json)[group];await page.mouse.click(b.x,b.y);
  await page.waitForFunction(g=>window.__JUNCTION_REVIEW__.group===g,group,{timeout:30000});
  const s=await state();check('actual connected group '+group,s.pieces===(group===12?49:121)&&s.autosave===false&&(group<2||s.junctions>0),s);
  await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__JUNCTION_REVIEW__.controls_visible===false);
  await page.screenshot({path:path.join(out,'group-'+group+'-after.png')});
  if(group===12)await page.screenshot({path:path.join(out,'pr245-after-detail.png'),clip:{x:540,y:290,width:220,height:180}});
  await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__JUNCTION_REVIEW__.controls_visible===true);
  if(group>=2){
   await page.mouse.click(s.compare_x,s.compare_y);
   await page.waitForFunction(()=>window.__JUNCTION_REVIEW__.before===true);
   await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__JUNCTION_REVIEW__.controls_visible===false);
   await page.screenshot({path:path.join(out,'group-'+group+'-pair-only.png')});
   if(group===12)await page.screenshot({path:path.join(out,'pr245-before-detail.png'),clip:{x:540,y:290,width:220,height:180}});
   await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__JUNCTION_REVIEW__.controls_visible===true);
   await page.mouse.click(s.compare_x,s.compare_y);
   await page.waitForFunction(()=>window.__JUNCTION_REVIEW__.before===false);
  }
 }
 const before=await state();await page.mouse.click(700,600);await page.keyboard.down('KeyD');
 await page.waitForFunction(x=>window.__JUNCTION_REVIEW__.player_x>x+25,before.player_x,{timeout:30000});
 await page.keyboard.up('KeyD');check('real player movement over joins',(await state()).player_x>before.player_x+25,await state());
 check('zero engine/browser errors',errors.length===0,errors);
}catch(e){check('probe completed',false,String(e))}
finally{
 await page.keyboard.up('KeyD');await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,utc:new Date().toISOString()},null,2));
}
process.exit(checks.every(x=>x.ok)?0:1);
