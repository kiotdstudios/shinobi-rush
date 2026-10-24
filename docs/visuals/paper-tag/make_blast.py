import numpy as np, math, random, sys
from PIL import Image, ImageDraw, ImageFilter
W,H=384,384
CX,GY=192,282          # ground centre of the blast
N=60
BAYER=np.array([[0,32,8,40,2,34,10,42],[48,16,56,24,50,18,58,26],[12,44,4,36,14,46,6,38],[60,28,52,20,62,30,54,22],
[3,35,11,43,1,33,9,41],[51,19,59,27,49,17,57,25],[15,47,7,39,13,45,5,37],[63,31,55,23,61,29,53,21]])/64.0
def hexc(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))
SMOKE=[hexc(c) for c in ('#2a1c1c','#4d3a35','#76604f','#a58c74','#d0b898')]
SMOKE_HOT=[hexc(c) for c in ('#3a1814','#7a3a22','#b8622e','#e69446','#ffcf7a')]   # shadow..highlight
SMOKE_OUT=hexc('#1c1216')
FIRE=[hexc(c) for c in ('#5a0f12','#a3231a','#e2531b','#ff9a25','#ffd447','#fff6c8')]  # cold..hot
FIRE_OUT=hexc('#4a0d10')
def disc(mask,cx,cy,rx,ry):
    x0,x1=int(max(0,cx-rx-1)),int(min(W,cx+rx+2)); y0,y1=int(max(0,cy-ry-1)),int(min(H,cy+ry+2))
    if x1<=x0 or y1<=y0 or rx<=0.3 or ry<=0.3: return
    yy,xx=np.mgrid[y0:y1,x0:x1]
    mask[y0:y1,x0:x1]|=(((xx+0.5-cx)/rx)**2+((yy+0.5-cy)/ry)**2)<=1.0
def dil(m):
    o=m.copy()
    o[1:]|=m[:-1];o[:-1]|=m[1:];o[:,1:]|=m[:,:-1];o[:,:-1]|=m[:,1:]
    return o
class Puff:
    def __init__(s,rng,kind,t0,life,pos,vel,r0,grow,buoy=0.0,drag=2.2,heat=1.0,lobes=7,flat=1.0):
        s.kind,s.t0,s.life,s.p,s.v,s.r0,s.grow,s.buoy,s.drag,s.heat0,s.flat=kind,t0,life,pos,vel,r0,grow,buoy,drag,heat,flat
        s.lobes=[(rng.uniform(-.62,.62),rng.uniform(-.55,.45),rng.uniform(.5,.78)) for _ in range(lobes)]
        s.seed=rng.random()
    def state(s,t):
        a=t-s.t0
        if a<0 or a>s.life: return None
        k=s.drag; f=(1-math.exp(-k*a))/k
        x=s.p[0]+s.v[0]*f; y=s.p[1]+s.v[1]*f; z=s.p[2]+s.v[2]*f+s.buoy*a*a*0.5
        u=a/s.life
        r=s.r0+s.grow*math.sqrt(a)
        return x,y,z,r,u
