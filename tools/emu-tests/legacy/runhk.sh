#!/bin/bash
# usage: runhk.sh <scenario> <outdir> [state] [last]
cd /home/claude/redux
/home/claude/redux/killemu.sh
HOOK=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="hook"{print $1}')
HKT=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="hk_table"{print $1}')
DRAW=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="draw_hook"{print $1}')
PICK=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="pick_slot"{print $1}')
BASE=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="_start"{print $1}')
DRAWJAL=$([ -n "$DRAW" ] && python3 -c "print('%08x' % (0x0c000000 | ((0x$DRAW >> 2) & 0x3ffffff)))")
JAL=$(python3 -c "print('%08x' % (0x0c000000 | ((0x$HOOK >> 2) & 0x3ffffff)))")
rm -rf "$2"
HK_SCEN=$1 HK_STATE=${3:-/home/claude/redux/hk_dining.sstate} HK_LAST=${4:-340} HK_HOOK=$HOOK HK_PREADDR=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="ARROW_PRE"{print $1}') HK_DRAW=$DRAW HK_ZADDR=$(mips-linux-gnu-nm /home/claude/re1/hotkey.elf | awk '$3=="ARROW_Z"{print $1}') HK_DRAWJAL=$DRAWJAL HK_PICK=$PICK HK_BASE=$BASE HK_TABLE=$HKT HK_JAL=$JAL \
HK_INJECT=${HK_INJECT-/home/claude/re1/hotkey.bin} \
HARNESS_OUT_DIR="$2" HARNESS_SCRIPT=/home/claude/redux/s_hk.lua HARNESS_OUT="$2" timeout 300 \
  /home/claude/redux2/b271/squashfs-root/AppRun -cli -stdout -interpreter -run -iso /home/claude/re1/re1_hk.cue -dofile /home/claude/redux/harness.lua > "$2.emu.log" 2>&1
echo "exit $?"
