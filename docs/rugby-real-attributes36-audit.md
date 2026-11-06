# Rugby Réel 2026-2027 — audit indépendant des 36 attributs

## Périmètre
Audit **en lecture seule** de `modding/data06/rugby-master-2026-2027.json` : 1 592 joueurs attendus et 36 champs dans `attributesV2`. Aucune note, identité, effectif, calendrier, sauvegarde, interface ou moteur modifié. Ne pas fusionner cet audit avec l'ancienne PR #361 (11 attributs, annulée).

## Exécution
```sh
node tools/rugby-real-attributes36-audit.cjs > /tmp/rugby-real-attributes36-report.json
node --test tests/rugby-real-attributes36-audit.cjs
```
La sortie JSON contient les distributions par attribut (minimum, déciles, médiane, moyenne, dispersion), les groupes poste/championnat lorsque les métadonnées sont présentes sur la fiche, les vecteurs strictement identiques et les corrélations extrêmes (|r| ≥ 0,95). Les valeurs de notes sont des **estimations de gameplay**, non des statistiques observées.

## Contrôles et limites
- Schéma attendu : 1 592 fiches avec `attributesV2`, 36 clés, valeurs numériques de 20 à 97 et IDs sans doublons.
- Les formats de potentiel et traits cachés doivent être confrontés à la base réelle ; leur absence n'est pas remplacée par une valeur inventée.
- Une corrélation forte n'est pas, à elle seule, une erreur ; elle signale une revue rugby et statistique.
- La méthode n'établit pas la qualité réelle des joueurs. Pour recalibrer individuellement : observations et statistiques **datées avant le 1er juillet 2026**, pondérations par poste, incertitudes et revue manuelle stratifiée.
- Les notes de Rugby 25 ne sont pas copiées : aucun droit de réutilisation ni équivalence méthodologique supposés.
- Avant un futur raccordement au jeu, étudier séparément l'adaptateur des 36 attributs vers les 11 compétences du moteur, les écarts par poste, les tests sportifs et la compatibilité des sauvegardes.

## Gouvernance
PR DRAFT isolée ; seul l'intégrateur unique peut faire progresser le gate officiel. Aucune fusion ou bypass.

## Audit sur le fichier complet — 6 novembre 2026

