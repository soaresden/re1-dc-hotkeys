# Changelog

*[Version française](CHANGELOG.fr.md)*

## v1.1.0 — 2026-10-11

### New
- **US versions supported**: Resident Evil – Director's Cut (USA, SLUS-00551) and Director's Cut – Dual Shock Ver. (USA, SLUS-00747), in addition to the French release (SLES-00970). Every feature works the same in the three versions.
- **In-game options menu**: hold **Select for 5 seconds** in game. The game pauses on its last frame and a menu lists the mod options: **Up / Down** to choose, **Cross** (or Left / Right) to switch ON / OFF, **Start** (or Triangle / Select) to go back. Changes apply at once; they are not saved (the patcher's choice comes back at the next boot). The menu is in English in every version.
- **Quick reload**: **R1 + Circle** fills the equipped weapon up to its capacity (Beretta 15, shotgun / Colt / bazooka 6) with the ammo of its type you carry. Emptied stacks are removed and the inventory is compacted, as after a combine.
- **Carried ammo in the HUD**: next to the loaded ammo (green), the ammo of the weapon's type you carry, in blue, all stacks added up (e.g. two stacks of 30 and 15 shells show 45).
- **Patcher**:
  - recognises the version by itself (image size, then the executable's checksum);
  - accepts the Dual Shock version as a single .bin (e.g. extracted from a .chd) or as the Redump *(Track 1)* file (the generated .cue keeps the original audio track);
  - English / French switch;
  - two new options: the in-game menu and quick reload (8 options in all).
- **One xdelta per version** in `patch/` (all options on).

### Fixed
- **Chris (6-slot inventory)**: the quick-slot arrows and the pick highlight were drawn one row too high; they now follow the game's 6-slot grid.

### Changed
- The code no longer contains any game address: each version has its own table (`src/versions.py`), and the build refuses an address that would not fit a version.
- The options menu and the L2 overlay now live in game code that nothing can reach (library functions never called, found by analysis and checked in the emulator), which frees room in the main block.
- Patch files renamed: `<game name> [Hotkeys].xdelta`. The former `… - Raccourcis.xdelta` is gone.
- Developer tools: `tools/re/port.py` (finds the addresses in another version), `tools/re/deadcode.py` (unreachable code), `tools/re/iso.py` (disc files), version option in the test bench.

### Known limits
- Not tested yet on real hardware, nor with Rebecca.
- Weapon capacities used by quick reload are the usual ones of the game; tell us if one is wrong.

## v1.0.0 — 2026-10-11

First public release, French version (SLES-00970) only.

- **L2 + d-pad quick slots**: the four top cells of the inventory are mapped to ↑ ↓ ← →. A weapon is equipped, a healing item (spray, herbs, mixes, serum) is used, as with "Use" in the inventory. Translucent arrows mark these cells in the inventory.
- **L2 overlay**: while L2 is held, the four quick slots at the bottom of the screen (item icons, quantities, equipped weapon tinted).
- **Health display**: top left, a cross and the health in digits, in the colour of the game's condition (green, yellow, orange, red).
- **Equipped weapon and ammo**: under the health, the weapon icon and its loaded ammo (red when empty).
- **Quick turn**: Square + Down, like in RE3.
- **Move items in the inventory**: Square picks an item up, Square on another one swaps them; the equipped weapon follows its item.
- **Browser patcher**: pick the original .bin, tick the options, get a patched .bin + .cue or a .ppf for DuckStation. No game data inside: it reads the executable from your own disc. Also online on GitHub Pages.
- Display hidden in menus, cutscenes and doors.

## Before v1.0.0 (not published)

- **2026-10-10** — Fix: after a weapon change with L2, stripes appeared at the top of the screen until the next room (the weapon sounds were loaded over the copy of the room background). The build chain was made to work on Windows and checked byte for byte against the previous build.
- **2026-09-30** — First version: L2 + d-pad quick slots (equip, heal), Square to move items in the inventory, arrows on the quick slots. Tested in PCSX-Redux.
