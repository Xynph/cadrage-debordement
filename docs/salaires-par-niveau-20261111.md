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
- Les carrières mondiales sont traitées plus bas (« Tous les championnats
  de la base »).

## Tous les championnats de la base

Demande de Léo du 11 novembre : étendre salaires et budget à toute la base,
avec une réputation par championnat. Même drapeau, éteint par défaut.

### Inventaire et chemins de code

La carrière mondiale la plus large (`world-champ`) compte 116 clubs : 14 en
première division française, 16 en deuxième, 14 en troisième, 10 en première
division anglaise, 14 en deuxième, 16 dans le championnat celte, italien et
sud-africain, 10 dans le championnat du Pacifique, 12 et 8 dans les deux
divisions japonaises, 2 clubs invités.

| Sujet | Chemin aujourd'hui, sans la variable |
| --- | --- |
| Salaires de départ | Écrits dans les registres (`native/engine/world-*.json`), sans lien avec le championnat : 8,9 M€ de masse moyenne en deuxième division anglaise, 4,6 M€ en troisième division française |
| Finances du club joué | `financeWeek` (`dist/game.js`), appelé par `native/engine/world-career.cjs`, ligne 369 : même calcul qu'en France |
| Finances des autres clubs | `worldWeeklyEconomy` (`dist/world-career.js`, ligne 87) : 160 000 € par semaine pour tous |
| Intersaison | 2,5 M€ aux clubs gérés avant les prolongations (`dist/world-career.js`, ligne 150), 2,5 M€ au club joué (`native/engine/world-career.cjs`, ligne 385) |

### Repères réels

| Championnat | Repère trouvé | Source |
| --- | --- | --- |
| Première division française | Plafond 10,7 M€ ; masse moyenne 9,9 M€, recettes 33 M€ ; budgets de 17 à 46 M€ | Rapport 2026 sur l'économie des clubs ; [RugbyPass, 26 décembre 2024](https://rugbypass.com/news/every-country-in-the-world-where-you-can-be-paid-to-play-rugby-2) |
| Deuxième division française | Masse moyenne 3,2 M€, recettes 10,7 M€ ; salaire moyen de 75 000 à 85 000 € ; quatre budgets au-dessus de 13 M€ | Rapport 2026 ; RugbyPass, même article |
| Troisième division française | 2 000 à 10 000 € par mois pour un joueur médian. Ni masse ni budget moyen trouvés | RugbyPass, même article |
| Première division anglaise | Plafond 6,4 M£, soit un peu moins de 7,5 M€ ; perte moyenne de 3,4 M£ par club en 2023-2024 ; chiffre d'affaires « type » de 20 M£ | [The42, 17 avril 2025](https://www.the42.ie/urc-salary-cap-6681136-Apr2025/) ; [Planet Rugby, 31 mai 2024](https://www.planetrugby.com/news/how-premiership-clubs-compare-to-south-africas-joke-spending-power) ; [Leonard Curtis, 12 novembre 2025](https://www.leonardcurtis.co.uk/news/leonard-curtis-shines-fresh-light-on-prem-rugby-club-finances-in-new-report) |
| Deuxième division anglaise | Salaire moyen 25 000 £, jusqu'à 70 000 £ ; 133 000 £ de la fédération par club. Aucun budget de club trouvé | RugbyPass, même article ; [RugbyPass, 20 septembre 2024](https://rugbypass.com/news/english-rugby-a-million-miles-away-from-fixing-championship-crisis-paul-turner) |
| Championnat celte, italien et sud-africain | Pas de plafond ; budget de 20 M€ pour la première province irlandaise (2022) ; budgets joueurs gallois de 5 M€ ; plafond sud-africain de 85 M de rands, soit 3,5 M£ | The42 ; RugbyPass ; Planet Rugby |
| Championnat du Pacifique | Plafond néo-zélandais de 4,7 M de dollars par club (environ 2,6 M€) ; salaire de base moyen 195 000 dollars (environ 107 000 €) ; recettes des franchises non publiées | [SA Rugby magazine, 13 août 2026](https://www.sarugbymag.co.za/kiwi-super-rugby-clubs-bleed-cash/) |
| Japon | Un salaire de vedette proche de 1 M€. **Aucun chiffre de masse, de budget ou de salaire moyen trouvé** | RugbyPass, même article |

### La table : `native/engine/league-economy.cjs`

| Championnat | Réputation | Masse moyenne | Recettes moyennes | Plafond | Nature du chiffre |
| --- | --- | --- | --- | --- | --- |
| Première division française | 100 | 9,9 M€ | 33 M€ | 10,7 M€ | Relevé |
| Première division anglaise | 88 | 6,9 M€ | 23 M€ | 7,5 M€ | Plafond relevé ; masse et recettes estimées |
| Celte, italien et sud-africain | 84 | 5,4 M€ | 18 M€ | aucun | Estimation à partir de trois repères |
| Pacifique | 82 | 2,3 M€ | 7,6 M€ | 2,6 M€ | Plafond et salaire moyen relevés ; recettes estimées |
| Première division japonaise | 76 | 6,0 M€ | 20 M€ | aucun | **Estimation** |
| Deuxième division française | 70 | 3,2 M€ | 10,7 M€ | aucun | Relevé |
| Clubs invités | 70 | 4,0 M€ | 13 M€ | aucun | **Estimation** |
| Deuxième division japonaise | 52 | 2,0 M€ | 6,6 M€ | aucun | **Estimation** |
| Troisième division française | 50 | 1,4 M€ | 4,6 M€ | aucun | Estimation à partir de la fourchette de salaires |
| Deuxième division anglaise | 48 | 1,1 M€ | 3,6 M€ | aucun | Salaire moyen relevé ; recettes estimées |

La réputation est un choix de jeu : la première division française est la
référence. Les recettes estimées sont posées à 3,3 fois la masse, comme en
France, pour qu'un club moyen reste près de l'équilibre. La répartition des
recettes de chaque championnat (partenaires, ligue ou fédération,
billetterie) est estimée hors de France. La règle des 52 % ne s'applique
qu'aux trois divisions françaises.

### Salaires

La règle de la version 3 s'applique partout (courbe, poste, politique du
club, âge, histoire, espoirs). Hors des deux premières divisions françaises,
les salaires sont ensuite multipliés par un facteur propre au championnat,
calculé à la création pour que la masse moyenne rejoigne la table. Le facteur
est gardé dans la marque (`S.startingSalaries.calage`).

