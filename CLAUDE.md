# RE1 Hotkey — mod Resident Evil Director's Cut (PS1, version FR)

Projet de Denis (« Soaresden »). Réponds en français.

## Objectif

Patch de **Resident Evil – Director's Cut**, trois versions : **FR SLES-00970** (version de référence de la recherche), **US SLUS-00551**, **US Dual Shock SLUS-00747** (`src/versions.py`). Chaque fonction peut être désactivée (octet de `config`, voir plus bas) :

| n° | Fonction | Fichier | Effet |
|---|---|---|---|
| 0 | menu_move | `feat_menu_move.S` | Inventaire : Carré prend un objet, Carré sur un autre les échange. L'arme équipée suit son objet. |
| 1 | quickslots | `feat_quickslots.S` | En jeu, L2 + direction utilise la case 1 (↑), 2 (↓), 3 (←), 4 (→) : arme = équiper, spray / plantes / mélanges / sérum (0x41–0x4B) = soigner. Flèches translucides sur ces cases dans l'inventaire. |
| 2 | overlay | `feat_overlay.S` | L2 maintenu : bandeau en bas avec les 4 cases (ordre ← ↑ ↓ →), icônes, quantités, arme équipée teintée. |
| 3 | hud_hp | `feat_hud.S` | En haut à gauche : croix + vie en chiffres, couleur de l'état du jeu (vert / jaune / orange / rouge). |
| 4 | hud_ammo | `feat_hud.S` | Sous la vie : icône de l'arme équipée (demi-taille) et munitions (rouge à 0, rien pour le couteau). |
| 5 | quickturn | `feat_quickturn.S` | Carré + Bas : demi-tour en 8 images de jeu (comme RE3). |
| 6 | options | `feat_options.S` | Select maintenu ~3 s : menu en jeu (pause, image figée) pour basculer les autres options. |
| 7 | reload | `feat_reload.S` | R1 + Rond : remplit l'arme équipée (capacités `reload_cap` : Beretta 15, fusil / Colt / bazooka 6, à confirmer en jeu) avec les munitions `ammo_of` portées ; pile vide retirée + F_COMPACT. |

