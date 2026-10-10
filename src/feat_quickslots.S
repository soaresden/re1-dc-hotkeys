/* Feature quickslots: in game, L2 + d-pad uses the item of a quick slot
   (slot 1 = up, 2 = down, 3 = left, 4 = right):
     weapon (ids 1..10)                    -> equip it
     spray, herbs, mixes, serum (0x41..4B) -> same as "use" in the inventory
     anything else                         -> nothing
   While L2 is held, the d-pad is hidden from the game.
   In the inventory the four quick slots carry a translucent arrow.

   The weapon swap loads from the CD (it must be able to yield): it runs as
   a game task in task slot 1 with the game task suspended, like the
   inventory does.

   Needs: hook (input), draw_hook (arrows), lib.S */

quickslot_input:
        addiu   $sp, $sp, -0x28
        sw      $ra, 0x24($sp)
        lui     $t0, 0x800d
        lw      $t1, -0x3fc($t0)           /* 0x800CFC04 raw pad held */
        andi    $t2, $t1, 0x0001           /* L2 */
        beqz    $t2, 9f
        nop
        /* L2 held: hide the d-pad from the game */
        lw      $t3, -0x3f8($t0)           /* 0x800CFC08 raw newly pressed */
        andi    $t4, $t3, 0xf000           /* newly pressed d-pad */
        lui     $t5, 0xffff
        ori     $t5, $t5, 0x0fff
        and     $t1, $t1, $t5
        and     $t3, $t3, $t5
        sw      $t1, -0x3fc($t0)
        sw      $t3, -0x3f8($t0)
        lhu     $t6, -0x3f4($t0)           /* 0x800CFC0C */
        and     $t6, $t6, $t5
        sh      $t6, -0x3f4($t0)
        lhu     $t6, -0x3f0($t0)           /* 0x800CFC10 */
        and     $t6, $t6, $t5
        sh      $t6, -0x3f0($t0)
        lhu     $t6, -0x7980($t0)          /* 0x800C8680 mapped held */
        andi    $t6, $t6, 0xdfc0           /* drop directions and the L2 bit */
        sh      $t6, -0x7980($t0)
        lhu     $t6, -0x797e($t0)          /* 0x800C8682 mapped pressed */
        andi    $t6, $t6, 0xdfc0
        sh      $t6, -0x797e($t0)
        beqz    $t4, 9f
        nop
        /* quick slot: up=0, down=1, left=2, right=3 */
        li      $t7, 0
        andi    $t6, $t4, 0x1000
        bnez    $t6, 1f
        nop
        li      $t7, 1
        andi    $t6, $t4, 0x4000
        bnez    $t6, 1f
        nop
        li      $t7, 2
        andi    $t6, $t4, 0x8000
        bnez    $t6, 1f
        nop
        li      $t7, 3
1:      jal     can_act                    /* keeps t7 */
        nop
        beqz    $v0, 9f
        nop
        lui     $t0, 0x800d
        addiu   $t9, $t0, -0x787c          /* 0x800C8784 main inventory */
        sll     $t4, $t7, 1
        addu    $t4, $t4, $t9              /* &inventory[slot] */
        lbu     $t2, 0($t4)                /* item id */
        beqz    $t2, 9f
        nop
        addiu   $t6, $t2, -1
        sltiu   $t6, $t6, 10               /* weapons: ids 1..10 */
        bnez    $t6, 2f
        nop
        addiu   $t6, $t2, -0x41
        sltiu   $t6, $t6, 11               /* spray, herbs, mixes, serum: 0x41..0x4B */
        bnez    $t6, 3f
        nop
        b       9f
        nop

2:      /* weapon: equip it from a task */
        addiu   $t3, $t7, 1                /* equipped slot is 1-based */
        lbu     $t6, -0x7977($t0)          /* 0x800C8689 equipped slot */
        beq     $t6, $t3, 9f
        nop
        lui     $t8, %hi(st)
        sb      $t3, %lo(st + ST_PEND)($t8)
        move    $a0, $zero                 /* suspend the game task */
        JAL(F_TASK_SUSPEND)
        li      $a0, 1                     /* start the swap task in slot 1 */
        lui     $a1, %hi(swap_task)
        addiu   $a1, $a1, %lo(swap_task)
        JAL(F_TASK_START)
        b       9f
        nop

