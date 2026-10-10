/* Resident Evil Director's Cut (PAL-F, SLES-009.70) - gameplay mods
   Code block loaded at 0x8000E800 (prepended to the executable image).

   Each feature lives in its own file and can be switched off by the patcher
   (byte in `config`, at _start + 8):
     0 menu_move   feat_menu_move.S   Square moves / swaps items in the inventory
     1 quickslots  feat_quickslots.S  L2 + d-pad uses the item of slots 1-4
                                      (arrows on the 4 slots in the inventory)
     2 overlay     feat_overlay.S     L2 held: the 4 quick slots at the bottom
     3 hud_hp      feat_hud.S         health top left, coloured like the condition
     4 hud_ammo    feat_hud.S         equipped weapon + ammo under it
     5 quickturn   feat_quickturn.S   Square + Down: 180 degree turn
   Shared code: lib.S (game state tests, primitives, numbers).

   Three calls of the game are redirected (src/build_patch.py):
     0x80032084 jal LOOP_NEXT   -> hook        every frame, after the pad read
     0x80054C9C jal F_GRID_DRAW -> draw_hook   inventory item grid
     0x80032740 jal F_PAL_ANIM  -> frame_hook  every frame, the OT is complete
*/
        .set noreorder
        .set noat
#include "game.h"
        .section .text
        .globl _start
_start:
        b       boot
        nop
        .globl config
config:
        .byte   1, 1, 1, 1, 1, 1, 0, 0

boot:
        /* the last 0x1800 bytes of the original image (0x800AE000..0x800AF800)
           were dropped to make room for this block: zero them, then copy back
           the non-zero segments stored in taildata as (addr, len, bytes...) */
        lui     $t1, 0x800b
        addiu   $t1, $t1, -0x2000          /* 0x800AE000 */
        li      $t2, 0x1800/4
1:      sw      $zero, 0($t1)
        addiu   $t2, $t2, -1
        bnez    $t2, 1b
        addiu   $t1, $t1, 4
        lui     $t0, %hi(taildata)
        addiu   $t0, $t0, %lo(taildata)
2:      lw      $t1, 0($t0)                /* segment address, 0 = end */
        lw      $t2, 4($t0)                /* length in bytes (multiple of 4) */
        beqz    $t1, 4f
        addiu   $t0, $t0, 8
3:      lw      $t3, 0($t0)
        addiu   $t0, $t0, 4
        sw      $t3, 0($t1)
        addiu   $t2, $t2, -4
        bnez    $t2, 3b
        addiu   $t1, $t1, 4
        b       2b
        nop
4:      lui     $t0, %hi(st)
        addiu   $t0, $t0, %lo(st)
        li      $t3, 0xff
        sb      $t3, ST_PICK($t0)
        sb      $zero, ST_TURN($t0)
        sb      $zero, ST_LOCK($t0)
        j       GAME_ENTRY
        nop

/* ------------------------------------------------------------------
   Every frame, from the main loop right after the pad has been read and
   mapped: input of the features. Tail-jumps to the original callee. */
        .globl hook
hook:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        jal     menu_open
        nop
        beqz    $v0, 1f
        nop
        CFG($t0, C_MENU_MOVE)
        beqz    $t0, 9f
        nop
        jal     menu_move_input
        nop
        b       9f
        nop
1:      lui     $t0, %hi(st)               /* menu closed: drop any pending pick */
        addiu   $t0, $t0, %lo(st)
        li      $t1, 0xff
        sb      $t1, ST_PICK($t0)
        CFG($t0, C_QUICKSLOTS)
        beqz    $t0, 2f
        nop
        jal     quickslot_input
        nop
2:      CFG($t0, C_QUICKTURN)
        beqz    $t0, 9f
        nop
        jal     quickturn_input
        nop
9:      lw      $ra, 0x14($sp)
        addiu   $sp, $sp, 0x18
        j       LOOP_NEXT
        nop

/* ------------------------------------------------------------------
   Every frame, once the game has built its OT (just before DrawSync):
   things drawn over the game. */
        .globl frame_hook
