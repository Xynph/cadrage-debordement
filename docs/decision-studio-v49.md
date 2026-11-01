# V4.9 Premium PC — Finances et Formation

Date : 1er novembre 2026. Base : `main 7ec09160fc0b3cf01a42bd39ca1e775ba9b28838`. Branche indépendante `integration/v49-premium-finance-academy-20261101`. Aucune fusion autorisée pour V4.9.

## Audit réel et limites

La revue a utilisé les PNG réels de l'artefact Chromium V4.8 #13086869149 (finance : trésorerie, dossiers, flux ; formation : vue native ; classement en contrôle de contexte). La planche inspectée révélait des indicateurs financiers peu différenciés, des courbes/variations à lecture secondaire, et des étapes de formation semblables à des blocs de données, sans repères visuels assez nets. Les éléments actuels restent utilisables et les tests V4.8 sont verts : il s'agit d'une amélioration de hiérarchie et non d'un défaut de moteur.

## Travail concret

- `dist/premium-v49.css` : surfaces et titres mieux différenciés sur les panneaux natifs DA42 ; solde, projections et indicateurs financiers en une matrice lisible avec nombres tabulaires ; flux hebdomadaires, barres de salaires et ligne de référence mieux structurés ; passage de jeunes joueurs vers les pros, étiquettes de parcours et cartes de potentiel mieux hiérarchisés. Aucun faux montant ni niveau de compétence ajouté.
- `dist/index.html` : chargement de cette couche après l'art-direction V4. Aucune modification HTML de la structure des commandes, de la navigation ni des événements.
- `tests/premium-v49-browser.py` : 28 nouvelles captures Chromium réelles (4 sous-pages finance + 3 formation, × 2 thèmes × 2 tailles PC 1440×900 et 1920×1080). Vérifie onglets natifs, panneau unique visible, absence de scroll de document et de dépassement, état de carrière `S` intact et localStorage `bdt-v1` inchangé ; existence des vrais graphes/flux/parcours/cartes, styles appliqués.
- `.github/workflows/premium-v49.yml` : workflow isolé Chromium + artefact, sans toucher la CI LNR ni les tests V4.8.

## Concurrence et réception

PR #188 V4.8 garde les chemins `dist/premium-v4.css`, `tests/premium-v4-browser.py`, `docs/decision-studio-v48.md`. PR #189/#190 réservent leurs nouveaux tests LNR et workflows. Les fichiers de cette V4.9 sont distincts, y compris le test navigateur et le workflow. `dist/index.html` n'est pas réservé par un autre chantier au moment de la prise de chantier. Si V4.8 entre dans main avant V4.9, rapprocher la branche avec main sans modifier le lot V4.8.

Aucun moteur, simulation, règle rugby, valeur financière, effectif réel, Business, DATA-06, sauvegarde, requête payante ni menu de démarrage changé. Les anciens imports demeurent inchangés. Les tests de rendu ne certifient pas Windows, Safari, lecteur d'écran ou opérations métier destructives. Consulter CI et vraies captures du SHA final avant toute revue de fusion.

**État initial : CI à vérifier sur le SHA exact ; aucune fusion sans autorisation explicite et release gate.**
