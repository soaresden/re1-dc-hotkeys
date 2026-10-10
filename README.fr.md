# Resident Evil Director's Cut — Cases rapides, HUD et demi-tour (PS1)

*[English version](README.md)*

Un mod de gameplay pour **Resident Evil – Director's Cut (PlayStation)** qui ajoute du confort moderne sans toucher à une seule texture :

- **Cases rapides L2 + croix** : équiper une arme ou se soigner sans ouvrir l'inventaire
- **Overlay des cases rapides** : en maintenant L2, les quatre cases en bas de l'écran
- **Vie** en haut à gauche, dans la couleur de l'état du jeu (Bien / Attention / Danger)
- **Arme équipée et munitions** sous la vie
- **Demi-tour** : Carré + Bas, comme dans RE3
- **Déplacer les objets dans l'inventaire** : Carré pour prendre un objet, Carré pour l'échanger avec un autre

Chaque option s'active ou se désactive dans le patcheur.

| En jeu (L2 maintenu) | Inventaire |
|---|---|
| ![Vie et overlay](docs/img/ingame-overlay.png) | ![Objet pris](docs/img/inventory-pick.png) |

![Couleurs de la vie](docs/img/hp-colours.png)

> **Version prise en charge : Resident Evil – Director's Cut (France), SLES-00970** (Redump, SHA1 du BIN `5d9d1ea07595ae468ba4183a73331f0dace2384e`). Les autres versions (US, UK, Japon…) demandent un portage des adresses du jeu : voir [Autres versions](#autres-versions).

## Installer

### Option 1 : le patcheur (conseillé)

Ouvre **[le patcheur en ligne](https://soaresden.github.io/re1-dc-hotkeys/)** (ou télécharge [`patcher/RE1-Hotkeys-Patcher.html`](patcher/RE1-Hotkeys-Patcher.html) et ouvre-le hors ligne), puis :

1. choisis ton `.bin` d'origine ;
2. coche les options voulues ;
3. télécharge le **.bin patché (+ .cue)** ou un **.ppf**.

Tout se passe dans le navigateur, rien n'est envoyé. Le patcheur ne contient aucune donnée du jeu : il lit l'exécutable sur ton image et reconstruit les secteurs (EDC/ECC compris).

**DuckStation avec un .ppf :** active *Réglages → Console → Apply Image Patches* et place le `.ppf` à côté de l'image d'origine, avec le même nom (`Mon jeu.bin` → `Mon jeu.ppf`). Ça marche aussi avec un `.chd` du même jeu.

**Seulement un .chd ?** Extrais d'abord le `.bin` : `chdman extractcd -i jeu.chd -o jeu.cue -ob jeu.bin`.

### Option 2 : xdelta (toutes les options)

Applique [`patch/…- Raccourcis.xdelta`](patch/) sur le `.bin` d'origine avec xdelta3, Delta Patcher ou un autre outil xdelta.

## Commandes

| Où | Touche | Effet |
|---|---|---|
| En jeu | **L2 + ↑ / ↓ / ← / →** | utilise la case 1 / 2 / 3 / 4 : une arme est équipée, un soin (spray, plantes, mélanges, sérum) est utilisé |
| En jeu | **L2** maintenu | overlay des cases ; la croix ne fait plus marcher |
| En jeu | **Carré + Bas** | demi-tour |
| Inventaire | **Carré** sur un objet, puis **Carré** sur un autre | les échange (l'arme équipée suit son objet) ; Carré sur le même objet ou la fermeture du menu annule |

Les cases rapides sont les quatre cases du haut de l'inventaire (le carré 2×2) ; le mod dessine une flèche translucide sur chacune.

## Limites

- Pas d'action rapide en visée, pendant une animation (escalier, ramassage, porte), une cinématique, ni quand le perso est au sol.
- Carré n'échange que deux cases occupées : le jeu exige un inventaire sans trou.
- L'affichage est masqué dans les menus, les cinématiques et les portes.
- Testé avec Jill, sur émulateur avec un BIOS Sony et dans PCSX-Redux (OpenBIOS et SCPH-5502). Pas encore testé sur console, ni avec Chris (6 cases) et Rebecca : les retours sont les bienvenus.

## Fonctionnement

- Un bloc de code de 6 Ko est chargé en `0x8000E800`, dans la mémoire noyau que le BIOS réserve sans l'utiliser (le tas du noyau Sony s'arrête à `0xE600` avec les réglages de ce jeu). L'en-tête de l'exécutable charge l'image à cette adresse sans changer la taille du fichier ; les 6 derniers Ko de l'image d'origine sont reconstruits au démarrage à partir de segments stockés dans le bloc.
- Trois appels du jeu sont redirigés : la boucle principale après la lecture de la manette (commandes), le dessin de la grille d'inventaire (flèches, surbrillance), et la boucle principale une fois la table d'affichage de l'image terminée (HUD, overlay).
- Le HUD et l'overlay sont des primitives GPU construites par le mod, avec des textures que le jeu garde en VRAM pendant la partie (chiffres de l'inventaire, cache d'icônes d'objets).
- Le changement d'arme tourne dans une tâche du jeu, comme l'inventaire. Les sons de l'arme passent par le tampon du modèle d'arme au lieu du tampon qu'utilise l'inventaire : en jeu, celui-ci contient la copie du décor de la salle, et y charger quoi que ce soit laisse des stries en haut de l'écran.
- Chaque option est un octet de la table `config` au début du bloc, écrit par le patcheur.

