/* Resident Evil Director's Cut (PAL-F, SLES-009.70): game addresses used by the mods.
   See CLAUDE.md for what each one is and how it was found. */

/* ---- code ---- */
#define GAME_ENTRY      0x800606a8      /* original pc0 */
#define LOOP_NEXT       0x80032edc      /* replaced call in the main loop (after the pad read) */
#define F_PAL_ANIM      0x80015c0c      /* replaced call, once per frame before DrawSync */
#define F_GRID_DRAW     0x80054f3c      /* replaced call: inventory item grid */
#define F_SYNC_EQUIP    0x80054e74      /* not called: see swap_task */
#define F_LOAD_SOUNDS   0x80052404      /* (weapon id, VB buffer) */
#define F_LOAD_WEAPON   0x800249c0
#define F_PLAY_SE       0x800532d0      /* (bank, sound, 0) */
#define F_SET_ANIM      0x80030474
#define F_TASK_START    0x80037598      /* (slot, entry) */
#define F_TASK_EXIT     0x800375f4
#define F_TASK_SUSPEND  0x80037710      /* (slot) */
#define F_TASK_RESUME   0x80037734      /* (slot) */
#define F_HEAL          0x80057ca0      /* "use" for items 0x41..0x4B, id in 0x800B90EB */
#define F_COMPACT       0x8002d678      /* compact the inventory */
#define F_OT_LINK       0x80066dac      /* (prim, OT descriptor, z, words) -> next packet */
#define MENU_TASK       0x800546d8
#define GAME_TASK       0x8002a050

/* ---- data ---- */
#define WEAPON_BUF      0x800ea800      /* weapon model, 0x7A00 bytes; biggest weapon VB = 15 sectors */
#define COND_COLOURS    0x80091ccc      /* RGB per condition level 0..3 (red, orange, yellow, green) */
#define SLOT_XY         0x80092e68      /* inventory cell (x, y) pairs, cell n at (n + 4) * 4 */

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

/* config byte numbers (the patcher writes the bytes at _start + 8 + n) */
#define C_MENU_MOVE     0
#define C_QUICKSLOTS    1
#define C_OVERLAY       2
#define C_HUD_HP        3
#define C_HUD_AMMO      4
#define C_QUICKTURN     5
