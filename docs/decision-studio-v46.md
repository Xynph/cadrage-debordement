# V4.6 Premium PC — avant-match et centre de match en direct

Date : 1er novembre 2026. Base GitHub : `main 0f02dc5b295df15dea2a7868403d3fd619725894`. Branche : `integration/v46-premium-match-center-20261101`. Responsabilité : intégrateur unique, sans fusion.

## Audit visuel réel avant changement

Archive de captures du dernier workflow V4.5 : `premium-v4-browser-report`, run #41306769268, artefact #13083955546. Images réelles inspectées : `premium-v4/match-analyste-1440.png` (1440×2023), `premium-v4/match-tribune-1440.png`, `premium-v4/live-1440.png` (1440×1865). L'avant-match conserve de nombreuses informations mais le bloc d'introduction est peu marqué, la répartition entre la colonne de duel et le rapport adverse est déséquilibrée. En direct, l'étroite bande du score et les commandes sont moins lisibles que le terrain 2D, surtout avec les bancs latéraux. Ces écarts sont constatés dans les captures, non présumés.

## Changements visuels

- **Avant-match PC** : vraie scène de rencontre avec photo déjà embarquée, contraste typographique, nouveau rapport de largeur des deux colonnes, panneau de duel accentué, compteurs de préparation mieux séparés, commandes du coup d'envoi renforcées et dossier adverse plus lisible.
- **Direct PC** : score rendu prioritaire sans modifier sa valeur ; contraste du stade, contrôle de pause / avance à cible plus grande, onglets du cockpit plus visibles, bancs latéraux et bordure de terrain rééquilibrés. La photo est un décor existant en local et n'affecte aucun graphique du moteur.
- **Garde-fous** : styles bornés aux éléments natifs `.prematch-grid` et `.live-layout` à partir de 1200 px. Aucun JS de jeu modifié, aucune modification des événements, joueurs, tactiques, substitutions, temps ou sauvegardes. Modes Tribune/Analyste PC traités ; mobile inchangé.
- **Tests** : `tests/premium-v4-browser.py` étendu pour 4 captures avant-match (2 thèmes × 2 résolutions), 2 captures direct Analyste (1440×900, 1920×1080), contrôles de présence des vraies commandes, préservation de `S` et `bdt-v1` avant coup d'envoi, minute de match figée pendant la pause, terrain toujours présent et absence de débordement. Suite V4 préexistante maintenue, tests transversaux GitHub et Validation CI à exécuter sur SHA exact.

## Limites

Cette direction artistique ne prétend pas changer les règles du rugby (cf. `docs/rugby-rules-reference.md`), le plan de jeu, les résultats, les règles de pause ou la restitution tactile. Chromium Linux ne certifie ni Windows natif ni lecteur d'écran. Aucune collecte payante, aucune fusion sans autorisation expresse.