def render(t,puffs,rng_sparks):
    img=np.zeros((H,W,4),np.uint8)
    order=[]
    for p in puffs:
        st=p.state(t)
        if st: order.append((p,st))
    # smoke first (back), sorted by depth then height; fire over it
    def key(o):
        p,(x,y,z,r,u)=o
        return (0 if p.kind=='smoke' else 1, y*0.5 - z*0.02)
    order.sort(key=key)
    for p,(x,y,z,r,u) in order:
        sx=CX+x; sy=GY+y*0.5-z
        base=np.zeros((H,W),bool)
        for ox,oy,lr in p.lobes:
            disc(base,sx+ox*r,sy+oy*r*p.flat,r*lr,r*lr*p.flat)
        if not base.any(): continue
        col=np.zeros((H,W,3),np.uint8)
        if p.kind=='smoke':
            warmv=max(0.0,1-u*1.7)*p.heat0
            SM=SMOKE_HOT if warmv>0.45 else SMOKE
            SMOKE_L=SM
            col[base]=SM[1]
            lay=np.zeros((H,W),bool)
            for ox,oy,lr in p.lobes: disc(lay,sx+ox*r-r*0.1,sy+oy*r*p.flat-r*0.12,r*lr*0.9,r*lr*0.9*p.flat)
            lay&=base; col[lay]=SM[2]
            lay2=np.zeros((H,W),bool)
            for ox,oy,lr in p.lobes: disc(lay2,sx+ox*r-r*0.2,sy+oy*r*p.flat-r*0.26,r*lr*0.62,r*lr*0.62*p.flat)
            lay2&=lay; col[lay2]=SM[3]
            lay3=np.zeros((H,W),bool)
            for ox,oy,lr in p.lobes[:4]: disc(lay3,sx+ox*r-r*0.28,sy+oy*r*p.flat-r*0.34,r*lr*0.28,r*lr*0.28*p.flat)
            lay3&=lay2; col[lay3]=SM[4]
            # bottom shadow band
            sh=base&~np.roll(np.roll(base,-max(2,int(r*0.18)),0),0,1)
            col[sh]=SM[0]
            # heat tint from the fireball below: warm the lower smoke early on
            out=SMOKE_OUT
            fade=1.0 if u<0.55 else max(0.0,1-(u-0.55)/0.45)
        else:
            heat=max(0.0,p.heat0*(1-u**1.7*0.95))
            lv=[min(5,int(heat*6))]
            col[base]=FIRE[max(0,min(5,int(heat*5.2)-0))]
            layers=[(0.0,0.0,0.92),(0.06,0.10,0.74),(0.12,0.2,0.52),(0.16,0.28,0.3)]
            for i,(dx,dy,sc) in enumerate(layers):
                hi=int(heat*5.2)-1+i
                if hi<0 or i==0: 
                    continue
                lay=np.zeros((H,W),bool)
                for ox,oy,lr in p.lobes: disc(lay,sx+ox*r-r*dx,sy+oy*r*p.flat-r*dy,r*lr*sc,r*lr*sc*p.flat)
                lay&=base
                col[lay]=FIRE[min(5,max(0,hi))]
            out=FIRE_OUT
            fade=1.0 if u<0.8 else max(0.0,1-(u-0.8)/0.2)
        ol=dil(base)&~base
        if fade<1.0:
            thr=BAYER[np.arange(H)[:,None]%8,np.arange(W)[None,:]%8]
            keep=thr<fade
            base&=keep; ol&=keep
        img[ol,:3]=out; img[ol,3]=255
        img[base,:3]=col[base]; img[base,3]=255
    return img
def build():
    rng=random.Random(7)
    P=[]
    def fire(n,t0a,t0b,la,lb,spread,vzr,r0r,gr,hr,buoy,flat=0.92,posz=(4,20),drag=(2.6,4.2),pos_xy=14):
        for i in range(n):
            a=rng.uniform(0,math.tau); d=rng.uniform(0,1)**0.6
            sp=rng.uniform(*spread)
            P.append(Puff(rng,'fire',rng.uniform(t0a,t0b),rng.uniform(la,lb),(rng.uniform(-pos_xy,pos_xy),rng.uniform(-pos_xy/2,pos_xy/2),rng.uniform(*posz)),
              (math.cos(a)*sp*d*0.9,math.sin(a)*sp*d*0.55,rng.uniform(*vzr)*(1-0.4*d)),rng.uniform(*r0r),rng.uniform(*gr),buoy=rng.uniform(*buoy),drag=rng.uniform(*drag),heat=rng.uniform(*hr),flat=flat))
    fire(40,0.02,0.16,0.8,1.3,(50,190),(60,230),(14,28),(20,40),(0.85,1.0),(30,110))
    fire(18,0.2,0.6,0.55,0.95,(20,110),(70,170),(9,16),(10,18),(0.6,0.9),(80,170),flat=1.15,posz=(10,50),pos_xy=34)
    # cook-off secondary pops
    for tt,(ox,oy) in ((0.26,(-46,12)),(0.38,(52,-10)),(0.5,(-8,-26))):
        for i in range(9):
            a=rng.uniform(0,math.tau); sp=rng.uniform(30,110)
            P.append(Puff(rng,'fire',tt+rng.uniform(0,.05),rng.uniform(.45,.7),(ox+rng.uniform(-8,8),oy*1.0,rng.uniform(10,40)),
              (math.cos(a)*sp,math.sin(a)*sp*.5,rng.uniform(30,140)),rng.uniform(8,15),rng.uniform(12,22),buoy=rng.uniform(40,120),drag=3.2,heat=.95,flat=.95))
    # smoke head + column
    for i in range(62):
        a=rng.uniform(0,math.tau); d=rng.uniform(0.15,1)
        sp=rng.uniform(60,210)
        t0=0.12+rng.uniform(0,0.65)
        P.append(Puff(rng,'smoke',t0,rng.uniform(0.8,1.25),(rng.uniform(-34,34),rng.uniform(-20,20),rng.uniform(10,80)),
          (math.cos(a)*sp*d,math.sin(a)*sp*d*0.55,rng.uniform(50,230)),rng.uniform(18,32),rng.uniform(26,50),buoy=rng.uniform(40,110),drag=2.7,heat=rng.uniform(.3,1),flat=0.9))
    # low dust ring puffs
    for i in range(34):
        a=i/34*math.tau+rng.uniform(-.1,.1); sp=rng.uniform(220,330)
        P.append(Puff(rng,'smoke',0.03+rng.uniform(0,.06),rng.uniform(0.5,0.85),(math.cos(a)*24,math.sin(a)*24,2),
          (math.cos(a)*sp,math.sin(a)*sp*0.8,rng.uniform(10,40)),rng.uniform(8,13),rng.uniform(12,20),buoy=40,drag=5.2,heat=.3,flat=0.8))
    return P
