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
 await page.goto(base+'?autoblend=review&editor=1');
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__?.ready,null,{timeout:180000});
 const state=()=>page.evaluate(()=>({...window.__AUTO_BLEND_REVIEW__}));
 for(const group of (arg('pointer-only')?[19]:Array.from({length:20},(_,i)=>i))){
  const b=JSON.parse((await state()).buttons_json)[group];await page.mouse.click(b.x,b.y);
  await page.waitForFunction(g=>window.__AUTO_BLEND_REVIEW__.group===g,group,{timeout:30000});
  const s=await state();check('actual auto-blended group '+group,s.cells===121&&s.bad===0&&s.missing===0&&s.autosave===false&&(group<10||s.junctions>0),s);
  await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.controls_visible===false);
  await page.screenshot({path:path.join(out,'group-'+group+'.png')});
  await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.controls_visible===true);
 }
 let s=await state(),b=JSON.parse(s.buttons_json)[20];await page.mouse.click(b.x,b.y);
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.operations===1);
 s=await state();check('undo redo and save/reload preserve exact tiles and owners',s.bad===0&&s.missing===0,s);
 const before=s;await page.mouse.click(700,600);await page.keyboard.down('KeyD');
 await page.waitForFunction(x=>window.__AUTO_BLEND_REVIEW__.x>x+25,before.x,{timeout:30000});
 await page.keyboard.up('KeyD');check('real player movement over blended floor',(await state()).x>before.x+25);
 b=JSON.parse((await state()).buttons_json)[21];await page.mouse.click(b.x,b.y);
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.paint_mode===true);
 s=await state();await page.mouse.click(s.paint_x,s.paint_y);
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.paint_mat===window.__AUTO_BLEND_REVIEW__.paint_target);
 check('real pointer paints a managed material',true,await state());
 await page.keyboard.press('Control+KeyZ');
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.paint_mat===window.__AUTO_BLEND_REVIEW__.paint_before);
 check('real keyboard undo restores brush ownership',true,await state());
 await page.keyboard.press('Control+KeyY');
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.paint_mat===window.__AUTO_BLEND_REVIEW__.paint_target);
 check('real keyboard redo restores brush ownership',true,await state());
 await page.screenshot({path:path.join(out,'pointer-paint.png')});
 await page.goto(base+'?autoblend=review&map_editor=1');
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__?.ready&&window.__AUTO_BLEND_REVIEW__.black_editor===true,null,{timeout:180000});
 s=await state();b=JSON.parse(s.buttons_json)[21];await page.mouse.click(b.x,b.y);
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.paint_mode===true);
 s=await state();await page.mouse.click(s.paint_x,s.paint_y);
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.paint_mat===window.__AUTO_BLEND_REVIEW__.paint_target);
 check('black map editor pointer paints with material ownership',true,await state());
 await page.screenshot({path:path.join(out,'black-editor-paint.png')});
 check('zero engine/browser errors',errors.length===0,errors);
}catch(e){check('probe completed',false,String(e));await page.screenshot({path:path.join(out,'failure.png')});check('failure state',false,await page.evaluate(()=>({...window.__AUTO_BLEND_REVIEW__})))}
finally{
 await page.keyboard.up('KeyD');await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,utc:new Date().toISOString()},null,2));
}
process.exit(checks.every(x=>x.ok)?0:1);
