/* Feature options: in game, hold Select for about 3 seconds to pause the
   game and open the options menu over the last game frame:
     Up / Down         choose a mod option
     Cross, Left/Right switch it on / off
     Start, Triangle,
     Select            back to the game
   The options are the bytes of `config` (the ones the patcher writes), so
   they apply at once. They are not saved: the patcher's choice comes back
   at the next boot.

   How:
   - the game task is suspended (like the inventory does); the last drawn
     frame is copied into the room background copy (BG_COPY), which the main
     loop redraws every frame: the frozen frame stays on screen;
   - the menu font (src/font.py, 1 bpp) is expanded into FONT_RAM and loaded
     into VRAM at FONT_X, FONT_Y; the VRAM it covers is saved in VRAM_SAVE
     and put back on exit;
   - on exit a task reloads the real room background (F_BG_RELOAD, as the
     inventory exit does) and resumes the game task.
   This code lives in .text2: game code that nothing can reach (see
   tools/re/deadcode.py), at OPT_CODE; VRAM_SAVE and FONT_RAM are two other
   such ranges, used as RAM.

   Needs: hook (input), frame_hook (drawing), lib.S */

#define OPT_HOLD        75              /* game frames with Select held */
#define OPT_COUNT       6               /* options listed: config bytes 0..5 (not this menu) */
#define FONT_GLYPHS     42              /* len(src/font.py CHARS), checked by build.py */
#define BG_COPY         0x801d10ec      /* room background copy, 320x240 */
#define FONT_X          896             /* VRAM, 16-bit units */
#define FONT_Y          496
#define FONT_W          42              /* 21 glyphs of 8 px (4 bpp) per row, 2 rows */
#define FONT_H          16
#define FONT_STRIDE     (FONT_W * 2)
#define CLUT_X          944
#define FONT_BYTES      (FONT_STRIDE * FONT_H)
#define FONT_TPAGE      ((FONT_X / 64) | ((FONT_Y / 256) << 4))         /* 4 bpp */
#define FONT_CLUT       ((CLUT_X / 16) | (FONT_Y << 6))
#define FONT_V0         (FONT_Y & 0xff)
#define MODE_FONT       (0xe1000600 | FONT_TPAGE)
#define MODE_HALF       0xe1000600      /* semi-transparency 0.5 B + 0.5 F */
#define GP_SPRT8        0x74000000      /* 8x8 textured sprite */
#define PAD_SELECT      0x0100
#define OPT_X           58
#define OPT_Y           44
#define OPT_LINE        14

        .section .text2, "ax"

/* from hook, every frame outside the inventory (if config C_OPTIONS):
   v0 = 1 if the frame belongs to the options menu (no other input then) */
        .globl options_hook
options_hook:
        addiu   $sp, $sp, -0x20
        sw      $ra, 0x1c($sp)
        sw      $s0, 0x18($sp)
        lui     $s0, %hi(st)
        addiu   $s0, $s0, %lo(st)
        lbu     $t1, ST_OPT($s0)
        bnez    $t1, opt_input
        nop
        lbu     $t1, ST_OPTLOCK($s0)
        beqz    $t1, 2f
        nop
        /* just closed: hide the pad from the game until everything is released */
        lui     $t0, %hi(PAD_HELD)
        lw      $t1, %lo(PAD_HELD)($t0)
        bnez    $t1, 1f
        nop
        sb      $zero, ST_OPTLOCK($s0)
1:      lui     $t0, %hi(MAP_HELD)
        sh      $zero, %lo(MAP_HELD)($t0)
        SAMEHI(MAP_HELD, MAP_NEW)
        sh      $zero, %lo(MAP_NEW)($t0)
        b       8f
        li      $v0, 1
