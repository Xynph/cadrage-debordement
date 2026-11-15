# Rugby Legacy 27 — configuration Claude Code

Jeu de management de rugby à XV (dépôt historique « Cadrage Débordement »).
Ce dépôt embarque le kit **Claude Code Game Studios** (CCGS, licence MIT,
voir `.claude/LICENSE-CCGS.txt`) : 49 agents de studio (directeurs, chefs de
département, spécialistes), ~78 commandes `/…`, hooks et règles par dossier.

## Ordre de priorité des règles

1. Les consignes de Léo dans la conversation.
2. `AGENTS.md` (cycle de travail, CI, fusions, données réelles) — **il prime sur
   tout le kit CCGS**.
3. Ce fichier, puis les documents CCGS sous `.claude/`.

@AGENTS.md

## Adaptation du kit CCGS à ce projet

Le protocole CCGS d'origine (« demander avant chaque écriture », « aucun commit
sans instruction ») **ne s'applique pas** ici. Léo veut un maximum d'autonomie :

- Écrire, committer, ouvrir des PR et fusionner selon `AGENTS.md`, sans
  demander de validation pour les décisions techniques secondaires.
- Demander d'abord pour : suppression de fichiers ou de données, opération
  destructive ou irréversible, toute dépense ou appel à un service payant
  (`project.yaml` → `modes.automation_always_ask`).
- Répondre en français, de façon courte et orientée résultat.
- Cap actuel : **consolider** (améliorer l'existant, rendre le jeu agréable,
  beau et addictif) plutôt qu'ajouter de nouvelles fonctionnalités.
- Uniquement la carrière **Monde** : aucun test sur l'ancien mode France.
- Données réelles (vrais noms, photos, logos) : jamais dans ce dépôt public ;
  elles vont dans le dépôt privé `rugby-reel-donnees` (pack Rugby Réel).
- Agents : modèle le plus puissant seulement pour la conception et le difficile
  (match 3D, interfaces nouvelles, moteur, économie) ; modèle léger pour le
  mécanique. Un agent ne dépasse jamais le réglage de la conversation.

## Technique

- Moteur natif : Godot 4.7 (GDScript, rendu GL Compatibility) dans
  `native/godot/` ; version web/JS et outils dans le reste du dépôt.
- `project.yaml` : configuration CCGS (moteur, rigueur `minimal`, automatisation
  `autonomous`).
- L'arborescence CCGS par défaut (`src/`, `design/`, `production/`) n'est pas
  imposée : les commandes s'adaptent à la structure existante. Les documents de
  conception CCGS (GDD, ADR) vont dans `docs/`.

## Commandes CCGS utiles ici

- `/adopt` ou `/project-stage-detect` : analyser l'existant.
- `/help`, `/next-step` : savoir quoi faire ensuite.
- `/balance-check` (économie, salaires), `/ux-review`, `/design-review`,
  `/perf-profile`, `/playtest-report`, `/tech-debt`, `/bug-triage`,
  `/team-polish`, `/team-ui`, `/team-qa`.

## Coordination

@.claude/docs/coordination-rules.md

## Normes de code

@.claude/docs/coding-standards.md

## Contexte de session

`production/session-state/active.md` (non versionné) sert de point de reprise
après compaction ou `/clear`. Les scripts de `.claude/scripts/` produisent des
observations, jamais des verdicts.
