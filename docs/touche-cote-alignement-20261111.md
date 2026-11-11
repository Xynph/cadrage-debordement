# Touche : côté et géométrie des alignements dans la scène 3D (11 novembre 2026)

Périmètre : la scène `lineout` produite par `matchScene` (`dist/match2d.js`) et
transmise telle quelle à la vue 3D par `dist/match3d/scene-adapter.js` et par le
moteur natif (`native/engine/worker.cjs` charge `match2d.js`). Référence :
[loi 18, touche](rugby-rules-reference.md), saison simulée 2025/26.

Deux lots sur la même PR : le côté des alignements (premier commit), puis leur
géométrie (second lot). Aucun des deux ne lit ni n'écrit l'état du match, ni
n'appelle le générateur aléatoire.

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
| 18.22 | Le lanceur se tient sur la marque, pieds sur ou derrière la ligne de touche | Talonneur de l'équipe qui lance en `x = marque`, `y = 0` |
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
  - le ballon reste à `y = 4` (marque du moteur), pas dans les mains du lanceur :
    voir « Limites ».
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
| Ballon | `y = 4` | `y = 4` (inchangé) | dans les mains du lanceur |

## Mise en place : d'où viennent les avants

La scène qui précède la touche est « Sortie en touche » (`touch`) dans 739 cas sur
758, « Avantage » dans 19. Il n'existe aucune scène intermédiaire : le moteur
enregistre la sortie puis la touche dans la même séquence atomique, et en ajouter
une changerait le journal d'événements (exclu).

Dans la scène `touch`, l'équipe qui lance (le plus souvent celle qui n'a pas
botté) reçoit la formation générique de défense des consignes tactiques : ses avants
sont étalés sur la largeur, `y = 10 + slot × 6,5` (jusqu'à 55,5 m de la touche),
à 9 m de la sortie. Après un coup de pied direct en touche sans gain, la marque
revient en plus jusqu'à 32,5 m en arrière de la sortie. La scène précédant la
sortie montre déjà ces positions (déplacement médian nul de ces avants entre elle
et `touch`, 169 touches de 12 matchs) : la convergence se joue entièrement entre `touch` et `lineout`.

| Plus grand déplacement d'un avant de l'équipe qui lance, `touch` → `lineout` | Après `d05b5f75` | Après ce lot |
| --- | --- | --- |
| Par scène : min / médiane / 9ᵉ décile / max | 21,4 / 24,7 / 29,2 / 46,8 m | 11,3 / 41,7 / 42,9 / 58,7 m |
| Avants à plus de 15 m de leur place | 3 800 / 6 036 | 3 712 / 6 036 |

La géométrie réglementaire **allonge** donc la course des avants les plus
éloignés (rangée à 14,5 m au plus au lieu de 32,1 m). Dans la vue Godot par
défaut, sur une touche réelle (graine 1, club 0, 10ᵉ minute, marque 64), le plus
long trajet passe de 28,0 à 41,7 m et l'allure de pointe mesurée de 50,9 à
75,8 m/s ; sur une touche à 5 m de l'en-but (graine 1, club 7, marque 95), de
29,1 à 41,1 m et de 52,9 à 74,7 m/s (capture hors dépôt, 30 images/s). Ce n'est pas un défaut de la
scène de touche : en match, cette mise en place dure plusieurs dizaines de secondes
de ballon mort, alors que la vue l'affiche en une seule transition (0,55 s dans la
vue par défaut, `BLEND_SECONDS` ; au plus 2 s dans la couche de gestes de la
PR #554).

La scène `touch` pourrait techniquement rapprocher ces avants, mais elle décrit
l'instant où le ballon franchit la ligne : y placer les avants à mi-chemin ne
ferait que couper un trajet de 40 m en deux transitions de 20 m, toujours
parcourues en 0,55 s (plus de 35 m/s), et montrerait une équipe déjà repliée au
moment du coup de pied. Elle n'a donc pas été modifiée.

Plus petite évolution proposée, côté affichage uniquement : quand la scène reçue
est `lineout`, donner à la transition une durée proportionnelle au plus long
déplacement (par exemple une allure plafonnée vers 6 à 7 m/s, soit 6 à 9 s pour
40 à 58 m), le direct attendant la fin comme il le fait déjà pour les gestes
(`is_presenting_extended_pass`). Variante dans la couche de gestes : commencer la
mise en place dès la scène `touch` en lisant l'événement suivant du journal (elle
lit déjà `live.events`), sans rien demander au moteur.

