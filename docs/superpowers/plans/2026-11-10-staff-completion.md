# Staff Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. No subagents or commits in this delegated scope.

**Goal:** Compléter les staffs initiaux France30 et Monde116 par des personnages fictifs distincts des références.
**Architecture:** Module pur de fonction/tiers/génération, vue composée par édition, politique persistante optionnelle pour les nouveaux cycles. Anciennes carrières inchangées.
**Tech Stack:** Node CommonJS, VM native, tests node:test, portraits locaux banque2.
**Spec:** docs/superpowers/specs/2026-11-10-staff-completion-design.md

## Global Constraints

- 15 fonctions minimales hors manager humain ; tiers15/20/26 selon base<72/72–81/>=82 ; aucune baisse des staffs existants.
- Sources vérifiées et IDs des packs inchangés ; ajouts sourceKind generated et identityStatus fictional.
- Aucun coût/bonus/RNG/effet de visite ; anciennes sauvegardes sans nouvelle politique inchangées.
- Aucun fichier worker, manifeste, salle3D ou registre source modifié.

## Review Focus

- Intitulés génériques ou multilingues : ne pas déduire un médecin d’un soigneur ou d’un coach.
- Source historique : conserver la référence sans compter une personne active ni réanimer un retraité.
- Grand effectif sans spécialités : conserver chaque membre et ajouter les fonctions manquantes.
- Ancienne sauvegarde/licenciement humain : ne pas remigrer ni remplir au chargement.
- Portabilité VM/pack : même provenance et même visage, schéma strict malgré les noms réels normalisés.

### Task1 — Politique pure et vue initiale

Files: create native/engine/staff-completion.cjs; modify native/engine/staff.cjs; create tests/staff-completion.cjs.

- [x] Écrire/observer les tests rouges de fonctions, appariement, minima, tiers, sources immuables, noms/IDs, pureté et portraits.
- [x] Implémenter factory pure et composition mise en cache ; common et world utilisent la même vue.
- [x] Vérifier France30/Monde116 et produire le rapport avant/après sans données réelles ajoutées.

### Task2 — Cycle persistant compatible

Files: modify native/engine/staff-career.cjs; extend tests/staff-completion.cjs; add dedicated worker tests if needed.

- [x] Écrire/observer les tests rouges de provenance GENERATED, cibles fonctionnelles, compatibilité ancienne politique, libération sans refill et remplacement IA annuel.
- [x] Intégrer la factory pure à la factory sérialisée et ajouter le marqueur optionnel strict ; conserver validation ancien schéma.
- [x] Générer les nouveaux candidats avec des noms complets et portraits2 ; vérifier import/reprise/disk rollback réels.
- [x] Exécuter tests pertinents existants, rapporter toute limite de suite globale, puis rendre au parent sans commit.
