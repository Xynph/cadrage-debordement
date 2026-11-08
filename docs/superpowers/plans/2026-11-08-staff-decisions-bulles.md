# Staffs, décisions et bulles — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrichir le jeu natif de staffs à identités interchangeables, d'un coach
en bulle BD et d'aides de gestion tirées du moteur existant.

**Architecture:** Godot conserve la présentation ; projections de lecture natives
séparées de la simulation. Registre de staffs anonymisé embarqué et identités/
images réelles privées référencées par IDs. Format de pack versionné compatible.

**Tech Stack:** Godot4.7.2 Windows, GDScript, Node26, JS/CJS, outils Python locaux.

**Spec:** docs/superpowers/specs/2026-11-08-staff-decisions-bulles-design.md

## Global Constraints

- Tous fichiers et livraisons sur E:, seul raccourci autorisé sur le bureau.
- Aucun reset ni écriture de test du profil personnel.
- Identités réelles et photographies hors distribution publique.
- Données LNR/recherches concurrentes non écrasées.
- Aucun résultat en attente annoncé vert ; gate officiel sans bypass.
- Lecture seule des aides : aucune mutation sportive/RNG par navigation.

## Review Focus

- Anciens packs installés sans clé staff : lecture sans migration implicite.
- Homonymes joueurs/staff et IDs inconnus : pas d'application d'identité croisée.
- Coach ouvert avec texte long et clavier à1280 : commandes toujours accessibles.
- Saison avancée et ancien relevé staff : date visible, pas de carrière réelle inventée.
- Grande équipe commune et rechargement : plafond cohérent entre aperçu/refus/signature.

### Task 1: Inventaire GitHub

**Files:** docs/idees-github-20261108.md ; artefacts de recherche hors dépôt.
**Interfaces:** Produit tableau sourcé, priorités et preuve par fichiers réellement
chargés ; consommé par Task4. Aucun état de jeu modifié.

- [ ] Lire les deux pages de PR ouvertes et les idées/issues pertinentes.
- [ ] Confronter chaque famille au main et au protocole Godot.
- [ ] Publier l'inventaire et les décisions retenues avec les références exactes.

### Task 2: Coach en bulle

**Files:** native/godot/guide/coach_guide.gd ; nouveau coach_bubble.gd ; tests Godot dédiés.
**Interfaces:** `GuideBubble` reste le Label dont `text` est prononcé ; panneau
`GuideSpeechBalloon` dessine contour/fond/pointe sans intercepter les clics.

- [ ] Ajouter puis exécuter un contrôle qui constate l'absence de vraie bulle.
- [ ] Composer la bulle ivoire, conserver défilement et texte vocal identique.
- [ ] Vérifier ouvert/compact/options/dialogues, clavier et trois résolutions.
- [ ] Commit de la fonction et des preuves utiles.

### Task 3: Staff et packs

**Files:** data/staff/verified.json, scripts/build-staff-registry.cjs,
native/engine/staff.cjs, staff-registry.json, media-packs.cjs, worker.cjs,
native/godot/ui/staff_view.gd, main.gd, tests/staff-registry.cjs, staff-packs.cjs,
scripts/build-godot-prototype.py et documentation du mod.
**Interfaces:** Staff `{id,clubId,name,role,sourceRole,observedAt,sourceSeason}` ;
`staff.project(model)` ajoute les équipes anonymes sans lire la BDD source privée.
Packv2 ajoute `staff` à l'overlay ; v1 continue identique, aucun champ carrière ajouté.

- [ ] Rassembler les sources officielles et les photos autorisées pour le pack privé.
- [ ] Tester registre30clubs/IDsuniques/anonymisation/déterminisme avant le compilateur.
- [ ] Compiler le registre public sans noms réels, URLs ni photos privées.
- [ ] Tester les packs v1/v2, doublons/IDs/image/path hostiles et état/RNG conservés.
- [ ] Implémenter l'overlay strict et atomique, page Staff et dates/fallbacks visibles.
- [ ] Construire le pack privé enrichi sur E: et recevoir création/changement/reprise.

### Task 4: Décisions de gestion

**Files:** native/engine/model.cjs, gestion.cjs, nouveau decisions.cjs,
native/godot/ui/squad_views.gd, match_screen.gd et tests/native-decisions.cjs.
**Interfaces:** `decisions` contient préparation/besoins/développement/rapport issus
des helpers existants ; les contrôleurs restent l'autorité des commandes.

- [ ] Réutiliser les idées de Task1 compatibles avec le moteur chargé.
- [ ] Tests de projection indépendante état/disque/RNG et de données manquantes.
- [ ] Raccorder analyse adverse, bilan chiffré, besoins/contrats et progression.
- [ ] Reproduire le blocage42 en base commune ; fixer uniquement sa politique
  cohérente après audit, puis tester aperçu, offre, signature et reprise aux bornes.
- [ ] Commit avec documentation des estimations et limites.

### Task 5: Carrière longue, revue et livraison

**Files:** tests/QA concernés, native/godot/qa_runner.gd, README.md,
DEVELOPPEMENT.md, docs/decisions-natives-20261108.md.
**Interfaces:** Consomme les quatre tâches et les sauvegardes historiques.

- [ ] Campagne multi-saisons14+16 : effectifs, finances, âge, mouvements, sauvegarde/reprise.
- [ ] Revue indépendante du diff complet, corriger les défauts reproduits.
- [ ] ZIP Windows neuf extrait/déplacé, recette réelle des fonctions aux trois tailles.
- [ ] Publication PR, CI du dernierSHA et gate officiel, vérifier post-fusion7/7.
- [ ] Installer sur E:, raccourci bureau, profil personnel conservé, bilan et passation.