3:      /* healing item: same as "use" in the inventory. The heal routine
           reads the item id from 0x800B90EB: save/restore the menu work
           bytes it touches. */
        sw      $t4, 0x10($sp)             /* &inventory[slot] */
        lui     $t8, 0x800c
        lw      $t6, -0x6f20($t8)          /* 0x800B90E0..E3 */
        lw      $t5, -0x6f1c($t8)          /* 0x800B90E4..E7 */
        sw      $t6, 0x14($sp)
        sw      $t5, 0x18($sp)
        lw      $t6, -0x6f18($t8)          /* 0x800B90E8..EB */
        lw      $t5, -0x6f04($t8)          /* 0x800B90FC..FF */
        sw      $t6, 0x1c($sp)
        sw      $t5, 0x20($sp)
        sb      $t2, -0x6f15($t8)          /* 0x800B90EB = item */
        JAL(F_HEAL)
        lui     $t8, 0x800c
        lw      $t6, 0x14($sp)
        lw      $t5, 0x18($sp)
        sw      $t6, -0x6f20($t8)
        sw      $t5, -0x6f1c($t8)
        lw      $t6, 0x1c($sp)
        lw      $t5, 0x20($sp)
        sw      $t6, -0x6f18($t8)
        sw      $t5, -0x6f04($t8)
        andi    $v0, $v0, 0xff
        beqz    $v0, 9f                    /* nothing to heal */
        nop
        lw      $t4, 0x10($sp)
        lbu     $t6, 1($t4)                /* quantity */
        beqz    $t6, 4f
        nop
        addiu   $t6, $t6, -1
        sb      $t6, 1($t4)
        bnez    $t6, 5f
        nop
4:      sb      $zero, 0($t4)              /* used up: remove and compact */
        JAL(F_COMPACT)
5:      li      $a0, 3
        li      $a1, 6
        move    $a2, $zero
        JAL(F_PLAY_SE)
9:      lw      $ra, 0x24($sp)
        jr      $ra
        addiu   $sp, $sp, 0x28

/* ------------------------------------------------------------------
   Task body (slot 1). Runs in its own thread and may yield. */
        .globl swap_task
swap_task:
        lui     $t0, 0x800d
        lui     $t8, %hi(st)
        lbu     $t3, %lo(st + ST_PEND)($t8)
        sb      $t3, -0x7977($t0)          /* 0x800C8689 equipped slot */
        lui     $t8, 0x800c
        ori     $t8, $t8, 0x5124
        sw      $t8, -0x54ec($t0)          /* 0x800CAB14 = player object */
        /* same as F_SYNC_EQUIP (0x80054E74), except for the sound buffer:
           it loads the weapon sounds through 0x801D10EC, which holds the
           copy of the room background redrawn every frame (the inventory
           restores it on exit, we would leave stripes at the top of the
           screen). The weapon model buffer is used instead: the sounds are
           in the SPU before F_LOAD_WEAPON overwrites it. */
        lui     $s0, 0x800c
        lw      $t9, -0x4ef8($s0)          /* 0x800BB108 inventory pointer */
        sll     $t3, $t3, 1
        addu    $t9, $t9, $t3
        lbu     $a0, -2($t9)               /* item in the equipped slot */
        lbu     $t6, 0x5126($s0)
        beq     $a0, $t6, 2f               /* same weapon: nothing to load */
        nop
        sb      $a0, 0x5126($s0)           /* 0x800C5126 weapon id */
        lw      $t6, 0x3004($s0)
        lui     $t7, 0x0002
        and     $t6, $t6, $t7
        beqz    $t6, 1f
        li      $t6, 4
        bne     $a0, $t6, 1f
        nop
        li      $a0, 2                     /* weapon 4 -> 2 when 0x800C3004 & 0x20000 */
        sb      $a0, 0x5126($s0)