def spikes(t):
    img=np.zeros((H,W,4),np.uint8)
    if t>0.2: return img
    u=t/0.2
    pil=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(pil)
    r=SR=0
    rr=random.Random(3)
    for layer,(scale,colr) in enumerate([(1.0,FIRE[2]),(0.78,FIRE[3]),(0.52,FIRE[4]),(0.28,FIRE[5])]):
        pts=[]
        n=14
        for i in range(n*2):
            ang=i/(n*2)*math.tau
            base=(40+150*math.sqrt(u))*scale
            rad=base*(1.0 if i%2==0 else 0.38)*(0.75+0.5*rr.random() if layer==0 else 1)
            if layer==0 and i%2==0: rad*=1+0.35*(i%4==0)
            pts.append((CX+math.cos(ang)*rad,GY-30*(1-u)+math.sin(ang)*rad*0.62))
        d.polygon(pts,fill=colr+(255,),outline=(FIRE_OUT+(255,)) if layer==0 else None)
    a=np.array(pil)
    fade=1.0 if u<0.6 else max(0,1-(u-0.6)/0.4)
    thr=BAYER[np.arange(H)[:,None]%8,np.arange(W)[None,:]%8]
    a[...,3]=np.where((a[...,3]>0)&(thr<fade),255,0)
    return a
def ring(t):
    pil=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(pil)
    if t>0.5: return np.array(pil)
    u=t/0.5; r=30+205*(1-(1-u)**2.2)
    th=max(1,int(11*(1-u)))
    for k,c in enumerate([(235,214,170),(190,160,120)]):
        rx=r-k*th*0.9; 
        if rx>2: d.ellipse([CX-rx,GY-rx*.5,CX+rx,GY+rx*.5],outline=c+(255,),width=max(1,th-k*2))
    a=np.array(pil); fade=max(0,1-u**1.5)
    thr=BAYER[np.arange(H)[:,None]%8,np.arange(W)[None,:]%8]
    a[...,3]=np.where((a[...,3]>0)&(thr<fade),255,0)
    return a
class Spark:
    def __init__(s,rng,kind):
        a=rng.uniform(0,math.tau); sp=rng.uniform(150,420) if kind=='ember' else rng.uniform(80,240)
        s.kind=kind; s.v=(math.cos(a)*sp,math.sin(a)*sp*0.5,rng.uniform(140,360) if kind=='ember' else rng.uniform(120,300)); s.t0=rng.uniform(0,0.1)
        s.life=rng.uniform(0.5,1.2) if kind=='ember' else 1.4; s.sz=rng.choice([1,2,2,3]) if kind=='ember' else rng.choice([3,4,5])
