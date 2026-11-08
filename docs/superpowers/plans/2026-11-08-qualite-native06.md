# Qualité native0.6 — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. La demande explicite de Léo autorise des agents simultanés sur chemins disjoints ; cette instruction prime sur la préférence séquentielle du skill.

**Goal:** Améliorer sensiblement présentation, confort, compréhension et mémoire du jeu Windows sans changer les règles sportives ni la BDD.

**Architecture:** Garder Godot pour la présentation et le worker embarqué comme autorité de carrière. Presse et rapports utilisent les domaines existants ; le carnet appartient à la carrière. Le son est original, local et réglable. Les trois producteurs initiaux partagent une branche isolée avec réservations distinctes ; parent unique intégrateur.

**Tech Stack:** Godot4.7.2, GDScript, Node22/26, Windowsx64 ; aucune nouvelle dépendance externe requise.

**Spec:** propositions du chat acceptées intégralement par Léo, contraintes et briefs exacts `E:/Cadrage-Debordement/artefacts/native06-20261108/`. Réservation publique #73/comment6724843165. Autorisation d'avancer en autonomie, QCM si doute produit réel ; aucune validation redondante écran par écran.

## Global Constraints

- DA originale carnet, anthracite/ivoire/couleurclub ; match semi-réaliste sobre proposé par l'intégrateur à la demande de recommandation.
- Tout travail/profil temporaire/cache/outil sur E:. Profil personnel et pack privé intacts.
- Aucun changement de loi, RNG sportif, économie centrale, BDD/profils1592, identités réelles ou archives publiques tierces.
- Aucun achat/facturation/service payant ni nouvel accès secret ; sons créés localement. Essais ElevenLabs non licenciés séparés du programme commercial.
- Sauvegardes anciennes compatibles ; persistence transactionnelle, erreurs visibles, aucun repli silencieux. Export/import du carnet reçu si domaine optionnel ajouté.
- Pas de modification du gate, workflow, protection, limites ou timeouts de CI.
- Sous-agents sans commits/push/checkout ; parent seul publie. Tests graphiques sérialisés ; pas de fausse preuve DPI par simple redimensionnement.

## Review Focus

- Reprise/import/changement de club : notes et récits doivent appartenir à la bonne carrière/personne.
- Champs français longs/Unicode, fenêtre720p et haute densité : contrôles utiles visibles sans perte de focus/brouillon.
- Match arrêté/repris/changement de qualité : pas de faux contact, ballon détaché, son répété ni mutation du modèle.
- Écriture refusée : carrière/RNG/fichier préservés ; confirmation ne vaut pas réalisation.
- Archive ou rapport ancien incomplet : inconnues explicites, aucun fait inventé ni attribut caché divulgué.

## Ordre et livrables

### Tâche1 — Présentation3D (agent, vague1)
- [ ] Baseline et défauts concrets ; tests de projection/contact/entrée immuable.
- [ ] Poses et appuis crédibles, cohérence ballon/contact, terrain/lumière mesurés ; trois caméras/qualités et mode calme conservés.
- [ ] Tests ciblés et self-review ; scène de comparaison préparée pour réception graphique par parent.
Fichiers/interfaces et critères exacts : task-1-brief.md ; rapport task-1-report.md. Aucun changement du moteur ni des événements canoniques.

### Tâche2 — Lisibilité (agent, vague1)
- [ ] Auditer et corriger hiérarchie, tuiles, états/focus et contrastes à partir des captures du vraiEXE.
- [ ] Layouts aux trois tailles en conservant contrôles/brouillons ; hiérarchie partagée dans les skins, corrections locales justifiées.
- [ ] Tests ciblés, liste des captures à recevoir ; DPI réel non annoncé s'il n'a pas été exécuté.
Fichiers/interfaces exacts : task-2-brief.md ; rapport task-2-report.md. Ne touche pas main/preferences/press/decision_views.

### Tâche3 — Presse/recrutement (agent, vague1)
- [ ] Réutiliser mémoire existante pour relance réellement sourcée à une déclaration de la carrière, cinq réponses maintenues.
- [ ] Rapports argumentés besoins/qualités/freins, distinguer observations/estimation/inconnu ; consultation sans mutation.
- [ ] Tests relance exacte/club/date/import, rapports partiels/anciens et paramètres de mission inchangés.
Fichiers/interfaces exacts : task-3-brief.md ; rapport task-3-report.md.

### Tâche4 — Son original (agent, vague2)
- [ ] Générer des sons procéduraux originaux locaux (interface et stade), provenance explicite, aucune voix ou musique tierce.
- [ ] Contrôleur sonore dédié, événements dédupliqués, pas de son à la simple restauration d'un match/import ; mute et volumes indépendants sans casser la voix Gabi.
- [ ] Préférences anciennes lues exactement, tests de volume/reprise/absence/erreurs et écoute/capture parent.
Réservations détaillées à publier avant dispatch ; parent fait les raccordements main si agent précédent encore actif.

### Tâche5 — Carnet personnel (agent, vague2)
- [ ] Domaine optionnel appartenant à la carrière : notes texte bornées attachées aux IDs joueurs et une intention générale ; pas de fuite entre deux nouvelles carrières du même club.
- [ ] Vue discrète intégrée aux fiches et suivis existants, pas de menu principal supplémentaire ; édition explicite sauvegardée et suppression confirmée.
- [ ] Tests aller-retour ancien/nouveau, changement de pack/club, Unicode, limites, refus disque atomique ; export/import emporte les notes.
Décisions de schéma exactes prises après audit, brief/réservation puis revue avant raccordement.

### Tâche6 — Compréhension des décisions (parent ou agent, vague2)
- [ ] Enrichir confirmations existantes avec coût immédiat/engagement, contrepartie, irréversibilité utile et incertitude réellement connue.
- [ ] Réutiliser reçus de décision ; ne pas présenter devis/prévision comme signature/recette. Pas de formule économique parallèle.
- [ ] Tests de quelques vrais parcours coûteux/signature/contreoffre/refus, géométrie popup720p, clavier.

### Tâche7 — Démarrage et intégration (parent)
- [ ] Reproduire/instrumenter premier lancement lent sans désactiver protections système ni masquer problème. Limiter les conclusions aux mesures obtenues.
- [ ] Recevoir candidat03 et son vrai plein écran ; CI exacte54d verte constatée42503838830. Gate officiel397 puis CI postfusion si toutes conditions reçues.
- [ ] Revoir chaque lot (spec et qualité) et corriger problèmes importants ; tests ciblés puis une CI finale et revue globale des effets croisés.
- [ ] Construire le nouveauEXE, réception déplacée avec Node embarqué/PATHréduit, profils temporaires/export/import, clavier/match/son/menu/sous-menu, captures comparables.
- [ ] Publier PR, vérifier HEAD/contenu distant, gate officiel sans bypass, CI postfusion ; installer surE et raccourci seulement après validation. Compte rendu honnête des limites et passation #73.

## Décisions prises par l'intégrateur

Les agents simultanés réalisent les trois premiers lots sur chemins exclusifs ; aucun agent enfant. Les lots son et carnet attendent une place, pas une nouvelle confirmation humaine. Les changements sensibles de persistence reçoivent un contrat explicite et des tests renforcés. Les tests GPU sont sérialisés pour conserver des mesures interprétables. Ce plan complète le lot0.5 ; il ne présente pas ses fonctionnalités comme déjà livrées sur main.