Mesure, carrière `world-champ`, graine 27, par l'API publique :

| Championnat | Avant : masse moyenne | Après : min / moyenne / max | Cible | Salaire moyen des 34 mieux payés du club | Facteur |
| --- | --- | --- | --- | --- | --- |
| Première division française | 18,4 M€ | 7,95 / 9,74 / 12,97 | 9,9 | 248 000 € | 1 |
| Première division anglaise | 16,2 M€ | 4,86 / 6,90 / 8,97 | 6,9 | 150 000 € | 1,077 |
| Celte, italien et sud-africain | 16,6 M€ | 3,28 / 5,40 / 7,31 | 5,4 | 128 000 € | 0,957 |
| Pacifique | 11,7 M€ | 1,51 / 2,30 / 3,46 | 2,3 | 65 000 € | 0,524 |
| Première division japonaise | 12,2 M€ | 3,72 / 6,00 / 9,04 | 6,0 | 149 000 € | 0,894 |
| Deuxième division française | 16,1 M€ | 2,63 / 3,42 / 5,15 | 3,2 | 89 000 € | 1 |
| Clubs invités | 13,6 M€ | 2,66 / 4,00 / 5,33 | 4,0 | 105 000 € | 0,899 |
| Deuxième division japonaise | 7,1 M€ | 1,49 / 2,00 / 3,05 | 2,0 | 48 000 € | 0,675 |
| Troisième division française | 4,6 M€ | 0,91 / 1,40 / 1,98 | 1,4 | 37 000 € | 0,678 |
| Deuxième division anglaise | 8,9 M€ | 0,80 / 1,11 / 1,51 | 1,1 | 28 000 € | 0,382 |

