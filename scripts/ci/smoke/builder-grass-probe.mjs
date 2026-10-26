import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir'),{port:0}):null;
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const checks={},errors=[];const wait=ms=>page.waitForTimeout(ms);
const state=()=>page.evaluate(()=>({...window.__EDITOR_STATE__,zoom:window.__SHINOBI_STATE__?.zoom}));
const click=async(x,y)=>{await page.mouse.click(x,y);await wait(350)};
const filter=async name=>{const f=JSON.parse((await state()).filters_json)[name];await click(f.x,f.y)};
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto((server?server.url:arg('base-url'))+'?editor=1');
 await page.waitForFunction(()=>window.__EDITOR_STATE__?.open&&window.__EDITOR_STATE__.cards_json&&window.__SHINOBI_READY__,null,{timeout:90000});await wait(800);
 const initial=await state(),zoom=initial.zoom;checks.original_grass_editable=initial.grass_count===247&&initial.tall_count===111&&initial.count>358;
 await page.mouse.move(initial.scroll_x,initial.scroll_y);await page.mouse.wheel(0,600);await wait(600);checks.palette_scrolls=(await state()).scroll>0;
 for(let i=0;i<5;i++){await page.mouse.wheel(0,900);await wait(100)}await wait(500);checks.bottom_no_zoom=(await state()).zoom===zoom;
 for(let i=0;i<5;i++){await page.mouse.wheel(0,-900);await wait(100)}await wait(500);checks.top_no_zoom=(await state()).zoom===zoom&&(await state()).scroll===0;
 await page.mouse.move(initial.panel_x+20,initial.panel_y+20);await page.mouse.wheel(0,-400);await wait(500);checks.header_no_zoom=(await state()).zoom===zoom;
 await page.mouse.move(600,350);await page.mouse.wheel(0,-100);await wait(500);checks.outside_zoom=(await state()).zoom!==zoom;
 await page.mouse.wheel(0,100);await wait(500);
 await filter('Trees');await filter('Temple walls');
 let st=await state();checks.filters_hide= !JSON.parse(st.cards_json).tree_1.shown&&!JSON.parse(st.filters_json).Trees.shown&&st.count===initial.count;
 for(let i=0;i<12;i++){st=await state();const card=JSON.parse(st.cards_json).grass9_center;if(card.shown)break;await page.mouse.move(st.scroll_x,st.scroll_y);await page.mouse.wheel(0,120);await wait(300)}
 st=await state();const card=JSON.parse(st.cards_json).grass9_center;if(!card.shown)throw Error('grass card not visible');await click(card.x,card.y);checks.grass_palette=(await state()).place_id==='grass9_center';await page.screenshot({path:out+'/01-grass-palette.png'});
 await click(300,550);checks.place=(await state()).grass_count===248;
 await page.mouse.click(300,550,{button:'right'});await wait(200);await click(300,550);const selected=await state();checks.select=selected.selected_id==='grass9_center';
 await page.mouse.move(300,550);await page.mouse.down();await page.mouse.move(390,580,{steps:8});await page.mouse.up();await wait(500);const moved=await state();checks.drag=moved.selected_id==='grass9_center'&&Math.hypot(moved.selected_x-selected.selected_x,moved.selected_y-selected.selected_y)>60;
 await page.screenshot({path:out+'/02-moved-grass.png'});
 await page.keyboard.press('Delete');await wait(500);checks.delete=(await state()).grass_count===247;
 await filter('Grass');st=await state();checks.hide_grass_cancels=st.selected_id===''&&!JSON.parse(st.cards_json).grass9_center.shown&&st.grass_count===247;
 await filter('Grass');await filter('Trees');await filter('Temple walls');st=await state();checks.reveal=Object.values(JSON.parse(st.filters_json)).every(f=>f.shown)&&st.grass_count===247;
 // Add through the palette, explicitly save, reload and verify the persisted edit.
 await filter('Trees');await filter('Temple walls');
 st=await state();for(let i=0;i<12&&!JSON.parse(st.cards_json).grass9_center.shown;i++){await page.mouse.move(st.scroll_x,st.scroll_y);await page.mouse.wheel(0,JSON.parse(st.cards_json).grass9_center.y>st.scroll_y?120:-120);await wait(250);st=await state()}
 const c=JSON.parse(st.cards_json).grass9_center;if(!c.shown)throw Error("save test card not visible");await click(c.x,c.y);await click(300,550);checks.second_place=(await state()).grass_count===248;await page.keyboard.press('Control+s');await wait(8000);await page.reload();await page.waitForFunction(()=>window.__EDITOR_STATE__?.open&&window.__EDITOR_STATE__.cards_json,null,{timeout:90000});await wait(800);checks.save_reload=(await state()).grass_count===248;
 checks.no_errors=errors.length===0;writeFileSync(out+'/builder-grass-proof.json',JSON.stringify({checks,errors,initial,selected,moved,last:await state()},null,2));console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
