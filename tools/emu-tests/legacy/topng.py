import sys,re,os
from PIL import Image
outdir=sys.argv[1]
for line in open(os.path.join(outdir,'log.txt')):
    m=re.match(r'SHOT (\S+) (\d+)x(\d+) bpp=(\d)',line)
    if not m: continue
    name,w,h,bpp=m.group(1),int(m.group(2)),int(m.group(3)),int(m.group(4))
    p=os.path.join(outdir,name+'.raw')
    if not os.path.exists(p): continue
    d=open(p,'rb').read()
    if bpp==1:
        im=Image.frombytes('RGB',(w,h),d[:w*h*3])
    else:
        im=Image.new('RGB',(w,h)); px=im.load()
        for y in range(h):
            row=y*w*2
            for x in range(w):
                v=d[row+x*2]|(d[row+x*2+1]<<8)
                px[x,y]=((v&31)<<3,((v>>5)&31)<<3,((v>>10)&31)<<3)
    im.save(os.path.join(outdir,name+'.png'))
print('ok')
