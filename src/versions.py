"""Supported versions of Resident Evil Director's Cut: disc constants and the
game addresses used by the mod (src/*.S get them from build/<id>/version.h).

The FR addresses come from the original research (CLAUDE.md); the US ones
were found with tools/re/port.py and checked by hand (call sites, function
bodies, data tables found by content)."""

# names in every version (see src/game.h for what they are)
VERSIONS = {
    'fr': {
        'name': "Resident Evil - Director's Cut (France)",
        'serial': 'SLES-00970', 'exe_name': 'SLES_009.70',
        'bin_size': 720248256, 'bin_sha1': '5d9d1ea07595ae468ba4183a73331f0dace2384e',
        'exe_lba': 287669, 'exe_sectors': 320,
        'cue_tracks': '  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n',
        'chd': "Resident Evil - Director's Cut (France) [SLES_009.70].chd",
        'lang': 'fr',
        'game_fps': 25,            # PAL: the game loop runs at 50 / 2
        'addr': {
            'GAME_ENTRY': 0x800606a8, 'LOOP_NEXT': 0x80032edc, 'F_PAL_ANIM': 0x80015c0c, 'F_GRID_DRAW': 0x80054f3c,
            'SITE_HOOK': 0x80032084, 'SITE_FRAME': 0x80032740, 'SITE_GRID': 0x80054c9c,
            'F_LOAD_SOUNDS': 0x80052404, 'F_LOAD_WEAPON': 0x800249c0, 'F_PLAY_SE': 0x800532d0, 'F_SET_ANIM': 0x80030474,
            'F_TASK_START': 0x80037598, 'F_TASK_EXIT': 0x800375f4, 'F_TASK_SUSPEND': 0x80037710, 'F_TASK_RESUME': 0x80037734,
            'F_HEAL': 0x80057ca0, 'F_COMPACT': 0x8002d678, 'F_OT_LINK': 0x80066dac,
            'MENU_TASK': 0x800546d8, 'GAME_TASK': 0x8002a050,
            'COND_COLOURS': 0x80091ccc, 'SLOT_XY': 0x80092e68,
            'PKT_PTR': 0x800b7978, 'MENU_OFS': 0x800b8e92, 'MENU_WORK': 0x800b90e0,
            'INV_PTR': 0x800bb108, 'ICON_CACHE': 0x800bb1e8, 'PAD': 0x800cfc04,
            'F_LOAD_IMAGE': 0x800643a4, 'F_STORE_IMAGE': 0x80064408, 'F_DRAW_SYNC': 0x800640e0,
            'F_BG_RELOAD': 0x80017a4c,
            # unreachable game code (tools/re/deadcode.py, checked in PCSX-Redux)
            'OPT_CODE': 0x8008749c, 'OPT_CODE_SIZE': 3196, 'VRAM_SAVE': 0x800142f8, 'FONT_RAM': 0x800628a0,
        },
    },
    'us': {
        'name': "Resident Evil - Director's Cut (USA)",
        'serial': 'SLUS-00551', 'exe_name': 'SLUS_005.51',
        'bin_size': 707027664, 'bin_sha1': 'd926cec7ac6a1665cc00039ab92dee6a6bebe824',
        'exe_lba': 282051, 'exe_sectors': 318,
        'cue_tracks': '  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n',
        'chd': "Resident Evil - Director's Cut (USA).chd",
        'lang': 'en',
        'game_fps': 30,            # NTSC: 60 / 2
        'addr': {
            'GAME_ENTRY': 0x8005ef34, 'LOOP_NEXT': 0x80032074, 'F_PAL_ANIM': 0x80015df8, 'F_GRID_DRAW': 0x80053a18,
            'SITE_HOOK': 0x80031378, 'SITE_FRAME': 0x80031a1c, 'SITE_GRID': 0x80053780,
            'F_LOAD_SOUNDS': 0x80050fc4, 'F_LOAD_WEAPON': 0x80023e38, 'F_PLAY_SE': 0x80051e38, 'F_SET_ANIM': 0x8002f79c,
            'F_TASK_START': 0x800366b0, 'F_TASK_EXIT': 0x8003670c, 'F_TASK_SUSPEND': 0x80036828, 'F_TASK_RESUME': 0x8003684c,
            'F_HEAL': 0x80056660, 'F_COMPACT': 0x8002ca0c, 'F_OT_LINK': 0x80065f4c,
            'MENU_TASK': 0x80052e48, 'GAME_TASK': 0x800294b0,
            'COND_COLOURS': 0x80090b94, 'SLOT_XY': 0x80091d30,
            'PKT_PTR': 0x800b6878, 'MENU_OFS': 0x800b7d92, 'MENU_WORK': 0x800b7fe0,
            'INV_PTR': 0x800ba008, 'ICON_CACHE': 0x800ba0e8, 'PAD': 0x800cf844,
            'F_LOAD_IMAGE': 0x80063520, 'F_STORE_IMAGE': 0x80063584, 'F_DRAW_SYNC': 0x8006325c,
            'F_BG_RELOAD': 0x80017c2c,
            'OPT_CODE': 0x8008674c, 'OPT_CODE_SIZE': 3196, 'VRAM_SAVE': 0x800144f8, 'FONT_RAM': 0x80061a1c,
        },
    },
    'usds': {
        'name': "Resident Evil - Director's Cut - Dual Shock Ver. (USA)",
        'serial': 'SLUS-00747', 'exe_name': 'SLUS_007.47',
        'bin_size': 728602560, 'bin_sha1': 'e5d1612ead98cdd0f21232cfa914fc62771025ee',
        # Redump: track 1 alone (data, ends where track 2 and its pregap start)
        'track1_size': 293880 * 2352,
        'exe_lba': 293403, 'exe_sectors': 326,
        'cue_tracks': '  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n  TRACK 02 AUDIO\n    INDEX 00 65:18:30\n    INDEX 01 65:20:30\n',
        'chd': "Resident Evil - Director's Cut - Dual Shock Ver. (USA).chd",
        'lang': 'en',
        'game_fps': 30,
        # the task yield stores its return address at task + 4: tasks can not be
        # recognised by their entry (see menu_open / game_running in lib.S)
        'defines': ['TASK_PC_RESUME'],
        'addr': {
            'GAME_ENTRY': 0x80061888, 'LOOP_NEXT': 0x80032df0, 'F_PAL_ANIM': 0x800158c0, 'F_GRID_DRAW': 0x800560e8,
            'SITE_HOOK': 0x80032038, 'SITE_FRAME': 0x800326f4, 'SITE_GRID': 0x80055e48,
            'F_LOAD_SOUNDS': 0x8005362c, 'F_LOAD_WEAPON': 0x800248f4, 'F_PLAY_SE': 0x800544e0, 'F_SET_ANIM': 0x80030428,
            'F_TASK_START': 0x800374e0, 'F_TASK_EXIT': 0x80037560, 'F_TASK_SUSPEND': 0x8003767c, 'F_TASK_RESUME': 0x800376a0,
            'F_HEAL': 0x80058e4c, 'F_COMPACT': 0x8002d5d4, 'F_OT_LINK': 0x80067e3c,
            'MENU_TASK': 0x800554f0, 'GAME_TASK': 0,     # not used (TASK_PC_RESUME)
            'COND_COLOURS': 0x80095a70, 'SLOT_XY': 0x80096c1c,
            'PKT_PTR': 0x800bae44, 'MENU_OFS': 0x800bc362, 'MENU_WORK': 0x800bc5a8,
            'INV_PTR': 0x800be8f0, 'ICON_CACHE': 0x800be9d0, 'PAD': 0x800cf844,
            'F_LOAD_IMAGE': 0x80065434, 'F_STORE_IMAGE': 0x80065498, 'F_DRAW_SYNC': 0x80065170,
            'F_BG_RELOAD': 0x80017744,
            'OPT_CODE': 0x8008899c, 'OPT_CODE_SIZE': 3196, 'VRAM_SAVE': 0x80014360, 'FONT_RAM': 0x80063930,
        },
    },
}

