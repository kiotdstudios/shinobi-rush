"""Extract generated drawings; chroma cleanup/nearest sampling/registration, never synthesize art."""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
ASSET=ROOT/'assets/vfx/chakra_charge_blue_v2'
PARTS=['buildup','sustain-a','sustain-b','sustain-c','sustain-d','release']
ANCHOR=(128,224)
def clean(im):
 a=np.array(im.convert('RGBA'));r,g,b=[a[:,:,n].astype(float) for n in range(3)]
 bg=(r>g+24)&(r>b*.65) # remove magenta/pink antialias fringes; blue/white cores remain
 a[:,:,3]=np.where(bg,0,255)
 a[a[:,:,3]==0,:3]=0
 return Image.fromarray(a)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 allframes=[];records=[];sources={};qc={}
 (ASSET/'frames').mkdir(exist_ok=True)
 for part in PARTS:
  path=ASSET/'source'/f'{part}-final.png';raw=Image.open(path);w,h=raw.size;cells=[];roots=[]
  for n in range(16):
   x,y=n%4,n//4
   cell=clean(raw.crop((round(x*w/4),round(y*h/4),round((x+1)*w/4),round((y+1)*h/4)))).resize((256,256),Image.Resampling.NEAREST)
   box=cell.getbbox();assert box is not None
   assert min(box[:2])>0 and box[2]<256 and box[3]<256,(part,n,'source edge contact',box)
   a=np.asarray(cell);white=(a[:,:,0]>140)&(a[:,:,1]>190)&(a[:,:,2]>220)&(a[:,:,3]>0)
   white[:170]=False;white[:,:88]=False;white[:,168:]=False
   yy,xx=np.where(white)
   if len(yy)>4:
    ry=int(yy.max());rx=float(np.median(xx[yy>=ry-2]));roots.append((rx,ry))
   cells.append(cell)
  # One registration for the complete sheet, no per-frame zoom/bbox fitting.
  rx,ry=np.median(roots,axis=0) if roots else (128,215)
  if part=='release':rx,ry=(128,215)
  dx,dy=round(ANCHOR[0]-rx),round(ANCHOR[1]-ry)
  partframes=[]
  order=list(range(16))
  if part=='sustain-c':order=order[4:]+order[:4] # enter/leave this pulse at its established full-charge phase
  for n,source_index in enumerate(order):
   cell=cells[source_index]
   box=cell.getbbox();assert box[0]+dx>=0 and box[1]+dy>=0 and box[2]+dx<=256 and box[3]+dy<=256,(part,n,'clamped')
   frame=Image.new('RGBA',(256,256));frame.paste(cell,(dx,dy))
   output=ASSET/'frames'/f'{len(allframes):03}.png';frame.save(output)
   records.append({'index':len(allframes),'phase':'sustain' if part.startswith('sustain') else part,'source_sheet':path.name,'source_frame':source_index,'path':str(output.relative_to(ASSET)).replace('\\','/'),'sha256':sha(output),'duration_ms':1000/24})
   allframes.append(frame);partframes.append(frame)
  sources[path.name]={'sha256':sha(path),'size':[w,h],'grid':[4,4],'registration':[dx,dy]}
  qc[part]={'frames':16,'unique':len({f.tobytes() for f in partframes}),'root_measurements':roots,'sheet_translation':[dx,dy],'source_edge_contact':False,'paste_clamping':False}
 assert len(allframes)==96 and len({f.tobytes() for f in allframes})==96
 atlas=Image.new('RGBA',(256*8,256*12))
 for n,frame in enumerate(allframes):atlas.paste(frame,((n%8)*256,(n//8)*256))
 atlas.save(ASSET/'sheet.png')
 manifest={'schema':1,'status':'new_reference_candidate_for_owner_review','frame_size':[256,256],'ground_anchor':list(ANCHOR),'fps':24,'half_speed_fps':12,'frame_count':96,'unique_drawings':96,'sequences':{'buildup':{'from':0,'to':15,'loop':False},'sustain':{'from':16,'to':79,'loop':True},'release':{'from':80,'to':95,'loop':False}},'body':'none; approved idle used only in scale-preview','production_bound':False,'reference':{'file':'source/reference-pink.png','sha256':sha(ASSET/'source/reference-pink.png'),'frames':9,'cell_size':[32,32]},'generator':'builtin image_gen; PixelLab reviewed, not used','processing':'chroma cleanup, fixed-cell nearest scaling, one translation per sheet; no procedural effects, tweening or repeated frame padding','sources':sources,'frames':records}
 (ASSET/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (HERE/'qc.json').write_text(json.dumps(qc,indent=2)+'\n')
 body=Image.open(ROOT/'assets/characters/player/sprites/production/idle/SE_000.png').convert('RGBA')
 previews=[];fx=[]
 for frame in allframes:
  bg=Image.new('RGBA',(512,400),'#1d2935');d=ImageDraw.Draw(bg);d.text((18,16),'BLUE CHARGE V2 | 96 UNIQUE FRAMES | 24 FPS',fill='white')
  bg.alpha_composite(body,(192,224-116+96));bg.alpha_composite(frame,(128,96))
  d.text((18,367),'Approved idle for scale only; no new charging body.',fill='#a8c5db')
  previews.append(bg.convert('RGB'))
  blank=Image.new('RGBA',(320,320),'#1d2935');blank.alpha_composite(frame,(32,32));fx.append(blank.convert('RGB'))
 for frames,name in [(previews,'character-preview'),(fx,'effect-preview')]:
  for speed,label in [(1,'normal'),(.5,'half-speed')]:
   holds=[round((n+1)*100/24/speed)*10-round(n*100/24/speed)*10 for n in range(96)]
   frames[0].save(HERE/f'{name}-{label}.gif',save_all=True,append_images=frames[1:],duration=holds,loop=0,disposal=2,optimize=False)
  loop=frames[16:80]
  loop[0].save(HERE/f'{name}-sustain-half-speed.gif',save_all=True,append_images=loop[1:],duration=[round((n+1)*100/12)*10-round(n*100/12)*10 for n in range(64)],loop=0,disposal=2,optimize=False)
 contact=Image.new('RGB',(256*8,280*12),'#1d2935');d=ImageDraw.Draw(contact)
 for n,frame in enumerate(allframes):
  x,y=n%8*256,n//8*280;contact.paste(frame,(x,y+24),frame);d.text((x+8,y+6),f'{n:02} {records[n]["phase"]}',fill='white')
 contact.save(HERE/'contact-sheet.png')
 print('PASS:96 unique RGBA frames, sources contained, no clamping; previews and manifest exported')
if __name__=='__main__':main()
