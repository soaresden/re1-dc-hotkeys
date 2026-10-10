# Resident Evil Director's Cut — Quick slots, HUD & quick turn (PS1)

*[Version française](README.fr.md)*

A gameplay mod for **Resident Evil – Director's Cut (PlayStation)** that adds modern conveniences without touching a single texture:

- **L2 + d-pad quick slots** — equip a weapon or heal without opening the inventory
- **Quick-slot overlay** — hold L2 to see your four quick slots at the bottom of the screen
- **Health display** — top left, in the colour of the game's own condition (Fine / Caution / Danger)
- **Equipped weapon & ammo** — under the health
- **Quick turn** — Square + Down, like in RE3
- **Move items in the inventory** — Square to pick an item up, Square again to swap it with another one

Every feature can be switched on or off in the patcher.

| In game (L2 held) | Inventory |
|---|---|
| ![HUD and overlay](docs/img/ingame-overlay.png) | ![Picking an item](docs/img/inventory-pick.png) |

![Health colours](docs/img/hp-colours.png)

> **Supported version: Resident Evil – Director's Cut (France), SLES-00970** (Redump, BIN SHA1 `5d9d1ea07595ae468ba4183a73331f0dace2384e`). Other versions (US, UK, Japan…) need a port of the game addresses — see [Other versions](#other-versions).

## Install

### Option 1 — the patcher (recommended)

Open **[the online patcher](https://soaresden.github.io/re1-dc-hotkeys/)** (or download [`patcher/RE1-Hotkeys-Patcher.html`](patcher/RE1-Hotkeys-Patcher.html) and open it offline), then:

1. pick your original `.bin`;
2. tick the features you want;
3. download either the **patched .bin (+ .cue)**, or a **.ppf**.

Everything runs in your browser; nothing is uploaded. The patcher contains no game data: it reads the executable from your own disc image and rebuilds the sectors (EDC/ECC included).

**DuckStation with a .ppf:** enable *Settings → Console → Apply Image Patches* and put the `.ppf` next to the original image, with the same file name (`My Game.bin` → `My Game.ppf`). It also works with a `.chd` of the same game.

**Only have a .chd?** Extract the `.bin` first: `chdman extractcd -i game.chd -o game.cue -ob game.bin`.

### Option 2 — xdelta (all features on)

Apply [`patch/…- Raccourcis.xdelta`](patch/) to the original `.bin` with xdelta3, Delta Patcher or any xdelta tool.

## Controls

| Where | Input | Effect |
|---|---|---|
| In game | **L2 + ↑ / ↓ / ← / →** | use quick slot 1 / 2 / 3 / 4: a weapon is equipped, a healing item (spray, herbs, mixes, serum) is used |
| In game | hold **L2** | quick-slot overlay; the d-pad no longer moves the character |
| In game | **Square + Down** | 180° quick turn |
| Inventory | **Square** on an item, then **Square** on another | swap them (the equipped weapon follows its item); Square on the same item or closing the menu cancels |

The quick slots are the four top cells of the inventory (the 2×2 square); the mod draws a translucent arrow on each of them.

## Limitations

- No quick action while aiming, during animations (stairs, picking up, doors), cutscenes, or when the character is down.
- Square only swaps two occupied cells: the game requires an inventory without holes.
- The on-screen display is hidden in menus, cutscenes and doors.
- Tested with Jill, on emulator with a Sony BIOS and in PCSX-Redux (OpenBIOS and SCPH-5502). Not tested on real hardware, nor with Chris (6 slots) and Rebecca yet: reports welcome.

## How it works

- A 6 KB code block is loaded at `0x8000E800`, in kernel memory the BIOS reserves but does not use (the Sony kernel heap ends at `0xE600` with this game's settings). The executable header loads the image there without changing the file size; the last 6 KB of the original image are rebuilt at boot from compressed segments stored in the block.
- Three calls of the game are redirected: the main loop after the pad read (input), the inventory grid draw (arrows, highlight), and the main loop once the frame's ordering table is complete (HUD, overlay).
- The HUD and overlay are GPU primitives built by the mod, using textures the game keeps in VRAM during play (the inventory digits and the item icon cache).
- A weapon swap runs as a game task, like the inventory does. The weapon sounds are loaded through the weapon model buffer instead of the buffer the game uses in the inventory: in game that buffer holds the copy of the room background, and loading there leaves stripes at the top of the screen.
- Each feature is one byte of the `config` table at the start of the block, written by the patcher.

Source layout (`src/`):

| File | Content |
|---|---|
| `hotkey.S` | boot, `config`, the three hooks |
| `lib.S` | game state tests, GPU primitives, numbers |
| `feat_menu_move.S`, `feat_quickslots.S`, `feat_overlay.S`, `feat_hud.S`, `feat_quickturn.S` | one file per feature — reuse them freely |
| `game.h` | game addresses and constants (FR version) |
| `build.py` | the whole build |
| `patcher/core.js`, `patcher/patcher.html` | the patcher (browser and Node) |

[`CLAUDE.md`](CLAUDE.md) holds the detailed research notes (addresses, pitfalls, test bench), in French.

## Build

Requirements: Python 3, Node, a MIPS GNU toolchain, chdman and xdelta3. On Windows, put them in `tools/`:

- `tools/mips/` — `gcc-mipsel-none-elf-12.3.0-windows.zip` from the [PSn00bSDK releases](https://github.com/Lameguy64/PSn00bSDK/releases) (on Linux, `binutils-mips-linux-gnu` + `cpp` work too);
- `tools/chdman/chdman.exe` — from MAME;
- `tools/xdelta/xdelta3-*.exe` — [xdelta3 3.0.11](https://github.com/jmacd/xdelta-gpl/releases).

Put the original `Resident Evil - Director's Cut (France) [SLES_009.70].chd` at the root, then:

```
python src/build.py              # block, patched BIN/CUE, patcher, .ppf, .xdelta, patched CHD
python src/build.py --asm        # code block only
python src/build.py --no-chd     # skip the CHD
node tools/test_patcher.js       # the JS patcher must produce the same bytes as the Python build
```

The test bench (`tools/emu-tests/`) drives PCSX-Redux with Lua scenarios (`run.py <scenario>`); it needs a save state you make yourself (`launch.py`, then `cmd.py "save dining_jill"`).

## Other versions

All game addresses (functions and variables) are specific to the French executable. A port to another version means finding the same functions and variables in that executable (signature search on the disassembly), then updating `src/game.h`, the hook sites in `src/build_patch.py` and the disc constants (executable LBA, size, checksum). Contributions welcome.

## Credits

Mod by **soaresden**, with Claude (Anthropic). Resident Evil is a trademark of Capcom; this project is not affiliated with Capcom and contains no game data.

License: [MIT](LICENSE).
