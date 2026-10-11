# Historique des versions

*[English version](CHANGELOG.md)*

## v1.1.0 — 2026-10-11

### Nouveautés
- **Versions US prises en charge** : Resident Evil – Director's Cut (USA, SLUS-00551) et Director's Cut – Dual Shock Ver. (USA, SLUS-00747), en plus de la version française (SLES-00970). Toutes les options fonctionnent de la même façon sur les trois versions.
- **Menu d'options en jeu** : maintiens **Select 5 secondes** en jeu. Le jeu se met en pause sur sa dernière image et un menu liste les options du mod : **Haut / Bas** pour choisir, **Croix** (ou Gauche / Droite) pour passer ON / OFF, **Start** (ou Triangle / Select) pour revenir. Les changements s'appliquent tout de suite ; ils ne sont pas sauvegardés (le choix du patcheur revient au démarrage suivant). Le menu est en anglais dans toutes les versions.
- **Rechargement rapide** : **R1 + Rond** remplit l'arme équipée jusqu'à sa capacité (Beretta 15, fusil à pompe / Colt / bazooka 6) avec les munitions de son type que tu portes. Les piles vidées disparaissent et l'inventaire se tasse, comme après une combinaison.
- **Munitions portées dans le HUD** : à côté des balles chargées (en vert), les munitions de ce type portées, en bleu, toutes les piles additionnées (par exemple deux piles de 30 et 15 cartouches affichent 45).
- **Patcheur** :
  - reconnaît la version tout seul (taille de l'image, puis somme de contrôle de l'exécutable) ;
  - accepte la version Dual Shock en .bin unique (par exemple extrait d'un .chd) ou en fichier Redump *(Track 1)* (le .cue généré garde la piste audio d'origine) ;
  - choix anglais / français ;
  - deux nouvelles options : le menu en jeu et le rechargement rapide (8 options en tout).
- **Un xdelta par version** dans `patch/` (toutes les options).

### Corrigé
- **Chris (inventaire de 6 cases)** : les flèches des cases rapides et la surbrillance de l'objet pris étaient dessinées une rangée trop haut ; elles suivent maintenant la grille de 6 cases du jeu.

### Modifié
- Le code ne contient plus aucune adresse du jeu : chaque version a sa table (`src/versions.py`) et la construction refuse une adresse qui ne collerait pas à une version.
- Le menu d'options et l'overlay L2 sont maintenant placés dans du code du jeu que rien ne peut atteindre (fonctions de bibliothèque jamais appelées, trouvées par analyse et vérifiées dans l'émulateur), ce qui libère de la place dans le bloc principal.
- Fichiers de patch renommés : `<nom du jeu> [Hotkeys].xdelta`. L'ancien `… - Raccourcis.xdelta` disparaît.
- Outils de développement : `tools/re/port.py` (retrouve les adresses dans une autre version), `tools/re/deadcode.py` (code inatteignable), `tools/re/iso.py` (fichiers du disque), choix de la version dans le banc de test.

### Limites connues
- Pas encore testé sur console, ni avec Rebecca.
- Les capacités utilisées par le rechargement rapide sont celles habituelles du jeu ; signale-nous une erreur.

## v1.0.0 — 2026-10-11

Première version publique, version française (SLES-00970) seulement.

- **Cases rapides L2 + croix** : les quatre cases du haut de l'inventaire sont associées à ↑ ↓ ← →. Une arme est équipée, un soin (spray, plantes, mélanges, sérum) est utilisé comme avec « Utiliser ». Des flèches translucides marquent ces cases dans l'inventaire.
- **Overlay L2** : tant que L2 est maintenu, les quatre cases rapides en bas de l'écran (icônes, quantités, arme équipée teintée).
- **Vie** : en haut à gauche, une croix et la santé en chiffres, dans la couleur de l'état du jeu (vert, jaune, orange, rouge).
- **Arme équipée et munitions** : sous la vie, l'icône de l'arme et ses balles chargées (en rouge à zéro).
- **Demi-tour** : Carré + Bas, comme dans RE3.
- **Déplacer les objets dans l'inventaire** : Carré prend un objet, Carré sur un autre les échange ; l'arme équipée suit son objet.
- **Patcheur dans le navigateur** : choisis le .bin d'origine, coche les options, récupère un .bin + .cue patché ou un .ppf pour DuckStation. Aucune donnée du jeu dedans : il lit l'exécutable sur ton disque. Aussi en ligne sur GitHub Pages.
- Affichage masqué dans les menus, les cinématiques et les portes.

## Avant la v1.0.0 (non publié)

- **2026-10-10** — Correctif : après un changement d'arme avec L2, des stries apparaissaient en haut de l'écran jusqu'à la salle suivante (les sons de l'arme étaient chargés par-dessus la copie du décor de la salle). Chaîne de construction rendue utilisable sous Windows et vérifiée octet par octet contre la version précédente.
- **2026-09-30** — Première version : cases rapides L2 + croix (équiper, soigner), Carré pour déplacer les objets de l'inventaire, flèches sur les cases rapides. Testé dans PCSX-Redux.
