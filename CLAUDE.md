# Rugby Legacy 27 — configuration Claude Code

Jeu de management de rugby à XV (dépôt historique « Cadrage Débordement »).
Ce dépôt embarque le kit **Claude Code Game Studios** (CCGS, licence MIT,
voir `.claude/LICENSE-CCGS.txt`) : 49 agents de studio + `log-reader` (directeurs, chefs de
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
  mécanique. Un agent ne dépasse jamais le réglage de la conversation. Pour
  cette raison, aucun agent ni commande du kit n'est épinglé sur `opus` : les
  trois agents directeurs (`creative-director`, `technical-director`,
  `producer`) suivent le modèle de la session (`inherit`), et
  `/architecture-review`, `/gate-check`, `/review-all-gdds` n'ont plus de
  `model:` (modifications locales à reporter après chaque mise à jour CCGS).
- Lancer une commande `/team-…` (qui ouvre plusieurs sous-agents) vaut accord
  de Léo pour ces sous-agents ; hors de ces commandes, la règle « aucun
  sous-agent sans accord » d'`AGENTS.md` s'applique. `log-reader` (Haiku) lit
  les journaux de tests et de CI sans rien modifier.

## Économie de tokens

- Un chantier = une session. Entre deux chantiers : passation dans la PR,
  puis `/clear` (le contexte accumulé est relu à chaque tour).
- Chercher d'abord en mode « fichiers » (Grep `files_with_matches`), puis lire
  la plage utile (`offset`/`limit`). Jamais `DEVELOPPEMENT.md` (250 Ko) ni
  `README.md` en entier : chercher la section.
- `.ignore` exclut des recherches les bases du monde et données d'une ligne
  (jusqu'à 11 Mo) : les interroger avec `node -e` ou `jq`, pas avec Grep.
- Journaux de CI et sorties de tests longues : `log-reader` (Haiku), qui rend
  seulement les échecs.
- 53 commandes CCGS hors sujet sont masquées au modèle
  (`disable-model-invocation`) mais restent utilisables en tapant `/nom`.

## Modèle et effort côté Claude

`AGENTS.md` demande de recommander l'effort de GPT‑6.1 Sol à Codex ; côté
Claude, recommander plutôt le réglage Claude adapté à la prochaine étape
(article « Which Claude model should you build with? », lu le 15/11/2026) :

| Tâche Rugby Legacy | Réglage conseillé |
| --- | --- |
| Correctif cadré, test qui échoue, régénération, docs | Sonnet 5.5, `medium` |
| Code courant, débogage, lot multi-PR | Opus 5.5, `medium` puis `high` |
| Match 3D, moteur, économie, refonte d'interface, architecture | Opus 5.5 `high` ; Fable 5.2 si `high` ne suffit pas |
| Lecture de journaux, recherche de fichiers | sous-agent Haiku (`log-reader`) |

Ordre d'escalade : 1) se donner un moyen de vérifier (test, build, capture),
2) monter l'effort d'un cran, 3) seulement ensuite changer de modèle, en
repartant d'un effort plus bas. Au-delà de `high`, un cran d'effort coûte
autant qu'un modèle plus grand. Changer de modèle en fin d'étape (le cache et
une partie du raisonnement sont perdus au changement).

## Technique

- Moteur natif : Godot 4.7 (GDScript, rendu GL Compatibility) dans
  `native/godot/` ; version web/JS et outils dans le reste du dépôt.
- `project.yaml` : configuration CCGS (moteur, rigueur `minimal`, automatisation
  `autonomous`).
- L'arborescence CCGS par défaut (`src/`, `design/`, `production/`) n'est pas
  imposée : `project.yaml` déclare `engine.code_root: native/godot` et
  `engine.test_root: tests`, et les règles `.claude/rules/` visent aussi
  `native/godot/`. Les documents de conception CCGS (GDD) vont dans
  `docs/gdd/`, les ADR dans `docs/architecture/`.
- Les commandes de lancement et de test du tableau CCGS (gdUnit4, projet à la
  racine) ne s'appliquent pas. Commandes réelles :
  - retour rapide : `node ci/quick-check.cjs <liste-des-fichiers-modifiés>` ;
  - une suite JS : `node tests/<suite>.cjs` ;
  - suites Godot (SDK 4.7.2 requis) : `bash ci/run-godot-suites.sh <liste>` ;
  - projet Godot : `godot --path native/godot`.

Version du moteur et écarts avec les connaissances du modèle :
@docs/engine-reference/godot/VERSION.md

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
