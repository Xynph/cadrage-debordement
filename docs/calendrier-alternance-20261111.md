# Calendriers : alternance domicile/extérieur (11 novembre 2026)

## Constat (mesuré avant correction)

Les générateurs de calendrier reprenaient tous la même méthode du cercle, avec une
inversion domicile/extérieur calculée sur `(journée + table) % 2`. Comme chaque club
avance d’une table par journée, cette parité ne change jamais pour lui : il reçoit ou se
déplace pendant toute la phase aller, puis l’inverse pendant le retour. Le club 29
(deuxième division, 16 clubs) jouait ainsi `E D D D D D D D D D D D D D D D E E E E E E E E E E E E E E`.

Sonde : `node sonde-calendrier.cjs <racine> --monde` (hors dépôt, dans l’audit du
11 novembre). Série = plus longue suite de rencontres de championnat consécutives au
même endroit, pour le pire club.

| Calendrier | Clubs / journées | Avant : série max (dom./ext.) | Clubs avec série ≥ 3 avant | Après : série max | Réceptions par club (avant = après) |
|---|---|---|---|---|---|
| France30, première division (`dist/france-competition.js`) | 14 / 26 | 13 / 13 | 13 | 2 / 2 | 13 |
| France30, deuxième division | 16 / 30 | 15 / 15 | 15 | 2 / 2 | 15 |
| Mode historique 14 clubs (`dist/game.js`) | 14 / 26 | 13 / 13 | 13 | 2 / 2 | 13 |
| Monde, élite générée (saison 1 sans agenda quotidien, saisons 2 et suivantes) | 14 / 26 | 13 / 13 | 13 | 2 / 2 | 13 |
| Monde, accession générée | 16 / 30 | 15 / 15 | 15 | 2 / 2 | 15 |
| Monde, Premiership générée (saisons 2+) | 10 / 18 | 9 / 9 | 9 | 2 / 2 | 9 |
| Monde, URC générée (saisons 2+) | 16 / 18 | 4 / 5 | 13 | 2 / 2 | 9 |
| Espoirs Élite, poules de 6 | 6 / 10 | 5 / 5 | 5 | 2 / 2 | 5 |
| Espoirs Élite, poules de 4 (phase qualificative) | 4 / 6 | 3 / 3 | 3 | 3 / 3 (inévitable, voir plus bas) | 3 |
| Espoirs Accession, poules de 10 | 10 / 18 | 9 / 9 | 9 | 2 / 2 | 9 |
| Atelier de calendrier fictif, 2 à 32 clubs | jusqu’à 32 / 62 | jusqu’à 31 | tous | 2 (3 à quatre clubs en aller-retour) | équilibré |

Équilibre aller/retour (réceptions dans la phase aller) : avant, de 0 à n−2 selon le club ;
après, n/2−1 ou n/2 (par exemple 6 ou 7 en première division, 7 ou 8 en deuxième).
Le nombre total de réceptions par saison ne change pour aucun championnat en
aller-retour : seule leur répartition dans le temps change.

Calendriers non modifiés, parce qu’ils sont repris des calendriers publiés (saison 1)
puis reconduits à l’identique (Champ, Nationale, Japan League One, Super Rugby
Pacific avec inversion des réceptions une saison sur deux) : Premiership publiée 2,
Champ 2, Japan League One D2 2, LNR publiée (agenda quotidien de l’exécutable) 2,
URC publiée 3, Nationale 3, Japan League One D1 3, Super Rugby Pacific 2027 3 à
domicile et 4 à l’extérieur. Poules européennes (4 journées, 2 réceptions) : 2.

## Algorithme

Tables de Berger (méthode du cercle de de Werra) avec alternance, une fonction de
quelques lignes recopiée à l’identique dans chaque module (les modules sont chargés
séparément, parfois par injection de source) :

- n clubs (n pair ; si n est impair, un adversaire fictif fixe donne l’exemption),
  m = n − 1 tours ; au tour r, le club fixe (indice m) affronte le club r, à domicile si r
  est impair ; les autres paires sont (r + k, r − k) modulo m, la première citée recevant
  si k est impair.
- Chaque club n’a qu’une rupture d’alternance par phase, n − 2 ruptures en tout, le
  minimum possible pour un aller simple.