def sparks(t,S):
    img=np.zeros((H,W,4),np.uint8)
    for s in S:
        a=t-s.t0
        if a<0 or a>s.life: continue
        def pos(a):
            return CX+s.v[0]*a, GY+s.v[1]*a*1.0 - (s.v[2]*a-420*a*a), (s.v[2]*a-420*a*a)
        x,y,z=pos(a)
        if z<0 and s.kind=='chunk': 
            z=0; y=GY+s.v[1]*a
        u=a/s.life
        if s.kind=='ember':
            for k in range(4):
                xx,yy,zz=pos(max(0,a-k*0.012)); 
                if zz<0: continue
                c=FIRE[max(0,4-k-int(u*3))]
                xi,yi=int(xx),int(yy); sz=max(1,s.sz-(k>1))
                if 0<=xi<W-sz and 0<=yi<H-sz and (u<0.8 or (xi+yi)%2==0): img[yi:yi+sz,xi:xi+sz,:3]=c; img[yi:yi+sz,xi:xi+sz,3]=255
        else:
            xi,yi=int(x),int(y); sz=s.sz
            if 0<=xi<W-sz-1 and 0<=yi<H-sz-1:
                img[yi:yi+sz+1,xi:xi+sz+1,:3]=(24,14,14); img[yi:yi+sz+1,xi:xi+sz+1,3]=255
                img[yi:yi+sz,xi:xi+sz,:3]=(92,60,44) if u<0.9 else (60,40,34)
                img[yi,xi:xi+sz,:3]=(140,98,70)
    return img
def glow(t):
    yy,xx=np.mgrid[0:H,0:W]
    out=np.zeros((H,W,3),np.float32)
    def add(cx,cy,rx,ry,col,amp):
        d=((xx-cx)/rx)**2+((yy-cy)/ry)**2
        v=np.exp(-d*2.2)*amp
        out[...]+=v[...,None]*np.array(col,np.float32)/255.0
    f=lambda u:max(0.0,1-u)
    add(CX,GY-40,120*(0.4+t*2),90*(0.4+t*1.8),(255,150,40),1.1*f(t/1.0))
    add(CX,GY-30,60+90*t,45+70*t,(255,240,170),1.6*f(t/0.35))
    add(CX,GY+4,200,70,(255,110,30),0.9*f(t/1.4))
    a=np.clip(out,0,1)
    return (a*255).astype(np.uint8)
if __name__=='__main__':
    P=build(); rng=random.Random(11)
    S=[Spark(rng,'ember') for _ in range(40)]+[Spark(rng,'chunk') for _ in range(9)]
    frames=[];glows=[]
    for i in range(N):
        t=i/30.0
        base=Image.new('RGBA',(W,H),(0,0,0,0))
        for layer in (ring(t),render(t,P,None),spikes(t),sparks(t,S)):
            base.alpha_composite(Image.fromarray(layer,'RGBA'))
        frames.append(base)
        g=glow(t); glows.append(Image.fromarray(g,'RGB'))
    import os
    out=sys.argv[1] if len(sys.argv)>1 else '.'
    os.makedirs(out,exist_ok=True)
    for i,(f,g) in enumerate(zip(frames,glows)):
        f.save(f'{out}/blast_{i:02d}.png'); g.save(f'{out}/glow_{i:02d}.png')
    # preview sheet over dark floor
    idx=[0,2,4,7,10,14,18,23,28,34,40,46]
    sh=Image.new('RGBA',(W*6//2*1,H*2//2*1))
    sh=Image.new('RGBA',(W*6//2,H*2//2),(26,24,30,255))
    for k,i in enumerate(idx):
        bg=Image.new('RGBA',(W,H),(36,34,40,255))
        gl=np.array(glows[i]).astype(np.int32)+np.array(bg.convert('RGB')).astype(np.int32)
        bg=Image.fromarray(np.clip(gl,0,255).astype(np.uint8),'RGB').convert('RGBA'); bg.alpha_composite(frames[i])
        sh.paste(bg.resize((W//2,H//2),Image.NEAREST),((k%6)*W//2,(k//6)*H//2))
    sh.save(f'{out}/sheet.png')
