# Diagnostic économique natif — lot indépendant pendant UI-02C

Base auditée : `e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807`. Tous les montants sont fictifs, pas les budgets réels des clubs. Six nouveaux fichiers seulement ; aucun coefficient, fichier `dist/`, harness partagé, sauvegarde utilisateur ou branche UI-02C modifié. La PR #85 reste séparée et non fusionnée.

## État réellement observé

La première CI du commit `79597eb8` (run `41191614809`) a validé **cinq campagnes de quinze saisons**, soit 75 saisons dans des campagnes complètes. Le scénario `modeste / 99173` a validé six saisons puis échoué à l'export de la septième : `validateCareer`, `saves.js:246:256`, contrôle du registre financier. La synthèse générale a correctement refusé de déclarer les 90 saisons validées.

La version suivante conserve le rapport partiel et l'état fictif rejeté dans les artefacts, puis **échoue toujours**. Le fichier `failure-state-*` porte `productionSave:false` : ce n'est pas une sauvegarde utilisateur importable. Un diagnostic sur copie vérifie si le seul retour du registre à 100 lignes suffit à satisfaire le validateur. Cette copie ne remplace jamais l'état fautif et ne permet pas à la campagne de continuer artificiellement.

Les 20 groupes courts initiaux ont réussi localement et dans la première CI. Un 21e groupe teste la capture d'un registre trop long, l'absence de modification de l'état d'origine et le maintien du rejet. Les essais locaux de trois saisons pour référence et déficit/formation ont réussi ; une répétition locale longue a été interrompue à sa limite d'exécution et n'est pas comptée comme campagne complète. Le verdict du dernier SHA et les artefacts, publiés en #73, font autorité.

## Méthode de mesure

Réutilisation de `tests/harness.cjs` et `tests/career-resilience/native.cjs`. Appels aux vrais `finishRound`, `advanceSeason`, `trainWeek`, opérations de recrutement, investissements et import/export ; aucun score ou classement V51 de substitution.

Les nouvelles écritures du manager sont relevées avant leur éviction du registre borné. Pour les treize adversaires, la variation effective de trésorerie est rapprochée des partenaires, salaires, scores et domiciles réels, entretien et primes issues des rapports IA. Les transitions distinguent renouvellements, recrutements, apport, remboursement, conversion de déficit en dette et installations. Un résidu supérieur à 0,001 € ou une étiquette inconnue fait échouer le banc. L'absence d'effet sur l'état complet et le RNG a été comparée à un témoin sur une vraie journée.

Sources et SHA sont enregistrés. Les reprises utilisent le parseur et la confirmation d'import natifs ; le RNG est un état annexe du test, pas une extension des sauvegardes officielles.

## Scénarios et limites

Trois politiques, graines `827381` et `99173`, quinze saisons prévues par combinaison :

- `reference` : club 0, trésorerie native, sans décisions discrétionnaires de recrutement, prolongation, entraînement ou investissement.
- `modeste` : club 13, mêmes choix passifs.
- `deficitFormation` : club 13, trésorerie initiale −250 000 € avec ajustement déclaré ; sponsor stable, séances de formation à 4 000 € lorsqu'elles sont financées et investissement annuel si abordable. Aucun recrutement ou renouvellement discrétionnaire de professionnels.

Ce ne sont pas des politiques représentatives de tous les joueurs. Le scénario déficit/formation combine plusieurs changements et ne mesure donc pas un effet causal isolé de l'investissement. Deux graines par profil ne constituent pas un étalonnage statistique exhaustif. Les classes de qualité utilisent les données natives ; leur corrélation avec l'argent ne prouve pas une causalité.

```sh
node tests/economy-audit.cjs
node ci/economy-audit.cjs modeste 99173 15 economy-audit-report
node ci/economy-audit.cjs --aggregate economy-audit-input
```

L'agrégation exige six campagnes distinctes et complètes, les mêmes empreintes sources, des totaux cohérents et aucun échec. Un scénario arrêté n'est jamais retiré de la matrice pour faire passer la CI.

## Priorité P0 — registre financier après un titre

La trace de la campagne en échec désigne `S.ledger`, limité à 100 lignes par le validateur. `finishRound` insère directement `Prime de champion` après les traitements qui bornent déjà le registre, sans le reborner ensuite. Le second passage de CI doit conserver la longueur exacte, le champion, le club du manager, l'état du signalement de sauvegarde et le résultat de validation de la copie diagnostique pour confirmer la reproduction native complète.

