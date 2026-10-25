import json,urllib.request,concurrent.futures
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[3]
jobs=json.loads((Path(__file__).parent/'jobs.json').read_text(encoding='utf-8-sig'))
def fetch(task):
 job,i=task; out=root/'assets/pickups'/job['kind']/'source'/job['layer'];out.mkdir(parents=True,exist_ok=True)
 p=out/f'{i:02}.png'
 if not p.exists():
  with urllib.request.urlopen(f"https://api.pixellab.ai/mcp/images/{job['id']}/download?index={i}",timeout=120) as response:p.write_bytes(response.read())
 im=Image.open(p); expected=(256,256) if job['layer'] in ['smoke','billow'] else (128,128)
 assert im.size==expected and im.mode=='RGBA',(p,im.size,im.mode)
 return str(p)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for p in pool.map(fetch,[(j,i) for j in jobs for i in range(j['frames']+1)]): print(Path(p).parent.parent.parent.name,Path(p).parent.name,Path(p).name,flush=True)
for kind in ['tag_bomb','smoke_tag_bomb']:
 base=root/'assets/pickups'/kind; layers={}; sheet=Image.new('RGBA',(8*128,6*152),(20,29,35,255)); draw=ImageDraw.Draw(sheet)
 for row,job in enumerate(j for j in jobs if j['kind']==kind):
  frames=[]; hashes=[]
  for i in range(job['frames']):
   im=Image.open(base/'source'/job['layer']/f'{i+1:02}.png').convert('RGBA')
   assert im.getbbox() is not None
   if kind=='smoke_tag_bomb' and job['layer'] not in ['smoke','billow']:
    # Exact native-pixel palette correction: keep scarlet seams; neutralize cool-gray ink/body.
    data=[]
    for r,g,b,a in im.getdata():
     if a and not (r>g*1.25 and r>b*1.15):
      v=round(0.2126*r+0.7152*g+0.0722*b);r=g=b=v
     data.append((r,g,b,a))
    im.putdata(data)
   name=f"{job['layer']}_{i:02}.png";im.save(base/name);frames.append(name);hashes.append(hash(im.tobytes()))
   if job['layer'] not in ['smoke','billow']:
    x=(i%8)*128;y=row*304+(i//8)*152
    sheet.alpha_composite(im,(x,y));draw.text((x+4,y+130),f"{job['layer']} {i:02}",fill='white')
  layers[job['layer']]={'frames':frames,'frame_size':list(im.size),'fps':14 if job['layer'] in ['idle','billow'] else 40 if job['layer']=='fly' else 18 if job['layer'] in ['smoke','billow'] else 16,'loop':job['layer']!='smoke','unique_frames':len(set(hashes)),'anchor':[128,208] if job['layer'] in ['smoke','billow'] else [64,64]}
 (base/f'{kind}.art.json').write_text(json.dumps({'schema':1,'id':kind,'generator':'PixelLab','layers':layers,'runtime_body_scale':0.5,'pickup_glow':'existing paper_tag aura/embers tinted independently','effects':'existing paper_tag_blast' if kind=='tag_bomb' else 'independent layered smoke; no damage; no AI stealth'},indent=2)+'\n')
 sheet.convert('RGB').save(Path(__file__).parent/f'{kind}-contact.png')
print('Exported and checked native frames')
