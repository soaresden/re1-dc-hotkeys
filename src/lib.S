/* Shared code: game state tests, GPU primitives, numbers.
   Register use is documented per function; t-registers are never kept
   across a call to a game function. */

/* ------------------------------------------------------------------
   v0 = 1 if the inventory is open (task slot 1 runs the menu task).
   uses t6, t8, v1 */
menu_open:
        lui     $v1, 0x801f                /* task table 0x801FEC24, 0x80 per slot */
        ori     $v1, $v1, 0xec24
        lhu     $t6, 0x80($v1)
        beqz    $t6, 9f
        move    $v0, $zero
        lw      $t6, 0x84($v1)
        lui     $t8, (MENU_TASK >> 16)
        ori     $t8, $t8, (MENU_TASK & 0xffff)
        bne     $t6, $t8, 9f
        nop
        li      $v0, 1
9:      jr      $ra
        nop

/* v0 = 1 if the game task runs normally in slot 0 and slot 1 is free
   (no menu, no swap task). uses t6, t8, v1 */
game_running:
        lui     $v1, 0x801f
        ori     $v1, $v1, 0xec24
        move    $v0, $zero
        lhu     $t6, 0($v1)                /* status: 0 = free, 0x40 = suspended */
        andi    $t8, $t6, 0x40
        bnez    $t8, 9f
        nop
        beqz    $t6, 9f
        nop
        lhu     $t6, 0x80($v1)
        bnez    $t6, 9f
        nop
        lw      $t6, 4($v1)
        lui     $t8, (GAME_TASK >> 16)
        ori     $t8, $t8, (GAME_TASK & 0xffff)
        bne     $t6, $t8, 9f
        nop
        li      $v0, 1
9:      jr      $ra
        nop

/* v0 = 1 if the player can do a quick action now: in game, controllable,
   standing / walking / turning, alive, main inventory.
   uses t0, t6, t8, t9, v1 (keeps t1-t5, t7) */
can_act:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        jal     game_running
        nop
        beqz    $v0, 9f
        nop
        move    $v0, $zero
        lui     $t0, 0x800d
        lhu     $t6, -0x5500($t0)          /* 0x800CAB00 */
        andi    $t6, $t6, 0x0101
        li      $t8, 0x0101
        bne     $t6, $t8, 9f
        nop
        lui     $t8, 0x800c
        lw      $t6, 0x3000($t8)           /* 0x800C3000 game flags */
        lui     $t9, 0x0050
        ori     $t9, $t9, 0x7f00
        and     $t6, $t6, $t9
        bnez    $t6, 9f
        nop
        lw      $t6, 0x3004($t8)
        lui     $t9, 0x1000
        and     $t6, $t6, $t9
        bnez    $t6, 9f
        nop
        lbu     $t6, 0x51a9($t8)           /* player routine: 0 = normal */
        bnez    $t6, 9f
        nop
        lbu     $t6, 0x51aa($t8)           /* sub-state: idle / walking / turning */
        sltiu   $t6, $t6, 9
        beqz    $t6, 9f
        nop
        lh      $t6, 0x51ac($t8)           /* health */
        blez    $t6, 9f
        nop
        lw      $t6, -0x4ef8($t8)          /* 0x800BB108 inventory pointer */
        addiu   $t9, $t0, -0x787c          /* 0x800C8784 main inventory */
        bne     $t6, $t9, 9f
        nop
        li      $v0, 1
9:      lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* ------------------------------------------------------------------
   s4 = OT descriptor of this frame, frame = 0x800C3010. The main loop
   clears three OT pairs (20 bytes per descriptor): 0x800C88C8 (scene,
   1024 entries), 0x800C88F0 and 0x800C88A0 (inventory).
   ot_desc: inventory OT, ot_desc_game: scene OT (drawn in game) */
ot_desc_game:
        b       1f
        ori     $t3, $zero, 0x88c8
ot_desc:
        ori     $t3, $zero, 0x88a0
1:      lui     $t0, 0x800c
        lbu     $t1, 0x3010($t0)
        sll     $t2, $t1, 2
        addu    $t2, $t2, $t1
        sll     $t2, $t2, 2
        or      $s4, $t0, $t3
        jr      $ra
        addu    $s4, $s4, $t2

/* s2, s3 = screen offset of the inventory, as the sprite helper computes it */
menu_offset:
        lui     $t0, 0x800c
        lh      $t3, -0x716e($t0)          /* 0x800C8E92 */
        lui     $t5, 0x1f80
        lh      $t4, 0x398($t5)
        subu    $s2, $t3, $t4
        lh      $t3, -0x7168($t0)          /* 0x800C8E98 */
        lh      $t4, 0x39a($t5)
        jr      $ra
        subu    $s3, $t3, $t4

/* a0 = slot -> t8 = screen x, t9 = screen y of its 40x30 inventory cell
   (needs s2, s3 from menu_offset) */
