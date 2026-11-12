# Calendar Session Reading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ouvrir le créneau publié exact depuis son ID, dans le programme du jour existant, avec retour sans mutation.

**Architecture:** Competition valide et résout une séance de la projection courante. Le calendrier conserve sa vue et focalise la séance sélectionnée ; le contrôleur applique son chemin de consultation commun.

**Tech Stack:** GDScript, Godot 4.7.2 officiel, Node 22, registre SDK existant.

**Spec:** `docs/superpowers/specs/2026-11-12-calendar-session-reading-design.md`

## Global Constraints

- Base code : `3aef0263` ; ne pas déplacer `76077ed3` pendant ses campagnes.
- Aucun moteur, donnée, économie, calendrier métier, workflow, réglage GitHub ou asset réservé modifié.
- Aucun appel métier pendant la lecture ; modèle/profil/seed/horloge/bridge inchangés.
- Godot sérialisé exclusivement par root avec `/workspace/work/rg27-godot.lock`.
- Dummy et trois compteurs vocaux ; aucune hausse des délais existants ou de la VM 15 s.
- Réaffecter les agents spécialisés autorisés par l’utilisateur ; navigation_core garde seul le contrôleur partagé.

## Review Focus

- ID vide, inconnu, dupliqué ou date invalide : refus sans effet, pas de prochaine séance substituée.
- ID dont le nom assaini entre en collision : focus et destination restent liés à l’ID exact.
- Filtre initial masquant les séances : la destination devient visible, puis Back restaure le filtre.
- Créneau passé : aucune affirmation de réalisation ou d’effet sportif.
- Cible déjà ouverte et scène obligatoire : ni doublon d’historique ni contournement des gardes.
- Origine `calendar_table=true` : construire le programme, puis restaurer le tableau au retour.

---

### Task 1: Test d’acceptation avant le code

**Owner:** functional_qa ; root exécute. **Files:** créer `tests/godot-calendar-session-links.gd` et `.cjs`.

**Interfaces:** consomme la vraie scène main, `navigation_controller.open_entity({kind:"session",id})`, les boutons avec métadonnées `entity_kind=session/entity_id`, et l’état `calendar_reading` existant. Produit un rapport ciblé avec checks, failures, compteurs, captures et SHA.

- [x] Écrire un parcours réel : carrière Common 0, refus pendant le rendez-vous obligatoire, puis préparation publique terminée avant baseline.
- [x] Choisir un ID réel daté différent d’aujourd’hui ; filtrer la grille, ouvrir le lien hebdomadaire au clavier puis à la souris, vérifier jour exact, focus et contenu publiés.
- [x] Vérifier Back : sélection/mois/vue/filtre/scroll/focus ; répétition sans doublon ; profil/modèle/seed/horloge/bridge inchangés.
- [x] Ajouter les classes du Review Focus. Les projections synthétiques sont des copies isolées, jamais des sauvegardes modifiées ou des captures présentées comme réelles.
- [x] Fixer mute et compteurs avant attente ; wrapper enfant 90 s, superviseur existant 180 s, sans avancer de journées ni exporter pendant la consultation. La proposition initiale de 120 s n’était pas consommée par le contrôleur : aucun champ ignoré ni changement du contrôleur n’est ajouté.
- [x] Root reçoit d’abord le rouge attendu sur la base sans adaptateur, sans Parse Error ni faux échec de fixture. Conserver ce reçu puis annoncer le début de l’implémentation.

### Task 2: Adaptateur et raccord commun

**Owners:** world_links (`competition_canvas.gd`, `month_calendar.gd`) ; navigation_core (`navigation_controller.gd`) ; worktrees séparés.

**Interfaces:** `Competition.target_available(owner_app, "session", id)` et `Competition.open_target(owner_app, "session", id)` réutilisent les signatures existantes ; ajouter `Competition.session_focus_name(id: String) -> String` pour le bouton du détail. `calendar_reading.focus` contient ce nom stable. `Competition.session_context_matches(owner_app: Control, id: Variant) -> bool` valide que la séance exacte est encore sélectionnée dans le programme visible ; core l’utilise pour la cible courante et la répétition, après les gardes. World possède la persistance/invalidation de ce contexte de lecture.

- [x] World résout uniquement la séance unique de `calendarPlanning.sessions`, date validée par `calendar_agenda.valid_date`.
- [x] World réutilise l’ouverture date, définit filtre/date/focus et rend des boutons cohérents avec les polices et styles existants ; aucun nouveau dialogue ou réglage métier.
- [x] Core ajoute `session` au chemin Competition, destination Calendrier et exclusions de navigation redondante ; conserver les gardes/historique communs et le refus fermé.
- [x] Root intègre les commits compatibles et reçoit le vert du test initial ; faire corriger le code si un invariant échoue.
- [x] Revoir séparément les changements par un agent qui n’en est pas l’auteur.

### Task 3: Registre et réception partagée

**Owners:** ci_closeout (registre/preuves), root (validation/publication).

**Files:** `ci/godot-sdk-followup.json`, contrat existant `tests/ci-godot-sdk-registry.cjs`, documentation de recette.

- [x] Ajouter le nouveau wrapper une seule fois à une famille dont l’enveloppe reste sous 45 min ; conserver le superviseur existant 180 s et l’enfant 90 s, sans relever de limite existante. Enveloppe conservatrice 44 min 44,022 s, non garantie de durée réelle ; reçu graphique local 50,359 s.
- [ ] Vérifier la couverture et les sélecteurs : total attendu 76 exécutions / 57 suites / 75 couples suite-cas, doublon historique conservé.
- [ ] Root reçoit le nouveau parcours en 2560×1440 et les contrôles de taille ; rejouer Navigation/Entités et les régressions calendrier pertinentes après modification.
- [ ] Publier le lot consolidé en brouillon, réécrire titre/description autour du périmètre final, puis une seule validation SDK/JS partagée du HEAD final si les reçus sont bons.
- [ ] Conserver séparément les campagnes de `76077ed3`, les échecs précédents et les résultats du futur HEAD. Aucune fusion main avant 09 h Paris ; passation à 08 h 30.
