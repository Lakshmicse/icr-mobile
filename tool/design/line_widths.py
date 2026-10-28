import sys
from PIL import Image
import numpy as np
def load(p):
    im=Image.open(p)
    if im.mode=='RGBA':
        bg=Image.new('RGBA',im.size,(255,255,255,255)); bg.alpha_composite(im); im=bg
    return im.convert('RGB')
def lines(a,box,thr=170,minh=5):
    x0,y0,x1,y1=box; g=a[y0:y1,x0:x1].min(axis=2); dark=g<thr
    rows=dark.any(axis=1); out=[]; i=0
    while i<len(rows):
        if rows[i]:
            j=i
            while j<len(rows) and rows[j]: j+=1
            if j-i>=minh:
                cols=np.where(dark[i:j].any(axis=0))[0]; out.append((y0+i,y0+j,x0+cols.min(),x0+cols.max()))
            i=j
        else: i+=1
    return out
design,render=sys.argv[1],sys.argv[2]
D=load('docs/designs/hires/'+design); D=D.resize((780,int(D.height*780/D.width)),Image.LANCZOS)
R=load('build/screens/'+render)
A=np.asarray(D).astype(float); B=np.asarray(R).astype(float)
box=tuple(int(v) for v in sys.argv[3].split(','))
la,lb=lines(A,box),lines(B,box)
print('design lines (y0,y1,xmin,xmax,width):'); [print('  ',l,l[3]-l[2]) for l in la]
print('render lines:'); [print('  ',l,l[3]-l[2]) for l in lb]
if len(la)==len(lb):
    print('width ratio design/render per line:',[round((a[3]-a[2])/(b[3]-b[2]),3) for a,b in zip(la,lb)])
