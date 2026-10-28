import sys
from PIL import Image
import numpy as np
def load(p):
    im=Image.open(p)
    if im.mode=='RGBA':
        bg=Image.new('RGBA',im.size,(255,255,255,255)); bg.alpha_composite(im); im=bg
    return im.convert('RGB')
def ink(a,box):
    x0,y0,x1,y1=box; g=a[y0:y1,x0:x1].min(axis=2); return (255-g).sum()/1000
def diff(a,b,box):
    x0,y0,x1,y1=box; return np.abs(a[y0:y1,x0:x1]-b[y0:y1,x0:x1]).max(axis=2).mean()
design,render=sys.argv[1],sys.argv[2]
D=load('docs/designs/hires/'+design); D=D.resize((780,int(D.height*780/D.width)),Image.LANCZOS)
R=load('build/screens/'+render)
A=np.asarray(D).astype(float); B=np.asarray(R).astype(float)
for arg in sys.argv[3:]:
    name,box=arg.split('=')
    box=tuple(int(v) for v in box.split(','))
    di,ri=ink(A,box),ink(B,box)
    print(f'{name:22} ink design {di:7.0f} render {ri:7.0f} ratio {di/ri:.2f}   mean px diff {diff(A,B,box):.2f}')