## Compatibilité avec la PR #554 (gestes 3D)

Essai local (non poussé) : fusion de cette branche avec
`origin/claude/tranche-demo-match-20261111` (`84852d9b`) dans un worktree jetable,
conflits sans rapport (fichiers de livraison Windows) résolus en gardant la version de la branche touche,
projet stagé et importé, puis supprimé.

- `tests/godot-match-gestes.cjs` : le premier test (fixture identique à la
  séquence du moteur) **échoue** tant que `tests/fixtures/match-gestes-sequence.json`
  n'est pas régénérée ; seule la scène `lineout` de la fixture change (positions
  des joueurs, ballon et origine inchangés). Fixture régénérée localement : les deux
  tests passent, 125 contrôles, 0 échec, avec et sans `CD_MATCH_GESTES=1` (le test
  retire lui-même la variable de son environnement).
- Pas de double retournement : la couche de gestes place les rangées par équipe
  (`facing` selon l'équipe, équipe 0 côté x faible), même convention que la scène ;
  le contrôle « deux lignes séparées par un couloir, chacune de son côté » passe.
- `godot-match-framing`, `-presentation`, `-pass`, `-journal` passent sur la fusion,
  avec et sans la variable ; `lineout-side`, `lineout-geometry`, `match-actions`,
  `match2d`, `match3d-adapter` aussi.
- Mise en place mesurée par le test des gestes : inchangée (`farthest_m` 41,6 m,
  6 coureurs au-delà de 15 m, 2,0 s, pointe 8,9 m/s jusqu'à 15 m). Les gestes partent
  des positions de la scène `touch`, que ce lot ne modifie pas, et calculent
  eux-mêmes leurs marques : les avants n'arrivent pas moins vite.

À ajuster dans #554 à l'intégration :

1. régénérer la fixture (`node tests/godot-match-gestes-scenes.cjs > tests/fixtures/match-gestes-sequence.json`) ;
2. `_line()` borne la ligne à [6, 94] : la scène et la loi 18.9 utilisent [5, 95]
   (marques à 5 et 95 réelles, par exemple tir manqué sorti en touche) ;
3. constantes propres aux gestes à rapprocher de la scène, désormais conforme :
   couloir de 1,2 m (scène et loi : 1 m ; le test des gestes fige 1,2 m),
   vis-à-vis à `y = 2,6` (loi : 2 m de la ligne des 5 m, soit `y = 3`), demi à 2,8 m
   de sa rangée (loi : 2 m) ; ou lire directement les positions de la scène ;
4. la durée de mise en place (2 s au plus) reste la vraie cause des courses trop
   rapides : voir la proposition ci-dessus.

## Preuve de non-régression sportive

80 matchs (20 graines × 4 clubs) rejoués avant et après avec `matchScene`
appelée à chaque tick : score, essais, statistiques, journal complet d'événements
(empreinte), état du match et prochain tirage aléatoire identiques pour les deux
lots (1 276 scènes de touche dans ces matchs pour le second). `tests/lineout-geometry.cjs`
vérifie en plus qu'un appel de `matchScene` ne consomme aucun tirage.

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

Test partagé qui fige l'ancienne géométrie : `tests/match-actions.cjs` (ligne 16)
exige `ball.y === 4` pour la scène de touche. Le ballon est donc resté à la marque
du moteur ; il n'a pas été modifié ici.

## Limites et non vérifié

- Le ballon n'est pas dans les mains du lanceur (`y = 4` au lieu de 0) : le changer
  demande d'accorder `tests/match-actions.cjs` et la détection de la touche de la
  PR #554 (`_is_lineout` lit `origin.y == 4`, que ce lot ne modifie pas).
- Mise en place trop rapide à l'affichage : non corrigée (voir ci-dessus).
- Équipe réduite, touche rapide et délai de formation : non représentés.
- Rendu Godot regardé sur des captures Linux (Xvfb, OpenGL de compatibilité) de la
  vue par défaut avant/après (caméras TV et tactique) et d'une touche avec gestes
  sur la fusion jetable ; pas sous Windows. Les rangées à 0,5 m de la ligne
  laissent les deux files presque au contact à l'écran : c'est la distance
  réglementaire, aucun choix de style n'a été fait ici.
