# V4.2 — galerie de captures réelles et revue visuelle

**Provenance contrôlée :** captures issues du workflow Chromium de la PR #164, [V4 Premium visual acceptance #41294785004](https://github.com/Xynph/cadrage-debordement/actions/runs/41294785004), artefact téléchargeable **`premium-v4-browser-report` (ID `13078897879`)**. Le workflow s'est terminé en `success` sur le SHA `c918958be09359a7a4e2f3f3943adff941a28e9b`. Ce sont les véritables rendus de l'application lancée en Chromium Linux avec une carrière fictive créée par le navigateur, et non des maquettes ou des images générées.

**Référence avant :** captures V4.1, [workflow #41293020335](https://github.com/Xynph/cadrage-debordement/actions/runs/41293020335), artefact `premium-v4-browser-report` (ID `13077679797`), SHA V4.1 `4f3d68607ac62b11007b5028ef6f4fc7fbea4d33`. Les comparaisons suivantes concernent le même scénario de test avec seed fixe, mais des commits distincts. La galerie d'origine inclut 64 fichiers et deux thèmes ; les artefacts GitHub Actions **expirent après sept jours**, comme défini par le workflow.

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
