/* Features hud_hp and hud_ammo, drawn in game (frame_hook):
     hud_hp   : top left, a cross in the colour of the condition shown by
                the inventory (green / yellow / orange / red) and the health
                in digits of the same colour family
     hud_ammo : under it, the equipped weapon icon (half size) and its ammo
                (red when empty, nothing for the knife)
   Condition level = (health - 1) / (max health / 4), max 3, as the
   inventory computes it (max health: byte P_HPMAX).

   Needs: frame_hook (s4 = OT), lib.S. Textures: inventory digits and icon
   cache, resident in VRAM during the game. */

#define HUD_X           10
#define HUD_Y           10

hud_draw:
        addiu   $sp, $sp, -0x20
        sw      $ra, 0x1c($sp)
        sw      $s0, 0x18($sp)
        sw      $s1, 0x14($sp)
        CFG($t0, C_HUD_HP)
        beqz    $t0, 3f
        nop
        lui     $t8, %hi(P_HP)
        SAMEHI(P_HP, P_HPMAX)
        lh      $s0, %lo(P_HP)($t8)        /* health */
        lbu     $t1, %lo(P_HPMAX)($t8)     /* max health */
        move    $s1, $zero                 /* condition level */
        blez    $s0, 2f
        srl     $t1, $t1, 2
        beqz    $t1, 2f
        addiu   $t2, $s0, -1
        divu    $t2, $t1
        mflo    $s1
        sltiu   $t3, $s1, 4
        bnez    $t3, 2f
        nop
        li      $s1, 3
2:      bgez    $s0, 1f
        nop
        move    $s0, $zero
1:      /* cross, colour from the game's table (R, G, B bytes) */
        lui     $t1, (COND_COLOURS >> 16)
        addiu   $t1, $t1, (COND_COLOURS & 0xffff)
        sll     $t2, $s1, 1
        addu    $t2, $t2, $s1
        addu    $t1, $t1, $t2
        lbu     $t3, 0($t1)
        lbu     $t4, 1($t1)
        lbu     $t5, 2($t1)
        sll     $t4, $t4, 8
        sll     $t5, $t5, 16
        or      $t3, $t3, $t4
        or      $t3, $t3, $t5
        lui     $t4, (GP_TILE >> 16)
        or      $t3, $t3, $t4
        sw      $t3, 0x10($sp)
        li      $a0, HUD_X                 /* horizontal bar 7x3 */
        li      $a1, HUD_Y + 2
        lui     $a2, 3
        ori     $a2, $a2, 7
        jal     put_tile
        move    $a3, $t3
        li      $a0, HUD_X + 2             /* vertical bar 3x7 */
        li      $a1, HUD_Y
        lw      $a3, 0x10($sp)
        lui     $a2, 7
        jal     put_tile
        ori     $a2, $a2, 3
        /* health */
        lui     $t1, %hi(level_digits)
        addu    $t1, $t1, $s1
        lbu     $a3, %lo(level_digits)($t1)
        li      $a0, HUD_X + 10
        li      $a1, HUD_Y
        jal     draw_number
        move    $a2, $s0

3:      CFG($t0, C_HUD_AMMO)
        beqz    $t0, 9f
        nop
        lui     $t0, %hi(EQUIPPED)
        lbu     $t1, %lo(EQUIPPED)($t0)    /* equipped slot, 1-based */
        beqz    $t1, 9f
        nop
        lui     $t8, %hi(INV_PTR)
        lw      $t2, %lo(INV_PTR)($t8)     /* inventory pointer */
        sll     $t3, $t1, 1
        addu    $t2, $t2, $t3
        lbu     $s0, -2($t2)               /* weapon id */
        lbu     $s1, -1($t2)               /* ammo */
        beqz    $s0, 9f
        nop
        SAMEHI(INV_PTR, ICON_CACHE)
        addiu   $t3, $t8, %lo(ICON_CACHE)  /* icon cache slot per item slot */
        addu    $t3, $t3, $t1
        lbu     $t3, -1($t3)
        sll     $t3, $t3, 13               /* v = cache slot * 32, in bits 8-15 */
        ori     $a2, $t3, 88               /* u */
        li      $a0, HUD_X - 2
        li      $a1, HUD_Y + 12
        lui     $a3, %hi(tex_icon_half)
        jal     put_ft4
        addiu   $a3, $a3, %lo(tex_icon_half)
        li      $t1, 1                     /* knife: no ammo */
        beq     $s0, $t1, 9f
        nop
        jal     ammo_count                 /* s1 = what the inventory shows */
        nop
        li      $a3, DIG_GREEN
        bnez    $s1, 4f
        nop
        li      $a3, DIG_RED
4:      li      $a0, HUD_X + 20
        li      $a1, HUD_Y + 16
        jal     draw_number
        move    $a2, $s1
9:      lui     $a0, (MODE_ADD >> 16)      /* draw mode, drawn first: the game may leave */
        ori     $a0, $a0, (MODE_ADD & 0xffff)  /* drawing to the display area off */
        jal     put_mode
        li      $a2, Z_HUD
        lw      $ra, 0x1c($sp)
        lw      $s0, 0x18($sp)
        lw      $s1, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x20

/* s0 = item id, s1 = quantity -> s1 = number shown by the inventory
   (weapons other than id 6 keep a flag in bit 7). uses t1 */
ammo_count:
        sltiu   $t1, $s0, 11
        beqz    $t1, 9f
        li      $t1, 6
        beq     $s0, $t1, 9f
        nop
        andi    $s1, $s1, 0x7f
9:      jr      $ra
        nop

        .section .data
level_digits:                              /* digit colour per condition level */
        .byte   DIG_RED, DIG_ORANGE, DIG_ORANGE, DIG_GREEN
        .section .text
