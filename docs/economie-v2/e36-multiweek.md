# Économie V2 E3.6 — six semaines appariées et divergences de trajectoire

## Périmètre

Banc R&D indépendant empilé sur PR #357, non importé par le jeu. Uniquement cinq nouveaux chemins. Aucun changement gameplay, sauvegardes natives, PRODUCTEUR, MATCH 3D (en pause), DATA/LNR, `main` ou gate.

## Deux expériences à distinguer

**Six campagnes natives × quinze saisons** : la campagne E3.5/E3.4/E2.4 est rejouée comme **non-régression** (90 saisons, 2 610 tours, 18 imports attendus) ; elle ne comporte pas quinze saisons de contrefactuels. Elle vérifie les sauvegardes et les flux natifs inchangés.

**Dix-huit comparaisons multi-semaines** : pour chaque couple profil/graine, trois expériences `facility`, `academy 4000`, `academy 12000`, chacune avec deux copies de la même sauvegarde native et du même état de RNG, sur six semaines. Chaque paire exécute les fonctions natives d'entraînement puis `finishRound()` dans les deux branches. Tous les relevés sont des observations du moteur exécuté, non une projection sportive.

## Mesures et prudence

- **Coût réellement débité** : installations : une tentative de `worldUpgradeFacility()`, coût du devis au moment de l'exécution, événement source daté uniquement à la saison ; formation : `careerAcademyTraining()` à chaque période, débit vérifié par variation de cash au moment de l'action, paiement compté uniquement s'il est effectivement observé. Les charges courantes et revenus des matchs restent distincts du coût de décision.
- **Progression sportive mesurée** : `rating` et `dev.xp` des joueurs observés sur les deux branches à chaque semaine ; mêmes identifiants présents dans chaque bras, attrition de cohorte relevée, somme des deltas et nombre de joueurs avec hausse de note.
- **Résultats de match réellement simulés** : `finishRound()` exécuté dans les deux bras ; variations des victoires, points de classement, points marqués/encaissés relevées. Celles-ci ne constituent pas automatiquement un effet causal. La première divergence de PRNG (`value` ET `calls`) est enregistrée à l'étape avant entraînement / avant match / après match. À partir de cette divergence, les différences de score ne sont plus interprétables comme un contrefactuel à bruit commun. Même en l'absence de divergence d'index RNG, les trajectoires de composition/forme/finance peuvent diverger : les observations restent limitées à six semaines.
- **Sauvegardes** : chaque original est testé inchangé `state`, `checksum` et RNG ; les snapshots des deux copies sont parsés par le véritable lecteur natif chaque semaine. Aucun résultat prospectif garanti, aucune dette ou échéance inventée, `fullSeasonEffect=null` et `causalMatchImprovementGuaranteed=null`.

## Limitations

Le test appelle explicitement les routines de formation sur chaque semaine, sans simuler l'interface complète d'un joueur décidant d'entraîner ou de ne pas entraîner. L'égalité de départ est vérifiée ; les écarts de résultats après modifications d'état et/ou de RNG ne prouvent pas une amélioration indépendante des autres décisions. La progression peut être plafonnée par le potentiel et dépendre d'autres appels natifs. Le classement observé sur six semaines ne représente pas une prédiction sur 15 saisons.

## Qualification

CI E3.6 requise sur HEAD exact : six jobs profils/graines, suites de tests natives, six rapports JSON et ZIP, SHA256 et comparaison aux logs réels, contrôles de `saveParity` et source immuable. Garder la PR DRAFT et refuser toute promotion de gameplay, READY, gate ou fusion.
