# Balance check : calendrier des mutations v2 (domaine Économie)

> **Date** : 20/11/2026 · **Méthode** : `/balance-check` (kit CCGS), mode autonome, lecture seule · **Cible** : `docs/gdd/calendrier-mutations.md` (§ 3 bis à 3 quinquies, formules et réglages v2) et `native/engine/calendrier-mutations.json` (bloc `clubsGeres`)
> **Verdict global : CONCERNS** (aucun problème bloquant ; deux points à corriger ou trancher avant fusion, quatre à surveiller).

## Sources

| Source | État |
|---|---|
| `temp/mesure-mutations/avant.json` et `.txt` (main, ancien calendrier) | FOUND |
| `temp/mesure-mutations/apres-v2.json` et `.txt` (v2, plancher des clubs gérés actif) | FOUND |
| `temp/mesure-mutations/apres-sans-plancher.json` et `.txt` (comptage des accords invalide, seuls effectifs, caisses, masses, niveaux lus) | FOUND |
| `temp/mesure-mutations/apres-v2-part20.*` (participation hors période 0,2) | FOUND |
| `docs/gdd/calendrier-mutations.md`, `docs/gdd/budget-transferts.md`, `docs/gdd/vente-joueurs.md` | FOUND |
| `native/engine/calendrier-mutations.json`, et lecture du code `calendrier-mutations.cjs`, `interclub-market.cjs`, `club-transfers.cjs` pour les formules de prix | FOUND |
| `design/registry/entities.yaml` | ABSENT : cibles prises dans les GDD |

**Limites de la mesure** (à garder en tête pour tous les verdicts) : une seule graine (4242), un seul passage par variante, 3 saisons, 115 clubs gérés. Les écarts de quelques pour cent ne sont pas distinguables du bruit. Les relevés « fin de saison » sont pris en semaine 45, **avant** la bascule : les 26 + 39 arrivées de la saison 1 ne se voient qu'à la semaine 14 de la saison 2 ; la bascule de la saison 3 n'est pas mesurée du tout (« exécutés n/d »). Les stratégies du joueur ci-dessous viennent de la **lecture du code et des formules, pas d'une partie jouée** : ce sont des ordres de grandeur à confirmer par un script.

## Synthèse des verdicts

| # | Point | Verdict |
|---|---|---|
| 1 | Plafond « salaire × 52 × saisons restantes » : achat du club joué | **À corriger (texte et critère, pas le moteur)** : le plafond ne mord jamais |
| 2 | Boucle achat puis revente (club joué) | Sain (perte structurelle), une variante à surveiller |
| 3 | Pré-contrats du club joué à répétition | À surveiller |
| 4 | Vente à un club géré, indemnité plafonnée | Sain |
| 5 | Volume du marché des clubs gérés (26/48/49 contre 16/27/40) | Sain |
| 6 | Caisses des clubs gérés | Sain |
| 7 | Masses au-dessus de la limite (Pro D2 3 vers 6) | **À corriger** (biais du test de masse) |
| 8 | Dernière semaine du mercato vide | À surveiller (texte à ajuster) |
| 9 | Club joué sans plancher de 40 | À surveiller |
| 10 | Plancher de 40 des clubs gérés | Sain (décision confirmée) |
| 11 | Participation hors période 0,1 | Sain (0,2 et 0,5 confirmés trop chargés) |
| 12 | Cohérence des documents | À corriger (texte) |

## 1. Le plafond d'indemnité ne limite jamais l'achat du club joué : à corriger

Prix d'achat du club joué (`interclub-market.cjs`, ligne 29) : `brut = salaire × semaines × (saisons restantes + 1) / 2`, avec `semaines = wageForecastWeeks` (29 en mode classique ; valeur de la carrière Monde `CDWorldCareer.sizing.rounds` à confirmer, mais inférieure à 52 dans tous les cas plausibles). Plafond v2 : `salaire × 52 × n`, où n = saisons restantes après l'arrivée.

- n = 1 : brut ≈ 29 × salaire, plafond 52 × salaire.
- n = 2 : brut ≈ 43,5 × salaire, plafond 104 × salaire.
- n = 3 : brut ≈ 58 × salaire, plafond 156 × salaire.

