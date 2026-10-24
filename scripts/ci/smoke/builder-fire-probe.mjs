import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir'),{port:0}):null;
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const checks={},errors=[];
const wait=ms=>page.waitForTimeout(ms);
const state=()=>page.evaluate(()=>({...window.__EDITOR_STATE__,zoom:window.__SHINOBI_STATE__?.zoom}));
const click=async(x,y)=>{await page.mouse.click(x,y);await wait(300)};
const filter=async name=>{const f=JSON.parse((await state()).filters_json)[name];await click(f.x,f.y)};
const card=async id=>{
 for(let i=0;i<24;i++){
  const s=await state(),c=JSON.parse(s.cards_json)[id];
  if(c.shown){await click(c.x,c.y);return}
  await page.mouse.move(s.scroll_x,s.scroll_y);await page.mouse.wheel(0,c.y>s.scroll_y?100:-100);await wait(160);
 }
 throw Error('Cannot reach card '+id);
};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto((server?server.url:arg('base-url'))+'?editor=1&v='+Date.now());
 await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json&&window.__SHINOBI_READY__,null,{timeout:90000});await wait(700);
 const initial=await state();
 checks.filter_exists=!!JSON.parse(initial.filters_json)['Ashen fire'];
 checks.five_cards=Object.keys(JSON.parse(initial.cards_json)).filter(k=>k.startsWith('fire_')).length===5;
 for(const [name,f] of Object.entries(JSON.parse(initial.filters_json))) if(name!=='Ashen fire'&&f.shown)await filter(name);
 const zoom=(await state()).zoom;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,900);await wait(250);await page.mouse.wheel(0,-900);await wait(250);
 checks.scroll_no_zoom=(await state()).zoom===zoom;
 await card('fire_tall_pillar');await click(750,550);
 checks.place=(await state()).count===initial.count+1;
 await page.mouse.click(750,550,{button:'right'});await wait(200);await click(750,550);
 const selected=await state();checks.select=selected.selected_id==='fire_tall_pillar';
 await page.mouse.move(750,550);await page.mouse.down();await page.mouse.move(825,590,{steps:8});await page.mouse.up();await wait(350);
 const moved=await state();checks.move=moved.selected_id==='fire_tall_pillar'&&Math.hypot(moved.selected_x-selected.selected_x,moved.selected_y-selected.selected_y)>30;
 await page.keyboard.press('Delete');await wait(350);checks.delete=(await state()).count===initial.count;
 await card('fire_tall_pillar');await filter('Ashen fire');
 let s=await state();checks.hide_cancels=s.place_id===''&&!JSON.parse(s.cards_json).fire_tall_pillar.shown;
 await filter('Ashen fire');
 const roles=['tall_pillar','short_brazier','tripod_brazier','wall_brazier','fire_pit'];
 for(let i=0;i<5;i++){
  await card('fire_'+roles[i]);await click(180+i*160,550);
 }
 s=await state();checks.all_five_place=s.count===initial.count+5&&s.fire_count===initial.fire_count+5;
 const pops=s.fire_pops;await wait(2800);checks.live_pop_events=(await state()).fire_pops>pops;
 await page.mouse.click(600,540,{button:'right'});await wait(200);
 await page.screenshot({path:out+'/ashen-fire-builder.png'});
 await page.keyboard.press('Control+s');
 await page.waitForFunction(expected=>{
  try{return JSON.parse(localStorage.getItem('shinobi-rush:world-layout:v1')).items.filter(i=>i.id.startsWith('fire_')).length===expected}catch{return false}
 },s.fire_count,{timeout:30000});
 checks.browser_backup=true;
 await page.reload();
 await page.waitForFunction(n=>window.__EDITOR_STATE__?.fire_count===n,initial.fire_count+5,{timeout:90000});await wait(700);
 checks.save_reload=(await state()).count===initial.count+5;
 const backup=await page.evaluate(()=>localStorage.getItem('shinobi-rush:world-layout:v1'));
 await page.evaluate(()=>localStorage.setItem('shinobi-rush:world-layout:v1','{invalid'));
 await page.reload();await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json&&window.__SHINOBI_READY__,null,{timeout:90000});await wait(300);
 checks.invalid_backup_fallback=(await state()).count>0;
 await page.evaluate(text=>localStorage.setItem('shinobi-rush:world-layout:v1',text),backup);
 await page.reload();await page.waitForFunction(n=>window.__EDITOR_STATE__?.fire_count===n,initial.fire_count+5,{timeout:90000});
 checks.backup_restored=(await state()).count===initial.count+5;
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/result.json',JSON.stringify({checks,errors,initial,selected,moved,last:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