Organisation des sources (`src/`) :

| Fichier | Contenu |
|---|---|
| `hotkey.S` | démarrage, `config`, les trois accroches |
| `lib.S` | tests d'état du jeu, primitives GPU, nombres |
| `feat_menu_move.S`, `feat_quickslots.S`, `feat_overlay.S`, `feat_hud.S`, `feat_quickturn.S` | un fichier par option, à réutiliser librement |
| `game.h` | adresses et constantes du jeu (version FR) |
| `build.py` | toute la construction |
| `patcher/core.js`, `patcher/patcher.html` | le patcheur (navigateur et Node) |

[`CLAUDE.md`](CLAUDE.md) contient les notes de recherche détaillées (adresses, pièges, banc de test).

## Construire

Prérequis : Python 3, Node, une toolchain GNU MIPS, chdman et xdelta3. Sous Windows, dans `tools/` :

- `tools/mips/` : `gcc-mipsel-none-elf-12.3.0-windows.zip` des [releases PSn00bSDK](https://github.com/Lameguy64/PSn00bSDK/releases) (sous Linux, `binutils-mips-linux-gnu` + `cpp` conviennent) ;
- `tools/chdman/chdman.exe` : de MAME ;
- `tools/xdelta/xdelta3-*.exe` : [xdelta3 3.0.11](https://github.com/jmacd/xdelta-gpl/releases).

Place le CHD d'origine `Resident Evil - Director's Cut (France) [SLES_009.70].chd` à la racine, puis :

```
python src/build.py              # bloc, BIN/CUE patchés, patcheur, .ppf, .xdelta, CHD patché
python src/build.py --asm        # seulement le bloc de code
python src/build.py --no-chd     # sans le CHD
node tools/test_patcher.js       # le patcheur JS doit produire les mêmes octets que Python
```

Le banc de test (`tools/emu-tests/`) pilote PCSX-Redux avec des scénarios Lua (`run.py <scénario>`) ; il faut un save state fait soi-même (`launch.py`, puis `cmd.py "save dining_jill"`).

## Autres versions

Toutes les adresses du jeu (fonctions et variables) sont propres à l'exécutable français. Porter le mod sur une autre version, c'est retrouver ces fonctions et variables dans l'autre exécutable (recherche de signatures dans le désassemblage), puis mettre à jour `src/game.h`, les sites d'accroche de `src/build_patch.py` et les constantes du disque (LBA, taille et somme de contrôle de l'exécutable). Les contributions sont les bienvenues.

## Crédits

Mod de **soaresden**, avec Claude (Anthropic). Resident Evil est une marque de Capcom ; ce projet n'est pas affilié à Capcom et ne contient aucune donnée du jeu.

Licence : [MIT](LICENSE).