Face aux repères : 28 000 € en deuxième division anglaise pour 25 000 £
relevés (29 000 €) ; 65 000 € dans le Pacifique pour un salaire de base moyen
de 107 000 € (le jeu compte 40 joueurs par franchise, le chiffre réel en
compte moins et la fédération paie en plus) ; 37 000 € en troisième division
française pour une fourchette de 24 000 à 120 000 € par an.

### Budget

Le budget de club (recettes, charges, propriétaire, prime de classement,
clôture) s'applique aux 116 clubs avec les chiffres de leur championnat. Une
saison mondiale dure 46 semaines : chaque semaine paie 52/46 de salaire. Un
match de poule européenne à domicile rapporte une recette ordinaire en plus ;
un match éliminatoire, 1,5 fois une recette complète.

Une saison mondiale complète puis `next_season`, manager dans un club de
première division anglaise (club 30, propriétaire entreprise, enveloppe
1,55 M€), graine 27. Trésorerie des autres clubs en M€, min / médiane / max :

| Championnat | Départ | Mi-saison (semaine 23) | Fin (semaine 46) | Après l'intersaison |
| --- | --- | --- | --- | --- |
| Première division française | 2,50 / 4,80 / 7,50 | 0,83 / 5,22 / 8,71 | 1,66 / 5,09 / 9,02 | 3,62 / 6,07 / 9,09 |
| Deuxième division française | 2,00 / 2,70 / 3,60 | 1,09 / 2,48 / 3,95 | 0,37 / 1,95 / 3,18 | 1,67 / 2,67 / 5,67 |
| Troisième division française | 2,60 partout | 2,42 / 2,61 / 2,66 | 2,09 / 2,52 / 2,61 | 2,30 / 2,60 / 3,35 |
| Première division anglaise | 4,00 partout | 4,16 / 4,54 / 5,66 | 2,52 / 3,82 / 7,96 | 3,88 / 4,15 / 9,07 |
| Deuxième division anglaise | 3,60 partout | 3,42 / 3,60 / 3,69 | 3,12 / 3,49 / 3,68 | 3,43 / 3,59 / 3,75 |
| Celte, italien et sud-africain | 4,00 partout | 2,92 / 3,76 / 4,31 | 1,27 / 3,01 / 5,64 | 2,67 / 4,55 / 7,34 |
| Pacifique | 4,00 partout | 2,51 / 3,12 / 3,31 | 2,81 / 3,44 / 3,73 | 3,13 / 4,04 / 4,39 |
| Première division japonaise | 4,20 partout | 2,32 / 3,64 / 3,93 | 2,31 / 3,99 / 4,74 | 3,66 / 4,21 / 4,53 |
| Deuxième division japonaise | 3,40 partout | 3,04 / 3,25 / 3,38 | 2,80 / 3,34 / 3,71 | 3,24 / 3,38 / 4,25 |
| Clubs invités | 4,00 partout | 2,02 / 3,16 | −0,36 / 1,99 | 2,77 / 3,43 |

Club joué : 4,00 M€ au départ, 5,15 à mi-saison, 4,71 à la fin, 5,72 après
l'intersaison (7e sur 10, prime de 1,01 M€, saison dans le vert de 1,73 M€,
aucun apport). Aucun club endetté ; un club invité finit sous zéro avant la
clôture. Export puis réimport après l'intersaison : accepté, texte identique.

Masses après l'intersaison (clubs gérés remis au niveau de la règle) : de
−5 % (première division japonaise) à +28 % (deuxième division anglaise,
1,41 M€ pour 1,1) par rapport à la cible ; +21 % dans le Pacifique. Cause
probable, non vérifiée : les joueurs ajoutés à l'intersaison et la
progression des notes. Un club relégué garde ses salaires de première
division (10,2 M€ en deuxième division française).

### Réputation dans les choix des joueurs

Le jeu décide qu'un joueur signe quand le salaire offert atteint son seuil :
`reservationWage` (`dist/economy.js`, ligne 424), soit 86 à 93 % du salaire
demandé (`askingWage`, ligne 388). Pour les carrières marquées, le salaire
demandé au club joué est recalculé :

- prolongation : la base n'est plus l'ancien barème (`dist/economy.js`,
  ligne 346, environ 383 000 € par an pour un joueur noté 75) mais le salaire
  de la version 3 pour ce joueur dans ce club ;