Le brut est toujours inférieur au plafond (il faudrait plus de 104 n / (n+1) semaines, soit au moins 52). **Le plafond est inerte pour le club joué.** Le GDD (§ 3 quater 1 et la formule « 468 000 € ») laisse croire que la v2 a rendu l'achat moins cher ou plus encadré : ce n'est pas le cas, le prix du club joué est identique à celui d'avant. Il mord seulement pour :
- les achats entre clubs gérés (`club-transfers.cjs` : prix `52 × min(2, n+1) × facteur d'âge`, jusqu'à 166 × salaire pour un jeune de moins de 24 ans, donc ramené à 52 × salaire quand n = 1), d'où la médiane qui passe de 170 k€ à 120 k€ ;
- les offres reçues par le club joué (§ 4).

Conséquence : un joueur à une saison de contrat s'achète déjà « 0,56 an de salaire », pas « pour presque rien », et ce n'est pas nouveau. Le risque redouté (acheter en mai un joueur à une saison de contrat grâce au plafond) n'existe pas dans le moteur : un joueur dont le contrat s'achève cette saison ne s'achète plus du tout (pré-contrat seulement), et un joueur qui arrive avec n = 1 est, au 1er juillet, **en dernière année de contrat**, donc invendable (`calRaisonVenteFin`).

**Recommandation** : (a) corriger le GDD § 3 quater 1 en disant que le plafond ne s'applique pas au club joué à l'achat, ou (b) si l'intention était de plafonner, passer le brut à `min(brut, plafond)` n'a aucun effet : il faudrait baisser la formule elle-même. Je recommande (a). Ajouter au critère d'acceptation 3 un test « indemnité du club joué ≤ plafond » qui est vrai par construction, pour verrouiller l'invariant si `semaines` ou la formule changent un jour.

## 2. Boucle achat puis revente du club joué : sain, une variante à surveiller

Prix d'achat : fonction du **salaire** (~ 29 à 58 × salaire). Prix de vente : `valeur × (0,78 à 1,02)` avec `valeur = transferValue` (fonction de la note, de l'âge, du potentiel, **indépendante du salaire**), plafonnée à `52 × n × salaire` (v2). Retour au budget : 50 %.

