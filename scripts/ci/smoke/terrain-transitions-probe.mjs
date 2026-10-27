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
 await page.goto(base+'?terraintransitions=review');
 await page.waitForFunction(()=>window.__TERRAIN_REVIEW__?.ready&&window.__TERRAIN_REVIEW__.buttons_json,null,{timeout:180000});
 const state=()=>page.evaluate(()=>({...window.__TERRAIN_REVIEW__}));
 const families=['grass_path','grass_temple','dirt_temple','grass_rock','dirt_rock','temple_rock','grass_dirt'];
 for(const family of families){
  const rects=JSON.parse((await state()).buttons_json),b=rects[family];await page.mouse.click(b.x,b.y);
  await page.waitForFunction(f=>window.__TERRAIN_REVIEW__.family===f,family,{timeout:30000});
  const s=await state();check(family+' actual connected floor and bank filter',s.pieces===121&&s.brown_filter===true,s);
  await page.screenshot({path:path.join(out,family+'.png')});
 }
 const before=await state();await page.mouse.click(700,600);await page.keyboard.down('KeyD');
 await page.waitForFunction(x=>window.__TERRAIN_REVIEW__.player_x>x+25,before.player_x,{timeout:30000});
 await page.keyboard.up('KeyD');
 check('real player crosses new floor',(await state()).player_x>before.player_x+25,await state());
 check('no engine/browser errors',errors.length===0,errors);
}catch(e){check('probe completed',false,String(e))}
finally{
 await page.keyboard.up('KeyD');await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,utc:new Date().toISOString()},null,2));
}
process.exit(checks.every(x=>x.ok)?0:1);