- recrue : même salaire de la version 3, multiplié par l'attrait du
  championnat.

| Cas | Effet sur le salaire demandé |
| --- | --- |
| Vers un championnat plus réputé | Jusqu'à −8 % |
| Vers un championnat moins réputé | Jusqu'à +18 % |
| Joueur « casanier » (un sur quatre) qui change de pays | +8 % |
| Joueur « voyageur » (15 %) qui change de pays | −4 % |
| Joueur « ambitieux » (15 %) | Effet de la réputation multiplié par 1,5 |
| 31 ans et plus, vers le Japon | Plus de prime pour descendre, et −6 % |
| Chaque joueur | ±3 % selon son humeur |

L'effet est borné entre −15 % et +30 %. Il ne dépend que de l'identité du
joueur, de son âge et des deux championnats : rien ne révèle son niveau.
L'origine d'un joueur du marché vient de son dernier club connu, sinon de son
identifiant dans la base ; inconnue (jeunes des petits clubs), la réputation
ne joue pas.

Taux d'acceptation d'une même offre, 5 000 joueurs tirés, contrat de deux
ans (calcul sur la formule du jeu, `/home/claude/audit/acceptation.cjs`) :

| Origine → destination | Demande moyenne | Offre au salaire juste | Offre à 95 % | Offre à 90 % | Offre à 95 %, joueur de 33 ans |
| --- | --- | --- | --- | --- | --- |
| 2e division anglaise → 1re française | −7 % | 100 % | 99 % | 90 % | 99 % |
| 2e française → 1re française | −9 % | 100 % | 100 % | 100 % | 100 % |
| 1re anglaise → 1re française | −3 % | 100 % | 93 % | 74 % | 93 % |
| Même championnat | 0 | 100 % | 98 % | 57 % | 98 % |
| 1re française → 1re anglaise | +9 % | 70 % | 31 % | 4 % | 31 % |
| 1re française → celte | +12 % | 52 % | 16 % | 1 % | 16 % |
| 1re française → 2e française | +19 % | 2 % | 0 % | 0 % | 0 % |
| 1re française → 1re japonaise | +17 % | 20 % | 2 % | 0 % | 100 % |
| Pacifique → 1re japonaise | +5 % | 88 % | 61 % | 19 % | 100 % |

### Ce que cette extension a révélé

- **Les prolongations et les recrues revenaient à l'ancien barème.** Le club
  joué : corrigé par le salaire demandé ci-dessus. Les clubs gérés
  (`dist/ai-roster-cycle.js`, lignes 73 et 370 : plancher de 1 000 puis
  2 000 € par semaine) : à chaque intersaison, leurs contrats sont remis au
  niveau de la règle (`recaler`). Conséquence assumée : chez eux, un joueur
  qui progresse est augmenté dès l'été suivant.
- **Le moteur refusait toute offre sous 1 000 € par semaine** (52 000 € par
  an) : `dist/economy.js`, fonction `negotiateContract`, et
  `native/engine/gestion.cjs`, ligne 59. Corrigé depuis pour les carrières
  marquées (plancher de la règle, voir la suite ci-dessous).
- Le marché entre clubs (`native/engine/interclub-market.cjs`) a le même
  plancher et n'est pas branché dans le moteur livré ; il n'a pas été touché.

## Suite du 11 novembre : plancher, clauses, attrait recalé

Tout reste derrière `CD_SALAIRES_PAR_NIVEAU=1`, pour les carrières marquées.

- **Plancher des contrats** : 270 € par semaine (14 000 € par an), celui de
  la règle des salaires, au lieu de 1 000 €. La validation de sauvegarde
  l'accepte pour ces carrières. Un espoir signe à 20 800 € par an (testé par
  la commande publique, export, réimport et reprise).
- **Clauses de montée et de descente** propres à chaque joueur : baisse de 8
  à 25 % en cas de descente pour sept joueurs sur dix, prime de 5 à 20 % en
  cas de montée pour six sur dix.
- **Clubs gérés** : la masse qu'ils s'autorisent suit le plafond de la ligue,
  les 52 % des recettes (France) et leurs moyens, avec une marge propre à
  chaque club. À la création, aucun ne dépasse.
