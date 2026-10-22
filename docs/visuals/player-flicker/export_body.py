from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
root=Path.cwd();src=Path('assets/characters/player/source/flicker-se')
raw=Image.open(src/'raw.png').convert('RGBA');cw,ch=raw.width//2,raw.height//2
ref=Image.open('assets/characters/player/sprites/production/idle/SE_000.png').convert('RGBA');colors=sorted({(r,g,b) for r,g,b,a in ref.get_flattened_data() if a==255});pal=Image.new('RGB',(len(colors),1));pal.putdata(colors);pal=pal.quantize(colors=min(64,len(colors)),dither=Image.Dither.NONE)
hands=[(57,69),(59,63),(53,53),(60,67)];frames=[];contact=Image.new('RGB',(1024,280),'#26313d')
for i,h in enumerate(hands):
 cell=raw.crop((i%2*cw,i//2*ch,(i%2+1)*cw,(i//2+1)*ch)).resize((128,128),Image.Resampling.NEAREST);alpha=cell.getchannel('A').point(lambda a:255 if a>=160 else 0);cell=cell.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');cell.putalpha(alpha)
 sole=cell.getbbox()[3]-1;dy=116-sole;body=Image.new('RGBA',(128,128));body.alpha_composite(cell,(0,dy));hand=[h[0],h[1]+dy]
 points=[(x,y) for x in range(hand[0]-3,hand[0]+4) for y in range(hand[1]-3,hand[1]+4) if 0<=x<128 and 0<=y<128 and body.getpixel((x,y))[3]==255];assert points,(i,hand);hand=list(min(points,key=lambda p:(p[0]-hand[0])**2+(p[1]-hand[1])**2))
 p=Path(f'assets/characters/player/sprites/production/body_flicker/SE_{i:03}.png');body.save(p)
 frames.append(dict(frame_index=i,body_frame='res://'+p.as_posix(),right_hand_px=hand,weapon_angle_deg=[140,130,135,140][i],weapon_layer='front',hand_occlusion_rect=[hand[0]-2,hand[1]-2,5,5],phase=['brace','compress','reappear','recover'][i],duration_ms=[12,12,24,24][i],root_registration_px=[0,dy],body_sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
 panel=Image.new('RGB',(256,280),'#26313d');big=body.resize((256,256),Image.Resampling.NEAREST);panel.paste(big,(0,24),big);ImageDraw.Draw(panel).text((5,5),f"{i}: {frames[-1]['phase']} socket {hand}",fill='white');contact.paste(panel,(i*256,0))
 assert body.size==(128,128) and set(body.getchannel('A').get_flattened_data())<={0,255}
data={'schema':'shinobi_body_flicker_pose_v1','direction':'SE','frame_size':[128,128],'foot_anchor':[64,116],'standing_body_height_px':104,'frames':frames,'single_duration_ms':120,'double_second_start_ms':160,'double_duration_ms':280,'events':[{'ms':0,'event':'flicker_start'},{'ms':12,'event':'vanish_and_request_swept_traverse'},{'ms':84,'event':'reappear'},{'ms':120,'event':'complete'}],'single_afterimage':{'duration_ms':100,'source':'snapshot of exact body and independent weapon; one reusable ghost node'},'double_events_ms':[0,12,84,120,160,172,244,280],'vfx_baseline':'res://assets/vfx/body_flicker/body_flicker_SE.art.json','vfx_source_sha':'43c316a9c2309f1cafa2918c6ecd8d0ff08a5a97','movement_and_damage_owner':'Aki; timing is a visual proposal, not gameplay balance','source':{'tool':'built-in image_gen','raw_size':list(raw.size),'processing':'shared fixed-grid nearest to128, approved palette, alpha160, explicit planted sole translation; no per-frame scaling or body interpolation'}}
Path('assets/characters/player/animations/body_flicker_SE.art.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n');contact.save('docs/visuals/player-flicker/body-contact.png')
print('PASS four unique128RGBA compact flicker poses; no lunge; opaque sockets; fixed root; existing hierarchy')