Distribution : xdelta par version (toutes les options) et **patcheur HTML** (`patcher/RE1-Hotkeys-Patcher.html` + GitHub Pages `docs/index.html`, FR/EN, détecte la version par la taille du .bin puis le CRC de l'exe). Le patch ne touche que l'exécutable. Dépôt public : https://github.com/soaresden/re1-dc-hotkeys (pas de données du jeu : ni CHD, ni .ppf, ni save states).

## État actuel

Testé dans PCSX-Redux (OpenBIOS) avec Jill, sur les **trois versions** (scénarios `feat`, `quick`, `fire2`, `stripes`, `hp`) : tout ce qui précède, plus l'absence de stries après un échange d'arme. Démarrage vérifié avec le BIOS Sony **SCPH-5502** (PAL) : le noyau occupe 0xE000–0xE5FF, le bloc commence en 0xE800. Version FR validée par Denis sur émulateur.

**Pas encore testé :** versions US sur DuckStation / Beetle, Chris (6 cases), Rebecca (inventaire 0x800C8790 : les raccourcis sont refusés), l'affichage pendant une vraie animation de porte (masqué par 0x800C845B, non vérifié), le PPF sur CHD dans DuckStation.

## Contenu du dossier

- CHD d'origine à la racine (noms dans `versions.py`, champ `chd`) : jamais modifiés, ignorés par git. Ils peuvent être retirés : `build/<version>/orig.bin` suffit.
- `patch/` : un `.xdelta` par version (toutes options). Les `.ppf` (contiennent l'exe décalé) restent dans `build/<version>/hotkeys.ppf`, non publiés.
- `patcher/RE1-Hotkeys-Patcher.html` et `docs/index.html` : patcheur généré (ne pas éditer à la main).
- `src/` :
  - `hotkey.S` (démarrage, `config`, les 3 accroches) + `lib.S` + un `feat_*.S` par fonction ; `game.h` : noms, champs, constantes ; **aucune adresse en dur** : tout vient de `build/<version>/version.h` ;
  - `versions.py` : adresses par version + constantes du disque (LBA/secteurs de l'exe, tailles et SHA1 des .bin, pistes du .cue) ;
  - `build.py`, `build_patch.py`, `make_tail.py`, `cdsector.py`, `fix_delay.py`, `make_ppf.py`, `apply_ppf.py`, `link.ld` ;
  - `patcher/core.js` (cœur, navigateur + Node) et `patcher/patcher.html` (modèle, FR/EN) ;
  - `LISEZMOI.md`.
- `tools/` : `mips/`, `chdman/`, `xdelta/`, `redux/` (non suivis par git), `emu-tests/`, `re/xref.py`, `re/iso.py` (SYSTEM.CNF, LBA de l'exe, extraction), `re/port.py` (portage d'adresses), `test_patcher.js`, `test_patcher_ui.js`.
- `build/<version>/` (fr, us, usds) : orig.bin/.cue, exe, version.h, tail.bin, hotkey.*, exe.patched, patched.bin/.cue/.ppf, exe.dis (US). `build/exe.dis` = désassemblage FR.
- `annonces.md` : brouillons Reddit / romhacking.net (ignoré par git).

## Chaîne de construction

**`python src/build.py`** : pour chaque version dont l'image est trouvée (CHD à la racine ou `build/<v>/orig.bin`) :

1. extrait `orig.bin` du CHD si besoin, vérifie son SHA1, extrait l'exe du BIN ;
2. génère `version.h` (adresses + `TAIL_START`, `BLOCK_SIZE`), `make_tail.py`, cpp (`-I build/<v>`), `fix_delay.py`, as, ld, objcopy → `hotkey.bin`, vérification objdump (load delays, branchements dans un délai) ; refus si le bloc dépasse 0x1800 ;
3. `build_patch.py` : vérifie qu'à chaque site l'instruction d'origine est le `jal` attendu, puis `patched.bin` + `.cue` ;
4. `patch/<nom> [Hotkeys].xdelta` (xdelta3 lancé depuis `build/<v>/`, noms relatifs) et `hotkeys.ppf` local ;
5. `--chd` : CHD patchés à la racine ;
6. le patcheur, avec toutes les versions construites.

Options : `--ver fr,us,usds`, `--asm`, `--chd`, `--no-patches`. Puis **`node tools/test_patcher.js`** (secteurs et PPF identiques pour chaque version) et `node tools/test_patcher_ui.js <v>`.

Outils (dans `tools/`, sinon PATH) : GCC/binutils `mipsel-none-elf` 12.3.0 (PSn00bSDK v0.24 ; `mips-linux-gnu-*` convient aussi), chdman (MAME 0.257), xdelta3 3.0.11, Node, `capstone` (pip).

## Portage vers une autre version

1. `python tools/re/iso.py <image.bin>` : SYSTEM.CNF, LBA et taille de l'exe ; `python tools/re/iso.py <image.bin> <EXE> <sortie>` pour l'extraire.
2. `python tools/re/port.py build/fr/exe <autre exe> <adresses...>` : apparie les fonctions par signature (adresses masquées), aligne les paires pour voter les adresses de données ; « code, N before / M after » = longueur de la correspondance autour de l'adresse. **Les adresses vraiment utilisées** se relèvent sur le bloc assemblé (paires lui + décalage), pas dans les commentaires.
3. Vérifier à la main : sites d'accroche (le `jal` d'origine et sa cible), corps des fonctions comparés côte à côte, tables (COND_COLOURS, SLOT_XY) retrouvées par leur contenu, arguments de F_LOAD_WEAPON. Pièges vus : correspondance courte = souvent fausse (grille US, tâche de jeu Dual Shock).
4. Ajouter l'entrée dans `versions.py`, construire (`SAMEHI` refuse un registre de base partagé devenu faux), créer un save state (`launch.py <v>` puis `cmd.py`), lancer les scénarios `run.py ... --ver <v>`.

Écarts connus : US d'origine = compilation plus ancienne (correspondances courtes), Dual Shock très proche de la FR. Zone 0x800C3000–0x800CAB14 et objet joueur identiques partout ; 0x800B…, la manette (0x800CF844 en US) et le code décalés.

**Dual Shock (`TASK_PC_RESUME`)** : la mise en attente d'une tâche y écrit son adresse de retour en tâche + 4. On ne peut donc pas reconnaître la tâche de jeu ni l'inventaire par leur entrée : `game_running` saute ce test, et `menu_open` regarde `st.menu`, mis à 2 par `draw_hook` quand la grille est dessinée et décrémenté à chaque image.

## Architecture du patch

**Placement en mémoire**

- **Bloc :** 0x8000E800–0x8000FFFF (6 Ko) dans le tas du noyau BIOS (Sony : 0xE000–0xE5FF utilisés avec TCB=4/EVENT=16, mesuré sous SCPH-5502 ; OpenBIOS : rien ; les trois versions ont TCB=4/EVENT=16). Code ≈ 4,5 Ko + `taildata` 1,3–1,4 Ko : il reste ~90 octets en Dual Shock (6052/6144), ~140 en FR/US.
- **En-tête de SLES_009.70 :** t_addr et pc0 = 0x8000E800, t_size inchangé (0x9F800), taille du fichier inchangée.
- **Restauration au démarrage :** les 6 derniers Ko de l'image d'origine (`TAIL_START`, FR 0x800AE000) sont abandonnés ; `boot` les remet à zéro, recopie les segments non nuls de `taildata` (`make_tail.py`, DROP = 0x1800, trous de moins de 8 zéros gardés dans le segment ; même logique dans `core.js`), initialise `st` et saute à `GAME_ENTRY`.
- **`config`** à `_start + 8` (8 octets, 1 = actif) : le patcheur l'écrit directement. **`st`** : état (pick, pend, turn, lock, ybias, menu).

**Trois appels redirigés** (`build_patch.hooks(v)` ; adresses FR ci-dessous)

- `0x80032084` `jal 0x80032EDC` → `hook` : chaque image, après la lecture de la manette. Menu ouvert → `menu_move_input` ; sinon `quickslot_input`, `quickturn_input`. Termine par `j LOOP_NEXT`.
- `0x80054C9C` `jal 0x80054F3C` → `draw_hook` : grille d'inventaire, puis flèches (`menu_arrows`) et surbrillance (`menu_pick_draw`) dans l'OT d'inventaire (0x800C88A0 + image × 20).
- `0x80032740` `jal 0x80015C0C` (animation des palettes, un seul appelant) → `frame_hook` : appelle l'original puis, si la tâche de jeu tourne, hors cinématique (0x800CAB00 & 0x100) et hors porte (0x800C845B), dessine `hud_draw` et, si L2, `overlay_draw` dans **l'OT de la scène** (0x800C88C8 + image × 20).

**Dessin en jeu**

- La boucle principale bascule l'indice d'image 0x800C3010, puis vide trois paires d'OT (descripteurs de 20 octets) : 0x800C88C8 (scène, 1024 entrées), 0x800C88F0, 0x800C88A0. Pointeur de paquets : 0x800B7978. Liaison : 0x80066DAC(prim, desc, z, mots).
- **Les deux tampons ont le même offset de dessin : le jeu ajoute lui-même 0x800C845C (0 ou 240) à ses y.** `frame_hook` le recopie dans `st.ybias`, que `put_poly` / `put_tile` / `put_ft4` ajoutent (sinon l'affichage n'apparaît qu'une image sur deux).
- Textures résidentes en jeu (8 bpp) : chiffres de l'inventaire en tpage 28 (768,256), 8×8, u = 0x80 vert / 0x88 orange / 0x90 bleu / 0xC0 rouge, v = chiffre × 8, CLUT (0,484) ; icônes d'objets 40×30 en tpage 29 (832,256), u = 88, v = case de cache × 32, CLUT (0,486). Le cache d'icônes 0x800BB1E8[case] est tenu à jour par le jeu (0x8002D870 recharge tout, le ramassage met à jour la case).
- `put_ft4` (POLY_FT4 + descripteurs `tex_*`), `put_poly` (F3/F4 depuis des sommets en octets signés), `put_tile`, `put_mode` (E1 : additif 0xE1000620 / soustractif 0xE1000640, lié en dernier = dessiné en premier dans son z), `draw_number` (0..999, sans zéros de tête).
- z (petit = devant) : HUD 1, overlay 3 (bandeau) / 2 (contenu) / 1 (teinte), inventaire 3 (icônes à 4).

**Échange d'arme (`swap_task`, tâche slot 1, tâche de jeu suspendue)** : refait F_SYNC_EQUIP (0x80054E74) mais charge les sons (0x80052404(id, tampon)) dans le tampon du modèle 0x800EA800 au lieu de 0x801D10EC, puis retour en idle (0x80030474) et modèle (0x800249C0), reprise de la tâche 0 (0x80037734), fin (0x800375F4).

**Soin :** 0x80057CA0 (lit l'id en 0x800B90EB ; sauvegarder/restaurer 0x800B90E0..EB et 0x800B90FC), décrément, tassement 0x8002D678 si épuisé.

**Demi-tour :** angle du joueur = demi-mot 0x800C5198 (0..0xFFF), +0x100 par image de jeu pendant 8 images ; directions et course masquées dans la manette mappée pendant le tour, puis Bas masqué jusqu'à son relâchement.

**État de santé :** niveau = (PV − 1) / (PVmax / 4), max 3 ; PVmax = octet 0x800C5299 (96 pour Jill) ; couleurs RGB en 0x80091CCC.

**Pièges déjà rencontrés**

- **Load delay R3000** : `fix_delay.py` ajoute un nop après un load seulement si l'instruction suivante nomme le registre (ou n'est pas une instruction) ; un load dans un délai de branchement est refusé. La vérification objdump de `build.py` contrôle le résultat.
- **Macros cpp** : une macro produit plusieurs instructions sur une ligne séparées par `;` ; `fix_delay.py` les sépare.
- **Chargement CD** : jamais depuis l'ordonnanceur, toujours depuis une tâche.
- **0x801D10EC n'est pas libre** : copie du décor de la salle (StoreImage en 0x80017CA4), recopiée dans le framebuffer à chaque image (0x8005067C). Y charger quoi que ce soit en jeu laisse des stries jusqu'au changement de salle.
- **Drapeau 0x800C845B** : 1 aussi pendant les portes. Pour l'inventaire, regarder la tâche slot 1.
- **Inventaire sans trou** : Carré n'échange que deux cases occupées.
- **Place** : le bloc est presque plein. La RAM basse « libre » sous OpenBIOS ne l'est pas avec un BIOS Sony ; les zones à zéro du jeu sont probablement des variables utilisées ailleurs ; la recherche de code mort n'a rien donné de fiable.

## Adresses utiles (version FR ; les autres : `src/versions.py`)

| Adresse | Rôle |
|---|---|
| 0x800C8784 | inventaire principal (paires id/quantité) |
| 0x800BB108 | pointeur d'inventaire actif (0x800C8790 = Rebecca) |
| 0x800BB1E8[ ] | case du cache d'icônes par case d'objet |
| 0x800C8689 | case équipée, 1-based |
| 0x800C5126 | id de l'arme équipée |
| 0x800C5125 & 3 | personnage (1 = Jill, 8 cases ; sinon 6) |
| 0x800C5124 | objet joueur ; +0x74 (0x800C5198) angle |
| 0x800C51A8 / A9 / AA | état / routine / sous-état (0 = normal ; sous-état < 9 = idle/marche/tourne) |
| 0x800C51AC / 0x800C5299 | PV / PV max |
| 0x800CAB14 | pointeur d'objet courant (mettre 0x800C5124 avant les appels joueur) |
| 0x800CAB00 | 0xFFFF en jeu, bit 0x100 à 0 en cinématique |
| 0x800CFC04 / 0x800CFC08 | manette brute maintenue / nouvellement pressée |
| 0x800C8680 / 0x800C8682 | manette mappée du jeu |
| 0x800B90F3 / F0 / EB | curseur d'inventaire (case + 4) × 2 / état du menu / objet sous le curseur |
| 0x801FEC24 + slot × 0x80 | tâches : +0 statut (0x40 = suspendue), +4 entrée ; jeu = 0x8002A050, inventaire = 0x800546D8 |
| 0x800C3010 / 0x800C845C | indice d'image / décalage y (0 ou 240) |
| 0x800B8E92 / +6 | décalage d'écran du menu x / y (et non 0x800C8E92 comme noté avant) |

Manette brute : L2 0x0001, R2 0x0002, L1 0x0004, R1 0x0008, Triangle 0x0010, Rond 0x0020, Croix 0x0040, Carré 0x0080, ↑ 0x1000, → 0x2000, ↓ 0x4000, ← 0x8000.
Manette mappée : Carré (course) 0x0200, ↓ 0x0024, ↑ 0x0011, ← 0x0008, → 0x0002, Croix 0x40C0, R1 (viser) 0x0500, Triangle 0x8000, L1 0x0800, R2 0x1000.

## Banc de test (tools/emu-tests)

- **Émulateur :** PCSX-Redux Windows CLI (nightly 27178) dans `tools/redux/`. L'ancien `hk_dining.sstate.gz` (build Linux) le fait planter : utiliser `dining_jill.sstate.gz` (Jill, salle à manger, couteau / Beretta 15 / spray ; décompressé dans `build/` par `run.py`), créé avec `launch.py` + `cmd.py "save ..."`. BIOS Sony : `-bios <scph5502.bin>` (dans `D:\DOCS\Documents\a-Emulation\Batocera\PACK FULL BIOS ...\bios\`).
- **`run.py <scénario> [dernière image]`** : injecte `build/hotkey.bin` et les 3 `jal` dans le save state, sortie dans `build/emu/<scénario>/` (log, PNG, `.vram` + PNG, `.ram`). Le dossier de sortie est vidé, pas supprimé (Windows refuse si c'est le dossier courant d'un shell).
- **`launch.py`** (en arrière-plan) + **`cmd.py "press START 6\nshot x\nsave y\nvram z\nstatus"`** : pilotage interactif.
- **API du harness :** `press`, `shot`, `vram`, `dump`, `save`, `load`, `r8/r16/r32/w8/w32`, `L`.
- **Scénarios :** `feat` (vie, overlay, demi-tour), `hp` (couleurs), `quick` (soin, Carré dans l'inventaire), `fire2` (équiper, tirer), `stripes` (VRAM avant/après échange), `cdlog`, `otlog`, `wbp`, `dbg`/`dbg2`, `padmap`, `turn`, `menuvram`.
- **Points d'arrêt Lua :** `-interpreter` + `PCSX.settings.emulator.Debug.Debug = true`, listener gardé dans une globale. Une fermeture Lua capture `n` à l'enregistrement : utiliser la globale `FR`.

## Pistes / idées pour la suite

- **Menu d'options en jeu** (demandé) : activer / désactiver nos options en jeu dans un overlay, sur l'image figée du jeu. Il faut une police (aucune police de lettres n'est en VRAM en jeu : seulement les chiffres et les icônes de l'inventaire) et de la place (bloc plein). `config` est déjà lue à chaque image, donc la bascule elle-même est simple.
- **Mini-carte** en haut à droite (demandée) : gros chantier. La carte du jeu est chargée depuis le CD à l'ouverture de l'écran PLAN ; il faudrait trouver son format, la garder en RAM (place ?) et dessiner la salle courante. Le bloc n'a plus de place : il faudra d'abord trouver de la mémoire libre fiable ou compacter le code.
- Tester DuckStation / Beetle, Chris, Rebecca, portes.
- Gagner de la place : utiliser les délais de `jal`, regrouper les `lui 0x800c/0x800d`.
- Initialiser un dépôt git (ignorer `build/`, `tools/mips`, `tools/redux`, les CHD, le zip de textures).

## Menu d'options en jeu (feat_options.S, option 6)

Select maintenu `OPT_HOLD` (75) images de jeu : `opt_open` suspend la tâche de jeu, StoreImage du tampon de `Y_OFFSET` (dernière image dessinée) vers 0x801D10EC (copie du décor, redessinée par la boucle à chaque image : l'image figée reste), sauvegarde la VRAM sous la police (rect (896,496,42,16) + CLUT (944,496)) dans `VRAM_SAVE`, décompresse la police 1 bpp (`src/font.py`, 42 glyphes, sans J ni Z) en 4 bpp dans `FONT_RAM` et la charge. Haut/Bas, Croix/Gauche/Droite (bascule `config[0..5]`), Start/Triangle/Select (sortie). `opt_close` remet la VRAM, lance une tâche (slot 1) qui appelle `F_BG_RELOAD` (rechargement du décor depuis le CD, comme à la sortie de l'inventaire) puis reprend la tâche de jeu ; `ST_OPTLOCK` cache la manette au jeu jusqu'au relâchement. Dessin : panneau F4 noir à 50 % (E1 abr 0), texte en SPRT_8 (0x74, couleur = teinte), page de texture `MODE_FONT`. Libellés anglais dans toutes les versions (`build.py` MENU_TEXT → `build/<v>/strings.inc`, police → `font.inc`).

**Deuxième zone de code `.text2`** à `OPT_CODE` (code mort de 3196 o, `link.ld` généré par version) : overlay + menu (~2,6 Ko). `build_patch.py` l'écrit en place dans l'image, le patcheur aussi (`code2`, `code2Addr`). Plages mortes trouvées par `tools/re/deadcode.py` (atteignabilité depuis toutes les références possibles) : FR 0x8008749C (3196, code), 0x800142F8 (1736, `VRAM_SAVE`), 0x800628A0 (1716, `FONT_RAM`), 0x8005CB3C (1468, libre) ; mêmes tailles en US/DS (`versions.py`). Vérifiées dans PCSX-Redux : démarrage à froid FR avec surveillance exécution/lecture/écriture (seul le BIOS y écrit, au chargement de l'exe), scénarios FR/US/DS (`DEAD_RANGES=...`).

**Grille de 6 cases (Chris)** : le jeu dessine la grille 2 cases plus bas dans SLOT_XY quand le bit 1 de `MW_LAYOUT` (MENU_WORK + 9, 0x800B90E9) est à 0 (Jill : 03, Chris : 00) ; `cell_origin` fait pareil. Le curseur (`MW_CURSOR`) reste (case + 4) × 2 pour les deux. Save state `build/dining_chris.sstate` (couteau, spray).

**PPF local renommé `hotkeys.ppf`** : PCSX-Redux (et DuckStation) appliquent tout seuls un `.ppf` de même nom que l'image ; `patched.ppf` à côté de `patched.bin` réappliquait un ancien patch aux démarrages à froid.

**HUD munitions** : à côté des balles chargées (vert), réserve en bleu = somme des quantités des objets `ammo_of[arme]` de l'inventaire (table dans feat_hud.S : Beretta 0x0B, fusil 0x0C, Colt Python 0x04 → 0x0E, 0x05 → 0x0D, bazookas 0x07/08/09 → 0x10/11/12 ; liste d'objets donnée par Denis).

Testé (PCSX-Redux) sur les 3 versions : ouverture, bascule, reprise, effet immédiat ; démarrage avec BIOS Sony SCPH-5502 (FR) et SCPH-1001 (US) : tas du noyau < 0xE600.
