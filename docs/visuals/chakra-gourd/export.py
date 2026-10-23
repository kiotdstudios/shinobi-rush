"""Extract PixelLab frames/effect sheet and render matching pickup review previews."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import json,math,hashlib,numpy as np
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
ART=ROOT/'assets/pickups/chakra_gourd';SOURCE=ART/'source';HEALTH=ROOT/'assets/pickups/health_gourd'

def rgba(path):return Image.open(path).convert('RGBA')
def main():
 raw=sorted((SOURCE/'body').glob('*.png'));assert len(raw)==17
 body=[rgba(p) for p in raw];assert all(x.size==(64,96) for x in body)
 # Don't give an identical closing key a double hold at the loop seam.
 closing=body[-1].tobytes()==body[0].tobytes()
 if closing:body.pop()
 for n,im in enumerate(body):im.save(ART/f'gourd_{n:02}.png')
 sheet=rgba(SOURCE/'blue-sparks-sheet.png');assert sheet.size==(288,288)
 for n in range(9):sheet.crop(((n%3)*96,(n//3)*96,(n%3+1)*96,(n//3+1)*96)).save(ART/f'ember_{n:02}.png')
 rgba(SOURCE/'blue-glow.png').save(ART/'glow_00.png')
 for layer in ['glow','ember']:
  for path in ART.glob(layer+'_*.png'):
   old=np.asarray(rgba(HEALTH/path.name));new=np.asarray(rgba(path));assert np.array_equal(old[:,:,3],new[:,:,3])
   visible=old[:,:,3]>0;assert np.array_equal(new[:,:,:3][visible],old[:,:,[2,1,0]][visible]),path
 boxes=[im.getbbox() for im in body]
 manifest={'schema':1,'id':'chakra_gourd','status':'art_review','production_bound':False,'generator':'PixelLab','layers':{'gourd':{'frames':[f'gourd_{n:02}.png' for n in range(len(body))],'frame_size':[64,96],'fps':14,'loop':True},'glow':{'frames':['glow_00.png'],'frame_size':[96,96],'fps':12,'loop':True,'blend':'add'},'ember':{'frames':[f'ember_{n:02}.png' for n in range(9)],'frame_size':[96,96],'fps':12,'loop':'ping_pong','blend':'add'}},'presentation':{'float_height':56,'bob_px':4,'bob_radians_per_second':2.3,'pulse_radians_per_second':3.1,'glow_rotation_radians_per_second':.35,'glow_scale':[1.25,1.55],'glow_modulate':[.4,.7,1],'floor_color':[.1,.45,1],'floor_radii':[46,12],'floor_y_scale':.5,'beam_height':170},'qc':{'body_unique':len({x.tobytes() for x in body}),'body_height_range':[min(b[3]-b[1] for b in boxes),max(b[3]-b[1] for b in boxes)],'body_bboxes':boxes,'closing_duplicate_removed':closing,'effects_exact_health_geometry_and_alpha':True,'effect_palette_operation':'PixelLab map_colors; RGBA R/B exchange, alpha unchanged'},'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ART.glob('*.png')}}
 (ART/'chakra_gourd.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
 render_previews(body)
 print(json.dumps(manifest['qc']))

def add_sprite(canvas,im,cx,cy,alpha=1,scale=1,angle=0,add=False,tint=(1,1,1)):
 im=im.copy()
 if tint!=(1,1,1) or alpha!=1:
  a=np.array(im);a[:,:,:3]=(a[:,:,:3]*np.array(tint)).clip(0,255).astype('uint8');a[:,:,3]=(a[:,:,3]*alpha).astype('uint8');im=Image.fromarray(a)
 if scale!=1:im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
 if angle:im=im.rotate(angle,Image.Resampling.NEAREST,expand=True)
 pos=(round(cx-im.width/2),round(cy-im.height/2));layer=Image.new('RGBA',canvas.size);layer.paste(im,pos)
 if add:
  a=np.array(layer);a[:,:,:3]=(a[:,:,:3].astype(float)*(a[:,:,3:4]/255)).astype('uint8');a[:,:,3]=255
  canvas.paste(ImageChops.add(canvas.convert('RGB'),Image.fromarray(a).convert('RGB')).convert('RGBA'))
 else:canvas.alpha_composite(layer)

def render_previews(blue):
 red=[rgba(p) for p in sorted(HEALTH.glob('gourd_*.png'))]
 colors=[(1,.18,.1),(.1,.45,1)];seq=[]
 for n in range(84):
  t=n/14;canvas=Image.new('RGBA',(360,260),'#15212c');draw=ImageDraw.Draw(canvas);draw.text((8,8),'HEALTH / CHAKRA - separate body + glow + sparks',fill='white')
  for i,(folder,frames,cx) in enumerate([(HEALTH,red,90),(ART,blue,270)]):
   pulse=.5+.5*math.sin(t*3.1);color=colors[i];pool=Image.new('RGBA',canvas.size);pd=ImageDraw.Draw(pool)
   for j in range(7):
    k=j/6;r=(46+(12-46)*k)*(.94+.06*pulse);a=(.05+(.2-.05)*k)*(.8+.4*pulse)
    pd.ellipse((cx-r,225-r*.5,cx+r,225+r*.5),fill=tuple(round(c*255) for c in color)+(round(a*255),))
   # Floor beam presentation is engine-drawn in HealthGourd; preview the same dimensions/colour.
   for y in range(170):
    width=9+8*y/170;alpha=(.16+.07*pulse)*y/170
    pd.line((cx-width,55+y,cx+width,55+y),fill=tuple(round(c*255) for c in color)+(round(alpha*255),))
   canvas.alpha_composite(pool)
   bob=round(math.sin(t*2.3)*4);gbob=round(math.sin(t*2.3-.7)*4)
   add_sprite(canvas,rgba(folder/'glow_00.png'),cx,169+gbob,alpha=.6+.4*pulse,scale=1.25+.3*pulse,angle=-t*.35*180/math.pi,add=True,tint=(1,.5,.4) if i==0 else (.4,.7,1))
   add_sprite(canvas,frames[int(t*14)%len(frames)],cx,169+bob)
   key=int(t*12)%16;key=key if key<=8 else 16-key
   add_sprite(canvas,rgba(folder/f'ember_{key:02}.png'),cx,169,add=True)
  seq.append(canvas.convert('RGB').resize((720,520),Image.Resampling.NEAREST))
 for speed,label in [(1,'normal'),(.5,'half-speed')]:
  holds=[round((n+1)*100/14/speed)*10-round(n*100/14/speed)*10 for n in range(84)]
  seq[0].save(HERE/f'{label}.gif',save_all=True,append_images=seq[1:],duration=holds,loop=0,optimize=False,disposal=2)
 seq[12].save(HERE/'comparison.png')
 sheet=Image.new('RGBA',(384,((len(blue)+3)//4)*112),'#15212c');draw=ImageDraw.Draw(sheet)
 for n,im in enumerate(blue):sheet.alpha_composite(im,((n%4)*96+16,(n//4)*112));draw.text(((n%4)*96+8,(n//4)*112+98),f'{n:02}',fill='white')
 sheet.save(HERE/'contact-sheet.png')
if __name__=='__main__':main()