cell_origin:
        lui     $t1, (SLOT_XY >> 16)
        addiu   $t1, $t1, (SLOT_XY & 0xffff)
        addiu   $t2, $a0, 4
        sll     $t2, $t2, 2
        addu    $t1, $t1, $t2
        lh      $t8, 0($t1)
        lh      $t9, 2($t1)
        addu    $t8, $t8, $s2
        jr      $ra
        addu    $t9, $t9, $s3

/* ------------------------------------------------------------------
   a0 = primitive, a2 = z, a3 = words after the tag: links it into this
   frame's OT (s4) and advances the packet pointer 0x800B7978. */
link_prim:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        move    $a1, $s4
        JAL(F_OT_LINK)
        lui     $t0, 0x800b
        sw      $v0, 0x7978($t0)
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* write t6 vertices from signed byte pairs at t5, relative to (t8, t9),
   to t7 (one y<<16 | x word each). uses t1, t2 */
put_vertices:
        lb      $t1, 0($t5)
        lb      $t2, 1($t5)
        addu    $t1, $t1, $t8
        addu    $t2, $t2, $t9
        andi    $t1, $t1, 0xffff
        sll     $t2, $t2, 16
        or      $t1, $t1, $t2
        sw      $t1, 0($t7)
        addiu   $t5, $t5, 2
        addiu   $t7, $t7, 4
        addiu   $t6, $t6, -1
        bnez    $t6, put_vertices
        nop
        jr      $ra
        nop

/* (put_poly, put_tile, put_ft4 add st.ybias to y) */

/* flat polygon: a0 = GPU command + colour, a1 = vertices (byte pairs,
   relative to t8, t9), a2 = vertex count (3 or 4), a3 = z */
put_poly:
        addiu   $sp, $sp, -0x20
        sw      $ra, 0x1c($sp)
        lui     $t0, %hi(st + ST_YBIAS)
        lh      $t0, %lo(st + ST_YBIAS)($t0)
        addu    $t9, $t9, $t0
        sw      $a2, 0x18($sp)
        sw      $a3, 0x14($sp)
        lui     $t0, 0x800b
        lw      $t7, 0x7978($t0)           /* packet pointer */
        sw      $t7, 0x10($sp)
        sw      $a0, 4($t7)
        move    $t5, $a1
        move    $t6, $a2
        jal     put_vertices
        addiu   $t7, $t7, 8
        lw      $a0, 0x10($sp)
        lw      $a3, 0x18($sp)
        lw      $a2, 0x14($sp)
        jal     link_prim
        addiu   $a3, $a3, 1
        lw      $ra, 0x1c($sp)
        jr      $ra
        addiu   $sp, $sp, 0x20

/* one-word primitive (draw mode): a0 = word, a2 = z.
   Linked after the primitives of the same z, it is drawn before them. */
put_mode:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t0, 0x800b
        lw      $t7, 0x7978($t0)
        sw      $a0, 4($t7)
        move    $a0, $t7
        jal     link_prim
        li      $a3, 1
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* filled rectangle: a0 = x, a1 = y, a2 = h << 16 | w, a3 = GP_TILE + colour,
   at z = Z_HUD */
put_tile:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t0, %hi(st + ST_YBIAS)
        lh      $t0, %lo(st + ST_YBIAS)($t0)
        addu    $a1, $a1, $t0
        lui     $t0, 0x800b
        lw      $t7, 0x7978($t0)
        sw      $a3, 4($t7)
        andi    $t1, $a0, 0xffff
        sll     $t2, $a1, 16
        or      $t1, $t1, $t2
        sw      $t1, 8($t7)
        sw      $a2, 12($t7)
        move    $a0, $t7
        li      $a2, Z_HUD
        jal     link_prim
        li      $a3, 3
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* textured quad (POLY_FT4): a0 = x, a1 = y, a2 = v << 8 | u, a3 = texture
   descriptor (see TEX_* below): the texture rectangle tw x th at (u, v) is
   drawn as sw x sh at (x, y). uses t0-t7 */
