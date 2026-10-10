"""Start PCSX-Redux with drive.lua (interactive, polls build/emu/drive/cmd.txt).
usage: python tools/emu-tests/launch.py [cue]   then send commands with cmd.py"""
import os, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import BUILD, HERE, emulator
out = os.path.join(BUILD, 'emu', 'drive')
shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
cue = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BUILD, 're1_hk.cue')
env = dict(os.environ, HARNESS_SCRIPT=os.path.join(HERE, 'drive.lua'), HARNESS_OUT=out,
           CMD_FILE=os.path.join(out, 'cmd.txt'))
log = open(out + '.emu.log', 'w')
subprocess.run([emulator(), '-cli', '-stdout', '-interpreter', '-run', '-iso', cue,
                '-dofile', os.path.join(HERE, 'harness.lua')], env=env, stdout=log, stderr=subprocess.STDOUT, cwd=HERE)
