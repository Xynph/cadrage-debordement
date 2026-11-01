# V4.4 Premium PC — Navigation et lisibilité décisionnelle

Date : 1er novembre 2026. Base : `main 3fc721360224f670c56af2db8d975384bd173d14`. Branche : `integration/v44-pc-navigation-accessibility-20261101`. Périmètre PC 1440×900 / 1920×1080, thèmes Analyste et Tribune.

## Diagnostic

Le contrôle des planches Chromium V4.3 montre une barre de sous-pages dense et des boutons précédent/suivant de 32×36 px, petits pour un usage souris et peu lisibles. Audit source : le gestionnaire `keydown` de la barre intercepte les flèches, Début et Fin depuis **tous** les enfants de la navigation, y compris les boutons auxiliaires, alors que ceux-ci ne sont pas des onglets. Cela provoque un changement de sous-page inattendu quand le focus est sur un bouton précédent/suivant. Les libellés de ces boutons ne précisent pas la destination.

## Changements livrés dans la PR

1. Le gestionnaire clavier s'applique désormais exclusivement à `button[data-da42-subpage]`. Les touches fléchées, Home et End restent opérationnelles sur les vrais onglets ; elles ne sont plus détournées sur les boutons auxiliaires.
2. Les deux boutons décrivent dynamiquement leur destination (libellé français et `aria-controls` pointant vers le panneau exact) selon l'onglet actif, avec retour circulaire identique. La zone de navigation a `role=group` et un nom accessible.
3. Les cibles interactives des deux commandes passent de 32×36 à 44×44 px sur PC. Texte du repère, compteur et index légèrement agrandis. Aucune surcharge des contenus métier ni modification des données.
4. Le test Chromium sur les 5 espaces et les deux largeurs vérifie les destinations accessibles, la non-interception du clavier, la conservation du focus et la dimension des boutons ; il conserve les contrôles de sauvegarde, les 17 pages et les captures de référence.

## Non-régression et limites

Aucun fichier `modding/`, `Business/`, LNR, sauvegarde, moteur, ni `dist/game.js` touché. Il ne s'agit pas d'une certification d'un lecteur d'écran ou de Windows natif. Les verdicts Node/Chromium GitHub Actions doivent être vérifiés sur le SHA final avant toute fusion ; aucune fusion automatique.
