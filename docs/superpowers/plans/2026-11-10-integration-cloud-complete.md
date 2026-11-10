# Intégration complète Oval Legacy — plan d’exécution

> **For agentic workers:** Use superpowers:executing-plans task-by-task, with an independent final review.

**Goal:** Réunir les passations PC, les six chantiers Cloud et les demandes ultérieures dans une version jouable, vérifiée et intégrée à main.

**Architecture:** Une PR cumulative depuis main reçoit les trois têtes publiées, sans réécrire les branches sources. Résolution manuelle des raccords du moteur, des sauvegardes et des scènes ; corrections limitées aux défauts d’intégration reproduits. Le portail officiel effectue la fusion avec SHA verrouillés après réception complète, puis la CI du reçu de fusion est contrôlée.

**Tech Stack:** JavaScript Node22, Godot4.7.2 sous Linux Cloud, GitHub Actions, gate ci/release-gate.cjs.

**Spec:** Autorisation utilisateur « fais tout ça » du10novembre2026 ; AGENTS.md, docs/developpement-parallele.md et docs/chat-release-gate.md. Les demandes produit déjà réalisées restent contraignantes.

## Global Constraints

- Un seul intégrateur ; aucun push direct sur main et aucun contournement de CI.
- Réception visuelle2560×1440 ; aucune nouvelle adaptation720p ou recette Windows.
- Préserver les sauvegardes anciennes et le RNG ; aucune perte ni réinitialisation implicite.
- Niveau propre exact, potentiel toujours en fourchette ; observation requise pour les qualités adverses.
- Notes au poste limitées à la tactique ; première ligne qualifiée et groupes de postes corrects.
- Monde présenté naturellement au manager ; provenance technique conservée dans la documentation interne.
- Utilisateur autorise cette intégration et le nettoyage des PR réellement remplacées ; aucune nouvelle confirmation de principe nécessaire.

## Review Focus

- Une feuille légale de22 joueurs doit rester compatible avec les causeries, scènes et reprises.
- La sortie de la causerie post-match ne doit pas sauter les jours du calendrier quotidien.
- L’ouverture d’une ancienne carrière n’applique aucun gain, nouveau tirage ou remplacement silencieux.
- Les scènes obligatoires ne doivent pas bloquer sans issue un parcours entraînement/match/inter-saison.
- Les changements de Gabi et du thème ne doivent pas annuler le clavier, les réglages d’accessibilité ou le défilement interne des listes.

## Task1 — Livrer une source cumulative traçable

Files: branche integration/oval-cloud-complet-20261110 ; docs/integration-cloud-complete-20261110.md.
Consumes: main5c19a27 ; Cloudde8c070 ; salles/staffb0421b7 ; Gabia9963e6, références complètes dans la réception finale.
Produces: un HEAD cumulatif, une PR réservée versmain et un inventaire des PR reprises.

- [x] Publier le plan et la PR de réservation, indiquant explicitement les recouvrements.
- [x] Recevoir Cloud, salles/staff et Gabi ; résoudre chaque conflit en conservant les deux contrats utiles.
- [ ] Vérifier syntaxe des scripts modifiés, imports Godot et compilation déterministe des catalogues.
- [x] Consigner les choix de résolution et committer la source cumulative.

## Task2 — Vérifier les raccords métier et les anciennes carrières

Files: native/engine/worker.cjs, native/engine/match-talks.cjs, tests/integration-cloud-complete.cjs et harness concernés selon conflit réel.
Consumes: source cumulative ; produit: parcours publics cohérents et sauvegardes restaurables.

- [x] Reproduire les défauts22 joueurs/calendrier quotidien par les vrais chemins moteur avant correction.
- [x] Corriger seulement les raccords confirmés et vérifier les non-régressions associées.
- [x] Parcourir une ancienne sauvegarde, une nouvelle partie, plusieurs semaines et une intersaison avec reprise.
- [ ] Exécuter la CI JavaScript complète des cinq shards sur le HEAD exact et résoudre tous les échecs bloquants.

## Task3 — Recevoir l’interface et la revue indépendante

Files: tests/godot-*.cjs/gd existants ; docs/integration-cloud-complete-20261110/ pour preuves choisies.
Consumes: même HEAD cumulatif ; produit: captures réelles1440 et revue des raccords.

- [ ] Stage Godot et réception des parcours Bureau, Effectif/Contrats, Tactique, Recrutement, Calendrier, sauvegardes, scènes et Gabi.
- [ ] Vérifier tris, listes complètes et défilement interne ; aucune qualité adverse exacte révélée.
- [ ] Publier des captures réelles représentatives ; aucun export privé de carrière dans GitHub.
- [x] Faire relire le diff d’intégration par un agent indépendant ; traiter les constats importants avec reproduction et tests.

## Task4 — Intégrer et transmettre

Files: PR cumulative et descriptions des PR réellement reprises, docs/integration-cloud-complete-20261110.md.
Consumes: tête finale, CI complète verte et main exact vert ; produit: reçu main validé.

- [ ] Vérifier que les trois têtes sources et main n’ont pas avancé sans réception.
- [ ] Exécuter le portail officiel en check puis merge avec CD_EXPECTED_HEAD_SHA et CD_EXPECTED_BASE_SHA.
- [ ] Vérifier le SHA du reçu et les sept jobs complets de la CI post-fusion.
- [ ] Fermer comme remplacées uniquement les PR prouvées intégrées, sans supprimer leurs branches.
- [ ] Mettre à jour la passation cumulative avec le reçu, les tests, les images et les éventuelles limites matérielles.
