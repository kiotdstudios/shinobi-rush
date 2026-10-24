import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const output='build/bandit-black-kunai-browser';mkdirSync(output,{recursive:true});
const server=process.argv[2].startsWith('https:')?null:await startStaticServer(process.argv[2],{port:0});
const browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader']});
const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[],states=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto(server?server.url:process.argv[2]);await page.waitForFunction(()=>window.__SHINOBI_READY__===true,null,{timeout:120000});
 await page.locator('canvas').click();
 await page.keyboard.down('d');await page.waitForFunction(()=>window.__SHINOBI_STATE__.x>1050,null,{timeout:12000});await page.keyboard.up('d');
 let retreating=false;
 for(let n=0;n<180;n++){
  await page.waitForTimeout(100);const s=await page.evaluate(()=>({...window.__SHINOBI_STATE__}));states.push(s);
  const distance=Math.hypot(s.bandit_x-s.x,s.bandit_y-s.y);
  const retreat=distance<260&&s.y<850;
  if(retreat&&!retreating){await page.keyboard.down('s');retreating=true}
  if(!retreat&&retreating){await page.keyboard.up('s');retreating=false}
  if(n%10===0||s.bandit_animation==='throw')await page.screenshot({path:`${output}/flight-${n}.png`});
  if(states.filter(s=>s.bandit_animation==='throw').length>=5)break;
 }
 writeFileSync(output+'/states.json',JSON.stringify(states,null,2));
 await page.keyboard.up('s');
 assert(states.some(s=>s.bandit_animation==='throw'),'normal AI throw animation must be observed');
 assert.deepEqual(errors,[]);writeFileSync(output+'/result.json',JSON.stringify({result:'PASS',errors,states},null,2));console.log('PASS: normal browser movement approaches bandit; real AI kunai throw observed;0 browser errors');
}finally{await browser.close();if(server)await server.close()}
