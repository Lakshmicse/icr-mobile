"""Match each text line of a render with the same line of its design and report ink / width ratios.
python matchlines.py DESIGN RENDER [--min-ink 600] [--flag 1.18]"""
import sys, argparse
from PIL import Image
import numpy as np
def load(p):
    im=Image.open(p)
    if im.mode=='RGBA':
        bg=Image.new('RGBA',im.size,(255,255,255,255)); bg.alpha_composite(im); im=bg
    return im.convert('RGB')
def find_lines(a):
    g=a.min(axis=2); sat=a.max(axis=2)-a.min(axis=2)
    H=a.shape[0]
    # a row is "text-like" when it has dark pixels on an otherwise light row
    dark=g<150
    light_frac=(g>215).mean(axis=1)
    rows=dark.sum(axis=1)>2
    rows&=light_frac>0.55
    out=[];i=0
    while i<H:
        if rows[i]:
            j=i
            while j<H and rows[j]: j+=1
            if 6<=j-i<=26:
                cols=np.where(dark[i:j].any(axis=0))[0]
                seg=g[i:j, cols.min():cols.max()+1]
                out.append(dict(y0=i,y1=j,x0=cols.min(),x1=cols.max(),ink=(255-seg).sum()/1000))
            i=j
        else: i+=1
    return out
ap=argparse.ArgumentParser(); ap.add_argument('design'); ap.add_argument('render'); ap.add_argument('--min-ink',type=float,default=400); ap.add_argument('--flag',type=float,default=1.18)
a=ap.parse_args()
from PIL import ImageFilter
D0=load('docs/designs/hires/'+a.design)
R=load('build/screens/'+a.render)
fw=min(D0.width,1560)
rs=np.asarray(R.filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
best=None
for dx in (range(0,D0.width-fw+1,4) if D0.width>fw else [0]):
    for dy in range(0,80,2):
        c=np.asarray(D0.crop((dx,dy,dx+fw,dy+int(360/(780/fw)))).resize((780,360),Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))).astype(np.int16)
        e=np.abs(c-rs[:360]).mean()
        if best is None or e<best[0]: best=(e,dx,dy)
_,dx,dy=best
D=D0.crop((dx,dy,dx+fw,D0.height)); D=D.resize((780,int(D.height*780/fw)),Image.LANCZOS)
print('aligned dx',dx,'dy',dy)
A=np.asarray(D).astype(float); B=np.asarray(R).astype(float)
la,lb=find_lines(A),find_lines(B)
used=set(); rows=[]
for l in la:
    best=None
    for k,m in enumerate(lb):
        if k in used: continue
        if abs((l['y0']+l['y1'])/2-(m['y0']+m['y1'])/2)<=7 and abs(l['x0']-m['x0'])<=14:
            d=abs(l['y0']-m['y0'])+abs(l['x0']-m['x0'])
            if best is None or d<best[0]: best=(d,k)
    if best:
        used.add(best[1]); m=lb[best[1]]
        wd=l['x1']-l['x0']; wr=m['x1']-m['x0']
        if wd>30 and l['ink']>a.min_ink and m['ink']>a.min_ink:
            rows.append((l['y0'],wd/wr,l['ink']/m['ink'],wd,wr,m['y0']-l['y0']))
print(f'{len(la)} design lines, {len(lb)} render lines, {len(rows)} matched with ink')
if rows:
    ink=np.array([r[2] for r in rows]); wid=np.array([r[1] for r in rows])
    print(f'ink ratio median {np.median(ink):.2f} (p25 {np.percentile(ink,25):.2f}, p75 {np.percentile(ink,75):.2f}); width ratio median {np.median(wid):.3f} (p10 {np.percentile(wid,10):.3f}, p90 {np.percentile(wid,90):.3f})')
    print('lines where the design is heavier (ink ratio >= %.2f) or width is off by >2%%:'%a.flag)
    for y,w,i,wd,wr,dy in rows:
        if i>=a.flag or abs(w-1)>0.02: print(f'  y={y:5d} ({y/2:6.1f} dp)  ink x{i:.2f}  width x{w:.3f} ({wd:.0f} vs {wr:.0f} px)  render dy={dy:+d}')
