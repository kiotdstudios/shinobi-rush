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
 checks.filter=!!JSON.parse(initial.filters_json)['Dynamic shrine'];
 checks.save_accessible=initial.save_accessible===true;
 for(const [name,f] of Object.entries(JSON.parse(initial.filters_json)))if(name!=='Dynamic shrine'&&f.shown)await filter(name);
 const zoom=(await state()).zoom;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,300);await wait(200);await page.mouse.wheel(0,-300);await wait(200);
 checks.scroll_no_zoom=(await state()).zoom===zoom;
 await card('dynamic_shrine');let px=750,py=550;
 for(const point of [[750,650],[350,650],[150,650],[750,550],[750,350]]){[px,py]=point;await click(px,py);if((await state()).shrine_count>initial.shrine_count)break}
 checks.place=(await state()).shrine_count===initial.shrine_count+1;
 await page.mouse.click(px,py,{button:'right'});await wait(200);await click(px,py-40);
 const selected=await state();checks.select=selected.selected_id==='dynamic_shrine';
 await page.mouse.move(px,py-40);await page.mouse.down();await page.mouse.move(px-100,py-40,{steps:8});await page.mouse.up();await wait(300);
 const moved=await state();checks.move=moved.selected_id==='dynamic_shrine'&&Math.abs(moved.selected_x-selected.selected_x)>20;
 await page.screenshot({path:out+'/shrine-builder.png'});
 await page.keyboard.press('Control+s');await wait(400);
 const storage=await page.evaluate(()=>JSON.parse(localStorage.getItem('shinobi-rush:world-layout:v1')));
 checks.saved=storage.items.filter(i=>i.id==='dynamic_shrine').length===initial.shrine_count+1;
 await page.reload();await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json&&window.__SHINOBI_READY__,null,{timeout:90000});await wait(700);
 checks.reload=(await state()).shrine_count===initial.shrine_count+1;
 await filter('Dynamic shrine');checks.hide=!JSON.parse((await state()).filters_json)['Dynamic shrine'].shown;
 await filter('Dynamic shrine');
 await click(px-100,py-40);await page.keyboard.press('Delete');await wait(300);
 checks.delete=(await state()).shrine_count===initial.shrine_count;
 checks.no_errors=errors.length===0;
 const deployed=server?null:await(await page.request.get(arg('base-url')+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/result.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:deployed?.commit_sha??null,checks,errors,initial,selected,moved,last:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