frame_hook:
        addiu   $sp, $sp, -0x20
        sw      $ra, 0x1c($sp)
        sw      $s4, 0x18($sp)
        JAL(F_PAL_ANIM)                    /* the replaced call */
        jal     game_running
        nop
        beqz    $v0, 9f
        nop
        lui     $t0, 0x800d
        lhu     $t1, -0x5500($t0)          /* 0x800CAB00: bit 0x0100 off during cutscenes */
        andi    $t1, $t1, 0x0100
        beqz    $t1, 9f
        nop
        lbu     $t1, -0x7ba5($t0)          /* 0x800C845B: 1 during doors */
        bnez    $t1, 9f
        nop
        jal     ot_desc_game               /* s4 = scene OT of this frame */
        nop
        /* the game draws both buffers with the same drawing offset and adds
           0x800C845C (0 or 240) to its y coordinates itself: so do we */
        lui     $t0, 0x800d
        lbu     $t1, -0x7ba4($t0)          /* 0x800C845C */
        lui     $t2, %hi(st + ST_YBIAS)
        sh      $t1, %lo(st + ST_YBIAS)($t2)
        jal     hud_draw
        nop
        CFG($t0, C_OVERLAY)
        beqz    $t0, 9f
        nop
        lui     $t0, 0x800d
        lw      $t1, -0x3fc($t0)           /* 0x800CFC04 raw pad held */
        andi    $t1, $t1, 0x0001           /* L2 */
        beqz    $t1, 9f
        nop
        jal     overlay_draw
        nop
9:      lui     $t2, %hi(st + ST_YBIAS)
        sh      $zero, %lo(st + ST_YBIAS)($t2)
        lw      $ra, 0x1c($sp)
        lw      $s4, 0x18($sp)
        jr      $ra
        addiu   $sp, $sp, 0x20

/* ------------------------------------------------------------------
   Replaces "jal F_GRID_DRAW" in the inventory task: the grid, then the
   quick-slot arrows and the pick highlight over it. */
        .globl draw_hook
draw_hook:
        addiu   $sp, $sp, -0x20
        sw      $ra, 0x1c($sp)
        sw      $s0, 0x18($sp)
        sw      $s1, 0x14($sp)
        sw      $s2, 0x10($sp)
        sw      $s3, 0x0c($sp)
        sw      $s4, 0x08($sp)
        JAL(F_GRID_DRAW)
        jal     ot_desc
        nop
        jal     menu_offset                /* s2, s3 = screen offset of the menu */
        nop
        CFG($t0, C_QUICKSLOTS)
        beqz    $t0, 1f
        nop
        jal     menu_arrows
        nop
1:      jal     menu_pick_draw             /* nothing unless an item is picked */
        nop
        lw      $ra, 0x1c($sp)
        lw      $s0, 0x18($sp)
        lw      $s1, 0x14($sp)
        lw      $s2, 0x10($sp)
        lw      $s3, 0x0c($sp)
        lw      $s4, 0x08($sp)
        jr      $ra
        addiu   $sp, $sp, 0x20

#include "lib.S"
#include "feat_menu_move.S"
#include "feat_quickslots.S"
#include "feat_quickturn.S"
#include "feat_hud.S"
#include "feat_overlay.S"

        .globl code_end
code_end:

/* ------------------------------------------------------------------ */
        .section .data
        .balign 4
        .globl st
st:                                        /* state of the features */
        .byte   0xff                       /* ST_PICK: picked inventory slot, 0xff = none */
        .byte   0                          /* ST_PEND: slot to equip (1-based) for swap_task */
        .byte   0                          /* ST_TURN: frames left in a quick turn */
        .byte   0                          /* ST_LOCK: down is ignored until released */
        .hword  0                          /* ST_YBIAS: 0 or 240, see frame_hook */
        .hword  0

        .section .tail
        .balign 4
        .globl taildata
taildata:
        .incbin "tail.bin"
        .balign 4
        .globl block_end
block_end:
