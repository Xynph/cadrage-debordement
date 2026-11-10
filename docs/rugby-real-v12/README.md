# Rugby Réel V12 — revoir toutes les notes

Les **1 592 joueurs et leurs 57 312 attributs** sont revus dans un candidat complet. Les notes sont des estimations de jeu assumées : elles doivent produire des profils et des matchs crédibles. Les statistiques réelles servent de repères, sans prétendre mesurer directement une vitesse, une technique ou un potentiel.

Base : `512e296467985d95284e1c3c3959b23e569019d2`. Le master, les effectifs, les identifiants, le calendrier et `dist/**` restent intacts. V12 **remplace** les candidats antérieurs sur les notes ; il ne s’ajoute ni à V6/V8/V9/V10 ni à V11.

## Résultat des notes

- 57 312 attributs examinés ; **53 543 valeurs modifiées** dans le candidat.
- 36 attributs conservés ; projection cohérente vers les 11 compétences du moteur.
- Références propres aux 11 familles de postes, avec spécialisations, qualités secondaires et points faibles.
- Capacités moyennes au poste : **76,33 TOP 14 / 68,53 PRO D2**, soit **7,80 points**. Écart par poste : **7,24 à 8,33**.
- Distribution conservant le recouvrement : meilleurs PRO D2 à 78 ; moyenne TOP 14 à 76,33. Aucun changement automatique de qualité à la promotion/relégation.
- Potentiel, six traits cachés, identités, clubs, division et postes du master conservés. Aucun malus de blessure ou de faible temps de jeu inventé.

| Joueur | Ancienne capacité dérivée des 36 notes | Capacité V12 au même poste |
|---|---:|---:|
| Antoine Dupont | 78,82 | 87 |
| Thomas Ramos | 63,87 | 86 |
| Jack Willis | 72,10 | 86 |
| Louis Bielle-Biarrey | 73,22 | 85 |
| Matthieu Jalibert | 76,79 | 87 |
| Setareki Bituniyata | 70,25 | 78 |

Cette capacité est une moyenne pondérée des qualités du poste. **Ce n’est pas la note générale historique du master**, ni exactement le `roleNote()` à 11 compétences du moteur. Les scores de match utilisent bien ce dernier sur les compétences projetées. Le champ historique `rating` et le potentiel historique ne sont pas écrasés : leur échelle doit être raccordée avant activation. 520 comparaisons de capacité/potentiel sont explicitement signalées dans l’audit.

## Comment sont estimées les notes

Le [référentiel V12 des attributs par poste](../../native/engine/role-attribute-priors.json) expose les 36 références pour chacun des 11 postes. L’écart de division est moins marqué pour la discipline, le leadership et les qualités étrangères au poste. Il est plus marqué pour les qualités essentielles. Ces valeurs sont des paramètres de simulation.

L’ancien modèle contient des estimations et du bruit déterministe. V12 retire ses effets moyens de poste/division/âge/mensurations par régression régularisée, puis ne conserve que **35 % d’un résidu individuel borné à ±15**, pour éviter d’effacer toute diversité ou d’ériger ce bruit en vérité. Aucun nouveau hasard fondé sur le nom ou l’identifiant n’est ajouté. Aucune prime de réputation du club.

L’âge et les mensurations disponibles interviennent ensuite une seule fois. Les repères statistiques ont des effets limités et ciblés : exposition/régularité sur activité et décisions ; essais par minute sur portage/placement ; observations défensives sur plaquage ; transformations réussies/tentées sur le but. Plusieurs observations du même total ne sont jamais additionnées. Une faible exposition ne produit pas de malus.

Les distinctions individuelles officielles et évaluations Six Nations fournissent une ancre qualitative bornée sur les qualités techniques/mentales pertinentes. Elles ne modifient ni physique, ni but, ni discipline, ni leadership. Une distinction ne garantit pas une note cible ; aucune note de jeu n’est présentée comme une statistique observée.

## Âge : maturité puis déclin

Les repères initiaux évitent de mettre un joueur de 18 ans à sa pleine maturité et distinguent les qualités : vitesse/explosivité plus précoces, force plus tardive, technique et décisions plus durables. Les pentes sont des choix de jeu, pas des coefficients physiologiques universels.

Les recherches et la proposition d’évolution annuelle par poste sont déjà isolées dans [PR #373](https://github.com/Xynph/cadrage-debordement/pull/373), fichier `docs/rugby-real-v11/age-research.md` : étude FFR/PLOS 2023 des trajectoires d’âge, Barr et al. 2014 sur les qualités de sprint. V12 ne superpose pas ces courbes futures à la calibration de départ. Le raccordement annuel doit réutiliser la progression existante (`development.js`) et les courbes V11, avec compatibilité des sauvegardes ; aucune seconde mécanique de carrière n’est créée ici.

## Données centralisées

- Réutilisation explicite de la collecte V11 : 809 lignes de classements/observations 2025-26.
- Nouvelle collecte publique tentée sur **1 592 fiches LNR** : **325 joueurs** avec historique disponible, **840 lignes de saison** 2023-24 à 2025-26 ; **322 joueurs** ont une ligne 2025-26. Les **1 143 refus réseau 403** et autres absences sont enregistrés comme indisponibles, jamais comme zéro. Aucun contournement ni relance de ces accès.
- 40 lignes de taux de transformations LNR (20 par division), **33 joueurs du master rapprochés**, avec tirs réussis et tentés. Un joueur observé dans deux compétitions garde deux périmètres séparés ; pas de somme abusive.
- Quatre distinctions de la Nuit du rugby 2025-26 et six évaluations individuelles Six Nations 2026 (cinq rapprochées strictement, Cannone absent du master). L’article des distinctions est daté du **28 septembre 2026** : connaissance rétrospective de la saison, pas information prétendue disponible le 1er juillet.
- **627 joueurs** bénéficient d’au moins un repère rapproché ; les autres restent estimés. `evidenceRecordCount` compte des enregistrements, pas des preuves indépendantes.

Sources et périodes sont dans trois fichiers centraux, sans dossier individuel. Collecteurs reproductibles par accès public HTML ; les tests ne sollicitent aucun site extérieur.

## Matchs et management

La campagne finale comporte **5 888 matchs**. PRO D2 moyen / TOP 14 moyen : **24,22 % de victoires et −6,87 points**, contre 31,25 % et −4,46 avant révision des 36 notes. Promu de référence face au TOP 14 moyen : **29,69 %**, puis **31,25 % avec cinq recrues**, écart moyen amélioré de **2,00 points**. Relégué conservé contre PRO D2 moyen : **62,50 %**.

**Limites sportives encore visibles :** face au TOP 14 le plus fort de la grille, le promu gagne encore **40,63 %** (écart moyen −4,30) ; retirer cinq cadres du relégué ne dégrade presque pas son écart moyen (+5,50 → +5,47) et son taux de victoire augmente dans cet échantillon. Les notes seules ne résolvent donc pas toute la hiérarchie ni la profondeur d’effectif. Leurs effets restent limités par les interactions tactiques, la projection des spécialités et les remplaçants de niveaux proches. Ces observations justifient une calibration supplémentaire du raccordement/moteur, pas une hausse automatique de notes à la promotion.

Voir [results.md](results.md) et [measures.json](measures.json) : trois variantes, mêmes graines/domiciles, mêmes IDs de recrues et de départs, vrai `createRugbyMatch → advanceRugby → applyMatchInjuries`. Aucun moteur parallèle, aucun coefficient de résultat modifié.

Les équipes faible/moyenne/forte, le candidat promu et les cinq mouvements sont sélectionnés **une fois selon la qualité V12**, puis figés dans les trois variantes. Seuls les clubs permettant une feuille de quinze titulaires et huit remplaçants entrent dans cette sélection, et chaque scénario est contrôlé avant simulation. Béziers, Brive, Aurillac, Montauban et Valence Romans en sont exclus à cause de postes vacants dans le master, sans leur ajouter de joueurs ni de polyvalence inventée. « Champion » et « relégué » désignent ici des scénarios d’effectif, pas une prédiction des résultats réels. Les budgets/frais de transfert ne sont pas simulés par ce banc de comparaison ; profondeur de banc et effet sportif des recrutements/départs sont mesurés.

Le raccordement des 36 attributs au générateur LNR de production reste à faire dans un fichier réservé. La carrière senior de `main` ne simule pas encore deux divisions et des promotions/relégations : aucun taux de maintien ou remontée sur plusieurs saisons n’est revendiqué. Le contrôle de carrière et la reproduction du défaut de sauvegarde en saison 2 restent dans #373 ; V12 ne change aucun format de sauvegarde.

Les postes restent ceux du master, dont 1 576 sont estimés. Cela laisse des incohérences de profil possibles et limite les classements individuels par poste. Ce candidat améliore les notes sans refaire les effectifs. Les suggestions d’intégration doivent conserver les qualifications de première ligne.

## Utilisation

```sh
node --test tests/rugby-real-full-ratings-v12.cjs
node tools/rugby-real-v12/export.cjs /tmp/v12-ratings
node tools/rugby-real-v12/campaign.cjs /tmp/matches.json 64 candidate
```

`data/scouting/review-v12/candidate.json` contient toutes les notes par ID, ordre des attributs et compétences explicite. L’export produit aussi **ratings-before-after.csv** (1 592 lignes, valeurs avant/après), audit, distributions et leaders. `apply()` travaille sur une copie et refuse une autre base, les candidats empilés, clés déplacées, doublons, compétences ou capacité incohérentes. Il n’est appelé par aucun écran ni import de sauvegarde.

CI dédiée : 13 tests ciblés, reproduction exacte du candidat, invariance du master, campagnes natives sur 64 graines et deux domiciles, rapport comparatif et CSV téléchargeable. La PR reste DRAFT ; seul l’intégrateur peut raccorder puis intégrer.
