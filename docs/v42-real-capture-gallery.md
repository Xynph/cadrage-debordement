# V4.2 — galerie de captures réelles et revue visuelle

## Nouvelle référence — Sous-pages PC exclusives (architecture type FM)

La version actuelle de la PR #164 introduit des **sous-pages réelles**, jamais des dossiers déroulés dans l'écran principal. Sur bureau, préparation, finances, recrutement et formation, la navigation secondaire se trouve sous l'onglet métier natif. Une seule page est présente visuellement : l'ancien contenu est masqué au changement d'onglet. Les raccourcis clavier Flèche gauche / Flèche droite / Home / End fonctionnent.

**Captures attendues du dernier workflow Chromium** : une capture **de chaque sous-page**, avec nom `pc-{onglet}-{souspage}-analyste-1920x1080.png` et `pc-{onglet}-{souspage}-analyste-1440x900.png`. Cela couvre **17 sous-pages × 2 résolutions = 34 images PC**, notamment :

| Onglet principal | Sous-pages (illustrées en 1920×1080 et 1440×900) |
| --- | --- |
| Bureau | pilotage, calendrier, dossiers |
| Tactiques | xv, condition, analyse, dossiers |
| Finances | tresorerie, flux, salaires, dossiers |
| Recrutement | besoins, marche, dossiers |
| Formation | passerelle, potentiel, dossiers |

Pour accéder aux PNG réels, ouvrir **Actions → V4 Premium visual acceptance → artefact `premium-v4-browser-report` → `art-direction-v4/`**, puis chercher les noms ci-dessus. **Ne pas les confondre avec les anciennes captures V4.2** : la preuve correspond uniquement au workflow vert sur la tête finale de la PR après navigation PC. L'artefact a une rétention de sept jours.

**Critères d'acceptation** : aucune sous-page ajoutée au-dessous d'une autre, `aria-selected` et `hidden` corrects, pas de scroll du document sur les fenêtres PC 1920×1080 et 1440×900 ; navigation native du centre de match, des candidats et des espoirs toujours fonctionnelle ; aucune modification de `S` ou du contenu sauvegardé lors du passage d'une sous-page à une autre. Si une commande native exige davantage de lignes, seul son dossier de travail peut défiler localement.

**Périmètre :** PC uniquement. Les anciennes archives 390 px sont historiques et ne font pas partie de cette galerie ni des critères d'acceptation de la navigation.

## Refonte PC approfondie (tête de PR à valider)

**Décision produit : PC uniquement**, selon l'issue #73. L'audit des captures existantes V4.2 en 1440 px a montré un bureau trop proche de quatre statistiques génériques et une succession de flux financiers sans véritable hiérarchie visuelle. Une seconde passe de développement, sur la PR #164, remplace ces compositions par un **poste de commandement avec panorama de stade et panneau de navigation**, un **anneau de condition des titulaires et des groupes de disponibilité**, une **chronologie financière en colonnes**, des **fiches talent plus riches** et un **observatoire des coûts du marché**.

Le script `tests/art-direction-v4-browser.py` produit désormais des captures dédiées sur de **vrais navigateurs Chromium** aux dimensions PC demandées :

| Vue | PC 1920×1080 | PC 1440×900 |
| --- | --- | --- |
| Bureau | `pc-dashboard-analyste-1920x1080.png` | `pc-dashboard-analyste-1440x900.png` |
| Préparation du XV | `pc-tactics-analyste-1920x1080.png` | `pc-tactics-analyste-1440x900.png` |
| Finances | `pc-finance-analyste-1920x1080.png` | `pc-finance-analyste-1440x900.png` |
| Formation | `pc-formation-analyste-1920x1080.png` | `pc-formation-analyste-1440x900.png` |
| Recrutement | `pc-recruitment-analyste-1920x1080.png` | `pc-recruitment-analyste-1440x900.png` |

**Ces nouveaux fichiers doivent être vérifiés dans l'artefact de la dernière CI verte** ; les noms dans ce tableau sont les sorties attendues du script, pas une preuve anticipée d'exécution. La CI vérifie en plus le non-débordement horizontal, la composition desktop en deux colonnes et le caractère strictement en lecture seule de ces navigations. Les captures 390 px des premières CI demeurent archivées mais ne constituent plus un axe d'amélioration.



**Provenance contrôlée :** captures issues du workflow Chromium de la PR #164, [V4 Premium visual acceptance #41294785004](https://github.com/Xynph/cadrage-debordement/actions/runs/41294785004), artefact téléchargeable **`premium-v4-browser-report` (ID `13078897879`)**. Le workflow s'est terminé en `success` sur le SHA `c918958be09359a7a4e2f3f3943adff941a28e9b`. Ce sont les véritables rendus de l'application lancée en Chromium Linux avec une carrière fictive créée par le navigateur, et non des maquettes ou des images générées.

