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
 checks.filter_exists=!!JSON.parse(initial.filters_json)['Volcanic trees'];
 checks.three_cards=Object.keys(JSON.parse(initial.cards_json)).filter(k=>k.startsWith('ashen_')).length===3;
 for(const [name,f] of Object.entries(JSON.parse(initial.filters_json))) if(name!=='Volcanic trees'&&f.shown)await filter(name);
 const zoom=(await state()).zoom;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,900);await wait(250);await page.mouse.wheel(0,-900);await wait(250);
 checks.scroll_no_zoom=(await state()).zoom===zoom;
 await card('ashen_sentinel');await click(750,550);
 checks.place=(await state()).count===initial.count+1;
 await page.mouse.click(750,550,{button:'right'});await wait(200);await click(750,550);
 const selected=await state();checks.select=selected.selected_id==='ashen_sentinel';
 await page.mouse.move(750,550);await page.mouse.down();await page.mouse.move(825,590,{steps:8});await page.mouse.up();await wait(350);
 const moved=await state();checks.move=moved.selected_id==='ashen_sentinel'&&Math.hypot(moved.selected_x-selected.selected_x,moved.selected_y-selected.selected_y)>30;
 await page.keyboard.press('Delete');await wait(350);checks.delete=(await state()).count===initial.count;
 await card('ashen_sentinel');await filter('Volcanic trees');
 let s=await state();checks.hide_cancels=s.place_id===''&&!JSON.parse(s.cards_json).ashen_sentinel.shown;
 await filter('Volcanic trees');
 const roles=['sentinel','windbent','elder'];
 for(let i=0;i<3;i++){
  await card('ashen_'+roles[i]);await click(300+i*300,590);
 }
 s=await state();checks.all_three_place=s.count===initial.count+3&&s.ashen_count===initial.ashen_count+3;
 checks.ash_capacity=s.ashen_capacity===s.ashen_count*24;
 const clock=s.ashen_clock;await wait(1000);checks.animation_clock=(await state()).ashen_clock>clock+0.5;
 await page.mouse.click(600,540,{button:'right'});await wait(200);
 await page.screenshot({path:out+'/volcanic-trees-builder.png'});
 await page.keyboard.press('Control+s');await wait(8000);await page.reload();
 await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json,null,{timeout:90000});await wait(700);
 checks.save_reload=(await state()).count===initial.count+3;
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/result.json',JSON.stringify({checks,errors,initial,selected,moved,last:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
