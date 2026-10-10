/* Feature quickturn: Square + Down (as in RE3) turns the player around in
   TURN_FRAMES frames. During the turn the directions and Square are hidden
   from the game; afterwards Down stays hidden until it is released, so
   the player does not walk backwards right away.

   Player angle: halfword 0x800C5198 (0..0xFFF, 0x800 = half a turn).
   Needs: hook (input), lib.S */

#define TURN_FRAMES     8
#define TURN_STEP       (0x800 / TURN_FRAMES)

quickturn_input:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t5, %hi(st)
        addiu   $t5, $t5, %lo(st)
        lbu     $t1, ST_TURN($t5)
        bnez    $t1, 2f                    /* turning */
        nop
        lbu     $t1, ST_LOCK($t5)
        bnez    $t1, 4f                    /* waiting for Down to be released */
        nop
        lui     $t0, 0x800d
        lw      $t1, -0x3fc($t0)           /* 0x800CFC04 raw held */
        andi    $t2, $t1, 0x0001           /* not with L2 (quick slots) */
        bnez    $t2, 9f
        nop
        andi    $t2, $t1, 0x4080           /* Down + Square held... */
        li      $t3, 0x4080
        bne     $t2, $t3, 9f
        nop
        lw      $t3, -0x3f8($t0)           /* ...one of them just pressed */
        andi    $t3, $t3, 0x4080
        beqz    $t3, 9f
        nop
        jal     can_act                    /* keeps t5 */
        nop
        beqz    $v0, 9f
        nop
        li      $t1, TURN_FRAMES
2:      lui     $t8, 0x800c
        lhu     $t2, 0x5198($t8)           /* player angle */
        addiu   $t2, $t2, TURN_STEP
        andi    $t2, $t2, 0x0fff
        sh      $t2, 0x5198($t8)
        addiu   $t1, $t1, -1
        sb      $t1, ST_TURN($t5)
        bnez    $t1, 3f
        li      $t2, 1
        sb      $t2, ST_LOCK($t5)          /* turn done: hold Down back */
3:      li      $t3, 0xfdc0                /* mapped pad: no directions (0x003F), no run (0x0200) */
        b       5f
        nop
4:      lui     $t0, 0x800d
        lw      $t1, -0x3fc($t0)
        andi    $t1, $t1, 0x4000           /* Down still held? */
        bnez    $t1, 6f
        nop
        b       9f
        sb      $zero, ST_LOCK($t5)
6:      li      $t3, 0xffdb                /* mapped pad: no Down (0x0024) */
5:      lui     $t0, 0x800d
        lhu     $t6, -0x7980($t0)          /* 0x800C8680 mapped held */
        and     $t6, $t6, $t3
        sh      $t6, -0x7980($t0)
        lhu     $t6, -0x797e($t0)          /* 0x800C8682 mapped pressed */
        and     $t6, $t6, $t3
        sh      $t6, -0x797e($t0)
9:      lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18
