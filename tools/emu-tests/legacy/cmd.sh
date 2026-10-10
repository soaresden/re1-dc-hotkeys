#!/bin/bash
# usage: cmd.sh "<cmd lines>" [wait_seconds] [shotname]
printf '%b\n' "$1" > /home/claude/redux/cmd.txt
sleep ${2:-3}
if [ -n "$3" ]; then DISPLAY=:77 import -window root /home/claude/redux/out8/$3.png; fi
tail -3 /home/claude/redux/out8/log.txt | cut -c1-220
