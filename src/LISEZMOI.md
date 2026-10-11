# RE1 Director's Cut : raccourcis, HUD et demi-tour

Versions prises en charge : France (SLES-00970), USA (SLUS-00551), USA Dual Shock (SLUS-00747). Le patcheur reconnaît la version tout seul.

## Installer

**Le plus simple : le patcheur** `patcher/RE1-Hotkeys-Patcher.html`. Ouvre-le dans un navigateur, choisis le `.bin` d'origine, coche les options voulues, puis télécharge :

- le **.bin patché** (+ son .cue) ;
- ou un **.ppf** pour DuckStation : active « Apply Image Patches » dans les réglages Console et place le `.ppf` à côté de l'image d'origine (`.bin` ou `.chd`), avec le même nom de fichier.

Tout se passe dans le navigateur, rien n'est envoyé. Le patcheur ne contient aucune donnée du jeu : il lit l'exécutable sur ton image. Jeu uniquement en `.chd` : `chdman extractcd -i jeu.chd -o jeu.cue -ob jeu.bin`.

**Patchs tout faits** (toutes les options), dans `patch/` : un `.xdelta` par version (xdelta3, Delta Patcher…), à appliquer sur le BIN d'origine (SHA1 dans le README).

## Les options

**Déplacer les objets (inventaire)**

- **Carré** sur un objet le « prend » : la case est teintée en orange.
- **Carré** sur un autre objet échange les deux. L'arme équipée suit son objet.
- **Carré** à nouveau sur le même objet, ou la fermeture du menu, annule.

**Cases rapides : L2 + croix**

Les quatre premières cases (le carré 2×2 en haut de l'inventaire) portent une flèche translucide :

| Case | Position | Raccourci |
|---|---|---|
| 1 | en haut à gauche | ↑ |
| 2 | en haut à droite | ↓ |
| 3 | en bas à gauche | ← |
| 4 | en bas à droite | → |

En jeu, maintiens **L2** et appuie sur une direction :

- **arme :** elle est équipée (petite pause de chargement, comme par le menu) ;
- **spray, plantes, mélanges, sérum :** même effet que « Utiliser ». L'objet n'est consommé que si le soin a servi ;
- **autres objets :** rien.

Pendant que L2 est maintenu, la croix ne fait plus bouger le perso.

**Overlay des cases rapides** : tant que L2 est maintenu, un bandeau en bas de l'écran montre les quatre cases dans l'ordre de la croix (← ↑ ↓ →), avec l'icône de l'objet, sa quantité et l'arme équipée teintée.

**Vie** : en haut à gauche, une croix et la santé en chiffres, dans la couleur de l'état affiché par l'inventaire (vert « Bien », jaune et orange « Attention », rouge « Danger »).

**Arme et munitions** : sous la vie, l'icône de l'arme équipée, ses balles chargées (en rouge à zéro ; rien pour le couteau) et, en bleu, les munitions de ce type portées dans l'inventaire (toutes les piles additionnées).

**Demi-tour** : **Carré + Bas**, comme dans RE3. Ensuite, relâche Bas pour repartir.

**Rechargement rapide** : **R1 + Rond** remplit l'arme équipée jusqu'à sa capacité (Beretta 15, fusil à pompe, Colt et bazooka 6) en prenant dans les munitions de ce type portées ; une pile vide disparaît et l'inventaire se tasse, comme après une combinaison.

**Menu d'options en jeu** : maintiens **Select** 5 secondes. Le jeu se fige sur sa dernière image ; **Haut / Bas** pour choisir, **Croix** (ou Gauche / Droite) pour activer / désactiver, **Start** pour revenir au jeu. Les changements valent jusqu'à l'extinction (le choix du patcheur revient au démarrage suivant).

## Limites

- Pas de raccourci ni de demi-tour pendant une visée, une animation (escalier, ramassage, porte), une cinématique, ni quand le perso est au sol.
- Carré n'échange que deux cases occupées : le jeu exige un inventaire sans trou.
- Quand un objet est épuisé, le jeu tasse l'inventaire : les objets suivants remontent d'une case.
- L'affichage (vie, munitions, overlay) est masqué pendant les menus, les cinématiques et les portes.
- Testé avec Jill dans PCSX-Redux (OpenBIOS ; démarrage aussi avec le BIOS Sony SCPH-5502). Pas encore testé avec Chris ni Rebecca.

## Fonctionnement technique

**Placement du code**

- Le bloc (6 Ko) est chargé en 0x8000E800, juste avant l'exécutable, dans la zone mémoire du noyau que le BIOS réserve mais n'utilise pas au-delà de 0xE600 (mesuré avec le BIOS Sony).
- L'en-tête de SLES_009.70 charge l'image à cette adresse, sans changer la taille du fichier. Les 6 derniers Ko de l'image d'origine sont restaurés au démarrage à partir de segments stockés dans le bloc.
- Chaque option est un octet de la table `config` (au début du bloc) : le patcheur l'écrit, le code teste l'octet.

**Appels redirigés**

- `jal` en 0x80032084 (boucle principale, après la lecture de la manette) : Carré dans l'inventaire, L2 + croix, demi-tour.
- `jal` en 0x80054C9C (grille d'inventaire) : flèches et surbrillance.
- `jal` en 0x80032740 (boucle principale, OT de l'image terminée) : vie, munitions, overlay, dessinés dans l'OT de la scène avec les textures de l'inventaire présentes en VRAM (chiffres, icônes d'objets).

**Actions**

- **Changement d'arme :** tâche du jeu lancée dans l'emplacement 1, tâche de jeu suspendue, comme le fait l'inventaire. Les sons de l'arme passent par le tampon du modèle d'arme, pas par 0x801D10EC qui garde le décor de la salle (sinon : stries en haut de l'écran).
- **Soins :** 0x80057CA0 (routine « Utiliser »), décrément de la quantité, puis tassement 0x8002D678 si l'objet est épuisé.
- **Demi-tour :** l'angle du joueur (0x800C5198) avance de 0x100 par image pendant 8 images.

## Reconstruire

Prérequis : Python 3 et Node, plus les outils dans `tools/` (Windows) ou sur le PATH (Linux : binutils-mips-linux-gnu, cpp, chdman, xdelta3). Le CHD d'origine doit être à la racine du projet.

```
python src/build.py              # toutes les versions trouvées : bloc, BIN/CUE patchés, patcheur, .xdelta
python src/build.py --asm        # seulement le bloc de code
python src/build.py --ver us     # une seule version (fr, us, usds) ; --chd : CHD patchés
node tools/test_patcher.js       # le patcheur doit donner exactement le même résultat
```

Les fichiers intermédiaires vont dans `build/`. Le code est dans `src/hotkey.S` (démarrage, accroches), `src/lib.S` (outils communs) et un fichier `src/feat_*.S` par option ; les adresses du jeu de chaque version sont dans `src/versions.py`.