# same address in every version found so far
COMMON = {
    'GFLAGS': 0x800c3000,      # +0 flags, +4 flags 2, +0x10 frame index
    'PLAYER': 0x800c5124,      # player object (fields: P_* in game.h)
    'DOOR_FLAG': 0x800c845b,   # 1 during doors; +1: y offset 0 / 240
    'MAP_PAD': 0x800c8680,     # mapped pad: +0 held, +2 pressed
    'EQUIPPED': 0x800c8689,    # equipped slot, 1-based
    'INV_MAIN': 0x800c8784,    # main inventory (id, quantity pairs)
    'CTRL_FLAGS': 0x800cab00,  # 0xFFFF in game, bit 0x100 off during cutscenes
    'CUR_OBJ': 0x800cab14,     # current object pointer
    'WEAPON_BUF': 0x800ea800,  # weapon model, 0x7A00 bytes
    'ANIM_BUF': 0x800f2200,    # weapon animations
    'TASKS': 0x801fec24,       # task table, 0x80 per slot
    'SPRITE': 0x1f800380,      # scratchpad sprite parameters (menu)
}


def header(vid):
    """#defines of src/version.h for one version"""
    v = VERSIONS[vid]
    out = ['/* generated by src/build.py from src/versions.py: %s (%s) */' % (v['name'], v['serial'])]
    for k, a in list(v['addr'].items()) + list(COMMON.items()):
        out.append('#define %-16s 0x%08x' % (k, a))
    out.append('#define %-16s %d' % ('GAME_FPS', v['game_fps']))
    for d in v.get('defines', []):
        out.append('#define %s 1' % d)
    return '\n'.join(out) + '\n'