- **Écran Finances** : il lit le budget de la saison (propriétaire, plafond,
  marge, amende encourue) au lieu des anciennes prévisions.
- **Renforts d'urgence** (espoir promu pour compléter la feuille de match) :
  au plancher de la règle au lieu de 2 500 € par semaine (`dist/rugby.js:14`).
- **Joueurs de complément** (40 professionnels par club) : au salaire de la
  règle dans leur club au lieu de 1 400 à 2 200 € par semaine
  (`native/engine/professional-depth.cjs:44`).
- **Saisons sans club** : un joueur libéré à la fin de la saison N n'a passé
  aucune saison sans club pendant la saison N + 1. Le levier partait une
  saison trop tôt ; corrigé.

### Attrait recalé (décision de Léo : « assez réaliste, tout en restant jouable »)

Cible : un joueur de première division française accepte de descendre en
deuxième division ≈10 à 20 % du temps à salaire égal, ≈50 % à +15-20 %, la
plupart à +30 %. Réputations resserrées en tête (anglaise 92, celte 90,
Pacifique 86) ; prime de descente faible entre championnats proches ; Japon :
prime nette jusqu'à 29 ans, attrait fort à partir de 31 ans ; tempéraments
casanier, voyageur, ambitieux, pragmatique ; leviers sans rapport avec le
niveau (peu utilisé, sans club, retour dans un club connu).

Taux d'acceptation recalculés sur la formule du moteur (5 000 joueurs, 27 ans,
seuil du jeu, contrat de deux ans), offre exprimée en part du salaire juste
du club acheteur. Ils remplacent le tableau plus haut, antérieur au recalage :

| Origine → destination | 100 % | 110 % | 115 % | 120 % | 130 % | 33 ans, 100 % / 120 % |
| --- | --- | --- | --- | --- | --- | --- |
| 1re française → 2e française | 13 % | 26 % | 45 % | 71 % | 97 % | 13 % / 71 % |
| 1re française → 1re japonaise | 11 % | 43 % | 68 % | 89 % | 100 % | 100 % / 100 % |
| 1re française → celte | 82 % | 100 % | 100 % | 100 % | 100 % | 82 % / 100 % |
| 1re française → 1re anglaise | 88 % | 100 % | 100 % | 100 % | 100 % | 88 % / 100 % |
| 1re anglaise → 1re française | 97 % | 100 % | 100 % | 100 % | 100 % | 97 % / 100 % |

La cible de Léo est tenue pour la descente en deuxième division française
(13 % à salaire égal, 45 à 71 % à +15-20 %, 97 % à +30 %). Hors de France, le
Top 14 attire bien davantage qu'il n'est quitté : un joueur anglais le rejoint
97 fois sur 100 à salaire égal, un joueur du Top 14 part en Angleterre ou en
URC 82 à 88 fois sur 100 à salaire égal (écart de réputation faible, voir plus
haut). Ces taux restent calculés sur la formule : la mesure ci-dessous montre
que les clubs gérés ne font presque aucun transfert, ils ne sont donc pas
vérifiables par des offres réelles entre clubs gérés.

## Mesure sur deux saisons, carrière mondiale (12 novembre)

Carrière mondiale la plus large (`world-champ`, 116 clubs), graine 27, club
joué 30 (1re division anglaise), API publique du worker, semaines déléguées,
`next_season` à chaque fin de saison. Drapeau allumé ; une première saison
drapeau éteint sert de référence. Code : `main` f05708e2 fusionné. Montants en
M€ par an (salaires hebdomadaires × 52).

La troisième saison n'a pas pu être mesurée : la deuxième a pris 47 minutes
(la machine était partagée) et le processus a été arrêté à la limite de deux
heures pendant la troisième. Deux saisons et deux intersaisons sont donc
consignées.

Masse salariale médiane par championnat (maximum entre parenthèses) :

