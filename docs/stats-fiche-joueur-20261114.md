# Stats de la fiche joueur = feuille réaliste du match (14 novembre 2026)

Retour de Léo : sur la fiche d'un ailier titulaire de Toulouse (carrière Monde, onglet
Performances), 8 matchs complets donnaient 0 à 3 plaquages, 0 à 28 m et aucun essai par match.

## Cause

Deux calculs coexistaient :

- l'écran de match lisait la feuille réaliste `native/engine/match-stats.cjs`
  (`feuilleStatistiques`, calibrée sur des références réelles, voir
  `docs/stats-match-realistes-20261113.md`) ;
- la fiche joueur (`S.matchNotes`, `native/engine/match-notes.cjs`) comptait les faits bruts du
  journal du moteur : une trentaine de courses racontées par match, d'où 0 à 3 plaquages pour un ailier.

## Correction : une seule source de vérité

- `match-stats.cjs` tient dans une fabrique (`fabrique()`), installée telle quelle dans la VM du
  moteur (`CDMatchStats`, `native-systems.cjs`). Les exports Node ne changent pas.
- À la fin de **chaque match noté** (manager et IA : `enregistrer`, journal du direct ou journal
  transitoire des matchs simulés), `match-notes.cjs` calcule la même feuille que l'écran de match :
  même clé de rencontre (`saison:journée:phase:paire`), mêmes attributs, même journal. Les essais sont
  ceux du journal (mêmes marqueurs), donc la somme des essais des joueurs = essais du match et la
  somme des points = score (vérifié sur tous les matchs d'une saison Monde).
- `noter()` accepte `contexte.feuille` / `contexte.apports` : les chiffres du joueur (essais,
  plaquages, manqués, mètres, courses, franchissements, récupérations, ballons perdus, pénalités,
  passes, offloads, défenseurs battus, points…) viennent de la feuille. Le direct
  (`match-direct.cjs`) passe la même feuille : note du direct = note enregistrée, « Mon XV » = tableau.

## Notes cohérentes avec les stats

`match-stats.apportsNote(feuille)` : écart de chaque joueur au rendement attendu **de son poste
dans ce match** (part du total de son équipe selon les poids `POIDS` du poste et ses minutes) pour
les plaquages (+0,05), plaquages manqués (−0,16), mètres (+0,009/m), défenseurs battus (+0,07),
offloads (+0,06), ballons perdus (−0,1). Somme nulle par équipe et par statistique, bornée à ±0,9
d'impact brut (avant compression). La base 6,5 et l'étalonnage par poste/maillot ne bougent pas en
moyenne ; le XV type (classé sur les notes) n'a pas changé de règle. Les essais comptaient déjà
(+1,5 brut chacun) et restent attribués au même joueur que sur la feuille.

## Sauvegarde (compacte, tolérante)

| Champ | Avant | Après |
|---|---|---|
| `joueurs[id].s` (tous les joueurs du monde) | 7 totaux | 11 : + passes, franchissements, plaquages manqués, points |
| `detail[id]` (effectif du manager) | 9 champs | 19 : + courses, passes, franchissements, manqués, défenseurs battus, offloads, récupérations, ballons perdus, points, pénalités |
| `passees[id]` | 6 champs | 8 : + plaquages, mètres de la saison |

Pas de nouvelle version : les anciennes formes restent valides (la validation accepte les deux), les
totaux sont complétés à zéro au match suivant, les champs absents sont projetés `null` et affichés
« — ». Coût mesuré : +22 Kio sur 4 journées pour 2 463 joueurs notés (≈ +100 à 150 Kio sur une saison).

## Mesures (carrière Monde, `tests/stats-fiche-joueur.cjs`, titulaires, par 80 minutes)

| Poste | Plaquages | Manqués | Mètres | Passes | Essais / match |
|---|---|---|---|---|---|
| Pilier | 6,3 | 0,9 | 14 | 2,0 | 0,06 |
| Talonneur | 8,7 | 1,3 | 16 | 3,0 | 0,03 |
| Deuxième ligne | 9,8 | 1,3 | 16 | 2,8 | 0,03 |
| Troisième ligne | 13,8 | 1,6 | 39 | 3,9 | 0,21 |
| Demi de mêlée | 4,4 | 0,7 | 21 | 60 | 0,18 |
| Demi d'ouverture | 5,8 | 0,9 | 29 | 34 | 0,18 |
| Centre | 8,2 | 1,6 | 49 | 7,3 | 0,17 |
| Ailier | 4,9 | 1,0 | 58 | 4,2 | 0,15 |
| Arrière | 4,2 | 1,0 | 53 | 6,8 | 0,15 |

(4 journées, valeur par défaut du test ; la saison complète se lance avec `CD_STATS_JOURNEES=26`, ~50 minutes.)

## Limites

- Les essais par ailier (~0,15 par match) restent sous la cible de Léo (0,3–0,5) : c'est le nombre
  d'essais **du moteur** (score), que la feuille ne doit pas inventer. Chantier séparé : la
  répartition des essais par poste et le volume d'essais du moteur de match.
- Les attributions déduites (fautif d'une pénalité, plaqueur manqué non nommé) peuvent différer entre
  la feuille et les faits du journal comptés dans la note ; l'apport de la feuille pèse dans le même
  sens que la ligne de stats affichée.
- Matchs internationaux : le moteur ne simule que le score, aucune feuille (inchangé).
