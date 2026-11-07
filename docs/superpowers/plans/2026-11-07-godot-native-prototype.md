# Plan prototype Godot natif

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for the independent bridge and3D tasks; the parent implements the art direction and packaging natively, then commissions one fresh whole-branch review.

**Goal:** livrer une épreuve Windows native convaincante de la direction artistique et du raccord à la simulation, sans navigateur.

**Architecture:** UI/3D Godot, processus Node embarqué réutilisant les modules réels, JSON lignes sur pipes non bloquants. Atlas commun depuis `dist/assets/club-atlas`. Pas de nouveau moteur de rugby ni de BDD modifiée.

**Tech Stack:** Godot4.7.2 stable/GDScript, Node JavaScript existant, WebP et TTF/OFL, build Python.

**Spec:** `docs/superpowers/specs/2026-11-07-godot-native-prototype-design.md`.

## Contraintes globales

Prototype explicite, Windows x64, aucun Chrome/Edge/WebView ni dépendance à installer pour jouer. Valeurs et matchs issus du moteur, profil prototype isolé et erreurs visibles. Pas de faux mode30 déjà jouable, pas de BDD LNR, pas de nouvelle R&D animation. Préserver le projet historique et ses sauvegardes.

## Points de revue

Processus absent/crash/pipes partiels ou UTF8 coupé ; fermeture sans processus orphelin ; disque refusé sans réussite affichée ; référence de joueur non possédé ; image/crédit manquant ; contraste des accents ; clic répété pendant commande en cours.

### 1. Pont réel de simulation

Créer `native/engine/worker.cjs`, `native/engine/model.cjs` si nécessaire, `native/godot/engine_bridge.gd`, `tests/godot-engine.cjs` et rapport de tâche. Ne modifier aucun moteur `dist` ni les fichiers DA.

Interface Godot : `class_name NativeEngineBridge extends Node`, signaux `model_changed(model:Dictionary)`, `command_failed(message:String)`, `ready`; `start(data_dir:String)`, `send(command:String,payload:Dictionary={})`, `stop()`. Chemins dev depuis projet/variableCD_NODE_EXECUTABLE ; export depuis dossier .exe/runtime/node.exe et .exe/engine/worker.cjs. Aucun shell de commande. Protocole et modèle exactement décrits dans la spec.

- [ ] RED : commandes/IDs invalides, vrai état/export/match identiques au moteur direct, actions et sauvegarde/reprise, écriture refusée, commandes après fermeture.
- [ ] Implémenter un chargement headless de production des mêmes modules, sans importer le harness tests ; whitelist de commandes et garde transactionnelle. Pas de message non JSON sur stdout.
- [ ] Tester le modèle, le protocole et les mutations ; tester pont Godot sans blocage. Reporter preuves et limitations, commit local ciblé, revue indépendante.

### 2. Scène de match native

Créer `native/godot/match_view.gd` uniquement (+ rapport hors production). `class_name NativeMatchView extends Node3D`, `apply_frame(live:Dictionary)`, `set_camera(mode:String)`. Consommer `live.scene` normalisé par le vrai adapter et `live.teams` pour noms/couleurs ; positions/score ne sont jamais décidés ici.

- [ ] Vérifier la forme de l'adapter source et ses unités ; construire terrain110×80, lignes, enceinte générique, ciel/lumière/ombres, modèles existants licenciés et maillots lisibles.
- [ ] TV éloignée et tactique cadrent le terrain entier ; personnages suivent/interpolent les positions et les présences. Réutiliser les animations présentes sans créer une nouvelle logique physique/rugby.
- [ ] Import/run Godot sans erreur, contrôle du nombre de joueurs/ballon et des deux caméras ; pas de mutation du payload. Captures réelles et réception par le parent DA ; commit ciblé, revue.

### 3. Application et direction artistique

Parent : `native/godot/project.godot`, `main.tscn`, `main.gd`, `theme.gd`, aides UI si nécessaires, `scripts/build-godot-prototype.py`, tests Godot de réception, `.gitignore` des ressources générées.

- [ ] Préparer soixante WebP vérifiés et manifeste/crédits, fontes TTF avec licences, atlas portraits et modèle3D licencié ; staging reproductible vers assets du projet, pas de sources privées.
- [ ] Composition native Bureau/Club/Effectif/Fiche/Match. Boutons réels vers les commandes du pont, retours d'état/error, pause/vitesse de présentation et contrôles de fenêtre ; aucun contrôle décoratif présenté comme une action.
- [ ] Parcourir les trente territoires en catalogue et distinguer la portée du prototype. Réception1440×900/1920×1080, deux accents de club, noms longs, quatre vues capturées et examinées.

### 4. Épreuve Windows exportée et livraison

- [ ] Export Windowsrelease avec templates officiels et runtime Node embarqué ; licences Godot/Node/fontes/photos/modèle, manifeste des fichiers/empreintes et notice courte.
- [ ] Ouvrir réellement le .exe exporté avec profil temporaire, effectuer entraînement/fiche/club/match/sauvegarde/reprise, vérifier ses processus propres sans navigateur, lancer ZIP déplacé, absence réseau et arrêt propre.
- [ ] Revue fraîche du diff complet, corrections et tests pertinents ; publier branche/PR et preuves. Ne pas annoncer portage complet, carrière30 ou publication Steam avant leurs travaux propres. La prochaine décision produit porte sur l'acceptation du prototype et la poursuite du portage.
