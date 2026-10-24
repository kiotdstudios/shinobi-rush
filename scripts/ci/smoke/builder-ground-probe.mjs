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
 checks.filter_exists=!!JSON.parse(initial.filters_json)['Ground / paths'];
 checks.nine_cards=Object.keys(JSON.parse(initial.cards_json)).filter(k=>k.startsWith('ground9_')).length===9;
 for(const [name,f] of Object.entries(JSON.parse(initial.filters_json))) if(name!=='Ground / paths'&&f.shown)await filter(name);
 const zoom=(await state()).zoom;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,900);await wait(250);await page.mouse.wheel(0,-900);await wait(250);
 checks.scroll_no_zoom=(await state()).zoom===zoom;
 await card('ground9_center');await click(300,550);
 checks.place=(await state()).count===initial.count+1;
 await page.mouse.click(300,550,{button:'right'});await wait(200);await click(300,550);
 const selected=await state();checks.select=selected.selected_id==='ground9_center';
 await page.mouse.move(300,550);await page.mouse.down();await page.mouse.move(390,580,{steps:8});await page.mouse.up();await wait(350);
 const moved=await state();checks.move=moved.selected_id==='ground9_center'&&Math.hypot(moved.selected_x-selected.selected_x,moved.selected_y-selected.selected_y)>30;
 await page.keyboard.press('Delete');await wait(350);checks.delete=(await state()).count===initial.count;
 await card('ground9_center');await filter('Ground / paths');
 let s=await state();checks.hide_cancels=s.place_id===''&&!JSON.parse(s.cards_json).ground9_center.shown;
 await filter('Ground / paths');
 const roles=['corner_top','edge_ne','corner_right','edge_nw','center','edge_se','corner_left','edge_sw','corner_bottom'];
 // Native tile-space steps projected into screen space at the current game zoom.
 const z=(await state()).zoom;
 for(let i=0;i<9;i++){
  await card('ground9_'+roles[i]);const row=Math.floor(i/3),col=i%3;
  await click(750+(col-row)*36*z,440+(col+row)*18*z);
 }
 checks.all_nine_place=(await state()).count===initial.count+9;
 await page.mouse.click(600,540,{button:'right'});await wait(200);
 await page.screenshot({path:out+'/ground-nine-builder.png'});
 await page.keyboard.press('Control+s');await wait(8000);await page.reload();
 await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json,null,{timeout:90000});await wait(700);
 checks.save_reload=(await state()).count===initial.count+9;
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/result.json',JSON.stringify({checks,errors,initial,selected,moved,last:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
