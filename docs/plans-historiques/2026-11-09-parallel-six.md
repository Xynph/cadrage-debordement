# Six développements parallèles — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Livrer six tranches utiles du comparatif concurrentiel, raccordées au client Godot, avec tests et limites explicites.
**Architecture:** Six branches isolées, domaines natifs indépendants et vues Godot dédiées. L’intégrateur seul modifie les manifestes et les points partagés. Réutiliser les moteurs existants, projections pures quand possible, pas de bonus gratuit ni de nouvelle règle officielle supposée.
**Tech Stack:** JavaScript/CJS Node22, Godot4.7.2 GDScript, worker transactionnel existant.
**Spec:** Proposition détaillée de comparaison dans la conversation, acceptée par la demande de tout développer en parallèle ; designs précis dans docs/parallel-{market,staff,analytics,youth,match,editor}.md. Les choix de tranche sont ceux du constructeur dans le cadre de l’autonomie autorisée.

## Global Constraints
- Source main e38a79f, chaque agent dans sa branche/worktree disjoint.
- Aucun nouveau service payant ni dépendance réseau de jeu.
- Anciennes sauvegardes préservées, imports stricts, transactions worker seules responsables du disque.
- Ne pas inventer de statistiques ou de causalité, respecter les règles attestées et distinguer les abstractions fictives.
- Pas de fusion de ce lot sans réception complète ; publication par root.

## Review Focus
- Refus de transfert : argent/effectifs/contrats/profil inchangés.
- Jeunes et staff : pas de double bonus, plans explicites prioritaires, absence de suivi tolérée.
- Analyses/relecture : preuve issue du moteur et limites sur données absentes, lecture sans mutation.
- Éditeur : doublons/calendrier incohérent refusés, compétition fictive explicite.
- Raccord Godot : parsing et accès réel aux vues, compatibilité fenêtres usuelles.

## Tâches indépendantes
- [x] Marché — module interclub-market, vue et entrée Effectif, tests argent/contrats/sauvegardes/refus.
- [x] Staff — mentorat spécialisé utilisant le budget de progression existant, vue Staff, activation volontaire et tests de priorité/validation.
- [x] Analyses — historique réellement produit, tendances et conseils traçables, vue Mémoire, tests de provenance/pureté.
- [x] Jeunes — objectifs/bilans/recommandations dérivés, réorientation par plans existants, tests données manquantes et modèles annuels.
- [x] Match — relecture des événements réels dans Journal, parcours actions et géométrie réelle ; pas de faux replay animé.
- [x] Éditeur — calendrier fictif validé, aperçu et échange local ; pas d’altération des compétitions officielles.

Chaque tâche produit un commit et sa documentation, après tests ciblés. Root lit les changements et vérifie les interfaces avant intégration.

## Intégration et validation
- [x] Recevoir les six commits, relire les mutations et résoudre les dépendances.
- [x] Raccorder native-systems et manifestes build, vérifier commandes uniques et projections.
- [x] Écrire test worker croisé de projection pure, commandes réelles, refus atomique et reprise disque.
- [x] Exécuter suites ciblées, parsing Godot et recette UI adaptée.
- [ ] Documenter résultat et limites dans DEVELOPPEMENT, publier branche/PR, recevoir CI exacte.

## Réception en cours
- Analyses : commit producteur 3c2478b, intégré f72db53 ; manifeste raccordé.
- Staff : commit producteur f924a33, intégré 858b15e ; revue indépendante analytics reçue, deux observations corrigées (import orphelin et libellé arbitrage25/50).
- Test croisé tests/parallel-six-integration.cjs : rouge confirmé avant raccord des domaines (absence interclubMarket).
- Baseline tests/native-systems.cjs : PASS sous Node22.
- Staging root : PASS, assets anonymisés et ressources locales générés.
- Décisions de tranche : transferts immédiats fictifs plutôt que précontrats non vérifiés ; mentorat optionnel sans nouvelle économie ; relecture événementielle plutôt qu’animation d’un plaqueur non mesuré ; éditeur de calendriers échangeables, pas de nouvelle carrière personnalisée à ce stade.

## Réception finale locale
Six lots reçus et correctifs de revue intégrés. 41tests backend regroupés, quatre recettes Godot et test croisé production (achat+activation mentorat+reprise+import) PASS. Revue indépendante transverse clean. Les limites produit sont explicites dans le journal. CI distante et publication à recevoir.