Cycle complet v2 : conclure en mai, arriver le 1er juillet, jouer 3 journées, mettre en vente, conclure, **le joueur ne part qu'au 1er juillet suivant** (douze mois de salaire payés). Pour n = 2 à l'achat :
- coût ≈ 43,5 × salaire (indemnité) + ~29 × salaire (la saison de portage) = **72,5 × salaire** ;
- recette maximale ≈ plafond de vente après un an (n' = 1) = **52 × salaire**.

Le cycle est donc perdant d'au moins 20 × salaire par joueur, quelle que soit la valeur du joueur. **Pas de boucle rentable via l'achat** : le plafond de vente fait ici son travail. La v2 allonge aussi le cycle d'un an (avant : arrivée immédiate en mai, revente possible dès la saison suivante), ce qui réduit le rendement annuel du joueur qui voudrait boucler.

Variante à surveiller : un joueur peut faire monter son propre plafond de vente en prolongeant avec un salaire plus haut (`extend_contract`), car le plafond se calcule sur le salaire courant. Le surcoût de salaire est payé pendant tout le portage (≈ 29 × l'écart), et la recette reste bornée par `valeur × 1,02`, donc l'effet est faible. Pas de correction proposée ; à vérifier dans la mesure du point 3.

## 3. Pré-contrats du club joué à répétition : à surveiller

Coût du pré-contrat : prime de 2 semaines de salaire (arrondie au millier), **sans indemnité**, pas de plafond par saison pour le club joué (les bornes 2 / 2 / 2 ne concernent que les clubs gérés), et aucune protection des « 5 meilleurs » du vendeur (les clubs gérés, eux, les protègent entre eux). Les limites réelles sont la masse salariale, les places, la réserve de 400 k€ et l'enveloppe de transferts (la prime la consomme).

Boucle possible : pré-contrat sur 3 ans, portage d'un an (≈ 29 × salaire), vente à `0,9 × valeur` avec plafond de vente `52 × 2 × salaire = 104 × salaire`. Rentable si `0,9 × valeur > ~31 × salaire`, c'est-à-dire si `valeur > ~35 × salaire`, ce qui est **plausible pour un jeune sous-payé** (ordre de grandeur : un joueur de note 75, potentiel +5, 22 ans vaut environ 430 k€ ; avec un salaire de 6 000 € la semaine, le portage coûte 190 k€). Profit possible de l'ordre de 100 à 200 k€ par joueur et par an, limité par le nombre de joueurs en fin de contrat disponibles (un tiers des contrats par saison) et par la masse. Ce mécanisme existait déjà en v1 (pré-contrat), la v2 ne l'aggrave pas ; il reste le seul chemin où l'indemnité d'entrée est quasi nulle.

**Recommandation chiffrée** : avant fusion ou juste après, lancer un relevé unique (script sur la base de départ) du ratio `transferValue / (salaire demandé × 52)` pour les joueurs en fin de contrat. Seuil d'alerte : plus de 10 % des joueurs avec un ratio > 1,2. Si dépassé : interdire la vente d'une recrue arrivée par pré-contrat avant le 1er juillet suivant son arrivée (« 1 saison complète »), ce qui est déjà le cas en pratique, ou limiter le club joué à 3 pré-contrats par saison (même ordre que les clubs gérés : 2). Ne rien changer sans le relevé.

**Relevé du 20/11/2026** (graines 4242 et 7, janvier de la saison 1, environ 2 000 joueurs éligibles) : 89 % ont une valeur de revente supérieure à 1,2 × un an de salaire demandé (seuil d'alerte de 10 % dépassé). La boucle « pré-contrat (prime de 2 semaines, sans indemnité) puis revente un an plus tard » rapporte en médiane 56 000 € par joueur, jusqu'à 380 000 € (joueur de 23 ans noté 88, 6 800 € par semaine). **Décision** : le club joué est limité à 3 pré-contrats signés par saison (`preContrats.maxParSaison`, plage sûre 2 – 5) ; le 4e est refusé avec une raison écrite.

## 4. Vente d'un joueur du club joué à un club géré, indemnité plafonnée : sain

`calOffresBascule` retire les offres pour un joueur en fin de contrat et plafonne les autres (hors offres contre-proposées, que la relance +5 / +10 / +15 % ne peut de toute façon pas faire dépasser le plafond de l'acheteur). Effet : le plafond rogne seulement la vente de joueurs **sous-payés par rapport à leur valeur** (valeur > 52 × n × salaire), cas normal d'un jeune ou d'une vedette bon marché. Cela ne crée pas d'exploit, ça réduit les recettes.

Deux remarques sans gravité :
- les offres déjà plafonnées puis « Demander plus » repartent d'un montant plafonné : le plafond ne se rattrape pas par la négociation, c'est cohérent ;
- le cash arrive au 1er juillet, la vente choisie rend 50 % au budget **à l'exécution** : voir le point 12 (quelle enveloppe reçoit ce retour).

## 5. Volume du marché entre clubs gérés : sain

| Saison | Avant | v2 | Dont mai-juin | Dernière semaine | Indemnités totales (avant / v2) | Médiane (avant / v2) |
|---|---|---|---|---|---|---|
| 1 | 16 | 26 | 20 (77 %) | 0 | 4,4 / 6,5 M€ | 0,30 / 0,30 M€ |
| 2 | 27 | 48 | 30 (63 %) | 1 | 7,3 / 8,3 M€ | 0,20 / 0,20 M€ |
| 3 | 40 | 49 | 34 (69 %) | 0 | 8,0 / 6,8 M€ | 0,20 / 0,10 M€ |

- Total sur 3 saisons : 83 contre 123 accords (+48 %), pour 19,7 contre 21,6 M€ d'indemnités (+10 %) : le plafond a fait baisser le prix moyen d'environ un quart, le volume monte plus vite que la dépense.
- Aucun accord ne tombe à la bascule (0 / 26, 0 / 48) : les contrôles à la conclusion sont suffisants ; les contrôles de la bascule ne sont donc pas exercés par cette mesure (non évalué, voir limites).
- 39 pré-contrats par saison, tous identiques en nombre (39 / 39 / 39) : ce nombre vient du tirage (1 à 2 par semaine sur 26 semaines), pas de la demande ; et **100 % des rumeurs** (26, 25, 27) se concrétisent. Pour l'agrément : une rumeur qui se réalise toujours est un oracle ; viser 70 % (`rumeurs` : ajouter un taux de réalisation de 0,7). Pas bloquant.
- Pic : 31 à 33 % des accords de la saison tombent en une seule semaine (la 1re de mai : 8/26, 16/48, 16/49). C'est voulu (« temps fort »), mais c'est un mur pour le courrier « Point mercato » : prévoir qu'il tienne à 16 lignes.

## 6. Caisses des clubs gérés : sain

| Fin de saison 3 (sem. 45) | Avant | v2 |
|---|---|---|
| Caisse médiane | 1,4 M€ | 1,7 M€ |
| Clubs en négatif | 9 | 9 |
| Niveau moyen (23 meilleurs) | 78,3 | 77,5 |

Les écarts sont dans le bruit. Les clubs en négatif sont les mêmes types d'avant (catégorie « autre » à −1,5 M€ dans les deux variantes, « champ » 4 puis 5) : problème préexistant, pas causé par la v2. Le détail par saison est équivalent (fin de saison 2 : 4 puis 3 clubs en négatif).

## 7. Masses au-dessus de la limite : à corriger

| | Avant | v2 | Pro D2 (« accession », 16 clubs) |
|---|---|---|---|
| Sem. 14 saison 1 | 12 / 115 | 18 / 115 | 1 puis 1 |
| Sem. 14 saison 2 | 14 | 16 | 2 puis 1 |
| Sem. 14 saison 3 | 17 | 21 | 3 puis **6** |
| Part 0,2, sem. 14 saison 3 | | 22 | |

Lecture honnête : la v2 démarre déjà à 18 en semaine 14 de la saison 1 alors qu'aucun accord n'est encore exécuté (l'ancien calendrier avait déjà fait ses achats de la semaine 13, ce qui lui donnait 12) ; la comparaison juste est donc 18, 16, 21 contre 12, 14, 17 : un écart de **+4 à +6 clubs**, assez stable, **sans dérive croissante**. La hausse « Pro D2 3 vers 6 » est réelle mais isolée (saison 3 uniquement, 1 saison sur 3, une seule graine).

Cause probable (hypothèse, non mesurée) lue dans les règles : le test d'achat et de pré-contrat compte la masse de la saison suivante comme `masse − salaires qui s'achèvent + accords en attente + nouveau salaire ≤ limite` (§ 3 bis 1 et 4), alors que le même GDD dit que « la plupart sont prolongés à la bascule ». Le test **suppose que les contrats qui s'achèvent partent**, la bascule les prolonge, et le club se retrouve au-dessus de sa limite. Les pré-contrats (39 par saison) aggravent le biais.

**Recommandation chiffrée** : dans le test de masse, ne retirer que 30 % des salaires qui s'achèvent (réglage `clubsGeres.masse.partDepartsCompteeEnFinDeContrat` = 0,3, plage 0 à 0,6 ; 0 = conservateur total) au lieu de 100 %. Critère de sortie : à la même mesure de 3 saisons, au plus 17 clubs au-dessus de la limite en saison 3 et au plus 3 en Pro D2, sans baisse de plus de 15 % du volume d'accords (≥ 21 par saison en moyenne). Alternative : faire retirer la prolongation automatique d'un joueur dont l'équipe est déjà au-dessus de la limite (règle plus invasive, à éviter).

## 8. Dernière semaine du mercato vide : à surveiller

0 / 1 / 0 accord dans la dernière semaine, alors que les clubs y tiennent **deux tours**, que le courrier « Dernière semaine du mercato » annonce un « rush final » et que le GDD dit que les clubs gérés font leur rush. Les semaines 40 à 42 portent 0 à 4 accords. La demande est épuisée dès la première semaine de mai (31 à 33 % du total d'un coup) : chaque club n'a que 3 achats par saison et recrute selon un besoin qui disparaît dès le premier tour.

Ce n'est pas un défaut d'économie, c'est une promesse non tenue côté présentation. Deux options chiffrées :
1. **Texte seulement** (recommandé, coût nul) : remplacer « rush final » par un récapitulatif (« X accords conclus, Y encore possibles ») et passer `toursDerniereSemaine` à 1 (sans effet mesuré).
2. **Étaler la demande** : en période des mutations, faire tenir le tour à chaque club avec une probabilité de 0,35 par semaine (tirage déterministe) au lieu de 1, sauf la dernière semaine (1,0). Cible à mesurer : pic de la 1re semaine ≤ 20 % des accords, dernière semaine ≥ 10 % des accords de mai-juin (3 à 4 par saison). Risque : cela réduit le volume total ; vérifier qu'il reste ≥ 40 accords en saison 3.

## 9. Club joué sans plancher de 40 : à surveiller

Mesure sans intervention du manager (club 102 laissé à lui-même) : effectif 40, puis **36, 33, 31** en fin de saison 1, 2, 3 (avant : 40 constant par complément automatique), avec une caisse équivalente (3,7 / 1,2 / 0,9 M€ contre 3,6 / 1,1 / 0,8 M€). L'effectif fond d'environ 3 par saison tant que personne ne recrute. C'est normal pour un manager passif, mais cela signifie :

- **stratégie dégénérée possible** : tenir un effectif de 24 à 26 professionnels, faire monter des espoirs aux frais de la maison à chaque blessure ou suspension, et économiser la masse des remplaçants. La limite naturelle est la qualité (les espoirs sont plus faibles) et le moral ; non mesurée ici ;
- la garde d'effectif du club joué vendeur (feuille de 23 conforme + 2 par famille) est le bon garde-fou, mais aucun test ne vérifie qu'un manager peut descendre sous ~30.

**Recommandation** : relever, sur une partie de 3 saisons avec un manager actif minimal, le nombre de feuilles de 23 complétées par des espoirs (alerte « Effectif trop juste » déclenchée). Seuil : si plus de 4 matchs par saison sont complétés par des espoirs sans blessures massives, ajouter un coût de maintien (masse minimale ou prime d'entretien) ; sinon, ne rien changer. En attendant, ne pas descendre sous 31 sans alerte visible (alerte déjà prévue en § 3 quater 5).

## 10. Plancher de 40 des clubs gérés : sain (décision confirmée)

Sans plancher, la saison 3 compte un club à 29 professionnels et **4 clubs sous 37** (7 en saison 1, 2 en saison 2), pour un gain d'économie non mesurable (caisse médiane 1,8 M€ contre 1,7 M€, 3 puis 11 clubs en négatif en fin de saison 3 contre 9). Garder le plancher est la bonne décision ; le gain de simplicité du retrait ne justifie pas des clubs à 29.

## 11. Participation hors période : sain

| Réglage | Accords saisons 1 / 2 / 3 | Part en mai-juin | Clubs au-dessus de la limite, saison 3 | Clubs en négatif en fin de saison 3 |
|---|---|---|---|---|
| 0,1 (retenu) | 26 / 48 / 49 | 63 à 77 % | 21 | 9 |
| 0,2 | 31 / 57 / 50 | 40 à 74 % | 22 à 23 | 10 |

0,2 déplace le marché vers l'hiver (22 accords d'hiver en saison 3 contre 10), sans gain d'agrément évident et avec un peu plus de clubs en négatif et en dépassement. 0,1 est confirmé. Plage de réglage (0,05 à 0,5) : relever le bas à 0,05 reste sûr ; au-dessus de 0,2, ne pas aller sans nouvelle mesure.

## 12. Cohérence des documents : à corriger (texte)

- `vente-joueurs.md` § 3 règle 8 dit encore « Pendant la période : exécution immédiate » et règle 11 « s'exécutent au 1er mai » : c'est le v1 ; le GDD des mutations dit « le texte ci-dessous (v1) reste vrai sauf la date », mais la date est précisément ce qui change. Mettre un renvoi explicite en tête du § 3 de `vente-joueurs.md`.
- `budget-transferts.md` R2 : l'indemnité d'un accord est **engagée à la conclusion** (en mars, par exemple, sur l'enveloppe de la saison courante) et le joueur arrive au 1er juillet. À préciser : si l'accord tombe à la bascule, le montant revient à l'enveloppe de quelle saison (la saison close ou la nouvelle) ? Idem pour les 50 % rendus par une vente choisie exécutée au 1er juillet : enveloppe de la nouvelle saison ? Non vérifié dans le code ; à décider et à écrire. Recommandation : toujours **la nouvelle saison**, pour qu'aucune enveloppe close ne reçoive d'argent.
- `calendrier-mutations.md` § 3 quinquies, tableau « Masse hebdomadaire médiane, clubs au-dessus de la limite : 17 / 21 » : la comparaison utile est par saison (voir point 7), pas seulement la saison 3.

## Recommandations

| Priorité | Problème | Correction | Effet attendu |
|---|---|---|---|
| 1 (avant fusion) | Test de masse optimiste (point 7) | Ne retirer que 30 % des salaires qui s'achèvent, réglage `partDepartsCompteeEnFinDeContrat` | Au plus 17 clubs au-dessus de la limite en saison 3, au plus 3 en Pro D2 |
| 2 (avant fusion) | Plafond inerte pour le club joué, texte trompeur (point 1) | Corriger le GDD § 3 quater 1 et ajouter un test d'invariant | Plus de fausse promesse de réglage |
| 3 (avant fusion) | Documents contradictoires (point 12) | Renvoi v2 dans `vente-joueurs.md` ; trancher l'enveloppe qui reçoit les retours à la bascule | Plus d'ambiguïté d'implémentation |
| 4 | Dernière semaine vide (point 8) | Texte du courrier (option 1) ; option 2 si on veut un vrai rush | Promesse tenue |
| 5 | Pré-contrats du club joué (point 3) | Relevé du ratio valeur / salaire ; plafond de 3 par saison si > 10 % des joueurs ont un ratio > 1,2 | Ferme la seule boucle à coût d'entrée nul |
| 6 | Club joué sans plancher (point 9) | Relevé des feuilles complétées par des espoirs ; seuil 4 matchs par saison | Détecte l'effectif minimal exploité |
| 7 | Rumeurs toujours vraies (point 5) | Taux de réalisation 0,7 | Presse moins prévisible |

## Valeurs qui demandent attention

| Valeur | Actuelle | Proposition | Raison |
|---|---|---|---|
| `clubsGeres.masse.partDepartsCompteeEnFinDeContrat` (nouveau) | 0 (implicite : tous les départs retirés) | 0,3 (0 à 0,6) | Les contrats qui s'achèvent sont en majorité prolongés |
| `toursDerniereSemaine` | 2 | 1 si option 1 du point 8 ; inchangé si option 2 | Le second tour ne produit rien |
| `rumeurs` | 100 % se réalisent | taux 0,7 | Évite un oracle fiable |
| `participationHorsPeriode` | 0,1 | inchangé | Mesures 0,2 et 0,5 plus chargées |
| `plancherIndemnite` | 10 000 € | inchangé | Aucun accord observé au plancher |
| `preContrats.parSemaine` (clubs gérés) | 2 | inchangé | Nombre fixé par le tirage, pas par la demande |
| Pas de plage cible dans le GDD | | à écrire | Le GDD ne donne pas de cible chiffrée pour « clubs au-dessus de la limite » ni « accords par saison » : les verdicts 5 et 7 sont jugés contre l'avant, pas contre une cible. À ajouter |

## Non évalué (annoncé)

- Bascule de la saison 3 (49 accords et 39 pré-contrats exécutés) : pas dans la mesure.
- Effet des arrivées de la bascule sur les masses : visible seulement à la semaine 14 de la saison suivante (déjà utilisé ci-dessus).
- Variance entre graines : une seule graine.
- Rentabilité réelle des boucles du joueur (points 2 et 3) : estimée par les formules, pas jouée. `wageForecastWeeks` de la carrière Monde non lu.

Relancer `/balance-check` après les corrections 1 à 3.
