/* Feature overlay: while L2 is held in game, a band at the bottom of the
   screen shows the four quick slots, in d-pad order (left, up, down,
   right), each with its arrow, the item icon and its quantity as in the
   inventory. The equipped weapon is tinted.

   Needs: frame_hook (s4 = OT), lib.S. Textures: inventory digits and icon
   cache, resident in VRAM during the game. */

#define OV_X0           68              /* first cell; cells are 40 wide, 48 apart */
#define OV_Y            186             /* arrows; icons at OV_Y + 10 */

overlay_draw:
        addiu   $sp, $sp, -0x30
        sw      $ra, 0x2c($sp)
        sw      $s0, 0x28($sp)
        sw      $s1, 0x24($sp)
        sw      $s2, 0x20($sp)
        sw      $s3, 0x1c($sp)
        /* dark band behind (subtractive), drawn first */
        li      $t8, 160
        li      $t9, OV_Y + 22
        lui     $a0, (GP_F4_SEMI >> 16)
        ori     $a0, $a0, 0x4040
        lui     $t1, 0x0040
        or      $a0, $a0, $t1              /* 0x404040 */
        lui     $a1, %hi(ov_band)
        addiu   $a1, $a1, %lo(ov_band)
        li      $a2, 4
        jal     put_poly
        li      $a3, Z_OV_BACK
        lui     $a0, (MODE_SUB >> 16)
        ori     $a0, $a0, (MODE_SUB & 0xffff)
        jal     put_mode
        li      $a2, Z_OV_BACK
        move    $s0, $zero                 /* cell 0..3 */
1:      lui     $t1, %hi(ov_order)
        addu    $t1, $t1, $s0
        lbu     $s1, %lo(ov_order)($t1)    /* s1 = quick slot */
        sll     $t2, $s0, 4
        sll     $t3, $s0, 5
        addu    $t2, $t2, $t3
        addiu   $s2, $t2, OV_X0            /* s2 = cell x */
        /* arrow */
        move    $t8, $s2
        li      $t9, OV_Y
        lui     $a0, (GP_F3 >> 16)
        ori     $a0, $a0, 0xd0d0
        lui     $t1, 0x00d0
        or      $a0, $a0, $t1              /* 0xd0d0d0 */
        lui     $a1, %hi(ov_arrows)
        addiu   $a1, $a1, %lo(ov_arrows)
        sll     $t1, $s1, 1
        addu    $t1, $t1, $s1
        sll     $t1, $t1, 1                /* 6 bytes per arrow */
        addu    $a1, $a1, $t1
        li      $a2, 3
        jal     put_poly
        li      $a3, Z_OVERLAY
        /* item */
        lui     $t8, %hi(INV_PTR)
        lw      $t2, %lo(INV_PTR)($t8)     /* inventory pointer */
        sll     $t3, $s1, 1
        addu    $t2, $t2, $t3
        lbu     $s3, 0($t2)                /* id */
        lbu     $t4, 1($t2)                /* quantity */
        beqz    $s3, 8f
        nop
        sw      $t4, 0x10($sp)
        SAMEHI(INV_PTR, ICON_CACHE)
        addiu   $t3, $t8, %lo(ICON_CACHE)  /* icon cache slot */
        addu    $t3, $t3, $s1
        lbu     $t3, 0($t3)
        sll     $t3, $t3, 13               /* v = cache slot * 32, in bits 8-15 */
        ori     $a2, $t3, 88
        move    $a0, $s2
        li      $a1, OV_Y + 10
        lui     $a3, %hi(tex_icon)
        jal     put_ft4
        addiu   $a3, $a3, %lo(tex_icon)
        /* quantity, for the items the inventory numbers: ids 2..18 and 47 */
        addiu   $t1, $s3, -2
        sltiu   $t1, $t1, 17
        bnez    $t1, 2f
        li      $t1, 47
        bne     $s3, $t1, 3f
        nop
2:      lw      $a0, 0x10($sp)
        sltiu   $t1, $s3, 11               /* weapons other than id 6: bit 7 is a flag */
        beqz    $t1, 4f
        li      $t1, 6
        beq     $s3, $t1, 4f
        nop
        andi    $a0, $a0, 0x7f
4:      sw      $a0, 0x10($sp)
        jal     number_width
        nop
        addiu   $a0, $s2, 39               /* right aligned in the cell */
        subu    $a0, $a0, $v0
        li      $a1, OV_Y + 10 + 21
        lw      $a2, 0x10($sp)
        jal     draw_number
        li      $a3, DIG_GREEN
3:      /* equipped weapon: tint the cell */
        lui     $t0, %hi(EQUIPPED)
        lbu     $t1, %lo(EQUIPPED)($t0)    /* 1-based */
        addiu   $t2, $s1, 1
        bne     $t1, $t2, 8f
        nop
        move    $t8, $s2
        li      $t9, OV_Y + 10
        lui     $a0, (GP_F4_SEMI >> 16)
        ori     $a0, $a0, 0x3070           /* warm tint, as the inventory pick */
        lui     $a1, %hi(cell_shape)
        addiu   $a1, $a1, %lo(cell_shape)
        li      $a2, 4
        jal     put_poly
        li      $a3, Z_OV_FRONT
        lui     $a0, (MODE_ADD >> 16)
        ori     $a0, $a0, (MODE_ADD & 0xffff)
        jal     put_mode
        li      $a2, Z_OV_FRONT
8:      addiu   $s0, $s0, 1
        sltiu   $t1, $s0, 4
        bnez    $t1, 1b
        nop
        lw      $ra, 0x2c($sp)
        lw      $s0, 0x28($sp)
        lw      $s1, 0x24($sp)
        lw      $s2, 0x20($sp)
        lw      $s3, 0x1c($sp)
        jr      $ra
        addiu   $sp, $sp, 0x30

        .section .data
ov_order:                                  /* quick slot shown in each cell */
        .byte   2, 0, 1, 3
ov_arrows:                                 /* per quick slot, relative to the cell (x, OV_Y) */
        .byte   20,0,  14,8,  26,8         /* up */
        .byte   20,8,  14,0,  26,0         /* down */
        .byte   15,4,  23,-1, 23,9         /* left */
        .byte   25,4,  17,-1, 17,9         /* right */
ov_band:                                   /* relative to (160, OV_Y + 22) */
        .byte   -100,-24,  100,-24,  -100,24,  100,24
        .section .text
