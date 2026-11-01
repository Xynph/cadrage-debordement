# DATA-06 — 350 années supplémentaires vérifiées

Collecte du 1er novembre 2026 sur la branche de la PR #160, en rôle PRODUCTEUR.
Aucune fusion, activation du mod, modification du moteur ou des sauvegardes.

## Résultat et couverture

Le précédent audit reliait 894 années à des identifiants LNR ; le complément
Diogo Hasse Ferreira en ajoutait une. Les deux nouveaux fichiers apportent
**350 autres identifiants LNR uniques**, absents de ces 895 : **1 245 / 1 592**
avec une année sourcée et rattachée, **347 restants**. Le JSON de l'ancien audit
reste un instantané historique à 894 ; il n'a pas été réécrit.

- `birthyears-six-clubs-verified-2026-11-01.json` : 162 années, provenant des
  tableaux Wikipédia complets, des biographies explicitant les noms complets
  et des sources officielles Section Paloise et VRDR.
- `birthyears-itsrugby-verified-2026-11-01.json` : 188 autres années, après
  lecture effective de 210 fiches publiques ItsRugby des 30 clubs. Parmi les
  22 autres tentatives, 15 dates sont absentes ou invalides et 7 années sont
  déjà dans le premier complément. Aucune tentative laissée en arrière-plan.

| Club prioritaire | Nouvelles années de ce lot | Couverture cumulée LNR | Restantes |
| --- | ---: | ---: | ---: |
| Dax | 6 | 31 / 36 | 5 |
| Nevers | 39 | 48 / 61 | 13 |
| Soyaux-Angoulême | 34 | 41 / 51 | 10 |
| Valence Romans | 29 | 35 / 40 | 5 |
| Narbonne | 36 | 42 / 48 | 6 |
| Nice | 40 | 48 / 51 | 3 |

Les six clubs reçoivent 184 nouvelles années ; les autres clubs, 166.
Les 42 lacunes restantes des six clubs et les autres lacunes du catalogue ne
doivent pas être présentées comme résolues. Aucun effectif exhaustif au
1er juillet 2026 n'est revendiqué.

## Décalage Wikipédia 2025-2026 / 2026-2027 résolu

Les pages directes et leurs six versions permanentes ont réellement été
téléchargées. Leurs tableaux ont exactement les mêmes lignes factuelles et
leurs titres indiquent tous `Effectif 2026-2027`. Les anciens aperçus indexés
ne sont pas employés comme preuve de saison.

| Club | Révision permanente | Dernière modification publiée |
| --- | --- | --- |
| Dax | 239388447 | 10/09/2026 |
| Nevers | 240519421 | 19/10/2026 |
| Soyaux-Angoulême | 239094469 | 30/08/2026 |
| Valence Romans | 239093909 | 30/08/2026 |
| Narbonne | 240802046 | 28/10/2026 |
| Nice | 240235189 | 10/10/2026 |

Chaque source conserve son URL, sa révision le cas échéant, sa date de collecte
et le SHA256 du HTML effectivement lu. Les faits retenus sont conservés avec
le nom et la date tels que publiés. Les pages complètes, images et biographies
ne sont pas redistribuées.

## Identités et contradictions

Le catalogue DATA-03 reste la référence des 1 592 ID LNR. Les rapprochements
exigent le nom complet normalisé et le club, ou un nom complet explicitement
publié dans la biographie. Aucun rapprochement flou ou par position de tableau.
Les identifiants source ItsRugby des effectifs de #155, également conservés
sans modification sur #158 `fe0707710df48f07da1e9b889bbc390bc24d8e76`, sont
contrôlés dans l'URL et dans le nom du `Person` JSON-LD de chaque fiche.

Treize identifiants source apparaissent dans plusieurs effectifs ItsRugby :
ils sont retenus uniquement lorsque toutes les occurrences ont exactement le
même nom normalisé, qu'il n'existe qu'un seul joueur de ce nom dans tout le
catalogue LNR et qu'une occurrence correspond au club LNR attendu. Ces
occurrences sont toutes conservées dans le nouveau complément ; elles ne
prouvent pas l'appartenance à un club au départ d'une carrière. C'est une
preuve de naissance individuelle, pas une mise à jour des mutations.

Les dates `0000-00-00`, absentes ou calendaires invalides sont exclues. Aucune
année n'est déduite d'un âge. Le contrôle supplémentaire des âges LNR de #158
n'a révélé aucun écart incompatible parmi les observations retenues auxquelles
ce contrôle pouvait s'appliquer.

- **Alexis Levron, `lnr:1932`** : le tableau du club Wikipédia contient une
  mauvaise année. La source officielle Section Paloise donne explicitement
  le **2 novembre 2000**, conforme à sa biographie individuelle. Seule 2000
  est retenue.
- **Dylan Idrissi, `lnr:11779`** : le site officiel VRDR répète le même nom
  avec deux années différentes. Le joueur est exclu de ce complément en
  attente de résolution, même si d'autres annuaires donnent 2003.
- Les noms abrégés sans preuve explicite de nom complet, les homonymes et les
  sources ne publiant qu'un âge restent non rapprochés. Ainsi la fiche de
  Johan Wasserman né en 1977 n'est pas attribuée au jeune Johan Georg Wasserman.

## Vérification et réception

`node --test tests/data06-birthyears-six-clubs.cjs` : 10 tests ciblés couvrant
identité LNR, club, URL, nouveauté, absence de doublons entre compléments,
provenance, saison/révisions, dates valides, conflits et bilan des 210 fiches.
Tests réalisés localement ; suite complète du jeu et CI distante à vérifier
sur la tête publiée. Aucun appel Firecrawl ou service payant.

Importer ultérieurement uniquement les `records`, conserver la provenance,
ajouter chaque ID une fois, préserver les données précédentes. Les éventuels
conflits avec d'autres champs restent à examiner par l'intégrateur. Les champs
`validAtCareerStart` restent explicitement `null`.

Priorité suivante : résoudre les 42 lacunes prioritaires par sources officielles
et preuves d'identité, puis les 305 autres lacunes, sans transformer un âge ou
un alias plausible en année vérifiée. PR #160 reste non fusionnée.