2:      /* Select held long enough, in game? */
        lui     $t0, %hi(PAD_HELD)
        lw      $t1, %lo(PAD_HELD)($t0)
        andi    $t1, $t1, PAD_SELECT
        beqz    $t1, 3f
        nop
        jal     game_running
        nop
        beqz    $v0, 3f
        nop
        lui     $t0, %hi(CTRL_FLAGS)
        lhu     $t1, %lo(CTRL_FLAGS)($t0)
        andi    $t1, $t1, 0x0100
        beqz    $t1, 3f
        nop
        lbu     $t1, ST_SELCNT($s0)
        addiu   $t1, $t1, 1
        sb      $t1, ST_SELCNT($s0)
        sltiu   $t1, $t1, OPT_HOLD
        bnez    $t1, 7f
        nop
        jal     opt_open
        nop
        b       8f
        li      $v0, 1
3:      sb      $zero, ST_SELCNT($s0)
7:      move    $v0, $zero
8:      lw      $ra, 0x1c($sp)
        lw      $s0, 0x18($sp)
        jr      $ra
        addiu   $sp, $sp, 0x20

/* menu open: pad (s0 = st, frame of options_hook) */
opt_input:
        lui     $t0, %hi(PAD_NEW)
        lw      $t2, %lo(PAD_NEW)($t0)     /* newly pressed */
        lbu     $t3, ST_OPTCUR($s0)
        andi    $t1, $t2, 0x1000           /* up */
        beqz    $t1, 1f
        nop
        addiu   $t3, $t3, OPT_COUNT - 1
1:      andi    $t1, $t2, 0x4000           /* down */
        beqz    $t1, 2f
        nop
        addiu   $t3, $t3, 1
2:      sltiu   $t1, $t3, OPT_COUNT        /* wrap */
        bnez    $t1, 3f
        nop
        addiu   $t3, $t3, -OPT_COUNT
3:      lbu     $t1, ST_OPTCUR($s0)
        sb      $t3, ST_OPTCUR($s0)
        beq     $t1, $t3, 4f
        nop
        sw      $t2, 0x10($sp)
        jal     opt_sound
        li      $a1, 5
        lw      $t2, 0x10($sp)
4:      andi    $t1, $t2, 0xa040           /* cross, left, right: switch */
        beqz    $t1, 5f
        nop
        lbu     $t3, ST_OPTCUR($s0)
        lui     $t4, %hi(config)
        addiu   $t4, $t4, %lo(config)
        addu    $t4, $t4, $t3
        lbu     $t5, 0($t4)
        sw      $t2, 0x10($sp)
        xori    $t5, $t5, 1
        sb      $t5, 0($t4)
        jal     opt_sound
        li      $a1, 6
        lw      $t2, 0x10($sp)
5:      andi    $t1, $t2, 0x0910           /* start, select, triangle: back */
        beqz    $t1, 6f
        nop
        jal     opt_close
        nop
6:      b       8b
        li      $v0, 1