- L’aller commence au troisième tour du cercle (r = 2) : aucun club n’a alors sa rupture à
  la première ni à la dernière journée, et le retour (miroir de l’aller, domicile et
  extérieur inversés) ne crée jamais une troisième rencontre consécutive au raccord.
- Résultat pour tout n de 2 à 32 sauf 4 : au plus deux rencontres de suite au même
  endroit, réceptions exactement égales aux déplacements en aller-retour.
- Déterministe : le calendrier ne dépend que de l’ordre des clubs fourni (partition de la
  saison) ; aucun tirage aléatoire n’est consommé.

Quatre clubs en aller-retour en miroir : une série de trois est mathématiquement
inévitable (vérifié exhaustivement : 6 ordres × 64 orientations). Sans l’exigence de miroir,
un retour décalé d’une journée (aller A B C, retour B C A inversés) descend à deux pour
toutes les tailles ; ce n’est pas appliqué ici, la consigne étant le miroir.

URC (quatre boucliers de quatre, 18 journées : 12 adversaires une fois, les 3 du bouclier
deux fois) : aucun cercle classique ne couvre ce format. Le générateur utilise un gabarit
de 18 journées obtenu hors ligne par recherche locale sur la factorisation « ou exclusif »
de 16 clubs (les trois journées intra-bouclier forment exactement les quatre boucliers),
puis vérifié par `tests/schedule-alternance.cjs` : 9 réceptions, au plus deux rencontres
de suite au même endroit, 4 ou 5 réceptions par moitié de saison, retour d’un derby au
moins six journées après l’aller. Les emplacements suivent l’ordre d’apparition des
boucliers et des clubs dans la liste fournie.

## Anciennes sauvegardes

Choix : accepter les deux formes, sans migration. Une saison déjà commencée garde son
calendrier enregistré jusqu’à l’intersaison ; la saison suivante est tirée avec le nouveau
générateur.

- France30 (`dist/france-save-validation.js`) : le calendrier enregistré doit égaler le
  nouveau ou l’ancien (`CDFranceCompetition.legacySchedule`). Tout autre calendrier reste
  refusé (« calendrier altéré »).
- Monde (`native/engine/world-career.cjs`) : la relecture recalcule la saison avec le
  nouveau générateur puis, en cas d’écart, avec l’ancien (`legacyCalendar: true`) ; un
  calendrier qui ne correspond à aucun des deux reste refusé.
- Espoirs du centre de formation natif (`native/engine/academy.cjs`) : chaque phase déjà
  tirée (poules préliminaires, phase qualificative, Accession junior) peut porter l’ancien
  ou le nouveau calendrier.
- Mode historique 14 clubs et documents de l’atelier : leur validation ne contrôle que la
  structure (chaque club une fois par journée, chaque confrontation présente) ; les
  anciens calendriers se chargent tels quels.

Les anciens générateurs sont conservés à l’identique (empreintes vérifiées par le test).

## Vérifications

- `tests/schedule-alternance.cjs` : tous les générateurs (France30 avec plusieurs
  partitions, mode historique, Espoirs 2 à 12 clubs, Accession junior, atelier 2 à
  32 clubs simple et aller-retour, élite/accession/Premiership/URC monde avec trois
  ordres de clubs et deux saisons) : chaque club au plus une fois par journée, chaque
  adversaire le bon nombre de fois, aller et retour inversés, retour en miroir, équilibre
  exact, série maximale, déterminisme ; empreintes des anciens générateurs ; import d’une
  sauvegarde France portant l’ancien calendrier accepté, calendrier quelconque refusé.
- Exécutions par l’API publique du worker (hors dépôt) : voir la description de la PR.

## Non vérifié et limites

- Le calendrier réel LNR n’est pas un miroir strict de l’aller ; le jeu garde un retour en
  miroir (abstraction déjà déclarée : calendrier sans dates réelles).
- Les calendriers publiés reconduits (Champ, Nationale, Japon, Super Rugby Pacific,
  saison 1 URC/Premiership/LNR) gardent leurs séries réelles de 3 ou 4.
- La répartition des recettes de billetterie dans la saison suit désormais l’alternance ;
  le total annuel est inchangé. Aucun réglage économique n’a été modifié.
- Aucun essai sous Windows ni dans l’interface Godot.
