# Plan Effectif et fiches joueurs Premium

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Exécution native autorisée dans la conversation ; revue indépendante finale.

**Goal:** rendre l'effectif dense et les fiches directement utiles dans le jeu natif.

**Architecture:** module `CDSquadPresentation` de projections HTML pures et décorateur DOM après `CDEditorial`. Les composants, contrôleurs, calculs et commandes UI02 restent la source métier. État de sélection et fenêtres en mémoire uniquement.

**Tech Stack:** JavaScript natif, CSS, node:test et Playwright.

**Spec:** `docs/superpowers/specs/2026-11-07-premium-squad-profiles-design.md`.

## Contraintes globales

Français, 1440×900 et 1920×1080, dix lignes à 1440, zéro défilement global, valeurs réelles, carrière et aléatoire invariants en consultation, aucun faux portrait LNR, quatre onglets natifs, aucun changement moteur/format/gate.

## Points de revue

Filtre vide : aucun aperçu périmé. Nom long : identité lisible sans recouvrement. Comparaison : focus et fenêtre maintenus après render. Carrière importée : sélection valide même si même club. Valeurs absentes : aucun zéro inventé.

### 1. Tableau et dossier natifs

Fichiers : créer `dist/premium-squad.js`, `dist/premium-squad.css`, `tests/premium-squad.cjs`, `tests/premium-squad-browser.mjs` ; modifier `dist/index.html` (chargement) et `dist/premium-editorial.js` (suppression aperçu/radar doublon seulement).

Interface : `CDSquadPresentation.selectPlayer(ids, previous)` renvoie un ID présent ou null ; `playerCard(projected, options)` et `profileOverview(projected)` produisent du HTML échappé sans mutation. `install(globalThis)` décore uniquement la route team après chaque rendu natif.

- [x] Tests RED : sélection filtrée/vide, valeurs nulles, HTML hostile, projection invariante ; navigateur : dix lignes, aperçu choisi, un radar, actions natives, filtre vide, comparaison/focus/Échap, carrière neuve/avancée, LNR, tailles et thèmes.
- [x] Exécuter et constater les échecs avant implémentation.
- [x] Implémenter les projections et le décorateur ; préserver les liaisons UI02 et raccorder les deux nouveaux assets dans index.
- [x] Exécuter les tests ciblés et corriger tout échec ; inspecter les captures.

### 2. Qualification et livraison

Fichiers : `.github/workflows/premium-squad.yml`, `docs/premium-squad-profiles-20261107.md`, `docs/premium-squad-captures/*`, `DEVELOPPEMENT.md` ; adapter `tests/premium-editorial-browser.mjs` seulement si une ancienne assertion décrit une présentation remplacée.

- [x] Exécuter les régressions sauvegardes/UI02/rotation/Bureau/match ; revue indépendante du diff complet et corrections vérifiées.
- [ ] Documenter mesures, captures et limites ; un commit final publié/vérifié, une PR attachée, CI complète sur le dernier SHA et parcours navigateur distant.
- [ ] Coordonner le rôle d'intégrateur dans #73, vérifier main/HEAD/protections puis gate officiel, CI post-fusion 7/7 et passation brève. Si le gate reste techniquement bloqué, publier les preuves et l'état réel sans bypass.