/* a1 = menu sound (bank 3) */
opt_sound:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        li      $a0, 3
        JAL(F_PLAY_SE)
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* pause the game, freeze its last frame, load the font */
opt_open:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        sw      $s0, 0x10($sp)
        lui     $s0, %hi(st)
        addiu   $s0, $s0, %lo(st)
        move    $a0, $zero
        JAL(F_TASK_SUSPEND)                /* game task */
        move    $a0, $zero
        JAL(F_DRAW_SYNC)
        /* the frame drawn last (buffer of the y offset) -> background copy */
        lui     $t0, %hi(Y_OFFSET)
        lbu     $t1, %lo(Y_OFFSET)($t0)
        lui     $a0, %hi(rect_frame)
        addiu   $a0, $a0, %lo(rect_frame)
        sh      $t1, 2($a0)
        lui     $a1, (BG_COPY >> 16)
        jal     F_STORE_IMAGE
        ori     $a1, $a1, (BG_COPY & 0xffff)
        /* keep the VRAM under the font */
        lui     $a0, %hi(rect_font)
        addiu   $a0, $a0, %lo(rect_font)
        lui     $a1, %hi(VRAM_SAVE)
        jal     F_STORE_IMAGE
        addiu   $a1, $a1, %lo(VRAM_SAVE)
        lui     $a0, %hi(rect_clut)
        addiu   $a0, $a0, %lo(rect_clut)
        lui     $a1, %hi(VRAM_SAVE + FONT_BYTES)
        jal     F_STORE_IMAGE
        addiu   $a1, $a1, %lo(VRAM_SAVE + FONT_BYTES)
        move    $a0, $zero
        JAL(F_DRAW_SYNC)
        jal     font_expand
        nop
        lui     $a0, %hi(rect_font)
        addiu   $a0, $a0, %lo(rect_font)
        lui     $a1, %hi(FONT_RAM)
        jal     F_LOAD_IMAGE
        addiu   $a1, $a1, %lo(FONT_RAM)
        lui     $a0, %hi(rect_clut)
        addiu   $a0, $a0, %lo(rect_clut)
        lui     $a1, %hi(font_clut)
        jal     F_LOAD_IMAGE
        addiu   $a1, $a1, %lo(font_clut)
        move    $a0, $zero
        JAL(F_DRAW_SYNC)
        li      $t1, 1
        sb      $t1, ST_OPT($s0)
        sb      $zero, ST_SELCNT($s0)
        jal     opt_sound
        li      $a1, 6
        lw      $ra, 0x14($sp)
        lw      $s0, 0x10($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* put the VRAM back, then a task reloads the room background and resumes */
opt_close:
        addiu   $sp, $sp, -0x18
        sw      $ra, 0x14($sp)
        move    $a0, $zero
        JAL(F_DRAW_SYNC)
        lui     $a0, %hi(rect_font)
        addiu   $a0, $a0, %lo(rect_font)
        lui     $a1, %hi(VRAM_SAVE)
        jal     F_LOAD_IMAGE
        addiu   $a1, $a1, %lo(VRAM_SAVE)
        lui     $a0, %hi(rect_clut)
        addiu   $a0, $a0, %lo(rect_clut)
        lui     $a1, %hi(VRAM_SAVE + FONT_BYTES)
        jal     F_LOAD_IMAGE
        addiu   $a1, $a1, %lo(VRAM_SAVE + FONT_BYTES)
        move    $a0, $zero
        JAL(F_DRAW_SYNC)
        lui     $t0, %hi(st)
        addiu   $t0, $t0, %lo(st)
        sb      $zero, ST_OPT($t0)
        li      $t1, 1
        sb      $t1, ST_OPTLOCK($t0)
        jal     opt_sound
        li      $a1, 4
        li      $a0, 1
        lui     $a1, %hi(opt_resume_task)
        jal     F_TASK_START
        addiu   $a1, $a1, %lo(opt_resume_task)
        lw      $ra, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x18

/* task (slot 1): real background back, game task resumed */
opt_resume_task:
        JAL(F_BG_RELOAD)
        move    $a0, $zero
        JAL(F_TASK_RESUME)
        JAL(F_TASK_EXIT)
1:      b       1b
        nop

/* 1 bpp font -> 4 bpp texture in FONT_RAM (glyph g: column g % 21, row g / 21) */
font_expand:
        lui     $t0, %hi(FONT_RAM)
        addiu   $t0, $t0, %lo(FONT_RAM)
        li      $t1, FONT_BYTES / 4
        move    $t2, $t0
1:      sw      $zero, 0($t2)
        addiu   $t1, $t1, -1
        bnez    $t1, 1b
        addiu   $t2, $t2, 4
        lui     $t3, %hi(font_1bpp)
        addiu   $t3, $t3, %lo(font_1bpp)
        move    $t4, $zero                 /* glyph */
        move    $t5, $zero                 /* column */
        move    $t6, $t0                   /* top left of the glyph */
2:      move    $t7, $zero                 /* row 0..7 */
3:      lbu     $t8, 0($t3)
        addiu   $t3, $t3, 1
        sll     $t9, $t7, 6                /* row * FONT_STRIDE (84 = 64 + 16 + 4) */
        sll     $t1, $t7, 4
        addu    $t9, $t9, $t1
        sll     $t1, $t7, 2
        addu    $t9, $t9, $t1
        addu    $t9, $t9, $t6              /* first byte of this row of the glyph */
        li      $t1, 4                     /* 4 bytes = 8 pixels */
4:      move    $t2, $zero
        andi    $a0, $t8, 0x80             /* left pixel: low nibble */
        beqz    $a0, 5f
        andi    $a0, $t8, 0x40
        ori     $t2, $t2, 0x01
5:      beqz    $a0, 6f
        nop
        ori     $t2, $t2, 0x10
6:      sb      $t2, 0($t9)
        addiu   $t9, $t9, 1
        sll     $t8, $t8, 2
        addiu   $t1, $t1, -1
        bnez    $t1, 4b
        nop
        addiu   $t7, $t7, 1
        sltiu   $t1, $t7, 8
        bnez    $t1, 3b
        nop
        addiu   $t4, $t4, 1                /* next glyph */
        addiu   $t5, $t5, 1
        sltiu   $t1, $t5, 21
        bnez    $t1, 7f
        addiu   $t6, $t6, 4
        move    $t5, $zero                 /* second row of glyphs */
        addiu   $t6, $t0, FONT_STRIDE * 8
7:      sltiu   $t1, $t4, FONT_GLYPHS
        bnez    $t1, 2b
        nop
        jr      $ra
        nop

/* ------------------------------------------------------------------
   from frame_hook while the menu is open (s4 = scene OT, y bias set) */
        .globl options_draw
options_draw:
        addiu   $sp, $sp, -0x28
        sw      $ra, 0x24($sp)
        sw      $s0, 0x20($sp)
        sw      $s1, 0x1c($sp)
        /* black panel at 50 % (frozen frame still visible), drawn first */
        li      $t8, 160
        li      $t9, 120
        lui     $a0, (GP_F4_SEMI >> 16)
        lui     $a1, %hi(opt_panel)
        addiu   $a1, $a1, %lo(opt_panel)
        li      $a2, 4
        jal     put_poly
        li      $a3, Z_OV_BACK
        lui     $a0, (MODE_HALF >> 16)
        ori     $a0, $a0, (MODE_HALF & 0xffff)
        jal     put_mode
        li      $a2, Z_OV_BACK
        /* title */
        li      $a0, OPT_X
        li      $a1, OPT_Y - 18
        lui     $a2, %hi(str_title)
        addiu   $a2, $a2, %lo(str_title)
        lui     $a3, 0x0080
        jal     draw_text
        ori     $a3, $a3, 0x8080
        /* the options */
        move    $s0, $zero
1:      sll     $t1, $s0, 4                /* s0 * 16 - s0 * 2 = s0 * OPT_LINE (14) */
        sll     $t3, $s0, 1
        subu    $t1, $t1, $t3
        addiu   $s1, $t1, OPT_Y            /* s1 = y */
        lui     $t4, %hi(st + ST_OPTCUR)
        lbu     $t4, %lo(st + ST_OPTCUR)($t4)
        lui     $a3, 0x0080                /* white */
        bne     $t4, $s0, 2f
        ori     $a3, $a3, 0x8080
        lui     $a3, 0x0030                /* selected: yellow + cursor */
        ori     $a3, $a3, 0x8080
        sw      $a3, 0x10($sp)
        li      $a0, OPT_X - 10
        move    $a1, $s1
        lui     $a2, %hi(str_cursor)
        jal     draw_text
        addiu   $a2, $a2, %lo(str_cursor)
        lw      $a3, 0x10($sp)
2:      lui     $a2, %hi(opt_labels)
        sll     $t1, $s0, 2
        addu    $a2, $a2, $t1
        lw      $a2, %lo(opt_labels)($a2)
        li      $a0, OPT_X
        jal     draw_text
        move    $a1, $s1
        /* on / off */
        lui     $t1, %hi(config)
        addu    $t1, $t1, $s0
        lbu     $t1, %lo(config)($t1)
        lui     $a2, %hi(str_off)
        addiu   $a2, $a2, %lo(str_off)
        lui     $a3, 0x0030                /* off: red */
        beqz    $t1, 3f
        ori     $a3, $a3, 0x3080
        lui     $a2, %hi(str_on)
        addiu   $a2, $a2, %lo(str_on)
        lui     $a3, 0x0030                /* on: green */
        ori     $a3, $a3, 0x8030
3:      li      $a0, 232
        jal     draw_text
        move    $a1, $s1
        addiu   $s0, $s0, 1
        sltiu   $t1, $s0, OPT_COUNT
        bnez    $t1, 1b
        nop
        /* help line */
        li      $a0, OPT_X - 10
        li      $a1, OPT_Y + OPT_COUNT * OPT_LINE + 8
        lui     $a2, %hi(str_help)
        addiu   $a2, $a2, %lo(str_help)
        lui     $a3, 0x0060
        jal     draw_text
        ori     $a3, $a3, 0x6060
        /* texture page of the font, drawn before the text */
        lui     $a0, (MODE_FONT >> 16)
        ori     $a0, $a0, (MODE_FONT & 0xffff)
        jal     put_mode
        li      $a2, Z_HUD
        lw      $ra, 0x24($sp)
        lw      $s0, 0x20($sp)
        lw      $s1, 0x1c($sp)
        jr      $ra
        addiu   $sp, $sp, 0x28

/* a0 = x, a1 = y, a2 = glyph indices (0xff = end), a3 = colour (0xBBGGRR,
   0x80 = texture as is). 8x8 sprites at z = Z_HUD, 6 pixels apart */
draw_text:
        addiu   $sp, $sp, -0x28
        sw      $ra, 0x24($sp)
        sw      $s0, 0x20($sp)
        sw      $s1, 0x1c($sp)
        sw      $s2, 0x18($sp)
        sw      $s3, 0x14($sp)
        move    $s0, $a0
        lui     $t0, %hi(st + ST_YBIAS)
        lh      $t0, %lo(st + ST_YBIAS)($t0)
        addu    $s1, $a1, $t0
        move    $s2, $a2
        lui     $t1, (GP_SPRT8 >> 16)
        or      $s3, $a3, $t1
1:      lbu     $t1, 0($s2)
        addiu   $s2, $s2, 1
        li      $t2, 0xff
        beq     $t1, $t2, 9f
        nop
        beqz    $t1, 3f                    /* space */
        sltiu   $t2, $t1, 21
        li      $t3, FONT_V0               /* glyph row 0 */
        bnez    $t2, 2f
        nop
        addiu   $t1, $t1, -21
        li      $t3, FONT_V0 + 8
2:      sll     $t1, $t1, 3                /* u = column * 8 */
        sll     $t3, $t3, 8
        or      $t1, $t1, $t3
        lui     $t3, FONT_CLUT
        or      $t1, $t1, $t3              /* clut | v | u */
        lui     $t0, %hi(PKT_PTR)
        lw      $a0, %lo(PKT_PTR)($t0)
        sw      $s3, 4($a0)
        andi    $t2, $s0, 0xffff
        sll     $t3, $s1, 16
        or      $t2, $t2, $t3
        sw      $t2, 8($a0)
        sw      $t1, 12($a0)
        li      $a2, Z_HUD
        jal     link_prim
        li      $a3, 3
3:      b       1b
        addiu   $s0, $s0, 6
9:      lw      $ra, 0x24($sp)
        lw      $s0, 0x20($sp)
        lw      $s1, 0x1c($sp)
        lw      $s2, 0x18($sp)
        lw      $s3, 0x14($sp)
        jr      $ra
        addiu   $sp, $sp, 0x28

        .globl opt_code_end
opt_code_end:

/* ------------------------------------------------------------------ */
        .balign 4
rect_frame:     .hword 0, 0, 320, 240
rect_font:      .hword FONT_X, FONT_Y, FONT_W, FONT_H
rect_clut:      .hword CLUT_X, FONT_Y, 16, 1
font_clut:      .hword 0x0000, 0x7fff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
opt_panel:                                 /* relative to (160, 120) */
        .byte   -112,-104,  112,-104,  -112,84,  112,84
        .balign 4
#include "strings.inc"
font_1bpp:
#include "font.inc"
        .balign 4
        .globl opt_end
opt_end:
        .section .text
