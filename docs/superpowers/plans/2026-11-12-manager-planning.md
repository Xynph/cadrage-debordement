# Fluidité et préparation du manager — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Réduire les réponses inutiles et permettre les trois arbitrages approuvés.
**Architecture:** Transport négocié autour du worker, réassemblage dans le pont.
Intentions natives bornées ; calculs de planning sur le modèle public uniquement.
**Tech Stack:** Node CJS, Godot 4.7.2, tests Node et GDScript.
**Spec:** `docs/superpowers/specs/2026-11-12-manager-planning-design.md`

## Global Constraints

- Aucun changement économique (#552), de règle sportive ou de données réelles.
- Aucun push main, installation PC pro, achat ou accès Téléchargements.
- Aucun nom/attribut caché dans une projection nouvelle.
- Intentions distinctes des commandes sportives et financières.

## Review Focus

- Un delta doit retirer les anciens reçus et champs supprimés.
- Un changement de carrière/pack ne doit pas conserver une branche obsolète.
- Un draft n'autorise ni doublon ni première ligne non qualifiée.
- Un joueur non observé conserve ses inconnues dans les scénarios.
- Une archive incomplète ne devient ni zéro statistique ni preuve de causalité.

### Task 1: Transport et lectures

**Files:** `native/engine/model-transport.cjs`, `worker.cjs`,
`native/godot/engine_bridge.gd`, `model_transport.gd`,
`tests/model-transport.cjs`, `tests/godot-model-transport.gd`.
**Interfaces:** `createTransport().encode(response, {version,base})` ;
enveloppe `transport` avec révision et branches modifiées/supprimées.

- [x] Tester échec puis reconstruction exacte, pertes de révision, refus,
  suppression des reçus et repli complet.
- [x] Implémenter la négociation et le réassemblage hors thread UI.
- [x] Cacher les seules projections VM pures entre consultations ; invalider
  avant toute commande autre que snapshot.
- [x] Recevoir le vrai pont, mesurer tailles et durées, commit.

### Task 2: Intentions et projections

**Files:** `native/engine/manager-planning.cjs`, `native-systems.cjs`,
`worker.cjs`, `tests/manager-planning.cjs`.
**Interfaces:** commandes `manager_plan_lineup`, `manager_plan_scenario`,
`manager_plan_goal` ; projection `managerPlanning` sur le modèle public.

- [x] Tests rouges de drafts, scénarios et objectif, refus atomiques,
  sources manquantes, contexte périmé, export/import et lecture pure.
- [x] Domaine VM pour intentions par identifiant, validation stricte/bornée.
- [x] Projections publiques : trois rencontres, trois horizons, coûts et
  suivi mesuré ; aucune transaction ou prédiction cachée.
- [x] Tests verts et suites natives concernées, commit.

### Task 3: Atelier du manager et réception

**Files:** `native/godot/ui/manager_planning.gd`, entrées Bureau/Préparation,
`tests/godot-manager-planning.gd`, `tests/godot-manager-planning.cjs`.
**Interfaces:** modèle `managerPlanning`, commandes Task 2.

- [x] Écrire et observer la recette rouge des trois parcours.
- [x] Atelier responsive en conteneurs, choix provisoires et validations
  explicites ; aucun clic de consultation n'exécute une transaction.
- [x] Tests Godot réels, captures Linux et mesures cumulées.
- [x] Revue de branche, corrections couvertes, PR avec limites Windows.

## Journal de réalisation

Task 1: complete — transport Node/Godot et stdio réels, cache de snapshot.
Task 2: complete — intentions, horizons, prêts, import signé et reprise reçus.
Task 3: complete — 34 contrôles dans le vrai jeu, captures Linux, revue indépendante et correctifs couverts.

Les décisions et limites sont consignées dans `docs/manager-planning-20261112.md`.
PR préparée sur la branche dédiée ; aucune fusion ou livraison Windows effectuée.
