/* Resident Evil Director's Cut: what the mods use of the game.
   The addresses depend on the version: build/<version>/version.h, generated
   from src/versions.py. See CLAUDE.md for what each one is and how it was found.

   code (functions; call args in comments)
     GAME_ENTRY      original pc0
     LOOP_NEXT       called at SITE_HOOK, main loop after the pad read
     F_PAL_ANIM      called at SITE_FRAME, once per frame before DrawSync (OT complete)
     F_GRID_DRAW     called at SITE_GRID: inventory item grid
     F_LOAD_SOUNDS   (weapon id, VB buffer)
     F_LOAD_WEAPON   (weapon id, 14, WEAPON_BUF, ANIM_BUF)
     F_PLAY_SE       (bank, sound, 0)
     F_SET_ANIM      player animation
     F_TASK_START    (slot, entry)    F_TASK_EXIT ()    F_TASK_SUSPEND (slot)    F_TASK_RESUME (slot)
     F_HEAL          "use" for items 0x41..0x4B, item id in MENU_WORK + MW_ITEM
     F_COMPACT       compact the inventory
     F_OT_LINK       (prim, OT descriptor, z, words) -> next packet
     MENU_TASK, GAME_TASK   task entries (inventory, game)
   data
     COND_COLOURS    RGB per condition level 0..3 (red, orange, yellow, green)
     SLOT_XY         inventory cell (x, y) pairs, cell n at (n + 4) * 4
     PKT_PTR         packet pointer          MENU_OFS     menu screen offset x (y at +6)
     MENU_WORK       inventory work bytes    INV_PTR      active inventory pointer
     ICON_CACHE      icon cache slot per inventory slot
     PAD             raw pad: +0 held, +4 newly pressed, +8, +0xC
     + the COMMON ones of versions.py (GFLAGS, PLAYER, ...) */
#include "version.h"

/* fields */
#define PAD_HELD        (PAD + 0)
#define PAD_NEW         (PAD + 4)
#define MAP_HELD        (MAP_PAD + 0)
#define MAP_NEW         (MAP_PAD + 2)
#define G_FLAGS         (GFLAGS + 0)
#define G_FLAGS2        (GFLAGS + 4)
#define G_FRAME         (GFLAGS + 0x10)
#define Y_OFFSET        (DOOR_FLAG + 1)     /* 0 or 240: the game adds it to its y */
#define P_WEAPON        (PLAYER + 0x02)     /* weapon id */
#define P_ANGLE         (PLAYER + 0x74)     /* halfword 0..0xFFF, 0x800 = half a turn */
#define P_STATE         (PLAYER + 0x84)     /* word; +1 routine (0 = normal), +2 sub-state */
#define P_ROUTINE       (PLAYER + 0x85)
#define P_SUBSTATE      (PLAYER + 0x86)     /* < 9: idle / walking / turning */
#define P_HP            (PLAYER + 0x88)
#define P_HPMAX         (PLAYER + 0x175)
#define MW_ITEM         (MENU_WORK + 0x0b)  /* item under the cursor */
#define MW_GRID         (MENU_WORK + 0x10)  /* 1 = on the grid */
#define MW_CURSOR       (MENU_WORK + 0x13)  /* (slot + 4) * 2 */
#define OT_MENU         0x800c88a0          /* + frame * 20: inventory OT descriptors */
#define OT_SCENE        0x800c88c8          /* + frame * 20: scene OT descriptors */

/* lui once for two addresses: assemble only if they share the upper half */
#define SAMEHI(a, b)    .if (((a) + 0x8000) >> 16) - (((b) + 0x8000) >> 16); .error "different %hi: " #a " " #b; .endif

/* textures resident in VRAM during the game (8 bpp) */
#define TP_DIGITS       0x9c            /* tpage 28 (768,256) 8 bpp: digits 8x8, u = colour column, v = digit * 8 */
#define CLUT_DIGITS     0x7900          /* (0,484) */
#define TP_ICONS        0x9d            /* tpage 29 (832,256) 8 bpp: item icons 40x30 at u = 88, v = cache slot * 32 */
#define CLUT_ICONS      0x7980          /* (0,486) */
#define DIG_GREEN       0x80
#define DIG_ORANGE      0x88
#define DIG_BLUE        0x90
#define DIG_RED         0xc0

/* GPU commands (colour in the low 24 bits, 0xBBGGRR) */
#define GP_F3           0x20000000
#define GP_F3_SEMI      0x22000000
#define GP_F4_SEMI      0x2a000000
#define GP_FT4          0x2c000000
#define GP_TILE         0x60000000
#define MODE_ADD        0xe1000620      /* draw mode: semi-transparency B+F, dither */
#define MODE_SUB        0xe1000640      /* draw mode: semi-transparency B-F, dither */

/* depth in the OT (smaller = drawn later = in front); the inventory icons are at 4 */
#define Z_MENU          3               /* inventory arrows / pick highlight */
#define Z_HUD           1
#define Z_OV_BACK       3               /* overlay panel */
#define Z_OVERLAY       2               /* overlay arrows, icons, numbers */
#define Z_OV_FRONT      1               /* overlay: equipped highlight */
#define DIGIT_STEP      7

/* texture descriptor for put_ft4 (lib.S): command word, clut, tpage,
   screen size, texture size, z */
#define TEX_CMD         0
#define TEX_CLUT        4
#define TEX_TPAGE       6
#define TEX_SW          8
#define TEX_SH          10
#define TEX_TW          12
#define TEX_TH          13
#define TEX_Z           14

/* call a game function (same 256 MB segment, plain jal works) */
#define JAL(f)          jal f; nop
/* config byte n -> reg (0 = feature off) */
#define CFG(reg, n)     lui reg, %hi(config + n); lbu reg, %lo(config + n)(reg)

/* fields of `st` (hotkey.S) */
#define ST_PICK         0
#define ST_PEND         1
#define ST_TURN         2
#define ST_LOCK         3
#define ST_YBIAS        4               /* halfword: y added to our primitives (frame_hook) */
#define ST_MENU         6               /* TASK_PC_RESUME: frames left since the grid was drawn */
#define ST_OPT          8               /* options menu open */
#define ST_OPTCUR       9               /* options menu: selected line */
#define ST_SELCNT       10              /* frames with Select held */
#define ST_OPTLOCK      11              /* options menu just closed: pad hidden until released */

/* config byte numbers (the patcher writes the bytes at _start + 8 + n) */
#define C_MENU_MOVE     0
#define C_QUICKSLOTS    1
#define C_OVERLAY       2
#define C_HUD_HP        3
#define C_HUD_AMMO      4
#define C_QUICKTURN     5
#define C_OPTIONS       6
