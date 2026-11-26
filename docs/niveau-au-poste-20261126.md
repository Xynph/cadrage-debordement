# Niveau au poste (lot K2, 26/11/2026)

## Ce qui change dans le match

Avant, chaque titulaire pesait 1/15 dans l'écart de niveau entre les deux équipes : un pilier, un ailier ou un arrière
bien plus faible que ses coéquipiers ne changeait presque rien. Désormais, un titulaire **nettement plus faible (ou plus
fort) que la norme de son poste** se sent dans la phase de son poste :

| Poste | Phase touchée |
|---|---|
| Piliers, talonneur (deuxième ligne un peu) | mêlée gardée, pénalités de mêlée |
| Talonneur, deuxième ligne | touche gardée |
| Ailiers, arrière, centres | finition dans les 22 (essais), un peu la percée |
| Troisième ligne, centres, demis | percée ballon en main |
| Buteur | réussite au but (déjà individuelle, inchangée) |

Le joueur ne voit jamais l'effet exact : aucun chiffre ni texte nouveau à l'écran.

## Neutre en moyenne

Chaque titulaire est comparé à la **norme de son poste dans le Monde** : l'écart moyen d'un titulaire de ce poste à la
moyenne de son XV (niveau de match, qualité Mêlée, qualité Touche), mesuré sur les 116 clubs de deux Mondes
(`temp/moteur-match-realisme/k2/normes.cjs`, normes stables d'un Monde à l'autre à 0,4 près). Seul l'**excès au-delà
d'une marge** (environ 1,2 écart type : 5 points de niveau, 8 de Mêlée, 7 de Touche) compte. Une équipe de structure
ordinaire n'a donc aucun effet ; le calage favori / outsider et les scores restent ceux d'avant.

- Jeu courant (`edgePoste`, `dist/rugby.js`) : `parPoint × (excès pondéré de l'attaque − excès pondéré de la défense)`,
  ajouté à la probabilité de percée (0,02 par point) et de finition (0,03 par point) dans `advanceCausalPlay`
  (`dist/restarts.js`). Hors compression de `levelGapChampionnat` (qui écrasait l'effet en Top 14). Poids par famille
  dans `NIVEAU_POSTE.percee/finition`.
- Conquête (`uniteConquete`) : qualité de l'unité (moyenne simple, comme avant) + `accent × excès pondéré` des postes
  clés (mêlée : piliers 3,5, talonneur 2, deuxième ligne 0,5, accent 2 ; touche : talonneur 2, deuxième ligne 1,5,
  accent 1,2). Pèse sur la mêlée gardée, la touche gardée et le bénéficiaire des pénalités de mêlée.
- Aucun tirage ajouté. `teamEdge` inchangé (enveloppé par d'autres modules). `NIVEAU_POSTE_RULES=0` : ancien moteur.

Piège corrigé du premier essai : une fonction `niveauForme` existait déjà dans `dist/development.js` (forme pour
l'entraînement, 0 à 4) ; la fonction du niveau au poste s'appelle `niveauPosteForme`.

## Mesures

Voir la description de la PR #1351 (tableau main / branche par poste, calage 3 championnats × 600 et saisons Monde).
Test : `tests/match-niveau-poste.cjs`.
