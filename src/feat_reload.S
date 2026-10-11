/* Feature reload: R1 + Circle in game fills the equipped weapon up to its
   capacity with the ammo of its type carried in the inventory, like a
   "combine" in the inventory. Emptied stacks are removed and the inventory
   compacted (F_COMPACT, as the game does).
   Capacities (reload_cap): Beretta 15, shotgun 6, Colt Python 6 (magnum and
   dumdum), bazooka 6. Ammo items: ammo_of (feat_hud.S).

   Needs: hook (input), lib.S, feat_hud.S (ammo_of) */

#define PAD_R1          0x0008
#define PAD_CIRCLE      0x0020

reload_input:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t0, %hi(PAD_HELD)
        lw      $t1, %lo(PAD_HELD)($t0)
        lw      $t2, %lo(PAD_NEW)($t0)
        andi    $t1, $t1, PAD_R1
        beqz    $t1, 9f
        andi    $t2, $t2, PAD_CIRCLE
        beqz    $t2, 9f
        nop
        jal     game_running
        nop
        beqz    $v0, 9f
        nop
        lui     $t0, %hi(CTRL_FLAGS)
        lhu     $t1, %lo(CTRL_FLAGS)($t0)
        andi    $t1, $t1, 0x0101
        li      $t2, 0x0101
        bne     $t1, $t2, 9f
        nop
        jal     reload_weapon
        nop
9:      lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* fill the equipped weapon from the inventory. uses t0-t9, a0-a3 */
reload_weapon:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t0, %hi(EQUIPPED)
        lbu     $t1, %lo(EQUIPPED)($t0)    /* 1-based */
        lui     $t9, %hi(INV_PTR)
        lw      $t9, %lo(INV_PTR)($t9)
        beqz    $t1, 9f
        nop
        sll     $t4, $t1, 1
        addu    $t4, $t4, $t9
        addiu   $t4, $t4, -2               /* t4 = &inv[equipped] */
        lbu     $t5, 0($t4)                /* weapon */
        sltiu   $t1, $t5, 11
        beqz    $t1, 9f
        nop
        lui     $t1, %hi(ammo_of)
        addu    $t1, $t1, $t5
        lbu     $a0, %lo(ammo_of)($t1)     /* a0 = ammo item */
        lui     $t1, %hi(reload_cap)
        addu    $t1, $t1, $t5
        lbu     $a1, %lo(reload_cap)($t1)  /* a1 = capacity */
        beqz    $a0, 9f
        nop
        lbu     $t6, 1($t4)
        andi    $a2, $t6, 0x80             /* flag kept in bit 7 */
        andi    $t6, $t6, 0x7f             /* t6 = loaded */
        subu    $t7, $a1, $t6              /* t7 = missing */
        blez    $t7, 9f
        move    $a3, $zero                 /* a3 = a stack was emptied */
        li      $t8, 8                     /* 8 slots (6 for Chris: the rest is empty) */
        move    $t2, $t9
1:      beq     $t2, $t4, 3f               /* not the weapon itself */
        nop
        lbu     $t1, 0($t2)
        lbu     $t3, 1($t2)
        bne     $t1, $a0, 3f
        nop
        sltu    $t1, $t3, $t7              /* take = min(stack, missing) */
        bnez    $t1, 2f
        move    $t1, $t3
        move    $t1, $t7
2:      subu    $t3, $t3, $t1
        addu    $t6, $t6, $t1
        subu    $t7, $t7, $t1
        sb      $t3, 1($t2)
        bnez    $t3, 3f
        nop
        sb      $zero, 0($t2)              /* used up */
        li      $a3, 1
3:      addiu   $t8, $t8, -1
        beqz    $t7, 4f                    /* full */
        addiu   $t2, $t2, 2
        bnez    $t8, 1b
        nop
4:      lbu     $t1, 1($t4)
        or      $t6, $t6, $a2
        beq     $t1, $t6, 9f               /* nothing taken (no ammo) */
        nop
        sb      $t6, 1($t4)
        beqz    $a3, 5f
        nop
        JAL(F_COMPACT)
5:      li      $a0, 3
        li      $a1, 6
        move    $a2, $zero
        JAL(F_PLAY_SE)
9:      lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

        .section .data
reload_cap:                                /* capacity of weapons 0..10 */
        .byte   0, 0, 15, 6, 6, 6, 0, 6, 6, 6, 0
        .balign 4
        .section .text2, "ax"
