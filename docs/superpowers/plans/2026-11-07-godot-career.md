# Plan Godot — carrière et direction artistique

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for the cohesive engine task and art scene, with task reviews and one final whole-branch review. Parent implements the disjoint native UI and packaging.

**Goal:** une version Windows native belle et jouable avec menus, vraies décisions et carrière France30 reliée.

**Architecture:** Godot UI en vues spécialisées ; moteur JavaScript natif partagé, nouveau mode France séparé des anciens ; modèle1 enrichi de façon additive. Réutiliser le pont atomique et les ressources déjà reçues.

**Tech Stack:** Godot4.7.2 GDScript, Node embarqué, JavaScript de simulation existant, TTF et WebP locaux.

**Spec:** `docs/superpowers/specs/2026-11-07-godot-career-design.md`.

## Contraintes globales

Windows natif, zéro navigateur/HTTP. Aucune BDD Rugby Réel ni donnée de l'autre producteur modifiée. Anciens modes et sauvegardes conservés, toutes valeurs/actions métier réelles ; consultations sans RNG/écrit. Trente IDs stables, divisions14/16, moteur existant et format vérifié. Stockage hors exécutable, refus visible/rollback, imports stricts, processus enfant fermé. Aucun contrôle décoratif présenté comme action. Pas de souris/CUA/activation des fenêtres de Léo. Pas de nouvelle R&D animation.

## Points de revue

Carrière absente/corrompue : menu stable sans création répétée. Joueur blessé/perdu après affichage : commande revalidée, refus clair. Journée sans match/fin de saison : action correcte. Import multilingue volumineux ou disque bloqué : pas de lecteur perdu ni succès simulé. Affichage aux deux tailles, photo panoramique et nom long : actions/terrain/focus non rognés.

### Tâche1 — carrière France30 et contrôleurs natifs

Producteur exclusif : nouveaux modules France et raccordements minimaux listés dans le plan France reliée ; native/engine/worker.cjs, model.cjs, gestion.cjs si utile ; tests/france-* et tests/godot-management.cjs. Aucun main.gd, thème, scène3D, build ou journal parent.

- [ ] Lire audit/plan France et références officielles exactes avant logique de compétition. Confirmer la forme du modèle et les payloads à l'intégrateur avant UI.
- [ ] RED calendriers/classements14/16,433 résultats, contextes croisés, lieux/départage, promotion/barrage, IDs stables, trente départs ; imports hostiles/écrit refusé/rollback et anciennes carrières identiques.
- [ ] Implémenter mode natif France30 et passage de saison ; ne pas activer la page web incompatible. Raccorder composition/tactiques/charges/capitaine/buteur/recrutement/contrats aux contrôleurs existants, sans coefficients inventés.
- [ ] GREEN saisons natives multiples dont au moins huit à dix pour taille/nœuds, validations/export/reprise à chaque transition ; commandes invalides/déjà périmées refusées ; projections sans RNG/écrit.
- [ ] Commit ciblé, rapport exact et revue indépendante ; corrections/re-revue avant raccordement.

### Tâche2 — UI native de jeu

Parent : native/godot/main.gd, theme.gd, visual_widgets.gd, nouveaux ui/*.gd ; qa_runner.gd et tests/godot-ui.gd ; staging/build et journal.

- [ ] Composition avant détails : menu d'accueil photographique, création par division et club, reprise/import/paramètres réels ; navigation et action contextuelle unifiées, préalpha discrète.
- [ ] Vues Bureau, Effectif/Fiche, Composition, Préparation, Calendrier, Classements, Recrutement/Contrats, Finances, Club : consommer le modèle convenu, actions reçues seulement, retours/lock métier visibles. UI divisée en fichiers par responsabilité.
- [ ] Tester l'accueil sans carrière, confirmation du remplacement, consultation stable, refus disque, joueur périmé, nom long/couleur claire, vrai deuxième match et intersaison, sauvegarde et import/export.
- [ ] Captures Windows exactes1440×900/1920×1080, réception visuelle et clavier automatique, aucune utilisation de souris.

### Tâche3 — scène et ambiance

Producteur scène seul : native/godot/match_view.gd, aides visuelles3D éventuelles ; test/captures dédiés dans scratch. Consomme le même live.scene/live.teams, méthodes apply_frame et set_camera inchangées.

- [ ] Ajouter profondeur de lumière, pelouse/marquages, signalétique originale, ambiance de tribunes et meilleur angle TV, conserver tactique/terrain entier et lecture des équipes.
- [ ] Aucun acteur sportif/ballon ajouté sans trame ; interpolations et modèles/animations existants uniquement. Vue vide et présences30→29→0 restent vérifiées.
- [ ] Rendu Windows réel, tests de cadrage aux ratios UI et revue indépendante.

### Tâche4 — réception et publication

- [ ] Tests ciblés du modèle/gestion, France/saves et régression historique réellement exécutés ; parcours UI complet et intersaison, scènes reçues.
- [ ] Export ZIP autonome, manifeste/licences, profil existant14 repris et nouvelle carrière30 ; ZIP déplacé, PATH sans Node, processus et absence réseau observés, fermeture propre.
- [ ] Revue globale fraîche, corrections regroupées et re-revue. Rapport illustré/journal en français avec preuves/limites ; publier et vérifier tous les blobs de la branche/PR, CI du dernier SHA et gate officiel avant intégration.