**Référence avant :** captures V4.1, [workflow #41293020335](https://github.com/Xynph/cadrage-debordement/actions/runs/41293020335), artefact `premium-v4-browser-report` (ID `13077679797`), SHA V4.1 `4f3d68607ac62b11007b5028ef6f4fc7fbea4d33`. Les comparaisons suivantes concernent le même scénario de test avec seed fixe, mais des commits distincts. La galerie d'origine inclut 64 fichiers et deux thèmes ; les artefacts GitHub Actions **expirent après sept jours**, comme défini par le workflow.

## Contrôle photographique réel sur la première tête PC

Le workflow [V4 Premium Chromium #41296264951](https://github.com/Xynph/cadrage-debordement/actions/runs/41296264951) a **réellement réussi** sur le SHA `6ed1a37711778c1a7f42b59efd4ef232ec9f7d90`. Son artefact `premium-v4-browser-report` (ID `13079536588`) a été téléchargé et examiné : les **dix vrais PNG 1920×1080 / 1440×900 existent** ; `art-direction-v4/report.json` contient `passed: true`, **427 contrôles**, aucune erreur JS ; `premium-v4/report.json` indique **529 contrôles réussis**.

**Problème graphique identifié et corrigé après lecture des images :** le bureau cumulait deux grandes affiches de match presque identiques, la nouvelle zone de commande et l'ancien panneau duel, puis répétait l'information de disponibilité. L'ancien duel est devenu, **sur PC**, une barre de passage plus compacte vers le centre de match natif. Le nouvel espace de commande garde la mise en scène et les informations décisionnelles ; le bouton natif reste accessible. La CI de la correction doit être revalidée sur une nouvelle tête, et ses captures doivent remplacer la première galerie comme référence finale.

**Autres constats :** les graphiques de finances occupent bien la largeur centrale PC ; les cartes de formation et l'observatoire du recrutement se trouvent plus bas dans les écrans complets. Aucun chevauchement visible sur les images examinées. La longueur du document tactique reste importante, mais il s'agit d'un jeu PC. Les vérifications Chromium ne certifient pas Windows natif, Safari/Firefox ni les lecteurs d'écran.

## Galerie — dix captures desktop/mobile V4.2

Dans [l'artefact GitHub de V4.2](https://github.com/Xynph/cadrage-debordement/actions/runs/41294785004), ouvrir « Artifacts → premium-v4-browser-report », puis le dossier `art-direction-v4/`.

| Expérience | Desktop 1440 px | Mobile 390 px | Élément V4.2 observé |
| --- | --- | --- | --- |
| Bureau | `dashboard-analyste-1440.png` | `dashboard-analyste-390.png` | Centre de quatre décisions près du début de la page |
| Préparation du XV | `tactics-analyste-1440.png` | `tactics-analyste-390.png` | Section condition en trois zones, après le radar |
| Finances | `finance-analyste-1440.png` | `finance-analyste-390.png` | Flux par semaine sous la synthèse financière |
| Formation | `formation-analyste-1440.png` | `formation-analyste-390.png` | Comparatif actuel/plafond sous la première composition |
| Recrutement | `recruitment-analyste-1440.png` | `recruitment-analyste-390.png` | Synthèse des coûts publics sous le diagnostic |

Un nouveau contrôle navigateur `tests/art-direction-v4-browser.py` doit confirmer ces cinq studios, les destinations des quatre boutons du bureau, la correspondance des mouvements de trésorerie et des profils avec le snapshot réel, et l'absence de changement d'état ou de sauvegarde pendant la navigation. Les mêmes 14 vues V4 par thème et largeur restent soumises aux vérifications d'overflow déjà présentes.

## Revue comparée V4.1 → V4.2

- **Bureau** : la V4.1 passait de la synthèse directement à l'affiche du prochain match ; la V4.2 interpose un centre de décisions avec quatre sorties explicites. C'est le changement le plus immédiatement visible sans faire défiler.
- **Préparation** : radar et fiches de titulaires préservés ; la répartition de condition crée une lecture supplémentaire avant les contrôles du match, en dessous de la première hauteur de page.
- **Finances** : la courbe native conserve sa cohérence visuelle ; les variations hebdomadaires ne remplacent pas les chiffres prévisionnels, elles apparaissent sous les panneaux V4.1.
- **Formation** : la nouvelle comparaison complète le graphe de potentiels V4.1 ; elle n'ajoute pas d'évaluation cachée.
- **Recrutement** : le terrain et le nuage de candidats restent les visuels dominants ; la synthèse de coûts est une lecture de second niveau.

**Constat UX honnête :** sur mobile, certaines pages restent très longues (la capture de préparation en 390 px dépasse 10 000 px de haut). C'est un axe d'amélioration ultérieur : simplifier le parcours et l'ordre des informations plutôt que prétendre qu'un simple contrôle d'overflow certifie l'ergonomie. La V4.2 actuelle ne modifie pas cette longueur structurelle.

## Traçabilité et limites

Les images PNG restent dans les artefacts GitHub Actions, pas dans les fichiers binaires du dépôt : l'API d'écriture de cette session ne permet pas de verser directement les images dans Git. Ce document constitue un **index vérifiable**, pas une galerie d'images intégrées permanente. Les comparatifs montés à partir des vraies captures ont été constitués localement dans la session de revue et remis à l'utilisateur, pas publiés comme fichiers GitHub. Les captures ne démontrent ni Safari, Firefox, NVDA/VoiceOver, ni une installation Windows. Ne jamais considérer une CI encore en cours comme réussie.

**Aucune fusion autorisée par ce document.**
