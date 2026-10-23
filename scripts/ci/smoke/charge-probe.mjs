import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const output='build/charge-runtime-browser';mkdirSync(output,{recursive:true});
const server=process.argv[2].startsWith('https:')?null:await startStaticServer(process.argv[2],{port:0});
const browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader']});
const page=await browser.newPage({viewport:{width:1280,height:720}});const errors=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto(server?server.url:process.argv[2]);await page.waitForFunction(()=>window.__SHINOBI_READY__===true,null,{timeout:120000});
 await page.locator('canvas').click();
 await page.keyboard.press('q',{delay:60});await page.waitForTimeout(200);
 assert.notEqual((await page.evaluate(()=>window.__SHINOBI_STATE__)).state,'CHARGE');
 await page.keyboard.down('q');await page.waitForFunction(()=>window.__SHINOBI_STATE__?.state==='CHARGE',null,{timeout:15000});
 const before=await page.evaluate(()=>({...window.__SHINOBI_STATE__}));
 await page.waitForTimeout(1500);const after=await page.evaluate(()=>({...window.__SHINOBI_STATE__}));
 assert.equal(after.player_attack_anim,'charge');assert.equal(after.player_weapon_visible,false);assert(Math.abs(after.x-before.x)<.1&&Math.abs(after.y-before.y)<.1);
 await page.screenshot({path:output+'/charge.png'});
 await page.keyboard.up('q');await page.waitForFunction(()=>window.__SHINOBI_STATE__.state==='IDLE');
 await page.keyboard.down('d');await page.waitForFunction(()=>window.__SHINOBI_STATE__.state==='MOVE');await page.keyboard.up('d');
 assert.deepEqual(errors,[]);writeFileSync(output+'/result.json',JSON.stringify({result:'PASS',before,after,errors},null,2));console.log('PASS: browser key hold charges, planted pose/no weapon, release and movement');
}finally{await browser.close();if(server)await server.close()}