1:      lui     $a1, (WEAPON_BUF >> 16)
        ori     $a1, $a1, (WEAPON_BUF & 0xffff)
        JAL(F_LOAD_SOUNDS)                 /* VH -> 0x800F5400, VB -> a1 -> SPU */
        /* back to idle, as the inventory exit does */
        lui     $s0, 0x800c
        li      $t6, 1
        sw      $t6, 0x51a8($s0)
        sb      $zero, 0x51e1($s0)
        sb      $zero, 0x51b0($s0)
        sb      $zero, 0x51e2($s0)
        sb      $zero, 0x51e3($s0)
        sb      $zero, 0x51ae($s0)
        move    $a0, $zero
        lw      $a1, 0x51b4($s0)
        lw      $a2, 0x51b8($s0)
        li      $a3, 0x400
        JAL(F_SET_ANIM)
        lui     $s0, 0x800c
        lbu     $a0, 0x5126($s0)           /* new weapon id */
        li      $a1, 14
        lui     $a2, 0x800e
        ori     $a2, $a2, 0xa800
        lui     $a3, 0x800f
        ori     $a3, $a3, 0x2200
        JAL(F_LOAD_WEAPON)                 /* weapon model + animations */
2:      move    $a0, $zero                 /* resume the game task */
        JAL(F_TASK_RESUME)
        JAL(F_TASK_EXIT)                   /* never returns */
3:      b       3b
        nop

/* ------------------------------------------------------------------
   from draw_hook (s2, s3 = menu offset, s4 = OT): translucent arrow on
   each quick slot. uses s0, s1 (saved by draw_hook) */
menu_arrows:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        move    $s0, $zero
1:      lui     $s1, %hi(arrow_shapes)
        addiu   $s1, $s1, %lo(arrow_shapes)
        sll     $t1, $s0, 4                /* 16 bytes per shape */
        addu    $s1, $s1, $t1
        jal     cell_origin                /* t8, t9 */
        move    $a0, $s0
        lui     $a0, (GP_F3_SEMI >> 16)    /* head */
        ori     $a0, $a0, 0x3828           /* 0x603828 */
        lui     $t1, 0x0060
        or      $a0, $a0, $t1
        move    $a1, $s1
        li      $a2, 3
        jal     put_poly
        li      $a3, Z_MENU
        jal     cell_origin                /* t8, t9 were clobbered */
        move    $a0, $s0
        lui     $a0, (GP_F4_SEMI >> 16)    /* shaft */
        ori     $a0, $a0, 0x3828
        lui     $t1, 0x0060
        or      $a0, $a0, $t1
        addiu   $a1, $s1, 6
        li      $a2, 4
        jal     put_poly
        li      $a3, Z_MENU
        addiu   $s0, $s0, 1
        sltiu   $t1, $s0, 4
        bnez    $t1, 1b
        nop
        lui     $a0, (MODE_ADD >> 16)      /* additive, drawn before the arrows */
        ori     $a0, $a0, (MODE_ADD & 0xffff)
        jal     put_mode
        li      $a2, Z_MENU
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

        .section .data
/* per slot: 3 head vertices + 4 shaft vertices (TL, TR, BL, BR), + 2 pad;
   the cell is 40x30, centre (20, 15) */
arrow_shapes:
        .byte 20,6,   14,12,  26,12,   18,12, 22,12, 18,23, 22,23,  0,0    /* up */
        .byte 20,24,  14,18,  26,18,   18,7,  22,7,  18,18, 22,18,  0,0    /* down */
        .byte 9,15,   15,9,   15,21,   15,13, 30,13, 15,17, 30,17,  0,0    /* left */
        .byte 31,15,  25,9,   25,21,   10,13, 25,13, 10,17, 25,17,  0,0    /* right */
        .section .text
