# Homme du match par poste et matchs délégués (14 novembre 2026)

Deux sujets d'équilibrage du moteur Node (`native/engine`), carrière Monde uniquement.

## 1. Homme du match par poste (maillots 1 à 15)

### Constat (avant)

Mesure en carrière Monde (`world-champ`, club 102, graine 4242, cadence hebdomadaire, matchs du
manager délégués) : **795 matchs** de tous les championnats détaillés (semaines 1 à 25),
**23 797 notes** de joueurs ayant joué 40 minutes ou plus. Le poste est le maillot porté (1 à 15).

L'homme du match était « la meilleure performance relative au poste » (impact rapporté à un
écart-type par famille de poste étalonné sur l'ancien mode France), **pas la meilleure note** : dans
16 % des matchs, l'homme du match affiché n'avait pas la meilleure note (jusqu'à 0,5 d'écart).
Résultat : ailiers et centres sur-représentés (42 % à eux quatre), ouvreur et arrière rares.

### Cible et justification

Pas de statistique publique de l'homme du match par poste pour le Top 14, la Premiership ou l'URC
(prix remis par le diffuseur ou le vote du public, non compilés). Seule référence chiffrée trouvée :
la Coupe du monde 2023 (World Rugby, 46 prix jusqu'aux quarts de finale) : ouvreurs 21,7 %,
ailiers 17,4 %, troisième ligne aile 15,2 %, numéros 8 13,0 %, centres 10,9 %, demis de mêlée 8,7 %,
arrières 6,5 %, talonneurs 4,3 %, deuxième ligne 2,2 %, piliers 0 %.

Cible retenue pour un championnat de club : celle-ci, déplacée vers les avants (rencontres de
club plus fermées, conquête plus décisive, et l'observation de Léo : « avants, surtout troisième
ligne et talonneurs, et 9/10 souvent élus ; piliers rares mais présents »), sans poste à plus de
13 % ni sous 2,5 % :

| Maillot | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Cible (%) | 2,5 | 6,5 | 2,5 | 4 | 4 | 8 | 8 | 8,5 | 10 | 13 | 6,5 | 6 | 6 | 6,5 | 8 |

Avants 44 % / arrières 56 % (Coupe du monde : 35 / 65) ; troisième ligne 24,5 % ; charnière 23 %.

### Correction : pondération par poste dans la note (aucun tirage, aucun quota)

`native/engine/match-notes.cjs` :

- le **poste occupé** (maillot 1 à 15) est transmis au calcul (`contexte(l).postes` : maillot de
  départ, puis celui du joueur remplacé, sinon la place sur le terrain) ; repli sur le poste naturel
  (famille) pour un ancien journal ; rien pour un journal réduit (matchs internationaux, inchangés) ;
- `POSTES_NOTE[maillot] = [attendu, amplitude]`, étalonnés sur les 795 matchs :
  `impact = amplitude × (1,08 × faits − attendu × part) + (0,25 + collectif + influence) × part`.
  L'**attendu** retire les faits que le poste produit d'office (un troisième ligne plaque et court
  bien plus qu'un pilier) : moyennes par poste entre 6,6 et 6,8. L'**amplitude** fixe la dispersion
  du poste : un ouvreur (1,49) ou un demi de mêlée (1,26) fait plus souvent le match, ou le rate,
  qu'un troisième ligne aile (0,82) ou un deuxième ligne (0,86). La constante commune 0,25 garde la
  moyenne générale d'avant (les anciens décalages France étaient plus faibles que l'attendu Monde) ;
- **homme du match = meilleure note** (30 minutes au moins) ; à égalité : l'impact avant arrondi,
  le vainqueur, le plus de faits, l'identifiant.

### Avant / après

Mêmes 795 matchs, recalculés avec le nouveau barème (le calcul est pur : mêmes journaux) ; puis
contrôle **hors échantillon** dans le jeu, sur une autre carrière (club 0, même graine, 763 matchs
notés par le nouveau code).

| Notes (≥ 40 min) | Avant | Après (mêmes matchs) | Après (autre carrière, en jeu) |
|---|---|---|---|
| Moyenne | 6,68 | 6,67 | 6,68 |
| Écart-type | 1,06 | 1,08 | 1,11 |
| Part ≥ 8 | 13,8 % | 14,1 % | 15,1 % |
| Part ≥ 9 | 2,6 % | 2,8 % | 3,3 % |
| Part < 5,5 | 10,5 % | 11,0 % | 11,1 % |
| Homme du match ≠ meilleure note | 16 % des matchs | 0 | 0 |

| Maillot | Cible | Avant | Après (mêmes matchs) | Après (en jeu) | Moyenne avant → après | Écart-type avant → après |
|---|---|---|---|---|---|---|
| 1 Pilier gauche | 2,5 | 4,5 | 2,5 | 2,2 | 6,69 → 6,64 | 0,75 → 0,77 |
| 2 Talonneur | 6,5 | 4,2 | 6,7 | 6,8 | 6,82 → 6,65 | 0,98 → 1,12 |
| 3 Pilier droit | 2,5 | 4,8 | 2,4 | 2,5 | 6,53 → 6,69 | 0,79 → 0,80 |
| 4 Deuxième ligne | 4 | 3,5 | 3,9 | 3,4 | 6,47 → 6,66 | 1,08 → 0,99 |
| 5 Deuxième ligne | 4 | 3,6 | 4,0 | 4,1 | 6,65 → 6,58 | 0,97 → 1,00 |
| 6 Troisième ligne | 8 | 7,3 | 7,9 | 6,6 | 6,73 → 6,74 | 1,31 → 1,16 |
| 7 Troisième ligne | 8 | 7,8 | 8,2 | 6,9 | 6,66 → 6,70 | 1,25 → 1,18 |
| 8 Numéro 8 | 8,5 | 6,2 | 8,8 | 9,7 | 6,67 → 6,72 | 1,16 → 1,17 |
| 9 Demi de mêlée | 10 | 6,8 | 10,1 | 9,7 | 6,69 → 6,71 | 1,04 → 1,18 |
| 10 Ouvreur | 13 | 5,9 | 13,0 | 14,8 | 6,60 → 6,62 | 1,00 → 1,27 |
| 11 Ailier | 6,5 | 11,8 | 6,5 | 7,3 | 6,89 → 6,75 | 1,03 → 1,06 |
| 12 Centre | 6 | 11,3 | 6,7 | 4,5 | 6,74 → 6,65 | 1,11 → 1,07 |
| 13 Centre | 6 | 8,7 | 6,4 | 4,5 | 6,65 → 6,61 | 1,08 → 1,05 |
| 14 Ailier | 6,5 | 10,1 | 6,5 | 5,0 | 6,75 → 6,60 | 0,97 → 1,02 |
| 15 Arrière | 8 | 3,5 | 7,3 | 12,1 | 6,62 → 6,65 | 1,15 → 1,21 |

Groupes (avant → après en jeu) : piliers 9,3 → 4,7 % ; talonneur 4,2 → 6,8 % ; deuxième ligne
7,1 → 7,5 % ; troisième ligne 21,3 → 23,2 % ; charnière 12,7 → 24,5 % ; ailiers 21,9 → 12,3 % ;
centres 20,0 → 9,0 % ; arrière 3,5 → 12,1 %. Avants 47,3 → 42,3 %.

Hors échantillon (première carrière de contrôle), l'arrière (12 %) et l'ouvreur (15 %) dépassaient un
peu la cible et les centres (4,5 %) restaient en dessous. Sur l'ensemble des carrières de contrôle
(2 160 matchs, avant l'ajustement final) : arrière 10,4 %, ouvreur 14,0 %, centres 4,9 et 5,2 %. Les
amplitudes des centres (0,93 → 0,96 et 0,97 → 1,00) et de l'arrière (1,09 → 1,05) ont donc été
ajustées d'un demi-pas (colonne « mêmes matchs » : valeurs finales). Contrôle final en jeu (test
ci-dessous, club 102, 164 matchs) : 1 : 1,8 % · 2 : 7,3 · 3 : 2,4 · 4 : 3,0 · 5 : 4,9 · 6 : 5,5 ·
7 : 8,5 · 8 : 11,0 · 9 : 10,4 · 10 : 12,2 · 11 : 6,7 · 12 : 5,5 · 13 : 5,5 · 14 : 6,7 · 15 : 8,5.
À re-mesurer sur plusieurs saisons et graines avant d'affiner encore.

### Test

`tests/homme-du-match-postes.cjs` (carrière Monde, cadence hebdomadaire, 150 matchs au moins) :
homme du match = meilleure note de chaque match ; aucun maillot au-delà de 20 % ; chaque groupe de
poste élu au moins une fois ; piliers ≤ 12 % ; troisième ligne 12–40 % ; charnière 10–38 % ;
ailiers + centres ≤ 40 % ; avants 30–62 % ; moyenne générale 6,45–6,9, écart-type 0,85–1,3 ;
moyenne de chaque maillot 6,3–7,0. `tests/match-notes.cjs` : pondération par poste occupé,
remplaçant au maillot du remplacé, homme du match = meilleure note.

### Effets sur le reste du jeu

Les notes alimentent la forme, donc la composition des entraîneurs IA (±3 à 4 % du score de
choix), la valeur, l'intérêt, les sélections. Les moyennes par poste restant proches (6,6–6,8) et
la moyenne générale inchangée, ces effets bougent peu ; les résultats des matchs IA changent
seulement à travers ces effets bornés (comme à chaque recalibrage des notes). Aucune donnée figée
(`tests/fixtures`) ne contient de note : aucune régénération nécessaire.

## 2. Toulouse perd beaucoup en matchs délégués

### Mesure

Même graine (4242), carrière Monde en cadence hebdomadaire, 16 à 20 premières semaines (12 à 15
journées de Top 14 ; les carrières plus longues ont été tuées par manque de mémoire de la machine
partagée). Toulouse (club 0) :

- **joueur, délégué, feuille gardée** : le joueur ne touche pas à sa feuille (elle reste celle du
  match précédent, comme dans le jeu), chaque match est délégué (`delegate`) ;
- **joueur, délégué, sélection du staff** : `auto_lineup` (« Sélection du staff ») avant chaque match ;
- **IA** : le joueur entraîne un autre club (102), Toulouse est géré par l'IA.

| Toulouse | Délégué, feuille gardée (avant) | Délégué, feuille gardée (après) | Délégué, sélection du staff (après) | IA |
|---|---|---|---|---|
| Top 14 (V-N-D) | 4-0-11 | 3-0-11 | 10-1-3 | 9-0-3 |
| Points pour / contre (Top 14) | 175 / 301 | 239 / 318 | 261 / 198 | 209 / 135 |
| Classement (semaine 24, avant) | 12e sur 14 | — | — | — |
| Niveau moyen du XV (adversaire) | 83,0 (77,7) | 82,2 (78,2) | 81,3 (78,2) | 83,1 (78,3) |
| Condition au coup d'envoi (adversaire) | **52 %** (98 %) | **68 %** (98 %) | 98 % (97 %) | 96 % (98 %) |
| Condition à la fin | 29 % | 67 % | 79 % | 77 % |
| Remplacements (adversaire) | **0,8** (7,4) | 7,5 (8,3) | 6,9 (8,4) | 7,8 (7,4) |
| Joueurs à 80 minutes | 13,8 | 8,6 | 8,3 | 8,5 |
| Plan de jeu en cours de match | jamais revu (« équilibré ») | revu à 40 et 60 min | revu | revu |
| Internationaux absents | aucun (cadence hebdomadaire sans carrière internationale) | | | |

Condition au coup d'envoi semaine après semaine, feuille gardée : avant 100, 91, 81, 71, 61, 64,
53, 42, 39, 35, 31, 43, 41, 36 % ; après 100, 93, 86, 78, 72, 82, 75, 66, 61, 58, 56, 64, 57, 50 % ;
IA : 92 à 100 % toute la saison.

### Causes

1. **Défaut (corrigé) : un match délégué était joué sans aucun remplacement ni ajustement.** Le
   moteur (`dist/opposition.js`) réserve `manageSubstitutions`, `opponentDefensiveScout` et
   `adaptManager` à l'équipe sans manager (`side !== l.userSide`). L'écran du match promet pourtant
   « L'adjoint prend en charge la fin de cette rencontre » : en réalité quinze titulaires jouaient
   80 minutes, le plan n'était jamais revu, et la fatigue se reportait sur les semaines suivantes.
2. **Cause principale, réaliste : aucune rotation.** La feuille du joueur est reprise telle quelle de
   match en match ; l'entraînement collectif « normal » rend +20 de condition par semaine, moins
   que ce que coûte un match. L'IA, elle, compose chaque semaine avec la condition des joueurs
   (`managerSheet`) et met au repos ses joueurs épuisés (règle documentée dans `v27-physical-load` :
   le club du joueur choisit lui-même ses plans physiques). La **sélection du staff** (`auto_lineup`,
   bouton « Sélection du staff », ou la délégation de la sélection dans le bureau) fait bien tourner
   les joueurs fatigués : 98 % au coup d'envoi, résultats au niveau de l'IA. Ce n'est pas un défaut
   du moteur : un entraîneur qui aligne les mêmes 23 joueurs quinze semaines de suite les épuise.
   (Même constat chez un autre agent : titulaires de Toulouse à 9–19 % de condition en délégué.)
3. Écartées : la composition (niveau du XV identique à l'IA), la tactique de départ (« équilibré »
   pour le joueur, choisie selon l'effectif pour l'IA : effet secondaire, l'adjoint la revoit
   désormais à 40 et 60 minutes), les internationaux (retirés de la même façon chez le joueur et chez
   l'IA par `matchRoster`), la rotation excessive (c'est l'inverse).

### Correction

`native/engine/match-delegation.cjs` (domaine natif) : pendant la seule commande `delegate` (le worker
active puis désactive le domaine), après chaque minute jouée, l'adjoint applique au club du joueur
exactement les décisions d'un entraîneur IA du même niveau (`adaptManager`, `aiSubs` =
observation de l'attaque adverse + remplacements). La feuille et la consigne de départ restent
celles du joueur ; le direct est inchangé ; rien n'est ajouté à la sauvegarde.

Effet : 7,5 remplacements par match, condition de fin 67 % au lieu de 29 %, chute de condition
ralentie (50 % au lieu de 36 % après 14 journées). Mais sans rotation la feuille gardée reste
perdante (3-0-11) : la fatigue d'avant-match domine. Avec la sélection du staff, Toulouse délégué
fait aussi bien que l'IA (10-1-3 contre 9-0-3).

### Stabilité des matchs IA

Le correctif ne touche que le match délégué du club du joueur. Les matchs IA ne changent qu'à
travers le générateur commun (les décisions de l'adjoint consomment des tirages, comme celles de
l'adversaire) et les effets bornés des notes. Aucune donnée figée n'est concernée (`tests/fixtures` :
matchs du chorégraphe en direct, sans délégation ni note).

### Proposition (à décider par Léo)

Le piège reste entier pour un joueur qui délègue sans toucher à sa feuille. Pistes, de la plus
légère à la plus forte : alerte de Gabi avant le coup d'envoi quand un titulaire est sous 70 % ;
bouton « Confier aussi la feuille à l'adjoint » au moment de déléguer ; délégation de la sélection
cochée par défaut dans les nouvelles carrières ; repos automatique des joueurs épuisés qui suivent le
plan collectif (règle de l'IA : condition < 60 % ou charge ≥ 55).
