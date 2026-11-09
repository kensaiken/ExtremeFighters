from PIL import Image
import math
N=32
pal={'K':(70,22,0),'1':(255,246,190),'2':(255,214,92),'3':(255,176,40),'4':(240,132,12),'5':(204,92,4),'6':(150,56,0),
     'R':(214,20,16),'r':(150,8,8),'W':(255,255,255)}
im=Image.new('RGBA',(N,N),(0,0,0,0))
cx=cy=15.5; R=14.6
g=[[None]*N for _ in range(N)]
for y in range(N):
    for x in range(N):
        dx,dy=x+0.5-16,y+0.5-16
        d=math.hypot(dx,dy)
        if d<=R:
            # light from top-left
            lx,ly=-0.55,-0.6
            nz=math.sqrt(max(0,1-(d/R)**2))
            shade=(dx/R)*lx+(dy/R)*ly+nz*0.55
            # bands
            if shade>0.95: c='1'
            elif shade>0.72: c='2'
            elif shade>0.42: c='3'
            elif shade>0.12: c='4'
            elif shade>-0.2: c='5'
            else: c='6'
            if d>R-1.15: c='K'
            g[y][x]=c
# specular highlight
for (x,y) in [(9,7),(10,7),(8,8),(9,8),(10,8),(8,9),(9,9),(11,6),(10,6)]:
    g[y][x]='W'
star=["..R..",
      "..R..",
      "RRRRR",
      ".RRR.",
      ".R.R."]
# 4 stars: 4-star ball pattern (diamond-ish)
for (sx,sy) in [(14,7),(8,14),(19,14),(13,20)]:
    for j,row in enumerate(star):
        for i,c in enumerate(row):
            if c=='R': g[sy+j][sx+i]='R'
    # small dark under-edge for depth
    for j,row in enumerate(star):
        for i,c in enumerate(row):
            if c=='R' and (j+1==len(star) or star[j+1][i]!='R'):
                if sy+j+1<N and g[sy+j+1][sx+i] not in ('R','K',None): g[sy+j+1][sx+i]='r'
for y in range(N):
    for x in range(N):
        if g[y][x]: im.putpixel((x,y),pal[g[y][x]]+(255,))
im.save('bola32.png')
im.resize((256,256),Image.NEAREST).save('bola.ico',sizes=[(256,256),(128,128),(64,64),(48,48),(32,32),(16,16)])
p=Image.new('RGBA',(512,512),(40,40,48,255)); p.alpha_composite(im.resize((512,512),Image.NEAREST)); p.save('bola_vista_previa.png')
