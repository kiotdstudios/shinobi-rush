import numpy as np, math, random, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
S=8                      # master supersample
TW,TH=40,72              # native tag size
rng=random.Random(5)
def hexc(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))
OUT=hexc('#1b0f12')
def noise(w,h,scale,seed):
    r=np.random.RandomState(seed); n=r.rand(h//scale+2,w//scale+2)
    return np.array(Image.fromarray((n*255).astype(np.uint8)).resize((w,h),Image.BICUBIC)).astype(np.float32)/255
def master(burn=0.0):
    W,H=TW*S,TH*S
    paper=np.zeros((H,W,3),np.float32)
    yy,xx=np.mgrid[0:H,0:W]
    base=np.array(hexc('#f0e4b6'),np.float32); dark=np.array(hexc('#cdb985'),np.float32)
    t=np.clip(0.25*(yy/H)+0.55*(xx/W)**1.5+0.25*noise(W,H,10,1),0,1)[...,None]
    paper[:]=base*(1-t)+dark*t
    fib=noise(W,H,3,2)
    paper*= (0.96+0.06*fib)[...,None]
    im=Image.fromarray(np.clip(paper,0,255).astype(np.uint8),'RGB').convert('RGBA')
    d=ImageDraw.Draw(im)
    b=int(3.2*S)
    # red border
    d.rectangle([0,0,W-1,H-1],fill=hexc('#a9263a')+(255,))
    d.rectangle([b,b,W-1-b,H-1-b],fill=(0,0,0,0))
    inner=Image.fromarray(np.clip(paper,0,255).astype(np.uint8),'RGB').convert('RGBA')
    mask=Image.new('L',(W,H),0); ImageDraw.Draw(mask).rectangle([b,b,W-1-b,H-1-b],fill=255)
    im.paste(inner,(0,0),mask)
    d=ImageDraw.Draw(im)
    d.rectangle([b-3,b-3,W-1-b+3,H-1-b+3],outline=hexc('#5e1020')+(255,),width=3)
    d.rectangle([2,2,W-3,H-3],outline=hexc('#cf4455')+(255,),width=3)
    ink=hexc('#17121a')
    # brush squiggle columns
    def squiggle(cx,y0,y1,w,amp,seg):
        pts=[];y=y0
        while y<y1:
            pts.append((cx+rng.uniform(-amp,amp),y)); y+=seg*rng.uniform(.6,1.4)
        for i in range(len(pts)-1):
            wd=int(w*rng.uniform(.6,1.5))
            d.line([pts[i],pts[i+1]],fill=ink+(255,),width=wd)
            d.ellipse([pts[i][0]-wd/2,pts[i][1]-wd/2,pts[i][0]+wd/2,pts[i][1]+wd/2],fill=ink+(255,))
    inner_l,inner_r=b+3*S//2,W-b-3*S//2
    cols=[inner_l+ (inner_r-inner_l)*f for f in (0.14,0.5,0.86)]
    for c in cols:
        squiggle(c,b+S*2,int(H*0.26),int(1.0*S),int(1.7*S),int(2.2*S))
        squiggle(c,int(H*0.72),H-b-int(11*S),int(1.0*S),int(1.7*S),int(2.2*S))
    for c in (cols[0],cols[2]):
        squiggle(c,int(H*0.30),int(H*0.68),int(1.0*S),int(1.4*S),int(2.4*S))
    # big kanji 爆
    f=ImageFont.truetype('C:/Windows/Fonts/YuGothB.ttc',int(25*S))
    tw=d.textbbox((0,0),'爆',font=f)
    gx=(W-(tw[2]-tw[0]))//2-tw[0]; gy=int(H*0.5-(tw[3]-tw[1])/2)-tw[1]
    glyph=Image.new('L',(W,H),0); ImageDraw.Draw(glyph).text((gx,gy),'爆',font=f,fill=255)
    g=np.array(glyph).astype(np.float32)/255
    
    g=np.array(Image.fromarray((g*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(S*0.18)))>120
    arr=np.array(im); arr[g,:3]=ink; arr[g,3]=255
    im=Image.fromarray(arr,'RGBA'); d=ImageDraw.Draw(im)
    # red seal
    sx,sy=W//2,H-b-int(6*S)
    d.rectangle([sx-int(4*S),sy-int(4*S),sx+int(4*S),sy+int(4*S)],fill=hexc('#a9263a')+(255,),outline=hexc('#5e1020')+(255,),width=S//2)
    for k in range(5):
        x0=sx-int(3*S)+rng.randint(0,int(3*S)); y0=sy-int(3*S)+rng.randint(0,int(3*S))
        d.line([x0,y0,x0+rng.randint(S,3*S),y0+rng.randint(0,2*S)],fill=hexc('#f0e4b6')+(255,),width=S//2)
    # scorched corner
    arr=np.array(im).astype(np.float32)
    yy,xx=np.mgrid[0:H,0:W]
    dist=np.sqrt(((xx-W*1.05)/ (W*0.9))**2+((yy-H*1.02)/(H*0.22))**2)
    sc=np.clip(1-dist,0,1)*(0.6+0.8*noise(W,H,6,4))
    sc=np.clip(sc*1.4,0,1)[...,None]
    arr[...,:3]=arr[...,:3]*(1-0.7*sc)+np.array(hexc('#2a1612'),np.float32)*0.7*sc
    return Image.fromarray(np.clip(arr,0,255).astype(np.uint8),'RGBA')
M=master()
M.save('master.png')
def palette_from(images,n=30):
    w=sum(i.width for i in images); h=max(i.height for i in images)
    sheet=Image.new('RGB',(w,h),(0,0,0)); x=0
    for i in images:
        bg=Image.new('RGB',i.size,(0,0,0)); bg.paste(i.convert('RGB'),mask=i.split()[3]); sheet.paste(bg,(x,0)); x+=i.width
    q=sheet.quantize(colors=n,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    pal=np.array(q.getpalette()[:n*3]).reshape(-1,3)
    return pal
def quant(img,pal,outline=True,hard=140):
    a=np.array(img.convert('RGBA'))
    al=a[...,3]>=hard
    rgb=a[...,:3].astype(np.int32)
    d=((rgb[:,:,None,:]-pal[None,None,:,:].astype(np.int32))**2).sum(-1)
    idx=d.argmin(-1); out=pal[idx].astype(np.uint8)
    res=np.zeros(a.shape,np.uint8); res[...,:3]=out; res[...,3]=np.where(al,255,0)
    if outline:
        p=np.pad(al,1); nb=p[:-2,1:-1]|p[2:,1:-1]|p[1:-1,:-2]|p[1:-1,2:]
        ol=nb&~al
        res[ol,:3]=OUT; res[ol,3]=255
    return Image.fromarray(res,'RGBA')
def box_down(img,f):
    return img.resize((img.width//f,img.height//f),Image.BOX)
def place(canvas_size,img,anchor=(0.5,0.5),off=(0,0)):
    c=Image.new('RGBA',canvas_size,(0,0,0,0))
    c.alpha_composite(img,(int(canvas_size[0]*anchor[0]-img.width/2+off[0]),int(canvas_size[1]*anchor[1]-img.height/2+off[1])))
    return c
def yaw_view(m,yaw,roll,shade=True):
    W,H=m.size
    sx=max(0.06,abs(math.cos(yaw)))
    back=math.cos(yaw)<0
    img=m.transpose(Image.FLIP_LEFT_RIGHT) if back else m
    if back:
        a=np.array(img).astype(np.float32); a[...,:3]=a[...,:3]*0.82+np.array([30,24,18],np.float32)*0.18  # paper back, ink bleeds faintly
        img=Image.fromarray(a.astype(np.uint8),'RGBA')
    img=img.resize((max(1,int(W*sx)),H),Image.BILINEAR)
    if shade:
        a=np.array(img).astype(np.float32)
        k=math.sin(yaw)  # one side turns away
        grad=np.linspace(1+0.12*k,1-0.22*abs(k)-0.12*k,img.width)[None,:,None]
        a[...,:3]*=grad; img=Image.fromarray(np.clip(a,0,255).astype(np.uint8),'RGBA')
    pad=Image.new('RGBA',(int(max(W,H)*1.5),)*2,(0,0,0,0)); pad.alpha_composite(img,((pad.width-img.width)//2,(pad.height-img.height)//2))
    return pad.rotate(math.degrees(roll),Image.BICUBIC)
if __name__=='__main__':
    out=sys.argv[1]; os.makedirs(out,exist_ok=True)
    # float frames (16): gentle yaw sway and roll
    F=[];
    for i in range(16):
        u=i/16*math.tau
        v=yaw_view(M,0.5*math.sin(u),0.09*math.sin(u+1.0))
        F.append(v)
    # fly frames (20): full spin about the long axis while tilted
    FL=[]
    for i in range(20):
        u=i/20*math.tau
        v=yaw_view(M,u,math.radians(-28)+0.05*math.sin(u*2))
        FL.append(v)
    # armed: tag lying flat, iso projected, ink glowing
    def flat(glow):
        h=M.rotate(90,expand=True)
        a=np.array(h).astype(np.float32)
        ink=(a[...,:3].sum(-1)<120)&(a[...,3]>0)
        red=(a[...,0]>140)&(a[...,1]<90)&(a[...,3]>0)
        if glow>0:
            a[ink,:3]=a[ink,:3]*(1-glow)+np.array([255,150,40],np.float32)*glow
            a[red,:3]=a[red,:3]*(1-glow*.6)+np.array([255,90,50],np.float32)*glow*.6
        h=Image.fromarray(np.clip(a,0,255).astype(np.uint8),'RGBA')
        W,H=h.size
        # iso projection: rotate 28deg then squash vertically 0.5
        pad=Image.new('RGBA',(int(max(W,H)*1.3),)*2,(0,0,0,0)); pad.alpha_composite(h,((pad.width-W)//2,(pad.height-H)//2))
        pad=pad.rotate(-24,Image.BICUBIC)
        return pad.resize((pad.width,int(pad.height*0.5)),Image.BILINEAR)
    A=[flat(0.15+0.85*(0.5+0.5*math.sin(i/16*math.tau))) for i in range(16)]
    # shared palette
    sample=[box_down(A[12],S),box_down(F[0],S),box_down(FL[5],S),box_down(A[0],S),box_down(A[8],S),box_down(yaw_view(M,0.9,0),S)]
    pal=palette_from(sample,27)
    pal=np.vstack([pal[:27],np.array([hexc('#ff9628'),hexc('#ffd060'),hexc('#ff5a32')])])
    np.save(f'{out}/pal.npy',pal)
    def fin(frames,size,anchor=(0.5,0.5),down=S,name=''):
        for i,f in enumerate(frames):
            d=box_down(f,down); q=quant(d,pal); c=place(size,q,anchor)
            c.save(f'{out}/{name}_{i:02d}.png')
    fin(F,(56,92),name='tag')
    fin(FL,(64,64),name='fly',down=S*3//2) if False else None
    # fly is drawn smaller (0.65x): downsample by S/0.65
    for i,f in enumerate(FL):
        k=int(S/0.62)
        d=f.resize((f.width*10//k,f.height*10//k),Image.BOX) if False else f.resize((int(f.width/(S/0.62)),int(f.height/(S/0.62))),Image.BOX)
        q=quant(d,pal); place((64,64),q).save(f'{out}/fly_{i:02d}.png')
    for i,f in enumerate(A):
        d=f.resize((int(f.width/(S/0.78)),int(f.height/(S/0.78))),Image.BOX); q=quant(d,pal); place((80,48),q,(0.5,0.55)).save(f'{out}/armed_{i:02d}.png')
    # preview
    files=[f'{out}/tag_{i:02d}.png' for i in (0,4,8,12)]+[f'{out}/fly_{i:02d}.png' for i in (0,3,6,9)]+[f'{out}/armed_{i:02d}.png' for i in (0,4,8)]
    ims=[Image.open(f) for f in files]
    w=sum(i.width for i in ims); sh=Image.new('RGBA',(w,92),(34,32,40,255)); x=0
    for i in ims: sh.alpha_composite(i,(x,(92-i.height)//2)); x+=i.width
    sh.resize((w*3,276),Image.NEAREST).save(f'{out}/sheet.png')