| Championnat (clubs) | Plafond | Création | Après intersaison 1 | Après intersaison 2 |
| --- | --- | --- | --- | --- |
| 1re française (14) | 10,7 | 9,6 (max 10,4) | 9,8 (max 10,4) | 10,06 (max 10,59) |
| 2e française (16) | — | 3,28 (max 5,15) | 3,07 (max 8,03) | 2,91 (max 7,84) |
| 3e française (14) | — | 1,46 (max 1,98) | 1,54 (max 2,94) | 1,54 (max 2,25) |
| 1re anglaise (10) | 7,5 | 6,99 (max 7,45) | 7,16 (max 7,46) | 6,59 (max 7,37) |
| 2e anglaise (14) | — | 1,13 (max 1,51) | 1,19 (max 1,55) | 1,29 (max 1,49) |
| celte (URC) (16) | — | 5,49 (max 7,31) | 5,65 (max 7,72) | 5,8 (max 8,01) |
| Pacifique (SRP) (10) | 2,6 | 2,32 (max 2,56) | 2,41 (max 2,68), 1 au-dessus | 2,47 (max 2,65), 1 au-dessus |
| 1re japonaise (12) | — | 6,04 (max 9,04) | 6,22 (max 8,92) | 6,34 (max 10,01) |
| 2e japonaise (8) | — | 2,13 (max 3,05) | 2,18 (max 3,7) | 1,95 (max 3,36) |
| invités (2) | — | 5,33 | 5,65 | 5,55 |

| Moment | Masse totale | Au-dessus du plafond | Clubs endettés | Effectif moyen, 1re française | Caisse du club joué |
| --- | --- | --- | --- | --- | --- |
| Création | 486,9 | 0 | 0 | 56,6 | 4,00 |
| Fin de saison 1 | 487,5 | 0 | 1 (invité) | 56,6 | 4,74 |
| Après intersaison 1 | 483,6 | 1 (SRP) | 0 | 51,5 | 5,75 |
| Fin de saison 2 | 485,0 | 1 (SRP) | 1 (invité) | 51,6 | 10,10 |
| Après intersaison 2 | 483,0 | 1 (SRP) | 0 | 46,5 | 10,38 |

Référence drapeau éteint, même graine : masse totale 1 478,7 M€ à la création
puis 1 346,4 après la première intersaison ; médiane 18,7 M€ en 1re française,
17,2 en 1re anglaise, 12,0 dans le Pacifique ; les 34 clubs des trois
championnats plafonnés sont au-dessus de leur plafond ; 5 clubs endettés en
fin de saison 1 (contre 1 drapeau allumé).

Lecture :

- **Stabilité** : la masse totale ne dérive pas (−0,8 % en deux saisons) ;
  aucun club de 1re française ni de 1re anglaise ne dépasse son plafond. Un
  club du Pacifique reste 2 à 3 % au-dessus du sien après chaque intersaison :
  dépassement léger, non corrigé.
- **Endettement** : un seul club, un invité, passe sous zéro en fin de saison
  et revient positif à l'intersaison (apport du propriétaire). Aucun club des
  championnats nationaux n'est endetté.
- **Club joué** : sa caisse passe de 4,0 à 10,4 M€ en deux saisons (+4,4 M€ sur
  la seule saison 2, semaines déléguées). À surveiller : le club joué
  s'enrichit nettement plus vite que les clubs gérés (médiane anglaise 8,1 M€).
- **Mouvements entre championnats** : presque uniquement par montée et
  descente avec le club (saison 1 : 88 joueurs de 2e vers 3e française, 83 en
  sens inverse, 48 de 2e vers 1re, 45 de 1re vers 2e, 50 et 39 au Japon ;
  saison 2 : chiffres voisins). Un seul joueur change de club par saison
  (1re française vers 2e anglaise, puis 2e anglaise vers Pacifique), au même
  salaire. Les clubs gérés de la carrière mondiale ne se transfèrent pas de
  joueurs : départs (596 puis 619, retraites et fins de contrat) et arrivées
  (112 puis 232, jeunes et joueurs libres). C'est vrai aussi drapeau éteint
  (632 départs, 103 arrivées, un transfert) : ce n'est pas un effet de ce
  travail, mais la réputation des championnats ne joue donc que sur les offres
  du manager et sur les joueurs libres.
- **Effectifs** : ils baissent d'environ cinq joueurs par saison (1re
  française 56,6 → 51,5 → 46,5 ; 1re japonaise 54,8 → 41,3). Même pente
  drapeau éteint (56,6 → 49,9) : défaut existant, signalé, non traité ici.
