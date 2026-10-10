import re,sys,collections
# parse objdump output, track lui per register, resolve following addiu/lw/sw/lh/sh/lb/sb/lbu/lhu with same base reg
lines=open('exe.dis').read().splitlines()
ins=[]
for l in lines:
    m=re.match(r'^([0-9a-f]{8}):\s+([0-9a-f]{8})\s+(\S+)\s*(.*)$',l)
    if m: ins.append((int(m.group(1),16),int(m.group(2),16),m.group(3),m.group(4)))
xrefs=collections.defaultdict(list)
lui={}
for i,(addr,word,op,args) in enumerate(ins):
    if op=='lui':
        r,v=args.split(',')
        lui[r]=int(v,16)<<16
        continue
    m=re.match(r'^(\w+),(\w+),(-?(?:0x[0-9a-f]+|\d+))$',args)
    if op in('addiu','ori') and m:
        rd,rs,imm=m.group(1),m.group(2),int(m.group(3),0)
        if rs in lui:
            xrefs[(lui[rs]+imm)&0xffffffff].append((addr,op))
            if rd!=rs: lui.pop(rd,None)
        else: lui.pop(rd,None)
        continue
    m=re.match(r'^(\w+),(-?\d+)\((\w+)\)$',args)
    if m and op[0] in 'ls':
        rt,imm,rs=m.group(1),int(m.group(2)),m.group(3)
        if rs in lui:
            xrefs[(lui[rs]+imm)&0xffffffff].append((addr,op))
        if op[0]=='l': lui.pop(rt,None)
        continue
    # any other op writing a reg: crude - drop dest
    m=re.match(r'^(\w+),',args)
    if m and op not in('sw','sh','sb','beq','bne','bnez','beqz','blez','bgtz','bltz','bgez','swc2','swl','swr','mtc2','ctc2','mult','multu','div','divu','jr','jalr','j','jal','b'):
        lui.pop(m.group(1),None)
    if op in('jal','jalr','jr','j','b','beq','bne','bnez','beqz'): pass
import pickle
pickle.dump(dict(xrefs),open('xrefs.pkl','wb'))
lo=int(sys.argv[1],16); hi=int(sys.argv[2],16)
for a in sorted(xrefs):
    if lo<=a<hi:
        print(hex(a), ' '.join(f"{hex(x)}:{o}" for x,o in xrefs[a][:14]), ('...' if len(xrefs[a])>14 else ''))
