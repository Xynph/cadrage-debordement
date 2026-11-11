# Touche : côté et géométrie des alignements dans la scène 3D (11 novembre 2026)

Périmètre : la scène `lineout` produite par `matchScene` (`dist/match2d.js`) et
transmise telle quelle à la vue 3D par `dist/match3d/scene-adapter.js` et par le
moteur natif (`native/engine/worker.cjs` charge `match2d.js`). Référence :
[loi 18, touche](rugby-rules-reference.md), saison simulée 2025/26.

Trois lots sur la même PR : le côté des alignements (premier commit), leur
géométrie (second lot), puis le ballon dans les mains du lanceur et la mise en
marche des avants dès la sortie en touche (troisième lot). Aucun ne modifie l'état
du match ni n'appelle le générateur aléatoire ; le troisième lit le journal
(l'événement qui suit le fait affiché), sans rien y écrire.

## Loi 18 consultée le 11 novembre 2026

Textes officiels World Rugby, en ligne :
[version française](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/18-touche-remise-en-jeu-rapide-et-alignement/)
et [version anglaise](https://passport.world.rugby/laws-of-the-game/laws-by-number/18-touch-quick-throw-and-lineout/).

| Article | Exigence | Scène après ce lot |
| --- | --- | --- |
| 18.9 | Alignement sur la marque, jamais à moins de 5 m de la ligne de but | Marque bornée à [5, 95] dans la scène seulement (le moteur la borne déjà ; aucune marque hors bornes sur 758 scènes) |
| 18.10 | Une rangée par équipe, parallèle à la ligne de remise en jeu, à 0,5 m de celle-ci de son côté, entre les lignes des 5 et 15 m | Rangées en `marque ∓ 0,5`, joueurs de 5,5 à 14,5 m de la touche : couloir d'un mètre centré sur la ligne de remise en jeu |
| 18.15 | Un joueur de l'équipe qui ne lance pas entre la touche et la ligne des 5 m, à 2 m de la marque de son côté et à 2 m de la ligne des 5 m | Talonneur adverse en `marque ∓ 2`, `y = 3` |
| 18.16 | Un receveur au plus par équipe, entre 5 et 15 m, à 2 m de ses partenaires de l'alignement | Demi de mêlée de chaque équipe à 2 m derrière sa rangée, `y = 10` |
| 18.22 | Le lanceur se tient sur la marque, pieds sur ou derrière la ligne de touche | Talonneur de l'équipe qui lance en `x = marque`, `y = 0`, ballon dans ses mains (`ball = (marque, 0)`, troisième lot) |
| 18.35 | Non-participants à 10 m au moins de la ligne de remise en jeu de leur côté, ou derrière la ligne de but si elle est plus proche | Inchangés quand la place habituelle (15,8 m et plus) tient dans le terrain ; sinon sur leur ligne de but |

« De son côté » (18.10, 18.15) est lu comme le côté de son propre en-but, comme
pour les lignes de hors-jeu : c'est la convention du premier commit (chaque équipe
du côté de son propre en-but, quelle que soit l'équipe qui lance). Cette lecture
est la mienne ; le texte consulté ne la définit pas explicitement.

### Règle, abstraction, non vérifié

- **Règle appliquée** : les six lignes du tableau ci-dessus.
- **Abstractions volontaires de la scène** :
  - le lanceur est le talonneur (slot 1) : le moteur ne désigne aucun lanceur et
    la référence interdit de l'inventer côté moteur ; la scène le faisait déjà ;
  - les sept autres avants présents forment la rangée (nombre inchangé), dans
    l'ordre des slots, espacés régulièrement de 1,5 m ; la loi laisse le nombre au
    choix de l'équipe qui lance (18.13, 18.14) ;
  - le demi de mêlée (slot 8) est le receveur de chaque équipe ;
  - les non-participants trop proches de leur en-but sont posés **sur** la ligne de
    but : l'adaptateur 3D borne x à [0, 100] et ne peut pas les placer derrière ;
  - le ballon de la scène est à la place du lanceur, `(marque, 0)` : la scène est
    plane, « dans les mains » se lit comme « au même point que le lanceur ». Le fait
    du moteur garde `y = 4` (`from` et `to` de l'événement, et l'origine `origin` de
    la scène) : seul le ballon affiché change.
- **Non vérifié** : le cas d'une équipe réduite (carton) n'est pas rééquilibré
  (18.14 : l'adversaire ne peut pas aligner plus de joueurs que l'équipe qui lance) ;
  la touche rapide (18.2 à 18.8) n'est pas représentée ; le délai de formation
  (18.12, présenté comme expérimentation globale) n'est pas simulé.

## Constat chiffré (sonde hors dépôt, 48 matchs, 758 scènes de touche)

Matchs simulés avec le vrai moteur (graines 1 à 12 × clubs 0, 3, 7, 12, deux
tactiques), toutes les scènes `lineout` distinctes, mi-temps 1 et 2, les deux
équipes. Le moteur n'inverse pas les sens d'attaque à la mi-temps : l'équipe 0
attaque toujours vers x croissant ; la touche est toujours du côté y = 0.

### Premier commit : côté des alignements

Avant `d05b5f75`, l'équipe qui lançait était toujours placée en `x = touche − 2` :
du côté de l'en-but adverse dans les 402 scènes où l'équipe 1 lançait (deux
mi-temps). Correction en une ligne (`side===team` devenu `side===0`).

### Second lot : géométrie

| Mesure (758 scènes) | Après `d05b5f75` | Après ce lot | Loi 18 |
| --- | --- | --- | --- |
| Couloir entre les rangées | 4 m | 1 m, centré sur la marque | 1 m (2 × 0,5 m) |
| Profondeur des rangées (min / médiane / max) | 9 / 22,2 / 32,1 m | 5,5 / 10 / 14,5 m | 5 à 15 m |
| Joueurs de rangée entre 5 et 15 m | 1 513 / 10 542 | 10 542 / 10 542 | tous |
| Lanceur | à 2 m de la marque, `y = 2` | sur la marque, `y = 0` | sur la marque, sur la touche |
| Vis-à-vis du lanceur | 2 m de la marque, `y = 2` | 2 m de la marque, `y = 3` | 2 m de la marque et de la ligne des 5 m |
| Demi de mêlée | non-participant, 13 m, `y = 7` (1 396 cas) | receveur, 2 m derrière sa rangée, `y = 10` | 18.16 |
| Non-participants à moins de 10 m hors ligne de but | 503 joueurs dans 84 scènes (minimum 3,5 m) | 0 | 0 |
| Non-participants sur leur ligne de but | 0 | 1 124 (quand leur en-but est à moins de 15,8 à 29,8 m selon leur place) | autorisé |
| Ballon | `y = 4` | `y = 4` (inchangé au second lot ; `y = 0`, à la place du lanceur, au troisième) | dans les mains du lanceur |

## Mise en place : d'où viennent les avants

La scène qui précède la touche est « Sortie en touche » (`touch`) dans 739 cas sur
758, « Avantage » dans 19 (la sortie, puis l'avantage, puis la touche). Il n'existe
aucune scène intermédiaire : le moteur enregistre la sortie puis la touche dans la
même séquence atomique, et en ajouter une changerait le journal d'événements (exclu).

Dans la scène `touch`, l'équipe qui lance (le plus souvent celle qui n'a pas
botté) reçoit la formation générique de défense des consignes tactiques : ses avants
sont étalés sur la largeur, `y = 10 + slot × 6,5` (jusqu'à 55,5 m de la touche),
à 9 m de la sortie. Après un coup de pied direct en touche sans gain, la marque
revient en plus jusqu'à 32,5 m en arrière de la sortie.

### Troisième lot : les avants partent dès la sortie en touche

Quand le fait affiché est une sortie en touche (ou un avantage) **et que l'événement
suivant du journal est la mise en place d'une touche** (au plus un avantage entre
les deux), `matchScene` place les avants (postes 1 à 8, slots 0 à 7) des deux
équipes **à mi-chemin** entre leur place habituelle dans cette scène et leur place
dans la touche qui suit (même fonction `lineoutSpot` que la scène de touche, même
marque bornée à [5, 95]). Ils sont en marche, pas alignés ; les arrières et le
ballon ne changent pas. Une sortie qui ne mène pas à une touche (mêlée après
avantage, mi-temps, fin du match) est inchangée.

Lecture du journal : `upcomingLineout` cherche l'événement affiché dans
`l.events` et regarde le suivant (ou celui d'après si le suivant est un avantage).
Rien n'est écrit, aucun tirage : vérifié par `tests/lineout-approach.cjs` et par la
sonde `compare-sportif` (ci-dessous).

Choix tranchés (Léo absent) :

- **mi-chemin** plutôt qu'une distance fixe : c'est l'intermédiaire neutre entre
  « au moment où le ballon sort » et « alignés », et il divise par deux chacune des
  deux transitions de la vue par défaut ;
- **avants seulement** (consigne), demi de mêlée et arrières inchangés ;
- scène `advantage` traitée comme la sortie quand elle précède la touche, sinon
  les avants feraient un aller-retour entre les deux scènes.

| Plus grand déplacement d'un avant (les deux équipes), 346 touches de 24 matchs | Avant ce lot | Après |
| --- | --- | --- |
| Scène précédente → `touch` : médiane / 9ᵉ décile / max | 35 / 43 / 60,2 m | 31,1 / 43,1 / 57,5 m |
| `touch` → `lineout` : min / médiane / 9ᵉ décile / max | 36,2 / 42,1 / 43 / 58,7 m | 18,1 / 21 / 21,5 / 29,3 m |
| `lineout` → scène suivante (touche gagnée ou perdue) : médiane / max | 43,5 / 47,8 m | inchangé |
| Arrières, `touch` → `lineout` : médiane / max | 19,1 / 41,3 m | inchangé |

Le trajet total d'un avant (scène précédente → touche) est inchangé (médiane 42,1 m,
max 59,2 m) : la scène ne fait que le couper en deux. **La vue par défaut affiche
toujours chaque transition en 0,55 s** : la moitié de 58,7 m reste une course
absurde (voir « Ce qui change à l'écran »). La durée de mise en place relève de la
présentation : elle est traitée dans la couche de gestes de la PR #554, qui
contient cette branche.

Mesures avant ce lot, conservées pour mémoire : vue Godot par défaut, touche réelle
(graine 1, club 0, 10ᵉ minute, marque 64), plus long trajet 28,0 → 41,7 m et pointe
50,9 → 75,8 m/s entre le premier et le second lot (capture hors dépôt, 30 images/s).

## Compatibilité avec la PR #554 (gestes 3D)

La PR #554 fusionne cette branche (fusion ordinaire) et l'accorde : fixture
régénérée, détection de la touche par le type de scène (plus par `origin.y == 4`),
places d'alignement lues dans la scène, durée de mise en place proportionnelle au
plus long trajet. Voir `docs/match-gestes-20261111.md` sur cette branche.

## Ce qui change à l'écran (vue par défaut, sans `CD_MATCH_GESTES`)

Seules deux scènes changent, à chaque touche :

1. **Sortie en touche** (et avantage qui précède une touche) : les huit avants de
   chaque équipe sont à mi-chemin de leur place d'alignement au lieu d'être à leur
   place habituelle ; ils y courent donc dès que le ballon sort.
2. **Touche** : géométrie de la loi 18 (lots 1 et 2) et ballon posé au point du
   lanceur, sur la ligne de touche (à 0,23 m du sol, comme tout ballon libre de la
   vue par défaut), au lieu de 4 m dans le terrain. La vue ne fait pas tenir le
   ballon par le lanceur : sans porteur désigné, elle pose un ballon libre au
   point de la scène.

Toutes les autres scènes sont identiques (vérifié par `tests/lineout-approach.cjs`
pour les sorties qui ne mènent pas à une touche). La vue par défaut garde sa
transition de 0,55 s : les avants traversent toujours trop vite, en deux fois au
lieu d'une.

## Preuve de non-régression sportive

80 matchs (20 graines × 4 clubs) rejoués avant et après avec `matchScene`
appelée à chaque tick : score, essais, statistiques, journal complet d'événements
(empreinte), état du match et prochain tirage aléatoire identiques pour chacun des
trois lots (1 276 scènes de touche dans ces matchs). Troisième lot : sonde
`compare-sportif` entre `2f5d9ba5` et ce lot, **80/80 identiques**.
`tests/lineout-geometry.cjs` vérifie en plus qu'un appel de `matchScene` ne
consomme aucun tirage et ne modifie pas l'état ; `tests/lineout-approach.cjs`, que
la lecture du journal ne le modifie pas.

## Tests

- `tests/lineout-side.cjs` (premier commit) : côté des rangées et des
  non-participants, deux équipes, deux mi-temps. Le lanceur, désormais sur la
  marque, n'est plus compté parmi les joueurs d'un côté.
- `tests/lineout-geometry.cjs` (second lot) : 274 scènes réelles (6 graines ×
  3 clubs, dont 31 à moins de 10 m d'un en-but) et 36 scènes construites (deux
  équipes × deux mi-temps × marques 2, 5, 8, 12, 50, 88, 92, 95, 98) ; vérifie
  la marque bornée, le couloir d'un mètre centré, la fourchette 5–15 m, le lanceur,
  le vis-à-vis, les receveurs, les non-participants (10 m ou ligne de but), la
  conservation par l'adaptateur 3D, l'absence de mutation et de tirage, et que la
  marque ramenée à 5 m ne touche pas l'action enregistrée. Il échoue sur `d05b5f75`.

- `tests/lineout-approach.cjs` (troisième lot) : 187 scènes réelles précédant une
  touche (12 matchs, dont 5 sorties suivies d'un avantage) et 336 qui n'en
  précèdent pas ; avants à mi-chemin de leur place d'alignement (encadrement quand
  la place habituelle est sur une borne de la scène), arrières et ballon inchangés,
  journal non modifié.
- `tests/lineout-geometry.cjs` étendu : ballon de la scène à la place du lanceur
  (`y = 0`), fait du moteur toujours à `y = 4`.

Test partagé modifié (une assertion) : `tests/match-actions.cjs` ligne 16, la scène
de touche attend désormais `ball.y === 0` au lieu de 4.

Autres lecteurs de `y == 4` cherchés dans `dist/`, `native/godot` et `tests/` :
`tests/lineout-side.cjs` et `tests/lineout-geometry.cjs` construisent des faits
moteur à `y = 4` (inchangés, c'est le fait) ; `tests/godot-match-gestes-scenes.cjs`
(PR #554) teste `origin.y === 4` d'une scène `setpiece-win`, qui reste le fait du
moteur ; `native/godot/match_gestes.gd` (PR #554) lisait `origin.y == 4` : remplacé
dans #554 par la lecture du journal. Aucun autre lecteur.

## Limites et non vérifié

- Vue par défaut : transitions toujours de 0,55 s, donc courses de mise en place
  encore beaucoup trop rapides (moitié du trajet à chaque transition) ; corrigé
  seulement avec la couche de gestes (#554).
- Mi-chemin : choix de présentation, pas une mesure ; le moteur ne simule pas la
  reformation (18.12).
- Équipe réduite, touche rapide et délai de formation : non représentés.
- Rendu Godot de la vue par défaut regardé sur des captures Linux (Xvfb, OpenGL de
  compatibilité), pas sous Windows. Les rangées à 0,5 m de la ligne laissent les
  deux files presque au contact à l'écran : c'est la distance réglementaire, aucun
  choix de style n'a été fait ici.
- `ci/select-tests.cjs` n'associe pas `lineout-*` ni `match-actions` à
  `dist/match2d.js` (fichier partagé, non modifié ici).