- **Export refusé en fin de saison 2** : « Le fichier est trop volumineux
  (24 Mio UTF-8 maximum pour cette édition) ». L'état persisté fait 31,5 Mo
  (27,8 Mo pour la carrière) : effectifs 14,3 Mo, académies des clubs gérés
  5,2 Mo, encadrement 1,8 Mo, économie 1,7 Mo, marché 1,7 Mo. Ce travail n'ajoute
  qu'environ 20 ko (budget de saison et marque ; salaires et fins de contrat
  existaient déjà). L'export redevient possible après l'intersaison. Défaut
  de l'édition, signalé, non traité ici ; la reprise depuis le disque n'est pas
  concernée.

## Tests

`node --test`, un fichier à la fois, après fusion de `main` (f05708e2),
drapeau éteint puis allumé : `starting-salaries` 14, `club-budget` 26,
`league-economy` 15, soit 55 sur 55 dans les deux cas.

Suites voisines (économie, contrats, budget, finances, transferts, salaires),
un fichier à la fois, drapeau éteint puis allumé : `economy`, `economy-audit`,
`champion-budget-regression`, `ai-transfer-competition`, `coach-market`,
`deepen-market`, `deepen-market-worker`, `finance-planning`,
`finance-v2-playable`, `france-finance`, `interclub-market`,
`staff-contract-quality-audit`, `transfer-planning`, `v31-finance-forecasts`,
`v33-contract-renewals`, `v35-salary-demand`, `v46-v51-contracts`,
`v51-financial-recovery`, `v51-financial-regressions`, `v51-world-finance`,
`v58-2-contract-cycle`, `world-epcr-draw-budget`, `world-finance-ko`,
`world-initial-contracts`, `world-wage-forecast` : tous verts dans les deux
cas. `world-finance-flow-audit` : 5 sur 5 drapeau éteint, 4 sur 5 drapeau
allumé. Le test en échec attend 54 clubs gérés réconciliés avec l'ancien
barème (160 000 € par semaine) et en trouve 0 : l'audit
`ci/world-finance-flow-audit.cjs` modélise les flux remplacés par ce travail.
Attendu tant que l'audit ne connaît pas le nouveau budget ; à adapter avant
toute activation. Les tests Godot (`godot-*`, `deepen-market-ui`) n'ont pas
tourné : SDK absent.

Ce qui suit décrit l'état du premier lot (41 tests).

- `tests/club-budget.cjs` (20 tests, 3 secondes) : recettes, propriétaire,
  prime de classement, affluence, phases finales, règles de la ligue,
  clôture, prévision ; puis dans le moteur du jeu : carrière non marquée
  (ancien calcul vérifié club par club, 2,5 M€ conservés), carrière marquée
  (annonce, une semaine, vente d'un joueur, fin de saison, clôture non
  rejouable, salaire demandé, comptes illisibles).
- `tests/league-economy.cjs` (10 tests, moins d'une seconde) : table,
  salaires calés par championnat, deux divisions de référence inchangées,
  intersaison, demande salariale, attrait (sens, bornes, tempéraments,
  Japon, indépendance du niveau), origine d'un joueur, budget par
  championnat.
- `tests/starting-salaries.cjs` (11 tests, environ 4 minutes) : le vrai
  moteur par l'API publique, France et carrière mondiale, drapeau éteint
  puis allumé, semaine jouée, export, réimport, reprise depuis le disque.

Suites existantes relancées sans la variable après l'extension :
`world-finance-flow-audit` 4 sur 4, `interclub-market` 8 sur 8,
`france-cover` 1 sur 1, `management-france-day-worker` 1 sur 1.

Non vérifié pour l'extension mondiale : une seule graine, un seul club joué
(première division anglaise), deux saisons (mesure du 12 novembre, plus haut) ;
la troisième saison ; les autres éditions mondiales (58, 68, 88 et 102
clubs) ; le taux d'acceptation par des offres réelles dans une carrière
mondiale (il est calculé sur la formule, et les clubs gérés ne transfèrent
presque pas).
