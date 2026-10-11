/* Feature menu_move: in the inventory, Square on an item picks it up (the
   cell is tinted), Square on another item swaps the two, Square on the
   same item or closing the menu cancels. The equipped weapon follows its
   item. Only two occupied cells can be swapped: the game needs an
   inventory without holes.

   Needs: hook (input, menu open), draw_hook (highlight), lib.S */

/* called every frame while the inventory is open */
menu_move_input:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t0, %hi(PAD_NEW)
        lw      $t3, %lo(PAD_NEW)($t0)     /* raw newly pressed */
        andi    $t3, $t3, 0x0080           /* Square */
        beqz    $t3, 9f
        nop
        lui     $t8, %hi(MW_GRID)
        lbu     $t6, %lo(MW_GRID)($t8)     /* 1 = on the grid */
        li      $t5, 1
        bne     $t6, $t5, 9f
        nop
        SAMEHI(MW_GRID, MW_CURSOR)
        lbu     $t6, %lo(MW_CURSOR)($t8)   /* cursor = (slot+4)*2 */
        sltiu   $t5, $t6, 8
        bnez    $t5, 9f
        nop
        srl     $t6, $t6, 1
        addiu   $t7, $t6, -4               /* t7 = cursor slot (same with 6 slots) */
        lui     $t9, %hi(INV_PTR)
        lw      $t9, %lo(INV_PTR)($t9)     /* inventory pointer */
        sll     $t4, $t7, 1
        addu    $t4, $t4, $t9              /* &inv[cursor] */
        lbu     $t2, 0($t4)
        beqz    $t2, 9f                    /* empty cell: ignore */
        nop
        lui     $t8, %hi(st)
        addiu   $t8, $t8, %lo(st)
        lbu     $t6, ST_PICK($t8)
        li      $t5, 0xff
        bne     $t6, $t5, 1f
        nop
        sb      $t7, ST_PICK($t8)          /* pick up */
        b       8f
        li      $a1, 5
1:      sb      $t5, ST_PICK($t8)          /* clear the pick in all cases */
        beq     $t6, $t7, 8f               /* same cell: cancel */
        li      $a1, 4
        /* swap inv[t6] <-> inv[t7] (id + quantity) */
        sll     $t1, $t6, 1
        addu    $t1, $t1, $t9              /* &inv[pick] */
        lhu     $t2, 0($t1)
        lhu     $t3, 0($t4)
        sh      $t3, 0($t1)
        sh      $t2, 0($t4)
        /* swap the icon cache slots */
        lui     $t1, %hi(ICON_CACHE)
        addiu   $t1, $t1, %lo(ICON_CACHE)
        addu    $t2, $t1, $t6
        addu    $t3, $t1, $t7
        lbu     $a0, 0($t2)
        lbu     $a1, 0($t3)
        sb      $a1, 0($t2)
        sb      $a0, 0($t3)
        /* keep the equipped weapon on its item */
        SAMEHI(PAD_NEW, EQUIPPED)
        lbu     $t2, %lo(EQUIPPED)($t0)    /* 1-based */
        addiu   $a0, $t6, 1
        addiu   $a1, $t7, 1
        bne     $t2, $a0, 2f
        nop
        b       3f
        sb      $a1, %lo(EQUIPPED)($t0)
2:      bne     $t2, $a1, 3f
        nop
        sb      $a0, %lo(EQUIPPED)($t0)
3:      lbu     $t2, 0($t4)                /* item now under the cursor */
        lui     $t8, %hi(MW_ITEM)
        sb      $t2, %lo(MW_ITEM)($t8)
        li      $a1, 6
8:      li      $a0, 3                     /* menu sounds: 5 pick, 6 swap, 4 cancel */
        move    $a2, $zero
        JAL(F_PLAY_SE)
9:      lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* from draw_hook (s2, s3 = menu offset, s4 = OT): tint the picked cell */
menu_pick_draw:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t1, %hi(st)
        lbu     $a0, %lo(st + ST_PICK)($t1)
        li      $t1, 0xff
        beq     $a0, $t1, 9f
        nop
        jal     cell_origin
        nop
        lui     $a0, (GP_F4_SEMI >> 16)
        ori     $a0, $a0, 0x3070           /* warm tint, 0xBBGGRR = 0x003070 */
        lui     $a1, %hi(cell_shape)
        addiu   $a1, $a1, %lo(cell_shape)
        li      $a2, 4
        jal     put_poly
        li      $a3, Z_MENU
        lui     $a0, (MODE_ADD >> 16)      /* additive, drawn before the tint */
        ori     $a0, $a0, (MODE_ADD & 0xffff)
        jal     put_mode
        li      $a2, Z_MENU
9:      lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

        .section .data
cell_shape:                                /* a 40x30 cell, inset by 1 */
        .byte 1,1, 39,1, 1,29, 39,29
        .section .text
