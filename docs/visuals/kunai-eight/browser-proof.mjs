import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const out=process.env.KUNAI_OUT||'build/kunai-eight-browser';
mkdirSync(out,{recursive:true});
const server=process.env.KUNAI_URL?null:await startStaticServer(process.env.KUNAI_DIR||'../kunai-eight-final-web',{port:0});
const base=process.env.KUNAI_URL||server.url;
const pack=JSON.parse(readFileSync('assets/combat/kunai/kunai-combat.art.json'));
const browser=await chromium.launch({headless:true});
const errors=[],records=[];
try {
 const page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
 await page.goto(base+'?kunai=directions');
 await page.waitForFunction(()=>window.__KUNAI_EIGHT__?.ready,null,{timeout:120000});
 const state=()=>page.evaluate(()=>{const s=window.__KUNAI_EIGHT__;return {character:s.character,direction:s.direction,action:s.action,mode:s.mode,frame:s.frame,speed:s.speed,paused:s.paused,time:s.time,missing:s.missing,sprites:JSON.parse(s.sprites_json)}});
 const click=async label=>{const r=await page.evaluate(label=>JSON.parse(window.__KUNAI_EIGHT__.controls_json)[label],label);assert(r,label);await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(45)};
 assert.equal((await state()).speed,.5);assert.equal((await state()).character,'both');
 await click('Pause');const stopped=(await state()).time;await page.waitForTimeout(180);assert.equal((await state()).time,stopped);
 for(const direction of ['S','SE','E','NE','N','NW','W','SW']) {
  await click('combo');await click(direction);const seen=new Set();
  for(let n=0;n<18;n++) {
   const s=await state();assert.equal(s.missing,0);assert.equal(s.direction,direction);assert(s.paused);
   const key=s.action+'-'+s.frame;assert(!seen.has(key));seen.add(key);
   for(const id of ['player','bandit']) {
    const actual=s.sprites[id],expected=pack.characters[id][direction][s.action][s.frame];
    assert.equal(actual.body,expected.body_frame);assert.deepEqual(actual.hand_px,expected.right_hand_px);
    assert.deepEqual(actual.grip,[expected.right_hand_px[0]-64,expected.right_hand_px[1]-116]);
    assert.equal(actual.angle,expected.weapon_angle_deg);assert.equal(actual.layer,expected.weapon_layer);assert(actual.visible);
   }
   await page.screenshot({path:`${out}/${direction}-${key}.png`,clip:{x:100,y:90,width:1080,height:420}});
   records.push(s);await click('Step');
  }
  assert.equal((await state()).action,'light1');assert.equal((await state()).frame,0);
  for(const action of ['dash_attack','guard']) {
   await click(action);const count=action==='guard'?1:5;
   for(let n=0;n<count;n++){const s=await state();assert.equal(s.action,action);assert.equal(s.frame,n);assert.equal(s.missing,0);records.push(s);await click('Step')}
  }
 }
 await click('player');assert(!(await state()).sprites.bandit.visible);
 await click('bandit');assert(!(await state()).sprites.player.visible);
 await click('both');await click('Body');assert(!(await state()).sprites.player.body_visible);await click('Body');
 await click('Blade');assert(!(await state()).sprites.bandit.blade_visible);await click('Blade');
 await click('Trails');assert(!(await state()).sprites.player.trail_visible);await click('Trails');
 await click('Normal');assert.equal((await state()).speed,1);assert(!(await state()).paused);
 await click('Half speed');assert.equal((await state()).speed,.5);await click('Pause');
 for(const id of ['player','bandit'])assert((await state()).sprites[id].texture_cache<=198);
 await page.screenshot({path:`${out}/review-controls.png`});
 writeFileSync(`${out}/review.json`,JSON.stringify({base,records,errors},null,2));
 assert.deepEqual(errors,[]);
 console.log(`PASS: ${records.length} paired poses, 8 headings, exact stepping, sockets, layers and playback controls; no browser errors`);
} finally {await browser.close();if(server)await server.close()}