put_ft4:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        lui     $t0, %hi(st + ST_YBIAS)
        lh      $t0, %lo(st + ST_YBIAS)($t0)
        addu    $a1, $a1, $t0
        lui     $t0, 0x800b
        lw      $t7, 0x7978($t0)
        lw      $t1, TEX_CMD($a3)
        sw      $t1, 4($t7)
        lhu     $t2, TEX_SW($a3)
        lhu     $t3, TEX_SH($a3)
        andi    $t4, $a0, 0xffff           /* x */
        addu    $t6, $a0, $t2
        andi    $t6, $t6, 0xffff           /* x + sw */
        sll     $t5, $a1, 16               /* y << 16 */
        or      $t1, $t4, $t5
        sw      $t1, 8($t7)                /* top left */
        or      $t1, $t6, $t5
        sw      $t1, 16($t7)               /* top right */
        addu    $t5, $a1, $t3
        sll     $t5, $t5, 16               /* (y + sh) << 16 */
        or      $t1, $t4, $t5
        sw      $t1, 24($t7)               /* bottom left */
        or      $t1, $t6, $t5
        sw      $t1, 32($t7)               /* bottom right */
        lbu     $t2, TEX_TW($a3)
        lbu     $t3, TEX_TH($a3)
        andi    $t4, $a2, 0xff             /* u */
        addu    $t6, $t4, $t2              /* u + tw */
        andi    $t5, $a2, 0xff00           /* v << 8 */
        sll     $t3, $t3, 8
        addu    $t3, $t5, $t3              /* (v + th) << 8 */
        lhu     $t1, TEX_CLUT($a3)
        sll     $t1, $t1, 16
        or      $t1, $t1, $t4
        or      $t1, $t1, $t5
        sw      $t1, 12($t7)               /* uv0 | clut */
        lhu     $t1, TEX_TPAGE($a3)
        sll     $t1, $t1, 16
        or      $t1, $t1, $t6
        or      $t1, $t1, $t5
        sw      $t1, 20($t7)               /* uv1 | tpage */
        or      $t1, $t4, $t3
        sw      $t1, 28($t7)               /* uv2 */
        or      $t1, $t6, $t3
        sw      $t1, 36($t7)               /* uv3 */
        lbu     $a2, TEX_Z($a3)
        move    $a0, $t7
        jal     link_prim
        li      $a3, 9
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* number 0..999 with the inventory digits, no leading zeros:
   a0 = x, a1 = y, a2 = value, a3 = colour column (DIG_*) */
draw_number:
        addiu   $sp, $sp, -0x28
        sw      $ra, 0x24($sp)
        sw      $s0, 0x20($sp)
        sw      $s1, 0x1c($sp)
        sw      $s2, 0x18($sp)
        sw      $s3, 0x14($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s3, $a3
        sltiu   $t1, $a2, 1000
        bnez    $t1, 1f
        nop
        li      $a2, 999
1:      move    $t1, $zero                 /* hundreds */
2:      sltiu   $t2, $a2, 100
        bnez    $t2, 3f
        nop
        addiu   $a2, $a2, -100
        b       2b
        addiu   $t1, $t1, 1
3:      sb      $t1, 0x10($sp)
        move    $t1, $zero                 /* tens */
4:      sltiu   $t2, $a2, 10
        bnez    $t2, 5f
        nop
        addiu   $a2, $a2, -10
        b       4b
        addiu   $t1, $t1, 1
5:      sb      $t1, 0x11($sp)
        sb      $a2, 0x12($sp)
        move    $s2, $zero                 /* first digit drawn: skip zeros, keep the last */
6:      sltiu   $t2, $s2, 2
        beqz    $t2, 7f
        addu    $t3, $sp, $s2
        lbu     $t3, 0x10($t3)
        bnez    $t3, 7f
        nop
        b       6b
        addiu   $s2, $s2, 1
7:      addu    $t3, $sp, $s2
        lbu     $t3, 0x10($t3)
        move    $a0, $s0
        move    $a1, $s1
        sll     $t3, $t3, 11               /* v = digit * 8, in bits 8-15 */
        or      $a2, $s3, $t3
        lui     $a3, %hi(tex_digit)
        jal     put_ft4
        addiu   $a3, $a3, %lo(tex_digit)
        addiu   $s0, $s0, DIGIT_STEP
        addiu   $s2, $s2, 1
        sltiu   $t2, $s2, 3
        bnez    $t2, 7b
        nop
        move    $v0, $s0
        lw      $ra, 0x24($sp)
        lw      $s0, 0x20($sp)
        lw      $s1, 0x1c($sp)
        lw      $s2, 0x18($sp)
        lw      $s3, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x28

/* v0 = width in pixels of a number drawn by draw_number (a0 = value) */
number_width:
        li      $v0, DIGIT_STEP
        sltiu   $t1, $a0, 10
        bnez    $t1, 9f
        nop
        addiu   $v0, $v0, DIGIT_STEP
        sltiu   $t1, $a0, 100
        bnez    $t1, 9f
        nop
        addiu   $v0, $v0, DIGIT_STEP
9:      jr      $ra
        nop

/* ------------------------------------------------------------------ */
        .section .data
        .balign 4
/* texture descriptors for put_ft4 (fields: TEX_* in game.h) */
tex_digit:      .word GP_FT4 | 0x808080
                .hword CLUT_DIGITS, TP_DIGITS, 8, 8
                .byte 8, 8, Z_HUD, 0
tex_icon:       .word GP_FT4 | 0x808080
                .hword CLUT_ICONS, TP_ICONS, 40, 30
                .byte 40, 30, Z_OVERLAY, 0
tex_icon_half:  .word GP_FT4 | 0x808080
                .hword CLUT_ICONS, TP_ICONS, 20, 15
                .byte 40, 30, Z_HUD, 0
        .section .text
