# Identity packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Livrer une base native commune anonymisée, le pack Rugby Réel et l’import d’identités personnalisées à la création et en carrière.
**Architecture:** Compilation des données actives en catalogue anonymisé ; état sportif indépendant des projections d’identité. Installation ZIP locale et atomique ; UI Godot raccordée aux commandes du worker.
**Tech Stack:** JavaScript/Node embarqué, GDScript/Godot4.7.2, Python de construction, Windows x64.
**Spec:** docs/superpowers/specs/2026-11-07-identity-packs-design.md

## Global Constraints

- Tout travail, outil, temporaire et livraison sous E:/Cadrage-Debordement ; raccourci bureau conservé.
- Aucun fichier BDD LNR/V12/naissances du producteur modifié, aucune proposition DRAFT activée ; copier les statistiques actives sans réévaluation.
- Même1592joueurs/30clubs/IDs/statistiques sous noms fictifs ou réels ; sauvegardes et progression préservées au changement de pack.
- Aucune image officielle ni catalogue de vrais noms embarqué dans le jeu de base ou publié sur GitHub par ce lot.
- Pas de changement de loi, compétition, économie centrale, renderer3D, workflow ou gate.
- Importeurs bornés et confinés, erreurs visibles, rollback complet ; profils hors exécutable.
- Anciennes carrières actives supprimées seulement à la réception finale autorisée ; lecteurs historiques conservés.

## Review Focus

- Pack de création choisi avec une carrière ouverte : cette carrière et son RNG ne changent pas (tâche2).
- Joueur transféré ou sorti de son club initial : son identité suit son ID, pas sa place ou son club courant (tâches2/3).
- Sauvegarde importée sur un profil sans le pack : liaison conservée, manque explicite, carrière jouable (tâches2/3).
- ZIP Unicode, noms quasi identiques, fichiers ajoutés ou source remplacée entre aperçu et confirmation : rejet sans écraser le pack précédent (tâche2).
- Le budget de validation doit accepter une vraie saison complète avec1592profils sans relâcher les limites des anciens formats (tâche1).

### Task1: Base commune et nouvelle carrière native

**Files:** scripts/build-rugby-common.cjs ; dist/rugby-common-rosters.js ; native/engine/common-rosters.cjs ; dist/france-career.js ; dist/saves.js ; native/engine/worker.cjs ; native/engine/model.cjs ; tests/godot-common-rosters.cjs.
**Interfaces:** `new_career {mode:'common',club}` ; `meta.database` ; nouveaux joueurs aux IDs LNR, noms fictifs déterministes distincts de toutes les identités source. Statistiques identiques au mod actif. `meta.catalogue` reste30clubs. Les modes fiction/france existants sont inchangés.
- [x] Écrire puis exécuter RED comparant1592IDs et36/11attributs/note/potentiel/traits du mod, pseudonymes uniques, création club0/29 et export/reprise.
- [x] Implémenter compilation déterministe avec empreintes de sources et initialisation avant les systèmes de carrière, sans créer puis remplacer un monde fictif.
- [x] Raccorder marqueur de base, bornes/imports, projection et garde du worker ; accepter les âges réels existants sans invention.
- [x] Exécuter GREEN parité intégrale, deux divisions, saison/intersaison, dépassement budget hostile, anciennes sauvegardes, rollback disque/RNG ; commit et revue ciblée.

### Task2: Packs d’identité et installation ZIP

**Files:** native/engine/media-packs.cjs ; native/engine/worker.cjs ; native/engine/model.cjs ; dist/saves.js ; tests/godot-media-packs.cjs.
**Interfaces:** commandes `pack_inspect`, `pack_install`, `pack_select` et `model.packs`, `logoPath`, `portraitPath`, `portraitStatus` exactement définis dans la spec. Manifest personnalisé `cd-identity-pack-v1` et adaptateur direct du ZIP fourni ; noms réels des1592joueurs issus de son inventaire et30noms de clubs vérifiés.
- [x] Écrire/exécuter RED pour vraie archive locale, Unicode/traversal/doublons/bombes/SHA/source modifiée, installation existante conservée, aucune exécution HTML.
- [x] Implémenter lecteur ZIP borné, normalisation/schéma, installation atomique et liaison de sauvegarde versionnée ; documenter les champs exacts du format retenu.
- [x] Ajouter projection par ID de toutes les vues et messages sans modifier l’état sportif ; sélections création/carrière indépendantes, rollback et pack manquant explicite.
- [x] Exécuter GREEN sur archive réelle1622images, personnalisé partiel, réel→base→réel après transfert et match, export/import/restart, refus disque et confinement ; commit et revue ciblée.

### Task3: Parcours Godot et médias

**Files:** native/godot/main.gd ; pack_manager.gd ; ui/pack_views.gd ; ui/entry_screens.gd ; ui/game_skin.gd ; ui/squad_views.gd ; qa_runner.gd ; tests/godot-pack-ui.cjs/.gd ; scripts/build-godot-prototype.py.
**Interfaces:** commandes/modèles précédents ; texture des fichiers installés via Image, cache borné, mention IA. Création `mode:'common'` et sélection de pack indépendante ; accès paramètres en carrière.
- [x] Écrire/exécuter RED sur vrai contrôle de création et paramètres, aperçu/confirmation/rejet, identité/photo visible, IA, bascule et focus.
- [x] Implémenter page Packs cohérente anthracite/ivoire, sélection visible, analyse avant confirmation, couverture/données distinguées et erreurs explicites ; raccord des blasons/portraits par ID.
- [x] Mettre la construction à jour pour inclure seulement le catalogue anonymisé et les nouveaux modules, pas les images officielles.
- [x] Exécuter GREEN SDK Windows réel1440/1920, 30clubs, import aux deux endroits, transfert/photoID, bascule progression identique, pack absent et échec ZIP ; revue ciblée.

### Task4: Distribution, audit et intégration

**Files:** README.md ; DEVELOPPEMENT.md ; docs/donnees-du-jeu.md ; docs/rugby-real-native-packs-20261107.md et captures ; livraison/jeu et donnees sur E hors Git.
- [x] Revue globale unique puis vague groupée de correctifs si nécessaire, conformément au workflow SDD.
- [x] Construire ZIP base propre, installer le pack privé au profil, recevoir le vrai executable déplacé et les sauvegardes ; vérifier manifeste/absence médias réels dans base.
- [x] Préserver une copie privée des anciens fichiers puis retirer les carrières actives autorisées ; mettre à jour cible/icône du raccourci bureau.
- [ ] Publier source et PR, vérifier HEAD/contenu, CI exacte et gate officiel si terminal ; sinon état CI en attente/non fusionnée. PASSATION#73.
- [x] Bilan français concis avec lacunes réellement constatées du mod et ordre recommandé, sans prétendre corriger les audits BDD non activés.