Une première execution native [GitHub Actions #42307563953](https://github.com/Xynph/cadrage-debordement/actions/runs/42307563953) sur le HEAD `b195cf0` a réussi : 4/4 tests, 1592 joueurs, 36 attributs, aucune valeur d'attribut manquante ou hors bornes, aucun ID duplique, 1592 vecteurs distincts. ATTENTION : cette version ne verifiait pas correctement `hiddenTraitsV2` et utilisait mal le poste de gameplay. La correction est dans les commits suivants ; attendre sa CI finale et ne pas recycler le premier verdict pour ces deux controles. Les correlations fortes sont mesurees sur l'ensemble des joueurs, ce qui ne remplace pas les controles intra-poste.

## Sources sportives et methode de recalibrage individuel — spec non appliquee

**Date d'arret incontournable : 1er juillet 2026.** Les statistiques 2026-2027 connues a posteriori sont interdites comme entrees des notes de depart. Le fichier maitre comporte deja `v2Evidence`, `v3Calibration`, `performance2025_2026`, `v4EvidenceAdjustment` et des metadonnees `modelV2` a `modelV5`. Il faut **auditer l'existant et la couverture des preuves avant toute nouvelle variation**, faute de quoi on compterait deux fois la meme performance.

Sources officielles retenues pour la verification des donnees historiques :
- [LNR TOP 14, statistiques joueurs saison 2025-2026](https://top14.lnr.fr/statistiques/joueurs/2025-2026)
- [LNR TOP 14, temps de jeu joueurs 2025-2026](https://top14.lnr.fr/classement/joueurs/temps-de-jeu/2025-2026)
- [LNR TOP 14, discipline joueurs 2025-2026](https://top14.lnr.fr/classement/joueurs/nombre-de-cartons/2025-2026)
- [LNR PRO D2, realisateurs joueurs 2025-2026](https://prod2.lnr.fr/classement/joueurs/meilleurs-realisateurs/2025-2026)
- [LNR PRO D2, XV de la saison 2025-2026](https://prod2.lnr.fr/actualite/voici-le-xv-de-la-saison-2025-2026-de-pro-d2) : reconnaissance editoriale, **pas** un indicateur numerique de chacune des 36 competences.

### Grille de lien entre performance documentee et attributs de jeu

| Poste | Attributs prioritairement a examiner | Preuves individuelles pertinentes | Limite de preuve |
|---|---|---|---|
| Pilier gauche/droit | scrumTechnique, strength, ruckClearout, tackling, discipline | minutes, titularisations, plaquages, fautes; revue video experte de la melee | la melee est collective, aucune note de technique tiree de la seule victoire en melee |
| Talonneur | hooking, lineoutThrow, ballHandling, tackling, maul | lancers et prises en touche si disponibles, minutes, plaquages, fautes | ne pas confondre qualite du lancer et conquete collective |
| Deuxieme ligne | lineoutJump, lineoutLift, maul, ruckClearout, endurance | prises/vols en touche, temps de jeu, interventions defensives | les metres parcourus et le role de soutien sont rarement publies |
| Troisieme ligne / n8 | jackal, tackling, ballCarry, workRate, ruckClearout | ballons grattes, plaquages, metres, portees et minutes si publies | volume de jeu et efficacite doivent etre separes |
| Demi de melee | passing, decisions, kickAccuracy, vision, workRate | minutes, coups de pied, passes/assists si publies, observation terrain | une passe decisive n'isole pas la precision technique |
| Ouvreur | kickAccuracy, kickDistance, decisions, goalAccuracy, passing | penalites, transformations reussies/tentees, minutes, jeu au pied | ne pas estimer le but sur des points totaux uniquement |
| Centre | tackling, ballCarry, passing, decisions, offload | plaquages, metres, franchissements, offloads si publies | dependance au role offensif et au collectif |
| Ailier | acceleration, topSpeed, evasion, kickChase, receiving | essais, franchissements, metres, courses documentees | essais ≠ vitesse mesuree ; ne pas inferer la vitesse depuis la taille ou la nationalite |
| Arriere | aerialAbility, positioning, kickDistance, receiving, decisions | duels aeriens, occupation au pied, minutes, retours de jeu | duels et placement demandent souvent une expertise qualitative |

**Regles candidates pour un futur lot (non implantees dans la base)** :
1. Rapprocher la fiche sur son ID stable et son nom/club durant la saison 2025-2026 ; ne pas utiliser le club 2026-2027 pour attribuer une statistique de 2025-2026.
2. Preuve obligatoire : URL, competition, saison, date d'observation, mesure brute, unite, minutes ou nombre de tentatives, provenance, licence, indicateur de fiabilite et trace des possibles homonymes.
3. Normaliser chaque mesure contre des distributions **du meme poste et championnat** en tenant compte de l'exposition (minutes, tentatives), et comparer avec le score existant pour eviter le double comptage.
4. Un ajustement automatique est interdit sans echantillon adequat ; seuil initial a tester : >=300 minutes pour les mesures de volume, >=20 tentatives pour les pourcentages de but. Ce sont des seuils de travail et non des normes officielles.
5. Proposer un `deltaCandidate` conservateur borne a ±4 par attribut, seulement si la mesure indique une competence directement observable et n'a pas deja ete absorbee dans V4/V5. Sinon delta=0 et `evidenceNeeded=true`. Validation humaine pour les specialites de melee/touche, traits caches et potentiel.
6. Conserver strictement les 36 notes, traits caches, potentiel, IDs et donnees maitresses jusqu'a la revue par poste, controle de distribution, tests de match, sauvegardes et integration distincte. Jamais de scores arbitraires par nom ou prestige.

### Grille de qualite par joueur

- `observed` : statistique individuelle sourcable de 2025-2026, avec echantillon.
- `expert-estimate` : jugement rugby explicite et date, sans travestir en statistique.
- `model-estimate` : valeur de simulation purement estimee, sans preuve individuelle.
- `unknown` : aucune base verifiable ; pas de changement.
- `conflict` : plusieurs sources contradictoires ; bloquer l'ajustement.

**Livrable futur** : table candidate separant `playerId`, `attribute`, `oldValue`, `candidateValue`, `delta`, `evidenceRefs`, `confidence`, `reason`, `baselineModelVersion`, `reviewedBy` ; elle ne remplace jamais directement `attributesV2`.