Correction recommandée dans un chantier distinct : passer par l'écriture financière centralisée ou borner l'insertion de prime, en préservant **un seul crédit**. Tester finale gagnée avec registre plein, export et reprise, répétition de `finishRound`, et ancienne carrière. Ne pas augmenter la limite du validateur pour masquer le défaut. Aucune correction de production n'est incluse ici ; le producteur a été averti en #73 pour éviter une intervention concurrente.

## Priorité P1 — prévision V41 incomplète

`careerBudgetModel` ne reprend pas `worldUpkeep` dans `weeklyOtherCosts`. Après l'investissement natif au niveau 3, **2 900 € par période**, soit **34 800 € sur l'horizon de douze périodes**, sont omis. Le groupe 16 isole les règlements sans billetterie ni victoire et reproduit exactement l'écart. Son succès prouve la reproduction du défaut, pas la justesse de la prévision.

Raccordement recommandé : intégrer une seule fois l'entretien connu, séparer la formation et tester plusieurs niveaux ainsi que les anciennes carrières sans `worldVersion`.

## Accumulation monétaire : flux et fréquence

Première saison référence, graine 827381 : trésorerie cumulée de 67 700 000 € à 113 668 925 €. L'excédent de 45 968 925 € est expliqué par 64 960 000 € de partenaires, 67 588 000 € de billetterie, 14 160 000 € de primes de victoire, −98 549 075 € de salaires et −2 190 000 € de signatures IA. Aucun apport intersaison n'est ajouté à ce bilan initial.

Le moteur règle partenaires et salaires sur **29 tours** par saison, même lorsque le club ne joue plus les phases finales ; il ne simule pas un calendrier de 52 semaines. Les adversaires reçoivent 160 000 € par tour, 360 000 € lorsqu'ils sont premiers dans la paire et 80 000 € par victoire. L'apport de 2,5 M€ par club est versé à chaque intersaison. Vérifier occurrences et flux avant d'invoquer un doublon : barèmes, apports récurrents et dépenses limitées d'un manager passif peuvent produire l'excédent.

Ne pas remplacer arbitrairement 29 par 52 ni réduire des recettes sans objectif de gameplay et campagne comparée. Les clôtures annuelles ne prouvent pas l'absence de déficit intermédiaire ; les points d'observation négatifs du rapport peuvent inclure plusieurs décisions dans un même tour.

## Asymétries à arbitrer, sans changement de règles ici

- Les demi-finales et la finale sont affichées « Terrain neutre », mais une billetterie est attribuée au premier club de la paire. Chaque occurrence est tracée. Définir ensuite la règle souhaitée : partage, attribution ou absence, puis harmoniser affichage et comptabilité.
- La prime de champion de 1 M€ est attribuée seulement si le club du manager gagne. Les comptes adverses ne la reçoivent pas. C'est une asymétrie de gameplay à arbitrer, pas une règle officielle de rugby.
- La remise à zéro d'une trésorerie IA négative augmente sa dette : ne pas compter cette conversion comme richesse nette gratuite. Les intérêts de 4 % et remboursements sont séparés. Le cas court −500 000 € de trésorerie / 200 000 € de dette aboutit à 2 250 000 € de trésorerie / 478 000 € de dette après le traitement natif.

## Couverture et coordination

Seuil d'investissement à un euro près, réserve d'entretien non prélevée deux fois, répétition après import, formation financée/refusée, sponsor unique, recrutement à trésorerie exacte, transfert conservant les budgets et un seul propriétaire, acheteur insuffisant, panne de stockage visible, dernier fichier correct préservé, corruption rejetée, actions bloquées en match et preuve d'échec sur copie.

Le plan UI-02C se trouve dans `docs/ui02-reception-checklist.md`. Le journal du lot reste dans ces nouveaux documents et #73 pour ne pas modifier le journal partagé. Les compteurs de contrôles répétés ne sont pas autant de suites indépendantes. Aucun test Windows natif ou visuel UI-02C revendiqué. Une CI verte d'une reproduction ne garantit pas un jeu économiquement équilibré ; l'échec natif découvert reste bloquant jusqu'à sa correction coordonnée.
