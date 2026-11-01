# V4.5 Premium PC — effectif, fiche joueur et classement

**Base** : `main 2167c2ab5086c7c0abddb1be1958de884588cfa9` ; branche `integration/v45-premium-player-league-20261101`. Périmètre desktop 1440×900 et 1920×1080, thèmes Analyste et Tribune.

## Audit réel

Les archives `ui02-browser-report` #13081594903 et `ui01-browser-report` #13082383115 ont été téléchargées et ouvertes. En 1440 px, la **fiche joueur / Contrat** remplit à peine le haut de l'écran avant une grande zone vide ; le tableau de l'**effectif** reste extrêmement dense et peu raccordé aux visualisations ; l'**espace classement** manque de composition décisionnelle par rapport aux 17 sous-pages V4.3. Les vues de référence sont de véritables captures Chromium du jeu.

## Conception

1. **Effectif** : hiérarchie accentuée de la cartographie et de la disponibilité, chemin de navigation direct vers le vrai tableau professionnel, tableau natif à scroll local et en-tête fixe sur PC, lignes et liens plus lisibles. Filtres, tri, joueurs, ordre et données conservés.
2. **Joueur** : un studio de lecture du contrat, calculé uniquement sur le joueur actuel (note au poste, condition, salaire hebdomadaire fictif, minutes effectivement enregistrées et potentiel). La blessure n'est déclarée que si le moteur la signale. La vraie fiche native et ses commandes contractuelles restent en dessous, autres onglets inchangés. Radar et forces du profil mieux composés en PC.
3. **Classement** : bandeau lisible de situation (leader selon le classement natif, points du club et matchs joués) ; une égalité à zéro point est explicitement provisoire. Tableaux et départages natifs inchangés.
4. **Non-régression** : extension Playwright avec 16 captures PC supplémentaires (4 vues × 2 tailles × 2 thèmes) en plus des 51 sous-pages V4.3/4.4. Vérification valeurs natives, panneaux/onglets, largeur, état `S` et stockage inchangés, export et commandes.

**Restrictions** : aucun `modding/**`, `Business/**`, moteur, `dist/game.js`, `dist/index.html` ni sauvegarde touchés. Les montants financiers du jeu restent fictifs. Chromium Linux ne certifie pas Windows portable, Safari ou lecteur d'écran. Aucune fusion sans autorisation expresse.
