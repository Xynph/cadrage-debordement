# Dedicated Matchday Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mettre en place l'écran de match et les quinze interactions validées.
**Architecture:** Shell dédié après le rendu natif, réemploi du terrain 2D/3D ; contrôleur de cadence et des décisions via API natives. Préférences hors sauvegarde ; projections statistiques sans nombres inventés.
**Tech Stack:** JavaScript/CSS sans compilation, Node, Playwright Chromium.
**Spec:** docs/superpowers/specs/2026-11-07-dedicated-matchday-design.md

## Global Constraints
PC 1920×1080 et 1440×900, aucun défilement global. Aucun coefficient de jeu, règle rugby, MATCH3D, index réservé LNR ou schéma de sauvegarde modifié. Confirmation obligatoire pour Résultat immédiat. Statistiques permanentes.

## Review Focus
Fenêtre ouverte pendant incident : pause impérative conservée. Annulation de simulation : aucun effet carrière. Remplaçant devenu inéligible : refus explicite. Rafraîchissement périodique : focus et saisie préservés. Sauvegarde ancienne/LNR : aucune fausse donnée ou portrait réel inventé.

### Task 1: Contrôleur et projections
Files: dist/premium-editorial.js ; tests/premium-editorial-matchday.cjs.
Interfaces: CDEditorial.matchday {normalizePreferences,metrics,important,isStoppage,install}; window.CDMatchday {open,close,step,confirm,instant,setPreference,cancel}.
- [ ] Écrire tests préférences invalides, stats réelles/zéros/absences et arrêts structurés, lancer rouge.
- [ ] Ajouter contrôleur de cadence, pauses impératives, brouillon et file validée, simulation native avec adjoint.
- [ ] Exécuter Node : tests verts, simulation/gestion sans règles nouvelles.

### Task 2: Écran dédié
Files: dist/premium-editorial.js/.css ; tests/premium-editorial-live.mjs.
- [ ] Écrire tests d'écran : colonne stats, huit portraits, ticker, boutons, fenêtres, clavier.
- [ ] Ajouter shell compact, fenêtres et paramètres, réemployer terrain existant, filtrer caméras proches.
- [ ] Vérifier 2 tailles × 2 thèmes, canvas entier, conseil réel, vrai remplacement et export.

### Task 3: Qualification et publication
Files: .github/workflows/premium-editorial.yml ; docs/dedicated-matchday-20261107.md ; DEVELOPPEMENT.md.
- [ ] Comparer simulation immédiate au moteur natif avec graines et adjoint identiques ; tests sauvegardes et régression menus.
- [ ] Capturer et inspecter réellement les écrans, revue indépendante, corrections ciblées.
- [ ] Commit/PR, CI HEAD exact, gate officiel puis post-fusion si toutes protections réunies ; passation #73.
