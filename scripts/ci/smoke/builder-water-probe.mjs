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
 checks.filter_exists=!!JSON.parse(initial.filters_json)['River water'];
 checks.ten_cards=Object.keys(JSON.parse(initial.cards_json)).filter(k=>k.startsWith('water9_')||k==='waterfall_small').length===10;
 for(const [name,f] of Object.entries(JSON.parse(initial.filters_json)))if(name!=='River water'&&f.shown)await filter(name);
 const zoom=(await state()).zoom;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,600);await wait(200);await page.mouse.wheel(0,-600);await wait(200);
 checks.scroll_no_zoom=(await state()).zoom===zoom;
 await card('waterfall_small');await click(750,550);
 checks.place=(await state()).count===initial.count+1;
 await page.mouse.click(750,550,{button:'right'});await wait(200);await click(750,550);
 const selected=await state();checks.select=selected.selected_id==='waterfall_small';
 await page.mouse.move(750,550);await page.mouse.down();await page.mouse.move(810,590,{steps:8});await page.mouse.up();await wait(300);
 const moved=await state();checks.move=moved.selected_id==='waterfall_small'&&Math.hypot(moved.selected_x-selected.selected_x,moved.selected_y-selected.selected_y)>20;
 await page.keyboard.press('Delete');await wait(250);checks.delete=(await state()).count===initial.count;
 await card('water9_center');await filter('River water');let s=await state();checks.hide_cancels=s.place_id===''&&!JSON.parse(s.cards_json).water9_center.shown;
 await filter('River water');
 for(const [id,x,y] of [['water9_center',300,550],['water9_edge_ne',372,550],['water9_corner_top',444,550],['waterfall_small',650,500]]){await card(id);await click(x,y)}
 s=await state();checks.layers_place=s.water_count===initial.water_count+4;
 const c=s.water_clock;await wait(650);checks.live_animation=(await state()).water_clock>c+.3;
 await page.mouse.click(650,500,{button:'right'});await wait(150);
 await page.screenshot({path:out+'/water-builder.png'});
 await page.keyboard.press('Control+s');
 await page.waitForFunction(()=>{try{return JSON.parse(localStorage.getItem('shinobi-rush:world-layout:v1')).items.filter(i=>i.id.startsWith('water9_')||i.id==='waterfall_small').length===4}catch{return false}},null,{timeout:30000});
 await page.reload();await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json&&window.__SHINOBI_READY__,null,{timeout:90000});await wait(500);
 checks.save_reload=(await state()).water_count===initial.water_count+4&&(await state()).count===initial.count+4;
 checks.no_errors=errors.length===0;
 const deployed=server?null:await(await page.request.get(arg('base-url')+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/result.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:deployed?.commit_sha??null,checks,errors,initial,selected,moved,last:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
