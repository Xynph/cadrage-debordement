# Youth Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre les décisions de formation utiles et leur progression observable à partir du moteur existant.

**Architecture:** Une factory native garde des baselines et plans bornés, sans croissance propre. `growPlayer` consulte facultativement son partage V29 ; le backend installe seulement des observations après les événements existants.

**Tech Stack:** JavaScript CommonJS/factory VM, Node 22, tests du vrai harness.

**Spec:** `docs/superpowers/specs/2026-11-09-youth-progression-design.md`

## Global Constraints

- Aucune croissance ni récompense lors d'une commande de plan, observation ou projection.
- En l'absence du domaine, résultat et RNG historiques inchangés.
- Les profils annuels V11 conservent leur moteur et refusent la spécialisation sans effet.
- Aucun championnat Espoirs activé dans Monde ; aucun fichier worker/model/gestion/saves partagé modifié par ce lot.
- État borné, numérique et sans noms copiés ; baseline à partir de l'activation seulement.

## Review Focus

- Baseline après import sans ancien suivi : afficher absence de passé, ne pas l'inventer.
- Promotion et changement de club : suivre l'ID et ne pas révéler de joueurs désormais adverses.
- Baselines contenant une qualité absente/non finie : import refusé, projection sans réparation.
- Appels répétés d'observation/match : mêmes points et même budget.
- Profils annuels : rendre visible l'exposition réelle et la différence de moteur.

### Task 1: Budget et plans

**Files:** modifier uniquement `dist/development.js` dans `growPlayer`; créer `native/engine/youth-development.cjs`; tester `tests/youth-development-plan.cjs`.

**Interfaces:** `growthShare(s,p,allowFocus): number|null`, plans `general|specialist|integration`, allocations 0/0,5/0,25.

- [x] Écrire puis exécuter le test qui réclame 0,30 XP générale et 0,10 XP ciblée pour 0,40 XP d'intégration.
- [x] Ajouter le hook facultatif puis la factory de choix, sans deuxième boucle de croissance.
- [x] Vérifier conservation, plafonds, restrictions et absence de plan avec les mêmes appels réels.

### Task 2: Observation et import

**Files:** même factory ; tests `tests/youth-development-observation.cjs` ; documentation de contrat.

**Interfaces:** `enable(s)`, `setPlan(s,...)`, `observe(s,reason)`, `project(s)`, `validate(s)`, commandes natives fermées.

- [x] Écrire les cas rouges baseline/delta/projection pure et sérialisation falsifiée.
- [x] Stocker les mesures numériques et observations bornées, préserver la baseline lors d'une révision/promotion.
- [ ] Vérifier observation répétée, transition annuelle et mobilité sans mutation de validation.
- [ ] Exécuter les nouvelles suites, V29, V72 et développement ; enregistrer le commit et le contrat de raccord.
