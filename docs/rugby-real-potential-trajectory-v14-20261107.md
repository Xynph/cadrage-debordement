# Rugby Réel — potentiel de carrière réellement utilisé et trajectoires V11 (V14)

Référence `main` : `044e83d2a9f860d59c2aeac2a22df94235bf04c9` au 7 novembre 2026 ; nouveau lot **100 % diagnostique**, aucune mutation de BDD active.

## Constat majeur : l'ancien déficit de potentiel est un faux positif fonctionnel

Le diagnostic V13 comptait **393 joueurs** dont le potentiel historique brut était numériquement sous la capacité active, dont 40 en priorité. Mais dans `dist/lnr-career.js`, une nouvelle carrière LNR initialise :

```js
p.dev.potential = clamp(p.rating + Math.max(0, oldPotential - oldRating), p.rating, 99);
```

Ce n'est **pas** une comparaison directe de `oldPotential` avec le nouveau `rating`. La marge historique de progression (ancien potentiel moins ancienne note) est conservée. Sur **1 592 joueurs**, la capacité dépasse `dev.potential` chez **0 joueur** ; **1 545** conservent une marge positive et **47** ont une marge nulle. Les 40 dossiers V13 les plus alarmants comportent **7** cas à marge nulle, mais **33** avec une véritable marge positive. Exemple : `lnr:2450`, ancien rating 66, ancien potentiel 69, note active 88 → potentiel de carrière 91, marge **+3**, et non −19. `lnr:2425` : 65 → 71, actif 89 → potentiel carrière 95, marge **+6**.

**Correction non destructive livrée** : `data/scouting/potential-trajectory-v14-20261107.json` classe désormais les 40 profils dans la **bonne échelle de carrière**, avec leurs deux anciens champs, la note active, le potentiel réellement recalculé, le plafond annuel V11 et une action d'audit (`review-zero-room` ou `preserve-rebased-room`). Chaque ligne propose `ratingChange: 0` et `potentialChange: 0` ; elle est **hors runtime**. Ce JSON remplace l'interprétation erronée « 393 potentiels à augmenter », sans écraser les données source.

## Deux moteurs d'évolution : contrôle du raccordement

Le moteur `dist/development.js` dérive le plafond virtuel annuel de `Math.max(p.rating, p.dev.potential)` avant de passer une **copie** au `LNR_V11_AGE.step`. Il conserve le potentiel d'origine dans `p.potential`, et utilise `p.dev.potential` en progression ; il n'y a donc pas de simple blocage automatique lié au décalage de note. Pour les profils V12, `growPlayer` enregistre l'activité dans l'XP mais n'augmente plus directement le rating : la courbe annuelle V11 assure la transition.

La sensibilité des **40** cas prioritaires est examinée à **23 âges (18…40) × deux scénarios = 1 840 pas annuels** sur des copies. Scénario A = plafond virtuel appliqué comme en carrière ; B = potentiel historique brut pour isoler l'effet du raccordement. Les conditions contrôlées sont 1 600 minutes / année, entraînement 100 %, aucune blessure ni charge, professionnalisme conservé. Le test mesure vitesses, vivacité, décisions et moyenne des 36 attributs, notamment entre 30 et 40 ans, protège la non-mutation de la BDD et l'idempotence de la saison.

**Limites essentielles :** un joueur déjà noté 88 au début de cette simulation reçoit artificiellement la même base à 18 ans. Ce banc n'est pas une reconstitution de sa jeunesse. Il n'exécute ni les vrais calendriers, ni les départs à la retraite, blessures, transferts ou saisons match par match. Il teste la fonction annuelle réellement présente dans `dist/lnr-v11-aging.js`, pas la survivance d'un joueur réel jusqu'à 40 ans. Les tests multi-saisons natifs de #383 restent des preuves complémentaires, pas un étalonnage scientifique.

## Décision pour la BDD de départ 2026–2027

Ne pas ajouter de points de potentiel ni abaisser les notes des **393** joueurs. Contrôler séparément les **47 marges nulles**, les trajectoires physiques/mentales par poste, et l'éventuel écart entre un plafond de score de carrière et les 36 attributs. La régression automatisée protège le calcul exact du `dev.potential` et inspecte les 40 dossiers. Les valeurs sont des estimations ludiques ; elles ne doivent jamais être présentées comme des capacités physiologiques mesurées.

**Aucun changement** dans `dist/**`, `modding/**`, le master LNR, les identités/effectifs/clubs/calendrier, UI, MATCH3D, moteur, sauvegardes ou branches de PR #385/#387. La PR demeure DRAFT, aucune fusion. Le workflow dédié doit confirmer l'exécution réelle du test avant toute qualification.
