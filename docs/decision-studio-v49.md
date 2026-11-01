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

## Réception Work — V4.9.1, 1er novembre 2026

V4.8 #188 fusionnée par squash `aee4c66376ea34195c3851d1f1086b5a982083ef` après contrôle du gate officiel `decide()`, état REST `clean`, JavaScript 7/7 et Chromium verts sur `4c0c7644`. La branche V4.9 intègre ce main par merge sans conflit et sans réécriture de ses fichiers. Le transport REST de lecture et le connecteur authentifié de fusion avec SHA attendu ont remplacé uniquement le transport CLI indisponible ; aucun critère du gate n'a été modifié.

Les 28 PNG initiaux de l'artefact #13087554419 ont été ouverts ; les sept sous-pages ont été inspectées dans les deux thèmes. Une exécution locale Chromium déterministe sur la branche raccordée reproduit un défaut réel à 1440×900 : le viewport de la courbe était forcé à 130 px et son conteneur flexible se comprimait jusqu'au chevauchement du tableau ; les cartes d'espoirs avaient 104 px utiles pour 127 px de contenu et masquaient leur pied. Le contrôle « pas de scroll global » ne suffisait pas à détecter ces problèmes.

Correctifs de présentation dans `dist/premium-v49.css` :

- Trésorerie : courbe de 190 à 250 px, trait renforcé, indicateurs répartis en deux colonnes et mention du modèle séparée ; figure, légende et valeurs ne se compriment plus. Le panneau possède un défilement local, sans masquer les montants détaillés ni réintroduire le scroll du document.
- Potentiel : cartes d'au moins 180 px, nom et niveaux agrandis, écart complet en pied de carte. Le contenu reste accessible pour plusieurs lignes de joueurs.
- Passerelle : panneaux à défilement local et étapes organisées en valeur/libellé ; actions natives de suivi accessibles, cibles de 44 px. Aucun événement ni valeur de carrière modifié.

Recette : les nouvelles assertions ont d'abord échoué sur la courbe à 1440 px. Après correction, 28 nouvelles captures Chromium et 208 contrôles réussis : séparation figure/tableau, hauteur lisible du graphique, cartes sans contenu coupé, dernière valeur financière et action jeunes pros accessibles, en plus des invariants `S`/`bdt-v1`, navigation et absence d'erreurs JS/HTTP. `node --test tests/saves.cjs tests/art-direction-v4.cjs` : 2/2 fichiers réussis, dont export/import, aperçu/annulation, restauration, anciennes sauvegardes, quotas et dix exports intersaison. Diff vérifié : aucun changement LNR/DATA/Business/moteur/stockage. La CI complète de la tête publiée reste exigée ; preuves définitives consignées dans #73. Aucune fusion de #193 autorisée.
