"""Send commands to a running drive.lua session (see launch.py), wait, print the log tail.
usage: python tools/emu-tests/cmd.py "press START 8\\nshot s1" [wait seconds]"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import BUILD, to_png

out = os.path.join(BUILD, 'emu', 'drive')
tmp = os.path.join(out, 'cmd.tmp')
# written then renamed: the emulator must never see a half-written file
with open(tmp, 'w', newline='\n') as f:
    f.write(sys.argv[1].replace('\\n', '\n') + '\n')
os.replace(tmp, os.path.join(out, 'cmd.txt'))
time.sleep(float(sys.argv[2]) if len(sys.argv) > 2 else 2)
to_png(out)
print(''.join(open(os.path.join(out, 'log.txt')).readlines()[-4:]))
