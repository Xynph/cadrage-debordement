---
name: ccgs-studio
description: Rôles de studio du kit Claude Code Game Studios (game designer, directeur technique, QA, UX, économie…) et règles pour utiliser les commandes CCGS depuis Codex. À lire avant toute commande CCGS ou quand une tâche relève d'un rôle de studio.
---

# Studio CCGS pour Codex

Le kit Claude Code Game Studios est installé dans `.claude/` (pour Claude Code)
et ses commandes sont copiées dans `.agents/skills/` (pour Codex).
`AGENTS.md` prime sur tout le kit.
Kit d'agents : CCGS seul (décision de Léo, 16/11/2026) ; ne pas utiliser ni
réinstaller Superpowers (ses plans passés sont dans `docs/plans-historiques/`).

## Rôles (agents)

Les 38 rôles sont décrits dans `.claude/agents/<rôle>.md`. Pour travailler
« en tant que » rôle : lire ce fichier et suivre ses consignes. L'en-tête
(`tools`, `model`, `maxTurns`, `memory`) est propre à Claude Code : l'ignorer.
Si Codex peut lancer des sous-agents, leur donner le contenu du fichier comme
consigne ; sinon, endosser le rôle soi-même.

Rôles disponibles :
- `accessibility-specialist` : Accessibility standards and assistive features — remapping, text scaling, colorblind modes, screen reader support.
- `ai-programmer` : Implements game AI — behavior trees, state machines, pathfinding, perception, decision-making, NPC and enemy behavior, AI debugging.
- `analytics-engineer` : Telemetry and analytics — event tracking, player behavior, A/B test frameworks, dashboard specification, data pipelines.
- `art-director` : Owns visual identity — style guides, art bible, asset standards, color palettes, UI visual direction.
- `audio-director` : Owns sonic identity — music direction, sound palette, audio implementation strategy, mix balance.
- `community-manager` : Player-facing communication — patch notes, social posts, community updates, feedback collection, player bug triage, crisis communication.
- `creative-director` : Highest creative authority — vision, tone, aesthetic direction. Use when a decision affects game identity or department leads deadlock.
- `devops-engineer` : Build pipelines, CI/CD configuration, version control workflow, branching strategy, automated test pipelines, deployment infrastructure.
- `economy-designer` : Resource economies — loot tables, sink/faucet analysis, progression curve calibration, economic balance.
- `engine-programmer` : Core engine systems — rendering pipeline, physics, memory, resource loading, scene management, performance-critical framework code.
- `game-designer` : Mechanical and systems design — core loops, progression, combat, economy, player-facing rules. Mechanics-level questions.
- `gameplay-programmer` : Implements designed mechanics as code — player systems, combat, interactive features, gameplay system code.
- `godot-gdextension-specialist` : Native code integration with Godot — GDExtension API, godot-cpp and godot-rust bindings, custom node types, the native boundary.
- `godot-gdscript-specialist` : GDScript code quality — static typing enforcement, signal architecture, coroutine patterns, GDScript idioms, typed and performant.
- `godot-shader-specialist` : Godot rendering customization — shading language, visual shaders, material setup, particle shaders, post-processing.
- `godot-specialist` : Authority on Godot-specific patterns and APIs — node/scene architecture, signals, resources; guides GDScript vs C# vs GDExtension.
- `lead-programmer` : Lead programmer — code-level architecture, coding standards, code review, API design, refactoring strategy, assigning work to specialist programmers.
- `level-designer` : Spatial design for levels and areas — encounter layouts, pacing, difficulty, layout planning, environmental storytelling.
- `live-ops-designer` : Post-launch content — seasonal events, battle passes, content cadence, retention, engagement analytics. Keeps the game fresh.
- `log-reader` : Lit journaux de tests et de CI, liste les échecs, ne modifie rien (Haiku).
- `log-reader` : Lit journaux de tests et de CI et liste les échecs, sans rien modifier (modèle léger).
- `localization-lead` : Internationalization architecture — i18n system design, string extraction workflows, locale testing, locale-specific issues, translation pipeline.
- `narrative-director` : Story architecture, world-building, character design, dialogue strategy. Narrative structure and direction rather than writing individual lines.
- `performance-analyst` : Performance analyst — profiling, bottlenecks, memory analysis, frame time investigation, recommends optimizations, tracks metrics over time.
- `producer` : Production concerns — sprint planning, milestone tracking, risk, scope, cross-department coordination when multiple departments must synchronize.
- `prototyper` : Throwaway builds — concept prototypes after brainstorm to test an idea is fun before GDDs; vertical slices pre-production. Speed over standards.
- `qa-lead` : Test strategy and process — test plan creation, bug severity assessment, regression planning, release quality gates, readiness evaluation.
- `qa-tester` : Writes test cases, bug reports, and checklists — test case generation, regression checklist creation, execution documentation.
- `release-manager` : Release pipeline — certification checklists, store submissions and page prep, platform requirements, version numbering, release-day coordination.
- `security-engineer` : Protects against cheating, exploits, breaches — anti-cheat measures, secure save data and network comms, player privacy compliance.
- `sound-designer` : SFX specifications and spec sheets — audio event documentation, mixing parameters, sound category definitions.
- `systems-designer` : Detailed subsystem mechanics — combat formulas, progression curves, crafting recipes, status effect interactions, mathematical modeling of a mechanic.
- `technical-artist` : Technical artist bridging art and engineering — shaders, VFX, rendering optimization, art pipeline tools, art-to-engine issues.
- `technical-director` : High-level technical decisions — engine architecture, technology choices, performance strategy, technical risk, cross-system conflicts.
- `tools-programmer` : Internal dev tools — editor extensions, content authoring tools, debug utilities, pipeline automation, editor workflow.
- `ui-programmer` : Implements user interface systems — menus, HUDs, inventory screens, dialogue boxes, UI framework code, screen flow.
- `ux-designer` : User experience flows, interaction design, information architecture — user flow mapping, interaction pattern design, onboarding, accessibility requirements.
- `world-builder` : World builder for lore — factions, cultures, history, geography, ecology, world rules. Faction design, lore consistency checks.
- `writer` : Writer of player-facing text — dialogue, lore entries, item and ability descriptions, environmental text.

## Traduire les commandes CCGS (écrites pour Claude Code)

- `AskUserQuestion` : en mode autonome (`project.yaml`), décider soi-même et
  noter la décision ; ne demander à Léo que pour suppressions, opérations
  destructives ou dépenses.
- `Task` / `Agent` avec `subagent_type: X` : voir « Rôles » ci-dessus.
- « May I write… ? » / « aucun commit sans instruction » : ne s'appliquent pas
  ici (voir `CLAUDE.md`, section « Adaptation »).
- Scripts `bash .claude/scripts/*.sh` et `.claude/hooks/yaml-helper.sh` :
  utilisables tels quels depuis la racine du dépôt.
- Configuration : `project.yaml` (Godot 4.7, GDScript, rigueur `minimal`).
- Les hooks de `.claude/settings.json` ne tournent pas sous Codex.
