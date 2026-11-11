# Salaires de départ liés au niveau

Relevé du 11 novembre 2026 sur `fe79c365` (#539). Suite du constat P1 de
`docs/audit-priorites-cloud-20261111.md` (#549). **Éteint par défaut** : ce
chantier n'est pas prêt à être activé, voir « Limites et points non vérifiés ».

## Le défaut

Le salaire de départ d'un joueur sort d'une empreinte de son identifiant
(`dist/lnr-career.js:54`). Il ne dépend ni de son niveau ni de son club, et
l'indemnité de transfert en découle.

## Les masses salariales du jeu sont fictives

Le jeu paie 34 semaines par saison.

| | Jeu aujourd'hui | Réel, 2024-2025 |
| --- | --- | --- |
| Première division, moyenne par club | 12,3 M€ (11,2 à 14,2) | 9,9 M€, écart de 1 à 2,2 |
| Deuxième division, moyenne par club | 10,7 M€ (8,1 à 13,3) | 3,2 M€, écart de 1 à 3,4 |
| Ce qui fait varier la masse d'un club | Le nombre de joueurs (corrélation 0,97) | — |

Source des chiffres réels : rapport 2026 sur l'économie des clubs de Top 14
et de Pro D2, première moitié lue. Décision de Léo : fictives, donc à adapter.

## Ce que fait `native/engine/starting-salaries.cjs` (version 2)

Décision de Léo du 11 novembre : pas de barème unique. C'est un jeu, il faut
des joueurs sous-payés et des joueurs surpayés, et des clubs qui ne paient
pas tous pareil. Les salaires se paient sur l'année entière.

À la création d'une carrière seulement, quand `CD_SALAIRES_PAR_NIVEAU=1`, le
salaire annuel d'un joueur est une valeur de référence selon son niveau,
multipliée par quatre facteurs :

| Facteur | Effet | D'où il vient |
| --- | --- | --- |
| Poste | 0,84 (talonneur, ailier) à 1,14 (deuxième ligne) | Salaires réels par poste, 2023-2024 |
| Politique du club | 0,8 à 1,3 : un club fort paie plus, chaque club a son tempérament | Choix de jeu |
| Âge | 0,62 à 21 ans, 1,04 de 26 à 30 ans, 1,12 de 31 à 33 ans | Choix de jeu |
| Histoire du joueur | 0,55 à 1,8 : bien ou mal négocié, signé avant de progresser ou de décliner | Choix de jeu |

Référence : 26 000 € à 60 de niveau, 78 000 € à 70, 155 000 € à 75,
255 000 € à 80, 520 000 € à 90. Plancher 14 000 €, plafond 800 000 €.

| Mesure, graine 27 | Avant | Après |
| --- | --- | --- |
| Lien entre salaire et niveau, 1 596 joueurs | −0,01 | 0,84 en première division, 0,78 en deuxième |
| Joueurs de niveau 75 (73 joueurs) | — | de 59 000 à 283 000 € |
| Masse annuelle, première division | 12,3 M€ sur 34 semaines | 8,9 M€ (7,1 à 12,5) ; réel 9,9 |
| Masse annuelle, deuxième division | 10,7 M€ sur 34 semaines | 3,0 M€ (2,2 à 4,4) ; réel 3,2 |
| Salaire moyen, première division | — | 155 000 € ; réel 259 000 € sur des effectifs plus courts |
| Moins de 60 000 € en première division | — | 19 % ; réel 27 % |
| Plus de 480 000 € en première division | — | 3,6 % ; réel 4 % |

### Version 3 : les contrats espoirs

La version 2 donnait 155 000 € de salaire moyen en première division contre
259 000 € dans la réalité. Cause : chaque club de première division compte
dans le jeu une vingtaine de joueurs de 21 ans ou moins, notés 70 en
moyenne, payés comme des professionnels installés. Le chiffre réel porte sur
520 professionnels, soit 37 par club.

Correction : dans chaque club, hors des 34 meilleurs, un joueur de 22 ans ou
moins a un contrat espoir (18 000 à 46 000 € en première division, 14 000 à
30 000 € en deuxième). La référence des professionnels est relevée de 20 %.

| Mesure, graine 27 | Version 3 | Réel |
| --- | --- | --- |
| Première division, masse moyenne | 10,0 M€ (8,2 à 13,3) | 9,9 M€ |
| Première division, moyenne des 37 mieux payés par club | 242 000 € | 259 000 € |
| Première division, les autres (21 par club) | 52 000 € | — |
| Deuxième division, masse moyenne | 3,5 M€ (2,6 à 5,2) | 3,2 M€ |
| Deuxième division, moyenne des 34 mieux payés par club | 90 000 € | — |

Le moteur compte encore les salaires à la semaine et n'en paie que 34 par
saison : le module écrit l'année divisée par 52. **Le paiement sur 52
semaines reste à faire dans le moteur**, avec le budget.

## Budget du club : `native/engine/club-budget.cjs`

Pour les carrières créées avec ces salaires (marque `startingSalaries`), le
calcul hebdomadaire des finances suit les comptes réels 2024-2025. Les autres
carrières gardent l'ancien calcul.

| | Première division | Deuxième division |
| --- | --- | --- |
| Recettes annuelles visées, moyenne | 33 M€ | 10,7 M€ |
| Partenaires / ligue / billetterie / boutique / divers | 45 / 19 / 16 / 8 / 12 % | 48 / 22 / 8 / 4 / 18 % |
| Salaires des joueurs | dus sur 52 semaines, payés sur les semaines de compétition | idem |
| Cotisations | 40 % des salaires | idem |
| Staff et fonctionnement | 58 % des recettes | idem |

Un club moyen qui paie la masse moyenne de sa division finit la saison près
de l'équilibre (test : à moins de 8 % des recettes).

### Ce qui a été ajouté le 11 novembre (suite)

Tout ce qui suit ne vaut que pour les carrières créées avec
`CD_SALAIRES_PAR_NIVEAU=1`. Sans la variable, rien ne change : les tests le
vérifient club par club (voir « Tests »).

| Sujet | Règle |
| --- | --- |
| Clubs gérés par le jeu | Même budget que le club joué : recettes de leur division, salaires dus sur 52 semaines, cotisations, fonctionnement |
| Gestion des clubs gérés | Ils réinvestissent 70 % d'un excédent prévu ; ils économisent jusqu'à 15 % de leurs recettes quand le déficit prévu dépasse ce que leur propriétaire comble |
| Propriétaire | Mécène (comble jusqu'à 12 % des recettes environ), entreprise (6 %), association (rien). Tiré une fois pour toutes selon le club ; un grand club n'est jamais une association |
| Annonce | En début de saison, message du propriétaire avec le montant qu'il comblera |
| Fin de saison | À la place des 2,5 M€ versés à tous : prime de classement, amende éventuelle, puis « Apport du propriétaire » au journal, à hauteur des pertes de la saison et dans la limite annoncée |
| Pertes au-delà de l'enveloppe | Baisse de confiance de 5 à 15 points et message. En dessous de 2 % des recettes, personne ne s'en émeut |
| Prime de classement | Un quart du versement de la ligue dépend du rang final : 2,82 M€ au premier de première division, 0,31 M€ au dernier ; 1,06 M€ et 0,12 M€ en deuxième |
| Billetterie | 40 % en abonnements, versés chaque semaine ; le reste au guichet, de 0,78 à 1,22 fois la recette type selon les cinq derniers résultats |
| Phases finales | Un match éliminatoire à domicile rapporte 1,5 fois une recette complète ; sur terrain neutre, chaque club touche une part de recette |
| Plafond salarial | 10,7 M€ par an en première division |
| Salaires et recettes | Masse des joueurs au plus égale à 52 % des recettes, dans les deux divisions |
| Avertissement | Message de la ligue dès que la masse dépasse une des deux limites, répété toutes les dix semaines |
| Sanction | Constatée sur la masse de la dernière semaine de la saison : amende de la moitié du dépassement (2 M€ au plus) et 6 points de confiance en moins. Les clubs gérés paient la même amende |
| Prévision | `S.clubBudget.prevision`, recalculée chaque semaine (voir plus bas) |

### Les deux défauts trouvés

**1. Les clubs gérés par le jeu s'enrichissaient.** Cause :
`dist/world-career.js`, ligne 87, dans `worldWeeklyEconomy` :
`c.cash+=160000-wage+(home?360000:0)+(won?80000:0)-upkeep`. Chaque club géré
touche 160 000 € par semaine, 360 000 € par réception et 80 000 € par
victoire, quels que soient sa division et ses salaires. Ces montants étaient
réglés sur des masses de 8 à 14 M€ payées en 34 semaines. Avec des salaires
réalistes (un club de deuxième division paie 60 000 € par semaine au lieu de
300 000 €), il reste 5 à 10 M€ par saison. S'y ajoutent 2,5 M€ à chaque
intersaison (`dist/world-career.js`, ligne 166). Correction : pour les
carrières marquées, ces deux calculs sont remplacés par le budget du club
joué. L'ancien code n'est pas modifié.

**2. Plus de billetterie après le 17e match : c'est le calendrier, pas la
billetterie.** Cause : `dist/france-competition.js`, ligne 10, fonction
`schedule`. Le tirage fait alterner domicile et extérieur selon la somme du
numéro de journée et de la place du club dans la rotation, or ces deux
nombres avancent ensemble : la parité ne change pas. Valence (club 29) joue
sa 1re journée à l'extérieur, les journées 2 à 16 à domicile, puis les
journées 17 à 30 à l'extérieur. Sur les 16 clubs de deuxième division, un
seul alterne ; la pire série fait 15 matchs. En première division, la pire
série fait 13 matchs. Chaque club reçoit bien la moitié de ses matchs sur la
saison, donc le total de billetterie est juste ; c'est sa répartition dans le
temps qui est fausse, et le manager enchaîne 14 déplacements.

Ce défaut existe sans la variable. Il n'est **pas corrigé** : la sauvegarde
vérifie que le calendrier est exactement celui de `schedule`
(`dist/france-save-validation.js`, ligne 31), le changer casserait les
carrières existantes. Dans le nouveau budget seulement : les abonnements
(40 % de la billetterie) rentrent chaque semaine, et la recette par match est
divisée par le vrai nombre de réceptions (13 ou 15) au lieu de 17. Ce second
point corrigeait une perte : le premier budget n'encaissait que 76 % de la
billetterie visée en première division et 88 % en deuxième.

### Deux saisons mesurées, graine 27

Trésorerie en millions d'euros. « Avant » : nouvelle économie telle qu'elle
était au commit `b2759a6e`. Une saison complète jouée par l'API publique
(matchs délégués), puis `next_season`.

Manager à Valence (deuxième division, propriétaire entreprise, enveloppe
0,5 M€) :

| Instant | Valence | Première division, autres clubs (min / médiane / max) | Deuxième division, autres clubs | Avant : Valence | Avant : médianes 1re / 2e |
| --- | --- | --- | --- | --- | --- |
| Départ | 2,30 | 2,50 / 4,80 / 7,50 | 2,00 / 2,70 / 3,60 | 2,30 | 4,80 / 2,70 |
| Mi-saison (semaine 17) | 2,46 | 0,20 / 4,26 / 8,43 | 1,01 / 1,98 / 3,97 | 2,71 | 7,66 / 7,74 |
| Fin (semaine 34) | 1,83 | 0,28 / 3,07 / 6,13 | 0,34 / 1,87 / 3,42 | 2,19 | 9,64 / 12,46 |
| Après l'intersaison | 2,30 | 1,79 / 4,88 / 6,75 | 1,61 / 2,70 / 6,40 | 4,69 | 11,94 / 14,49 |

Valence finit 11e : 8,34 M€ de recettes, 8,80 M€ de charges, prime de
classement 431 600 €, apport du propriétaire 35 100 €. Confiance 100.

Manager à Toulouse (première division, propriétaire entreprise, enveloppe
2,7 M€, masse de 12,97 M€ au-dessus du plafond dès le départ) :

| Instant | Toulouse | Première division, autres clubs (min / médiane / max) | Deuxième division, clubs |
| --- | --- | --- | --- |
| Départ | 7,50 | 2,50 / 4,60 / 6,40 | 2,00 / 2,70 / 3,60 |
| Mi-saison | 8,11 | 0,11 / 4,03 / 7,93 | 1,01 / 2,47 / 4,03 |
| Fin | 8,01 | −0,76 / 3,62 / 5,44 | 0,25 / 1,88 / 3,25 |
| Après l'intersaison | 9,31 | 1,64 / 3,85 / 7,22 | 1,88 / 2,80 / 5,80 |

Toulouse finit 3e : 45,3 M€ de recettes, 44,8 M€ de charges, dont une
billetterie de phase finale de 878 300 €. Prime de classement 2,44 M€, amende
de 1,13 M€ pour dépassement du plafond (avertissements reçus à la création et
à la semaine 30), aucun apport. Confiance 96 après la sanction.

Dans les deux saisons : aucun club endetté après l'intersaison, un seul club
géré passe sous zéro en fin de saison (−0,76 M€) avant la prime et l'apport.
Export puis réimport après l'intersaison : accepté, texte identique.

Les trésoreries baissent entre le départ et la fin de saison puis remontent :
le quart du versement de la ligue et l'apport du propriétaire n'arrivent qu'à
la clôture.

### Ce que le futur écran peut lire : `S.clubBudget.prevision`

| Champ | Sens |
| --- | --- |
| `recettesPrevues`, `chargesPrevues`, `resultatPrevu` | Saison entière : déjà réalisé plus le reste au rythme actuel, prime de classement au rang du moment, amende prévue déduite |
| `recettesEncaissees`, `chargesPayees` | Réalisé depuis le début de saison |
| `horsBudget` | Ce qui a bougé la caisse hors du budget courant : ventes et achats de joueurs, primes de signature, travaux |
| `proprietaire` | `type`, `libelle`, `enveloppe` |
| `apportPrevu` | Ce que le propriétaire verserait à ce rythme |
| `masseSalariale`, `plafondSalarial`, `limiteRecettes` | Masse annuelle des joueurs et ses deux limites (`plafondSalarial` vaut `null` en deuxième division) |
| `margePlafond`, `margeRecettes`, `amendePrevue` | Marge sous chaque limite (négative en cas de dépassement) et amende encourue |
| `primeClassementPrevue`, `rang` | Prime au rang actuel |
| `tresorerie`, `tresoreriePrevue` | Caisse actuelle et caisse attendue après la clôture |

`S.clubBudget.clubs` tient un compteur par club (propriétaire, enveloppe,
caisse de départ, recettes, charges, salaires, masse). La sauvegarde accepte
ce champ tel quel ; des comptes illisibles dans une sauvegarde retouchée sont
rouverts au lieu d'arrêter le jeu.

La vente d'un joueur crédite bien la caisse (`acceptSale`,
`dist/economy.js`, ligne 456 : le club acheteur est débité, écriture
« Vente : … » au journal) et entre dans `horsBudget` la semaine suivante.
Vérifié dans le moteur chargé par le test, pas par une commande publique :
le moteur natif n'expose aucune commande de vente à un autre club.

### Limites et points non vérifiés

- Une seule graine (27), deux clubs, une saison et une intersaison chacun. La
  dérive sur cinq ou dix saisons n'est pas mesurée.
- Les clubs gérés ne réagissent pas au plafond salarial : ils paient
  l'amende. Dans cette graine, un seul club dépasse 10,7 M€ à la création
  (Toulouse, 12,97 M€) ; non vérifié sur d'autres graines.
- Un manager peut dépenser l'enveloppe du propriétaire en transferts : les
  pertes comblées comprennent tout ce qui a bougé la caisse.
- Si le manager change de club à l'intersaison, l'annonce lue est celle de
  l'ancien club ; la prévision se corrige à la première semaine.
- L'écran Finances actuel n'affiche rien de tout cela et ses prévisions
  comptent encore 34 semaines de salaires, 160 000 € de partenaires et
  2,5 M€ d'intersaison (`dist/economy.js`, lignes 472 à 597).
- Phases finales : mesurées une fois (Toulouse). Le barrage d'accession et
  une finale sur terrain neutre ne sont couverts que par les tests du module.
- Non mesuré : prolongations, offres d'un club pour attirer un joueur,
  carrières internationales (le budget ne s'applique qu'au mode France).

## Tests

`node --test tests/starting-salaries.cjs tests/club-budget.cjs` : 27 sur 27.

- `tests/club-budget.cjs` (18 tests, 3 secondes) : recettes, propriétaire,
  prime de classement, affluence, phases finales, règles de la ligue,
  clôture, prévision ; puis dans le moteur du jeu : carrière non marquée
  (ancien calcul vérifié club par club, 2,5 M€ conservés), carrière marquée
  (annonce, une semaine, vente d'un joueur, fin de saison, comptes
  illisibles).
- `tests/starting-salaries.cjs` (9 tests, environ 2 minutes) : le vrai
  moteur par l'API publique, drapeau éteint puis allumé, une semaine jouée,
  export, réimport, reprise depuis le disque, deuxième semaine après reprise.

Suites existantes relancées sans la variable : `world-finance-flow-audit`
4 sur 4, `interclub-market` 8 sur 8, `france-cover` 1 sur 1,
`management-france-day-worker` 1 sur 1.
