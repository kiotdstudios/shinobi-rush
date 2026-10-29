import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {startStaticServer} from './lib/serve.mjs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir')):null;
const base=arg('url')||server.url;
console.log('Starting browser at '+base);
const browser=await chromium.launch({headless:true});
console.log('Browser launched');
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
page.setDefaultTimeout(120000);
const checks=[],errors=[];
const check=(name,ok,detail)=>{checks.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)throw Error(name)};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__AUTO_BLEND_REVIEW__}));
const button=async i=>{if(!(await state()).controls_visible){await page.keyboard.press('KeyH');await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__.controls_visible)}const b=JSON.parse((await state()).buttons_json)[i];await page.mouse.click(b.x,b.y)};
const worldClick=async(x,y)=>{if((await state()).controls_visible){await page.keyboard.press('KeyH');await page.waitForFunction(()=>!window.__AUTO_BLEND_REVIEW__.controls_visible)}await page.mouse.click(x,y)};
const wait=async fn=>page.waitForFunction(fn,null,{timeout:120000,polling:100});
try{
 if(arg('expected-sha')){
  const build=await(await fetch(new URL('build-info.json?v='+Date.now(),base))).json();
  check('exact deployed build',build.commit_sha===arg('expected-sha'),build.commit_sha);
 }
 console.log('Loading editor');
 await page.goto(base+'?autoblend=review&map_editor=1');
 console.log('Waiting for editor readiness');
 await page.waitForFunction(()=>window.__AUTO_BLEND_REVIEW__?.ready,null,{timeout:180000});
 const initial=await page.evaluate(()=>localStorage.getItem('shinobi-rush:world-layout:v1'));
 await button(22);await wait(()=>window.__AUTO_BLEND_REVIEW__.smart&&window.__AUTO_BLEND_REVIEW__.paint_id==='grass_dirt_06_b');
 check('smart brush selects ambiguous tile without assignment',JSON.parse((await state()).family_json).grass_dirt_06_b===undefined);
 await button(23);await wait(()=>window.__AUTO_BLEND_REVIEW__.family_open);
 let s=await state();
 check('review requires explicit approval',Object.keys(JSON.parse(s.family_json)).length===0);
 await page.screenshot({path:path.join(out,'family-review.png')});
 s=await state();
 // Drive the actual native Godot option menu and confirmation button with mouse/keyboard.
 const index=JSON.parse(s.family_options).indexOf('dirt');
 check('pixel suggestions include dirt',index>=2);
 await page.mouse.click(s.family_x,s.family_y);
 await wait(()=>window.__AUTO_BLEND_REVIEW__.family_popup===true);
 // Coordinates measured from the native popup at the fixed 1280x720 test viewport:
 // 31px option control, 2px popup gap, 27px regular menu rows, no separators.
 s=await state();
 await page.mouse.click(s.family_x,s.family_y+17.5+(index+.5)*27);
 await wait(()=>String(window.__AUTO_BLEND_REVIEW__.family_selected)==='dirt');
 s=await state();await page.mouse.click(s.approve_x,s.approve_y);
 await wait(()=>JSON.parse(window.__AUTO_BLEND_REVIEW__.family_json).grass_dirt_06_b==='dirt');
 check('manual family approval applied',true);
 s=await state();await worldClick(s.paint_x,s.paint_y);
 await wait(()=>window.__AUTO_BLEND_REVIEW__.paint_mat==='dirt');
 check('real pointer smart-paints approved material',true);
 await page.keyboard.press('Control+KeyZ');
 await page.waitForFunction(m=>window.__AUTO_BLEND_REVIEW__.paint_mat===m,s.paint_before);
 check('real keyboard undo restores original ownership',true);
 await page.keyboard.press('Control+KeyY');await wait(()=>window.__AUTO_BLEND_REVIEW__.paint_mat==='dirt');
 check('real keyboard redo restores smart paint',true);
 await button(24);await wait(()=>window.__AUTO_BLEND_REVIEW__.shape==='fill');
 s=await state();await worldClick(s.fill_x,s.fill_y);
 await wait(()=>window.__AUTO_BLEND_REVIEW__.fill_mat==='dirt');
 check('connected fill remains bounded',JSON.parse((await state()).materials_json).length<=121);
 await button(20);await wait(()=>window.__AUTO_BLEND_REVIEW__.operations===1);
 check('exact undo redo save reload with approvals',JSON.parse((await state()).family_json).grass_dirt_06_b==='dirt');
 await button(25);await wait(()=>window.__AUTO_BLEND_REVIEW__.tool==='erase');
 s=await state();await worldClick(s.paint_x,s.paint_y);
 await wait(()=>window.__AUTO_BLEND_REVIEW__.tile_count===0);
 check('pointer erase removes selected floor',true);
 await page.keyboard.press('Control+KeyZ');await wait(()=>window.__AUTO_BLEND_REVIEW__.tile_count===1);
 check('erase undo restores floor',true);
 await page.screenshot({path:path.join(out,'smart-brush-editor.png')});
 check('normal saved world remains unchanged',initial===await page.evaluate(()=>localStorage.getItem('shinobi-rush:world-layout:v1')));
 check('zero engine/browser errors',errors.length===0,errors);
}catch(e){checks.push({name:'probe completed',ok:false,detail:String(e)});console.error(e);await page.screenshot({path:path.join(out,'failure.png')});writeFileSync(path.join(out,'failure-state.json'),JSON.stringify(await state(),null,2))}
finally{await browser.close();if(server)await server.close();writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,utc:new Date().toISOString()},null,2))}
process.exit(checks.every(x=>x.ok)?0:1);
