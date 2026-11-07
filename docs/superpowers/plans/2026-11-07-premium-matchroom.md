# Premium Matchroom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Afficher immédiatement le terrain et donner quatre vraies pages aux commandes natives du direct.
**Architecture:** Réorganisation des mêmes nœuds dans premium-editorial.js, styles à portée ed-matchroom. Le cockpit natif et ses variables restent la source des actions et données.
**Tech Stack:** JavaScript natif, CSS, Playwright Chromium.
**Spec:** docs/premium-matchroom-20261107.md

## Global Constraints
- PC 1440×900 et 1920×1080, aucun scroll global.
- Aucun changement de S, RNG, disque en consultation ; aucun moteur, MATCH3D, DATA ou sauvegarde modifié.
- Aucun nœud de commande cloné ou supprimé ; inconnus accessibles dans Consignes.

## Review Focus
- Longs noms, deux thèmes : commandes lisibles et tailles de terrain conservées.
- Rendu pendant match en cours : vue et focus demeurent cohérents.
- Match en pause : fiches et remplacements accessibles sans duplication.
- Mode LNR : aucun visage fictif ajouté.
- Modes 2D/3D : mêmes conteneurs et contrôles, pas de scène parallèle.

### Task 1: Salle de match native
**Files:** dist/premium-editorial.js, dist/premium-editorial.css ; tests/premium-editorial-live.mjs ; workflow premium-editorial.yml.
**Interfaces:** enhanceLive(main, model) consomme les éléments du cockpit existant et matchCockpitFocus. Produit quatre panneaux ARIA, branchés aux boutons existants.
- [x] Écrire le test : terrain dans le viewport, onglets et focus, états/disque identiques, nœuds et listes natives ; capturer les deux thèmes aux deux tailles.
- [x] Exécuter et observer l'échec géométrique sur main.
- [x] Implémenter le déplacement des nœuds et les styles, sans toucher les fonctions de match.
- [x] Exécuter les tests natifs et régressions, inspecter les PNG et corriger les écarts.
- [ ] Revue indépendante, correction unique des observations importantes, journal/commit/PR, réception CI exacte et gate officiel.

## Progression
Base main f1bd6c639c2527291f5361ae6d6d1df9e261bc56. Prévol, isolat et réservation #6704425025 réalisés. Tests à exécuter, aucun résultat anticipé.

Revue terminée, deux observations Important corrigées : cadre 3D complet et focus au rendu périodique. Local : 174 contrôles salle de match avant ajout du dernier échantillon de contraste, 315 contrôles gestion, 10 tests Node. La première ancienne suite V4 a atteint un timeout de capture local ; relance isolée en cours, aucun succès anticipé.

Dernière recette complète locale : 226 contrôles, 18 PNG, zéro erreur JS/asset ; carré 3D entier et focus au render vérifiés. L’ouverture des commandes détaillées est ajoutée au test final.
