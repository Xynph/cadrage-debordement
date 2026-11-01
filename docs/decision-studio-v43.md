# V4.3 Premium PC — Espaces de gestion

**Base exacte :** `main 6c76b0dddb7dc3475e73392eb95c47b7e1e5e9ea` (V4.2 intégrée). **Branche :** `integration/v4-3-premium-pc-workspaces`. **Périmètre : PC exclusivement**, tests prioritaires à 1920×1080 et 1440×900. Aucune fusion sans autorisation.

## Audit réel de la référence V4.2

La référence provient de GitHub Actions **V4 Premium visual acceptance #41298815729**, artefact **premium-v4-browser-report ID 13080279314**, téléchargé et ouvert sur ses 34 PNG Chromium : 17 sous-pages × 2 tailles PC, scénario de carrière fictive seed-fixe. La planche 1440×900 a été inspectée réellement (Bureau/Pilotage, Bureau/Calendrier, Recrutement/Besoins, Finances/Salaires, ainsi que l'ensemble des autres sous-pages). Les faits observés :

- Sur **Calendrier**, les cinq étapes ne prennent qu'une petite bande et laissent l'essentiel de la page vide ; le prochain match forme un second bandeau indépendant.
- Sur **Finances/Salaires**, les neuf lignes restent petites dans une grande surface, mal hiérarchisées et difficiles à comparer du regard.
- Sur les cinq espaces métier, plusieurs panneaux s'arrêtent avant le bas de l'espace disponible ; les dossiers natifs ont peu de personnalité graphique.
- La barre V4.2 assure bien les sous-pages exclusives et les contrôles natifs, mais ne donne aucun raccourci immédiat de sous-page précédente/suivante ou repère chiffré propre à la carrière.

## Refonte V4.3 effectivement codée

1. **Navigation secondaire augmentée sur 17 sous-pages :** chaque bande d'onglets présente désormais le numéro de sous-page, la précédente et la suivante, avec retour circulaire, ainsi qu'un *repère de carrière réel* adapté à chaque page (fixtures, effectif sélectionné, niveau de condition natif, échéances, budget fictif, masse salariale, besoins prioritaires, candidats publics, espoirs). Le changement d'onglet ne modifie ni la carrière ni la sauvegarde. Les relations `aria-controls` / `aria-labelledby` sont explicites ; les raccourcis clavier V4.2 restent opérationnels.
2. **Calendrier PC reconstruit en parcours plein écran :** cinq tuiles au même niveau, rivales agrandies, rendez-vous prioritaire distinct et lecture DOM/EXT. La navigation native vers la compétition et le centre de match reste conservée.
3. **Finances orientées décision :** neuf familles de salaires présentées comme une carte de charges occupant la surface, montants tabulaires, barres lisibles ; projection et variations utilisent davantage de hauteur réelle sans changer les calculs.
4. **Tactiques, Formation et Recrutement :** jauge de condition et répartition plus lisibles, cartes talents hiérarchisées et marché structuré en deux zones documentées. Aucune note cachée ou projection inventée.
5. **Dossiers natifs :** séparation visuelle accentuée, focus clavier visible, zone de défilement strictement **locale** pour les longues listes. Les panneaux ne se déploient pas à la suite dans le document.

## Non-régression

- 17 sous-pages réelles (3 Bureau + 4 Tactiques + 4 Finances + 3 Recrutement + 3 Formation) et **une seule sous-page visible** à la fois.
- Aucune création d'accordéon pour naviguer, aucun scroll vertical global en 1440×900 ni 1920×1080 ; les tableaux peuvent défiler dans leur propre zone.
- Aucun changement des sauvegardes, de `S`, des finances réelles, des règles de rugby ni du moteur. Les projections financières fictives restent identifiées comme telles.
- Tests Playwright : transitions, attributs ARIA, navigation avant/arrière avec boucle, repères natifs, absence de scroll global, conservation de `S` et `localStorage`, liens métier natifs, exports et 51 captures PC réelles attendues (**17 Analyste 1440 + 17 Analyste 1920 + 17 Tribune 1440**).
- Captures générées par le workflow Chromium de la PR ; seules les captures **réellement produites et inspectées** seront présentées comme nouvelles. La CI JavaScript sur SHA final et la réception Chromium doivent être vérifiées avant toute recommandation de fusion.

**Limites :** le navigateur testé par GitHub Actions est Chromium Linux ; il ne certifie pas Windows portable natif, Safari/Firefox ou les lecteurs d'écran. Les autres pages historiques hors des 17 sous-pages V4.2 ne sont pas refondues dans ce lot. Aucun chantier mobile.

## Fichiers réservés

`dist/art-direction-v4.js`, `dist/art-direction-v4.css`, `tests/art-direction-v4-browser.py`, `docs/decision-studio-v43.md`, `DEVELOPPEMENT.md`. Aucune modification Business, DATA-06 ou du producteur. Passation de coordination dans l'issue #73 ; PR autonome sans fusion.

## Revue V4.3.1 des captures — 1er novembre 2026

Archive réelle du workflow Chromium #41303665206, artefact #13082381296 : **51 captures inspectées** (17 Analyste 1440×900, 17 Analyste 1920×1080, 17 Tribune 1440×900) et rapport `report.json` : **530 contrôles réussis, zéro erreur JavaScript** sur HEAD `6f65c51`. Constat visuel ciblé : les cinq très grandes cartes Calendrier contiennent le nom et l'abréviation de l'adversaire dans leur tiers supérieur et une grande zone vide en dessous, particulièrement en 1920×1080. Correctif V4.3.1 limité à ce calendrier : numérotation décorative 01–05 en filigrane, nom d'adversaire ancré en bas derrière un filet, contenu et navigation native inchangés, deux thèmes. Nouveau contrôle Playwright pour vérifier la position des noms et les cinq repères ; **résultat sur nouvelle tête à confirmer par CI**. Les autres captures ne révèlent pas de défilement global ou de panneau tronqué à ce niveau de revue ; l'acceptation esthétique reste distincte du passage des tests.
