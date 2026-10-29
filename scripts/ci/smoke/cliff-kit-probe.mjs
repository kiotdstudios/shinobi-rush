import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {startStaticServer} from './lib/serve.mjs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir')||'docs/visuals/cliff-kit/gameplay';mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir')):null;
const base=arg('url')||server.url;
const preset=arg('preset')==='river'?'river':'review';
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block'});
const page=await context.newPage(),checks=[],errors=[];
const start=Date.now();let clipStart=0;let originalLayout;
const check=(name,ok,detail)=>{checks.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)throw new Error(name)};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__CLIFF_REVIEW__}));
const click=async index=>{const p=JSON.parse((await state()).buttons_json)[index];await page.mouse.click(p.x,p.y);await page.waitForTimeout(150)};
let held=[];
const keys=async wanted=>{for(const k of held)if(!wanted.includes(k))await page.keyboard.up(k);for(const k of wanted)if(!held.includes(k))await page.keyboard.down(k);held=wanted};
async function moveTo(target,max=180,rules={}){
 const samples=[];
 for(let i=0;i<max;i++){
  const s=await state();samples.push({x:s.x,y:s.y,e:s.elevation,depth:s.depth,wet:s.over_water,chakra:s.chakra});
  if(i>0&&i%30===0)console.log('Traversal progress',JSON.stringify({target,x:s.x,y:s.y,e:s.elevation}));
  const dx=target.x-s.x,dy=target.y-s.y;
  if(Math.hypot(dx,dy)<(rules.tolerance||24)&&(!rules.minE||s.elevation>rules.minE)&&(!rules.maxE||s.elevation<rules.maxE)&&(!rules.wet||s.over_water)){await keys([]);await page.waitForTimeout(180);return {arrived:true,samples,end:await state()}}
  const wanted=[];
  if(Math.abs(dx)>4&&Math.abs(dx)>=Math.abs(dy)*.65)wanted.push(dx>0?'KeyD':'KeyA');
  if(Math.abs(dy)>4&&Math.abs(dy)>=Math.abs(dx)*.65)wanted.push(dy>0?'KeyS':'KeyW');
  // Dispatch the press/release pair without extra held-time waits; renderer scheduling
  // already contributes frame latency on software WebGL. Never write game input state.
  for(const key of wanted)await page.keyboard.press(key);
  await page.waitForTimeout(100);
 }
 await keys([]);await page.waitForTimeout(180);return {arrived:false,samples,end:await state()};
}
try{
 if(arg('expected-sha')){const b=await(await fetch(new URL('build-info.json?v='+Date.now(),base))).json();check('exact deployed build',b.commit_sha===arg('expected-sha'),b)}
 await page.goto(base+'?cliffs='+preset+'&editor=1');
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__?.ready,null,{timeout:180000});
 originalLayout=await page.evaluate(()=>localStorage.getItem('shinobi-rush:world-layout:v1'));
 check('full 134-cell demonstration in actual game',(await state()).cells===134,await state());
 await page.screenshot({path:path.join(out,'overview.png')});
 await click(4);await page.waitForFunction(()=>window.__CLIFF_REVIEW__.operations===1);
 check('move erase undo redo and real file save/reload',true,await state());
 clipStart=(Date.now()-start)/1000;
 for(const [index,name,mouth,run] of [[0,'SE',{x:-288,y:54},{x:72,y:-36}],[1,'SW',{x:396,y:144},{x:-72,y:-36}]]){
  await click(index);
  const climb=await moveTo({x:mouth.x+run.x*1.3,y:mouth.y+run.y*1.3},180,{minE:65});
  check(name+' real keyboard climbs to walkable platform',climb.arrived&&climb.end.elevation>65&&climb.end.depth===1,climb);
  await page.screenshot({path:path.join(out,name+'-upper.png')});
  if(index===0){
   const river=await moveTo({x:108,y:18},180,{minE:65,wet:true});
   check('walk across full plateau onto upper river',river.arrived&&river.end.elevation>65&&river.end.over_water&&river.end.chakra<100,river);
   await page.screenshot({path:path.join(out,'upper-river.png')});
  }
  const head=await moveTo({x:mouth.x+run.x,y:mouth.y+run.y},180,{tolerance:10});
  check(name+' aligns with actual upper stair mouth',head.arrived,head);
  const entrance=await moveTo(mouth,180,{tolerance:preset==='river'?18:12});
  check(name+' traverses the stair ramp to its lower mouth',entrance.arrived,entrance);
  const down=await moveTo({x:mouth.x-run.x*.35,y:mouth.y-run.y*.35},180,{maxE:1});
  check(name+' real keyboard descends, restoring lower depth',down.arrived&&down.end.elevation<1&&down.end.depth===0,down);
  await page.screenshot({path:path.join(out,name+'-lower.png')});
 }
 await click(5);
 const blocked=await moveTo({x:-108,y:54},35);
 check('lower player cannot walk through cliff side',!blocked.arrived&&blocked.samples.every(x=>x.e<1),blocked);
 await click(6);
 const fall=await state();await page.waitForTimeout(180);const fall2=await state();
 check('native waterfall mouth and basin match 66px rise',fall.lip_y===42&&fall.basin_y===108&&fall.foam_y===107,fall);
 check('independent cascade and foam frames advance',fall.fall_frame!==fall2.fall_frame||fall.foam_frame!==fall2.foam_frame,{before:fall,after:fall2});
 await page.screenshot({path:path.join(out,'waterfall.png')});
 await page.goto(base+'?cliffs='+preset+'&map_editor=1');
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__?.ready,null,{timeout:180000});
 if(!(await state()).editor_open)await click(3);
 await page.waitForFunction(()=>{const c=JSON.parse(window.__CLIFF_REVIEW__.cards_json).cliff_ground;return c.visible&&c.y>80&&c.y<650});
 let layer=await state();await page.mouse.click(layer.layer_x,layer.layer_y);
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__.cliffs_visible===false);
 check('real editor layer eye hides cliff kit',true,await state());
 await page.mouse.click(layer.layer_x,layer.layer_y);
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__.cliffs_visible===true);
 check('real editor layer eye restores cliff kit',true,await state());
 const card=JSON.parse((await state()).cards_json).cliff_ground;
 await page.mouse.click(card.x,card.y);
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__.place_id==='cliff_ground');
 let s=await state();await page.mouse.click(s.paint_x,s.paint_y);
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__.probe_a===true);
 check('real editor catalog card places snapped cliff module',(await state()).cells===135,await state());
 await page.keyboard.press('Control+KeyZ');await page.waitForFunction(()=>window.__CLIFF_REVIEW__.probe_a===false);
 check('real keyboard undo removes placed module',true,await state());
 await page.keyboard.press('Control+KeyY');await page.waitForFunction(()=>window.__CLIFF_REVIEW__.probe_a===true);
 check('real keyboard redo restores placed module',true,await state());
 s=await state();let t=JSON.parse(s.tools_json).select;await page.mouse.click(t.x,t.y);
 // Drag the visible top by exactly two U cells (72x36), keeping pointer offset from the object's anchor.
 s=await state();const zoom=s.camera_zoom;await page.mouse.move(s.paint_x,s.paint_y-66*zoom);await page.mouse.down();
 await page.mouse.move(s.paint_x+72*zoom,s.paint_y-66*zoom+36*zoom,{steps:10});await page.mouse.up();
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__.probe_b===true&&window.__CLIFF_REVIEW__.probe_a===false);
 check('real editor drag rebuilds moved cliff topology',true,await state());
 s=await state();t=JSON.parse(s.tools_json).erase;await page.mouse.click(t.x,t.y);
 await page.mouse.click(s.paint_x+72*zoom,s.paint_y-66*zoom+36*zoom);
 await page.waitForFunction(()=>window.__CLIFF_REVIEW__.probe_b===false);
 check('real editor erase removes moved geometry',(await state()).cells===134,await state());
 await page.keyboard.press('Control+KeyZ');await page.waitForFunction(()=>window.__CLIFF_REVIEW__.probe_b===true);
 check('undo erase restores geometry',true,await state());
 await click(4);await page.waitForFunction(()=>window.__CLIFF_REVIEW__.operations===1);
 check('black editor file save/reload preserves edited topology',(await state()).probe_b===true,await state());
 await page.screenshot({path:path.join(out,'editor.png')});
 s=await state();
 const popupEvent=context.waitForEvent('page');await page.mouse.click(s.play_x,s.play_y);const popup=await popupEvent;
 popup.on('pageerror',e=>errors.push(String(e)));popup.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await popup.waitForFunction(()=>window.__CLIFF_REVIEW__?.ready,null,{timeout:180000});
 const played=await popup.evaluate(()=>({...window.__CLIFF_REVIEW__}));
 check('real Playtest opens the edited demo with moved geometry',played.cells===135&&played.probe_b===true,played);
 check('demo editing and playtest preserve the normal saved world',await page.evaluate(original=>localStorage.getItem('shinobi-rush:world-layout:v1')===original,originalLayout));
 await popup.close();
 check('zero engine or browser errors' ,errors.length===0,errors);
}catch(e){checks.push({name:'probe completed',ok:false,detail:String(e)});console.log('FAIL',String(e));await page.screenshot({path:path.join(out,'failure.png')});checks.push({name:'failure state',ok:false,detail:await state()})}
finally{await keys([]);await context.close();await browser.close();if(server)await server.close();writeFileSync(path.join(out,'result.json'),JSON.stringify({utc:new Date().toISOString(),checks,errors,clipStart},null,2));}
process.exit(checks.every(x=>x.ok)?0:1);
