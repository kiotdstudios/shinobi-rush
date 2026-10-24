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
 checks.filter_exists=!!JSON.parse(initial.filters_json)['Blightwood lights'];
 checks.six_cards=Object.keys(JSON.parse(initial.cards_json)).filter(k=>k.startsWith('blight_')).length===6;
 for(const [name,f] of Object.entries(JSON.parse(initial.filters_json))) if(name!=='Blightwood lights'&&f.shown)await filter(name);
 const zoom=(await state()).zoom;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,900);await wait(250);await page.mouse.wheel(0,-900);await wait(250);
 checks.scroll_no_zoom=(await state()).zoom===zoom;
 await card('blight_wooden_post');await click(750,550);
 checks.place=(await state()).count===initial.count+1;
 await page.mouse.click(750,550,{button:'right'});await wait(200);await click(750,550);
 const selected=await state();checks.select=selected.selected_id==='blight_wooden_post';
 await page.mouse.move(750,550);await page.mouse.down();await page.mouse.move(825,590,{steps:8});await page.mouse.up();await wait(350);
 const moved=await state();checks.move=moved.selected_id==='blight_wooden_post'&&Math.hypot(moved.selected_x-selected.selected_x,moved.selected_y-selected.selected_y)>30;
 await page.keyboard.press('Delete');await wait(350);checks.delete=(await state()).count===initial.count;
 await card('blight_wooden_post');await filter('Blightwood lights');
 let s=await state();checks.hide_cancels=s.place_id===''&&!JSON.parse(s.cards_json).blight_wooden_post.shown;
 await filter('Blightwood lights');
 const roles=['wooden_post','stone_pagoda','branch_lantern','stone_brazier','spirit_totem'];
 for(let i=0;i<5;i++){await card('blight_'+roles[i]);await click(180+i*160,550)}
 await card('blight_fireflies');await click(820,610);
 s=await state();checks.all_six_place=s.count===initial.count+6&&s.blight_count===initial.blight_count+5&&s.swarm_count===initial.swarm_count+1;
 checks.bounded_firefly_pool=s.fly_count===initial.fly_count+92;
 const clock=s.light_clock;await wait(1500);checks.live_animation=(await state()).light_clock>clock+.5;
 await page.mouse.click(820,610,{button:'right'});await wait(200);await click(820,610);
 s=await state();checks.select_standalone_swarm=s.selected_id==='blight_fireflies';
 await page.mouse.move(820,610);await page.mouse.down();await page.mouse.move(875,630,{steps:8});await page.mouse.up();await wait(300);
 const swarm_moved=await state();checks.move_standalone_swarm=swarm_moved.selected_id==='blight_fireflies'&&Math.hypot(swarm_moved.selected_x-s.selected_x,swarm_moved.selected_y-s.selected_y)>20;
 await page.keyboard.press('Delete');await wait(300);checks.delete_standalone_swarm=(await state()).swarm_count===initial.swarm_count&&(await state()).blight_count===initial.blight_count+5;
 await card('blight_fireflies');await click(820,610);await page.mouse.click(600,540,{button:'right'});await wait(200);
 await page.screenshot({path:out+'/blightwood-builder.png'});
 await page.keyboard.press('Control+s');
 await page.waitForFunction(n=>{try{return JSON.parse(localStorage.getItem('shinobi-rush:world-layout:v1')).items.filter(i=>i.id.startsWith('blight_')).length===n}catch{return false}},6,{timeout:30000});
 await page.reload();await page.waitForFunction(()=>window.__EDITOR_STATE__?.cards_json&&window.__SHINOBI_READY__,null,{timeout:90000});await wait(500);
 const restored=await state();checks.save_reload=restored.blight_count===initial.blight_count+5&&restored.swarm_count===initial.swarm_count+1&&restored.count===initial.count+6;
 checks.no_errors=errors.length===0;
 const deployed=server?null:await (await page.request.get(arg('base-url')+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/result.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:deployed?.commit_sha??null,checks,errors,initial,selected,moved,last:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
