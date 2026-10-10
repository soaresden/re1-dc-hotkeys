#!/bin/bash
# usage: launch.sh <cue> [outdir]
CUE=$1
OUT=${2:-/home/claude/redux/out8}
for p in $(pgrep -x pcsx-redux) $(pgrep -f "b271/squashfs-root/usr/bin"); do kill -9 $p 2>/dev/null; done
sleep 1
pgrep -x Xvfb >/dev/null || (Xvfb :77 -screen 0 1024x768x24 >/dev/null 2>&1 &)
sleep 1
rm -rf "$OUT"; mkdir -p "$OUT"; rm -f /home/claude/redux/cmd.txt
cd /home/claude/redux
DISPLAY=:77 HARNESS_SCRIPT=/home/claude/redux/drive.lua HARNESS_OUT="$OUT" \
  setsid nohup /home/claude/redux2/b271/squashfs-root/AppRun -run -stdout -no-gui-log $EMUFLAGS -iso "$CUE" \
  -dofile /home/claude/redux/harness.lua > "$OUT/emu.log" 2>&1 < /dev/null &
echo launched
